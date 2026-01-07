-- Curvature v2: compute per-vertex turning geometry + radius proxy.
-- Uses ordered way nodes from rs_curvature_way_vertices.

-- VALIDATION: Quick check that vertices table has geometry data
-- Uses sampling to avoid expensive full table scans on large datasets
DO $$
DECLARE
    has_data BOOLEAN;
    has_geoms BOOLEAN;
    sample_null_count BIGINT;
    sample_total BIGINT;
BEGIN
    -- Quick existence check (uses index if available, very fast)
    SELECT EXISTS(SELECT 1 FROM rs_curvature_way_vertices LIMIT 1) INTO has_data;
    
    IF NOT has_data THEN
        RAISE EXCEPTION 'ERROR: rs_curvature_way_vertices table is empty. Run 01_prepare_inputs.sql first.';
    END IF;
    
    -- Quick check: do we have ANY non-null geometries? (uses index, very fast)
    SELECT EXISTS(
        SELECT 1 FROM rs_curvature_way_vertices 
        WHERE geom IS NOT NULL AND geom_3857 IS NOT NULL 
        LIMIT 1
    ) INTO has_geoms;
    
    IF NOT has_geoms THEN
        RAISE EXCEPTION 'ERROR: All geometries are NULL in rs_curvature_way_vertices. Cannot compute distances. Check that rs_highway_way_nodes has valid lon/lat coordinates.';
    END IF;
    
    -- Sample-based check: examine a random sample to estimate NULL percentage
    -- This is much faster than full table scan (typically < 1 second)
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE geom IS NULL OR geom_3857 IS NULL)
    INTO sample_total, sample_null_count
    FROM (
        SELECT geom, geom_3857 
        FROM rs_curvature_way_vertices 
        TABLESAMPLE SYSTEM (0.1)  -- Sample 0.1% of rows
        LIMIT 10000  -- Cap at 10k rows for speed
    ) sample;
    
    IF sample_total > 0 THEN
        DECLARE
            estimated_null_pct NUMERIC;
        BEGIN
            estimated_null_pct := (sample_null_count::NUMERIC / sample_total::NUMERIC) * 100;
            
            IF estimated_null_pct > 80 THEN
                RAISE WARNING 'WARNING: Sample suggests ~%s%% of geometries may be NULL. Results may be incomplete. Consider checking full table if needed.', ROUND(estimated_null_pct, 1)::TEXT;
            ELSE
                RAISE NOTICE 'Validation passed: Table has data with geometries. Sample suggests ~%s%% NULL geometries.', ROUND(estimated_null_pct, 1)::TEXT;
            END IF;
        END;
    ELSE
        RAISE NOTICE 'Validation passed: Table has data with geometries.';
    END IF;
END $$;

TRUNCATE rs_curvature_vertex_metrics;

