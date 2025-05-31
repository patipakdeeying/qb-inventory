QBCore = exports['qb-core']:GetCoreObject()
Inventories = {}
RegisteredShops = {}

CreateThread(function()
    MySQL.query('SELECT * FROM inventories', {}, function(result)
        if result and #result > 0 then
            for i = 1, #result do
                local inventory = result[i]
                local cacheKey = inventory.identifier
                Inventories[cacheKey] = {
                    items = json.decode(inventory.items) or {},
                    isOpen = false
                }
            end
            print(#result .. ' inventories successfully loaded')
        end
    end)
end)

-- Handlers
AddEventHandler('playerDropped', function()
    for _, inv in pairs(Inventories) do
        if inv.isOpen == source then
            inv.isOpen = false
        end
    end
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    for inventory, data in pairs(Inventories) do
        if data.isOpen then
            MySQL.prepare('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?', { inventory, json.encode(data.items), json.encode(data.items) })
        end
    end
end)

RegisterNetEvent('QBCore:Server:UpdateObject', function()
    if source ~= '' then return end
    QBCore = exports['qb-core']:GetCoreObject()
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'AddItem', function(item, amount, slot, info, reason)
        return AddItem(Player.PlayerData.source, item, amount, slot, info, reason)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'RemoveItem', function(item, amount, slot, reason)
        return RemoveItem(Player.PlayerData.source, item, amount, slot, reason)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'GetItemBySlot', function(slot)
        return GetItemBySlot(Player.PlayerData.source, slot)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'GetItemByName', function(item)
        return GetItemByName(Player.PlayerData.source, item)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'GetItemsByName', function(item)
        return GetItemsByName(Player.PlayerData.source, item)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'ClearInventory', function(filterItems)
        ClearInventory(Player.PlayerData.source, filterItems)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'SetInventory', function(items)
        SetInventory(Player.PlayerData.source, items)
    end)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    local Players = QBCore.Functions.GetQBPlayers()
    for k in pairs(Players) do
        QBCore.Functions.AddPlayerMethod(k, 'AddItem', function(item, amount, slot, info)
            return AddItem(k, item, amount, slot, info)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'RemoveItem', function(item, amount, slot)
            return RemoveItem(k, item, amount, slot)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'GetItemBySlot', function(slot)
            return GetItemBySlot(k, slot)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'GetItemByName', function(item)
            return GetItemByName(k, item)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'GetItemsByName', function(item)
            return GetItemsByName(k, item)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'ClearInventory', function(filterItems)
            ClearInventory(k, filterItems)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'SetInventory', function(items)
            SetInventory(k, items)
        end)

        Player(k).state.inv_busy = false
    end
end)

-- Functions

local function checkWeapon(source, item)
    local currentWeapon = type(item) == 'table' and item.name or item
    local ped = GetPlayerPed(source)
    local weapon = GetSelectedPedWeapon(ped)
    local weaponInfo = QBCore.Shared.Weapons[weapon]
    if weaponInfo and weaponInfo.name == currentWeapon then
        RemoveWeaponFromPed(ped, weapon)
        TriggerClientEvent('qb-weapons:client:UseWeapon', source, { name = currentWeapon }, false)
    end
end

