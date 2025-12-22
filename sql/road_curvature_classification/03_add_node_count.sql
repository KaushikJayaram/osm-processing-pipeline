-- Step 1: Drop the column if it already exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='osm_all_roads_for_curvature' AND column_name='node_count'
    ) THEN
        ALTER TABLE osm_all_roads_for_curvature DROP COLUMN node_count;
    END IF;
END$$;

-- Step 2: Add the new column
ALTER TABLE osm_all_roads_for_curvature ADD COLUMN IF NOT EXISTS node_count INT;

-- Step 3: Calculate the number of nodes for each road
UPDATE osm_all_roads_for_curvature
SET node_count = (SELECT COUNT(*) 
                  FROM (SELECT ST_DumpPoints(geom_ls)) AS points);
