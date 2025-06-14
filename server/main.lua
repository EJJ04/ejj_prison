lib.locale()

local jailedPlayers = {} 
local jailStartTimes = {} 
local escapedPlayers = {} 
local alarmActive = false 
local playersInAlarmRange = {} 
local tunnelExists = false 
local tunnelResetTimer = nil 
local prisonTimer = nil

local function GetPlayerPrison(source)
    local identifier = GetIdentifier(source)
    if not identifier then return nil end
    
    local result = MySQL.scalar.await('SELECT prison FROM ejj_prison WHERE identifier = ? AND time > 0', {
        identifier
    })
    
    return result
end

local function GetPrisonConfig(prisonId)
    if not prisonId or not Config.Prisons[prisonId] or not Config.Prisons[prisonId].enabled then
        return nil
    end
    return Config.Prisons[prisonId]
end

local function IsValidPrison(prisonId)
    return Config.Prisons[prisonId] and Config.Prisons[prisonId].enabled
end

function CheckJailTime(source, suppressUnjail)
    local identifier = GetIdentifier(source)
    if not identifier then return 0 end
    
    local result = MySQL.query.await('SELECT time, prison FROM ejj_prison WHERE identifier = ?', {identifier})
    if result and result[1] then
        local jailTime = result[1].time
        local prisonId = result[1].prison
        
        if jailTime > 0 then
            local prisonConfig = Config.Prisons[prisonId]
            if not prisonConfig then
                return 0
            end
            
            if jailTime == 0 and not suppressUnjail then
                MySQL.update('UPDATE ejj_prison SET time = 0, prison = NULL WHERE identifier = ?', {identifier})
                TriggerClientEvent('ejj_prison:client:setJailStatus', source, false)
                TriggerClientEvent('ejj_prison:client:setJailTime', source, 0)
                TriggerClientEvent('ejj_prison:client:setPrisonId', source, nil)
                TriggerClientEvent('ejj_prison:restoreOriginalClothes', source)
                TriggerClientEvent('ejj_prison:client:cleanupPrison', source)
            else
                TriggerClientEvent('ejj_prison:client:setJailTime', source, jailTime)
            end
            
            return jailTime
        end
    end
    return 0
end

local keptItemsLookup = {}
for _, itemName in pairs(Config.KeepItemsOnJail) do
    keptItemsLookup[itemName] = true
end

