return {
    id    = "floor_2",
    floor = 2,
    room_count   = { min=9, max=13 },
    room_types   = { corridor=0.3, chamber=0.35, monster_lair=0.2, treasure_room=0.15 },
    connectivity = "normal",
    monster_density = 0.55,
    monster_pool    = { "goblin", "goblin_archer", "skeleton" },
    loot_density    = 0.3,
    loot_pool       = { "health_potion", "iron_sword", "leather_armor", "torch" },
    difficulty      = 2,
    recommended_level = 3,
    ecology = {
        min_population  = 3,
        max_population  = 15,
        respawn_delay   = 1200,
        spawn_per_cycle = 2,
    },
}
