local hud = require 'client.modules.hud'

lib.locale()

local session = nil
local lastToggle = {}

local BLOCKED_CONTROLS = {
	21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 36, 37, 44, 45, 47,
	58, 75, 140, 141, 142, 143, 199, 200, 202, 241, 242, 245, 257, 263, 264,
}

local MOVE_CONTROLS = {
	[21] = true,
	[22] = true,
	[30] = true,
	[31] = true,
	[32] = true,
	[33] = true,
	[34] = true,
	[35] = true,
	[36] = true,
}

local LOOK_CONTROLS = { 1, 2, 106 }

---@param value number
---@param min number
---@param max number
---@return number
local function clamp(value, min, max)
	if value < min then return min end
	if value > max then return max end
	return value
end

---@param options table
---@param key string
---@param fallback any
---@return any
local function option(options, key, fallback)
	if options[key] ~= nil then return options[key] end
	return fallback
end

---@param options table
---@param key string
---@param default any
---@return boolean
local function flag(options, key, default)
	local value = options[key]
	if value == nil then value = default end
	return value and true or false
end

---@param override? table
---@return table
local function resolveOrbit(override)
	local configOrbit = type(Config.orbit) == 'table' and Config.orbit or {}
	local callOrbit = type(override) == 'table' and override or {}
	return {
		minRadius = option(callOrbit, 'minRadius', configOrbit.minRadius or 1.5),
		maxRadius = option(callOrbit, 'maxRadius', configOrbit.maxRadius or 25.0),
		zoomStep = option(callOrbit, 'zoomStep', configOrbit.zoomStep or 0.75),
		sensitivity = option(callOrbit, 'sensitivity', configOrbit.sensitivity or 0.005),
		blend = option(callOrbit, 'blend', configOrbit.blend or 250),
	}
end

---@param key string
---@param fallback any
---@return any
local function orbitOption(key, fallback)
	local orbit = session and session.orbit
	if type(orbit) ~= 'table' or orbit[key] == nil then return fallback end
	return orbit[key]
end

---@param vec vector3
---@return vector3
local function normalize(vec)
	local length = #vec
	if length < 0.0001 then return vec end
	return vec / length
end

---@param rot vector3
---@return vector3
local function rotationToDirection(rot)
	local z = math.rad(rot.z)
	local x = math.rad(rot.x)
	local horizontal = math.abs(math.cos(x))
	return vector3(-math.sin(z) * horizontal, math.cos(z) * horizontal, math.sin(x))
end

---@param x number
---@param y number
---@param z number
---@return number, number, number
local function cartesianToSpherical(x, y, z)
	local radius = math.sqrt(x * x + y * y + z * z)
	if radius < 0.001 then return 0.001, 0.0, 1.0 end
	return radius, math.atan(y, x), math.acos(clamp(z / radius, -1.0, 1.0))
end

---@param radius number
---@param theta number
---@param phi number
---@return vector3
local function sphericalToCartesian(radius, theta, phi)
	return vector3(
		radius * math.sin(phi) * math.cos(theta),
		radius * math.sin(phi) * math.sin(theta),
		radius * math.cos(phi)
	)
end

---@param vec vector3
---@return table
local function packVec(vec)
	return { x = vec.x + 0.0, y = vec.y + 0.0, z = vec.z + 0.0 }
end

---@param entity number
---@param scale table
local function applyAxisScale(entity, scale)
	local forward, right, up, position = GetEntityMatrix(entity)
	forward = normalize(forward) * (scale.z or 1.0)
	right = normalize(right) * (scale.x or 1.0)
	up = normalize(up) * (scale.y or 1.0)

	SetEntityMatrix(entity,
		forward.x, forward.y, forward.z,
		right.x, right.y, right.z,
		up.x, up.y, up.z,
		position.x, position.y, position.z
	)
end

