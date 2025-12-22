#!/usr/bin/env python3

import os
import requests

def download_osm_pbf(url: str, output_path: str, overwrite: bool = False) -> None:
    """
    Download an OSM PBF file from the given URL and save it to 'output_path'.

    :param url: The URL of the OSM PBF file (e.g. a Geofabrik link).
    :param output_path: Local file path where the PBF should be saved.
    :param overwrite: If True, overwrite existing file at output_path.
    """
    # 1. Check if file already exists
    if os.path.exists(output_path):
        if not overwrite:
            print(f"[download_osm_pbf] File already exists at {output_path}. Skipping download.")
            return
        else:
            print(f"[download_osm_pbf] Overwriting existing file at {output_path}...")

    print(f"[download_osm_pbf] Downloading from {url}...")
    response = requests.get(url, stream=True)
    response.raise_for_status()  # Raises an HTTPError if the response is not 200 OK

    # 2. Stream download in chunks
    with open(output_path, 'wb') as file_out:
        chunk_size = 1024 * 1024  # 1 MB chunks
        for chunk in response.iter_content(chunk_size=chunk_size):
            if chunk:  # filter out keep-alive new chunks
                file_out.write(chunk)

    print(f"[download_osm_pbf] Download complete. File saved to {output_path}")


# Example standalone usage:
if __name__ == "__main__":
    # Just a demo call:
    # download_osm_pbf(
    #     url="https://download.geofabrik.de/asia/india-latest.osm.pbf",
    #     output_path="./india-latest.osm.pbf"
    # )
    pass
