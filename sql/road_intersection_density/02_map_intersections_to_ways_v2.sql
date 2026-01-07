-- Road Intersection Speed Degradation: Map intersections to ways with impact parameters (v2)
-- 
-- Impact Parameters (using alternate_1 values):
-- - Major intersection: 75% speed reduction for 50m
-- - Middling intersection: 50% speed reduction for 25m
-- - Minor intersection: 25% speed reduction for 10m (Urban settings only)
--   - In SemiUrban and Rural, minor intersections have no impact (0% speed reduction)

DROP TABLE IF EXISTS temp_way_intersections_v2;
CREATE TEMP TABLE temp_way_intersections_v2 (
    way_id BIGINT,
    node_id BIGINT,
    intersection_type TEXT,
    impact_distance_m DOUBLE PRECISION,
    speed_reduction DOUBLE PRECISION,
    PRIMARY KEY (way_id, node_id)
);

INSERT INTO temp_way_intersections_v2 
    (way_id, node_id, intersection_type, impact_distance_m, speed_reduction)
SELECT DISTINCT ON (w.way_id, n.node_id)
    w.way_id,
    n.node_id,
    n.intersection_type,
    CASE 
        WHEN n.intersection_type = 'major' THEN 50.0
        WHEN n.intersection_type = 'middling' THEN 25.0
        WHEN n.intersection_type = 'minor' AND o.road_setting_i1 = 'Urban' THEN 10.0
        ELSE 0.0
    END AS impact_distance_m,
    CASE 
        WHEN n.intersection_type = 'major' THEN 0.75
        WHEN n.intersection_type = 'middling' THEN 0.5
        WHEN n.intersection_type = 'minor' AND o.road_setting_i1 = 'Urban' THEN 0.25
        ELSE 0.0
    END AS speed_reduction
FROM temp_intersection_nodes_v2 n
JOIN rs_highway_way_nodes w ON n.node_id = w.node_id
JOIN osm_all_roads o ON w.way_id = o.osm_id
WHERE o.bikable_road = TRUE
  AND n.intersection_type IN ('major', 'middling', 'minor')
  -- TEST BBOX FILTER: Commented out to process all of India
  -- AND ST_Intersects(o.geometry, ST_SetSRID(ST_MakeEnvelope(76.0, 12.0, 78.0, 14.0, 4326), 4326))
ORDER BY w.way_id, n.node_id;

