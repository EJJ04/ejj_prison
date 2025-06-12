Framework = nil

local function InitializeFramework()
    if GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
        Framework = 'esx'
        
        AddEventHandler('esx:playerLoaded', function(playerId, xPlayer, isNew)
            local identifier = GetIdentifier(playerId)
            if identifier then
                local result = MySQL.query.await('SELECT time, prison, UNIX_TIMESTAMP(date) as start_time FROM ejj_prison WHERE identifier = ?', {identifier})
                if result and result[1] and result[1].time > 0 then
                    local jailTime = result[1].time
                    local prisonId = result[1].prison
                    local startTime = result[1].start_time
                    
                    if Config.OfflineTimeServing then
                        local currentTime = os.time()
                        local elapsedMinutes = math.floor((currentTime - startTime) / 60)
                        local remainingTime = math.max(0, jailTime - elapsedMinutes)
                        
                        if remainingTime > 0 then
                            MySQL.update('UPDATE ejj_prison SET time = ? WHERE identifier = ?', {remainingTime, identifier})
                            jailTime = remainingTime
                        else
                            jailTime = 0
                        end
                    end
                    
                    if jailTime > 0 then
                        TriggerEvent('ejj_prison:playerLoaded', playerId)
                    else
                        MySQL.update('UPDATE ejj_prison SET time = 0, prison = NULL WHERE identifier = ?', {identifier})
                    end
                end
            end
        end)
        
        AddEventHandler('esx:playerDropped', function(playerId)
            TriggerEvent('ejj_prison:playerDropped', playerId)
        end)
        
    elseif GetResourceState('qbx_core') == 'started' then
        Framework = 'qbx'
        
        AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
            local identifier = GetIdentifier(Player.PlayerData.source)
            if identifier then
                local result = MySQL.query.await('SELECT time, prison, UNIX_TIMESTAMP(date) as start_time FROM ejj_prison WHERE identifier = ?', {identifier})
                if result and result[1] and result[1].time > 0 then
                    local jailTime = result[1].time
                    local prisonId = result[1].prison
                    local startTime = result[1].start_time
                    
                    if Config.OfflineTimeServing then
                        local currentTime = os.time()
                        local elapsedMinutes = math.floor((currentTime - startTime) / 60)
                        local remainingTime = math.max(0, jailTime - elapsedMinutes)
                        
                        if remainingTime > 0 then
                            MySQL.update('UPDATE ejj_prison SET time = ? WHERE identifier = ?', {remainingTime, identifier})
                            jailTime = remainingTime
                        else
                            jailTime = 0
                        end
                    end
                    
                    if jailTime > 0 then
                        TriggerEvent('ejj_prison:playerLoaded', Player.PlayerData.source)
                    else
                        MySQL.update('UPDATE ejj_prison SET time = 0, prison = NULL WHERE identifier = ?', {identifier})
                    end
                end
            end
        end)
        
        AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
            TriggerEvent('ejj_prison:playerDropped', src)
        end)
        
    elseif GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
        Framework = 'qb'
        
        AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
            local identifier = GetIdentifier(Player.PlayerData.source)
            if identifier then
                local result = MySQL.query.await('SELECT time, prison, UNIX_TIMESTAMP(date) as start_time FROM ejj_prison WHERE identifier = ?', {identifier})
                if result and result[1] and result[1].time > 0 then
                    local jailTime = result[1].time
                    local prisonId = result[1].prison
                    local startTime = result[1].start_time
                    
                    if Config.OfflineTimeServing then
                        local currentTime = os.time()
                        local elapsedMinutes = math.floor((currentTime - startTime) / 60)
                        local remainingTime = math.max(0, jailTime - elapsedMinutes)
                        
                        if remainingTime > 0 then
                            MySQL.update('UPDATE ejj_prison SET time = ? WHERE identifier = ?', {remainingTime, identifier})
                            jailTime = remainingTime
                        else
                            jailTime = 0
                        end
                    end
                    
                    if jailTime > 0 then
                        TriggerEvent('ejj_prison:playerLoaded', Player.PlayerData.source)
                    else
                        MySQL.update('UPDATE ejj_prison SET time = 0, prison = NULL WHERE identifier = ?', {identifier})
                    end
                end
            end
        end)
        
        AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
            TriggerEvent('ejj_prison:playerDropped', src)
        end)
    end
end

InitializeFramework()

function GetIdentifier(source)
    if not Framework then
        print("Framework is not defined.")
        return nil
    end

    if Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            return xPlayer.getIdentifier()
        end
    elseif Framework == 'qbx' then
        local Player = exports.qbx_core:GetPlayer(source)
        if Player and Player.PlayerData then
            return Player.PlayerData.citizenid
        end
    elseif Framework == 'qb' then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player and Player.PlayerData then
            return Player.PlayerData.citizenid
        end
    else
        -- Add custom framework here
    end

    return nil 
