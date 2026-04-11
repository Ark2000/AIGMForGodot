return {
    id = "giant_rat",
    components = {
        identity    = { name = "Giant Rat",  archetype = "creature" },
        stats       = { hp = 6,  hp_max = 6,  attack = 2, defense = 0, speed = 12, level = 1 },
        actor       = { move_cooldown = 8,  attack_cooldown = 10 },
        faction     = { id = "vermin",
                        hostility = { vermin="neutral", adventurer="aggressive",
                                      goblin_tribe="neutral", undead="neutral",
                                      beast="neutral", orc_clan="neutral" } },
        ai_behavior = { archetype = "random_wander" },
        is_actor    = { value = true },
        active_modifiers = {},
        loot_table  = {
            { item_id = "health_potion", count = 1, chance = 0.05 },
        },
    },
}
