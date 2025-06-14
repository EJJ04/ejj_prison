lib.locale()

local currentJob = nil
local jobPoints = {}
local jobBlips = {}
local resourceObjects = {}
local resourcePoints = {}
local escapeProps = {} 
local tunnelRockObject = nil 
local exitRockObject = nil 
local hasEscaped = false 
local lastJobSelectionTime = 0 
local isDead = false
local completedElectricalBoxes = {} 
local shopBlip = nil
local prisonBlips = {}
local prisonNPCs = {}
local prisonZones = {}
local currentPrison = nil
local prisonTimer = nil

function GetAllEnabledPrisons()
    local enabledPrisons = {}
    for prisonId, prisonData in pairs(Config.Prisons) do
        if prisonData.enabled then
            enabledPrisons[prisonId] = prisonData
        end
    end
    return enabledPrisons
end

function InitializePrisonSystem(prisonId)
    if not prisonId then return end
    
    currentPrison = prisonId
    
    local prisonData = Config.Prisons[prisonId]
    if not prisonData then 
        return 
    end
    
    local playerPed = PlayerPedId()
    local coords = prisonData.locations.jail
    SetEntityCoords(playerPed, coords.x, coords.y, coords.z)
    SetEntityHeading(playerPed, coords.w or 0.0)
    
    SpawnAllPrisonNPCs()
    CreatePrisonBlips()
    CreatePrisonZones()
    SpawnResourceObjects(prisonId)
    CreateShopBlip(prisonId)
    
    for prisonId, prisonData in pairs(GetAllEnabledPrisons()) do
        local guardPoint = lib.points.new({
            coords = prisonData.locations.guard,
            distance = Config.Guard.radius
        })
        
        guardPoint.prisonId = prisonId
        
        function guardPoint:onEnter()
            if currentPrison == self.prisonId then
                ShowTextUI(locale('ui_talk_guard'))
            end
        end
        
        function guardPoint:onExit()
            HideTextUI()
        end
        
        function guardPoint:nearby()
            if currentPrison == self.prisonId and IsControlJustReleased(0, 38) then
                HandleGuardInteraction(self.prisonId)
            end
        end
        
        local shopPoint = lib.points.new({
            coords = prisonData.shop.ped.coords,
            distance = prisonData.shop.ped.radius
        })
        
        shopPoint.prisonId = prisonId
        
        function shopPoint:onEnter()
            if currentPrison == self.prisonId then
                ShowTextUI(locale('ui_prison_shop'))
            end
        end
        
        function shopPoint:onExit()
            HideTextUI()
        end
        
        function shopPoint:nearby()
            if currentPrison == self.prisonId and IsControlJustReleased(0, 38) then
                HandleShopInteraction(self.prisonId)
            end
        end
        
        local craftingPoint = lib.points.new({
            coords = prisonData.crafting.prisoner.coords,
            distance = prisonData.crafting.prisoner.radius
        })
        
        craftingPoint.prisonId = prisonId
        
        function craftingPoint:onEnter()
            if currentPrison == self.prisonId then
                ShowTextUI(locale('ui_prison_crafting'))
            end
        end
        
        function craftingPoint:onExit()
            HideTextUI()
        end
        
        function craftingPoint:nearby()
            if currentPrison == self.prisonId and IsControlJustReleased(0, 38) then
                HandleCraftingInteraction(self.prisonId)
            end
        end
    end
    
    TriggerEvent('ejj_prison:client:setJailClothes')
end

local function GetAllEnabledPrisons()
    if not Config.Prisons then
        return {}
    end
    local enabled = {}
    for prisonId, prisonData in pairs(Config.Prisons) do
        if prisonData and prisonData.enabled then
            enabled[prisonId] = prisonData
        end
    end
    return enabled
end

local function GetPrisonConfig(prisonId)
    if not prisonId or not Config.Prisons or not Config.Prisons[prisonId] or not Config.Prisons[prisonId].enabled then
        return nil
    end
    return Config.Prisons[prisonId]
end

function IsPlayerInJail()
    return currentPrison ~= nil
end

function Notify(message, type)
    lib.notify({
        description = message,
        type = type or 'info'
    })
end

function ShowTextUI(text)
    lib.showTextUI(text, {
        position = Config.TextUIPosition
    })
end

