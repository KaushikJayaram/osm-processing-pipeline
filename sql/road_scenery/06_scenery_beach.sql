-- Assign road_scenery_beach
-- APPROACH 4 (HYBRID): Feature-centric with progressive filtering
-- Iterates through coastlines, marks nearby roads, excludes already-marked roads
-- This avoids duplicate processing when roads are near multiple coastline segments
-- 100 meters ≈ 0.001 degrees (approximate)
-- 
-- IMPORTANT: Reset road_scenery_beach = 0 before running this query
UPDATE osm_all_roads r
SET road_scenery_beach = 1
FROM rs_coastline c
WHERE ST_DWithin(r.geometry, c.geometry, 0.001)  -- ~100 meters in degrees
AND r.road_scenery_urban = 0 
AND r.road_scenery_semiurban = 0
AND r.road_scenery_beach = 0;  -- Progressive filter: exclude already-marked roads
