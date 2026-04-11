-- Phase 2: Space & Dungeon tests
package.path = package.path .. ";./?.lua"

local assert    = require("test.assert")
local World     = require("core.world")
local Registry  = require("core.registry")
local Scheduler = require("core.scheduler")
local generator = require("dungeon.generator")
local topology  = require("dungeon.topology")

assert.suite("Phase 2 — Space & Dungeon")

-- Helper: load minimal registry with entity defs and behaviors
local function make_registry()
    local r = Registry.new()
    -- register a simple creature
    r:register("entity_def", "rat", {
        components = {
            identity    = { name="Rat", archetype="creature" },
            stats       = { hp=5, hp_max=5, attack=2, defense=0, speed=10, level=1 },
            actor       = { move_cooldown=10, attack_cooldown=10 },
            faction     = { id="vermin", hostility={} },
            ai_behavior = { archetype="random_wander" },
            is_actor    = { value=true },
            active_modifiers = {},
        }
    })
    r:register("behavior_def", "random_wander", require("data.behaviors.random_wander"))
    r:register("floor_config", "floor_1", require("data.floor_configs.floor_1"))
    return r
end

-- ── topology: get_neighbors ───────────────────────────────────────────────────
do
    local w = World.new()
    local r1 = w:create_entity()
    local r2 = w:create_entity()
    w:add_component(r1, "connections", {
        [1] = { target_room_id=r2, state="open", one_way=false }
    })
    w:add_component(r2, "connections", {
        [1] = { target_room_id=r1, state="open", one_way=false }
    })
    local n = topology.get_neighbors(w, r1)
    assert.equal(#n, 1, "get_neighbors returns one neighbor")
    assert.equal(n[1], r2, "correct neighbor id")

    -- locked connection not returned
    local r3 = w:create_entity()
    w:add_component(r3, "connections", {
        [1] = { target_room_id=r1, state="locked", one_way=false }
    })
    local n3 = topology.get_neighbors(w, r3)
    assert.equal(#n3, 0, "locked connection excluded")
end

-- ── topology: find_path ───────────────────────────────────────────────────────
do
    local w = World.new()
    -- chain: r1-r2-r3
    local r1, r2, r3 = w:create_entity(), w:create_entity(), w:create_entity()
    w:add_component(r1, "connections", { [1]={target_room_id=r2, state="open"} })
    w:add_component(r2, "connections", {
        [1]={target_room_id=r1, state="open"},
        [2]={target_room_id=r3, state="open"}
    })
    w:add_component(r3, "connections", { [1]={target_room_id=r2, state="open"} })

    local path = topology.find_path(w, r1, r3)
    assert.not_nil(path, "find_path returns path")
    assert.equal(#path, 3, "path length correct")
    assert.equal(path[1], r1, "path starts at from")
    assert.equal(path[3], r3, "path ends at to")

    assert.is_nil(topology.find_path(w, r1, 999), "unreachable returns nil")
end

-- ── generator: basic floor ────────────────────────────────────────────────────
do
    math.randomseed(42)
    local w = World.new()
    w.dungeon.total_floors = 5
    local r = make_registry()
    w._registry = r

    local cfg = require("data.floor_configs.floor_1")
    -- simple cfg without monster_pool to avoid spawn issues
    local test_cfg = {
        id="floor_1", floor=1,
        room_count={min=6, max=8},
        room_types={corridor=0.5, chamber=0.5},
        connectivity="normal",
        monster_density=0,
        monster_pool={},
        loot_density=0,
        loot_pool={},
    }
    generator.generate_floor(w, r, 1, test_cfg)

    local f1 = w.dungeon.floors[1]
    assert.not_nil(f1, "floor 1 data created")
    assert.not_nil(f1.entrance, "entrance exists")
    assert.not_nil(f1.exit,     "exit exists")
    assert.is_true(f1.entrance ~= f1.exit, "entrance ≠ exit")

    -- check connectivity: all rooms reachable from entrance
    local reachable = {}
    local queue = { f1.entrance }
    reachable[f1.entrance] = true
    local head = 1
    while head <= #queue do
        local cur = queue[head]; head = head + 1
        for _, nid in ipairs(topology.get_neighbors(w, cur)) do
            if not reachable[nid] then
                reachable[nid] = true
                table.insert(queue, nid)
            end
        end
    end
    local room_count = 0
    for _ in pairs(f1.rooms) do room_count = room_count + 1 end
    local reach_count = 0
    for _ in pairs(reachable) do reach_count = reach_count + 1 end
    assert.equal(room_count, reach_count, "all rooms are reachable (connected graph)")
end

-- ── action_timer_system ───────────────────────────────────────────────────────
do
    local w   = World.new()
    local ats = require("systems.action_timer_system")
    local e   = w:create_entity()
    w:add_component(e, "action_timer", { cooldown_max=3, cooldown_cur=3, ready=false })
    w.tick = 0
    ats.update(w)
    local at = w:get_component(e, "action_timer")
    assert.equal(at.cooldown_cur, 2, "cooldown decremented")
    assert.is_false(at.ready, "not yet ready")
    ats.update(w)
    ats.update(w)
    assert.is_true(at.ready, "ready after 3 ticks")
end

-- ── random_wander behavior ────────────────────────────────────────────────────
do
    math.randomseed(1)
    local w = World.new()
    local r = make_registry()
    w._registry = r

    -- simple 2-room dungeon
    local r1 = w:create_entity()
    local r2 = w:create_entity()
    w:add_component(r1, "is_room", {value=true})
    w:add_component(r1, "room_info", {type="entrance", floor=1})
    w:add_component(r1, "connections", { [1]={target_room_id=r2, state="open"} })
    w:add_component(r2, "is_room", {value=true})
    w:add_component(r2, "room_info", {type="chamber", floor=1})
    w:add_component(r2, "connections", { [1]={target_room_id=r1, state="open"} })

    local e = r:spawn_entity(w, "rat", { position={room_id=r1} })
    w:add_component(e, "action_timer", {cooldown_max=1, cooldown_cur=0, ready=true})

    local ats    = require("systems.action_timer_system")
    local ai_sys = require("systems.ai_system")
    local mv_sys = require("systems.movement_system")

    ai_sys.update(w)
    local intent = w:get_component(e, "ai_intent")
    assert.not_nil(intent, "ai_system produced intent")
    assert.equal(intent.action, "move", "intent is move")

    mv_sys.update(w)
    local pos = w:get_component(e, "position")
    assert.equal(pos.room_id, r2, "entity moved to neighbor")
end

-- ── 1000 tick wander smoke test ───────────────────────────────────────────────
do
    math.randomseed(99)
    local w   = World.new()
    local reg = make_registry()
    w._registry = reg
    w.dungeon.total_floors = 5

    local test_cfg = {
        id="floor_1", floor=1,
        room_count={min=5, max=6},
        room_types={chamber=1.0},
        connectivity="normal",
        monster_density=0.8,
        monster_pool={"rat"},
        loot_density=0,
        loot_pool={},
    }
    generator.generate_floor(w, reg, 1, test_cfg)

    local sched = Scheduler.new()
    sched:register(require("systems.action_timer_system"))
    sched:register(require("systems.ai_system"))
    sched:register(require("systems.movement_system"))
    sched:init(w)

    local moved_events = 0
    w:subscribe("entity_moved", function() moved_events = moved_events + 1 end)

    assert.no_error(function()
        for _ = 1, 1000 do sched:run(w); w:advance_tick() end
    end, "1000-tick wander runs without crash")
    assert.greater_than(moved_events, 0, "entities moved during wander")
end

assert.summary()
