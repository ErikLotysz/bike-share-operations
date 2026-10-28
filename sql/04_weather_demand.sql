-- SQL TASK 4
-- Step 1: Aggregate bike journeys to one row per local clock hour
WITH hourly_demand AS (
  SELECT
    DATETIME_TRUNC(start_datetime, HOUR) AS local_hour,
    COUNT(*) AS journey_starts

  FROM
    `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.journeys_clean`

  GROUP BY
    local_hour
),

-- Step 2: Join hourly bike demand to hourly weather
demand_weather AS (
  SELECT
    d.local_hour,
    d.journey_starts,
    w.temperature_c,
    w.precipitation_mm,
    w.wind_speed_kmh,
    w.weather_code,

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

-- Step 3: Calculate average dry demand for each hour/day-type combination
dry_baseline AS (
  SELECT
    is_weekend,
    start_hour,

    -- Typical demand under dry conditions
    AVG(journey_starts) AS expected_dry_journey_starts

  FROM
    demand_weather

  WHERE
    precipitation_mm = 0

  GROUP BY
    is_weekend,
    start_hour
),

-- Step 4: Match each wet hour with its corresponding dry baseline
wet_hours AS (
  SELECT
    dw.local_hour,
    dw.journey_starts,
    dw.precipitation_mm,
    dw.is_weekend,
    dw.start_hour,
    db.expected_dry_journey_starts

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

-- Step 5: Compare actual wet-hour demand with matched dry expectations
SELECT
  COUNT(*) AS comparable_wet_hours,

  SUM(journey_starts) AS actual_wet_starts,

  SUM(expected_dry_journey_starts) AS expected_dry_starts,

  -- Calculate demand difference relative to matched dry conditions
  100 * SAFE_DIVIDE(
    SUM(journey_starts)
      - SUM(expected_dry_journey_starts),
    SUM(expected_dry_journey_starts)
  ) AS wet_vs_dry_difference_pct

FROM
  wet_hours;