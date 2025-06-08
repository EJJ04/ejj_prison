# EJJ Prison System

A comprehensive FiveM prison system with escape mechanics, job system, crafting, and full localization support.

## Features

- **Complete Prison System**: Jail/unjail players with time-based sentences
- **Prison Jobs**: Cooking, electrical work, and training with minigames
- **Escape System**: Dig tunnels with shovels and escape through hidden passages
- **Crafting System**: Craft tools using prison resources
- **Alarm System**: Distance-based prison alarms when players escape
- **Shop System**: Purchase items within the prison
- **Multi-Language Support**: 8 languages (English, Danish, German, Spanish, Swedish, Japanese, Norwegian, Portuguese)
- **Framework Support**: ESX, QBCore, and QBX compatible

## Installation

1. Add `ejj_prison` to your server resources folder
2. Add `ensure ejj_prison` to your server.cfg
3. Configure the resource in `config.lua`
4. Import the SQL table (automatically created on first run)

## Configuration

Edit `config.lua` to customize:
- Prison locations and zones
- Job rewards and locations
- Escape mechanics and timing
- Shop items and prices
- Dispatch system integration
- Localization settings

## Exports

### Server Exports

#### JailPlayer
Jail a player for a specified amount of time.

**Usage:**
```lua
exports['ejj_prison']:JailPlayer(playerId, jailTime)
```

**Parameters:**
- `playerId` (number): The server ID of the player to jail
- `jailTime` (number): Time in minutes to jail the player

**Returns:**
- `boolean`: `true` if successful, `false` if failed

**Example:**
```lua
-- Jail player with ID 1 for 30 minutes
local success = exports['ejj_prison']:JailPlayer(1, 30)
if success then
    print("Player jailed successfully")
else
    print("Failed to jail player")
end
```

#### UnjailPlayer
Release a player from jail immediately.

**Usage:**
```lua
exports['ejj_prison']:UnjailPlayer(playerId)
```

**Parameters:**
- `playerId` (number): The server ID of the player to unjail

**Returns:**
- `boolean`: `true` if successful, `false` if failed

**Example:**
```lua
-- Release player with ID 1 from jail
local success = exports['ejj_prison']:UnjailPlayer(1)
if success then
    print("Player released successfully")
else
    print("Failed to release player")
end
```

### Client Exports

#### JailPlayer (Client-side)
Trigger a jail command from client-side (requires police permissions).

**Usage:**
```lua
exports['ejj_prison']:JailPlayer(playerId, jailTime)
```

**Parameters:**
- `playerId` (number): The server ID of the player to jail
- `jailTime` (number): Time in minutes to jail the player

**Returns:**
- `boolean`: `true` if command was sent, `false` if no permission

**Example:**
```lua
-- Client-side jail command (only works for police)
local success = exports['ejj_prison']:JailPlayer(1, 45)
if success then
    print("Jail command sent")
else
    print("No permission or invalid parameters")
end
```

#### UnjailPlayer (Client-side)
Trigger an unjail command from client-side (requires police permissions).

**Usage:**
```lua
exports['ejj_prison']:UnjailPlayer(playerId)
```

**Parameters:**
- `playerId` (number): The server ID of the player to unjail

**Returns:**
- `boolean`: `true` if command was sent, `false` if no permission

**Example:**
```lua
-- Client-side unjail command (only works for police)
local success = exports['ejj_prison']:UnjailPlayer(1)
if success then
    print("Unjail command sent")
else
    print("No permission or invalid parameters")
end
```

#### IsPlayerJailed
Check if the current player is in jail.

**Usage:**
```lua
exports['ejj_prison']:IsPlayerJailed()
```

**Returns:**
- `boolean`: `true` if player is jailed, `false` if not

**Example:**
```lua
-- Check if current player is in jail
local isJailed = exports['ejj_prison']:IsPlayerJailed()
if isJailed then
    print("You are currently in jail")
else
    print("You are not in jail")
end
```

#### GetJailTime
Get the current player's remaining jail time.

**Usage:**
```lua
exports['ejj_prison']:GetJailTime()
```

**Returns:**
- `number`: Remaining jail time in minutes (0 if not jailed)

**Example:**
```lua
-- Get current player's remaining jail time
local timeRemaining = exports['ejj_prison']:GetJailTime()
if timeRemaining > 0 then
    print("Time remaining: " .. timeRemaining .. " minutes")
else
    print("You are not in jail")
end
```

## Usage Examples

### MDT Integration (Server-side)
```lua
-- Example MDT jail function
RegisterCommand('mdt_jail', function(source, args)
    local playerId = tonumber(args[1])
    local jailTime = tonumber(args[2])
    
    if playerId and jailTime then
        local success = exports['ejj_prison']:JailPlayer(playerId, jailTime)
        if success then
            print("Player " .. playerId .. " jailed for " .. jailTime .. " minutes")
        end
    end
end, true)
```

### Police Menu Integration (Client-side)
```lua
-- Example police menu jail option
RegisterNetEvent('police:openJailMenu')
AddEventHandler('police:openJailMenu', function(targetId)
    local input = lib.inputDialog('Jail Player', {
        {type = 'number', label = 'Time (minutes)', required = true, min = 1, max = 999}
    })
    
    if input then
        local jailTime = input[1]
        exports['ejj_prison']:JailPlayer(targetId, jailTime)
    end
end)
```

### Automatic Status Check (Client-side)
```lua
-- Check jail status periodically
CreateThread(function()
    while true do
        local jailTime = exports['ejj_prison']:GetJailTime()
        if jailTime > 0 then
            -- Player is jailed, update UI or restrict actions
            print("Jail time remaining: " .. jailTime .. " minutes")
        end
        Wait(60000) -- Check every minute
    end
end)
```

### Event-based Integration
```lua
-- Server-side: Listen for custom jail events
RegisterNetEvent('myresource:jailPlayer')
AddEventHandler('myresource:jailPlayer', function(targetId, time, reason)
    local success = exports['ejj_prison']:JailPlayer(targetId, time)
    if success then
        -- Log the jail action
        print(GetPlayerName(targetId) .. " jailed for " .. time .. " minutes. Reason: " .. reason)
    end
end)
```

## Commands

- `/jail [id] [time]` - Jail a player (police only)
- `/unjail [id]` - Unjail a player (police only)
- `/jailstatus [id]` - Check jail status (police only)
- `/resettunnel` - Reset escape tunnel (admin only)

## Dependencies

- **ox_lib** - Required for UI, zones, and callbacks
- **Framework** - ESX, QBCore, or QBX
- **Database** - MySQL (table created automatically)

## Configuration Options

### Key Settings
- `Config.Framework` - Your server framework ('esx', 'qbcore', 'qbx')
- `Config.Menu` - Menu system ('ox_lib', 'esx', 'qbcore')
- `Config.TextUIPosition` - TextUI position ('right-center', 'left-center', etc.)
- `Config.Dispatch` - Dispatch system integration
- `Config.MinigameTries` - Number of skill checks required

### Locations
- Prison spawn point and release location
- Job interaction points (cooking, electrical, training)
- Resource gathering locations
- Escape tunnel coordinates

### Job System
- Configurable job rewards (time reduction)
- Minigame difficulty settings
- Job cooldown periods

### Escape System
- Tunnel reset timing
- Required items for digging
- Alarm system settings
- Dispatch integration

## Support

For support, bug reports, or feature requests, please contact the resource author or check the resource documentation.

## License

This resource is provided as-is. Please respect the author's work and any licensing terms. 