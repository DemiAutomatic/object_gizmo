![](https://img.shields.io/github/downloads/DemiAutomatic/object_gizmo/total?logo=github)
![](https://img.shields.io/github/downloads/DemiAutomatic/object_gizmo/latest/total?logo=github)
![](https://img.shields.io/github/contributors/DemiAutomatic/object_gizmo?logo=github)
![](https://img.shields.io/github/v/release/DemiAutomatic/object_gizmo?logo=github)\
[![](https://badges.5metrics.dev/object_gizmo/serverRank.svg?style=for-the-badge)](https://5metrics.dev/resource/object_gizmo)
[![](https://badges.5metrics.dev/object_gizmo/servers.svg?style=for-the-badge)](https://5metrics.dev/resource/object_gizmo)
[![](https://badges.5metrics.dev/object_gizmo/players.svg?style=for-the-badge)](https://5metrics.dev/resource/object_gizmo)


# Object Gizmo Module

This module exports a `useGizmo` function that enables manipulation of entity position and rotation.

## Installation

1. Download the `object_gizmo` resource.
2. Extract the `object_gizmo` folder into your server's `resources` directory.
3. Add `start object_gizmo` to your server's `server.cfg` file.

## Export

`exports.object_gizmo:useGizmo(handle)`

## Usage

Ensure the `object_gizmo` module script is running on your server.

The `useGizmo` export can be used in any Lua script on the client side as follows:

```lua
local handle = --[[Your target entity]]
local result = exports.object_gizmo:useGizmo(handle)
```

`result` will contain the entity handle, final position, and final rotation.

## Test Command

This module includes a test command `testGizmo` that demonstrates how to use the gizmo.
It is only registered when `Config.debug` is `true`, and logs a warning when it is.

The command creates an object at the player's location and then activates the gizmo for that object.

```lua
local model = `prop_mp_cone_02`
RegisterCommand('testGizmo', function()
    local offset = GetEntityCoords(cache.ped) + GetEntityForwardVector(cache.ped) * 3
    lib.requestModel(model)
    local obj = CreateObject(model, offset.x, offset.y, offset.z, false, false, false)
    local data = exports.object_gizmo:useGizmo(obj)

    lib.print.info(data)
end)
```

## Locales

Set the language with the `ox:locale` convar in your `server.cfg`, e.g. `setr ox:locale "de"`.

Available: `cs`, `de`, `en`, `es`, `fr`, `it`, `nl`, `pl`, `pt-br`, `ru`, `sv`, `tr`.

To add one, copy `locales/en.json` to `locales/<code>.json` and translate the values. The manifest
globs `locales/*.json`, so no other change is needed.

## Configuration

The `config.lua` file at the root of the resource lets you change how the gizmo looks:

```lua
Config.outlineColor = { r = 255, g = 255, b = 255, a = 255 } -- highlight colour (RGBA, 0-255)
Config.outlineShader = 0                                    -- 0 = hard edge, 1 = softer/filled edge
Config.pedAlpha = 200                                       -- peds can't be outlined, they fade instead (0-255)
Config.enableScale = false                                  -- enable Scale Mode ([S])
Config.debug = false                                        -- enable the /testGizmo debug command
```

## Controls

While using the gizmo, the following controls apply:
- [W]: Switch to Translate Mode
- [R]: Switch to Rotate Mode
- [S]: Switch to Scale Mode (if enabled)
- [Q]: Switch between Relative and World
- [LAlt]: Snap To Ground
- [Enter]: Finish Editing

The current mode (Translate/Rotate) will be displayed on the screen.

## Note

The gizmo only works on entities that you have sufficient permissions to manipulate. Make sure you have the correct permissions to move or rotate the entity you are working with.

## Credits

- [Andyyy7666](https://github.com/overextended/ox_lib/pull/453)
- [AvarianKnight](https://forum.cfx.re/t/allow-drawgizmo-to-be-used-outside-of-fxdk/5091845/8?u=demi-automatic)
- [citizenfx](https://github.com/citizenfx/lua/blob/luaglm-dev/cfx/libs/scripts/examples/dataview.lua) — `client/dataview.lua`