---@param entity number
---@return table
local function readScale(entity)
	local forward, right, up = GetEntityMatrix(entity)
	return { x = #right, y = #up, z = #forward }
end

---@param scale table
---@return boolean
local function scaleIsUniform(scale)
	return math.abs(scale.x - 1.0) < 0.001
		and math.abs(scale.y - 1.0) < 0.001
		and math.abs(scale.z - 1.0) < 0.001
end

---@param name string
---@return boolean
local function once(name)
	local now = GetGameTimer()
	local previous = lastToggle[name]
	if previous and (now - previous) < 150 then return false end
	lastToggle[name] = now
	return true
end

---@param bind CKeybind | nil
---@param fallback string
---@return string
local function keyLabel(bind, fallback)
	if not bind then return fallback end
	local current = bind.currentKey
	if not current or current == '' or current:match('^%d+$') then return fallback end
	return current:upper()
end

---@param bind CKeybind | nil
---@param code string
---@return boolean
local function bindMatches(bind, code)
	if not bind or not code then return false end
	local current = bind.currentKey
	if not current or current == '' then return false end
	current = current:lower()

	local token = code
	if code:sub(1, 3) == 'Key' then
		token = code:sub(4)
	elseif code:sub(1, 5) == 'Digit' then
		token = code:sub(6)
	end

	if token:lower() == current then return true end

	if code == 'Enter' or code == 'NumpadEnter' then
		return current == 'return' or current == 'enter' or current == 'numpadenter'
	end

	if code == 'AltLeft' or code == 'AltRight' then
		return current == 'lmenu' or current == 'rmenu' or current == 'alt' or current == 'lalt' or current == 'ralt'
	end

	return false
end

local translateBind, rotateBind, scaleBind, spaceBind, groundBind, closeBind, cursorBind, snapBind, copyBind

---@param entity number
---@return vector3
local function pivotOf(entity)
	local center = session.center
	if center.x == 0.0 and center.y == 0.0 and center.z == 0.0 then
		return GetEntityCoords(entity)
	end
	return GetOffsetFromEntityInWorldCoords(entity, center.x, center.y, center.z)
end

---@param zone table
---@param point vector3
---@return boolean
local function zoneContains(zone, point)
	local ok, inside = pcall(zone.contains, zone, point)
	return ok and inside == true
end

---@param point vector3
---@return boolean
local function pointAllowed(point)
	if session.bounds and not zoneContains(session.bounds, point) then
		return false
	end

	local limit = session.distanceLimit
	if limit and limit > 0.0 and #(point - session.limitOrigin) > limit then
		return false
	end

	return true
end

---@param bounds table
---@return table?, boolean
local function resolveBounds(bounds)
	if type(bounds) ~= 'table' then
		lib.print.error('object_gizmo bounds must be an ox_lib zone')
		return nil, false
	end

	if type(bounds.contains) == 'function' then
		return bounds, false
	end

	local kind = bounds.type or bounds.__type
	if kind == 'sphere' then
		return lib.zones.sphere({
			coords = bounds.coords,
			radius = bounds.radius,
			debug = bounds.debug,
			debugColour = bounds.debugColour,
		}), true
	end

	if kind == 'box' then
		return lib.zones.box({
			coords = bounds.coords,
			size = bounds.size,
			rotation = bounds.rotation,
			debug = bounds.debug,
			debugColour = bounds.debugColour,
		}), true
	end

	if kind == 'poly' then
		return lib.zones.poly({
			points = bounds.points,
			thickness = bounds.thickness,
			debug = bounds.debug,
			debugColour = bounds.debugColour,
		}), true
	end

	lib.print.error('object_gizmo bounds must be an ox_lib zone or a box, sphere, or poly definition')
	return nil, false
end

---@param entity number
---@return boolean
local function clampOrigin(entity)
	local coords = GetEntityCoords(entity)

	if not session.bounds then
		local limit = session.distanceLimit
		if not limit or limit <= 0.0 then
			session.limited = false
			return false
		end

		local origin = session.limitOrigin
		local offset = coords - origin
		local distance = #offset
		if distance <= limit or distance < 0.0001 then
			session.limited = false
			return false
		end

		local clamped = origin + (offset * (limit / distance))
		SetEntityCoordsNoOffset(entity, clamped.x, clamped.y, clamped.z, false, false, false)
		session.limited = true
		return true
	end

	if pointAllowed(coords) then
		session.boundsAnchor = coords
		session.limited = false
		return false
	end

	local anchor = session.boundsAnchor
	if not anchor or not pointAllowed(anchor) then
		session.limited = true
		return false
	end

	local inside = anchor
	local outside = coords
	for _ = 1, 16 do
		local mid = (inside + outside) * 0.5
		if pointAllowed(mid) then
			inside = mid
		else
			outside = mid
		end
	end

	SetEntityCoordsNoOffset(entity, inside.x, inside.y, inside.z, false, false, false)
	session.boundsAnchor = inside
	session.limited = true
	return true
end

---@param entity number
local function applyLockedScale(entity)
	local scale = session.scale
	if not scale then return end
	if not session.enableScale and scaleIsUniform(scale) then return end
	applyAxisScale(entity, scale)
end

---@return table
local function makeResult()
	local entity = session.entity
	local exists = DoesEntityExist(entity)
	local snap = session.snapshot

	return {
		handle = entity,
		position = exists and GetEntityCoords(entity) or snap.coords,
		rotation = exists and GetEntityRotation(entity, 2) or snap.rotation,
		cancelled = session.cancelled and true or false,
		confirmed = (not session.open) and not session.cancelled,
	}
end

local function pushEntity()
	if not session or not DoesEntityExist(session.entity) then return end
	local pivot = pivotOf(session.entity)
	local rotation = GetEntityRotation(session.entity, 2)
	SendNUIMessage({
		action = 'setEntity',
		data = {
			handle = session.entity,
			position = packVec(pivot),
			rotation = packVec(rotation),
			scale = session.scale,
		}
	})
end

local function pushControls()
	if not session then return end
	SendNUIMessage({
		action = 'configure',
		data = {
			mode = session.mode,
			space = session.space,
			translationSnap = session.snap and session.translationSnap or 0,
			rotationSnap = session.snap and session.rotationSnap or 0,
			scaleSnap = session.snap and session.scaleSnap or 0,
			size = session.gizmoSize,
			axes = session.axes,
			cursor = session.cursor,
			camera = session.camera,
		}
	})
end

---@return table
local function sessionView()
	local entity = session.entity
	return {
		mode = session.mode,
		space = session.space,
		camera = session.camera,
		cursor = session.cursor,
		snap = session.snap,
		enableScale = session.enableScale,
		snapToGround = session.snapToGround,
		snapToggle = session.snapToggle,
		copy = session.enableCopy,
		cancel = session.enableCancel,
		showCoords = session.showCoords,
		prompts = session.prompts,
		promptPosition = session.promptPosition,
		promptLayout = session.promptLayout,
		textUiPosition = session.textUiPosition,
		limited = session.limited,
		coords = DoesEntityExist(entity) and GetEntityCoords(entity) or session.snapshot.coords,
		rotation = DoesEntityExist(entity) and GetEntityRotation(entity, 2) or session.snapshot.rotation,
		keys = {
			translate = keyLabel(translateBind, 'W'),
			rotate = keyLabel(rotateBind, 'R'),
			scale = keyLabel(scaleBind, 'S'),
			space = keyLabel(spaceBind, 'Q'),
			ground = keyLabel(groundBind, 'LMENU'),
			snap = keyLabel(snapBind, 'X'),
			cursor = keyLabel(cursorBind, 'G'),
			copy = keyLabel(copyBind, 'C'),
			cancel = 'ESC',
			done = keyLabel(closeBind, 'ENTER'),
		},
	}
end

local function refreshHud()
	if not session then return end
	hud.draw(sessionView())
end

---@param mode GizmoMode
local function setMode(mode)
	if not session or not session.open then return end
	if mode == 'translate' and not session.enableTranslate then return end
	if mode == 'rotate' and not session.enableRotate then return end
	if mode == 'scale' and not session.enableScale then return end
	if session.mode == mode then return end
	session.mode = mode
	pushControls()
	refreshHud()
end

local function toggleSpace()
	if not session or not session.open or not once('space') then return end
	session.space = session.space == 'local' and 'world' or 'local'
	pushControls()
	refreshHud()
end

local function toggleSnap()
	if not session or not session.open or not session.snapToggle or not once('snap') then return end
	session.snap = not session.snap
	pushControls()
	refreshHud()
end

local function toggleCursor()
	if not session or not session.open or session.camera ~= 'gameplay' or not once('cursor') then return end
	session.cursor = not session.cursor
	SetNuiFocus(session.cursor, session.cursor)
	SetNuiFocusKeepInput(session.cursor)
	pushControls()
	refreshHud()
end

local function copyTransform()
	if not session or not session.open or not session.enableCopy or not once('copy') then return end
	if not DoesEntityExist(session.entity) then return end

	local coords = GetEntityCoords(session.entity)
	local rotation = GetEntityRotation(session.entity, 2)
	lib.setClipboard(('vec3(%.4f, %.4f, %.4f), vec3(%.4f, %.4f, %.4f)'):format(
		coords.x, coords.y, coords.z, rotation.x, rotation.y, rotation.z
	))
	lib.notify({
		description = locale('copied'),
		type = 'success',
	})
end

---@param entity number
---@param coords vector3
---@return number | nil
local function probeGroundZ(entity, coords)
	local handle = StartShapeTestLosProbe(
		coords.x, coords.y, coords.z + 2.0,
		coords.x, coords.y, coords.z - 50.0,
		1 | 16,
		entity,
		7
	)

	local deadline = GetGameTimer() + 250
	while GetGameTimer() < deadline do
		local state, hit, endCoords = GetShapeTestResult(handle)
		if state ~= 1 then
			if hit == 1 or hit == true then
				return endCoords.z
			end
			return nil
		end
		Wait(0)
	end
end

---@param entity number
local function snapPedToGround(entity)
	local coords = GetEntityCoords(entity)
	local groundZ = probeGroundZ(entity, coords)
	if not groundZ then
		local found, z = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)
		if found then groundZ = z end
	end
	if not groundZ then return end
	SetEntityCoordsNoOffset(entity, coords.x, coords.y, groundZ + 1.0, false, false, false)
