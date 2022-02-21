# OECM validation

Use [bcgov/designatedlands](https://github.com/bcgov/designatedlands) script to identify areas with sufficent overlapping restrictions to perhaps qualify as OECM designations.

Repo contains:

- config file
- data source csv
- script for overlaying NRR/CEF with oecm designatedlands output
- queries for reporting

This README does not cover db setup, see designatedlands repo for more info.

## Run overlays

1. Use the existing `designatedlands` conda environment:

        cd $PROJECTS/repo/designatedlands   # navigate to designatedlands repo
        conda env create -f environment.yml # create environment if it does not already exist
        conda activate designatedlands      # activate the environment

2. Manually download required data as noted in `sources_designations.csv` to `$PROJECTS/repo/designatedlands/source_data` folder

3. Remove shape_area column from Peace Moberly Tract shapefile (value is too large)

        ogr2ogr source_data/pm.shp source_data/Peace_Moberly_Tract.shp -select Shape_Leng

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
See https://gist.github.com/smnorris/01cf5147d73cec1d05a9ec149b5f264e for complete instructions. Note that creating the .gdb with this method  is *extremely* slow. It is managable on an intel mac but may not be feasible on an M1 mac.

To avoid monkeying with the network settings (necessary to connect from the container to db on localhost), do the 
translation in two steps - first dumping to FlatGeobuf temp files and then to file gdb.

    # pg -> .fgb
    mkdir -p outputs/oecm_designations
    time ogr2ogr -f FlatGeobuf \
      outputs/oecm_designations/designations_planarized.fgb \
      PG:$DATABASE_URL \
      -lco SPATIAL_INDEX=NO \
      -nln designations_planarized \
      -nlt Polygon \
      -sql "select * from oecm"
    time ogr2ogr -f FlatGeobuf \
      outputs/oecm_designations/designations_planarized_cef.fgb \
      PG:$DATABASE_URL \
      -lco SPATIAL_INDEX=NO \
      -nln designations_planarized_cef \
      -nlt Polygon \
      -sql "select * from oecm_nrr_cef"

    # .fgb -> .gdb (this takes several hours)
    docker run --network=host --platform linux/amd64 --rm -v /Users:/Users osgeo/gdal:fgdb \
      ogr2ogr -f FileGDB \
      $PWD/outputs/oecm_designations.gdb \
      -nln designations_planarized \
      -nlt Polygon \
      $PWD/outputs/oecm_designations/designations_planarized.fgb \
      designations_planarized
    docker run --platform linux/amd64 --rm -v /Users:/Users osgeo/gdal:fgdb \
      ogr2ogr -f FileGDB \
      $PWD/outputs/oecm_designations.gdb \
      -update \
      -nln designations_planarized_cef \
      -nlt Polygon \
      $PWD/outputs/oecm_designations/designations_planarized_cef.fgb \
      designations_planarized_cef

    # delete the temp flatgeobufs
    rm -r outputs/oecm_designations