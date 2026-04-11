return {
    id = "troll",
    components = {
        identity    = { name = "Troll", archetype = "creature" },
        stats       = { hp = 35, hp_max = 35, attack = 10, defense = 4, speed = 7, level = 3 },
        actor       = { move_cooldown = 14, attack_cooldown = 18 },
        faction     = { id = "beast",
                        hostility = { beast="neutral", adventurer="aggressive",
                                      vermin="neutral", goblin_tribe="aggressive",
                                      orc_clan="neutral", undead="neutral" } },
        ai_behavior = { archetype = "territorial" },
        is_actor    = { value = true },
        active_modifiers = {},
        loot_table  = {
            { item_id = "chain_mail",    count = 1, chance = 0.12 },
            { item_id = "iron_sword",    count = 1, chance = 0.12 },
            { item_id = "health_potion", count = 1, chance = 0.30 },
            { item_id = "greater_health_potion", count = 1, chance = 0.10 },
        },
    },
}
