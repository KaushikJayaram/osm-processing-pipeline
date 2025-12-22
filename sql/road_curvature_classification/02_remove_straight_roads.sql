-- Step 1: Drop the columns if they already exist
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='osm_all_roads' AND column_name='length'
    ) THEN
        ALTER TABLE osm_all_roads DROP COLUMN "length";
    END IF;
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='osm_all_roads' AND column_name='straight_line_length'
    ) THEN
        ALTER TABLE osm_all_roads DROP COLUMN straight_line_length;
    END IF;
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='osm_all_roads' AND column_name='length_factor'
    ) THEN
        ALTER TABLE osm_all_roads DROP COLUMN length_factor;
    END IF;
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='osm_all_roads' AND column_name='road_curvature_classification'
    ) THEN
        ALTER TABLE osm_all_roads DROP COLUMN road_curvature_classification;
    END IF;
END$$;

-- Step 2: Add the new columns
ALTER TABLE osm_all_roads ADD COLUMN IF NOT EXISTS "length" FLOAT;
ALTER TABLE osm_all_roads ADD COLUMN IF NOT EXISTS straight_line_length FLOAT;
ALTER TABLE osm_all_roads ADD COLUMN IF NOT EXISTS length_factor FLOAT;
ALTER TABLE osm_all_roads ADD COLUMN IF NOT EXISTS road_curvature_classification VARCHAR;

-- Step 3: Calculate lengths and length factor
UPDATE osm_all_roads SET
    "length" = ST_Length(geom_ls::geography),
    straight_line_length = ST_Distance(ST_StartPoint(geom_ls)::geography, ST_EndPoint(geom_ls)::geography),
    length_factor = CASE 
                        WHEN ST_Length(geom_ls::geography) > 0 
                        THEN ST_Distance(ST_StartPoint(geom_ls)::geography, ST_EndPoint(geom_ls)::geography) / ST_Length(geom_ls::geography)
                        ELSE NULL 
                    END;

-- Step 4: Drop the table if it already exists
DROP TABLE IF EXISTS osm_all_roads_for_curvature;

-- Step 5: Create a new table for curved roads
CREATE TABLE osm_all_roads_for_curvature AS
SELECT * 
FROM osm_all_roads 
WHERE length_factor < 0.9;
