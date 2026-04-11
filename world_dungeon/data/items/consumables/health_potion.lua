return {
    id = "health_potion",
    components = {
        identity  = { name = "Health Potion", archetype = "item" },
        item_info = { def_id="health_potion", name="Health Potion",
                      tags={"consumable","healing","potion"}, weight=1, value=15,
                      stackable=true, stack_count=1 },
        location  = { type="ground", room_id=nil, owner_id=nil, slot=nil },
        usable    = { consumable=true,
                      effects = { { type="heal", amount=20 } },
                      targeting="self" },
        is_item   = { value=true },
    },
}
