# OECM validation

Use [bcgov/designatedlands](https://github.com/bcgov/designatedlands) script to identify areas with sufficent overlapping restrictions to perhaps qualify as OECM designations.

Repo contains list of designations/level of restriction (`sources_designations.csv`) and reporting queries.

## Usage

Run `designatedlands.py` script as per usual, but referencing `sources_designations.csv` held here.

## Reporting

`psql2csv < sql/designation_summary.sql > designation_summary.csv`
`psql2csv < sql/designation_summary_acts.sql > designation_summary_acts.csv`