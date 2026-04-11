-- Phase 1: Core Infrastructure tests
package.path = package.path .. ";./?.lua"

local assert = require("test.assert")
local World  = require("core.world")
local Scheduler = require("core.scheduler")
local Registry  = require("core.registry")
local util      = require("core.util")

assert.suite("Phase 1 — Core Infrastructure")

-- ── World: entity creation ────────────────────────────────────────────────────
do
    local w = World.new()
    local e1 = w:create_entity()
    local e2 = w:create_entity()
    assert.not_nil(e1, "create_entity returns id")
    assert.not_equal(e1, e2, "entity ids are unique")
    assert.is_true(w:is_alive(e1), "new entity is alive")
end

-- ── World: components ────────────────────────────────────────────────────────
do
    local w = World.new()
    local e = w:create_entity()
    w:add_component(e, "stats", { hp=10, attack=3 })
    local s = w:get_component(e, "stats")
    assert.not_nil(s, "get_component returns data")
    assert.equal(s.hp, 10, "component data correct")
    assert.is_true(w:has_component(e, "stats"), "has_component true")
    assert.is_false(w:has_component(e, "position"), "has_component false")
    w:remove_component(e, "stats")
    assert.is_nil(w:get_component(e, "stats"), "remove_component works")
end

-- ── World: lazy destroy ───────────────────────────────────────────────────────
do
    local w = World.new()
    local e = w:create_entity()
    w:add_component(e, "stats", { hp=5 })
    w:destroy_entity(e)
    assert.is_true(w:is_alive(e) == false, "entity marked dead before flush")
    w:flush_destroyed()
    assert.is_nil(w:get_component(e, "stats"), "component gone after flush")
end

-- ── World: room index ────────────────────────────────────────────────────────
do
    local w = World.new()
    local room = w:create_entity()
    w:add_component(room, "is_room", { value=true })
    local ent = w:create_entity()
    w:add_component(ent, "position", { room_id=room })
    local in_room = w:get_entities_in_room(room)
    assert.equal(#in_room, 1, "room index: entity found")
    w:move_entity_to_room(ent, 999)
    assert.equal(#w:get_entities_in_room(room), 0, "room index updated on move")
end

-- ── World: events ────────────────────────────────────────────────────────────
do
    local w = World.new()
    local received = {}
    w:subscribe("test_event", function(e) table.insert(received, e.data.value) end)
    w:emit("test_event", { value=42 })
    w:emit("test_event", { value=7  })
    assert.equal(#received, 2, "subscriber receives events")
    assert.equal(received[1], 42, "event data correct")
    assert.equal(#w._event_log, 2, "event_log grows")
end

-- ── World: advance_tick ───────────────────────────────────────────────────────
do
    local w = World.new()
    assert.equal(w.tick, 0, "initial tick=0")
    w:advance_tick()
    assert.equal(w.tick, 1, "tick incremented")
end

-- ── Scheduler: priority order ────────────────────────────────────────────────
do
    local s = Scheduler.new()
    local order = {}
    s:register({ name="b", priority=20, update=function() table.insert(order,"b") end })
    s:register({ name="a", priority=10, update=function() table.insert(order,"a") end })
    s:register({ name="c", priority=30, update=function() table.insert(order,"c") end })
    local w = World.new(); w.tick = 1
    s:run(w)
    assert.equal(order[1], "a", "lowest priority runs first")
    assert.equal(order[3], "c", "highest priority runs last")
end

-- ── Scheduler: on_tick ───────────────────────────────────────────────────────
do
    local s = Scheduler.new()
    local count = 0
    s:register({ name="t", priority=1, on_tick=5,
                 update=function() count = count + 1 end })
    local w = World.new()
    for i = 0, 9 do
        w.tick = i
        s:run(w)
    end
    assert.equal(count, 2, "on_tick=5 fires at 0 and 5 in 0..9")
end

-- ── Registry: register and get ───────────────────────────────────────────────
do
    local r = Registry.new()
    r:register("entity_def", "rat", { components={ stats={hp=3} } })
    local def = r:get("entity_def", "rat")
    assert.not_nil(def, "registry get works")
    assert.equal(def.components.stats.hp, 3, "def data correct")
    assert.has_error(function() r:register("entity_def","rat",{}) end,
                     "duplicate registration raises error")
end

-- ── Registry: spawn_entity (deep copy) ───────────────────────────────────────
do
    local w = World.new()
    local r = Registry.new()
    r:register("entity_def", "rat", {
        components = { stats = { hp=5, attack=2 }, is_actor = { value=true } }
    })
    local e1 = r:spawn_entity(w, "rat")
    local e2 = r:spawn_entity(w, "rat")
    local s1 = w:get_component(e1, "stats")
    local s2 = w:get_component(e2, "stats")
    s1.hp = 999
    assert.equal(s2.hp, 5, "instances don't share component references")
end

-- ── util functions ────────────────────────────────────────────────────────────
do
    local t = { a=1, b=2, c=3 }
    assert.equal(util.table_size(t), 3, "table_size")
    assert.is_true(util.table_contains(t, 2), "table_contains found")
    assert.is_false(util.table_contains(t, 9), "table_contains not found")

    local arr = {1,2,3,4,5}
    util.shuffle(arr)
    assert.equal(#arr, 5, "shuffle preserves length")

    local items = { {"a", 0.9}, {"b", 0.1} }
    local counts = {a=0, b=0}
    for _ = 1, 1000 do
        local pick = util.weighted_random(items)
        counts[pick] = (counts[pick] or 0) + 1
    end
    assert.is_true(counts.a > counts.b, "weighted_random favors higher weight")

    local orig = { x=1, nested={ y=2 } }
    local copy = util.deep_copy(orig)
    copy.nested.y = 99
    assert.equal(orig.nested.y, 2, "deep_copy is independent")
end

-- ── 10000 tick smoke test ─────────────────────────────────────────────────────
do
    local w = World.new()
    local s = Scheduler.new()
    local counter = 0
    s:register({ name="tick_counter", priority=1,
                 update=function() counter = counter + 1 end })
    s:init(w)
    assert.no_error(function()
        for _ = 1, 10000 do
            s:run(w)
            w:advance_tick()
        end
    end, "10000 ticks without crash")
    assert.equal(counter, 10000, "system ran exactly 10000 times")
end

assert.summary()
