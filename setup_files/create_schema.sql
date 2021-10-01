CREATE TABLE green_tripdata_staging (
  id bigserial primary key,
  vendor_id text,
  lpep_pickup_datetime text,
  lpep_dropoff_datetime text,
  store_and_fwd_flag text,
  rate_code_id text,
  pickup_longitude numeric,
  pickup_latitude numeric,
  dropoff_longitude numeric,
  dropoff_latitude numeric,
  passenger_count text,
  trip_distance text,
  fare_amount text,
  extra text,
  mta_tax text,
  tip_amount text,
  tolls_amount text,
  ehail_fee text,
  improvement_surcharge text,
  total_amount text,
  payment_type text,
  trip_type text,
  pickup_location_id text,
  dropoff_location_id text,
  congestion_surcharge text,
  junk1 text,
  junk2 text
)
WITH (
  autovacuum_enabled = false,
  toast.autovacuum_enabled = false
);
/*
N.B. junk columns are there because some tripdata file headers are
inconsistent with the actual data, e.g. header says 20 or 21 columns per row,
but data actually has 22 or 23 columns per row, which COPY doesn't like.
junk1 and junk2 should always be null
*/

CREATE TABLE yellow_tripdata_staging (
  id bigserial primary key,
  vendor_id text,
  tpep_pickup_datetime text,
  tpep_dropoff_datetime text,
  passenger_count text,
  trip_distance text,
  pickup_longitude numeric,
  pickup_latitude numeric,
  rate_code_id text,
  store_and_fwd_flag text,
  dropoff_longitude numeric,
  dropoff_latitude numeric,
  payment_type text,
  fare_amount text,
  extra text,
  mta_tax text,
  tip_amount text,
  tolls_amount text,
  improvement_surcharge text,
  total_amount text,
  pickup_location_id text,
  dropoff_location_id text,
  congestion_surcharge text,
  junk1 text,
  junk2 text
)
WITH (
  autovacuum_enabled = false,
  toast.autovacuum_enabled = false
);

CREATE TABLE fhv_trips_staging (
  dispatching_base_num text,
  pickup_datetime text,
  dropoff_datetime text,
  pickup_location_id text,
  dropoff_location_id text,
  shared_ride text,
  hvfhs_license_num text,
  junk text
)
WITH (
  autovacuum_enabled = false,
  toast.autovacuum_enabled = false
);

CREATE TABLE fhv_trips (
  id bigserial primary key,
  dispatching_base_num text,
  pickup_datetime timestamp without time zone,
  dropoff_datetime timestamp without time zone,
  pickup_location_id integer,
  dropoff_location_id integer,
  shared_ride integer,
  hvfhs_license_num text
);

CREATE TABLE hvfhs_licenses (
  license_number text primary key,
  company_name text
);

INSERT INTO hvfhs_licenses
VALUES ('HV0002', 'juno'),
       ('HV0003', 'uber'),
       ('HV0004', 'via'),
       ('HV0005', 'lyft');

CREATE TABLE cab_types (
  id serial primary key,
  type text
);

INSERT INTO cab_types (type) VALUES ('yellow'), ('green');

CREATE TABLE trips (
  id bigserial primary key,
  cab_type_id integer,
  vendor_id text,
  pickup_datetime timestamp without time zone,
  dropoff_datetime timestamp without time zone,
  store_and_fwd_flag text,
  rate_code_id integer,
  pickup_longitude numeric,
  pickup_latitude numeric,
  dropoff_longitude numeric,
  dropoff_latitude numeric,
  passenger_count integer,
  trip_distance numeric,
  fare_amount numeric,
  extra numeric,
  mta_tax numeric,
  tip_amount numeric,
  tolls_amount numeric,
  ehail_fee numeric,
  improvement_surcharge numeric,
  congestion_surcharge numeric,
  total_amount numeric,
  payment_type text,
  trip_type integer,
  pickup_nyct2010_gid integer,
  dropoff_nyct2010_gid integer,
  pickup_location_id integer,
  dropoff_location_id integer
);

CREATE TABLE nyct2010_taxi_zone_mapping AS
SELECT
  ct.boroct2010,
  ct.gid AS nyct2010_gid,
  tz.locationid AS taxi_zone_location_id,
  ST_Area(ST_Intersection(ct.geom, tz.geom)) / ST_Area(ct.geom) AS overlap
FROM nyct2010 ct, taxi_zones tz
WHERE ST_Intersects(ct.geom, tz.geom)
  AND ST_Area(ST_Intersection(ct.geom, tz.geom)) / ST_Area(ct.geom) > 0.5;

CREATE UNIQUE INDEX ON nyct2010_taxi_zone_mapping (nyct2010_gid);
CREATE INDEX ON nyct2010_taxi_zone_mapping (nyct2010_gid, taxi_zone_location_id);
CREATE INDEX ON nyct2010_taxi_zone_mapping (boroct2010, taxi_zone_location_id);

CREATE TABLE hhi_by_tract (
  boroct2010 text not null,
  variable_num int not null,
  variable_label text not null,
  estimate numeric not null
);
CREATE UNIQUE INDEX ON hhi_by_tract (boroct2010, variable_num);

\copy hhi_by_tract FROM 'setup_files/hhi_by_tract.csv' CSV HEADER;

CREATE TABLE taxi_zone_speed_zone_mapping (
  taxi_zone_locationid integer primary key,
  speed_zone integer not null
);

\copy taxi_zone_speed_zone_mapping FROM 'setup_files/taxi_zone_speed_zone_mapping.csv' CSV HEADER;

CREATE TABLE taxi_zone_names AS
SELECT DISTINCT
  locationid,
  zone,
  borough
FROM taxi_zones;
CREATE UNIQUE INDEX ON taxi_zone_names (locationid);
