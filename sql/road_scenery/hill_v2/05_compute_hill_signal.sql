-- Compute Hill Signal Raw and Smoothed
-- Params: :smoothing_radius_deg

-- 1. Compute Raw Signal
UPDATE osm_all_roads
SET hill_signal_raw =
    COALESCE(hill_slope_mean, 0)
    + (COALESCE(NULLIF(hill_relief_1km, -9999), 0) / 20.0)
WHERE road_scenery_urban = 0 
  AND road_scenery_semiurban = 0
  AND geometry && ST_MakeEnvelope(:lon_min, :lat_min, :lon_max, :lat_max, 4326);

-- 2. Compute Smoothed Signal (Spatial Average)
-- Uses approximate degrees for index usage on 4326 geometry
WITH smoothed AS (
    SELECT 
        r1.ctid,
        AVG(r2.hill_signal_raw) as smooth_sig
    FROM osm_all_roads r1
    JOIN osm_all_roads r2 
      ON ST_DWithin(r1.geometry, r2.geometry, :smoothing_radius_deg)
    WHERE r1.road_scenery_urban = 0 
      AND r1.road_scenery_semiurban = 0
      AND r1.geometry && ST_MakeEnvelope(:lon_min, :lat_min, :lon_max, :lat_max, 4326)
      AND r2.road_scenery_urban = 0 
      AND r2.road_scenery_semiurban = 0
      AND r2.geometry && ST_MakeEnvelope(:lon_min, :lat_min, :lon_max, :lat_max, 4326)
    GROUP BY r1.ctid
)
UPDATE osm_all_roads r
SET hill_signal_smoothed = s.smooth_sig
FROM smoothed s
WHERE r.ctid = s.ctid;