end

local function snapToGround()
	if not session or not session.open or not session.snapToGround or not once('ground') then return end
	local entity = session.entity
	if not DoesEntityExist(entity) then return end

	-- Furniture previews disable collision. PlaceObjectOnGroundOrObjectProperly
	-- no-ops unless the entity can collide, and it never moves a ped.
	local frozen = IsEntityPositionFrozen(entity)
	local collisionDisabled = GetEntityCollisionDisabled(entity)
	local isPed = IsEntityAPed(entity)

	if frozen then
		FreezeEntityPosition(entity, false)
	end

	if collisionDisabled and not isPed then
		SetEntityCollision(entity, true, true)
		Wait(0)
	end

	local stillOpen = session and session.open and DoesEntityExist(entity)
	if stillOpen then
		if isPed then
			snapPedToGround(entity)
		else
			PlaceObjectOnGroundOrObjectProperly(entity)
		end
	end

	if collisionDisabled and DoesEntityExist(entity) then
		SetEntityCollision(entity, false, false)
	end

	if frozen and DoesEntityExist(entity) then
		FreezeEntityPosition(entity, true)
	end

	if not stillOpen then return end

	clampOrigin(entity)
	applyLockedScale(entity)
	pushEntity()
	refreshHud()

	if session.onChange then
		pcall(session.onChange, makeResult())
	end
