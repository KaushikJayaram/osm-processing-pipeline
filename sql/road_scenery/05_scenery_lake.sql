-- Assign road_scenery_lake
-- APPROACH 4 (HYBRID): Feature-centric with progressive filtering
-- Iterates through lakes (285k), marks nearby roads, excludes already-marked roads
-- This combines the efficiency of feature-centric iteration with elimination of duplicate work
-- 100 meters ≈ 0.001 degrees (approximate, varies slightly by latitude in India)
-- 
-- Performance benefits:
-- - Fewer outer iterations (285k lakes vs 4M roads)
-- - No duplicate processing (each road processed once)
-- - Progressive optimization (fewer roads to check as more are marked)
-- 
-- IMPORTANT: Reset road_scenery_lake = 0 before running this query
UPDATE osm_all_roads r
SET road_scenery_lake = 1
FROM rs_lakes l
WHERE ST_DWithin(r.geometry, l.geometry, 0.001)  -- ~100 meters in degrees
AND r.road_scenery_urban = 0 
AND r.road_scenery_semiurban = 0
AND r.road_scenery_lake = 0;  -- Progressive filter: exclude already-marked roads
