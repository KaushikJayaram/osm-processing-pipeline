-- Step 1: Add the necessary columns to the osm_all_roads table
ALTER TABLE osm_all_roads 
ADD COLUMN IF NOT EXISTS road_scenery_urban INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS road_scenery_semiurban INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS road_scenery_rural INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS road_scenery_forest INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS road_scenery_hill INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS road_scenery_lake INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS road_scenery_beach INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS road_scenery_river INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS road_scenery_desert INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS road_scenery_field INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS road_scenery_saltflat INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS road_scenery_mountainpass INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS road_scenery_snowcappedmountain INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS road_scenery_plantation INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS road_scenery_backwater INT DEFAULT 0;

-- Step 2: Create spatial indexes to speed up processing only if data exists in the table
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM osm_all_roads LIMIT 1) THEN
        CREATE INDEX IF NOT EXISTS idx_osm_all_roads_geom ON osm_all_roads USING GIST(geometry);
        -- Partial index for non-urban, non-semiurban roads (optimizes scenery queries)
        CREATE INDEX IF NOT EXISTS idx_osm_all_roads_non_urban_semiurban 
        ON osm_all_roads USING GIST(geometry)
        WHERE road_scenery_urban = 0 AND road_scenery_semiurban = 0;
        
        -- Optional: Partial indexes for progressive filtering (Approach 4 - Hybrid)
        -- These help speed up the "exclude already-marked" filters
        -- Uncomment if you find the queries are still slow
        CREATE INDEX IF NOT EXISTS idx_osm_all_roads_scenery_forest_unmarked 
        ON osm_all_roads(road_scenery_forest) 
        WHERE road_scenery_urban = 0 AND road_scenery_semiurban = 0 AND road_scenery_forest = 0;
        
        CREATE INDEX IF NOT EXISTS idx_osm_all_roads_scenery_hill_unmarked 
        ON osm_all_roads(road_scenery_hill) 
        WHERE road_scenery_urban = 0 AND road_scenery_semiurban = 0 AND road_scenery_hill = 0;
        
        CREATE INDEX IF NOT EXISTS idx_osm_all_roads_scenery_lake_unmarked 
        ON osm_all_roads(road_scenery_lake) 
        WHERE road_scenery_urban = 0 AND road_scenery_semiurban = 0 AND road_scenery_lake = 0;
    
    END IF;

    IF EXISTS (SELECT 1 FROM rs_forest LIMIT 1) THEN
        CREATE INDEX IF NOT EXISTS idx_rs_forest_geom ON rs_forest USING GIST(geometry);
    END IF;

    IF EXISTS (SELECT 1 FROM rs_hills_nodes LIMIT 1) THEN
        CREATE INDEX IF NOT EXISTS idx_rs_hills_geom ON rs_hills_nodes USING GIST(geometry);
    END IF;

    IF EXISTS (SELECT 1 FROM rs_hills_relations LIMIT 1) THEN
        CREATE INDEX IF NOT EXISTS idx_rs_hills_geom ON rs_hills_relations USING GIST(geometry);
    END IF;

    IF EXISTS (SELECT 1 FROM rs_lakes LIMIT 1) THEN
        CREATE INDEX IF NOT EXISTS idx_rs_lakes_geom ON rs_lakes USING GIST(geometry);
    END IF;

    IF EXISTS (SELECT 1 FROM rs_coastline LIMIT 1) THEN
        CREATE INDEX IF NOT EXISTS idx_rs_coastline_geom ON rs_coastline USING GIST(geometry);
    END IF;

    IF EXISTS (SELECT 1 FROM rs_rivers LIMIT 1) THEN
        CREATE INDEX IF NOT EXISTS idx_rs_rivers_geom ON rs_rivers USING GIST(geometry);
    END IF;

    IF EXISTS (SELECT 1 FROM rs_desert LIMIT 1) THEN
        CREATE INDEX IF NOT EXISTS idx_rs_desert_geom ON rs_desert USING GIST(geometry);
    END IF;

    IF EXISTS (SELECT 1 FROM rs_fields LIMIT 1) THEN
        CREATE INDEX IF NOT EXISTS idx_rs_fields_geom ON rs_fields USING GIST(geometry);
    END IF;

--Need to add rs_salt_flat
--    IF EXISTS (SELECT 1 FROM rs_salt_flat LIMIT 1) THEN
--        CREATE INDEX IF NOT EXISTS idx_rs_salt_flat_geom ON rs_salt_flat USING GIST(geometry);
--    END IF;

    IF EXISTS (SELECT 1 FROM rs_mountain_pass LIMIT 1) THEN
        CREATE INDEX IF NOT EXISTS idx_rs_mountain_pass_geom ON rs_mountain_pass USING GIST(geometry);
    END IF;

END $$;