function HideTextUI()
    lib.hideTextUI()
end

function ShowMenu(data)
    if not data or not data.id then return end
    
    local menuData = {
        id = data.id,
        title = data.title,
        menu = data.menu,
        canClose = data.canClose ~= false,
        onExit = data.onExit,
        onBack = data.onBack,
        options = {}
    }
    
    if data.items then
        for _, item in ipairs(data.items) do
            local option = {
                title = item.title,
                description = item.description,
                icon = item.icon,
                disabled = item.disabled,
                menu = item.menu,
                arrow = item.arrow,
                metadata = item.metadata,
                image = item.image,
                progress = item.progress,
                colorScheme = item.colorScheme
            }
            
            if item.onSelect then
                option.onSelect = function()
                    item.onSelect(item)
                end
            elseif item.event then
                option.event = item.event
                option.args = item.args
            elseif item.serverEvent then
                option.serverEvent = item.serverEvent
                option.args = item.args
            end
            
            table.insert(menuData.options, option)
        end
    end
    
    lib.registerContext(menuData)
    lib.showContext(data.id)
end

function CreateJobBlip(coords, jobType, name)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 544)
    SetBlipColour(blip, 5)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(name or locale('blip_' .. jobType))
    EndTextCommandSetBlipName(blip)
    return blip
end

function SpawnAllPrisonNPCs()
    for prisonId, prisonData in pairs(GetAllEnabledPrisons()) do
        prisonNPCs[prisonId] = {
            guard = SpawnPed(Config.Guard.model, prisonData.locations.guard),
            shopPed = SpawnPed(prisonData.shop.ped.model, prisonData.shop.ped.coords),
            craftingPed = SpawnPed(prisonData.crafting.prisoner.model, prisonData.crafting.prisoner.coords)
        }
    end
end

function CleanupAllPrisonNPCs()
    for prisonId, npcs in pairs(prisonNPCs) do
        for _, ped in pairs(npcs) do
            if DoesEntityExist(ped) then
                DeleteEntity(ped)
            end
        end
    end
    prisonNPCs = {}
end

function SpawnResourceObjects(prisonId)
    local prisonConfig = GetPrisonConfig(prisonId)
    if not prisonConfig then return end
    
    resourceObjects[prisonId] = {}
    for resourceKey, resourceConfig in pairs(prisonConfig.crafting.resources) do
        if resourceConfig.object and resourceConfig.object ~= false then
            local object = SpawnObject(resourceConfig.object.model, resourceConfig.coords)
            SetEntityCollision(object, false, false) 
            resourceObjects[prisonId][resourceKey] = object
        end
    end
end

function CleanupResourceObjects(prisonId)
    if not resourceObjects[prisonId] then return end
    
    for resourceKey, object in pairs(resourceObjects[prisonId]) do
        if DoesEntityExist(object) then
            DeleteEntity(object)
        end
    end
    resourceObjects[prisonId] = {}
end

function AttachEscapeProps(prisonId)
    local prisonConfig = GetPrisonConfig(prisonId)
    if not prisonConfig then return end
    
    local ped = cache.ped
    for _, propConfig in ipairs(prisonConfig.escape.digging.animation.props) do
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
    if not IsPlayerInJail() then return end
    
    local prisonConfig = GetPrisonConfig(currentPrison)
    if not prisonConfig then return end
    
    local hasItem = lib.callback.await('ejj_prison:hasItem', false, prisonConfig.escape.digging.requiredItem)
    if not hasItem then
        Notify(locale('need_shovel'), 'error')
        return
    end
    
    AttachEscapeProps(currentPrison)
    lib.playAnim(cache.ped, prisonConfig.escape.digging.animation.dict, prisonConfig.escape.digging.animation.anim, 8.0, 8.0, prisonConfig.escape.digging.animation.duration, 1, 0, false, false, false)
    
    local success = StartMinigame()
    
    ClearPedTasksImmediately(cache.ped)
    CleanupEscapeProps()
    
    if success then
        HideTextUI()
        TriggerServerEvent('ejj_prison:server:tunnelActivity', "Tunnel dug")
        Notify(locale('tunnel_dug_success'), 'success')
    else
        Notify(locale('tunnel_dig_failed'), 'error')
    end
end

