-- Step 1: Drop the columns if they already exist
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='osm_all_roads_for_curvature' AND column_name='curvature'
    ) THEN
        ALTER TABLE osm_all_roads_for_curvature DROP COLUMN curvature;
    END IF;
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='osm_all_roads_for_curvature' AND column_name='node_radius'
    ) THEN
        ALTER TABLE osm_all_roads_for_curvature DROP COLUMN node_radius;
    END IF;
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='osm_all_roads_for_curvature' AND column_name='segment_radius'
    ) THEN
        ALTER TABLE osm_all_roads_for_curvature DROP COLUMN segment_radius;
    END IF;
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='osm_all_roads_for_curvature' AND column_name='segment_length'
    ) THEN
        ALTER TABLE osm_all_roads_for_curvature DROP COLUMN segment_length;
    END IF;
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='osm_all_roads_for_curvature' AND column_name='road_curvature_classification'
    ) THEN
        ALTER TABLE osm_all_roads_for_curvature DROP COLUMN road_curvature_classification;
    END IF;
END$$;

-- Step 2: Add the new columns
ALTER TABLE osm_all_roads_for_curvature
ADD COLUMN IF NOT EXISTS curvature FLOAT,
ADD COLUMN IF NOT EXISTS node_radius FLOAT[],
ADD COLUMN IF NOT EXISTS segment_radius FLOAT[],
ADD COLUMN IF NOT EXISTS segment_length FLOAT[],
ADD COLUMN IF NOT EXISTS road_curvature_classification VARCHAR;
