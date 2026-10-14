--[[
	Realistic View — плагин для HELIX
	Реалистичная камера и зрение + состояние персонажа при низком HP.

	Установка: положить файл в  gamemodes/<ваша_схема>/plugins/realisticview.lua

	Хуки для кастомизации (можно использовать в своей схеме / других плагинах):
		GetPlayerMoanSound(client)  -> строка с путём к звуку (или nil для стандартного)
		ShouldPlayerMoan(client)    -> вернуть false, чтобы запретить стон (например, для кукол/Combine)
]]

local PLUGIN = PLUGIN

PLUGIN.name = "Realistic View"
PLUGIN.author = "Claude"
PLUGIN.description = "Реалистичная камера и зрение; при низком HP — стоны, покраснение краёв экрана, пульс."

-- ============================================================================
-- Локализация
-- ============================================================================
-- Все строки русские. Таблица добавляется и в "russian", и в "english",
-- чтобы настройки были русифицированы независимо от выбранного в Helix языка.
local phrases = {
	realisticView = "Реалистичный вид",

	-- серверные настройки
	cfgRvEnabled = "Реалистичный вид включён",
	cfgRvHurtReaction = "Реакция камеры на урон",
	cfgRvLowHealth = "Порог низкого здоровья",
	cfgRvMoans = "Стоны при низком здоровье",
	cfgRvMoanMin = "Мин. интервал между стонами (сек)",
	cfgRvMoanMax = "Макс. интервал между стонами (сек)",
	cfgRvMoanVolume = "Громкость стонов",
	cfgRvMoanLevel = "Дальность слышимости стонов (дБ)",
	cfgRvEffectHealth = "Здоровье, с которого нарастают размытие и затемнение",
	cfgRvWoundBlur = "Размытие при низком здоровье",
	cfgRvWoundDarken = "Затемнение при низком здоровье",

	-- клиентские настройки: камера
	optRvIntensity = "Общая интенсивность камеры",
	optdRvIntensity = "Множитель всех эффектов камеры. 0 — полностью отключает.",
	optRvBobScale = "Покачивание при ходьбе",
	optdRvBobScale = "Насколько заметно камера покачивается при ходьбе и беге.",
	optRvRunShake = "Тряска при беге",
	optdRvRunShake = "Дополнительное покачивание на бегу. 0 — как при ходьбе.",
	optRvTilt = "Наклоны при движении",
	optdRvTilt = "Крен камеры при стрейфе и наклон вперёд при беге.",
	optRvBreath = "Дыхание и дрожание взгляда",
	optdRvBreath = "Лёгкое колебание камеры от дыхания и дрейф взгляда.",
	optRvSway = "Инерция головы",
	optdRvSway = "Запаздывание камеры при резких поворотах.",
	optRvLandScale = "Удар при приземлении",
	optdRvLandScale = "Сила просадки камеры после прыжка или падения.",
	optRvFlinch = "Отдача при уроне",
	optdRvFlinch = "Сила тряски камеры при получении урона.",
	optRvSprintFov = "Расширение FOV при беге",
	optdRvSprintFov = "Небольшое увеличение угла обзора во время спринта.",
	optRvWeaponSway = "Покачивание оружия",
	optdRvWeaponSway = "Оружие в руках следует за движениями камеры.",

	-- клиентские настройки: зрение
	optRvVignette = "Естественная виньетка",
	optdRvVignette = "Лёгкое затемнение краёв экрана, как у реального зрения.",
	optRvVignetteStrength = "Сила виньетки",
	optRvLowVignette = "Красные края при низком здоровье",
	optdRvLowVignette = "Пульсирующие красные края экрана при низком здоровье.",
	optRvHurtFlash = "Вспышка и размытие при уроне",
	optdRvHurtFlash = "Короткая красная вспышка и размытие при попадании.",
	optRvBlink = "Моргание",
	optdRvBlink = "Реалистичное моргание, включая рефлекторное при уроне.",
	optRvBlinkRate = "Частота моргания",
	optRvBlinkDepth = "Закрытие глаз при моргании",
	optdRvBlinkDepth = "Насколько сильно веки закрывают экран при моргании.",
	optRvEyeAdapt = "Адаптация глаз к свету",
	optdRvEyeAdapt = "Яркий свет слепит и заставляет щуриться, в темноте глаза привыкают не сразу.",
	optRvAdaptStrength = "Сила адаптации к свету",
	optRvMotionBlur = "Размытие в движении",
	optdRvMotionBlur = "Размытие при беге и быстрых поворотах головы.",
	optRvMotionBlurStrength = "Сила размытия в движении",

	-- клиентские настройки: низкое здоровье
	optRvWoundBlurStrength = "Размытие при низком здоровье",
	optdRvWoundBlurStrength = "Чем меньше здоровья, тем сильнее размыт экран. 0 — выключено.",
	optRvWoundDarkenStrength = "Затемнение при низком здоровье",
	optdRvWoundDarkenStrength = "Чем меньше здоровья, тем темнее экран. 0 — выключено.",
	optRvLowSway = "Шатание при низком здоровье",
	optdRvLowSway = "Качание и поникшая голова при низком здоровье.",
	optRvDroop = "Тяжесть век при низком здоровье",
	optdRvDroop = "Веки тяжелеют, глаза иногда закрываются сами."
}

