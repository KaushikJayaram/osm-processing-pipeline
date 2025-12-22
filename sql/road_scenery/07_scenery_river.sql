-- Assign road_scenery_river
-- APPROACH 4 (HYBRID): Feature-centric with progressive filtering
-- Iterates through rivers, marks nearby roads, excludes already-marked roads
-- This avoids duplicate processing when roads are near multiple river segments
-- 50 meters ≈ 0.0005 degrees (approximate)
-- 
-- IMPORTANT: Reset road_scenery_river = 0 before running this query
UPDATE osm_all_roads r
SET road_scenery_river = 1
FROM rs_rivers riv
WHERE ST_DWithin(r.geometry, riv.geometry, 0.0005)  -- ~50 meters in degrees
AND r.road_scenery_urban = 0 
AND r.road_scenery_semiurban = 0
AND r.road_scenery_river = 0;  -- Progressive filter: exclude already-marked roads
