#!/bin/bash

fhvhv_schema="(hvfhs_license_num,dispatching_base_num,pickup_datetime,dropoff_datetime,pickup_location_id,dropoff_location_id,shared_ride)"

for filename in raw_tlc_data/fhvhv_tripdata*.csv; do
  echo "`date`: beginning load for ${filename}"
  cat $filename | psql nyc-ecommerce-analysis -c "COPY fhv_trips_staging ${fhvhv_schema} FROM stdin CSV HEADER;"
  echo "`date`: finished raw load for ${filename}"
  psql nyc-ecommerce-analysis -f setup_files/populate_fhv_trips.sql
  echo "`date`: loaded trips for ${filename}"
done;

psql nyc-ecommerce-analysis -c "CREATE INDEX ON fhv_trips USING BRIN (pickup_datetime) WITH (pages_per_range = 32);"
