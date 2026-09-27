---@meta

---@alias GizmoMode 'translate' | 'rotate' | 'scale'
---@alias GizmoSpace 'world' | 'local'
---@alias GizmoCamera 'gameplay' | 'orbit'
---@alias GizmoPivot 'origin' | 'center'

---@class GizmoAxes
---@field x? boolean
---@field y? boolean
---@field z? boolean

---@class GizmoOrbit
---@field minRadius? number
---@field maxRadius? number
---@field zoomStep? number
---@field sensitivity? number
---@field blend? number

---@class GizmoColor
---@field r number
---@field g number
---@field b number
---@field a number

---@class GizmoOptions
---@field distanceLimit? number Max distance from `origin` (or the entity position when the gizmo opened), in metres.
---@field origin? vector3 Point the distance limit is measured from.
---@field bounds? table An ox_lib zone, or `{ type = 'box'|'sphere'|'poly', ... }` using the same fields as `lib.zones`. The entity origin stays inside. A definition is removed when the gizmo closes. An existing zone is left in place.
---@field mode? GizmoMode
---@field space? GizmoSpace | 'relative' `relative` is treated as `local`.
---@field camera? GizmoCamera
---@field pivot? GizmoPivot
---@field enableScale? boolean
---@field enableRotate? boolean
---@field enableTranslate? boolean
---@field enableSnapToggle? boolean
---@field enableCopy? boolean
---@field enableCancel? boolean
---@field snapToGround? boolean
---@field translationSnap? number Metres, used while snap is toggled on.
---@field rotationSnap? number Degrees, used while snap is toggled on.
---@field scaleSnap? number
---@field snap? boolean Start with snap enabled.
---@field outline? boolean
---@field outlineColor? GizmoColor
---@field outlineShader? number
---@field pedAlpha? number
---@field freezeEntity? boolean
---@field freezePlayer? boolean
---@field disableCollision? boolean
---@field playerCanMove? boolean
---@field restoreOnCancel? boolean
---@field requestControl? boolean
---@field showCoords? boolean
---@field prompts? boolean Use sleepless_prompts for this call when that resource is started.
---@field promptPosition? string
---@field promptLayout? 'row' | 'column'
---@field textUiPosition? string
---@field gizmoSize? number
---@field orbit? GizmoOrbit
---@field axes? GizmoAxes GTA axes. `z = false` hides the vertical handle.
---@field onChange? fun(result: GizmoResult)

---@class GizmoResult
---@field handle number
---@field position vector3
---@field rotation vector3
---@field cancelled boolean True when the edit was cancelled or the entity disappeared.
---@field confirmed boolean True when the player finished with the confirm control.

exports.object_gizmo = {}

--- Opens the gizmo on an entity and blocks until the player finishes or cancels.
--- A numeric second argument is treated as `distanceLimit`.
---@param entity number
---@param options? GizmoOptions | number
---@return GizmoResult
function exports.object_gizmo:useGizmo(entity, options) end

---@return boolean
function exports.object_gizmo:isGizmoActive() end

--- Cancel the open gizmo and restore the entity when restore-on-cancel is enabled.
function exports.object_gizmo:cancelGizmo() end

--- Confirm the open gizmo.
function exports.object_gizmo:confirmGizmo() end
