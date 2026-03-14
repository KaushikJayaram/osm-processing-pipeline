-- ============================================================================
-- ONE-TIME SCRIPT: Add persona v2 scoring columns to osm_all_roads
-- ============================================================================
-- This adds the parameter score columns and persona score columns 
-- needed for the v2 persona framework
-- ============================================================================

-- Add 8 core parameter score columns (0-1 scale)
ALTER TABLE osm_all_roads
    ADD COLUMN IF NOT EXISTS score_urban_gate NUMERIC(5, 4),
    ADD COLUMN IF NOT EXISTS score_cruise_road NUMERIC(5, 4),
    ADD COLUMN IF NOT EXISTS score_offroad NUMERIC(5, 4),
    ADD COLUMN IF NOT EXISTS score_calm_road NUMERIC(5, 4),
    ADD COLUMN IF NOT EXISTS score_flow NUMERIC(5, 4),
    ADD COLUMN IF NOT EXISTS score_remoteness NUMERIC(5, 4),
    ADD COLUMN IF NOT EXISTS score_twist NUMERIC(5, 4);

-- Add 3 persona-specific scenic score columns (0-1 scale)
ALTER TABLE osm_all_roads
    ADD COLUMN IF NOT EXISTS score_scenic_wild NUMERIC(5, 4),
    ADD COLUMN IF NOT EXISTS score_scenic_serene NUMERIC(5, 4),
    ADD COLUMN IF NOT EXISTS score_scenic_fast NUMERIC(5, 4);

-- Add 4 persona score columns (0-1 scale)
ALTER TABLE osm_all_roads
    ADD COLUMN IF NOT EXISTS persona_milemuncher_score NUMERIC(5, 4),
    ADD COLUMN IF NOT EXISTS persona_cornercraver_score NUMERIC(5, 4),
    ADD COLUMN IF NOT EXISTS persona_trailblazer_score NUMERIC(5, 4),
    ADD COLUMN IF NOT EXISTS persona_tranquiltraveller_score NUMERIC(5, 4);

-- Add 4 normalized persona score columns (0-1 scale)
ALTER TABLE osm_all_roads
    ADD COLUMN IF NOT EXISTS persona_milemuncher_score_normalised NUMERIC(5, 4),
    ADD COLUMN IF NOT EXISTS persona_cornercraver_score_normalised NUMERIC(5, 4),
    ADD COLUMN IF NOT EXISTS persona_trailblazer_score_normalised NUMERIC(5, 4),
    ADD COLUMN IF NOT EXISTS persona_tranquiltraveller_score_normalised NUMERIC(5, 4);

-- Add comments for parameter scores
COMMENT ON COLUMN osm_all_roads.score_urban_gate IS 
    'Urban gate filter (0/1). 0 if road_scenery_urban=1, else 1.';
COMMENT ON COLUMN osm_all_roads.score_cruise_road IS 
    'Cruise road score (0-1). High for highways and major roads.';
COMMENT ON COLUMN osm_all_roads.score_offroad IS 
    'Off-road score (0-1). High for tracks, paths, and rural roads.';
COMMENT ON COLUMN osm_all_roads.score_calm_road IS 
    'Calm road score (0-1). High for peaceful, low-traffic roads.';
COMMENT ON COLUMN osm_all_roads.score_flow IS 
    'Flow score (0-1). Based on intersection speed degradation.';
COMMENT ON COLUMN osm_all_roads.score_remoteness IS 
    'Remoteness score (0-1). Inverse of reinforced_pressure.';
COMMENT ON COLUMN osm_all_roads.score_twist IS 
    'Twistiness score (0-1). Normalized from twistiness_score with hill factor.';
COMMENT ON COLUMN osm_all_roads.score_scenic_wild IS 
    'Wild scenic score (0-1). For TrailBlazer: emphasizes forest, hills, remote nature.';
COMMENT ON COLUMN osm_all_roads.score_scenic_serene IS 
    'Serene scenic score (0-1). For TranquilTraveller: emphasizes lakes, calm water features.';
COMMENT ON COLUMN osm_all_roads.score_scenic_fast IS 
    'Fast scenic score (0-1). For MileMuncher/CornerCraver: emphasizes dramatic features.';

-- Add comments for persona scores
COMMENT ON COLUMN osm_all_roads.persona_milemuncher_score IS 
    'Persona V2 score (0-1) for MileMuncher. Prefers highways, flow, minimal twists.';
COMMENT ON COLUMN osm_all_roads.persona_cornercraver_score IS 
    'Persona V2 score (0-1) for CornerCraver. Prefers twisty, technical roads.';
COMMENT ON COLUMN osm_all_roads.persona_trailblazer_score IS 
    'Persona V2 score (0-1) for TrailBlazer. Prefers offroad, remote, scenic routes.';
COMMENT ON COLUMN osm_all_roads.persona_tranquiltraveller_score IS 
    'Persona V2 score (0-1) for TranquilTraveller. Prefers calm, scenic, peaceful roads.';

-- Add comments for normalized persona scores
COMMENT ON COLUMN osm_all_roads.persona_milemuncher_score_normalised IS 
    'Normalized MileMuncher score (0-1). Stretched using global min/max for better distribution.';
COMMENT ON COLUMN osm_all_roads.persona_cornercraver_score_normalised IS 
    'Normalized CornerCraver score (0-1). Stretched using global min/max for better distribution.';
COMMENT ON COLUMN osm_all_roads.persona_trailblazer_score_normalised IS 
    'Normalized TrailBlazer score (0-1). Stretched using global min/max for better distribution.';
COMMENT ON COLUMN osm_all_roads.persona_tranquiltraveller_score_normalised IS 
    'Normalized TranquilTraveller score (0-1). Stretched using global min/max for better distribution.';