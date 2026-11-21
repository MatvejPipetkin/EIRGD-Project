AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local function Freeze(self)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	local phys = self:GetPhysicsObject()

	if (IsValid(phys)) then
		phys:EnableMotion(false)
		phys:Sleep()
	end
end

function ENT:Initialize()
	local HACK = ix.hack

	-- Значения по умолчанию на случай, если узел поставили из меню спавна.
	if (self:GetNodeType() == "") then
		self:SetNodeType("tablet")
		self:SetDifficulty(HACK.types.tablet.defaultDiff)
		self:SetOwnerFaction("")
	end

	-- Имя выдаём позже: если узел создаёт Setup(), он задаст своё и счётчик имён не потратится зря.
	timer.Simple(0, function()
		if (IsValid(self) and self:GetNodeName() == "") then
			self:SetNodeName(HACK.NextNodeName())
		end
	end)

	if (not self:GetModel() or self:GetModel() == "") then
		self:SetModel(HACK.types[self:GetNodeType()].models[1])
	end

	Freeze(self)
	self:SetUseType(SIMPLE_USE)
end

-- Применить сохранённые / заданные параметры.
function ENT:Setup(d)
	local HACK = ix.hack

	self:SetNodeType(d.type or "tablet")
	self:SetDifficulty(math.Clamp(d.diff or HACK.types[self:GetNodeType()].defaultDiff, 1, #HACK.difficulties))
	self:SetOwnerFaction(d.faction or "")
	self:SetNodeName(d.name or HACK.NextNodeName())

	if (d.model and d.model ~= self:GetModel()) then
		self:SetNodeModel(d.model)
	end
end

function ENT:SetNodeModel(model)
	self:SetModel(model)
	Freeze(self)
end

function ENT:Use(activator)
	if (not IsValid(activator) or not activator:IsPlayer()) then return end

	if ((self.nextUse or 0) > CurTime()) then return end

	self.nextUse = CurTime() + 1

	ix.hack.OnNodeUse(activator, self)
end

function ENT:OnRemove()
	if (ix.hack and ix.hack.AbortNode) then
		ix.hack.AbortNode(self)
	end
end
