-- Assign road_scenery_lake
-- APPROACH 4 (HYBRID): Feature-centric with progressive filtering
-- Iterates through lakes (285k), marks nearby roads, excludes already-marked roads
-- This combines the efficiency of feature-centric iteration with elimination of duplicate work
-- NOTE: SRID 4326 distance is in degrees; this is an approximation (varies by latitude)
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
WHERE ST_DWithin(r.geometry, l.geometry, 0.00025)  -- ~25 meters in degrees
AND r.bikable_road IS TRUE
AND lower(l."water") IN ('reservoir', 'lake', 'oxbow', 'pond')
AND r.road_scenery_urban = 0 
AND r.road_scenery_lake = 0;  -- Progressive filter: exclude already-marked roads
