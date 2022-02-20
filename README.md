# OECM validation

Use [bcgov/designatedlands](https://github.com/bcgov/designatedlands) script to identify areas with sufficent overlapping restrictions to perhaps qualify as OECM designations.

Repo contains:

- config file
- data source csv
- queries for reporting on output

## Usage

1. Use the existing `designatedlands` conda/docker setup:

        cd $PROJECTS/repo/designatedlands  # navigate to designatedlands repo
        docker start dlpg                  # start up the existing db container
        conda activate designatedlands     # activate the environment

2. Manually download required data as noted in `sources_designations.csv` to `$PROJECTS/repo/designatedlands/source_data` folder.

3. Still in `designatedlands` folder, load all data to postgres:

        python designatedlands.py download $PROJECTS/repo/oecm_validation/oecm_nrr_cef.cfg

    This will bail on source 40, CE human disturbance. Stop the script and load manually.

4. Load CE data manually

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
            -nln src_40_cef_human_disturbance \
            -lco GEOMETRY_NAME=geom \
            -sql "SELECT * FROM BC_CEF_Human_Disturb_BTM_2021_merge WHERE CEF_DISTURB_GROUP_RANK IN (1,2,3,4,5,6,7,8,9,10)" \
            source_data/BC_CEF_Human_Disturbance_2021.gdb

    After loading, the features are not all valid. Make them valid:

        psql -c "UPDATE src_40_cef_human_disturbance set geom = st_makevalid(geom);"

    CE disturbance features are a nasty mess and extremely complex. Subdivide to make viewing and processing practical:

        # subdivide the geometries, writing to a new table
        psql -c "create table src_40_temp as
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
            from src_40_cef_human_disturbance;"
        # do the switcheroo, keeping original as _bk then index
        psql -c "alter table src_40_cef_human_disturbance rename to src_40_bk;"
        psql -c "alter table src_40_temp rename to src_40_cef_human_disturbance;"
        psql -c "create index on src_40_cef_human_disturbance using gist (geom);"
        psql -c "create index on src_40_cef_human_disturbance (ogc_fid);"
        # drop original
        psql -c "drop table src_40_bk"


5. Preprocess:

        python designatedlands.py preprocess $PROJECTS/repo/oecm_validation/oecm_nrr_cef.cfg

6. Create an output without nrr/cef inputs (using an identical source list, minus those two sources) and rename:

        python designatedlands.py process-vector $PROJECTS/repo/oecm_validation/oecm.cfg
        psql -c "alter table designations_planarized rename to designations_planarized_oecm"

6. Create another output *with* nrr/cef inputs :

        python designatedlands.py process-vector $PROJECTS/repo/oecm_validation/oecm_nrr_cef.cfg
        # creating the index bails because it is named and already exists in the renamed output from above - index with this command
        psql -c "create index on designations_planarized using gist (geom);""
        psql -c "alter table designations_planarized rename to designations_planarized_oecm_nrr_cef"

Yes, creating the two different outputs this way means all the desingation overlays are run twice - but the overlays do not take long, dumping features to .gdb is currently the bottleneck. Reworking and using the `designatedlands overlay` tool would remove this redundancy.

## Reporting

        mkdir -p outputs
        psql2csv < sql/oecm_summary.sql > outputs/oecm_summary.csv
        psql2csv < sql/oecm_nrr_cef_summary.sql > outputs/oecm_nrr_cef_summary.csv

Create custom outputs:

        psql -f sql/oecm_dump.sql


## Dump output to .gdb

To dump to .gdb we need a version of gdal with the ESRI File Geodatabase driver enabled.
Currently, building a separate docker container seems to be the easiest way to do this.
See https://gist.github.com/smnorris/01cf5147d73cec1d05a9ec149b5f264e for complete instructions.

Once the docker container is ready, use it to dump postgres output tables to file:

    docker run --rm -v /Users:/Users osgeo/gdal:fgdb \
      ogr2ogr -f FileGDB \
      $PWD/outputs/designatedlands_20220210.gdb \
      PG:postgresql://postgres:postgres@host.docker.internal:5433/designatedlands \
      -nln designations_planarized \
      -nlt Polygon \
      -sql "select * from oecm"

    docker run --rm -v /Users:/Users osgeo/gdal:fgdb \
      ogr2ogr -f FileGDB \
      $PWD/outputs/designatedlands_20220219.gdb \
      PG:postgresql://postgres:postgres@host.docker.internal:5433/designatedlands \
      -update \
      -nln designations_planarized_cef \
      -nlt Polygon \
      -sql "select * from oecm_nrr_cef"