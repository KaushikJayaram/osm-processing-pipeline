-- Curvature v2: prepare vertex table + indexes

TRUNCATE rs_curvature_way_vertices;

-- Filter to useful highway types (mirrors sql/road_classification/04_prepare_osm_all_roads_table.sql)
WITH eligible_ways AS (
    SELECT osm_id
    FROM osm_all_roads
    WHERE highway IN (
        'motorway', 'trunk', 'primary', 'secondary', 'tertiary',
        'residential', 'unclassified', 'service', 'track', 'path',
        'living_street', 'trunk_link', 'primary_link', 'secondary_link',
        'motorway_link', 'tertiary_link', 'road'
    )
)
INSERT INTO rs_curvature_way_vertices (way_id, node_id, seq, lon, lat, geom, geom_3857)
SELECT
    w.way_id,
    w.node_id,
    w.seq,
    w.lon,
    w.lat,
    CASE
        WHEN w.lon IS NULL OR w.lat IS NULL THEN NULL
        ELSE ST_SetSRID(ST_MakePoint(w.lon::double precision, w.lat::double precision), 4326)
    END AS geom,
    CASE
        WHEN w.lon IS NULL OR w.lat IS NULL THEN NULL
        ELSE ST_Transform(ST_SetSRID(ST_MakePoint(w.lon::double precision, w.lat::double precision), 4326), 3857)
    END AS geom_3857
FROM rs_highway_way_nodes AS w
JOIN eligible_ways AS e ON e.osm_id = w.way_id
WHERE w.seq IS NOT NULL;

-- Helpful indexes for windowing + joins
CREATE INDEX IF NOT EXISTS idx_rs_curvature_way_vertices_way_seq
ON rs_curvature_way_vertices (way_id, seq);

CREATE INDEX IF NOT EXISTS idx_rs_curvature_way_vertices_node_id
ON rs_curvature_way_vertices (node_id);

-- Source tables should also be indexed
CREATE INDEX IF NOT EXISTS idx_rs_highway_way_nodes_way_seq
ON rs_highway_way_nodes (way_id, seq);

CREATE INDEX IF NOT EXISTS idx_rs_highway_way_nodes_node_id
ON rs_highway_way_nodes (node_id);

CREATE INDEX IF NOT EXISTS idx_rs_conflict_nodes_geom
ON rs_conflict_nodes USING GIST (geometry);


