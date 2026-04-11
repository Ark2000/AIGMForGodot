return {
    id    = "floor_3",
    floor = 3,
    room_count   = { min=10, max=14 },
    room_types   = { corridor=0.25, chamber=0.35, monster_lair=0.25, treasure_room=0.15 },
    connectivity = "sparse",
    monster_density = 0.6,
    monster_pool    = { "orc", "skeleton", "troll" },
    loot_density    = 0.3,
    loot_pool       = { "health_potion", "chain_mail", "iron_shield", "greater_health_potion" },
    difficulty      = 3,
    recommended_level = 4,
    ecology = {
        min_population  = 3,
        max_population  = 14,
        respawn_delay   = 1500,
        spawn_per_cycle = 2,
    },
}
