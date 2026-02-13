-- Finalize Classification (relief-only)
-- Param: :hill_relief_threshold

UPDATE osm_all_roads
SET road_scenery_hill = CASE
    WHEN hill_relief_1km > :hill_relief_threshold THEN 1
    ELSE 0
END
WHERE bikable_road = TRUE
  AND geometry && ST_MakeEnvelope(:lon_min, :lat_min, :lon_max, :lat_max, 4326);