local function InventoryHandler(source)
    local removedItems = {}
    local data = GetInventoryItems(source)
    for i=1, #data do 
        local keep = false
        for j=1, #Config.KeepItemsOnJail do 
            if data[i].name == Config.KeepItemsOnJail[j] then
                keep = true
                break
            end
        end
        if not keep then
            removedItems[#removedItems + 1] = data[i]
            RemoveItem(source, data[i].name, data[i].count, data[i].metadata, data[i].slot)
        end
    end
    return removedItems
end

function SetJailTime(identifier, time, source, prisonId)
    if time > 0 then
        if not prisonId or not IsValidPrison(prisonId) then
            if source then
                TriggerClientEvent('ejj_prison:notify', source, locale('server_invalid_prison'), 'error')
            end
            return false
        end
        local startTime = os.time()
        local removedInventory = {}
        if source then
            removedInventory = InventoryHandler(source)
        end

        MySQL.query.await('INSERT INTO ejj_prison (identifier, time, date, inventory, prison) VALUES (?, ?, NOW(), ?, ?) ON DUPLICATE KEY UPDATE time = ?, date = NOW(), inventory = ?, prison = ?', {
            identifier, time, json.encode(removedInventory), prisonId, time, json.encode(removedInventory), prisonId
        })
        jailedPlayers[identifier] = { time = time, startTime = startTime, prisonId = prisonId }

        if source then
            local prisonConfig = Config.Prisons[prisonId]
            if prisonConfig and prisonConfig.locations and prisonConfig.locations.jail then
                local targetPed = GetPlayerPed(source)
                if targetPed then
                    SetEntityCoords(targetPed, prisonConfig.locations.jail.x, prisonConfig.locations.jail.y, prisonConfig.locations.jail.z)
                    SetEntityHeading(targetPed, prisonConfig.locations.jail.w or 0.0)
                    TriggerClientEvent('ejj_prison:client:setJailStatus', source, true)
                    TriggerClientEvent('ejj_prison:client:setJailTime', source, time)
                    TriggerClientEvent('ejj_prison:client:setPrisonId', source, prisonId)
                    TriggerClientEvent('ejj_prison:changeToPrisonClothes', source)
                    TriggerClientEvent('ejj_prison:client:resetJobCooldowns', source)
                end
            end
        end

        SetTimeout(time * 60 * 1000, function()
            local currentTime = CheckJailTime(source, true)
            if currentTime and currentTime > 0 then
                SetJailTime(identifier, 0, source, prisonId)
                if source then
                    TriggerClientEvent('ejj_prison:notify', source, locale('server_released_automatic'), 'success')
                end
            end
        end)
    else
        local result = MySQL.query.await('SELECT inventory FROM ejj_prison WHERE identifier = ?', {
            identifier
        })
        if source and result and result[1] and result[1].inventory then
            local inventory = json.decode(result[1].inventory)
            if inventory then
                for _, item in pairs(inventory) do
                    if item and item.name and item.count and item.count > 0 then
                        AddItem(source, item.name, item.count, item.metadata, item.slot)
                    end
                end
            end
        end

        if source and prisonId then
            local prisonConfig = Config.Prisons[prisonId]
            if prisonConfig and prisonConfig.locations and prisonConfig.locations.release then
                local targetPed = GetPlayerPed(source)
                if targetPed then
                    SetEntityCoords(targetPed, prisonConfig.locations.release.x, prisonConfig.locations.release.y, prisonConfig.locations.release.z)
                    SetEntityHeading(targetPed, prisonConfig.locations.release.w or 0.0)
                end
            end
        end

        if source then
            TriggerClientEvent('ejj_prison:client:cleanupPrison', source)
            TriggerClientEvent('ejj_prison:client:setJailStatus', source, false)
            TriggerClientEvent('ejj_prison:client:setJailTime', source, 0)
            TriggerClientEvent('ejj_prison:client:setPrisonId', source, nil)
            TriggerClientEvent('ejj_prison:restoreOriginalClothes', source)
        end

        MySQL.query.await('DELETE FROM ejj_prison WHERE identifier = ?', {
            identifier
        })
        jailedPlayers[identifier] = nil
    end
end

function GetCurrentJailTime(identifier)
    local jailData = jailedPlayers[identifier]
    if not jailData or type(jailData) ~= 'table' then
        return 0
    end
    local remainingTime = jailData.time - math.floor((os.time() - jailData.startTime) / 60)
    return math.max(0, remainingTime)
end

function RestorePlayerJail(playerId, prisonId)
    local identifier = GetIdentifier(playerId)
    if not identifier then return end
    
    local jailTime = CheckJailTime(playerId)
    if jailTime and jailTime > 0 then
        local prisonConfig = Config.Prisons[prisonId]
        if prisonConfig and prisonConfig.locations and prisonConfig.locations.jail then
            local targetPed = GetPlayerPed(playerId)
            if targetPed then
                SetEntityCoords(targetPed, prisonConfig.locations.jail.x, prisonConfig.locations.jail.y, prisonConfig.locations.jail.z)
                SetEntityHeading(targetPed, prisonConfig.locations.jail.w or 0.0)
            end
        end
        TriggerClientEvent('ejj_prison:client:setJailStatus', playerId, true)
        TriggerClientEvent('ejj_prison:client:setJailTime', playerId, jailTime)
        TriggerClientEvent('ejj_prison:client:setPrisonId', playerId, prisonId)
        TriggerClientEvent('ejj_prison:changeToPrisonClothes', playerId)
    end
end

local function StartPrisonTimer()
    if prisonTimer then return end
    
    prisonTimer = CreateThread(function()
        while true do
            Wait(60000) 
            
            for _, playerId in ipairs(GetPlayers()) do
                local source = tonumber(playerId)
                if source then
                    local jailTime = CheckJailTime(source)
                    if jailTime <= 0 then
                        -- Player's time is up, they will be automatically released by CheckJailTime
                        -- No need to do anything here as CheckJailTime handles the release
                    end
                end
            end
        end
    end)
end

local function StopPrisonTimer()
    if prisonTimer then
        prisonTimer = nil
    end
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        StartPrisonTimer()
        
        local players = GetPlayers()
        for _, playerId in ipairs(players) do
            local identifier = GetIdentifier(playerId)
            if identifier then
                local jailTime = CheckJailTime(playerId)
                if jailTime and jailTime > 0 then
                    local prisonId = GetPlayerPrison(playerId)
                    RestorePlayerJail(playerId, prisonId)
                end
            end
        end

        local result = MySQL.query.await('SELECT identifier, time, UNIX_TIMESTAMP(date) as start_time, prison FROM ejj_prison')
        if result then
            for _, row in ipairs(result) do
                jailedPlayers[row.identifier] = { time = row.time, startTime = row.start_time, prisonId = row.prison }
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        StopPrisonTimer()
    end
end)

