-- Phase 5: Ecology & Adventurer AI tests
package.path = package.path .. ";./?.lua"

local assert    = require("test.assert")
local World     = require("core.world")
local Registry  = require("core.registry")
local Scheduler = require("core.scheduler")

assert.suite("Phase 5 — Ecology & Adventurer AI")

-- ── ecology_system: respawn under min population ──────────────────────────────
do
    local w = World.new()
    w.dungeon.total_floors = 1
    local reg = Registry.new()
    w._registry = reg

    reg:register("entity_def", "giant_rat", require("data.entities.creatures.giant_rat"))
    reg:register("behavior_def", "random_wander", require("data.behaviors.random_wander"))
    reg:register("floor_config", "floor_1", {
        id="floor_1", floor=1,
        room_count={min=3,max=3},
        room_types={chamber=1.0},
        connectivity="sparse",
        monster_density=0,
        monster_pool={"giant_rat"},
        loot_density=0,
        loot_pool={},
        ecology={ min_population=2, max_population=10, respawn_delay=0, spawn_per_cycle=2 },
    })

    -- Build a minimal dungeon manually
    local r1 = w:create_entity()
    w:add_component(r1, "is_room",    {value=true})
    w:add_component(r1, "room_info",  {type="entrance", floor=1})
    w:add_component(r1, "connections",{})
    w:add_component(r1, "room_state", {light="dim", tags={}})
    local r2 = w:create_entity()
    w:add_component(r2, "is_room",    {value=true})
    w:add_component(r2, "room_info",  {type="chamber", floor=1})
    w:add_component(r2, "connections",{[1]={target_room_id=r1, state="open"}})
    w:add_component(r2, "room_state", {light="dim", tags={}})

    local conn1 = w:get_component(r1, "connections")
    conn1[1] = {target_room_id=r2, state="open"}

    w.dungeon.floors[1] = {
        rooms    = {[r1]=true, [r2]=true},
        entrance = r1,
        exit     = nil,
    }

    -- spawn_system must be inited for spawn_requested
    local spawn_sys = require("systems.spawn_system")
    w._combat_formulas = require("data.config.combat_formulas")
    spawn_sys.init(w)

    -- ecology update should request spawns
    local eco_sys = require("systems.ecology_system")
    eco_sys.init(w)

    local spawn_requests = 0
    w:subscribe("spawn_requested", function() spawn_requests = spawn_requests + 1 end)

    w.tick = 100  -- on_tick=100
    eco_sys.update(w)

    assert.greater_than(spawn_requests, 0, "ecology requests spawn when under min population")
end

-- ── adventurer goal: goal state transitions ───────────────────────────────────
do
    local w = World.new()
    w.dungeon.total_floors = 5
    local reg = Registry.new()
    w._registry = reg

    reg:register("entity_def", "warrior",   require("data.entities.adventurers.warrior"))
    reg:register("behavior_def","adventurer",require("data.behaviors.adventurer"))
    reg:register("floor_config","floor_1",  require("data.floor_configs.floor_1"))

    -- Build minimal floor
    local r1 = w:create_entity()
    w:add_component(r1, "is_room",    {value=true})
    w:add_component(r1, "room_info",  {type="entrance", floor=1})
    w:add_component(r1, "connections",{})
    w:add_component(r1, "room_state", {light="dim", tags={}})
    local r2 = w:create_entity()
    w:add_component(r2, "is_room",    {value=true})
    w:add_component(r2, "room_info",  {type="stairs", floor=1})
    w:add_component(r2, "connections",{[1]={target_room_id=r1, state="open"}})
    w:add_component(r2, "room_state", {light="dim", tags={}})
    local conn1 = w:get_component(r1, "connections")
    conn1[1] = {target_room_id=r2, state="open"}

    w.dungeon.floors[1] = {
        rooms={[r1]=true,[r2]=true}, entrance=r1, exit=r2
    }

    local warrior = reg:spawn_entity(w, "warrior", { position={room_id=r1} })
    w:add_component(warrior, "action_timer", {cooldown_max=10, cooldown_cur=0, ready=true})

    local goal = w:get_component(warrior, "adventurer_goal")
    assert.not_nil(goal, "adventurer_goal component present")
    assert.equal(goal.ultimate, "retrieve_yendor", "ultimate goal set")
    assert.equal(goal.current_stage, "explore_floor", "starts in explore_floor")
end

-- ── adventurer spawning via ecology ──────────────────────────────────────────
do
    math.randomseed(7)
    local w = World.new()
    w.dungeon.total_floors = 5
    local reg = Registry.new()
    w._registry = reg

    local archetypes = {"warrior","rogue","mage"}
    for _, a in ipairs(archetypes) do
        reg:register("entity_def", a, require("data.entities.adventurers." .. a))
    end
    reg:register("behavior_def","adventurer",require("data.behaviors.adventurer"))
    for i = 1, 5 do
        reg:register("floor_config","floor_"..i,require("data.floor_configs.floor_"..i))
    end

    local r1 = w:create_entity()
    w:add_component(r1, "is_room",    {value=true})
    w:add_component(r1, "room_info",  {type="entrance", floor=1})
    w:add_component(r1, "connections",{})
    w:add_component(r1, "room_state", {light="dim", tags={}})
    w.dungeon.floors[1] = { rooms={[r1]=true}, entrance=r1, exit=nil }

    -- Register items referenced by starting_gear
    for _, id in ipairs({"iron_sword","rusty_dagger","magic_staff","leather_armor",
                         "health_potion","antidote","torch"}) do
        reg:register("entity_def", id, require("data.items." ..
            (({iron_sword="weapons",rusty_dagger="weapons",magic_staff="weapons",
               leather_armor="armor",chain_mail="armor",iron_shield="armor",
               health_potion="consumables",antidote="consumables",torch="misc",iron_key="misc",
               greater_health_potion="consumables"})[id] or "misc")
            .. "." .. id))
    end

    local spawn_sys = require("systems.spawn_system")
    w._combat_formulas = require("data.config.combat_formulas")
    spawn_sys.init(w)
    local eq_sys = require("systems.equipment_system")

    local eco_sys = require("systems.ecology_system")
    eco_sys.init(w)

    w.tick = 500  -- trigger spawn
    local spawned = 0
    w:subscribe("adventurer_spawned", function() spawned = spawned + 1 end)
    eco_sys.update(w)
    w:flush_destroyed()

    assert.equal(spawned, 1, "one adventurer spawned on first ecology cycle")
    local advs = w:get_all_entities_with("adventurer_goal")
    local alive = 0
    for _, eid in ipairs(advs) do if w:is_alive(eid) then alive = alive + 1 end end
    assert.equal(alive, 1, "adventurer is alive in world")
end

assert.summary()
