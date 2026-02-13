-- 01_worldcover_schema.sql
-- Adds columns for WorldCover 2020 sampling and Scenery V2 classification.

BEGIN;

DO $$
BEGIN
    -- 1. Add Pixel Count Columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osm_all_roads' AND column_name='wc_total_px') THEN
        ALTER TABLE osm_all_roads ADD COLUMN wc_total_px INT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osm_all_roads' AND column_name='wc_forest_px') THEN
        ALTER TABLE osm_all_roads ADD COLUMN wc_forest_px INT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osm_all_roads' AND column_name='wc_field_px') THEN
        ALTER TABLE osm_all_roads ADD COLUMN wc_field_px INT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osm_all_roads' AND column_name='wc_desert_px') THEN
        ALTER TABLE osm_all_roads ADD COLUMN wc_desert_px INT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osm_all_roads' AND column_name='wc_snow_px') THEN
        ALTER TABLE osm_all_roads ADD COLUMN wc_snow_px INT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osm_all_roads' AND column_name='wc_water_px') THEN
        ALTER TABLE osm_all_roads ADD COLUMN wc_water_px INT;
    END IF;

    -- 2. Add Fraction Columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osm_all_roads' AND column_name='wc_forest_frac') THEN
        ALTER TABLE osm_all_roads ADD COLUMN wc_forest_frac REAL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osm_all_roads' AND column_name='wc_field_frac') THEN
        ALTER TABLE osm_all_roads ADD COLUMN wc_field_frac REAL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osm_all_roads' AND column_name='wc_desert_frac') THEN
        ALTER TABLE osm_all_roads ADD COLUMN wc_desert_frac REAL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osm_all_roads' AND column_name='wc_snow_frac') THEN
        ALTER TABLE osm_all_roads ADD COLUMN wc_snow_frac REAL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osm_all_roads' AND column_name='wc_water_frac') THEN
        ALTER TABLE osm_all_roads ADD COLUMN wc_water_frac REAL;
    END IF;

    -- 3. Add Scenery V2 Classification Columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osm_all_roads' AND column_name='scenery_v2_primary') THEN
        ALTER TABLE osm_all_roads ADD COLUMN scenery_v2_primary TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osm_all_roads' AND column_name='scenery_v2_forest') THEN
        ALTER TABLE osm_all_roads ADD COLUMN scenery_v2_forest BOOLEAN DEFAULT FALSE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osm_all_roads' AND column_name='scenery_v2_field') THEN
        ALTER TABLE osm_all_roads ADD COLUMN scenery_v2_field BOOLEAN DEFAULT FALSE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osm_all_roads' AND column_name='scenery_v2_desert') THEN
        ALTER TABLE osm_all_roads ADD COLUMN scenery_v2_desert BOOLEAN DEFAULT FALSE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osm_all_roads' AND column_name='scenery_v2_snow') THEN
        ALTER TABLE osm_all_roads ADD COLUMN scenery_v2_snow BOOLEAN DEFAULT FALSE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osm_all_roads' AND column_name='scenery_v2_water') THEN
        ALTER TABLE osm_all_roads ADD COLUMN scenery_v2_water BOOLEAN DEFAULT FALSE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osm_all_roads' AND column_name='scenery_v2_confidence') THEN
        ALTER TABLE osm_all_roads ADD COLUMN scenery_v2_confidence REAL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='osm_all_roads' AND column_name='scenery_v2_source') THEN
        ALTER TABLE osm_all_roads ADD COLUMN scenery_v2_source TEXT DEFAULT 'worldcover_2020_50m';
    END IF;

END $$;

-- 4. Create Indexes for performance if needed
-- Index on scenery_v2_source to help with partial updates/resets
CREATE INDEX IF NOT EXISTS idx_osm_all_roads_scenery_v2_source ON osm_all_roads(scenery_v2_source);

COMMIT;
