-- Phase 4: RPG Depth tests
package.path = package.path .. ";./?.lua"

local assert    = require("test.assert")
local World     = require("core.world")
local Registry  = require("core.registry")
local stats_sys = require("systems.stats_system")
local eq_sys    = require("systems.equipment_system")

assert.suite("Phase 4 — RPG Depth")

local function base_world()
    local w   = World.new()
    local reg = Registry.new()
    w._registry = reg
    return w, reg
end

-- ── equipment modifiers ───────────────────────────────────────────────────────
do
    local w, reg = base_world()

    -- register an iron_sword item
    reg:register("entity_def", "iron_sword", {
        components = {
            identity  = { name="Iron Sword", archetype="item" },
            item_info = { def_id="iron_sword", name="Iron Sword",
                          tags={"weapon"}, weight=4, value=25,
                          stackable=false, stack_count=1 },
            location  = { type="ground" },
            equippable = { slot="main_hand",
                           modifiers = { {stat="attack", type="add", value=6} } },
            is_item   = { value=true },
        }
    })

    local fighter = w:create_entity()
    w:add_component(fighter, "stats",           { hp=20, hp_max=20, attack=8, defense=3, speed=10, level=1 })
    w:add_component(fighter, "active_modifiers",{})
    w:add_component(fighter, "equipment_slots", { main_hand=nil })
    w:add_component(fighter, "inventory",       { capacity=30, weight_current=0, items={} })

    local base_atk = stats_sys.get_stat(w, fighter, "attack")
    assert.equal(base_atk, 8, "base attack before equip")

    local sword = reg:spawn_entity(w, "iron_sword")
    eq_sys.equip(w, fighter, sword)

    local new_atk = stats_sys.get_stat(w, fighter, "attack")
    assert.equal(new_atk, 14, "attack +6 after equip")

    eq_sys.unequip(w, fighter, "main_hand")
    local unequip_atk = stats_sys.get_stat(w, fighter, "attack")
    assert.equal(unequip_atk, 8, "attack restored after unequip")
end

-- ── modifier duration + status_system ────────────────────────────────────────
do
    local w = World.new()
    local e = w:create_entity()
    w:add_component(e, "stats",           { hp=20, hp_max=20, attack=8, defense=3, speed=10, level=1 })
    w:add_component(e, "active_modifiers",{
        stunned = { id="stunned", source=e, duration=3,
                    stats={}, flags={ cannot_act=true } }
    })
    w:add_component(e, "skills", {})

    local status = require("systems.status_system")

    assert.is_true(stats_sys.has_flag(w, e, "cannot_act"), "stunned flag present")

    w.tick = 1
    status.update(w)
    local mods = w:get_component(e, "active_modifiers")
    assert.not_nil(mods.stunned, "stunned still present after 1 tick (duration=2)")
    w.tick = 2; status.update(w)
    w.tick = 3; status.update(w)
    assert.is_nil(mods.stunned, "stunned removed after duration expires")
    assert.is_false(stats_sys.has_flag(w, e, "cannot_act"), "flag gone after removal")
end

-- ── level_system: xp and level-up ────────────────────────────────────────────
do
    local w, reg = base_world()
    local level_sys = require("systems.level_system")
    level_sys.init(w)

    local e = w:create_entity()
    w:add_component(e, "identity", { name="Hero", archetype="warrior" })
    w:add_component(e, "stats",    { hp=40, hp_max=40, attack=8, defense=5, speed=8, level=1 })
    w:add_component(e, "level",    { current=1, xp=0, xp_next=100 })
    w:add_component(e, "skills",   {})

    w:emit("xp_gained", { receiver_id=e, amount=50, source_id=nil })
    local lvl = w:get_component(e, "level")
    assert.equal(lvl.xp, 50, "xp accumulated")
    assert.equal(lvl.current, 1, "no level-up yet")

    w:emit("xp_gained", { receiver_id=e, amount=60, source_id=nil })
    assert.equal(lvl.current, 2, "leveled up at 110 xp")
    assert.less_than(lvl.xp, lvl.xp_next, "xp reset after level-up")

    local stats = w:get_component(e, "stats")
    assert.greater_than(stats.attack, 8, "attack increased on level-up")
