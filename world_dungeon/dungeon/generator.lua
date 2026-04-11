local util = require("core.util")

local M = {}

-- connectivity constants → extra edge ratio beyond spanning tree
local CONNECTIVITY = { sparse=0.1, normal=0.25, dense=0.5 }

-- ── build a random spanning tree ─────────────────────────────────────────────
local function spanning_tree(ids)
    local edges   = {}
    if #ids <= 1 then return edges end
    local shuffled = util.deep_copy(ids)
    util.shuffle(shuffled)
    local visited = { [shuffled[1]] = true }
    for i = 2, #shuffled do
        local visited_list = util.keys(visited)
        local parent = util.random_pick(visited_list)
        table.insert(edges, { from=parent, to=shuffled[i] })
        visited[shuffled[i]] = true
    end
    return edges
end

-- ── connect two rooms bidirectionally ────────────────────────────────────────
local function connect(world, a, b, conn_type)
    local ca = world:get_component(a, "connections")
    local cb = world:get_component(b, "connections")
    -- check not already connected
    for _, c in pairs(ca) do
        if c.target_room_id == b then return end
    end
    local ia = util.table_size(ca) + 1
    local ib = util.table_size(cb) + 1
    ca[ia] = { target_room_id=b, state="open", one_way=false, type=conn_type or "normal" }
    cb[ib] = { target_room_id=a, state="open", one_way=false, type=conn_type or "normal" }
end

-- ── create a single room entity ──────────────────────────────────────────────
local function make_room(world, room_type, floor_num, index)
    local rid = world:create_entity()
    world:add_component(rid, "is_room",    { value=true })
    world:add_component(rid, "room_info",  { type=room_type, floor=floor_num, template=room_type })
    world:add_component(rid, "connections",{})
    world:add_component(rid, "room_state", { light="dim", tags={} })
    world:add_component(rid, "identity",   { name=room_type.."_f"..floor_num.."_"..index,
                                             archetype="room" })
    return rid
end

-- ── populate monsters in a room ──────────────────────────────────────────────
local function maybe_spawn_monster(world, registry, room_id, floor_num, cfg)
    if math.random() > cfg.monster_density then return end
    local pool = cfg.monster_pool
    if not pool or #pool == 0 then return end
    local def_id = util.random_pick(pool)
    local eid = registry:spawn_entity(world, def_id, {
        position = { room_id=room_id }
    })
    -- reset cooldown so entity acts immediately
    local at = world:get_component(eid, "action_timer")
    if not at then
        local actor = world:get_component(eid, "actor")
        local cd = actor and actor.move_cooldown or 10
        world:add_component(eid, "action_timer", { cooldown_max=cd, cooldown_cur=math.random(1, cd), ready=false })
    end
    return eid
end

-- ── populate loot items ──────────────────────────────────────────────────────
local function maybe_spawn_item(world, registry, room_id, cfg)
    if math.random() > cfg.loot_density then return end
    local pool = cfg.loot_pool
    if not pool or #pool == 0 then return end
    local def_id = util.random_pick(pool)
    -- items are registered as item_def not entity_def; spawn manually
    local idef = registry:try_get("item_def", def_id)
    if not idef then
        -- try entity_def (for items registered that way)
        local ok, eid = pcall(function()
            return registry:spawn_entity(world, def_id, {
                position = { room_id=room_id },
                location = { type="ground", room_id=room_id },
            })
        end)
        if ok then return eid end
        return
    end
    local eid = registry:spawn_entity(world, def_id, {
        position = { room_id=room_id },
        location = { type="ground", room_id=room_id },
    })
    return eid
end

