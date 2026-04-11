return {
    max_ticks = 10000,

    log = {
        enabled          = true,
        mode             = "follow",   -- "follow" | "world"
        auto_follow      = true,
        output           = "stdout",   -- "stdout" | "file"
        file_path        = "logs/sim.log",
        summary_interval = 1000,
        min_importance   = "LOW",      -- for world mode
    },

    max_adventurers          = 3,
    adventurer_spawn_interval = 500,

    -- seed (nil = random)
    seed = nil,
}
