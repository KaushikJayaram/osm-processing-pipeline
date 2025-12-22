-- RideSense India grid Code
-- Creating grids of 1km X 1km grids from existing rs_india_bounds table created using Lua script
-- OPTIMIZED: Use MIN/MAX instead of ST_Union to avoid expensive geometry union operation
-- Last modified by: KJ

-- Drop existing table if it exists
DROP TABLE IF EXISTS india_grids;

-- Creating india grid table that will store grids for 1km X 1km
CREATE TABLE india_grids (
    grid_id SERIAL PRIMARY KEY,
    grid_geom GEOMETRY(Polygon, 4326),
    grid_area DOUBLE PRECISION,
    is_valid BOOLEAN DEFAULT FALSE  -- Flag to mark valid grids
);

-- Step 1: Generate ALL grid cells in the bounding box (uniform 1km x 1km)
-- OPTIMIZATION: Use MIN/MAX on bounding box coordinates instead of ST_Union
-- This is MUCH faster - avoids expensive geometry union operation
WITH bounds AS (
    SELECT 
        MIN(ST_XMin(geometry)) AS lon_min, 
        MIN(ST_YMin(geometry)) AS lat_min, 
        MAX(ST_XMax(geometry)) AS lon_max, 
        MAX(ST_YMax(geometry)) AS lat_max
    FROM rs_india_bounds
    WHERE admin_level = '4' AND geometry IS NOT NULL  -- ✅ Only using valid state-level boundaries
),
grid AS (
    -- Running loop to generate all grids
    SELECT
        lon_min + (i * 0.009) AS lon_lower,  -- 1 km ≈ 0.009 degrees
        lat_min + (j * 0.009) AS lat_lower,  
        lon_min + ((i + 1) * 0.009) AS lon_upper,
        lat_min + ((j + 1) * 0.009) AS lat_upper
    FROM bounds,
         generate_series(0, FLOOR((lon_max - lon_min) / 0.009)::integer) AS i,  
         generate_series(0, FLOOR((lat_max - lat_min) / 0.009)::integer) AS j  
)
-- Step 2: Insert ALL grid cells (no filtering yet - maintains uniform 1km x 1km size)
INSERT INTO india_grids (grid_geom)
SELECT ST_SetSRID(ST_MakeEnvelope(lon_lower, lat_lower, lon_upper, lat_upper, 4326), 4326) AS grid_geom
FROM grid;

-- Step 3: Create spatial index on grid table for fast intersection checks
CREATE INDEX idx_india_grids_geom ON india_grids USING GIST (grid_geom);

-- Step 4: Ensure spatial index exists on state boundaries
CREATE INDEX IF NOT EXISTS idx_rs_india_bounds_geom 
ON rs_india_bounds USING GIST (geometry)
WHERE admin_level = '4' AND geometry IS NOT NULL;

-- Step 5: Mark valid grids by iterating through each state boundary
-- This uses the spatial index on india_grids for efficient lookups
-- Complexity: O(states × log(grids)) instead of O(grids × states)
UPDATE india_grids
SET is_valid = TRUE
WHERE EXISTS (
    SELECT 1
    FROM rs_india_bounds
    WHERE admin_level = '4' 
      AND geometry IS NOT NULL
      AND ST_Intersects(india_grids.grid_geom, geometry)
);

-- Step 6: Delete invalid grids (those that don't intersect any state boundary)
DELETE FROM india_grids WHERE is_valid = FALSE;

-- Step 7: Drop the temporary flag column (optional - you can keep it if useful)
ALTER TABLE india_grids DROP COLUMN is_valid;

-- Step 8: Calculate area for each grid in square kilometers
UPDATE india_grids
SET grid_area = ST_Area(ST_Transform(grid_geom, 32643)) / 1000000;  -- Convert from square meters to square kilometers
