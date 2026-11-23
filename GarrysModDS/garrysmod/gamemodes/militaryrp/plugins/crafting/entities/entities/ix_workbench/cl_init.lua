include("shared.lua")

function ENT:Draw()
	self:DrawModel()
end

function ENT:Think()
	if (self:GetActive()) then
		local data = ix.plugin.Get("crafting").workbenches[self:GetBenchType()]
		local col = data and data.color or color_white
		local center = self:WorldSpaceCenter() + Vector(0, 0, 20)
		local dl = DynamicLight(self:EntIndex())

		if (dl) then
			dl.pos = center
			dl.r, dl.g, dl.b = col.r, col.g, col.b
			dl.brightness = 2 + math.sin(CurTime() * 14) * 0.6
			dl.Size = 150
			dl.Decay = 800
			dl.DieTime = CurTime() + 0.1
		end

		if ((self.nextSpark or 0) < CurTime()) then
			self.nextSpark = CurTime() + 0.12

			local fx = EffectData()
			fx:SetOrigin(center)
			fx:SetNormal(VectorRand())
			fx:SetMagnitude(1)
			fx:SetScale(1)
			fx:SetRadius(2)
			util.Effect("Sparks", fx)
		end
	end

	self:NextThink(CurTime())
	return true
end

function ENT:OnPopulateEntityInfo(container)
	local data = ix.plugin.Get("crafting").workbenches[self:GetBenchType()]
	if (!data) then return end

	local name = container:AddRow("name")
	name:SetImportant()
	name:SetText(data.name)
	name:SetBackgroundColor(data.color)
	name:SizeToContents()

	local desc = container:AddRow("description")
	desc:SetText(data.description or "")
	desc:SizeToContents()
end
