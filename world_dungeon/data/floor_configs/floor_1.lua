return {
    id    = "floor_1",
    floor = 1,
    room_count   = { min=8, max=12 },
    room_types   = { corridor=0.4, chamber=0.4, monster_lair=0.1, treasure_room=0.1 },
    connectivity = "normal",
    monster_density = 0.5,
    monster_pool    = { "giant_rat", "giant_rat", "goblin" },
    loot_density    = 0.25,
    loot_pool       = { "health_potion", "rusty_dagger", "torch" },
    difficulty      = 1,
    recommended_level = 2,
    ecology = {
        min_population  = 3,
        max_population  = 15,
        respawn_delay   = 1000,
        spawn_per_cycle = 2,
    },
}
