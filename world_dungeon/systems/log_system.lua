-- Priority 95 — consume event_log and output human-readable text

local renderer    = require("logger.renderer")
local perspective = require("logger.perspective")

-- ── world summary ────────────────────────────────────────────────────────────

local function world_summary(world)
    local lines = {}
    table.insert(lines, string.format("\n=== Tick %d Summary ===", world.tick))

    -- active adventurers
    local advs = world:get_all_entities_with("adventurer_goal")
    local adv_descs = {}
    for _, eid in ipairs(advs) do
        if world:is_alive(eid) then
            local id  = world:get_component(eid, "identity")
            local lvl = world:get_component(eid, "level")
            local pos = world:get_component(eid, "position")
            local floor = "?"
            if pos and pos.room_id then
                local ri = world:get_component(pos.room_id, "room_info")
                if ri then floor = tostring(ri.floor) end
            end
            table.insert(adv_descs, string.format("%s lv%d floor%s",
                id and id.name or "?",
                lvl and lvl.current or 1,
                floor))
        end
    end
    if #adv_descs > 0 then
        table.insert(lines, "Adventurers: " .. table.concat(adv_descs, ", "))
    else
        table.insert(lines, "Adventurers: none")
    end

    -- floor populations
    local pop_parts = {}
    for floor_num, floor_data in pairs(world.dungeon.floors) do
        local cnt = 0
        for rid in pairs(floor_data.rooms) do
            for _, eid in ipairs(world:get_entities_in_room(rid)) do
                if world:get_component(eid, "is_actor") and
                   not world:get_component(eid, "adventurer_goal") then
                    cnt = cnt + 1
                end
            end
        end
        table.insert(pop_parts, string.format("F%d:%d", floor_num, cnt))
    end
    table.sort(pop_parts)
    table.insert(lines, "Monster pop: " .. table.concat(pop_parts, "  "))

    -- Hall of Fame
    table.insert(lines, string.format("Hall of Fame: %d", #world.hall_of_fame))
    table.insert(lines, "")
    return table.concat(lines, "\n")
end

-- ── system definition ────────────────────────────────────────────────────────

return {
    name     = "log_system",
    priority = 95,

    init = function(world)
        local sim_cfg = require("data.config.simulation")
        local log_cfg = sim_cfg.log
        if not log_cfg.enabled then return end

        world._log = {
            cfg            = log_cfg,
            perspective    = perspective.new({
                mode             = log_cfg.mode,
                perception_range = 1,
                min_importance   = log_cfg.min_importance or "LOW",
                auto_follow      = log_cfg.auto_follow,
            }),
            last_processed = 0,
            out_file       = nil,
        }

        if log_cfg.output == "file" then
            local dir = log_cfg.file_path:match("^(.*)/")
            if dir then os.execute("mkdir -p " .. dir) end
            world._log.out_file = io.open(log_cfg.file_path, "w")
        end

        -- auto-follow: switch target when current dies
        world:subscribe("adventurer_died", function(event)
            local lg = world._log
            if not lg then return end
            local p = lg.perspective
            if p.mode == "follow" and p.auto_follow then
                if p.target_eid == event.data.entity_id or
                   not world:is_alive(p.target_eid or 0) then
                    p.target_eid = perspective.find_follow_target(world)
                end
            end
        end)

        world:subscribe("adventurer_spawned", function(event)
            local lg = world._log
            if not lg then return end
            local p = lg.perspective
            if p.mode == "follow" and p.auto_follow and not p.target_eid then
                p.target_eid = event.data.entity_id
            end
        end)
    end,

    update = function(world)
        local lg = world._log
        if not lg then return end
        local log_cfg = lg.cfg
        if not log_cfg.enabled then return end

        -- auto-follow maintenance
        local p = lg.perspective
        if p.mode == "follow" and p.auto_follow then
            if not p.target_eid or not world:is_alive(p.target_eid) then
                p.target_eid = perspective.find_follow_target(world)
            end
        end

        -- process new events
        local event_log = world._event_log
        local start     = lg.last_processed + 1
        for i = start, #event_log do
            local event = event_log[i]
            if perspective.should_show(world, p, event) then
                local line = renderer.render(world, event)
                if line then
                    if lg.out_file then
                        lg.out_file:write(line .. "\n")
                        lg.out_file:flush()
                    else
                        print(line)
                    end
                end
            end
        end
        lg.last_processed = #event_log

        -- periodic summary
        local interval = log_cfg.summary_interval or 1000
        if world.tick > 0 and world.tick % interval == 0 then
            local summary = world_summary(world)
            if lg.out_file then
                lg.out_file:write(summary .. "\n")
            else
                print(summary)
            end
        end
    end,
}
