local config = ix.medical.config

local smooth = {blur = 0, vignette = 0, r = 0, g = 0, b = 0, a = 0}

-- суммарные эффекты всех текущих состояний
local function Collect()
	local med = LocalPlayer():GetLocalVar("med")
	local blur, vignette, r, g, b, a = 0, 0, 0, 0, 0, 0

	if (med) then
		for _, cond in pairs(med.cond) do
			local fx = config.conditions[cond.id] and config.conditions[cond.id].fx

			if (fx) then
				blur = blur + (fx.blur or 0)
				vignette = math.max(vignette, fx.vignette or 0)

				if (fx.tint) then
					r = r + fx.tint[1] * fx.tint[4]
					g = g + fx.tint[2] * fx.tint[4]
					b = b + fx.tint[3] * fx.tint[4]
					a = a + fx.tint[4]
				end
			end
		end
	end

	-- тошнота и приступ рвоты: мутное зрение и зеленоватый оттенок
	local sick = ix.medical.NauseaLevel and ix.medical.NauseaLevel() or 0

	if (sick > 0) then
		blur = blur + 0.5 * sick
		r = r + 90 * 0.3 * sick
		g = g + 160 * 0.3 * sick
		b = b + 60 * 0.3 * sick
		a = a + 0.3 * sick
	end

	if (a > 0) then
		r, g, b = r / a, g / a, b / a
	end

	return math.min(blur, 0.8), vignette, r, g, b, math.min(a, 0.4)
end

hook.Add("RenderScreenspaceEffects", "ixMedicalFX", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive()) then
		return
	end

	local blur, vignette, r, g, b, a = Collect()
	local fade = math.min(FrameTime() * 2, 1)

	-- плавные переходы при получении/снятии состояния
	smooth.blur = Lerp(fade, smooth.blur, blur)
	smooth.vignette = Lerp(fade, smooth.vignette, vignette)
	smooth.r = Lerp(fade, smooth.r, r)
	smooth.g = Lerp(fade, smooth.g, g)
	smooth.b = Lerp(fade, smooth.b, b)
	smooth.a = Lerp(fade, smooth.a, a)

	if (smooth.blur > 0.02) then
		-- сотрясение и контузия: «плывущее» зрение
		local wobble = 0.5 + 0.5 * math.sin(CurTime() * 1.3)

		DrawMotionBlur(0.12, math.min(smooth.blur * (0.6 + 0.4 * wobble), 0.85), 0.03)
	end

	if (smooth.a > 0.01) then
		DrawColorModify({
			["$pp_colour_addr"] = smooth.r / 255 * smooth.a * 0.35,
			["$pp_colour_addg"] = smooth.g / 255 * smooth.a * 0.35,
			["$pp_colour_addb"] = smooth.b / 255 * smooth.a * 0.35,
			["$pp_colour_brightness"] = 0,
			["$pp_colour_contrast"] = 1,
			["$pp_colour_colour"] = 1 - smooth.a * 0.8,
			["$pp_colour_mulr"] = 0,
			["$pp_colour_mulg"] = 0,
			["$pp_colour_mulb"] = 0
		})
	end
end)

-- красная пульсирующая виньетка при кровотечении
hook.Add("HUDPaint", "ixMedicalVignette", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or smooth.vignette < 0.02) then
		return
	end

	local width, height = ScrW(), ScrH()
	local pulse = 0.65 + 0.35 * math.sin(CurTime() * (2 + smooth.vignette * 3))
	local strength = 255 * smooth.vignette * pulse
	local steps = 24
	local band = math.floor(height * 0.22 / steps)
	local side = math.floor(width * 0.14 / steps)

	draw.NoTexture()

	-- рамка из полос с убывающей прозрачностью (без внешних материалов)
	for i = 0, steps - 1 do
		local alpha = strength * (1 - i / steps) ^ 2

		surface.SetDrawColor(190, 15, 15, alpha)
		surface.DrawRect(0, i * band, width, band)
		surface.DrawRect(0, height - (i + 1) * band, width, band)
		surface.DrawRect(i * side, 0, side, height)
		surface.DrawRect(width - (i + 1) * side, 0, side, height)
	end
end)

--[[
	СПЕЦЭФФЕКТЫ: капли крови, рвота, тошнота (сервер: sv_effects.lua, настройки: config.effects)
]]
local fxc = config.effects

local FX_VOMIT, FX_DRIP, FX_NAUSEA = 1, 2, 3

local vomiting = {} -- [игрок] = {start, dur}
local nausea = {start = 0, dur = 0}
local emitter

local SPINE_BONES = {
	{"ValveBiped.Bip01_Spine", 0.35},
	{"ValveBiped.Bip01_Spine1", 0.35},
	{"ValveBiped.Bip01_Spine2", 0.30}
}
local HEAD_BONE = "ValveBiped.Bip01_Head1"
local RETCH_TIMES = {0.7, 1.3, 1.9} -- моменты позывов (для длительности 3.6 с)
local BURST_TIMES = {1.5, 2.2, 2.8} -- моменты выбросов

local function GetEmitter()
	if (!emitter) then
		emitter = ParticleEmitter(vector_origin)
	end

	return emitter
end

local function WoundPos(ply, limbID)
	local name = fxc.woundBones[limbID]
	local bone = name and ply:LookupBone(name)

	if (bone) then
		local pos = ply:GetBonePosition(bone)

		if (pos and pos != ply:GetPos()) then
			return pos
		end
	end

	return ply:WorldSpaceCenter()
end