function EscapeThroughTunnel()
    if not IsPlayerInJail() then return end
    
    local prisonConfig = GetPrisonConfig(currentPrison)
    if not prisonConfig then return end
    
    SetEntityCoords(cache.ped, prisonConfig.escape.exit.coords.x, prisonConfig.escape.exit.coords.y, prisonConfig.escape.exit.coords.z)
    SetEntityHeading(cache.ped, prisonConfig.escape.exit.coords.w)
    
    exitRockObject = SpawnObject(prisonConfig.escape.exit.exitRock.model, prisonConfig.escape.exit.exitRock.coords)
    
    hasEscaped = true
    TriggerServerEvent('ejj_prison:playerEscaped')
    
    local playerName = cache.ped and GetPlayerName(cache.playerId) or 'Unknown'
    PoliceDispatch({
        coords = prisonConfig.escape.digging.coords,
        playerName = playerName
    })
    
    Notify(locale('escaped_success'), 'success')
end

function StartPrisonAlarm(prisonId)
    local prisonConfig = GetPrisonConfig(prisonId)
    if not prisonConfig or not prisonConfig.escape.alarm.enabled then return end
    
    local playerCoords = GetEntityCoords(cache.ped)
    local distance = #(playerCoords - prisonConfig.escape.alarm.center)
    
    if distance > prisonConfig.escape.alarm.maxDistance then return end
    
    PrepareAlarm(prisonConfig.escape.alarm.name)
    
    local timeout = 0
    while not PrepareAlarm(prisonConfig.escape.alarm.name) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end
    
    if PrepareAlarm(prisonConfig.escape.alarm.name) then
        StartAlarm(prisonConfig.escape.alarm.name, -1)
    end
end

function StopPrisonAlarm()
    for prisonId, prisonData in pairs(GetAllEnabledPrisons()) do
        if prisonData.escape.alarm.enabled then
            StopAlarm(prisonData.escape.alarm.name, true)
        end
    end
end

function InitializeInteractionPoints()
    for prisonId, prisonData in pairs(GetAllEnabledPrisons()) do
        local guardPoint = lib.points.new({
            coords = prisonData.locations.guard,
            distance = Config.Guard.radius
        })
        
        guardPoint.prisonId = prisonId
        
        function guardPoint:onEnter()
            if currentPrison == self.prisonId then
                ShowTextUI(locale('ui_talk_guard'))
            end
        end
        
        function guardPoint:onExit()
            HideTextUI()
        end
        
        function guardPoint:nearby()
            if currentPrison == self.prisonId and IsControlJustReleased(0, 38) then
                HandleGuardInteraction(self.prisonId)
            end
        end
    end
end

