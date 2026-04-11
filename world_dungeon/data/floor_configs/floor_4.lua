return {
    id    = "floor_4",
    floor = 4,
    room_count   = { min=10, max=13 },
    room_types   = { corridor=0.2, chamber=0.35, monster_lair=0.3, treasure_room=0.15 },
    connectivity = "sparse",
    monster_density = 0.65,
    monster_pool    = { "orc", "troll", "skeleton" },
    loot_density    = 0.35,
    loot_pool       = { "greater_health_potion", "chain_mail", "iron_shield", "iron_sword" },
    difficulty      = 4,
    recommended_level = 5,
    ecology = {
        min_population  = 2,
        max_population  = 12,
        respawn_delay   = 2000,
        spawn_per_cycle = 1,
    },
}
