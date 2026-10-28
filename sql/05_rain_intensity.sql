-- SQL TASK 5
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

-- Step 2: Join hourly demand with hourly weather
demand_weather AS (
  SELECT
    d.local_hour,
    d.journey_starts,
    w.precipitation_mm,

    -- Extract hour of day for matched comparisons
    EXTRACT(HOUR FROM d.local_hour) AS start_hour,

    -- Flag Saturday and Sunday as weekend
    CASE
      WHEN EXTRACT(DAYOFWEEK FROM d.local_hour) IN (1, 7)
        THEN TRUE
      ELSE FALSE
    END AS is_weekend

  FROM
    hourly_demand AS d

  INNER JOIN
    `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.weather_hourly_clean` AS w
  ON
    d.local_hour = w.local_hour
),

-- Step 3: Calculate typical dry demand for each hour/day-type combination
dry_baseline AS (
  SELECT
    is_weekend,
    start_hour,
    AVG(journey_starts) AS expected_dry_journey_starts
  FROM
    demand_weather
  WHERE
    precipitation_mm = 0
  GROUP BY
    is_weekend,
    start_hour
),

-- Step 4: Match wet hours to their comparable dry baseline
wet_hours AS (
  SELECT
    dw.local_hour,
    dw.journey_starts,
    dw.precipitation_mm,
    db.expected_dry_journey_starts,

    -- Reproduce the same precipitation groups used in Python
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
    dw.is_weekend = db.is_weekend
    AND dw.start_hour = db.start_hour

  WHERE
    dw.precipitation_mm > 0
)

-- Step 5: Compare actual and expected demand by precipitation intensity
SELECT
  precipitation_group,

  COUNT(*) AS wet_hours,

  AVG(precipitation_mm) AS mean_precipitation_mm,

  SUM(journey_starts) AS actual_starts,

  SUM(expected_dry_journey_starts) AS expected_dry_starts,

  -- Calculate demand difference from comparable dry conditions
  100 * SAFE_DIVIDE(
    SUM(journey_starts)
      - SUM(expected_dry_journey_starts),
    SUM(expected_dry_journey_starts)
  ) AS difference_pct

FROM
  wet_hours

GROUP BY
  precipitation_group

-- Keep the intensity groups in logical order
ORDER BY
  CASE precipitation_group
    WHEN 'Low' THEN 1
    WHEN 'Medium' THEN 2
    WHEN 'High' THEN 3
  END;