lib.locale()

local jailedPlayers = {} 
local jailStartTimes = {} 
local escapedPlayers = {} 
local alarmActive = false 
local playersInAlarmRange = {} 
local tunnelExists = false 
local tunnelResetTimer = nil 

function CheckJailTime(source)
    local xPlayer = GetPlayer(source)
    if not xPlayer then return 0 end
    
    local identifier = GetIdentifier(source)
    
    if jailedPlayers[identifier] and jailStartTimes[identifier] then
        local originalTime = jailedPlayers[identifier]
        local startTime = jailStartTimes[identifier]
        local currentTime = os.time()
        local timeElapsed = math.floor((currentTime - startTime) / 60) 
        local remainingTime = math.max(0, originalTime - timeElapsed)
        
        if remainingTime <= 0 then
            jailedPlayers[identifier] = nil
            jailStartTimes[identifier] = nil
            MySQL.query.await('DELETE FROM ejj_prison WHERE identifier = ?', {
                identifier
            })
            return 0
        end
        
        return remainingTime
    end
    
    local result = MySQL.query.await('SELECT time, UNIX_TIMESTAMP(date) as start_time FROM ejj_prison WHERE identifier = ?', {
        identifier
    })
    
    if result and result[1] and result[1].time > 0 then
        local originalTime = result[1].time
        local startTime = result[1].start_time
        local currentTime = os.time()
        local timeElapsed = math.floor((currentTime - startTime) / 60) 
        local remainingTime = math.max(0, originalTime - timeElapsed)
        
        jailedPlayers[identifier] = originalTime
        jailStartTimes[identifier] = startTime
        
        if remainingTime <= 0 then
            jailedPlayers[identifier] = nil
            jailStartTimes[identifier] = nil
            MySQL.query.await('DELETE FROM ejj_prison WHERE identifier = ?', {
                identifier
            })
            return 0
        end
        
        return remainingTime
    end
    
    return 0
end

function SetJailTime(identifier, time, source)
    if time > 0 then
        local startTime = os.time()
        local inventory = nil
        
        if source then
            inventory = GetInventoryItems(source)
            local itemsToRemove = {}
            
            for slot, item in pairs(inventory) do
                if item and item.name and item.count and item.count > 0 then
                    local shouldKeep = false
                    
                    for _, keepItem in pairs(Config.KeepItemsOnJail) do
                        if item.name == keepItem then
                            shouldKeep = true
                            break
                        end
                    end
                    
                    if not shouldKeep then
                        table.insert(itemsToRemove, {slot = slot, item = item})
                    else
                        inventory[slot] = nil
                    end
                end
            end
            
            for _, itemData in pairs(itemsToRemove) do
                RemoveItem(source, itemData.item.name, itemData.item.count, itemData.item.metadata or itemData.item.info, itemData.slot)
            end
        end
        
        MySQL.query.await('INSERT INTO ejj_prison (identifier, time, date, inventory) VALUES (?, ?, NOW(), ?) ON DUPLICATE KEY UPDATE time = ?, date = NOW(), inventory = ?', {
            identifier, time, json.encode(inventory), time, json.encode(inventory)
        })
        jailedPlayers[identifier] = time
        jailStartTimes[identifier] = startTime
    else
        local result = MySQL.query.await('SELECT inventory FROM ejj_prison WHERE identifier = ?', {
            identifier
        })
        
        if source and result and result[1] and result[1].inventory then
            local inventory = json.decode(result[1].inventory)
            if inventory then
                for slot, item in pairs(inventory) do
                    if item and item.name and item.count and item.count > 0 then
                        AddItem(source, item.name, item.count, item.metadata or item.info, slot)
                    end
                end
            end
        end
        
        MySQL.query.await('DELETE FROM ejj_prison WHERE identifier = ?', {
            identifier
        })
        jailedPlayers[identifier] = nil
        jailStartTimes[identifier] = nil
    end
end

function GetCurrentJailTime(identifier)
    if not jailedPlayers[identifier] or not jailStartTimes[identifier] then
        return 0
    end
    
    local originalTime = jailedPlayers[identifier]
    local startTime = jailStartTimes[identifier]
    local currentTime = os.time()
    local timeElapsed = math.floor((currentTime - startTime) / 60) 
    local remainingTime = math.max(0, originalTime - timeElapsed)
    
    return remainingTime
end

