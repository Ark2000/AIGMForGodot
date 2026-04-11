-- Phase 3: Combat & Death tests
package.path = package.path .. ";./?.lua"

local assert    = require("test.assert")
local World     = require("core.world")
local Registry  = require("core.registry")
local Scheduler = require("core.scheduler")
local stats_sys = require("systems.stats_system")

assert.suite("Phase 3 — Combat & Death")

local function make_world()
    local w = World.new()
    w._registry = Registry.new()
    w.dungeon.total_floors = 5
    return w, w._registry
end

local function register_basics(reg)
    reg:register("entity_def", "fighter_a", {
        components = {
            identity   = { name="FighterA", archetype="creature" },
            stats      = { hp=20, hp_max=20, attack=8, defense=2, speed=10, level=1 },
            actor      = { move_cooldown=10, attack_cooldown=10 },
            faction    = { id="team_a", hostility={ team_b="aggressive", team_a="neutral" } },
            ai_behavior= { archetype="pack_hunter" },
            is_actor   = { value=true },
            active_modifiers={},
            loot_table = { { item_id="health_potion", count=1, chance=1.0 } },
        }
    })
    reg:register("entity_def", "fighter_b", {
        components = {
            identity   = { name="FighterB", archetype="creature" },
            stats      = { hp=20, hp_max=20, attack=8, defense=2, speed=10, level=1 },
            actor      = { move_cooldown=10, attack_cooldown=10 },
            faction    = { id="team_b", hostility={ team_a="aggressive", team_b="neutral" } },
            ai_behavior= { archetype="pack_hunter" },
            is_actor   = { value=true },
            active_modifiers={},
            loot_table = {},
        }
    })
    reg:register("entity_def", "health_potion", {
        components = {
            identity  = { name="Health Potion", archetype="item" },
            item_info = { def_id="health_potion", name="Health Potion",
                          tags={"consumable","healing"}, weight=1, value=15,
                          stackable=true, stack_count=1 },
            location  = { type="ground" },
            usable    = { consumable=true, effects={{type="heal",amount=20}}, targeting="self" },
            is_item   = { value=true },
        }
    })
    reg:register("behavior_def", "pack_hunter", require("data.behaviors.pack_hunter"))
end

-- ── combat formula sanity ─────────────────────────────────────────────────────
do
    local formulas = require("data.config.combat_formulas")
    local atk = { attack=10, defense=3, speed=10, level=1 }
    local def = { attack=5,  defense=4, speed=10, level=1 }
    local dmg = formulas.physical_damage(atk, def)
    assert.greater_than(dmg, 0, "damage > 0")
    local hit = formulas.hit_chance(atk, def)
    assert.is_true(hit >= 0.05 and hit <= 0.95, "hit_chance in [0.05, 0.95]")
    local crit = formulas.crit_chance(atk)
    assert.is_true(crit >= 0 and crit <= 1, "crit_chance in [0,1]")
end

-- ── combat_system: attack intent deals damage ─────────────────────────────────
do
    local w, reg = make_world()
    register_basics(reg)

    local r = w:create_entity()
    w:add_component(r, "is_room",    {value=true})
    w:add_component(r, "room_info",  {type="chamber", floor=1})
    w:add_component(r, "connections",{})
    w:add_component(r, "room_state", {light="dim", tags={}})

    local a = reg:spawn_entity(w, "fighter_a", { position={room_id=r} })
    local b = reg:spawn_entity(w, "fighter_b", { position={room_id=r} })

    w:add_component(a, "action_timer", {cooldown_max=10, cooldown_cur=0, ready=true})
    w:add_component(a, "ai_intent",    {action="attack", target=b})

    local combat = require("systems.combat_system")
    combat.init(w)

    -- Guarantee a hit
    w._combat_formulas = {
        hit_chance      = function() return 1.0 end,
        crit_chance     = function() return 0.0 end,
        crit_multiplier = 2.0,
        physical_damage = function() return 5 end,
        xp_for_kill     = function() return 50 end,
    }

    local attacks = 0
    w:subscribe("entity_attacked", function() attacks = attacks + 1 end)

    combat.update(w)
    assert.equal(attacks, 1, "entity_attacked event emitted")
    local hp = stats_sys.get_hp(w, b)
    assert.less_than(hp, 20, "target took damage")
end

-- ── entity_died emitted when hp ≤ 0 ──────────────────────────────────────────
do
    math.randomseed(42)
    local w, reg = make_world()
    register_basics(reg)

    local r = w:create_entity()
    w:add_component(r, "is_room",    {value=true})
    w:add_component(r, "room_info",  {type="chamber", floor=1})
    w:add_component(r, "connections",{})
    w:add_component(r, "room_state", {light="dim", tags={}})

    local a = reg:spawn_entity(w, "fighter_a", { position={room_id=r} })
    local b = reg:spawn_entity(w, "fighter_b", { position={room_id=r} })

    -- Set b to 1 hp so one hit kills
    local bs = w:get_component(b, "stats")
    bs.hp = 1

    w:add_component(a, "action_timer", {cooldown_max=10, cooldown_cur=0, ready=true})
    w:add_component(a, "ai_intent",    {action="attack", target=b})

    local combat = require("systems.combat_system")
    combat.init(w)

    local died_count = 0
    w:subscribe("entity_died", function() died_count = died_count + 1 end)

    -- Guarantee hit by patching the formula
    w._combat_formulas = {
        hit_chance       = function() return 1.0 end,
        crit_chance      = function() return 0.0 end,
        crit_multiplier  = 2.0,
        physical_damage  = function() return 100 end,
        xp_for_kill      = function() return 50 end,
    }

    combat.update(w)
    assert.equal(died_count, 1, "entity_died emitted on fatal hit")
end

-- ── spawn_system: loot dropped on death ──────────────────────────────────────
do
    local w, reg = make_world()
    register_basics(reg)

    local spawn_sys = require("systems.spawn_system")
    w._combat_formulas = require("data.config.combat_formulas")
    spawn_sys.init(w)

    local r = w:create_entity()
    w:add_component(r, "is_room",    {value=true})
    w:add_component(r, "room_info",  {type="chamber", floor=1})
    w:add_component(r, "connections",{})
    w:add_component(r, "room_state", {light="dim", tags={}})

    local victim = reg:spawn_entity(w, "fighter_a", { position={room_id=r} })
    local killer = reg:spawn_entity(w, "fighter_b", { position={room_id=r} })

    -- loot_table chance=1.0 so guaranteed drop
    local items_spawned = 0
    w:subscribe("item_spawned", function() items_spawned = items_spawned + 1 end)

    w:emit("entity_died", { entity_id=victim, killer_id=killer, room_id=r })
    w:flush_destroyed()

    assert.equal(items_spawned, 1, "loot item spawned on death")
    assert.is_false(w:is_alive(victim), "dead entity destroyed")
end

-- ── stats_system: get_stat ───────────────────────────────────────────────────
do
    local w = World.new()
    local e = w:create_entity()
    w:add_component(e, "stats", { hp=20, hp_max=20, attack=8, defense=3, speed=10, level=1 })
    w:add_component(e, "active_modifiers", {
        test_mod = { id="test_mod", source=e, duration=nil,
                     stats={ attack={ add=4, mul=1.5 } }, flags={} }
    })
    local atk = stats_sys.get_stat(w, e, "attack")
    -- (8 + 4) * 1.5 = 18
    assert.equal(atk, 18, "get_stat applies add then mul")
end

assert.summary()
