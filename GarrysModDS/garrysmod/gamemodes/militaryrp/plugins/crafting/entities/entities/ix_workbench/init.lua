AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local FALLBACK_MODEL = "models/props_c17/FurnitureTable002a.mdl"

-- Q-меню: запись SpawnableEntities с KeyValues = {benchtype = "<id>"} вызывает это ДО Spawn().
-- Без этого метода тип терялся и все верстаки становились "mechanical".
function ENT:KeyValue(key, value)
	if (key == "benchtype") then
		value = string.lower(tostring(value))

		local plugin = ix.plugin.Get("crafting")

		if (plugin and plugin.workbenches[value]) then
			self.spawnType = value
		end

		return true
	end
end

function ENT:Initialize()
	local plugin = ix.plugin.Get("crafting")
	local id = self.spawnType or self:GetBenchType()

	if (id == "" or !plugin.workbenches[id]) then
		id = "mechanical"
	end

	self:SetType(id)
end

function ENT:SetType(id)
	local data = ix.plugin.Get("crafting").workbenches[id]
	if (!data) then return end

	local model = data.model

	if (!isstring(model) or model:lower() == "models/error.mdl" or !util.IsValidModel(model)) then
		MsgC(Color(255, 120, 120), "[Crafting] Модель верстака «", id, "» не найдена (", tostring(model), "), использую запасную.\n")
		model = FALLBACK_MODEL
	end

	self:SetBenchType(id)
	self:SetModel(model)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	local phys = self:GetPhysicsObject()

	if (IsValid(phys)) then
		phys:EnableMotion(false)
		phys:Sleep()
	end
end

function ENT:Use(activator)
	if (!IsValid(activator) or !activator:IsPlayer() or (self.nextUse or 0) > CurTime()) then return end

	self.nextUse = CurTime() + 0.5
	ix.plugin.Get("crafting"):OpenBench(activator, self)
end
