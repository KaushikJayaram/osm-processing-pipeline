-- Finalize Classification
-- Param: :hill_signal_threshold

UPDATE osm_all_roads
SET road_scenery_hill = 1
WHERE hill_signal_smoothed > :hill_signal_threshold
  AND road_scenery_urban = 0
  AND road_scenery_semiurban = 0
  AND geometry && ST_MakeEnvelope(:lon_min, :lat_min, :lon_max, :lat_max, 4326);

-- Reset to 0 if below threshold (optional, to clean up re-runs)
UPDATE osm_all_roads
SET road_scenery_hill = 0
WHERE hill_signal_smoothed <= :hill_signal_threshold
  AND road_scenery_urban = 0
  AND road_scenery_semiurban = 0
  AND geometry && ST_MakeEnvelope(:lon_min, :lat_min, :lon_max, :lat_max, 4326);
