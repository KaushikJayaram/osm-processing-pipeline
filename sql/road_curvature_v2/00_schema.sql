-- Curvature v2 mini-module
-- Creates intermediate + output tables used by the roadcurvature.com-style computation.
--
-- Assumes osm2pgsql flex import using scripts/Lua3_RouteProcessing_with_curvature.lua
-- has created:
--   - rs_highway_way_nodes(way_id, node_id, seq, lon, lat)
--   - rs_conflict_nodes(osm_id, conflict_type, geometry, ...)
--   - osm_all_roads(osm_id, highway, ...)

DROP TABLE IF EXISTS rs_curvature_way_vertices;
CREATE UNLOGGED TABLE rs_curvature_way_vertices (
    way_id BIGINT NOT NULL,
    node_id BIGINT NOT NULL,
    seq INTEGER NOT NULL,
    lon REAL,
    lat REAL,
    geom GEOMETRY(POINT, 4326),
    geom_3857 GEOMETRY(POINT, 3857)
);

DROP TABLE IF EXISTS rs_curvature_vertex_metrics;
CREATE UNLOGGED TABLE rs_curvature_vertex_metrics (
    way_id BIGINT NOT NULL,
    node_id BIGINT NOT NULL,
    seq INTEGER NOT NULL,
    cum_m DOUBLE PRECISION,
    dist_prev_m DOUBLE PRECISION,
    dist_next_m DOUBLE PRECISION,
    dist_prev_next_m DOUBLE PRECISION,
    turn_angle_rad DOUBLE PRECISION,
    radius_m DOUBLE PRECISION,
    contrib_m DOUBLE PRECISION,
    curvature_bucket TEXT,
    suppressed BOOLEAN DEFAULT FALSE
);

DROP TABLE IF EXISTS rs_curvature_conflict_points;
CREATE UNLOGGED TABLE rs_curvature_conflict_points (
    way_id BIGINT NOT NULL,
    node_id BIGINT NOT NULL,
    seq INTEGER,
    cum_m DOUBLE PRECISION,
    conflict_source TEXT,
    conflict_type TEXT
);

DROP TABLE IF EXISTS rs_curvature_way_summary;
CREATE UNLOGGED TABLE rs_curvature_way_summary (
    way_id BIGINT PRIMARY KEY,
    total_length_m DOUBLE PRECISION,
    meters_sharp DOUBLE PRECISION,
    meters_broad DOUBLE PRECISION,
    meters_straight DOUBLE PRECISION,
    twistiness_score DOUBLE PRECISION,
    twistiness_class TEXT
);


