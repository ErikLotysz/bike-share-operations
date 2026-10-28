— SQL TASK 3
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

  -- Keep Monday-Friday journeys based on journey start date
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

-- Step 3: Count departures for each station and hour
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

-- Step 4: Count arrivals for each station and hour
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

-- Step 5: Combine departures and arrivals
hourly_station_flow AS (
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
),

-- Step 6: Convert monthly weekday totals into average flow per weekday
average_hourly_flow AS (
  SELECT
    station_id,
    station_name,
    hour,
    departures,
    arrivals,

    -- Positive = net accumulation; negative = net depletion
    SAFE_DIVIDE(
      arrivals - departures,
      number_of_weekdays
    ) AS avg_net_flow_per_weekday

  FROM
    hourly_station_flow
  CROSS JOIN
    weekday_count
),

-- Step 7: Rank each station's hours by absolute net-flow pressure
ranked_pressure AS (
  SELECT
    station_id,
    station_name,
    hour,
    avg_net_flow_per_weekday,

    -- Measure pressure regardless of whether flow is positive or negative
    ABS(avg_net_flow_per_weekday) AS abs_avg_net_flow,

    -- Rank hours separately within each station
    ROW_NUMBER() OVER (
      PARTITION BY station_id
      ORDER BY ABS(avg_net_flow_per_weekday) DESC
    ) AS pressure_rank

  FROM
    average_hourly_flow
)

-- Step 8: Keep only the highest-pressure hour for each station
SELECT
  station_id,
  station_name,
  hour,
  avg_net_flow_per_weekday,
  abs_avg_net_flow

FROM
  ranked_pressure

WHERE
  pressure_rank = 1

ORDER BY
  abs_avg_net_flow DESC;