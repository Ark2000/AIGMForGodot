return {
    id = "chain_mail",
    components = {
        identity  = { name = "Chain Mail", archetype = "item" },
        item_info = { def_id="chain_mail", name="Chain Mail",
                      tags={"armor","body","medium"}, weight=10, value=50,
                      stackable=false, stack_count=1 },
        location  = { type="ground", room_id=nil, owner_id=nil, slot=nil },
        equippable = { slot="body",
                       modifiers = { { stat="defense", type="add", value=4 },
                                     { stat="speed",   type="add", value=-1 } } },
        is_item   = { value=true },
    },
}
