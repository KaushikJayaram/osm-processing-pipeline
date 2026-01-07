# RideSense OSM PBF Processing Pipeline V2

## Overview
This is a simplified version of the OSM processing pipeline focused exclusively on:
- **Local execution only** (no AWS/cloud support)
- **"New" mode only** (from scratch processing)
- Clean, maintainable code structure

This project automates the processing of OpenStreetMap (OSM) data to generate an **Augmented PBF File** with custom attributes that enhance routing for the RideSense application. The pipeline ensures the latest OSM data is used while incorporating custom road attributes such as **road classification, curvature classification, scenery attributes, and access permissions**.

## Prerequisites

1. **PostgreSQL with PostGIS**
   ```bash
   # Ubuntu/Debian
   sudo apt update
   sudo apt install postgresql postgresql-contrib postgis osm2pgsql
   
   # macOS
   brew install postgresql postgis osm2pgsql
   ```

2. **Python 3.8+**
   ```bash
   python3 --version
   ```

3. **Required Python packages** (install via requirements.txt)

## Setup

1. **Clone or navigate to the project directory**
   ```bash
   cd osm-file-processing-v2
   ```

2. **Set up Python virtual environment**
   
   This project uses the centralized virtual environment setup. From the project root:
   ```bash
   # Set up the venv (includes osmium which requires system dependencies)
   ./setup_venv.sh osm-file-processing-v2 osm-file-processing-v2/requirements.txt
   
   # Activate the venv
   source activate_venv.sh osm-file-processing-v2
   ```
   
   **Note**: The `osmium` package requires system dependencies (cmake, boost, expat, etc.). 
   If installation fails, run `./setup_osmium_deps.sh` first, then retry.
   
   See `README_VENV_SETUP.md` in the project root for more details.

3. **Configure environment**
   ```bash
   # Copy environment template
   cp .env.example .env
   
   # Edit .env with your database settings
   nano .env  # or use your preferred editor
   ```

