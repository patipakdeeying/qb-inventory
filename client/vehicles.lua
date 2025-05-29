-- Functions

local function IsBackEngine(vehModel)
    return BackEngineVehicles[vehModel]
end

local function OpenTrunk(vehicle)
    LoadAnimDict('amb@prop_human_bum_bin@idle_b')
    TaskPlayAnim(PlayerPedId(), 'amb@prop_human_bum_bin@idle_b', 'idle_d', 4.0, 4.0, -1, 50, 0, false, false, false)
    if IsBackEngine(GetEntityModel(vehicle)) then
        SetVehicleDoorOpen(vehicle, 4, false, false)
    else
        SetVehicleDoorOpen(vehicle, 5, false, false)
    end
end

function CloseTrunk()
    local vehicle, distance = QBCore.Functions.GetClosestVehicle()
    if vehicle == 0 or distance > 5 then return end
    LoadAnimDict('amb@prop_human_bum_bin@idle_b')
    TaskPlayAnim(PlayerPedId(), 'amb@prop_human_bum_bin@idle_b', 'exit', 4.0, 4.0, -1, 50, 0, false, false, false)
    if IsBackEngine(GetEntityModel(vehicle)) then
        SetVehicleDoorShut(vehicle, 4, false)
    else
        SetVehicleDoorShut(vehicle, 5, false)
    end
end

-- Callbacks

QBCore.Functions.CreateClientCallback('qb-inventory:client:vehicleCheck', function(cb)
    local ped = PlayerPedId()
    local inVehicle = GetVehiclePedIsIn(ped, false)

    if inVehicle ~= 0 then -- Glovebox
        local plate = GetVehicleNumberPlateText(inVehicle)
        local class = GetVehicleClass(inVehicle)
        local modelHash = GetEntityModel(inVehicle)
        local modelName = GetDisplayNameFromVehicleModel(modelHash)
        local inventory = 'glovebox-' .. plate
        print(string.format("[QB-Inv Client] Glovebox Check: ID=%s, Class=%s, Model=%s", inventory, class, modelName))
        cb(inventory, class, modelName) -- Added modelName
        return
    end

    local vehicle, distance = QBCore.Functions.GetClosestVehicle()
    if vehicle ~= 0 and distance < 5 then -- Trunk
        local pos = GetEntityCoords(ped)
        local dimensionMin, dimensionMax = GetModelDimensions(GetEntityModel(vehicle))
        local trunkpos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, (dimensionMin.y), 0.0)
        if BackEngineVehicles[GetEntityModel(vehicle)] then trunkpos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, (dimensionMax.y), 0.0) end
        
        if #(pos - trunkpos) < 1.5 then
            if GetVehicleDoorLockStatus(vehicle) < 2 then
                OpenTrunk(vehicle) -- Assumes OpenTrunk handles animation/door state
                local class = GetVehicleClass(vehicle)
                local plate = GetVehicleNumberPlateText(vehicle)
                local modelHash = GetEntityModel(vehicle)
                local modelName = GetDisplayNameFromVehicleModel(modelHash)
                local inventory = 'trunk-' .. plate
                print(string.format("[QB-Inv Client] Trunk Check: ID=%s, Class=%s, Model=%s, LockStatus=%s", inventory, class, modelName, GetVehicleDoorLockStatus(vehicle)))
                cb(inventory, class, modelName) -- Added modelName
            else
                QBCore.Functions.Notify(Lang:t('notify.vlocked'), 'error')
                cb(nil) -- Explicitly call back with nil if locked
                return
            end
        else
             cb(nil) -- Not close enough to trunk
             return
        end
    else
        cb(nil) -- No vehicle found or not in one
        return
    end
    cb(nil) -- Default callback if no conditions met
end)
