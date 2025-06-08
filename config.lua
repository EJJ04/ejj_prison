Config = {}

-- Debug mode
Config.Debug = false

-- Notification system to use ('ox_lib', 'qb', or 'esx')
Config.Notify = 'ox_lib'

-- Text UI system to use ('ox_lib', 'qb', or 'esx')
Config.TextUI = 'ox_lib'

-- TextUI Position Settings
-- ox_lib: 'right-center', 'left-center', 'top-center', 'bottom-center'
-- qb: 'left', 'right', 'top'  
-- esx: No position support
Config.TextUIPosition = 'left-center'

-- Menu system to use ('ox_lib', 'esx', or 'qb')
Config.Menu = 'ox_lib'

-- Time format for jail time display
Config.TimeFormat = 'minutes'

-- Minigame settings (applies to all activities)
Config.MinigameTries = 3 -- Number of skill checks required to succeed

-- Guard settings
Config.Guard = {
    model = 's_m_m_prisguard_01',
    radius = 3.0
}

-- Locations
Config.Locations = {
    jail = vector4(1769.2166, 2552.5620, 45.5650, 0.0),
    release = vector4(1846.9674, 2585.8567, 45.6726, 269.4901),
    guard = vector4(1752.9586, 2566.7290, 44.5650, 224.2271),
    cooking = vector3(1780.8937, 2564.2419, 45.6731), 
    electrical = {
        vector3(1761.5, 2540.8, 45.67),
        vector3(1772.3, 2564.1, 45.67),
        vector3(1785.2, 2566.9, 45.67)
    },
    training = {
        chinups = vector4(1746.5942, 2481.6499, 45.7407, 118.2180),
        pushups = vector4(1742.8623, 2480.6362, 45.7593, 120.2251),
        weights = vector4(1745.6586, 2483.7991, 45.7407, 208.9112),
        situps = vector4(1744.1934, 2479.4695, 45.7593, 123.2899)
    }
}

-- Job zones configuration
Config.JobZones = {
    cooking = {
        radius = 1.0
    },
    electrician = {
        radius = 1.5
    },
    training = {
        radius = 1.0
    }
}

-- Skill check settings for each job


-- Job configuration
Config.JobCooldown = 5 -- Cooldown in minutes before player can select a new job

-- Job rewards (jail time reduction in minutes)
Config.JobRewards = {
    cooking = 5,
    electrician = 10,
    training = 7
}

-- Job blip configuration
Config.JobBlips = {
    cooking = {
        sprite = 79, -- Chef hat icon
        color = 2,   -- Green
        scale = 0.8,
        name = 'Prison Kitchen'
    },
    electrician = {
        sprite = 354, -- Electrical icon
        color = 5,    -- Yellow
        scale = 0.8,
        name = 'Electrical Box'
    },
    training = {
        sprite = 311, -- Gym icon
        color = 3,    -- Blue
        scale = 0.8,
        name = 'Training Area'
    }
}

-- Prison zone configuration
Config.PrisonZone = {
    enabled = true,
    name = 'ejj_prison_zone',
    points = {
        vector3(1896.0, 2593.0, 46.0),
        vector3(1897.0, 2517.0, 46.0),
        vector3(1795.0, 2385.0, 46.0),
        vector3(1685.0, 2361.0, 46.0),
        vector3(1496.0, 2426.0, 46.0),
        vector3(1499.0, 2640.0, 46.0),
        vector3(1681.0, 2811.0, 46.0),
        vector3(1887.0, 2736.0, 46.0),
    },
    thickness = 52.0
}

-- Prison hospital configuration
Config.Hospital = {
    coords = vector4(1768.1671, 2570.3691, 45.7298, 138.9697) -- Prison medical facility location
}

-- Police dispatch configuration
Config.Dispatch = {
    enabled = true,
    system = 'cd_dispatch', -- Options: 'cd_dispatch', 'ps-dispatch', 'qs-dispatch', 'core_dispatch', 'rcore_dispatch', 'aty_dispatch', 'op-dispatch', 'origen_police', 'emergencydispatch', 'custom'
    jobs = {'police', 'sheriff'}, -- Police job names
    code = '10-99', -- Dispatch code for prison break
    title = 'Prison Break',
    priority = 'high',
    blip = {
        sprite = 238, -- Prison icon
        scale = 1.2,
        colour = 1, -- Red
        flashes = true,
        time = 60, -- Blip duration in seconds
        radius = 0,
    }
}

