-- Create overlay table in EPSG:54009, filtered by test bounds.
-- Idempotent: skips creation if public.india_grids_54009 already exists.

DO $$
BEGIN
    IF to_regclass('public.india_grids_54009') IS NULL THEN
        CREATE UNLOGGEDTABLE public.india_grids_54009 AS
        SELECT
            g.grid_id,
            ST_Transform(g.grid_geom, 54009) AS geom_54009,
            ST_PointOnSurface(ST_Transform(g.grid_geom, 54009)) AS centroid_54009,
            ST_Area(ST_Transform(g.grid_geom, 54009))::numeric AS grid_area_m2
        FROM public.india_grids g
        WHERE ST_Intersects(
            g.grid_geom,
            ST_MakeEnvelope(:lon_min, :lat_min, :lon_max, :lat_max, 4326)
        );

        CREATE INDEX IF NOT EXISTS india_grids_54009_geom_gix
            ON public.india_grids_54009
            USING GIST (geom_54009);

        CREATE INDEX IF NOT EXISTS india_grids_54009_centroid_gix
            ON public.india_grids_54009
            USING GIST (centroid_54009);
        
        CREATE INDEX IF NOT EXISTS idx_india_grids_54009_grid_id ON public.india_grids_54009 (grid_id);

        ANALYZE public.india_grids_54009;
    ELSE
        RAISE NOTICE 'public.india_grids_54009 already exists. Skipping create.';
    END IF;
END $$;