AddEventHandler('ejj_prison:playerLoaded', function(source)
    Wait(5000)
    RestorePlayerJail(source)
    
    TriggerClientEvent('ejj_prison:syncTunnelState', source, tunnelExists)
end)

lib.callback.register('ejj_prison:getJailTime', function(source)
    local identifier = GetIdentifier(source)
    if not identifier then return 0 end
    
    local result = MySQL.query.await('SELECT time, date FROM ejj_prison WHERE identifier = ?', {identifier})
    if result and result[1] and result[1].time > 0 then
        local jailTime = result[1].time
        local startDate = result[1].date
        local currentTime = os.time()
        local startTime = os.time(os.date("!*t", startDate))
        local elapsedMinutes = math.floor((currentTime - startTime) / 60)
        local remainingTime = math.max(0, jailTime - elapsedMinutes)
        
        if remainingTime > 0 then
            MySQL.update('UPDATE ejj_prison SET time = ? WHERE identifier = ?', {remainingTime, identifier})
        else
            MySQL.update('DELETE FROM ejj_prison WHERE identifier = ?', {identifier})
        end
        
        return remainingTime
    end
    return 0
end)

lib.callback.register('ejj_prison:getPlayerInventory', function(source)
    return GetInventoryItems(source)
end)

lib.callback.register('ejj_prison:hasItem', function(source, itemName)
    local itemCount = GetItemCount(source, itemName)
    return itemCount > 0
end)

function TriggerPrisonAlarm(prisonId)
    local prisonConfig = GetPrisonConfig(prisonId)
    
    if not prisonConfig or not prisonConfig.escape.alarm.enabled or alarmActive then
        return
    end
    
    alarmActive = true
    playersInAlarmRange = {}
    
    CreateThread(function()
        local startTime = GetGameTimer()
        local endTime = startTime + prisonConfig.escape.alarm.duration
        
        while alarmActive and GetGameTimer() < endTime do
            local players = GetPlayers()
            local currentNearbyPlayers = {}
            
            for _, playerId in ipairs(players) do
                local playerSource = tonumber(playerId)
                if playerSource then
                    local playerPed = GetPlayerPed(playerSource)
                    if playerPed and playerPed ~= 0 then
                        local playerCoords = GetEntityCoords(playerPed)
                        local distance = #(vector3(playerCoords.x, playerCoords.y, playerCoords.z) - prisonConfig.escape.alarm.center)
                        
                        if distance <= prisonConfig.escape.alarm.maxDistance then
                            currentNearbyPlayers[playerSource] = true
                            
                            if not playersInAlarmRange[playerSource] then
                                TriggerClientEvent('ejj_prison:startAlarm', playerSource, prisonId)
                                playersInAlarmRange[playerSource] = true
                            end
                        end
                    end
                end
            end
            
            for playerId, _ in pairs(playersInAlarmRange) do
                if not currentNearbyPlayers[playerId] then
                    TriggerClientEvent('ejj_prison:stopAlarm', playerId)
                    playersInAlarmRange[playerId] = nil
                end
            end
            
            Wait(1000)
        end
        
        StopPrisonAlarm()
    end)
