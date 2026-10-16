local PLUGIN = PLUGIN

local glowMat = Material("sprites/light_glow02_add")
local blurMat = Material("pp/blurscreen")

--[[
	НАСТРОЙКИ ИНТЕРФЕЙСА КРИТИЧЕСКОГО СОСТОЯНИЯ
	Цвета и эффекты можно менять здесь. Стиль совпадает с экраном выбора персонажа.
]]
local CFG = {
	criticalColor = Color(214, 66, 58), -- основной цвет, пока игрок угасает
	helpColor = Color(90, 160, 235), -- цвет, когда ему оказывают помощь
	sounds = true,
	soundVolume = 0.55,
	ambientLoop = "ambient/atmosphere/undercity_loop1.wav", -- глухой гул в ушах ("" = отключить)
	ambientVolume = 0.2,

	blur = 1, -- размытие зрения (0 = выкл)
	desaturate = 1, -- обесцвечивание (0 = выкл)
	vignette = 1, -- «туннельное» зрение (0 = выкл)
	scanlines = 1, -- ЭЛТ-развёртка (0 = выкл)
	grain = 1, -- зерно (0 = выкл)
	blackouts = true, -- периодические провалы сознания
	hideHelixHud = true, -- прятать полоски и прицел Helix

	vitals = true, -- колонка жизненных показателей слева
	statusPanel = true, -- колонка статуса и журнала справа
	ecg = true, -- кардиограмма
	markers = true, -- метки над лежащими игроками для остальных
	markerDistance = 650, -- дальность видимости меток

	soundSet = {
		hover = {"buttons/blip1.wav", 0.35, 115},
		click = {"buttons/button15.wav", 0.5, 100},
		deny = {"buttons/button10.wav", 0.5, 100},
		tick = {"buttons/blip2.wav", 0.22, 130},
		boom = {"ambient/machines/thumper_hit.wav", 0.6, 70},
		confirm = {"buttons/combine_button7.wav", 0.45, 100},
		reveal = {"buttons/combine_button3.wav", 0.3, 110},
		low = {"buttons/button17.wav", 0.35, 80}
	}
}

local phrases = {
	dnTitle = "КРИТИЧЕСКОЕ СОСТОЯНИЕ",
	dnSubtitle = "ЖИЗНЕННЫЕ ФУНКЦИИ НАРУШЕНЫ",
	dnStatusCritical = "ЖИЗНЕОБЕСПЕЧЕНИЕ: НЕСТАБИЛЬНО",
	dnStatusRescue = "ЖИЗНЕОБЕСПЕЧЕНИЕ: СТАБИЛИЗАЦИЯ",
	dnClass = "",
	dnClassChoice = "",

	dnLabelChoice = "ВРЕМЯ НА РЕШЕНИЕ",
	dnLabelWait = "ДО ОСТАНОВКИ СЕРДЦА",
	dnLabelRescue = "СТАБИЛИЗАЦИЯ",

	dnVitals = "ЖИЗНЕННЫЕ ПОКАЗАТЕЛИ",
	dnHealth = "ЗДОРОВЬЕ",
	dnHealthUnit = "ЕД.",
	dnPulse = "ПУЛЬС",
	dnPulseUnit = "УД/МИН",
	dnSpo2 = "SpO2",
	dnPressure = "ДАВЛЕНИЕ",
	dnConscious = "СОЗНАНИЕ",
	dnConsciousA = "СПУТАННОЕ",
	dnConsciousB = "УГАСАЕТ",
	dnConsciousC = "ПОЧТИ УТРАЧЕНО",
	dnConsciousD = "ВОССТАНАВЛИВАЕТСЯ",

	dnState = "СОСТОЯНИЕ",
	dnSinceInjury = "С МОМЕНТА ТРАВМЫ",
	dnDecision = "РЕШЕНИЕ",
	dnDecisionNone = "НЕ ПРИНЯТО",
	dnDecisionWait = "ЖДУ ПОМОЩИ",
	dnHelp = "ПОМОЩЬ",
	dnHelpNone = "НЕ ОБНАРУЖЕНА",
	dnHelpLocked = "НЕДОСТУПНА",
	dnHelpActive = "ОКАЗЫВАЕТСЯ",
	dnLog = "ЖУРНАЛ СОБЫТИЙ",
	dnEcg = "ЭКГ",

	dnLogFall = "ПАДЕНИЕ ЗАФИКСИРОВАНО",
	dnLogUnconscious = "ПОТЕРЯ СОЗНАНИЯ",
	dnLogWait = "СИГНАЛ ТРЕВОГИ ПЕРЕДАЁТСЯ",
	dnLogHelp = "ПОМОЩЬ ОБНАРУЖЕНА",
	dnLogHelpLost = "ПОМОЩЬ ПРЕРВАНА",

	dnMarker = "ПОСТРАДАВШИЙ",
	dnMarkerDeciding = "ПРИНИМАЕТ РЕШЕНИЕ",
	dnMarkerHelp = "ИДЁТ ПОМОЩЬ",
	dnPrompt = "ОКАЗАТЬ ПОМОЩЬ",
	dnPromptHold = "УДЕРЖИВАЙТЕ КНОПКУ",
	dnPromptCrouch = "ПРИСЯДЬТЕ И УДЕРЖИВАЙТЕ КНОПКУ",

	dnBtnWait = "ЖДАТЬ ПОМОЩИ",
	dnBtnWaitSub = "ПЕРЕДАТЬ СИГНАЛ И ДЕРЖАТЬСЯ",
	dnBtnDie = "УМЕРЕТЬ",
	dnBtnDieSub = "УДЕРЖИВАЙТЕ ДЛЯ ПОДТВЕРЖДЕНИЯ",
	dnBtnBusy = "ИДЁТ ОКАЗАНИЕ ПОМОЩИ"
}

ix.lang.AddTable("russian", phrases)
ix.lang.AddTable("english", phrases)

