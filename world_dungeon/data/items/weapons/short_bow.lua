return {
    id = "short_bow",
    components = {
        identity  = { name = "Short Bow", archetype = "item" },
        item_info = { def_id="short_bow", name="Short Bow",
                      tags={"weapon","ranged","bow"}, weight=2, value=20,
                      stackable=false, stack_count=1 },
        location  = { type="ground", room_id=nil, owner_id=nil, slot=nil },
        equippable = { slot="main_hand",
                       modifiers = { { stat="attack", type="add", value=5 },
                                     { stat="speed",  type="add", value=1 } } },
        is_item   = { value=true },
    },
}
