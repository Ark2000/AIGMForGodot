return {
    id = "iron_key",
    components = {
        identity  = { name = "Iron Key", archetype = "item" },
        item_info = { def_id="iron_key", name="Iron Key",
                      tags={"misc","key"}, weight=1, value=10,
                      stackable=false, stack_count=1 },
        location  = { type="ground", room_id=nil, owner_id=nil, slot=nil },
        is_item   = { value=true },
    },
}
