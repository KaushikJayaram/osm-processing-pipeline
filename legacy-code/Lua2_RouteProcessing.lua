local tables = {}

tables.rs_forest = osm2pgsql.define_way_table('rs_forest', {
    { column = 'osm_id', type = 'bigint' },
    { column = 'name', type = 'text' },
    { column = 'natural', type = 'text' },
    { column = 'landuse', type = 'text' },
    { column = 'entity_type', type = 'text' },
    { column = 'geometry', type = 'geometry', projection = 4326 },
    { column = 'tags', type = 'hstore' }
})

tables.rs_hills_nodes = osm2pgsql.define_node_table('rs_hills_nodes', {
    { column = 'osm_id', type = 'bigint' },
    { column = 'name', type = 'text' },
    { column = 'natural', type = 'text' },
    { column = 'entity_type', type = 'text' },
    { column = 'geometry', type = 'geometry', projection = 4326 },
    { column = 'tags', type = 'hstore' }
})

tables.rs_hills_relations = osm2pgsql.define_relation_table('rs_hills_relations', {
    { column = 'osm_id', type = 'bigint' },
    { column = 'name', type = 'text' },
    { column = 'natural', type = 'text' },
    { column = 'entity_type', type = 'text' },
    { column = 'geometry', type = 'geometry', projection = 4326, not_null = true },
    { column = 'tags', type = 'hstore' }
})

tables.rs_lakes = osm2pgsql.define_way_table('rs_lakes', {
    { column = 'osm_id', type = 'bigint' },
    { column = 'name', type = 'text' },
    { column = 'water', type = 'text' },
    { column = 'natural', type = 'text' },
    { column = 'entity_type', type = 'text' },
    { column = 'geometry', type = 'geometry', projection = 4326 },
    { column = 'tags', type = 'hstore' }
})

tables.rs_coastline = osm2pgsql.define_way_table('rs_coastline', {
    { column = 'osm_id', type = 'bigint' },
    { column = 'name', type = 'text' },
    { column = 'natural', type = 'text' },
    { column = 'entity_type', type = 'text' },
    { column = 'geometry', type = 'geometry', projection = 4326 },
    { column = 'tags', type = 'hstore' }
})

tables.rs_rivers = osm2pgsql.define_way_table('rs_rivers', {
    { column = 'osm_id', type = 'bigint' },
    { column = 'name', type = 'text' },
    { column = 'waterway', type = 'text' },
    { column = 'entity_type', type = 'text' },
    { column = 'geometry', type = 'geometry', projection = 4326 },
    { column = 'tags', type = 'hstore' }
})

tables.rs_desert = osm2pgsql.define_way_table('rs_desert', {
    { column = 'osm_id', type = 'bigint' },
    { column = 'name', type = 'text' },
    { column = 'natural', type = 'text' },
    { column = 'entity_type', type = 'text' },
    { column = 'geometry', type = 'geometry', projection = 4326 },
    { column = 'tags', type = 'hstore' }
})

tables.rs_fields = osm2pgsql.define_way_table('rs_fields', {
    { column = 'osm_id', type = 'bigint' },
    { column = 'name', type = 'text' },
    { column = 'landuse', type = 'text' },
    { column = 'natural', type = 'text' },
    { column = 'entity_type', type = 'text' },
    { column = 'geometry', type = 'geometry', projection = 4326 },
    { column = 'tags', type = 'hstore' }
})

tables.rs_mountain_pass = osm2pgsql.define_node_table('rs_mountain_pass', {
    { column = 'osm_id', type = 'bigint' },
    { column = 'name', type = 'text' },
    { column = 'mountain_pass', type = 'text' },
    { column = 'entity_type', type = 'text' },
    { column = 'geometry', type = 'geometry', projection = 4326 },
    { column = 'tags', type = 'hstore' }
})

tables.rs_india_bounds = osm2pgsql.define_relation_table('rs_india_bounds', {
    { column = 'osm_id', type = 'bigint' },
    { column = 'name', type = 'text' },
    { column = 'boundary', type = 'text' },
    { column = 'admin_level', type = 'text' },
    { column = 'type', type = 'text' },
    { column = 'geometry', type = 'geometry', projection = 4326 },
    { column = 'tags', type = 'hstore' }
})

