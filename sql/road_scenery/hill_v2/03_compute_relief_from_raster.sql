-- Compute relief metrics from pre-smoothed relief raster (1km neighborhood)
-- Short roads (<2000m): centroid sampling
-- Long roads (>=2000m): sample at least 1 point per 2000m and average relief
-- Uses rs_relief_1km_120m raster (EPSG:3857, NoData=-9999)

WITH base AS (
    SELECT
        r.ctid,
        r.geometry,
        r.geom_3857,
        r.length_geom_3857 AS length_m
    FROM osm_all_roads r
    JOIN public.osm_all_roads_grid rg
      ON rg.osm_id = r.osm_id
    WHERE r.bikable_road = TRUE
      AND r.geom_3857 IS NOT NULL
      AND r.geometry && ST_MakeEnvelope(:lon_min, :lat_min, :lon_max, :lat_max, 4326)
      AND rg.grid_id BETWEEN :grid_id_min AND :grid_id_max
),
short_samples AS (
    SELECT
        b.ctid,
        ST_Centroid(b.geom_3857) AS pt
    FROM base b
    WHERE b.length_m < 2000
),
long_samples AS (
    SELECT
        b.ctid,
        ST_LineInterpolatePoint(b.geom_3857, (gs + 0.5) / ncalc.n) AS pt
    FROM base b
    CROSS JOIN LATERAL (
        SELECT GREATEST(1, CEIL(b.length_m / 2000.0))::int AS n
    ) ncalc
    CROSS JOIN LATERAL generate_series(0, ncalc.n - 1) gs
    WHERE b.length_m >= 2000
),
sample_points AS (
    SELECT * FROM short_samples
    UNION ALL
    SELECT * FROM long_samples
),
sampled_values AS (
    SELECT
        sp.ctid,
        ST_Value(rt.rast, sp.pt) AS val
    FROM sample_points sp
    JOIN rs_relief_1km_120m rt
      ON ST_Intersects(rt.rast, sp.pt)
),
relief_stats AS (
    SELECT
        ctid,
        AVG(val) AS relief_mean
    FROM sampled_values
    WHERE val IS NOT NULL
      AND val <> -9999
    GROUP BY ctid
)
UPDATE osm_all_roads r
SET hill_relief_1km = s.relief_mean
FROM relief_stats s
WHERE r.ctid = s.ctid;
