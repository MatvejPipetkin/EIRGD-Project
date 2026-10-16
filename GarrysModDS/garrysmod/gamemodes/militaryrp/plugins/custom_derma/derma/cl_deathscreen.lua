local DS = {
	PlaySounds = true,

	-- Звуки (если файла нет в вашей сборке - просто замените путь или поставьте nil)
	ImpactSound = "physics/body/body_medium_impact_hard1.wav", -- глухой удар в момент смерти
	BeatSound = "player/heartbeat1.wav",
	FlatlineSound = "hl1/fvox/flatline.wav",

	-- Цвет кардиограммы
	TraceColor = Color(205, 210, 215),

	-- Строка внизу (поставьте nil, чтобы убрать)
	Footer = "Ты больше не помнишь обстоятельств своей гибели.",

	-- Подзаголовок под именем персонажа (появляется, когда сердце остановилось)
	Subtitle = "Сердце больше не бьётся.",

	-- Мысли. Каждый раз выбираются случайные, без повторов.
	Thoughts = {
		"Всё, что ты строил, обрывается на полуслове.",
		"Кто-то ещё ждёт тебя. И не дождётся.",
		"То, о чём ты думал в последний миг, уже не имеет значения.",
		"Тишина оказалась не такой страшной. Страшно то, что в ней больше никого нет.",
		"Ты столько раз откладывал всё на потом. Потом не наступит.",
		"Мир не остановился. Он просто продолжил без тебя.",
		"Ты успел сказать всё, что хотел? А тем, кому нужно было?",
		"Тепло уходит из рук. Мысли становятся тише.",
		"Твоё имя ещё будут произносить, но уже в прошедшем времени.",
		"Каждый выбор вёл сюда. Был ли среди них тот, который можно было изменить?",
		"Странно. Совсем не больно. Только очень тихо.",
		"Где-то на столе остынет недопитая чашка.",
		"Ты думал, что впереди ещё будет время всё исправить.",
		"Звуки отдаляются, будто кто-то медленно закрывает дверь.",
		"Последнее, что ты запомнил, уже ускользает. Как сон под утро.",
		"Свет внутри становится всё меньше, но не гаснет. Пока нет.",
		"Кто расскажет, каким ты был? И расскажет ли правду?",
		"Холод поднимается от пальцев. Он не злой. Он просто приходит.",
		"Всё, что казалось важным, вдруг стало очень лёгким.",
	},

	-- Обрывки воспоминаний: тихо проступают и растворяются по краям экрана
	Fragments = {
		"голос, зовущий по имени",
		"запах дождя на асфальте",
		"тёплая ладонь",
		"скрип старой двери",
		"свет в окне напротив",
		"чей-то смех в соседней комнате",
		"вкус горячего чая",
		"дорога, по которой ты шёл столько раз",
		"незаконченный разговор",
		"шаги, которые стихли вдали",
		"лицо, которое уже не вспомнить",
		"обещание, которое не сдержал",
		"утренний свет на стене",
		"песня, мелодию которой не вспомнить",
	},

	-- Стадии угасания. Первое число - момент в долях времени работы сердца
	-- (0 - начало, 1 - остановка сердца, больше 1 - после остановки).
	Stages = {
		{0.00, "Сознание гаснет"},
		{0.18, "Дыхание сбивается"},
		{0.40, "Давление падает"},
		{0.62, "Звуки уходят вдаль"},
		{0.82, "Пульс едва ощутим"},
		{1.00, "Сердце остановилось"},
		{1.45, "Тишина"},
	},

	TraceRate = 120,    -- частота «семплов» кардиограммы в секунду
	TracePoints = 300,  -- длина линии кардиограммы
	StartBPM = 112,     -- пульс в момент смерти
	MoteCount = 34,     -- пылинки, плавающие в темноте
}

-- ============================================================
-- ШРИФТЫ
-- ============================================================
local function CreateDeathFonts()
	surface.CreateFont("ixDeathScreenName", {
		font = "Times New Roman",
		size = ScreenScaleH(28),
		weight = 400,
		extended = true,
	})

	surface.CreateFont("ixDeathScreenSub", {
		font = "Times New Roman",
		size = ScreenScaleH(12),
		weight = 300,
		italic = true,
		extended = true,
	})

	surface.CreateFont("ixDeathScreenThought", {
		font = "Times New Roman",
		size = ScreenScaleH(16),
		weight = 300,
		italic = true,
		extended = true,
	})

	surface.CreateFont("ixDeathScreenFrag", {
		font = "Times New Roman",
		size = ScreenScaleH(11),
		weight = 300,
		italic = true,
		extended = true,
	})

	surface.CreateFont("ixDeathScreenSmall", {
		font = "Arial",
		size = ScreenScaleH(8),
		weight = 300,
		extended = true,
	})

	surface.CreateFont("ixDeathScreenMono", {
		font = "Courier New",
		size = ScreenScaleH(7.5),
		weight = 500,
		extended = true,
	})
