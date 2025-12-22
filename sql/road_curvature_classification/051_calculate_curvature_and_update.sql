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
COMMIT;

-- Step 2: Add the new column
ALTER TABLE osm_all_roads ADD COLUMN IF NOT EXISTS 
geom_ls GEOMETRY(LINESTRING, 4326);
COMMIT;

-- Step 3: Drop the table if it already exists
DROP TABLE IF EXISTS osm_all_roads_geom_ls;
COMMIT;

-- Step 4: Create the new table
CREATE TABLE osm_all_roads_geom_ls AS
SELECT osm_id, 
       (ST_Dump(geometry)).geom AS geom_ls
FROM osm_all_roads
WHERE GeometryType(geometry) = 'MULTILINESTRING';
COMMIT;

-- Step 5: Update the osm_all_roads table
UPDATE osm_all_roads 
SET geom_ls = geometry 
WHERE GeometryType(geometry) = 'LINESTRING';
COMMIT;

UPDATE osm_all_roads AS o
SET geom_ls = g.geom_ls
FROM osm_all_roads_geom_ls AS g
WHERE o.osm_id = g.osm_id;
COMMIT;

DROP TABLE IF EXISTS curvature_results;
CREATE TABLE curvature_results (
    osm_id BIGINT,
    segment_length REAL,
    road_curvature_ratio REAL,
    road_curvature_classification VARCHAR
);
COMMIT;

-- Step 2: Calculate curvature and insert results directly into the results table.
WITH all_segments AS (
    -- Handle simple LINESTRINGs
    SELECT 
        osm_id,
        geometry AS geom_ls
    FROM osm_all_roads
    WHERE GeometryType(geometry) = 'LINESTRING' AND highway IS NOT NULL
    UNION ALL
    -- Handle MULTILINESTRINGs by dumping them into separate LINESTRINGs
    SELECT 
        osm_id,
        (ST_Dump(geometry)).geom AS geom_ls
    FROM osm_all_roads
    WHERE GeometryType(geometry) = 'MULTILINESTRING' AND highway IS NOT NULL
)
INSERT INTO curvature_results (osm_id, segment_length, road_curvature_ratio, road_curvature_classification)
SELECT 
    osm_id,
    ST_Length(geom_ls::geography) as segment_length,
    CASE 
        WHEN ST_Length(geom_ls::geography) = 0 THEN NULL
        ELSE ST_Distance(ST_StartPoint(geom_ls)::geography, ST_EndPoint(geom_ls)::geography) 
             / NULLIF(ST_Length(geom_ls::geography), 0)
    END AS road_curvature_ratio,
    CASE 
        WHEN ST_Length(geom_ls::geography) = 0 THEN 'straight'
        WHEN ST_Distance(ST_StartPoint(geom_ls)::geography, ST_EndPoint(geom_ls)::geography) / NULLIF(ST_Length(geom_ls::geography), 0) > 0.9 THEN 'straight'
        WHEN ST_Distance(ST_StartPoint(geom_ls)::geography, ST_EndPoint(geom_ls)::geography) / NULLIF(ST_Length(geom_ls::geography), 0) > 0.75 THEN 'medium'
        ELSE 'high'
    END AS road_curvature_classification
FROM all_segments;
COMMIT;

-- Step 3: Add the classification column to the main table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='osm_all_roads' AND column_name='road_curvature_classification'
    ) THEN
        ALTER TABLE osm_all_roads ADD COLUMN road_curvature_classification VARCHAR;
    END IF;
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='osm_all_roads' AND column_name='road_curvature_ratio'
    ) THEN
        ALTER TABLE osm_all_roads ADD COLUMN road_curvature_ratio REAL;
    END IF;
END$$;
COMMIT;

-- Step 4: Create indexes to speed up the UPDATE
-- Index on curvature_results for the DISTINCT ON query
CREATE INDEX IF NOT EXISTS idx_curvature_results_osm_id_segment_length 
ON curvature_results (osm_id, segment_length DESC);
COMMIT;

-- Index on osm_all_roads.osm_id for the UPDATE join (if it doesn't exist)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'osm_all_roads' 
        AND indexname = 'idx_osm_all_roads_osm_id'
    ) THEN
        CREATE INDEX idx_osm_all_roads_osm_id ON osm_all_roads (osm_id);
    END IF;
END$$;
COMMIT;

-- Step 5: Update the main table using the results.
-- For each osm_id, we choose the classification of its longest segment.
WITH final_classification AS (
    SELECT DISTINCT ON (osm_id)
        osm_id,
        road_curvature_classification,
        road_curvature_ratio
    FROM curvature_results
    ORDER BY osm_id, segment_length DESC
)
UPDATE osm_all_roads AS o
SET road_curvature_classification = f.road_curvature_classification,
    road_curvature_ratio = f.road_curvature_ratio
FROM final_classification AS f
WHERE o.osm_id = f.osm_id;
COMMIT;

-- Step 6: Set any remaining nulls for highways to 'straight' as a fallback
UPDATE osm_all_roads
SET road_curvature_classification = 'straight',
    road_curvature_ratio = COALESCE(road_curvature_ratio, 1)
WHERE highway IS NOT NULL AND (road_curvature_classification IS NULL OR road_curvature_ratio IS NULL);
COMMIT;

-- Step 7: Clean up the temporary table and indexes
DROP INDEX IF EXISTS idx_curvature_results_osm_id_segment_length;
DROP TABLE curvature_results;
COMMIT;
