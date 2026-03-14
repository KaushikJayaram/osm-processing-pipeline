-- ============================================================================
-- Urban Cluster Polygons - Option 3: Distance-based DBSCAN (ST_ClusterDBSCAN)
-- ============================================================================
-- Creates urban cluster polygons from india_grids using ST_ClusterDBSCAN
-- to group urban and semi-urban cells within a specified distance threshold.
--
-- Uses improved geometry handling with ST_CollectionExtract for clean MultiPolygons.
-- Transforms to UTM (32643) for accurate distance calculations in meters.
--
-- What it does:
--   1. Filters urban and semi-urban cells within test bbox
--   2. Transforms to UTM (32643) for distance calculations
--   3. Clusters using ST_ClusterDBSCAN with configurable eps and minpoints
--   4. Dissolves clusters into clean MultiPolygon geometries
--   5. Computes area, centroid, bbox, and grid count per cluster
--
-- Expected runtime: ~20-60 seconds for test bbox (depends on urban/semi-urban cell density)
--
-- Tuning knobs:
--   - eps_m: Distance threshold in meters (default: 1500m)
--            Typical range: 1200-2500m
--            Lower values = more clusters, higher = fewer/larger clusters
--            ~1500m merges near-touching cells and small gaps
--   - minpoints: Minimum cells per cluster (default: 3)
--                Typical range: 2-10
--                Lower = more small clusters, higher = filters out small clusters
--   To change: modify the values in the ST_ClusterDBSCAN call below
--
-- Output table: public.rs_urban_clusters_i1_opt3_test
-- ============================================================================

-- Drop dependent views first (if they exist)
DROP MATERIALIZED VIEW IF EXISTS vis.map_urban_clusters_opt3_test_z10 CASCADE;
DROP VIEW IF EXISTS vis.urban_clusters_opt3_test CASCADE;

-- Drop existing table (CASCADE will also drop any remaining dependencies)
DROP TABLE IF EXISTS public.rs_urban_clusters_i1_opt3_test CASCADE;

CREATE UNLOGGED TABLE public.rs_urban_clusters_i1_opt3_test AS
WITH urban_cells AS (
    -- Filter to urban cells within test bbox
    SELECT 
        grid_id,
        grid_geom AS geom_4326,
        ST_Transform(grid_geom, 32643) AS geom_utm  -- Transform to UTM for distance calculations
    FROM public.india_grids
    WHERE grid_classification_l1 IN ('Urban', 'SemiUrban')
      AND grid_geom IS NOT NULL
      AND grid_geom && ST_MakeEnvelope(:lon_min, :lat_min, :lon_max, :lat_max, 4326)
      AND ST_Intersects(grid_geom, ST_MakeEnvelope(:lon_min, :lat_min, :lon_max, :lat_max, 4326))
),
clustered AS (
    -- Cluster using DBSCAN in UTM (distance in meters)
    -- eps_m = 1500.0 meters, minpoints = 3
    SELECT 
        grid_id,
        geom_4326,
        geom_utm,
        ST_ClusterDBSCAN(geom_utm, eps := 1500.0, minpoints := 3) OVER () AS cluster_id
    FROM urban_cells
),
filtered_clusters AS (
    -- Filter out noise (cluster_id IS NULL from DBSCAN)
    SELECT 
        grid_id,
        geom_4326,
        cluster_id
    FROM clustered
    WHERE cluster_id IS NOT NULL
),
dissolved AS (
    -- Dissolve clusters into single geometries
    SELECT 
        cluster_id,
        ST_UnaryUnion(ST_Collect(geom_4326)) AS cluster_geom,
        COUNT(*) AS grid_count
    FROM filtered_clusters
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

ALTER TABLE public.rs_urban_clusters_i1_opt3_test ADD PRIMARY KEY (cluster_id);
CREATE INDEX rs_urban_clusters_i1_opt3_test_geom_gix ON public.rs_urban_clusters_i1_opt3_test USING GIST (geom);
-- VACUUM ANALYZE must be run separately (cannot run in transaction)
-- Run manually: VACUUM ANALYZE public.rs_urban_clusters_i1_opt3_test;
ALTER TABLE public.rs_urban_clusters_i1_opt3_test SET LOGGED;
