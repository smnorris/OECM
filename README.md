# OECM validation

Use [bcgov/designatedlands](https://github.com/bcgov/designatedlands) script to identify areas with sufficent overlapping restrictions to perhaps qualify as OECM designations.

Repo contains:

- config file
- data source csv
- script for overlaying NRR/CEF with oecm designatedlands output
- queries for reporting

## Run overlays

1. Use the existing `designatedlands` conda/docker setup:

        cd $PROJECTS/repo/designatedlands  # navigate to designatedlands repo
        docker start dlpg                  # start up the existing db container
        conda activate designatedlands     # activate the environment

2. Manually download required data as noted in `sources_designations.csv` to `$PROJECTS/repo/designatedlands/source_data` folder.

3. Still in `designatedlands` folder, run designatedlands script to create required output table `designations_planarized`:

        python designatedlands.py download $PROJECTS/repo/oecm_validation/oecm.cfg
        python designatedlands.py preprocess $PROJECTS/repo/oecm_validation/oecm.cfg
        python designatedlands.py process-vector $PROJECTS/repo/oecm_validation/oecm.cfg

4. Load CEF and NRR data, overlay with `designations_planarized`, create custom output table, run reports:

        cd $PROJECTS/repo/oecm_validation
        ./oecm_validation.sh

## Dump output tables to file:

To dump to .gdb we need a version of gdal with the ESRI File Geodatabase driver enabled.
Currently, building a separate docker container seems to be the easiest way to do this.
See https://gist.github.com/smnorris/01cf5147d73cec1d05a9ec149b5f264e for complete instructions.

Once the docker container is ready, use it to dump postgres output tables to file:

    docker run --rm -v /Users:/Users osgeo/gdal:fgdb \
      ogr2ogr -f FileGDB \
      $PWD/outputs/oecm_designations.gdb \
      PG:postgresql://postgres:postgres@host.docker.internal:5433/designatedlands \
      -nln designations_planarized \
      -nlt Polygon \
      -sql "select * from oecm"

    docker run --rm -v /Users:/Users osgeo/gdal:fgdb \
      ogr2ogr -f FileGDB \
      $PWD/outputs/oecm_designations.gdb \
      PG:postgresql://postgres:postgres@host.docker.internal:5433/designatedlands \
      -update \
      -nln designations_planarized_cef \
      -nlt Polygon \
      -sql "select
              a.oecm_nrr_cef_id,
              a.designations_planarized_id,
              b.designation,
              b.source_id,
              b.source_name,
              b.forest_restrictions,
              b.mine_restrictions,
              b.og_restrictions,
              b.forest_restriction_max,
              b.mine_restriction_max,
              b.og_restriction_max,
              b.sum_restriction,
              b.acts,
              b.map_tile,
              a.adm_nr_region_id,
              c.region_name,
              a.cef_id,
              d.cef_disturb_group_rank,
              d.cef_disturb_sub_group,
              a.geom
            from oecm_nrr_cef a
            inner join oecm b
            on a.designations_planarized_id = b.designations_planarized_id
            left outer join adm_nr_regions_sp c
            on a.adm_nr_region_id = c.adm_nr_region_id
            left outer join cef_human_disturbance d
            on a.cef_id = d.cef_id;"