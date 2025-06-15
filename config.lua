Config = {}

-- Want to see debug messages in your console? Set this to true when testing stuff
Config.Debug = false

-- Which notification system should we use? Most people use ox_lib these days but you can pick 'qb' or 'esx' too
Config.Notify = 'ox_lib'

-- Which text UI system should we use for interaction prompts? Options: 'ox_lib' (modern, recommended), 'qb' (QBCore DrawText), 'esx' (ESX TextUI)
Config.TextUI = 'ox_lib'

-- Where should the text UI show up on screen? I like left-center but you can change it
-- ox_lib options: 'right-center', 'left-center', 'top-center', 'bottom-center'
-- qb options: 'left', 'right', 'top'  
-- esx doesn't support positioning (sorry ESX users!)
Config.TextUIPosition = 'left-center'

-- Which menu system to use for interactions like the shop and crafting
-- Options: 'ox_lib' (modern, recommended), 'esx' (ESX context menus), 'qb' (QB menu system)
Config.Menu = 'ox_lib'

-- Which minigame system to use for skill checks? Options: 'ox_lib' (ox_lib skillCheck), 'qb' (qb-minigames)
Config.Minigame = 'ox_lib'

-- Should players be able to serve prison time while offline? Set to true to enable offline time serving
Config.OfflineTimeServing = true

-- Set to true to bypass all permission checks (useful for NPCs/peds or custom systems)
Config.BypassPermissions = false

-- Items that players should keep when jailed (will not be removed from inventory)
-- Add item names that should remain with the player during imprisonment
Config.KeepItemsOnJail = {
    'phone', -- Mobile phone
    -- Add more items here that prisoners should keep
    -- Examples:
    -- 'wallet',
    -- 'keys',
    -- 'cigarettes',
}

Config.Permissions = {
    jail = {
        requirePolice = true,
        allowedJobs = {'police', 'sheriff'}, -- Add any jobs that should have permission
        allowedGroups = {'police', 'admin'} -- Add any groups that should have permission
    },
    unjail = {
        requirePolice = true,
        allowedJobs = {'police', 'sheriff'},
        allowedGroups = {'police', 'admin'}
    },
    check = {
        requirePolice = true,
        allowedJobs = {'police', 'sheriff'},
        allowedGroups = {'police', 'admin'}
    },
    add = {
        requirePolice = true,
        allowedJobs = {'police', 'sheriff'},
        allowedGroups = {'police', 'admin'}
    },
    remove = {
        requirePolice = true,
        allowedJobs = {'police', 'sheriff'},
        allowedGroups = {'police', 'admin'}
    }
}

-- How many skill checks do players need to complete for jobs? 3 seems fair - not too easy, not too hard
Config.MinigameTries = 1

-- The guard NPC that players interact with for jobs and stuff
Config.Guard = {
    model = 's_m_m_prisguard_01', -- What the guard looks like (prison guard model)
    radius = 3.0 -- How close players need to be to interact with him
}

-- Prison outfit configuration - what players wear when jailed
Config.PrisonClothes = {
    male = {
        { component_id = 3, drawable = 5, texture = 0 },   -- Arms
        { component_id = 4, drawable = 7, texture = 0 },   -- Pants
        { component_id = 6, drawable = 1, texture = 0 },   -- Shoes
        { component_id = 8, drawable = 15, texture = 0 },  -- Undershirt
        { component_id = 11, drawable = 5, texture = 2 }   -- Torso 
    },
    female = {
        { component_id = 3, drawable = 14, texture = 0 },   -- Arms
        { component_id = 4, drawable = 2, texture = 7 },   -- Pants 
        { component_id = 6, drawable = 49, texture = 0 },   -- Shoes 
        { component_id = 8, drawable = 15, texture = 0 },   -- Undershirt
        { component_id = 11, drawable = 73, texture = 7 }   -- Torso 
    },
    hat = { component_id = 0, drawable = -1, texture = 0 } -- No hat for prisoners
}

