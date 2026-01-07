-- Road Intersection Speed Degradation: Find and categorize intersections (v2 - New Approach)
-- This finds all intersection nodes and categorizes them as Major, Middling, or Minor
--
-- Road Type Sets:
-- - Set A: NH, SH, MDR, OH
-- - Set B: HAdj, WoH, Path, Track
--
-- Intersection Types (based on 2 highest hierarchy roads):
-- - Major: Both roads in Set A
-- - Middling: One road in Set A, one in Set B
-- - Minor: Both roads in Set B
--
-- Uses same filtering logic to exclude way splits (3+ roads, different types, or mid-node crossings)

-- Create temp table to store intersection nodes with categorization
DROP TABLE IF EXISTS temp_intersection_nodes_v2;
CREATE TEMP TABLE temp_intersection_nodes_v2 (
    node_id BIGINT PRIMARY KEY,
    intersection_type TEXT,  -- 'major', 'middling', 'minor'
    top_road_type_1 TEXT,
    top_road_type_2 TEXT
);

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
      -- TEST BBOX FILTER: Commented out to process all of India
      -- AND ST_Intersects(o.geometry, ST_SetSRID(ST_MakeEnvelope(76.0, 12.0, 78.0, 14.0, 4326), 4326))
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
      -- TEST BBOX FILTER: Commented out to process all of India
      -- AND ST_Intersects(o.geometry, ST_SetSRID(ST_MakeEnvelope(76.0, 12.0, 78.0, 14.0, 4326), 4326))
),
node_hierarchy_ranks AS (
    -- Get top 2 hierarchies for each node
    SELECT 
        node_id,
        road_type_i1,
        hierarchy,
        ROW_NUMBER() OVER (PARTITION BY node_id ORDER BY hierarchy DESC) AS rank
    FROM node_way_hierarchies
),
node_top_types AS (
    -- Get top 2 road types for each node
    SELECT 
        node_id,
        MAX(CASE WHEN rank = 1 THEN road_type_i1 END) AS top_type_1,
        MAX(CASE WHEN rank = 2 THEN road_type_i1 END) AS top_type_2
    FROM node_hierarchy_ranks
    WHERE rank <= 2
    GROUP BY node_id
    HAVING COUNT(*) >= 2  -- Must have at least 2 ways
)
-- Categorize intersections based on road type sets
INSERT INTO temp_intersection_nodes_v2 (node_id, intersection_type, top_road_type_1, top_road_type_2)
SELECT 
    node_id,
    CASE 
        -- Major: Both roads in Set A (NH, SH, MDR, OH)
        WHEN top_type_1 IN ('NH', 'SH', 'MDR', 'OH') 
         AND top_type_2 IN ('NH', 'SH', 'MDR', 'OH') THEN 'major'
        -- Middling: One road in Set A, one in Set B
        WHEN top_type_1 IN ('NH', 'SH', 'MDR', 'OH') 
         AND top_type_2 IN ('HAdj', 'WoH', 'Path', 'Track') THEN 'middling'
        -- Minor: Both roads in Set B (HAdj, WoH, Path, Track)
        WHEN top_type_1 IN ('HAdj', 'WoH', 'Path', 'Track') 
         AND top_type_2 IN ('HAdj', 'WoH', 'Path', 'Track') THEN 'minor'
        ELSE 'unknown'
    END AS intersection_type,
    top_type_1,
    top_type_2
FROM node_top_types
WHERE top_type_1 IS NOT NULL AND top_type_2 IS NOT NULL
  AND (
      -- Major
      (top_type_1 IN ('NH', 'SH', 'MDR', 'OH') AND top_type_2 IN ('NH', 'SH', 'MDR', 'OH'))
      OR
      -- Middling
      (top_type_1 IN ('NH', 'SH', 'MDR', 'OH') AND top_type_2 IN ('HAdj', 'WoH', 'Path', 'Track'))
      OR
      -- Minor
      (top_type_1 IN ('HAdj', 'WoH', 'Path', 'Track') AND top_type_2 IN ('HAdj', 'WoH', 'Path', 'Track'))
  );

