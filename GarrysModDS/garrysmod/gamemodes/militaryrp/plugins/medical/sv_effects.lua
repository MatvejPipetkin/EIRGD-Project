--[[
	СПЕЦЭФФЕКТЫ (сервер): кровавые следы, капли из раны, рвота при отравлении.
	Настройки — config.effects и поля drip / vomit у состояний (libs/sh_medical_config.lua).
	Клиентская часть (анимация, частицы, экранные эффекты) — cl_effects.lua.
]]

local config = ix.medical.config
local fxc = config.effects

util.AddNetworkString("ixMedFX")

-- типы сообщений ixMedFX
local FX_VOMIT, FX_DRIP, FX_NAUSEA = 1, 2, 3

local function Nearby(pos)
	local list = {}
	local sqr = fxc.range * fxc.range

	for _, ply in ipairs(player.GetAll()) do
		if (ply:GetPos():DistToSqr(pos) <= sqr) then
			list[#list + 1] = ply
		end
	end

	return list
end

local function RandomSound(list)
	return list and list[math.random(#list)]
end

--[[
	КРОВЬ
]]
local function BloodDecal(client, offset, spread)
	local pos = client:GetPos() + (offset or vector_origin)

	if (spread) then
		pos = pos + Vector(math.Rand(-spread, spread), math.Rand(-spread, spread), 0)
	end

	local tr = util.TraceLine({start = pos + Vector(0, 0, 16), endpos = pos - Vector(0, 0, 300), filter = client})

	if (tr.Hit and !tr.HitSky) then
		util.Decal(fxc.blood.decal, tr.HitPos + tr.HitNormal * 4, tr.HitPos - tr.HitNormal * 4, client)
	end
end

local function Drip(client, cond, def)
	local blood = fxc.blood
	local now = CurTime()

	-- защита от спама декалей
	if (now < (client.ixMedDecalGate or 0)) then
		return
	end

	client.ixMedDecalGate = now + 1 / math.max(blood.maxDecalsPerSecond, 1)

	local velocity = client:GetVelocity()
	local offset = vector_origin

	-- на бегу кровь остаётся дорожкой позади игрока
	if (velocity:Length2D() > 40) then
		local dir = velocity
		dir.z = 0
		offset = -dir:GetNormalized() * 10
	end

	BloodDecal(client, offset, 6)

	-- сильное кровотечение: на месте растекается лужа
	if (def.drip.pool and velocity:Length2D() < 40 and math.random() < 0.35) then
		BloodDecal(client, nil, 14)
	end

	if (blood.particles and cond.limb) then
		net.Start("ixMedFX")
			net.WriteUInt(FX_DRIP, 3)
			net.WriteEntity(client)
			net.WriteString(cond.limb)
			net.WriteBool(def.drip.pool == true)
		net.Send(Nearby(client:GetPos()))
	end
end

-- лужа крови под умершим от кровотечения
hook.Add("PlayerDeath", "ixMedicalFXDeath", function(client)
	local state = client.ixMed

	if (!fxc.enabled or !fxc.blood.enabled or !state) then
		return
	end

	for _, cond in pairs(state.cond) do
		local def = config.conditions[cond.id]

		if (def and def.drip and def.drip.pool) then
			for i = 1, 5 do
				BloodDecal(client, nil, 28)
			end

			return
		end
	end
end)

--[[
	РВОТА
]]
local function At(client, token, delay, callback)
	timer.Simple(delay, function()
		if (IsValid(client) and client:Alive() and client.ixMedVomitEnd == token) then
			callback()
		end
	end)
end

local function Puddle(client, index)
	local rules = fxc.vomit
	local ang = Angle(0, client:EyeAngles().y, 0)
	local start = client:GetPos() + ang:Forward() * (18 + index * 9) + ang:Right() * math.Rand(-6, 6) + Vector(0, 0, 32)
	local tr = util.TraceLine({start = start, endpos = start - Vector(0, 0, 100), filter = client})

	if (tr.Hit) then
		util.Decal(rules.decal, tr.HitPos + tr.HitNormal * 4, tr.HitPos - tr.HitNormal * 4, client)
	end
end

-- предупреждение: за несколько секунд до приступа начинает мутить
function ix.medical.Nausea(client)
	local rules = fxc.vomit

	if (!fxc.enabled or !rules.enabled or !IsValid(client) or !client:Alive()) then
		return
	end

	net.Start("ixMedFX")
		net.WriteUInt(FX_NAUSEA, 3)
		net.WriteEntity(client)
		net.WriteFloat(rules.warnTime)
	net.Send(client)

	client:Notify("Вас мутит...")

	local snd = RandomSound(rules.sounds.warn)

	if (snd) then
		client:EmitSound(snd, 55)
	end
end

-- приступ рвоты; bSkipNeeds — не списывать воду/сытость (при заболевании их уже списал onset)
function ix.medical.Vomit(client, bSkipNeeds, def)
	local rules = fxc.vomit

	if (!fxc.enabled or !rules.enabled or !IsValid(client) or !client:Alive() or !client:GetCharacter()) then
		return false
	end

	if ((client.ixMedVomitEnd or 0) > CurTime() or client:InVehicle()) then
		return false
	end

	local duration = rules.duration
	local token = CurTime() + duration

	client.ixMedVomitEnd = token
	client:SetLocalVar("medVomit", token)

	-- приступ отвлекает от лечения и прерывает действие
	if (rules.stopAction) then
		if (ix.medical.StopProcedure and ix.medical.StopProcedure(client, true)) then
			client:Notify("Вас скрутило, процедура прервана.")
		end

		client.ixMedBusy = nil
		client:SetAction()
	end

	net.Start("ixMedFX")
		net.WriteUInt(FX_VOMIT, 3)
		net.WriteEntity(client)
		net.WriteFloat(duration)
	net.Send(Nearby(client:GetPos()))

	if (rules.chat and ix.chat and ix.chat.classes and ix.chat.classes.me and rules.chatText) then
		ix.chat.Send(client, "me", rules.chatText)
	end

	-- таймлайн: позывы, выбросы, лужи
	local punch = rules.viewPunch

	client:ViewPunch(Angle(punch * 2, 0, 0))

	for index, delay in ipairs({0.7, 1.3, 1.9}) do
		At(client, token, delay * duration / 3.6, function()
			local snd = RandomSound(rules.sounds.retch)

			if (snd) then
				client:EmitSound(snd, 65, math.random(90, 105))
			end

			client:ViewPunch(Angle(punch, math.Rand(-punch, punch) * 0.5, 0))
		end)
	end

	for index, delay in ipairs({1.5, 2.2, 2.8}) do
		At(client, token, delay * duration / 3.6, function()
			local snd = RandomSound(rules.sounds.splash)

			if (snd) then
				client:EmitSound(snd, 65, math.random(90, 110))
			end

			if (index <= (rules.puddleSize or 3)) then
				Puddle(client, index)
			end

			client:ViewPunch(Angle(punch * 1.2, math.Rand(-punch, punch) * 0.4, 0))
		end)
	end

	At(client, token, duration - 0.1, function()
		if (!bSkipNeeds and def and def.vomit and ix.medical.AddNeeds) then
			ix.medical.AddNeeds(client, def.vomit.hunger, def.vomit.thirst)
		end

		client:SetLocalVar("medVomit", nil)
	end)

	hook.Run("MedicalVomited", client)

	return true
end

--[[
	ПЛАНИРОВЩИК
]]
local function ProcessFX(client, dt)
	local state = client.ixMed
	local rules = fxc.vomit

	for _, cond in pairs(state.cond) do
		local def = config.conditions[cond.id]

		if (def) then
			if (def.drip and fxc.blood.enabled) then
				local severity = ix.medical.Severity(cond)
				local velocity = client:GetVelocity():Length2D()
				local interval = def.drip.interval / severity

				if (velocity > 40) then
					interval = interval / fxc.blood.moveBoost
				else
					interval = interval * fxc.blood.standMul
				end

				cond.dripNext = (cond.dripNext or math.Rand(0, interval)) - dt

				if (cond.dripNext <= 0) then
					cond.dripNext = interval * math.Rand(0.8, 1.2)

					Drip(client, cond, def)
				end
			end

			if (def.vomit and rules.enabled) then
				if (!cond.vomitNext) then
					cond.vomitNext = math.Rand(def.vomit.min, def.vomit.max) * 0.6
				end

				cond.vomitNext = cond.vomitNext - dt

				if (!cond.vomitWarned and cond.vomitNext <= rules.warnTime and cond.vomitNext > 0) then
					cond.vomitWarned = true

					ix.medical.Nausea(client)
				end

				if (cond.vomitNext <= 0) then
					cond.vomitWarned = nil

					if (ix.medical.Vomit(client, false, def)) then
						-- чем дальше пройден курс лечения, тем реже приступы
						cond.vomitNext = math.Rand(def.vomit.min, def.vomit.max) / math.max(ix.medical.Severity(cond), 0.2)
					else
						cond.vomitNext = 10
					end
				end
			end
		end
	end
end

timer.Create("ixMedicalFX", 0.5, 0, function()
	if (!fxc.enabled) then
		return
	end

	for _, client in ipairs(player.GetAll()) do
		if (client.ixMed and client:GetCharacter() and client:Alive()) then
			ProcessFX(client, 0.5)
		end
	end
end)

-- во время приступа нельзя стрелять и ударять
hook.Add("StartCommand", "ixMedicalFXVomit", function(client, cmd)
	if ((client.ixMedVomitEnd or 0) > CurTime()) then
		cmd:RemoveKey(bit.bor(IN_ATTACK, IN_ATTACK2, IN_JUMP, IN_DUCK))
	end
end)

hook.Add("PlayerDeath", "ixMedicalFXVomitReset", function(client)
	client.ixMedVomitEnd = nil
	client:SetLocalVar("medVomit", nil)
end)