end

function StopPrisonAlarm()
    if not alarmActive then
        return
    end
    
    alarmActive = false
    
    for playerId, _ in pairs(playersInAlarmRange) do
        TriggerClientEvent('ejj_prison:stopAlarm', playerId)
    end
    
    playersInAlarmRange = {}
end

function ResetEscapeTunnel()
    if not tunnelExists then
        return
    end
    
    tunnelExists = false
    
    if tunnelResetTimer then
        tunnelResetTimer = nil
    end
    
    TriggerClientEvent('ejj_prison:removeTunnelRock', -1)
end

lib.addCommand('jail', {
    help = locale('jail_command_help'),
    restricted = 'group.police',
    params = {
        {
            name = 'id',
            type = 'number',
            help = locale('jail_command_id'),
            optional = false
        },
        {
            name = 'time',
            type = 'number',
            help = locale('jail_command_time'),
            optional = false
        },
        {
            name = 'prison',
            type = 'string',
            help = locale('jail_command_prison'),
            optional = true
        }
    }
}, function(source, args, raw)
    if not HasPermission(source, 'jail') then
        TriggerClientEvent('ejj_prison:notify', source, locale('no_permission_jail'), 'error')
        return
    end

    local targetId = args.id
    local duration = args.time
    local prisonId = args.prison or 'bolingbroke'
    
    local targetPlayer = GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('ejj_prison:notify', source, locale('player_not_found'), 'error')
        return
    end
    
    local targetName = GetPlayerName(targetId)
    local officerName = source == 0 and "Console" or GetPlayerName(source)
    local targetIdentifier = GetIdentifier(targetId)
    
    if not targetIdentifier then
        TriggerClientEvent('ejj_prison:notify', source, locale('player_not_found'), 'error')
        return
    end
    
    LogJail(officerName, targetName, duration)
    SetJailTime(targetIdentifier, duration, targetId, prisonId)
    TriggerClientEvent('ejj_prison:notify', source, locale('player_jailed', targetName, duration), 'success')
end)

lib.addCommand('unjail', {
    help = locale('unjail_command_help'),
    restricted = 'group.police',
    params = {
        {
            name = 'id',
            type = 'number',
            help = locale('unjail_command_id'),
            optional = false
        }
    }
}, function(source, args, raw)
    if not HasPermission(source, 'unjail') then
        TriggerClientEvent('ejj_prison:notify', source, locale('no_permission_unjail'), 'error')
        return
    end

    local targetId = args.id
    
    local targetPlayer = GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('ejj_prison:notify', source, locale('player_not_found'), 'error')
        return
    end
    
    local targetName = GetPlayerName(targetId)
    local officerName = source == 0 and "Console" or GetPlayerName(source)
    local targetIdentifier = GetIdentifier(targetId)
    
    if not targetIdentifier then
        TriggerClientEvent('ejj_prison:notify', source, locale('player_not_found'), 'error')
        return
    end
    
    local result = MySQL.query.await('SELECT time, prison FROM ejj_prison WHERE identifier = ?', {targetIdentifier})
    if not result or not result[1] or result[1].time <= 0 then
        TriggerClientEvent('ejj_prison:notify', source, locale('player_not_jailed', targetName), 'error')
        return
    end
    
    local prisonId = result[1].prison or 'bolingbroke'
    
    LogUnjail(officerName, targetName, true)
    
    SetJailTime(targetIdentifier, 0, targetId, prisonId)
    TriggerClientEvent('ejj_prison:notify', source, locale('player_unjailed', targetName), 'success')
end)