function RestorePlayerJail(source)
    local xPlayer = GetPlayer(source)
    if not xPlayer then return end
    
    local identifier = GetIdentifier(source)
    local jailTime = CheckJailTime(source)
    
    if jailTime and jailTime > 0 then
        SetEntityCoords(GetPlayerPed(source), Config.Locations.jail.x, Config.Locations.jail.y, Config.Locations.jail.z)
        SetEntityHeading(GetPlayerPed(source), Config.Locations.jail.w or 0.0)
        
        TriggerClientEvent('ejj_prison:jailStatusChanged', source, true)
        TriggerClientEvent('ejj_prison:changeToPrisonClothes', source)
        
        TriggerClientEvent('ejj_prison:notify', source, locale('server_returned_to_prison', jailTime), 'info')
    end
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for _, playerId in ipairs(GetPlayers()) do
            local source = tonumber(playerId)
            if source then
                Wait(1000) 
                RestorePlayerJail(source)
            end
        end
    end
end)

AddEventHandler('ejj_prison:playerLoaded', function(source)
    Wait(5000)
    RestorePlayerJail(source)
    
    TriggerClientEvent('ejj_prison:syncTunnelState', source, tunnelExists)
end)

lib.callback.register('ejj_prison:getJailTime', function(source)
    if not IsPlayerPolice(source) then
        return false
    end

    return CheckJailTime(source)
end)

lib.callback.register('ejj_prison:getPlayerInventory', function(source)
    return GetInventoryItems(source)
end)

lib.callback.register('ejj_prison:hasItem', function(source, itemName)
    local itemCount = GetItemCount(source, itemName)
    return itemCount > 0
end)



function TriggerPrisonAlarm()
    if not Config.Escape.alarm.enabled or alarmActive then
        return
    end
    
    alarmActive = true
    playersInAlarmRange = {}
    
    CreateThread(function()
        local startTime = GetGameTimer()
        local endTime = startTime + Config.Escape.alarm.duration
        
        while alarmActive and GetGameTimer() < endTime do
            local players = GetPlayers()
            local currentNearbyPlayers = {}
            
            for _, playerId in ipairs(players) do
                local playerSource = tonumber(playerId)
                if playerSource then
                    local playerPed = GetPlayerPed(playerSource)
                    if playerPed and playerPed ~= 0 then
                        local playerCoords = GetEntityCoords(playerPed)
                        local distance = #(vector3(playerCoords.x, playerCoords.y, playerCoords.z) - Config.Escape.alarm.center)
                        
                        if distance <= Config.Escape.alarm.maxDistance then
                            currentNearbyPlayers[playerSource] = true
                            
                            if not playersInAlarmRange[playerSource] then
                                TriggerClientEvent('ejj_prison:startAlarm', playerSource)
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
        { name = 'id', type = 'number', help = locale('jail_param_id') },
        { name = 'time', type = 'number', help = locale('jail_param_time') }
    }
}, function(source, args)
    if not IsPlayerPolice(source) then
        TriggerClientEvent('ejj_prison:notify', source, locale('no_permission'), 'error')
        return
    end
    
    local targetId = args.id
    local jailTime = args.time
    local xPlayer = GetPlayer(targetId)
    local xAdmin = GetPlayer(source)
    
    if not xPlayer then
        TriggerClientEvent('ejj_prison:notify', source, locale('player_not_found'), 'error')
        return
    end
    
    if not xAdmin then return end
    
    SetJailTime(GetIdentifier(targetId), jailTime, targetId)
    
    SetEntityCoords(GetPlayerPed(targetId), Config.Locations.jail.x, Config.Locations.jail.y, Config.Locations.jail.z)
    SetEntityHeading(GetPlayerPed(targetId), Config.Locations.jail.w or 0.0)
    
    TriggerClientEvent('ejj_prison:jailStatusChanged', targetId, true)
    TriggerClientEvent('ejj_prison:changeToPrisonClothes', targetId)
    
    TriggerClientEvent('ejj_prison:notify', source, locale('player_jailed', targetId, jailTime), 'success')
    TriggerClientEvent('ejj_prison:notify', targetId, locale('you_were_jailed', jailTime, source), 'error')
end)

