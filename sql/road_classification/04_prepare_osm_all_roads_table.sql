-- FILTER HIGHWAY TYPES: Only process specific highway types in road classification
-- These highway types are RETAINED for all road classification processing:
-- motorway, trunk, primary, secondary, tertiary, residential, unclassified, service, track, path,
-- living_street, trunk_link, primary_link, secondary_link, motorway_link, tertiary_link
-- All other highway types are excluded from processing.
-- 
-- We use a bikable_road column to mark eligible roads, which simplifies all subsequent queries
-- and allows for efficient partial indexing.

-- Add bikable_road column to mark roads that should be processed
ALTER TABLE osm_all_roads
ADD COLUMN IF NOT EXISTS bikable_road BOOLEAN DEFAULT FALSE;

-- Mark roads with eligible highway types as bikable_road = true
-- All other roads remain FALSE (handled by DEFAULT)
UPDATE osm_all_roads
SET bikable_road = TRUE
WHERE highway IN ('motorway', 'trunk', 'primary', 'secondary', 'tertiary', 'residential', 'unclassified', 'service', 'track', 'path', 'living_street', 'trunk_link', 'primary_link', 'secondary_link', 'motorway_link', 'tertiary_link', 'road');

-- Ensure any existing NULL values are set to FALSE (for rows added before this column existed)
UPDATE osm_all_roads
SET bikable_road = FALSE
WHERE bikable_road IS NULL;

-- Create a partial index on bikable_road = true for efficient filtering
DO $$ 
BEGIN 
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes WHERE tablename = 'osm_all_roads' AND indexname = 'idx_osm_all_roads_bikable_road'
    ) THEN 
        CREATE INDEX idx_osm_all_roads_bikable_road ON osm_all_roads (osm_id) WHERE bikable_road = TRUE;
    END IF;
END $$;

-- Create a spatial index on osm_all_roads.geometry to optimize spatial operations
DO $$ 
BEGIN 
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes WHERE tablename = 'osm_all_roads' AND indexname = 'idx_osm_all_roads_geom'
    ) THEN 
        CREATE INDEX idx_osm_all_roads_geom ON osm_all_roads USING GIST (geometry);
    END IF;
END $$;

-- Create an index on osm_all_roads.ref to speed up filtering for NH/SH references
DO $$ 
BEGIN 
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes WHERE tablename = 'osm_all_roads' AND indexname = 'idx_osm_all_roads_ref'
    ) THEN 
        CREATE INDEX idx_osm_all_roads_ref ON osm_all_roads (ref);
    END IF;
END $$;


-- Add columns for road lengths, build percentage, and population density to osm_all_roads
ALTER TABLE osm_all_roads
ADD COLUMN IF NOT EXISTS length_Urban_WoH DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS length_Urban_H DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS length_SemiUrban_WoH DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS length_SemiUrban_H DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS length_Rural_WoH DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS length_Rural_H DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS build_perc DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS population_density DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS multi_grid BOOLEAN;