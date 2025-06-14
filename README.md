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
- 🤖 NPC/Ped jail system support
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

```lua
-- Jail a player
exports['ejj_prison']:JailPlayer(source, targetId, duration, prisonId)
-- Returns: boolean (success)
-- Note: source is optional. If not provided, it will be treated as a system action

-- Unjail a player
exports['ejj_prison']:UnjailPlayer(source, targetId)
-- Returns: boolean (success)
-- Note: source is optional. If not provided, it will be treated as a system action

-- Check a player's jail time
exports['ejj_prison']:CheckJailTime(source, targetId)
-- Returns: number (jail time in minutes) or false
-- Note: source is optional. If not provided, it will be treated as a system action

-- Add time to a player's sentence
exports['ejj_prison']:AddJailTime(source, targetId, additionalTime)
-- Returns: boolean (success)
-- Note: source is optional. If not provided, it will be treated as a system action

-- Remove time from a player's sentence
exports['ejj_prison']:RemoveJailTime(source, targetId, removeTime)
-- Returns: boolean (success)
-- Note: source is optional. If not provided, it will be treated as a system action
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
- Permission bypass for NPCs/peds
- And more!

### Permission Bypass

You can enable permission bypass for NPCs/peds by setting `Config.BypassPermissions = true` in your `config.lua`. This allows:
- NPCs to jail players without permission checks
- System scripts to use jail functions without a source
- Custom integrations to work without permission requirements

Example usage with NPCs:
```lua
-- From an NPC script
exports['ejj_prison']:JailPlayer(nil, targetId, duration, prisonId)

-- From console
exports['ejj_prison']:JailPlayer(0, targetId, duration, prisonId)

-- From a player script
exports['ejj_prison']:JailPlayer(source, targetId, duration, prisonId)
```

## Support

Need help? Join our Discord: [Discord](https://discord.gg/N869PRHGfd)

## License

This resource is licensed under the MIT License. Feel free to modify and use it as you wish! 