end

CreateDeathFonts()
hook.Add("LoadFonts", "ixDeathScreenFonts", CreateDeathFonts)
hook.Add("ScreenResolutionChanged", "ixDeathScreenFontsRes", CreateDeathFonts)

-- ============================================================
-- ВСПОМОГАТЕЛЬНОЕ
-- ============================================================
local function Ease(x)
	x = math.Clamp(x, 0, 1)

	return x * x * (3 - 2 * x)
end

-- Мягкая виньетка по краям экрана
local function DrawVignette(w, h, size, alpha, r, g, b)
	if (alpha <= 1) then return end

	draw.NoTexture()

	local steps = 16
	local step = size / steps
	local thick = math.ceil(step) + 1

	for i = 0, steps - 1 do
		local al = alpha * (1 - i / steps) ^ 2
		local inset = i * step

		surface.SetDrawColor(r, g, b, al)
		surface.DrawOutlinedRect(inset, inset, w - inset * 2, h - inset * 2, thick)
	end
end

local function Gauss(x, c, w)
	return math.exp(-((x - c) / w) ^ 2)
end

-- Форма одного удара сердца (ЭКГ).
-- p - фаза удара 0..1, T - длительность удара в секундах,
-- wide - расширение комплекса QRS (умирающее сердце бьётся «широко» и вяло).
local function ECG(p, T, wide)
	local k = wide / T
	local dq, ds = 0.028 * k, 0.032 * k

	return 0.11 * Gauss(p, 0.15, 0.04)                 -- P
		- 0.14 * Gauss(p, 0.30 - dq, 0.014 * k)        -- Q
		+ 1.00 * Gauss(p, 0.30, 0.017 * k)             -- R
		- 0.26 * Gauss(p, 0.30 + ds, 0.015 * k)        -- S
		+ 0.24 * Gauss(p, 0.55 + 0.03 * (wide - 1), 0.065) -- T
end

