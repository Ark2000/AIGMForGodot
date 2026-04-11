return {
    id = "amulet_of_yendor",
    components = {
        identity  = { name = "Amulet of Yendor", archetype = "item" },
        item_info = { def_id="amulet_of_yendor", name="Amulet of Yendor",
                      tags={"artifact","unique","quest_item"}, weight=0,
                      value=99999, stackable=false, stack_count=1 },
        location  = { type="ground", room_id=nil, owner_id=nil, slot=nil },
        unique    = { spawned=false },
        is_item   = { value=true },
    },
}