lib.addCommand('unjail', {
    help = locale('help_unjail'),
    params = {
        { name = 'id', type = 'number', help = locale('param_player_id') }
    }
}, function(source, args)
    if not IsPlayerPolice(source) then
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
    
    SetJailTime(GetIdentifier(targetId), 0, targetId)
    
    SetEntityCoords(GetPlayerPed(targetId), Config.Locations.release.x, Config.Locations.release.y, Config.Locations.release.z)
    SetEntityHeading(GetPlayerPed(targetId), Config.Locations.release.w or 0.0)
    
    TriggerClientEvent('ejj_prison:jailStatusChanged', targetId, false)
    TriggerClientEvent('ejj_prison:restoreOriginalClothes', targetId)
    
    TriggerClientEvent('ejj_prison:notify', source, locale('server_player_released', targetId), 'success')
    TriggerClientEvent('ejj_prison:notify', targetId, locale('server_released_by', source), 'success')
end)

lib.addCommand('jailstatus', {
    help = locale('help_jail_status'),
    params = {
        { name = 'id', type = 'number', help = locale('param_player_id') }
    }
}, function(source, args)
    if not IsPlayerPolice(source) then
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
    
    if jailTime > 0 then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_player_jail_time', targetId, jailTime), 'info')
    else
        TriggerClientEvent('ejj_prison:notify', source, locale('server_player_not_in_jail', targetId), 'info')
    end
end)

lib.addCommand('resettunnel', {
    help = locale('help_reset_tunnel'),
    restricted = 'group.admin'
}, function(source, args)
    if tunnelExists then
        ResetEscapeTunnel()
        TriggerClientEvent('ejj_prison:notify', source, locale('tunnel_reset_success'), 'success')
    else
        TriggerClientEvent('ejj_prison:notify', source, locale('no_tunnel_to_reset'), 'info')
    end
end)

RegisterNetEvent('ejj_prison:jobResult', function(jobType, success)
    local source = source
    local xPlayer = GetPlayer(source)
    
    if not xPlayer then return end
    
    local identifier = GetIdentifier(source)
    local currentJailTime = CheckJailTime(source)
    
    if not currentJailTime or currentJailTime <= 0 then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_not_in_jail'), 'error')
        return
    end
    
    if not success then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_job_failed'), 'error')
        return
    end
    
    local rewardTime = Config.JobRewards[jobType] or 0
    
    local originalTime = jailedPlayers[identifier]
    local newOriginalTime = math.max(0, originalTime - rewardTime)
    
    if newOriginalTime > 0 then
        local startTime = jailStartTimes[identifier]
        MySQL.query.await('UPDATE ejj_prison SET time = ? WHERE identifier = ?', {
            newOriginalTime, identifier
        })
        jailedPlayers[identifier] = newOriginalTime
        
        local currentTime = os.time()
        local timeElapsed = math.floor((currentTime - startTime) / 60)
        local remainingTime = math.max(0, newOriginalTime - timeElapsed)
        
        if remainingTime <= 0 then
            SetJailTime(identifier, 0, source)
            SetEntityCoords(GetPlayerPed(source), Config.Locations.release.x, Config.Locations.release.y, Config.Locations.release.z)
            SetEntityHeading(GetPlayerPed(source), Config.Locations.release.w or 0.0)
            TriggerClientEvent('ejj_prison:jailStatusChanged', source, false)
            TriggerClientEvent('ejj_prison:restoreOriginalClothes', source)
            TriggerClientEvent('ejj_prison:notify', source, locale('job_completed_released'), 'success')
        else
            TriggerClientEvent('ejj_prison:notify', source, locale('job_completed_time_reduced', rewardTime, remainingTime), 'success')
        end
    else
        SetJailTime(identifier, 0, source)
        SetEntityCoords(GetPlayerPed(source), Config.Locations.release.x, Config.Locations.release.y, Config.Locations.release.z)
        SetEntityHeading(GetPlayerPed(source), Config.Locations.release.w or 0.0)
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
        jailStartTimes[identifier] = nil
    end
end)