-- Prison escape configuration
Config.Escape = {
    resetTime = 30, -- Time in minutes before tunnel resets
    digging = {
        coords = vector4(1774.6844, 2480.8213, 45.7408, 209.5112),
        radius = 1.5,
        requiredItem = 'shovel',
        removeShovel = true, -- Set to false if shovel should not be removed after digging
        animation = {
            dict = 'random@burial',
            anim = 'a_burial',
            duration = 10000, -- 10 seconds
            props = {
                {
                    bone = 28422,
                    model = 'prop_tool_shovel',
                    placement = {
                        pos = vector3(0.0, 0.0, 0.24),
                        rot = vector3(0.0, 0.0, 0.0)
                    }
                },
                {
                    bone = 28422,
                    model = 'prop_ld_shovel_dirt',
                    placement = {
                        pos = vector3(0.0, 0.0, 0.24),
                        rot = vector3(0.0, 0.0, 0.0)
                    }
                }
            }
        },
        tunnelRock = {
            coords = vector3(1775.223, 2479.969, 44.557),
            model = 'prop_rock_1_i'
        }
    },
    exit = {
        coords = vector4(1803.2581, 2436.7910, 45.7550, 214.3743),
        radius = 1.5,
        exitRock = {
            coords = vector3(1803.306, 2436.779, 44.531),
            model = 'prop_rock_1_i'
        }
    },
    alarm = {
        enabled = true,
        name = 'PRISON_ALARMS',
        duration = 60000, -- 60 seconds (60000ms)
        maxDistance = 500.0, -- Max distance from prison to hear alarm
        center = vector3(1774.6844, 2480.8213, 45.7408) -- Prison center for distance calculation
    }
}

-- Prison shop configuration
Config.Shop = {
    ped = {
        model = 's_m_m_prisguard_01',
        coords = vector4(1783.2460, 2560.7188, 44.6731, 179.2982),
        radius = 2.0
    },
    items = {
        {
            name = 'water',
            label = 'Water Bottle',
            price = 0, -- Free for prisoners
            icon = 'fas fa-tint'
        },
        {
            name = 'burger',
            label = 'Prison Burger',
            price = 0, -- Free for prisoners
            icon = 'fas fa-hamburger'
        }
    }
}

-- Crafting system configuration
Config.Crafting = {
    prisoner = {
        model = 's_m_y_prisoner_01',
        coords = vector4(1762.0648, 2473.6333, 44.7408, 29.9728),
        radius = 2.0
    },
    resources = {
        metal = {
            coords = vector3(1777.5552, 2563.5906, 45.6731),
            radius = 1.5,
            item = 'metal_scrap',
            label = 'Metal Scrap',
            icon = 'fas fa-cogs',
            object = false -- No object for metal
        },
        wood = {
            coords = vector4(1690.255, 2553.248, 45.268, 90.129),
            radius = 1.5,
            item = 'wood_plank',
            label = 'Wood Plank',
            icon = 'fas fa-tree',
            object = {
                model = 'prop_rub_planks_04',
                respawnTime = 30000 -- 30 seconds respawn time
            }
        },
        ducttape = {
            coords = vector4(1753.173, 2472.894, 45.394, -50.612),
            radius = 1.5,
            item = 'duct_tape',
            label = 'Duct Tape',
            icon = 'fas fa-tape',
            object = {
                model = 'prop_gaffer_tape',
                respawnTime = 25000 -- 25 seconds respawn time
            }
        }
    },
    recipes = {
        shovel = {
            label = 'Prison Shovel',
            icon = 'fas fa-shovel',
            ingredients = {
                metal_scrap = 2,
                wood_plank = 1,
                duct_tape = 1
            },
            result = {
                item = 'shovel',
                count = 1
            }
        }
    }
}