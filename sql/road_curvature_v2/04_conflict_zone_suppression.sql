-- Curvature v2: suppress curvature contributions within 30m of conflict points.
-- Inspired by roadcurvature.com "Avoiding congestion and conflict zones" (30m both directions).
-- https://roadcurvature.com/

TRUNCATE rs_curvature_conflict_points;

WITH derived_intersections AS (
    -- Any node used by >=2 distinct ways is treated as an intersection conflict point.
    SELECT
        node_id
    FROM rs_curvature_way_vertices
    GROUP BY node_id
    HAVING COUNT(DISTINCT way_id) >= 2
),
conflict_nodes_union AS (
    -- Tagged conflict nodes from OSM (traffic controls, etc.)
    SELECT
        c.osm_id AS node_id,
        'tagged'::text AS conflict_source,
        c.conflict_type AS conflict_type
    FROM rs_conflict_nodes AS c
    UNION
    -- Derived intersection nodes (topology-based)
    SELECT
        d.node_id,
        'derived_intersection'::text AS conflict_source,
        NULL::text AS conflict_type
    FROM derived_intersections AS d
),
conflicts_on_ways AS (
    -- Map conflict nodes onto each way (only if the way actually contains that node)
    SELECT
        v.way_id,
        v.node_id,
        v.seq,
        m.cum_m,
        u.conflict_source,
        u.conflict_type
    FROM conflict_nodes_union AS u
    JOIN rs_curvature_way_vertices AS v ON v.node_id = u.node_id
    JOIN rs_curvature_vertex_metrics AS m
        ON m.way_id = v.way_id AND m.node_id = v.node_id AND m.seq = v.seq
)
INSERT INTO rs_curvature_conflict_points (way_id, node_id, seq, cum_m, conflict_source, conflict_type)
SELECT way_id, node_id, seq, cum_m, conflict_source, conflict_type
FROM conflicts_on_ways;

-- Index for suppression lookup
CREATE INDEX IF NOT EXISTS idx_rs_curvature_conflict_points_way_cum
ON rs_curvature_conflict_points (way_id, cum_m);

-- Mark vertices suppressed if within 30m along-the-way distance of any conflict point.
UPDATE rs_curvature_vertex_metrics AS m
SET suppressed = TRUE
WHERE EXISTS (
    SELECT 1
    FROM rs_curvature_conflict_points AS c
    WHERE c.way_id = m.way_id
      AND c.cum_m IS NOT NULL
      AND m.cum_m IS NOT NULL
      AND abs(m.cum_m - c.cum_m) <= 30.0
);


