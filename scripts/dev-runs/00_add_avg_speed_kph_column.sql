-- One-time SQL to add avg_speed_kph column to osm_all_roads
-- Run this before executing avg_speed_kph_run.py

BEGIN;

-- Add the avg_speed_kph column
ALTER TABLE osm_all_roads 
ADD COLUMN IF NOT EXISTS avg_speed_kph DOUBLE PRECISION;

-- Optionally create an index for faster queries (uncomment if needed)
-- CREATE INDEX IF NOT EXISTS idx_osm_all_roads_avg_speed_kph 
--     ON osm_all_roads (avg_speed_kph) 
--     WHERE avg_speed_kph IS NOT NULL;

COMMIT;

-- Verify the column was added
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_name = 'osm_all_roads' 
  AND column_name = 'avg_speed_kph';
