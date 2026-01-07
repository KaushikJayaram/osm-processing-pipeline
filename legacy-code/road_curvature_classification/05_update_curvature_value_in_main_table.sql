-- Add the new column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='osm_all_roads' AND column_name='road_curvature_classification'
    ) THEN
        ALTER TABLE osm_all_roads ADD COLUMN IF NOT EXISTS road_curvature_classification VARCHAR;
    END IF;
END$$;

-- Update the road_curvature_classification for matching osm_id
UPDATE osm_all_roads AS o
SET road_curvature_classification = c.road_curvature_classification
FROM osm_all_roads_for_curvature AS c
WHERE o.osm_id = c.osm_id;

-- Set road_curvature_classification to 'straight' for ways with a highway tag and null classification
UPDATE osm_all_roads
SET road_curvature_classification = 'straight'
WHERE highway IS NOT NULL AND road_curvature_classification IS NULL;
