-- Dashboard 2
-- Create a reusable dashboard view for weekday station-hour flow
CREATE OR REPLACE VIEW
  `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.dashboard_station_pressure`
AS

-- Step 1: Keep weekday journeys and extract start/end hours
WITH weekday_journeys AS (
  SELECT
    start_station_id,
    start_station_name,
    end_station_id,
    end_station_name,

    -- Extract the hour when each journey started
    EXTRACT(HOUR FROM start_datetime) AS start_hour,

    -- Extract the hour when each journey ended
    EXTRACT(HOUR FROM end_datetime) AS end_hour

  FROM
    `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.journeys_clean`

  -- Monday-Friday only
  WHERE
    EXTRACT(DAYOFWEEK FROM start_datetime) NOT IN (1, 7)
),

-- Step 2: Count the number of weekdays in the dataset
weekday_count AS (
  SELECT
    COUNT(DISTINCT DATE(start_datetime)) AS number_of_weekdays
  FROM
    `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.journeys_clean`
  WHERE
    EXTRACT(DAYOFWEEK FROM start_datetime) NOT IN (1, 7)
),

-- Step 3: Count departures by station and hour
departures AS (
  SELECT
    start_station_id AS station_id,
    start_station_name AS station_name,
    start_hour AS hour,
    COUNT(*) AS departures
  FROM
    weekday_journeys
  GROUP BY
    station_id,
    station_name,
    hour
),

-- Step 4: Count arrivals by station and hour
arrivals AS (
  SELECT
    end_station_id AS station_id,
    end_station_name AS station_name,
    end_hour AS hour,
    COUNT(*) AS arrivals
  FROM
    weekday_journeys
  GROUP BY
    station_id,
    station_name,
    hour
),

-- Step 5: Combine both sides of station flow
station_hour_flow AS (
  SELECT
    COALESCE(d.station_id, a.station_id) AS station_id,
    COALESCE(d.station_name, a.station_name) AS station_name,
    COALESCE(d.hour, a.hour) AS hour,
    COALESCE(d.departures, 0) AS departures,
    COALESCE(a.arrivals, 0) AS arrivals
  FROM
    departures AS d
  FULL OUTER JOIN
    arrivals AS a
  ON
    d.station_id = a.station_id
    AND d.hour = a.hour
)

-- Step 6: Convert monthly weekday totals into average weekday flow
SELECT
  station_id,
  station_name,
  hour,

  -- Flag operational workshop locations so they can be filtered in BI
  CASE
    WHEN station_name LIKE 'Mechanical Workshop%'
      THEN TRUE
    ELSE FALSE
  END AS is_operational_location,

  SAFE_DIVIDE(
    departures,
    number_of_weekdays
  ) AS avg_departures_per_weekday,

  SAFE_DIVIDE(
    arrivals,
    number_of_weekdays
  ) AS avg_arrivals_per_weekday,

  -- Positive = accumulation; negative = depletion
  SAFE_DIVIDE(
    arrivals - departures,
    number_of_weekdays
  ) AS avg_net_flow_per_weekday,

  -- Measure pressure regardless of direction
  ABS(
    SAFE_DIVIDE(
      arrivals - departures,
      number_of_weekdays
    )
  ) AS abs_avg_net_flow

FROM
  station_hour_flow

CROSS JOIN
  weekday_count;


-- Check how many station-hour rows and stations are available
SELECT
  COUNT(*) AS station_hour_rows,
  COUNT(DISTINCT station_id) AS stations,
  MIN(hour) AS first_hour,
  MAX(hour) AS last_hour
FROM
  `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.dashboard_station_pressure`;


-- Cross-check Waterloo Station 3 against our Python results
SELECT
  station_name,
  hour,
  avg_departures_per_weekday,
  avg_arrivals_per_weekday,
  avg_net_flow_per_weekday
FROM
  `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.dashboard_station_pressure`
WHERE
  station_id = 1072
  AND hour IN (8, 17)
ORDER BY
  hour;