end

function GetPlayer(source)
    if not Framework then
        print("Framework is not defined.")
        return nil
    end

    if Framework == 'esx' then
        return ESX.GetPlayerFromId(source)
    elseif Framework == 'qbx' then
        return exports.qbx_core:GetPlayer(source)
    elseif Framework == 'qb' then
        return QBCore.Functions.GetPlayer(source)
    else
        -- Add custom framework here
        return nil
    end
end

function AddItem(source, name, count, metadata, slot)
    if Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            xPlayer.addInventoryItem(name, count)
        end
    elseif Framework == 'qbx' then
        exports.ox_inventory:AddItem(source, name, count, metadata)
    elseif Framework == 'qb' then
        local src = tonumber(source)
        local xPlayer = QBCore.Functions.GetPlayer(src)
        if xPlayer then
            xPlayer.Functions.AddItem(name, count, nil, metadata)
        end
    else
        -- Add custom framework here
    end
end

function RemoveItem(source, name, count, metadata, slot)
    if Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            xPlayer.removeInventoryItem(name, count)
        end
    elseif Framework == 'qbx' then
        exports.ox_inventory:RemoveItem(source, name, count, metadata, slot)
    elseif Framework == 'qb' then
        local src = tonumber(source)
        local xPlayer = QBCore.Functions.GetPlayer(src)
        if xPlayer then
            if slot then
                xPlayer.Functions.RemoveItem(name, count, slot)
            else
                xPlayer.Functions.RemoveItem(name, count)
            end
        end
    else
        -- Add custom framework here
    end
end

function GetItemCount(source, item)
    if Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return 0 end
        local inventoryItem = xPlayer.getInventoryItem(item)
        return inventoryItem and inventoryItem.count or 0
    elseif Framework == 'qbx' then
        return exports.ox_inventory:GetItemCount(source, item)
    elseif Framework == 'qb' then
        return exports['qb-inventory']:GetItemCount(source, item) or 0
    else
        -- Add custom framework here
    end

    return 0
end

function GetInventoryItems(source)
    if Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        local items = {}
        if xPlayer and xPlayer.getInventory then
            local data = xPlayer.getInventory()
            for i=1, #data do 
                local item = data[i]
                items[#items + 1] = {
                    name = item.name,
                    label = item.label,
                    count = item.count,
                    weight = item.weight,
                    metadata = item.metadata or item.info,
                    slot = item.slot or i
                }
            end
        end
        return items
    elseif Framework == 'qbx' then
        local items = {}
        local data = exports.ox_inventory:GetInventoryItems(source)
        for slot, item in pairs(data) do 
            items[#items + 1] = {
                name = item.name,
                label = item.label,
                count = item.count,
                weight = item.weight,
                metadata = item.metadata,
                slot = slot
            }
        end
        return items
    elseif Framework == 'qb' then
        local source = tonumber(source)
        local xPlayer = QBCore.Functions.GetPlayer(source)
        local items = {}
        if xPlayer and xPlayer.PlayerData and xPlayer.PlayerData.items then
            local data = xPlayer.PlayerData.items
            for slot, item in pairs(data) do 
                items[#items + 1] = {
                    name = item.name,
                    label = item.label,
                    count = item.amount,
                    weight = item.weight,
                    metadata = item.info,
                    slot = slot
                }
            end
        end
        return items
    else
        -- Add custom framework here
    end

    return {}
end

function HasPermission(source, action)
    if source == 0 then return true end 
    
    local config = Config.Permissions[action]
    if not config then return false end
    
    if not config.requirePolice then return true end
    
    for _, group in ipairs(config.allowedGroups) do
        if IsPlayerAceAllowed(source, 'group.' .. group) then
            return true
        end
    end
    
    if Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer and xPlayer.job and xPlayer.job.name then
            for _, allowedJob in ipairs(config.allowedJobs) do
                if xPlayer.job.name == allowedJob then
                    return true
                end
            end
        end
    elseif Framework == 'qbx' then
        local Player = exports.qbx_core:GetPlayer(source)
        if Player and Player.PlayerData and Player.PlayerData.job then
            for _, allowedJob in ipairs(config.allowedJobs) do
                if Player.PlayerData.job.name == allowedJob then
                    return true
                end
            end
        end
    elseif Framework == 'qb' then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player and Player.PlayerData and Player.PlayerData.job then
            for _, allowedJob in ipairs(config.allowedJobs) do
                if Player.PlayerData.job.name == allowedJob then
                    return true
                end
            end
        end
    end
    
    return false
end