lib.addCommand('jailstatus', {
    help = locale('jailstatus_command_help'),
    restricted = 'group.police',
    params = {
        {
            name = 'id',
            type = 'number',
            help = locale('jail_command_id'),
            optional = true
        }
    }
}, function(source, args, raw)
    if not HasPermission(source, 'check') then
        TriggerClientEvent('ejj_prison:notify', source, locale('no_permission_check'), 'error')
        return
    end
    
    local targetId = args.id or source
    local targetPlayer = GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('ejj_prison:notify', source, locale('player_not_found'), 'error')
        return
    end
    
    local identifier = GetIdentifier(targetId)
    if not identifier then
        TriggerClientEvent('ejj_prison:notify', source, locale('player_not_found'), 'error')
        return
    end
    
    local result = MySQL.query.await('SELECT time, prison FROM ejj_prison WHERE identifier = ?', {identifier})
    if result and result[1] and result[1].time > 0 then
        TriggerClientEvent('ejj_prison:notify', source, locale('player_jail_time', GetPlayerName(targetId), result[1].time), 'info')
    else
        TriggerClientEvent('ejj_prison:notify', source, locale('player_not_jailed', GetPlayerName(targetId)), 'info')
    end
end)

lib.addCommand('resettunnel', {
    help = locale('help_reset_tunnel'),
    restricted = Config.Permissions.admin
}, function(source, args)
    if tunnelExists then
        ResetEscapeTunnel()
        TriggerClientEvent('ejj_prison:notify', source, locale('tunnel_reset_success'), 'success')
    else
        TriggerClientEvent('ejj_prison:notify', source, locale('no_tunnel_to_reset'), 'info')
    end
end)

RegisterNetEvent('ejj_prison:completeJob', function(jobType, location)
    local source = source
    local xPlayer = GetPlayer(source)
    if not xPlayer then return end
    
    local identifier = GetIdentifier(source)
    if not identifier then return end
    
    local result = MySQL.query.await('SELECT time, prison FROM ejj_prison WHERE identifier = ?', {identifier})
    if not result or not result[1] or result[1].time <= 0 then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_not_in_jail'), 'error')
        return
    end
    
    local jailData = {
        time = result[1].time,
        prisonId = result[1].prison
    }
    
    local rewardTime = 0
    if jobType == 'electrician' and type(location) == 'number' then
        rewardTime = Config.JobRewards.electrician[location] or 0
    elseif jobType == 'training' and type(location) == 'string' then
        rewardTime = Config.JobRewards.training[location] or 0
    else
        rewardTime = Config.JobRewards[jobType] or 0
    end
    
    if rewardTime > 0 then
        local newTime = math.max(0, jailData.time - rewardTime)
        
        MySQL.update('UPDATE ejj_prison SET time = ? WHERE identifier = ?', {newTime, identifier})
        
        TriggerClientEvent('ejj_prison:client:setJailTime', source, newTime)
        
        if newTime == 0 then
            local prisonConfig = Config.Prisons[jailData.prisonId]
            if prisonConfig and prisonConfig.locations and prisonConfig.locations.release then
                SetEntityCoords(GetPlayerPed(source), 
                    prisonConfig.locations.release.x, 
                    prisonConfig.locations.release.y, 
                    prisonConfig.locations.release.z)
                SetEntityHeading(GetPlayerPed(source), prisonConfig.locations.release.w or 0.0)
            end
            
            TriggerClientEvent('ejj_prison:client:setJailStatus', source, false)
            TriggerClientEvent('ejj_prison:client:setPrisonId', source, nil)
            TriggerClientEvent('ejj_prison:restoreOriginalClothes', source)
            TriggerClientEvent('ejj_prison:client:cleanupPrison', source)
            TriggerClientEvent('ejj_prison:notify', source, locale('job_completed_released'), 'success')
        else
            TriggerClientEvent('ejj_prison:notify', source, locale('job_completed_time_reduced', rewardTime, newTime), 'success')
        end
        
        local playerName = GetPlayerName(source)
        LogJobCompletion(playerName, jobType, rewardTime)
    end
end)

