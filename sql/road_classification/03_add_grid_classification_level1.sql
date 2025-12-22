--Adding grid_classification_l1 column
ALTER TABLE india_grids ADD COLUMN IF NOT EXISTS grid_classification_l1 varchar;

--creating column based on thresholds
update india_grids set grid_classification_l1= subquery.classif
from (
		select grid_id,
		case when population_density is not null
		then
		    case when (250 * build_perc + 3 * population_density) >= 7500 then 'Urban'
		    when (250 * build_perc + 3 * population_density) < 7500 AND (50 * build_perc + population_density) > 1000 then 'Semi-Urban'
			else 'Rural' end
		else
		    case when build_perc>=30 then 'Urban'
		    when (build_perc between 20 and 30) then 'Semi-Urban'
			else 'Rural' end
		end as classif
		from india_grids
) subquery
where india_grids.grid_id=subquery.grid_id;

-- Add the 'grid_classification_l2' column to the india_grids table to store refined classifications
ALTER TABLE india_grids
ADD COLUMN IF NOT EXISTS grid_classification_l2 VARCHAR;

-- Create a GIST index on the grid_geom column of india_grids to optimize spatial queries
DO $$ 
BEGIN 
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes WHERE tablename = 'india_grids' AND indexname = 'idx_india_grids_geom'
    ) THEN 
        CREATE INDEX idx_india_grids_geom ON india_grids USING GIST (grid_geom);
    END IF;
END $$;

-- Create a BTREE index on grid_classification_l1 column of india_grids to speed up filtering operations
DO $$ 
BEGIN 
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes WHERE tablename = 'india_grids' AND indexname = 'idx_india_grids_grid_classification_l1'
    ) THEN 
        CREATE INDEX idx_india_grids_grid_classification_l1 ON india_grids (grid_classification_l1);
    END IF;
END $$;