tables.rs_reserve_forest = osm2pgsql.define_way_table('rs_reserve_forest', {
    { column = 'osm_id', type = 'bigint' },
    { column = 'name', type = 'text' },
    { column = 'leisure', type = 'text' },
    { column = 'entity_type', type = 'text' },
    { column = 'geometry', type = 'geometry', projection = 4326 },
    { column = 'tags', type = 'hstore' }
})

tables.rs_reserve_forest_relations = osm2pgsql.define_relation_table('rs_reserve_forest_relations', {
    { column = 'osm_id', type = 'bigint' },
    { column = 'name', type = 'text' },
    { column = 'leisure', type = 'text' },
    { column = 'entity_type', type = 'text' },
    { column = 'geometry', type = 'geometry', projection = 4326 },
    { column = 'tags', type = 'hstore' }
})

tables.rs_protected = osm2pgsql.define_way_table('rs_protected', {
    { column = 'osm_id', type = 'bigint' },
    { column = 'name', type = 'text' },
    { column = 'boundary', type = 'text' },
    { column = 'entity_type', type = 'text' },
    { column = 'geometry', type = 'geometry', projection = 4326 },
    { column = 'tags', type = 'hstore' }
})

tables.rs_shrub = osm2pgsql.define_way_table('rs_shrub', {
    { column = 'osm_id', type = 'bigint' },
    { column = 'name', type = 'text' },
    { column = 'natural', type = 'text' },
    { column = 'entity_type', type = 'text' },
    { column = 'geometry', type = 'geometry', projection = 4326 },
    { column = 'tags', type = 'hstore' }
})

tables.osm_all_roads = osm2pgsql.define_way_table('osm_all_roads', {
    { column = 'osm_id', type = 'bigint' },
    { column = 'name', type = 'text' },
    { column = 'highway', type = 'text' },
    { column = 'ref', type = 'text' },
    { column = 'lanes', type = 'text' },
    { column = 'maxspeed', type = 'text' },
    { column = 'tags', type = 'jsonb' },
    { column = 'junction', type = 'text' },
    { column = 'geometry', type = 'multilinestring', projection = 4326 }
})

tables.osm_relation_ways = osm2pgsql.define_relation_table('osm_relation_ways', {
    { column = 'osm_relation_id', type = 'bigint' },
    { column = 'member_way_id', type = 'bigint' }
})

function osm2pgsql.process_node(node)
    if node.tags.natural == 'peak' then
        tables.rs_hills_nodes:insert({
            osm_id = node.id,
            name = node.tags.name,
            natural = node.tags.natural,
            entity_type = 'node',
            geometry = node:as_point(),
            tags = node.tags
        })
    elseif node.tags['mountain pass'] == 'yes' then
        tables.rs_mountain_pass:insert({
            osm_id = node.id,
            name = node.tags.name,
            mountain_pass = node.tags['mountain pass'],
            entity_type = 'node',
            geometry = node:as_point(),
            tags = node.tags
        })
    end
end

