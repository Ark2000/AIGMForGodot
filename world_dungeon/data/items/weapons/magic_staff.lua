return {
    id = "magic_staff",
    components = {
        identity  = { name = "Magic Staff", archetype = "item" },
        item_info = { def_id="magic_staff", name="Magic Staff",
                      tags={"weapon","staff","magical"}, weight=3, value=40,
                      stackable=false, stack_count=1 },
        location  = { type="ground", room_id=nil, owner_id=nil, slot=nil },
        equippable = { slot="main_hand",
                       modifiers = { { stat="attack", type="add", value=8 },
                                     { stat="speed",  type="add", value=1 } } },
        is_item   = { value=true },
    },
}