AddEventHandler('ejj_prison:playerDropped', function(source)
    local xPlayer = GetPlayer(source)
    if not xPlayer then return end
    local identifier = GetIdentifier(source)
    local currentJailTime = GetCurrentJailTime(identifier)
    if currentJailTime >= 0 and jailedPlayers[identifier] then
        if currentJailTime > 0 then
            MySQL.query.await('INSERT INTO ejj_prison (identifier, time, date) VALUES (?, ?, NOW()) ON DUPLICATE KEY UPDATE time = ?, date = NOW()', {
                identifier, currentJailTime, currentJailTime
            })
        else
            MySQL.query.await('DELETE FROM ejj_prison WHERE identifier = ?', {
                identifier
            })
        end
        jailedPlayers[identifier] = nil
    end
end)

MySQL.execute([[
    CREATE TABLE IF NOT EXISTS `ejj_prison` (
        `identifier` varchar(50) NOT NULL,
        `time` int(11) NOT NULL,
        `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `inventory` json DEFAULT NULL,
        `prison` varchar(50) DEFAULT 'bolingbroke',
        PRIMARY KEY (`identifier`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]])

RegisterNetEvent('ejj_prison:server:tunnelActivity', function(action)
    local src = source
    local playerName = GetPlayerName(src)
    LogTunnelActivity(playerName, action)
end)

RegisterNetEvent('ejj_prison:playerEscaped', function()
    local src = source
    local playerName = GetPlayerName(src)
    LogEscapeAttempt(playerName, true, "Tunnel")
end)

function ReduceJailTime(identifier, timeToReduce, source, prisonId)
    if not identifier then return end
    
    local currentTime = CheckJailTime(source)
    if not currentTime or currentTime <= 0 then return end
    
    local newTime = math.max(0, currentTime - timeToReduce)
    
    MySQL.update('UPDATE ejj_prison SET time = ? WHERE identifier = ?', {newTime, identifier})
    
    if jailedPlayers[identifier] then
        jailedPlayers[identifier].time = newTime
    end
    
    if source then
        TriggerClientEvent('ejj_prison:client:setJailTime', source, newTime)
        
        if newTime == 0 then
            TriggerClientEvent('ejj_prison:client:setJailStatus', source, false)
            TriggerClientEvent('ejj_prison:client:setPrisonId', source, nil)
            TriggerClientEvent('ejj_prison:restoreOriginalClothes', source)
            TriggerClientEvent('ejj_prison:client:cleanupPrison', source)
            
            if prisonId then
                local prisonConfig = Config.Prisons[prisonId]
                if prisonConfig and prisonConfig.locations and prisonConfig.locations.release then
                    SetEntityCoords(GetPlayerPed(source), 
                        prisonConfig.locations.release.x, 
                        prisonConfig.locations.release.y, 
                        prisonConfig.locations.release.z)
                    SetEntityHeading(GetPlayerPed(source), prisonConfig.locations.release.w or 0.0)
                end
            end
        end
    end
end

RegisterNetEvent('ejj_prison:server:craftingActivity', function(item, success)
    local src = source
    local playerName = GetPlayerName(src)
    LogCrafting(playerName, item, success)
end)

RegisterNetEvent('ejj_prison:jailPlayerExport', function(playerId, jailTime)
    local src = source
    local targetName = GetPlayerName(playerId)
    local officerName = GetPlayerName(src)
    LogJail(officerName, targetName, jailTime, "Exported")
end)

RegisterNetEvent('ejj_prison:unjailPlayerExport', function(playerId)
    local src = source
    local targetName = GetPlayerName(playerId)
    local officerName = GetPlayerName(src)
    LogUnjail(officerName, targetName, true)
end)

RegisterNetEvent('ejj_prison:server:resourcePickup', function(item)
    local src = source
    local playerName = GetPlayerName(src)
    LogCrafting(playerName, item, true, "Resource Pickup")
end)

RegisterNetEvent('ejj_prison:server:shopPurchase', function(item)
    local src = source
    local playerName = GetPlayerName(src)
    LogCrafting(playerName, item, true, "Shop Purchase")
end)

RegisterNetEvent('ejj_prison:server:itemCraft', function(recipeId)
    local src = source
    local playerName = GetPlayerName(src)
    LogCrafting(playerName, recipeId, true, "Crafting")
end)

exports('JailPlayer', function(source, targetId, duration, prisonId)
    if not source then
        source = 0
    end

    if not Config.BypassPermissions and not HasPermission(source, 'jail') then
        if source ~= 0 then
            TriggerClientEvent('ejj_prison:notify', source, locale('no_permission_jail'), 'error')
        end
        return false
    end
    
    local targetPlayer = GetPlayer(targetId)
    if not targetPlayer then
        if source ~= 0 then
            TriggerClientEvent('ejj_prison:notify', source, locale('player_not_found'), 'error')
        end
        return false
    end
    
    local targetName = GetPlayerName(targetId)
    local officerName = source == 0 and "System" or GetPlayerName(source)
    local targetIdentifier = GetIdentifier(targetId)
    
    if not targetIdentifier then
        if source ~= 0 then
            TriggerClientEvent('ejj_prison:notify', source, locale('player_not_found'), 'error')
        end
        return false
    end
    
    LogJail(officerName, targetName, duration)
    SetJailTime(targetIdentifier, duration, nil, prisonId)
    if source ~= 0 then
        TriggerClientEvent('ejj_prison:notify', source, locale('player_jailed', targetName, duration), 'success')
    end
    return true
end)

exports('UnjailPlayer', function(source, targetId)
    if not source then
        source = 0
    end

    if not Config.BypassPermissions and not HasPermission(source, 'unjail') then
        if source ~= 0 then
            TriggerClientEvent('ejj_prison:notify', source, locale('no_permission_unjail'), 'error')
        end
        return false
    end
    
    local targetPlayer = GetPlayer(targetId)
    if not targetPlayer then
        if source ~= 0 then
            TriggerClientEvent('ejj_prison:notify', source, locale('player_not_found'), 'error')
        end
        return false
    end
    
    local targetName = GetPlayerName(targetId)
    local officerName = source == 0 and "System" or GetPlayerName(source)
    local targetIdentifier = GetIdentifier(targetId)
    
    if not targetIdentifier then
        if source ~= 0 then
            TriggerClientEvent('ejj_prison:notify', source, locale('player_not_found'), 'error')
        end
        return false
    end
    
    LogUnjail(officerName, targetName, true)
    
    TriggerClientEvent('ejj_prison:client:unjailPlayer', targetId)
    SetJailTime(targetIdentifier, 0)
    if source ~= 0 then
        TriggerClientEvent('ejj_prison:notify', source, locale('player_unjailed', targetName), 'success')
    end
    return true
end)

exports('CheckJailTime', function(source, targetId)
    if not source then
        source = 0
    end

    if not Config.BypassPermissions and not HasPermission(source, 'check') then
        if source ~= 0 then
            TriggerClientEvent('ejj_prison:notify', source, locale('no_permission_check'), 'error')
        end
        return false
    end
    
    local targetIdentifier = GetIdentifier(targetId)
    if not targetIdentifier then
        if source ~= 0 then
            TriggerClientEvent('ejj_prison:notify', source, locale('player_not_found'), 'error')
        end
        return false
    end
    
    local jailTime = CheckJailTime(targetIdentifier)
    if jailTime and jailTime > 0 then
        if source ~= 0 then
            TriggerClientEvent('ejj_prison:notify', source, locale('player_jail_time', GetPlayerName(targetId), jailTime), 'info')
        end
        return jailTime
    else
        if source ~= 0 then
            TriggerClientEvent('ejj_prison:notify', source, locale('player_not_jailed', GetPlayerName(targetId)), 'info')
        end
        return 0
    end
end)

exports('AddJailTime', function(source, targetId, additionalTime)
    if not source then
        source = 0
    end

    if not Config.BypassPermissions and not HasPermission(source, 'add') then
        if source ~= 0 then
            TriggerClientEvent('ejj_prison:notify', source, locale('no_permission_add'), 'error')
        end
        return false
    end
    
    local targetIdentifier = GetIdentifier(targetId)
    if not targetIdentifier then
        if source ~= 0 then
            TriggerClientEvent('ejj_prison:notify', source, locale('player_not_found'), 'error')
        end
        return false
    end
    
    local currentTime = CheckJailTime(targetIdentifier)
    if not currentTime or currentTime <= 0 then
        if source ~= 0 then
            TriggerClientEvent('ejj_prison:notify', source, locale('player_not_jailed', GetPlayerName(targetId)), 'error')
        end
        return false
    end
    
    local newTime = currentTime + additionalTime
    SetJailTime(targetIdentifier, newTime)
    if source ~= 0 then
        TriggerClientEvent('ejj_prison:notify', source, locale('jail_time_added', GetPlayerName(targetId), additionalTime, newTime), 'success')
    end
    return true
end)

exports('RemoveJailTime', function(source, targetId, removeTime)
    if not source then
        source = 0
    end

    if not Config.BypassPermissions and not HasPermission(source, 'remove') then
        if source ~= 0 then
            TriggerClientEvent('ejj_prison:notify', source, locale('no_permission_remove'), 'error')
        end
        return false
    end
    
    local targetIdentifier = GetIdentifier(targetId)
    if not targetIdentifier then
        if source ~= 0 then
            TriggerClientEvent('ejj_prison:notify', source, locale('player_not_found'), 'error')
        end
        return false
    end
    
    local currentTime = CheckJailTime(targetIdentifier)
    if not currentTime or currentTime <= 0 then
        if source ~= 0 then
            TriggerClientEvent('ejj_prison:notify', source, locale('player_not_jailed', GetPlayerName(targetId)), 'error')
        end
        return false
    end
    
    local newTime = math.max(0, currentTime - removeTime)
    SetJailTime(targetIdentifier, newTime)
    
    if newTime == 0 then
        TriggerClientEvent('ejj_prison:client:unjailPlayer', targetId)
        if source ~= 0 then
            TriggerClientEvent('ejj_prison:notify', source, locale('player_unjailed', GetPlayerName(targetId)), 'success')
        end
    else
        if source ~= 0 then
            TriggerClientEvent('ejj_prison:notify', source, locale('jail_time_removed', GetPlayerName(targetId), removeTime, newTime), 'success')
        end
    end
    return true
end)

lib.callback.register('ejj_prison:getPlayerPrison', function(source)
    local identifier = GetIdentifier(source)
    if not identifier then return nil end
    
    local result = MySQL.query.await('SELECT prison FROM ejj_prison WHERE identifier = ?', {identifier})
    if result and result[1] then
        return result[1].prison
    end
    return nil
end)

RegisterNetEvent('ejj_prison:server:releasePlayer', function()
    local source = source
    local identifier = GetIdentifier(source)
    if not identifier then return end

    local result = MySQL.query.await('SELECT prison FROM ejj_prison WHERE identifier = ?', {identifier})
    if result and result[1] then
        local prisonId = result[1].prison or 'bolingbroke'
        SetJailTime(identifier, 0, source, prisonId)
        TriggerClientEvent('ejj_prison:notify', source, locale('server_released_automatic'), 'success')
    end
end)