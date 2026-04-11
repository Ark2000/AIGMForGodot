return {
    id = "iron_shield",
    components = {
        identity  = { name = "Iron Shield", archetype = "item" },
        item_info = { def_id="iron_shield", name="Iron Shield",
                      tags={"armor","shield","off_hand"}, weight=6, value=30,
                      stackable=false, stack_count=1 },
        location  = { type="ground", room_id=nil, owner_id=nil, slot=nil },
        equippable = { slot="off_hand",
                       modifiers = { { stat="defense", type="add", value=3 } } },
        is_item   = { value=true },
    },
}
