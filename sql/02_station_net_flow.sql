-- SQL TASK 2
-- Step 1: Count how many journeys departed from each station
WITH departures AS (
  SELECT
    start_station_id AS station_id,
    start_station_name AS station_name,
    COUNT(*) AS departures
  FROM
    `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.journeys_clean`
  GROUP BY
    start_station_id,
    start_station_name
),

-- Step 2: Count how many journeys arrived at each station
arrivals AS (
  SELECT
    end_station_id AS station_id,
    end_station_name AS station_name,
    COUNT(*) AS arrivals
  FROM
    `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.journeys_clean`
  GROUP BY
    end_station_id,
    end_station_name
),

-- Step 3: Combine departure and arrival totals for every station
station_flow AS (
  SELECT
    COALESCE(d.station_id, a.station_id) AS station_id,
    COALESCE(d.station_name, a.station_name) AS station_name,
    COALESCE(d.departures, 0) AS departures,
    COALESCE(a.arrivals, 0) AS arrivals
  FROM
    departures AS d
  FULL OUTER JOIN
    arrivals AS a
  ON
    d.station_id = a.station_id
)

-- Step 4: Calculate each station's net customer flow
SELECT
  station_id,
  station_name,
  departures,
  arrivals,

  -- Positive = net accumulation; negative = net depletion
  arrivals - departures AS net_flow

FROM
  station_flow

ORDER BY
  net_flow ASC;