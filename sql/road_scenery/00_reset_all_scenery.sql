-- Reset all scenery columns before running scenery assignment queries
-- This is REQUIRED for Approach 4 (Hybrid) to work correctly
-- Run this script before executing any scenery assignment queries
--
-- The hybrid approach uses progressive filtering (excludes already-marked roads),
-- so all scenery columns must be reset to 0 before processing

-- Reset all scenery columns for non-urban, non-semiurban roads
UPDATE osm_all_roads 
SET 
    road_scenery_forest = 0,
    road_scenery_hill = 0,
    road_scenery_lake = 0,
    road_scenery_beach = 0,
    road_scenery_river = 0,
    road_scenery_desert = 0,
    road_scenery_field = 0,
    road_scenery_mountainpass = 0,
    road_scenery_saltflat = 0,
    road_scenery_snowcappedmountain = 0,
    road_scenery_plantation = 0,
    road_scenery_backwater = 0
WHERE road_scenery_urban = 0 
AND road_scenery_semiurban = 0;

-- Note: road_scenery_urban, road_scenery_semiurban, and road_scenery_rural
-- are NOT reset here as they are assigned separately in 02_scenery_urban_and_semi_urban.sql

