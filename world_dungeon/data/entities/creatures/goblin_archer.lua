return {
    id = "goblin_archer",
    components = {
        identity    = { name = "Goblin Archer", archetype = "creature" },
        stats       = { hp = 8, hp_max = 8, attack = 5, defense = 0, speed = 11, level = 1 },
        actor       = { move_cooldown = 10, attack_cooldown = 14 },
        faction     = { id = "goblin_tribe",
                        hostility = { goblin_tribe="neutral", adventurer="aggressive",
                                      vermin="neutral", undead="neutral",
                                      beast="neutral", orc_clan="neutral" } },
        ai_behavior = { archetype = "territorial" },
        is_actor    = { value = true },
        active_modifiers = {},
        loot_table  = {
            { item_id = "short_bow",    count = 1, chance = 0.12 },
            { item_id = "health_potion", count = 1, chance = 0.10 },
        },
    },
}
