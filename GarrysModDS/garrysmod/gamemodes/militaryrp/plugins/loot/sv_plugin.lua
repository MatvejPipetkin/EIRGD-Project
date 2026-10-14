
local PLUGIN = PLUGIN

function PLUGIN:SaveLootingSystem()
	local data = {}

	for _, v in ipairs(ents.FindByClass("ix_looting2")) do
		if (IsValid(v)) then
			data[#data + 1] = {
				v:GetPos(),
				v:GetAngles(),
				v.data
			}
		end
	end

	if #data > 0 then
		ix.data.Set("lootingsystem", data)
	end
end

function PLUGIN:LoadLootingSystem()
	for _, v in ipairs(ix.data.Get("lootingsystem") or {}) do
		local ent = ents.Create("ix_looting2")

		ent:SetPos(v[1])
		ent:SetAngles(v[2])

		if v[3] and istable(v[3]) then
			if v[3].model then
				ent:SetModel(v[3].model)
			end
			if v[3].name then
				ent:SetNetVar("name", v[3].name)
			end
			if v[3].desc then
				ent:SetNetVar("desc", v[3].desc)
			end
			if v[3].showtext then
				ent:SetNetVar("show", v[3].showtext)
			end
		end

		ent:Spawn()

		print("[DEBUG] Apply data to entity")

		timer.Simple(0.1, function()
			if not IsValid(ent) then return end
			
			ent.data = v[3]

			print("--------------------------------")
			print("[DEBUG] Done! Applied data to entity")
			PrintTable(v[3])
			print("--------------------------------")
			PrintTable(ent.data)
			print("--------------------------------")

			for k, v in pairs(ents.FindInSphere(ent:GetPos(), 64)) do
				if v:GetClass() == "ix_looting2" and v:EntIndex() ~= ent:EntIndex() then
					v:Remove()
				end
			end
		end)
	end
end

function PLUGIN:CreateLootingEntity(client)
	if client:Alive() then
		if client:IsAdmin() or client:IsSuperAdmin() then
			local character = client:GetCharacter()

			if character then
				local trace = client:GetEyeTrace().HitPos

				local lootingentity = ents.Create( "ix_looting2" )
				lootingentity:SetModel( "models/props_junk/garbage128_composite001a.mdl" )
				lootingentity:SetPos( trace )
				lootingentity:Spawn()

				lootingentity.data = {
					name = "Контейнер",
					desc = "",
					model = "models/props_junk/garbage128_composite001a.mdl",
					respawn = true,
					items = {},
					time = 300,
					pick = 3,
					squat = false,
					loot_text = "Обыскиваем...",
					max_drop = 1,
					showtext = true,
					soundstart = "",
					soundend = "",
					chance = 30,
					openinventory = true,
				}

				lootingentity:SetNetVar("name", "Контейнер")
				lootingentity:SetNetVar("desc", "")
				lootingentity:SetNetVar("show", true)

				self:SaveData()
				client:Notify("Вы успешно создали Looting Entity.")
			end
		else
			client:Notify("У вас нету доступа!")
		end
	end
end

function PLUGIN:EditLootingEntity(client)
	if client:Alive() then
		if client:IsAdmin() or client:IsSuperAdmin() then
			local character = client:GetCharacter()

			if character then
				local trace = client:GetEyeTrace().Entity
				if trace:GetClass() ~= "ix_looting2" then client:Notify("Вы не смотрите на Looting Entity!")return end

				netstream.Start(client, "OpenEditLootingEntity", trace.data, trace)
				client:Notify("Вы успешно открыли меню изменения")
			end
		else
			client:Notify("У вас нету доступа!")
		end
	end
end

function PLUGIN:RemoveLootingEntity(client)
	if client:Alive() then
		if client:IsAdmin() or client:IsSuperAdmin() then
			local character = client:GetCharacter()

			if character then
				local succ = false
				local trace = client:GetEyeTrace().Entity
				local dat = trace.data

				if trace:GetClass() ~= "ix_looting2" then client:Notify("Вы не смотрите на Looting Entity!")return end

				local old_data = ix.data.Get("lootingsystem")

				for k, v in pairs(old_data) do
					if dat == v[3] then
						trace:Remove()
						table.remove(old_data, k)
						succ = true
						client:Notify("Вы успешно удалили Looting Entity.")
						break
					end
				end

				if succ then
					ix.data.Set("lootingsystem", old_data)
				end
			end
		end
	end
end