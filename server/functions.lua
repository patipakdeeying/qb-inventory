-- Local Functions

local function InitializeInventory(inventoryId, data)
    Inventories[inventoryId] = {
        items = {},
        isOpen = false,
        label = data and data.label or inventoryId,
        maxweight = data and data.maxweight or Config.StashSize.maxweight,
        slots = data and data.slots or Config.StashSize.slots
    }
    return Inventories[inventoryId]
end

local function GetFirstFreeSlot(items, maxSlots)
    local startSlot = Config.HotbarSlots + 1 -- Start checking slots after hotbar
    for i = startSlot, maxSlots do -- Modify the loop to start from startSlot
        if items[i] == nil then
            return i
        end
    end
    return nil
end

local function SetupShopItems(shopItems)
    local items = {}
    local slot = 1
    if shopItems and next(shopItems) then
        for _, item in pairs(shopItems) do
            local itemInfo = QBCore.Shared.Items[item.name:lower()]
            if itemInfo then
                items[slot] = {
                    name = itemInfo['name'],
                    amount = tonumber(item.amount),
                    info = item.info or {},
                    label = itemInfo['label'],
                    description = itemInfo['description'] or '',
                    weight = itemInfo['weight'],
                    type = itemInfo['type'],
                    unique = itemInfo['unique'],
                    useable = itemInfo['useable'],
                    price = item.price,
                    image = itemInfo['image'],
                    slot = slot,
                }
                slot = slot + 1
            end
        end
    end
    return items
end

local function mergeTables(base, override)
    local merged = {}
    for k, v in pairs(base) do merged[k] = v end
    if override then
        for k, v in pairs(override) do merged[k] = v end
    end
    return merged
end

function GetVehicleStorageConfig(vehicleModelName, vehicleClass)
    local modelNameKey = vehicleModelName and vehicleModelName:lower() or ""
    local classKey = tonumber(vehicleClass)
    local effectiveConfig = {}

    if VehicleStorage and VehicleStorage.default then
        effectiveConfig = mergeTables(effectiveConfig, VehicleStorage.default)
    else
        print("ERROR: QB-Inventory - VehicleStorage.default configuration is missing.")
        effectiveConfig = { gloveboxSlots = 1, gloveboxTotalItemQuantityLimit = 1, trunkSlots = 1, trunkTotalItemQuantityLimit = 1 } -- Basic emergency fallback
    end

    if classKey and VehicleStorage and VehicleStorage.categories and VehicleStorage.categories[classKey] then
        effectiveConfig = mergeTables(effectiveConfig, VehicleStorage.categories[classKey])
    end

    if modelNameKey ~= "" and VehicleStorage and VehicleStorage.models and VehicleStorage.models[modelNameKey] then
        effectiveConfig = mergeTables(effectiveConfig, VehicleStorage.models[modelNameKey])
    end

    return effectiveConfig
end

-- Helper function (place it nearby or where accessible)
function GetCurrentTotalItemQuantity(itemsTable)
    local totalQuantity = 0
    if itemsTable then
        for _, itemData in pairs(itemsTable) do
            if itemData and itemData.amount then
                totalQuantity = totalQuantity + itemData.amount
            end
        end
    end
    return totalQuantity
end
-- Exported Functions

function LoadInventory(source, citizenid)
    local inventory = MySQL.prepare.await('SELECT inventory FROM players WHERE citizenid = ?', { citizenid })
    local loadedInventory = {}
    local missingItems = {}
    inventory = json.decode(inventory)
    if not inventory or not next(inventory) then return loadedInventory end

    for _, item in pairs(inventory) do
        if item then
            local itemInfo = QBCore.Shared.Items[item.name:lower()]

            if itemInfo then
                loadedInventory[item.slot] = {
                    name = itemInfo['name'],
                    amount = item.amount,
                    info = item.info or '',
                    label = itemInfo['label'],
                    description = itemInfo['description'] or '',
                    weight = itemInfo['weight'],
                    type = itemInfo['type'],
                    unique = itemInfo['unique'],
                    useable = itemInfo['useable'],
                    image = itemInfo['image'],
                    shouldClose = itemInfo['shouldClose'],
                    slot = item.slot,
                    combinable = itemInfo['combinable']
                }
            else
                missingItems[#missingItems + 1] = item.name:lower()
            end
        end
    end

    if #missingItems > 0 then
        print(('The following items were removed for player %s as they no longer exist: %s'):format(source and GetPlayerName(source) or citizenid, table.concat(missingItems, ', ')))
    end

    return loadedInventory
end

exports('LoadInventory', LoadInventory)

function SaveInventory(source, offline)
    local PlayerData
    if offline then
        PlayerData = source
    else
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return end
        PlayerData = Player.PlayerData
    end

    local items = PlayerData.items
    local ItemsJson = {}

    if items and next(items) then
        for slot, item in pairs(items) do
            if item then
                ItemsJson[#ItemsJson + 1] = {
                    name = item.name,
                    amount = item.amount,
                    info = item.info,
                    type = item.type,
                    slot = slot,
                }
            end
        end
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode(ItemsJson), PlayerData.citizenid })
    else
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', { '[]', PlayerData.citizenid })
    end
end

exports('SaveInventory', SaveInventory)

