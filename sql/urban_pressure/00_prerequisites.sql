-- Urban pressure prerequisites and sanity checks.
-- This script is read-only; it does not modify schema or data.

-- PostGIS version and raster capability checks.
SELECT postgis_full_version() AS postgis_full_version;

-- Confirm PostGIS extension is installed.
SELECT EXISTS (
    SELECT 1
    FROM pg_extension
    WHERE extname = 'postgis'
) AS postgis_extension_installed;

-- Check expected tables.
SELECT to_regclass('public.ghs_pop_e2030_r2023a_54009_100') IS NOT NULL
    AS has_ghs_pop_table;
SELECT to_regclass('public.ghs_built_s_e2030_r2023a_54009_100') IS NOT NULL
    AS has_ghs_built_table;
SELECT to_regclass('public.india_grids_54009') IS NOT NULL
    AS has_india_grids_54009;
