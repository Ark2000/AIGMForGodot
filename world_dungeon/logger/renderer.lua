-- Renders events into human-readable strings

local M = {}

-- Importance levels
M.IMPORTANCE = {
    TRACE    = 1,
    LOW      = 2,
    MEDIUM   = 3,
    HIGH     = 4,
    CRITICAL = 5,
}

local LEVEL_BY_TYPE = {
    action_timer_ready = M.IMPORTANCE.TRACE,
    entity_moved       = M.IMPORTANCE.LOW,
    modifier_applied   = M.IMPORTANCE.LOW,
    modifier_removed   = M.IMPORTANCE.LOW,
    item_spawned       = M.IMPORTANCE.LOW,
    entity_attacked    = M.IMPORTANCE.MEDIUM,
    skill_used         = M.IMPORTANCE.MEDIUM,
    item_picked_up     = M.IMPORTANCE.MEDIUM,
    item_used          = M.IMPORTANCE.MEDIUM,
    entity_healed      = M.IMPORTANCE.MEDIUM,
    xp_gained          = M.IMPORTANCE.MEDIUM,
    adventurer_spawned = M.IMPORTANCE.HIGH,
    adventurer_died    = M.IMPORTANCE.CRITICAL,
    entity_died        = M.IMPORTANCE.HIGH,
    entity_leveled_up  = M.IMPORTANCE.HIGH,
    item_equipped      = M.IMPORTANCE.HIGH,
    skill_unlocked     = M.IMPORTANCE.HIGH,
    boss_died          = M.IMPORTANCE.CRITICAL,
    yendor_retrieved   = M.IMPORTANCE.CRITICAL,
    adventurer_escaped = M.IMPORTANCE.CRITICAL,
}

function M.importance_of(event_type)
    return LEVEL_BY_TYPE[event_type] or M.IMPORTANCE.LOW
end

function M.importance_name(level)
    for name, v in pairs(M.IMPORTANCE) do
        if v == level then return name end
    end
    return "LOW"
end

function M.importance_from_name(name)
    return M.IMPORTANCE[name] or M.IMPORTANCE.LOW
end

-- Get entity name from world
local function ename(world, eid)
    if not eid then return "someone" end
    return world:entity_name(eid)
end

local function room_desc(world, room_id)
    if not room_id then return "unknown" end
    local ri = world:get_component(room_id, "room_info")
    if ri then return ri.type .. " (floor " .. ri.floor .. ")" end
    return "room#" .. room_id
end

-- ── per-event renderers ───────────────────────────────────────────────────────

local renderers = {}

renderers.entity_moved = function(world, event)
    local d = event.data
    return string.format("%s moved to %s",
        ename(world, d.entity_id),
        room_desc(world, d.to_room))
end

renderers.entity_attacked = function(world, event)
    local d = event.data
    local attacker = ename(world, d.attacker_id)
    local defender = ename(world, d.defender_id)
    if not d.hit then
        return string.format("%s's attack missed %s.", attacker, defender)
    end
    if d.crit then
        return string.format("%s lands a CRITICAL hit on %s for %d damage! (HP: %d→%d)",
            attacker, defender, d.damage, d.hp_before, d.hp_after)
    end
    return string.format("%s hits %s for %d damage. (HP: %d→%d)",
        attacker, defender, d.damage, d.hp_before, d.hp_after)
end

renderers.entity_died = function(world, event)
    local d = event.data
    local name   = ename(world, d.entity_id)
    local killer = d.killer_id and ename(world, d.killer_id) or "unknown"
    -- check if adventurer
    if d.entity_id and world:get_component(d.entity_id, "adventurer_goal") then
        local lvl = world:get_component(d.entity_id, "level")
        local adv = world:get_component(d.entity_id, "adventurer_goal")
        return string.format("*** %s has fallen! (Level %d, %d kills, floor %d) ***",
            name,
            lvl and lvl.current or 1,
            adv and adv.kills or 0,
            adv and adv.target_floor or 1)
    end
    if d.killer_id then
        return string.format("%s was slain by %s.", name, killer)
    end
    return string.format("%s has died.", name)
end

renderers.entity_leveled_up = function(world, event)
    local d = event.data
    return string.format("%s reached level %d!", ename(world, d.entity_id), d.new_level)
end

renderers.skill_unlocked = function(world, event)
    local d = event.data
    return string.format("%s learned new skill: %s (level %d)",
        ename(world, d.entity_id), d.skill_id, d.level)
end

renderers.item_picked_up = function(world, event)
    local d = event.data
    local item_name = ename(world, d.item_id)
    return string.format("%s picked up %s.", ename(world, d.entity_id), item_name)
end

renderers.item_equipped = function(world, event)
    local d = event.data
    local item_name = ename(world, d.item_id)
    return string.format("%s equipped %s (%s).",
        ename(world, d.entity_id), item_name, d.slot or "?")
end

renderers.skill_used = function(world, event)
    local d = event.data
    local registry = world._registry
    local skill_name = d.skill_id
    if registry then
        local def = registry:try_get("skill_def", d.skill_id)
        if def then skill_name = def.name end
    end
    if d.target_id then
        return string.format("%s used %s on %s.",
            ename(world, d.entity_id), skill_name, ename(world, d.target_id))
    end
    return string.format("%s used %s.", ename(world, d.entity_id), skill_name)
end

renderers.xp_gained = function(world, event)
    local d = event.data
    return string.format("%s gained %d XP.", ename(world, d.receiver_id), d.amount)
end

renderers.modifier_applied = function(world, event)
    local d = event.data
    return string.format("%s is now %s.", ename(world, d.entity_id), d.modifier_id)
end

renderers.modifier_removed = function(world, event)
    local d = event.data
    return string.format("%s's %s wore off.", ename(world, d.entity_id), d.modifier_id)
end

renderers.adventurer_spawned = function(world, event)
    local d = event.data
    return string.format("--- %s the %s enters the dungeon. ---",
        d.name or ename(world, d.entity_id), d.archetype or "adventurer")
end

renderers.adventurer_died = function(world, event)
    local d   = event.data
    local e   = d.entry or {}
    return string.format("*** %s the %s has perished! (Level %d, %d kills, %d ticks) ***",
        e.name or "Adventurer", e.archetype or "?",
        e.level or 1, e.kills or 0, e.ticks_taken or 0)
end

renderers.yendor_retrieved = function(world, event)
    local d = event.data
    local e = d.entry or {}
    return string.format(
        "\n=== %s has retrieved the Amulet of Yendor! ===\n*** HALL OF FAME ***\n    Level %d | %d kills | %d ticks\n",
        e.name or "Adventurer", e.level or 1, e.kills or 0, e.ticks_taken or 0)
end

renderers.entity_healed = function(world, event)
    local d = event.data
    return string.format("%s healed for %d HP.", ename(world, d.entity_id), d.amount)
end

renderers.item_used = function(world, event)
    local d = event.data
    return string.format("%s used %s.", ename(world, d.entity_id), ename(world, d.item_id))
end

-- ── public API ─────────────────────────────────────────────────────────────────

function M.render(world, event)
    local fn = renderers[event.type]
    if fn then
        local ok, result = pcall(fn, world, event)
        if ok and result then
            return string.format("[T=%d] %s", event.tick, result)
        end
    end
    return nil
end

return M
