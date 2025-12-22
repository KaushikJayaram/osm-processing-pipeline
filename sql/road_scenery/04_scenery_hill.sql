-- Assign road_scenery_hill
-- APPROACH 4 (HYBRID): Feature-centric with progressive filtering
-- Handles both hill nodes (distance-based) and hill relations (intersection-based)
-- 3000 meters ≈ 0.027 degrees (approximate)
-- 
-- IMPORTANT: Reset road_scenery_hill = 0 before running this query
UPDATE osm_all_roads r
SET road_scenery_hill = 1
WHERE r.road_scenery_urban = 0 
AND r.road_scenery_semiurban = 0 
AND r.road_scenery_hill = 0  -- Progressive filter: exclude already-marked roads
AND (
    -- Feature-centric: iterate through hill nodes (distance-based)
    EXISTS (
        SELECT 1 
        FROM rs_hills_nodes hn 
        WHERE ST_DWithin(r.geometry, hn.geometry, 0.027)  -- ~3000 meters in degrees
    )
    OR
    -- Feature-centric: iterate through hill relations (intersection-based)
    EXISTS (
        SELECT 1 
        FROM rs_hills_relations hr 
        WHERE ST_Intersects(r.geometry, hr.geometry)
    )
);

