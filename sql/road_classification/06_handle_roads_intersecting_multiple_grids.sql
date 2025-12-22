-- Handle roads that intersect with multiple grids 
-- Only process bikable roads (bikable_road = true)
WITH road_intersections AS (
    SELECT
        r.osm_id,
        g.grid_id,
        g.grid_classification_l2,
        ST_Length(ST_Intersection(r.geometry, g.grid_geom)::geography) AS road_length,
        g.build_perc AS grid_build_perc,
        g.population_density AS grid_population_density
    FROM
        osm_all_roads r
    JOIN
        india_grids g
    ON
        ST_Intersects(r.geometry, g.grid_geom) -- Only calculate intersections for intersecting pairs
    WHERE
        r.bikable_road = TRUE
),
aggregated_data AS (
    SELECT
        ri.osm_id,
        -- Determine multi_grid status
        (COUNT(DISTINCT ri.grid_classification_l2) > 1) AS multi_grid,
        -- Sum road lengths for each classification
        SUM(CASE WHEN ri.grid_classification_l2 = 'Urban_WoH' THEN ri.road_length ELSE 0 END) AS length_Urban_WoH,
        SUM(CASE WHEN ri.grid_classification_l2 = 'Urban_H' THEN ri.road_length ELSE 0 END) AS length_Urban_H,
        SUM(CASE WHEN ri.grid_classification_l2 = 'SemiUrban_WoH' THEN ri.road_length ELSE 0 END) AS length_SemiUrban_WoH,
        SUM(CASE WHEN ri.grid_classification_l2 = 'SemiUrban_H' THEN ri.road_length ELSE 0 END) AS length_SemiUrban_H,
        SUM(CASE WHEN ri.grid_classification_l2 = 'Rural_WoH' THEN ri.road_length ELSE 0 END) AS length_Rural_WoH,
        SUM(CASE WHEN ri.grid_classification_l2 = 'Rural_H' THEN ri.road_length ELSE 0 END) AS length_Rural_H,
        -- Calculate average build percentage and population density
        AVG(ri.grid_build_perc) AS build_perc,
        AVG(ri.grid_population_density) AS population_density
    FROM
        road_intersections ri
    GROUP BY
        ri.osm_id
)
-- Update osm_all_roads with aggregated data
-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads r
SET
    multi_grid = agg.multi_grid,
    length_Urban_WoH = agg.length_Urban_WoH,
    length_Urban_H = agg.length_Urban_H,
    length_SemiUrban_WoH = agg.length_SemiUrban_WoH,
    length_SemiUrban_H = agg.length_SemiUrban_H,
    length_Rural_WoH = agg.length_Rural_WoH,
    length_Rural_H = agg.length_Rural_H,
    build_perc = agg.build_perc,
    population_density = agg.population_density
FROM
    aggregated_data agg
WHERE
    r.osm_id = agg.osm_id
    AND r.bikable_road = TRUE;
