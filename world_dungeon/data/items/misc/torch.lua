return {
    id = "torch",
    components = {
        identity  = { name = "Torch", archetype = "item" },
        item_info = { def_id="torch", name="Torch",
                      tags={"misc","light","torch"}, weight=1, value=3,
                      stackable=true, stack_count=1 },
        location  = { type="ground", room_id=nil, owner_id=nil, slot=nil },
        is_item   = { value=true },
    },
}