local function DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[DeepCopy(orig_key)] = DeepCopy(orig_value)
        end
        setmetatable(copy, DeepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Events

RegisterNetEvent('qb-inventory:server:openVending', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    CreateShop({
        name = 'vending',
        label = 'Vending Machine',
        coords = data.coords,
        slots = #Config.VendingItems,
        items = Config.VendingItems
    })
    OpenShop(src, 'vending')
end)

RegisterNetEvent('qb-inventory:server:closeInventory', function(inventory)
    local src = source
    local QBPlayer = QBCore.Functions.GetPlayer(src)
    if not QBPlayer then return end
    Player(source).state.inv_busy = false
    if inventory:find('shop%-') then return end
    if inventory:find('otherplayer%-') then
        local targetId = tonumber(inventory:match('otherplayer%-(.+)'))
        Player(targetId).state.inv_busy = false
        return
    end
    if not Inventories[inventory] then return end
    Inventories[inventory].isOpen = false
    MySQL.prepare('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?', { inventory, json.encode(Inventories[inventory].items), json.encode(Inventories[inventory].items) })
end)

RegisterNetEvent('qb-inventory:server:useItem', function(item)
    local src = source
    local itemData = GetItemBySlot(src, item.slot)
    if not itemData then return end
    local itemInfo = QBCore.Shared.Items[itemData.name]
    if itemData.type == 'weapon' then
        TriggerClientEvent('qb-weapons:client:UseWeapon', src, itemData, itemData.info.quality and itemData.info.quality > 0)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'use')
    elseif itemData.name == 'id_card' then
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('qb-inventory:client:ItemBox', source, itemInfo, 'use')
        local playerPed = GetPlayerPed(src)
        local playerCoords = GetEntityCoords(playerPed)
        local players = QBCore.Functions.GetPlayers()
        local gender = item.info.gender == 0 and 'Male' or 'Female'
        for _, v in pairs(players) do
            local targetPed = GetPlayerPed(v)
            local dist = #(playerCoords - GetEntityCoords(targetPed))
            if dist < 3.0 then
                TriggerClientEvent('chat:addMessage', v, {
                    template = '<div class="chat-message advert" style="background: linear-gradient(to right, rgba(5, 5, 5, 0.6), #74807c); display: flex;"><div style="margin-right: 10px;"><i class="far fa-id-card" style="height: 100%;"></i><strong> {0}</strong><br> <strong>Civ ID:</strong> {1} <br><strong>First Name:</strong> {2} <br><strong>Last Name:</strong> {3} <br><strong>Birthdate:</strong> {4} <br><strong>Gender:</strong> {5} <br><strong>Nationality:</strong> {6}</div></div>',
                    args = {
                        'ID Card',
                        item.info.citizenid,
                        item.info.firstname,
                        item.info.lastname,
                        item.info.birthdate,
                        gender,
                        item.info.nationality
                    }
                })
            end
        end
    elseif itemData.name == 'driver_license' then
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'use')
        local playerPed = GetPlayerPed(src)
        local playerCoords = GetEntityCoords(playerPed)
        local players = QBCore.Functions.GetPlayers()
        for _, v in pairs(players) do
            local targetPed = GetPlayerPed(v)
            local dist = #(playerCoords - GetEntityCoords(targetPed))
            if dist < 3.0 then
                TriggerClientEvent('chat:addMessage', v, {
                    template = '<div class="chat-message advert" style="background: linear-gradient(to right, rgba(5, 5, 5, 0.6), #657175); display: flex;"><div style="margin-right: 10px;"><i class="far fa-id-card" style="height: 100%;"></i><strong> {0}</strong><br> <strong>First Name:</strong> {1} <br><strong>Last Name:</strong> {2} <br><strong>Birth Date:</strong> {3} <br><strong>Licenses:</strong> {4}</div></div>',
                    args = {
                        'Drivers License',
                        item.info.firstname,
                        item.info.lastname,
                        item.info.birthdate,
                        item.info.type
                    }
                }
                )
            end
        end
    else
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'use')
    end
end)

RegisterNetEvent('qb-inventory:server:snowball', function(action)
    if action == 'add' then
        AddItem(source, 'weapon_snowball', 1, false, false, 'qb-inventory:server:snowball')
    elseif action == 'remove' then
        RemoveItem(source, 'weapon_snowball', 1, false, 'qb-inventory:server:snowball')
    end
end)

-- Callbacks

