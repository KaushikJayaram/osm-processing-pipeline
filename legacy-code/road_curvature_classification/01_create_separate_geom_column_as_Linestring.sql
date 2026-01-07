-- Step 1: Drop the column if it already exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='osm_all_roads' AND column_name='geom_ls'
    ) THEN
        ALTER TABLE osm_all_roads DROP COLUMN geom_ls;
    END IF;
END$$;

-- Step 2: Add the new column
ALTER TABLE osm_all_roads ADD COLUMN IF NOT EXISTS 
geom_ls GEOMETRY(LINESTRING, 4326);

-- Step 3: Drop the table if it already exists
DROP TABLE IF EXISTS osm_all_roads_geom_ls;

-- Step 4: Create the new table
CREATE TABLE osm_all_roads_geom_ls AS
SELECT osm_id, 
       (ST_Dump(geometry)).geom AS geom_ls
FROM osm_all_roads
WHERE GeometryType(geometry) = 'MULTILINESTRING';

-- Step 5: Update the osm_all_roads table
UPDATE osm_all_roads 
SET geom_ls = geometry 
WHERE GeometryType(geometry) = 'LINESTRING';

UPDATE osm_all_roads AS o
SET geom_ls = g.geom_ls
FROM osm_all_roads_geom_ls AS g
WHERE o.osm_id = g.osm_id;
