return {
    id = "goblin",
    components = {
        identity    = { name = "Goblin",  archetype = "creature" },
        stats       = { hp = 10, hp_max = 10, attack = 4, defense = 1, speed = 10, level = 1 },
        actor       = { move_cooldown = 10, attack_cooldown = 12 },
        faction     = { id = "goblin_tribe",
                        hostility = { goblin_tribe="neutral", adventurer="aggressive",
                                      vermin="neutral", undead="neutral",
                                      beast="neutral", orc_clan="neutral" } },
        ai_behavior = { archetype = "pack_hunter" },
        is_actor    = { value = true },
        active_modifiers = {},
        loot_table  = {
            { item_id = "rusty_dagger", count = 1, chance = 0.15 },
            { item_id = "health_potion", count = 1, chance = 0.10 },
        },
    },
}
