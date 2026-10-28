-- Dashboard
-- Create a reusable view for average hourly demand by day type
CREATE OR REPLACE VIEW
  `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.dashboard_hourly_demand`
AS

-- First calculate journey starts for each individual date and hour
WITH daily_hourly_demand AS (
  SELECT
    DATE(start_datetime) AS journey_date,

    -- Extract the local start hour
    EXTRACT(HOUR FROM start_datetime) AS start_hour,

    -- Classify each date as weekday or weekend
    CASE
      WHEN EXTRACT(DAYOFWEEK FROM start_datetime) IN (1, 7)
        THEN 'Weekend'
      ELSE 'Weekday'
    END AS day_type,

    -- Count journeys starting during each date/hour combination
    COUNT(*) AS journey_starts

  FROM
    `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.journeys_clean`

  GROUP BY
    journey_date,
    start_hour,
    day_type
)

-- Average the daily hourly counts by weekday/weekend
SELECT
  day_type,
  start_hour,
  AVG(journey_starts) AS avg_journey_starts_per_day

FROM
  daily_hourly_demand

GROUP BY
  day_type,
  start_hour;




-- Confirm the dashboard view contains 24 hours for both day types
SELECT
  day_type,
  COUNT(*) AS rows,
  MIN(start_hour) AS first_hour,
  MAX(start_hour) AS last_hour

FROM
  `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.dashboard_hourly_demand`

GROUP BY
  day_type;