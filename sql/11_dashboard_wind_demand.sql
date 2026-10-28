-- Dashboard 6
-- Create a wind-analysis view without the station hour field
CREATE OR REPLACE VIEW
  `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.dashboard_wind_demand`
AS

SELECT
  local_hour,
  wind_speed_kmh,
  demand_index_pct,
  precipitation_mm

FROM
  `project-e4f7da88-ace4-4df1-9bc.bike_share_ops.dashboard_weather_demand`;