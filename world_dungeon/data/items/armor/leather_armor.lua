return {
    id = "leather_armor",
    components = {
        identity  = { name = "Leather Armor", archetype = "item" },
        item_info = { def_id="leather_armor", name="Leather Armor",
                      tags={"armor","body","light"}, weight=5, value=15,
                      stackable=false, stack_count=1 },
        location  = { type="ground", room_id=nil, owner_id=nil, slot=nil },
        equippable = { slot="body",
                       modifiers = { { stat="defense", type="add", value=2 } } },
        is_item   = { value=true },
    },
}
