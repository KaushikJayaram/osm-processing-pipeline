-- Road Intersection Density: Schema setup
-- Creates temporary tables for intersection density calculation

-- Temporary table to store intersection scores per node
DROP TABLE IF EXISTS temp_intersection_node_scores;
CREATE TEMP TABLE temp_intersection_node_scores (
    node_id BIGINT PRIMARY KEY,
    intersection_score DOUBLE PRECISION
);

-- Temporary table to store aggregated intersection scores per way
DROP TABLE IF EXISTS temp_way_intersection_scores;
CREATE TEMP TABLE temp_way_intersection_scores (
    way_id BIGINT PRIMARY KEY,
    total_intersection_score DOUBLE PRECISION
);

