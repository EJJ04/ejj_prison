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
                TriggerClientEvent('ejj_prison:client:RestoreClothes', source)
                TriggerClientEvent('ejj_prison:client:cleanupPrison', source)
            else
                TriggerClientEvent('ejj_prison:client:setJailTime', source, jailTime)
            end
            
            return jailTime
        end
    end
    return 0
end

function GetCurrentJailTime(identifier)
    if not identifier then 
        return 0 
    end
    local result = MySQL.query.await('SELECT time, UNIX_TIMESTAMP(date) as start_time FROM ejj_prison WHERE identifier = ?', {identifier})
    if not result or not result[1] then 
        return 0 
    end
    local jailTime = result[1].time
    local startTime = result[1].start_time
    local currentTime = os.time()
    local elapsedMinutes = math.floor((currentTime - startTime) / 60)
    local remainingTime = math.max(0, jailTime - elapsedMinutes)
    return remainingTime
end

function SetJailTime(source, time, prisonId)
    local identifier = GetIdentifier(source)
    if not identifier then return end

    if time > 0 then
        local inventory = GetInventoryItems(source)
        local inventoryJson = json.encode(inventory)

        if inventory and type(inventory) == 'table' then
            local keepSet = {}
            for _, keepItem in ipairs(Config.KeepItemsOnJail) do
                keepSet[tostring(keepItem):lower()] = true
            end
            for _, item in ipairs(inventory) do
                local itemName = tostring(item.name):lower()
                if not keepSet[itemName] then
                    RemoveItem(source, item.name, item.count, item.metadata, item.slot)
                end
            end
        end

        MySQL.insert('INSERT INTO ejj_prison (identifier, time, prison, inventory) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE time = ?, prison = ?, inventory = ?', {
            identifier, time, prisonId, inventoryJson,
            time, prisonId, inventoryJson
        })
        
        jailedPlayers[identifier] = {
            time = time,
            prison = prisonId,
            startTime = os.time()
        }
        
        local prisonConfig = Config.Prisons[prisonId]
        if prisonConfig and prisonConfig.locations and prisonConfig.locations.jail then
            SetEntityCoords(GetPlayerPed(source), prisonConfig.locations.jail.x, prisonConfig.locations.jail.y, prisonConfig.locations.jail.z)
            SetEntityHeading(GetPlayerPed(source), prisonConfig.locations.jail.w or 0.0)
        end
        
        TriggerClientEvent('ejj_prison:client:InitializePrison', source, prisonId)
        
        TriggerClientEvent('ejj_prison:client:ChangeClothes', source, "prison")
        
        TriggerClientEvent('ejj_prison:notify', source, locale('jailed_for_time', time), 'info')
    else
        local prisonConfig = Config.Prisons[prisonId]
        if prisonConfig and prisonConfig.locations and prisonConfig.locations.release then
            SetEntityCoords(GetPlayerPed(source), prisonConfig.locations.release.x, prisonConfig.locations.release.y, prisonConfig.locations.release.z)
            SetEntityHeading(GetPlayerPed(source), prisonConfig.locations.release.w or 0.0)
        end
        
        local result = MySQL.query.await('SELECT inventory FROM ejj_prison WHERE identifier = ?', {identifier})
        if result and result[1] and result[1].inventory then
            local inventory = json.decode(result[1].inventory)
            if inventory then
                for _, item in ipairs(inventory) do
                    local amount = item.count or item.amount or 1
                    AddItem(source, item.name, amount, item.metadata, item.slot)
                end
            end
        end
        
        MySQL.query('DELETE FROM ejj_prison WHERE identifier = ?', {identifier})
        
        jailedPlayers[identifier] = nil
        
        TriggerClientEvent('ejj_prison:client:ChangeClothes', source, "original")
        
        TriggerClientEvent('ejj_prison:notify', source, locale('released_from_prison'), 'success')
    end
end

