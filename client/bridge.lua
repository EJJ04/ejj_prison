Framework = nil

PlayerLoaded, PlayerData = nil, {}

local function InitializeFramework()
    if GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
        Framework = 'esx'

        RegisterNetEvent('esx:playerLoaded', function(xPlayer)
            PlayerData = xPlayer
            PlayerLoaded = true
            TriggerServerEvent('ejj_prison:checkOfflineTime')
        end)

        RegisterNetEvent('esx:onPlayerLogout', function()
            table.wipe(PlayerData)
            PlayerLoaded = false
        end)

        AddEventHandler('onResourceStart', function(resourceName)
            if GetCurrentResourceName() ~= resourceName then return end
            PlayerData = GetPlayerData()
            PlayerLoaded = true
            TriggerServerEvent('ejj_prison:checkOfflineTime')
        end)

    elseif GetResourceState('qbx_core') == 'started' then
        Framework = 'qbx'

        AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
            PlayerData = GetPlayerData()
            PlayerLoaded = true
            TriggerServerEvent('ejj_prison:checkOfflineTime')
        end)

        RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
            table.wipe(PlayerData)
            PlayerLoaded = false
        end)

        AddEventHandler('onResourceStart', function(resourceName)
            if GetCurrentResourceName() ~= resourceName then return end
            PlayerData = GetPlayerData()
            PlayerLoaded = true
            TriggerServerEvent('ejj_prison:checkOfflineTime')
        end)
    elseif GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
        Framework = 'qb'

        AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
            PlayerData = GetPlayerData()
            PlayerLoaded = true
            TriggerServerEvent('ejj_prison:checkOfflineTime')
        end)

        RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
            table.wipe(PlayerData)
            PlayerLoaded = false
        end)

        AddEventHandler('onResourceStart', function(resourceName)
            if GetCurrentResourceName() ~= resourceName then return end
            PlayerData = GetPlayerData()
            PlayerLoaded = true
            TriggerServerEvent('ejj_prison:checkOfflineTime')
        end)
    else
        -- Add custom framework here
    end
end

function GetPlayerData()
    if Framework == 'esx' then
        return ESX.GetPlayerData()
    elseif Framework == 'qb' then
        return QBCore.Functions.GetPlayerData()
    elseif Framework == 'qbx' then
        return exports.qbx_core:GetPlayerData()
    else
        -- Add custom framework here
    end
end

InitializeFramework()