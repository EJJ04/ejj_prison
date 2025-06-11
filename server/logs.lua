local Config = {
    Webhooks = {
        Jail = "YOUR_JAIL_WEBHOOK_HERE", 
        Unjail = "YOUR_UNJAIL_WEBHOOK_HERE",
        Escape = "YOUR_ESCAPE_WEBHOOK_HERE", 
        Tunnel = "YOUR_TUNNEL_WEBHOOK_HERE", 
        Job = "YOUR_JOB_WEBHOOK_HERE",
        Crafting = "YOUR_CRAFTING_WEBHOOK_HERE", 
        Admin = "YOUR_ADMIN_WEBHOOK_HERE" 
    },
    Colors = {
        Jail = 16711680, 
        Unjail = 65280,
        Escape = 16776960, 
        Tunnel = 16711935, 
        Job = 65535, 
        Crafting = 16777215, 
        Admin = 16711680 
    }
}

local function GetCurrentTime()
    return os.date("%Y-%m-%d %H:%M:%S")
end

local function SendToDiscord(webhook, title, description, color, fields)
    local embed = {
        {
            ["title"] = title,
            ["description"] = description,
            ["type"] = "rich",
            ["color"] = color,
            ["footer"] = {
                ["text"] = "Timestamp: " .. GetCurrentTime() .. " | Server Time: " .. os.time()
            },
            ["fields"] = fields or {}
        }
    }

    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({
        username = "Prison System",
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

function LogJail(officer, target, duration, reason)
    local fields = {
        {
            ["name"] = "Officer",
            ["value"] = officer,
            ["inline"] = true
        },
        {
            ["name"] = "Prisoner",
            ["value"] = target,
            ["inline"] = true
        },
        {
            ["name"] = "Duration",
            ["value"] = duration .. " minutes",
            ["inline"] = true
        },
        {
            ["name"] = "Reason",
            ["value"] = reason or "No reason provided",
            ["inline"] = false
        }
    }

    SendToDiscord(Config.Webhooks.Jail, "Prisoner Jailed", "A new prisoner has been incarcerated", Config.Colors.Jail, fields)
end

function LogUnjail(officer, target, earlyRelease)
    local fields = {
        {
            ["name"] = "Officer",
            ["value"] = officer,
            ["inline"] = true
        },
        {
            ["name"] = "Prisoner",
            ["value"] = target,
            ["inline"] = true
        },
        {
            ["name"] = "Release Type",
            ["value"] = earlyRelease and "Early Release" or "Time Served",
            ["inline"] = true
        }
    }

    SendToDiscord(Config.Webhooks.Unjail, "Prisoner Released", "A prisoner has been released from custody", Config.Colors.Unjail, fields)
end

function LogEscapeAttempt(prisoner, success, method)
    local fields = {
        {
            ["name"] = "Prisoner",
            ["value"] = prisoner,
            ["inline"] = true
        },
        {
            ["name"] = "Status",
            ["value"] = success and "Successful" or "Failed",
            ["inline"] = true
        },
        {
            ["name"] = "Method",
            ["value"] = method or "Unknown",
            ["inline"] = true
        }
    }

    SendToDiscord(Config.Webhooks.Escape, "Escape Attempt", "A prisoner has attempted to escape", Config.Colors.Escape, fields)
end

function LogTunnelActivity(prisoner, action)
    local fields = {
        {
            ["name"] = "Prisoner",
            ["value"] = prisoner,
            ["inline"] = true
        },
        {
            ["name"] = "Action",
            ["value"] = action,
            ["inline"] = true
        }
    }

    SendToDiscord(Config.Webhooks.Tunnel, "Tunnel Activity", "Tunnel-related activity detected", Config.Colors.Tunnel, fields)
end

function LogJobCompletion(prisoner, jobType, timeReduced)
    local fields = {
        {
            ["name"] = "Prisoner",
            ["value"] = prisoner,
            ["inline"] = true
        },
        {
            ["name"] = "Job Type",
            ["value"] = jobType,
            ["inline"] = true
        },
        {
            ["name"] = "Time Reduced",
            ["value"] = timeReduced .. " minutes",
            ["inline"] = true
        }
    }

    SendToDiscord(Config.Webhooks.Job, "Job Completed", "A prisoner has completed their assigned work", Config.Colors.Job, fields)
end

function LogCrafting(prisoner, item, success)
    local fields = {
        {
            ["name"] = "Prisoner",
            ["value"] = prisoner,
            ["inline"] = true
        },
        {
            ["name"] = "Item",
            ["value"] = item,
            ["inline"] = true
        },
        {
            ["name"] = "Status",
            ["value"] = success and "Success" or "Failed",
            ["inline"] = true
        }
    }

    SendToDiscord(Config.Webhooks.Crafting, "Crafting Activity", "A prisoner has attempted to craft an item", Config.Colors.Crafting, fields)
end

function LogAdminAction(admin, action, target, details)
    local fields = {
        {
            ["name"] = "Admin",
            ["value"] = admin,
            ["inline"] = true
        },
        {
            ["name"] = "Action",
            ["value"] = action,
            ["inline"] = true
        },
        {
            ["name"] = "Target",
            ["value"] = target or "N/A",
            ["inline"] = true
        },
        {
            ["name"] = "Details",
            ["value"] = details or "No additional details",
            ["inline"] = false
        }
    }

    SendToDiscord(Config.Webhooks.Admin, "Admin Action", "An administrator has performed an action", Config.Colors.Admin, fields)
end