-- Раскладка мысли по словам: нужна, чтобы слова проявлялись по одному
local function LayoutThought(text, font, maxW)
	surface.SetFont(font)

	local spaceW = surface.GetTextSize(" ")
	local lines, cur, curW, index = {}, {}, 0, 0

	for word in string.gmatch(text, "%S+") do
		local ww = surface.GetTextSize(word)

		if (#cur > 0 and curW + spaceW + ww > maxW) then
			lines[#lines + 1] = {words = cur, w = curW}
			cur, curW = {}, 0
		end

		local x = (#cur > 0) and (curW + spaceW) or 0

		index = index + 1
		cur[#cur + 1] = {text = word, x = x, w = ww, i = index}
		curW = x + ww
	end

	if (#cur > 0) then
		lines[#lines + 1] = {words = cur, w = curW}
	end

	return lines, index
end

local function FormatTime(sec)
	sec = math.max(math.ceil(sec), 0)

	if (sec >= 60) then
		return string.format("%02d:%02d", math.floor(sec / 60), sec % 60)
	end

	return sec .. " с"
end

local function TypeText(text, p)
	local len = utf8.len(text) or #text
	local n = math.floor(len * math.Clamp(p, 0, 1))

	if (n >= len) then
		return text
	end

	return string.sub(text, 1, (utf8.offset(text, n + 1) or (#text + 1)) - 1)
end

-- Состояние слота мысли: проявление по словам, затем плавное исчезновение
local function SlotState(slot, t)
	if (t < slot.from or t > slot.to) then
		return nil
	end

	local p = (t - slot.from) / (slot.to - slot.from)
	local reveal = math.Clamp(p / 0.4, 0, 1)
	local fade = slot.last and 1 or (1 - Ease((p - 0.78) / 0.22))

	return reveal, fade
end

-- ============================================================
-- ПАНЕЛЬ
-- ============================================================
local activePanel
local PANEL = {}

function PANEL:Init()
	activePanel = self

	local scrW, scrH = ScrW(), ScrH()

	self:SetSize(scrW, scrH)
	self:SetPos(0, 0)
	self:SetZPos(32767)

	-- ДЛИТЕЛЬНОСТЬ БЕРЁТСЯ ИЗ КОНФИГА СЕРВЕРА
	self.duration = math.max(ix.config.Get("spawnTime", 5), 1)
	self.startTime = CurTime()

	self.t = 0                 -- общий прогресс 0..1 (по spawnTime)
	self.el = 0                -- прошедшие секунды
	self.alphaMul = 1          -- общий множитель прозрачности (для закрытия)
	self.progress = 0

	-- За это время сердце успевает остановиться
	self.heartTime = math.max(math.min(math.Clamp(self.duration * 0.5, 2.5, 14), self.duration * 0.85), 0.8)

	-- Сердце
	self.hp = 0                -- 0 - бьётся, 1 - остановилось
	self.flatlined = false
	self.pulse = 0
	self.sampleAcc = 0
	self.wander = math.Rand(0, 6.28)
	self.dispBpm = DS.StartBPM
	self.trace = {}

	for i = 1, DS.TracePoints do
		self.trace[i] = 0
	end

	self:NextBeat()

	-- Имя персонажа
	local char = LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()
	local name = char and char:GetName() or LocalPlayer():Nick()
	self.charName = string.utf8upper(name)

	-- Пылинки в темноте
	self.motes = {}

	for i = 1, DS.MoteCount do
		self.motes[i] = {
			x = math.Rand(0, 1),
			y = math.Rand(0, 1),
			speed = math.Rand(0.004, 0.012),
			drift = math.Rand(-0.004, 0.004),
			size = math.random(1, 2),
			phase = math.Rand(0, 6.28),
			rate = math.Rand(0.4, 1.4),
		}
	end

	-- Стадии угасания
	self.stages = {}

	for _, st in ipairs(DS.Stages) do
		self.stages[#self.stages + 1] = {
			text = st[2],
			time = 0.5 + st[1] * (self.heartTime - 0.5)
		}
	end

	-- Расписание текстов
	self:BuildSlots()
	self:BuildFragments()

	-- Глухой удар: сознание отключилось мгновенно
	self:OnImpact()

	-- Анимация только для вызова завершения (все визуальные эффекты считаются по времени)
	self:CreateAnimation(self.duration, {
		bIgnoreConfig = true,
		target = {progress = 1},

		OnComplete = function(animation, panel)
			if (!panel:IsClosing()) then
				panel:Close()
			end
		end
	})
end

function PANEL:BuildSlots()
	local maxW = ScrW() * 0.55

	-- Сколько мыслей поместится: короткий спавн - одна, длинный - больше
	local total = math.Clamp(math.floor((self.duration - 1.2) / 5.5), 1, 7)

	local pool = table.Copy(DS.Thoughts)
	local slots = {}

	for _ = 1, total do
		if (#pool == 0) then break end

		local text = table.remove(pool, math.random(#pool))
		local lines, count = LayoutThought(text, "ixDeathScreenThought", maxW)

		slots[#slots + 1] = {lines = lines, count = count}
	end

	if (#slots == 0) then
		self.slots = {}
		return
	end

	-- Мысли начинаются почти сразу: экран уже чёрный
	local textStart = math.Clamp(1.3 / self.duration, 0.05, 0.3)
	local len = (1 - textStart) / #slots

	for i, slot in ipairs(slots) do
		slot.from = textStart + (i - 1) * len
		slot.to = slot.from + len
		slot.last = (i == #slots)
	end

	self.slots = slots
end

function PANEL:BuildFragments()
	-- Места вокруг центрального текста (доли экрана)
	local anchors = {
		{0.20, 0.30}, {0.80, 0.31}, {0.14, 0.58}, {0.86, 0.57},
		{0.30, 0.64}, {0.70, 0.63}, {0.50, 0.29}, {0.50, 0.60}
	}

	for i = #anchors, 2, -1 do
		local j = math.random(i)

		anchors[i], anchors[j] = anchors[j], anchors[i]
	end

	local pool = table.Copy(DS.Fragments)
	local total = math.Clamp(math.floor(self.duration / 3.2), 2, #anchors)
	local spacing = math.max((self.duration - 1.6) / total, 0.6)

	self.fragments = {}

	for i = 1, total do
		if (#pool == 0) then break end

		local anchor = anchors[i]

		self.fragments[#self.fragments + 1] = {
			text = table.remove(pool, math.random(#pool)),
			x = anchor[1] + math.Rand(-0.03, 0.03),
			y = anchor[2] + math.Rand(-0.015, 0.015),
			from = math.max(0.9 + (i - 1) * spacing + math.Rand(-0.15, 0.15), 0.7),
			life = math.Clamp(spacing * 1.8, 2.6, 5.5),
			seed = math.Rand(0, 6.28)
		}
	end
end

function PANEL:IsClosing()
	return self.bIsClosing
end

function PANEL:Close()
	self.bIsClosing = true

	self:CreateAnimation(2, {
		index = 2,
		bIgnoreConfig = true,
		target = {alphaMul = 0},

		OnComplete = function(animation, panel)
			panel:Remove()
		end
	})
end

function PANEL:OnRemove()
	if (activePanel == self) then
		activePanel = nil
	end

	local ply = LocalPlayer()

	if (IsValid(ply)) then
		if (DS.ImpactSound) then ply:StopSound(DS.ImpactSound) end
		if (DS.BeatSound) then ply:StopSound(DS.BeatSound) end
		if (DS.FlatlineSound) then ply:StopSound(DS.FlatlineSound) end
	end
end

-- ------------------------------------------------------------
-- Звуки
-- ------------------------------------------------------------
function PANEL:OnImpact()
	if (!DS.PlaySounds or !DS.ImpactSound) then return end

	local ply = LocalPlayer()

	if (IsValid(ply)) then
		ply:EmitSound(DS.ImpactSound, 0, 60, 0.9, CHAN_STATIC)
	end
end

function PANEL:OnBeat(strength)
	self.pulse = math.Clamp(0.3 + 0.7 * strength, 0, 1)

	if (!DS.PlaySounds or !DS.BeatSound) then return end

	local ply = LocalPlayer()

	if (IsValid(ply) and strength > 0.05) then
		ply:StopSound(DS.BeatSound)
		ply:EmitSound(DS.BeatSound, 0, math.Clamp(60 + strength * 40, 60, 100), strength * 0.9, CHAN_STATIC)
	end
end

function PANEL:OnFlatline()
	self.flatlined = true
	self.pulse = 0

	if (!DS.PlaySounds or !DS.FlatlineSound) then return end

	local ply = LocalPlayer()

	if (IsValid(ply)) then
		ply:EmitSound(DS.FlatlineSound, 0, 100, 0.6, CHAN_STATIC)
	end
end

-- ------------------------------------------------------------
-- Сердце
-- ------------------------------------------------------------

-- Параметры следующего удара. Чем ближе остановка, тем он реже,
-- шире, слабее и неувереннее; часть ударов пропускается.
function PANEL:NextBeat()
	local hp = self.hp
	local bpm = math.max(DS.StartBPM * (1 - hp) ^ 1.3 + 16 * (1 - hp), 14)
	local interval = (60 / bpm) * (1 + math.Rand(-1, 1) * (0.04 + hp * 0.45))

	self.beatInterval = math.Clamp(interval, 0.42, 3.2)
	self.beatWide = 1 + hp * 2.4
	self.beatAmp = (0.22 + 0.78 * (1 - hp) ^ 1.2) * math.Rand(0.85, 1)
	self.beatStrength = (1 - hp) ^ 1.4

	if (hp > 0.3 and math.random() < hp * hp * 0.6) then
		self.beatAmp = self.beatAmp * 0.12
		self.beatStrength = 0
	end

	if (hp > 0.95) then
		self.beatAmp = 0
		self.beatStrength = 0
	end

	self.beatT = 0
	self.beatFired = false
end

function PANEL:Think()
	local ft = FrameTime()

	self.el = CurTime() - self.startTime

	if (!self.bIsClosing) then
		self.t = math.Clamp(self.el / self.duration, 0, 1)
	end

	self.hp = math.Clamp(self.el / self.heartTime, 0, 1)

	if (self.hp >= 1 and !self.flatlined) then
		self:OnFlatline()
	end

	self.pulse = math.max(self.pulse - ft * 2.5, 0)

	local targetBpm = self.flatlined and 0 or (60 / self.beatInterval)

	self.dispBpm = Lerp(math.min(ft * 3, 1), self.dispBpm, targetBpm)

	-- Кардиограмма (прокрутка)
	local dtS = 1 / DS.TraceRate

	self.sampleAcc = self.sampleAcc + ft

	local guard = 0

	while (self.sampleAcc >= dtS and guard < 10) do
		self.sampleAcc = self.sampleAcc - dtS
		guard = guard + 1

		local value

		if (!self.flatlined) then
			self.beatT = self.beatT + dtS

			if (self.beatT >= self.beatInterval) then
				local over = self.beatT - self.beatInterval

				self:NextBeat()
				self.beatT = over
			end

			local p = self.beatT / self.beatInterval

			if (!self.beatFired and p >= 0.30) then
				self.beatFired = true

				if (self.beatAmp > 0.15) then
					self:OnBeat(self.beatStrength)
				end
			end

			value = ECG(p, self.beatInterval, self.beatWide) * self.beatAmp
				+ (math.random() - 0.5) * 0.05 * (1 + self.hp * 2)
		else
			-- асистолия: почти прямая линия с лёгким дрейфом
			self.wander = self.wander + dtS
			value = math.sin(self.wander * 1.1) * 0.025 + (math.random() - 0.5) * 0.012
		end

		table.remove(self.trace, 1)
		self.trace[#self.trace + 1] = value
	end
end

-- ------------------------------------------------------------
-- Отрисовка
-- ------------------------------------------------------------
function PANEL:Paint(w, h)
	local a = self.alphaMul
	local el, t = self.el, self.t
	local hp = self.hp
	local alive = 1 - hp
	local now = RealTime()
	local cx, cy = w * 0.5, h * 0.46

	-- 1. Мгновенная чернота: сознание отключилось в тот же кадр
	surface.SetDrawColor(2, 2, 4, 255 * a)
	surface.DrawRect(0, 0, w, h)

	draw.NoTexture()

	-- 4. Пылинки
	local moteA = math.Clamp(el / 1.5, 0, 1) * (0.25 + 0.75 * math.sqrt(alive)) * a

	for _, m in ipairs(self.motes) do
		local mx = (m.x + math.sin(now * 0.3 * m.rate + m.phase) * 0.01 + now * m.drift) % 1
		local my = (m.y - now * m.speed) % 1
		local flick = 0.35 + 0.65 * math.abs(math.sin(now * m.rate + m.phase))

		surface.SetDrawColor(170, 175, 190, 55 * flick * moteA)
		surface.DrawRect(mx * w, my * h, m.size, m.size)
	end

	-- 5. Тёмная рамка по краям
	DrawVignette(w, h, h * 0.55, 150 * a, 0, 0, 0)

	-- 7. Стадии угасания (слева внизу, печатаются по одной)
	local stageA = Ease((el - 0.35) / 0.6) * a

	if (stageA > 0.01) then
		local shown = {}

		for _, st in ipairs(self.stages) do
			if (el >= st.time) then
				shown[#shown + 1] = st
			end
		end

		local first = math.max(#shown - 3, 1)
		local lineH = ScreenScaleH(7.5) * 1.6

		for i = first, #shown do
			local st = shown[i]
			local newest = (i == #shown)
			local text = "> " .. st.text

			if (newest) then
				text = TypeText(text, (el - st.time) / 0.6)
			end

			local fadeBack = 0.5 ^ (#shown - i)

			draw.SimpleText(text, "ixDeathScreenMono", w * 0.04, h * 0.75 + (i - first) * lineH,
				Color(150, 155, 168, 190 * fadeBack * stageA), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	-- 8. Имя персонажа, сверху
	local nameA = Ease((el - 0.7) / 1.4) * a

	if (nameA > 0.01) then
		local ny = h * 0.17
		local breathe = 0.92 + 0.08 * math.sin(now * 1.1)

		surface.SetFont("ixDeathScreenName")

		local nameW, nameH = surface.GetTextSize(self.charName)

		draw.SimpleText(self.charName, "ixDeathScreenName", cx + 2, ny,
			Color(120, 120, 135, 40 * nameA), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(self.charName, "ixDeathScreenName", cx, ny,
			Color(222, 222, 228, 255 * nameA * breathe), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local lineW = math.min(nameW * 0.6, w * 0.3) * Ease((el - 1.2) / 1.4)

		surface.SetDrawColor(140, 140, 150, 120 * nameA)
		surface.DrawRect(cx - lineW * 0.5, ny + nameH * 0.65, lineW, 1)

		-- подзаголовок появляется, когда сердце остановилось
		local subA = Ease((el - self.heartTime - 0.5) / 1.6) * a

		if (DS.Subtitle and subA > 0.01) then
			draw.SimpleText(DS.Subtitle, "ixDeathScreenSub", cx, ny + nameH * 1.1,
				Color(150, 150, 162, 255 * subA), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	-- 9. Обрывки воспоминаний по краям
	for _, fr in ipairs(self.fragments) do
		local p = (el - fr.from) / fr.life

		if (p > 0 and p < 1) then
			local env = math.sin(p * math.pi) ^ 1.6
			local flick = 0.85 + 0.15 * math.sin(now * 6 + fr.seed)
			local al = 150 * env * flick * a
			local fx = w * fr.x + math.sin(now * 0.5 + fr.seed) * 6
			local fy = h * fr.y - p * h * 0.012

			-- эхо по бокам: лёгкая «расфокусировка»
			draw.SimpleText(fr.text, "ixDeathScreenFrag", fx - 3, fy,
				Color(150, 150, 165, al * 0.3), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(fr.text, "ixDeathScreenFrag", fx + 3, fy,
				Color(150, 150, 165, al * 0.3), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(fr.text, "ixDeathScreenFrag", fx, fy,
				Color(165, 165, 178, al), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	-- 10. Мысли: слова проявляются одно за другим и растворяются, поднимаясь вверх
	surface.SetFont("ixDeathScreenThought")

	local _, thoughtH = surface.GetTextSize("A")
	local lineH = thoughtH * 1.3

	for _, slot in ipairs(self.slots) do
		local reveal, fade = SlotState(slot, t)

		if (reveal) then
			local totalH = lineH * #slot.lines
			local top = cy - totalH * 0.5 + lineH * 0.5
			local lift = (1 - fade) * 10

			for li, line in ipairs(slot.lines) do
				local lx = cx - line.w * 0.5
				local ly = top + (li - 1) * lineH - lift

				for _, word in ipairs(line.words) do
					local r = Ease((reveal * (slot.count + 1.5) - (word.i - 1)) / 1.5)

					if (r > 0.01) then
						local al = 235 * r * fade * a
						local wx = lx + word.x
						local wy = ly + (1 - r) * 7

						draw.SimpleText(word.text, "ixDeathScreenThought", wx - 1, wy,
							Color(190, 190, 202, al * 0.22), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
						draw.SimpleText(word.text, "ixDeathScreenThought", wx + 1, wy,
							Color(190, 190, 202, al * 0.22), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
						draw.SimpleText(word.text, "ixDeathScreenThought", wx, wy,
							Color(208, 208, 214, al), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					end
				end
			end
		end
	end

	-- 11. Таймер возвращения + линия прогресса
	local uiA = math.Clamp((el - 1.2) / 1.5, 0, 1) * a

	if (uiA > 0.01) then
		local remaining = self.duration * (1 - t)
		local barW = w * 0.18
		local bx, by = w * 0.5 - barW * 0.5, h * 0.9

		surface.SetDrawColor(255, 255, 255, 25 * uiA)
		surface.DrawRect(bx, by, barW, 1)

		surface.SetDrawColor(190, 190, 190, 130 * uiA)
		surface.DrawRect(bx, by, barW * t, 1)

		draw.SimpleText("Возвращение через " .. FormatTime(remaining), "ixDeathScreenSmall",
			w * 0.5, by - ScreenScaleH(7), Color(160, 160, 160, 170 * uiA), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		if (DS.Footer) then
			draw.SimpleText(DS.Footer, "ixDeathScreenSmall", w * 0.5, by + ScreenScaleH(8),
				Color(120, 120, 120, 140 * uiA), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
end

vgui.Register("ixDeathScreen", PANEL, "Panel")

-- ============================================================
-- МГНОВЕННОЕ ЗАТЕМНЕНИЕ
-- Экран смерти создаётся по сообщению сервера и может опоздать на несколько
-- кадров. Пока панели нет, закрываем экран чёрным в тот же кадр, когда
-- клиент узнал о смерти, чтобы не было видно падения тела.
-- ============================================================
local wasAlive = true
local blackUntil = 0

hook.Add("Think", "ixDeathScreenInstantBlack", function()
	local client = LocalPlayer()

	if (!IsValid(client)) then return end

	local alive = client:Alive()

	if (wasAlive and !alive) then
		blackUntil = RealTime() + 0.75
	elseif (alive) then
		blackUntil = 0
	end

	wasAlive = alive
end)

hook.Add("DrawOverlay", "ixDeathScreenInstantBlack", function()
	if (blackUntil <= RealTime() or IsValid(activePanel)) then return end

	surface.SetDrawColor(2, 2, 4, 255)
	surface.DrawRect(0, 0, ScrW(), ScrH())
end)