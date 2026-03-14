-- ============================================================================
-- Urban Cluster Polygons - Option 1 (FIXED): ST_ClusterIntersecting via UNNEST
-- ============================================================================
-- Creates urban cluster polygons from india_grids using ST_ClusterIntersecting
-- to group contiguous urban and semi-urban cells (grid_classification_l1 IN ('Urban', 'SemiUrban')).
--
-- Uses improved UNNEST pattern for stable cluster IDs and cleaner geometry handling.
-- Transforms to 3857 for clustering operations, stores final geometries in 4326.
--
-- What it does:
--   1. Filters urban and semi-urban cells within test bbox
--   2. Transforms to 3857 for clustering (better spatial operations)
--   3. Clusters contiguous cells using ST_ClusterIntersecting with UNNEST
--   4. Dissolves clusters into clean MultiPolygon geometries
--   5. Computes area, centroid, bbox, and grid count per cluster
--
-- Expected runtime: ~15-45 seconds for test bbox (depends on urban/semi-urban cell density)
-- Tuning knobs: None (contiguity-based clustering is deterministic)
--
-- Output table: public.rs_urban_clusters_i1_opt1_test
-- ============================================================================

-- Drop dependent views first (if they exist)
DROP MATERIALIZED VIEW IF EXISTS vis.map_urban_clusters_opt1_test_z10 CASCADE;
DROP VIEW IF EXISTS vis.urban_clusters_opt1_test CASCADE;

-- Drop existing table (CASCADE will also drop any remaining dependencies)
DROP TABLE IF EXISTS public.rs_urban_clusters_i1_opt1_test CASCADE;

CREATE UNLOGGED TABLE public.rs_urban_clusters_i1_opt1_test AS
WITH params AS (
  SELECT
    ST_Transform(
      ST_MakeEnvelope(:lon_min, :lat_min, :lon_max, :lat_max, 4326),
      3857
    ) AS bbox_3857
),
urban_cells AS (
  SELECT
    g.grid_id,
    g.grid_geom AS geom_4326,
    ST_Transform(g.grid_geom, 3857) AS geom_3857
  FROM public.india_grids g
  JOIN params p ON TRUE
  WHERE g.grid_classification_l1 IN ('Urban', 'SemiUrban')
    AND g.grid_geom IS NOT NULL
    AND g.grid_geom && ST_MakeEnvelope(:lon_min, :lat_min, :lon_max, :lat_max, 4326)
    AND ST_Intersects(g.grid_geom, ST_MakeEnvelope(:lon_min, :lat_min, :lon_max, :lat_max, 4326))
),
clustered AS (
  -- Cluster contiguous cells using ST_ClusterIntersecting (window function)
  SELECT
    grid_id,
    geom_4326,
    geom_3857,
    ST_ClusterIntersecting(geom_3857) OVER () AS cluster_id
  FROM urban_cells
),
dissolved AS (
  -- Dissolve clusters into single geometries
  SELECT
    cluster_id,
    ST_UnaryUnion(ST_Collect(geom_4326)) AS cluster_geom,
    COUNT(*) AS grid_count
  FROM clustered
  GROUP BY cluster_id
),
cluster_geom AS (
  -- Ensure valid MultiPolygon using improved geometry handling
  SELECT
    ROW_NUMBER() OVER (ORDER BY cluster_id) AS cluster_id,
    ST_Multi(ST_CollectionExtract(ST_MakeValid(d.cluster_geom), 3)) AS geom,
    d.grid_count
  FROM dissolved d
  WHERE d.cluster_geom IS NOT NULL
),
cluster_stats AS (
  -- Re-count grids for accuracy (using spatial join)
  SELECT
    cg.cluster_id,
    cg.geom,
    COUNT(u.grid_id)::int AS grid_count
  FROM cluster_geom cg
  JOIN urban_cells u
    ON ST_Intersects(cg.geom, u.geom_4326)
  GROUP BY cg.cluster_id, cg.geom
)
SELECT
  cluster_id,
  geom,
  -- Compute area in km² using UTM Zone 43N (32643) for accuracy
  (ST_Area(ST_Transform(geom, 32643)) / 1e6) AS area_km2,
  ST_Centroid(geom) AS centroid,
  ST_Envelope(geom) AS bbox,
  grid_count,
  now() AS created_at
FROM cluster_stats
WHERE geom IS NOT NULL;

ALTER TABLE public.rs_urban_clusters_i1_opt1_test ADD PRIMARY KEY (cluster_id);
CREATE INDEX rs_urban_clusters_i1_opt1_test_geom_gix ON public.rs_urban_clusters_i1_opt1_test USING GIST (geom);
-- VACUUM ANALYZE must be run separately (cannot run in transaction)
-- Run manually: VACUUM ANALYZE public.rs_urban_clusters_i1_opt1_test;
ALTER TABLE public.rs_urban_clusters_i1_opt1_test SET LOGGED;
