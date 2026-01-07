-- Drop existing table if it exists
DROP TABLE IF EXISTS india_grids;

-- Create table structure
CREATE TABLE india_grids (
    grid_id INTEGER PRIMARY KEY,
    grid_geom GEOMETRY(Polygon, 4326),
    grid_area DOUBLE PRECISION
);
