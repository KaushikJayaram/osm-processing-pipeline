-- One-time SQL to add fourlane column to osm_all_roads
-- Run this before executing fourlane_run.py

BEGIN;

-- Add the fourlane column (TEXT type to store 'yes' or 'no')
ALTER TABLE osm_all_roads 
ADD COLUMN IF NOT EXISTS fourlane TEXT;

-- Optionally create an index for faster queries (uncomment if needed)
-- CREATE INDEX IF NOT EXISTS idx_osm_all_roads_fourlane 
--     ON osm_all_roads (fourlane);

COMMIT;

-- Verify the column was added
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_name = 'osm_all_roads' 
  AND column_name = 'fourlane';