function RestorePlayerJail(playerId, prisonId)
    local identifier = GetIdentifier(playerId)
    if not identifier then 
        if Config.Debug then print("^1[ERROR] RestorePlayerJail: Could not get identifier for player " .. tostring(playerId) .. "^0") end
        return 
    end
    
    local jailTime = CheckJailTime(playerId)
    if jailTime and jailTime > 0 then
        if not prisonId then
            local result = MySQL.query.await('SELECT prison FROM ejj_prison WHERE identifier = ? AND time > 0', {identifier})
            if result and result[1] and result[1].prison then
                prisonId = result[1].prison
            else
                prisonId = 'bolingbroke' 
            end
        end
        
        if Config.Debug then print("^2[DEBUG] RestorePlayerJail: Restoring player " .. tostring(playerId) .. " to prison " .. tostring(prisonId) .. " with time " .. tostring(jailTime) .. "^0") end
        
        local prisonConfig = Config.Prisons[prisonId]
        if prisonConfig and prisonConfig.locations and prisonConfig.locations.jail then
            TriggerClientEvent('ejj_prison:client:setJailStatus', playerId, true)
            TriggerClientEvent('ejj_prison:client:setJailTime', playerId, jailTime)
            TriggerClientEvent('ejj_prison:client:setPrisonId', playerId, prisonId)
            TriggerClientEvent('ejj_prison:client:ChangeClothes', playerId)
            
            local targetPed = GetPlayerPed(playerId)
            if targetPed then
                SetEntityCoords(targetPed, prisonConfig.locations.jail.x, prisonConfig.locations.jail.y, prisonConfig.locations.jail.z)
                SetEntityHeading(targetPed, prisonConfig.locations.jail.w or 0.0)
            end
            
            TriggerClientEvent('ejj_prison:client:InitializePrison', playerId, prisonId)
        else
            if Config.Debug then print("^1[ERROR] RestorePlayerJail: Invalid prison config for " .. tostring(prisonId) .. "^0") end
        end
    else
        if Config.Debug then print("^2[DEBUG] RestorePlayerJail: Jail time is 0 or less, releasing player " .. tostring(playerId) .. "^0") end
        if not prisonId then
            local result = MySQL.query.await('SELECT prison FROM ejj_prison WHERE identifier = ?', {identifier})
            if result and result[1] and result[1].prison then
                prisonId = result[1].prison
            else
                prisonId = 'bolingbroke'
            end
        end
        local prisonConfig = Config.Prisons[prisonId]
        if prisonConfig and prisonConfig.locations and prisonConfig.locations.release then
            local targetPed = GetPlayerPed(playerId)
            if targetPed then
                SetEntityCoords(targetPed, prisonConfig.locations.release.x, prisonConfig.locations.release.y, prisonConfig.locations.release.z)
                SetEntityHeading(targetPed, prisonConfig.locations.release.w or 0.0)
            end
        end
        TriggerClientEvent('ejj_prison:client:setJailStatus', playerId, false)
        TriggerClientEvent('ejj_prison:client:setJailTime', playerId, 0)
        TriggerClientEvent('ejj_prison:client:setPrisonId', playerId, nil)
        TriggerClientEvent('ejj_prison:client:RestoreClothes', playerId)
        TriggerClientEvent('ejj_prison:client:cleanupPrison', playerId)
        MySQL.update('DELETE FROM ejj_prison WHERE identifier = ?', {identifier})
        TriggerClientEvent('ejj_prison:notify', playerId, locale('server_released_automatic'), 'success')
    end
end

