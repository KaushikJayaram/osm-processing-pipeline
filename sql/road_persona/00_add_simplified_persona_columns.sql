-- ============================================================================
-- ONE-TIME SCRIPT: Add simplified persona scoring columns to osm_all_roads
-- ============================================================================
-- This adds ONLY the base_score columns needed for the simplified framework
-- No corridor_km or final_score columns (Phase 1 only)
--
-- Run this AFTER dropping all old persona columns
-- ============================================================================

-- Add base score columns for each persona (0-100 scale, NULL if not scored)
ALTER TABLE osm_all_roads
    ADD COLUMN IF NOT EXISTS persona_milemuncher_base_score NUMERIC(5, 2),
    ADD COLUMN IF NOT EXISTS persona_cornercraver_base_score NUMERIC(5, 2),
    ADD COLUMN IF NOT EXISTS persona_trailblazer_base_score NUMERIC(5, 2),
    ADD COLUMN IF NOT EXISTS persona_tranquiltraveller_base_score NUMERIC(5, 2);

-- Add comments for documentation
COMMENT ON COLUMN osm_all_roads.persona_milemuncher_base_score IS 
    'Simplified persona score (0-100) for MileMuncher persona. NULL if not scored.';
COMMENT ON COLUMN osm_all_roads.persona_cornercraver_base_score IS 
    'Simplified persona score (0-100) for CornerCraver persona. NULL if not scored.';
COMMENT ON COLUMN osm_all_roads.persona_trailblazer_base_score IS 
    'Simplified persona score (0-100) for TrailBlazer persona. NULL if not scored.';
COMMENT ON COLUMN osm_all_roads.persona_tranquiltraveller_base_score IS 
    'Simplified persona score (0-100) for TranquilTraveller persona. NULL if not scored.';

-- Verify columns are added
DO $$
DECLARE
    v_added_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_added_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'osm_all_roads'
      AND column_name IN (
          'persona_milemuncher_base_score',
          'persona_cornercraver_base_score',
          'persona_trailblazer_base_score',
          'persona_tranquiltraveller_base_score'
      );
    
    IF v_added_count = 4 THEN
        RAISE NOTICE 'SUCCESS: All 4 simplified persona base_score columns added successfully.';
    ELSE
        RAISE NOTICE 'WARNING: Expected 4 columns, found %. Check manually.', v_added_count;
    END IF;
END $$;

