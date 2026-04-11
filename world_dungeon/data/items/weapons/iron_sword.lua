return {
    id = "iron_sword",
    components = {
        identity  = { name = "Iron Sword", archetype = "item" },
        item_info = { def_id="iron_sword", name="Iron Sword",
                      tags={"weapon","melee","sword"}, weight=4, value=25,
                      stackable=false, stack_count=1 },
        location  = { type="ground", room_id=nil, owner_id=nil, slot=nil },
        equippable = { slot="main_hand",
                       modifiers = { { stat="attack", type="add", value=6 } } },
        is_item   = { value=true },
    },
}
