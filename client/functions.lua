function SpawnPed(model, coords)
    lib.requestModel(model, 10000)
    while not HasModelLoaded(model) do Wait(0) end
    local ped = CreatePed(4, model, coords.x, coords.y, coords.z, coords.w, false, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    return ped
end

function SpawnObject(model, coords)
    lib.requestModel(model, 10000)
    while not HasModelLoaded(model) do Wait(0) end
    local object = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(object, coords.w)
    FreezeEntityPosition(object, true)
    return object
end

function StartMinigame()
    local totalTries = Config.MinigameTries or 1
    
    if Config.Minigame == 'ox_lib' then
        local difficulties = {'easy', 'medium', 'hard'}
        
        for i = 1, totalTries do
            local success = lib.skillCheck(difficulties)
            
            if not success then
                return false 
            end
            
            if i < totalTries then
                Wait(500)
            end
        end
        
        return true
        
    elseif Config.Minigame == 'qb' then
        for i = 1, totalTries do
            local difficulty = 'medium'
            local keys = 'wasd'
            local success = exports['qb-minigames']:Skillbar(difficulty, keys)
            
            if not success then
                return false
            end
            
            if i < totalTries then
                Wait(500)
            end
        end
        
        return true
    else
        local difficulties = {'easy', 'medium', 'hard'}
        
        for i = 1, totalTries do
            local success = lib.skillCheck(difficulties)
            
            if not success then
                return false 
            end
            
            if i < totalTries then
                Wait(500)
            end
        end
        
        return true
    end
end

function PoliceDispatch(data)
    if not Config.Dispatch.enabled then
        return
    end
    
    if not data then 
        print('^1[ejj_prison ERROR]: Failed to retrieve dispatch data, cannot proceed^0') 
        return 
    end
    
    local coords = data.coords or Config.Escape.digging.coords
    local message = locale('dispatch_prison_break_message', data.playerName or 'Unknown')
    local title = Config.Dispatch.code .. ' - ' .. Config.Dispatch.title
    
    if Config.Dispatch.system == 'cd_dispatch' then
        local playerData = exports['cd_dispatch']:GetPlayerInfo()
        if not playerData then
            print('^1[ejj_prison ERROR]: cd_dispatch failed to return playerData, cannot proceed^0')
            return
        end
        TriggerServerEvent('cd_dispatch:AddNotification', {
            job_table = Config.Dispatch.jobs,
            coords = coords,
            title = title,
            message = message,
            flash = 0,
            unique_id = playerData.unique_id,
            sound = 1,
            blip = {
                sprite = Config.Dispatch.blip.sprite,
                scale = Config.Dispatch.blip.scale,
                colour = Config.Dispatch.blip.colour,
                flashes = Config.Dispatch.blip.flashes,
                text = title,
                time = Config.Dispatch.blip.time,
                radius = Config.Dispatch.blip.radius,
            }
        })
        
    elseif Config.Dispatch.system == 'ps-dispatch' then
        local alert = {
            coords = coords,
            message = message,
            dispatchCode = Config.Dispatch.code,
            description = Config.Dispatch.title,
            radius = Config.Dispatch.blip.radius,
            sprite = Config.Dispatch.blip.sprite,
            color = Config.Dispatch.blip.colour,
            scale = Config.Dispatch.blip.scale,
            length = Config.Dispatch.blip.time / 20 
        }
        exports["ps-dispatch"]:CustomAlert(alert)
        
    elseif Config.Dispatch.system == 'qs-dispatch' then
        local playerData = exports['qs-dispatch']:GetPlayerInfo()
        if not playerData then
            print('^1[ejj_prison ERROR]: qs-dispatch failed to return playerData, cannot proceed^0')
            return
        end
        exports['qs-dispatch']:getSSURL(function(image)
            TriggerServerEvent('qs-dispatch:server:CreateDispatchCall', {
                job = Config.Dispatch.jobs,
                callLocation = coords,
                callCode = { code = Config.Dispatch.code, snippet = Config.Dispatch.title },
                message = message,
                flashes = Config.Dispatch.blip.flashes,
                image = image or nil,
                blip = {
                    sprite = Config.Dispatch.blip.sprite,
                    scale = Config.Dispatch.blip.scale,
                    colour = Config.Dispatch.blip.colour,
                    flashes = Config.Dispatch.blip.flashes,
                    text = title,
                    time = (Config.Dispatch.blip.time * 1000),
                }
            })
        end)
        
    elseif Config.Dispatch.system == 'core_dispatch' then
        local gender = IsPedMale(cache.ped) and 'male' or 'female'
        TriggerServerEvent('core_dispatch:addCall', Config.Dispatch.code, Config.Dispatch.title,
        {{icon = 'fa-venus-mars', info = gender}},
        {coords.x, coords.y, coords.z},
        'police', Config.Dispatch.blip.time * 1000, Config.Dispatch.blip.sprite, Config.Dispatch.blip.colour, Config.Dispatch.blip.flashes)
        
    elseif Config.Dispatch.system == 'rcore_dispatch' then
        local playerData = exports['rcore_dispatch']:GetPlayerData()
        if not playerData then
            print('^1[ejj_prison ERROR]: rcore_dispatch failed to return playerData, cannot proceed^0')
            return
        end
        local alert = {
            code = title,
            default_priority = Config.Dispatch.priority,
            coords = coords,
            job = Config.Dispatch.jobs,
            text = message,
            type = 'alerts',
            blip_time = Config.Dispatch.blip.time,
            blip = {
                sprite = Config.Dispatch.blip.sprite,
                colour = Config.Dispatch.blip.colour,
                scale = Config.Dispatch.blip.scale,
                text = title,
                flashes = Config.Dispatch.blip.flashes,
                radius = Config.Dispatch.blip.radius,
            }
        }
        TriggerServerEvent('rcore_dispatch:server:sendAlert', alert)
        
    elseif Config.Dispatch.system == 'aty_dispatch' then
        TriggerEvent('aty_dispatch:SendDispatch', Config.Dispatch.title, Config.Dispatch.code, Config.Dispatch.blip.sprite, Config.Dispatch.jobs)
        
    elseif Config.Dispatch.system == 'op-dispatch' then
        local job = 'police'
        local text = message
        local id = cache.serverId
        local panic = false
        TriggerServerEvent('Opto_dispatch:Server:SendAlert', job, title, text, coords, panic, id)
        
    elseif Config.Dispatch.system == 'origen_police' then
        local alert = {
            coords = coords,
            title = title,
            type = 'GENERAL',
            message = message,
            job = 'police',
        }
        TriggerServerEvent("SendAlert:police", alert)
        
    elseif Config.Dispatch.system == 'emergencydispatch' then
        TriggerServerEvent('emergencydispatch:emergencycall:new', 'police', title, coords, true)
        
    elseif Config.Dispatch.system == 'custom' then
        -- Add your custom dispatch system here
        -- You can access: coords, message, title, Config.Dispatch settings 
    else
        print('^1[ejj_prison ERROR]: No dispatch system was detected - please check Config.Dispatch.system^0')
    end
end

function CompleteJob(jobType)
    if not Config.JobRewards[jobType] then
        return false
    end

    TriggerServerEvent('ejj_prison:complete' .. jobType:gsub("^%l", string.upper) .. 'Job')
    return true
end

function IsPlayerInJail()
    local jailTime = lib.callback.await('ejj_prison:getJailTime', false)
    return jailTime > 0
end

function Notify(message, type, length)
    if Config.Notify == 'ox_lib' then
        lib.notify({
            description = message,
            type = type
        })
    elseif Config.Notify == 'qb' then
        local qbType = type or 'primary'
        if type == 'info' then
            qbType = 'primary'
        elseif type == 'warn' then
            qbType = 'warning'
        elseif type == 'success' then
            qbType = 'success'
        elseif type == 'error' then
            qbType = 'error'
        else
            qbType = 'primary'
        end
        
        QBCore.Functions.Notify(message, qbType, length or 5000)
    elseif Config.Notify == 'esx' then
        ESX.ShowNotification(message)
    end
end

function ShowTextUI(text, position)
    local uiPosition = position or Config.TextUIPosition
    
    if Config.TextUI == 'ox_lib' then
        lib.showTextUI(text, {
            position = uiPosition or 'right-center',
            icon = 'fa-solid fa-circle-info'
        })
    elseif Config.TextUI == 'qb' then
        exports['qb-core']:DrawText(text, uiPosition or 'left')
    elseif Config.TextUI == 'esx' then
        ESX.TextUI(text, 'info')
    end
end

function HideTextUI()
    if Config.TextUI == 'ox_lib' then
        lib.hideTextUI()
    elseif Config.TextUI == 'qb' then
        exports['qb-core']:HideText()
    elseif Config.TextUI == 'esx' then
        exports['esx_textui']:HideUI()
    end
end

function Menu(menuData)
    if Config.Menu == 'ox_lib' then
        if menuData.register then
            lib.registerContext(menuData.data)
        end
        if menuData.show then
            lib.showContext(menuData.data.id)
        end
    elseif Config.Menu == 'qb' then
        if menuData.show then
            local qbMenuItems = {}
            
            if menuData.data.title then
                table.insert(qbMenuItems, {
                    header = menuData.data.title,
                    isMenuHeader = true
                })
            end
            
            if menuData.data.options then
                for _, option in ipairs(menuData.data.options) do
                    local qbItem = {
                        header = option.title,
                        txt = option.description,
                        icon = option.icon,
                        disabled = option.disabled,
                        hidden = option.hidden
                    }
                    
                    if option.onSelect then
                        qbItem.action = option.onSelect
                    end
                    
                    table.insert(qbMenuItems, qbItem)
                end
            end
            
            exports['qb-menu']:openMenu(qbMenuItems)
        end
    elseif Config.Menu == 'esx' then
        if menuData.show then
            ESX.UI.Menu.Open('default', GetCurrentResourceName(), menuData.data.id, {
                title = menuData.data.title,
                align = 'top-left',
                elements = menuData.data.options
            }, function(data, menu)
                if data.current.onSelect then
                    data.current.onSelect()
                end
            end, function(data, menu)
                menu.close()
            end)
        end
    end
end

function ShowMenu(options)
    local menuType = Config.Menu or 'ox_lib'
    
    if menuType == 'ox_lib' then
        ShowOxLibMenu(options)
    elseif menuType == 'esx' then
        ShowESXMenu(options)
    elseif menuType == 'qb' then
        ShowQBMenu(options)
    end
end

function ShowOxLibMenu(options)
    local contextOptions = {}
    
    for _, option in ipairs(options.items) do
        local contextOption = {
            title = option.title,
            description = option.description,
            icon = option.icon,
            disabled = option.disabled,
            menu = option.menu,
            arrow = option.arrow,
            metadata = option.metadata,
            image = option.image,
            progress = option.progress,
            colorScheme = option.colorScheme
        }
        
        if option.onSelect then
            contextOption.onSelect = function()
                option.onSelect(option)
            end
        elseif option.event then
            contextOption.event = option.event
            contextOption.args = option.args
        elseif option.serverEvent then
            contextOption.serverEvent = option.serverEvent
            contextOption.args = option.args
        end
        
        table.insert(contextOptions, contextOption)
    end
    
    lib.registerContext({
        id = options.id,
        title = options.title,
        menu = options.menu,
        canClose = options.canClose ~= false,
        onExit = options.onExit,
        onBack = options.onBack,
        options = contextOptions
    })
    
    lib.showContext(options.id)
end

function ShowESXMenu(options)
    local elements = {}
    
    for _, option in ipairs(options.items) do
        local element = {
            unselectable = option.disabled or false,
            disabled = option.disabled or false,
            icon = option.icon or '',
            title = option.title,
            description = option.description,
            input = option.input or false,
            inputType = option.inputType,
            inputPlaceholder = option.inputPlaceholder,
            inputValue = option.inputValue,
            inputMin = option.inputMin,
            inputMax = option.inputMax,
            name = option.name or option.title
        }
        
        table.insert(elements, element)
    end
    
    ESX.OpenContext(options.position or 'right', elements, function(menu, element)
        for _, option in ipairs(options.items) do
            if (option.name or option.title) == element.name then
                if option.onSelect then
                    option.onSelect(option, element)
                elseif option.event then
                    TriggerEvent(option.event, option.args)
                elseif option.serverEvent then
                    TriggerServerEvent(option.serverEvent, option.args)
                end
                break
            end
        end
    end, options.onClose)
end

function ShowQBMenu(options)
    local menuData = {}
    
    if options.title then
        table.insert(menuData, {
            header = options.title,
            isMenuHeader = true,
            txt = ""
        })
    end
    
    for _, option in ipairs(options.items) do
        local menuItem = {
            header = option.title or "",
            txt = option.description or "",
            icon = option.icon,
            isMenuHeader = false,
            disabled = option.disabled or false,
            hidden = option.hidden or false
        }
        
        if option.onSelect then
            menuItem.action = function()
                option.onSelect(option)
            end
        elseif option.event or option.serverEvent then
            menuItem.params = {
                event = option.event or option.serverEvent,
                args = option.args or {},
                isServer = option.serverEvent and true or false,
                isCommand = false,
                isQBCommand = false,
                isAction = false
            }
        end
        
        table.insert(menuData, menuItem)
    end
    
    table.insert(menuData, {
        header = "Close",
        icon = "fas fa-times",
        params = {
            event = "qb-menu:closeMenu"
        }
    })
    
    exports['qb-menu']:openMenu(menuData)
end

function CloseMenu()
    local menuType = Config.Menu or 'ox_lib'
    
    if menuType == 'ox_lib' then
        lib.hideContext()
    elseif menuType == 'esx' then
        ESX.CloseContext()
    elseif menuType == 'qb' then
        exports['qb-menu']:closeMenu()
    end
end

function GetOpenMenu()
    local menuType = Config.Menu or 'ox_lib'
    
    if menuType == 'ox_lib' then
        return lib.getOpenContextMenu()
    end
    
    return nil
end

function HasPermission(action)
    local playerData = GetPlayerData()
    if not playerData then return false end
    
    local config = Config.Permissions[action]
    if not config then return false end
    
    if not config.requirePolice then return true end
    
    if Framework == 'esx' then
        if playerData.job and playerData.job.name then
            for _, allowedJob in ipairs(config.allowedJobs) do
                if playerData.job.name == allowedJob then
                    return true
                end
            end
        end
    elseif Framework == 'qbx' then
        if playerData.job and playerData.job.name then
            for _, allowedJob in ipairs(config.allowedJobs) do
                if playerData.job.name == allowedJob then
                    return true
                end
            end
        end
    elseif Framework == 'qb' then
        if playerData.job and playerData.job.name then
            for _, allowedJob in ipairs(config.allowedJobs) do
                if playerData.job.name == allowedJob then
                    return true
                end
            end
        end
    end
    
    return false
end

function ChangeClothes(type)
    lib.requestAnimDict("clothingshirt", 10000)
    TaskPlayAnim(cache.ped, "clothingshirt", "try_shirt_positive_d", 8.0, 1.0, -1, 49, 0, 0, 0, 0)
    Wait(1000)
    
    if type == "prison" then
        if GetEntityModel(cache.ped) == GetHashKey("mp_m_freemode_01") then
            for k, v in pairs(Config.PrisonClothes.male) do
                SetPedComponentVariation(cache.ped, v.component_id, v.drawable, v.texture, 0)
            end
        else
            for k, v in pairs(Config.PrisonClothes.female) do
                SetPedComponentVariation(cache.ped, v.component_id, v.drawable, v.texture, 0)
            end
        end
        if Config.PrisonClothes.hat.drawable ~= -1 then
            SetPedPropIndex(cache.ped, Config.PrisonClothes.hat.component_id, Config.PrisonClothes.hat.drawable, Config.PrisonClothes.hat.texture, true)
        else
            ClearPedProp(cache.ped, Config.PrisonClothes.hat.component_id)
        end
    else
        if Framework == "qb" then
            TriggerServerEvent('qb-clothes:loadPlayerSkin')
        elseif Framework == "esx" then
            ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
                TriggerEvent('skinchanger:loadSkin', skin)
            end)
        elseif Framework == "qbx" then
            TriggerServerEvent('qb-clothes:loadPlayerSkin')
        else
            SetPedDefaultComponentVariation(cache.ped)
            ClearPedProp(cache.ped, 0)
        end
        
        TriggerEvent("fivem-appearance:client:reloadSkin")
        TriggerEvent("fivem-appearance:ReloadSkin")
        TriggerEvent("illenium-appearance:client:reloadSkin")
        TriggerEvent("illenium-appearance:ReloadSkin")
    end
    
    Wait(1000)
    ClearPedTasks(cache.ped)
    RemoveAnimDict("clothingshirt")
end