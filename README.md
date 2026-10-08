![](https://img.shields.io/github/downloads/DemiAutomatic/object_gizmo/total?logo=github)
![](https://img.shields.io/github/downloads/DemiAutomatic/object_gizmo/latest/total?logo=github)
![](https://img.shields.io/github/contributors/DemiAutomatic/object_gizmo?logo=github)
![](https://img.shields.io/github/v/release/DemiAutomatic/object_gizmo?logo=github)\
[![](https://badges.5metrics.dev/object_gizmo/serverRank.svg?style=for-the-badge)](https://5metrics.dev/resource/object_gizmo)
[![](https://badges.5metrics.dev/object_gizmo/servers.svg?style=for-the-badge)](https://5metrics.dev/resource/object_gizmo)
[![](https://badges.5metrics.dev/object_gizmo/players.svg?style=for-the-badge)](https://5metrics.dev/resource/object_gizmo)

# object_gizmo

A drop-in 3D gizmo for moving, rotating, and optionally scaling entities.

Documentation: [sleeplessdevelopment.dev/docs/gizmo](https://sleeplessdevelopment.dev/docs/gizmo)

`exports.object_gizmo:useGizmo(entity)` still blocks until the player is done, and still returns `handle`, `position`, and `rotation`. Extra result fields are safe to ignore.

## Dependencies

- [ox_lib](https://github.com/communityox/ox_lib)

[sleepless_prompts](https://github.com/Sleepless-Development/sleepless_prompts) is optional. When it is running, the controls use a prompt strip. Otherwise they use ox_lib text UI, which also prints the live position and rotation. Set `Config.prompts = false` to keep that text UI.

## Installation

1. Download `object_gizmo`.
2. Put the folder in your `resources` directory. Keep the folder name `object_gizmo`.
3. Add `ensure object_gizmo` to `server.cfg` after `ox_lib`.

## 💾 Download

[object_gizmo.zip](https://github.com/Sleepless-Development/object_gizmo/releases/latest/download/object_gizmo.zip)

## Usage

```lua
local handle = --[[ your entity ]]
local result = exports.object_gizmo:useGizmo(handle)

if result.confirmed then
    lib.print.info(result.position, result.rotation)
end
```

`result.cancelled` is true when the player backs out or the entity disappears. With the default config, cancel puts the entity back where it was when the gizmo opened.

### Options

The second argument is optional. A number is treated as a distance limit, in metres, measured from the entity origin at the start of the edit.

Any `config.lua` value can be overridden for a single call. Omitted keys keep the config value.

```lua
exports.object_gizmo:useGizmo(entity, 2.5)

exports.object_gizmo:useGizmo(entity, {
    camera = 'gameplay', -- 'gameplay' or 'orbit'
    mode = 'rotate',     -- 'translate', 'rotate', 'scale'
    space = 'local',     -- 'world' or 'local' ('relative' is accepted)
    pivot = 'origin',    -- 'origin' or 'center'
    enableScale = true,
    enableCancel = true,
    enableCopy = false,
    enableSnapToggle = true,
    snap = true,
    snapToGround = true,
    translationSnap = 0.1,
    rotationSnap = 15,
    distanceLimit = 2.5,
    origin = vec3(0.0, 0.0, 0.0),
    bounds = lib.zones.box({
        coords = vec3(100.0, 200.0, 30.0),
        size = vec3(4.0, 4.0, 3.0),
        rotation = 45,
    }),
    outline = true,
    outlineColor = { r = 255, g = 255, b = 255, a = 255 },
    outlineShader = 0,
    pedAlpha = 200,
    gizmoSize = 0.7,
    freezeEntity = true,
    freezePlayer = false,
    playerCanMove = false,
    prompts = true,
    promptPosition = 'bottom-center',
    promptLayout = 'row',
    textUiPosition = 'right-center',
    showCoords = true,
    orbit = { minRadius = 2.0, maxRadius = 12.0, zoomStep = 0.5 },
    onChange = function(update)
        -- fires while the entity is moving. update.confirmed is false here.
    end,
})
```

`pivot = 'center'` puts the handles on the model bounds and rotates around that point. The returned `position` is still the entity origin, which is what existing scripts save.

`camera = 'gameplay'` keeps the player camera. `camera = 'orbit'` takes a scripted camera: drag empty space to orbit, and use the wheel to zoom. Set the usual choice in `config.lua`, then pass the other one on the calls that need it.

`bounds` keeps the entity origin inside an ox_lib zone. Pass a zone you already created, or a definition with `type = 'box'`, `'sphere'`, or `'poly'` and the same fields `lib.zones` accepts. A definition is removed when the gizmo closes. An existing zone is left alone. `debug = true` on a definition draws it for the edit. The limit follows `zone:contains`, so boxes keep their rotation and polys keep their thickness. `distanceLimit` still applies as well. The prompt shows the limit when the entity is against the edge.

### Other exports

```lua
exports.object_gizmo:isGizmoActive()
exports.object_gizmo:cancelGizmo()
exports.object_gizmo:confirmGizmo()
```

Local events, for other resources that want to react without wrapping the export:

- `object_gizmo:client:editStarted` `(entity)`
- `object_gizmo:client:editFinished` `(result)`

## Controls

Defaults match the previous version. Players can rebind them under Settings, Key Bindings, FiveM.

- [W] Translate
- [R] Rotate
- [S] Scale, when scale is enabled for that call
- [Q] World / local
- [LAlt] Snap to ground
- [G] Release the cursor so the gameplay camera can look around
- ['X'] Toggle snap
- [C] Copy the transform to the clipboard
- [Enter] Finish
- [Esc] Cancel and restore

[G] is not used while the camera mode is `orbit`.

## Configuration

`config.lua` keeps the existing options (`outlineColor`, `outlineShader`, `pedAlpha`, `enableScale`, `debug`) and adds the new ones. Anything left unset falls back to the defaults in the client, so an older `config.lua` still loads. Peds are faded with `pedAlpha`. `SetEntityDrawOutline` is not used on them.

Set the language with the `ox:locale` convar, for example `setr ox:locale "de"`.

Available: `cs`, `de`, `en`, `es`, `fr`, `it`, `nl`, `pl`, `pt-br`, `ru`, `sv`, `tr`.

## Test command

`/testGizmo` is registered only when `Config.debug` is true.

```lua
/testGizmo
/testGizmo prop_bench_01a
/testGizmo ped
/testGizmo ped a_f_y_business_01
/testGizmo orbit
/testGizmo orbit ped
/testGizmo gameplay prop_barrier_work05
```

## Credits

- [DemiAutomatic](https://github.com/DemiAutomatic/object_gizmo)
- [three.js](https://github.com/mrdoob/three.js)
- [overextended/ox_lib](https://github.com/communityox/ox_lib)
