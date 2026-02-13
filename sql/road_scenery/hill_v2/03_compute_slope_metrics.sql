-- Compute slope metrics for roads
-- Short roads (<500m): centroid sampling
-- Long roads (>=500m): sample at least 1 point per 500m along the line
-- Uses rs_slope_120m raster (EPSG:3857)

WITH base AS (
    SELECT
        r.ctid,
        r.geometry,
        lm.geom_3857,
        ST_Length(lm.geom_3857) AS length_m
    FROM osm_all_roads r
    JOIN public.osm_all_roads_grid rg
      ON rg.osm_id = r.osm_id
    CROSS JOIN LATERAL (
        SELECT ST_LineMerge(ST_CollectionExtract(ST_Transform(r.geometry, 3857), 2)) AS geom_3857
    ) lm
    WHERE r.bikable_road = TRUE
      AND r.geometry && ST_MakeEnvelope(:lon_min, :lat_min, :lon_max, :lat_max, 4326)
      AND rg.grid_id BETWEEN :grid_id_min AND :grid_id_max
),
centroid_samples AS (
    SELECT
        b.ctid,
        s.val
    FROM base b
    CROSS JOIN LATERAL (
        SELECT ST_Value(rt.rast, ST_Centroid(b.geom_3857)) AS val
        FROM rs_slope_120m rt
        WHERE ST_Intersects(rt.rast, ST_Centroid(b.geom_3857))
        LIMIT 1
    ) s
    WHERE b.length_m < 500
),
long_samples AS (
    SELECT
        b.ctid,
        s.val
    FROM base b
    CROSS JOIN LATERAL (
        SELECT GREATEST(1, CEIL(b.length_m / 500.0))::int AS n
    ) ncalc
    CROSS JOIN LATERAL generate_series(0, ncalc.n - 1) gs
    CROSS JOIN LATERAL (
        SELECT ST_LineInterpolatePoint(b.geom_3857, (gs + 0.5) / ncalc.n) AS pt
    ) p
    CROSS JOIN LATERAL (
        SELECT ST_Value(rt.rast, p.pt) AS val
        FROM rs_slope_120m rt
        WHERE ST_Intersects(rt.rast, p.pt)
        LIMIT 1
    ) s
    WHERE b.length_m >= 500
),
combined_samples AS (
    SELECT * FROM centroid_samples
    UNION ALL
    SELECT * FROM long_samples
),
slope_stats AS (
    SELECT
        ctid,
        AVG(val) AS mean_slope,
        MAX(val) AS max_slope
    FROM combined_samples
    WHERE val IS NOT NULL
    GROUP BY ctid
)
UPDATE osm_all_roads r
SET
    hill_slope_mean = s.mean_slope,
    hill_slope_max = s.max_slope
FROM slope_stats s
WHERE r.ctid = s.ctid;
