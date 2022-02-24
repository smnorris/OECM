#!/bin/bash
set -euxo pipefail

# add associated acts column to designatedlands_planarized, creating oecm table
psql -f sql/oecm.sql

# Load NRR/CEF data to designatedlands db
# NRR (manual download as WFS does not include this layer)
ogr2ogr \
    -f PostgreSQL \
    PG:$DATABASE_URL \
    -lco OVERWRITE=YES \
    -overwrite \
    -lco SCHEMA=public \
    -nlt PROMOTE_TO_MULTI \
    -nlt CONVERT_TO_LINEAR \
    -nln adm_nr_regions_sp \
    -lco GEOMETRY_NAME=geom \
    data/ADM_NR_REGIONS_SP.gdb \
    WHSE_ADMIN_BOUNDARIES_ADM_NR_REGIONS_SP

# a pk is automatically created, rename to something more clear
psql -c "alter table adm_nr_regions_sp rename column objectid_1 to adm_nr_region_id"

# CEF (manual download from GeoBC)
ogr2ogr \
    -f PostgreSQL \
    PG:$DATABASE_URL \
    -lco OVERWRITE=YES \
    -overwrite \
    -lco SCHEMA=public \
    -nlt PROMOTE_TO_MULTI \
    -nlt CONVERT_TO_LINEAR \
    -nln cef_load \
    -lco GEOMETRY_NAME=geom \
    -sql "SELECT * FROM BC_CEF_Human_Disturb_BTM_2021_merge WHERE CEF_DISTURB_GROUP_RANK IN (1,2,3,4,5,6,7,8,9,10)" \
    data/BC_CEF_Human_Disturbance_2021.gdb

# CEF features are extremely complex - validate and subdivide
psql -c "create table cef_human_disturbance as
    select
      ogc_fid as cef_id,
      cef_disturb_group,
      cef_disturb_group_rank,
      cef_disturb_sub_group,
      cef_disturb_sub_group_rank,
      source_short_name,
      source,
      cef_extraction_date,
      area_ha,
      cef_human_disturb_flag,
      st_makevalid(
        st_multi(
          st_subdivide(
            st_force2d(
              st_makevalid(geom)
            )
          )
        )
      ) as geom
    from cef_load;"

psql -c "create index on cef_human_disturbance using gist (geom);"
psql -c "create index on cef_human_disturbance (cef_id);"

# drop temp CEF load table
psql -c "drop table cef_load;"

# create empty output table for overlay
psql -c "drop table if exists oecm_nrr_cef"
psql -c "create table oecm_nrr_cef
(
  oecm_nrr_cef_id serial primary key,
  designations_planarized_id integer,
  adm_nr_region_id integer,
  cef_id integer,
  designation text,
  source_id text,
  source_name text,
  forest_restrictions text,
  mine_restrictions text,
  og_restrictions text,
  forest_restriction_max integer,
  mine_restriction_max integer,
  og_restriction_max integer,
  sum_restriction integer,
  acts text,
  nr_region text,
  cef_disturb_group_rank integer,
  cef_disturb_sub_group text,
  map_tile text,
  geom geometry(polygon, 3005)
);"

# run overlay in parallel
TILES=$(psql -AtX -c "SELECT distinct map_tile from designations_planarized order by map_tile")
parallel --progress psql -f sql/oecm_nrr_cef.sql -v tile={1} ::: $TILES

# delete features from oecm_nrr_cef that are outside of designatedlands tiling system (ie, marine)
psql -c "delete from oecm_nrr_cef where designations_planarized_id is null"

# index the output geoms 
psql -c "create index on oecm_nrr_cef using gist (geom)"

# run reporting
mkdir -p outputs
psql2csv < sql/oecm_summary.sql > outputs/oecm_summary.csv
psql2csv < sql/oecm_nrr_cef_summary.sql > outputs/oecm_nrr_cef_summary.csv