-- Multiple prison support - add more prisons here
Config.Prisons = {
    bolingbroke = {
        enabled = true, -- Set to false to disable this prison
        name = 'Bolingbroke Penitentiary',
        locations = {
    jail = vector4(1769.2166, 2552.5620, 45.5650, 0.0), -- Where players spawn when they get jailed
    release = vector4(1846.9674, 2585.8567, 45.6726, 269.4901), -- Where they go when released
    guard = vector4(1752.9586, 2566.7290, 44.5650, 224.2271), -- Where the guard NPC stands
    cooking = vector3(1780.8937, 2564.2419, 45.6731), -- Kitchen job location
    electrical = { -- Multiple electrical box locations around the prison
        vector3(1761.5, 2540.8, 45.67),
        vector3(1718.4652, 2527.7903, 45.5648),
        vector3(1664.8314, 2501.6807, 45.5648),
        vector3(1627.8918, 2538.4287, 45.5648),
        vector3(1724.9268, 2506.1248, 45.8069)
    },
    training = { -- Different workout equipment locations in the gym
        chinups = vector4(1746.5942, 2481.6499, 45.7407, 118.2180),
        pushups = vector4(1742.8623, 2480.6362, 45.7593, 120.2251),
        weights = vector4(1745.6586, 2483.7991, 45.7407, 208.9112),
        situps = vector4(1744.1934, 2479.4695, 45.7593, 123.2899)
            }
    },
    blip = { -- Prison blip configuration for the map
        enabled = true, -- Set to false to disable the prison blip
        coords = vector3(1845.0, 2585.0, 45.0), -- Where the blip appears on map (near release point)
        sprite = 238, -- Prison/jail icon (238 = prison icon, 60 = police station, 84 = marker)
        color = 1, -- Red color (1 = red, 2 = green, 3 = blue, 5 = yellow, 8 = orange)
        scale = 1.0, -- Size of the blip (0.5 = small, 1.0 = normal, 1.5 = large)
        name = 'Bolingbroke Penitentiary', -- Label that appears when hovering over blip
        shortRange = false -- Set to true if blip should only show when nearby, false to always show
        },
        hospital = { -- Where players go if they get hurt and need medical attention while in prison
            coords = vector4(1768.1671, 2570.3691, 45.7298, 138.9697) -- Prison medical facility
        },
        shop = { -- Prison shop where players can buy food and water while jailed
            ped = { -- The NPC that runs the shop
                model = 's_m_m_prisguard_01', -- Another prison guard
                coords = vector4(1783.2460, 2560.7188, 44.6731, 179.2982), -- Where he stands
                radius = 2.5 -- How close players need to be to shop
            },
            blip = { -- Blip configuration for the shop (only visible to jailed players)
                sprite = 52, -- Shop/store icon
                color = 2, -- Green color
                scale = 0.8, -- Medium size
                name = 'Prison Canteen' -- What appears on map
            },
            items = { -- What's available in the shop
                {
                    name = 'water', -- Item name (must match your items.lua or database)
                    label = 'Water Bottle', -- What players see
                    price = 0, -- Free water because prison
                    icon = 'fas fa-tint' -- Water drop icon
                },
                {
                    name = 'burger', -- Food item
                    label = 'Prison Burger', -- Probably not very tasty
                    price = 0, -- Also free
                    icon = 'fas fa-hamburger' -- Burger icon
                }
            }
        },
        crafting = { -- Crafting system - players collect materials to make escape tools
            prisoner = { -- The prisoner NPC who helps with crafting
                model = 's_m_y_prisoner_01', -- Prisoner model
                coords = vector4(1762.0648, 2473.6333, 44.7408, 29.9728), -- Where he hangs out
                radius = 2.0 -- How close to interact
            },
            resources = { -- Materials players can find around the prison
                metal = { -- Metal scraps
                    coords = vector3(1777.5552, 2563.5906, 45.6731), -- Location to find metal
                    radius = 1.5, -- How close to pick up
                    item = 'metal_scrap', -- Item name
                    label = 'Metal Scrap', -- Display name
                    icon = 'fas fa-cogs', -- Metal gear icon
                    object = false -- No physical object spawns (invisible pickup)
                },
                wood = { -- Wood planks
                    coords = vector4(1690.255, 2553.248, 44.268, 90.129), -- Where to find wood
                    radius = 1.5,
                    item = 'wood_plank',
                    label = 'Wood Plank',
                    icon = 'fas fa-tree', -- Tree icon
                    object = { -- Physical object that appears
                        model = 'prop_rub_planks_04', -- Wooden planks model
                        respawnTime = 30000 -- Respawns after 30 seconds
                    }
                },
                ducttape = { -- Duct tape for holding stuff together
                    coords = vector4(1753.173, 2472.894, 45.394, -50.612), -- Tape location
                    radius = 1.5,
                    item = 'duct_tape',
                    label = 'Duct Tape',
                    icon = 'fas fa-tape', -- Tape icon
                    object = {
                        model = 'prop_gaffer_tape', -- Tape roll model
                        respawnTime = 25000 -- Respawns after 25 seconds
                    }
                }
            },
            recipes = { -- What players can craft with the materials
                shovel = { -- The escape tool
                    label = 'Prison Shovel', -- What it's called
                    icon = 'fas fa-shovel', -- Shovel icon
                    ingredients = { -- What you need to make it
                        metal_scrap = 1, -- 1 metal scrap
                        wood_plank = 1, -- 1 wood plank
                        duct_tape = 1 -- 1 duct tape
                    },
                    result = { -- What you get
                        item = 'shovel', -- Shovel item
                        count = 1 -- You get one shovel
                    }
                }
            }
        },
        escape = { -- Prison escape system - the fun part! Players can dig tunnels to break out
    resetTime = 30, -- How long until tunnel disappears (minutes) - prevents permanent escapes
    digging = { -- Where players can start digging the tunnel
        coords = vector4(1774.6844, 2480.8213, 45.7408, 209.5112), -- Digging location
        radius = 1.5, -- How close they need to be
        requiredItem = 'shovel', -- What item they need to dig (crafted from materials)
        removeShovel = true, -- Should we take their shovel after digging? Set false to keep it
        animation = { -- The digging animation - looks pretty cool
            dict = 'random@burial',
            anim = 'a_burial',
            duration = 10000, -- 10 seconds of digging
            props = { -- Props that appear while digging
                {
                    bone = 28422, -- Hand bone
                    model = 'prop_tool_shovel', -- Shovel prop
                    placement = {
                        pos = vector3(0.0, 0.0, 0.24),
                        rot = vector3(0.0, 0.0, 0.0)
                    }
                },
                {
                    bone = 28422,
                    model = 'prop_ld_shovel_dirt', -- Dirt on shovel prop
                    placement = {
                        pos = vector3(0.0, 0.0, 0.24),
                        rot = vector3(0.0, 0.0, 0.0)
                    }
                }
            }
        },
        tunnelRock = { -- The rock that appears at tunnel entrance
            coords = vector3(1775.223, 2479.969, 44.557),
            model = 'prop_rock_1_i'
        }
    },
    exit = { -- Where the tunnel exits (outside prison walls)
        coords = vector4(1803.2581, 2436.7910, 45.7550, 214.3743), -- Exit location
        radius = 1.5, -- How close to get to exit
        exitRock = { -- Rock/dirt pile at tunnel exit
            coords = vector3(1803.258, 2436.791, 44.541),
            model = 'prop_rock_1_i' -- You can change this to a dirt pile model if you have one
        }
            },
    alarm = { -- Prison alarms when someone escapes
        enabled = true, -- Set false to disable alarms
        name = 'PRISON_ALARMS', -- Sound name
        duration = 60000, -- How long alarms last (60 seconds)
        maxDistance = 500.0, -- How far away you can hear them
        center = vector3(1774.6844, 2480.8213, 45.7408) -- Where sound comes from
    }
        },
        zone = { -- Prison boundary zone - this prevents players from escaping by just walking out
            enabled = true, -- Set to false if you don't want zone restrictions
            name = 'ejj_prison_zone_bolingbroke', -- Internal name for the zone
            points = { -- These points create the prison boundary - adjust for your prison layout
                vector3(1896.0, 2593.0, 46.0),
                vector3(1897.0, 2517.0, 46.0),
                vector3(1795.0, 2385.0, 46.0),
                vector3(1685.0, 2361.0, 46.0),
                vector3(1496.0, 2426.0, 46.0),
                vector3(1499.0, 2640.0, 46.0),
                vector3(1681.0, 2811.0, 46.0),
                vector3(1887.0, 2736.0, 46.0),
            },
            thickness = 52.0 -- How thick the boundary zone is
        }
    }
    -- Add more prisons here - they will all run simultaneously:
    -- sandy_shores = {
    --     enabled = true,
    --     name = 'Sandy Shores Correctional',
    --     locations = { ... },
    --     blip = { ... },
    --     hospital = { ... },
    --     shop = { ... },
    --     crafting = { ... },
    --     escape = { ... },
    --     zone = { ... }
    -- }
}

