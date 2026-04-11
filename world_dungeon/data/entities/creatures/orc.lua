return {
    id = "orc",
    components = {
        identity    = { name = "Orc", archetype = "creature" },
        stats       = { hp = 20, hp_max = 20, attack = 7, defense = 3, speed = 8, level = 2 },
        actor       = { move_cooldown = 12, attack_cooldown = 16 },
        faction     = { id = "orc_clan",
                        hostility = { orc_clan="neutral", adventurer="aggressive",
                                      vermin="neutral", goblin_tribe="neutral",
                                      undead="aggressive", beast="neutral" } },
        ai_behavior = { archetype = "pack_hunter" },
        is_actor    = { value = true },
        active_modifiers = {},
        loot_table  = {
            { item_id = "iron_sword",    count = 1, chance = 0.15 },
            { item_id = "leather_armor", count = 1, chance = 0.10 },
            { item_id = "health_potion", count = 1, chance = 0.20 },
        },
    },
}
