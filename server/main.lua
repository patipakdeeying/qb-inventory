QBCore = exports['qb-core']:GetCoreObject()
Inventories = {}
--Drops = {}
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

-- CreateThread(function()
--     while true do
--         for k, v in pairs(Drops) do
--             if v and (v.createdTime + (Config.CleanupDropTime * 60) < os.time()) and not Drops[k].isOpen then
--                 local entity = NetworkGetEntityFromNetworkId(v.entityId)
--                 if DoesEntityExist(entity) then DeleteEntity(entity) end
--                 Drops[k] = nil
--             end
--         end
--         Wait(Config.CleanupDropInterval * 60000)
--     end
-- end)

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
    -- if Drops[inventory] then
    --     Drops[inventory].isOpen = false
    --     if #Drops[inventory].items == 0 and not Drops[inventory].isOpen then -- if no listeed items in the drop on close
    --         TriggerClientEvent('qb-inventory:client:removeDropTarget', -1, Drops[inventory].entityId)
    --         Wait(500)
    --         local entity = NetworkGetEntityFromNetworkId(Drops[inventory].entityId)
    --         if DoesEntityExist(entity) then DeleteEntity(entity) end
    --         Drops[inventory] = nil
    --     end
    --     return
    -- end
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

-- RegisterNetEvent('qb-inventory:server:openDrop', function(dropId)
--     local src = source
--     local Player = QBCore.Functions.GetPlayer(src)
--     if not Player then return end
--     local playerPed = GetPlayerPed(src)
--     local playerCoords = GetEntityCoords(playerPed)
--     local drop = Drops[dropId]
--     if not drop then return end
--     if drop.isOpen then return end
--     local distance = #(playerCoords - drop.coords)
--     if distance > 2.5 then return end
--     local formattedInventory = {
--         name = dropId,
--         label = dropId,
--         maxweight = drop.maxweight,
--         slots = drop.slots,
--         inventory = drop.items
--     }
--     drop.isOpen = true
--     TriggerClientEvent('qb-inventory:client:openInventory', source, Player.PlayerData.items, formattedInventory)
-- end)

-- RegisterNetEvent('qb-inventory:server:updateDrop', function(dropId, coords)
--     Drops[dropId].coords = coords
-- end)

RegisterNetEvent('qb-inventory:server:snowball', function(action)
    if action == 'add' then
        AddItem(source, 'weapon_snowball', 1, false, false, 'qb-inventory:server:snowball')
    elseif action == 'remove' then
        RemoveItem(source, 'weapon_snowball', 1, false, 'qb-inventory:server:snowball')
    end
end)

-- Callbacks

QBCore.Functions.CreateCallback('qb-inventory:server:GetCurrentDrops', function(_, cb)
    cb(Drops)
end)

-- QBCore.Functions.CreateCallback('qb-inventory:server:createDrop', function(source, cb, item)
--     local src = source
--     local Player = QBCore.Functions.GetPlayer(src)
--     if not Player then
--         cb(false)
--         return
--     end
--     local playerPed = GetPlayerPed(src)
--     local playerCoords = GetEntityCoords(playerPed)
--     if RemoveItem(src, item.name, item.amount, item.fromSlot, 'dropped item') then
--         if item.type == 'weapon' then checkWeapon(src, item) end
--         TaskPlayAnim(playerPed, 'pickup_object', 'pickup_low', 8.0, -8.0, 2000, 0, 0, false, false, false)
--         local bag = CreateObjectNoOffset(Config.ItemDropObject, playerCoords.x + 0.5, playerCoords.y + 0.5, playerCoords.z, true, true, false)
--         local dropId = NetworkGetNetworkIdFromEntity(bag)
--         local newDropId = 'drop-' .. dropId
--         local itemsTable = setmetatable({ item }, {
--             __len = function(t)
--                 local length = 0
--                 for _ in pairs(t) do length += 1 end
--                 return length
--             end
--         })
--         if not Drops[newDropId] then
--             Drops[newDropId] = {
--                 name = newDropId,
--                 label = 'Drop',
--                 items = itemsTable,
--                 entityId = dropId,
--                 createdTime = os.time(),
--                 coords = playerCoords,
--                 maxweight = Config.DropSize.maxweight,
--                 slots = Config.DropSize.slots,
--                 isOpen = true
--             }
--             TriggerClientEvent('qb-inventory:client:setupDropTarget', -1, dropId)
--         else
--             table.insert(Drops[newDropId].items, item)
--         end
--         cb(dropId)
--     else
--         cb(false)
--     end
-- end)

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
    -- elseif inventoryId:find('drop-') == 1 then
    --     if Drops[inventoryId] and Drops[inventoryId]['items'] then
    --         items = Drops[inventoryId]['items']
    --     end
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