-- Database integration settings
Config.Database = {
    -- Column name in ejj_prison table that stores prison ID
    prisonColumn = 'prison',
    
    -- SQL queries for multi-prison support (examples for server-side implementation)
    queries = {
        -- Get player's assigned prison
        getPlayerPrison = "SELECT prison FROM ejj_prison WHERE identifier = ?",
        
        -- Set player's prison assignment
        setPlayerPrison = "UPDATE ejj_prison SET prison = ? WHERE identifier = ?",
        
        -- Get all players in a specific prison
        getPrisonPlayers = "SELECT * FROM ejj_prison WHERE prison = ? AND time > 0"
    }
}

-- Currently active prison (can be changed dynamically in the future for multi-prison support)
Config.CurrentPrison = 'bolingbroke'

-- How close players need to be to interact with job locations
Config.JobZones = {
    cooking = {
        radius = 1.0 -- Pretty close for kitchen work
    },
    electrician = {
        radius = 1.5 -- Bit more room for electrical work
    },
    training = {
        radius = 1.0 -- Close to the gym equipment
    }
}

-- Job cooldown - how long players have to wait before doing another job
-- Set this higher if people are spamming jobs, lower if you want more activity
Config.JobCooldown = 5 -- 5 minutes seems reasonable

-- How much time gets taken off their sentence for completing each job
-- Electrical work pays the most because it's harder, cooking pays least
Config.JobRewards = {
    cooking = 5, -- 5 minutes off sentence for cooking job
    electrician = 5, -- One reward for fixing all boxes (total 20 minutes off)
    training = 20 -- One reward for completing all training exercises (chinups, pushups, weights, situps)
}

