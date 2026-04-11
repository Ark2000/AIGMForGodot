--[[
  games/dungeon.lua — autonomous dungeon simulation for the AI GM benchmark.

  A self-contained world: a lone adventurer descends four dungeon floors,
  fighting enemies, finding loot, and confronting the Shadow Lich. No human
  input — every actor follows scripted rules. Runs forever: death → respawn
  with penalty, victory → new run with higher difficulty.

  Floors:
    1  The Goblin Warrens      8 rooms  goblins / rats / spiders
    2  The Orcish Stronghold   8 rooms  orcs / dark elves / shamans
    3  The Crypt of Shadows    8 rooms  skeletons / wraiths / vampires
    4  The Lich's Sanctum      6 rooms  lich guards + Shadow Lich (3 phases)

  Player AI: EXPLORE → FIGHT ↔ RETREAT → REST → EXPLORE
  Boss AI:   3 phases, each with escalating mechanics

  All events: { t, type, data }

  Usage:
    .\lua54.exe games\dungeon.lua [--world_path=world.json]
                                  [--events_path=events.jsonl]
                                  [--lock_path=service_kimi/session_01/agent.lock]
                                  [--tps=1] [--tick_sleep=0.3]
                                  [--reset] [--test]
]]

local json = require("json")

-- ── CONFIG ────────────────────────────────────────────────────────────────────

local config = {
  world_path  = "world.json",
  events_path = "events.jsonl",
  lock_path   = "service_kimi/session_01/agent.lock",
  tps         = 1,    -- ticks per real-second for catch-up after agent acts
  tick_sleep  = 0.3,  -- seconds between normal ticks; 0 = as fast as possible
}

local do_reset = false
local do_test  = false
local do_ticks = nil   -- --ticks=N: run exactly N ticks then exit (for inspection)
for i = 1, #arg do
  local a = arg[i]
  if     a == "--reset" then do_reset = true
  elseif a == "--test"  then do_test  = true
  else
    local k, v = a:match("^%-%-([^=]+)=(.*)")
    if k then
      if k == "tps" or k == "tick_sleep" then config[k] = tonumber(v) or config[k]
      elseif k == "ticks" then do_ticks = tonumber(v)
      else config[k] = v end
    end
  end
end

-- ── I/O ───────────────────────────────────────────────────────────────────────

local function read_file(path)
  local f = io.open(path, "rb"); if not f then return nil end
  local s = f:read("*a"); f:close(); return s
end

local function write_atomic(path, text)
  local tmp = path .. ".tmp"
  local f = assert(io.open(tmp, "wb")); f:write(text); f:close()
  os.remove(path)
  if not os.rename(tmp, path) then os.remove(path); assert(os.rename(tmp, path)) end
end

local function load_world()
  local s = read_file(config.world_path); if not s then return nil end
  local ok, t = pcall(json.decode, s)
  return (ok and type(t) == "table") and t or nil
end

local function save_world(w) write_atomic(config.world_path, json.encode(w)) end

local function emit(w, etype, data)
  local ev = { t = w.t, type = etype, data = data or {} }
  local f = io.open(config.events_path, "ab"); if not f then return end
  f:write(json.encode(ev) .. "\n"); f:close()
end

local function agent_active()
  local f = io.open(config.lock_path, "rb"); if f then f:close(); return true end; return false
end

local function sleep_s(s)
  if s <= 0 then return end
  local ok = os.execute(string.format("sleep %.3f 2>/dev/null", s))
  if not ok then os.execute(string.format("timeout /t %d /nobreak >nul 2>&1", math.max(1, math.floor(s)))) end
end