ix.lang.AddTable("russian", phrases)
ix.lang.AddTable("english", phrases)

-- ============================================================================
-- Серверные настройки (меняются в F1 -> Config)
-- ============================================================================
ix.config.Add("rvEnabled", true, "Включить плагин Realistic View.", nil, {
	category = "realisticView"
})

ix.config.Add("rvHurtReaction", true, "Отдача камеры и красная вспышка при получении урона.", nil, {
	category = "realisticView"
})

ix.config.Add("rvLowHealth", 30, "Если здоровье ниже этого значения — стоны и красные края экрана.", nil, {
	data = {min = 1, max = 100},
	category = "realisticView"
})

ix.config.Add("rvEffectHealth", 70, "Ниже этого здоровья начинают нарастать размытие и затемнение экрана. Чем меньше здоровье — тем сильнее эффект.", nil, {
	data = {min = 5, max = 100},
	category = "realisticView"
})

ix.config.Add("rvWoundBlur", true, "Размытие экрана, которое усиливается по мере потери здоровья.", nil, {
	category = "realisticView"
})

ix.config.Add("rvWoundDarken", true, "Затемнение и обесцвечивание экрана, которые усиливаются по мере потери здоровья.", nil, {
	category = "realisticView"
})

ix.config.Add("rvMoans", true, "Издавать тихие стоны при низком здоровье.", nil, {
	category = "realisticView"
})

ix.config.Add("rvMoanMin", 4, "Минимальный интервал между стонами при самом низком HP (сек).", nil, {
	data = {min = 1, max = 30},
	category = "realisticView"
})

ix.config.Add("rvMoanMax", 9, "Интервал между стонами на пороге низкого HP (сек).", nil, {
	data = {min = 2, max = 60},
	category = "realisticView"
})

ix.config.Add("rvMoanVolume", 0.35, "Громкость стонов (0.05 - 1.0). Стоны намеренно тихие.", nil, {
	data = {min = 0.05, max = 1, decimals = 2},
	category = "realisticView"
})

ix.config.Add("rvMoanLevel", 55, "Дальность слышимости стонов в дБ (45 — только вплотную, 75 — слышно издалека).", nil, {
	data = {min = 40, max = 90},
	category = "realisticView"
})

