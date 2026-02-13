-- Compute relief metrics (1km neighborhood)
-- Short roads (<500m): centroid buffer
-- Long roads (>=500m): sample at least 1 point per 500m and average relief
-- Uses rs_dem_120m raster (EPSG:3857)
-- Buffer: :buffer_relief_m (meters)

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
      AND r.hill_relief_1km IS NULL
),
centroid_relief AS (
    SELECT
        b.ctid,
        CASE
            WHEN (stats).count IS NULL OR (stats).count = 0 THEN NULL
            WHEN (stats).max = -9999 THEN NULL
            WHEN (stats).min = -9999 THEN NULL
            ELSE (stats).max - (stats).min
        END AS relief
    FROM base b
    CROSS JOIN LATERAL (
        SELECT ST_Buffer(ST_Centroid(b.geom_3857), :buffer_relief_m) AS buffer_geom
    ) bg
    CROSS JOIN LATERAL (
        SELECT ST_SummaryStatsAgg(
            ST_Clip(
                rt.rast,
                bg.buffer_geom
            ),
            1, true
        ) AS stats
        FROM rs_dem_120m rt
        WHERE ST_Intersects(
            ST_Envelope(rt.rast),
            bg.buffer_geom
        )
    ) s
    WHERE b.length_m < 2000
),
long_relief AS (
    SELECT
        b.ctid,
        CASE
            WHEN (stats).count IS NULL OR (stats).count = 0 THEN NULL
            WHEN (stats).max = -9999 THEN NULL
            WHEN (stats).min = -9999 THEN NULL
            ELSE (stats).max - (stats).min
        END AS relief
    FROM base b
    CROSS JOIN LATERAL (
        SELECT GREATEST(1, CEIL(b.length_m / 2000.0))::int AS n
    ) ncalc
    CROSS JOIN LATERAL generate_series(0, ncalc.n - 1) gs
    CROSS JOIN LATERAL (
        SELECT ST_LineInterpolatePoint(b.geom_3857, (gs + 0.5) / ncalc.n) AS pt
    ) p
    CROSS JOIN LATERAL (
        SELECT ST_Buffer(p.pt, :buffer_relief_m) AS buffer_geom
    ) bg
    CROSS JOIN LATERAL (
        SELECT ST_SummaryStatsAgg(
            ST_Clip(
                rt.rast,
                bg.buffer_geom
            ),
            1, true
        ) AS stats
        FROM rs_dem_120m rt
        WHERE ST_Intersects(
            ST_Envelope(rt.rast),
            bg.buffer_geom
        )
    ) s
    WHERE b.length_m >= 2000
),
combined_relief AS (
    SELECT * FROM centroid_relief
    UNION ALL
    SELECT * FROM long_relief
),
relief_stats AS (
    SELECT
        ctid,
        AVG(relief) AS relief
    FROM combined_relief
    WHERE relief IS NOT NULL
    GROUP BY ctid
)
UPDATE osm_all_roads r
SET hill_relief_1km = s.relief
FROM relief_stats s
WHERE r.ctid = s.ctid;

-- ---------------------------------------------------------------------------
-- Validation block (run manually)
-- Ensures extreme relief values are not present after NoData-safe computation.
-- ---------------------------------------------------------------------------
-- SELECT
--   COUNT(*) FILTER (WHERE hill_relief_1km > 5000) AS suspicious_rows
-- FROM osm_all_roads;

-- ---------------------------------------------------------------------------
-- Notes:
-- - NoData must be set at raster ingest for exclude_nodata=true to work.
-- - raster2pgsql -N is mandatory to carry NoData metadata into PostGIS.
-- - If metadata is missing, ST_SummaryStatsAgg can treat NoData as real data.
-- ---------------------------------------------------------------------------
