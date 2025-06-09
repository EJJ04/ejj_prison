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
    if Framework == 'esx' then
        return ESX.GetPlayerFromId(source).identifier
    elseif Framework == 'qbx' then
        return QBCore.Functions.GetPlayerData(source).PlayerData.citizenid
    elseif Framework == 'qb' then
        return QBCore.Functions.GetPlayerData(source).PlayerData.citizenid
    else
        -- Add custom framework here
    end
end

function GetPlayer(source)
    if Framework == 'esx' then
        return ESX.GetPlayerFromId(source)
    elseif Framework == 'qbx' then
        return QBCore.Functions.GetPlayer(source)
    elseif Framework == 'qb' then
        return QBCore.Functions.GetPlayer(source)
    else
        -- Add custom framework here
    end
end

function AddItem(source, item, count, metadata, slot)
    if Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        xPlayer.addInventoryItem(item, count, metadata, slot)
        return true
    elseif Framework == 'qbx' then
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return false end
        return Player.Functions.AddItem(item, count, slot, metadata)
    elseif Framework == 'qb' then
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return false end
        return Player.Functions.AddItem(item, count, slot, metadata)
    else
        -- Add custom framework here
    end
end

function RemoveItem(source, item, count, metadata, slot)
    if Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        xPlayer.removeInventoryItem(item, count, metadata, slot)
        return true
    elseif Framework == 'qbx' then
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return false end
        return Player.Functions.RemoveItem(item, count, slot, metadata)
    elseif Framework == 'qb' then
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return false end
        return Player.Functions.RemoveItem(item, count, slot, metadata)
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
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return 0 end
        local inventoryItem = Player.Functions.GetItemByName(item)
        return inventoryItem and inventoryItem.count or 0
    elseif Framework == 'qb' then
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return 0 end
        local inventoryItem = Player.Functions.GetItemByName(item)
        return inventoryItem and inventoryItem.count or 0
    else
        -- Add custom framework here
    end
end

function GetInventoryItems(source)
    if Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return {} end
        return xPlayer.getInventory()
    elseif Framework == 'qbx' then
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return {} end
        return Player.PlayerData.items
    elseif Framework == 'qb' then  
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return {} end
        return Player.PlayerData.items
    else
        -- Add custom framework here
    end
end

function IsPlayerPolice(source)
    if Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        return xPlayer.job.name == 'police'
    elseif Framework == 'qbx' then
        local PlayerData = QBCore.Functions.GetPlayerData()
        return PlayerData.job.name == 'police'
    elseif Framework == 'qb' then
        local PlayerData = QBCore.Functions.GetPlayerData()
        return PlayerData.job.name == 'police'
    else
        -- Add custom framework here
    end
end