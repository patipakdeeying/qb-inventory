QBCore = exports['qb-core']:GetCoreObject()
Inventories = {}
Drops = {}
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

CreateThread(function()
    while true do
        for k, v in pairs(Drops) do
            if v and (v.createdTime + (Config.CleanupDropTime * 60) < os.time()) and not Drops[k].isOpen then
                local entity = NetworkGetEntityFromNetworkId(v.entityId)
                if DoesEntityExist(entity) then DeleteEntity(entity) end
                Drops[k] = nil
            end
        end
        Wait(Config.CleanupDropInterval * 60000)
    end
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
    if Drops[inventory] then
        Drops[inventory].isOpen = false
        if #Drops[inventory].items == 0 and not Drops[inventory].isOpen then -- if no listeed items in the drop on close
            TriggerClientEvent('qb-inventory:client:removeDropTarget', -1, Drops[inventory].entityId)
            Wait(500)
            local entity = NetworkGetEntityFromNetworkId(Drops[inventory].entityId)
            if DoesEntityExist(entity) then DeleteEntity(entity) end
            Drops[inventory] = nil
        end
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

RegisterNetEvent('qb-inventory:server:DoItemRemoval', function(itemSlot, itemName, amountToRemove)
    local src = source
    local QBPlayer = QBCore.Functions.GetPlayer(src) -- Use a different name like QBPlayer for the local object

    if not QBPlayer or not QBPlayer.PlayerData or not QBPlayer.PlayerData.source then
        print('[qb-inventory] DoItemRemoval: Could not get valid QBPlayer object for source ' .. src)
        return
    end

    local playerServerId = QBPlayer.PlayerData.source -- This is the ID to use with the global Player() state accessor
    local itemInSlot = GetItemBySlot(playerServerId, itemSlot) -- GetItemBySlot is in functions.lua

    if not itemInSlot or itemInSlot.name:lower() ~= itemName:lower() or itemInSlot.amount < amountToRemove then
        TriggerClientEvent('QBCore:Notify', playerServerId, "Error removing item. Details mismatch or insufficient amount.", "error")
        print('[qb-inventory] DoItemRemoval: Item validation failed for player ' .. playerServerId .. ' - Slot: ' .. itemSlot .. ' Name: ' .. itemName .. ' Amount: ' .. amountToRemove .. ' Found: ' .. (itemInSlot and json.encode(itemInSlot) or 'nil'))
        return
    end

    if RemoveItem(playerServerId, itemName, amountToRemove, itemSlot, "removed_via_menu") then -- RemoveItem is in functions.lua
        local itemInfo = QBCore.Shared.Items[itemName:lower()]
        if itemInfo then
            TriggerClientEvent('qb-inventory:client:ItemBox', playerServerId, itemInfo, 'remove', amountToRemove)
        end
        TriggerClientEvent('QBCore:Notify', playerServerId, "Removed " .. amountToRemove .. "x " .. (itemInfo and itemInfo.label or itemName), "success")

        -- Correctly using the GLOBAL Player(sourceId) state accessor function
        if Player(playerServerId).state and Player(playerServerId).state.inv_busy then
            TriggerClientEvent('qb-inventory:client:updateInventory', playerServerId)
            print("[qb-inventory] DoItemRemoval: Sent updateInventory event for player " .. playerServerId .. " because inv_busy was true.")
        elseif Player(playerServerId).state == nil then
            print("[qb-inventory] DoItemRemoval: Player(" .. playerServerId .. ").state was nil. Cannot check inv_busy for UI update.")
        else
            -- This means Player(playerServerId).state exists, but inv_busy is false or nil
            print("[qb-inventory] DoItemRemoval: Player(" .. playerServerId .. ").state.inv_busy was false or nil. No inventory update event sent.")
        end
    else
        TriggerClientEvent('QBCore:Notify', playerServerId, "Failed to remove " .. (itemInfo and itemInfo.label or itemName) .. ".", "error")
    end
end)

RegisterNetEvent('qb-inventory:server:DoGiveItemToPlayerId', function(itemSlot, itemName, itemInfoParam, amountToGive, targetPlayerServerId)
    local src = source
    local SourcePlayer = QBCore.Functions.GetPlayer(src)

    if not SourcePlayer or SourcePlayer.PlayerData.metadata['isdead'] or SourcePlayer.PlayerData.metadata['inlaststand'] or SourcePlayer.PlayerData.metadata['ishandcuffed'] then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.cannot_give_now'), 'error') -- Add this lang key
        return
    end

    local TargetPlayer = QBCore.Functions.GetPlayer(tonumber(targetPlayerServerId))
    if not TargetPlayer then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.target_not_online'), 'error') -- Add this lang key
        return
    end

    if TargetPlayer.PlayerData.source == src then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.cannot_give_self'), 'error') -- Add this lang key
        return
    end

    if TargetPlayer.PlayerData.metadata['isdead'] or TargetPlayer.PlayerData.metadata['inlaststand'] or TargetPlayer.PlayerData.metadata['ishandcuffed'] then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.target_cannot_receive'), 'error') -- Add this lang key
        return
    end

    -- Optional: Distance Check (though ID is provided, good for sanity)
    local sourcePed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(TargetPlayer.PlayerData.source)
    local distance = #(GetEntityCoords(sourcePed) - GetEntityCoords(targetPed))
    if distance > 5.0 then -- Configurable distance
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.too_far_to_give'), 'error') -- Add this lang key
        return
    end

    local sourceItem = GetItemBySlot(src, itemSlot) -- from functions.lua
    if not sourceItem or sourceItem.name:lower() ~= itemName:lower() or sourceItem.amount < amountToGive then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.you_dont_have_enough'), 'error') -- Add this lang key
        return
    end
    
    -- Use itemInfo from the source item if itemInfoParam is minimal, or merge/prioritize
    local actualItemInfoToGive = sourceItem.info or itemInfoParam or {}

    -- Check if target can receive (using your refined CanAddItem from functions.lua)
    local canTargetReceive, reasonCannotReceive = CanAddItem(TargetPlayer.PlayerData.source, itemName, amountToGive)
    if not canTargetReceive then
        local reasonMsg = reasonCannotReceive or "inventory full"
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.target_inventory_full', {reason = reasonMsg}), 'error') -- Add e.g. target_inventory_full = "Target's inventory is %{reason}."
        TriggerClientEvent('QBCore:Notify', TargetPlayer.PlayerData.source, Lang:t('notify.inventory_full_ Giver_tried', {giver = SourcePlayer.PlayerData.charinfo.firstname}), 'warning') -- Add e.g. inventory_full_giver_tried = "%{giver} tried to give you items but your inventory is full."
        return
    end

    if RemoveItem(src, itemName, amountToGive, itemSlot, "Gave to player ID: " .. targetPlayerServerId) then
        if AddItem(TargetPlayer.PlayerData.source, itemName, amountToGive, nil, actualItemInfoToGive, "Received from player ID: " .. src) then
            local sharedItemData = QBCore.Shared.Items[itemName:lower()]
            
            TriggerClientEvent('qb-inventory:client:giveAnim', src)
            TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItemData, 'remove', amountToGive)
            
            TriggerClientEvent('qb-inventory:client:giveAnim', TargetPlayer.PlayerData.source)
            TriggerClientEvent('qb-inventory:client:ItemBox', TargetPlayer.PlayerData.source, sharedItemData, 'add', amountToGive)
            
            TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.you_gave_item', {amount = amountToGive, item = sharedItemData.label, target = TargetPlayer.PlayerData.charinfo.firstname .. ' ' .. TargetPlayer.PlayerData.charinfo.lastname}), 'success')
            TriggerClientEvent('QBCore:Notify', TargetPlayer.PlayerData.source, Lang:t('notify.received_item_from', {amount = amountToGive, item = sharedItemData.label, giver = SourcePlayer.PlayerData.charinfo.firstname .. ' ' .. SourcePlayer.PlayerData.charinfo.lastname}), 'success')

            if Player(TargetPlayer.PlayerData.source).state and Player(TargetPlayer.PlayerData.source).state.inv_busy then
                 TriggerClientEvent('qb-inventory:client:updateInventory', TargetPlayer.PlayerData.source)
            end
            if Player(src).state and Player(src).state.inv_busy then
                 TriggerClientEvent('qb-inventory:client:updateInventory', src)
            end
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.failed_to_give_target_add_fail'), 'error') -- Add lang key
            -- Attempt to give back item to source player if AddItem to target failed (complex, requires available slot)
            -- For simplicity now, it's just a fail. A robust system would roll back or stash the item.
            print("CRITICAL: Removed item from source "..src.." but FAILED to AddItem to target "..TargetPlayer.PlayerData.source)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.failed_to_remove_for_give'), 'error') -- Add lang key
    end
end)

