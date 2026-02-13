-- Spatial smoothing for urban_pressure (chunked by grid_id).
-- Params: :grid_id_min, :grid_id_max, :neighbor_radius

WITH neigh AS (
    SELECT
        g.grid_id,
        AVG(ig_n.urban_pressure) AS reinforced
    FROM public.india_grids_54009 g
    JOIN public.india_grids_54009 n
        ON ST_DWithin(g.centroid_54009, n.centroid_54009, :neighbor_radius)
    JOIN public.india_grids ig_n
        ON ig_n.grid_id = n.grid_id
    WHERE g.grid_id BETWEEN :grid_id_min AND :grid_id_max
    GROUP BY g.grid_id
)
UPDATE public.india_grids ig
SET reinforced_pressure = neigh.reinforced
FROM neigh
WHERE ig.grid_id = neigh.grid_id
  AND ig.grid_id BETWEEN :grid_id_min AND :grid_id_max;