local function CreateFonts()
	local h = ScrH()

	surface.CreateFont("ixDownTitle", {font = "Roboto", size = math.floor(h * 0.034), weight = 700, extended = true, antialias = true})
	surface.CreateFont("ixDownTimer", {font = "Roboto", size = math.floor(h * 0.07), weight = 600, extended = true, antialias = true})
	surface.CreateFont("ixDownMid", {font = "Roboto", size = math.floor(h * 0.022), weight = 600, extended = true, antialias = true})
	surface.CreateFont("ixDownSmall", {font = "Roboto", size = math.floor(h * 0.016), weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixDownTiny", {font = "Roboto", size = math.floor(h * 0.012), weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixDownMono", {font = "Courier New", size = math.floor(h * 0.0135), weight = 500, extended = true, antialias = true})
end

CreateFonts()
hook.Add("ScreenResolutionChanged", "ixDownedFonts", CreateFonts)

-- ---------------------------------------------------------------------------
-- Утилиты
-- ---------------------------------------------------------------------------

local function EaseOutCubic(x)
	return 1 - (1 - x) ^ 3
end

local function Gauss(x, c, w)
	return math.exp(-((x - c) / w) ^ 2)
end

-- форма одного удара сердца на ЭКГ (зубцы P, Q, R, S, T)
local function EcgShape(ph)
	return 0.12 * Gauss(ph, 0.18, 0.035)
		- 0.14 * Gauss(ph, 0.285, 0.012)
		+ 1.0 * Gauss(ph, 0.31, 0.014)
		- 0.22 * Gauss(ph, 0.34, 0.014)
		+ 0.28 * Gauss(ph, 0.55, 0.07)
end

-- плавный подъём и спад (для провалов сознания)
local function Bell(p, c)
	if (p < c) then
		local x = p / c

		return x * x * (3 - 2 * x)
	end

	local x = (p - c) / (1 - c)

	return 1 - x * x * (3 - 2 * x)
end

local function FormatTime(sec)
	sec = math.max(math.ceil(sec), 0)

	return string.format("%02d:%02d", math.floor(sec / 60), sec % 60)
end

local function TypeText(text, p)
	local len = utf8.len(text) or #text
	local n = math.floor(len * math.Clamp(p, 0, 1))

	if (n >= len) then
		return text
	end

	return text:sub(1, (utf8.offset(text, n + 1) or (#text + 1)) - 1)
end

local lastPlayed = {}

local function PlayUI(key, pitchMul, volMul)
	if (!CFG.sounds) then return end

	local def = CFG.soundSet[key]

	if (!def) then return end

	local now = RealTime()

	if (lastPlayed[key] and now - lastPlayed[key] < 0.05) then return end

	lastPlayed[key] = now

	local vol = math.Clamp(def[2] * (volMul or 1) * CFG.soundVolume, 0, 1)
	local pitch = math.Clamp(def[3] * (pitchMul or 1), 40, 255)
	local ply = LocalPlayer()

	if (IsValid(ply)) then
		ply:EmitSound(def[1], 75, pitch, vol, CHAN_AUTO)
	else
		surface.PlaySound(def[1])
	end
end

-- ---------------------------------------------------------------------------
-- Сглаженная отрисовка (как в cl_character)
-- ---------------------------------------------------------------------------

local FEATHER = {{0, 0.6, 0.45}, {0.6, 1.3, 0.14}}
local quad = {{x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}}

local function SetQuad(x1, y1, x2, y2, x3, y3, x4, y4)
	local q = quad

	q[1].x, q[1].y = x1, y1
	q[2].x, q[2].y = x2, y2
	q[3].x, q[3].y = x3, y3
	q[4].x, q[4].y = x4, y4

	surface.DrawPoly(q)
end

local function LineBand(x1, y1, x2, y2, nx, ny, o1, o2)
	SetQuad(x1 + nx * o1, y1 + ny * o1, x2 + nx * o1, y2 + ny * o1, x2 + nx * o2, y2 + ny * o2, x1 + nx * o2, y1 + ny * o2)
end

local function SmoothLine(x1, y1, x2, y2, thick, r, g, b, a)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)

	if (len < 0.001 or a <= 0) then return end

	local nx, ny = -dy / len, dx / len
	local half = thick * 0.5

	draw.NoTexture()
	surface.SetDrawColor(r, g, b, a)
	LineBand(x1, y1, x2, y2, nx, ny, -half, half)

	for _, f in ipairs(FEATHER) do
		surface.SetDrawColor(r, g, b, a * f[3])
		LineBand(x1, y1, x2, y2, nx, ny, half + f[1], half + f[2])
		LineBand(x1, y1, x2, y2, nx, ny, -half - f[2], -half - f[1])
	end
end

local function RingBand(cx, cy, rIn, rOut, a0, step, seg)
	if (rOut <= 0) then return end

	rIn = math.max(rIn, 0)

	local c0, s0 = math.cos(a0), math.sin(a0)

	for i = 1, seg do
		local a = a0 + step * i
		local c1, s1 = math.cos(a), math.sin(a)

		SetQuad(
			cx + c0 * rOut, cy + s0 * rOut,
			cx + c1 * rOut, cy + s1 * rOut,
			cx + c1 * rIn, cy + s1 * rIn,
			cx + c0 * rIn, cy + s0 * rIn
		)

		c0, s0 = c1, s1
	end
end

local function SmoothArc(cx, cy, r, deg0, deg1, thick, seg, cr, cg, cb, ca)
	if (ca <= 0 or deg1 <= deg0) then return end

	local a0 = math.rad(deg0)
	local step = math.rad(deg1 - deg0) / seg
	local half = thick * 0.5

	draw.NoTexture()
	surface.SetDrawColor(cr, cg, cb, ca)
	RingBand(cx, cy, r - half, r + half, a0, step, seg)

	for _, f in ipairs(FEATHER) do
		surface.SetDrawColor(cr, cg, cb, ca * f[3])
		RingBand(cx, cy, r + half + f[1], r + half + f[2], a0, step, seg)
		RingBand(cx, cy, r - half - f[2], r - half - f[1], a0, step, seg)
	end
end

local function DrawBrackets(x, y, w, h, len, r, g, b, a)
	draw.NoTexture()
	surface.SetDrawColor(r, g, b, a)

	surface.DrawRect(x, y, len, 2)
	surface.DrawRect(x, y, 2, len)
	surface.DrawRect(x + w - len, y, len, 2)
	surface.DrawRect(x + w - 2, y, 2, len)
	surface.DrawRect(x, y + h - 2, len, 2)
	surface.DrawRect(x, y + h - len, 2, len)
	surface.DrawRect(x + w - len, y + h - 2, len, 2)
	surface.DrawRect(x + w - 2, y + h - len, 2, len)
end

local function Text(text, font, x, y, r, g, b, a, ax, ay)
	ax = ax or TEXT_ALIGN_LEFT
	ay = ay or TEXT_ALIGN_CENTER

	draw.SimpleText(text, font, x + 1, y + 1, Color(0, 0, 0, a * 0.6), ax, ay)
	draw.SimpleText(text, font, x, y, Color(r, g, b, a), ax, ay)
end

-- виньетка из ступенчатых полос; extH/extW — глубина в долях экрана
local function DrawVignette(w, h, strength, extH, extW, r, g, b)
	if (strength <= 0) then return end

	local n = 30
	local th = math.ceil(h * extH / n)
	local tw = math.ceil(w * extW / n)

	draw.NoTexture()

	for i = 0, n - 1 do
		local f = (1 - i / n) ^ 2.4

		surface.SetDrawColor(r, g, b, 255 * math.min(strength, 1) * f)
		surface.DrawRect(0, i * th, w, th)
		surface.DrawRect(0, h - (i + 1) * th, w, th)
		surface.DrawRect(i * tw, 0, tw, h)
		surface.DrawRect(w - (i + 1) * tw, 0, tw, h)
	end
end

local function DrawScanlines(w, h, k, now, r, g, b)
	if (k <= 0) then return end

	draw.NoTexture()
	surface.SetDrawColor(0, 0, 0, 16 * k)

	for y = 0, h, 3 do
		surface.DrawRect(0, y, w, 1)
	end

	local bandH = h * 0.16
	local y0 = ((now * h * 0.08) % (h + bandH)) - bandH
	local parts = 14

	for i = 0, parts - 1 do
		local f = math.sin((i + 0.5) / parts * math.pi)

		surface.SetDrawColor(r, g, b, 6 * f * k)
		surface.DrawRect(0, y0 + i * bandH / parts, w, math.ceil(bandH / parts) + 1)
	end
end

local function DrawGrain(w, h, k)
	if (k <= 0) then return end

	draw.NoTexture()

	for _ = 1, 55 do
		local v = math.random(130, 255)
		local s = math.random(1, 2)

		surface.SetDrawColor(v, v, v, math.random(6, 20) * k)
		surface.DrawRect(math.random(0, w), math.random(0, h), s, s)
	end
end

-- «веки»: сплошная чернота у краёв с мягкой кромкой
local function DrawLids(cover)
	local w, h = ScrW(), ScrH()
	local soft = math.max(h * 0.05, 8)
	local n = math.max(math.floor(soft / 2), 4)
	local seg = soft / n
	local solid = math.floor(cover)

	draw.NoTexture()

	if (solid > 0) then
		surface.SetDrawColor(0, 0, 0, 250)
		surface.DrawRect(0, 0, w, solid)
		surface.DrawRect(0, h - solid, w, solid)
	end

	for i = 0, n - 1 do
		local y0 = math.floor(cover + i * seg)
		local y1 = math.floor(cover + (i + 1) * seg)

		if (y1 > 0 and y1 > y0) then
			local top = math.max(y0, 0)

			surface.SetDrawColor(0, 0, 0, 250 * (1 - (i + 1) / (n + 1)) ^ 1.5)
			surface.DrawRect(0, top, w, y1 - top)
			surface.DrawRect(0, h - y1, w, y1 - top)
		end
	end
end

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

-- ---------------------------------------------------------------------------
-- Состояние интерфейса
-- ---------------------------------------------------------------------------

local ECG_N = 160

local S = {
	fade = 0, shock = 0, wasDowned = false, downedAt = 0,
	phase = 1, remaining = 0, total = 1,
	rescued = false, rescueStart = 0, rescueFade = 0, rescueProg = 0,
	urgency = 0, k = 0,
	heart = 0, bpm = 62, beatAmp = 1, beatT = 0, beatStrong = true, pulse = 0,
	ecg = {}, ecgAcc = 0,
	nextBlackout = 0, blackoutStart = nil, blackoutDur = 1, blackout = 0,
	spin = 0, lastSec = -1,
	vit = {pulse = 62, spo2 = 94, sys = 100, dia = 64},
	log = {}, ragMap = {}, ragNext = 0
}

for i = 1, ECG_N do
	S.ecg[i] = 0
end

local function AccentRGB()
	local rf = S.rescueFade
	local c, d = CFG.criticalColor, CFG.helpColor

	return Lerp(rf, c.r, d.r), Lerp(rf, c.g, d.g), Lerp(rf, c.b, d.b)
end

local function AddLog(text)
	S.log[#S.log + 1] = {t = RealTime(), text = text}

	if (#S.log > 6) then
		table.remove(S.log, 1)
	end
end

-- общий доступ для панели с кнопками
ix.downedUI = {
	CFG = CFG,
	PlayUI = PlayUI,
	SmoothLine = SmoothLine,
	EaseOutCubic = EaseOutCubic,
	GetFade = function() return S.fade end,
	GetBlackout = function() return S.blackout end
}

local function RefreshRagdolls()
	S.ragMap = {}

	for _, ent in ipairs(ents.FindByClass("prop_ragdoll")) do
		local owner = ent:GetNetVar("player")

		if (IsValid(owner)) then
			S.ragMap[owner] = ent
		end
	end
end

local function GetDownedPos(ply)
	local rag = S.ragMap[ply]

	if (IsValid(rag)) then
		return rag:GetPos() + Vector(0, 0, 12)
	end

	return ply:GetPos() + Vector(0, 0, 12)
end

local function StartAmbient(client)
	if (CFG.ambientLoop == "" or S.ambient) then return end

	S.ambient = CreateSound(client, CFG.ambientLoop)
	S.ambient:PlayEx(0, 78)
end

local function OnDowned(client)
	local now = RealTime()

	S.downedAt = now
	S.shock = 1
	S.phase = 1
	S.rescued = false
	S.rescueProg = 0
	S.lastSec = -1
	S.nextBlackout = now + math.Rand(3.5, 6)
	S.log = {}

	PlayUI("boom", 1, 1)
	StartAmbient(client)
	AddLog(L("dnLogFall"))

	timer.Simple(1.4, function()
		if (S.wasDowned) then
			AddLog(L("dnLogUnconscious"))
			PlayUI("low", 1, 1)
		end
	end)
end

local function OnRecovered(alive)
	S.rescued = false

	if (alive) then
		PlayUI("confirm", 1, 1)
	end
end

function PLUGIN:Think()
	local client = LocalPlayer()

	if (!IsValid(client)) then return end

	local dt = math.Clamp(RealFrameTime(), 0.001, 0.1)
	local now = RealTime()
	local ct = CurTime()
	local alive = client:Alive()
	local downed = alive and client:IsDowned()

	if (downed and !IsValid(self.downMenu)) then
		self.downMenu = vgui.Create("ixDownedMenu")
	elseif (!downed and IsValid(self.downMenu)) then
		self.downMenu:Remove()
	end

	if (downed and !S.wasDowned) then
		OnDowned(client)
	elseif (!downed and S.wasDowned) then
		OnRecovered(alive)
	end

	S.wasDowned = downed

	S.fade = math.Approach(S.fade, downed and 1 or 0, dt * (downed and 0.45 or (alive and 0.9 or 4)))
	S.shock = math.max(S.shock - dt * 1.4, 0)

	local target = 0
	local rescued = false

	if (downed) then
		local choiceEnd = client:GetNetVar("ixDownChoiceEnd", 0)
		local deathTime = client:GetNetVar("ixDownDeath", 0)
		local choiceTotal = math.max(ix.config.Get("downChoiceTime", 30), 1)
		local waitTotal = math.max(ix.config.Get("downWaitTime", 60), 1)

		rescued = client:GetNetVar("ixDownRescued", false)

		local phase = deathTime > 0 and 2 or 1

		if (phase == 1) then
			S.remaining = math.max(choiceEnd - ct, 0)
			S.total = choiceTotal
			target = 0.12 * (1 - S.remaining / choiceTotal)
		else
			S.remaining = math.max(deathTime - ct, 0)
			S.total = waitTotal
			target = 0.2 + 0.8 * (1 - S.remaining / waitTotal)
		end

		if (phase == 2 and S.phase != 2) then
			AddLog(L("dnLogWait"))
			PlayUI("confirm", 1, 1)
		end

		S.phase = phase

		if (rescued != S.rescued) then
			S.rescued = rescued

			if (rescued) then
				S.rescueStart = now
				AddLog(L("dnLogHelp"))
				PlayUI("reveal", 1, 1)
			else
				AddLog(L("dnLogHelpLost"))
				PlayUI("deny", 1, 1)
			end
		end

		-- отсчёт последних секунд
		local sec = math.ceil(S.remaining)

		if (!rescued and sec <= 10 and sec > 0 and sec != S.lastSec) then
			PlayUI("tick", 1 + (10 - sec) * 0.05, 1)
		end

		S.lastSec = sec
	else
		S.rescued = false
	end

	-- оценка прогресса лечения на стороне игрока (сервер шлёт только флаг)
	local reviveTime = math.max(ix.config.Get("downReviveTime", 8), 0.1)

	S.rescueProg = rescued and math.Clamp((now - S.rescueStart) / reviveTime, 0, 1) or 0
	S.rescueFade = Lerp(math.min(dt * 3, 1), S.rescueFade, rescued and 1 or 0)

	S.urgency = Lerp(math.min(dt * 2, 1), S.urgency, target)
	S.k = S.urgency * (1 - 0.6 * S.rescueProg)
	S.bpm = Lerp(S.k, 62, 34)
	S.spin = S.spin + dt * 11 * (1 - 0.65 * S.k)

	-- кардиограмма: фиксированный шаг дискретизации
	if (S.fade > 0.01) then
		local step = 0.025

		S.ecgAcc = math.min(S.ecgAcc + dt, step * 8)

		while (S.ecgAcc >= step) do
			S.ecgAcc = S.ecgAcc - step
			S.heart = S.heart + step * S.bpm / 60

			if (S.heart >= 1) then
				S.heart = S.heart - 1
				-- чем хуже состояние, тем чаще пропускаются удары
				S.beatAmp = (math.random() < S.k ^ 2 * 0.45) and 0.1 or Lerp(S.k, 1, 0.5)
				S.beatT = now
				S.beatStrong = S.beatAmp > 0.3
			end

			local v = EcgShape(S.heart) * S.beatAmp + (math.random() - 0.5) * (0.05 + S.k ^ 3 * 0.35)

			table.remove(S.ecg, 1)
			S.ecg[ECG_N] = v
		end
	end

	S.pulse = math.Clamp(Gauss(S.heart, 0.31, 0.05) * S.beatAmp, 0, 1)

	-- провалы сознания
	if (CFG.blackouts and downed and S.fade > 0.9) then
		if (!S.blackoutStart and now >= S.nextBlackout) then
			S.blackoutStart = now
			S.blackoutDur = math.Rand(0.7, 1.4) * (0.8 + S.k)
			PlayUI("boom", 0.8, 0.45)
		end

		if (S.blackoutStart) then
			local p = (now - S.blackoutStart) / S.blackoutDur

			if (p >= 1) then
				S.blackoutStart = nil
				S.blackout = 0
				S.nextBlackout = now + math.Rand(5, 11) * (1.2 - S.k * 0.6)
			else
				S.blackout = Bell(p, 0.35) * (0.7 + 0.3 * S.k)
			end
		end
	else
		S.blackoutStart = nil
		S.blackout = Lerp(math.min(dt * 6, 1), S.blackout, 0)
	end

	-- плавное сглаживание показателей
	local v = S.vit
	local ks = math.min(dt * 1.5, 1)

	v.pulse = Lerp(ks, v.pulse, S.bpm)
	v.spo2 = Lerp(ks, v.spo2, Lerp(S.k, 94, 58))
	v.sys = Lerp(ks, v.sys, Lerp(S.k, 100, 44))
	v.dia = Lerp(ks, v.dia, Lerp(S.k, 64, 24))

	-- сопоставление рэгдоллов и игроков (для меток и подсказок)
	if (now >= S.ragNext) then
		S.ragNext = now + 0.5

		for _, ply in ipairs(player.GetAll()) do
			if (ply:IsDowned()) then
				RefreshRagdolls()
				break
			end
		end
	end

	-- фоновый гул в ушах
	if (S.ambient) then
		if (S.fade <= 0.002 and !downed) then
			S.ambient:Stop()
			S.ambient = nil
		else
			S.ambient:ChangeVolume(CFG.ambientVolume * S.fade * CFG.soundVolume, 0)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Эффекты на мир: обесцвечивание, размытие, затемнение
-- ---------------------------------------------------------------------------

local cm = {
	["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0, ["$pp_colour_contrast"] = 1, ["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0
}

function PLUGIN:RenderScreenspaceEffects()
	local f = S.fade
	local shock = S.shock

	if (f <= 0.002 and shock <= 0.002) then return end

	local k = S.k

	cm["$pp_colour_colour"] = math.max(1 - f * 0.88 * CFG.desaturate, 0.05)
	cm["$pp_colour_brightness"] = -0.04 * f - 0.1 * f * (0.4 + k) - S.blackout * 0.35
	cm["$pp_colour_contrast"] = 1 - 0.18 * f
	cm["$pp_colour_addr"] = 0.02 * f * (0.6 + 0.4 * S.pulse)

	DrawColorModify(cm)

	local blur = (f * (1.2 + 5 * k) + S.blackout * 2 + shock * 3) * CFG.blur

	if (blur > 0.2) then
		DrawScreenBlur(math.min(blur, 8))
	end

	if (f > 0.05) then
		DrawMotionBlur(1 - f * 0.35 * CFG.blur, 0.85, 0.015)
	end
end

function PLUGIN:HUDPaintBackground()
	local f = S.fade
	local shock = S.shock

	if (f <= 0.002 and shock <= 0.002) then return end

	local w, h = ScrW(), ScrH()
	local now = RealTime()
	local k = S.k
	local ar, ag, ab = AccentRGB()

	draw.NoTexture()

	-- общее затемнение + провал сознания
	surface.SetDrawColor(5, 7, 12, math.min(f * (55 + 110 * k) + S.blackout * 220, 255))
	surface.DrawRect(0, 0, w, h)

	-- «туннельное» зрение: сужается по мере угасания
	DrawVignette(w, h, f * (0.75 + 0.25 * k) * CFG.vignette, 0.2 + 0.3 * k, 0.12 + 0.2 * k, 0, 0, 0)

	-- красные края, пульсирующие в такт сердцу
	DrawVignette(w, h, f * (0.2 + 0.35 * k) * (0.5 + 0.5 * S.pulse) * CFG.vignette, 0.16, 0.1, ar, ag, ab)

	-- вспышка в момент падения
	if (shock > 0.002) then
		surface.SetDrawColor(255, 70, 60, 170 * shock ^ 2)
		surface.DrawRect(0, 0, w, h)

		DrawVignette(w, h, shock, 0.4, 0.25, 160, 10, 10)
	end

	-- тяжёлые веки и полное закрытие при провале
	local lid = math.Clamp(f * (0.04 + 0.22 * k) * (0.85 + 0.15 * math.sin(now * 0.9)) + S.blackout, 0, 1)

	if (lid > 0.005) then
		DrawLids(lid * h * 0.5)
	end
end

if (CFG.hideHelixHud) then
	function PLUGIN:ShouldHideBars()
		if (S.fade > 0.05) then
			return true
		end
	end

	function PLUGIN:ShouldDrawCrosshair()
		if (S.fade > 0.05) then
			return false
		end
	end
end

-- ---------------------------------------------------------------------------
-- Основной интерфейс пострадавшего
-- ---------------------------------------------------------------------------

local function DrawRow(x, y, width, label, value, ar, ag, ab, ha, frac)
	Text(label, "ixDownMono", x, y, ar, ag, ab, 150 * ha)
	Text(value, "ixDownMono", x + width, y, 255, 255, 255, 215 * ha, TEXT_ALIGN_RIGHT)

	if (frac) then
		draw.NoTexture()
		surface.SetDrawColor(ar, ag, ab, 45 * ha)
		surface.DrawRect(x, y + 10, width, 2)
		surface.SetDrawColor(ar, ag, ab, 200 * ha)
		surface.DrawRect(x, y + 10, math.floor(width * math.Clamp(frac, 0, 1)), 2)
	end
end

local function DrawColumnHeader(x, y, width, label, ar, ag, ab, ha)
	Text(label, "ixDownSmall", x, y, 255, 255, 255, 150 * ha)

	draw.NoTexture()
	surface.SetDrawColor(ar, ag, ab, 90 * ha)
	surface.DrawRect(x, y + 12, width, 1)
end

local function DrawEcg(cx, ey, ew, eh, ar, ag, ab, ha)
	local x0 = cx - ew * 0.5
	local y0 = ey - eh * 0.5

	-- рамка и сетка
	draw.NoTexture()
	surface.SetDrawColor(ar, ag, ab, 28 * ha)
	surface.DrawRect(x0, ey, ew, 1)

	for i = 1, 9 do
		surface.DrawRect(x0 + ew * i / 10, y0, 1, eh)
	end

	DrawBrackets(x0 - 8, y0 - 6, ew + 16, eh + 12, 10, ar, ag, ab, 120 * ha)

	Text(L("dnEcg"), "ixDownMono", x0 - 8, y0 - 18, ar, ag, ab, 150 * ha)
	Text(string.format("%d %s", math.floor(S.vit.pulse), L("dnPulseUnit")), "ixDownMono", x0 + ew + 8, y0 - 18, 255, 255, 255, 190 * ha, TEXT_ALIGN_RIGHT)

	-- линия, новая часть справа ярче
	local px, py

	for i = 1, ECG_N do
		local x = x0 + (i - 1) / (ECG_N - 1) * ew
		local y = ey - math.Clamp(S.ecg[i], -0.6, 1.2) * eh * 0.42

		if (px) then
			local a = (40 + 215 * (i / ECG_N) ^ 1.5) * ha

			SmoothLine(px, py, x, y, 1.6, ar, ag, ab, a)
		end

		px, py = x, y
	end

	if (px) then
		surface.SetMaterial(glowMat)
		surface.SetDrawColor(255, 255, 255, 140 * ha)
		surface.DrawTexturedRect(px - 14, py - 14, 28, 28)
		draw.NoTexture()
	end
end

local function DrawMain(client, w, h, ha)
	local now = RealTime()
	local ar, ag, ab = AccentRGB()
	local cx, cy = math.floor(w * 0.5), math.floor(h * 0.43)
	local R = math.floor(h * 0.16)
	local m = 28
	local sinceFall = now - S.downedAt

	local frac, timerText, label

	if (S.rescued) then
		frac = S.rescueProg
		timerText = string.format("%d%%", math.floor(frac * 100))
		label = L("dnLabelRescue")
	else
		frac = S.total > 0 and math.Clamp(S.remaining / S.total, 0, 1) or 0
		timerText = FormatTime(S.remaining)
		label = S.phase == 2 and L("dnLabelWait") or L("dnLabelChoice")
	end

	-- ===== заголовок =====
	local tp = (sinceFall - 0.6) / 1.1
	local title = TypeText(L("dnTitle"), tp)
	local ty = cy - R - 50 - math.floor(h * 0.07) -- выше внешних дуг кольца (R+44)

	if (tp > 0) then
		if (sinceFall < 2.4 or math.random() < 0.004) then
			local off = math.random(2, 5)

			Text(title, "ixDownTitle", cx - off, ty, ar, ag, ab, 140 * ha, TEXT_ALIGN_CENTER)
			Text(title, "ixDownTitle", cx + off, ty, 90, 160, 235, 90 * ha, TEXT_ALIGN_CENTER)
		end

		Text(title, "ixDownTitle", cx, ty, 255, 255, 255, 245 * ha, TEXT_ALIGN_CENTER)

		surface.SetFont("ixDownTitle")

		local tw = surface.GetTextSize(L("dnTitle"))
		local subA = math.Clamp((tp - 0.6) / 0.4, 0, 1)

		Text(L("dnSubtitle"), "ixDownSmall", cx, ty + math.floor(h * 0.034), 255, 255, 255, 150 * ha * subA, TEXT_ALIGN_CENTER)

		draw.NoTexture()
		surface.SetDrawColor(ar, ag, ab, 110 * ha * subA)
		surface.DrawRect(cx - tw * 0.5 - 40, ty + math.floor(h * 0.05), tw + 80, 1)
		DrawBrackets(cx - tw * 0.5 - 52, ty - math.floor(h * 0.026), tw + 104, math.floor(h * 0.08), 8, 255, 255, 255, 120 * ha * subA)
	end

	-- ===== центральное кольцо =====
	surface.SetMaterial(glowMat)
	surface.SetDrawColor(ar, ag, ab, (22 + 30 * S.pulse) * ha)
	surface.DrawTexturedRect(cx - R * 1.4, cy - R * 1.4, R * 2.8, R * 2.8)
	draw.NoTexture()

	SmoothArc(cx, cy, R, 0, 360, 1, 120, ar, ag, ab, 70 * ha)

	-- деления: подсвечены те, что соответствуют оставшемуся времени
	for i = 0, 59 do
		local a = math.rad(i * 6 - 90)
		local major = i % 5 == 0
		local r1 = R - (major and 14 or 8)
		local r2 = R - 3
		local lit = (i / 60) <= frac
		local c, s = math.cos(a), math.sin(a)

		SmoothLine(cx + c * r1, cy + s * r1, cx + c * r2, cy + s * r2, major and 2 or 1,
			lit and 255 or ar, lit and 255 or ag, lit and 255 or ab, (lit and 200 or 55) * ha)
	end

	-- дуга оставшегося времени
	local rp = R + 14

	if (frac < 0.998) then
		SmoothArc(cx, cy, rp, -90 + 360 * frac, 270, 3, math.max(math.floor((1 - frac) * 140), 2), ar, ag, ab, 40 * ha)
	end

	if (frac > 0.002) then
		local seg = math.max(math.floor(frac * 140), 2)

		SmoothArc(cx, cy, rp, -90, -90 + 360 * frac, 10, seg, ar, ag, ab, 38 * ha)
		SmoothArc(cx, cy, rp, -90, -90 + 360 * frac, 3, seg, 255, 255, 255, 235 * ha)

		local ae = math.rad(-90 + 360 * frac)

		surface.SetMaterial(glowMat)
		surface.SetDrawColor(255, 255, 255, 150 * ha)
		surface.DrawTexturedRect(cx + math.cos(ae) * rp - 22, cy + math.sin(ae) * rp - 22, 44, 44)
		draw.NoTexture()
	end

	-- вращающиеся сегменты: замедляются, когда пострадавший угасает
	local base = S.spin

	for i = 0, 5 do
		local sa = base + i * 60

		SmoothArc(cx, cy, R + 34, sa, sa + 32, 2, 14, ar, ag, ab, 150 * ha)
	end

	for i = 0, 11 do
		local sa = -base * 1.9 + i * 30

		SmoothArc(cx, cy, R - 28, sa, sa + 12, 1, 6, ar, ag, ab, 95 * ha)
	end

	local sway = math.sin(now * 0.7) * 22

	for q = 0, 3 do
		local sa = q * 90 + sway - 13

		SmoothArc(cx, cy, R + 44, sa, sa + 26, 3, 12, 255, 255, 255, 185 * ha)
	end

	-- расходящееся кольцо на каждый удар сердца
	local bp = (now - S.beatT) / 0.95

	if (S.beatStrong and bp > 0 and bp < 1) then
		SmoothArc(cx, cy, R * (0.35 + 0.55 * EaseOutCubic(bp)), 0, 360, 2, 90, ar, ag, ab, 110 * (1 - bp) ^ 2 * ha)
	end

	-- цифры в центре
	local warn = (!S.rescued and S.remaining <= 10 and S.remaining > 0)
	local blink = warn and (0.55 + 0.45 * math.abs(math.sin(now * 5))) or 1

	Text(timerText, "ixDownTimer", cx, cy - math.floor(h * 0.008), 255, warn and 140 or 255, warn and 130 or 255, 245 * ha * blink, TEXT_ALIGN_CENTER)
	Text(label, "ixDownSmall", cx, cy + math.floor(h * 0.05), ar, ag, ab, 210 * ha, TEXT_ALIGN_CENTER)

	-- ===== ЭКГ =====
	if (CFG.ecg) then
		DrawEcg(cx, cy + R + math.floor(h * 0.1), math.floor(w * 0.28), math.floor(h * 0.065), ar, ag, ab, ha)
	end

	local lh = math.floor(h * 0.03)
	local colW = math.floor(h * 0.23)

	-- ===== жизненные показатели (слева) =====
	if (CFG.vitals) then
		local x = m + 12
		local y0 = math.floor(h * 0.5 - lh * 2.5)
		local v = S.vit
		local jit = math.sin(now * 3.1) * 1.2

		DrawColumnHeader(x, y0 - lh * 1.5, colW, L("dnVitals"), ar, ag, ab, ha)

		local threshold = math.max(ix.config.Get("downHealth", 5), 1)

		DrawRow(x, y0, colW, L("dnHealth"), string.format("%d %s", math.max(client:Health(), 0), L("dnHealthUnit")), ar, ag, ab, ha, client:Health() / threshold)
		DrawRow(x, y0 + lh, colW, L("dnPulse"), string.format("%d %s", math.floor(v.pulse + jit), L("dnPulseUnit")), ar, ag, ab, ha, v.pulse / 100)
		DrawRow(x, y0 + lh * 2, colW, L("dnSpo2"), string.format("%d%%", math.floor(v.spo2 + jit * 0.5)), ar, ag, ab, ha, (v.spo2 - 50) / 50)
		DrawRow(x, y0 + lh * 3, colW, L("dnPressure"), string.format("%d/%d", math.floor(v.sys + jit), math.floor(v.dia + jit * 0.5)), ar, ag, ab, ha, v.sys / 120)

		local state

		if (S.rescued) then
			state = L("dnConsciousD")
		elseif (S.k > 0.7) then
			state = L("dnConsciousC")
		elseif (S.k > 0.3) then
			state = L("dnConsciousB")
		else
			state = L("dnConsciousA")
		end

		DrawRow(x, y0 + lh * 4, colW, L("dnConscious"), state, ar, ag, ab, ha)
	end

	-- ===== состояние и журнал (справа) =====
	if (CFG.statusPanel) then
		local x = w - m - 12 - colW
		local y0 = math.floor(h * 0.5 - lh * 2.5)

		DrawColumnHeader(x, y0 - lh * 1.5, colW, L("dnState"), ar, ag, ab, ha)

		DrawRow(x, y0, colW, L("dnSinceInjury"), FormatTime(sinceFall), ar, ag, ab, ha)
		DrawRow(x, y0 + lh, colW, L("dnDecision"), S.phase == 2 and L("dnDecisionWait") or L("dnDecisionNone"), ar, ag, ab, ha)
		local helpText = S.rescued and L("dnHelpActive") or (S.phase == 2 and L("dnHelpNone") or L("dnHelpLocked"))

		DrawRow(x, y0 + lh * 2, colW, L("dnHelp"), helpText, ar, ag, ab, ha)

		local ly = y0 + lh * 3.8

		DrawColumnHeader(x, ly, colW, L("dnLog"), ar, ag, ab, ha)

		local n = #S.log

		for i = 1, n do
			local entry = S.log[i]
			local newest = i == n
			local text = string.format("[%s] %s", FormatTime(entry.t - S.downedAt), entry.text)

			if (newest) then
				text = TypeText(text, (now - entry.t) / 0.5)
			end

			Text(text, "ixDownMono", x, ly + lh * 1.1 + (i - 1) * lh * 0.85, 255, 255, 255, (newest and 220 or 110) * ha)
		end
	end

	-- ===== статус и подпись =====
	local statusText = S.rescued and L("dnStatusRescue") or L("dnStatusCritical")
	local dot = 0.45 + 0.55 * math.abs(math.sin(now * (S.rescued and 2 or 3.2)))

	Text(statusText, "ixDownSmall", w - m - 20, m + 14, 255, 255, 255, 190 * ha, TEXT_ALIGN_RIGHT)
	draw.NoTexture()
	surface.SetDrawColor(ar, ag, ab, 255 * dot * ha)
	surface.DrawRect(w - m - 10, m + 10, 8, 8)

	Text(S.phase == 2 and L("dnClass") or L("dnClassChoice"), "ixDownTiny", cx, h - 28, 255, 255, 255, 85 * ha, TEXT_ALIGN_CENTER)
end

-- ---------------------------------------------------------------------------
-- Интерфейс для тех, кто рядом с пострадавшим
-- ---------------------------------------------------------------------------

-- помочь можно только тому, кто сам выбрал «Ждать помощи»
local function IsHelpable(ply)
	return ply:IsDowned() and ply:GetNetVar("ixDownDeath", 0) > 0
end

local function GetLookedDowned(client)
	local start = client:GetShootPos()
	local trace = util.TraceLine({
		start = start,
		endpos = start + client:GetAimVector() * ix.config.Get("downReviveDistance", 90),
		filter = client,
		mask = MASK_SHOT
	})

	local entity = trace.Entity

	if (!IsValid(entity)) then return end

	if (entity:IsPlayer()) then
		return (entity != client and IsHelpable(entity)) and entity or nil
	end

	for ply, rag in pairs(S.ragMap) do
		if (IsValid(ply) and rag == entity and IsHelpable(ply)) then
			return ply
		end
	end

	if (entity:IsRagdoll()) then
		for _, other in ipairs(player.GetAll()) do
			if (other != client and IsHelpable(other) and other:GetPos():DistToSqr(entity:GetPos()) < 6400) then
				return other
			end
		end
	end
end

local function DrawPrompt(client, w, h)
	local now = RealTime()
	local ar, ag, ab = CFG.helpColor.r, CFG.helpColor.g, CFG.helpColor.b
	local key = (input.LookupBinding("+use") or "e"):upper()
	local needCrouch = ix.config.Get("downRequireCrouch", true) and !client:Crouching()
	local sub = needCrouch and L("dnPromptCrouch") or L("dnPromptHold")
	local pw, ph = math.floor(h * 0.34), math.floor(h * 0.075)
	local x, y = math.floor(w * 0.5 - pw * 0.5), math.floor(h * 0.62)
	local breathe = 0.85 + 0.15 * math.sin(now * 3)

	draw.NoTexture()
	surface.SetDrawColor(7, 10, 15, 190)
	surface.DrawRect(x, y, pw, ph)
	surface.SetDrawColor(ar, ag, ab, 22)
	surface.DrawRect(x, y, pw, ph)

	DrawBrackets(x, y, pw, ph, 10, ar, ag, ab, 200 * breathe)

	-- «клавиша»
	local kb = ph - 22
	local kx, ky = x + 14, y + 11

	surface.SetDrawColor(255, 255, 255, needCrouch and 70 or 230)
	surface.DrawOutlinedRect(kx, ky, kb, kb, 2)
	Text(key, "ixDownMid", kx + kb * 0.5, ky + kb * 0.5, 255, 255, 255, needCrouch and 120 or 255, TEXT_ALIGN_CENTER)

	Text(L("dnPrompt"), "ixDownMid", kx + kb + 16, y + ph * 0.36, 255, 255, 255, 240)
	Text(sub, "ixDownTiny", kx + kb + 16, y + ph * 0.72, ar, ag, ab, needCrouch and 230 or 160)
end

local function DrawMarker(client, ply, w, h)
	local eye = client:EyePos()
	local pos = GetDownedPos(ply)
	local dist = eye:Distance(pos)
	local maxDist = CFG.markerDistance

	if (dist > maxDist) then return end

	local tr = util.TraceLine({
		start = eye,
		endpos = pos,
		filter = {client, ply, S.ragMap[ply]},
		mask = MASK_OPAQUE
	})

	if (tr.Hit) then return end

	local sp = pos:ToScreen()

	if (!sp.visible) then return end

	local now = RealTime()
	local fa = math.Clamp(1 - (dist - 200) / math.max(maxDist - 200, 1), 0.25, 1)
	local rescued = ply:GetNetVar("ixDownRescued", false)
	local c = rescued and CFG.helpColor or CFG.criticalColor
	local x, y = sp.x, sp.y - 30
	local size = 22

	SmoothArc(x, y, size + 3 + math.sin(now * 3) * 2, 0, 360, 1, 40, c.r, c.g, c.b, 140 * fa)
	DrawBrackets(x - size, y - size, size * 2, size * 2, 7, 255, 255, 255, 190 * fa)

	local deathTime = ply:GetNetVar("ixDownDeath", 0)
	local info

	if (rescued) then
		info = L("dnMarkerHelp")
	elseif (deathTime > 0) then
		info = FormatTime(deathTime - CurTime())
	else
		info = L("dnMarkerDeciding")
	end

	Text(L("dnMarker"), "ixDownTiny", x, y - size - 14, c.r, c.g, c.b, 235 * fa, TEXT_ALIGN_CENTER)
	Text(info, "ixDownSmall", x, y + size + 12, 255, 255, 255, 230 * fa, TEXT_ALIGN_CENTER)
	Text(string.format("%d М", math.floor(dist * 0.01905)), "ixDownTiny", x, y + size + 28, 255, 255, 255, 140 * fa, TEXT_ALIGN_CENTER)
end

function PLUGIN:HUDPaint()
	local client = LocalPlayer()

	if (!IsValid(client)) then return end

	local w, h = ScrW(), ScrH()

	if (S.fade > 0.002) then
		local ha = math.Clamp((S.fade - 0.35) / 0.45, 0, 1) * (1 - S.blackout * 0.9)

		if (client:Alive() and client:IsDowned() and ha > 0.002) then
			DrawMain(client, w, h, ha)
		end

		-- атмосфера поверх всего
		local ar, ag, ab = AccentRGB()

		DrawScanlines(w, h, CFG.scanlines * S.fade, RealTime(), ar, ag, ab)
		DrawGrain(w, h, CFG.grain * S.fade)
	end

	if (client:Alive() and !client:IsDowned()) then
		if (CFG.markers) then
			for _, ply in ipairs(player.GetAll()) do
				if (ply != client and ply:Alive() and ply:IsDowned()) then
					DrawMarker(client, ply, w, h)
				end
			end
		end

		if (GetLookedDowned(client)) then
			DrawPrompt(client, w, h)
		end
	end
end