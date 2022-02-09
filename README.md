# OECM validation

Use [bcgov/designatedlands](https://github.com/bcgov/designatedlands) script to identify areas with sufficent overlapping restrictions to perhaps qualify as OECM designations.

Repo contains:

- designatedlands config file
- designatedlands data source csv
- queries for reporting on output

## Usage

1. Setup/run `designatedlands.py` script as per usual, but referencing `sources_designations.csv` held here

        cd $PROJECTS/repo/designatedlands  # navigate to designatedlands repo
        docker start dlpg                  # start up the existing db container
        conda activate designatedlands     # activate the environment
        # download datasets via script where possible
        python designatedlands.py download $PROJECTS/repo/oecm_validation/designatedlands_config.cfg

2. Manually download data as noted in `sources_designations.csv` to `source_data` folder in designatedlands repo.

3. Prep CE data manually

    CE human impacts data contains multisurface types - and does not load to postgis with existing `pgdata.ogr2pg`
    used in `designatedlands`. Rather than modifying `pgdata`, just load this table with `ogr2ogr` directly:

        ogr2ogr \
            -f PostgreSQL \
            PG:"host=localhost port=5433 user=postgres dbname=designatedlands password=postgres" \
            -lco OVERWRITE=YES \
            -overwrite \
            -lco SCHEMA=public \
            -nlt PROMOTE_TO_MULTI \
            -nlt CONVERT_TO_LINEAR \
            -nln src_39_cef_human_disturbance \
            -lco GEOMETRY_NAME=geom \
            -sql "SELECT * FROM BC_CEF_Human_Disturb_BTM_2021_merge WHERE CEF_DISTURB_GROUP_RANK IN (1,2,3,4,5,6,7,8,9,10)" \
            source_data/BC_CEF_Human_Disturbance_2021.gdb

    After loading, the features are not all valid. Make them valid:

        psql -c "UPDATE src_39_cef_human_disturbance set geom = st_makevalid(geom);"

    CE disturbance features are a nasty mess and extremely complex. Subdivide to make viewing and processing practical:

        # subdivide the geometries, writing to a new table
        psql -c "create table src_39_temp as
            select
             ogc_fid,
             cef_disturb_group,
             cef_disturb_group_rank,
             cef_disturb_sub_group,
             cef_disturb_sub_group_rank,
             source_short_name,
             source,
             cef_extraction_date,
             area_ha,
             cef_human_disturb_flag,
             st_makevalid(st_multi(ST_Subdivide(ST_Force2D(geom)))) as geom
            from src_39_cef_human_disturbance;"
        # do the switcheroo, keeping original as _bk then index
        psql -c "alter table src_39_cef_human_disturbance rename to src_39_bk;"
        psql -c "alter table src_39_temp rename to src_39_cef_human_disturbance;"
        psql -c "create index on src_39_cef_human_disturbance using gist (geom);"
        psql -c "create index on src_39_cef_human_disturbance (ogc_fid);"


4. Continue with processing:

        python designatedlands.py preprocess $PROJECTS/repo/oecm_validation/designatedlands_config.cfg
        python designatedlands.py process-vector $PROJECTS/repo/oecm_validation/designatedlands_config.cfg


## Reporting

Basic:
```
psql2csv < sql/designation_summary.sql > designation_summary.csv
psql2csv < sql/designation_summary_acts.sql > designation_summary_acts.csv
```

Separate out NR regions and CE disturbances

```
psql2csv < sql/designation_summary_acts_nrr_disturbance.sql > designation_summary_acts_nrr_disturbance.csv
```

## Dump output to .gdb

To dump to .gdb we need a version of gdal with the ESRI File Geodatabase driver enabled.
Currently, building a separate docker container seems to be the easiest way to do this.
See https://gist.github.com/smnorris/01cf5147d73cec1d05a9ec149b5f264e for complete instructions.

Once the docker container is ready, use it to dump postgres output tables to file:

    # alias the command for less typing
    alias dogr2ogr='docker run --rm -v /Users:/Users osgeo/gdal:fgdb ogr2ogr'

    # dump a previous output (without NR regions and CE disturbances)
    dogr2ogr -f FileGDB \
      $PWD/outputs/designatedlands_20200111.gdb \
      PG:postgresql://postgres:postgres@host.docker.internal:5433/designatedlands \
      -nln designations_planarized \
      -nlt Polygon \
      -sql "SELECT
        designations_planarized_id,
        array_to_string(process_order, ';') as process_order,
        array_to_string(designation, ';') as designation,
        array_to_string(source_id, ';') as source_id,
        array_to_string(source_name, ';') as source_name,
        array_to_string(forest_restrictions, ';') as forest_restrictions,
        array_to_string(mine_restrictions, ';') as mine_restrictions,
        array_to_string(og_restrictions, ';') as og_restrictions,
        forest_restriction_max,
        mine_restriction_max,
        og_restriction_max,
        map_tile,
        geom
       FROM designations_planarized_20220111"

    # dump the version with NR regions and CE roads, pulling the nr_region/cef_human_disturbance data from
    # the designation arrays and into new columns

    dogr2ogr -f FileGDB \
      $PWD/outputs/designatedlands_20200127.gdb \
      PG:postgresql://postgres:postgres@host.docker.internal:5433/designatedlands \
      -nln designations_planarized \
      -nlt Polygon \
      -sql "with positions as
        (
          select
            designations_planarized_id,
            array_position(designation, 'nr_region') as nr_position,
            array_position(designation, 'cef_human_disturbance') as cef_position
          from designations_planarized
        )
        select
          a.designations_planarized_id,
          array_to_string(array_remove(array_remove(designation, 'cef_human_disturbance'), 'nr_region'), ';') as designations,
          array_to_string(array_remove(array_remove(source_id, source_id[b.cef_position]), source_id[b.nr_position]), ';') as source_id,
          array_to_string(array_remove(array_remove(source_name, source_name[b.cef_position]), source_name[b.nr_position]), ';') as source_name,
          array_to_string(forest_restrictions, ';') as forest_restrictions,
          array_to_string(mine_restrictions, ';') as mine_restrictions,
          array_to_string(og_restrictions, ';') as og_restrictions,
          forest_restriction_max,
          mine_restriction_max,
          og_restriction_max,
          case when designation && ARRAY['nr_region'] then source_name[b.nr_position] end as nr_region,
          case when designation && ARRAY['cef_human_disturbance'] then source_name[b.cef_position] end as cef_human_disturbance,
          map_tile,
          geom
        from designations_planarized a
        inner join positions b
        on a.designations_planarized_id = b.designations_planarized_id;"