-- Road Intersection Density: Aggregate intersection scores per way
-- Weight intersection scores by:
-- 1. The road's own hierarchy (higher hierarchy = higher multiplier)
-- 2. Urban/rural setting (Urban > SemiUrban > Rural)
-- 3. Divide intersection score by number of roads at intersection (prevents double-counting)
--
-- Example: Road 1 - Road 2 - Road 3
--   Node 1-2: score 1.0, 2 roads → each gets 0.5
--   Node 2-3: score 1.0, 2 roads → each gets 0.5
--   Road 2 total: 0.5 + 0.5 = 1.0 (fair, not double-counted)

WITH intersection_node_counts AS (
    -- Count how many roads meet at each intersection node
    SELECT 
        node_id,
        COUNT(DISTINCT way_id) AS road_count
    FROM rs_highway_way_nodes
    WHERE way_id IN (SELECT osm_id FROM osm_all_roads WHERE bikable_road = TRUE)
    GROUP BY node_id
    HAVING COUNT(DISTINCT way_id) >= 2
)
INSERT INTO temp_way_intersection_scores (way_id, total_intersection_score)
SELECT 
    w.way_id,
    COALESCE(SUM(
        s.intersection_score / NULLIF(c.road_count, 0)  -- Divide by number of roads at intersection
        * CASE 
            -- Road hierarchy multiplier (based on the road itself)
            WHEN o.road_type_i1 = 'NH' THEN 1.5
            WHEN o.road_type_i1 = 'SH' THEN 1.3
            WHEN o.road_type_i1 = 'MDR' THEN 1.2
            WHEN o.road_type_i1 = 'OH' THEN 1.1
            WHEN o.road_type_i1 = 'HAdj' THEN 1.0
            WHEN o.road_type_i1 = 'WoH' THEN 0.9
            WHEN o.road_type_i1 = 'Track' THEN 0.8
            WHEN o.road_type_i1 = 'Path' THEN 0.7
            ELSE 1.0
        END
        * CASE 
            -- Urban/rural setting multiplier (updated: Urban=1.5, SemiUrban=1.1, Rural=1.0)
            WHEN o.road_setting_i1 = 'Urban' THEN 1.5
            WHEN o.road_setting_i1 = 'SemiUrban' THEN 1.1
            WHEN o.road_setting_i1 = 'Rural' THEN 1.0
            ELSE 1.0  -- Default for NULL or unknown settings
        END
    ), 0.0) AS total_intersection_score
FROM rs_highway_way_nodes w
JOIN temp_intersection_node_scores s ON w.node_id = s.node_id
JOIN intersection_node_counts c ON w.node_id = c.node_id
JOIN osm_all_roads o ON w.way_id = o.osm_id
WHERE w.way_id IN (SELECT osm_id FROM osm_all_roads WHERE bikable_road = TRUE)
GROUP BY w.way_id;

