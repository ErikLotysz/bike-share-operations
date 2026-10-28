-- SQL TASK 1
-- Step 1: Count journey starts for each calendar date and hour
WITH daily_hourly_demand AS (
  SELECT
    DATE(start_datetime) AS journey_date,

    -- Extract the hour from the local journey start time
    EXTRACT(HOUR FROM start_datetime) AS start_hour,

    -- Flag Saturday and Sunday as weekend days
    CASE
      WHEN EXTRACT(DAYOFWEEK FROM start_datetime) IN (1, 7)
        THEN TRUE
      ELSE FALSE
    END AS is_weekend,

    -- Count journey starts in that date/hour combination
    COUNT(*) AS journey_starts

  FROM
    `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.journeys_clean`

  GROUP BY
    journey_date,
    start_hour,
    is_weekend
)

-- Step 2: Average each hourly count across weekdays or weekends
SELECT
  is_weekend,
  start_hour,
  AVG(journey_starts) AS avg_journey_starts_per_day

FROM
  daily_hourly_demand

GROUP BY
  is_weekend,
  start_hour

ORDER BY
  is_weekend,
  start_hour;