-- Sets the items in a inventory.
--- @param identifier string The identifier of the player or inventory.
--- @param items table The items to set in the inventory.
--- @param reason string The reason for setting the items.
function SetInventory(identifier, items, reason)
    local player = QBCore.Functions.GetPlayer(identifier)

    print('Setting inventory for ' .. identifier)

    if not player and not Inventories[identifier] and not Drops[identifier] then
        print('SetInventory: Inventory not found')
        return
    end

    if player then
        player.Functions.SetPlayerData('items', items)
        if not player.Offline then
            local logMessage = string.format('**%s (citizenid: %s | id: %s)** items set: %s', GetPlayerName(identifier), player.PlayerData.citizenid, identifier, json.encode(items))
            TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'SetInventory', 'blue', logMessage)
        end
    elseif Drops[identifier] then
        Drops[identifier].items = items
    elseif Inventories[identifier] then
        Inventories[identifier].items = items
    end

    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    local setReason = reason or 'No reason specified'
    local resourceName = GetInvokingResource() or 'qb-inventory'
    TriggerEvent(
        'qb-log:server:CreateLog',
        'playerinventory',
        'Inventory Set',
        'blue',
        '**Inventory:** ' .. invName .. '\n' ..
        '**Items:** ' .. json.encode(items) .. '\n' ..
        '**Reason:** ' .. setReason .. '\n' ..
        '**Resource:** ' .. resourceName
    )
end

exports('SetInventory', SetInventory)

-- Sets the value of a specific key in the data of an item for a player.
--- @param source number The player's server ID.
--- @param itemName string The name of the item.
--- @param key string The key to set the value for.
--- @param val any The value to set for the key.
--- @param slot number (optional) The slot number of the item. If not provided, it will search by name.
--- @return boolean|nil - Returns true if the value was set successfully, false otherwise.
function SetItemData(source, itemName, key, val, slot)
    if not itemName or not key then return false end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local item
    if slot then
        item = Player.PlayerData.items[tonumber(slot)]
        if not item or item.name:lower() ~= itemName:lower() then return false end
    else
        item = GetItemByName(source, itemName)
        if not item then return false end
    end
    item[key] = val
    Player.PlayerData.items[item.slot] = item
    Player.Functions.SetPlayerData('items', Player.PlayerData.items)
    return true
end

exports('SetItemData', SetItemData)

function UseItem(itemName, ...)
    local itemData = QBCore.Functions.CanUseItem(itemName)
    if type(itemData) == 'table' and itemData.func then
        itemData.func(...)
    end
end

exports('UseItem', UseItem)