end

---@param cancelled boolean
local function closeSession(cancelled)
	if not session or not session.open then return end
	session.cancelled = cancelled
	session.open = false
end

---@param entity number
local function updateOrbit(entity)
	local pivot = pivotOf(entity)
	if not session.dragging then
		session.camTarget = session.camTarget + (pivot - session.camTarget) * 0.18
	end

	local offset = sphericalToCartesian(session.radius, session.theta, session.phi)
	local position = session.camTarget + offset
	SetCamCoord(session.cam, position.x, position.y, position.z)
	PointCamAtCoord(session.cam, session.camTarget.x, session.camTarget.y, session.camTarget.z)
end

local function destroyOrbitCam()
	local cam = session and session.cam
	if not cam then return end
	local blend = session.blend or 250
	session.cam = nil
	RenderScriptCams(false, true, blend, true, true)
	CreateThread(function()
		Wait(blend)
		if DoesCamExist(cam) then
			DestroyCam(cam, false)
		end
	end)
end

---@param entity number
local function highlight(entity)
	if IsEntityAPed(entity) then
		session.savedAlpha = GetEntityAlpha(entity)
		SetEntityAlpha(entity, session.pedAlpha, false)
		return
	end

	if session.outline == false then return end
	local color = session.outlineColor
	SetEntityDrawOutlineColor(color.r, color.g, color.b, color.a)
	SetEntityDrawOutlineShader(session.outlineShader)
	ResetEntityDrawOutlineRenderTechnique()
	SetEntityDrawOutline(entity, true)
end

local function clearHighlight()
	local entity = session.entity
	if not DoesEntityExist(entity) then return end
	if session.savedAlpha and DoesEntityExist(entity) then
		SetEntityAlpha(entity, session.savedAlpha, false)
	end
	if IsEntityAPed(entity) then return end
	SetEntityDrawOutline(entity, false)
	SetEntityDrawOutlineShader(session.outlineShader or 0)
	ResetEntityDrawOutlineRenderTechnique()
end

---@param entity number
local function ensureControl(entity)
	if session.requestControl == false then return end
	if not NetworkGetEntityIsNetworked(entity) then return end
	if NetworkHasControlOfEntity(entity) then return end

	local deadline = GetGameTimer() + 750
	while not NetworkHasControlOfEntity(entity) and GetGameTimer() < deadline do
		NetworkRequestControlOfEntity(entity)
		Wait(0)
	end

	if not NetworkHasControlOfEntity(entity) then
		lib.print.warn('object_gizmo could not get control of the entity')
	end
end

