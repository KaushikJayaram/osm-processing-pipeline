# Road Scenery V2 (ESA WorldCover 2020)

This module implements scenery classification using the ESA WorldCover 2020 map (downsampled to 50m).

## Prerequisites
- PostGIS with Raster support enabled (`postgis_raster` extension).
- `raster2pgsql` command line tool.
- Input data: `worldcover_2020_india_50m_ESRI54009_cog.tif` (SRID 54009).

## Run Order

1.  **Ingest Raster**:
    Run `osm-processing-pipeline/scripts/dev-runs/scenery_v2_run.py`.
    (The script handles raster ingestion automatically if needed).

2.  **Schema Migration**:
    Run `01_worldcover_schema.sql`.

3.  **Sampling**:
    Run `02_worldcover_sampling.sql`.
    (This is the heavy step. Expect 30-60 mins for full India).

4.  **Classification**:
    Run `03_scenery_v2_classify.sql`.
    (Fast, ~1-2 mins).

5.  **Validation**:
    Run `04_qc_samples.sql`.

## Common Failure Modes
1.  **SRID Mismatch**: If raster is not EPSG:54009, sampling will return 0 matches. The ingest logic forces `-s 54009`, but ensure the input file is projected correctly or compatible.
2.  **Raster Import Size**: Importing large TIFs can fail if disk space is low or DB temp space is small. Use tiling `-t 256x256` (default in script).
3.  **Missing Tools**: If `raster2pgsql` is not in PATH, ingest will fail.

## Logic Overview
- **Buffers**: 25m buffer around roads (EPSG:54009).
- **Classes**:
    - Forest: Tree cover (10), Mangroves (95)
    - Field: Shrubland (20), Grassland (30), Cropland (40)
    - Desert: Bare/sparse (60)
    - Snow: Snow/ice (70)
    - Water: Permanent water (80)
- **Classification**:
    - Urban/SemiUrban tags from `road_scenery_urban` take precedence.
    - Otherwise, dominant fraction (>= 0.35) determines `scenery_v2_primary`.
    - Secondary tags set if fraction >= 0.20.