RegisterNetEvent('qb-inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount)
    if toInventory:find('shop%-') then return end
    if not fromInventory or not toInventory or not fromSlot or not toSlot or not fromAmount or not toAmount then return end
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    fromSlot, toSlot, fromAmount, toAmount = tonumber(fromSlot), tonumber(toSlot), tonumber(fromAmount), tonumber(toAmount)

    -- --- START OF NEW LOGIC FOR INTERNAL PLAYER INVENTORY MOVES ---
    -- This block handles moving items *within* the same player inventory (including hotbar slots).
    -- It bypasses AddItem/RemoveItem to prevent "stack full" errors on relocations.
    if fromInventory == 'player' and toInventory == 'player' then
        local playerInventory = Player.PlayerData.items
        local movingItem = playerInventory[fromSlot]
        local targetSlotItem = playerInventory[toSlot] -- Item currently in the target slot

        if not movingItem then
            print('SetInventoryData: [Internal Move] No item to move in fromSlot ' .. fromSlot)
            return
        end

        -- If trying to move to the same slot, do nothing
        if fromSlot == toSlot then
            return
        end

        -- Scenario 1: Moving to an empty slot (most common for manual hotbar placement)
        if not targetSlotItem then
            playerInventory[toSlot] = movingItem       -- Place item in target slot
            playerInventory[toSlot].slot = toSlot      -- Update item's slot property
            playerInventory[fromSlot] = nil            -- Clear the original slot
            Player.Functions.SetPlayerData('items', playerInventory) -- Update player data
            return -- Done with this move
        end

        -- Scenario 2: Stacking on an existing item of the same type
        -- This applies if you drag item A onto item A in a different slot (and it's not a unique item)
        if movingItem.name:lower() == targetSlotItem.name:lower() and not movingItem.unique then
            local effectiveMaxStack = Config.ItemMaxStacks[movingItem.name:lower()] or Config.MaxStack
            local canAddToStack = effectiveMaxStack - targetSlotItem.amount

            if canAddToStack <= 0 then
                print('SetInventoryData: [Internal Move] Cannot stack - target stack for ' .. movingItem.name .. ' is full.')
                -- Client-side UI will typically prevent this, but server check is good.
                return
            end

            local amountToStack = math.min(movingItem.amount, canAddToStack)
            targetSlotItem.amount = targetSlotItem.amount + amountToStack -- Add to target stack
            movingItem.amount = movingItem.amount - amountToStack         -- Remove from source stack

            if movingItem.amount <= 0 then
                playerInventory[fromSlot] = nil -- Clear original slot if all moved
            else
                playerInventory[fromSlot] = movingItem -- Update original slot if partial move
            end
            Player.Functions.SetPlayerData('items', playerInventory)
            return -- Done
        end

        -- Scenario 3: Swapping items (target slot is occupied by a different item type, or a unique item)
        if targetSlotItem then
            playerInventory[toSlot] = movingItem       -- Place moving item in target slot
            playerInventory[toSlot].slot = toSlot      -- Update its slot property
            playerInventory[fromSlot] = targetSlotItem -- Place target item in original slot
            playerInventory[fromSlot].slot = fromSlot  -- Update its slot property
            Player.Functions.SetPlayerData('items', playerInventory)
            return -- Done
        end

        -- Fallback if something unexpected happened during internal move (shouldn't be hit often)
        print('SetInventoryData: [Internal Move] Unhandled scenario for ' .. movingItem.name .. ' from ' .. fromSlot .. ' to ' .. toSlot)
        return
    end
    -- --- END OF NEW LOGIC FOR INTERNAL PLAYER INVENTORY MOVES ---


    -- --- ORIGINAL LOGIC FOR TRANSFERS BETWEEN DIFFERENT INVENTORIES ---
    -- (player to stash, stash to player, player to trunk, etc.)
    -- This block remains largely as is, as it correctly uses AddItem/RemoveItem for external interactions.
    local fromItem = getItem(fromInventory, src, fromSlot)
    local toItem = getItem(toInventory, src, toSlot)

    if fromItem then
        if not toItem and toAmount > fromItem.amount then return end
        if fromInventory == 'player' and toInventory ~= 'player' then checkWeapon(src, fromItem) end

        local fromId = getIdentifier(fromInventory, src)
        local toId = getIdentifier(toInventory, src)

        if toItem and fromItem.name == toItem.name then -- Stacking on existing same item (between inventories)
            local amountToMove = fromAmount
            local actualAmountAdded = AddItem(toId, toItem.name, amountToMove, toSlot, toItem.info, 'stacked item')
            if actualAmountAdded > 0 then
                RemoveItem(fromId, fromItem.name, actualAmountAdded, fromSlot, 'stacked item')
            else
                print('SetInventoryData: Failed to stack ' .. fromItem.name .. ' to target inventory.')
            end

        elseif not toItem and toAmount < fromAmount then -- Splitting an item to a new slot (between inventories)
            local amountToMove = toAmount
            local actualAmountAdded = AddItem(toId, fromItem.name, amountToMove, toSlot, fromItem.info, 'split item')
            if actualAmountAdded > 0 then
                RemoveItem(fromId, fromItem.name, actualAmountAdded, fromSlot, 'split item')
            else
                print('SetInventoryData: Failed to split ' .. fromItem.name .. ' to new slot.')
            end

        else -- Swapping items or moving to an empty slot (between inventories)
            if toItem then -- Swapping items (between inventories)
                local fromItemAmount = fromItem.amount
                local toItemAmount = toItem.amount

                local canAddToTarget = AddItem(toId, fromItem.name, fromItemAmount, toSlot, fromItem.info, 'swapped item - check')
                if canAddToTarget == fromItemAmount then
                    local canAddBackToSource = AddItem(fromId, toItem.name, toItemAmount, fromSlot, toItem.info, 'swapped item - check back')
                    if canAddBackToSource == toItemAmount then
                        RemoveItem(fromId, fromItem.name, fromItemAmount, fromSlot, 'swapped item')
                        RemoveItem(toId, toItem.name, toItemAmount, toSlot, 'swapped item')
                        AddItem(toId, fromItem.name, fromItemAmount, toSlot, fromItem.info, 'swapped item')
                        AddItem(fromId, toItem.name, toItemAmount, fromSlot, toItem.info, 'swapped item')
                    else
                        print('SetInventoryData: Swap failed - source cannot fully accept swapped item ' .. toItem.name)
                    end
                else
                    print('SetInventoryData: Swap failed - target cannot fully accept item ' .. fromItem.name)
                end
            else -- Moving to an empty slot (between inventories)
                local amountToMove = fromItemAmount
                local actualAmountAdded = AddItem(toId, fromItem.name, amountToMove, toSlot, fromItem.info, 'moved item')
                if actualAmountAdded > 0 then
                    RemoveItem(fromId, fromItem.name, actualAmountAdded, fromSlot, 'moved item')
                else
                    print('SetInventoryData: Failed to move ' .. fromItem.name .. ' to empty slot.')
                end
            end
        end
    end
end)