local function sampleCamera()
	local position = GetFinalRenderedCamCoord()
	local rotation = GetFinalRenderedCamRot(2)
	return position, rotationToDirection(rotation), GetFinalRenderedCamFov()
end

local function sendCamera()
	local position, forward, fov = sampleCamera()
	SendNUIMessage({
		action = 'setCamera',
		data = {
			position = packVec(position),
			forward = packVec(forward),
			fov = fov,
		}
	})
end

local function disableFrameControls()
	local allowMove = session.playerCanMove
	for i = 1, #BLOCKED_CONTROLS do
		local control = BLOCKED_CONTROLS[i]
		if not (allowMove and MOVE_CONTROLS[control]) then
			DisableControlAction(0, control, true)
		end
	end

	if session.cursor then
		for i = 1, #LOOK_CONTROLS do
			DisableControlAction(0, LOOK_CONTROLS[i], true)
		end
	end

	DisablePlayerFiring(cache.playerId, true)
end

---@param entity number
local function restoreSnapshot(entity)
	local snap = session.snapshot
	SetEntityCoordsNoOffset(entity, snap.coords.x, snap.coords.y, snap.coords.z, false, false, false)
	SetEntityRotation(entity, snap.rotation.x, snap.rotation.y, snap.rotation.z, 2, true)
	applyAxisScale(entity, snap.scale)
end

local function cleanup()
	if not session then return end

	local entity = session.entity
	SetNuiFocus(false, false)
	SetNuiFocusKeepInput(false)
	SendNUIMessage({ action = 'close' })
	hud.hide()
	clearHighlight()
	destroyOrbitCam()

	if DoesEntityExist(entity) then
		if session.freezeEntity then
			FreezeEntityPosition(entity, session.entityFrozen)
		end
		if session.disableCollision then
			SetEntityCollision(entity, true, true)
		end
	end

	if session.freezePlayer then
		FreezeEntityPosition(cache.ped, session.pedFrozen)
	end

	if session.boundsOwned and session.bounds then
		pcall(session.bounds.remove, session.bounds)
	end
end

---@param data table
---@return boolean
local function applyMove(data)
	local entity = session.entity
	if not DoesEntityExist(entity) or type(data.position) ~= 'table' or type(data.rotation) ~= 'table' then
		return false
	end

	local pivot = vector3(data.position.x + 0.0, data.position.y + 0.0, data.position.z + 0.0)
	local rotation = vector3(data.rotation.x + 0.0, data.rotation.y + 0.0, data.rotation.z + 0.0)

	SetEntityCoordsNoOffset(entity, pivot.x, pivot.y, pivot.z, false, false, false)
	SetEntityRotation(entity, rotation.x, rotation.y, rotation.z, 2, true)

	local center = session.center
	if center.x ~= 0.0 or center.y ~= 0.0 or center.z ~= 0.0 then
		local worldCenter = GetOffsetFromEntityInWorldCoords(entity, center.x, center.y, center.z)
		local coords = GetEntityCoords(entity)
		SetEntityCoordsNoOffset(entity,
			coords.x + (pivot.x - worldCenter.x),
			coords.y + (pivot.y - worldCenter.y),
			coords.z + (pivot.z - worldCenter.z),
			false, false, false
		)
	end

	local limited = clampOrigin(entity)

	if session.mode == 'scale' and type(data.scale) == 'table' then
		session.scale = {
			x = data.scale.x + 0.0,
			y = data.scale.y + 0.0,
			z = data.scale.z + 0.0,
		}
	end

	applyLockedScale(entity)

	if session.onChange then
		pcall(session.onChange, makeResult())
	end

	return limited
end

---@param options any
---@return table
local function normalizeOptions(options)
	if type(options) == 'number' then
		return { distanceLimit = options }
	end
	if type(options) ~= 'table' then
		return {}
	end
	return options
end

---@param value any
---@return GizmoMode
local function normalizeMode(value)
	if value == 'rotate' or value == 'scale' or value == 'translate' then return value end
	return 'translate'
end

---@param value any
---@return GizmoSpace
local function normalizeSpace(value)
	if value == 'local' or value == 'relative' then return 'local' end
	return 'world'
end

---@param entity number
---@return GizmoResult
local function busyResult(entity)
	local exists = entity and DoesEntityExist(entity)
	return {
		handle = entity,
		position = exists and GetEntityCoords(entity) or vec3(0.0, 0.0, 0.0),
		rotation = exists and GetEntityRotation(entity, 2) or vec3(0.0, 0.0, 0.0),
		cancelled = true,
		confirmed = false,
	}
end