WITH params AS (
    SELECT
        radians(5.0) AS min_turn_angle_rad,      -- below this, treat as straight
        150.0::double precision AS sharp_radius_m,
        500.0::double precision AS broad_radius_m
),
pts AS (
    SELECT
        way_id,
        node_id,
        seq,
        geom,
        geom_3857,
        LAG(geom) OVER w AS prev_geom,
        LAG(geom_3857) OVER w AS prev_geom_3857,
        LEAD(geom) OVER w AS next_geom,
        LEAD(geom_3857) OVER w AS next_geom_3857
    FROM rs_curvature_way_vertices
    WINDOW w AS (PARTITION BY way_id ORDER BY seq)
),
dists AS (
    SELECT
        way_id,
        node_id,
        seq,
        geom,
        geom_3857,
        prev_geom,
        prev_geom_3857,
        next_geom,
        next_geom_3857,
        CASE
            WHEN prev_geom_3857 IS NULL OR geom_3857 IS NULL THEN NULL
            -- Use geom_3857 (Web Mercator, SRID 3857): ST_Distance returns meters directly
            -- This is more accurate than 4326 conversion and still fast (geometry, not geography)
            ELSE ST_Distance(prev_geom_3857, geom_3857)
        END AS dist_prev_m,
        CASE
            WHEN next_geom_3857 IS NULL OR geom_3857 IS NULL THEN NULL
            ELSE ST_Distance(geom_3857, next_geom_3857)
        END AS dist_next_m,
        CASE
            WHEN prev_geom_3857 IS NULL OR next_geom_3857 IS NULL THEN NULL
            ELSE ST_Distance(prev_geom_3857, next_geom_3857)
        END AS dist_prev_next_m,
        CASE
            WHEN prev_geom_3857 IS NULL OR next_geom_3857 IS NULL OR geom_3857 IS NULL THEN NULL
            ELSE ST_Azimuth(prev_geom_3857, geom_3857)
        END AS az1,
        CASE
            WHEN prev_geom_3857 IS NULL OR next_geom_3857 IS NULL OR geom_3857 IS NULL THEN NULL
            ELSE ST_Azimuth(geom_3857, next_geom_3857)
        END AS az2
    FROM pts
),
angles AS (
    SELECT
        d.*,
        CASE
            WHEN az1 IS NULL OR az2 IS NULL THEN NULL
            ELSE
                CASE
                    WHEN abs(az2 - az1) > pi() THEN (2 * pi() - abs(az2 - az1))
                    ELSE abs(az2 - az1)
                END
        END AS turn_angle_rad
    FROM dists AS d
),
radii AS (
    SELECT
        a.*,
        -- Circumradius of triangle(prev,cur,next) in meters:
        -- R = (abc) / (4A), A from Heron's formula.
        CASE
            WHEN a.dist_prev_m IS NULL OR a.dist_next_m IS NULL OR a.dist_prev_next_m IS NULL THEN NULL
            WHEN a.dist_prev_m = 0 OR a.dist_next_m = 0 OR a.dist_prev_next_m = 0 THEN NULL
            ELSE
                (
                    (a.dist_prev_m * a.dist_next_m * a.dist_prev_next_m)
                    /
                    NULLIF(
                        4.0 * sqrt(
                            GREATEST(
                                (
                                    ((a.dist_prev_m + a.dist_next_m + a.dist_prev_next_m) / 2.0)
                                    * (((a.dist_prev_m + a.dist_next_m + a.dist_prev_next_m) / 2.0) - a.dist_prev_m)
                                    * (((a.dist_prev_m + a.dist_next_m + a.dist_prev_next_m) / 2.0) - a.dist_next_m)
                                    * (((a.dist_prev_m + a.dist_next_m + a.dist_prev_next_m) / 2.0) - a.dist_prev_next_m)
                                ),
                                0.0
                            )
                        ),
                        0.0
                    )
                )
        END AS radius_m
    FROM angles AS a
),
cum AS (
    SELECT
        r.*,
        SUM(COALESCE(r.dist_prev_m, 0.0)) OVER (PARTITION BY r.way_id ORDER BY r.seq) AS cum_m
    FROM radii AS r
),
bucketed AS (
    SELECT
        c.*,
        (COALESCE(c.dist_prev_m, 0.0) + COALESCE(c.dist_next_m, 0.0)) / 2.0 AS contrib_m,
        CASE
            WHEN c.turn_angle_rad IS NULL OR c.radius_m IS NULL THEN NULL
            WHEN c.turn_angle_rad < (SELECT min_turn_angle_rad FROM params) THEN 'straight'
            WHEN c.radius_m <= (SELECT sharp_radius_m FROM params) THEN 'sharp'
            WHEN c.radius_m <= (SELECT broad_radius_m FROM params) THEN 'broad'
            ELSE 'straight'
        END AS curvature_bucket
    FROM cum AS c
)
INSERT INTO rs_curvature_vertex_metrics (
    way_id, node_id, seq, cum_m, dist_prev_m, dist_next_m, dist_prev_next_m,
    turn_angle_rad, radius_m, contrib_m, curvature_bucket, suppressed
)
SELECT
    way_id, node_id, seq, cum_m, dist_prev_m, dist_next_m, dist_prev_next_m,
    turn_angle_rad, radius_m,
    CASE
        WHEN curvature_bucket IS NULL THEN 0.0
        -- endpoints contribute noise; ignore them
        WHEN dist_prev_m IS NULL OR dist_next_m IS NULL THEN 0.0
        ELSE contrib_m
    END AS contrib_m,
    curvature_bucket,
    FALSE
FROM bucketed;

CREATE INDEX IF NOT EXISTS idx_rs_curvature_vertex_metrics_way_seq
ON rs_curvature_vertex_metrics (way_id, seq);

CREATE INDEX IF NOT EXISTS idx_rs_curvature_vertex_metrics_way_cum
ON rs_curvature_vertex_metrics (way_id, cum_m);


