#!/bin/bash
set -euxo pipefail


# convert temp .fgb files to .gdb

docker run --rm -v /home:/home osgeo/gdal:fgdb \
  ogr2ogr -f FileGDB \
  $PWD/oecm_designations.gdb \
  -nln oecm \
  -nlt Polygon \
  $PWD/oecm.fgb \
  oecm

docker run --rm -v /home:/home osgeo/gdal:fgdb \
  ogr2ogr -f FileGDB \
  $PWD/oecm_designations.gdb \
  -update \
  -nln oecm_nrr_cef_groups \
  -nlt Polygon \
  $PWD/oecm_nrr_cef_groups.fgb \
  oecm_nrr_cef_groups

docker run --rm -v /home:/home osgeo/gdal:fgdb \
  ogr2ogr -f FileGDB \
  $PWD/oecm_designations.gdb \
  -update \
  -nln oecm_nrr_cef_subgroups \
  -nlt Polygon \
  $PWD/oecm_nrr_cef_subgroups.fgb \
  oecm_nrr_cef_subgroups

zip -r oecm_designations.gdb.zip oecm_designations.gdb