4. **Download Required Data**
   - **GHSL Data**: Download from [GHSL Data Package 2023](https://drive.google.com/drive/folders/1QD4vOkC8G4Ja_yUMraY5KtBFdPdE-kz-?usp=drive_link)
     - Required file: `GHS_BUILT_S_E2030_GLOBE_R2023A_4326_30ss_V1_0.tif`
     - Place in `data/GHSL_data/` directory
   
   - **Population Data**: Download population density TIFF file
     - Required file: `ind_pd_2020_1km_UNadj.tif`
     - Place in `data/Population_data/` directory

## Running the Pipeline

Simply run:
```bash
# From project root, using the venv helper
./run_with_venv.sh osm-file-processing-v2 osm-file-processing-v2/main.py

# Or activate venv first
source activate_venv.sh osm-file-processing-v2
cd osm-file-processing-v2
python main.py
```

The pipeline consists of 4 main sections (each can be enabled/disabled via `PIPELINE_SECTIONS` in `main.py`):

1. **Download OSM PBF** (optional): Downloads latest India OSM data from Geofabrik
2. **Import to PostgreSQL** (optional): Uses osm2pgsql with Lua3 script to import OSM data. **Only run when importing a new PBF file.**
3. **Add Custom Tags**: Executes SQL scripts to calculate and assign custom attributes:
   - Road Classification (grid-based urban/semiurban/rural classification)
   - Road Curvature Classification v2 (with coordinate population)
   - Road Scenery Attributes
   - Road Access Permissions (rsbikeaccess)
   - Intersection Speed Degradation v2
   - Persona Scoring (MileMuncher, CornerCraver, TrailBlazer, TranquilTraveller)
4. **Write to PBF**: Writes calculated attributes back to a new augmented PBF file

## Pipeline Configuration

Sections can be enabled/disabled by editing `PIPELINE_SECTIONS` in `main.py`:

```python
PIPELINE_SECTIONS = {
    'download_osm': False,           # Downloads OSM PBF from Geofabrik
    'import_to_postgres': False,     # Imports PBF into PostgreSQL (only for new PBF)
    'add_custom_tags': True,          # Full custom tags pipeline (all 6 parts)
    'write_pbf': True,                # Writes augmented attributes back to PBF
}
```

## Configuration

All configuration is done via the `.env` file:

```env
# Database Configuration
DB_HOST=localhost
DB_NAME=ridesense_db
DB_USER=postgres
DB_PASSWORD=your_password
DB_PORT=5432

# File Paths
NEW_PBF_PATH=./osm_pbf_inputs/osm_pbf_new/india-latest.osm.pbf
OUTPUT_PBF_PATH=./osm_pbf_augmented_output/india-latest-augmented.osm.pbf
```

## Logging

The pipeline automatically logs all operations to timestamped log files in the `logs/` directory:
- `logs/main_pipeline_YYYYMMDD_HHMMSS.log` - Main pipeline execution log
- `logs/import_into_postgres_YYYYMMDD_HHMMSS.log` - OSM import log (when import section is enabled)
- `logs/add_custom_tags_YYYYMMDD_HHMMSS.log` - Custom tags processing log

Logs are written to both console and file, so you can monitor progress in real-time and review logs later even if the terminal closes.

## Output

The final augmented PBF file will be saved to the path specified in `OUTPUT_PBF_PATH` (default: `./osm_pbf_augmented_output/india-latest-augmented.osm.pbf`).

## Custom Attributes

The pipeline adds the following custom attributes to roads:

- **Road Classification**:
  - `road_setting_i1` - Setting derived from grid overlap. Values: `Urban`, `SemiUrban`, `Rural`
  - `road_type_i1` - Type derived from `highway` + `ref`. Values: `NH`, `SH`, `MDR`, `OH`, `HAdj`, `Track`, `Path`, `WoH`
  - `road_classification_i1` - Derived as `road_setting_i1 || road_type_i1` (e.g., `RuralSH`). Values:
    - `UrbanNH`, `UrbanSH`, `UrbanMDR`, `UrbanOH`, `UrbanHAdj`, `UrbanTrack`, `UrbanPath`, `UrbanWoH`
    - `SemiUrbanNH`, `SemiUrbanSH`, `SemiUrbanMDR`, `SemiUrbanOH`, `SemiUrbanHAdj`, `SemiUrbanTrack`, `SemiUrbanPath`, `SemiUrbanWoH`
    - `RuralNH`, `RuralSH`, `RuralMDR`, `RuralOH`, `RuralHAdj`, `RuralTrack`, `RuralPath`, `RuralWoH`
  - `road_classification` - Legacy 3-bucket. Values: `NH`, `SH`, `UNKNOWN`
  - `road_classification_v2` - Coarser bucket used for downstream display/bucketing. Values: `NH`, `SH`, `Urban`, `Service`, `Interior`
- **Curvature v2**: 
  - `meters_sharp`, `meters_broad`, `meters_straight` - Curvature buckets in meters
  - `twistiness_score` - Numeric twistiness score
  - `twistiness_class` - Classification: `straight`, `broad`, `sharp`
- **Scenery**: `road_scenery_urban`, `road_scenery_semiurban`, `road_scenery_rural`, `road_scenery_forest`, `road_scenery_hill`, `road_scenery_lake`, `road_scenery_beach`, `road_scenery_river`, `road_scenery_desert`, `road_scenery_field`, `road_scenery_saltflat`, `road_scenery_mountainpass`, `road_scenery_snowcappedmountain`, `road_scenery_plantation`, `road_scenery_backwater`
- **Access**: `rsbikeaccess` - Bike access permission flag
- **Intersection Speed Degradation v2**: 
  - `intersection_speed_degradation_base` - Base degradation (0.0-0.5)
  - `intersection_speed_degradation_setting_adjusted` - Adjusted for urban/semiurban/rural
  - `intersection_speed_degradation_final` - Final multiplier (0.5-1.0) for GraphHopper
- **Persona Scoring**: 
  - `persona_milemuncher_score`, `persona_cornercraver_score`, `persona_trailblazer_score`, `persona_tranquiltraveller_score` - Scores for each persona (0-100)
- **Environment**: `build_perc`, `population_density`

### What gets written into the augmented PBF
`scripts/write_tags_to_pbf_2.py` writes DB columns back into the augmented PBF as **OSM way tags** using the **same key name as the column** (e.g., column `road_type_i1` → tag `road_type_i1`).

## Performance Considerations

- Processing large OSM PBF files can be **memory-intensive**. It is recommended to run this on a machine with at least **16GB RAM**.
- The pipeline processes all of India's OSM data, which can take several hours depending on your hardware.
- Logs are automatically saved, so you can safely close the terminal and check progress later.

## Troubleshooting

1. **Database Connection Issues**
   - Verify PostgreSQL is running: `sudo systemctl status postgresql` (Linux) or `brew services list` (macOS)
   - Check database credentials in `.env` file
   - Ensure PostGIS extension is installed: `psql -d your_db -c "CREATE EXTENSION IF NOT EXISTS postgis;"`

2. **Missing Data Files**
   - Ensure GHSL and Population data files are in the correct directories
   - Check file paths in `add_custom_tags.py` if using custom locations

3. **Memory Issues**
   - Reduce osm2pgsql cache size in `import_into_postgres.py` (default: 16384 MB)
   - Close other applications to free up RAM

4. **Log Files**
   - Check `logs/` directory for detailed error messages
   - Logs persist even if the terminal closes

## Project Structure

```
osm-file-processing-v2/
├── main.py                    # Main entry point with section toggles
├── requirements.txt           # Python dependencies
├── .env.example              # Environment template
├── README.md                 # This file
├── scripts/
│   ├── download_osm_pbf.py
│   ├── import_into_postgres.py
│   ├── add_custom_tags.py    # Orchestrates all 6 custom tag parts
│   ├── write_tags_to_pbf_2.py # Writes augmented attributes to PBF
│   ├── Lua3_RouteProcessing_with_curvature.lua  # OSM import Lua script
│   └── rerun_road_classification_and_dependencies.py  # Standalone re-run script
├── sql/
│   ├── road_classification/   # Road classification (Part 1)
│   ├── road_curvature_v2/     # Curvature v2 (Part 2, includes coordinate population)
│   ├── road_scenery/          # Scenery attributes (Part 3)
│   ├── road_access/           # Bike access (Part 4)
│   ├── road_intersection_density/  # Intersection speed degradation v2 (Part 5)
│   └── road_persona/          # Persona scoring (Part 6)
├── legacy-code/               # Archived old/obsolete scripts
├── data/
│   ├── GHSL_data/            # Place GHSL TIFF files here
│   └── Population_data/      # Place population TIFF files here
└── logs/                     # Auto-created log files
```

## Important Notes

- **Import Step**: Only run `import_to_postgres` when importing a **new PBF file**. For iterative development, skip this step.
- **Coordinate Population**: Node coordinates in `rs_highway_way_nodes` are automatically populated as part of the curvature workflow (idempotent, skips if >95% already populated).
- **Section Toggles**: Use `PIPELINE_SECTIONS` in `main.py` to enable/disable specific sections without commenting out code.
- **Standalone Scripts**: For re-running specific parts, use `scripts/rerun_road_classification_and_dependencies.py` or create similar scripts.
- **Legacy Code**: Old/obsolete scripts have been moved to `legacy-code/` directory for reference.

## Large files & Git

This repo intentionally does **not** commit large/binary artifacts:
- **Rasters** (`data/**/*.tif`, `data/**/*.pdf`) are ignored; download them separately as described above.
- **OSM PBFs** (`osm_pbf_inputs/`, `osm_pbf_augmented_output/`, `*.pbf`) are ignored; they’re generated/downloaded locally.

