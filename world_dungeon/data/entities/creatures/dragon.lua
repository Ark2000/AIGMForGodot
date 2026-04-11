return {
    id = "dragon",
    components = {
        identity    = { name = "Ancient Dragon", archetype = "boss" },
        stats       = { hp = 120, hp_max = 120, attack = 22, defense = 8, speed = 9, level = 5 },
        actor       = { move_cooldown = 12, attack_cooldown = 20 },
        faction     = { id = "beast",
                        hostility = { beast="neutral", adventurer="aggressive",
                                      vermin="neutral", goblin_tribe="aggressive",
                                      orc_clan="aggressive", undead="neutral" } },
        ai_behavior = { archetype = "territorial" },
        is_actor    = { value = true },
        active_modifiers = {},
        unique      = { spawned = false },
        loot_table  = {
            { item_id = "chain_mail",           count = 1, chance = 0.5 },
            { item_id = "iron_sword",           count = 1, chance = 0.5 },
            { item_id = "greater_health_potion", count = 2, chance = 0.8 },
        },
    },
}
