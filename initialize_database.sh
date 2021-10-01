#!/bin/bash

mkdir -p raw_tlc_data

createdb nyc-ecommerce-analysis
psql nyc-ecommerce-analysis -c "CREATE EXTENSION IF NOT EXISTS postgis;"

shp2pgsql -s 102718:4326 -I shapefiles/taxi_zones/taxi_zones.shp | psql -d nyc-ecommerce-analysis
shp2pgsql -s 102718:4326 -I shapefiles/nyct2010_20d/nyct2010.prj | psql -d nyc-ecommerce-analysis
psql nyc-ecommerce-analysis -c "CREATE INDEX ON taxi_zones (locationid);"

psql nyc-ecommerce-analysis -f setup_files/create_schema.sql