---@param entity number
---@param options? GizmoOptions | number
---@return GizmoResult
local function useGizmo(entity, options)
	if session then
		lib.print.error('object_gizmo is already active')
		return busyResult(entity)
	end

	if not entity or not DoesEntityExist(entity) then
		return busyResult(entity)
	end

	options = normalizeOptions(options)

	local mode = normalizeMode(option(options, 'mode', Config.mode))
	local enableScale = option(options, 'enableScale', Config.enableScale) and true or false
	local enableRotate = option(options, 'enableRotate', true) and true or false
	local enableTranslate = option(options, 'enableTranslate', true) and true or false

	if mode == 'scale' and not enableScale then mode = 'translate' end
	if mode == 'rotate' and not enableRotate then mode = 'translate' end
	if mode == 'translate' and not enableTranslate then
		mode = enableRotate and 'rotate' or 'translate'
	end

	local center = vector3(0.0, 0.0, 0.0)
	if option(options, 'pivot', Config.pivot) == 'center' then
		local min, max = GetModelDimensions(GetEntityModel(entity))
		center = vector3((min.x + max.x) * 0.5, (min.y + max.y) * 0.5, (min.z + max.z) * 0.5)
	end

	local camera = option(options, 'camera', Config.camera)
	if camera ~= 'orbit' then camera = 'gameplay' end

	local orbit = resolveOrbit(options.orbit)
	local outlineColor = option(options, 'outlineColor', Config.outlineColor) or { r = 255, g = 255, b = 255, a = 255 }
	local bounds, boundsOwned = nil, false
	if options.bounds ~= nil then
		bounds, boundsOwned = resolveBounds(options.bounds)
	end

	local startCoords = GetEntityCoords(entity)
	local boundsAnchor = startCoords
	if bounds and not zoneContains(bounds, startCoords) and bounds.coords and zoneContains(bounds, bounds.coords) then
		boundsAnchor = bounds.coords
	end

	session = {
		open = true,
		cancelled = false,
		entity = entity,
		center = center,
		mode = mode,
		space = normalizeSpace(option(options, 'space', Config.space)),
		camera = camera,
		cursor = true,
		snap = option(options, 'snap', Config.snapEnabled) and true or false,
		translationSnap = option(options, 'translationSnap', Config.translationSnap or 0.25) + 0.0,
		rotationSnap = option(options, 'rotationSnap', Config.rotationSnap or 15) + 0.0,
		scaleSnap = option(options, 'scaleSnap', Config.scaleSnap or 0.1) + 0.0,
		snapToggle = flag(options, 'enableSnapToggle', Config.enableSnapToggle ~= false),
		snapToGround = flag(options, 'snapToGround', Config.snapToGround ~= false),
		enableCopy = flag(options, 'enableCopy', Config.enableCopy ~= false),
		enableCancel = flag(options, 'enableCancel', Config.enableCancel ~= false),
		enableScale = enableScale,
		enableRotate = enableRotate,
		enableTranslate = enableTranslate,
		outline = flag(options, 'outline', true),
		outlineColor = {
			r = outlineColor.r or 255,
			g = outlineColor.g or 255,
			b = outlineColor.b or 255,
			a = outlineColor.a or 255,
		},
		outlineShader = option(options, 'outlineShader', Config.outlineShader or 0),
		pedAlpha = option(options, 'pedAlpha', Config.pedAlpha or 200),
		freezeEntity = flag(options, 'freezeEntity', Config.freezeEntity ~= false),
		freezePlayer = flag(options, 'freezePlayer', Config.freezePlayer),
		disableCollision = flag(options, 'disableCollision', Config.disableCollision),
		restoreOnCancel = flag(options, 'restoreOnCancel', true),
		requestControl = flag(options, 'requestControl', Config.requestControl ~= false),
		showCoords = flag(options, 'showCoords', Config.showCoords ~= false),
		prompts = flag(options, 'prompts', Config.prompts ~= false),
		promptPosition = option(options, 'promptPosition', Config.promptPosition or 'bottom-center'),
		promptLayout = option(options, 'promptLayout', Config.promptLayout or 'row'),
		textUiPosition = option(options, 'textUiPosition', Config.textUiPosition or 'right-center'),
		playerCanMove = flag(options, 'playerCanMove', Config.playerCanMove),
		distanceLimit = tonumber(options.distanceLimit),
		limitOrigin = options.origin and vector3(options.origin.x, options.origin.y, options.origin.z) or startCoords,
		bounds = bounds,
		boundsOwned = boundsOwned,
		boundsAnchor = boundsAnchor,
		gizmoSize = option(options, 'gizmoSize', Config.gizmoSize or 0.5) + 0.0,
		orbit = orbit,
		axes = options.axes or { x = true, y = true, z = true },
		onChange = options.onChange,
		scale = readScale(entity),
		snapshot = {
			coords = GetEntityCoords(entity),
			rotation = GetEntityRotation(entity, 2),
			scale = readScale(entity),
		},
		entityFrozen = IsEntityPositionFrozen(entity),
		pedFrozen = IsEntityPositionFrozen(cache.ped),
		limited = false,
		dragging = false,
		blend = orbit.blend,
		confirmArmed = false,
		cancelArmed = false,
	}

	ensureControl(entity)

	if session.freezeEntity then
		FreezeEntityPosition(entity, true)
	end

	if session.freezePlayer then
		FreezeEntityPosition(cache.ped, true)
	end

	if session.disableCollision then
		SetEntityCollision(entity, false, false)
	end

	highlight(entity)

	if session.bounds then
		if not session.boundsAnchor or not pointAllowed(session.boundsAnchor) then
			if session.bounds.coords and pointAllowed(session.bounds.coords) then
				session.boundsAnchor = session.bounds.coords
			else
				session.boundsAnchor = nil
				lib.print.warn('object_gizmo bounds do not contain a usable point')
			end
		end

		clampOrigin(entity)
	end

	if camera == 'orbit' then
		local pivot = pivotOf(entity)
		local gameplayPos = GetGameplayCamCoord()
		local offset = gameplayPos - pivot
		local radius, theta, phi = cartesianToSpherical(offset.x, offset.y, offset.z)
		session.radius = clamp(radius, orbitOption('minRadius', 1.5), orbitOption('maxRadius', 25.0))
		session.theta = theta
		session.phi = clamp(phi, 0.12, math.pi - 0.12)
		session.camTarget = pivot
		session.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
		SetCamFov(session.cam, GetGameplayCamFov())
		updateOrbit(entity)
		SetCamActive(session.cam, true)
		RenderScriptCams(true, true, session.blend, true, true)
	end

	local pivot = pivotOf(entity)
	local rotation = GetEntityRotation(entity, 2)
	SetNuiFocus(true, true)
	SetNuiFocusKeepInput(true)
	SendNUIMessage({
		action = 'open',
		data = {
			handle = entity,
			position = packVec(pivot),
			rotation = packVec(rotation),
			scale = session.scale,
			mode = session.mode,
			space = session.space,
			translationSnap = session.snap and session.translationSnap or 0,
			rotationSnap = session.snap and session.rotationSnap or 0,
			scaleSnap = session.snap and session.scaleSnap or 0,
			size = session.gizmoSize,
			axes = session.axes,
			cursor = true,
			camera = session.camera,
		}
	})

	refreshHud()
	TriggerEvent('object_gizmo:client:editStarted', entity)

	local nextHud = 0
	local ok, err = pcall(function()
		while session and session.open do
			if not DoesEntityExist(entity) then
				session.cancelled = true
				session.open = false
				break
			end

			disableFrameControls()

			if session.camera == 'orbit' and session.cam then
				updateOrbit(entity)
			end

			sendCamera()

			if not session.confirmArmed then
				local acceptDown = IsControlPressed(0, 18) or IsDisabledControlPressed(0, 18)
					or IsControlPressed(0, 191) or IsDisabledControlPressed(0, 191)
					or IsControlPressed(0, 201) or IsDisabledControlPressed(0, 201)
				if not acceptDown then
					session.confirmArmed = true
				end
			end

			if not session.cancelArmed then
				local cancelDown = IsControlPressed(0, 200) or IsDisabledControlPressed(0, 200)
					or IsControlPressed(0, 202) or IsDisabledControlPressed(0, 202)
				if not cancelDown then
					session.cancelArmed = true
				end
			elseif session.enableCancel and not session.cursor and (IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 202)) then
				closeSession(true)
			end

			local now = GetGameTimer()
			if now >= nextHud then
				nextHud = now + 200
				refreshHud()
			end

			Wait(0)
		end
	end)

	if not ok then
		lib.print.error(err)
		if session then
			session.cancelled = true
			session.open = false
		end
	end

	if not session then
		return busyResult(entity)
	end

	if session.cancelled and session.restoreOnCancel and DoesEntityExist(entity) then
		restoreSnapshot(entity)
	end

	local result = makeResult()
	cleanup()
	session = nil
	TriggerEvent('object_gizmo:client:editFinished', result)
	return result