local function StartPrisonTimer()
    if prisonTimer then return end
    
    prisonTimer = CreateThread(function()
        while true do
            Wait(60000) 
            for _, src in ipairs(GetPlayers()) do
                local sourceNum = tonumber(src)
                local identifier = GetIdentifier(sourceNum)
                if identifier and jailedPlayers[identifier] then
                    local jailData = jailedPlayers[identifier]
                    local result = MySQL.query.await('SELECT time, UNIX_TIMESTAMP(date) as start_time FROM ejj_prison WHERE identifier = ?', {identifier})
                    if result and result[1] then
                        local jailTime = result[1].time
                        local startTime = result[1].start_time
                        local currentTime = os.time()
                        local elapsedMinutes = math.floor((currentTime - startTime) / 60)
                        local remainingTime = math.max(0, jailTime - elapsedMinutes)
                        if remainingTime > 0 then
                            MySQL.update('UPDATE ejj_prison SET time = ?, date = NOW() WHERE identifier = ?', {remainingTime, identifier})
                            jailedPlayers[identifier].time = remainingTime
                            jailedPlayers[identifier].startTime = currentTime
                            TriggerClientEvent('ejj_prison:client:setJailTime', sourceNum, remainingTime)
                        else
                            SetJailTime(sourceNum, 0, jailData.prison)
                        end
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
        if Config.Debug then print('^2[DEBUG] Resource starting: ' .. resourceName .. '^0') end
        if Config.Debug then print('^2[DEBUG] Framework detected: ' .. tostring(Framework) .. '^0') end
        
        StartPrisonTimer()
        
        local result = MySQL.query.await('SELECT identifier, time, UNIX_TIMESTAMP(date) as start_time, prison FROM ejj_prison')
        if result then
            if Config.Debug then print('^2[DEBUG] Found ' .. #result .. ' jail records^0') end
            for _, row in ipairs(result) do
                if row.time > 0 then
                    jailedPlayers[row.identifier] = { time = row.time, startTime = row.start_time, prisonId = row.prison }
                end
            end
        end
        
        local players = GetPlayers()
        if Config.Debug then print('^2[DEBUG] Found ' .. #players .. ' players^0') end
        for _, playerId in ipairs(players) do
            local playerIdNum = tonumber(playerId)
            if playerIdNum then
                if Config.Debug then print('^2[DEBUG] Processing player: ' .. tostring(playerId) .. '^0') end
                local identifier = GetIdentifier(playerIdNum)
                if identifier then
                    local jailTime = GetCurrentJailTime(identifier)
                    
                    if jailTime and jailTime > 0 then
                        if Config.Debug then print('^2[DEBUG] Player ' .. tostring(playerId) .. ' has jail time: ' .. tostring(jailTime) .. '^0') end
                        
                        local prisonId = nil
                        if jailedPlayers[identifier] and jailedPlayers[identifier].prisonId then
                            prisonId = jailedPlayers[identifier].prisonId
                        else
                            local prisonResult = MySQL.scalar.await('SELECT prison FROM ejj_prison WHERE identifier = ? AND time > 0', {identifier})
                            if prisonResult then
                                prisonId = prisonResult
                            else
                                prisonId = 'bolingbroke' 
                            end
                        end
                        
                        if Config.Debug then print('^2[DEBUG] Player ' .. tostring(playerId) .. ' prison ID: ' .. tostring(prisonId) .. '^0') end
                        
                        Wait(1000) 
                        RestorePlayerJail(playerIdNum, prisonId)
                        
                        TriggerClientEvent('ejj_prison:client:setJailTime', playerIdNum, jailTime)
                        TriggerClientEvent('ejj_prison:client:InitializePrison', playerIdNum, prisonId)
                    end
                end
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
    if Config.Debug then print('^2[DEBUG] playerLoaded event triggered for source: ' .. tostring(source) .. '^0') end
    Wait(5000)
    RestorePlayerJail(source)
    
    TriggerClientEvent('ejj_prison:syncTunnelState', source, tunnelExists)
end)

lib.callback.register('ejj_prison:getJailTime', function(source)
    local identifier = GetIdentifier(source)
    if not identifier then return 0 end
    
    return GetCurrentJailTime(identifier)
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
                                TriggerClientEvent('ejj_prison:playAlarmSound', playerSource, prisonId)
                                playersInAlarmRange[playerSource] = true
                            end
                        end
                    end
                end
            end
            for playerId, _ in pairs(playersInAlarmRange) do
                if not currentNearbyPlayers[playerId] then
                    TriggerClientEvent('ejj_prison:stopAlarmSound', playerId)
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
        TriggerClientEvent('ejj_prison:stopAlarmSound', playerId)
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
    SetJailTime(targetId, duration, prisonId)
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
    
    SetJailTime(targetId, 0, prisonId)
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
    
    local jailTime = GetCurrentJailTime(identifier)
    if jailTime and jailTime > 0 then
        TriggerClientEvent('ejj_prison:notify', source, locale('player_jail_time', GetPlayerName(targetId), jailTime), 'info')
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
        -- Use actual remaining jail time, not just DB value
        local currentRemaining = GetCurrentJailTime(identifier)
        local newTime = math.max(0, currentRemaining - rewardTime)
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
            TriggerClientEvent('ejj_prison:client:RestoreClothes', source)
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
    if currentJailTime > 0 then
        MySQL.query.await('INSERT INTO ejj_prison (identifier, time, date) VALUES (?, ?, NOW()) ON DUPLICATE KEY UPDATE time = ?, date = NOW()', {
            identifier, currentJailTime, currentJailTime
        })
    end
    jailedPlayers[identifier] = nil
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
    
    if action == "Tunnel dug" then
        local identifier = GetIdentifier(src)
        if not identifier then return end
        
        local result = MySQL.query.await('SELECT prison FROM ejj_prison WHERE identifier = ?', {identifier})
        if not result or not result[1] then return end
        
        local prisonId = result[1].prison
        if not prisonId then return end
        
        tunnelExists = true
        TriggerClientEvent('ejj_prison:createTunnel', -1, prisonId)
        
        if tunnelResetTimer then
            tunnelResetTimer = nil
        end
        
        tunnelResetTimer = SetTimeout(Config.Prisons[prisonId].escape.resetTime * 60000, function()
            ResetEscapeTunnel()
        end)
    end
end)

RegisterNetEvent('ejj_prison:playerEscaped', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end

    if player.PlayerData and player.PlayerData.inPrisonEscape then return end
    if player.PlayerData then
        player.PlayerData.inPrisonEscape = true
        SetTimeout(10000, function()
            if player and player.PlayerData then player.PlayerData.inPrisonEscape = nil end
        end)
    end

    local identifier = GetIdentifier(src)
    escapedPlayers[identifier] = true 
    local result = MySQL.query.await('SELECT * FROM ejj_prison WHERE identifier = ? AND time > 0', {
        identifier
    })

    if result and result[1] then
        local prisonConfig = GetPrisonConfig(result[1].prison)
        if not prisonConfig then return end

        TriggerPrisonAlarm(result[1].prison)

        if Config.RestoreOnEscape then
            TriggerClientEvent('ejj_prison:client:RestoreClothes', src)
            local invResult = MySQL.query.await('SELECT inventory FROM ejj_prison WHERE identifier = ?', {identifier})
            if invResult and invResult[1] and invResult[1].inventory then
                local inventory = json.decode(invResult[1].inventory)
                if inventory then
                    for _, item in ipairs(inventory) do
                        local amount = item.count or item.amount or 1
                        AddItem(src, item.name, amount, item.metadata, item.slot)
                    end
                end
            end
        end

        MySQL.update('UPDATE ejj_prison SET time = 0, prison = NULL WHERE identifier = ?', {
            identifier
        })

        if player.Functions and player.Functions.SetMetaData then
            player.Functions.SetMetaData("injail", 0)
        elseif player.set("injail", 0) then
            player.set("injail", 0)
        end
        TriggerClientEvent("prison:client:RemoveFromJail", src)
    end
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
            TriggerClientEvent('ejj_prison:client:RestoreClothes', source)
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

RegisterNetEvent('ejj_prison:server:itemCraft', function(recipeId)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end

    local result = MySQL.query.await('SELECT prison FROM ejj_prison WHERE identifier = ?', {identifier})
    local prisonId = result and result[1] and result[1].prison or Config.CurrentPrison or 'bolingbroke'
    local prisonConfig = Config.Prisons[prisonId]
    if not prisonConfig or not prisonConfig.crafting or not prisonConfig.crafting.recipes or not prisonConfig.crafting.recipes[recipeId] then return end
    local recipe = prisonConfig.crafting.recipes[recipeId]

    for ingredient, requiredAmount in pairs(recipe.ingredients) do
        local itemCount = GetItemCount(src, ingredient)
        if itemCount < requiredAmount then
            TriggerClientEvent('ejj_prison:notify', src, locale('crafting_failed'), 'error')
            return
        end
    end

    for ingredient, requiredAmount in pairs(recipe.ingredients) do
        RemoveItem(src, ingredient, requiredAmount)
    end

    AddItem(src, recipe.result.item, recipe.result.count or 1)
    TriggerClientEvent('ejj_prison:notify', src, locale('crafting_success', recipe.result.item), 'success')
end)

local function JailPlayer(source, targetId, duration, prisonId)
    if Config.BypassPermissions then
        if not targetId then
            prisonId = duration
            duration = targetId
            targetId = source
            source = 0
        elseif not duration then
            duration = targetId
            targetId = source
            source = 0
        end
    end

    if not source and Config.BypassPermissions then
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
    SetJailTime(targetIdentifier, duration, prisonId)
    if source ~= 0 then
        TriggerClientEvent('ejj_prison:notify', source, locale('player_jailed', targetName, duration), 'success')
    end
    return true
end

local function UnjailPlayer(source, targetId)
    if Config.BypassPermissions then
        if not targetId then
            targetId = source
            source = 0
        end
    end

    if not source and Config.BypassPermissions then
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
    SetJailTime(targetIdentifier, 0, targetId)
    if source ~= 0 then
        TriggerClientEvent('ejj_prison:notify', source, locale('player_unjailed', targetName), 'success')
    end
    return true
end

exports('JailPlayer', JailPlayer)
exports('UnjailPlayer', UnjailPlayer)

RegisterNetEvent('ejj_prison:jailPlayerExport', function(playerId, jailTime, prisonId)
    local src = source
    if not prisonId then
        for id, prisonData in pairs(Config.Prisons) do
            if prisonData.enabled then
                prisonId = id
                break
            end
        end
    end
    if Config.BypassPermissions then
        JailPlayer(nil, playerId, jailTime, prisonId)
    else
        JailPlayer(src, playerId, jailTime, prisonId)
    end
end)

RegisterNetEvent('ejj_prison:unjailPlayerExport', function(playerId)
    local src = source
    if Config.BypassPermissions then
        UnjailPlayer(nil, playerId)
    else
        UnjailPlayer(src, playerId)
    end
end)

RegisterNetEvent('ejj_prison:server:releasePlayer', function()
    local source = source
    local identifier = GetIdentifier(source)
    if not identifier then return end

    local result = MySQL.query.await('SELECT prison FROM ejj_prison WHERE identifier = ?', {identifier})
    if result and result[1] then
        local prisonId = result[1].prison or 'bolingbroke'
        SetJailTime(identifier, 0, prisonId)
        if not escapedPlayers[identifier] then
            TriggerClientEvent('ejj_prison:notify', source, locale('server_released_automatic'), 'success')
        end
    end
end)

RegisterNetEvent('ejj_prison:server:removeItem', function(item, count)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end
    
    local result = MySQL.query.await('SELECT time FROM ejj_prison WHERE identifier = ?', {identifier})
    if not result or not result[1] or result[1].time <= 0 then return end
    
    RemoveItem(src, item, count)
end)

RegisterNetEvent('ejj_prison:server:shopPurchase', function(item)
    local src = source
    local player = GetPlayer(src)
    if not player or not item or not item.name or item.price == nil then
        TriggerClientEvent('ejj_prison:notify', src, locale('player_not_found'), 'error')
        return
    end

    local canAfford = false
    local moneyType = 'money'
    local price = tonumber(item.price) or 0

    if price == 0 then
        canAfford = true
    elseif Framework == 'esx' then
        canAfford = player.getMoney() >= price
    elseif Framework == 'qbx' then
        canAfford = player.PlayerData.money[moneyType] and player.PlayerData.money[moneyType] >= price
    elseif Framework == 'qb' then
        canAfford = player.PlayerData.money[moneyType] and player.PlayerData.money[moneyType] >= price
    end

    if not canAfford then
        TriggerClientEvent('ejj_prison:notify', src, 'You do not have enough money.', 'error')
        return
    end

    -- Remove money only if price > 0
    if price > 0 then
        if Framework == 'esx' then
            player.removeMoney(price)
        elseif Framework == 'qbx' then
            player.Functions.RemoveMoney(moneyType, price)
        elseif Framework == 'qb' then
            player.Functions.RemoveMoney(moneyType, price)
        end
    end

    -- Give item (pass src for inventory bridge compatibility)
    AddItem(src, item.name, 1)
    local msg = price > 0 and ('You purchased ' .. (item.label or item.name) .. ' for $' .. price .. '.') or ('You received ' .. (item.label or item.name) .. ' for free!')
    TriggerClientEvent('ejj_prison:notify', src, msg, 'success')
end)

RegisterNetEvent('ejj_prison:server:resourcePickup', function(item)
    local src = source
    if not item then return end
    AddItem(src, item, 1)
    TriggerClientEvent('ejj_prison:notify', src, 'You picked up ' .. item .. '.', 'success')
end)