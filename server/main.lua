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
    local Player = GetPlayer(source)
    if not Player then return 0 end
    local identifier = GetIdentifier(source)
    local jailData = jailedPlayers[identifier]
    if jailData and type(jailData) == 'table' then
        local remainingTime = jailData.time - math.floor((os.time() - jailData.startTime) / 60)
        if remainingTime <= 0 then
            if suppressUnjail then
                return 0
            end
            local prisonId = jailData.prisonId or 'bolingbroke'
            local prisonConfig = Config.Prisons[prisonId]
            jailedPlayers[identifier] = nil
            MySQL.query('DELETE FROM ejj_prison WHERE identifier = ?', {identifier})
            if prisonConfig and prisonConfig.locations and prisonConfig.locations.release then
                local releaseCoords = prisonConfig.locations.release
                SetEntityCoords(GetPlayerPed(source), releaseCoords.x, releaseCoords.y, releaseCoords.z)
                SetEntityHeading(GetPlayerPed(source), releaseCoords.w or 0.0)
            end
            TriggerClientEvent('ejj_prison:notify', source, locale('server_released_automatic'), 'success')
            TriggerClientEvent('ejj_prison:jailStatusChanged', source, false, nil)
            TriggerClientEvent('ejj_prison:restoreOriginalClothes', source)
            SetJailTime(identifier, 0, source)
            return 0
        end
        return remainingTime
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

function RestorePlayerJail(source)
    local xPlayer = GetPlayer(source)
    if not xPlayer then return end
    
    local identifier = GetIdentifier(source)
    local jailTime = CheckJailTime(source)
    
    if jailTime and jailTime > 0 then
        local prisonId = GetPlayerPrison(source)
        local prisonConfig = GetPrisonConfig(prisonId)
        
        SetEntityCoords(GetPlayerPed(source), prisonConfig.locations.jail.x, prisonConfig.locations.jail.y, prisonConfig.locations.jail.z)
        SetEntityHeading(GetPlayerPed(source), prisonConfig.locations.jail.w or 0.0)
        
        TriggerClientEvent('ejj_prison:jailStatusChanged', source, true, prisonId)
        TriggerClientEvent('ejj_prison:changeToPrisonClothes', source)
        
        TriggerClientEvent('ejj_prison:notify', source, locale('server_returned_to_prison', jailTime), 'info')
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
        
        for _, playerId in ipairs(GetPlayers()) do
            local source = tonumber(playerId)
            if source then
                Wait(1000) 
                RestorePlayerJail(source)
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

AddEventHandler('playerJoining', function()
    if not prisonTimer then
        StartPrisonTimer()
    end
end)

AddEventHandler('ejj_prison:playerLoaded', function(source)
    Wait(5000)
    RestorePlayerJail(source)
    
    TriggerClientEvent('ejj_prison:syncTunnelState', source, tunnelExists)
end)

lib.callback.register('ejj_prison:getJailTime', function(source)
    if Config.RequirePoliceForJail and not IsPlayerPolice(source) then
        return false
    end
    return CheckJailTime(source, true)
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
    params = {
        { name = 'id', type = 'playerId', help = locale('jail_param_id') },
        { name = 'time', type = 'number', help = locale('jail_param_time') },
        { name = 'prison', type = 'string', help = 'Prison ID (e.g., bolingbroke)' }
    }
}, function(source, args)
    if Config.RequirePoliceForJail and not IsPlayerPolice(source) then
        TriggerClientEvent('ejj_prison:notify', source, locale('no_permission'), 'error')
        return
    end
    
    local targetId = args.id
    local jailTime = args.time
    local prisonId = args.prison
    local xPlayer = GetPlayer(targetId)
    local xAdmin = GetPlayer(source)
    
    if not xPlayer then
        TriggerClientEvent('ejj_prison:notify', source, locale('player_not_found'), 'error')
        return
    end
    
    if not xAdmin then return end
    
    if not IsValidPrison(prisonId) then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_invalid_prison', prisonId), 'error')
        return
    end
    
    SetJailTime(GetIdentifier(targetId), jailTime, targetId, prisonId)
    
    local prisonConfig = GetPrisonConfig(prisonId)
    
    SetEntityCoords(GetPlayerPed(targetId), prisonConfig.locations.jail.x, prisonConfig.locations.jail.y, prisonConfig.locations.jail.z)
    SetEntityHeading(GetPlayerPed(targetId), prisonConfig.locations.jail.w or 0.0)
    
    TriggerClientEvent('ejj_prison:jailStatusChanged', targetId, true, prisonId)
    TriggerClientEvent('ejj_prison:changeToPrisonClothes', targetId)
    
    TriggerClientEvent('ejj_prison:notify', source, locale('player_jailed', targetId, jailTime), 'success')
    TriggerClientEvent('ejj_prison:notify', targetId, locale('you_were_jailed', jailTime, source), 'error')