end

RegisterNUICallback('moveEntity', function(data, cb)
	if not session or not session.open or data.handle ~= session.entity then
		cb({ ok = false })
		return
	end

	local limited = applyMove(data)
	if not limited then
		cb({ ok = true, clamped = false })
		return
	end

	local pivot = pivotOf(session.entity)
	local rotation = GetEntityRotation(session.entity, 2)
	cb({
		ok = true,
		clamped = true,
		position = packVec(pivot),
		rotation = packVec(rotation),
	})
end)

RegisterNUICallback('setDragging', function(data, cb)
	if session then
		session.dragging = data.dragging and true or false
	end
	cb({ ok = true })
end)

RegisterNUICallback('rotateCamera', function(data, cb)
	if session and session.open and session.camera == 'orbit' and session.cursor and not session.dragging then
		local sensitivity = orbitOption('sensitivity', 0.005)
		session.theta = session.theta - (data.x or 0.0) * sensitivity
		session.phi = clamp(session.phi - (data.y or 0.0) * sensitivity, 0.12, math.pi - 0.12)
	end
	cb({ ok = true })
end)

RegisterNUICallback('zoomCamera', function(data, cb)
	if session and session.open and session.camera == 'orbit' then
		local step = orbitOption('zoomStep', 0.75)
		local delta = data.delta or 0.0
		if delta > 0 then
			session.radius = session.radius + step
		elseif delta < 0 then
			session.radius = session.radius - step
		end
		session.radius = clamp(session.radius, orbitOption('minRadius', 1.5), orbitOption('maxRadius', 25.0))
	end
	cb({ ok = true })
end)

