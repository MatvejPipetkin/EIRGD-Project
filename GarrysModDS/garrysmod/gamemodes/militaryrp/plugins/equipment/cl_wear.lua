-- отрисовка моделей снаряжения (параметр wear в конфиге предмета):
-- на игроках в мире и на модели предпросмотра в панели снаряжения
ix.equipment.wearCache = ix.equipment.wearCache or {}

local cache = ix.equipment.wearCache -- [игрок] = {[слот] = {uid, parent, ent}}

local function RemoveEntry(entry)
	if (entry and IsValid(entry.ent)) then
		entry.ent:Remove()
	end
end

function ix.equipment.ClearWear(store)
	for slotID, entry in pairs(store) do
		RemoveEntry(entry)
		store[slotID] = nil
	end
end

-- target — игрок или клиентская модель, equipment — {слот = {id, uid}}, store — кэш моделей этого target
function ix.equipment.DrawWear(target, store, equipment)
	for slotID, data in pairs(equipment) do
		local wear = ix.equipment.GetItemData(data.uid).wear
		local entry = store[slotID]

		if (!wear or !wear.model) then
			if (entry) then
				RemoveEntry(entry)
				store[slotID] = nil
			end

			continue
		end

		-- предмет в слоте сменился, сменилась модель-носитель или модель пропала
		if (entry and (entry.uid != data.uid or entry.parent != target or !IsValid(entry.ent))) then
			RemoveEntry(entry)
			entry = nil
			store[slotID] = nil
		end

		local bonemerge = wear.bonemerge or !wear.bone

		if (!entry) then
			local ent = ClientsideModel(wear.model, RENDERGROUP_OPAQUE)

			if (!IsValid(ent)) then
				continue
			end

			ent:SetNoDraw(true)

			if (bonemerge) then
				ent:SetParent(target)
				ent:AddEffects(EF_BONEMERGE)
			end

			if (wear.scale) then
				ent:SetModelScale(wear.scale, 0)
			end

			entry = {uid = data.uid, parent = target, ent = ent}
			store[slotID] = entry
		end

		local ent = entry.ent

		if (bonemerge) then
			ent:DrawModel()
		else
			local boneID = target:LookupBone(wear.bone)
			local matrix = boneID and target:GetBoneMatrix(boneID)

			if (matrix) then
				local pos, ang = LocalToWorld(wear.pos or vector_origin, wear.ang or angle_zero, matrix:GetTranslation(), matrix:GetAngles())

				ent:SetPos(pos)
				ent:SetAngles(ang)
				ent:SetupBones()
				ent:DrawModel()
			end
		end
	end

	-- убираем модели слотов, которые больше не заняты
	for slotID, entry in pairs(store) do
		if (!equipment[slotID]) then
			RemoveEntry(entry)
			store[slotID] = nil
		end
	end
end

hook.Add("PostPlayerDraw", "ixEquipmentWear", function(client)
	if (!IsValid(client) or !client:Alive()) then
		return
	end

	local equipment = client:GetNetVar("equipment")

	if (!equipment or table.IsEmpty(equipment)) then
		if (cache[client]) then
			ix.equipment.ClearWear(cache[client])
			cache[client] = nil
		end

		return
	end

	cache[client] = cache[client] or {}

	ix.equipment.DrawWear(client, cache[client], equipment)
end)

timer.Create("ixEquipmentWearCleanup", 2, 0, function()
	for client, store in pairs(cache) do
		if (!IsValid(client)) then
			ix.equipment.ClearWear(store)
			cache[client] = nil
		end
	end
end)