RegisterNetEvent('qb-inventory:server:openDrop', function(dropId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local drop = Drops[dropId]
    if not drop then return end
    if drop.isOpen then return end
    local distance = #(playerCoords - drop.coords)
    if distance > 2.5 then return end
    local formattedInventory = {
        name = dropId,
        label = dropId,
        maxweight = drop.maxweight,
        slots = drop.slots,
        inventory = drop.items
    }
    drop.isOpen = true
    TriggerClientEvent('qb-inventory:client:openInventory', source, Player.PlayerData.items, formattedInventory)
end)

RegisterNetEvent('qb-inventory:server:updateDrop', function(dropId, coords)
    Drops[dropId].coords = coords
end)

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

QBCore.Functions.CreateCallback('qb-inventory:server:createDrop', function(source, cb, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb(false)
        return
    end
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    if RemoveItem(src, item.name, item.amount, item.fromSlot, 'dropped item') then
        if item.type == 'weapon' then checkWeapon(src, item) end
        TaskPlayAnim(playerPed, 'pickup_object', 'pickup_low', 8.0, -8.0, 2000, 0, 0, false, false, false)
        local bag = CreateObjectNoOffset(Config.ItemDropObject, playerCoords.x + 0.5, playerCoords.y + 0.5, playerCoords.z, true, true, false)
        local dropId = NetworkGetNetworkIdFromEntity(bag)
        local newDropId = 'drop-' .. dropId
        local itemsTable = setmetatable({ item }, {
            __len = function(t)
                local length = 0
                for _ in pairs(t) do length += 1 end
                return length
            end
        })
        if not Drops[newDropId] then
            Drops[newDropId] = {
                name = newDropId,
                label = 'Drop',
                items = itemsTable,
                entityId = dropId,
                createdTime = os.time(),
                coords = playerCoords,
                maxweight = Config.DropSize.maxweight,
                slots = Config.DropSize.slots,
                isOpen = true
            }
            TriggerClientEvent('qb-inventory:client:setupDropTarget', -1, dropId)
        else
            table.insert(Drops[newDropId].items, item)
        end
        cb(dropId)
    else
        cb(false)
    end
end)

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

RegisterNetEvent('qb-inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    fromSlot = tonumber(fromSlot)
    toSlot = tonumber(toSlot)
    -- fromAmount is the original amount in the source slot (or what client thinks it is)
    -- toAmount is the amount the player intends to move/drop into the target slot

    local fromItem = getItem(fromInventory, src, fromSlot) -- Helper to get item from source
    local toItem = getItem(toInventory, src, toSlot)     -- Helper to get item currently in target slot (if any)

    if not fromItem then
        QBCore.Functions.Notify(src, "Source item not found.", "error")
        return
    end

    local fromId = getIdentifier(fromInventory, src) -- Helper to get actual inventory owner ID
    local toId = getIdentifier(toInventory, src)     -- Helper to get actual inventory owner ID

    -- Determine the actual quantity being attempted to move.
    -- This could be the whole stack (fromItem.amount) or a partial amount (toAmount, if splitting/stacking specific number).
    -- For simplicity, let's assume 'toAmount' from the client is the intended quantity to move for this operation.
    -- Ensure 'toAmount' is valid (e.g., not more than is in fromItem.amount if not splitting from a larger stack, not zero).
    local amountToAttemptMove = tonumber(toAmount)
    if not amountToAttemptMove or amountToAttemptMove <= 0 then
        QBCore.Functions.Notify(src, "Invalid amount to move.", "error")
        return
    end
    if fromItem.amount < amountToAttemptMove then
         QBCore.Functions.Notify(src, "Trying to move more than available in source slot.", "error")
         return
    end

    -- *** THE CRUCIAL PRE-CHECK ***
    -- Check if the 'toId' (player inventory) can accept the 'fromItem.name' with 'amountToAttemptMove'.
    -- The CanAddItem function is in server/functions.lua
    local canAccept, reason = CanAddItem(toId, fromItem.name, amountToAttemptMove) --

    if not canAccept then
        local targetInventoryLabel = toInventory
        if toInventory == "player" then targetInventoryLabel = "Your inventory" end 
        -- You might want to fetch a more descriptive label if Inventories[toInventory].label exists

        QBCore.Functions.Notify(src, "Cannot move item: " .. targetInventoryLabel .. " " .. (reason or "cannot accept it (full/weight/limit)."), "error")
        
        -- It's also good practice to inform the client UI that the operation failed so it can revert any visual changes.
        -- For example, by triggering a client event:
        TriggerClientEvent('qb-inventory:client:operationFailed', src, "Move failed: Destination cannot accept item.")
        return -- IMPORTANT: Stop further processing
    end

    -- *** END CRUCIAL PRE-CHECK ***

    -- If we are swapping items (toItem exists and it's not stacking on itself)
    -- we also need to check if the fromInventory can accept the toItem.
    if toItem and fromItem.name ~= toItem.name and fromId ~= toId then
        local canSourceAcceptSwap, swapReason = CanAddItem(fromId, toItem.name, toItem.amount)
        if not canSourceAcceptSwap then
            local sourceInventoryLabel = fromInventory
             if fromInventory == "player" then sourceInventoryLabel = "Your inventory" end

            QBCore.Functions.Notify(src, "Cannot swap: " .. sourceInventoryLabel .. " " .. (swapReason or "cannot accept the returning item."), "error")
            TriggerClientEvent('qb-inventory:client:operationFailed', src, "Swap failed: Source cannot accept the item from destination.")
            return
        end
    end

    -- If CanAddItem passed, proceed with the original logic for removing and then adding.
    -- The original logic for different scenarios (stacking, splitting, moving to empty, swapping) would follow.
    -- Example for a simple move to an potentially empty slot (simplified):

    local itemRemovedSuccessfully = false
    if toItem and fromItem.name == toItem.name and not QBCore.Shared.Items[fromItem.name].unique then -- Stacking
        itemRemovedSuccessfully = RemoveItem(fromId, fromItem.name, amountToAttemptMove, fromSlot, 'stacked item')
    elseif not toItem and amountToAttemptMove < fromItem.amount and not QBCore.Shared.Items[fromItem.name].unique then -- Splitting
        itemRemovedSuccessfully = RemoveItem(fromId, fromItem.name, amountToAttemptMove, fromSlot, 'split item')
    else -- Moving whole slot or swapping
        itemRemovedSuccessfully = RemoveItem(fromId, fromItem.name, fromItem.amount, fromSlot, (toItem and 'swapped item part 1' or 'moved item') )
    end

    if itemRemovedSuccessfully then
        local itemAddedSuccessfully = false
        if toItem and fromItem.name == toItem.name and not QBCore.Shared.Items[fromItem.name].unique then -- Stacking
            itemAddedSuccessfully = AddItem(toId, fromItem.name, amountToAttemptMove, toSlot, fromItem.info, 'stacked item')
        elseif not toItem and amountToAttemptMove < fromItem.amount and not QBCore.Shared.Items[fromItem.name].unique then -- Splitting
             itemAddedSuccessfully = AddItem(toId, fromItem.name, amountToAttemptMove, toSlot, fromItem.info, 'split item')
        elseif toItem then -- Swapping (fromItem has been removed, now add it; then remove toItem and add it to fromId)
            if AddItem(toId, fromItem.name, fromItem.amount, toSlot, fromItem.info, 'swapped item part 1') then
                if RemoveItem(toId, toItem.name, toItem.amount, toSlot, 'swapped item part 2') then -- Note: toItem was originally in toSlot, now fromItem is. This removal target toItem by name/amount if AddItem puts it elsewhere. Be cautious with slot targets in complex swaps.
                    if AddItem(fromId, toItem.name, toItem.amount, fromSlot, toItem.info, 'swapped item part 2') then
                        itemAddedSuccessfully = true
                    else
                        -- Failed to add toItem to fromId; try to give fromItem back to toId (complex rollback)
                        AddItem(toId, toItem.name, toItem.amount, toSlot, toItem.info, 'swap_rollback_toItem_to_toId')
                    end
                else
                    -- Failed to remove toItem; try to give fromItem back to fromId
                    AddItem(fromId, fromItem.name, fromItem.amount, fromSlot, fromItem.info, 'swap_rollback_fromItem_to_fromId')
                end
            end
        else -- Moving to empty slot
            itemAddedSuccessfully = AddItem(toId, fromItem.name, amountToAttemptMove, toSlot, fromItem.info, 'moved item')
        end

        if not itemAddedSuccessfully then
            -- Attempt to give the item back to the source inventory if AddItem failed
            QBCore.Functions.Notify(src, "Failed to add item to destination, attempting to return to source.", "error")
            AddItem(fromId, fromItem.name, amountToAttemptMove, fromSlot, fromItem.info, 'rollback_failed_add')
            -- Additional client notification for the rollback may be useful here
        end
    else
        QBCore.Functions.Notify(src, "Failed to remove item from source.", "error")
    end

    -- Update client inventories if they were involved and are open
    if Player(src).state.inv_busy then
        TriggerClientEvent('qb-inventory:client:updateInventory', src)
    end
    if fromInventory:find('otherplayer-') then
        local otherPlayerSrc = tonumber(fromInventory:match('otherplayer%-(.+)'))
        if Player(otherPlayerSrc) and Player(otherPlayerSrc).state.inv_busy then
            TriggerClientEvent('qb-inventory:client:updateInventory', otherPlayerSrc)
        end
    end
    if toInventory:find('otherplayer-') then
        local otherPlayerSrc = tonumber(toInventory:match('otherplayer%-(.+)'))
         if Player(otherPlayerSrc) and Player(otherPlayerSrc).state.inv_busy then
            TriggerClientEvent('qb-inventory:client:updateInventory', otherPlayerSrc)
        end
    end
end)