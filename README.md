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

2. **Install Python dependencies**
   ```bash
   pip install -r requirements.txt
   ```

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
python main.py
```

The pipeline will:
1. Download the latest OSM PBF file for India (if not already present)
2. Import the PBF into PostgreSQL using osm2pgsql
3. Apply custom road attributes via SQL scripts:
   - Road Classification
   - Road Curvature Classification
   - Road Scenery Attributes
   - Road Access Permissions
4. Write the augmented attributes back to a new PBF file

## Pipeline Steps

1. **Download OSM PBF**: Downloads latest India OSM data from Geofabrik
2. **Import to Postgres**: Uses osm2pgsql with custom Lua script to import OSM data
3. **Add Custom Tags**: Executes SQL scripts to calculate and assign custom attributes
4. **Write to PBF**: Writes calculated attributes back to the original PBF file

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
- **MDR Classification (optional, DB)**: `mdr`, `maybe_mdr_primary`, `maybe_mdr_secondary`, `final_mdr_status` (from `sql/road_classification/09_add_mdr.sql`)
- **Curvature**: `road_curvature_classification`, `road_curvature_ratio`
- **Scenery**: `road_scenery_urban`, `road_scenery_semiurban`, `road_scenery_rural`, `road_scenery_forest`, `road_scenery_hill`, `road_scenery_lake`, `road_scenery_beach`, `road_scenery_river`, `road_scenery_desert`, `road_scenery_field`, `road_scenery_saltflat`, `road_scenery_mountainpass`, `road_scenery_snowcappedmountain`, `road_scenery_plantation`, `road_scenery_backwater`
- **Access**: `rsbikeaccess`
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
├── main.py                    # Main entry point
├── requirements.txt           # Python dependencies
├── .env.example              # Environment template
├── README.md                 # This file
├── scripts/
│   ├── download_osm_pbf.py
│   ├── import_into_postgres.py
│   ├── add_custom_tags.py
│   ├── write_tags_to_pbf.py
│   └── Lua2_RouteProcessing.lua
├── sql/
│   ├── road_classification/
│   ├── road_curvature_classification/
│   ├── road_scenery/
│   └── road_access/
├── data/
│   ├── GHSL_data/            # Place GHSL TIFF files here
│   └── Population_data/      # Place population TIFF files here
└── logs/                     # Auto-created log files
```

## Notes

- This is a simplified version focused on local execution and "new" mode only
- All optimizations and improvements from v1 are preserved
- File-based logging ensures logs persist even if Cursor/terminal closes
- The pipeline is designed to be run from scratch each time (no merge mode)

## Large files & Git

This repo intentionally does **not** commit large/binary artifacts:
- **Rasters** (`data/**/*.tif`, `data/**/*.pdf`) are ignored; download them separately as described above.
- **OSM PBFs** (`osm_pbf_inputs/`, `osm_pbf_augmented_output/`, `*.pbf`) are ignored; they’re generated/downloaded locally.

