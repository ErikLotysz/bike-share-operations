-- Dashboard 4
-- Create one dashboard row containing the main KPI values
CREATE OR REPLACE VIEW
  `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.dashboard_kpis`
AS

-- Step 1: Calculate total journeys for each calendar date
WITH daily_demand AS (
  SELECT
    DATE(start_datetime) AS journey_date,

    -- Flag each date as weekday or weekend
    CASE
      WHEN EXTRACT(DAYOFWEEK FROM start_datetime) IN (1, 7)
        THEN 'Weekend'
      ELSE 'Weekday'
    END AS day_type,

    -- Count all journeys starting on that date
    COUNT(*) AS journey_starts

  FROM
    `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.journeys_clean`

  GROUP BY
    journey_date,
    day_type
)

-- Step 2: Produce a single row with the dashboard KPIs
SELECT

  -- Total journeys across all 31 October dates
  SUM(journey_starts) AS total_journeys,

  -- Average total journeys on a weekday
  AVG(
    CASE
      WHEN day_type = 'Weekday' THEN journey_starts
    END
  ) AS avg_weekday_journeys_per_day,

  -- Average total journeys on a weekend day
  AVG(
    CASE
      WHEN day_type = 'Weekend' THEN journey_starts
    END
  ) AS avg_weekend_journeys_per_day

FROM
  daily_demand;


-- Check that the KPI view reproduces our Python results
SELECT *
FROM
  `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.dashboard_kpis`;