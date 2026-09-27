local hud = {}

local GROUP_ID = 'object_gizmo'
local prompts = false
local signature = ''
local lastText = ''

---@param value number
---@return string
local function formatNumber(value)
	return ('%.2f'):format(value)
end

---@param vec vector3
---@return string
local function formatVec(vec)
	return ('%s, %s, %s'):format(formatNumber(vec.x), formatNumber(vec.y), formatNumber(vec.z))
end

---@param state table
---@return string
local function modeLabel(state)
	if state.mode == 'rotate' then return locale('rotate_mode') end
	if state.mode == 'scale' then return locale('scale_mode') end
	return locale('translate_mode')
end

---@param state table
---@return string
local function spaceLabel(state)
	if state.space == 'local' then return locale('relative') end
	return locale('world')
end

---@param key string
---@param label string
---@return string
local function controlLine(key, label)
	return ('[%s] - %s'):format(key, label)
end

---@param state table
---@return string
local function fullText(state)
	local keys = state.keys
	local lines = {
		locale('current_mode', modeLabel(state), spaceLabel(state)),
	}

	if state.showCoords then
		lines[#lines + 1] = locale('coords', formatVec(state.coords))
		lines[#lines + 1] = locale('rotation', formatVec(state.rotation))
	end

	if state.limited then
		lines[#lines + 1] = locale('limit_reached')
	end

	lines[#lines + 1] = controlLine(keys.translate, locale('translate_mode'))
	lines[#lines + 1] = controlLine(keys.rotate, locale('rotate_mode'))

	if state.enableScale then
		lines[#lines + 1] = controlLine(keys.scale, locale('scale_mode'))
	end

	lines[#lines + 1] = controlLine(keys.space, locale('toggle_space'))

	if state.snapToGround then
		lines[#lines + 1] = controlLine(keys.ground, locale('snap_to_ground'))
	end

	if state.snapToggle then
		local snapLabel = state.snap and locale('snap_on') or locale('snap_off')
		lines[#lines + 1] = controlLine(keys.snap, snapLabel)
	end

	if state.camera == 'gameplay' then
		local cursorLabel = state.cursor and locale('disable_cursor') or locale('enable_cursor')
		lines[#lines + 1] = controlLine(keys.cursor, cursorLabel)
	end

	if state.copy then
		lines[#lines + 1] = controlLine(keys.copy, locale('copy_transform'))
	end

	if state.cancel then
		lines[#lines + 1] = controlLine(keys.cancel, locale('cancel'))
	end

	lines[#lines + 1] = controlLine(keys.done, locale('done_editing'))

	return table.concat(lines, '  \n')
end

---@param state table
---@return table
local function buildPrompts(state)
	local list = {
		{
			id = 'translate',
			keybind = '_gizmoTranslation',
			label = locale('translate_mode'),
			disabled = state.mode ~= 'translate',
		},
		{
			id = 'rotate',
			keybind = '_gizmoRotation',
			label = locale('rotate_mode'),
			disabled = state.mode ~= 'rotate',
		},
	}

	if state.enableScale then
		list[#list + 1] = {
			id = 'scale',
			keybind = '_gizmoScale',
			label = locale('scale_mode'),
			disabled = state.mode ~= 'scale',
		}
	end

	local spaceText = spaceLabel(state)
	if state.limited then
		spaceText = ('%s / %s'):format(spaceText, locale('limit_reached'))
	end

	list[#list + 1] = {
		id = 'space',
		keybind = '_gizmoLocal',
		label = spaceText,
	}

	if state.snapToGround then
		list[#list + 1] = {
			id = 'ground',
			keybind = 'gizmoSnapToGround',
			label = locale('snap_to_ground'),
		}
	end

	if state.snapToggle then
		list[#list + 1] = {
			id = 'snap',
			keybind = 'gizmoSnap',
			label = state.snap and locale('snap_on') or locale('snap_off'),
		}
	end

	if state.camera == 'gameplay' then
		list[#list + 1] = {
			id = 'cursor',
			keybind = 'gizmoCursor',
			label = state.cursor and locale('disable_cursor') or locale('enable_cursor'),
		}
	end

	if state.copy then
		list[#list + 1] = {
			id = 'copy',
			keybind = 'gizmoCopy',
			label = locale('copy_transform'),
		}
	end

	if state.cancel then
		list[#list + 1] = {
			id = 'cancel',
			key = 'escape',
			label = locale('cancel'),
		}
	end

	list[#list + 1] = {
		id = 'done',
		keybind = 'gizmoclose',
		label = locale('done_editing'),
	}

	return list
end

---@param state table
---@return string
local function controlSignature(state)
	return table.concat({
		state.mode,
		state.space,
		state.camera,
		state.cursor and '1' or '0',
		state.snap and '1' or '0',
		state.limited and '1' or '0',
		state.enableScale and '1' or '0',
	}, '|')
end

---@param state table
---@return boolean
local function promptsAvailable(state)
	if state.prompts == false then return false end
	return GetResourceState('sleepless_prompts') == 'started'
end

---@param state table
function hud.draw(state)
	if promptsAvailable(state) then
		local sig = controlSignature(state)
		if not prompts or sig ~= signature then
			local shown = pcall(function()
				exports.sleepless_prompts:show(GROUP_ID, {
					position = state.promptPosition or 'bottom-center',
					layout = state.promptLayout or 'row',
					separator = 'slash',
					prompts = buildPrompts(state),
				})
			end)

			if shown then
				prompts = true
				signature = sig
				lastText = ''
			else
				prompts = false
			end
		end

		if prompts then
			return
		end
	elseif prompts then
		hud.hide()
	end

	local text = fullText(state)
	if text == lastText then return end
	lastText = text
	lib.showTextUI(text, {
		position = state.textUiPosition or 'right-center',
	})
end

function hud.hide()
	if prompts then
		pcall(function()
			exports.sleepless_prompts:hide(GROUP_ID)
		end)
	end

	lib.hideTextUI()
	prompts = false
	signature = ''
	lastText = ''
end

return hud