-- ============================================================================
-- СЕРВЕР
-- ============================================================================
if (SERVER) then
	util.AddNetworkString("ixRVHurt")

	local function Seq(fmt, count)
		local list = {}

		for i = 1, count do
			list[i] = string.format(fmt, i)
		end

		return list
	end

	local moanMale = Seq("vo/npc/male01/moan0%d.wav", 5)
	local moanFemale = Seq("vo/npc/female01/moan0%d.wav", 5)
	local moanMetro = Seq("npc/metropolice/pain%d.wav", 4)
	local moanCombine = Seq("npc/combine_soldier/pain%d.wav", 3)

	local function PickMoan(client)
		local custom = hook.Run("GetPlayerMoanSound", client)

		if (isstring(custom) and custom != "") then
			return custom
		end

		local class

		if (ix.anim and ix.anim.GetModelClass) then
			class = ix.anim.GetModelClass(client:GetModel())
		end

		local list

		if (class == "metrocop") then
			list = moanMetro
		elseif (class == "overwatch") then
			list = moanCombine
		elseif (class == "vortigaunt") then
			return nil
		elseif (class == "citizen_female" or (client.IsFemale and client:IsFemale())) then
			list = moanFemale
		else
			list = moanMale
		end

		return list[math.random(#list)]
	end

	-- Отдача камеры при получении урона (клиент делает тряску)
	function PLUGIN:PlayerHurt(client, attacker, health, damage)
	if (!ix.config.Get("rvEnabled", true) or !ix.config.Get("rvHurtReaction", true)) then return end
		if (!IsValid(client) or !client:GetCharacter()) then return end

		net.Start("ixRVHurt")
			net.WriteFloat(damage or 0)
		net.Send(client)
	end

	-- Стоны при низком HP
	function PLUGIN:Think()
		local curTime = CurTime()

		if ((self.rvNextScan or 0) > curTime) then return end
		self.rvNextScan = curTime + 0.25

		if (!ix.config.Get("rvEnabled", true) or !ix.config.Get("rvMoans", true)) then return end

		local threshold = ix.config.Get("rvLowHealth", 30)

		for _, client in ipairs(player.GetAll()) do
			local health = client:Health()

			if (client:Alive() and client:GetCharacter() and health > 0 and health < threshold) then
				if (!client.ixRVNextMoan) then
					-- первый стон — вскоре после падения ниже порога
					client.ixRVNextMoan = curTime + math.Rand(0.8, 2)
				elseif (curTime >= client.ixRVNextMoan) then
					local severity = math.Clamp(1 - health / threshold, 0, 1)

					if (hook.Run("ShouldPlayerMoan", client) != false) then
						local path = PickMoan(client)

						if (path) then
							local volume = ix.config.Get("rvMoanVolume", 0.35) * Lerp(severity, 0.8, 1)
							local pitch = math.random(94, 104) - math.floor(severity * 4)

							-- дальность слышимости настраивается в конфиге (rvMoanLevel)
							client:EmitSound(path, ix.config.Get("rvMoanLevel", 55), pitch, volume, CHAN_VOICE)
						end
					end

					local interval = Lerp(severity, ix.config.Get("rvMoanMax", 9), ix.config.Get("rvMoanMin", 4))
					client.ixRVNextMoan = curTime + interval * math.Rand(0.85, 1.2)
				end
			else
				client.ixRVNextMoan = nil
			end
		end
	end

	return
end

-- ============================================================================
-- КЛИЕНТ
-- ============================================================================
local function AddSlider(key, default, min, max)
	ix.option.Add(key, ix.type.number, default, {
		category = "realisticView", min = min, max = max, decimals = 2
	})
end

local function AddToggle(key, default)
	ix.option.Add(key, ix.type.bool, default, {category = "realisticView"})
end

-- Камера
AddSlider("rvIntensity", 1, 0, 2)
AddSlider("rvBobScale", 1, 0, 2)
AddSlider("rvRunShake", 0.6, 0, 2)
AddSlider("rvTilt", 1, 0, 2)
AddSlider("rvBreath", 1, 0, 2)
AddSlider("rvSway", 1, 0, 2)
AddSlider("rvLandScale", 1, 0, 2)
AddSlider("rvFlinch", 1, 0, 2)
AddToggle("rvSprintFov", true)
AddToggle("rvWeaponSway", true)

-- Зрение
AddToggle("rvVignette", true)
AddSlider("rvVignetteStrength", 1, 0, 2)
AddToggle("rvLowVignette", true)
AddToggle("rvHurtFlash", true)
AddToggle("rvBlink", true)
AddSlider("rvBlinkRate", 1, 0.2, 2)
AddSlider("rvBlinkDepth", 0.85, 0.2, 1)
AddToggle("rvEyeAdapt", true)
AddSlider("rvAdaptStrength", 1, 0, 2)
AddToggle("rvMotionBlur", true)
AddSlider("rvMotionBlurStrength", 1, 0, 2)

-- Низкое здоровье
AddSlider("rvWoundBlurStrength", 1, 0, 2)
AddSlider("rvWoundDarkenStrength", 1, 0, 2)
AddSlider("rvLowSway", 1, 0, 2)
AddSlider("rvDroop", 1, 0, 2)

local function Opt(key, default)
	if (ix.option and ix.option.Get) then
		return ix.option.Get(key, default)
	end

	return default
end

local function Noise(t, seed)
	return math.sin(t + seed) * 0.6 + math.sin(t * 2.3 + seed * 1.7) * 0.3 + math.sin(t * 4.1 + seed * 0.3) * 0.1
end

local state = {
	active = false, frame = 0, firstFrame = true,
	-- шаги / движение
	stepPhase = 0, amp = 0, strafeRoll = 0, leanPitch = 0, breathPhase = 0, speedSm = 0,
	bob = {z = 0, y = 0, p = 0, yaw = 0, r = 0},
	-- приземление (пружина)
	land = 0, landVel = 0, wasGround = true, airVelZ = 0, airTime = 0, groundTime = 0,
	-- инерция поворота
	lastAng = Angle(), lagYaw = 0, lagPitch = 0, turnRoll = 0,
	-- отдача при уроне
	flinchP = 0, flinchY = 0, flinchR = 0, hurtFlash = 0,
	fovAdd = 0,
	-- низкое HP (low — порог стонов/красных краёв, wound — плавное ранение для блюра и затемнения)
	low = 0, wound = 0, heart = 0, pulse = 0,
	-- моргание и веки
	blinkStart = nil, blinkDur = 0.22, blinkClose = 0.35, blinkDepth = 1, blinkReflex = false,
	nextBlink = 0, blinkLid = 0, droop = 0, squint = 0,
	-- зрение
	adapt = 0, adaptInit = false, blur = 0, rsYaw = 0,
	-- смещение viewmodel
	vm = {x = 0, y = 0, z = 0, p = 0, yaw = 0, r = 0}
}

-- Форма моргания: быстрое закрытие, более плавное открытие (p: 0..1, c: доля времени на закрытие)
local function BlinkShape(p, c)
	if (p < c) then
		local x = p / c

		return x * x * (3 - 2 * x)
	end

	local x = (p - c) / (1 - c)

	return 1 - x * x * (3 - 2 * x)
end

-- Размытие всего экрана (для низкого здоровья и урона)
local blurMat = Material("pp/blurscreen")

local function DrawScreenBlur(amount)
	surface.SetMaterial(blurMat)
	surface.SetDrawColor(255, 255, 255, 255)

	local passes = amount > 3 and 3 or 2

	for i = 1, passes do
		blurMat:SetFloat("$blur", (i / passes) * amount)
		blurMat:Recompute()
		render.UpdateScreenEffectTexture()
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
	end
end

-- Веки с мягким краем (cover — на сколько пикселей закрыт экран сверху и снизу)
local function DrawLids(cover)
	local w, h = ScrW(), ScrH()
	local soft = math.max(h * 0.05, 8)
	local n = 8
	local seg = soft / n

	surface.SetDrawColor(0, 0, 0, 245)
	surface.DrawRect(0, 0, w, cover)
	surface.DrawRect(0, h - cover, w, cover)

	for i = 0, n - 1 do
		surface.SetDrawColor(0, 0, 0, 245 * (1 - (i + 1) / (n + 1)) ^ 1.5)
		surface.DrawRect(0, cover + i * seg, w, seg + 1)
		surface.DrawRect(0, h - cover - (i + 1) * seg, w, seg + 1)
	end
end

net.Receive("ixRVHurt", function()
	local damage = net.ReadFloat()
	local power = math.Clamp(damage / 25, 0.3, 3)
	local scale = Opt("rvFlinch", 1)

	state.flinchP = math.Clamp(state.flinchP + power * 1.6 * scale, -8, 8)
	state.flinchY = math.Clamp(state.flinchY + math.Rand(-1, 1) * power * 1.5 * scale, -8, 8)
	state.flinchR = math.Clamp(state.flinchR + math.Rand(-1, 1) * power * 2.2 * scale, -10, 10)
	state.hurtFlash = math.min(1, state.hurtFlash + power * 0.35)

	-- рефлекторное моргание при ощутимом уроне
	if (damage >= 8 and Opt("rvBlink", true) and !state.blinkStart) then
		state.blinkReflex = true
		state.nextBlink = 0
	end
end)

-- ----------------------------------------------------------------------------
-- Камера
-- ----------------------------------------------------------------------------
function PLUGIN:CalcView(client, origin, angles, fov)
	state.active = false

	if (!ix.config.Get("rvEnabled", true)) then return end

	local k = Opt("rvIntensity", 1)
	if (k <= 0.01) then return end

	if (!IsValid(client) or !client:Alive() or !client:GetCharacter()) then return end
	if (client:GetViewEntity() != client or client:InVehicle()) then return end
	if (client:GetMoveType() == MOVETYPE_NOCLIP or client:GetObserverMode() != OBS_MODE_NONE) then return end
	if (client:ShouldDrawLocalPlayer()) then return end
	if (client.CanOverrideView and client:CanOverrideView()) then return end
	if (client.IsRagdolled and client:IsRagdolled()) then return end

	local dt = math.Clamp(FrameTime(), 0.001, 0.1)
	local ct = CurTime()
	local low = state.low

	-- множители из настроек игрока
	local bobScale = Opt("rvBobScale", 1)
	local runShake = Opt("rvRunShake", 0.6)
	local tiltScale = Opt("rvTilt", 1)
	local breathScale = Opt("rvBreath", 1)
	local swayScale = Opt("rvSway", 1)
	local landScale = Opt("rvLandScale", 1)
	local lowSway = Opt("rvLowSway", 1)

	local vel = client:GetVelocity()
	local speed = vel:Length2D()
	local walkSpeed = math.max(client:GetWalkSpeed(), 1)
	local runSpeed = math.max(client:GetRunSpeed(), walkSpeed + 1)
	local moveFrac = math.Clamp(speed / runSpeed, 0, 1.15)
	local swimming = client:WaterLevel() >= 2
	local flat = Angle(0, angles.y, 0)

	-- сглаженная скорость: убирает рывки фазы шага на неровностях и ступеньках
	state.speedSm = Lerp(math.min(dt * 8, 1), state.speedSm, speed)

	local smSpeed = state.speedSm
	local runMix = math.Clamp((smSpeed - walkSpeed) / (runSpeed - walkSpeed), 0, 1)

	-- «заземление» с задержкой: короткие отрывы от земли (ступеньки, мелкие неровности)
	-- больше не обнуляют покачивание и не вызывают ложное приземление
	if (client:OnGround() and !swimming) then
		state.groundTime = ct
	end

	local grounded = !swimming and (ct - state.groundTime) < 0.12

	if (state.firstFrame) then
		state.lastAng.p, state.lastAng.y = angles.p, angles.y
		state.firstFrame = false
	end

	-- ---- Шаговый цикл (head bob) ----
	-- длина шага растёт со скоростью, поэтому при беге частота шагов остаётся реалистичной
	local stride = Lerp(runMix, 64, 80)

	if (grounded) then
		state.stepPhase = (state.stepPhase + (smSpeed * dt / (stride * 2)) * math.pi * 2) % (math.pi * 2)
	end

	-- амплитуда почти не зависит от скорости: при беге шаги чаще, а не «трясёт» сильнее
	local ampTarget = grounded and math.Clamp(smSpeed / walkSpeed, 0, 1) or 0

	if (client:Crouching()) then
		ampTarget = ampTarget * 0.55
	end

	state.amp = Lerp(math.min(dt * 6, 1), state.amp, ampTarget)

	local ph = state.stepPhase
	local boost = state.amp * bobScale * (0.8 + 0.5 * runMix * runShake)

	-- основное — вертикальное смещение; повороты головы малы (голова в реальности стабилизируется)
	local rawZ = math.cos(ph * 2) * 0.65 * boost
	local rawY = math.sin(ph) * 0.40 * boost
	local rawPitch = -math.cos(ph * 2) * 0.16 * boost
	local rawYaw = math.sin(ph) * 0.12 * boost
	local rawRoll = math.sin(ph) * 0.28 * boost

	-- лёгкий фильтр срезает резкие всплески
	local bs = math.min(dt * 28, 1)
	local b = state.bob

	b.z = Lerp(bs, b.z, rawZ)
	b.y = Lerp(bs, b.y, rawY)
	b.p = Lerp(bs, b.p, rawPitch)
	b.yaw = Lerp(bs, b.yaw, rawYaw)
	b.r = Lerp(bs, b.r, rawRoll)

	local bobZ, bobY, bobPitch, bobYaw, bobRoll = b.z, b.y, b.p, b.yaw, b.r

	-- ---- Наклон при стрейфе и беге ----
	local strafeFrac = math.Clamp(vel:Dot(flat:Right()) / runSpeed, -1, 1)
	local fwdFrac = math.Clamp(vel:Dot(flat:Forward()) / runSpeed, -1, 1)

	state.strafeRoll = Lerp(math.min(dt * 5, 1), state.strafeRoll, strafeFrac * 1.4 * tiltScale)
	state.leanPitch = Lerp(math.min(dt * 3, 1), state.leanPitch, fwdFrac * 0.5 * tiltScale)

	-- ---- Дыхание и дрейф ----
	local breathHz = 0.22 + moveFrac * 0.35 + low * 0.25
	state.breathPhase = (state.breathPhase + dt * breathHz * math.pi * 2) % (math.pi * 2)

	local breathAmp = (0.12 + moveFrac * 0.2 + low * 0.35) * breathScale
	local breath = math.sin(state.breathPhase) * breathAmp

	local drift = (1 + low * 4) * breathScale
	local driftPitch = Noise(ct * 0.6, 1.3) * 0.08 * drift
	local driftYaw = Noise(ct * 0.5, 7.1) * 0.08 * drift

	-- ---- Приземление (пружина) ----
	if (!grounded) then
		state.airVelZ = math.min(state.airVelZ, vel.z)
		state.airTime = state.airTime + dt
	else
		-- удар только после настоящего полёта, а не после ступеньки
		if (!state.wasGround and state.airTime > 0.2) then
			local impact = math.Clamp((-state.airVelZ - 200) / 560, 0, 1.6)

			if (impact > 0) then
				state.landVel = state.landVel - impact * 60 * landScale
			end
		end

		state.airVelZ = 0
		state.airTime = 0
	end

	state.wasGround = grounded

	state.landVel = state.landVel + (-140 * state.land - 15 * state.landVel) * dt
	state.land = math.Clamp(state.land + state.landVel * dt, -10, 6)

	-- ---- Инерция поворота головы ----
	local yawD = math.Clamp(math.AngleDifference(angles.y, state.lastAng.y), -25, 25)
	local pitchD = math.Clamp(math.AngleDifference(angles.p, state.lastAng.p), -25, 25)

	state.lastAng.p, state.lastAng.y = angles.p, angles.y

	local decay = math.exp(-dt * 8)
	state.lagYaw = math.Clamp((state.lagYaw - yawD * 0.05 * swayScale) * decay, -2, 2)
	state.lagPitch = math.Clamp((state.lagPitch - pitchD * 0.05 * swayScale) * decay, -2, 2)

	local yawRate = yawD / dt
	state.turnRoll = Lerp(math.min(dt * 8, 1), state.turnRoll, math.Clamp(-yawRate * 0.003 * swayScale, -1.4, 1.4))

	-- ---- Отдача от урона (затухает) ----
	local fd = math.exp(-dt * 5)
	state.flinchP = state.flinchP * fd
	state.flinchY = state.flinchY * fd
	state.flinchR = state.flinchR * fd

	-- ---- Низкое HP: шатание, поникшая голова ----
	local lowPitch = (low * 1.0 + Noise(ct * 0.35, 5) * low * 1.0) * lowSway
	local lowYaw = Noise(ct * 0.5, 9) * low * 1.2 * lowSway
	local lowRoll = Noise(ct * 0.45, 3.3) * low * 2.2 * lowSway
	local lowZ = -low * 1.2 * lowSway

	-- ---- FOV ----
	local sprinting = Opt("rvSprintFov", true) and client:KeyDown(IN_SPEED) and grounded and smSpeed > walkSpeed * 1.05
	state.fovAdd = Lerp(math.min(dt * 3, 1), state.fovAdd, sprinting and 4 or 0)

	local newFov = fov + (state.fovAdd - state.pulse * low * 0.8) * k

	-- ---- Сборка итоговой камеры ----
	local newAngles = Angle(
		angles.p + (bobPitch + breath + driftPitch + state.leanPitch + state.lagPitch + state.land * 0.6 + state.flinchP + lowPitch) * k,
		angles.y + (bobYaw + driftYaw + state.lagYaw + state.flinchY + lowYaw) * k,
		angles.r + (bobRoll + state.strafeRoll + state.turnRoll + state.flinchR + lowRoll) * k
	)

	local newOrigin = origin
		+ flat:Right() * (bobY * k)
		+ Vector(0, 0, (bobZ + breath * 0.25 + state.land + lowZ) * k)

	-- ---- Смещение viewmodel (слабее, чтобы не складываться с родным покачиванием оружия) ----
	local vm = state.vm
	vm.x = bobY * 0.35
	vm.z = bobZ * 0.3 - state.land * 0.5 + breath * 0.05
	vm.y = 0
	vm.p = state.lagPitch * 0.9 + bobPitch * 0.3
	vm.yaw = state.lagYaw * 0.9 + bobYaw * 0.3
	vm.r = state.turnRoll * 0.5 + state.strafeRoll * 0.3

	state.active = true
	state.frame = FrameNumber()

	return {
		origin = newOrigin,
		angles = newAngles,
		fov = newFov,
		drawviewer = false
	}
end

hook.Add("CalcViewModelView", "ixRealisticView.ViewModel", function(weapon, vm, oldPos, oldAng, pos, ang)
	if (!state.active or state.frame != FrameNumber()) then return end
	if (!Opt("rvWeaponSway", true)) then return end

	local k = Opt("rvIntensity", 1)
	local o = state.vm

	pos = pos + ang:Right() * (o.x * k) + ang:Forward() * (o.y * k) + ang:Up() * (o.z * k)
	ang = Angle(ang.p + o.p * k, ang.y + o.yaw * k, ang.r + o.r * k)

	return pos, ang
end)

-- ----------------------------------------------------------------------------
-- Состояние (низкое HP, пульс, моргание) — каждый кадр
-- ----------------------------------------------------------------------------
function PLUGIN:Think()
	local client = LocalPlayer()
	if (!IsValid(client)) then return end

	local dt = math.Clamp(FrameTime(), 0.001, 0.1)
	local ct = CurTime()

	local threshold = ix.config.Get("rvLowHealth", 30)
	local health = client:Health()
	local alive = client:Alive() and client:GetCharacter() and health > 0
	local target = 0

	-- строго меньше порога: при HP < 30 эффект начинается, при 30 и выше — нет
	if (alive and health < threshold) then
		target = 0.35 + 0.65 * (1 - health / threshold)
	end

	state.low = Lerp(math.min(dt * 2.5, 1), state.low, target)

	if (state.low < 0.002) then
		state.low = 0
	end

	-- Ранение: нарастает плавно от rvEffectHealth до 1 HP (чем меньше здоровья — тем сильнее блюр и затемнение)
	local effectHp = ix.config.Get("rvEffectHealth", 70)
	local woundTarget = 0

	if (alive and health < effectHp) then
		woundTarget = math.Clamp(1 - (health - 1) / math.max(effectHp - 1, 1), 0, 1) ^ 1.2
	end

	-- ухудшение зрения происходит быстрее, чем восстановление
	local woundRate = woundTarget > state.wound and 3 or 0.8

	state.wound = Lerp(math.min(dt * woundRate, 1), state.wound, woundTarget)

	if (state.wound < 0.002) then
		state.wound = 0
	end

	-- Пульс: "туц-тук", учащается с падением HP
	local bpm = 70 + 70 * math.max(state.low, state.wound * 0.7)
	state.heart = (state.heart + dt * bpm / 60) % 1

	local ph = state.heart
	state.pulse = math.min(1, math.exp(-((ph - 0.05) / 0.05) ^ 2) + 0.6 * math.exp(-((ph - 0.32) / 0.06) ^ 2))

	state.hurtFlash = math.max(state.hurtFlash - dt * 1.8, 0)

	-- Тяжесть век: при слабости веки постепенно опускаются
	local droopTarget = 0

	if (alive) then
		droopTarget = (state.wound ^ 1.6 * 0.16 + state.low * 0.04) * math.max(Opt("rvDroop", 1), 0)
	end

	state.droop = Lerp(math.min(dt * 1.5, 1), state.droop, droopTarget)

	-- Моргание
	if (Opt("rvBlink", true) and client:Alive()) then
		local rate = math.max(Opt("rvBlinkRate", 1), 0.1)

		if (!state.blinkStart and ct >= state.nextBlink) then
			state.blinkStart = ct
			state.blinkDepth = math.Rand(0.8, 1)
			state.blinkClose = math.Rand(0.3, 0.4)
			state.blinkDur = math.Rand(0.16, 0.26) * (1 + state.wound * 0.5)

			if (state.blinkReflex) then
				-- рефлекторное моргание: быстрое и полное
				state.blinkReflex = false
				state.blinkDepth = 1
				state.blinkDur = math.Rand(0.12, 0.18)
			elseif (state.wound > 0.3 and math.random() < state.wound ^ 2 * 0.4 * math.min(Opt("rvDroop", 1), 1.5)) then
				-- тяжёлое моргание: глаза слипаются от слабости
				state.blinkDepth = 1
				state.blinkClose = 0.28
				state.blinkDur = math.Rand(0.55, 0.95)
			end
		end

		if (state.blinkStart) then
			local p = (ct - state.blinkStart) / state.blinkDur

			if (p >= 1) then
				state.blinkStart = nil
				state.blinkLid = 0

				if (math.random() < 0.12) then
					-- двойное моргание
					state.nextBlink = ct + math.Rand(0.12, 0.3)
				else
					state.nextBlink = ct + math.Rand(2.2, 5.8) / rate * (1 - state.wound * 0.35)
				end
			else
				state.blinkLid = BlinkShape(p, state.blinkClose) * state.blinkDepth
			end
		end
	else
		state.blinkStart = nil
		state.blinkLid = 0
	end
end

-- ----------------------------------------------------------------------------
-- Виньетка по краям экрана (без текстур, полосами)
-- ----------------------------------------------------------------------------
local function DrawEdgeVignette(r, g, b, maxAlpha, depth)
	if (maxAlpha < 1) then return end

	local w, h = ScrW(), ScrH()
	local step = 6
	local count = math.floor(h * depth / step)

	for i = 0, count - 1 do
		local frac = i / count
		local alpha = maxAlpha * (1 - frac) ^ 2.2

		if (alpha < 1) then break end

		surface.SetDrawColor(r, g, b, alpha)
		surface.DrawRect(0, i * step, w, step)            -- верх
		surface.DrawRect(0, h - (i + 1) * step, w, step)  -- низ
		surface.DrawRect(i * step, 0, step, h)            -- лево
		surface.DrawRect(w - (i + 1) * step, 0, step, h)  -- право
	end
end

function PLUGIN:HUDPaintBackground()
	if (!ix.config.Get("rvEnabled", true)) then return end

	local client = LocalPlayer()
	if (!IsValid(client) or !client:Alive() or !client:GetCharacter()) then return end

	local w, h = ScrW(), ScrH()

	-- лёгкое затемнение периферии (естественное зрение)
	if (Opt("rvVignette", true)) then
		DrawEdgeVignette(0, 0, 0, 85 * Opt("rvVignetteStrength", 1), 0.30)
	end

	-- затемнение и «туннельное» зрение: чем меньше здоровья, тем темнее и уже поле зрения
	local wound = state.wound

	if (wound > 0.01 and ix.config.Get("rvWoundDarken", true)) then
		local ds = Opt("rvWoundDarkenStrength", 1)
		local wave = 0.85 + 0.15 * math.sin(CurTime() * 0.9) -- медленные «волны» в глазах

		DrawEdgeVignette(0, 0, 0, math.min(255, (60 + 190 * wound) * ds) * wave * (0.85 + 0.15 * state.pulse), 0.30 + 0.30 * wound)

		surface.SetDrawColor(0, 0, 0, math.min(235, 150 * wound ^ 1.6 * ds * wave))
		surface.DrawRect(0, 0, w, h)
	end

	-- красные края при низком HP, пульсируют в такт сердцу (углы темнее за счёт наложения полос)
	local low = state.low

	if (low > 0.01 and Opt("rvLowVignette", true)) then
		local alpha = (60 + 150 * low) * (0.7 + 0.3 * state.pulse)
		DrawEdgeVignette(110, 0, 0, alpha, 0.22 + 0.2 * low)
	end

	-- короткая красная вспышка при попадании
	if (state.hurtFlash > 0.01 and Opt("rvHurtFlash", true)) then
		DrawEdgeVignette(150, 0, 0, 170 * state.hurtFlash, 0.30)
	end

	-- веки: тяжесть от слабости + прищур от яркого света + моргание
	local base = math.Clamp(state.droop + state.squint, 0, 0.5)
	local lid = base + (1 - base) * state.blinkLid * Opt("rvBlinkDepth", 0.85)

	if (lid > 0.005) then
		-- веки слегка просвечивают
		surface.SetDrawColor(0, 0, 0, lid * 60)
		surface.DrawRect(0, 0, w, h)

		DrawLids(lid * h * 0.5)
	end
end

-- ----------------------------------------------------------------------------
-- Постобработка: адаптация глаз, обесцвечивание, "туннельное" зрение, motion blur
-- ----------------------------------------------------------------------------
local cm = {
	["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0, ["$pp_colour_contrast"] = 1, ["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0
}

function PLUGIN:RenderScreenspaceEffects()
	if (!ix.config.Get("rvEnabled", true)) then return end

	local client = LocalPlayer()
	if (!IsValid(client) or !client:Alive() or !client:GetCharacter()) then return end

	local dt = math.Clamp(RealFrameTime(), 0.001, 0.1)
	local ct = CurTime()
	local k = Opt("rvIntensity", 1)
	local low = state.low
	local wound = state.wound

	local darken = ix.config.Get("rvWoundDarken", true) and Opt("rvWoundDarkenStrength", 1) or 0
	local blurStrength = ix.config.Get("rvWoundBlur", true) and Opt("rvWoundBlurStrength", 1) or 0
	local adaptK = Opt("rvAdaptStrength", 1)

	local brightness, contrast = 0, 1
	local over = 0

	-- Адаптация глаз: резкий свет слепит, резкая темнота — "ничего не видно" и постепенно проясняется
	if (Opt("rvEyeAdapt", true)) then
		local light = render.GetLightColor(EyePos())
		local lum = math.sqrt(math.Clamp(light.x * 0.2126 + light.y * 0.7152 + light.z * 0.0722, 0, 1))

		if (!state.adaptInit) then
			state.adapt = lum
			state.adaptInit = true
		end

		local diff = lum - state.adapt
		local rate = diff > 0 and 0.9 or 0.35 -- к свету глаза привыкают быстрее, чем к темноте

		state.adapt = state.adapt + diff * (1 - math.exp(-dt * rate))
		diff = lum - state.adapt

		if (diff > 0) then
			over = math.Clamp(diff * 1.4, 0, 0.5)
			brightness = brightness + over * 0.18
		else
			local under = math.Clamp(-diff * 1.2, 0, 0.5)
			brightness = brightness - under * 0.22
			contrast = contrast - under * 0.12
		end
	end

	-- Прищур от яркого света (веки опускаются в HUDPaintBackground)
	local squintTarget = (over > 0.05) and (over * 0.3 * adaptK) or 0
	state.squint = Lerp(math.min(dt * 3, 1), state.squint, squintTarget)

	cm["$pp_colour_brightness"] = brightness * k * adaptK - wound * 0.2 * darken            -- затемнение от ранения
	cm["$pp_colour_contrast"] = 1 + (contrast - 1) * k * adaptK
	cm["$pp_colour_colour"] = math.max(1 - low * 0.45 - wound * 0.35 * darken, 0.1)         -- обесцвечивание
	cm["$pp_colour_addr"] = low * 0.04 * (0.6 + state.pulse * 0.4)                           -- красноватый оттенок
	cm["$pp_colour_contrast"] = cm["$pp_colour_contrast"] - low * 0.08 - wound * 0.12 * darken

	DrawColorModify(cm)

	-- Ослепление при выходе на яркий свет
	if (over > 0.05 and k > 0.01 and adaptK > 0.01) then
		DrawBloom(0.7, over * 2.0 * k * adaptK, 7, 7, 2, 1, 1, 1, 1)
	end

	-- Размытие всего экрана: чем меньше здоровья, тем сильнее (+ короткое размытие при ударе)
	local amount = 0

	if (blurStrength > 0 and wound > 0.05) then
		local wave = 0.8 + 0.2 * math.sin(ct * 0.7 + 1.3) -- «плавающая» резкость
		amount = wound ^ 1.3 * 4.5 * blurStrength * wave * (0.92 + 0.08 * state.pulse)
	end

	if (Opt("rvHurtFlash", true)) then
		amount = amount + state.hurtFlash * 2.5
	end

	if (amount > 0.2) then
		DrawScreenBlur(math.min(amount, 9))
	end

	-- Размытие сверху и снизу — "туннельное" зрение при низком HP
	if (low > 0.15) then
		DrawToyTown(1 + math.floor(low * 2), ScrH() * (0.2 + 0.2 * low))
	end

	-- Motion blur: бег, быстрые повороты головы, слабость
	local blurTarget = 0

	if (Opt("rvMotionBlur", true)) then
		local ang = client:EyeAngles()
		local yawRate = math.AngleDifference(ang.y, state.rsYaw) / dt
		state.rsYaw = ang.y

		local speed = client:GetVelocity():Length()
		local sprint = (client:KeyDown(IN_SPEED) and speed > client:GetWalkSpeed() * 1.05) and 0.2 or 0

		blurTarget = (sprint + math.Clamp(math.abs(yawRate) / 700, 0, 0.35) + low * 0.3) * math.min(k, 1) * Opt("rvMotionBlurStrength", 1)
	end

	state.blur = Lerp(math.min(dt * 6, 1), state.blur, blurTarget)

	if (state.blur > 0.02) then
		DrawMotionBlur(1 - math.min(state.blur, 1) * 0.7, 0.8, 0.012)
	end
end