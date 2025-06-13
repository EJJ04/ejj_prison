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

```lua
-- Jail a player
exports['ejj_prison']:JailPlayer(source, targetId, duration, prisonId)
-- Returns: boolean (success)

-- Unjail a player
exports['ejj_prison']:UnjailPlayer(source, targetId)
-- Returns: boolean (success)

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

```lua
-- Jail a player (client-side)
exports['ejj_prison']:JailPlayer(playerId, jailTime)
-- Returns: boolean (success)

-- Unjail a player (client-side)
exports['ejj_prison']:UnjailPlayer(playerId)
-- Returns: boolean (success)
```

## Configuration

Check out `config.lua` to customize:
- Prison locations
- Jail times
- Required permissions
- Allowed jobs
- And more!

## Support

Need help? Join our Discord: [[Discord](https://discord.gg/N869PRHGfd)]

## License

This resource is licensed under the MIT License. Feel free to modify and use it as you wish! 