QBCore.Functions.CreateCallback('qb-inventory:server:attemptPurchase', function(source, cb, data)
    local itemInfo = data.item
    local amount = data.amount
    local shop = string.gsub(data.shop, 'shop%-', '')
    local Player = QBCore.Functions.GetPlayer(source)

    if not Player then
        cb(false)
        return
    end

    local shopInfo = RegisteredShops[shop]
    if not shopInfo then
        cb(false)
        return
    end

    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    if shopInfo.coords then
        local shopCoords = vector3(shopInfo.coords.x, shopInfo.coords.y, shopInfo.coords.z)
        if #(playerCoords - shopCoords) > 10 then
            cb(false)
            return
        end
    end

    if shopInfo.items[itemInfo.slot].name ~= itemInfo.name then -- Check if item name passed is the same as the item in that slot
        cb(false)
        return
    end

    if amount > shopInfo.items[itemInfo.slot].amount then
        TriggerClientEvent('QBCore:Notify', source, 'Cannot purchase larger quantity than currently in stock', 'error')
        cb(false)
        return
    end

    if not CanAddItem(source, itemInfo.name, amount) then
        TriggerClientEvent('QBCore:Notify', source, 'Cannot hold item', 'error')
        cb(false)
        return
    end

    local price = shopInfo.items[itemInfo.slot].price * amount
    if Player.PlayerData.money.cash >= price then
        Player.Functions.RemoveMoney('cash', price, 'shop-purchase')
        AddItem(source, itemInfo.name, amount, nil, itemInfo.info, 'shop-purchase')
        TriggerEvent('qb-shops:server:UpdateShopItems', shop, itemInfo, amount)
        cb(true)
    else
        TriggerClientEvent('QBCore:Notify', source, 'You do not have enough money', 'error')
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('qb-inventory:server:giveItem', function(source, cb, target, item, amount, slot, info)
    local player = QBCore.Functions.GetPlayer(source)
    if not player or player.PlayerData.metadata['isdead'] or player.PlayerData.metadata['inlaststand'] or player.PlayerData.metadata['ishandcuffed'] then
        cb(false)
        return
    end
    local playerPed = GetPlayerPed(source)

    local Target = QBCore.Functions.GetPlayer(target)
    if not Target or Target.PlayerData.metadata['isdead'] or Target.PlayerData.metadata['inlaststand'] or Target.PlayerData.metadata['ishandcuffed'] then
        cb(false)
        return
    end
    local targetPed = GetPlayerPed(target)

    local pCoords = GetEntityCoords(playerPed)
    local tCoords = GetEntityCoords(targetPed)
    if #(pCoords - tCoords) > 5 then
        cb(false)
        return
    end

    local itemInfo = QBCore.Shared.Items[item:lower()]
    if not itemInfo then
        cb(false)
        return
    end

    local hasItem = HasItem(source, item)
    if not hasItem then
        cb(false)
        return
    end

    local itemAmount = GetItemByName(source, item).amount
    if itemAmount <= 0 then
        cb(false)
        return
    end

    local giveAmount = tonumber(amount)
    if giveAmount > itemAmount then
        cb(false)
        return
    end

    local removeItem = RemoveItem(source, item, giveAmount, slot, 'Item given to ID #' .. target)
    if not removeItem then
        cb(false)
        return
    end

    local giveItem = AddItem(target, item, giveAmount, false, info, 'Item given from ID #' .. source)
    if not giveItem then
        cb(false)
        return
    end

    if itemInfo.type == 'weapon' then checkWeapon(source, item) end
    TriggerClientEvent('qb-inventory:client:giveAnim', source)
    TriggerClientEvent('qb-inventory:client:ItemBox', source, itemInfo, 'remove', giveAmount)
    TriggerClientEvent('qb-inventory:client:giveAnim', target)
    TriggerClientEvent('qb-inventory:client:ItemBox', target, itemInfo, 'add', giveAmount)
    if Player(target).state.inv_busy then TriggerClientEvent('qb-inventory:client:updateInventory', target) end
    cb(true)
end)

-- Item move logic

local function getItem(inventoryId, src, slot)
    local items = {}
    if inventoryId == 'player' then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData.items then
            items = Player.PlayerData.items
        end
    elseif inventoryId:find('otherplayer-') then
        local targetId = tonumber(inventoryId:match('otherplayer%-(.+)'))
        local targetPlayer = QBCore.Functions.GetPlayer(targetId)
        if targetPlayer and targetPlayer.PlayerData.items then
            items = targetPlayer.PlayerData.items
        end
    elseif inventoryId:find('drop-') == 1 then
        if Drops[inventoryId] and Drops[inventoryId]['items'] then
            items = Drops[inventoryId]['items']
        end
    else
        if Inventories[inventoryId] and Inventories[inventoryId]['items'] then
            items = Inventories[inventoryId]['items']
        end
    end

    for _, item in pairs(items) do
        if item.slot == slot then
            return item
        end
    end
    return nil
end

local function getIdentifier(inventoryId, src)
    if inventoryId == 'player' then
        return src
    elseif inventoryId:find('otherplayer-') then
        return tonumber(inventoryId:match('otherplayer%-(.+)'))
    else
        return inventoryId
    end
end

RegisterNetEvent('qb-inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmountOriginal, amountToTransfer)
    -- fromAmountOriginal is the original stack size in fromSlot (sent by client as 'fromAmount').
    -- amountToTransfer is the amount the user actually wants to move (sent by client as 'toAmount').

    if toInventory:find('shop%-') then return end -- Cannot move items into a shop like this
    if not fromInventory or not toInventory or not fromSlot or not toSlot or amountToTransfer == nil then
        print("SetInventoryData: Missing parameters")
        return
    end

    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    fromSlot, toSlot = tonumber(fromSlot), tonumber(toSlot)
    amountToTransfer = tonumber(amountToTransfer)

    if amountToTransfer <= 0 then
        print("SetInventoryData: Transfer amount must be positive.")
        TriggerClientEvent('QBCore:Notify', src, "Transfer amount must be positive.", 'error')
        return
    end

    local fromItem = getItem(fromInventory, src, fromSlot)

    if not fromItem then
        print("SetInventoryData: Source item not found at slot " .. fromSlot .. " in " .. fromInventory)
        TriggerClientEvent('QBCore:Notify', src, "Source item not found.", 'error')
        return
    end

    if amountToTransfer > fromItem.amount then
        print("SetInventoryData: Attempting to transfer " .. amountToTransfer .. " but only " .. fromItem.amount .. " available in " .. fromItem.name)
        TriggerClientEvent('QBCore:Notify', src, "Not enough items in source slot to transfer.", 'error')
        return
    end

    local toItem = getItem(toInventory, src, toSlot)
    local fromId = getIdentifier(fromInventory, src)
    local toId = getIdentifier(toInventory, src)

    -- ***** NEW: Check if it's an intra-inventory move *****
    if fromId == toId then
        print("SetInventoryData: Intra-inventory move for " .. fromId .. " (e.g., player to player). Bypassing CanAddItem capacity checks.")
        -- For intra-inventory moves, weight/capacity limits of the inventory as a whole don't change.
        -- We just need to ensure slot mechanics are handled by RemoveItem/AddItem.
        if RemoveItem(fromId, fromItem.name, amountToTransfer, fromSlot, 'intra-inventory move: source remove') then
            if not AddItem(toId, fromItem.name, amountToTransfer, toSlot, fromItem.info, 'intra-inventory move: target add') then
                -- This AddItem might fail due to slot logic issues not related to overall capacity,
                -- or if the specific slot is somehow problematic.
                print("SetInventoryData: CRITICAL (Intra-Inv) - AddItem failed after RemoveItem. Attempting rollback.")
                TriggerClientEvent('QBCore:Notify', src, "Error moving item within inventory. Attempting to restore.", 'error')
                if not AddItem(fromId, fromItem.name, amountToTransfer, fromSlot, fromItem.info, 'intra-inventory move: critical rollback') then
                     print("SetInventoryData: ULTRA CRITICAL (Intra-Inv) - Rollback to source also failed. Item '" .. fromItem.name .. "' x" .. amountToTransfer .. " lost within " .. fromId .. ", from slot " .. fromSlot)
                     TriggerClientEvent('QBCore:Notify', src, "CRITICAL ERROR: Item restoration failed. Item may be lost. Contact admin.", 'error')
                     TriggerEvent('qb-log:server:CreateLog', 'itemloss', 'INTRA-INV CRITICAL LOSS', 'red',
                        'Item: ' .. fromItem.name .. 'x' .. amountToTransfer ..
                        ', Within: ' .. fromId .. ' (Slot ' .. fromSlot .. ' to ' .. toSlot .. ')' ..
                        ', Player: ' .. GetPlayerName(src) .. '(' .. src .. ') - Rollback Failed')
                end
            else
                -- Successfully moved within the same inventory
                if fromInventory == 'player' and toInventory ~= 'player' then checkWeapon(src, fromItem) end -- This condition (toInventory ~= 'player') will be false here, so checkWeapon won't run, which is correct for intra-player.
            end
        else
            print("SetInventoryData: (Intra-Inv) Failed to remove item from " .. fromId .. ", slot " .. fromSlot)
            TriggerClientEvent('QBCore:Notify', src, "Could not move item from source slot.", 'error')
        end
        return -- IMPORTANT: End execution here for intra-inventory moves
    end

    -- If fromId ~= toId, proceed with the existing inter-inventory transfer logic (Scenario 1 and 2 from previous response)
    -- Scenario 1: Moving to an empty slot OR Stacking onto an existing compatible item
    if not toItem or (toItem and toItem.name == fromItem.name and not QBCore.Shared.Items[fromItem.name:lower()].unique) then
        local canFit, reason = CanAddItem(toId, fromItem.name, amountToTransfer)
        if canFit then
            if RemoveItem(fromId, fromItem.name, amountToTransfer, fromSlot, 'transfer: source remove') then
                if not AddItem(toId, fromItem.name, amountToTransfer, toSlot, fromItem.info, 'transfer: target add') then
                    print("SetInventoryData: CRITICAL - AddItem to target failed after RemoveItem. Attempting to return item to source.")
                    TriggerClientEvent('QBCore:Notify', src, "Error placing item in destination. Attempting to return to source.", 'error')
                    if not AddItem(fromId, fromItem.name, amountToTransfer, fromSlot, fromItem.info, 'transfer: critical rollback') then
                        print("SetInventoryData: ULTRA CRITICAL - Rollback to source also failed. Item '" .. fromItem.name .. "' x" .. amountToTransfer .. " lost from " .. fromId .. ", slot " .. fromSlot)
                        TriggerClientEvent('QBCore:Notify', src, "CRITICAL ERROR: Item return failed. Item may be lost. Contact admin.", 'error')
                        TriggerEvent('qb-log:server:CreateLog', 'itemloss', 'CRITICAL ITEM LOSS', 'red',
                            'Item: ' .. fromItem.name .. 'x' .. amountToTransfer ..
                            ', From: ' .. fromId .. ' (Slot ' .. fromSlot .. ')' ..
                            ', To: ' .. toId .. ' (Slot ' .. toSlot .. ')' ..
                            ', Player: ' .. GetPlayerName(src) .. '(' .. src .. ') - Rollback Failed')
                    end
                else
                    if fromInventory == 'player' and toInventory ~= 'player' then checkWeapon(src, fromItem) end
                end
            else
                print("SetInventoryData: Failed to remove item from source inventory " .. fromId .. ", slot " .. fromSlot)
                TriggerClientEvent('QBCore:Notify', src, "Could not take item from source.", 'error')
            end
        else
            local itemLabel = QBCore.Shared.Items[fromItem.name:lower()].label or fromItem.name
            local notification = "Cannot place " .. itemLabel .. " there."
            if reason == 'total_weight_limit' then
                notification = "Target inventory is too full (weight)."
            elseif reason == 'item_specific_weight_limit' then
                notification = "Target inventory cannot hold more of " .. itemLabel .. " (specific limit)."
            elseif reason == 'slot_limit' then
                notification = "Target inventory has no free slots."
            elseif reason == 'invalid_item' then
                notification = "The item being moved is invalid."
            elseif reason == 'invalid_amount' then
                notification = "Invalid amount for transfer."
            elseif reason then
                 notification = "Cannot place item: " .. reason
            end
            TriggerClientEvent('QBCore:Notify', src, notification, 'error')
            print("SetInventoryData: CanAddItem failed for '" .. fromItem.name .. "' to '" .. toId .. "'. Reason: " .. (reason or 'unknown'))
        end

    -- Scenario 2: Swapping different items (toItem exists and is different from fromItem.name)
    elseif toItem and toItem.name ~= fromItem.name then
        -- This is your existing swap logic from the file you uploaded, which uses CanAddItemWithReplacement
        -- Ensure this part is also robust, though the primary issue reported was for simple moves.
        print("SetInventoryData: Initiating SWAP between " .. fromItem.name .. " and " .. toItem.name)
        local movingFromItem = DeepCopy(fromItem)
        movingFromItem.amount = amountToTransfer
        local movingToItem = DeepCopy(toItem)

        local canTargetFitInSource, reasonTargetFit = CanAddItemWithReplacement(fromId, movingToItem.name, movingToItem.amount, fromSlot, movingFromItem)
        local canSourceFitInTarget, reasonSourceFit = CanAddItemWithReplacement(toId, movingFromItem.name, movingFromItem.amount, toSlot, movingToItem)

        if canSourceFitInTarget and canTargetFitInSource then
            local originalFromItemState = DeepCopy(fromItem)
            local originalToItemState = DeepCopy(toItem)
            if RemoveItem(fromId, originalFromItemState.name, amountToTransfer, fromSlot, 'swap: remove original from source') then
                if RemoveItem(toId, originalToItemState.name, originalToItemState.amount, toSlot, 'swap: remove original from target') then
                    local addedSourceToTarget = AddItem(toId, originalFromItemState.name, amountToTransfer, toSlot, originalFromItemState.info, 'swap: add fromItem to target slot')
                    local addedTargetToSource = AddItem(fromId, originalToItemState.name, originalToItemState.amount, fromSlot, originalToItemState.info, 'swap: add toItem to source slot')
                    if not (addedSourceToTarget and addedTargetToSource) then
                        print("SetInventoryData: CRITICAL - Swap failed during AddItem phase. Attempting complex rollback.")
                        TriggerClientEvent('QBCore:Notify', src, "Swap failed. Attempting to restore items.", 'error')
                        if not addedSourceToTarget then
                            AddItem(fromId, originalFromItemState.name, amountToTransfer, fromSlot, originalFromItemState.info, 'swap_rollback: fromItem to source')
                        end
                        if not addedTargetToSource then
                            AddItem(toId, originalToItemState.name, originalToItemState.amount, toSlot, originalToItemState.info, 'swap_rollback: toItem to target')
                        end
                    else
                        print("SetInventoryData: SWAP successful.")
                        if fromInventory == 'player' and toInventory ~= 'player' then checkWeapon(src, originalFromItemState) end
                        if toInventory == 'player' and fromInventory ~= 'player' then checkWeapon(src, originalToItemState) end
                    end
                else
                    print("SetInventoryData: Swap failed - Could not remove item from target slot. Rolling back source item.")
                    AddItem(fromId, originalFromItemState.name, amountToTransfer, fromSlot, originalFromItemState.info, 'swap_rollback: fromItem (target remove failed)')
                    TriggerClientEvent('QBCore:Notify', src, "Swap failed (target item stuck).", 'error')
                end
            else
                print("SetInventoryData: Swap failed - Could not remove item from source slot.")
                TriggerClientEvent('QBCore:Notify', src, "Swap failed (source item stuck).", 'error')
            end
        else
            local notification = "Cannot swap items: "
            if not canSourceFitInTarget then notification = notification .. "Dragged item won't fit in target slot ("..(reasonSourceFit or "check failed").."). " end
            if not canTargetFitInSource then notification = notification .. "Item from target slot won't fit back ("..(reasonTargetFit or "check failed")..")." end
            TriggerClientEvent('QBCore:Notify', src, notification, 'error')
            print("SetInventoryData (Swap): Pre-check failed. SourceFitReason: "..(reasonSourceFit or "N/A").."; TargetFitReason: "..(reasonTargetFit or "N/A"))
        end
    else
        print("SetInventoryData: Unhandled item transfer condition for fromSlot: "..fromSlot..", toSlot: "..toSlot)
        TriggerClientEvent('QBCore:Notify', src, "Unknown inventory action error.", 'error')
    end
end)

-- This new helper function would ideally be in functions.lua or local to main.lua if only used here.
-- It's a conceptual CanAddItem, but it simulates removing an item from the target inventory first.
function CanAddItemWithReplacement(inventoryId, itemNameToAdd, amountToAdd, targetSlotForNewItem, itemCurrentlyInTargetSlot)
    local Player = QBCore.Functions.GetPlayer(inventoryId)
    local itemDataToAdd = QBCore.Shared.Items[itemNameToAdd:lower()]

    if not itemDataToAdd then return false, 'invalid_item_to_add' end
    amountToAdd = tonumber(amountToAdd) or 1
    if amountToAdd <= 0 then return false, 'invalid_amount' end

    local originalItems, maxWeight, maxSlots
    if Player then
        originalItems = Player.PlayerData.items
        maxWeight = Config.MaxWeight
        maxSlots = Config.MaxSlots
    elseif Inventories[inventoryId] then
        originalItems = Inventories[inventoryId].items
        maxWeight = Inventories[inventoryId].maxweight
        maxSlots = Inventories[inventoryId].slots
    elseif Drops and Drops[inventoryId] then
        originalItems = Drops[inventoryId].items
        maxWeight = Drops[inventoryId].maxweight
        maxSlots = Drops[inventoryId].slots
    else
        return false, 'invalid_target_inventory'
    end

    -- Create a temporary inventory state *as if* itemCurrentlyInTargetSlot was removed
    local tempItems = DeepCopy(originalItems)
    if itemCurrentlyInTargetSlot and tempItems[targetSlotForNewItem] and tempItems[targetSlotForNewItem].name == itemCurrentlyInTargetSlot.name then
        tempItems[targetSlotForNewItem] = nil -- Simulate removal
    end
    -- Note: If itemCurrentlyInTargetSlot is nil (target slot was empty), tempItems is just a copy of originalItems.

    -- Now, check if itemNameToAdd can fit into this tempItems state
    -- 1. Overall weight check
    local weightOfItemToAdd = itemDataToAdd.weight * amountToAdd
    local currentTotalWeightOfTemp = GetTotalWeight(tempItems)
    if currentTotalWeightOfTemp + weightOfItemToAdd > maxWeight then
        return false, 'total_weight_limit'
    end

    -- 2. Item-specific weight check (ONLY FOR PLAYER INVENTORY)
    if Player and Config.ItemSpecificMaxWeights and Config.ItemSpecificMaxWeights[itemNameToAdd:lower()] then -- Check Config.ItemSpecificMaxWeights exists
        local currentSpecificItemWeight = 0
        for _, invItem in pairs(tempItems) do
            if invItem and invItem.name:lower() == itemNameToAdd:lower() then -- check invItem exists
                currentSpecificItemWeight = currentSpecificItemWeight + (invItem.weight * invItem.amount)
            end
        end
        if currentSpecificItemWeight + weightOfItemToAdd > Config.ItemSpecificMaxWeights[itemNameToAdd:lower()] then
            return false, 'item_specific_weight_limit'
        end
    end

    -- 3. Slot check
    local needsNewSlotInTemp = true
    if not itemDataToAdd.unique then
        for slotKey, invItem in pairs(tempItems) do
            if invItem and invItem.name:lower() == itemNameToAdd:lower() then
                 -- If a stack already exists (not in the targetSlotForNewItem, which is now simulated as empty or was already empty)
                if slotKey ~= targetSlotForNewItem then
                    needsNewSlotInTemp = false
                    break
                end
            end
        end
         -- If we are adding to targetSlotForNewItem (which is now notionally available), it doesn't strictly need a *new* slot beyond that one.
        if tempItems[targetSlotForNewItem] == nil then needsNewSlotInTemp = false; end
    end


    if needsNewSlotInTemp then -- This means item is unique OR no existing stack AND targetSlotForNewItem was NOT made available/suitable.
        local slotsUsedInTemp = 0
        for _, itemVal in pairs(tempItems) do if itemVal then slotsUsedInTemp = slotsUsedInTemp + 1 end end

        -- If targetSlotForNewItem was originally occupied, removing it freed one slot.
        -- So, if slotsUsedInTemp (after removal) >= maxSlots, it means even with the freed slot, we are full.
        if itemCurrentlyInTargetSlot and slotsUsedInTemp >= maxSlots then
             return false, 'slot_limit'
        elseif not itemCurrentlyInTargetSlot and slotsUsedInTemp >= maxSlots then
             -- Target slot was empty, and we still need a new slot, but inventory is full.
             return false, 'slot_limit'
        end
    end
    return true
end
