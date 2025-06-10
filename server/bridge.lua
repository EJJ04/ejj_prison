Framework = nil

local function InitializeFramework()
    if GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
        Framework = 'esx'
        
        AddEventHandler('esx:playerLoaded', function(playerId, xPlayer, isNew)
            TriggerEvent('ejj_prison:playerLoaded', playerId)
        end)
        
        AddEventHandler('esx:playerDropped', function(playerId)
            TriggerEvent('ejj_prison:playerDropped', playerId)
        end)
        
    elseif GetResourceState('qbx_core') == 'started' then
        Framework = 'qbx'
        
        AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
            TriggerEvent('ejj_prison:playerLoaded', Player.PlayerData.source)
        end)
        
        AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
            TriggerEvent('ejj_prison:playerDropped', src)
        end)
        
    elseif GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
        Framework = 'qb'
        
        AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
            TriggerEvent('ejj_prison:playerLoaded', Player.PlayerData.source)
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

    return nil -- Fallback if no valid identifier is found
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

function AddItem(source, item, count, metadata, slot)
    if Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        xPlayer.addInventoryItem(item, count) 
        return true
    elseif Framework == 'qbx' then
        local success, response = exports.ox_inventory:AddItem(source, item, count, metadata, slot)
        return success
    elseif Framework == 'qb' then
        return exports['qb-inventory']:AddItem(source, item, count, slot or false, metadata or false, 'ejj_prison:addItem')
    else
        -- Add custom framework here
    end

    return false
end

function RemoveItem(source, item, count, metadata, slot)
    if Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        xPlayer.removeInventoryItem(item, count)
        return true
    elseif Framework == 'qbx' then
        local success, response = exports.ox_inventory:RemoveItem(source, item, count, metadata, slot)
        return success
    elseif Framework == 'qb' then
        return exports['qb-inventory']:RemoveItem(source, item, count, slot or false, 'ejj_prison:removeItem')
    else
        -- Add custom framework here
    end

    return false
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
        if xPlayer and xPlayer.getInventory then
            return xPlayer.getInventory()
        end
    elseif Framework == 'qbx' or Framework == 'qb' then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player and Player.PlayerData and Player.PlayerData.items then
            return Player.PlayerData.items
        end
    else
        -- Add custom framework here
    end

    return {}
end

function IsPlayerPolice(source)
    if Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer and xPlayer.job and xPlayer.job.name then
            return xPlayer.job.name == 'police'
        end
    elseif Framework == 'qbx' then
        local Player = exports.qbx_core:GetPlayer(source)
        if Player and Player.PlayerData and Player.PlayerData.job then
            return Player.PlayerData.job.name == 'police'
        end
    elseif Framework == 'qb' then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player and Player.PlayerData and Player.PlayerData.job then
            return Player.PlayerData.job.name == 'police'
        end
    else
        -- Add custom framework here
    end

    return false
end
