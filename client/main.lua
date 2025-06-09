lib.locale()

local currentJob = nil
local jobPoints = {}
local jobBlips = {}
local resourceObjects = {}
local escapeProps = {} 
local tunnelRockObject = nil 
local exitRockObject = nil 
local hasEscaped = false 
local lastJobSelectionTime = 0 
local isDead = false
local completedElectricalBoxes = {} 

RegisterNetEvent('ejj_prison:notify', function(message, type)
    Notify(message, type)
end)

RegisterNetEvent('ejj_prison:jailStatusChanged', function(isJailed)
    if isJailed then
        SpawnResourceObjects()
        InitializeResourceSystem()
    else
        CleanupResourceObjects()
        CleanupResourcePoints() 
        lastJobSelectionTime = 0
        currentJob = nil
        ClearJobPoints()
        isDead = false
        completedElectricalBoxes = {}
    end
end)

RegisterNetEvent('ejj_prison:startAlarm', function()
    StartPrisonAlarm()
end)

RegisterNetEvent('ejj_prison:stopAlarm', function()
    StopPrisonAlarm()
end)

local guard = SpawnPed(Config.Guard.model, Config.Locations.guard)

local shopPed = SpawnPed(Config.Shop.ped.model, Config.Shop.ped.coords)

local craftingPed = SpawnPed(Config.Crafting.prisoner.model, Config.Crafting.prisoner.coords)

function SpawnResourceObjects()
    for resourceKey, resourceConfig in pairs(Config.Crafting.resources) do
        if resourceConfig.object and resourceConfig.object ~= false then
            local object = SpawnObject(resourceConfig.object.model, resourceConfig.coords)
            SetEntityCollision(object, false, false) 
            resourceObjects[resourceKey] = object
        end
    end
end

function CleanupResourceObjects()
    for resourceKey, object in pairs(resourceObjects) do
        if DoesEntityExist(object) then
            DeleteEntity(object)
        end
    end
    resourceObjects = {}
end

function AttachEscapeProps()
    local ped = cache.ped
    for _, propConfig in ipairs(Config.Escape.digging.animation.props) do
        lib.requestModel(propConfig.model, 10000)
        while not HasModelLoaded(propConfig.model) do Wait(0) end
        
        local prop = CreateObject(propConfig.model, 0.0, 0.0, 0.0, true, true, true)
        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, propConfig.bone), 
            propConfig.placement.pos.x, propConfig.placement.pos.y, propConfig.placement.pos.z,
            propConfig.placement.rot.x, propConfig.placement.rot.y, propConfig.placement.rot.z,
            true, true, false, true, 1, true)
        
        table.insert(escapeProps, prop)
    end
end

