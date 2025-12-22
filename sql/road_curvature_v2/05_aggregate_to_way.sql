-- Curvature v2: aggregate per-vertex curvature into per-way metrics.

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


