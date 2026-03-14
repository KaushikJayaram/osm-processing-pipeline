-- ============================================================================
-- DEPRECATED: This file has been split into two separate files
-- ============================================================================
-- 
-- The scoring logic is now split into:
--   1. 01_compute_parameter_scores.sql - Computes 8 parameter scores
--   2. 02_compute_persona_scores.sql   - Computes 4 persona scores
--
-- This file is kept for backwards compatibility but should not be used.
-- Please update your runner to use the new files.
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'DEPRECATED: This file has been replaced by:';
    RAISE NOTICE '  - 01_compute_parameter_scores.sql';
    RAISE NOTICE '  - 02_compute_persona_scores.sql';
    RAISE NOTICE 'Please update your runner configuration.';
    RAISE NOTICE '============================================================================';
END $$;
