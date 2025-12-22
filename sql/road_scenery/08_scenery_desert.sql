-- Assign road_scenery_desert
-- APPROACH 4 (HYBRID): Feature-centric with progressive filtering
-- Iterates through deserts, marks intersecting roads, excludes already-marked roads
-- This avoids duplicate processing when roads intersect multiple desert areas
-- 
-- IMPORTANT: Reset road_scenery_desert = 0 before running this query
UPDATE osm_all_roads r
SET road_scenery_desert = 1
FROM rs_desert d
WHERE ST_Intersects(r.geometry, d.geometry)
AND r.road_scenery_urban = 0 
AND r.road_scenery_semiurban = 0
AND r.road_scenery_desert = 0;  -- Progressive filter: exclude already-marked roads
