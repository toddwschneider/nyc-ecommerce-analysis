# NYC E-commerce Deliveries Analysis

Materials prepared in support of Charles Komanoff's report to the New York City Council, [Taming NYC's E-Delivery Gridlock](https://www.komanoff.net/cars_II/Taming_NYC's_E-Delivery_Gridlock.pdf)

The setup and schema code is largely copied from the [nyc-taxi-data](https://github.com/toddwschneider/nyc-taxi-data) GitHub repository, with a few changes:

- Import only selected months of data, instead of full history
  - Taxis: Jan 2018–Dec 2019
  - Uber/Lyft: Jun 2019, Oct 2019, Feb 2020
- Add `fetch_acs_hhi_data.R` script to get household income data from the [American Community Survey](https://www.census.gov/programs-surveys/acs)
- Add `tlc_speed_calculations.sql` analysis script to estimate vehicle travel speeds in different areas of the city

## Requirements

- [PostgreSQL](https://www.postgresql.org/download)
- [PostGIS](https://postgis.net/install)

## Setup Instructions

```sh
./initialize_database.sh
./download_raw_data.sh
./import_trip_data.sh
./import_fhv_trip_data.sh
```

## Questions/issues/contact

todd@toddwschneider.com, or open a GitHub issue
