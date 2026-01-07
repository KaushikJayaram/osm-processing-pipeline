-- Road Intersection Density: Find intersections and score them
-- This finds all intersection nodes and scores them based on road hierarchy
--
-- Road hierarchy mapping (same as Python code):
-- NH=8, SH=7, MDR=6, OH=5, HAdj=4, WoH=3, Track=2, Path=1
--
-- Scoring logic:
-- High-High (NH-NH, NH-SH, SH-SH): 1.0
-- High-Mid (NH-MDR, SH-MDR, NH-OH, SH-OH): 0.7
-- High-Low (NH-WoH, etc.): 0.4
-- Mid-Mid (MDR-MDR, MDR-OH, OH-OH): 0.5
-- Mid-Low (MDR-WoH, etc.): 0.3
-- Low-Low (WoH-WoH, etc.): 0.2

WITH way_node_positions AS (
    -- For each way, find min and max seq to identify endpoints
    SELECT 
        way_id,
        MIN(seq) AS min_seq,
        MAX(seq) AS max_seq
    FROM rs_highway_way_nodes
    GROUP BY way_id
),
node_way_info AS (
    -- For each node-way combination, determine if node is endpoint or mid-node
    SELECT 
        w.node_id,
        w.way_id,
        w.seq,
        o.road_type_i1,
        CASE 
            WHEN w.seq = p.min_seq OR w.seq = p.max_seq THEN TRUE
            ELSE FALSE
        END AS is_endpoint
    FROM rs_highway_way_nodes w
    JOIN osm_all_roads o ON w.way_id = o.osm_id
    JOIN way_node_positions p ON w.way_id = p.way_id
    WHERE o.bikable_road = TRUE
      AND o.road_type_i1 IS NOT NULL
),
intersection_nodes AS (
    -- Find nodes shared by 2+ ways
    -- Filter out way splits: only count as intersection if:
    --   - 3+ roads meet (definitely an intersection), OR
    --   - 2 roads meet with DIFFERENT road types (true intersection), OR
    --   - 2 roads meet and at least one is a MID-NODE (crossing, not way split)
    SELECT 
        node_id
    FROM node_way_info
    GROUP BY node_id
    HAVING COUNT(DISTINCT way_id) >= 2
       AND (
           -- 3+ roads meeting = definitely an intersection
           COUNT(DISTINCT way_id) >= 3
           OR
           -- 2 roads meeting with different types = true intersection
           COUNT(DISTINCT road_type_i1) >= 2
           OR
           -- 2 roads meeting and at least one is a mid-node (crossing, not endpoint-to-endpoint)
           SUM(CASE WHEN is_endpoint = FALSE THEN 1 ELSE 0 END) >= 1
       )
),
node_way_hierarchies AS (
    -- Get road types and hierarchies for each intersection node
    SELECT 
        w.node_id,
        o.road_type_i1,
        CASE 
            WHEN o.road_type_i1 = 'NH' THEN 8
            WHEN o.road_type_i1 = 'SH' THEN 7
            WHEN o.road_type_i1 = 'MDR' THEN 6
            WHEN o.road_type_i1 = 'OH' THEN 5
            WHEN o.road_type_i1 = 'HAdj' THEN 4
            WHEN o.road_type_i1 = 'WoH' THEN 3
            WHEN o.road_type_i1 = 'Track' THEN 2
            WHEN o.road_type_i1 = 'Path' THEN 1
            ELSE 0
        END AS hierarchy
    FROM intersection_nodes n
    JOIN rs_highway_way_nodes w ON n.node_id = w.node_id
    JOIN osm_all_roads o ON w.way_id = o.osm_id
    WHERE o.bikable_road = TRUE
      AND o.road_type_i1 IS NOT NULL
      AND o.road_type_i1 IN ('NH', 'SH', 'MDR', 'OH', 'HAdj', 'WoH', 'Track', 'Path')
),
node_hierarchy_ranks AS (
    -- Get top 2 hierarchies for each node
    SELECT 
        node_id,
        hierarchy,
        ROW_NUMBER() OVER (PARTITION BY node_id ORDER BY hierarchy DESC) AS rank
    FROM node_way_hierarchies
),
node_top_hierarchies AS (
    -- Get max and second_max hierarchy for each node
    SELECT 
        node_id,
        MAX(CASE WHEN rank = 1 THEN hierarchy END) AS max_hierarchy,
        MAX(CASE WHEN rank = 2 THEN hierarchy END) AS second_max_hierarchy
    FROM node_hierarchy_ranks
    WHERE rank <= 2
    GROUP BY node_id
    HAVING COUNT(*) >= 2  -- Must have at least 2 ways
)
-- Score intersections based on hierarchy combination
INSERT INTO temp_intersection_node_scores (node_id, intersection_score)
SELECT 
    node_id,
    CASE
        -- High-High (NH-NH, NH-SH, SH-SH): 1.0
        WHEN max_hierarchy >= 7 AND second_max_hierarchy >= 7 THEN 1.0
        -- High-Mid (NH-MDR, SH-MDR, NH-OH, SH-OH): 0.7
        WHEN max_hierarchy >= 7 AND second_max_hierarchy >= 5 THEN 0.7
        -- High-Low (NH-WoH, etc.): 0.4
        WHEN max_hierarchy >= 7 THEN 0.4
        -- Mid-Mid (MDR-MDR, MDR-OH, OH-OH): 0.5
        WHEN max_hierarchy >= 5 AND second_max_hierarchy >= 5 THEN 0.5
        -- Mid-Low (MDR-WoH, etc.): 0.3
        WHEN max_hierarchy >= 5 THEN 0.3
        -- Low-Low (WoH-WoH, etc.): 0.2
        ELSE 0.2
    END AS intersection_score
FROM node_top_hierarchies;

