-- Resume curvature v1 calculation from Step 5 (UPDATE)
-- Use this if the INSERT step completed but the script got stuck
-- This assumes curvature_results table already exists with data

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

-- Step 4: Create indexes to speed up the UPDATE
-- Index on curvature_results for the DISTINCT ON query
CREATE INDEX IF NOT EXISTS idx_curvature_results_osm_id_segment_length 
ON curvature_results (osm_id, segment_length DESC);

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

-- Step 6: Set any remaining nulls for highways to 'straight' as a fallback
UPDATE osm_all_roads
SET road_curvature_classification = 'straight',
    road_curvature_ratio = COALESCE(road_curvature_ratio, 1)
WHERE highway IS NOT NULL AND (road_curvature_classification IS NULL OR road_curvature_ratio IS NULL);

-- Step 7: Clean up the temporary table and indexes
DROP INDEX IF EXISTS idx_curvature_results_osm_id_segment_length;
DROP TABLE curvature_results;

