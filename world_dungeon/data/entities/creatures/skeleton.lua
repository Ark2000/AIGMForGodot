return {
    id = "skeleton",
    components = {
        identity    = { name = "Skeleton", archetype = "creature" },
        stats       = { hp = 14, hp_max = 14, attack = 6, defense = 2, speed = 9, level = 2 },
        actor       = { move_cooldown = 10, attack_cooldown = 14 },
        faction     = { id = "undead",
                        hostility = { undead="neutral", adventurer="aggressive",
                                      vermin="neutral", goblin_tribe="aggressive",
                                      orc_clan="aggressive", beast="neutral" } },
        ai_behavior = { archetype = "territorial" },
        is_actor    = { value = true },
        active_modifiers = {},
        loot_table  = {
            { item_id = "iron_sword",    count = 1, chance = 0.10 },
            { item_id = "health_potion", count = 1, chance = 0.12 },
        },
    },
}