MySQL.execute([[
    CREATE TABLE IF NOT EXISTS `ejj_prison` (
        `identifier` varchar(50) NOT NULL,
        `time` int(11) NOT NULL,
        `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `inventory` json DEFAULT NULL,
        PRIMARY KEY (`identifier`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]])

local result = MySQL.query.await('SELECT identifier, time, UNIX_TIMESTAMP(date) as start_time FROM ejj_prison')
if result then
    for _, row in ipairs(result) do
        jailedPlayers[row.identifier] = row.time
        jailStartTimes[row.identifier] = row.start_time
    end
end

RegisterNetEvent('ejj_prison:buyItem', function(itemName, price)
    local source = source
    local xPlayer = GetPlayer(source)
    
    if not xPlayer then return end
    
    local jailTime = CheckJailTime(source)
    if jailTime <= 0 then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_not_in_jail'), 'error')
        return
    end
    
    local validItem = false
    for _, item in ipairs(Config.Shop.items) do
        if item.name == itemName then
            validItem = true
            break
        end
    end
    
    if not validItem then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_invalid_item'), 'error')
        return
    end

    local success = AddItem(source, itemName, 1)
    if success then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_received_item', itemName), 'success')
    else
        TriggerClientEvent('ejj_prison:notify', source, locale('server_inventory_full_give'), 'error')
    end
end)

exports('JailPlayer', function(playerId, jailTime)
    local xPlayer = GetPlayer(playerId)
    
    if not xPlayer then
        return false
    end
    
    if not jailTime or jailTime <= 0 then
        return false
    end
    
    SetJailTime(GetIdentifier(playerId), jailTime, playerId)
    
    SetEntityCoords(GetPlayerPed(playerId), Config.Locations.jail.x, Config.Locations.jail.y, Config.Locations.jail.z)
    SetEntityHeading(GetPlayerPed(playerId), Config.Locations.jail.w or 0.0)
    
    TriggerClientEvent('ejj_prison:changeToPrisonClothes', playerId)
    TriggerClientEvent('ejj_prison:notify', playerId, locale('server_jailed_for', jailTime), 'error')
    
    if Config.KeepItemsOnJail and #Config.KeepItemsOnJail > 0 then
        SetTimeout(2000, function() 
            TriggerClientEvent('ejj_prison:notify', playerId, locale('server_items_kept_on_jail'), 'info')
        end)
    end
    
    return true
end)

RegisterNetEvent('ejj_prison:tunnelDug', function()
    local source = source
    local xPlayer = GetPlayer(source)
    
    if not xPlayer then return end
    
    local jailTime = CheckJailTime(source)
    if jailTime <= 0 then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_not_in_jail'), 'error')
        return
    end
    
    tunnelExists = true
    
    if tunnelResetTimer then
        tunnelResetTimer = nil
    end
    
    local resetTimeMs = Config.Escape.resetTime * 60 * 1000
    tunnelResetTimer = SetTimeout(resetTimeMs, function()
        ResetEscapeTunnel()
    end)
    
    TriggerClientEvent('ejj_prison:createTunnelRock', -1)
    
    if Config.Escape.digging.removeShovel then
        RemoveItem(source, Config.Escape.digging.requiredItem, 1)
        TriggerClientEvent('ejj_prison:notify', source, locale('shovel_broke'), 'info')
    end
end)

RegisterNetEvent('ejj_prison:playerEscaped', function()
    local source = source
    local xPlayer = GetPlayer(source)
    
    if not xPlayer then return end
    
    local identifier = GetIdentifier(source)
    
    local jailTime = CheckJailTime(source)
    if jailTime <= 0 then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_not_in_jail'), 'error')
        return
    end
    
    SetJailTime(identifier, 0, source) 
    
    jailedPlayers[identifier] = nil
    jailStartTimes[identifier] = nil
    escapedPlayers[identifier] = nil 
    
    TriggerClientEvent('ejj_prison:jailStatusChanged', source, false)
    TriggerClientEvent('ejj_prison:restoreOriginalClothes', source)
    
    TriggerPrisonAlarm()
    
    TriggerClientEvent('ejj_prison:notify', source, locale('server_escaped_success'), 'success')
end)

RegisterNetEvent('ejj_prison:pickupResource', function(resourceType)
    local source = source
    local xPlayer = GetPlayer(source)
    
    if not xPlayer then return end
    
    local jailTime = CheckJailTime(source)
    if jailTime <= 0 then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_not_in_jail'), 'error')
        return
    end
    
    local validResources = {}
    for _, resource in pairs(Config.Crafting.resources) do
        table.insert(validResources, resource.item)
    end
    
    local isValid = false
    for _, valid in ipairs(validResources) do
        if valid == resourceType then
            isValid = true
            break
        end
    end
    
    if not isValid then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_invalid_resource'), 'error')
        return
    end
    
    local success = AddItem(source, resourceType, 1)
    if success then
        local resourceName = resourceType:gsub('_', ' '):gsub('^%l', string.upper)
        TriggerClientEvent('ejj_prison:notify', source, locale('server_picked_up', resourceName), 'success')
    else
        TriggerClientEvent('ejj_prison:notify', source, locale('server_inventory_full_pickup'), 'error')
    end
end)

lib.callback.register('ejj_prison:craftItem', function(source, recipeId)
    local xPlayer = GetPlayer(source)
    
    if not xPlayer then return false end
    
    local jailTime = CheckJailTime(source)
    if jailTime <= 0 then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_not_in_jail'), 'error')
        return false
    end
    
    local recipe = Config.Crafting.recipes[recipeId]
    if not recipe then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_invalid_recipe'), 'error')
        return false
    end
    
    local hasIngredients = true
    for ingredient, requiredAmount in pairs(recipe.ingredients) do
        local itemCount = GetItemCount(source, ingredient)
        if itemCount < requiredAmount then
            hasIngredients = false
            break
        end
    end
    
    if not hasIngredients then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_missing_ingredients'), 'error')
        return false
    end
    
    for ingredient, requiredAmount in pairs(recipe.ingredients) do
        RemoveItem(source, ingredient, requiredAmount)
    end
    
    local success = AddItem(source, recipe.result.item, recipe.result.count)
    if success then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_crafted_item', recipe.label), 'success')
        return true
    else
        TriggerClientEvent('ejj_prison:notify', source, locale('server_inventory_full_craft'), 'error')
        for ingredient, requiredAmount in pairs(recipe.ingredients) do
            AddItem(source, ingredient, requiredAmount)
        end
        return false
    end
end)

exports('UnjailPlayer', function(playerId)
    local xPlayer = GetPlayer(playerId)
    
    if not xPlayer then
        return false
    end
    
    SetJailTime(GetIdentifier(playerId), 0, playerId)
    
    SetEntityCoords(GetPlayerPed(playerId), Config.Locations.release.x, Config.Locations.release.y, Config.Locations.release.z)
    SetEntityHeading(GetPlayerPed(playerId), Config.Locations.release.w or 0.0)
    
    TriggerClientEvent('ejj_prison:restoreOriginalClothes', playerId)
    TriggerClientEvent('ejj_prison:notify', playerId, locale('server_released_from_jail'), 'success')
    
    return true
end)

RegisterNetEvent('hospital:server:SetDeathStatus', function(deathStatus)
    local source = source
    
    local jailTime = CheckJailTime(source)
    if jailTime > 0 then
        TriggerClientEvent('ejj_prison:setDeathStatus', source, deathStatus)
    end
end)

RegisterNetEvent('ejj_prison:jailPlayerExport', function(playerId, jailTime)
    local source = source
    
    if not IsPlayerPolice(source) then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_no_permission_jail_export'), 'error')
        return
    end
    
    if not playerId or not jailTime or jailTime <= 0 then
        return
    end
    
    exports['ejj_prison']:JailPlayer(playerId, jailTime)
end)

RegisterNetEvent('ejj_prison:unjailPlayerExport', function(playerId)
    local source = source
    
    if not IsPlayerPolice(source) then
        TriggerClientEvent('ejj_prison:notify', source, locale('server_no_permission_unjail_export'), 'error')
        return
    end
    
    if not playerId then
        return
    end
    
    exports['ejj_prison']:UnjailPlayer(playerId)
end)

RegisterNetEvent('ejj_prison:checkOfflineTime', function()
    if not Config.OfflineTimeServing then
        return
    end
    
    local source = source
    local xPlayer = GetPlayer(source)
    
    if not xPlayer then return end
    
    local identifier = GetIdentifier(source)
    
    local result = MySQL.query.await('SELECT time, UNIX_TIMESTAMP(date) as start_time FROM ejj_prison WHERE identifier = ?', {
        identifier
    })
    
    if result and result[1] and result[1].time > 0 then
        local originalTime = result[1].time
        local startTime = result[1].start_time
        local currentTime = os.time()
        
        local offlineTimeElapsed = math.floor((currentTime - startTime) / 60)
        local remainingTime = math.max(0, originalTime - offlineTimeElapsed)
        
        if remainingTime <= 0 then
            SetJailTime(identifier, 0, source)
            TriggerClientEvent('ejj_prison:notify', source, locale('server_served_offline_time'), 'success')
        else
            MySQL.query.await('UPDATE ejj_prison SET time = ?, date = NOW() WHERE identifier = ?', {
                remainingTime, identifier
            })
            
            jailedPlayers[identifier] = remainingTime
            jailStartTimes[identifier] = currentTime
            
            if offlineTimeElapsed > 0 then
                TriggerClientEvent('ejj_prison:notify', source, locale('server_offline_time_served', offlineTimeElapsed, remainingTime), 'info')
            end
        end
    end
end)