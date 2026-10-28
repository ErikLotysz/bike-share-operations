-- Dashboard 3
-- Create the dashboard-ready hourly weather and demand view
CREATE OR REPLACE VIEW
  `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.dashboard_weather_demand`
AS

-- Step 1: Aggregate individual journeys to hourly demand
WITH hourly_demand AS (
  SELECT
    DATETIME_TRUNC(start_datetime, HOUR) AS local_hour,

    -- Count journeys starting during each local clock hour
    COUNT(*) AS journey_starts

  FROM
    `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.journeys_clean`

  GROUP BY
    local_hour
),

-- Step 2: Join hourly demand to the validated weather observations
demand_weather AS (
  SELECT
    d.local_hour,
    d.journey_starts,

    -- Extract hour of day for later comparisons
    EXTRACT(HOUR FROM d.local_hour) AS hour,

    -- Create a readable weekday/weekend category
    CASE
      WHEN EXTRACT(DAYOFWEEK FROM d.local_hour) IN (1, 7)
        THEN 'Weekend'
      ELSE 'Weekday'
    END AS day_type,

    w.temperature_c,
    w.precipitation_mm,
    w.wind_speed_kmh,
    w.weather_code

  FROM
    hourly_demand AS d

  -- INNER JOIN automatically excludes the ambiguous DST hour
  INNER JOIN
    `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.weather_hourly_clean` AS w

  ON
    d.local_hour = w.local_hour
),

-- Step 3: Calculate normal demand for each hour/day-type combination
demand_baseline AS (
  SELECT
    day_type,
    hour,

    -- Baseline used for the normalized demand index
    AVG(journey_starts) AS baseline_journey_starts

  FROM
    demand_weather

  GROUP BY
    day_type,
    hour
),

-- Step 4: Calculate the matched dry-weather baseline
dry_baseline AS (
  SELECT
    day_type,
    hour,

    -- Typical demand when precipitation is zero
    AVG(journey_starts) AS expected_dry_journey_starts

  FROM
    demand_weather

  WHERE
    precipitation_mm = 0

  GROUP BY
    day_type,
    hour
)

-- Step 5: Produce the final dashboard-ready hourly dataset
SELECT
  dw.local_hour,
  dw.day_type,
  dw.hour,
  dw.journey_starts,

  dw.temperature_c,
  dw.precipitation_mm,
  dw.wind_speed_kmh,
  dw.weather_code,

  -- Flag whether any precipitation occurred
  CASE
    WHEN dw.precipitation_mm > 0 THEN TRUE
    ELSE FALSE
  END AS is_wet,

  -- Use the same data-driven rain groups as the Python analysis
  CASE
    WHEN dw.precipitation_mm = 0 THEN 'Dry'
    WHEN dw.precipitation_mm <= 0.2 THEN 'Low'
    WHEN dw.precipitation_mm <= 1.5 THEN 'Medium'
    ELSE 'High'
  END AS precipitation_group,

  db.baseline_journey_starts,

  -- Express demand relative to normal demand for that hour/day type
  100 * SAFE_DIVIDE(
    dw.journey_starts,
    db.baseline_journey_starts
  ) AS demand_index_pct,

  dry.expected_dry_journey_starts,

  -- Compare each hour with typical dry demand for the same hour/day type
  100 * SAFE_DIVIDE(
    dw.journey_starts - dry.expected_dry_journey_starts,
    dry.expected_dry_journey_starts
  ) AS difference_from_dry_pct

FROM
  demand_weather AS dw

INNER JOIN
  demand_baseline AS db
ON
  dw.day_type = db.day_type
  AND dw.hour = db.hour

LEFT JOIN
  dry_baseline AS dry
ON
  dw.day_type = dry.day_type
  AND dw.hour = dry.hour;



-- Confirm the weather dashboard view has the expected number of hourly rows
SELECT
  COUNT(*) AS rows1,
  COUNT(DISTINCT local_hour) AS unique_hours,
  MIN(local_hour) AS first_hour,
  MAX(local_hour) AS last_hour,

  -- Check whether any hourly rows lack a dry baseline
  COUNTIF(expected_dry_journey_starts IS NULL) AS missing_dry_baselines

FROM
  `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.dashboard_weather_demand`;



-- Reproduce the controlled wet-vs-dry result from the dashboard dataset
SELECT
  COUNT(*) AS wet_hours,

  SUM(journey_starts) AS actual_wet_starts,

  SUM(expected_dry_journey_starts) AS expected_dry_starts,

  100 * SAFE_DIVIDE(
    SUM(journey_starts) - SUM(expected_dry_journey_starts),
    SUM(expected_dry_journey_starts)
  ) AS wet_vs_dry_difference_pct

FROM
  `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.dashboard_weather_demand`

WHERE
  is_wet = TRUE;