-- ── generate one floor ───────────────────────────────────────────────────────
function M.generate_floor(world, registry, floor_num, cfg)
    local room_count = math.random(cfg.room_count.min, cfg.room_count.max)
    local room_ids   = {}

    -- weighted type table
    local type_weights = {}
    for rtype, w in pairs(cfg.room_types or {}) do
        table.insert(type_weights, { rtype, w })
    end

    -- room 1 = entrance, last = stairs (or boss on final floor)
    local total_floors = world.dungeon.total_floors
    for i = 1, room_count do
        local rtype
        if i == 1 then
            rtype = "entrance"
        elseif i == room_count then
            rtype = (floor_num == total_floors) and "boss_room" or "stairs"
        else
            rtype = (#type_weights > 0)
                    and util.weighted_random(type_weights)
                    or "chamber"
        end
        local rid = make_room(world, rtype, floor_num, i)
        table.insert(room_ids, rid)
    end

    -- spanning tree connections
    local edges = spanning_tree(room_ids)
    for _, e in ipairs(edges) do
        connect(world, e.from, e.to, "normal")
    end

    -- extra edges
    local ratio = CONNECTIVITY[cfg.connectivity] or 0.2
    local extra = math.floor((room_count - 1) * ratio)
    for _ = 1, extra do
        local a = util.random_pick(room_ids)
        local b = util.random_pick(room_ids)
        if a ~= b then connect(world, a, b, "normal") end
    end

    -- store floor data
    local entrance_id = room_ids[1]
    local exit_id     = (floor_num < total_floors) and room_ids[#room_ids] or nil
    local boss_room   = (floor_num == total_floors) and room_ids[#room_ids] or nil

    world.dungeon.floors[floor_num] = {
        rooms     = {},
        entrance  = entrance_id,
        exit      = exit_id,
        boss_room = boss_room,
    }
    for _, rid in ipairs(room_ids) do
        world.dungeon.floors[floor_num].rooms[rid] = true
    end

    -- connect to previous floor via stairs
    if floor_num > 1 then
        local prev_exit = world.dungeon.floors[floor_num - 1].exit
        if prev_exit then
            -- stairs_down from prev exit → current entrance
            -- stairs_up  from current entrance → prev exit
            local cp = world:get_component(prev_exit, "connections")
            local ce = world:get_component(entrance_id, "connections")
            local ip = util.table_size(cp) + 1
            local ie = util.table_size(ce) + 1
            cp[ip] = { target_room_id=entrance_id, state="open", one_way=false, type="stairs_down" }
            ce[ie] = { target_room_id=prev_exit,   state="open", one_way=false, type="stairs_up"   }
        end
    end

    -- populate monsters and items (skip entrance and exit/boss rooms)
    for i, rid in ipairs(room_ids) do
        local ri = world:get_component(rid, "room_info")
        local skip = (i == 1) or (ri and (ri.type == "stairs" or ri.type == "boss_room"))
        if not skip then
            maybe_spawn_monster(world, registry, rid, floor_num, cfg)
            maybe_spawn_item(world, registry, rid, cfg)
        end
    end

    -- spawn boss on final floor
    if floor_num == total_floors and cfg.boss then
        local broom = boss_room or room_ids[#room_ids]
        local ok, eid = pcall(function()
            return registry:spawn_entity(world, cfg.boss, {
                position = { room_id=broom }
            })
        end)
        if ok then
            local actor = world:get_component(eid, "actor")
            local cd    = actor and actor.attack_cooldown or 20
            world:add_component(eid, "action_timer", {
                cooldown_max=cd, cooldown_cur=math.random(1, cd), ready=false
            })
        end
        -- spawn Amulet of Yendor in boss room
        pcall(function()
            registry:spawn_entity(world, "amulet_of_yendor", {
                position = { room_id=broom },
                location = { type="ground", room_id=broom },
            })
        end)
    end

    return world.dungeon.floors[floor_num]
end

-- ── generate entire dungeon ───────────────────────────────────────────────────
function M.generate(world, registry, floor_configs)
    world.dungeon.total_floors = #floor_configs
    for i, cfg in ipairs(floor_configs) do
        M.generate_floor(world, registry, i, cfg)
    end
end

return M
