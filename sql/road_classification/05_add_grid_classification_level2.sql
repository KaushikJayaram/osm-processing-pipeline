-- Classify Urban grids as 'Urban_H' (with NH/SH roads) or 'Urban_WoH' (without NH/SH roads)
-- Only process bikable roads (bikable_road = true)
UPDATE india_grids
SET grid_classification_l2 = 
    CASE
        WHEN EXISTS (
            SELECT 1 FROM osm_all_roads r
            WHERE (r.ref LIKE '%NH%' OR r.ref LIKE '%SH%') 
            AND ST_Intersects(r.geometry, india_grids.grid_geom)
            AND r.bikable_road = TRUE
        ) THEN 'Urban_H'
        ELSE 'Urban_WoH'
    END
WHERE grid_classification_l1 = 'Urban';

-- Classify Semi-urban grids as 'SemiUrban_H' (with NH/SH roads) or 'SemiUrban_WoH' (without NH/SH roads)
-- Only process bikable roads (bikable_road = true)
UPDATE india_grids
SET grid_classification_l2 = 
    CASE
        WHEN EXISTS (
            SELECT 1 FROM osm_all_roads r
            WHERE (r.ref LIKE '%NH%' OR r.ref LIKE '%SH%') 
            AND ST_Intersects(r.geometry, india_grids.grid_geom)
            AND r.bikable_road = TRUE
        ) THEN 'SemiUrban_H'
        ELSE 'SemiUrban_WoH'
    END
WHERE grid_classification_l1 = 'Semi-Urban';

-- Classify Rural grids as 'Rural_H' (with NH/SH roads) or 'Rural_WoH' (without NH/SH roads)
-- Only process bikable roads (bikable_road = true)
UPDATE india_grids
SET grid_classification_l2 = 
    CASE
        WHEN EXISTS (
            SELECT 1 FROM osm_all_roads r
            WHERE (r.ref LIKE '%NH%' OR r.ref LIKE '%SH%') 
            AND ST_Intersects(r.geometry, india_grids.grid_geom)
            AND r.bikable_road = TRUE
        ) THEN 'Rural_H'
        ELSE 'Rural_WoH'
    END
WHERE grid_classification_l1 = 'Rural';

DO $$ 
BEGIN 
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes WHERE tablename = 'india_grids' AND indexname = 'idx_india_grids_grid_classification_l2'
    ) THEN 
        CREATE INDEX idx_india_grids_grid_classification_l2 ON india_grids (grid_classification_l2);
    END IF;
END $$;
