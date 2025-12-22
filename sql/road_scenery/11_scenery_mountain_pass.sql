-- Assign road_scenery_mountain_pass
-- APPROACH 4 (HYBRID): Feature-centric with progressive filtering
-- Iterates through mountain passes, marks nearby roads, excludes already-marked roads
-- This avoids duplicate processing when roads are near multiple mountain passes
-- 10000 meters (10 km) ≈ 0.09 degrees (approximate)
-- 
-- IMPORTANT: Reset road_scenery_mountainpass = 0 before running this query
UPDATE osm_all_roads r
SET road_scenery_mountainpass = 1
FROM rs_mountain_pass mp
WHERE ST_DWithin(r.geometry, mp.geometry, 0.09)  -- ~10000 meters (10 km) in degrees
AND r.road_scenery_urban = 0 
AND r.road_scenery_semiurban = 0
AND r.road_scenery_mountainpass = 0;  -- Progressive filter: exclude already-marked roads
