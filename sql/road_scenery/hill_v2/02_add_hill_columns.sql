-- Add columns for hill scenery metrics to osm_all_roads
-- Note: using numeric/float types

ALTER TABLE osm_all_roads 
ADD COLUMN IF NOT EXISTS hill_relief_1km FLOAT,
ADD COLUMN IF NOT EXISTS road_scenery_hill INT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'osm_all_roads'
          AND column_name = 'geom_3857'
    ) THEN
        ALTER TABLE osm_all_roads
        ADD COLUMN geom_3857 geometry(LineString, 3857);

        ALTER TABLE osm_all_roads
        ADD COLUMN length_geom_3857 DOUBLE PRECISION;

        UPDATE osm_all_roads
        SET geom_3857 = ST_LineMerge(
                ST_CollectionExtract(
                    ST_Transform(geometry, 3857), 2
                )
            ),
            length_geom_3857 = ST_Length(
                ST_LineMerge(
                    ST_CollectionExtract(
                        ST_Transform(geometry, 3857), 2
                    )
                )
            )
        WHERE geometry IS NOT NULL;
    END IF;
END $$;

-- Ensure spatial index exists
CREATE INDEX IF NOT EXISTS idx_osm_all_roads_geom ON osm_all_roads USING GIST(geometry);

-- Optional: Index for filtering processed/unprocessed
CREATE INDEX IF NOT EXISTS idx_osm_all_roads_hill_relief
ON osm_all_roads(hill_relief_1km)
WHERE hill_relief_1km IS NULL;
