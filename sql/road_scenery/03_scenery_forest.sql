-- Assign road_scenery_forest
-- APPROACH 4 (HYBRID): Feature-centric with progressive filtering
-- Iterates through forests, marks intersecting roads, excludes already-marked roads
-- This avoids duplicate processing when roads intersect multiple forests
-- 
-- IMPORTANT: Reset road_scenery_forest = 0 before running this query
UPDATE osm_all_roads r
SET road_scenery_forest = 1
FROM rs_forest f
WHERE ST_Intersects(r.geometry, f.geometry)
AND r.road_scenery_urban = 0 
AND r.road_scenery_semiurban = 0
AND r.road_scenery_forest = 0;  -- Progressive filter: exclude already-marked roads