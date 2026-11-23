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

local FALLBACK_MODEL = "models/props_c17/consolebox01a.mdl"

local function IsUsableModel(model)
	return isstring(model) and model ~= "" and model:lower() ~= "models/error.mdl" and util.IsValidModel(model)
end

-- Подходящая модель: желаемая -> первая существующая из списка типа -> запасная (никогда не «ERROR»).
local function ResolveModel(typeId, preferred)
	if (IsUsableModel(preferred)) then return preferred end

	local info = ix.hack.types[typeId]

	for _, model in ipairs(info and info.models or {}) do
		if (IsUsableModel(model)) then return model end
	end

	MsgC(Color(255, 120, 120), "[Hacking] Нет модели для типа «", tostring(typeId), "» (",
		tostring(preferred or (info and info.models and info.models[1])), "), использую запасную.\n")

	return FALLBACK_MODEL
end

-- Q-меню: запись SpawnableEntities с KeyValues = {nodetype = "<id>"} вызывает это ДО Spawn().
-- Без этого метода тип терялся и каждый узел становился «tablet».
function ENT:KeyValue(key, value)
	if (key == "nodetype") then
		value = string.lower(tostring(value))

		if (ix.hack.types[value]) then
			self.spawnType = value
		end

		return true
	end
end

function ENT:Initialize()
	local HACK = ix.hack

	-- Значения по умолчанию на случай, если узел поставили из меню спавна.
	if (self:GetNodeType() == "") then
		local typeId = self.spawnType or "tablet"

		self:SetNodeType(typeId)
		self:SetDifficulty(HACK.types[typeId].defaultDiff)
		self:SetOwnerFaction("")
	end

	-- Имя выдаём позже: если узел создаёт Setup(), он задаст своё и счётчик имён не потратится зря.
	timer.Simple(0, function()
		if (IsValid(self) and self:GetNodeName() == "") then
			self:SetNodeName(HACK.NextNodeName())
		end
	end)

	-- Модель задаём всегда (а не «если пусто»): иначе узел из Q-меню мог остаться с моделью ERROR.
	self:SetNodeModel(ResolveModel(self:GetNodeType()))
	self:SetUseType(SIMPLE_USE)
end

-- Применить сохранённые / заданные параметры.
function ENT:Setup(d)
	local HACK = ix.hack

	self:SetNodeType(d.type or "tablet")
	self:SetDifficulty(math.Clamp(d.diff or HACK.types[self:GetNodeType()].defaultDiff, 1, #HACK.difficulties))
	self:SetOwnerFaction(d.faction or "")
	self:SetNodeName(d.name or HACK.NextNodeName())

	-- Сохранённая модель, если она рабочая; иначе (в т.ч. ранее сохранённый ERROR) - модель типа.
	local model = ResolveModel(self:GetNodeType(), d.model)

	if (model:lower() ~= (self:GetModel() or ""):lower()) then
		self:SetNodeModel(model)
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
