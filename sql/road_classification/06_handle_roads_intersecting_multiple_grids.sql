-- Handle roads that intersect with multiple grids
-- Only process bikable roads (bikable_road = true)
-- Chunk params: :grid_id_min, :grid_id_max
DROP TABLE IF EXISTS tmp_osm_ids_in_chunk;
CREATE TEMP TABLE tmp_osm_ids_in_chunk AS
SELECT DISTINCT r.osm_id
FROM india_grids g
JOIN osm_all_roads r
  ON ST_Intersects(r.geometry, g.grid_geom)
WHERE g.grid_id BETWEEN :grid_id_min AND :grid_id_max
  AND g.grid_geom && ST_MakeEnvelope(:lon_min, :lat_min, :lon_max, :lat_max, 4326)
  AND ST_Intersects(g.grid_geom, ST_MakeEnvelope(:lon_min, :lat_min, :lon_max, :lat_max, 4326))
  AND r.bikable_road = TRUE
  AND r.multi_grid IS NULL;

WITH road_intersections AS (
    SELECT
        r.osm_id,
        g.grid_id,
        g.grid_classification_l1,
        ST_Length(ST_Intersection(r.geometry, g.grid_geom)::geography) AS road_length,
        g.built_up_fraction AS grid_build_perc,
        g.pop_density AS grid_population_density
    FROM
        osm_all_roads r
    JOIN
        india_grids g
    ON
        ST_Intersects(r.geometry, g.grid_geom) -- Only calculate intersections for intersecting pairs
    WHERE
        r.bikable_road = TRUE
        AND r.multi_grid IS NULL
        AND r.osm_id IN (SELECT osm_id FROM tmp_osm_ids_in_chunk)
),
aggregated_data AS (
    SELECT
        ri.osm_id,
        -- Determine multi_grid status
        (COUNT(DISTINCT ri.grid_classification_l1) > 1) AS multi_grid,
        -- Sum road lengths for each classification
        SUM(CASE WHEN ri.grid_classification_l1 = 'Urban' THEN ri.road_length ELSE 0 END) AS length_Urban,
        SUM(CASE WHEN ri.grid_classification_l1 = 'SemiUrban' THEN ri.road_length ELSE 0 END) AS length_SemiUrban,
        SUM(CASE WHEN ri.grid_classification_l1 = 'Rural' THEN ri.road_length ELSE 0 END) AS length_Rural,
        -- Calculate average build percentage and population density
        AVG(ri.grid_build_perc) AS build_perc,
        AVG(ri.grid_population_density) AS population_density,
        LEAST(AVG(ri.grid_population_density) / 50000.0, 1.0) AS pop_density_normalized
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
    length_Urban = agg.length_Urban,
    length_SemiUrban = agg.length_SemiUrban,
    length_Rural = agg.length_Rural,
    build_perc = agg.build_perc,
    population_density = agg.population_density,
    pop_density_normalized = agg.pop_density_normalized
FROM
    aggregated_data agg
WHERE
    r.osm_id = agg.osm_id
    AND r.bikable_road = TRUE;

-- Assign final_road_classification_from_grid_overlap when multi_grid is FALSE
-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads
SET final_road_classification_from_grid_overlap =
    CASE
        WHEN length_Urban > 0 THEN 'Urban'
        WHEN length_SemiUrban > 0 THEN 'SemiUrban'
        WHEN length_Rural > 0 THEN 'Rural'
    END
WHERE multi_grid = FALSE
AND bikable_road = TRUE
AND osm_id IN (SELECT osm_id FROM tmp_osm_ids_in_chunk);

-- Assign final_road_classification_from_grid_overlap when multi_grid is TRUE
-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads
SET final_road_classification_from_grid_overlap =
    CASE
        WHEN length_Urban >= GREATEST(length_SemiUrban, length_Rural) THEN 'Urban'
        WHEN length_SemiUrban >= GREATEST(length_Urban, length_Rural) THEN 'SemiUrban'
        ELSE 'Rural'
    END
WHERE multi_grid = TRUE
AND bikable_road = TRUE
AND osm_id IN (SELECT osm_id FROM tmp_osm_ids_in_chunk);

-- Catch-all: Assign any remaining NULL values as 'Rural' (default classification)
-- Only process bikable roads (bikable_road = true)
UPDATE osm_all_roads
SET final_road_classification_from_grid_overlap = 'Rural'
WHERE final_road_classification_from_grid_overlap IS NULL
AND bikable_road = TRUE
AND osm_id IN (SELECT osm_id FROM tmp_osm_ids_in_chunk);

-- Add columns for road-level urban pressure metrics (idempotent)
ALTER TABLE osm_all_roads
ADD COLUMN IF NOT EXISTS urban_pressure DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS reinforced_pressure DOUBLE PRECISION;

-- Assign road-level urban_pressure and reinforced_pressure
-- Single-grid roads: same as grid value; multi-grid roads: average across intersecting grids
WITH road_grid AS (
    SELECT
        r.osm_id,
        g.urban_pressure,
        g.reinforced_pressure
    FROM osm_all_roads r
    JOIN india_grids g
      ON ST_Intersects(r.geometry, g.grid_geom)
    WHERE r.bikable_road = TRUE
      AND r.osm_id IN (SELECT osm_id FROM tmp_osm_ids_in_chunk)
),
agg AS (
    SELECT
        osm_id,
        AVG(urban_pressure) AS urban_pressure,
        AVG(reinforced_pressure) AS reinforced_pressure
    FROM road_grid
    GROUP BY osm_id
)
UPDATE osm_all_roads r
SET
    urban_pressure = agg.urban_pressure,
    reinforced_pressure = agg.reinforced_pressure
FROM agg
WHERE r.osm_id = agg.osm_id
  AND r.bikable_road = TRUE;

DROP TABLE IF EXISTS tmp_osm_ids_in_chunk;
