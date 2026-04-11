return {
    id = "rusty_dagger",
    components = {
        identity  = { name = "Rusty Dagger", archetype = "item" },
        item_info = { def_id="rusty_dagger", name="Rusty Dagger",
                      tags={"weapon","melee","dagger"}, weight=1, value=5,
                      stackable=false, stack_count=1 },
        location  = { type="ground", room_id=nil, owner_id=nil, slot=nil },
        equippable = { slot="main_hand",
                       modifiers = { { stat="attack", type="add", value=2 } } },
        is_item   = { value=true },
    },
}
