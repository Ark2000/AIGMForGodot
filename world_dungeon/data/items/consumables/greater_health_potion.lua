return {
    id = "greater_health_potion",
    components = {
        identity  = { name = "Greater Health Potion", archetype = "item" },
        item_info = { def_id="greater_health_potion", name="Greater Health Potion",
                      tags={"consumable","healing","potion"}, weight=1, value=40,
                      stackable=true, stack_count=1 },
        location  = { type="ground", room_id=nil, owner_id=nil, slot=nil },
        usable    = { consumable=true,
                      effects = { { type="heal", amount=45 } },
                      targeting="self" },
        is_item   = { value=true },
    },
}
