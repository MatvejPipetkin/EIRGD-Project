AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
	local plugin = ix.plugin.Get("crafting")
	local id = self:GetBenchType()

	if (id == "" or !plugin.workbenches[id]) then
		id = "mechanical"
	end

	self:SetType(id)
end

function ENT:SetType(id)
	local data = ix.plugin.Get("crafting").workbenches[id]
	if (!data) then return end

	local model = data.model

	if (!util.IsValidModel(model)) then
		model = "models/props_c17/FurnitureTable002a.mdl"
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
