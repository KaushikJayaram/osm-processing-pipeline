-- Assign road_scenery_field
-- APPROACH 4 (HYBRID): Feature-centric with progressive filtering
-- Iterates through fields, marks nearby roads, excludes already-marked roads
-- This avoids duplicate processing when roads are near multiple fields
-- 100 meters ≈ 0.001 degrees (approximate)
-- 
-- IMPORTANT: Reset road_scenery_field = 0 before running this query
UPDATE osm_all_roads r
SET road_scenery_field = 1
FROM rs_fields f
WHERE ST_DWithin(r.geometry, f.geometry, 0.001)  -- ~100 meters in degrees
AND r.road_scenery_urban = 0 
AND r.road_scenery_semiurban = 0
AND r.road_scenery_field = 0;  -- Progressive filter: exclude already-marked roads
