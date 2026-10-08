if not Config.debug then return end

lib.print.warn('Debug mode is enabled. Do not use debug in production.')

RegisterCommand('testGizmo', function(_, args)
	local camera = nil
	local modelName = 'prop_mp_cone_02'
	local kind = 'object'
	local index = 1

	if args[1] == 'orbit' or args[1] == 'gameplay' then
		camera = args[1]
		index = 2
	end

	if args[index] == 'ped' then
		kind = 'ped'
		modelName = args[index + 1] or 'a_m_m_business_01'
	elseif args[index] then
		modelName = args[index]
	end

	local model = joaat(modelName)
	local offset = GetEntityCoords(cache.ped) + GetEntityForwardVector(cache.ped) * 3
	lib.requestModel(model)

	local entity
	if kind == 'ped' then
		assert(IsModelAPed(model), ('testGizmo ped model is not a ped: %s'):format(modelName))
		local heading = (GetEntityHeading(cache.ped) + 180.0) % 360.0
		entity = CreatePed(4, model, offset.x, offset.y, offset.z, heading, false, false)
		SetEntityAsMissionEntity(entity, true, true)
		SetBlockingOfNonTemporaryEvents(entity, true)
		SetPedCanRagdoll(entity, false)
		FreezeEntityPosition(entity, true)
	else
		entity = CreateObject(model, offset.x, offset.y, offset.z, false, false, false)
	end

	SetModelAsNoLongerNeeded(model)

	local data = exports.object_gizmo:useGizmo(entity, camera and { camera = camera } or nil)
	lib.print.info(data)
end)