-- ── HELPERS ───────────────────────────────────────────────────────────────────

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function pick(t)
  if not t or #t == 0 then return nil end
  return t[math.random(#t)]
end

local function roll(lo, hi) return math.random(lo, hi) end

local function has_status(entity, name)
  for _, s in ipairs(entity.statuses or {}) do
    if s.name == name then return true end
  end
  return false
end

local function add_status(entity, name, duration)
  -- Don't stack; refresh instead
  for _, s in ipairs(entity.statuses or {}) do
    if s.name == name then s.duration = duration; return end
  end
  entity.statuses = entity.statuses or {}
  table.insert(entity.statuses, { name = name, duration = duration })
end

local function remove_status(entity, name)
  local out = {}
  for _, s in ipairs(entity.statuses or {}) do
    if s.name ~= name then out[#out+1] = s end
  end
  entity.statuses = out
end

-- ── DATA DEFINITIONS ──────────────────────────────────────────────────────────

-- ai modes: "normal" | "berserker" | "healer" | "ranged" | "slow" | "life_drain" | "boss"
local ENEMY_DEFS = {
  goblin_scout    = { name="Goblin Scout",     hp=25,  attack=6,  defense=1, xp=15, gold={1,5},    floor=1 },
  goblin_shaman   = { name="Goblin Shaman",    hp=20,  attack=4,  defense=0, xp=25, gold={3,8},    floor=1, ai="healer" },
  cave_rat        = { name="Cave Rat",         hp=12,  attack=4,  defense=0, xp=8,  gold={0,2},    floor=1 },
  giant_spider    = { name="Giant Spider",     hp=22,  attack=5,  defense=1, xp=18, gold={0,3},    floor=1, status_on_hit="poisoned" },
  orc_warrior     = { name="Orc Warrior",      hp=55,  attack=12, defense=3, xp=40, gold={5,15},   floor=2 },
  orc_berserker   = { name="Orc Berserker",    hp=45,  attack=16, defense=1, xp=50, gold={8,18},   floor=2, ai="berserker" },
  orc_shaman      = { name="Orc Shaman",       hp=35,  attack=8,  defense=2, xp=45, gold={10,20},  floor=2, ai="healer" },
  dark_elf_archer = { name="Dark Elf Archer",  hp=30,  attack=11, defense=2, xp=35, gold={8,15},   floor=2, status_on_hit="poisoned" },
  skeleton        = { name="Skeleton",         hp=40,  attack=9,  defense=4, xp=30, gold={0,5},    floor=3 },
  zombie          = { name="Zombie",           hp=65,  attack=7,  defense=2, xp=35, gold={0,3},    floor=3, ai="slow" },
  wraith          = { name="Wraith",           hp=35,  attack=13, defense=0, xp=55, gold={5,10},   floor=3, status_on_hit="cursed" },
  vampire_spawn   = { name="Vampire Spawn",    hp=50,  attack=11, defense=3, xp=60, gold={10,25},  floor=3, ai="life_drain" },
  lich_guard      = { name="Lich Guard",       hp=80,  attack=14, defense=5, xp=80, gold={15,30},  floor=4 },
  lich_servant    = { name="Lich Servant",     hp=45,  attack=12, defense=3, xp=70, gold={10,20},  floor=4 },
  shadow_lich     = { name="Shadow Lich",      hp=500, attack=25, defense=8, xp=0,  gold={150,300},floor=4, ai="boss", phases=3 },
}

local ITEM_DEFS = {
  health_potion         = { name="Health Potion",          kind="consumable", heal=40  },
  greater_health_potion = { name="Greater Health Potion",  kind="consumable", heal=80  },
  antidote              = { name="Antidote",               kind="consumable", cure=true },
  scroll_fire           = { name="Scroll of Fire",         kind="consumable", aoe_damage=60 },
  scroll_lightning      = { name="Scroll of Lightning",    kind="consumable", aoe_damage=90 },
  short_sword           = { name="Short Sword",            kind="weapon",     attack_bonus=3  },
  enchanted_sword       = { name="Enchanted Sword",        kind="weapon",     attack_bonus=8  },
  shadow_blade          = { name="Shadow Blade",           kind="weapon",     attack_bonus=14, status_on_hit="weakened" },
  leather_armor         = { name="Leather Armor",          kind="armor",      defense_bonus=2 },
  chain_mail            = { name="Chain Mail",             kind="armor",      defense_bonus=5 },
  shadow_plate          = { name="Shadow Plate",           kind="armor",      defense_bonus=9 },
  ring_of_regen         = { name="Ring of Regeneration",   kind="accessory",  regen_passive=true },
  amulet_of_protection  = { name="Amulet of Protection",   kind="accessory",  defense_bonus=3 },
  crown_of_the_damned   = { name="Crown of the Damned",    kind="accessory",  attack_bonus=10, defense_bonus=5 },
}

-- status name → { damage_per_tick, heal_per_tick, attack_malus, skip_attack, duration }
local STATUS_DEFS = {
  poisoned     = { damage_per_tick=5, duration=4 },
  burning      = { damage_per_tick=8, duration=3 },
  stunned      = { skip_attack=true,  duration=1 },
  regenerating = { heal_per_tick=8,   duration=5 },
  cursed       = { attack_malus=3,    duration=5 },
  weakened     = { attack_malus=5,    duration=4 },
  blessed      = { hit_bonus=0.10,    duration=8 },
}

-- Flavor text: arrays, picked randomly
local FLAVOR = {
  floor_enter = {
    [1] = "Guttering torchlight illuminates rough-hewn walls slick with moisture. Somewhere ahead, goblins chitter.",
    [2] = "The smell of blood and iron hits you like a wall. Orcish war-drums echo through stone corridors.",
    [3] = "The air turns cold and still. The stench of old death clings to every surface. Nothing living should be here.",
    [4] = "Reality bends. The walls are obsidian, floating above a void between worlds. The Lich's presence is overwhelming.",
  },
  hit_player = {
    goblin_scout    = { "A rusted blade nicks the arm.", "The scout darts in before you can react." },
    orc_warrior     = { "The axe blow rattles bone.", "Brute force sends the adventurer staggering." },
    orc_berserker   = { "Reckless fury overwhelms the guard.", "The berserker screams and hammers through." },
    wraith          = { "Cold passes not through flesh, but soul.", "Warmth drains from blood on contact." },
    vampire_spawn   = { "Fangs find the throat. Life ebbs away.", "The spawn drinks deep." },
    shadow_lich     = { "Black lightning tears through the guard.", "A void-sphere detonates against the chest." },
  },
  boss_phase = {
    [2] = { "The Lich shatters its own phylactery — raw necrotic energy floods the chamber.",
            "Phase one was a test. The Lich tears off its mortal mask." },
    [3] = { "Nothing but spite remains. The Lich pours everything into a storm of shadow.",
            "The sanctum cracks. It will drag everything down with it." },
  },
  player_levelup = {
    "Battle-hardened, reflexes sharpen and strikes hit harder.",
    "The near-death sharpens something deep. Power crystallises.",
    "Another monster falls. Another lesson learned in blood.",
  },
  death = {
    "The adventurer crumples. Darkness takes them.",
    "The light fades from their eyes. The dungeon claims another.",
    "They fall. The dungeon does not mourn.",
  },
  victory = {
    "The Shadow Lich howls as its form dissolves. The Sanctum shudders and stills.",
    "With the final blow, centuries of dark dominion collapse into silence.",
  },
}

-- ── FLOOR TEMPLATES ───────────────────────────────────────────────────────────

local FLOOR_TEMPLATES = {
  {
    name = "The Goblin Warrens",
    rooms = {
      { id="f1_entrance",  type="safe",     conns={"f1_warrens"},                 enemies={},                                          loot={} },
      { id="f1_warrens",   type="combat",   conns={"f1_entrance","f1_larder"},     enemies={"goblin_scout","goblin_scout"},              loot={"health_potion"} },
      { id="f1_larder",    type="combat",   conns={"f1_warrens","f1_shrine"},      enemies={"cave_rat","cave_rat","giant_spider"},        loot={} },
      { id="f1_shrine",    type="shrine",   conns={"f1_larder","f1_nest"},         enemies={},                                          loot={} },
      { id="f1_nest",      type="combat",   conns={"f1_shrine","f1_treasury"},     enemies={"goblin_shaman","goblin_scout","goblin_scout"}, loot={} },
      { id="f1_treasury",  type="treasure", conns={"f1_nest","f1_trap"},           enemies={},                                          loot={"short_sword","health_potion","health_potion"} },
      { id="f1_trap",      type="trap",     conns={"f1_treasury","f1_stairs"},     enemies={},                                          loot={"antidote"}, trap_damage=20 },
      { id="f1_stairs",    type="stairs",   conns={"f1_trap"},                     enemies={},                                          loot={} },
    },
  },
  {
    name = "The Orcish Stronghold",
    rooms = {
      { id="f2_entrance",   type="safe",     conns={"f2_barracks"},                enemies={},                                          loot={} },
      { id="f2_barracks",   type="combat",   conns={"f2_entrance","f2_market"},     enemies={"orc_warrior","orc_warrior"},               loot={"health_potion"} },
      { id="f2_market",     type="merchant", conns={"f2_barracks","f2_arena"},      enemies={},                                          loot={} },
      { id="f2_arena",      type="combat",   conns={"f2_market","f2_armory"},       enemies={"orc_berserker","orc_berserker"},            loot={} },
      { id="f2_armory",     type="treasure", conns={"f2_arena","f2_watchtower"},    enemies={},                                          loot={"chain_mail","greater_health_potion","enchanted_sword"} },
      { id="f2_watchtower", type="combat",   conns={"f2_armory","f2_pit"},          enemies={"dark_elf_archer","dark_elf_archer","orc_shaman"}, loot={} },
      { id="f2_pit",        type="trap",     conns={"f2_watchtower","f2_stairs"},   enemies={},                                          loot={"antidote"}, trap_damage=30 },
      { id="f2_stairs",     type="stairs",   conns={"f2_pit"},                      enemies={},                                          loot={} },
    },
  },
  {
    name = "The Crypt of Shadows",
    rooms = {
      { id="f3_entrance",   type="safe",     conns={"f3_gallery"},                  enemies={},                                          loot={} },
      { id="f3_gallery",    type="combat",   conns={"f3_entrance","f3_ossuary"},     enemies={"skeleton","skeleton","zombie"},             loot={"health_potion"} },
      { id="f3_ossuary",    type="trap",     conns={"f3_gallery","f3_shrine"},       enemies={},                                          loot={}, trap_damage=25 },
      { id="f3_shrine",     type="shrine",   conns={"f3_ossuary","f3_vaults"},       enemies={},                                          loot={} },
      { id="f3_vaults",     type="combat",   conns={"f3_shrine","f3_mausoleum"},     enemies={"wraith","wraith"},                          loot={"enchanted_sword"} },
      { id="f3_mausoleum",  type="combat",   conns={"f3_vaults","f3_blood_hall"},    enemies={"vampire_spawn","vampire_spawn"},            loot={"scroll_fire"} },
      { id="f3_blood_hall", type="treasure", conns={"f3_mausoleum","f3_stairs"},     enemies={},                                          loot={"shadow_blade","ring_of_regen","greater_health_potion"} },
      { id="f3_stairs",     type="stairs",   conns={"f3_blood_hall"},                enemies={},                                          loot={} },
    },
  },
  {
    name = "The Lich's Sanctum",
    rooms = {
      { id="f4_entrance",    type="safe",     conns={"f4_antechamber"},              enemies={},                                          loot={} },
      { id="f4_antechamber", type="combat",   conns={"f4_entrance","f4_library"},    enemies={"lich_guard","lich_guard"},                  loot={"greater_health_potion"} },
      { id="f4_library",     type="combat",   conns={"f4_antechamber","f4_reliquary"}, enemies={"lich_servant","lich_servant","lich_guard"}, loot={"scroll_lightning"} },
      { id="f4_reliquary",   type="treasure", conns={"f4_library","f4_vestibule"},   enemies={},                                          loot={"shadow_plate","amulet_of_protection","greater_health_potion"} },
      { id="f4_vestibule",   type="combat",   conns={"f4_reliquary","f4_throne"},    enemies={"lich_servant","lich_servant"},              loot={} },
      { id="f4_throne",      type="boss",     conns={"f4_vestibule"},                enemies={"shadow_lich"},                              loot={"crown_of_the_damned"} },
    },
  },
}

-- Room depth: position index within the floor (used for navigation direction)
local ROOM_DEPTH = {}
for fi, ft in ipairs(FLOOR_TEMPLATES) do
  for ri, r in ipairs(ft.rooms) do
    ROOM_DEPTH[r.id] = ri  -- higher index = deeper
  end
end

-- ── WORLD GENERATION ──────────────────────────────────────────────────────────

local function new_world(prev)
  local run        = prev and (prev.run + 1) or 0
  local difficulty = 1.0 + run * 0.15  -- enemies get 15% stronger each run

  -- Build floors and entity table
  local floors   = {}
  local entities = {}
  local eid_seq  = { n = 0 }

  local function next_eid(etype)
    eid_seq.n = eid_seq.n + 1
    return etype .. "_" .. eid_seq.n
  end

  for fi, ft in ipairs(FLOOR_TEMPLATES) do
    local rooms = {}
    for _, rt in ipairs(ft.rooms) do
      -- Deep-copy loot and connections
      local loot  = {}; for _, v in ipairs(rt.loot  or {}) do loot[#loot+1]  = v end
      local conns = {}; for _, v in ipairs(rt.conns or {}) do conns[#conns+1] = v end
      -- Spawn entities
      local room_entity_ids = {}
      for _, etype in ipairs(rt.enemies or {}) do
        local def = ENEMY_DEFS[etype]
        if def then
          local eid = next_eid(etype)
          local scaled_hp = math.floor(def.hp * difficulty)
          entities[eid] = {
            id       = eid,
            etype    = etype,
            name     = def.name,
            hp       = scaled_hp,
            max_hp   = scaled_hp,
            attack   = math.floor(def.attack * difficulty),
            defense  = def.defense or 0,
            xp       = def.xp or 0,
            gold_min = (def.gold or {1,1})[1],
            gold_max = (def.gold or {1,1})[2],
            ai       = def.ai or "normal",
            status_on_hit = def.status_on_hit,
            phases   = def.phases,
            phase    = def.phases and 1 or nil,
            floor    = fi,
            room     = rt.id,
            alive    = true,
            statuses = {},
            slow_skip = false,  -- for "slow" AI: skip every other tick
          }
          room_entity_ids[#room_entity_ids+1] = eid
        end
      end
      rooms[rt.id] = {
        id           = rt.id,
        type         = rt.type,
        conns        = conns,
        entity_ids   = room_entity_ids,
        loot         = loot,
        visited      = false,
        trap_triggered = false,
        trap_damage  = rt.trap_damage,
      }
    end
    floors[fi] = { name = ft.name, rooms = rooms, cleared = false }
  end

  -- Player initial state
  local player = {
    hp          = 100,
    max_hp      = 100,
    base_attack = 10,
    base_defense= 2,
    level       = 1,
    xp          = 0,
    xp_next     = 50,
    gold        = 10,
    floor       = 1,
    room        = "f1_entrance",
    alive       = true,
    ai_state    = "EXPLORE",
    statuses    = {},
    inventory   = {},
    equipment   = {},  -- slot → item_id
  }

  return {
    t          = prev and prev.t or 0,
    run        = run,
    difficulty = difficulty,
    player     = player,
    floors     = floors,
    entities   = entities,
    boss_phase = 1,  -- tracks current Shadow Lich phase globally
  }
end

-- ── PLAYER STATS (with equipment) ─────────────────────────────────────────────

local function player_attack(p)
  local atk = p.base_attack
  for _, item_id in pairs(p.equipment) do
    local def = ITEM_DEFS[item_id]
    if def and def.attack_bonus then atk = atk + def.attack_bonus end
  end
  for _, s in ipairs(p.statuses or {}) do
    local sd = STATUS_DEFS[s.name]
    if sd and sd.attack_malus then atk = atk - sd.attack_malus end
  end
  return math.max(1, atk)
end

local function player_defense(p)
  local def = p.base_defense
  for _, item_id in pairs(p.equipment) do
    local idef = ITEM_DEFS[item_id]
    if idef and idef.defense_bonus then def = def + idef.defense_bonus end
  end
  return math.max(0, def)
end

local function player_weapon(p)
  return p.equipment["weapon"]
end

-- ── INVENTORY / EQUIPMENT ─────────────────────────────────────────────────────

local function has_item(p, item_id)
  for _, v in ipairs(p.inventory) do if v == item_id then return true end end
  return false
end

local function remove_item(p, item_id)
  for i, v in ipairs(p.inventory) do
    if v == item_id then table.remove(p.inventory, i); return true end
  end
  return false
end

local function equip_item(w, p, item_id)
  local def = ITEM_DEFS[item_id]
  if not def then return end
  local slot = def.kind  -- "weapon", "armor", "accessory"
  if slot == "consumable" then return end
  -- Replace existing if strictly better
  local current = p.equipment[slot]
  local current_def = current and ITEM_DEFS[current]
  local new_better = true
  if current_def then
    local cur_val = (current_def.attack_bonus or 0) + (current_def.defense_bonus or 0)
    local new_val = (def.attack_bonus or 0) + (def.defense_bonus or 0)
    new_better = new_val > cur_val
  end
  if new_better then
    if current then p.inventory[#p.inventory+1] = current end  -- unequip old → back to bag
    p.equipment[slot] = item_id
    remove_item(p, item_id)
    emit(w, "item_equipped", { item=item_id, name=def.name, slot=slot })
  end
end

local function use_consumable(w, p, item_id)
  local def = ITEM_DEFS[item_id]
  if not def or def.kind ~= "consumable" then return false end
  if not remove_item(p, item_id) then return false end

  if def.heal then
    local gained = math.min(def.heal, p.max_hp - p.hp)
    p.hp = p.hp + gained
    emit(w, "item_used", { item=item_id, name=def.name, effect="heal", hp_gained=gained, hp=p.hp })

  elseif def.cure then
    local cured = {}
    for _, s in ipairs(p.statuses) do
      if STATUS_DEFS[s.name] and STATUS_DEFS[s.name].damage_per_tick then
        cured[#cured+1] = s.name
      end
    end
    for _, sname in ipairs(cured) do remove_status(p, sname) end
    emit(w, "item_used", { item=item_id, name=def.name, effect="cure", cured=cured })

  elseif def.aoe_damage then
    local floor_data = w.floors[p.floor]
    local room_data  = floor_data.rooms[p.room]
    local total = 0
    local killed = {}
    for _, eid in ipairs(room_data.entity_ids) do
      local e = w.entities[eid]
      if e and e.alive then
        e.hp = e.hp - def.aoe_damage
        total = total + def.aoe_damage
        if e.hp <= 0 then e.alive = false; killed[#killed+1] = eid end
      end
    end
    emit(w, "item_used", { item=item_id, name=def.name, effect="aoe_damage",
      damage=def.aoe_damage, total_damage=total, enemies_killed=#killed })
    for _, eid in ipairs(killed) do
      local e = w.entities[eid]
      local gold = roll(e.gold_min, e.gold_max)
      p.gold = p.gold + gold
      emit(w, "enemy_killed", { entity_id=eid, name=e.name, gold_looted=gold, xp_gained=e.xp })
      p.xp = p.xp + e.xp
    end
  end
  return true
end

-- ── STATUS EFFECTS ────────────────────────────────────────────────────────────

local function tick_statuses(w, entity, label)
  local surviving = {}
  for _, s in ipairs(entity.statuses or {}) do
    local sd = STATUS_DEFS[s.name]
    if sd then
      if sd.damage_per_tick then
        entity.hp = entity.hp - sd.damage_per_tick
        emit(w, "status_tick", { entity=label, status=s.name,
          damage=sd.damage_per_tick, hp=entity.hp })
      elseif sd.heal_per_tick then
        local gained = math.min(sd.heal_per_tick, entity.max_hp - entity.hp)
        entity.hp = entity.hp + gained
        emit(w, "status_tick", { entity=label, status=s.name,
          heal=gained, hp=entity.hp })
      end
    end
    s.duration = s.duration - 1
    if s.duration > 0 then surviving[#surviving+1] = s
    else emit(w, "status_expired", { entity=label, status=s.name }) end
  end
  entity.statuses = surviving
end

-- ── XP / LEVELLING ────────────────────────────────────────────────────────────

local function check_levelup(w, p)
  while p.xp >= p.xp_next do
    p.xp      = p.xp - p.xp_next
    p.level   = p.level + 1
    p.xp_next = math.floor(p.xp_next * 1.5)
    p.base_attack  = p.base_attack  + 2
    p.base_defense = p.base_defense + 1
    local old_max = p.max_hp
    p.max_hp  = p.max_hp + 15
    p.hp      = p.hp + 15  -- heal on level up
    emit(w, "player_levelup", {
      level       = p.level,
      hp          = p.hp,
      max_hp      = p.max_hp,
      attack      = player_attack(p),
      defense     = player_defense(p),
      flavor      = pick(FLAVOR.player_levelup),
    })
    p.hp = clamp(p.hp, 0, p.max_hp)
    _ = old_max  -- suppress unused warning
  end
end

-- ── COMBAT ────────────────────────────────────────────────────────────────────

-- Returns damage dealt (after defense), crit flag
local function calc_damage(raw_attack, defense, crit_chance)
  local crit = math.random() < (crit_chance or 0.08)
  local variance = roll(-3, 4)
  local dmg = math.max(1, raw_attack + variance - defense)
  if crit then dmg = math.floor(dmg * 1.8) end
  return dmg, crit
end

-- Enemy attacks player
local function enemy_attack_player(w, eid, e, p)
  local stunned = has_status(e, "stunned")
  if stunned then
    emit(w, "enemy_stunned", { entity_id=eid, name=e.name })
    remove_status(e, "stunned")
    return
  end
  -- Slow AI: skip every other tick
  if e.ai == "slow" then
    e.slow_skip = not e.slow_skip
    if e.slow_skip then return end
  end
  -- Berserker: +30% attack when below half HP
  local raw = e.attack
  if e.ai == "berserker" and e.hp < e.max_hp * 0.5 then
    raw = math.floor(raw * 1.30)
  end
  local dmg, crit = calc_damage(raw, player_defense(p))
  p.hp = p.hp - dmg
  local flv_pool = FLAVOR.hit_player[e.etype] or {}
  emit(w, "enemy_attacked_player", {
    entity_id   = eid,
    name        = e.name,
    damage      = dmg,
    crit        = crit,
    player_hp   = p.hp,
    flavor      = pick(flv_pool),
  })
  -- Apply on-hit status
  if e.status_on_hit and math.random() < 0.40 then
    local sd = STATUS_DEFS[e.status_on_hit]
    add_status(p, e.status_on_hit, sd.duration)
    emit(w, "status_applied", { entity="player", status=e.status_on_hit, source=eid })
  end
  -- Life drain: heal the attacker
  if e.ai == "life_drain" then
    local heal = math.floor(dmg * 0.4)
    e.hp = clamp(e.hp + heal, 0, e.max_hp)
    emit(w, "life_drained", { entity_id=eid, heal=heal })
  end
end

-- Player attacks one enemy
local function player_attack_enemy(w, p, eid, e)
  local stunned = has_status(p, "stunned")
  if stunned then
    emit(w, "player_stunned", { hp=p.hp })
    remove_status(p, "stunned")
    return
  end
  local raw = player_attack(p)
  local dmg, crit = calc_damage(raw, e.defense)
  e.hp = e.hp - dmg
  local wpn = player_weapon(p)
  emit(w, "player_attacked_enemy", {
    entity_id = eid,
    name      = e.name,
    damage    = dmg,
    crit      = crit,
    enemy_hp  = e.hp,
    weapon    = wpn,
  })
  -- On-hit weapon status
  if wpn then
    local wdef = ITEM_DEFS[wpn]
    if wdef and wdef.status_on_hit and math.random() < 0.30 then
      local sd = STATUS_DEFS[wdef.status_on_hit]
      add_status(e, wdef.status_on_hit, sd.duration)
      emit(w, "status_applied", { entity=eid, status=wdef.status_on_hit, source="player" })
    end
  end
  if e.hp <= 0 then
    e.alive = false
    local gold = roll(e.gold_min, e.gold_max)
    p.gold = p.gold + gold
    p.xp   = p.xp + e.xp
    emit(w, "enemy_killed", { entity_id=eid, name=e.name, gold_looted=gold, xp_gained=e.xp })
    check_levelup(w, p)
  end
end

-- ── BOSS PHASE MANAGEMENT ─────────────────────────────────────────────────────

local function check_boss_phase(w, eid, e)
  if e.ai ~= "boss" or not e.phases or not e.alive then return end
  local pct = e.hp / e.max_hp
  local new_phase = 1
  if pct <= 0.33 then new_phase = 3
  elseif pct <= 0.66 then new_phase = 2 end
  if new_phase > (e.phase or 1) then
    e.phase = new_phase
    w.boss_phase = new_phase
    local flv = pick(FLAVOR.boss_phase[new_phase]) or ""
    emit(w, "boss_phase_changed", {
      entity_id = eid,
      name      = e.name,
      phase     = new_phase,
      hp        = e.hp,
      hp_pct    = pct,
      flavor    = flv,
    })
    -- Phase 2: summon a lich_servant in the same room
    if new_phase == 2 then
      local seq = 0
      for k in pairs(w.entities) do
        local n = tonumber(k:match("lich_servant_(%d+)")) or 0
        if n > seq then seq = n end
      end
      local new_id = "lich_servant_" .. (seq + 1)
      local base = ENEMY_DEFS.lich_servant
      w.entities[new_id] = {
        id=new_id, etype="lich_servant", name=base.name,
        hp=base.hp, max_hp=base.hp, attack=base.attack, defense=base.defense,
        xp=0, gold_min=0, gold_max=0,
        ai="normal", floor=e.floor, room=e.room, alive=true, statuses={},
        slow_skip=false,
      }
      local room = w.floors[e.floor].rooms[e.room]
      room.entity_ids[#room.entity_ids+1] = new_id
      emit(w, "enemy_summoned", { summoner=eid, entity_id=new_id, name=base.name })
    end
    -- Phase 3: apply burning aura (re-emitted each tick via boss logic)
  end
end

-- ── HEALER AI ─────────────────────────────────────────────────────────────────

local function try_heal_ally(w, eid, healer, room)
  -- Find lowest-HP alive ally in room
  local target_id, target, lowest = nil, nil, math.huge
  for _, other_id in ipairs(room.entity_ids) do
    local other = w.entities[other_id]
    if other and other.alive and other_id ~= eid and other.hp < other.max_hp then
      if other.hp < lowest then
        lowest    = other.hp
        target_id = other_id
        target    = other
      end
    end
  end
  -- Heal self if no injured ally
  if not target_id and healer.hp < healer.max_hp then
    target_id = eid; target = healer
  end
  if target_id then
    local heal = roll(12, 22)
    target.hp = clamp(target.hp + heal, 0, target.max_hp)
    emit(w, "enemy_healed", { healer_id=eid, target_id=target_id,
      healer_name=healer.name, heal=heal, target_hp=target.hp })
    return true
  end
  return false
end

-- ── ROOM LOGIC: shrine, merchant, trap ────────────────────────────────────────

local function apply_shrine(w, p, room)
  if room.shrine_used then return end
  room.shrine_used = true
  -- 60% chance: heal to 70% HP; 40% chance: bless
  if math.random() < 0.60 then
    local target_hp = math.floor(p.max_hp * 0.70)
    local gained = math.max(0, target_hp - p.hp)
    p.hp = math.max(p.hp, target_hp)
    emit(w, "shrine_healed", { hp_gained=gained, hp=p.hp })
  else
    add_status(p, "blessed", STATUS_DEFS.blessed.duration)
    emit(w, "shrine_blessed", { duration=STATUS_DEFS.blessed.duration })
  end
end

local function apply_merchant(w, p, room)
  if room.merchant_visited then return end
  room.merchant_visited = true
  -- Buy best affordable potion if below max HP
  local price = 15
  while p.gold >= price and p.hp < p.max_hp do
    p.gold = p.gold - price
    p.inventory[#p.inventory+1] = "health_potion"
    emit(w, "merchant_purchase", { item="health_potion", price=price, gold_remaining=p.gold })
    price = price + 5  -- each purchase costs more
  end
end

local function apply_trap(w, p, room)
  if room.trap_triggered then return end
  room.trap_triggered = true
  local dmg = room.trap_damage or 20
  p.hp = p.hp - dmg
  emit(w, "trap_triggered", { damage=dmg, player_hp=p.hp })
end

-- ── LOOT PICKUP ───────────────────────────────────────────────────────────────

local function collect_loot(w, p, room)
  while #room.loot > 0 do
    local item_id = table.remove(room.loot, 1)
    local def = ITEM_DEFS[item_id]
    if def then
      if def.kind == "consumable" then
        p.inventory[#p.inventory+1] = item_id
        emit(w, "item_found", { item=item_id, name=def.name, added_to="inventory" })
      else
        -- Auto-equip or add to inventory
        p.inventory[#p.inventory+1] = item_id
        emit(w, "item_found", { item=item_id, name=def.name, added_to="inventory" })
        equip_item(w, p, item_id)
      end
    end
  end
end

-- ── NAVIGATION ────────────────────────────────────────────────────────────────

local function living_enemies_in_room(w, floor_idx, room_id)
  local room = w.floors[floor_idx].rooms[room_id]
  local living = {}
  for _, eid in ipairs(room.entity_ids) do
    local e = w.entities[eid]
    if e and e.alive then living[#living+1] = eid end
  end
  return living
end

-- Return next room ID going forward (deeper), or nil
local function next_forward_room(w, floor_idx, room_id)
  local room = w.floors[floor_idx].rooms[room_id]
  local cur_depth = ROOM_DEPTH[room_id] or 0
  local best, best_depth = nil, 0
  for _, conn in ipairs(room.conns) do
    local d = ROOM_DEPTH[conn] or 0
    if d > cur_depth and d > best_depth then
      best = conn; best_depth = d
    end
  end
  return best
end

-- Return nearest safe room going backward, or nil
local function retreat_room(w, floor_idx, room_id)
  local room = w.floors[floor_idx].rooms[room_id]
  local cur_depth = ROOM_DEPTH[room_id] or 0
  for _, conn in ipairs(room.conns) do
    local d = ROOM_DEPTH[conn] or 0
    if d < cur_depth then
      local living = living_enemies_in_room(w, floor_idx, conn)
      if #living == 0 then return conn end
    end
  end
  return nil
end

local function move_player(w, p, dest_room_id)
  local src = p.room
  p.room = dest_room_id
  local room = w.floors[p.floor].rooms[dest_room_id]
  if not room.visited then
    room.visited = true
    emit(w, "room_entered", { floor=p.floor, room=dest_room_id, type=room.type, from=src })
  else
    emit(w, "room_moved", { floor=p.floor, room=dest_room_id, type=room.type, from=src })
  end
  -- Trap on first entry
  if room.type == "trap" then apply_trap(w, p, room) end
  -- Boss room announcement (first entry only)
  if room.type == "boss" and not room.boss_announced then
    room.boss_announced = true
    emit(w, "boss_room_entered", { floor=p.floor, room=dest_room_id,
      flavor = "A presence of absolute malice fills the chamber." })
  end
end

-- ── PLAYER AI DECISION ────────────────────────────────────────────────────────

local function decide_player_ai(w, p)
  local living = living_enemies_in_room(w, p.floor, p.room)
  local hp_pct = p.hp / p.max_hp

  if #living > 0 then
    -- Enemies present: fight unless critically low with no potions
    if hp_pct < 0.25 and not has_item(p, "health_potion") and not has_item(p, "greater_health_potion") then
      p.ai_state = "RETREAT"
    else
      p.ai_state = "FIGHT"
    end
  else
    -- Room is clear — transition out of FIGHT/RETREAT/REST toward EXPLORE
    if p.ai_state == "FIGHT" or p.ai_state == "EXPLORE" then
      p.ai_state = "EXPLORE"
    elseif p.ai_state == "RETREAT" then
      p.ai_state = hp_pct < 0.50 and "REST" or "EXPLORE"
    elseif p.ai_state == "REST" then
      if hp_pct >= 0.65 then p.ai_state = "EXPLORE" end
      -- else stay resting
    end
  end
end

-- ── FLOOR DESCENT ─────────────────────────────────────────────────────────────

local function try_descend(w, p)
  local room = w.floors[p.floor].rooms[p.room]
  if room.type ~= "stairs" then return false end
  if p.floor >= 4 then return false end
  local next_floor = p.floor + 1
  p.floor = next_floor
  p.room  = "f" .. next_floor .. "_entrance"
  emit(w, "floor_descended", {
    floor   = next_floor,
    name    = w.floors[next_floor].name,
    flavor  = FLAVOR.floor_enter[next_floor] or "",
  })
  return true
end

-- ── MAIN TICK ─────────────────────────────────────────────────────────────────

local function tick(w)
  w.t = w.t + 1
  local t  = w.t
  local p  = w.player

  -- Passive regen from ring accessory
  if p.equipment["accessory"] == "ring_of_regen" and p.hp < p.max_hp then
    local regen = 3
    p.hp = clamp(p.hp + regen, 0, p.max_hp)
    emit(w, "passive_regen", { hp=p.hp, source="ring_of_regen" })
  end

  -- Tick player statuses
  tick_statuses(w, p, "player")

  -- Player death from status (poison, etc.)
  if p.hp <= 0 then
    p.hp = 0; p.alive = false
    emit(w, "player_died", {
      floor=p.floor, room=p.room, level=p.level,
      flavor=pick(FLAVOR.death)
    })
    return w
  end

  -- Tick entity statuses (only alive entities in player's vicinity)
  for eid, e in pairs(w.entities) do
    if e.alive and e.floor == p.floor then
      tick_statuses(w, e, eid)
      if e.hp <= 0 then
        e.alive = false
        emit(w, "enemy_killed_by_status", { entity_id=eid, name=e.name })
      end
    end
  end

  local room_data = w.floors[p.floor].rooms[p.room]
  local living    = living_enemies_in_room(w, p.floor, p.room)

  -- Phase 3 boss aura: damage player each tick while in boss room
  if room_data.type == "boss" and w.boss_phase >= 3 then
    for _, eid in ipairs(living) do
      local e = w.entities[eid]
      if e and e.ai == "boss" and e.alive then
        local aura_dmg = 8
        p.hp = p.hp - aura_dmg
        emit(w, "boss_aura_damage", { entity_id=eid, damage=aura_dmg, player_hp=p.hp })
      end
    end
  end

  -- Potion use: before engaging, heal if low
  local hp_pct = p.hp / p.max_hp
  if hp_pct < 0.40 then
    local potion = has_item(p, "greater_health_potion") and "greater_health_potion"
               or (has_item(p, "health_potion") and "health_potion" or nil)
    if potion then use_consumable(w, p, potion) end
  end

  -- Decide AI state
  decide_player_ai(w, p)

  if p.ai_state == "FIGHT" then
    -- All enemies attack player
    living = living_enemies_in_room(w, p.floor, p.room)
    for _, eid in ipairs(living) do
      local e = w.entities[eid]
      if e and e.alive then
        if e.ai == "healer" then
          -- Healer tries to heal an ally; attacks player if no one to heal
          if not try_heal_ally(w, eid, e, room_data) then
            enemy_attack_player(w, eid, e, p)
          end
        else
          enemy_attack_player(w, eid, e, p)
        end
        -- Boss phase 3: attacks twice
        if e.ai == "boss" and e.alive and w.boss_phase >= 3 then
          enemy_attack_player(w, eid, e, p)
        end
        if p.hp <= 0 then break end
      end
    end

    if p.hp <= 0 then
      p.hp = 0; p.alive = false
      emit(w, "player_died", {
        floor=p.floor, room=p.room, level=p.level,
        flavor=pick(FLAVOR.death)
      })
      return w
    end

    -- Player attacks one random living enemy
    living = living_enemies_in_room(w, p.floor, p.room)
    if #living > 0 then
      local target_id = pick(living)
      local target    = w.entities[target_id]
      if target and target.alive then
        player_attack_enemy(w, p, target_id, target)
        if target.ai == "boss" then check_boss_phase(w, target_id, target) end
      end
    end

    -- Emit HP critical warning
    if p.hp / p.max_hp < 0.25 then
      emit(w, "player_hp_critical", { hp=p.hp, max_hp=p.max_hp, floor=p.floor, room=p.room })
    end

  elseif p.ai_state == "RETREAT" then
    local dest = retreat_room(w, p.floor, p.room)
    if dest then move_player(w, p, dest)
    else p.ai_state = "FIGHT" end  -- nowhere to retreat; stand and fight

  elseif p.ai_state == "REST" then
    -- Slow passive regen while resting; only emit every 5 ticks to reduce noise
    local regen = 5
    p.hp = clamp(p.hp + regen, 0, p.max_hp)
    if w.t % 5 == 0 then
      emit(w, "player_resting", { hp=p.hp, max_hp=p.max_hp })
    end
    if p.hp / p.max_hp >= 0.65 then p.ai_state = "EXPLORE" end

  elseif p.ai_state == "EXPLORE" then
    -- Room-type events on first visit
    if not room_data.visited then
      room_data.visited = true
      emit(w, "room_entered", { floor=p.floor, room=p.room, type=room_data.type })
    end
    if room_data.type == "shrine"   then apply_shrine(w, p, room_data) end
    if room_data.type == "merchant" then apply_merchant(w, p, room_data) end
    -- Collect loot if room is safe
    if #living == 0 then collect_loot(w, p, room_data) end
    -- Descend or advance
    if not try_descend(w, p) then
      local dest = next_forward_room(w, p.floor, p.room)
      if dest then move_player(w, p, dest) end
    end
  end

  -- Victory check: Shadow Lich dead
  for _, e in pairs(w.entities) do
    if e.etype == "shadow_lich" and not e.alive then
      emit(w, "dungeon_cleared", {
        run=w.run, floor=p.floor, level=p.level, gold=p.gold,
        flavor=pick(FLAVOR.victory)
      })
      w.dungeon_cleared = true
      return w
    end
  end

  -- Heartbeat every 10 ticks
  if t % 10 == 0 then
    emit(w, "world_tick", {
      t=t, run=w.run, floor=p.floor, room=p.room, hp=p.hp,
      max_hp=p.max_hp, level=p.level, gold=p.gold, ai_state=p.ai_state
    })
  end

  return w
end

-- ── RESPAWN / RESET ───────────────────────────────────────────────────────────

local function respawn(w)
  emit(w, "run_ended", {
    run=w.run, outcome=w.dungeon_cleared and "victory" or "defeat",
    level=w.player.level, gold=w.player.gold,
  })
  local next_w = new_world(w)
  emit(next_w, "run_started", {
    run=next_w.run, difficulty=next_w.difficulty,
    floor=1, room="f1_entrance",
  })
  return next_w
end

-- ── RUN LOOP ──────────────────────────────────────────────────────────────────

local function run_loop()
  math.randomseed(os.time())

  local w = load_world()
  if not w or do_reset then
    -- Clear events log on (re)start
    local f = io.open(config.events_path, "wb"); if f then f:close() end
    w = new_world()
    save_world(w)
    emit(w, "simulation_started", { run=w.run, difficulty=w.difficulty })
    emit(w, "run_started",        { run=w.run, floor=1, room="f1_entrance" })
    emit(w, "floor_entered",      { floor=1, name=FLOOR_TEMPLATES[1].name,
      flavor=FLAVOR.floor_enter[1] })
    io.stderr:write("[dungeon] world initialized\n")
  end

  io.stderr:write(string.format("[dungeon] running — t=%d run=%d difficulty=%.2f\n",
    w.t, w.run, w.difficulty))

  while true do
    -- Pause while agent is active; fast-forward [t1,t2] on resume
    if agent_active() then
      local t1_real = os.time()
      io.stderr:write(string.format("[dungeon] pausing at t=%d (agent active)\n", w.t))
      while agent_active() do sleep_s(0.1) end
      local t2_real = os.time()
      local elapsed = math.max(0, t2_real - t1_real)
      local catchup = math.floor(elapsed * config.tps)
      io.stderr:write(string.format("[dungeon] resuming — elapsed=%.1fs catchup=%d ticks\n",
        elapsed, catchup))
      -- Reload: agent may have modified world.json
      w = load_world() or w
      for _ = 1, catchup do
        w = tick(w)
        if not w.player.alive or w.dungeon_cleared then
          w = respawn(w); break
        end
      end
      save_world(w)
    end

    w = tick(w)

    if not w.player.alive or w.dungeon_cleared then
      save_world(w)
      w = respawn(w)
    end

    save_world(w)

    if config.tick_sleep > 0 then sleep_s(config.tick_sleep) end
  end
end

-- ── SELF-TESTS ────────────────────────────────────────────────────────────────

local function run_tests()
  math.randomseed(42)

  -- Redirect events to temp file
  local orig = config.events_path
  config.events_path = "z_dungeon_test_events.jsonl"
  local ef = io.open(config.events_path, "wb"); if ef then ef:close() end

  local passed = 0
  local function check(name, cond, msg)
    if cond then
      passed = passed + 1
    else
      error("FAIL [" .. name .. "]: " .. (msg or "assertion failed"), 2)
    end
  end

  -- 1. World generation
  do
    local w = new_world()
    check("gen.tick_zero",       w.t == 0)
    check("gen.run_zero",        w.run == 0)
    check("gen.difficulty_base", w.difficulty == 1.0)
    check("gen.player_alive",    w.player.alive)
    check("gen.player_floor",    w.player.floor == 1)
    check("gen.floor_count",     #w.floors == 4)
    local count = 0; for _ in pairs(w.entities) do count = count + 1 end
    check("gen.entity_count",    count >= 10, "got " .. count)
    -- Each floor has at least 5 rooms
    for fi = 1, 4 do
      local rc = 0; for _ in pairs(w.floors[fi].rooms) do rc = rc + 1 end
      check("gen.floor"..fi.."_rooms", rc >= 5, "floor "..fi.." has "..rc)
    end
  end

  -- 2. Status effects
  do
    local w = new_world()
    local p = w.player
    add_status(p, "poisoned", 2)
    check("status.applied",    has_status(p, "poisoned"))
    local hp_before = p.hp
    tick_statuses(w, p, "player")
    check("status.damage",     p.hp < hp_before)
    check("status.duration",   has_status(p, "poisoned"))  -- still 1 tick left
    tick_statuses(w, p, "player")
    check("status.expired",    not has_status(p, "poisoned"))
  end

  -- 3. Regeneration status
  do
    local w = new_world()
    local p = w.player
    p.hp = 50
    add_status(p, "regenerating", 3)
    tick_statuses(w, p, "player")
    check("status.regen",      p.hp > 50)
  end

  -- 4. Combat: player kills weakened enemy
  do
    local w = new_world()
    local p = w.player
    -- Find a goblin scout
    local eid, e = nil, nil
    for id, ent in pairs(w.entities) do
      if ent.etype == "goblin_scout" then eid = id; e = ent; break end
    end
    check("combat.enemy_exists", eid ~= nil)
    if eid then
      e.hp = 1
      local hp_before = p.hp
      player_attack_enemy(w, p, eid, e)
      check("combat.enemy_killed",  not e.alive)
      check("combat.xp_gained",     p.xp > 0)
      check("combat.gold_gained",   p.gold > 10)  -- started at 10
      _ = hp_before
    end
  end

  -- 5. Enemy attacks player
  do
    local w = new_world()
    local p = w.player
    local eid, e = nil, nil
    for id, ent in pairs(w.entities) do
      if ent.etype == "goblin_scout" then eid = id; e = ent; break end
    end
    if eid then
      local hp_before = p.hp
      enemy_attack_player(w, eid, e, p)
      check("combat.enemy_hit",     p.hp < hp_before)
    end
  end

  -- 6. Berserker bonus
  do
    local w = new_world()
    local p = w.player
    -- Create a berserker entity directly
    local eid = "orc_berserker_test"
    local def = ENEMY_DEFS.orc_berserker
    w.entities[eid] = {
      id=eid, etype="orc_berserker", name=def.name,
      hp=1, max_hp=def.hp, attack=def.attack, defense=def.defense,
      xp=0, gold_min=0, gold_max=0,
      ai="berserker", floor=1, room="f1_entrance", alive=true,
      statuses={}, slow_skip=false,
    }
    -- A berserker at 1/45 HP should have elevated attack
    -- We just verify it doesn't crash and deals damage
    local hp_before = p.hp
    enemy_attack_player(w, eid, w.entities[eid], p)
    check("combat.berserker",      p.hp <= hp_before)
  end

  -- 7. Healer AI
  do
    local w = new_world()
    local eid = "goblin_shaman_test"
    w.entities[eid] = {
      id=eid, etype="goblin_shaman", name="Goblin Shaman",
      hp=20, max_hp=20, attack=4, defense=0,
      xp=0, gold_min=0, gold_max=0,
      ai="healer", floor=1, room="f1_entrance", alive=true,
      statuses={}, slow_skip=false,
    }
    local ally_id = "goblin_scout_test"
    w.entities[ally_id] = {
      id=ally_id, etype="goblin_scout", name="Goblin Scout",
      hp=5, max_hp=25, attack=6, defense=1,
      xp=0, gold_min=0, gold_max=0,
      ai="normal", floor=1, room="f1_entrance", alive=true,
      statuses={}, slow_skip=false,
    }
    local room = w.floors[1].rooms["f1_entrance"]
    room.entity_ids = { eid, ally_id }
    local ally_hp_before = w.entities[ally_id].hp
    try_heal_ally(w, eid, w.entities[eid], room)
    check("ai.healer",             w.entities[ally_id].hp > ally_hp_before)
  end

  -- 8. Item: health potion
  do
    local w = new_world()
    local p = w.player
    p.hp = 40
    p.inventory = { "health_potion" }
    use_consumable(w, p, "health_potion")
    check("item.potion",           p.hp > 40)
    check("item.potion_consumed",  not has_item(p, "health_potion"))
  end

  -- 9. Item: equip weapon
  do
    local w = new_world()
    local p = w.player
    p.inventory = { "enchanted_sword" }
    local atk_before = player_attack(p)
    equip_item(w, p, "enchanted_sword")
    check("item.equip",            player_attack(p) > atk_before)
    check("item.equip_slot",       p.equipment["weapon"] == "enchanted_sword")
  end

  -- 10. Level-up
  do
    local w = new_world()
    local p = w.player
    p.xp = p.xp_next
    local level_before = p.level
    check_levelup(w, p)
    check("levelup",               p.level > level_before)
    check("levelup.attack",        p.base_attack > 10)
  end

  -- 11. Boss phase transition
  do
    local w = new_world()
    local eid = nil
    for id, e in pairs(w.entities) do
      if e.etype == "shadow_lich" then eid = id; break end
    end
    check("boss.exists",           eid ~= nil)
    if eid then
      local e = w.entities[eid]
      e.hp = math.floor(e.max_hp * 0.60)
      check_boss_phase(w, eid, e)
      check("boss.phase2",         e.phase == 2)
      e.hp = math.floor(e.max_hp * 0.30)
      check_boss_phase(w, eid, e)
      check("boss.phase3",         e.phase == 3)
    end
  end

  -- 12. Respawn increments run counter
  do
    local w = new_world()
    w.player.alive = false
    local w2 = respawn(w)
    check("respawn.run",           w2.run == 1)
    check("respawn.player_alive",  w2.player.alive)
    check("respawn.floor_reset",   w2.player.floor == 1)
    check("respawn.hp_full",       w2.player.hp == w2.player.max_hp)
    check("respawn.difficulty",    w2.difficulty > 1.0)
  end

  -- 13. Multi-tick simulation: 40 ticks, no crash, valid events
  do
    local w = new_world()
    for _ = 1, 40 do
      w = tick(w)
      if not w.player.alive or w.dungeon_cleared then
        w = respawn(w)
      end
    end
    check("sim.40ticks",           w.t >= 40)
    local raw = read_file(config.events_path)
    check("sim.events_written",    raw ~= nil and #raw > 0)
    local ev_count = 0
    for line in (raw or ""):gmatch("[^\n]+") do
      if line ~= "" then
        local ok, ev = pcall(json.decode, line)
        check("sim.event_json",    ok, "bad JSON: " .. line)
        check("sim.event_t",       type(ev.t) == "number")
        check("sim.event_type",    type(ev.type) == "string")
        check("sim.event_data",    type(ev.data) == "table")
        ev_count = ev_count + 1
      end
    end
    check("sim.event_count",       ev_count >= 10, "only " .. ev_count .. " events")
  end

  -- Cleanup
  os.remove(config.events_path)
  config.events_path = orig

  print(string.format("OK (%d checks passed)", passed))
end

-- ── ENTRY POINT ───────────────────────────────────────────────────────────────

if do_test then
  run_tests()
  os.exit(0)
end

if do_ticks then
  math.randomseed(os.time())
  local f = io.open(config.events_path, "wb"); if f then f:close() end
  local w = new_world()
  save_world(w)
  emit(w, "simulation_started", { run=w.run, difficulty=w.difficulty })
  emit(w, "run_started",        { run=w.run, floor=1, room="f1_entrance" })
  for _ = 1, do_ticks do
    w = tick(w)
    if not w.player.alive or w.dungeon_cleared then
      save_world(w)
      w = respawn(w)
    end
  end
  save_world(w)
  io.stderr:write(string.format("[dungeon] %d ticks done. run=%d floor=%d room=%s hp=%d/%d level=%d\n",
    do_ticks, w.run, w.player.floor, w.player.room,
    w.player.hp, w.player.max_hp, w.player.level))
  os.exit(0)
end

run_loop()
