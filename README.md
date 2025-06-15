# EJJ Prison

A simple and flexible prison system for FiveM servers. Lock up those troublemakers and let them serve their time!

## Features

- 🚔 Multiple prison locations (Bolingbroke, Paleto, and more!)
- ⏱️ Configurable jail times
- 👮‍♂️ Police-only commands (configurable)
- 🏃‍♂️ Automatic teleportation to prison
- 🎮 Prison activities to pass the time
- 🔄 Framework support (ESX, QB, QBX)
- 🌍 Multi-language support
- 📝 Detailed logging system
- 🤖 NPC/AI jail system support
- 🔓 Configurable permission bypass

## Installation

1. Download the resource
2. Drop it in your resources folder
3. Add `ensure ejj_prison` to your server.cfg
4. Configure the `config.lua` file to your liking
5. Restart your server

## Commands

- `/jail [id] [time] [prison]` - Jail a player
- `/unjail [id]` - Unjail a player
- `/checkjail [id]` - Check a player's jail time
- `/addjailtime [id] [time]` - Add time to a player's sentence
- `/removejailtime [id] [time]` - Remove time from a player's sentence
- `/jailstatus` - Check your own jail status

## Exports

### Server Exports

The server exports can be used in multiple ways depending on your needs:

#### 1. Regular Player Usage
```lua
-- For regular player actions (requires permissions)
exports['ejj_prison']:JailPlayer(source, targetId, duration, prisonId)
exports['ejj_prison']:UnjailPlayer(source, targetId)
```

#### 2. NPC/AI System Usage (With BypassPermissions)
First, enable permission bypass in config.lua:
```lua
Config.BypassPermissions = true
```

Then you can use the exports in three different ways:

```lua
-- Method 1: Without source (recommended for NPCs/AI)
exports['ejj_prison']:JailPlayer(targetId, duration, prisonId)
exports['ejj_prison']:UnjailPlayer(targetId)

-- Example:
exports['ejj_prison']:JailPlayer(5, 30, "bolingbroke") -- Jail player 5 for 30 minutes
exports['ejj_prison']:UnjailPlayer(5) -- Unjail player 5

-- Method 2: With source = 0 (system action)
exports['ejj_prison']:JailPlayer(0, targetId, duration, prisonId)
exports['ejj_prison']:UnjailPlayer(0, targetId)

-- Method 3: With source = nil
exports['ejj_prison']:JailPlayer(nil, targetId, duration, prisonId)
exports['ejj_prison']:UnjailPlayer(nil, targetId)
```

Example in an NPC/AI script:
```lua
-- In your NPC/AI script
local targetPlayer = 3      -- The player ID to jail
local jailTime = 30        -- Time in minutes
local prison = "bolingbroke"  -- Prison ID from config (optional)

-- Simple jail without prison specified (uses first enabled prison)
exports['ejj_prison']:JailPlayer(targetPlayer, jailTime)

-- Jail with specific prison
exports['ejj_prison']:JailPlayer(targetPlayer, jailTime, prison)

-- Later, to unjail
exports['ejj_prison']:UnjailPlayer(targetPlayer)
```

#### 3. Console/System Usage
```lua
-- For console commands or system actions
exports['ejj_prison']:JailPlayer(0, targetId, duration, prisonId)
exports['ejj_prison']:UnjailPlayer(0, targetId)
```

Other server exports:
```lua
-- Check a player's jail time
exports['ejj_prison']:CheckJailTime(source, targetId)
-- Returns: number (jail time in minutes) or false

-- Add time to a player's sentence
exports['ejj_prison']:AddJailTime(source, targetId, additionalTime)
-- Returns: boolean (success)

-- Remove time from a player's sentence
exports['ejj_prison']:RemoveJailTime(source, targetId, removeTime)
-- Returns: boolean (success)
```

### Client Exports

The client exports can be used in two ways:

#### 1. Regular Usage
```lua
-- Jail a player with specific prison
exports['ejj_prison']:JailPlayer(playerId, jailTime, prisonId)
-- Example:
exports['ejj_prison']:JailPlayer(5, 30, "bolingbroke") -- Jail player 5 for 30 minutes in Bolingbroke

-- Jail a player without specifying prison (uses first enabled prison)
exports['ejj_prison']:JailPlayer(playerId, jailTime)
-- Example:
exports['ejj_prison']:JailPlayer(5, 30) -- Jail player 5 for 30 minutes in default prison

-- Unjail a player
exports['ejj_prison']:UnjailPlayer(playerId)
-- Example:
exports['ejj_prison']:UnjailPlayer(5) -- Unjail player 5
```

#### 2. NPC/AI System Usage
First, enable permission bypass in config.lua:
```lua
Config.BypassPermissions = true
```

Then you can use the client exports in your NPC/AI scripts:
```lua
-- In an NPC/AI script
local targetPlayer = 3      -- The player ID to jail
local jailTime = 30        -- Time in minutes
local prison = "bolingbroke"  -- Optional: specific prison ID

-- Jail with specific prison
exports['ejj_prison']:JailPlayer(targetPlayer, jailTime, prison)

-- Or jail using default prison
exports['ejj_prison']:JailPlayer(targetPlayer, jailTime)

-- Later, to unjail
exports['ejj_prison']:UnjailPlayer(targetPlayer)
```

All client exports return `boolean` indicating success or failure.

## Configuration

Check out `config.lua` to customize:
- Prison locations
- Jail times
- Required permissions
- Allowed jobs
- Permission bypass for NPCs/AI
- And more!

### Permission Bypass

The permission bypass system allows NPCs, AI systems, or scripts to jail players without requiring normal permissions:

1. Enable bypass in config.lua:
```lua
Config.BypassPermissions = true
```

2. This allows:
   - NPCs/AI to jail players directly
   - Scripts to use jail functions without a source
   - Automated systems to manage jail time
   - Custom integrations without permission requirements

3. Example use cases:
   - AI police officers that can arrest players
   - Automated jail systems
   - Anti-cheat integrations
   - Custom mission/quest systems
   - Automated moderation systems

## Support

Need help? Join our Discord: [Discord](https://discord.gg/N869PRHGfd)

## License

This resource is licensed under the MIT License. Feel free to modify and use it as you wish! 