end

-- ── skill_system: use_skill intent ───────────────────────────────────────────
do
    math.randomseed(1)
    local w, reg = base_world()
    reg:register("skill_def", "power_strike", require("data.skills.warrior.power_strike"))
    reg:register("status_def", "stunned", require("data.status_effects.stunned"))

    local r = w:create_entity()
    w:add_component(r, "is_room", {value=true})
    w:add_component(r, "room_info", {type="chamber", floor=1})
    w:add_component(r, "connections", {})
    w:add_component(r, "room_state", {light="dim", tags={}})

    local attacker = w:create_entity()
    w:add_component(attacker, "stats",           { hp=40, hp_max=40, attack=10, defense=5, speed=10, level=2 })
    w:add_component(attacker, "actor",           { move_cooldown=10, attack_cooldown=15 })
    w:add_component(attacker, "active_modifiers",{})
    w:add_component(attacker, "equipment_slots", {})
    w:add_component(attacker, "skills",          {
        power_strike = { def_id="power_strike", level=1, cooldown_cur=0 }
    })
    w:add_component(attacker, "position",        { room_id=r })
    w:add_component(attacker, "action_timer",    { cooldown_max=15, cooldown_cur=0, ready=true })
    w:add_component(attacker, "ai_intent", {
        action="use_skill", target={ skill_id="power_strike", target_eid=nil }
    })

    local target = w:create_entity()
    w:add_component(target, "stats",    { hp=20, hp_max=20, attack=5, defense=2, speed=8, level=1 })
    w:add_component(target, "active_modifiers", {})
    w:add_component(target, "equipment_slots",  {})
    w:add_component(target, "position",         { room_id=r })

    -- fix intent target
    w:get_component(attacker, "ai_intent").target.target_eid = target

    local skill_sys = require("systems.skill_system")
    skill_sys.update(w)

    local hp = stats_sys.get_hp(w, target)
    assert.less_than(hp, 20, "power_strike dealt damage")
    local sd = w:get_component(attacker, "skills")
    assert.greater_than(sd.power_strike.cooldown_cur, 0, "skill on cooldown after use")
end

-- ── item_system: pick_up ──────────────────────────────────────────────────────
do
    local w, reg = base_world()
    reg:register("entity_def", "health_potion", {
        components = {
            identity  = { name="HP", archetype="item" },
            item_info = { def_id="health_potion", name="HP",
                          tags={"consumable","healing"}, weight=1, value=10,
                          stackable=true, stack_count=1 },
            location  = { type="ground" },
            is_item   = { value=true },
        }
    })

    local r = w:create_entity()
    w:add_component(r, "is_room",    {value=true})
    w:add_component(r, "room_info",  {type="chamber", floor=1})
    w:add_component(r, "connections",{})
    w:add_component(r, "room_state", {light="dim", tags={}})

    local item = reg:spawn_entity(w, "health_potion", {
        position = {room_id=r},
        location = {type="ground", room_id=r},
    })

    local actor = w:create_entity()
    w:add_component(actor, "stats",          { hp=20, hp_max=20, attack=8, defense=3, speed=10, level=1 })
    w:add_component(actor, "actor",          { move_cooldown=10, attack_cooldown=10 })
    w:add_component(actor, "position",       { room_id=r })
    w:add_component(actor, "inventory",      { capacity=20, weight_current=0, items={} })
    w:add_component(actor, "equipment_slots",{})
    w:add_component(actor, "active_modifiers",{})
    w:add_component(actor, "action_timer",   { cooldown_max=10, cooldown_cur=0, ready=true })
    w:add_component(actor, "ai_intent",      { action="pick_up", target=item })

    local item_sys = require("systems.item_system")
    item_sys.update(w)

    local inv = w:get_component(actor, "inventory")
    assert.is_true(inv.items[item] == true, "item in inventory")
    local loc = w:get_component(item, "location")
    assert.equal(loc.type, "inventory", "location updated to inventory")
end

assert.summary()
