-- Road Intersection Speed Degradation: Schema setup (v2 - New Approach)
-- Creates temporary tables for intersection speed degradation calculation
--
-- New approach:
-- - Categorizes intersections as Major, Middling, or Minor based on road type sets
-- - Calculates speed degradation (0.0 to 0.5) based on distance-based impact
-- - Applies setting and infrastructure multipliers

-- Road Intersection Speed Degradation: Schema setup (v2 - New Approach)
-- Creates temporary tables for intersection speed degradation calculation
--
-- Note: Temp tables are created in their respective SQL files:
-- - temp_intersection_nodes_v2: Created in 01_find_and_categorize_intersections_v2.sql
-- - temp_way_intersections_v2: Created in 02_map_intersections_to_ways_v2.sql
-- - temp_way_base_degradation: Created in 03_calculate_base_degradation_v2.sql
--
-- This file is kept for documentation purposes and to ensure clean state
-- All temp tables are dropped and recreated in their respective files

-- Drop any existing temp tables to ensure clean state
DROP TABLE IF EXISTS temp_intersection_nodes_v2;
DROP TABLE IF EXISTS temp_way_intersections_v2;
DROP TABLE IF EXISTS temp_way_base_degradation;

