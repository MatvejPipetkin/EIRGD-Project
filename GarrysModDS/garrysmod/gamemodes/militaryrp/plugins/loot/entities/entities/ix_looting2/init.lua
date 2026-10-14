
include("shared.lua");

AddCSLuaFile("cl_init.lua");
AddCSLuaFile("shared.lua");

function ENT:Initialize()
	self:SetSolid(SOLID_VPHYSICS)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
		phys:Sleep()
		phys:Wake()
	end

	-- Initialize default data if not set
	-- if not self.data then
	-- 	self.data = {
	-- 		name = "Контейнер",
	-- 		desc = "",
	-- 		model = "models/props_junk/garbage128_composite001a.mdl",
	-- 		respawn = true,
	-- 		items = {},
	-- 		time = 300,
	-- 		pick = 3,
	-- 		squat = false,
	-- 		loot_text = "Обыскиваем...",
	-- 		max_drop = 1,
	-- 		showtext = true,
	-- 		soundstart = "",
	-- 		soundend = "",
	-- 		chance = 30,
	-- 		openinventory = true,
	-- 	}
	-- end
end

function ENT:RemoveOnUse()
	if not self.data then
		return
	end
	
	if self.data.respawn then
		local pos = self:GetPos()
		local ang = self:GetAngles()
		local data = self.data

		self:Remove()
		local lootingentity = ents.Create( "ix_looting2" )
		lootingentity:SetModel(data.model)
		lootingentity:SetPos(Vector(0,0,-1000))
		lootingentity:SetAngles(ang)
		lootingentity:Spawn()

		lootingentity.data = data

		lootingentity:SetNetVar("name", data.name)
		lootingentity:SetNetVar("desc", data.desc)
		lootingentity:SetNetVar("show", data.showtext)

		timer.Simple(self.data.time, function()
			lootingentity:SetPos(pos)
		end)
	else
		self.ColdDown = CurTime() + self.data.time
	end
end

function ENT:GiveRandomItem(client)
	if not self.data then
		client:Notify("Ошибка: данные объекта не инициализированы!")
		return
	end
	
	local dropPos = client:GetPos() + Vector(0, 0, 35) + client:GetAngles():Forward() * 4
	local character = client:GetCharacter()
	local inventory = character:GetInventory()
	local entity_items = self.data.items
	local get_items = {}

	if table.Count(entity_items) > 0 then
		for i = 1, self.data.max_drop do
			local random = math.random(0, 100)
			if random <= self.data.chance then
				local item = table.Random(entity_items)
				table.insert(get_items, item)
			end
		end
	else
		client:Notify("Кажется здесь нету ничего полезного, нету смысла продолжать искать что-то.")
	end

	--if table.Count(get_items) > 0 then
		if self.data.openinventory then
			local inventory = ix.item.CreateInv(10, 5, os.time())
			inventory.noSave = true

			for k, v in pairs(get_items) do
				local itemtable = ix.item.Get(v)
				if itemtable then
					inventory:Add(v)
				end
			end

			ix.storage.Open(client, inventory, {
				entity = self,
				name = self.data.name,
				searchText = "",
				searchTime = 0
			})

			self.ColdDown = CurTime() + self.data.time
		else
			for k, v in pairs(get_items) do
				local itemtable = ix.item.Get(v)
				if itemtable then
					if (not inventory:Add(v)) then
						ix.item.Spawn(v, dropPos)
					end
				end
			end

			if table.Count(get_items) == 0 then
				client:Notify("Вы не нашли ничего ценного. (0)")
			elseif table.Count(get_items) == 1 then
				client:Notify("Похоже вы что-то нашли (1).")
			else
				client:Notify("Вы нашли несколько предметов (" .. table.Count(get_items) .. ")")
			end

			self:RemoveOnUse()
		end
	--else
	--	client:Notify("Вы не нашли ничего ценного. (0)")
	--	self:RemoveOnUse()
	--end
end

function ENT:Use(activator, caller)
	local trace = activator:GetEyeTraceNoCursor()

	if (activator:IsPlayer() and trace.Entity == self) then
		local character = activator:GetCharacter()

		-- Ensure data exists before proceeding
		if not self.data then
			activator:Notify("Ошибка: данные объекта не инициализированы!")
			return
		end

		if (not self.ColdDown or CurTime() >= self.ColdDown) then

			if activator:Alive() and character then
				if self.data.squat then
					if not activator:Crouching() then
						activator:Notify("Вы должны присесть, чтобы взаимодействовать с данным предметом!")
						return
					end
				end

				if self.data.soundstart ~= "" then
					self:EmitSound(self.data.soundstart)
				end

				local pick_time = self.data.pick
				pick_time = math.Round(pick_time)

				for i = 0, pick_time do
					timer.Simple( i, function()
						local fine = true
						if trace.Entity ~= self then fine = false end
						if not activator:KeyDown(IN_USE) then fine = false end
						if self.data.squat then if not activator:Crouching() then fine = false end end

						if not fine then
							activator:SetAction()
						end
					end)
				end

				activator:SetAction(self.data.loot_text, pick_time)
				caller:PerformInteraction(pick_time, self, function(client)
					local bad = false
					local character = client:GetCharacter()
					if client:Alive() and character then
						if self.data.squat then
							if not activator:Crouching() then
								bad = true
							end
						end

						if not bad then
							self:GiveRandomItem(client)
							if self.data.soundend ~= "" then
								self:EmitSound(self.data.soundend)
							end
						end
					end

					return false
				end)
			end
		else
			activator:Notify("На данный момент это больше нельзя использовать!")
		end
	end
end