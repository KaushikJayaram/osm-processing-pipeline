#!/usr/bin/env python3

"""
One-time runner: export selected columns from `osm_all_roads` as OSM way tags into a new PBF.

This wraps `scripts/write_tags_to_pbf_2.py` and provides:
- CLI args for input/output
- .env-driven DB config
- timestamped logs in `<osm-processing-pipeline>/logs/`

Default paths are set to the user-provided India PBF and output folder.
"""

import argparse
import logging
import os
import sys
from datetime import datetime

from dotenv import load_dotenv


# ----------------------------------------------------------------------------
# Path helpers (match other dev-runs patterns)
# ----------------------------------------------------------------------------
def get_pipeline_base_dir() -> str:
    # script is in scripts/dev-runs, so up 2 levels is osm-processing-pipeline
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.dirname(os.path.dirname(script_dir))


def resolve_path(path: str) -> str:
    base_dir = get_pipeline_base_dir()
    if os.path.isabs(path):
        return path
    if path.startswith("./"):
        path = path[2:]
    return os.path.join(base_dir, path)


# ----------------------------------------------------------------------------
# Logging
# ----------------------------------------------------------------------------
def setup_logging():
    log_dir = resolve_path("logs")
    os.makedirs(log_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"write_tags_to_pbf_run_{timestamp}.log")

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
        handlers=[
            logging.FileHandler(log_file, mode="a", encoding="utf-8"),
            logging.StreamHandler(),
        ],
        force=True,
    )
    logger = logging.getLogger(__name__)
    logger.info("Logging initialized. Log file: %s", log_file)
    return logger, log_file


logger, log_file = setup_logging()


# ----------------------------------------------------------------------------
# CLI
# ----------------------------------------------------------------------------
DEFAULT_INPUT_PBF = (
    "/Users/kaushikjayaram/RideSense/Codebase/LocationIntelligence/osm-processing-pipeline/osm_pbf_augmented_output/india-latest-augmented_14012026_with_db_tags_20260305_085758.osm.pbf"
)
DEFAULT_OUTPUT_DIR = (
    "/Users/kaushikjayaram/RideSense/Codebase/LocationIntelligence/"
    "osm-processing-pipeline/osm_pbf_augmented_output"
)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Write extra tags from PostGIS (osm_all_roads) into a new OSM PBF."
    )
    parser.add_argument(
        "--input-pbf",
        default=DEFAULT_INPUT_PBF,
        help="Input .osm.pbf file path (default: India augmented PBF).",
    )
    parser.add_argument(
        "--output-dir",
        default=DEFAULT_OUTPUT_DIR,
        help="Directory to write output .osm.pbf file into.",
    )
    parser.add_argument(
        "--output-pbf",
        default=None,
        help="Optional full output .osm.pbf path. If set, overrides --output-dir.",
    )
    return parser.parse_args()


def build_output_path(args) -> str:
    if args.output_pbf:
        return args.output_pbf

    os.makedirs(args.output_dir, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    base = os.path.basename(args.input_pbf)
    if base.endswith(".osm.pbf"):
        base = base[: -len(".osm.pbf")]
    filename = f"{base}_with_db_tags_{ts}.osm.pbf"
    return os.path.join(args.output_dir, filename)


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
def main():
    args = parse_args()
    load_dotenv(override=True)

    # Make scripts/ importable (write_tags_to_pbf_2.py lives in osm-processing-pipeline/scripts/)
    scripts_dir = os.path.join(get_pipeline_base_dir(), "scripts")
    if scripts_dir not in sys.path:
        sys.path.insert(0, scripts_dir)

    try:
        import write_tags_to_pbf_2  # type: ignore
    except Exception as e:
        logger.error("Failed to import write_tags_to_pbf_2 from %s: %s", scripts_dir, e)
        raise

    db_config = {
        "host": os.getenv("DB_HOST", "localhost"),
        "name": os.getenv("DB_NAME", "ridesense"),
        "user": os.getenv("DB_USER", "postgres"),
        "password": os.getenv("DB_PASSWORD", "postgres"),
        "port": int(os.getenv("DB_PORT", "5432")),
        # write_tags_to_pbf expects this key:
        "new_pbf_path": args.input_pbf,
    }

    out_pbf = build_output_path(args)

    logger.info("Input PBF: %s", args.input_pbf)
    logger.info("Output PBF: %s", out_pbf)
    logger.info("DB: %s@%s:%s/%s", db_config["user"], db_config["host"], db_config["port"], db_config["name"])

    if not os.path.exists(args.input_pbf):
        raise FileNotFoundError(f"Input PBF not found: {args.input_pbf}")

    write_tags_to_pbf_2.write_tags_to_pbf(db_config=db_config, output_pbf_path=out_pbf)

    logger.info("Done. Output written to: %s", out_pbf)
    logger.info("Full log saved to: %s", log_file)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        logger.error("Fatal error: %s", e, exc_info=True)
        sys.exit(1)