-- Map blips for job locations - these show up on the map so players can find the jobs
Config.JobBlips = {
    cooking = {
        sprite = 79, -- Chef hat icon looks good for kitchen
        color = 2,   -- Green color
        scale = 0.8, -- Not too big, not too small
        name = 'Prison Kitchen'
    },
    electrician = {
        sprite = 354, -- Electrical bolt icon
        color = 5,    -- Yellow makes sense for electrical
        scale = 0.8,
        name = 'Electrical Box'
    },
    training = {
        sprite = 311, -- Gym/muscle icon
        color = 3,    -- Blue for training areas
        scale = 0.8,
        name = 'Training Area'
    }
}

-- Dispatch system settings - alerts police when someone breaks out of prison
Config.Dispatch = {
    enabled = false, -- Set to false if you don't want dispatch alerts
    system = 'cd_dispatch', -- Which dispatch system you're using - lots of options available
    -- Options: 'cd_dispatch', 'ps-dispatch', 'qs-dispatch', 'core_dispatch', 'rcore_dispatch', 'aty_dispatch', 'op-dispatch', 'origen_police', 'emergencydispatch', 'custom'
    jobs = {'police', 'sheriff'}, -- Which job names should get the alerts
    code = '10-99', -- Police radio code for prison breaks
    title = 'Prison Break', -- What shows up in the dispatch
    priority = 'high', -- How urgent the call is
    blip = { -- The blip that appears on the map
        sprite = 238, -- Prison/jail icon
        scale = 1.2, -- Bigger than normal so it stands out
        colour = 1, -- Red for danger
        flashes = true, -- Makes it flash to get attention
        time = 60, -- How long the blip stays on map (seconds)
        radius = 0, -- No radius circle
    }
}

Config.ResourcePickupAnimation = {
    dict = 'amb@prop_human_bum_bin@base',
    anim = 'base',
    duration = 3500 -- milliseconds
}

Config.JobAnimations = {
    cooking = {
        dict = 'amb@prop_human_bbq@male@base',
        anim = 'base',
        duration = 10000
    },
    electrician = {
        dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        anim = 'machinic_loop_mechandplayer',
        duration = 8000
    },
    training = {
        chinups = { dict = 'amb@prop_human_muscle_chin_ups@male@base', anim = 'base', duration = 10000 },
        pushups = { dict = 'amb@world_human_push_ups@male@base', anim = 'base', duration = 10000 },
        weights = { dict = 'amb@world_human_muscle_free_weights@male@barbell@base', anim = 'base', duration = 10000 },
        situps = { dict = 'amb@world_human_sit_ups@male@base', anim = 'base', duration = 10000 }
    }
}
