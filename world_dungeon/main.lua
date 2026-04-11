-- World Dungeon Simulator — main entry point
-- Usage: lua main.lua [seed]

package.path = package.path .. ";./?.lua"

local World     = require("core.world")
local Registry  = require("core.registry")
local Scheduler = require("core.scheduler")
local generator = require("dungeon.generator")

-- ── Config ────────────────────────────────────────────────────────────────────
local sim_cfg = require("data.config.simulation")
local seed    = tonumber(arg and arg[1]) or sim_cfg.seed or os.time()
math.randomseed(seed)
io.write(string.format("[SIM] seed=%d  max_ticks=%d\n", seed, sim_cfg.max_ticks))

-- ── World & Registry ─────────────────────────────────────────────────────────
local world    = World.new()
local registry = Registry.new()
world._registry = registry

-- ── Register all data ────────────────────────────────────────────────────────

-- Behaviors
local behaviors = {
    "random_wander","pack_hunter","territorial","coward","scavenger","adventurer"
}
for _, id in ipairs(behaviors) do
    registry:register("behavior_def", id, require("data.behaviors." .. id))
end

-- Status effects
local statuses = { "stunned","poisoned","burning","frozen","blessed","invisible","strengthened" }
for _, id in ipairs(statuses) do
    registry:register("status_def", id, require("data.status_effects." .. id))
end

-- Skill defs
local skill_files = {
    { "warrior", { "power_strike", "shield_bash", "battle_cry" } },
    { "rogue",   { "backstab", "poison_blade", "smoke_bomb"    } },
    { "mage",    { "fireball", "frost_bolt", "blink"           } },
}
for _, entry in ipairs(skill_files) do
    local cls, ids = entry[1], entry[2]
    for _, id in ipairs(ids) do
        registry:register("skill_def", id, require("data.skills." .. cls .. "." .. id))
    end
end

-- Entity defs: creatures
local creatures = {
    "giant_rat","goblin","goblin_archer","orc","skeleton","troll","dragon"
}
for _, id in ipairs(creatures) do
    registry:register("entity_def", id, require("data.entities.creatures." .. id))
end

-- Entity defs: adventurers
for _, id in ipairs({"warrior","rogue","mage"}) do
    registry:register("entity_def", id, require("data.entities.adventurers." .. id))
end

-- Entity defs: items (registered as both entity_def and item_def for convenience)
local item_files = {
    { "weapons",     { "rusty_dagger","iron_sword","short_bow","magic_staff" } },
    { "armor",       { "leather_armor","chain_mail","iron_shield" } },
    { "consumables", { "health_potion","greater_health_potion","antidote" } },
    { "misc",        { "torch","iron_key","amulet_of_yendor" } },
}
for _, entry in ipairs(item_files) do
    local subdir, ids = entry[1], entry[2]
    for _, id in ipairs(ids) do
        local def = require("data.items." .. subdir .. "." .. id)
        registry:register("entity_def", id, def)
        registry:register("item_def",   id, def)
    end
end

-- Room templates
local room_templates = {
    "entrance","corridor","chamber","monster_lair","treasure_room","stairs","boss_room"
}
for _, id in ipairs(room_templates) do
    registry:register("room_template", id, require("data.room_templates." .. id))
end

-- Floor configs
local TOTAL_FLOORS = 5
world.dungeon.total_floors = TOTAL_FLOORS
for i = 1, TOTAL_FLOORS do
    local cfg = require("data.floor_configs.floor_" .. i)
    registry:register("floor_config", "floor_" .. i, cfg)
end

-- ── Generate dungeon ──────────────────────────────────────────────────────────
io.write("[SIM] Generating dungeon...\n")
local floor_cfgs = {}
for i = 1, TOTAL_FLOORS do
    table.insert(floor_cfgs, registry:get("floor_config", "floor_" .. i))
end
generator.generate(world, registry, floor_cfgs)

local total_rooms = 0
for floor_num, fdata in pairs(world.dungeon.floors) do
    local n = 0
    for _ in pairs(fdata.rooms) do n = n + 1 end
    total_rooms = total_rooms + n
    io.write(string.format("  Floor %d: %d rooms\n", floor_num, n))
end
io.write(string.format("[SIM] %d total rooms across %d floors\n", total_rooms, TOTAL_FLOORS))

-- ── Register systems ──────────────────────────────────────────────────────────
local scheduler = Scheduler.new()

scheduler:register(require("systems.action_timer_system"))
scheduler:register(require("systems.ai_system"))
scheduler:register(require("systems.movement_system"))
scheduler:register(require("systems.combat_system"))
scheduler:register(require("systems.skill_system"))
scheduler:register(require("systems.item_system"))
scheduler:register(require("systems.status_system"))
scheduler:register(require("systems.level_system"))
scheduler:register(require("systems.spawn_system"))
scheduler:register(require("systems.ecology_system"))
scheduler:register(require("systems.log_system"))

scheduler:init(world)

-- ── Tick loop ────────────────────────────────────────────────────────────────
io.write(string.format("[SIM] Starting simulation (%d ticks)...\n\n", sim_cfg.max_ticks))

for _ = 1, sim_cfg.max_ticks do
    scheduler:run(world)
    world:advance_tick()
end

-- ── Final summary ─────────────────────────────────────────────────────────────
io.write(string.format("\n[SIM] Simulation complete at tick %d\n", world.tick))
io.write(string.format("[SIM] Events logged: %d\n", #world._event_log))
io.write(string.format("[SIM] Hall of Fame entries: %d\n", #world.hall_of_fame))
for i, entry in ipairs(world.hall_of_fame) do
    io.write(string.format("  #%d %s the %s — Level %d, %d kills, %d ticks\n",
        i, entry.name, entry.archetype, entry.level, entry.kills, entry.ticks_taken))
end
