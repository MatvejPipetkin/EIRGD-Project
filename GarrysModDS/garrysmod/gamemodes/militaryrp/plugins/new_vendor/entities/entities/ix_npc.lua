ENT.Type = "anim"
ENT.PrintName = "NPC (диалоги / квесты / магазин)"
ENT.Category = "Helix"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.isNPCSystem = true
ENT.bNoPersist = true

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "NoBubble")
	self:NetworkVar("String", 0, "DisplayName")
	self:NetworkVar("String", 1, "Description")
end

function ENT:Initialize()
	if (SERVER) then
		self:SetModel("models/mossman.mdl")
		self:SetUseType(SIMPLE_USE)
		self:SetMoveType(MOVETYPE_NONE)
		self:DrawShadow(true)
		self:InitPhysObj()

		self:AddCallback("OnAngleChange", function(entity)
			local mins, maxs = entity:GetAxisAlignedBoundingBox()

			entity:SetCollisionBounds(mins, maxs)
		end)

		self.npcDef = ix.npcsys:NewDef()

		self:SetDisplayName(self.npcDef.name)
		self:SetDescription(self.npcDef.desc)
	end

	timer.Simple(1, function()
		if (IsValid(self)) then
			self:SetAnim()
		end
	end)
end

function ENT:InitPhysObj()
	local mins, maxs = self:GetAxisAlignedBoundingBox()
	local bPhysObjCreated = self:PhysicsInitBox(mins, maxs)

	if (bPhysObjCreated) then
		local physObj = self:GetPhysicsObject()
		physObj:EnableMotion(false)
		physObj:Sleep()
	end
end

function ENT:GetAxisAlignedBoundingBox()
	local mins, maxs = self:GetModelBounds()
	mins = Vector(mins.x, mins.y, 0)
	mins, maxs = self:GetRotatedAABB(mins, maxs)

	return mins, maxs
end

function ENT:SetAnim()
	for k, v in ipairs(self:GetSequenceList()) do
		if (v:lower():find("idle") and v != "idlenoise") then
			return self:ResetSequence(k)
		end
	end

	if (self:GetSequenceCount() > 1) then
		self:ResetSequence(4)
	end
end

if (SERVER) then
	-- Спавн из Q-меню (вкладка Entities → Helix), как у ix_vendor.
	function ENT:SpawnFunction(client, trace)
		if (!ix.npcsys:CanManage(client)) then return end

		local angles = (trace.HitPos - client:GetPos()):Angle()
		angles.r = 0
		angles.p = 0
		angles.y = angles.y + 180

		local entity = ents.Create("ix_npc")
		entity:SetPos(trace.HitPos)
		entity:SetAngles(angles)
		entity:Spawn()

		ix.npcsys:SaveData()

		return entity
	end

	-- Применить конфиг (из редактора или при загрузке карты).
	function ENT:SetDef(def)
		self.npcDef = def

		if (self:GetModel() != def.model) then
			self:SetModel(def.model)
			self:InitPhysObj()
		end

		self:SetSkin(def.skin or 0)
		self:SetNoBubble(def.noBubble == true)
		self:SetDisplayName(def.name)
		self:SetDescription(def.desc)
		self:SetAnim()
	end

	function ENT:Use(activator)
		if (IsValid(activator) and activator:IsPlayer()) then
			ix.npcsys:Open(activator, self)
		end
	end
else
	function ENT:CreateBubble()
		self.bubble = ClientsideModel("models/extras/info_speech.mdl", RENDERGROUP_OPAQUE)
		self.bubble:SetPos(self:GetPos() + Vector(0, 0, 84))
		self.bubble:SetModelScale(0.6, 0)
	end

	function ENT:Draw()
		local bubble = self.bubble

		if (IsValid(bubble)) then
			local realTime = RealTime()

			bubble:SetRenderOrigin(self:GetPos() + Vector(0, 0, 84 + math.sin(realTime * 3) * 0.05))
			bubble:SetRenderAngles(Angle(0, realTime * 100, 0))
		end

		self:DrawModel()
	end

	function ENT:Think()
		local noBubble = self:GetNoBubble()

		if (IsValid(self.bubble) and noBubble) then
			self.bubble:Remove()
		elseif (!IsValid(self.bubble) and !noBubble) then
			self:CreateBubble()
		end

		if ((self.nextAnimCheck or 0) < CurTime()) then
			self:SetAnim()
			self.nextAnimCheck = CurTime() + 60
		end

		self:SetNextClientThink(CurTime() + 0.25)

		return true
	end

	function ENT:OnRemove()
		if (IsValid(self.bubble)) then
			self.bubble:Remove()
		end
	end

	ENT.PopulateEntityInfo = true

	function ENT:OnPopulateEntityInfo(container)
		local name = container:AddRow("name")
		name:SetImportant()
		name:SetText(self:GetDisplayName())
		name:SizeToContents()

		local descriptionText = self:GetDescription()

		if (descriptionText != "") then
			local description = container:AddRow("description")
			description:SetText(descriptionText)
			description:SizeToContents()
		end
	end
end
