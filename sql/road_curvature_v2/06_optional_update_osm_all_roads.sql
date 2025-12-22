-- Curvature v2: OPTIONAL helper to copy summary fields onto osm_all_roads.
-- This is NOT called by the main pipeline yet.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'osm_all_roads' AND column_name = 'twistiness_score'
    ) THEN
        ALTER TABLE osm_all_roads ADD COLUMN twistiness_score DOUBLE PRECISION;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'osm_all_roads' AND column_name = 'twistiness_class'
    ) THEN
        ALTER TABLE osm_all_roads ADD COLUMN twistiness_class TEXT;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'osm_all_roads' AND column_name = 'meters_sharp'
    ) THEN
        ALTER TABLE osm_all_roads ADD COLUMN meters_sharp DOUBLE PRECISION;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'osm_all_roads' AND column_name = 'meters_broad'
    ) THEN
        ALTER TABLE osm_all_roads ADD COLUMN meters_broad DOUBLE PRECISION;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'osm_all_roads' AND column_name = 'meters_straight'
    ) THEN
        ALTER TABLE osm_all_roads ADD COLUMN meters_straight DOUBLE PRECISION;
    END IF;
END $$;

UPDATE osm_all_roads AS o
SET
    twistiness_score = s.twistiness_score,
    twistiness_class = s.twistiness_class,
    meters_sharp = s.meters_sharp,
    meters_broad = s.meters_broad,
    meters_straight = s.meters_straight
FROM rs_curvature_way_summary AS s
WHERE o.osm_id = s.way_id;


