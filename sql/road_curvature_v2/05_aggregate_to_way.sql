-- Curvature v2: aggregate per-vertex curvature into per-way metrics.

-- VALIDATION: Check that vertex metrics have distance data
DO $$
DECLARE
    total_rows BIGINT;
    null_dist_count BIGINT;
    zero_length_ways BIGINT;
    null_dist_pct NUMERIC;
BEGIN
    SELECT COUNT(*), COUNT(*) FILTER (WHERE dist_prev_m IS NULL)
    INTO total_rows, null_dist_count
    FROM rs_curvature_vertex_metrics;
    
    IF total_rows = 0 THEN
        RAISE EXCEPTION 'ERROR: rs_curvature_vertex_metrics table is empty. Run 02_compute_vertex_angles.sql first.';
    END IF;
    
    null_dist_pct := (null_dist_count::NUMERIC / NULLIF(total_rows, 0)::NUMERIC) * 100;
    
    IF null_dist_count = total_rows THEN
        RAISE EXCEPTION 'ERROR: All dist_prev_m values are NULL in rs_curvature_vertex_metrics (%s rows). Distance calculations failed. Check that geometries are valid in rs_curvature_way_vertices.', total_rows;
    ELSIF null_dist_pct > 50 THEN
        RAISE WARNING 'WARNING: %s%% of dist_prev_m values are NULL (%s of %s rows). Many ways will have zero length.', ROUND(null_dist_pct, 1)::TEXT, null_dist_count, total_rows;
    END IF;
    
    -- Check if any ways will have non-zero length
    SELECT COUNT(DISTINCT way_id)
    INTO zero_length_ways
    FROM rs_curvature_vertex_metrics
    WHERE dist_prev_m IS NOT NULL AND dist_prev_m > 0;
    
    IF zero_length_ways = 0 THEN
        RAISE EXCEPTION 'ERROR: No ways have positive distances. All ways will have zero length. Check geometry data in previous steps.';
    END IF;
    
    RAISE NOTICE 'Validation passed: %s rows in rs_curvature_vertex_metrics, %s%% have NULL dist_prev_m, %s ways have positive distances', total_rows, ROUND(null_dist_pct, 1)::TEXT, zero_length_ways;
END $$;

TRUNCATE rs_curvature_way_summary;

WITH totals AS (
    SELECT
        way_id,
        SUM(COALESCE(dist_prev_m, 0.0)) AS total_length_m
    FROM rs_curvature_vertex_metrics
    GROUP BY way_id
),
bucket_sums AS (
    SELECT
        way_id,
        SUM(CASE WHEN suppressed THEN 0.0 WHEN curvature_bucket = 'sharp' THEN contrib_m ELSE 0.0 END) AS meters_sharp,
        SUM(CASE WHEN suppressed THEN 0.0 WHEN curvature_bucket = 'broad' THEN contrib_m ELSE 0.0 END) AS meters_broad,
        SUM(CASE WHEN suppressed THEN 0.0 WHEN curvature_bucket = 'straight' THEN contrib_m ELSE 0.0 END) AS meters_straight
    FROM rs_curvature_vertex_metrics
    GROUP BY way_id
),
scored AS (
    SELECT
        t.way_id,
        t.total_length_m,
        COALESCE(b.meters_sharp, 0.0) AS meters_sharp,
        COALESCE(b.meters_broad, 0.0) AS meters_broad,
        COALESCE(b.meters_straight, 0.0) AS meters_straight,
        CASE
            WHEN t.total_length_m IS NULL OR t.total_length_m = 0 THEN NULL
            ELSE (COALESCE(b.meters_sharp, 0.0) + 0.5 * COALESCE(b.meters_broad, 0.0)) / t.total_length_m
        END AS twistiness_score
    FROM totals AS t
    LEFT JOIN bucket_sums AS b USING (way_id)
)
INSERT INTO rs_curvature_way_summary (
    way_id, total_length_m, meters_sharp, meters_broad, meters_straight, twistiness_score, twistiness_class
)
SELECT
    way_id,
    total_length_m,
    meters_sharp,
    meters_broad,
    meters_straight,
    twistiness_score,
    CASE
        WHEN twistiness_score IS NULL THEN NULL
        WHEN twistiness_score < 0.03 THEN 'straight'
        WHEN twistiness_score < 0.08 THEN 'broad'
        ELSE 'sharp'
    END AS twistiness_class
FROM scored;