function CleanupEscapeProps()
    for _, prop in ipairs(escapeProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
    escapeProps = {}
end

function StartDigging()
    if not IsPlayerInJail() then
        return
    end
    
    local hasItem = lib.callback.await('ejj_prison:hasItem', false, Config.Escape.digging.requiredItem)
    if not hasItem then
        Notify(locale('need_shovel'), 'error')
        return
    end
    
    AttachEscapeProps()
    lib.playAnim(cache.ped, Config.Escape.digging.animation.dict, Config.Escape.digging.animation.anim, 8.0, 8.0, Config.Escape.digging.animation.duration, 1, 0, false, false, false)
    
    local success = StartMinigame()
    
    ClearPedTasksImmediately(cache.ped)
    CleanupEscapeProps()
    
    if success then
        TriggerServerEvent('ejj_prison:tunnelDug')
        Notify(locale('tunnel_dug_success'), 'success')
    else
        Notify(locale('tunnel_dig_failed'), 'error')
    end
end

function EscapeThroughTunnel()
    if not IsPlayerInJail() then
        return
    end
    
    SetEntityCoords(cache.ped, Config.Escape.exit.coords.x, Config.Escape.exit.coords.y, Config.Escape.exit.coords.z)
    SetEntityHeading(cache.ped, Config.Escape.exit.coords.w)
    
    exitRockObject = SpawnObject(Config.Escape.exit.exitRock.model, Config.Escape.exit.exitRock.coords)
    
    hasEscaped = true
    TriggerServerEvent('ejj_prison:playerEscaped')
    
    local playerName = cache.ped and GetPlayerName(cache.playerId) or 'Unknown'
    PoliceDispatch({
        coords = Config.Escape.digging.coords,
        playerName = playerName
    })
    
    Notify(locale('escaped_success'), 'success')
end

function StartPrisonAlarm()
    if not Config.Escape.alarm.enabled then
        return
    end
    
    local playerCoords = GetEntityCoords(cache.ped)
    local distance = #(playerCoords - Config.Escape.alarm.center)
    
    if distance > Config.Escape.alarm.maxDistance then
        return
    end
    
    PrepareAlarm(Config.Escape.alarm.name)
    
    local timeout = 0
    while not PrepareAlarm(Config.Escape.alarm.name) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end
    
    if PrepareAlarm(Config.Escape.alarm.name) then
        StartAlarm(Config.Escape.alarm.name, -1)
    end
end

function StopPrisonAlarm()
    if not Config.Escape.alarm.enabled then
        return
    end
    
    StopAlarm(Config.Escape.alarm.name, true)
end

local guardPoint = lib.points.new({
    coords = Config.Locations.guard,
    distance = Config.Guard.radius
})

function guardPoint:onEnter()
    ShowTextUI(locale('ui_talk_guard'))
end

function guardPoint:onExit()
    HideTextUI()
end

function guardPoint:nearby()
    if IsControlJustReleased(0, 38) then 
        HandleGuardInteraction()
    end
end

function HandleGuardInteraction()
    if not IsPlayerInJail() then
        return
    end
    
    ShowMenu({
        id = 'prison_guard_menu',
        title = locale('menu_prison_guard'),
        items = {
            {
                title = locale('menu_check_jail_time'),
                description = locale('desc_check_jail_time'),
                icon = 'fas fa-clock',
                onSelect = function()
                    local jailTime = lib.callback.await('ejj_prison:getJailTime', false)
                    Notify(locale('remaining_jail_time_info', jailTime), 'info')
                end
            },
            {
                title = locale('menu_view_jobs'),
                description = locale('desc_view_jobs'),
                icon = 'fas fa-briefcase',
                onSelect = function()
                    ShowJobsMenu()
                end
            }
        }
    })
end

function ShowJobsMenu()
    local menuItems = {}
    
    local currentTime = GetGameTimer()
    local timeSinceLastJob = currentTime - lastJobSelectionTime
    local cooldownMs = Config.JobCooldown * 60 * 1000 
    local isOnCooldown = timeSinceLastJob < cooldownMs and lastJobSelectionTime > 0
    
    if isOnCooldown then
        local remainingTime = math.ceil((cooldownMs - timeSinceLastJob) / 1000)
        table.insert(menuItems, {
            title = locale('job_cooldown_active', remainingTime),
            description = locale('job_cooldown_wait'),
            icon = 'fas fa-clock',
            disabled = true
        })
    end
    
    table.insert(menuItems, {
        title = locale('cooking_job_title'),
        description = locale('cooking_desc'),
        icon = 'fas fa-utensils',
        disabled = isOnCooldown,
        onSelect = function()
            if not isOnCooldown then
                SelectJob('cooking')
            end
        end
    })
    
    table.insert(menuItems, {
        title = locale('electrical_work_title'),
        description = locale('electrician_desc'),
        icon = 'fas fa-bolt',
        disabled = isOnCooldown,
        onSelect = function()
            if not isOnCooldown then
                SelectJob('electrician')
            end
        end
    })
    
    table.insert(menuItems, {
        title = locale('training_title'),
        description = locale('training_desc'),
        icon = 'fas fa-dumbbell',
        disabled = isOnCooldown,
        onSelect = function()
            if not isOnCooldown then
                SelectJob('training')
            end
        end
    })
    
    ShowMenu({
        id = 'prison_jobs_menu',
        title = locale('menu_prison_jobs'),
        items = menuItems
    })
end

local shopPoint = lib.points.new({
    coords = Config.Shop.ped.coords,
    distance = Config.Shop.ped.radius
})

function shopPoint:onEnter()
    if IsPlayerInJail() then
        ShowTextUI(locale('ui_prison_shop'))
    end
end

function shopPoint:onExit()
    HideTextUI()
end

function shopPoint:nearby()
    if IsControlJustReleased(0, 38) then 
        HandleShopInteraction()
    end
end

function HandleShopInteraction()
    if not IsPlayerInJail() then
        return
    end
    
    local shopItems = {}
    for _, item in ipairs(Config.Shop.items) do
        shopItems[#shopItems + 1] = {
            title = item.label,
            description = item.price > 0 and locale('shop_item_price', item.price) or locale('shop_item_free'),
            icon = item.icon,
            onSelect = function()
                TriggerServerEvent('ejj_prison:buyItem', item.name, item.price)
            end
        }
    end
    
    ShowMenu({
        id = 'prison_shop_menu',
        title = locale('prison_shop'),
        items = shopItems
    })
end

local resourcePickupCounts = {}
local resourcePoints = {}

function InitializeResourceSystem()
    resourcePickupCounts = {}
    
    local shovelRecipe = Config.Crafting.recipes.shovel
    if shovelRecipe and shovelRecipe.ingredients then
        for ingredient, maxAmount in pairs(shovelRecipe.ingredients) do
            resourcePickupCounts[ingredient] = {
                current = 0,
                max = maxAmount
            }
        end
    end
    
    CreateResourcePoints()
end

function CreateResourcePoints()
    for _, point in pairs(resourcePoints) do
        if point and point.remove then
            point:remove()
        end
    end
    resourcePoints = {}
    
    if resourcePickupCounts['metal_scrap'] and resourcePickupCounts['metal_scrap'].current < resourcePickupCounts['metal_scrap'].max then
        resourcePoints.metal = lib.points.new({
            coords = Config.Crafting.resources.metal.coords,
            distance = Config.Crafting.resources.metal.radius
        })

        function resourcePoints.metal:onEnter()
            if IsPlayerInJail() then
                local remaining = resourcePickupCounts['metal_scrap'].max - resourcePickupCounts['metal_scrap'].current
                ShowTextUI(locale('ui_pickup_metal') .. ' (' .. remaining .. ' left)')
            end
        end

        function resourcePoints.metal:onExit()
            HideTextUI()
        end

        function resourcePoints.metal:nearby()
            if IsControlJustReleased(0, 38) then 
                if not IsPlayerInJail() then
                    return
                end
                
                if resourcePickupCounts['metal_scrap'].current >= resourcePickupCounts['metal_scrap'].max then
                    Notify(locale('resource_limit_reached_metal'), 'error')
                    return
                end
                
                lib.playAnim(cache.ped, 'amb@prop_human_bum_bin@idle_b', 'idle_d', 8.0, 8.0, 3000, 1, 0, false, false, false)
                
                Wait(3000)
                
                resourcePickupCounts['metal_scrap'].current = resourcePickupCounts['metal_scrap'].current + 1
                
                TriggerServerEvent('ejj_prison:pickupResource', Config.Crafting.resources.metal.item)
                ClearPedTasksImmediately(cache.ped)
                
                if resourcePickupCounts['metal_scrap'].current >= resourcePickupCounts['metal_scrap'].max then
                    self:remove()
                    resourcePoints.metal = nil
                end
            end
        end
    end
    
    if resourcePickupCounts['wood_plank'] and resourcePickupCounts['wood_plank'].current < resourcePickupCounts['wood_plank'].max then
        resourcePoints.wood = lib.points.new({
            coords = vector3(Config.Crafting.resources.wood.coords.x, Config.Crafting.resources.wood.coords.y, Config.Crafting.resources.wood.coords.z),
            distance = Config.Crafting.resources.wood.radius
        })

        function resourcePoints.wood:onEnter()
            if IsPlayerInJail() and resourceObjects['wood'] and DoesEntityExist(resourceObjects['wood']) then
                local remaining = resourcePickupCounts['wood_plank'].max - resourcePickupCounts['wood_plank'].current
                ShowTextUI(locale('ui_pickup_wood') .. ' (' .. remaining .. ' left)')
            end
        end

        function resourcePoints.wood:onExit()
            HideTextUI()
        end

        function resourcePoints.wood:nearby()
            if IsControlJustReleased(0, 38) then 
                if not IsPlayerInJail() then
                    return
                end
                
                if resourcePickupCounts['wood_plank'].current >= resourcePickupCounts['wood_plank'].max then
                    Notify(locale('resource_limit_reached_wood'), 'error')
                    return
                end
                
                if not resourceObjects['wood'] or not DoesEntityExist(resourceObjects['wood']) then
                    Notify(locale('no_wood_planks'), 'error')
                    return
                end
                
                lib.playAnim(cache.ped, 'amb@prop_human_bum_bin@idle_b', 'idle_d', 8.0, 8.0, 3000, 1, 0, false, false, false)
                
                Wait(3000)
                
                DeleteEntity(resourceObjects['wood'])
                resourceObjects['wood'] = nil
                
                resourcePickupCounts['wood_plank'].current = resourcePickupCounts['wood_plank'].current + 1
                
                TriggerServerEvent('ejj_prison:pickupResource', Config.Crafting.resources.wood.item)
                ClearPedTasksImmediately(cache.ped)
                
                if resourcePickupCounts['wood_plank'].current >= resourcePickupCounts['wood_plank'].max then
                    self:remove()
                    resourcePoints.wood = nil
                else
                    SetTimeout(Config.Crafting.resources.wood.object.respawnTime, function()
                        if not resourceObjects['wood'] or not DoesEntityExist(resourceObjects['wood']) then
                            local object = SpawnObject(Config.Crafting.resources.wood.object.model, Config.Crafting.resources.wood.coords)
                            SetEntityCollision(object, false, false)
                            resourceObjects['wood'] = object
                        end
                    end)
                end
            end
        end
    end
    
    if resourcePickupCounts['duct_tape'] and resourcePickupCounts['duct_tape'].current < resourcePickupCounts['duct_tape'].max then
        resourcePoints.ducttape = lib.points.new({
            coords = vector3(Config.Crafting.resources.ducttape.coords.x, Config.Crafting.resources.ducttape.coords.y, Config.Crafting.resources.ducttape.coords.z),
            distance = Config.Crafting.resources.ducttape.radius
        })

        function resourcePoints.ducttape:onEnter()
            if IsPlayerInJail() and resourceObjects['ducttape'] and DoesEntityExist(resourceObjects['ducttape']) then
                local remaining = resourcePickupCounts['duct_tape'].max - resourcePickupCounts['duct_tape'].current
                ShowTextUI(locale('ui_pickup_tape') .. ' (' .. remaining .. ' left)')
            end
        end

        function resourcePoints.ducttape:onExit()
            HideTextUI()
        end

        function resourcePoints.ducttape:nearby()
            if IsControlJustReleased(0, 38) then 
                if not IsPlayerInJail() then
                    return
                end
                
                if resourcePickupCounts['duct_tape'].current >= resourcePickupCounts['duct_tape'].max then
                    Notify(locale('resource_limit_reached_tape'), 'error')
                    return
                end
                
                if not resourceObjects['ducttape'] or not DoesEntityExist(resourceObjects['ducttape']) then
                    Notify(locale('no_duct_tape'), 'error')
                    return
                end
                
                lib.playAnim(cache.ped, 'amb@prop_human_bum_bin@idle_b', 'idle_d', 8.0, 8.0, 3000, 1, 0, false, false, false)
                
                Wait(3000)
                
                DeleteEntity(resourceObjects['ducttape'])
                resourceObjects['ducttape'] = nil
                
                resourcePickupCounts['duct_tape'].current = resourcePickupCounts['duct_tape'].current + 1
                
                TriggerServerEvent('ejj_prison:pickupResource', Config.Crafting.resources.ducttape.item)
                ClearPedTasksImmediately(cache.ped)
                
                if resourcePickupCounts['duct_tape'].current >= resourcePickupCounts['duct_tape'].max then
                    self:remove()
                    resourcePoints.ducttape = nil
                else
                    SetTimeout(Config.Crafting.resources.ducttape.object.respawnTime, function()
                        if not resourceObjects['ducttape'] or not DoesEntityExist(resourceObjects['ducttape']) then
                            local object = SpawnObject(Config.Crafting.resources.ducttape.object.model, Config.Crafting.resources.ducttape.coords)
                            SetEntityCollision(object, false, false)
                            resourceObjects['ducttape'] = object
                        end
                    end)
                end
            end
        end
    end
end

function CleanupResourcePoints()
    for _, point in pairs(resourcePoints) do
        if point and point.remove then
            point:remove()
        end
    end
    resourcePoints = {}
    resourcePickupCounts = {}
end

local craftingPoint = lib.points.new({
    coords = vector3(Config.Crafting.prisoner.coords.x, Config.Crafting.prisoner.coords.y, Config.Crafting.prisoner.coords.z),
    distance = Config.Crafting.prisoner.radius
})

function craftingPoint:onEnter()
    if IsPlayerInJail() then
        ShowTextUI(locale('ui_talk_prisoner'))
    end
end

function craftingPoint:onExit()
    HideTextUI()
end

function craftingPoint:nearby()
    if IsControlJustReleased(0, 38) then
        HandleCraftingInteraction()
    end
end

local diggingPoint = lib.points.new({
    coords = vector3(Config.Escape.digging.coords.x, Config.Escape.digging.coords.y, Config.Escape.digging.coords.z),
    distance = Config.Escape.digging.radius
})

function diggingPoint:onEnter()
    if IsPlayerInJail() and not tunnelRockObject then
        ShowTextUI(locale('ui_dig_tunnel'))
    end
end

function diggingPoint:onExit()
    HideTextUI()
end

function diggingPoint:nearby()
    if IsControlJustReleased(0, 38) then 
        if not tunnelRockObject then
            StartDigging()
        end
    end
end

local tunnelRockPoint = lib.points.new({
    coords = Config.Escape.digging.tunnelRock.coords,
    distance = 1.5
})

function tunnelRockPoint:onEnter()
    if IsPlayerInJail() and tunnelRockObject and DoesEntityExist(tunnelRockObject) then
        ShowTextUI(locale('ui_escape_tunnel'))
    end
end

function tunnelRockPoint:onExit()
    HideTextUI()
end

function tunnelRockPoint:nearby()
    if IsControlJustReleased(0, 38) then 
        if tunnelRockObject and DoesEntityExist(tunnelRockObject) then
            EscapeThroughTunnel()
        end
    end
end

function HandleCraftingInteraction()
    if not IsPlayerInJail() then
        return
    end
    
    local inventory = lib.callback.await('ejj_prison:getPlayerInventory', false)
    ShowCraftingMenu(inventory)
end

function ShowCraftingMenu(playerInventory)
    local craftingItems = {}
    
    for recipeId, recipe in pairs(Config.Crafting.recipes) do
        local ingredientText = "Ingredients: "
        local ingredientList = {}
        
        for ingredient, requiredAmount in pairs(recipe.ingredients) do
            local playerAmount = 0
            if playerInventory then
                for _, item in pairs(playerInventory) do
                    if item and item.name == ingredient then
                        playerAmount = item.count or 0
                        break
                    end
                end
            end
            
            local resourceKey = ingredient:gsub("_scrap", ""):gsub("_plank", "wood"):gsub("_tape", "ducttape")
            local resourceLabel = Config.Crafting.resources[resourceKey] and Config.Crafting.resources[resourceKey].label or ingredient
            table.insert(ingredientList, requiredAmount .. "x " .. resourceLabel .. " (" .. playerAmount .. "/" .. requiredAmount .. ")")
        end
        
        ingredientText = ingredientText .. table.concat(ingredientList, ", ")
        
        craftingItems[#craftingItems + 1] = {
            title = recipe.label,
            description = ingredientText,
            icon = recipe.icon,
            onSelect = function()
                lib.callback('ejj_prison:craftItem', false, function(success)
                    if success then
                        CloseMenu()
                    end
                end, recipeId)
            end
        }
    end
    
    ShowMenu({
        id = 'crafting_menu',
        title = locale('menu_crafting'),
        items = craftingItems
    })
end

function SelectJob(jobType)
    if not IsPlayerInJail() then return end
    
    local currentTime = GetGameTimer()
    local timeSinceLastJob = currentTime - lastJobSelectionTime
    local cooldownMs = Config.JobCooldown * 60 * 1000 
    
    if timeSinceLastJob < cooldownMs and lastJobSelectionTime > 0 then
        local remainingTime = math.ceil((cooldownMs - timeSinceLastJob) / 1000)
        Notify(locale('job_cooldown_active', remainingTime), 'error')
        return
    end
    
    ClearJobPoints()
    
    currentJob = jobType
    lastJobSelectionTime = currentTime 
    CreateJobPoints(jobType)
            Notify(locale('job_selected'), 'success')
end

function CreateJobPoints(jobType)
    if jobType == 'cooking' then
        local blip = CreateJobBlip(Config.Locations.cooking, jobType)
        if blip then
            jobBlips[#jobBlips + 1] = blip
        end
        
        local point = lib.points.new({
            coords = Config.Locations.cooking,
            distance = Config.JobZones.cooking.radius
        })
        
        function point:onEnter()
            ShowTextUI(locale('ui_start_cooking'))
            if blip and DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
        end
        
        function point:nearby()
            if IsControlJustReleased(0, 38) then 
                StartCookingWork()
            end
        end
        
        function point:onExit()
            HideTextUI()
        end
        
        jobPoints[#jobPoints + 1] = point
        
    elseif jobType == 'electrician' then
        if Config.Locations.electrical then
            for i, coords in ipairs(Config.Locations.electrical) do
                local blip = CreateJobBlip(coords, jobType, locale('blip_electrical_box', i))
                if blip then
                    jobBlips[#jobBlips + 1] = blip
                end
                
                local point = lib.points.new({
                    coords = coords,
                    distance = Config.JobZones.electrician.radius
                })
                
                point.boxIndex = i
                point.blip = blip
                
                function point:onEnter()
                    if not completedElectricalBoxes[self.boxIndex] then
                        ShowTextUI(locale('ui_fix_electrical'))
                    end
                end
                
                function point:nearby()
                    if IsControlJustReleased(0, 38) and not completedElectricalBoxes[self.boxIndex] then 
                        StartElectricalWork(self.boxIndex, self.blip)
                    end
                end
                
                function point:onExit()
                    HideTextUI()
                end
                
                jobPoints[#jobPoints + 1] = point
            end
        end
        
    elseif jobType == 'training' then
        if Config.Locations.training then
            local chinupsBlip = CreateJobBlip(Config.Locations.training.chinups, jobType, locale('blip_chinups_station'))
            if chinupsBlip then
                jobBlips[#jobBlips + 1] = chinupsBlip
            end
            
            local chinupsPoint = lib.points.new({
                coords = Config.Locations.training.chinups,
                distance = Config.JobZones.training.radius
            })
            
            function chinupsPoint:onEnter()
                ShowTextUI(locale('ui_chinups'))
                if chinupsBlip and DoesBlipExist(chinupsBlip) then
                    RemoveBlip(chinupsBlip)
                end
            end
            
            function chinupsPoint:nearby()
                if IsControlJustReleased(0, 38) then 
                    StartChinupsWork()
                end
            end
            
            function chinupsPoint:onExit()
                HideTextUI()
            end
            
            jobPoints[#jobPoints + 1] = chinupsPoint
            
            local pushupsBlip = CreateJobBlip(Config.Locations.training.pushups, jobType, locale('blip_pushups_station'))
            if pushupsBlip then
                jobBlips[#jobBlips + 1] = pushupsBlip
            end
            
            local pushupsPoint = lib.points.new({
                coords = Config.Locations.training.pushups,
                distance = Config.JobZones.training.radius
            })
            
            function pushupsPoint:onEnter()
                ShowTextUI(locale('ui_pushups'))
                if pushupsBlip and DoesBlipExist(pushupsBlip) then
                    RemoveBlip(pushupsBlip)
                end
            end
            
            function pushupsPoint:nearby()
                if IsControlJustReleased(0, 38) then 
                    StartPushupsWork()
                end
            end
            
            function pushupsPoint:onExit()
                HideTextUI()
            end
            
            jobPoints[#jobPoints + 1] = pushupsPoint
            
            local weightsBlip = CreateJobBlip(Config.Locations.training.weights, jobType, locale('blip_weights_station'))
            if weightsBlip then
                jobBlips[#jobBlips + 1] = weightsBlip
            end
            
            local weightsPoint = lib.points.new({
                coords = Config.Locations.training.weights,
                distance = Config.JobZones.training.radius
            })
            
            function weightsPoint:onEnter()
                ShowTextUI(locale('ui_weights'))
                if weightsBlip and DoesBlipExist(weightsBlip) then
                    RemoveBlip(weightsBlip)
                end
            end
            
            function weightsPoint:nearby()
                if IsControlJustReleased(0, 38) then 
                    StartWeightsWork()
                end
            end
            
            function weightsPoint:onExit()
                HideTextUI()
            end
            
            jobPoints[#jobPoints + 1] = weightsPoint
            
            local situpsBlip = CreateJobBlip(Config.Locations.training.situps, jobType, locale('blip_situps_station'))
            if situpsBlip then
                jobBlips[#jobBlips + 1] = situpsBlip
            end
            
            local situpsPoint = lib.points.new({
                coords = Config.Locations.training.situps,
                distance = Config.JobZones.training.radius
            })
            
            function situpsPoint:onEnter()
                ShowTextUI(locale('ui_situps'))
                if situpsBlip and DoesBlipExist(situpsBlip) then
                    RemoveBlip(situpsBlip)
                end
            end
            
            function situpsPoint:nearby()
                if IsControlJustReleased(0, 38) then 
                    StartSitupsWork()
                end
            end
            
            function situpsPoint:onExit()
                HideTextUI()
            end
            
            jobPoints[#jobPoints + 1] = situpsPoint
        end
    end
end

function CreateJobBlip(coords, jobType, customName)
    local blipConfig = Config.JobBlips[jobType]
    if not blipConfig then return nil end
    
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, blipConfig.sprite)
    SetBlipColour(blip, blipConfig.color)
    SetBlipScale(blip, blipConfig.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(customName or blipConfig.name)
    EndTextCommandSetBlipName(blip)
    
    return blip
end

function ClearJobBlips()
    for _, blip in ipairs(jobBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    jobBlips = {}
end

function ClearJobPoints()
    for _, point in ipairs(jobPoints) do
        point:remove()
    end
    jobPoints = {}
    ClearJobBlips()
    HideTextUI()
    
    completedElectricalBoxes = {}
end

function StartCookingWork()
    TaskStartScenarioInPlace(cache.ped, 'PROP_HUMAN_BBQ', 0, true)
    
    local success = StartMinigame()
    TriggerServerEvent('ejj_prison:jobResult', 'cooking', success)
    
    ClearPedTasksImmediately(cache.ped)
    if success then
        ClearJobPoints()
        currentJob = nil
    end
end

function StartElectricalWork(boxIndex, blip)
    TaskStartScenarioInPlace(cache.ped, 'WORLD_HUMAN_WELDING', 0, true)
    
    local success = StartMinigame()
    
    ClearPedTasksImmediately(cache.ped)
    
    if success then
        completedElectricalBoxes[boxIndex] = true
        
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
        
        local totalBoxes = #Config.Locations.electrical
        local completedCount = 0
        for i = 1, totalBoxes do
            if completedElectricalBoxes[i] then
                completedCount = completedCount + 1
            end
        end
        
        if completedCount >= totalBoxes then
            TriggerServerEvent('ejj_prison:jobResult', 'electrician', true)
            ClearJobPoints()
            currentJob = nil
            Notify(locale('skill_check_completed', completedCount, totalBoxes), 'success')
        else
            Notify(locale('skill_check_completed', completedCount, totalBoxes), 'info')
        end
    else
        Notify(locale('job_failed'), 'error')
    end
end

function StartChinupsWork()
    local coords = Config.Locations.training.chinups
    SetEntityCoords(cache.ped, coords.x, coords.y, coords.z)
    SetEntityHeading(cache.ped, coords.w)
    TaskStartScenarioInPlace(cache.ped, 'PROP_HUMAN_MUSCLE_CHIN_UPS', 0, true)
    
    local success = StartMinigame()
    TriggerServerEvent('ejj_prison:jobResult', 'training', success)
    
    ClearPedTasksImmediately(cache.ped)
    if success then
        ClearJobPoints()
        currentJob = nil
    end
end

function StartPushupsWork()
    local coords = Config.Locations.training.pushups
    SetEntityCoords(cache.ped, coords.x, coords.y, coords.z)
    SetEntityHeading(cache.ped, coords.w)
    lib.playAnim(cache.ped, 'amb@world_human_push_ups@male@idle_a', 'idle_d', 8.0, 8.0, -1, 1, 0, false, false, false)
    
    local success = StartMinigame()
    TriggerServerEvent('ejj_prison:jobResult', 'training', success)
    
    ClearPedTasksImmediately(cache.ped)
    if success then
        ClearJobPoints()
        currentJob = nil
    end
end

function StartWeightsWork()
    local coords = Config.Locations.training.weights
    SetEntityCoords(cache.ped, coords.x, coords.y, coords.z)
    SetEntityHeading(cache.ped, coords.w)
    
    local prop = CreateObject("prop_curl_bar_01", coords.x, coords.y, coords.z, true, true, true)
    AttachEntityToEntity(prop, cache.ped, GetPedBoneIndex(cache.ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    
    lib.playAnim(cache.ped, 'amb@world_human_muscle_free_weights@male@barbell@base', 'base', 8.0, 8.0, -1, 1, 0, false, false, false)
    
    local success = StartMinigame()
    TriggerServerEvent('ejj_prison:jobResult', 'training', success)
    
    ClearPedTasksImmediately(cache.ped)
    DeleteEntity(prop)
    if success then
        ClearJobPoints()
        currentJob = nil
    end
end

function StartSitupsWork()
    local coords = Config.Locations.training.situps
    SetEntityCoords(cache.ped, coords.x, coords.y, coords.z)
    SetEntityHeading(cache.ped, coords.w)
    lib.playAnim(cache.ped, 'amb@world_human_sit_ups@male@idle_a', 'idle_a', 8.0, 8.0, -1, 1, 0, false, false, false)
    
    local success = StartMinigame()
    TriggerServerEvent('ejj_prison:jobResult', 'training', success)
    
    ClearPedTasksImmediately(cache.ped)
    if success then
        ClearJobPoints()
        currentJob = nil
    end
end

function IsPlayerInJail()
    local jailTime = lib.callback.await('ejj_prison:getJailTime', false)
    if jailTime <= 0 then
        return false
    end
    return true
end

function TeleportToPrisonHospital()
    if not IsPlayerInJail() then
        return
    end
    
    local hospitalCoords = Config.Hospital.coords
    
    SetEntityCoords(cache.ped, hospitalCoords.x, hospitalCoords.y, hospitalCoords.z)
    SetEntityHeading(cache.ped, hospitalCoords.w)
    
    Notify(locale('teleported_prison_hospital'), 'info')
end

local prisonZone = nil
if Config.PrisonZone.enabled then
    prisonZone = lib.zones.poly({
        name = Config.PrisonZone.name,
        points = Config.PrisonZone.points,
        thickness = Config.PrisonZone.thickness,
        debug = Config.Debug,
        onExit = function(self)
            if isDead then
                return
            end
            
            local jailTime = lib.callback.await('ejj_prison:getJailTime', false)
            if jailTime > 0 then
                SetEntityCoords(cache.ped, Config.Locations.jail.x, Config.Locations.jail.y, Config.Locations.jail.z)
                SetEntityHeading(cache.ped, Config.Locations.jail.w or 0.0)
                
                Notify(locale('cannot_escape_prison', jailTime), 'error')
            end
        end
    })
end

RegisterNetEvent('ejj_prison:createTunnelRock', function()
    if not tunnelRockObject then
        tunnelRockObject = SpawnObject(Config.Escape.digging.tunnelRock.model, Config.Escape.digging.tunnelRock.coords)
    end
end)

RegisterNetEvent('ejj_prison:removeTunnelRock', function()
    if tunnelRockObject and DoesEntityExist(tunnelRockObject) then
        DeleteEntity(tunnelRockObject)
        tunnelRockObject = nil
    end
    
    if exitRockObject and DoesEntityExist(exitRockObject) then
        DeleteEntity(exitRockObject)
        exitRockObject = nil
    end
    
    hasEscaped = false
end)

RegisterNetEvent('ejj_prison:syncTunnelState', function(tunnelExists)
    if tunnelExists and not tunnelRockObject then
        tunnelRockObject = SpawnObject(Config.Escape.digging.tunnelRock.model, Config.Escape.digging.tunnelRock.coords)
    elseif not tunnelExists and tunnelRockObject then
        if DoesEntityExist(tunnelRockObject) then
            DeleteEntity(tunnelRockObject)
            tunnelRockObject = nil
        end
    end
end)

RegisterNetEvent('ejj_prison:changeToPrisonClothes', function()
    ChangeClothes("prison")
end)

RegisterNetEvent('ejj_prison:restoreOriginalClothes', function()
    ChangeClothes("restore")
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        ClearJobPoints()
        if tunnelRockObject and DoesEntityExist(tunnelRockObject) then
            DeleteEntity(tunnelRockObject)
        end
        if exitRockObject and DoesEntityExist(exitRockObject) then
            DeleteEntity(exitRockObject)
        end
        if prisonZone then
            prisonZone:remove()
        end
    end
end)

AddEventHandler('esx:onPlayerDeath', function(data)
    local jailTime = lib.callback.await('ejj_prison:getJailTime', false)
    if jailTime > 0 then
        isDead = true
    end
end)

AddEventHandler('esx:onPlayerSpawn', function()
    local jailTime = lib.callback.await('ejj_prison:getJailTime', false)
    if jailTime > 0 then
        isDead = false
        TeleportToPrisonHospital()
    end
end)

RegisterNetEvent('ejj_prison:setDeathStatus', function(deathStatus)
    local jailTime = lib.callback.await('ejj_prison:getJailTime', false)
    if jailTime > 0 then
        if deathStatus then
            isDead = true
        else
            isDead = false
            TeleportToPrisonHospital()
        end
    end
end)

exports('JailPlayer', function(playerId, jailTime)
    if not IsPlayerPolice() then
        Notify(locale('no_permission_jail'), 'error')
        return false
    end
    
    if not playerId then
        return false
    end
    
    if not jailTime or jailTime <= 0 then
        return false
    end
    
    TriggerServerEvent('ejj_prison:jailPlayerExport', playerId, jailTime)
    return true
end)

exports('UnjailPlayer', function(playerId)
    if not IsPlayerPolice() then
        Notify(locale('no_permission_unjail'), 'error')
        return false
    end
    
    if not playerId then
        return false
    end
    
    TriggerServerEvent('ejj_prison:unjailPlayerExport', playerId)
    return true
end)

exports('IsPlayerJailed', function()
    return IsPlayerInJail()
end)

exports('GetJailTime', function()
    return lib.callback.await('ejj_prison:getJailTime', false)
end)