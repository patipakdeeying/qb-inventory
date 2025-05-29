-- In qb-inventory/config/config.lua

Config = {
    UseTarget = GetConvar('UseTarget', 'false') == 'true',

    MaxWeight = 999999999, -- Set very high to be non-restrictive
    MaxSlots = 40,        -- Your primary player inventory slot limit

    StashSize = {
        maxweight = 999999999, -- Set very high
        slots = 100
    },

    DropSize = {
        maxweight = 999999999, -- Set very high
        slots = 50
    },

    Keybinds = {
        Open = 'TAB',
        Hotbar = 'Z',
    },

    CleanupDropTime = 15,    -- in minutes
    CleanupDropInterval = 1, -- in minutes

    ItemDropObject = `bkr_prop_duffel_bag_01a`,
    ItemDropObjectBone = 28422,
    ItemDropObjectOffset = {
        vector3(0.260000, 0.040000, 0.000000),
        vector3(90.000000, 0.000000, -78.989998),
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

    -- NEW CONFIGURATION SECTION FOR ITEM MAX STACKS
    ItemMaxStacks = {
        -- item_name = max_stack_amount
        ['water_bottle'] = 10,
        ['burger'] = 5,
        ['medikit'] = 20,
        ['bandage'] = 20,
        -- Add other non-unique items and their desired max stack sizes here
        -- For items not listed here, and not unique, DefaultMaxStack will be used.
        -- Unique items will automatically have a max stack of 1.
    },
    DefaultMaxStack = 50, -- Default max stack for non-unique items NOT listed in ItemMaxStacks
}