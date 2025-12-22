--Adding Population density column
ALTER TABLE india_grids ADD COLUMN IF NOT EXISTS population_density DOUBLE PRECISION;

--Calculation density for each grid
--Using ST_Clip to clip population density as per grid rater
--Using mean for averaging per grid
UPDATE india_grids SET population_density = subquery.pop_density
FROM (
    SELECT
        o.grid_id,
        (ST_SummaryStats(ST_Clip(r.rast, o.grid_geom))).mean AS pop_density -- Calculates the average density
    FROM
        india_grids o
    JOIN
        pop_density r
    ON
        ST_Intersects(r.rast, o.grid_geom)
) AS subquery
WHERE
    india_grids.grid_id = subquery.grid_id;

--Adding Built up percentage column
ALTER TABLE india_grids ADD COLUMN IF NOT EXISTS build_perc DOUBLE PRECISION;

--Calculation built up percentage for each grid
--Using ST_Clip to clip build up as per grid raster
--Using SUM for build up and dividing by area per grid
UPDATE india_grids SET build_perc = subquery.build
FROM (
    SELECT
        o.grid_id,
        ((ST_SummaryStats(ST_Clip(r.rast, o.grid_geom))).sum / ST_Area(ST_Transform(o.grid_geom, 3395))) * 100 AS build -- Calculates the average density
    FROM
        india_grids o
    JOIN
        built_up_area r
    ON
        ST_Intersects(r.rast, o.grid_geom)
) AS subquery
WHERE
    india_grids.grid_id = subquery.grid_id;