end)

lib.addCommand('unjail', {
    help = locale('help_unjail'),
    params = {
        { name = 'id', type = 'playerId', help = locale('param_player_id') }
    }
}, function(source, args)
    if Config.RequirePoliceForJail and not IsPlayerPolice(source) then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_no_permission_command'), 'error')
        return
    end
    
    local targetId = args.id
    local xPlayer = GetPlayer(targetId)
    local xAdmin = GetPlayer(source)
    
    if not xPlayer then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_player_not_found'), 'error')
        return
    end
    
    if not xAdmin then return end
    
    local prisonId = GetPlayerPrison(targetId)
    local prisonConfig = GetPrisonConfig(prisonId)
    
    SetJailTime(GetIdentifier(targetId), 0, targetId)
    
    SetEntityCoords(GetPlayerPed(targetId), prisonConfig.locations.release.x, prisonConfig.locations.release.y, prisonConfig.locations.release.z)
    SetEntityHeading(GetPlayerPed(targetId), prisonConfig.locations.release.w or 0.0)
    
    TriggerClientEvent('ejj_prison:jailStatusChanged', targetId, false)
    TriggerClientEvent('ejj_prison:restoreOriginalClothes', targetId)
    
    TriggerClientEvent('ejj_prison:notify', source, locale('player_unjailed', targetId), 'success')
    TriggerClientEvent('ejj_prison:notify', targetId, locale('you_were_unjailed', source), 'success')
end)

lib.addCommand('jailstatus', {
    help = locale('help_jail_status'),
    params = {
        { name = 'id', type = 'playerId', help = locale('param_player_id') }
    }
}, function(source, args)
    if Config.RequirePoliceForJail and not IsPlayerPolice(source) then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_no_permission_command'), 'error')
        return
    end
    
    local targetId = args.id
    local xPlayer = GetPlayer(targetId)
    
    if not xPlayer then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_player_not_found'), 'error')
        return
    end
    
    local jailTime = CheckJailTime(targetId)
    
    if jailTime and jailTime > 0 then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_player_jail_time', targetId, jailTime), 'info')
    else
        TriggerClientEvent('ejj_prison:notify', source, locale('server_player_not_in_jail', targetId), 'info')
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
    local jailData = jailedPlayers[identifier]
    if not jailData or jailData.time <= 0 then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_not_in_jail'), 'error')
        return
    end
    local rewardTime = 0
    if jobType == 'electrician' and type(location) == 'number' then
        rewardTime = Config.JobRewards.electrician[location] or 0
    elseif jobType == 'training' and type(location) == 'string' then
        rewardTime = Config.JobRewards.training[location] or 0
    else
        rewardTime = Config.JobRewards[jobType] or 0
    end
    local newOriginalTime = jailData.time - rewardTime
    if newOriginalTime > 0 then
        jailedPlayers[identifier].time = newOriginalTime
        MySQL.query.await('UPDATE ejj_prison SET time = ? WHERE identifier = ?', {newOriginalTime, identifier})
        local currentTime = os.time()
        local timeElapsed = math.floor((currentTime - jailData.startTime) / 60)
        local remainingTime = math.max(0, newOriginalTime - timeElapsed)
        if remainingTime <= 0 then
            SetJailTime(identifier, 0, source)
            local prisonId = jailData.prisonId or 'bolingbroke'
            local prisonConfig = GetPrisonConfig(prisonId)
            SetEntityCoords(GetPlayerPed(source), prisonConfig.locations.release.x, prisonConfig.locations.release.y, prisonConfig.locations.release.z)
            SetEntityHeading(GetPlayerPed(source), prisonConfig.locations.release.w or 0.0)
            TriggerClientEvent('ejj_prison:jailStatusChanged', source, false)
            TriggerClientEvent('ejj_prison:restoreOriginalClothes', source)
            TriggerClientEvent('ejj_prison:notify', source, locale('job_completed_released'), 'success')
        else
            TriggerClientEvent('ejj_prison:notify', source, locale('job_completed_time_reduced', rewardTime, remainingTime), 'success')
        end
    else
        SetJailTime(identifier, 0, source)
        local prisonId = jailData.prisonId or 'bolingbroke'
        local prisonConfig = GetPrisonConfig(prisonId)
        SetEntityCoords(GetPlayerPed(source), prisonConfig.locations.release.x, prisonConfig.locations.release.y, prisonConfig.locations.release.z)
        SetEntityHeading(GetPlayerPed(source), prisonConfig.locations.release.w or 0.0)
        TriggerClientEvent('ejj_prison:jailStatusChanged', source, false)
        TriggerClientEvent('ejj_prison:restoreOriginalClothes', source)
        TriggerClientEvent('ejj_prison:notify', source, locale('job_completed_released'), 'success')
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