-- Dashboard 5
-- Create a dashboard-ready view for rain intensity and demand impact
CREATE OR REPLACE VIEW
  `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.dashboard_rain_intensity`
AS

-- Step 1: Aggregate journey starts to one row per local hour
WITH hourly_demand AS (
  SELECT
    DATETIME_TRUNC(start_datetime, HOUR) AS local_hour,
    COUNT(*) AS journey_starts
  FROM
    `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.journeys_clean`
  GROUP BY
    local_hour
),

-- Step 2: Join hourly journey demand to weather
demand_weather AS (
  SELECT
    d.local_hour,
    d.journey_starts,
    w.precipitation_mm,

    -- Extract hour for matched comparisons
    EXTRACT(HOUR FROM d.local_hour) AS hour,

    -- Classify each hour as weekday or weekend
    CASE
      WHEN EXTRACT(DAYOFWEEK FROM d.local_hour) IN (1, 7)
        THEN 'Weekend'
      ELSE 'Weekday'
    END AS day_type

  FROM
    hourly_demand AS d

  INNER JOIN
    `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.weather_hourly_clean` AS w
  ON
    d.local_hour = w.local_hour
),

-- Step 3: Calculate typical dry demand for each hour/day type
dry_baseline AS (
  SELECT
    day_type,
    hour,
    AVG(journey_starts) AS expected_dry_journey_starts
  FROM
    demand_weather
  WHERE
    precipitation_mm = 0
  GROUP BY
    day_type,
    hour
),

-- Step 4: Match wet hours with comparable dry conditions
wet_hours AS (
  SELECT
    dw.journey_starts,
    dw.precipitation_mm,
    db.expected_dry_journey_starts,

    -- Use the same data-driven precipitation groups as our analysis
    CASE
      WHEN dw.precipitation_mm <= 0.2 THEN 'Low'
      WHEN dw.precipitation_mm <= 1.5 THEN 'Medium'
      ELSE 'High'
    END AS precipitation_group

  FROM
    demand_weather AS dw

  INNER JOIN
    dry_baseline AS db
  ON
    dw.day_type = db.day_type
    AND dw.hour = db.hour

  WHERE
    dw.precipitation_mm > 0
)

-- Step 5: Produce one row per precipitation-intensity group
SELECT
  precipitation_group,
  COUNT(*) AS wet_hours,
  AVG(precipitation_mm) AS mean_precipitation_mm,

  -- Calculate demand difference against matched dry conditions
  100 * SAFE_DIVIDE(
    SUM(journey_starts) - SUM(expected_dry_journey_starts),
    SUM(expected_dry_journey_starts)
  ) AS demand_difference_pct

FROM
  wet_hours

GROUP BY
  precipitation_group;



-- Confirm the dashboard view matches the earlier rain analysis
SELECT *
FROM
  `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.dashboard_rain_intensity`;