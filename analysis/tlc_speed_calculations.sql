-- use taxi trips from 2018/19 to calculate trip distance percentiles between each pair of zones
CREATE TABLE taxi_trip_distance_percentiles AS
SELECT
  pickup_location_id,
  dropoff_location_id,
  count(*) AS num_trips,
  percentile_cont(0.01) WITHIN GROUP (ORDER BY trip_distance) AS p01,
  percentile_cont(0.05) WITHIN GROUP (ORDER BY trip_distance) AS p05,
  percentile_cont(0.10) WITHIN GROUP (ORDER BY trip_distance) AS p10,
  percentile_cont(0.25) WITHIN GROUP (ORDER BY trip_distance) AS p25,
  percentile_cont(0.50) WITHIN GROUP (ORDER BY trip_distance) AS p50,
  percentile_cont(0.75) WITHIN GROUP (ORDER BY trip_distance) AS p75,
  percentile_cont(0.90) WITHIN GROUP (ORDER BY trip_distance) AS p90,
  percentile_cont(0.95) WITHIN GROUP (ORDER BY trip_distance) AS p95,
  percentile_cont(0.99) WITHIN GROUP (ORDER BY trip_distance) AS p99,
  max(trip_distance) AS max
FROM trips
WHERE pickup_datetime >= '2018-01-01'
  AND pickup_datetime < '2020-01-01'
  AND trip_distance >= 0.2
  AND trip_distance < 50
  AND extract(epoch FROM dropoff_datetime - pickup_datetime) BETWEEN 2 * 60 AND 180 * 60
  AND trip_distance / extract(epoch FROM dropoff_datetime - pickup_datetime) * 3600 BETWEEN 1 AND 80
GROUP BY 1, 2
ORDER BY 1, 2;
CREATE INDEX ON taxi_trip_distance_percentiles (pickup_location_id, dropoff_location_id);

-- calculate 2018/19 taxi trip average distances traveled between zones, with some attempt to remove outliers
CREATE TABLE taxi_trip_distance_averages AS
SELECT
  t.pickup_location_id,
  t.dropoff_location_id,
  count(*) AS num_trips,
  avg(trip_distance) AS mean_distance,
  percentile_cont(0.5) WITHIN GROUP (ORDER BY trip_distance) AS median_distance,
  avg(t.trip_distance / extract(epoch FROM t.dropoff_datetime - t.pickup_datetime) * 3600) AS mean_mph,
  percentile_cont(0.5) WITHIN GROUP (ORDER BY t.trip_distance / extract(epoch FROM t.dropoff_datetime - t.pickup_datetime) * 3600) AS median_mph
FROM trips t
  INNER JOIN taxi_trip_distance_percentiles p
    ON t.pickup_location_id = p.pickup_location_id
    AND t.dropoff_location_id = p.dropoff_location_id
WHERE t.pickup_datetime >= '2018-01-01'
  AND t.pickup_datetime < '2020-01-01'
  AND t.trip_distance >= 0.2
  AND t.trip_distance < 50
  AND extract(epoch FROM t.dropoff_datetime - t.pickup_datetime) BETWEEN 2 * 60 AND 180 * 60
  AND t.trip_distance / extract(epoch FROM t.dropoff_datetime - t.pickup_datetime) * 3600 BETWEEN 1 AND 80
  AND t.trip_distance < p.p99
GROUP BY 1, 2
ORDER BY 1, 2;

CREATE OR REPLACE VIEW fhv_trips_with_extra_fields AS
SELECT
  *,
  extract(epoch FROM dropoff_datetime - pickup_datetime) AS trip_duration_seconds,
  pickup_datetime::date AS date,
  extract(hour FROM pickup_datetime) AS hour
FROM fhv_trips;

/*
estimate avg speeds for Uber/Lyft trips from Jun 2019, Oct 2019, and Feb 2020

assume each Uber/Lyft trip from A => B traveled the average distance calculated from taxi data above

in order to reduce the impact of highway travel, restrict to A => B trips where A and B are in the same borough,
  and the median A => B taxi trip was less than 3 miles
*/
CREATE TABLE uber_lyft_trip_speeds AS
SELECT
  t.id AS trip_id,
  t.pickup_location_id,
  t.dropoff_location_id,
  CASE
    WHEN extract(dow FROM t.date) IN (0, 6) OR t.date IN ('2019-10-14', '2020-02-17') THEN 'weekend_or_holiday'
    ELSE 'weekday'
  END AS day_type,
  CASE
    WHEN t.hour BETWEEN 0 AND 5 THEN 0
    WHEN t.hour BETWEEN 6 AND 11 THEN 6
    WHEN t.hour BETWEEN 12 AND 19 THEN 12
    WHEN t.hour BETWEEN 20 AND 23 THEN 20
  END AS time_of_day,
  d.mean_distance / t.trip_duration_seconds * 3600 AS estimated_mph,
  d.mean_distance,
  t.trip_duration_seconds
FROM fhv_trips_with_extra_fields t
  INNER JOIN taxi_trip_distance_averages d
    ON t.pickup_location_id = d.pickup_location_id
    AND t.dropoff_location_id = d.dropoff_location_id
  INNER JOIN taxi_zone_names puz ON t.pickup_location_id = puz.locationid
  INNER JOIN taxi_zone_names doz ON t.dropoff_location_id = doz.locationid
WHERE coalesce(t.shared_ride, 0) = 0
  AND t.hvfhs_license_num IS NOT NULL
  AND t.hvfhs_license_num IN ('HV0003', 'HV0005')
  AND (
       (t.pickup_datetime >= '2019-06-01' AND t.pickup_datetime < '2019-07-01')
    OR (t.pickup_datetime >= '2019-10-01' AND t.pickup_datetime < '2019-11-01')
    OR (t.pickup_datetime >= '2020-02-01' AND t.pickup_datetime < '2020-03-01')
  )
  AND t.trip_duration_seconds >= 2 * 60
  AND t.trip_duration_seconds < 180 * 60
  AND d.num_trips >= 100
  AND d.median_distance < 3
  AND puz.borough = doz.borough;

CREATE TABLE fhv_speeds_by_zone AS
SELECT
  pickup_location_id AS locationid,
  day_type,
  time_of_day,
  count(*) AS num_trips,
  avg(estimated_mph) AS mean_trip_mph,
  percentile_cont(0.5) WITHIN GROUP (ORDER BY estimated_mph) AS median_trip_mph,
  avg(mean_distance) AS mean_trip_distance,
  avg(trip_duration_seconds) / 60 AS mean_trip_minutes
FROM uber_lyft_trip_speeds
WHERE pickup_location_id != 1
GROUP BY locationid, day_type, time_of_day
ORDER BY locationid, day_type, time_of_day;

CREATE OR REPLACE TEMPORARY VIEW fhv_speeds_output_data AS
SELECT
  z.locationid,
  z.zone,
  z.borough,
  m.speed_zone,
  s.day_type,
  s.time_of_day,
  s.mean_trip_mph,
  s.median_trip_mph,
  s.num_trips,
  s.mean_trip_distance,
  s.mean_trip_minutes
FROM fhv_speeds_by_zone s
  INNER JOIN taxi_zone_names z ON s.locationid = z.locationid
  INNER JOIN taxi_zone_speed_zone_mapping m ON s.locationid = m.taxi_zone_locationid
ORDER BY z.locationid, s.day_type, s.time_of_day;

\copy (SELECT * FROM fhv_speeds_output_data) TO 'estimated_speeds_by_zone.csv' CSV HEADER;
