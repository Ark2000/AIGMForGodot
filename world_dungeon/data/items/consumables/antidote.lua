return {
    id = "antidote",
    components = {
        identity  = { name = "Antidote", archetype = "item" },
        item_info = { def_id="antidote", name="Antidote",
                      tags={"consumable","cure","potion"}, weight=1, value=20,
                      stackable=true, stack_count=1 },
        location  = { type="ground", room_id=nil, owner_id=nil, slot=nil },
        usable    = { consumable=true,
                      effects = { { type="remove_modifier", modifier_id="poisoned" } },
                      targeting="self" },
        is_item   = { value=true },
    },
}
