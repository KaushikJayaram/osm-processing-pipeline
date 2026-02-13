import os
import sys
import logging
from datetime import datetime

def get_project_root():
    """
    Finds the project root directory.
    Assumes the script is running somewhere inside the project.
    Walks up until it finds 'venv_plan.md' (repo root marker) or '.venv'.
    """
    current_dir = os.path.dirname(os.path.abspath(__file__))
    
    p = current_dir
    while p != "/" and p != os.path.dirname(p):
        if os.path.exists(os.path.join(p, "venv_plan.md")):
            return p
        if os.path.exists(os.path.join(p, ".venv")):
            return p
        p = os.path.dirname(p)
    
    # Fallback: assume we are in <root>/osm-processing-pipeline/scripts/utils.py
    return os.path.abspath(os.path.join(current_dir, "../../.."))

def get_pipeline_base_dir():
    """
    Get the base directory of the pipeline (osm-processing-pipeline).
    Assumes this file is in osm-processing-pipeline/scripts/utils.py
    """
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def resolve_project_path(path):
    """
    Resolve a path relative to the pipeline base directory (osm-processing-pipeline).
    If path starts with ./, it's relative to CWD (or maybe pipeline root?).
    The original scripts assumed relative to osm-processing-pipeline root.
    """
    base_dir = get_pipeline_base_dir()
    
    if os.path.isabs(path):
        return path
    
    if path.startswith('./'):
        path = path[2:]
        
    return os.path.join(base_dir, path)

def setup_logging(script_name=None):
    """
    Setup logging to both console and file in the project root 'logs' folder.
    """
    project_root = get_project_root()
    log_dir = os.path.join(project_root, "logs")
    os.makedirs(log_dir, exist_ok=True)
    
    if not script_name:
        script_name = os.path.splitext(os.path.basename(sys.argv[0]))[0]
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(log_dir, f"{script_name}_{timestamp}.log")
    
    # Configure root logger
    root_logger = logging.getLogger()
    
    # Remove existing handlers to avoid duplication if setup_logging called multiple times
    for h in root_logger.handlers[:]:
        root_logger.removeHandler(h)

    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file, mode='a', encoding='utf-8'),
            logging.StreamHandler()
        ],
        force=True # Force reconfiguration
    )
    
    logging.info(f"Logging initialized. Log file: {log_file}")
    return log_file
