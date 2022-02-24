# OECM validation

Use [bcgov/designatedlands](https://github.com/bcgov/designatedlands) script to identify areas with sufficent overlapping restrictions to perhaps qualify as OECM designations.

Repo contains:

- config file
- data source csv
- script for overlaying NRR/CEF with oecm designatedlands output
- queries for reporting
- rough guide to dumping to .gdb

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

4. Load CEF and NRR data, overlay with `designations_planarized`, create custom output table, run reports, dump to temp file:

        cd $PROJECTS/repo/oecm_validation
        ./oecm_validation.sh

5. Run a quick area based QA to see if total areas match and find features with biggest area differences between outputs:

        psql -f sql/qa.sql

6. Load temp files to remote for conversion to .gdb:

        scp outputs/oecm_designations/*fgb <USER>@<HOST>:<PATH>
        ssh <HOST> 'bash -s' < fgb2gdb.sh
