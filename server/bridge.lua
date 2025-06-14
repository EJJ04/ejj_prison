Framework = nil

PlayerLoaded, PlayerData = nil, {}

local function InitializeFramework()
    if GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
        Framework = 'esx'

        RegisterNetEvent('esx:playerLoaded', function(xPlayer)
            PlayerData = xPlayer
            PlayerLoaded = true
            local jailTime = lib.callback.await('ejj_prison:getJailTime', false)
            if jailTime and jailTime > 0 then
                currentPrison = lib.callback.await('ejj_prison:getPlayerPrison', false)
                if currentPrison then
                    InitializePrisonSystem(currentPrison)
                end
            end
        end)

        RegisterNetEvent('esx:onPlayerLogout', function()
            table.wipe(PlayerData)
            PlayerLoaded = false
        end)

        AddEventHandler('onResourceStart', function(resourceName)
            if GetCurrentResourceName() ~= resourceName then return end
            PlayerData = GetPlayerData()
            PlayerLoaded = true
            local jailTime = lib.callback.await('ejj_prison:getJailTime', false)
            if jailTime and jailTime > 0 then
                currentPrison = lib.callback.await('ejj_prison:getPlayerPrison', false)
                if currentPrison then
                    InitializePrisonSystem(currentPrison)
                    local remainingTime = jailTime
                    if remainingTime > 0 then
                        SetTimeout(remainingTime * 60 * 1000, function()
                            TriggerServerEvent('ejj_prison:server:releasePlayer')
                        end)
                    end
                end
            end
        end)

    elseif GetResourceState('qbx_core') == 'started' then
        Framework = 'qbx'

        AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
            PlayerData = GetPlayerData()
            PlayerLoaded = true
            local jailTime = lib.callback.await('ejj_prison:getJailTime', false)
            if jailTime and jailTime > 0 then
                currentPrison = lib.callback.await('ejj_prison:getPlayerPrison', false)
                if currentPrison then
                    InitializePrisonSystem(currentPrison)
                end
            end
        end)

        RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
            table.wipe(PlayerData)
            PlayerLoaded = false
        end)

        AddEventHandler('onResourceStart', function(resourceName)
            if GetCurrentResourceName() ~= resourceName then return end
            PlayerData = GetPlayerData()
            PlayerLoaded = true
            local jailTime = lib.callback.await('ejj_prison:getJailTime', false)
            if jailTime and jailTime > 0 then
                currentPrison = lib.callback.await('ejj_prison:getPlayerPrison', false)
                if currentPrison then
                    InitializePrisonSystem(currentPrison)
                    local remainingTime = jailTime
                    if remainingTime > 0 then
                        SetTimeout(remainingTime * 60 * 1000, function()
                            TriggerServerEvent('ejj_prison:server:releasePlayer')
                        end)
                    end
                end
            end
        end)
    elseif GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
        Framework = 'qb'

        AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
            PlayerData = GetPlayerData()
            PlayerLoaded = true
            local jailTime = lib.callback.await('ejj_prison:getJailTime', false)
            if jailTime and jailTime > 0 then
                currentPrison = lib.callback.await('ejj_prison:getPlayerPrison', false)
                if currentPrison then
                    InitializePrisonSystem(currentPrison)
                end
            end
        end)

        RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
            table.wipe(PlayerData)
            PlayerLoaded = false
        end)

        AddEventHandler('onResourceStart', function(resourceName)
            if GetCurrentResourceName() ~= resourceName then return end
            PlayerData = GetPlayerData()
            PlayerLoaded = true
            local jailTime = lib.callback.await('ejj_prison:getJailTime', false)
            if jailTime and jailTime > 0 then
                currentPrison = lib.callback.await('ejj_prison:getPlayerPrison', false)
                if currentPrison then
                    InitializePrisonSystem(currentPrison)
                    local remainingTime = jailTime
                    if remainingTime > 0 then
                        SetTimeout(remainingTime * 60 * 1000, function()
                            TriggerServerEvent('ejj_prison:server:releasePlayer')
                        end)
                    end
                end
            end
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

-- CreatePrisonBlips function is now implemented in main.lua
-- No need to have a wrapper function here since both files are in the same resource
-- and both run on the client side. The function can be accessed directly from main.lua.

InitializeFramework()