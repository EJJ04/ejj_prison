Framework = nil

PlayerLoaded, PlayerData = nil, {}

local function InitializeFramework()
    if GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
        Framework = 'esx'

        RegisterNetEvent('esx:playerLoaded', function(xPlayer)
            PlayerData = xPlayer
            PlayerLoaded = true
        end)

        RegisterNetEvent('esx:onPlayerLogout', function()
            table.wipe(PlayerData)
            PlayerLoaded = false
        end)

    elseif GetResourceState('qbx_core') == 'started' then
        Framework = 'qbx'

        AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
            PlayerData = GetPlayerData()
            PlayerLoaded = true
        end)

        RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
            table.wipe(PlayerData)
            PlayerLoaded = false
        end)

    elseif GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
        Framework = 'qb'

        AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
            PlayerData = GetPlayerData()
            PlayerLoaded = true
        end)

        RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
            table.wipe(PlayerData)
            PlayerLoaded = false
        end)
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

function Progress(opts)
    local label = opts.label or 'Processing...'
    local duration = opts.duration or 3000
    local anim = opts.anim
    local finished = false

    if anim and anim.dict and anim.clip and lib and cache and cache.ped then
        lib.playAnim(
            cache.ped,
            anim.dict,
            anim.clip,
            anim.blendIn or 8.0,
            anim.blendOut or 8.0,
            duration,
            anim.flag or 49
        )
    end

    if Framework == 'esx' and ESX and ESX.Progressbar then
        ESX.Progressbar(label, duration, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, function(cancelled)
            finished = not cancelled
        end)
        while not finished do Wait(50) end
    elseif Framework == 'qb' and QBCore and QBCore.Functions and QBCore.Functions.Progressbar then
        QBCore.Functions.Progressbar('ejj_prison_progress', label, duration, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function()
            finished = true
        end, function()
            finished = false
        end)
        while finished == false do Wait(50) end
    elseif Framework == 'qbx' and exports['qbx_core'] and exports['qbx_core'].Progressbar then
        exports['qbx_core']:Progressbar('ejj_prison_progress', label, duration, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function()
            finished = true
        end, function()
            finished = false
        end)
        while finished == false do Wait(50) end
    elseif lib and lib.progressBar then
        finished = lib.progressBar({
            duration = duration,
            label = label,
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true }
        })
    else
        Wait(duration)
        finished = true
    end

    if anim and anim.dict and cache and cache.ped then
        ClearPedTasks(cache.ped)
    end
    return finished
end

InitializeFramework()