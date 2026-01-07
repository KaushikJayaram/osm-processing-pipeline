-- Road Intersection Speed Degradation: Add columns to osm_all_roads (v2 - New Approach)
-- Adds columns for the new intersection speed degradation approach
--
-- Columns added:
-- - intersection_speed_degradation_base: Base degradation (before setting/lanes factors)
-- - intersection_speed_degradation_setting_adjusted: After setting multiplier applied
-- - intersection_speed_degradation_final: Final degradation (after all factors, 0.0 to 0.5)

ALTER TABLE osm_all_roads
ADD COLUMN IF NOT EXISTS intersection_speed_degradation_base DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS intersection_speed_degradation_setting_adjusted DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS intersection_speed_degradation_final DOUBLE PRECISION;

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_osm_all_roads_isd_base 
    ON osm_all_roads (intersection_speed_degradation_base) 
    WHERE intersection_speed_degradation_base > 0;

CREATE INDEX IF NOT EXISTS idx_osm_all_roads_isd_final 
    ON osm_all_roads (intersection_speed_degradation_final) 
    WHERE intersection_speed_degradation_final > 0;