local function MouthPos(ply)
	local bone = ply:LookupBone(HEAD_BONE)
	local pos = bone and ply:GetBonePosition(bone) or (ply:GetPos() + Vector(0, 0, 60))
	local forward = Angle(0, ply:EyeAngles().y, 0):Forward()

	return pos + forward * 5 - Vector(0, 0, 3), forward
end

-- капли крови из раны
local function SpawnDrips(ply, limbID, heavy)
	local em = GetEmitter()
	local pos = WoundPos(ply, limbID)
	local velocity = ply:GetVelocity() * 0.4

	for i = 1, heavy and 4 or 2 do
		local p = em:Add("effects/blood_core", pos + VectorRand() * 3)

		if (p) then
			p:SetDieTime(math.Rand(0.6, 1.1))
			p:SetStartAlpha(230)
			p:SetEndAlpha(0)
			p:SetStartSize(heavy and math.Rand(3, 5) or math.Rand(1.5, 3))
			p:SetEndSize(1)
			p:SetGravity(Vector(0, 0, -450))
			p:SetVelocity(velocity + VectorRand() * (heavy and 35 or 12))
			p:SetColor(math.random(120, 160), 0, 0)
			p:SetCollide(true)
			p:SetBounce(0)
		end
	end
end

-- струя рвоты изо рта
local function SpawnVomit(ply)
	local em = GetEmitter()
	local pos, forward = MouthPos(ply)

	for i = 1, 4 do
		local p = em:Add("effects/blood_core", pos + VectorRand() * 1.5)

		if (p) then
			local chunk = math.random() < 0.3

			p:SetDieTime(math.Rand(0.5, 0.9))
			p:SetStartAlpha(240)
			p:SetEndAlpha(0)
			p:SetStartSize(chunk and math.Rand(2, 3) or math.Rand(3, 6))
			p:SetEndSize(chunk and 1 or 2)
			p:SetGravity(Vector(0, 0, -600))
			p:SetVelocity(forward * math.Rand(70, 140) + Vector(math.Rand(-15, 15), math.Rand(-15, 15), math.Rand(-40, 10)) + ply:GetVelocity())

			if (chunk) then
				p:SetColor(math.random(110, 140), math.random(120, 150), math.random(30, 50))
			else
				p:SetColor(math.random(160, 190), math.random(170, 200), math.random(50, 80))
			end

			p:SetCollide(true)
			p:SetBounce(0.1)
		end
	end
end

net.Receive("ixMedFX", function()
	local kind = net.ReadUInt(3)
	local ply = net.ReadEntity()

	if (kind == FX_VOMIT) then
		local dur = net.ReadFloat()

		if (IsValid(ply)) then
			vomiting[ply] = {start = CurTime(), dur = dur, scale = dur / 3.6, nextBurst = 1}
		end
	elseif (kind == FX_DRIP) then
		local limbID = net.ReadString()
		local heavy = net.ReadBool()

		if (IsValid(ply) and ply:Alive()) then
			SpawnDrips(ply, limbID, heavy)
		end
	elseif (kind == FX_NAUSEA) then
		nausea.start = CurTime()
		nausea.dur = net.ReadFloat()
	end
end)

-- интенсивность тошноты для экранных эффектов (0..1)
function ix.medical.NauseaLevel()
	local now = CurTime()
	local mine = vomiting[LocalPlayer()]

	if (mine) then
		local left = mine.start + mine.dur - now

		return left > 0 and 1 or 0
	end

	if (nausea.dur > 0 and now < nausea.start + nausea.dur) then
		local progress = (now - nausea.start) / nausea.dur

		return math.Clamp(0.25 + 0.75 * progress, 0, 1) * (0.8 + 0.2 * math.sin(now * 5))
	end

	return 0
end

-- кривая наклона: плавно наклоняемся, во время позывов вздрагиваем, в конце выпрямляемся
local function BendFactor(t, dur, scale)
	local f = math.Clamp(math.min(t / 0.45, (dur - t) / 0.5), 0, 1)
	f = f * f * (3 - 2 * f)

	local pulse = 0

	for _, rt in ipairs(RETCH_TIMES) do
		local d = math.abs(t - rt * scale)

		if (d < 0.2) then
			pulse = pulse + math.cos(d / 0.2 * math.pi / 2) * 0.25
		end
	end

	return f * (1 + pulse)
end

local function ApplyBend(ply, factor)
	local rules = fxc.vomit.bones
	local sign = rules.sign or 1

	for _, entry in ipairs(SPINE_BONES) do
		local bone = ply:LookupBone(entry[1])

		if (bone) then
			ply:ManipulateBoneAngles(bone, Angle(0, rules.spine * entry[2] * factor * sign, 0))
		end
	end

	local head = ply:LookupBone(HEAD_BONE)

	if (head) then
		ply:ManipulateBoneAngles(head, Angle(0, rules.head * factor * sign, 0))
	end
end

hook.Add("Think", "ixMedicalFXThink", function()
	local now = CurTime()

	for ply, fx in pairs(vomiting) do
		if (!IsValid(ply) or !ply:Alive()) then
			if (IsValid(ply)) then
				ApplyBend(ply, 0)
			end

			vomiting[ply] = nil
		else
			local t = now - fx.start

			if (t >= fx.dur) then
				ApplyBend(ply, 0)
				vomiting[ply] = nil
			else
				ApplyBend(ply, BendFactor(t, fx.dur, fx.scale))

				-- выбросы: в течение 0.45 с после каждого момента летят брызги
				for _, bt in ipairs(BURST_TIMES) do
					local from = bt * fx.scale

					if (t >= from and t <= from + 0.45) then
						SpawnVomit(ply)
					end
				end
			end
		end
	end
end)