function osm2pgsql.process_way(way)
    if way.tags.natural == 'wood' or way.tags.landuse == 'forest' or way.tags.landuse == 'wood' then
        tables.rs_forest:insert({
            osm_id = way.id,
            name = way.tags.name,
            natural = way.tags.natural,
            landuse = way.tags.landuse,
            entity_type = 'way',
            geometry = way:as_polygon(),
            tags = way.tags
        })
    elseif way.tags.water == 'reservoir' or way.tags.natural == 'water' or way.tags.water == 'lake' then
        tables.rs_lakes:insert({
            osm_id = way.id,
            name = way.tags.name,
            water = way.tags.water,
            natural = way.tags.natural,
            entity_type = 'way',
            geometry = way:as_polygon(),
            tags = way.tags
        })
    elseif way.tags.natural == 'coastline' then
        tables.rs_coastline:insert({
            osm_id = way.id,
            name = way.tags.name,
            natural = way.tags.natural,
            entity_type = 'way',
            geometry = way:as_multilinestring(),
            tags = way.tags
        })
    elseif way.tags.waterway == 'river' then
        tables.rs_rivers:insert({
            osm_id = way.id,
            name = way.tags.name,
            waterway = way.tags.waterway,
            entity_type = 'way',
            geometry = way:as_multilinestring(),
            tags = way.tags
        })
    elseif way.tags.natural == 'desert' then
        tables.rs_desert:insert({
            osm_id = way.id,
            name = way.tags.name,
            natural = way.tags.natural,
            entity_type = 'way',
            geometry = way:as_polygon(),
            tags = way.tags
        })
    elseif way.tags.landuse == 'farmland' or way.tags.natural == 'field' then
        tables.rs_fields:insert({
            osm_id = way.id,
            name = way.tags.name,
            landuse = way.tags.landuse,
            natural = way.tags.natural,
            entity_type = 'way',
            geometry = way:as_polygon(),
            tags = way.tags
        })
    elseif way.tags.leisure == 'nature_reserve' or way.tags.boundary == 'national_park' then
        tables.rs_reserve_forest:insert({
            osm_id = way.id,
            name = way.tags.name,
            leisure = way.tags.leisure,
            entity_type = 'way',
            geometry = way:as_polygon(),
            tags = way.tags
        })
    elseif way.tags.boundary == 'protected_area' then
        tables.rs_protected:insert({
            osm_id = way.id,
            name = way.tags.name,
            boundary = way.tags.boundary,
            entity_type = 'way',
            geometry = way:as_polygon(),
            tags = way.tags
        })
    elseif way.tags.natural == 'fell' or way.tags.natural == 'grassland' or way.tags.natural == 'shrubbery' or way.tags.natural == 'scrub' or way.tags.natural == 'moor' or way.tags.natural == 'heath' then
        tables.rs_shrub:insert({
            osm_id = way.id,
            name = way.tags.name,
            natural = way.tags.natural,
            entity_type = 'way',
            geometry = way:as_polygon(),
            tags = way.tags
        })
    elseif way.tags.highway then
        tables.osm_all_roads:insert({
            osm_id = way.id,
            name = way.tags.name,
            highway = way.tags.highway,
            ref = way.tags.ref,
            lanes = way.tags.lanes,
            maxspeed = way.tags.maxspeed,
            junction = way.tags.junction,
            geometry = way:as_multilinestring(),
            tags = way.tags
        })
    end
end

function osm2pgsql.process_relation(relation)
    -- Ensure relation.tags is not nil before processing
    if not relation.tags then
        return  -- Skip processing this relation entirely
    end

    -- **Process relation if:**
    -- 1. `route` is present and of type `road`, OR
    -- 2. `highway` tag is not null, OR
    -- 3. `ref` contains "NH", OR
    -- 4. `ref` contains "SH"
    if (relation.tags.route == 'road') or 
       (relation.tags.highway ~= nil) or 
       (relation.tags.ref and string.match(relation.tags.ref, 'NH')) or 
       (relation.tags.ref and string.match(relation.tags.ref, 'SH')) 
       then
        for _, member in ipairs(relation.members) do
            -- Ensure member is a way before inserting
            if member.type == 'w' then
                tables.osm_relation_ways:insert({
                    member_way_id = member.ref
                })
            end
        end    
    end

    -- **Include all multipolygons where `boundary=administrative` (no `admin_level` filter)**
    if relation.tags.boundary == 'administrative'
       and (relation.tags.type == 'multipolygon' or relation.tags.type == 'boundary')
    then
        -- Try `as_multipolygon()` first, fallback to `as_geometry()`
        local geom = relation:as_multipolygon() or relation:as_geometry()

        if geom then
            tables.rs_india_bounds:insert({
                osm_id = relation.id,
                name = relation.tags.name,
                boundary = relation.tags.boundary,
                admin_level = relation.tags.admin_level, -- Retain the admin_level field if it exists
                type = relation.tags.type,
                entity_type = 'relation',
                geometry = geom,
                tags = relation.tags
            })
        end
    elseif relation.tags.natural == 'peak' 
       or (relation.tags.type == 'multipolygon' and relation.tags.name and string.match(relation.tags.name, '[Hh]ill'))
    then
        tables.rs_hills_relations:insert({
            osm_id = relation.id,
            name = relation.tags.name,
            natural = relation.tags.natural,
            entity_type = 'relation',
            geometry = relation:as_multipolygon(),
            tags = relation.tags
        })
    elseif relation.tags.leisure == 'nature_reserve' or relation.tags.boundary == 'national_park' then
        tables.rs_reserve_forest_relations:insert({
            osm_id = relation.id,
            name = relation.tags.name,
            leisure = relation.tags.leisure,
            entity_type = 'relation',
            geometry = relation:as_multipolygon(),
            tags = relation.tags
        })
    end
end