function HandleGuardInteraction(prisonId)
    if currentPrison ~= prisonId then
        return
    end
    
    Menu({
        register = true,
        show = true,
        id = 'prison_guard_menu',
        data = {
            id = 'prison_guard_menu',
            title = locale('menu_prison_guard'),
            options = {
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
    
    Menu({
        register = true,
        show = true,
        id = 'prison_jobs_menu',
        data = {
            id = 'prison_jobs_menu',
            title = locale('menu_prison_jobs'),
            options = menuItems
        }
    })
end

function SelectJob(jobType)
    if not IsPlayerInJail() then return end
    
    local prisonConfig = GetPrisonConfig(currentPrison)
    if not prisonConfig then return end
    
    currentJob = jobType
    lastJobSelectionTime = GetGameTimer()
    
    ClearJobPoints()
    
    if jobType == 'cooking' then
        Notify(locale('job_started_cooking'), 'success')
        StartCookingJob(prisonConfig)
    elseif jobType == 'electrician' then
        Notify(locale('job_started_electrician'), 'success')
        StartElectricalJob(prisonConfig)
    elseif jobType == 'training' then
        Notify(locale('job_started_training'), 'success')
        StartTrainingJob(prisonConfig)
    end
end

function StartCookingJob(prisonConfig)
    local coords = prisonConfig.locations.cooking
    local blip = CreateJobBlip(coords, 'cooking')
    table.insert(jobBlips, blip)
    
    local point = lib.points.new({
        coords = coords,
        distance = 2.0
    })
    
    function point:onEnter()
        ShowTextUI(locale('ui_start_cooking'))
    end
    
    function point:onExit()
        HideTextUI()
    end

    function point:nearby()
        if IsControlJustReleased(0, 38) then 
            PerformCookingTask()
        end
    end
    
    table.insert(jobPoints, point)
end

function StartElectricalJob(prisonConfig)
    if not prisonConfig.locations.electrical then return end
    
    for i, coords in ipairs(prisonConfig.locations.electrical) do
        local blip = CreateJobBlip(coords, 'electrician', locale('blip_electrical_box', i))
        table.insert(jobBlips, blip)
        
        local point = lib.points.new({
            coords = coords,
            distance = 2.0
        })
        
        point.boxId = i
        
        function point:onEnter()
            if not completedElectricalBoxes[self.boxId] then
                ShowTextUI(locale('ui_fix_electrical_box'))
            end
        end

        function point:onExit()
            HideTextUI()
        end

        function point:nearby()
            if IsControlJustReleased(0, 38) and not completedElectricalBoxes[self.boxId] then
                PerformElectricalTask(self.boxId)
            end
        end
        
        table.insert(jobPoints, point)
    end
end

function StartTrainingJob(prisonConfig)
    if not prisonConfig.locations.training then return end
    
    local trainingTypes = {'chinups', 'pushups', 'weights', 'situps'}
    
    for _, trainingType in ipairs(trainingTypes) do
        local coords = prisonConfig.locations.training[trainingType]
        if coords then
            local blip = CreateJobBlip(coords, 'training', locale('blip_' .. trainingType .. '_station'))
            table.insert(jobBlips, blip)
            
            local point = lib.points.new({
                coords = coords,
                distance = 2.0
            })
            
            point.trainingType = trainingType
            
            function point:onEnter()
                ShowTextUI(locale('ui_start_' .. self.trainingType))
            end
            
            function point:onExit()
                HideTextUI()
            end

            function point:nearby()
                if IsControlJustReleased(0, 38) then 
                    PerformTrainingTask(self.trainingType, prisonConfig.locations.training[self.trainingType])
                end
            end
            
            table.insert(jobPoints, point)
        end
    end
end

function PerformCookingTask()
    local anim = Config.JobAnimations.cooking
    lib.playAnim(cache.ped, anim.dict, anim.anim, 8.0, 8.0, anim.duration, 1, 0, false, false, false)
    local success = StartMinigame()
    ClearPedTasksImmediately(cache.ped)
    if success then
        HideTextUI()
        TriggerServerEvent('ejj_prison:completeJob', 'cooking', 0)
        ClearJobPoints()
    else
        Notify(locale('cooking_failed'), 'error')
    end
end

function PerformElectricalTask(boxId)
    local anim = Config.JobAnimations.electrician
    lib.playAnim(cache.ped, anim.dict, anim.anim, 8.0, 8.0, anim.duration, 1, 0, false, false, false)
    local success = StartMinigame()
    ClearPedTasksImmediately(cache.ped)
    if success then
        HideTextUI()
        completedElectricalBoxes[boxId] = true
        RemoveBlip(jobBlips[boxId])
        local prisonConfig = GetPrisonConfig(currentPrison)
        local totalBoxes = prisonConfig and prisonConfig.locations.electrical and #prisonConfig.locations.electrical or 0
        if #completedElectricalBoxes >= totalBoxes then
            TriggerServerEvent('ejj_prison:completeJob', 'electrician', boxId)
            ClearJobPoints()
        else
            Notify(locale('electrical_box_fixed', #completedElectricalBoxes, totalBoxes), 'info')
        end
    else
        Notify(locale('electrical_repair_failed'), 'error')
    end
end

function PerformTrainingTask(trainingType, coords)
    local anim = Config.JobAnimations.training[trainingType]
    if anim then
        SetEntityCoords(cache.ped, coords.x, coords.y, coords.z)
        SetEntityHeading(cache.ped, coords.w or 0.0)
        lib.playAnim(cache.ped, anim.dict, anim.anim, 8.0, 8.0, anim.duration, 1, 0, false, false, false)
        local success = StartMinigame()
        ClearPedTasksImmediately(cache.ped)
        if success then
            HideTextUI()
            TriggerServerEvent('ejj_prison:completeJob', 'training', trainingType)
            ClearJobPoints()
        else
            Notify(locale('job_failed_training'), 'error')
        end
    end
end

function ClearJobPoints()
    for _, point in pairs(jobPoints) do
        if point.remove then
            point:remove()
        end
    end
    jobPoints = {}
    
    for _, blip in pairs(jobBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    jobBlips = {}
    
    completedElectricalBoxes = {}
end

function InitializeResourceSystem(prisonId)
    local prisonConfig = GetPrisonConfig(prisonId)
    if not prisonConfig then return end
    
    for resourceKey, resourceConfig in pairs(prisonConfig.crafting.resources) do
        local point = lib.points.new({
            coords = resourceConfig.coords,
            distance = resourceConfig.radius
        })
        
        point.resourceKey = resourceKey
        point.prisonId = prisonId
        
        function point:onEnter()
            if currentPrison == self.prisonId then
                ShowTextUI(locale('ui_pickup_resource', resourceConfig.label))
            end
        end
        
        function point:onExit()
            HideTextUI()
        end
        
        function point:nearby()
            if currentPrison == self.prisonId and IsControlJustReleased(0, 38) then
                TriggerServerEvent('ejj_prison:server:resourcePickup', resourceConfig.item)
            end
        end
        
        table.insert(resourcePoints, point)
    end
end

function CleanupResourcePoints()
    for _, point in pairs(resourcePoints) do
        if point.remove then
            point:remove()
        end
    end
    resourcePoints = {}
end

function InitializeShopSystem()
    for prisonId, prisonData in pairs(GetAllEnabledPrisons()) do
        local shopPoint = lib.points.new({
            coords = prisonData.shop.ped.coords,
            distance = prisonData.shop.ped.radius
        })
        
        shopPoint.prisonId = prisonId
        
        function shopPoint:onEnter()
            if currentPrison == self.prisonId then
                ShowTextUI(locale('ui_prison_shop'))
            end
        end
        
        function shopPoint:onExit()
            HideTextUI()
        end
        
        function shopPoint:nearby()
            if currentPrison == self.prisonId and IsControlJustReleased(0, 38) then
                HandleShopInteraction(self.prisonId)
            end
        end
    end
end

function HandleShopInteraction(prisonId)
    local prisonConfig = GetPrisonConfig(prisonId)
    if not prisonConfig then return end
    
    local menuItems = {}
    
    for _, item in ipairs(prisonConfig.shop.items) do
        table.insert(menuItems, {
            title = item.label,
            description = locale('shop_item_price', item.price),
            icon = item.icon,
            onSelect = function()
                TriggerServerEvent('ejj_prison:server:shopPurchase', item)
            end
        })
    end
    
    Menu({
        register = true,
        show = true,
        id = 'prison_shop_menu',
        data = {
            id = 'prison_shop_menu',
            title = locale('menu_prison_shop'),
            options = menuItems
        }
    })
end

function InitializeCraftingSystem()
    for prisonId, prisonData in pairs(GetAllEnabledPrisons()) do
        local craftingPoint = lib.points.new({
            coords = prisonData.crafting.prisoner.coords,
            distance = prisonData.crafting.prisoner.radius
        })
        
        craftingPoint.prisonId = prisonId
        
        function craftingPoint:onEnter()
            if currentPrison == self.prisonId then
                ShowTextUI(locale('ui_prison_crafting'))
            end
        end
        
        function craftingPoint:onExit()
            HideTextUI()
        end
        
        function craftingPoint:nearby()
            if currentPrison == self.prisonId and IsControlJustReleased(0, 38) then
                HandleCraftingInteraction(self.prisonId)
            end
        end
    end
end

function HandleCraftingInteraction(prisonId)
    local prisonConfig = GetPrisonConfig(prisonId)
    if not prisonConfig then return end
    
    local menuItems = {}
    
    for recipeId, recipe in pairs(prisonConfig.crafting.recipes) do
        local playerInventory = lib.callback.await('ejj_prison:getPlayerInventory', false)
        local canCraft = true
        local ingredientText = ""
        
        for ingredient, requiredAmount in pairs(recipe.ingredients) do
            local playerAmount = 0
            for _, item in pairs(playerInventory) do
                if item.name == ingredient then
                    playerAmount = item.count
                    break
                end
            end
            
            local resourceLabel = prisonConfig.crafting.resources[ingredient] and prisonConfig.crafting.resources[ingredient].label or ingredient
            ingredientText = ingredientText .. resourceLabel .. ": " .. playerAmount .. "/" .. requiredAmount .. "\n"
            
            if playerAmount < requiredAmount then
                canCraft = false
            end
        end
        
        table.insert(menuItems, {
            title = recipe.label,
            description = ingredientText,
            icon = recipe.icon,
            disabled = not canCraft,
            onSelect = function()
                if canCraft then
                    local success = StartMinigame()
                    if success then
                        TriggerServerEvent('ejj_prison:server:itemCraft', recipeId)
                    else
                        Notify(locale('crafting_failed'), 'error')
                    end
                end
            end
        })
    end
    
    Menu({
        register = true,
        show = true,
        id = 'prison_crafting_menu',
        data = {
            id = 'prison_crafting_menu',
            title = locale('menu_prison_crafting'),
            options = menuItems
        }
    })
end

function InitializeEscapeSystem()
    for prisonId, prisonData in pairs(GetAllEnabledPrisons()) do
        local diggingPoint = lib.points.new({
            coords = prisonData.escape.digging.coords,
            distance = prisonData.escape.digging.radius
        })
        
        diggingPoint.prisonId = prisonId
        
        function diggingPoint:onEnter()
            if currentPrison == self.prisonId then
                ShowTextUI(locale('ui_dig_tunnel'))
            end
        end
        
        function diggingPoint:onExit()
            HideTextUI()
        end
        
        function diggingPoint:nearby()
            if currentPrison == self.prisonId and IsControlJustReleased(0, 38) then
                StartDigging()
            end
        end
        
        local exitPoint = lib.points.new({
            coords = prisonData.escape.exit.coords,
            distance = prisonData.escape.exit.radius or 1.5
        })
        
        exitPoint.prisonId = prisonId
        
        function exitPoint:onEnter()
            if hasEscaped then
                ShowTextUI(locale('ui_escape_through_tunnel'))
            end
        end
        
        function exitPoint:onExit()
            HideTextUI()
        end
        
        function exitPoint:nearby()
            if hasEscaped and IsControlJustReleased(0, 38) then
                EscapeThroughTunnel()
            end
        end
    end
end

function CreatePrisonZones()
    for prisonId, prisonData in pairs(GetAllEnabledPrisons()) do
        if prisonData.zone and prisonData.zone.enabled then
            local zone = lib.zones.poly({
                name = prisonData.zone.name,
                points = prisonData.zone.points,
                thickness = prisonData.zone.thickness,
                onExit = function()
                    if currentPrison == prisonId and not hasEscaped then
                        local prisonConfig = GetPrisonConfig(prisonId)
                        if prisonConfig then
                            SetEntityCoords(cache.ped, prisonConfig.locations.jail.x, prisonConfig.locations.jail.y, prisonConfig.locations.jail.z)
                            SetEntityHeading(cache.ped, prisonConfig.locations.jail.w or 0.0)
                            Notify(locale('cannot_leave_prison'), 'error')
                        end
                    end
                end
            })
            prisonZones[prisonId] = zone
        end
    end
end

function CleanupPrisonZones()
    for prisonId, zone in pairs(prisonZones) do
        if zone and type(zone) == 'table' and zone.remove then
            zone:remove()
        end
    end
    prisonZones = {}
end

function CreatePrisonBlips()
    for prisonId, prisonData in pairs(GetAllEnabledPrisons()) do
        if prisonData.blip and prisonData.blip.enabled then
            local blip = AddBlipForCoord(prisonData.blip.coords.x, prisonData.blip.coords.y, prisonData.blip.coords.z)
            SetBlipSprite(blip, prisonData.blip.sprite or 188)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, prisonData.blip.scale or 0.8)
            SetBlipColour(blip, prisonData.blip.color or 1)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(prisonData.blip.name or "Prison")
            EndTextCommandSetBlipName(blip)
            prisonBlips[prisonId] = blip
        end
    end
end

function CreateShopBlip(prisonId)
    if shopBlip and DoesBlipExist(shopBlip) then
        RemoveBlip(shopBlip)
    end
    
    local prisonConfig = GetPrisonConfig(prisonId)
    if not prisonConfig then return end
    
    local coords = prisonConfig.shop.ped.coords
    shopBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(shopBlip, prisonConfig.shop.blip.sprite)
    SetBlipColour(shopBlip, prisonConfig.shop.blip.color)
    SetBlipScale(shopBlip, prisonConfig.shop.blip.scale)
    SetBlipAsShortRange(shopBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(prisonConfig.shop.blip.name)
    EndTextCommandSetBlipName(shopBlip)
end

function RemoveShopBlip()
    if shopBlip and DoesBlipExist(shopBlip) then
        RemoveBlip(shopBlip)
        shopBlip = nil
    end
end

function TeleportToPrison(prisonId)
    local prisonConfig = GetPrisonConfig(prisonId)
    if prisonConfig then
        SetEntityCoords(cache.ped, prisonConfig.locations.jail.x, prisonConfig.locations.jail.y, prisonConfig.locations.jail.z)
        SetEntityHeading(cache.ped, prisonConfig.locations.jail.w or 0.0)
    end
end

function TeleportToPrisonHospital()
    local prisonConfig = GetPrisonConfig(currentPrison)
    if prisonConfig and prisonConfig.hospital then
        SetEntityCoords(cache.ped, prisonConfig.hospital.coords.x, prisonConfig.hospital.coords.y, prisonConfig.hospital.coords.z)
        SetEntityHeading(cache.ped, prisonConfig.hospital.coords.w or 0.0)
    end
end

function CreateTunnel(prisonId)
    local prisonConfig = GetPrisonConfig(prisonId)
    if not prisonConfig then return end
    
    tunnelRockObject = SpawnObject(prisonConfig.escape.digging.tunnelRock.model, prisonConfig.escape.digging.tunnelRock.coords)
    
    SetTimeout(prisonConfig.escape.resetTime * 60000, function()
        if tunnelRockObject and DoesEntityExist(tunnelRockObject) then
            DeleteEntity(tunnelRockObject)
            tunnelRockObject = nil
        end
        hasEscaped = false
    end)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        ClearJobPoints()
        CleanupAllPrisonNPCs()
        CleanupPrisonZones()
        CleanupResourcePoints()
        
        if tunnelRockObject and DoesEntityExist(tunnelRockObject) then
            DeleteEntity(tunnelRockObject)
        end
        if exitRockObject and DoesEntityExist(exitRockObject) then
            DeleteEntity(exitRockObject)
        end
        
        for prisonId, blip in pairs(prisonBlips) do
            if blip and DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
        end
        RemoveShopBlip()
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

RegisterNetEvent('ejj_prison:teleportToPrison', function(prisonId)
    TeleportToPrison(prisonId)
end)

RegisterNetEvent('ejj_prison:client:setJailStatus', function(status)
    if status then
        for prisonId, prisonData in pairs(GetAllEnabledPrisons()) do
            local guardPoint = lib.points.new({
                coords = prisonData.locations.guard,
                distance = Config.Guard.radius
            })
            
            guardPoint.prisonId = prisonId
            
            function guardPoint:onEnter()
                if currentPrison == self.prisonId then
                    ShowTextUI(locale('ui_talk_guard'))
                end
            end
            
            function guardPoint:onExit()
                HideTextUI()
            end
            
            function guardPoint:nearby()
                if currentPrison == self.prisonId and IsControlJustReleased(0, 38) then
                    HandleGuardInteraction(self.prisonId)
                end
            end
            
            local shopPoint = lib.points.new({
                coords = prisonData.shop.ped.coords,
                distance = prisonData.shop.ped.radius
            })
            
            shopPoint.prisonId = prisonId
            
            function shopPoint:onEnter()
                if currentPrison == self.prisonId then
                    ShowTextUI(locale('ui_prison_shop'))
                end
            end
            
            function shopPoint:onExit()
                HideTextUI()
            end
            
            function shopPoint:nearby()
                if currentPrison == self.prisonId and IsControlJustReleased(0, 38) then
                    HandleShopInteraction(self.prisonId)
                end
            end
            
            local craftingPoint = lib.points.new({
                coords = prisonData.crafting.prisoner.coords,
                distance = prisonData.crafting.prisoner.radius
            })
            
            craftingPoint.prisonId = prisonId
            
            function craftingPoint:onEnter()
                if currentPrison == self.prisonId then
                    ShowTextUI(locale('ui_prison_crafting'))
                end
            end
            
            function craftingPoint:onExit()
                HideTextUI()
            end
            
            function craftingPoint:nearby()
                if currentPrison == self.prisonId and IsControlJustReleased(0, 38) then
                    HandleCraftingInteraction(self.prisonId)
                end
            end
        end
    else
        local points = lib.points.getAllPoints()
        if points then
            for _, point in pairs(points) do
                if point and point.remove and point.prisonId then
                    point:remove()
                end
            end
        end
    end
end)

RegisterNetEvent('ejj_prison:client:setPrisonId', function(prisonId)
    currentPrison = prisonId
    if prisonId then
        SpawnAllPrisonNPCs()
        CreatePrisonBlips()
        CreatePrisonZones()
        SpawnResourceObjects(prisonId)
        CreateShopBlip(prisonId)
    else
        CleanupAllPrisonNPCs()
        CleanupPrisonZones()
        CleanupResourceObjects(prisonId)
        RemoveShopBlip()
    end
end)

RegisterNetEvent('ejj_prison:startAlarm', function(prisonId)
    StartPrisonAlarm(prisonId)
end)

RegisterNetEvent('ejj_prison:stopAlarm', function()
    StopPrisonAlarm()
end)

RegisterNetEvent('ejj_prison:createTunnel', function(prisonId)
    CreateTunnel(prisonId)
end)

RegisterNetEvent('ejj_prison:notify', function(message, type)
    Notify(message, type)
end)

RegisterNetEvent('ejj_prison:changeToPrisonClothes', function()
    ChangeClothes('prison')
end)

RegisterNetEvent('ejj_prison:restoreOriginalClothes', function()
    ChangeClothes('restore')
end)

exports('JailPlayer', function(playerId, jailTime)
    if not Config.BypassPermissions and not HasPermission('jail') then
        lib.notify({
            title = locale('no_permission'),
            description = locale('no_permission_jail'),
            type = 'error'
        })
        return false
    end
    
    if not playerId or not jailTime or jailTime <= 0 then
        return false
    end
    
    TriggerServerEvent('ejj_prison:jailPlayerExport', playerId, jailTime)
    return true
end)

exports('UnjailPlayer', function(playerId)
    if not Config.BypassPermissions and not HasPermission('unjail') then
        lib.notify({
            title = locale('no_permission'),
            description = locale('no_permission_unjail'),
            type = 'error'
        })
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

RegisterNetEvent('ejj_prison:client:cleanupPrison', function()
    if prisonBlips then
        for prisonId, blip in pairs(prisonBlips) do
            if blip and DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
        end
        prisonBlips = {}
    end

    if shopBlip and DoesBlipExist(shopBlip) then
        RemoveBlip(shopBlip)
        shopBlip = nil
    end

    if prisonNPCs then
        for prisonId, npcs in pairs(prisonNPCs) do
            if type(npcs) == 'table' then
                for _, ped in pairs(npcs) do
                    if ped and DoesEntityExist(ped) then
                        DeleteEntity(ped)
                    end
                end
            end
        end
        prisonNPCs = {}
    end

    if prisonZones then
        for prisonId, zone in pairs(prisonZones) do
            if zone and type(zone) == 'table' and zone.remove then
                zone:remove()
            end
        end
        prisonZones = {}
    end

    if resourceObjects then
        for prisonId, objects in pairs(resourceObjects) do
            if type(objects) == 'table' then
                for _, object in pairs(objects) do
                    if object and DoesEntityExist(object) then
                        DeleteEntity(object)
                    end
                end
            end
        end
        resourceObjects = {}
    end

    local points = lib.points.getAllPoints()
    if points then
        for _, point in pairs(points) do
            if point and point.remove and point.prisonId then
                point:remove()
            end
        end
    end

    currentPrison = nil
end)

RegisterNetEvent('ejj_prison:client:setJailTime', function(time)
    jailTime = time
    if prisonTimer then
        ClearTimeout(prisonTimer)
    end
    prisonTimer = SetTimeout(time * 60 * 1000, function()
        TriggerServerEvent('ejj_prison:server:releasePlayer')
    end)
end)

RegisterNetEvent('ejj_prison:client:resetJobCooldowns', function()
    lastJobCheck = 0
    if jobCheckInterval then
        ClearTimeout(jobCheckInterval)
        jobCheckInterval = nil
    end
end)