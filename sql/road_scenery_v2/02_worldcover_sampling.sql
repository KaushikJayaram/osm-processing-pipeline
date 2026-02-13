-- 02_worldcover_sampling.sql
-- Samples WorldCover 2020 raster data for each road using a 25m buffer.
-- Single-statement UPDATE to allow chunked execution.

WITH road_buffers AS MATERIALIZED (
    -- Buffer roads in EPSG:3857 by 25m (uses precomputed geom_3857)
    SELECT 
        r.osm_id, 
        ST_Buffer(r.geom_3857, 25) AS geom_buf
    FROM osm_all_roads r
    JOIN public.osm_all_roads_grid rg
      ON rg.osm_id = r.osm_id
    WHERE rg.grid_id BETWEEN :grid_id_min AND :grid_id_max
),
raster_stats AS (
    SELECT 
        rb.osm_id,
        (pvc).value AS pixel_val,
        (pvc).count AS pixel_count
    FROM road_buffers rb
    JOIN rs_worldcover_2020_50m r
    ON ST_ConvexHull(r.rast) && rb.geom_buf
    AND ST_Intersects(ST_ConvexHull(r.rast), rb.geom_buf)
    , LATERAL ST_ValueCount(
        ST_Clip(r.rast, rb.geom_buf), -- Clip raster to buffer
        1, -- band 1
        true -- exclude nodata
    ) AS pvc
),
aggregated_stats AS (
    SELECT 
        osm_id,
        -- Mapping:
        -- 10 Tree cover, 95 Mangroves -> Forest
        SUM(CASE WHEN pixel_val IN (10, 95) THEN pixel_count ELSE 0 END) AS forest_px,
        -- 20 Shrubland, 30 Grassland, 40 Cropland -> Field
        SUM(CASE WHEN pixel_val IN (20, 30, 40) THEN pixel_count ELSE 0 END) AS field_px,
        -- 60 Bare/sparse -> Desert
        SUM(CASE WHEN pixel_val = 60 THEN pixel_count ELSE 0 END) AS desert_px,
        -- 70 Snow/ice -> Snow
        SUM(CASE WHEN pixel_val = 70 THEN pixel_count ELSE 0 END) AS snow_px,
        -- 80 Permanent water -> Water
        SUM(CASE WHEN pixel_val = 80 THEN pixel_count ELSE 0 END) AS water_px,
        
        -- Total valid pixels (excluding ignored classes 50, 90, 100)
        SUM(CASE WHEN pixel_val IN (10, 95, 20, 30, 40, 60, 70, 80) THEN pixel_count ELSE 0 END) AS total_px
    FROM raster_stats
    GROUP BY osm_id
),
final_stats AS (
    SELECT 
        osm_id,
        forest_px,
        field_px,
        desert_px,
        snow_px,
        water_px,
        total_px,
        -- Calculate fractions
        CASE WHEN total_px > 0 THEN forest_px::REAL / total_px ELSE 0 END AS forest_frac,
        CASE WHEN total_px > 0 THEN field_px::REAL / total_px ELSE 0 END AS field_frac,
        CASE WHEN total_px > 0 THEN desert_px::REAL / total_px ELSE 0 END AS desert_frac,
        CASE WHEN total_px > 0 THEN snow_px::REAL / total_px ELSE 0 END AS snow_frac,
        CASE WHEN total_px > 0 THEN water_px::REAL / total_px ELSE 0 END AS water_frac
    FROM aggregated_stats
)
UPDATE osm_all_roads r
SET 
    wc_total_px = s.total_px,
    wc_forest_px = s.forest_px,
    wc_field_px = s.field_px,
    wc_desert_px = s.desert_px,
    wc_snow_px = s.snow_px,
    wc_water_px = s.water_px,
    wc_forest_frac = s.forest_frac,
    wc_field_frac = s.field_frac,
    wc_desert_frac = s.desert_frac,
    wc_snow_frac = s.snow_frac,
    wc_water_frac = s.water_frac
FROM final_stats s
WHERE r.osm_id = s.osm_id;
