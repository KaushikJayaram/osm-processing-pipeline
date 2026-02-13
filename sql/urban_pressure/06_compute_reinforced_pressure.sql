-- Spatial smoothing for urban_pressure using uniform neighborhood average.
-- Uses :neighbor_radius (meters) for ST_DWithin.

WITH neigh AS (
    SELECT
        g.grid_id,
        AVG(ig_n.urban_pressure) AS reinforced
    FROM public.india_grids_54009 g
    JOIN public.india_grids_54009 n
        ON ST_DWithin(g.centroid_54009, n.centroid_54009, :neighbor_radius)
    JOIN public.india_grids ig_n
        ON ig_n.grid_id = n.grid_id
    GROUP BY g.grid_id
)
UPDATE public.india_grids ig
SET reinforced_pressure = neigh.reinforced
FROM neigh
WHERE ig.grid_id = neigh.grid_id;

-- Optional: If you want to exclude self from the neighborhood, add:
--   AND g.grid_id <> n.grid_id
-- to the ST_DWithin join.
