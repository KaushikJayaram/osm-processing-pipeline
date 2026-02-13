# GHSL Urban Pressure (Development Module)

This module computes grid-level population and built-up aggregates from GHSL R2023A 100m rasters, then derives `urban_pressure` and `reinforced_pressure` for `public.india_grids`.

## Data Sources (Local Paths)

The raster files are already available in the data folder:

- `/Users/kaushikjayaram/RideSense/Codebase/LocationIntelligence/osm-processing-pipeline/data/GHSL_data/GHS_POP_E2030_GLOBE_R2023A_54009_100_V1_0.tif`
- `/Users/kaushikjayaram/RideSense/Codebase/LocationIntelligence/osm-processing-pipeline/data/GHSL_data/GHS_BUILT_S_E2030_GLOBE_R2023A_54009_100_V1_0.tif`

These are loaded into PostGIS as:

- `public.ghs_pop_e2030_r2023a_54009_100`
- `public.ghs_built_s_e2030_r2023a_54009_100`

The load is idempotent: if the table exists, import is skipped.

## Tunable Parameters

These are defined at the top of `scripts/dev-runs/urban_pressure_run.py` and passed into SQL.

### Test Bounds (Development Phase)

Initial runs are restricted to a smaller bounding box. For full India, update the bounds in `urban_pressure_run.py` and recreate `public.india_grids_54009`.

| Parameter | Test Value | Description |
|-----------|------------|-------------|
| `LAT_MIN` | 6.5 | Southern latitude bound |
| `LAT_MAX` | 35.5 | Northern latitude bound |
| `LON_MIN` | 68 | Western longitude bound |
| `LON_MAX` | 97.5 | Eastern longitude bound |

### Processing Parameters

| Parameter | Default | Unit | Description |
|-----------|---------|------|-------------|
| `PD_SAT` | 50000 | people/km² | Population density saturation threshold for normalization |
| `NEIGHBOR_RADIUS` | 5000 | meters | Radius for spatial smoothing of urban pressure |
| `RASTER_TILE_SIZE` | 256 | pixels | Raster tile size for `raster2pgsql` |
| `CHUNK_SIZE` | 50000 | rows | Grid_id chunk size for heavy updates |
| `URBAN_THRESHOLD` | 0.25 | 0-1 | Threshold for `urban_class = urban` |
| `SEMI_URBAN_THRESHOLD` | 0.10 | 0-1 | Lower bound for `urban_class = semi_urban` |

## Scripts (Dev Runs)

`scripts/dev-runs/urban_pressure_run.py`
- Imports rasters (if tables do not exist).
- Creates `public.india_grids_54009` (if it does not exist) filtered by test bounds.
- Executes SQL scripts in order to compute all target columns.
- Logs to `osm-processing-pipeline/logs/urban_pressure_run_<timestamp>.log`.

`scripts/dev-runs/urban_pressure_validate.py`
- Runs `99_validation_queries.sql` and logs results.
- Logs to `osm-processing-pipeline/logs/urban_pressure_validate_<timestamp>.log`.

## SQL Script Order

1. `00_prerequisites.sql`
2. `01_create_india_grids_54009.sql`
3. `02_add_target_columns.sql`
4. `03_zonal_pop_count_chunked.sql` (full India)
5. `04_zonal_built_up_chunked.sql` (full India)
6. `05_compute_urban_pressure.sql`
7. `06_compute_reinforced_pressure_chunked.sql` (full India)
8. `07_classify_urban_class.sql`
9. `99_validation_queries.sql` (via validation script)

## Notes

- `public.india_grids_54009` is recreated when `RECREATE_INDIA_GRIDS_54009 = True`.
- Full-India runs use chunked SQL for heavy steps; adjust `CHUNK_SIZE` as needed.
