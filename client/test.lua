if not Config.debug then return end

lib.print.warn('Debug mode is enabled. Do not use debug in production.')

RegisterCommand('testGizmo', function(_, args)
	local camera = nil
	local modelName = 'prop_mp_cone_02'

	if args[1] == 'orbit' or args[1] == 'gameplay' then
		camera = args[1]
		modelName = args[2] or modelName
	elseif args[1] then
		modelName = args[1]
	end

	local model = joaat(modelName)
	local offset = GetEntityCoords(cache.ped) + GetEntityForwardVector(cache.ped) * 3
	lib.requestModel(model)
	local obj = CreateObject(model, offset.x, offset.y, offset.z, false, false, false)
	SetModelAsNoLongerNeeded(model)

	local data = exports.object_gizmo:useGizmo(obj, camera and { camera = camera } or nil)
	lib.print.info(data)
end)
