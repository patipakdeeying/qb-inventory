Config = {
    UseTarget = GetConvar('UseTarget', 'false') == 'true',

    MaxSlots = 40,
    MaxStack = 64,
    HotbarSlots = 5,

    ItemMaxStacks = {
        ['water_bottle'] = 10,  -- Water bottles will stack up to 10
        ['tosti'] = 30,         -- Bread will stack up to 30
    },

    StashSize = {
        slots = 100
    },

    Keybinds = {
        Open = 'TAB',
        Hotbar = 'Z',
    },

    VendingObjects = {
        'prop_vend_soda_01',
        'prop_vend_soda_02',
        'prop_vend_water_01',
        'prop_vend_coffe_01',
    },

    VendingItems = {
        { name = 'kurkakola',    price = 4, amount = 50 },
        { name = 'water_bottle', price = 4, amount = 50 },
    },
}
