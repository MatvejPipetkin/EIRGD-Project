include("shared.lua")

local GLOW = Material("sprites/glow04_noz")

local COLOR_READY = Color(60, 255, 120)
local COLOR_COOLING = Color(255, 70, 50)
local COLOR_BUSY = Color(255, 200, 60)

function ENT:Draw()
	self:DrawModel()

	local color

	if (self:GetBusy()) then
		color = COLOR_BUSY
	elseif (self:GetCooling()) then
		color = COLOR_COOLING
	else
		color = COLOR_READY
	end

	-- Индикатор мигает: живой — ровно, занятый — быстро, сгоревший — редко.
	local rate = self:GetBusy() and 10 or (self:GetCooling() and 1.2 or 3)
	local pulse = 0.55 + 0.45 * math.abs(math.sin(CurTime() * rate + self:EntIndex()))
	local pos = self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z + 3))

	render.SetMaterial(GLOW)
	render.DrawSprite(pos, 14 * pulse, 14 * pulse, color)
	render.DrawSprite(pos, 34 * pulse, 34 * pulse, Color(color.r, color.g, color.b, 70))

	self:DrawHologram(pos, color, pulse)
end

-- Табличка-голограмма над узлом: видна вблизи, всегда повёрнута к игроку.
function ENT:DrawHologram(pos, color, pulse)
	local lp = LocalPlayer()

	if (not IsValid(lp)) then return end

	local dist = lp:GetPos():Distance(pos)
	local fade = math.Clamp(1 - (dist - 220) / 260, 0, 1)

	if (fade <= 0) then return end

	local hack = ix.hack
	local diff = hack.Difficulty(self:GetDifficulty())
	local status

	if (self:GetBusy()) then
		status = "ЗАНЯТ"
	elseif (self:GetCooling()) then
		status = "ВОССТАНОВЛЕНИЕ"
	else
		status = "ГОТОВ"
	end

	local yaw = (lp:GetPos() - pos):Angle().y
	local ang = Angle(0, yaw - 90, 90)
	local a = math.floor(255 * fade)
	local bob = math.sin(CurTime() * 2 + self:EntIndex()) * 0.6

	cam.Start3D2D(pos + Vector(0, 0, 16 + bob), ang, 0.1)
		surface.SetDrawColor(4, 12, 16, math.floor(190 * fade))
		surface.DrawRect(-110, -34, 220, 62)
		surface.SetDrawColor(color.r, color.g, color.b, math.floor(200 * fade))
		surface.DrawRect(-110, -34, 220, 2)
		surface.DrawRect(-110, -34, 2, 62)
		surface.DrawOutlinedRect(-110, -34, 220, 62)

		draw.SimpleText(self:GetNodeName(), "ixHackM", 0, -28, Color(168, 255, 238, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText("ЗАЩИТА: " .. diff.name, "ixHackS", 0, -4, Color(diff.color.r, diff.color.g, diff.color.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		draw.SimpleText(status, "ixHackS", 0, 10, Color(color.r, color.g, color.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	cam.End3D2D()
end
