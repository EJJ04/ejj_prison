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

local codemInv = 'codem-inventory'
local oxInv = 'ox_inventory'
local qbInv = 'qb-inventory'
local qsInv = 'qs-inventory'
local origenInv = 'origen_inventory'
local ak47Inv = 'ak47_inventory'

local inventorySystem
if GetResourceState(codemInv) == 'started' then
    inventorySystem = 'codem'
elseif GetResourceState(oxInv) == 'started' then
    inventorySystem = 'ox'
elseif GetResourceState(qbInv) == 'started' then
    inventorySystem = 'qb'
elseif GetResourceState(qsInv) == 'started' then
    inventorySystem = 'qs'
elseif GetResourceState(origenInv) == 'started' then
    inventorySystem = 'origen'
elseif GetResourceState(ak47Inv) == 'started' then
    inventorySystem = 'ak47'
end

function AddItem(player, item, count, metadata, slot, source)
    if inventorySystem == 'codem' then
        return exports[codemInv]:AddItem(source, item, count, slot or false, metadata or false)
    elseif inventorySystem == 'ox' then
        return exports[oxInv]:AddItem(source, item, count, metadata or false, slot or false)
    elseif inventorySystem == 'qb' then
        exports[qbInv]:AddItem(source, item, count, slot or false, metadata or false, 'ejj_prison:AddItem')
        TriggerClientEvent('qb-inventory:client:ItemBox', source, QBCore.Shared.Items[item], 'add', count)
        return
    elseif inventorySystem == 'qs' then
        return exports[qsInv]:AddItem(source, item, count, slot or false, metadata or false)
    elseif inventorySystem == 'origen' then
        return exports[origenInv]:addItem(source, item, count, metadata, slot)
    elseif inventorySystem == 'ak47' then
        return exports[ak47Inv]:AddItem(source, item, count, slot, metadata, nil, nil)
    else
        if Framework == 'esx' then
            return player.addInventoryItem(item, count, metadata, slot)
        elseif Framework == 'qb' then
            player.Functions.AddItem(item, count, slot, metadata)
            TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item], 'add', count)
            return
        else
            error("Unsupported framework or inventory state for AddItem.")
        end
    end
end

function RemoveItem(player, item, count, metadata, slot, source)
    if inventorySystem == 'codem' then
        return exports[codemInv]:RemoveItem(source, item, count, slot or false)
    elseif inventorySystem == 'ox' then
        return exports[oxInv]:RemoveItem(source, item, count, metadata or false, slot or false)
    elseif inventorySystem == 'qb' then
        exports[qbInv]:RemoveItem(source, item, count, slot or false, 'ejj_prison:RemoveItem')
        TriggerClientEvent('qb-inventory:client:ItemBox', source, QBCore.Shared.Items[item], 'remove', count)
        return
    elseif inventorySystem == 'qs' then
        return exports[qsInv]:RemoveItem(source, item, count, slot or false, metadata or false)
    elseif inventorySystem == 'origen' then
        return exports[origenInv]:removeItem(source, item, count, metadata, slot)
    elseif inventorySystem == 'ak47' then
        return exports[ak47Inv]:RemoveItem(source, item, count, slot)
    else
        if Framework == 'esx' then
            return player.removeInventoryItem(item, count, metadata or false, slot or false)
        elseif Framework == 'qb' then
            player.Functions.RemoveItem(item, count, slot, metadata or false)
            TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item], "remove", count)
            return
        else
            error("RemoveItem function is not supported in the current framework.")
        end
    end
end

function GetItemCount(source, item)
    local xPlayer
    if Framework == 'esx' then
        xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return 0 end
    elseif Framework == 'qb' then
        xPlayer = QBCore.Functions.GetPlayer(source)
        if not xPlayer then return 0 end
    end

    if inventorySystem == 'codem' then
        return exports[codemInv]:GetItemsTotalAmount(source, item)
    elseif inventorySystem == 'ox' then
        return exports[oxInv]:Search(source, 'count', item)
    elseif inventorySystem == 'qb' then
        return exports[qbInv]:GetItemCount(source, item) or 0
    elseif inventorySystem == 'qs' then
        local itemData = exports[qsInv]:GetItemByName(source, item)
        return itemData and (itemData.amount or itemData.count) or 0
    elseif inventorySystem == 'origen' then
        return exports[origenInv]:getItemCount(source, item, false, false) or 0    
    elseif inventorySystem == 'ak47' then
        return exports[ak47Inv]:Search(source, 'count', item) or 0
    else
        if Framework == 'esx' then
            local itemData = xPlayer.getInventoryItem(item)
            return itemData and (itemData.count or itemData.amount) or 0
        elseif Framework == 'qb' then
            local itemData = xPlayer.Functions.GetItemByName(item)
            return itemData and (itemData.amount or itemData.count) or 0
        else
            return 0
        end
    end
end

function GetInventoryItems(source)    
    if inventorySystem == 'ak47' then
        local items = {}

        local data = exports[ak47Inv]:GetInventoryItems(source)
        if data then
            for slot, item in pairs(data) do
                items[#items + 1] = {
                    name = item.name,
                    label = item.label or item.name,
                    count = item.amount,
                    weight = item.weight,
                    metadata = item.info,
                    slot = slot
                }
            end
        end
        return items
    end
    
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