RegisterNUICallback('key', function(data, cb)
	if session and session.open and not IsPauseMenuActive() and type(data.code) == 'string' then
		local code = data.code
		if code == 'Escape' then
			if session.enableCancel and session.cancelArmed then closeSession(true) end
		elseif (code == 'Enter' or code == 'NumpadEnter') and session.confirmArmed then
			closeSession(false)
		elseif bindMatches(translateBind, code) then
			setMode('translate')
		elseif bindMatches(rotateBind, code) then
			setMode('rotate')
		elseif bindMatches(scaleBind, code) then
			setMode('scale')
		elseif bindMatches(spaceBind, code) then
			toggleSpace()
		elseif bindMatches(groundBind, code) then
			snapToGround()
		elseif bindMatches(cursorBind, code) then
			toggleCursor()
		elseif bindMatches(snapBind, code) then
			toggleSnap()
		elseif bindMatches(copyBind, code) then
			copyTransform()
		end
	end
	cb({ ok = true })
end)

---@param name string
---@param description string
---@param defaultKey string
---@param onPressed fun()
---@return CKeybind
local function bind(name, description, defaultKey, onPressed)
	return lib.addKeybind({
		name = name,
		description = description,
		defaultKey = defaultKey,
		onPressed = function()
			if not session or not session.open then return end
			onPressed()
		end,
	})
end

translateBind = bind('_gizmoTranslation', locale('translation_mode_description'), 'W', function()
	setMode('translate')
end)

rotateBind = bind('_gizmoRotation', locale('rotation_mode_description'), 'R', function()
	setMode('rotate')
end)

spaceBind = bind('_gizmoLocal', locale('toggle_space_description'), 'Q', toggleSpace)
groundBind = bind('gizmoSnapToGround', locale('snap_to_ground_description'), 'LMENU', snapToGround)
closeBind = bind('gizmoclose', locale('close_gizmo_description'), 'RETURN', function()
	if not session.confirmArmed then return end
	local acceptDown = IsControlPressed(0, 18) or IsDisabledControlPressed(0, 18)
		or IsControlPressed(0, 191) or IsDisabledControlPressed(0, 191)
		or IsControlPressed(0, 201) or IsDisabledControlPressed(0, 201)
	if not acceptDown then return end
	closeSession(false)
end)
cursorBind = bind('gizmoCursor', locale('cursor_description'), 'G', toggleCursor)

snapBind = bind('gizmoSnap', locale('toggle_snap_description'), 'X', toggleSnap)
copyBind = bind('gizmoCopy', locale('copy_description'), 'C', copyTransform)
scaleBind = bind('_gizmoScale', locale('scale_mode_description'), 'S', function()
	setMode('scale')
end)

AddEventHandler('onResourceStop', function(resource)
	if resource ~= GetCurrentResourceName() or not session then return end
	session.open = false
	cleanup()
	session = nil
end)

exports('useGizmo', useGizmo)
exports('isGizmoActive', function()
	return session ~= nil
end)
exports('cancelGizmo', function()
	closeSession(true)
end)
exports('confirmGizmo', function()
	closeSession(false)
end)