-- Retrieves the slots in the items table that contain a specific item.
--- @param items table The table containing the items.
--- @param itemName string The name of the item to search for.
--- @return table A table containing the slots where the item was found.
function GetSlotsByItem(items, itemName)
    local slotsFound = {}
    if not items then return slotsFound end
    for slot, item in pairs(items) do
        if item.name:lower() == itemName:lower() then
            slotsFound[#slotsFound + 1] = slot
        end
    end
    return slotsFound
end

exports('GetSlotsByItem', GetSlotsByItem)

-- Retrieves the first slot number that contains an item with the specified name.
--- @param items table The table of items to search through.
--- @param itemName string The name of the item to search for.
--- @return number|nil - The slot number of the first matching item, or nil if no match is found.
function GetFirstSlotByItem(items, itemName)
    if not items then return end
    for slot, item in pairs(items) do
        if item.name:lower() == itemName:lower() then
            return tonumber(slot)
        end
    end
    return nil
end

exports('GetFirstSlotByItem', GetFirstSlotByItem)

--- Retrieves an item from a player's inventory based on the specified slot.
--- @param source number The player's server ID.
--- @param slot number The slot number of the item.
--- @return table|nil - item data if found, or nil if not found.
function GetItemBySlot(source, slot)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local items = Player.PlayerData.items
    return items[tonumber(slot)]
end

exports('GetItemBySlot', GetItemBySlot)

function GetTotalWeight(items)
    if not items then return 0 end
    -- local weight = 0
    -- for _, item in pairs(items) do
    --     local amount = item.amount
    --     if type(amount) ~= 'number' then
    --         amount = 1
    --     end
    --     weight = weight + (item.weight * amount)
    -- end
    -- return tonumber(weight)
    return 0 -- Add this line: Always return 0
end

exports('GetTotalWeight', GetTotalWeight)

-- Retrieves an item from a player's inventory by its name.
--- @param source number - The player's server ID.
--- @param item string - The name of the item to retrieve.
--- @return table|nil - item data if found, nil otherwise.
function GetItemByName(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local items = Player.PlayerData.items
    local slot = GetFirstSlotByItem(items, tostring(item):lower())
    return items[slot]
end

exports('GetItemByName', GetItemByName)

-- Retrieves a list of items with a specific name from a player's inventory.
--- @param source number The player's server ID.
--- @param item string The name of the item to search for.
--- @return table|nil - containing the items with the specified name.
function GetItemsByName(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local PlayerItems = Player.PlayerData.items
    item = tostring(item):lower()
    local items = {}
    for _, slot in pairs(GetSlotsByItem(PlayerItems, item)) do
        if slot then
            items[#items + 1] = PlayerItems[slot]
        end
    end
    return items
end

exports('GetItemsByName', GetItemsByName)

--- Retrieves the total count of used and free slots for a player or an inventory.
--- @param identifier number|string The player's identifier or the identifier of an inventory or drop.
--- @return number, number - The total count of used slots and the total count of free slots. If no inventory is found, returns 0 and the maximum slots.
function GetSlots(identifier)
    local inventory, maxSlots
    local player = QBCore.Functions.GetPlayer(identifier)
    if player then
        inventory = player.PlayerData.items
        maxSlots = Config.MaxSlots
    elseif Inventories[identifier] then
        inventory = Inventories[identifier].items
        maxSlots = Inventories[identifier].slots
    -- elseif Drops[identifier] then
    --     inventory = Drops[identifier].items
    --     maxSlots = Drops[identifier].slots
    end
    if not inventory then return 0, maxSlots end
    local slotsUsed = 0
    for _, v in pairs(inventory) do
        if v then
            slotsUsed = slotsUsed + 1
        end
    end
    local slotsFree = maxSlots - slotsUsed
    return slotsUsed, slotsFree
end

exports('GetSlots', GetSlots)

--- Retrieves the total count of specified items for a player.
--- @param source number The player's source ID.
--- @param items table|string The items to count. Can be either a table of item names or a single item name.
--- @return number|nil - The total count of the specified items.
function GetItemCount(source, items)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local isTable = type(items) == 'table'
    local itemsSet = isTable and {} or nil
    if isTable then
        for _, item in pairs(items) do
            itemsSet[item] = true
        end
    end
    local count = 0
    for _, item in pairs(Player.PlayerData.items) do
        if (isTable and itemsSet[item.name]) or (not isTable and items == item.name) then
            count = count + item.amount
        end
    end
    return count
end

exports('GetItemCount', GetItemCount)

--- Checks if an item can be added to a inventory based on the weight and slots available.
--- @param identifier string The identifier of the player or inventory.
--- @param item string The item name.
--- @param amount number The amount of the item.
--- @return boolean - Returns true if the item can be added, false otherwise.
--- @return string|nil - Returns a string indicating the reason why the item cannot be added (e.g., 'weight' or 'slots'), or nil if it can be added.
function CanAddItem(identifier, item, amount)
    local Player = QBCore.Functions.GetPlayer(identifier)

    local itemData = QBCore.Shared.Items[item:lower()]
    if not itemData then return false end

    local inventory, items
    if Player then
        inventory = {
            maxweight = Config.MaxWeight,
            slots = Config.MaxSlots
        }
        items = Player.PlayerData.items
    elseif Inventories[identifier] then
        inventory = Inventories[identifier]
        items = Inventories[identifier].items
    end

    if not inventory then
        print('CanAddItem: Inventory not found')
        return false
    end

    local slotsUsed, _ = GetSlots(identifier)

    if slotsUsed >= inventory.slots then
        return false, 'slots'
    end
    return true
end

exports('CanAddItem', CanAddItem)

--- Gets the total free weight of the player's inventory.
--- @param source number The player's server ID.
--- @return number - Returns the free weight of the players inventory. Error will return 0
function GetFreeWeight(source)
    if not source then
        warn('Source was not passed into GetFreeWeight')
        return 0
    end
    -- local Player = QBCore.Functions.GetPlayer(source)
    -- if not Player then return 0 end

    -- local totalWeight = GetTotalWeight(Player.PlayerData.items)
    -- local freeWeight = Config.MaxWeight - totalWeight
    -- return freeWeight
    return 999999999 -- Add this line: Always return a high value
end

exports('GetFreeWeight', GetFreeWeight)

function ClearInventory(source, filterItems)
    local player = QBCore.Functions.GetPlayer(source)
    local savedItemData = {}
    if filterItems then
        if type(filterItems) == 'string' then
            local item = GetItemByName(source, filterItems)
            if item then savedItemData[item.slot] = item end
        elseif type(filterItems) == 'table' then
            for _, itemName in ipairs(filterItems) do
                local item = GetItemByName(source, itemName)
                if item then savedItemData[item.slot] = item end
            end
        end
    end
    player.Functions.SetPlayerData('items', savedItemData)
    if not player.Offline then
        local logMessage = string.format('**%s (citizenid: %s | id: %s)** inventory cleared', GetPlayerName(source), player.PlayerData.citizenid, source)
        TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'ClearInventory', 'red', logMessage)
        local ped = GetPlayerPed(source)
        local weapon = GetSelectedPedWeapon(ped)
        if weapon ~= `WEAPON_UNARMED` then
            RemoveWeaponFromPed(ped, weapon)
        end
        if Player(source).state.inv_busy then TriggerClientEvent('qb-inventory:client:updateInventory', source) end
    end
end

exports('ClearInventory', ClearInventory)

--- Checks if a player has a certain item or items in their inventory.
--- @param source number The player's server ID.
--- @param items string|table The name of the item or a table of item names.
--- @param amount number (optional) The minimum amount required for each item.
--- @return boolean - Returns true if the player has the item(s) with the specified amount, false otherwise.
function HasItem(source, items, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    local isTable = type(items) == 'table'
    local isArray = isTable and table.type(items) == 'array' or false
    local totalItems = isArray and #items or 0
    local count = 0

    if isTable and not isArray then
        for _ in pairs(items) do totalItems = totalItems + 1 end
    end

    for _, itemData in pairs(Player.PlayerData.items) do
        if isTable then
            for k, v in pairs(items) do
                if itemData and itemData.name == (isArray and v or k) and ((amount and itemData.amount >= amount) or (not isArray and itemData.amount >= v) or (not amount and isArray)) then
                    count = count + 1
                    if count == totalItems then
                        return true
                    end
                end
            end
        else -- Single item as string
            if itemData and itemData.name == items and (not amount or (itemData and amount and itemData.amount >= amount)) then
                return true
            end
        end
    end

    return false
end

exports('HasItem', HasItem)

-- CloseInventory function closes the inventory for a given source and identifier.
-- It sets the isOpen flag of the inventory identified by the given identifier to false.
-- It also sets the inv_busy flag of the player identified by the given source to false.
-- Finally, it triggers the 'qb-inventory:client:closeInv' event for the given source.
function CloseInventory(source, identifier)
    if identifier and Inventories[identifier] then
        Inventories[identifier].isOpen = false
    end
    Player(source).state.inv_busy = false
    TriggerClientEvent('qb-inventory:client:closeInv', source)
end

exports('CloseInventory', CloseInventory)

-- Opens the inventory of a player by their ID.
--- @param source number - The player's server ID.
--- @param targetId number - The ID of the player whose inventory will be opened.
function OpenInventoryById(source, targetId)
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    local TargetPlayer = QBCore.Functions.GetPlayer(tonumber(targetId))
    if not QBPlayer or not TargetPlayer then return end
    if Player(targetId).state.inv_busy then CloseInventory(targetId) end
    local playerItems = QBPlayer.PlayerData.items
    local targetItems = TargetPlayer.PlayerData.items
    local formattedInventory = {
        name = 'otherplayer-' .. targetId,
        label = GetPlayerName(targetId),
        slots = Config.MaxSlots,
        inventory = targetItems
    }
    Wait(1500)
    Player(targetId).state.inv_busy = true
    TriggerClientEvent('qb-inventory:client:openInventory', source, playerItems, formattedInventory)
end

exports('OpenInventoryById', OpenInventoryById)

-- Clears a given stash of all items inside
--- @param identifier string
function ClearStash(identifier)
    if not identifier then return end
    local inventory = Inventories[identifier]
    if not inventory then return end
    inventory.items = {}
    MySQL.prepare('UPDATE inventories SET items = ? WHERE identifier = ?', { json.encode(inventory.items), identifier })
end

exports('ClearStash', ClearStash)

--- @param shopData table The data of the shop to create.
function CreateShop(shopData)
    if shopData.name then
        RegisteredShops[shopData.name] = {
            name = shopData.name,
            label = shopData.label,
            coords = shopData.coords,
            slots = #shopData.items,
            items = SetupShopItems(shopData.items)
        }
    else
        for key, data in pairs(shopData) do
            if type(data) == 'table' then
                if data.name then
                    local shopName = type(key) == 'number' and data.name or key
                    RegisteredShops[shopName] = {
                        name = shopName,
                        label = data.label,
                        coords = data.coords,
                        slots = #data.items,
                        items = SetupShopItems(data.items)
                    }
                else
                    CreateShop(data)
                end
            end
        end
    end
end

exports('CreateShop', CreateShop)

--- @param source number The player's server ID.
--- @param name string The identifier of the inventory to open.
function OpenShop(source, name)
    if not name then return end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    if not RegisteredShops[name] then return end
    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    if RegisteredShops[name].coords then
        local shopDistance = vector3(RegisteredShops[name].coords.x, RegisteredShops[name].coords.y, RegisteredShops[name].coords.z)
        if shopDistance then
            local distance = #(playerCoords - shopDistance)
            if distance > 5.0 then return end
        end
    end
    local formattedInventory = {
        name = 'shop-' .. RegisteredShops[name].name,
        label = RegisteredShops[name].label,
        slots = #RegisteredShops[name].items,
        inventory = RegisteredShops[name].items
    }
    TriggerClientEvent('qb-inventory:client:openInventory', source, Player.PlayerData.items, formattedInventory)
end

exports('OpenShop', OpenShop)

--- @param source number The player's server ID.
--- @param identifier string|nil The identifier of the inventory to open.
--- @param data table|nil Additional data for initializing the inventory.
function OpenInventory(source, identifier, data)
    if Player(source).state.inv_busy then return end
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    if not QBPlayer then return end

    if not identifier then -- Opening player's own inventory
        Player(source).state.inv_busy = true
        TriggerClientEvent('qb-inventory:client:openInventory', source, QBPlayer.PlayerData.items)
        return
    end

    if type(identifier) ~= 'string' then
        print('Inventory tried to open an invalid identifier')
        return
    end

    print(string.format("[QB-Inv Server] OpenInventory called for ID: %s, HasData: %s", tostring(identifier), tostring(data ~= nil)))
    if data then
        print("[QB-Inv Server] OpenInventory received data:", json.encode(data))
    end

    local inventory = Inventories[identifier]
    if not inventory then
        inventory = InitializeInventory(identifier, data) -- InitializeInventory might need 'data' if it sets defaults based on it
        Inventories[identifier] = inventory -- Ensure it's assigned back if InitializeInventory returns it
    end

    -- If 'data' is provided (it will be for trunks/gloveboxes from the command)
    if data then
        inventory.slots = data.slots or Config.StashSize.slots -- Use resolved slots from data
        inventory.totalItemQuantityLimit = data.totalItemQuantityLimit or Config.StashSize.maxweight -- Misusing StashSize.maxweight as a fallback for quantity is not ideal.
                                                                                                    -- Better to have a default quantity limit in VehicleStorage.default
                                                                                                    -- For now, ensure data.totalItemQuantityLimit is always set for vehicles.
        inventory.label = data.label or identifier
        if data.rules and data.type then
            inventory.rules = data.rules
            inventory.rules.type = data.type -- "trunk" or "glovebox"
        else
            inventory.rules = nil -- Clear rules for other stash types not configured this way
        end
    else -- For generic stashes not opened via the vehicle specific path
        inventory.slots = inventory.slots or Config.StashSize.slots
        inventory.label = inventory.label or identifier
        inventory.rules = nil -- Generic stashes don't have these vehicle-specific rules by default
        -- For generic stashes, you might want a default totalItemQuantityLimit from Config.StashSize if you add such a param there
    end
    inventory.isOpen = source

    if Inventories[identifier] then
         print(string.format("[QB-Inv Server] Stored config for %s: Slots=%s, QtyLimit=%s, RulesType=%s", identifier, tostring(Inventories[identifier].slots), tostring(Inventories[identifier].totalItemQuantityLimit), tostring(Inventories[identifier].rules and Inventories[identifier].rules.type)))
    end

    local formattedInventory = {
        name = identifier,
        label = inventory.label,
        slots = inventory.slots,
        inventory = inventory.items,
        -- Consider sending totalItemQuantityLimit and current total quantity to UI if you want to display it:
        -- totalItemQuantityLimit = inventory.totalItemQuantityLimit,
        -- currentItemQuantity = GetCurrentTotalItemQuantity(inventory.items)
    }
    print("[QB-Inv Server] FormattedInventory being sent to client:", json.encode(formattedInventory))
    TriggerClientEvent('qb-inventory:client:openInventory', source, QBPlayer.PlayerData.items, formattedInventory)
end

exports('OpenInventory', OpenInventory)

--- Creates a new inventory and returns the inventory object.
--- @param identifier string The identifier of the inventory to create.
--- @param data table Additional data for initializing the inventory.
function CreateInventory(identifier, data)
    if Inventories[identifier] then return end
    if not identifier then return end
    Inventories[identifier] = InitializeInventory(identifier, data)
end

exports('CreateInventory', CreateInventory)

--- Retrieves an inventory by its identifier.
--- @param identifier string The identifier of the inventory to retrieve.
--- @return table|nil - The inventory object if found, nil otherwise.
function GetInventory(identifier)
    return Inventories[identifier]
end

exports('GetInventory', GetInventory)

--- Removes an inventory by its identifier.
--- @param identifier string The identifier of the inventory to remove.
function RemoveInventory(identifier)
    if Inventories[identifier] then
        Inventories[identifier] = nil
    end
end

exports('RemoveInventory', RemoveInventory)

--- Adds an item to the player's inventory or a specific inventory.
--- @param identifier string The identifier of the player or inventory.
--- @param item string The name of the item to add.
--- @param amount number The amount of the item to add.
--- @param slot number (optional) The slot to add the item to. If not provided, it will find the first available slot.
--- @param info table (optional) Additional information about the item.
--- @param reason string (optional) The reason for adding the item.
--- @return boolean Returns true if the item was successfully added, false otherwise.
function AddItem(identifier, item, amount, slot, info, reason)
    local itemInfo = QBCore.Shared.Items[item:lower()]
    if not itemInfo then
        print('AddItem ERROR: Invalid item name provided: ' .. tostring(item))
        TriggerEvent('qb-log:server:CreateLog', 'inventory_error', 'AddItem Fail', 'red', 'Invalid item name for AddItem: ' ..tostring(item))
        return 0 -- Amount added
    end

    local isPlayerInventory = false
    local inventoryTable -- This will be PlayerData.items or Inventories[identifier].items
    local invFullConfig -- This will hold {slots, totalItemQuantityLimit, rules, etc.}

    local player = QBCore.Functions.GetPlayer(identifier)

    if player then
        isPlayerInventory = true
        inventoryTable = player.PlayerData.items
        invFullConfig = {
            slots = Config.MaxSlots, -- Player's own slot limit
            -- Player inventory doesn't use the new "totalItemQuantityLimit" concept directly in this config structure
            -- It's governed by MaxStack per item type in its single slot.
            type = "player"
        }
    elseif Inventories[identifier] then
        isPlayerInventory = false
        inventoryTable = Inventories[identifier].items
        invFullConfig = Inventories[identifier] -- This should contain .slots, .totalItemQuantityLimit, .rules (for vehicles)
                                                -- or .slots (for generic stashes)
        if not invFullConfig.type and identifier:find('trunk-') then invFullConfig.type = "trunk" end
        if not invFullConfig.type and identifier:find('glovebox-') then invFullConfig.type = "glovebox" end
    else
        print('AddItem ERROR: Inventory not found for identifier: ' .. tostring(identifier))
        TriggerEvent('qb-log:server:CreateLog', 'inventory_error', 'AddItem Fail', 'red', 'Attempted to add item to non-existent inventory: ' ..tostring(identifier))
        return 0 -- Amount added
    end

    if not inventoryTable then
        print('AddItem ERROR: Target inventoryTable is nil for identifier: ' .. tostring(identifier))
        return 0
    end

    amount = tonumber(amount) or 1
    if amount <= 0 then return 0 end -- Don't process non-positive or zero amounts

    local totalAmountAdded = 0
    local sourcePlayer = source -- Capture the source of the AddItem call if needed for notifications

    -- For Trunks and Gloveboxes: Apply item whitelists/blacklists first
    if not isPlayerInventory and invFullConfig.rules and invFullConfig.rules.type and (invFullConfig.rules.type == "trunk" or invFullConfig.rules.type == "glovebox") then
        local itemBaseName = item:lower()
        local itemAllowed = true
        local itemRules = invFullConfig.rules

        -- Check Disallowed List (takes precedence)
        if itemRules.disallowedItems and #itemRules.disallowedItems > 0 then
            for _, disallowedItemName in ipairs(itemRules.disallowedItems) do
                if disallowedItemName:lower() == itemBaseName then
                    itemAllowed = false
                    TriggerClientEvent('QBCore:Notify', sourcePlayer or -1, ("%s is not allowed in this %s."):format(itemInfo.label, itemRules.type), "error", 3500)
                    break
                end
            end
        end

        -- If not disallowed, and an Allowed List exists, item must be in it
        if itemAllowed and itemRules.allowedItems and #itemRules.allowedItems > 0 then
            local foundInAllowed = false
            for _, allowedItemName in ipairs(itemRules.allowedItems) do
                if allowedItemName:lower() == itemBaseName then
                    foundInAllowed = true
                    break
                end
            end
            if not foundInAllowed then
                itemAllowed = false
                TriggerClientEvent('QBCore:Notify', sourcePlayer or -1, ("Only specific items are allowed in this %s."):format(itemRules.type), "error", 3500)
            end
        end

        if not itemAllowed then
            return 0 -- Item addition failed due to restrictions
        end
    end

    local effectiveMaxStackForItem = Config.ItemMaxStacks[item:lower()] or Config.MaxStack -- Used for player inv individual item stack cap

    if itemInfo.unique then
        -- Handle Unique Items: Add 'amount' individual instances, each with quantity 1
        local successfullyAddedCount = 0
        for i = 1, amount do
            local currentInstanceInfo = {} -- Create a fresh info table for each unique instance
            if info then -- Deep copy base info if provided, so modifications are per-instance
                for k,v in pairs(info) do currentInstanceInfo[k] = v end
            end

            -- Pre-checks for vehicle inventories (trunks/gloveboxes) FOR EACH unique item instance:
            if not isPlayerInventory and invFullConfig.type and (invFullConfig.type == "trunk" or invFullConfig.type == "glovebox") then
                local currentFilledSlotsCheck = 0; for _ in pairs(inventoryTable) do currentFilledSlotsCheck = currentFilledSlotsCheck + 1 end
                if currentFilledSlotsCheck >= (invFullConfig.slots or math.huge) then
                    if i == 1 then TriggerClientEvent('QBCore:Notify', sourcePlayer or -1, ("This %s is full (cannot add more different items)."):format(invFullConfig.type), "error", 3500) end
                    break -- Stop trying to add more unique items if slot limit for types is reached
                end

                local currentTotalQuantityCheck = GetCurrentTotalItemQuantity(inventoryTable)
                if currentTotalQuantityCheck >= (invFullConfig.totalItemQuantityLimit or math.huge) then
                    if i == 1 then TriggerClientEvent('QBCore:Notify', sourcePlayer or -1, ("This %s is full (total quantity limit reached)."):format(invFullConfig.type), "error", 3500) end
                    break -- Stop trying to add more unique items if quantity limit is reached
                end
            end

            local finalPlacementSlot = nil
            -- If a specific 'slot' was passed to AddItem, only use it for the *first* unique item attempt if the slot is empty.
            -- Subsequent unique items in a multi-add scenario should always find new free slots.
            if i == 1 and slot ~= nil and type(slot) == 'number' and slot >= 1 and slot <= invFullConfig.slots and not inventoryTable[slot] then
                finalPlacementSlot = slot
            else
                finalPlacementSlot = GetFirstFreeSlot(inventoryTable, invFullConfig.slots)
            end

            if not finalPlacementSlot then
                if i == 1 then print('AddItem WARNING: No slot available for first unique item instance of ' .. item .. ' in ' .. identifier) end
                break -- Stop if no more slots are available
            end
            
            if itemInfo.type == 'weapon' then -- Generate unique serial for each weapon instance
                currentInstanceInfo.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
                if not currentInstanceInfo.quality then
                    currentInstanceInfo.quality = 100
                end
            end
            
            inventoryTable[finalPlacementSlot] = {
                name = item, amount = 1, info = currentInstanceInfo, label = itemInfo.label,
                description = itemInfo.description or '', type = itemInfo.type,
                unique = itemInfo.unique, useable = itemInfo.useable, image = itemInfo.image,
                shouldClose = itemInfo.shouldClose, slot = finalPlacementSlot, combinable = itemInfo.combinable
            }
            successfullyAddedCount = successfullyAddedCount + 1
        end
        totalAmountAdded = successfullyAddedCount
    else
        -- Handle Non-Unique (Stackable) Items
        if isPlayerInventory then
            local existingItemSlotKey = nil
            local existingItemData = nil
            for k, v in pairs(inventoryTable) do
                if v.name:lower() == item:lower() then
                    existingItemSlotKey = k; existingItemData = v; break
                end
            end

            if existingItemData then -- Item type exists in player inv, add to its single allowed slot
                local spaceInPlayerStack = effectiveMaxStackForItem - existingItemData.amount
                local amountCanAddToPlayerStack = math.min(amount, spaceInPlayerStack)
                if amountCanAddToPlayerStack > 0 then
                    existingItemData.amount = existingItemData.amount + amountCanAddToPlayerStack
                    totalAmountAdded = amountCanAddToPlayerStack
                else
                    TriggerClientEvent('QBCore:Notify', sourcePlayer or -1, itemInfo.label .. " stack is full.", "error", 2500)
                end
            else -- New item type for player, create in a new slot
                local amountForNewPlayerStack = math.min(amount, effectiveMaxStackForItem)
                if amountForNewPlayerStack > 0 then
                    local finalPlacementSlot = GetFirstFreeSlot(inventoryTable, invFullConfig.slots)
                    if not finalPlacementSlot then
                        TriggerClientEvent('QBCore:Notify', sourcePlayer or -1, "Inventory full.", "error", 2500)
                        -- totalAmountAdded remains 0
                    else
                        inventoryTable[finalPlacementSlot] = { name = item, amount = amountForNewPlayerStack, info = info or {}, label = itemInfo.label, description = itemInfo.description or '', type = itemInfo.type, unique = itemInfo.unique, useable = itemInfo.useable, image = itemInfo.image, shouldClose = itemInfo.shouldClose, slot = finalPlacementSlot, combinable = itemInfo.combinable }
                        if itemInfo.type == 'weapon' and not isPlayerInventory then -- Non-unique weapons in other inv? Less common.
                           -- if not inventoryTable[finalPlacementSlot].info.serie then inventoryTable[finalPlacementSlot].info.serie = ... end -- if non-unique weapons can have serials
                           if not inventoryTable[finalPlacementSlot].info.quality then inventoryTable[finalPlacementSlot].info.quality = 100 end
                        end
                        totalAmountAdded = amountForNewPlayerStack
                    end
                end
            end
        else
            -- Other Inventories (Trunk/Glovebox/Generic Stash - apply slot and total quantity limits)
            local existingItemSlotKey = nil
            local existingItemData = nil
            for k, v in pairs(inventoryTable) do
                if v.name:lower() == item:lower() then
                    existingItemSlotKey = k; existingItemData = v; break
                end
            end

            -- Check Total Item Quantity Limit for the container
            local currentTotalQuantity = GetCurrentTotalItemQuantity(inventoryTable)
            -- Use math.huge if totalItemQuantityLimit is not defined (e.g. for generic stashes without this new rule)
            local containerTotalQuantityLimit = invFullConfig.totalItemQuantityLimit or math.huge 
            
            if currentTotalQuantity >= containerTotalQuantityLimit then
                TriggerClientEvent('QBCore:Notify', sourcePlayer or -1, "Container is at its total item quantity limit.", "error", 3500)
                return 0 -- Already at or over total quantity capacity
            end

            local remainingQuantityCapacity = containerTotalQuantityLimit - currentTotalQuantity
            local amountToAddConsideringQuantityCap = math.min(amount, remainingQuantityCapacity)

            if amountToAddConsideringQuantityCap <= 0 then
                 -- This case should ideally be caught by the check above, but good as a safeguard
                TriggerClientEvent('QBCore:Notify', sourcePlayer or -1, "Cannot add more items, quantity limit reached.", "error", 3500)
                return 0
            end

            if existingItemData then -- Item type exists, add to its quantity (no individual stack cap here)
                existingItemData.amount = existingItemData.amount + amountToAddConsideringQuantityCap
                totalAmountAdded = amountToAddConsideringQuantityCap
            else -- New item type for this container
                local currentFilledSlots = 0
                for _ in pairs(inventoryTable) do currentFilledSlots = currentFilledSlots + 1 end
                
                -- Use math.huge if .slots is not defined (e.g. for generic stashes without this new rule)
                local containerSlotLimit = invFullConfig.slots or math.huge

                if currentFilledSlots >= containerSlotLimit then
                    TriggerClientEvent('QBCore:Notify', sourcePlayer or -1, "Container is full (cannot add more different item types).", "error", 3500)
                    return 0 -- No more distinct slots available
                end

                -- If we reached here, a new slot is available, and quantity cap allows addition
                local finalPlacementSlot = GetFirstFreeSlot(inventoryTable, containerSlotLimit) -- Use containerSlotLimit here
                if not finalPlacementSlot then
                    -- This should ideally be caught by currentFilledSlots >= containerSlotLimit, but good safeguard
                    print('AddItem WARNING: No free slot in other inventory '..identifier..' for new item type '..item..', though slot count indicated space.')
                    return 0
                else
                    inventoryTable[finalPlacementSlot] = { name = item, amount = amountToAddConsideringQuantityCap, info = info or {}, label = itemInfo.label, description = itemInfo.description or '', type = itemInfo.type, unique = itemInfo.unique, useable = itemInfo.useable, image = itemInfo.image, shouldClose = itemInfo.shouldClose, slot = finalPlacementSlot, combinable = itemInfo.combinable }
                    if itemInfo.type == 'weapon' then -- Non-unique weapons in other inv?
                       if not inventoryTable[finalPlacementSlot].info.quality then inventoryTable[finalPlacementSlot].info.quality = 100 end
                    end
                    totalAmountAdded = amountToAddConsideringQuantityCap
                end
            end
        end
    end

    if totalAmountAdded > 0 then
        if player then -- Only if it was a player inventory that got modified
            player.Functions.SetPlayerData('items', inventoryTable)
            if Player(identifier).state.inv_busy then TriggerClientEvent('qb-inventory:client:updateInventory', identifier) end
        end
        -- More detailed logging
        local invNameLog = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
        local reasonLog = reason or 'No reason specified'
        local resourceLog = GetInvokingResource() or 'qb-inventory'
        local slotFilledLog = "N/A"
        -- Try to find the slot(s) more accurately for logging (this part can be complex for multi-unique adds)
        if itemInfo.unique and totalAmountAdded > 0 then slotFilledLog = "Multiple (unique)"
        elseif existingItemSlotKey then slotFilledLog = tostring(existingItemSlotKey)
        else -- find new slot
            for k,v in pairs(inventoryTable) do if v.name:lower() == item:lower() and v.amount == totalAmountAdded then slotFilledLog = tostring(v.slot); break; end end
        end

        local logMessage = string.format('**Inventory:** %s (Slot: %s)\n**Item:** %s\n**Amount Added:** %d\n**Reason:** %s\n**Resource:** %s',
            invNameLog, slotFilledLog, item, totalAmountAdded, reasonLog, resourceLog)
        if not isPlayerInventory and totalAmountAdded > 0 and not itemInfo.unique then logMessage = logMessage .. "\n**Note:** Item stack size limit bypassed (non-player, non-unique item)" end
        if isPlayerInventory and totalAmountAdded < amount and totalAmountAdded > 0 then logMessage = logMessage .. "\n**Note:** Could not add full amount due to player stack/slot rules." end
        if not isPlayerInventory and totalAmountAdded < amount and totalAmountAdded > 0 then logMessage = logMessage .. "\n**Note:** Could not add full amount due to container slot/quantity limits." end

        TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'Item Added', 'green', logMessage)
    end

    return totalAmountAdded
end

exports('AddItem', AddItem)

-- Removes an item from a player's inventory.
--- @param identifier string - The identifier of the player.
--- @param item string - The name of the item to remove.
--- @param amount number - The amount of the item to remove.
--- @param slot number - The slot number of the item in the inventory. If not provided, it will find the first slot with the item.
--- @param reason string - The reason for removing the item. Defaults to 'No reason specified' if not provided.
--- @return boolean - Returns true if the item was successfully removed, false otherwise.
function RemoveItem(identifier, item, amount, slot, reason)
    if not QBCore.Shared.Items[item:lower()] then
        print('RemoveItem: Invalid item')
        return false
    end

    local inventory
    local player = QBCore.Functions.GetPlayer(identifier)

    if player then
        inventory = player.PlayerData.items
    elseif Inventories[identifier] then
        inventory = Inventories[identifier].items
    elseif Drops[identifier] then
        inventory = Drops[identifier].items
    end

    if not inventory then
        print('RemoveItem: Inventory not found')
        return false
    end

    slot = tonumber(slot) or GetFirstSlotByItem(inventory, item)

    if not slot then
        print('RemoveItem: Slot not found')
        return false
    end

    local inventoryItem = nil
    local itemKey = nil

    for key, invItem in pairs(inventory) do
        if invItem.slot == slot then
            inventoryItem = invItem
            itemKey = key
            break
        end
    end

    if not inventoryItem or inventoryItem.name:lower() ~= item:lower() then
        print('RemoveItem: Item not found in slot')
        return false
    end

    amount = tonumber(amount)
    if inventoryItem.amount < amount then
        print('RemoveItem: Not enough items in slot')
        return false
    end

    inventoryItem.amount = inventoryItem.amount - amount
    if inventoryItem.amount <= 0 then
        inventory[itemKey] = nil
    else
        inventory[itemKey] = inventoryItem
    end

    if player then player.Functions.SetPlayerData('items', inventory) end

    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    local removeReason = reason or 'No reason specified'
    local resourceName = GetInvokingResource() or 'qb-inventory'

    TriggerEvent(
        'qb-log:server:CreateLog',
        'playerinventory',
        'Item Removed',
        'red',
        '**Inventory:** ' .. invName .. ' (Slot: ' .. slot .. ')\n' ..
        '**Item:** ' .. item .. '\n' ..
        '**Amount:** ' .. amount .. '\n' ..
        '**Reason:** ' .. removeReason .. '\n' ..
        '**Resource:** ' .. resourceName
    )
    return true
end

exports('RemoveItem', RemoveItem)

function GetInventory(identifier)
    return Inventories[identifier]
end

exports('GetInventory', GetInventory)
