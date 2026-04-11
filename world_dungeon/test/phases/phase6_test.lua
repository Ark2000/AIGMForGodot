-- Phase 6: Logging System tests
package.path = package.path .. ";./?.lua"

local assert     = require("test.assert")
local World      = require("core.world")
local renderer   = require("logger.renderer")
local perspective = require("logger.perspective")

assert.suite("Phase 6 — Logging System")

-- ── renderer: importance levels ───────────────────────────────────────────────
do
    assert.equal(renderer.importance_of("yendor_retrieved"),
                 renderer.IMPORTANCE.CRITICAL, "yendor is CRITICAL")
    assert.equal(renderer.importance_of("entity_died"),
                 renderer.IMPORTANCE.HIGH, "entity_died is HIGH")
    assert.equal(renderer.importance_of("entity_attacked"),
                 renderer.IMPORTANCE.MEDIUM, "entity_attacked is MEDIUM")
    assert.equal(renderer.importance_of("entity_moved"),
                 renderer.IMPORTANCE.LOW, "entity_moved is LOW")
end

-- ── renderer: render produces strings ────────────────────────────────────────
do
    local w = World.new()
    local e1 = w:create_entity()
    local e2 = w:create_entity()
    w:add_component(e1, "identity", { name="Aldric", archetype="warrior" })
    w:add_component(e2, "identity", { name="Goblin", archetype="creature" })

    local r = w:create_entity()
    w:add_component(r, "is_room",   {value=true})
    w:add_component(r, "room_info", {type="chamber", floor=1})

    local event = {
        type="entity_attacked", tick=42,
        data={attacker_id=e1, defender_id=e2, hit=true, crit=false,
              damage=8, hp_before=15, hp_after=7, room_id=r}
    }
    local line = renderer.render(w, event)
    assert.not_nil(line, "renderer produces output")
    assert.is_true(line:find("Aldric") ~= nil, "attacker name in output")
    assert.is_true(line:find("8") ~= nil, "damage in output")

    local miss_event = {
        type="entity_attacked", tick=43,
        data={attacker_id=e1, defender_id=e2, hit=false, crit=false,
              damage=0, hp_before=7, hp_after=7, room_id=r}
    }
    local miss_line = renderer.render(w, miss_event)
    assert.is_true(miss_line:find("miss") ~= nil or miss_line:find("Miss") ~= nil or
                   miss_line:find("missed") ~= nil, "miss rendered")
end

-- ── renderer: critical hit ────────────────────────────────────────────────────
do
    local w = World.new()
    local e1 = w:create_entity()
    w:add_component(e1, "identity", {name="Brynn", archetype="warrior"})
    local e2 = w:create_entity()
    w:add_component(e2, "identity", {name="Orc", archetype="creature"})

    local event = {
        type="entity_attacked", tick=10,
        data={attacker_id=e1, defender_id=e2, hit=true, crit=true,
              damage=24, hp_before=30, hp_after=6}
    }
    local line = renderer.render(w, event)
    assert.is_true(line:find("CRITICAL") ~= nil or line:find("crit") ~= nil,
                   "crit indicated in output")
end

-- ── perspective: world mode filter ───────────────────────────────────────────
do
    local w = World.new()
    local p = perspective.new({ mode="world", min_importance="HIGH" })

    local low_event    = { type="entity_moved",    tick=1, data={} }
    local high_event   = { type="entity_died",     tick=1, data={} }
    local crit_event   = { type="yendor_retrieved",tick=1, data={} }

    assert.is_false(perspective.should_show(w, p, low_event),  "LOW filtered in world HIGH mode")
    assert.is_true(perspective.should_show(w, p, high_event),  "HIGH shown in world HIGH mode")
    assert.is_true(perspective.should_show(w, p, crit_event),  "CRITICAL always shown")
end

-- ── perspective: follow mode filter ──────────────────────────────────────────
do
    local w = World.new()
    local target = w:create_entity()
    w:add_component(target, "identity",  {name="Hero", archetype="warrior"})

    local r1 = w:create_entity()
    w:add_component(r1, "is_room",   {value=true})
    w:add_component(r1, "room_info", {type="entrance", floor=1})
    w:add_component(r1, "connections", {[1]={target_room_id=999, state="open"}})
    w:add_component(target, "position", {room_id=r1})

    local r2 = w:create_entity()
    w:add_component(r2, "is_room",    {value=true})
    w:add_component(r2, "room_info",  {type="chamber", floor=1})
    w:add_component(r2, "connections",{[1]={target_room_id=r1, state="open"}})
    local conn1 = w:get_component(r1, "connections")
    conn1[1] = {target_room_id=r2, state="open"}

    local p = perspective.new({
        mode="follow", target_eid=target,
        perception_range=1, min_importance="LOW"
    })

    -- event in same room as target
    local near_event = { type="entity_moved", tick=1, data={ entity_id=99, to_room=r1 } }
    assert.is_true(perspective.should_show(w, p, near_event), "event in target's room shown")

    -- event in far room (need to add it separately)
    local far_room = w:create_entity()
    w:add_component(far_room, "is_room",    {value=true})
    w:add_component(far_room, "room_info",  {type="chamber", floor=1})
    w:add_component(far_room, "connections",{})

    local far_event = { type="entity_moved", tick=1, data={ entity_id=99, to_room=far_room } }
    assert.is_false(perspective.should_show(w, p, far_event), "event outside range hidden in follow mode")

    -- target's own event always shown
    local own_event = { type="entity_moved", tick=1, data={ entity_id=target, to_room=far_room } }
    assert.is_true(perspective.should_show(w, p, own_event), "target's own events always shown")
end

-- ── log_system: outputs events ────────────────────────────────────────────────
do
    -- Capture stdout by redirecting
    local w = World.new()
    w.dungeon = { floors={} }
    w.hall_of_fame = {}
    w.ecology = { population={}, floor_activity={} }

    local logged = {}
    -- Patch print
    local old_print = print
    _G.print = function(s) table.insert(logged, s) end

    local log_sys = require("systems.log_system")
    w._log = nil  -- reset state

    local sim_cfg = {
        max_ticks = 100,
        log = {
            enabled = true,
            mode = "world",
            min_importance = "MEDIUM",
            auto_follow = false,
            output = "stdout",
            summary_interval = 99999,
        },
        max_adventurers = 3,
        adventurer_spawn_interval = 500,
    }
    -- Override require for simulation cfg in this scope
    package.loaded["data.config.simulation"] = sim_cfg

    log_sys.init(w)

    -- emit a medium-importance event
    w:emit("item_picked_up", { entity_id=1, item_id=2 })

    w.tick = 1
    log_sys.update(w)

    _G.print = old_print
    package.loaded["data.config.simulation"] = nil

    assert.greater_than(#logged, 0, "log_system outputs events")
end

assert.summary()
