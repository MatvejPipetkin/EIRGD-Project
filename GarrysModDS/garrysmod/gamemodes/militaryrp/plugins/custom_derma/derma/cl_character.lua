local glowMat = Material("sprites/light_glow02_add")
local audioFadeInTime = 2
local animationTime = 0.5
local matrixZScale = Vector(1, 1, 0.0001)

--[[
	НАСТРОЙКИ ИНТРО
	Положите logotip.png в materials/ и добавьте на сервере resource.AddFile("materials/logotip.png").
]]
local CFG = {
	logoPaths = {"logotip.png", "logotip", "vgui/logotip.png", "vgui/logotip"},
	logoHeight = 0.15, -- высота логотипа в долях от высоты экрана
	ringSize = 0.19, -- радиус кольца в долях от высоты экрана
	projectName = "EIRGD", -- запасная надпись, если логотип не найден, и подпись в углу экрана
	promptText = "НАЖМИТЕ ЛЮБУЮ КЛАВИШУ ДЛЯ ВХОДА В СИСТЕМУ",
	loadTime = 5, -- длительность "загрузки" в секундах, отсчёт начинается после нажатия (только при первом входе)
	introScale = 1.3, -- множитель длительности анимаций после загрузки (больше = медленнее)
	sounds = true,
	soundFlash = "ui/buttonclickrelease.wav",
	fallbackColor = Color(90, 160, 235),
	accentColor = Color(90, 160, 235), -- основной цвет интерфейса (сине-стальной); удалите строку, чтобы брать цвет из конфига Helix
	bgGlow = true, -- мягкое статичное свечение за кольцом
	bgSweep = false, -- медленный радарный луч внутри кольца
	bgDots = 0, -- количество медленно плывущих светлых точек (0 = отключить)
	gridAlpha = 1, -- прозрачность сетки (множитель, 0 = без сетки)
	statusText = "СВЯЗЬ: ЗАЩИЩЕНА", -- надпись в правом верхнем углу
	classification = "ДОСТУП ОГРАНИЧЕН  //  ТОЛЬКО ДЛЯ ЛИЧНОГО СОСТАВА", -- надпись внизу по центру

	-- ===== РАСШИРЕНИЯ: атмосфера / HUD / звук =====
	vignette = 0.85, -- затемнение по краям экрана (0 = выкл)
	scanlines = 1, -- ЭЛТ-развёртка и бегущая световая полоса (0 = выкл)
	grain = 1, -- плёночное зерно (0 = выкл)
	rotatingRings = true, -- вращающиеся прицельные сегменты вокруг кольца
	hexColumns = true, -- бегущий поток hex-данных у левого края
	telemetry = true, -- телеметрия у правого края (задержка, FPS, сигнал)
	compass = true, -- компасная лента сверху
	glitch = true, -- глитч-эффект логотипа (при появлении и редкими всплесками)
	shockwave = true, -- ударная волна, вспышка и тряска в момент входа в систему
	buttonSounds = true, -- звуки наведения и нажатия на кнопки меню
	soundVolume = 0.55, -- общая громкость интерфейсных звуков (0..1)
	ambientLoop = "ambient/atmosphere/undercity_loop1.wav", -- тихий фоновый гул ("" = отключить)
	ambientVolume = 0.22,
	buttonsOffsetY = 6, -- сдвиг основных кнопок меню вниз в пикселях (0 = как в оригинале)

	-- набор звуков {путь, громкость, высота тона}. Пути из базовых игр Source — можно заменить на свои файлы
	soundSet = {
		hover = {"buttons/blip1.wav", 0.35, 115},
		click = {"buttons/button15.wav", 0.5, 100},
		deny = {"buttons/button10.wav", 0.5, 100},
		open = {"buttons/combine_button1.wav", 0.4, 105},
		back = {"buttons/combine_button2.wav", 0.4, 95},
		tick = {"buttons/blip2.wav", 0.18, 130},
		step = {"buttons/button17.wav", 0.35, 105},
		boom = {"ambient/machines/thumper_hit.wav", 0.55, 100},
		confirm = {"buttons/combine_button7.wav", 0.45, 100},
		reveal = {"buttons/combine_button3.wav", 0.3, 110},
		error = {"buttons/button8.wav", 0.5, 100}
	},

	-- ключевые точки прогресса {время 0..1, прогресс 0..1}
	progressKeys = {
		{0.00, 0.00}, {0.10, 0.08}, {0.22, 0.20}, {0.30, 0.22}, {0.48, 0.55},
		{0.58, 0.58}, {0.62, 0.60}, {0.80, 0.90}, {0.90, 0.93}, {1.00, 1.00}
	},

	steps = {
		"ИНИЦИАЛИЗАЦИЯ ТАКТИЧЕСКОЙ СЕТИ",
		"УСТАНОВКА ЗАЩИЩЁННОГО КАНАЛА",
		"СИНХРОНИЗАЦИЯ ДАННЫХ РАЗВЕДКИ",
		"ЗАГРУЗКА ЛИЧНЫХ ДЕЛ",
		"ПРОВЕРКА ДОПУСКА",
		"КАЛИБРОВКА ИНТЕРФЕЙСА",
		"СВЯЗЬ УСТАНОВЛЕНА"
	}
}

local function CreateIntroFonts()
	local h = ScrH()

	surface.CreateFont("ixIntroMid", {font = "Roboto", size = math.floor(h * 0.022), weight = 600, extended = true, antialias = true})
	surface.CreateFont("ixIntroSmall", {font = "Roboto", size = math.floor(h * 0.016), weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixIntroTiny", {font = "Roboto", size = math.floor(h * 0.012), weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixIntroMono", {font = "Courier New", size = math.floor(h * 0.0135), weight = 500, extended = true, antialias = true})
end

CreateIntroFonts()

local function EaseOutCubic(x)
	return 1 - (1 - x) ^ 3
end

local function EaseInOutSine(x)
	return -(math.cos(math.pi * x) - 1) / 2
end

local function LerpKeys(keys, p)
	for i = 2, #keys do
		local a, b = keys[i - 1], keys[i]

		if (p <= b[1]) then
			local f = (p - a[1]) / math.max(b[1] - a[1], 0.0001)
			return Lerp(f, a[2], b[2])
		end
	end

	return keys[#keys][2]
end

local function GetAccent()
	return CFG.accentColor or ix.config.Get("color") or CFG.fallbackColor
end

local function Upper(text)
	return (string.utf8upper or string.upper)(text)
end

local function FindLogoMaterial()
	local list = table.Copy(CFG.logoPaths)

	if (Schema and Schema.logo) then
		list[#list + 1] = Schema.logo
	end

	for _, path in ipairs(list) do
		local mat = Material(path, "smooth mips")

		if (mat and !mat:IsError()) then
			return mat
		end
	end
end

--[[
	СГЛАЖЕННАЯ ОТРИСОВКА
	surface.DrawLine и обычные полигоны рисуются без антиалиасинга (видны "лесенки").
	Здесь линия и дуга собираются из ядра и двух полупрозрачных полос по краям —
	получается мягкая кромка без пикселей, независимо от настроек MSAA.
]]
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

	if (len < 0.001 or a <= 0) then
		return
	end

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
	if (rOut <= 0) then
		return
	end

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
	if (ca <= 0 or deg1 <= deg0) then
		return
	end

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

--[[
	РАСШИРЕНИЯ: звук, атмосфера (виньетка, развёртка, зерно), HUD-элементы
]]
local lastPlayed = {}

local function PlayUI(key, pitchMul, volMul)
	if (!CFG.sounds) then
		return
	end

	local def = CFG.soundSet and CFG.soundSet[key]

	if (!def) then
		return
	end

	local now = RealTime()

	-- защита от "залпа" одинаковых звуков в один кадр
	if (lastPlayed[key] and now - lastPlayed[key] < 0.05) then
		return
	end

	lastPlayed[key] = now

	local vol = math.Clamp(def[2] * (volMul or 1) * (CFG.soundVolume or 1), 0, 1)
	local pitch = math.Clamp(def[3] * (pitchMul or 1), 40, 255)
	local ply = LocalPlayer()

	if (IsValid(ply)) then
		ply:EmitSound(def[1], 75, pitch, vol, CHAN_AUTO)
	else
		surface.PlaySound(def[1])
	end
end

local function EaseOutExpo(x)
	return x >= 1 and 1 or 1 - 2 ^ (-10 * x)
end

local function Hash(n)
	local v = math.sin(n * 12.9898) * 43758.5453

	return v - math.floor(v)
end

local COMPASS = {[0] = "С", [45] = "СВ", [90] = "В", [135] = "ЮВ", [180] = "Ю", [225] = "ЮЗ", [270] = "З", [315] = "СЗ"}

local function HexLine()
	local b = {}

	for i = 1, 8 do
		b[i] = math.random(0, 255)
	end

	return string.format("%04X  %02X %02X %02X %02X  %02X %02X %02X %02X", math.random(0, 0xFFFF), b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8])
end

-- эффект "печатной машинки": возвращает первые p (0..1) символов строки (с учётом UTF-8)
local function TypeText(text, p)
	local len = utf8.len(text) or #text
	local n = math.floor(len * math.Clamp(p, 0, 1))

	if (n >= len) then
		return text
	end

	return text:sub(1, (utf8.offset(text, n + 1) or (#text + 1)) - 1)
end

local function DrawBrackets(x, y, w, h, len, r, g, b, a)
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

-- плавная виньетка из ступенчатых полос (без текстур — работает везде)
local function DrawVignette(w, h, strength)
	if (strength <= 0) then
		return
	end

	local n = 28
	local th = math.ceil(h * 0.24 / n)
	local tw = math.ceil(w * 0.15 / n)

	draw.NoTexture()

	for i = 0, n - 1 do
		local f = (1 - i / n) ^ 2.4

		surface.SetDrawColor(0, 0, 0, 190 * strength * f)
		surface.DrawRect(0, i * th, w, th)
		surface.DrawRect(0, h - (i + 1) * th, w, th)
		surface.DrawRect(i * tw, 0, tw, h)
		surface.DrawRect(w - (i + 1) * tw, 0, tw, h)
	end
end

local function DrawScanlines(w, h, k, now)
	if (k <= 0) then
		return
	end

	local accent = GetAccent()

	draw.NoTexture()

	-- тонкие строки развёртки
	surface.SetDrawColor(0, 0, 0, 16 * k)

	for y = 0, h, 3 do
		surface.DrawRect(0, y, w, 1)
	end

	-- медленно ползущая светлая полоса
	local bandH = h * 0.16
	local y0 = ((now * h * 0.08) % (h + bandH)) - bandH
	local parts = 14

	for i = 0, parts - 1 do
		local f = math.sin((i + 0.5) / parts * math.pi)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 6 * f * k)
		surface.DrawRect(0, y0 + i * bandH / parts, w, math.ceil(bandH / parts) + 1)
	end
end

local function DrawGrain(w, h, k)
	if (k <= 0) then
		return
	end

	draw.NoTexture()

	for _ = 1, 55 do
		local v = math.random(130, 255)
		local s = math.random(1, 2)

		surface.SetDrawColor(v, v, v, math.random(6, 20) * k)
		surface.DrawRect(math.random(0, w), math.random(0, h), s, s)
	end
end

-- вращающиеся сегменты вокруг основного кольца: внешние по часовой, внутренние против
local function DrawRotatingRings(cx, cy, R, now, ar, ag, ab, a)
	if (a <= 0) then
		return
	end

	local base = now * 11

	for i = 0, 5 do
		local s = base + i * 60

		SmoothArc(cx, cy, R + 34, s, s + 32, 2, 14, ar, ag, ab, 150 * a)
	end

	local base2 = -now * 21

	for i = 0, 11 do
		local s = base2 + i * 30

		SmoothArc(cx, cy, R - 26, s, s + 12, 1, 6, ar, ag, ab, 95 * a)
	end

	-- четыре "прицельные" дуги, плавно покачиваются
	local sway = math.sin(now * 0.7) * 22

	for q = 0, 3 do
		local s = q * 90 + sway - 13

		SmoothArc(cx, cy, R + 44, s, s + 26, 3, 12, 255, 255, 255, 185 * a)
	end
end

local function StyleMenuButton(button)
	button.hoverFrac = 0
	button.pressFrac = 0

	local basePressed = button.OnMousePressed

	button.OnCursorEntered = function(this)
		this.shineStart = RealTime()

		if (CFG.buttonSounds and !this:GetDisabled()) then
			PlayUI("hover", math.Rand(0.96, 1.06))
		end
	end

	button.OnCursorExited = function() end

	button.OnMousePressed = function(this, code)
		if (CFG.buttonSounds and code == MOUSE_LEFT) then
			if (this:GetDisabled()) then
				PlayUI("deny")
			else
				PlayUI("click")
				this.pressFrac = 1
			end
		end

		if (basePressed) then
			return basePressed(this, code)
		end
	end

	button.Paint = function(this, w, h)
		local disabled = this:GetDisabled()
		local target = (!disabled and this:IsHovered()) and 1 or 0
		local accent = GetAccent()
		local k = disabled and 0.3 or 1
		local now = RealTime()

		this.hoverFrac = Lerp(math.min(RealFrameTime() * 14, 1), this.hoverFrac, target)
		this.pressFrac = Lerp(math.min(RealFrameTime() * 7, 1), this.pressFrac, 0)

		local f = this.hoverFrac
		local ef = EaseOutCubic(f)
		local pf = this.pressFrac
		local ww = math.floor(w * EaseOutCubic(this.revealW or 1)) -- ширина "выезжающей" плашки при появлении
		local rx = this.revealX or 0
		local y, bh = 3, h - 6

		draw.NoTexture()

		surface.SetDrawColor(accent.r, accent.g, accent.b, (16 + 34 * f) * k)
		surface.DrawRect(0, y, ww, bh)

		-- заливка, выезжающая слева при наведении
		if (ef > 0.01) then
			surface.SetDrawColor(accent.r, accent.g, accent.b, 40 * ef * k)
			surface.DrawRect(0, y, math.floor(ww * ef), bh)
		end

		-- одиночный блик, пробегающий по кнопке при наведении
		if (f > 0.05 and !disabled) then
			local st = (now - (this.shineStart or now)) * 1.7

			if (st < 1) then
				local sx = math.floor(-40 + (ww + 80) * EaseOutCubic(st))

				for i = 0, 7 do
					local x = sx + i * 5

					if (x >= 0 and x < ww) then
						surface.SetDrawColor(255, 255, 255, 38 * math.sin((i + 0.5) / 8 * math.pi) * f)
						surface.DrawRect(x, y, 5, bh)
					end
				end
			end
		end

		-- рамка с лёгким "дыханием"
		local breathe = 0.5 + 0.5 * math.sin(now * 1.6 + h)

		surface.SetDrawColor(accent.r, accent.g, accent.b, (104 + 8 * breathe + 108 * f) * k)
		surface.DrawOutlinedRect(0, y, ww, bh, 1)

		-- маркер слева (расширяется при наведении)
		surface.SetDrawColor(255, 255, 255, (70 + 185 * f) * k)
		surface.DrawRect(0, y, 4 + math.floor(3 * ef), bh)

		-- скобки справа при наведении
		if (ef > 0.02 and ww > 24) then
			local bl = math.floor(10 * ef)

			surface.SetDrawColor(255, 255, 255, 200 * ef * k)
			surface.DrawRect(ww - bl - 1, y, bl, 2)
			surface.DrawRect(ww - 2, y, 2, bl)
			surface.DrawRect(ww - bl - 1, y + bh - 2, bl, 2)
			surface.DrawRect(ww - 2, y + bh - bl, 2, bl)
		end

		-- вспышка при нажатии
		if (pf > 0.01) then
			surface.SetDrawColor(255, 255, 255, 70 * pf * k)
			surface.DrawRect(0, y, ww, bh)
		end

		local text = this:GetText()
		local font = this:GetFont()
		local tx = w * 0.5 + rx * 0.5
		local ty = h * 0.5 + pf

		surface.SetFont(font)

		local tw = surface.GetTextSize(text)

		draw.SimpleText(text, font, tx + 1, ty + 1, Color(0, 0, 0, 150 * k), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(text, font, tx, ty, Color(255, 255, 255, (200 + 55 * f) * k), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		-- шевроны по бокам текста при наведении
		if (ef > 0.02) then
			local off = 26 - 10 * ef
			local lx, rxx = tx - tw * 0.5 - off, tx + tw * 0.5 + off

			SmoothLine(lx, ty - 5, lx + 5, ty, 1.5, 255, 255, 255, 230 * ef * k)
			SmoothLine(lx + 5, ty, lx, ty + 5, 1.5, 255, 255, 255, 230 * ef * k)
			SmoothLine(rxx, ty - 5, rxx - 5, ty, 1.5, 255, 255, 255, 230 * ef * k)
			SmoothLine(rxx - 5, ty, rxx, ty + 5, 1.5, 255, 255, 255, 230 * ef * k)
		end

		return true
	end
end

DEFINE_BASECLASS("ixSubpanelParent")
local PANEL = {}

function PANEL:Init()
	self:SetSize(self:GetParent():GetSize())
	self:SetPos(0, 0)

	self.childPanels = {}
	self.subpanels = {}
	self.activeSubpanel = ""

	self.currentDimAmount = 0
	self.currentY = 0
	self.currentScale = 1
	self.currentAlpha = 255
	self.targetDimAmount = 255
	self.targetScale = 0.9
end

function PANEL:Dim(length, callback)
	length = length or animationTime
	self.currentDimAmount = 0

	self:CreateAnimation(length, {
		target = {
			currentDimAmount = self.targetDimAmount,
			currentScale = self.targetScale
		},
		easing = "outCubic",
		OnComplete = callback
	})

	PlayUI("open")
	self:OnDim()
end

function PANEL:Undim(length, callback)
	length = length or animationTime
	self.currentDimAmount = self.targetDimAmount

	self:CreateAnimation(length, {
		target = {
			currentDimAmount = 0,
			currentScale = 1
		},
		easing = "outCubic",
		OnComplete = callback
	})

	PlayUI("back")
	self:OnUndim()
end

function PANEL:OnDim()
end

function PANEL:OnUndim()
end

function PANEL:Paint(width, height)
	local amount = self.currentDimAmount
	local bShouldScale = self.currentScale != 1
	local matrix

	if (bShouldScale) then
		matrix = Matrix()
		matrix:Scale(matrixZScale * self.currentScale)
		matrix:Translate(Vector(
			ScrW() * 0.5 - (ScrW() * self.currentScale * 0.5),
			ScrH() * 0.5 - (ScrH() * self.currentScale * 0.5),
			1
		))

		cam.PushModelMatrix(matrix)
		self.currentMatrix = matrix
	end

	BaseClass.Paint(self, width, height)

	if (bShouldScale) then
		cam.PopModelMatrix()
		self.currentMatrix = nil
	end

	if (amount > 0) then
		local color = Color(0, 0, 0, amount)

		surface.SetDrawColor(color)
		surface.DrawRect(0, 0, width, height)
	end
end

vgui.Register("ixCharMenuPanel", PANEL, "ixSubpanelParent")

PANEL = {}

local scrollBase = baseclass.Get("DScrollPanel")

function PANEL:Init()
	local parent = self:GetParent()
	self:SetSize(parent:GetWide() * 0.25, parent:GetTall())

	self:GetVBar():SetWide(0)
	self:GetVBar():SetVisible(false)

	self.entries = {}
end

function PANEL:Add(name)
	local panel = vgui.Create(name, self)
	panel:Dock(TOP)

	self.entries[#self.entries + 1] = panel

	return panel
end

function PANEL:AnchorCanvas()
	local canvas = self:GetCanvas()

	if (self:GetTall() > canvas:GetTall()) then
		canvas:SetPos(0, self:GetTall() - canvas:GetTall())
	end
end

function PANEL:SizeToContents()
	self:GetCanvas():Dock(NODOCK)
	self:GetCanvas():InvalidateLayout(true)
	self:AnchorCanvas()
end

function PANEL:PerformLayout(width, height)
	scrollBase.PerformLayout(self, width, height)
	self:AnchorCanvas()
end

if (scrollBase.PerformLayoutInternal) then
	function PANEL:PerformLayoutInternal()
		scrollBase.PerformLayoutInternal(self)
		self:AnchorCanvas()
	end
end

vgui.Register("ixCharMenuButtonList", PANEL, "DScrollPanel")

PANEL = {}

AccessorFunc(PANEL, "bUsingCharacter", "UsingCharacter", FORCE_BOOL)

function PANEL:Init()
	local parent = self:GetParent()
	local padding = self:GetPadding()
	local halfWidth = ScrW() * 0.5
	local halfPadding = padding * 0.5
	local bHasCharacter = #ix.characters > 0

	self.bUsingCharacter = LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()
	self:DockPadding(padding, padding, padding, padding)

	local infoLabel = self:Add("DLabel")
	infoLabel:SetTextColor(Color(255, 255, 255, 25))
	infoLabel:SetFont("ixMenuMiniFont")
	infoLabel:SetText(L("helix") .. " " .. GAMEMODE.Version)
	infoLabel:SizeToContents()
	infoLabel:SetPos(ScrW() - infoLabel:GetWide() - 4, ScrH() - infoLabel:GetTall() - 4)

	local logoPanel = self:Add("Panel")
	logoPanel:SetSize(ScrW(), ScrH() * 0.25)
	logoPanel:SetPos(0, ScrH() * 0.25)

	local logoMat = FindLogoMaterial()
	local logoW, logoH
	local title

	if (logoMat) then
		local aspect = logoMat:Width() / math.max(logoMat:Height(), 1)

		logoH = ScrH() * CFG.logoHeight
		logoW = logoH * aspect

		if (logoW > ScrW() * 0.55) then
			logoW = ScrW() * 0.55
			logoH = logoW / aspect
		end

		logoPanel:SetTall(logoH + padding * 2)
	else
		title = CFG.projectName

		surface.SetFont("ixTitleFont")
		local _, titleH = surface.GetTextSize(title)
		local newHeight = padding + titleH

		logoW, logoH = halfWidth, titleH
		logoPanel:SetTall(newHeight)
	end

	parent.logoCenterY = ScrH() * 0.25 + logoPanel:GetTall() * 0.5
	parent.logoHalfW = logoW * 0.5

	local function DrawLogo(width, height)
		if (!parent.bStarted) then
			return
		end

		local r = parent.logoReveal or 1

		if (r <= 0) then
			return
		end

		local now = RealTime()
		local accent = GetAccent()
		local cx, cy = width * 0.5, height * 0.5
		local a = 255 * math.min(r * 1.8, 1)
		local gl = CFG.glitch and (parent.logoGlitch or 0) or 0
		local seed = math.floor(now * 22)
		local drawW, drawH = logoW, logoH

		if (!logoMat) then
			surface.SetFont("ixTitleFont")
			drawW = surface.GetTextSize(title)
		end

		-- отрисовка содержимого логотипа со смещением ox и цветом; sliced = горизонтальные "сбойные" полосы
		local function Content(ox, cr, cg, cb, ca, sliced)
			if (!logoMat) then
				draw.SimpleText(title, "ixTitleFont", cx + ox, cy, Color(cr, cg, cb, ca), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

				return
			end

			local x = math.Round(cx - logoW * 0.5 + ox)
			local y = math.Round(cy - logoH * 0.5)
			local w, h = math.Round(logoW), math.Round(logoH)

			surface.SetMaterial(logoMat)
			surface.SetDrawColor(cr, cg, cb, ca)

			if (sliced) then
				local n = 12
				local sh = h / n

				for i = 0, n - 1 do
					local shift = 0

					if (Hash(seed * 7 + i) > 0.72) then
						shift = (Hash(seed * 3 + i * 5) - 0.5) * gl * 46
					end

					surface.DrawTexturedRectUV(x + shift, y + i * sh, w, sh + 1, 0, i / n, 1, (i + 1) / n)
				end
			else
				surface.DrawTexturedRect(x, y, w, h)
			end
		end

		-- проявление вертикальной "шторкой" слева направо
		local wipe = r < 1
		local fullW = drawW + 60
		local x0 = cx - fullW * 0.5
		local front = fullW * r

		if (wipe) then
			local sx, sy = logoPanel:LocalToScreen(0, 0)

			render.SetScissorRect(sx + x0, sy, sx + x0 + front, sy + height, true)
		end

		-- целочисленные координаты и анизотропная фильтрация: картинка без размытия и "лесенки"
		render.PushFilterMag(TEXFILTER.ANISOTROPIC)
		render.PushFilterMin(TEXFILTER.ANISOTROPIC)
			if (gl > 0.02) then
				local off = math.Round(2 + gl * 8)
				local ga = a * 0.5 * math.min(gl * 1.5, 1)

				Content(-off, 255, 50, 70, ga, false)
				Content(off, 50, 220, 255, ga, false)
			end

			Content(0, 255, 255, 255, a, gl > 0.25)
		render.PopFilterMin()
		render.PopFilterMag()

		if (wipe) then
			render.SetScissorRect(0, 0, 0, 0, false)

			local lx = math.floor(x0 + front)
			local la = math.sin(r * math.pi) * 255

			surface.SetMaterial(glowMat)
			surface.SetDrawColor(accent.r, accent.g, accent.b, la * 0.55)
			surface.DrawTexturedRect(lx - 50, cy - drawH * 0.8, 100, drawH * 1.6)
			draw.NoTexture()

			SmoothLine(lx, cy - drawH * 0.65, lx, cy + drawH * 0.65, 2, 255, 255, 255, la)
		end
	end

	logoPanel.Paint = function(panel, width, height)
		DrawLogo(width, height)
	end

	self.mainButtonList = self:Add("ixCharMenuButtonList")
	self.mainButtonList:SetSize(ScrW() * 0.3, ScrH() - padding * 2)
	self.mainButtonList:SetPos((ScrW() - self.mainButtonList:GetWide()) * 0.5, padding + (CFG.buttonsOffsetY or 0))

	local createButton = self.mainButtonList:Add("ixMenuButton")
	createButton:SetText("create")
	createButton:SizeToContents()
	createButton.DoClick = function()
		local maximum = hook.Run("GetMaxPlayerCharacter", LocalPlayer()) or ix.config.Get("maxCharacters", 5)
		if (#ix.characters >= maximum) then
			self:GetParent():ShowNotice(3, L("maxCharacters"))
			return
		end

		self:Dim()
		parent.newCharacterPanel:SetActiveSubpanel("faction", 0)
		parent.newCharacterPanel:SlideUp()
	end

	self.loadButton = self.mainButtonList:Add("ixMenuButton")
	self.loadButton:SetText("load")
	self.loadButton:SizeToContents()
	self.loadButton.DoClick = function()
		self:Dim()
		parent.loadCharacterPanel:SlideUp()
	end

	if (!bHasCharacter) then
		self.loadButton:SetDisabled(true)
	end

	local extraURL = ix.config.Get("communityURL", "")
	local extraText = ix.config.Get("communityText", "@community")

	if (extraURL != "" and extraText != "") then
		if (extraText:sub(1, 1) == "@") then
			extraText = L(extraText:sub(2))
		end

		local extraButton = self.mainButtonList:Add("ixMenuButton")
		extraButton:SetText(extraText, true)
		extraButton:SizeToContents()
		extraButton.DoClick = function()
			gui.OpenURL(extraURL)
		end
	end

	self.returnButton = self.mainButtonList:Add("ixMenuButton")
	self:UpdateReturnButton()
	self.returnButton.DoClick = function()
		if (self.bUsingCharacter) then
			parent:Close()
		else
			RunConsoleCommand("disconnect")
		end
	end

	self.mainButtonList:SizeToContents()
	self.menuButtons = self.mainButtonList.entries

	for _, button in ipairs(self.menuButtons) do
		button:SetContentAlignment(5)
		button:SetTextInset(0, 0)
		StyleMenuButton(button)
	end
end

function PANEL:PrepareButtons()
	for _, button in ipairs(self.menuButtons or {}) do
		button.revealA = 0
		button.revealX = -40
		button.revealW = 0
		button:SetAlpha(0)
		button:DockMargin(0, 0, 0, 0)
	end
end

function PANEL:RevealButtons()
	self:SetMouseInputEnabled(true)
	self:SetKeyboardInputEnabled(true)

	for i, button in ipairs(self.menuButtons or {}) do
		timer.Simple((i - 1) * 0.11, function()
			if (!IsValid(button)) then
				return
			end

			PlayUI("tick", 1 + i * 0.07, 0.9)

			button:CreateAnimation(0.9, {
				index = 20,
				target = {revealA = 255, revealX = 0, revealW = 1},
				easing = "outCubic",

				Think = function(animation, panel)
					panel:SetAlpha(panel.revealA)
				end,

				OnComplete = function(animation, panel)
					panel:SetAlpha(255)
					panel.revealX = 0
					panel.revealW = 1
				end
			})
		end)
	end
end

function PANEL:UpdateReturnButton(bValue)
	if (bValue != nil) then
		self.bUsingCharacter = bValue
	end

	self.returnButton:SetText(self.bUsingCharacter and "return" or "leave")
	self.returnButton:SizeToContents()
end

function PANEL:OnDim()
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
end

function PANEL:OnUndim()
	self:SetMouseInputEnabled(true)
	self:SetKeyboardInputEnabled(true)

	self.bUsingCharacter = LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()
	self:UpdateReturnButton()
end

function PANEL:OnClose()
	for _, v in pairs(self:GetChildren()) do
		if (IsValid(v)) then
			v:SetVisible(false)
		end
	end
end

function PANEL:PerformLayout(width, height)
	local padding = self:GetPadding()
	local list = self.mainButtonList

	list:SetSize(width * 0.3, height - padding * 2)
	list:SetPos((width - list:GetWide()) * 0.5, padding + (CFG.buttonsOffsetY or 0))
end

vgui.Register("ixCharMenuMain", PANEL, "ixCharMenuPanel")

PANEL = {}

function PANEL:Init()
	if (IsValid(ix.gui.loading)) then
		ix.gui.loading:Remove()
	end

	if (IsValid(ix.gui.characterMenu)) then
		if (IsValid(ix.gui.characterMenu.channel)) then
			ix.gui.characterMenu.channel:Stop()
		end

		ix.gui.characterMenu:Remove()
	end

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)

	self.mainPanel = self:Add("ixCharMenuMain")

	self.newCharacterPanel = self:Add("ixCharMenuNew")
	self.newCharacterPanel:SlideDown(0)

	self.loadCharacterPanel = self:Add("ixCharMenuLoad")
	self.loadCharacterPanel:SlideDown(0)

	self.notice = self:Add("ixNoticeBar")

	self:MakePopup()
	self.currentAlpha = 255
	self.volume = 0

	ix.gui.characterMenu = self

	if (!IsValid(ix.gui.intro)) then
		self:PlayMusic()
	end

	self:BeginIntro()

	hook.Run("OnCharacterMenuCreated", self)
end

function PANEL:BeginIntro()
	local bFast = self.mainPanel.bUsingCharacter and true or false

	self.introScale = bFast and 0.4 or CFG.introScale
	self.loadDuration = bFast and 0 or CFG.loadTime
	self.introStart = RealTime()
	self.bStarted = bFast
	self.bFlashPlayed = false
	self.bButtonsRevealed = false

	self.openTime = RealTime()
	self.hexLines = {}

	for i = 1, 14 do
		self.hexLines[i] = HexLine()
	end

	self:StartAmbient()

	self.dots = {}

	for i = 1, CFG.bgDots do
		self.dots[i] = {
			x = math.Rand(0, ScrW()),
			y = math.Rand(0, ScrH()),
			speed = math.Rand(5, 16),
			size = math.Rand(5, 11),
			phase = math.Rand(0, math.pi * 2),
			a = math.Rand(18, 45)
		}
	end

	self.mainPanel:PrepareButtons()
	self.mainPanel:SetMouseInputEnabled(false)

	self:UpdateIntro()
end

function PANEL:StartLoading()
	if (self.bStarted or IsValid(ix.gui.intro)) then
		return
	end

	self.bStarted = true
	self.introStart = RealTime()

	PlayUI("confirm")
end

function PANEL:OnMousePressed()
	self:StartLoading()
end

function PANEL:OnKeyCodePressed()
	self:StartLoading()
end

function PANEL:UpdateIntro()
	local s = self.introScale or 1
	local loadEnd = self.loadDuration or 0

	if (!self.bStarted) then
		self.introTime = 0
		self.loadProgress = 0
		self.loadUiAlpha = 0
		self.promptAlpha = 1
		self.flash = 0
		self.hudReveal = 0
		self.logoReveal = 0
		self.logoGlitch = 0
		self.dispProgress = 0
		self.shockT = nil
		self.shakeAmp = 0

		return
	end

	local t = RealTime() - (self.introStart or RealTime())
	local tt = t - loadEnd

	self.introTime = t
	self.promptAlpha = loadEnd > 0 and (1 - math.Clamp(t / 0.4, 0, 1)) or 0

	if (loadEnd > 0) then
		self.loadProgress = LerpKeys(CFG.progressKeys, math.Clamp(t / loadEnd, 0, 1))
		self.loadUiAlpha = 1 - math.Clamp(tt / (0.4 * s), 0, 1)
	else
		self.loadProgress = 1
		self.loadUiAlpha = 0
	end

	self.flash = 0
	self.hudReveal = EaseOutCubic(math.Clamp((tt - 0.25 * s) / (0.9 * s), 0, 1))
	self.logoReveal = EaseInOutSine(math.Clamp((tt - 0.3 * s) / (1.9 * s), 0, 1))

	if (tt >= 0 and !self.bFlashPlayed) then
		self.bFlashPlayed = true

		if (CFG.sounds and loadEnd > 0) then
			surface.PlaySound(CFG.soundFlash)
			PlayUI("boom")
		end
	end

	-- === РАСШИРЕНИЕ: плавный прогресс, вспышка, тряска, глитч и звуки загрузки ===
	local now = RealTime()

	self.dispProgress = (self.loadProgress >= 1) and 1 or Lerp(math.min(RealFrameTime() * 9, 1), self.dispProgress or 0, self.loadProgress)

	if (loadEnd > 0 and tt >= 0) then
		self.shockT = tt
		self.flash = (1 - math.Clamp(tt / 0.75, 0, 1)) ^ 2 * 0.3
		self.shakeAmp = (1 - math.Clamp(tt / 0.5, 0, 1)) ^ 2 * 7
	else
		self.shockT = nil
		self.shakeAmp = 0
	end

	local lr = self.logoReveal or 0
	local gl = 0

	if (lr > 0 and lr < 1) then
		gl = 0.3 + 0.7 * (1 - lr)
	elseif (lr >= 1) then
		local c = now % 9

		if (c < 0.25) then
			gl = 0.6 * (1 - c / 0.25)
		end
	end

	self.logoGlitch = gl

	if (loadEnd > 0 and tt < 0) then
		local p = self.dispProgress
		local pct = math.floor(p * 20)
		local idx = math.Clamp(math.floor(p * #CFG.steps) + 1, 1, #CFG.steps)

		if (pct != self.lastPct) then
			self.lastPct = pct
			PlayUI("tick", 0.8 + p * 0.9)
		end

		if (idx != self.lastStep) then
			if (self.lastStep) then
				PlayUI("step", 0.9 + idx * 0.03)
			end

			self.lastStep = idx
		end
	end

	if (loadEnd > 0 and tt >= 0.3 * s and !self.bRevealSound) then
		self.bRevealSound = true
		PlayUI("reveal")
	end

	if (tt >= 2.0 * s and !self.bButtonsRevealed) then
		self.bButtonsRevealed = true
		self.mainPanel:RevealButtons()
	end
end

function PANEL:Think()
	if (IsValid(ix.gui.intro)) then
		self.introStart = RealTime()
	end

	self:UpdateIntro()
end

function PANEL:PlayMusic()
	local path = "sound/" .. ix.config.Get("music")
	local url = path:match("http[s]?://.+")
	local play = url and sound.PlayURL or sound.PlayFile
	path = url and url or path

	play(path, "noplay", function(channel, error, message)
		if (!IsValid(self) or !IsValid(channel)) then
			return
		end

		channel:SetVolume(self.volume or 0)
		channel:Play()

		self.channel = channel

		self:CreateAnimation(audioFadeInTime, {
			index = 10,
			target = {volume = 1},

			Think = function(animation, panel)
				if (IsValid(panel.channel)) then
					panel.channel:SetVolume(self.volume * 0.5)
				end
			end
		})
	end)
end

function PANEL:StartAmbient()
	if (!CFG.sounds or !CFG.ambientLoop or CFG.ambientLoop == "") then
		return
	end

	local ply = LocalPlayer()

	if (!IsValid(ply)) then
		return
	end

	self.ambient = CreateSound(ply, CFG.ambientLoop)

	if (self.ambient) then
		self.ambient:PlayEx(0, 100)
		self.ambient:ChangeVolume(CFG.ambientVolume or 0.2, 4)
	end
end

function PANEL:ShowNotice(type, text)
	PlayUI(type == 3 and "error" or "confirm")

	self.notice:SetType(type)
	self.notice:SetText(text)
	self.notice:Show()
end

function PANEL:HideNotice()
	if (IsValid(self.notice) and !self.notice:GetHidden()) then
		self.notice:Slide("up", 0.5, true)
	end
end

function PANEL:OnCharacterDeleted(character)
	if (#ix.characters == 0) then
		self.mainPanel.loadButton:SetDisabled(true)
		self.mainPanel:Undim()
	else
		self.mainPanel.loadButton:SetDisabled(false)
	end

	self.loadCharacterPanel:OnCharacterDeleted(character)
end

function PANEL:OnCharacterLoadFailed(error)
	self.loadCharacterPanel:SetMouseInputEnabled(true)
	self.loadCharacterPanel:SlideUp()
	self:ShowNotice(3, error)
end

function PANEL:IsClosing()
	return self.bClosing
end

function PANEL:Close(bFromMenu)
	self.bClosing = true
	self.bFromMenu = bFromMenu

	PlayUI("open", 0.75)

	if (self.ambient) then
		self.ambient:FadeOut(2)
	end

	local fadeOutTime = animationTime * 8

	self:CreateAnimation(fadeOutTime, {
		index = 1,
		target = {currentAlpha = 0},

		Think = function(animation, panel)
			panel:SetAlpha(panel.currentAlpha)
		end,

		OnComplete = function(animation, panel)
			panel:Remove()
		end
	})

	self:CreateAnimation(fadeOutTime - 0.1, {
		index = 10,
		target = {volume = 0},

		Think = function(animation, panel)
			if (IsValid(panel.channel)) then
				panel.channel:SetVolume(self.volume * 0.5)
			end
		end,

		OnComplete = function(animation, panel)
			if (IsValid(panel.channel)) then
				panel.channel:Stop()
				panel.channel = nil
			end
		end
	})

	if (bFromMenu) then
		for _, v in pairs(self:GetChildren()) do
			if (IsValid(v)) then
				v:SetVisible(false)
			end
		end
	else
		self.mainPanel.currentAlpha = 255

		self.mainPanel:CreateAnimation(animationTime * 2, {
			target = {currentAlpha = 0},
			easing = "outQuint",

			Think = function(animation, panel)
				panel:SetAlpha(panel.currentAlpha)
			end,

			OnComplete = function(animation, panel)
				panel:SetVisible(false)
			end
		})
	end

	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
	gui.EnableScreenClicker(false)
end

function PANEL:DrawBackground(width, height)
	local accent = GetAccent()
	local ar, ag, ab = accent.r, accent.g, accent.b
	local ringA = math.Clamp((self.introTime or 0) / 1.2, 0, 1)
	local now = RealTime()
	local shk = self.shakeAmp or 0
	local cx = math.floor(width * 0.5 + (shk > 0 and math.sin(now * 83) * shk or 0))
	local cy = math.floor((self.logoCenterY or height * 0.36) + (shk > 0 and math.cos(now * 71) * shk * 0.7 or 0))
	local R = math.floor(height * CFG.ringSize * (0.86 + 0.14 * EaseOutCubic(ringA))) -- кольцо "захватывает цель"
	local lit = self.dispProgress or self.loadProgress or 1

	draw.NoTexture()

	-- мягкое свечение за кольцом
	if (CFG.bgGlow and ringA > 0) then
		local breathe = 0.5 + 0.5 * math.sin(RealTime() * 0.25)
		local gs = R * 3.4

		surface.SetMaterial(glowMat)
		surface.SetDrawColor(ar, ag, ab, (16 + 4 * breathe) * ringA)
		surface.DrawTexturedRect(cx - gs * 0.5, cy - gs * 0.5, gs, gs)
		draw.NoTexture()
	end

	-- тактическая сетка: крупная и еле заметная
	local ga = CFG.gridAlpha or 1
	local gridA = math.max(ringA, 0.55) -- сетка видна и до нажатия клавиши
	local step = math.max(math.floor(height / 12), 48)

	for gx = 0, width, step do
		local major = (gx / step) % 4 == 0

		surface.SetDrawColor(ar, ag, ab, (major and 6 or 2.5) * ga * gridA)
		surface.DrawRect(gx, 0, 1, height)
	end

	for gy = 0, height, step do
		local major = (gy / step) % 4 == 0

		surface.SetDrawColor(ar, ag, ab, (major and 6 or 2.5) * ga * gridA)
		surface.DrawRect(0, gy, width, 1)
	end

	-- медленно плывущие светлые точки
	if (self.dots and #self.dots > 0 and ringA > 0) then
		local now = RealTime()
		local dt = math.min(RealFrameTime(), 0.05)

		surface.SetMaterial(glowMat)

		for _, d in ipairs(self.dots) do
			d.y = d.y - d.speed * dt
			d.x = d.x + math.sin(now * 0.3 + d.phase) * 6 * dt

			if (d.y < -20) then
				d.y = height + 20
				d.x = math.Rand(0, width)
			end

			local tw = 0.6 + 0.4 * math.sin(now * 0.9 + d.phase * 3)

			surface.SetDrawColor(ar, ag, ab, d.a * tw * ringA)
			surface.DrawTexturedRect(d.x - d.size * 0.5, d.y - d.size * 0.5, d.size, d.size)
		end

		draw.NoTexture()
	end

	-- вращающиеся прицельные сегменты (в режиме ожидания видны приглушённо)
	if (CFG.rotatingRings) then
		DrawRotatingRings(cx, cy, R, now, ar, ag, ab, ringA)
	end

	self:DrawShockwave(cx, cy, R, ar, ag, ab)

	if (ringA <= 0) then
		return
	end

	-- кольцо-прицел: внешний и внутренний контуры
	SmoothArc(cx, cy, R + 22, 0, 360, 1, 120, ar, ag, ab, 70 * ringA)

	-- шкала азимута; подсвечивается по мере загрузки
	local ticks = 72

	for i = 0, ticks - 1 do
		local a = math.rad(-90 + i * 360 / ticks)
		local major = i % 6 == 0
		local len = major and 14 or 6
		local alpha = (lit >= 1 or i / ticks < lit) and 210 or 55
		local c, s = math.cos(a), math.sin(a)

		SmoothLine(cx + c * R, cy + s * R, cx + c * (R + len), cy + s * (R + len), major and 2 or 1, ar, ag, ab, alpha * ringA)
	end

	-- дуга прогресса
	if (lit < 1) then
		SmoothArc(cx, cy, R - 8, -90, -90 + 360 * lit, 3, math.max(8, math.ceil(120 * lit)), 255, 255, 255, 230 * ringA)
	else
		SmoothArc(cx, cy, R - 8, 0, 360, 2, 120, ar, ag, ab, 150 * ringA)
	end

	-- радарный луч (медленный, с угасающим следом)
	if (CFG.bgSweep) then
		local ang = (RealTime() * 40) % 360
		local rIn, rOut = R - 58, R - 18
		local trail, n = 70, 28

		draw.NoTexture()

		for j = 0, n - 1 do
			local f = 1 - j / n

			surface.SetDrawColor(ar, ag, ab, 30 * f * f * ringA)
			RingBand(cx, cy, rIn, rOut, math.rad(ang - (j + 1) * trail / n), math.rad(trail / n), 1)
		end

		local sa = math.rad(ang)

		SmoothLine(cx + math.cos(sa) * rIn, cy + math.sin(sa) * rIn, cx + math.cos(sa) * rOut, cy + math.sin(sa) * rOut, 1.5, ar, ag, ab, 140 * ringA)
	end

	-- боковые шкалы дальности
	local ladderStart = math.floor(math.max(R + 50, (self.logoHalfW or 0) + 40))
	local ladderLen = math.floor(width * 0.08)

	draw.NoTexture()
	surface.SetDrawColor(ar, ag, ab, 90 * ringA)

	for side = -1, 1, 2 do
		local x0 = cx + side * ladderStart
		local x1 = x0 + side * ladderLen

		surface.DrawRect(math.min(x0, x1), cy, ladderLen, 1)

		for k = 0, 8 do
			local tx = math.floor(x0 + (x1 - x0) * k / 8)
			local th = (k % 4 == 0) and 9 or 4

			surface.DrawRect(tx, cy - th, 1, th * 2 + 1)
		end
	end
end

function PANEL:DrawForeground(width, height)
	local accent = GetAccent()
	local ar, ag, ab = accent.r, accent.g, accent.b
	local cx = math.floor(width * 0.5)
	local cy = math.floor(self.logoCenterY or height * 0.36)
	local R = math.floor(height * CFG.ringSize)
	local now = RealTime()
	local ha = self.hudReveal or 0

	draw.NoTexture()

	if (ha > 0) then
		local m, l = 28, 42

		-- угловые скобки
		surface.SetDrawColor(ar, ag, ab, 200 * ha)

		surface.DrawRect(m, m, l, 2)
		surface.DrawRect(m, m, 2, l)
		surface.DrawRect(width - m - l, m, l, 2)
		surface.DrawRect(width - m - 2, m, 2, l)
		surface.DrawRect(m, height - m - 2, l, 2)
		surface.DrawRect(m, height - m - l, 2, l)
		surface.DrawRect(width - m - l, height - m - 2, l, 2)
		surface.DrawRect(width - m - 2, height - m - l, 2, l)

		-- верхняя линия-разделитель
		surface.SetDrawColor(ar, ag, ab, 60 * ha)
		surface.DrawRect(m + l + 8, m, width - (m + l + 8) * 2, 1)

		-- статус: квадратный индикатор
		surface.SetFont("ixIntroSmall")

		local statusW = surface.GetTextSize(CFG.statusText)

		surface.SetDrawColor(255, 255, 255, (120 + 110 * (0.5 + 0.5 * math.sin(now * 3.2))) * ha)
		surface.DrawRect(width - m - 12 - statusW - 16, m + 14, 7, 7)

		draw.SimpleText(Upper(CFG.projectName) .. "  //  " .. os.date("%H:%M:%S"), "ixIntroSmall", m + 12, m + 8, Color(255, 255, 255, 150 * ha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(TypeText(CFG.statusText, (ha - 0.1) / 0.8), "ixIntroSmall", width - m - 12 - statusW, m + 8, Color(255, 255, 255, 150 * ha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		-- гриф внизу с линиями по бокам
		local textW = surface.GetTextSize(CFG.classification)
		local by = height - m - 6 - math.floor(select(2, surface.GetTextSize(CFG.classification)) * 0.5)
		local lineEnd = cx - textW * 0.5 - 24

		draw.NoTexture()
		surface.SetDrawColor(ar, ag, ab, 70 * ha)
		surface.DrawRect(m + l + 8, by, math.max(lineEnd - (m + l + 8), 0), 1)
		surface.DrawRect(math.floor(cx + textW * 0.5 + 24), by, math.max(lineEnd - (m + l + 8), 0), 1)

		draw.SimpleText(TypeText(CFG.classification, (ha - 0.2) / 0.8), "ixIntroSmall", math.floor(cx - textW * 0.5), height - m - 6, Color(ar, ag, ab, 200 * ha), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

		self:DrawHudExtras(width, height, ha)
	end

	local pa = self.promptAlpha or 0

	if (pa > 0) then
		local pulse = 0.5 + 0.5 * math.sin(now * 1.2)

		draw.SimpleText(CFG.promptText, "ixIntroMid", cx, math.floor(height * 0.5), Color(255, 255, 255, (170 + 85 * pulse) * pa), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		-- рамка-захват вокруг надписи и бегущие по ней индикаторы
		surface.SetFont("ixIntroMid")

		local pw, ph = surface.GetTextSize(CFG.promptText)
		local bx, by = math.floor(cx - pw * 0.5 - 30), math.floor(height * 0.5 - ph * 0.5 - 16)
		local bw, bh = math.floor(pw + 60), math.floor(ph + 32)
		local grow = 3 * pulse
		local sx = bx + ((now * 0.45) % 1) * bw

		draw.NoTexture()
		DrawBrackets(bx - grow, by - grow, bw + grow * 2, bh + grow * 2, 14, ar, ag, ab, 200 * pa)

		surface.SetDrawColor(255, 255, 255, 130 * pa)
		surface.DrawRect(sx - 14, by - grow, 28, 1)
		surface.DrawRect(bx + bw - (sx - bx) - 14, by + bh + grow, 28, 1)

		draw.SimpleText("ТЕРМИНАЛ ГОТОВ  //  ОЖИДАНИЕ ОПЕРАТОРА", "ixIntroSmall", cx, by + bh + 26, Color(ar, ag, ab, (110 + 60 * pulse) * pa), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local ua = self.loadUiAlpha or 0

	if (ua > 0) then
		local p = self.dispProgress or self.loadProgress or 0
		local steps = CFG.steps
		local idx = math.Clamp(math.floor(p * #steps) + 1, 1, #steps)
		local lineH = height * 0.028
		local baseY = cy + R + 50 + math.floor(height * 0.04) + lineH * 2

		for k = 0, 2 do
			local si = idx - k

			if (si >= 1) then
				local text

				if (k == 0 and p < 1) then
					text = steps[si] .. string.rep(".", math.floor(now * 3) % 4)
				else
					text = steps[si] .. "  [OK]"
				end

				local col = k == 0 and Color(255, 255, 255, 255 * ua) or Color(ar, ag, ab, (k == 1 and 150 or 70) * ua)

				draw.SimpleText(text, "ixIntroMid", cx, baseY - k * lineH, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end

		-- полоса прогресса и проценты
		local barW = math.floor(width * 0.22)
		local barH = 4
		local barX = cx - math.floor(barW * 0.5)
		local barY = math.floor(baseY + lineH * 1.2)

		draw.NoTexture()
		surface.SetDrawColor(ar, ag, ab, 40 * ua)
		surface.DrawRect(barX, barY, barW, barH)
		surface.SetDrawColor(255, 255, 255, 235 * ua)
		surface.DrawRect(barX, barY, math.floor(barW * p), barH)

		-- сегментные деления и светящаяся головка полосы
		surface.SetDrawColor(7, 10, 15, 200 * ua)

		for i = 1, 19 do
			surface.DrawRect(barX + math.floor(barW * i / 20), barY, 1, barH)
		end

		surface.SetMaterial(glowMat)
		surface.SetDrawColor(255, 255, 255, 130 * ua)
		surface.DrawTexturedRect(barX + barW * p - 20, barY + barH * 0.5 - 20, 40, 40)
		draw.NoTexture()
		surface.SetDrawColor(ar, ag, ab, 140 * ua)
		surface.DrawOutlinedRect(barX - 2, barY - 2, barW + 4, barH + 4, 1)

		draw.SimpleText(string.format("%d%%", math.floor(p * 100)), "ixIntroSmall", cx, barY + barH + 10, Color(255, 255, 255, 170 * ua), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end
end

-- атмосфера: развёртка, зерно, виньетка (поверх всего меню)
function PANEL:DrawAtmosphere(width, height)
	local now = RealTime()

	DrawScanlines(width, height, CFG.scanlines or 0, now)
	DrawGrain(width, height, CFG.grain or 0)
	DrawVignette(width, height, CFG.vignette or 0)
end

-- вспышка при входе в систему и плавное выступление из чёрного при открытии меню
function PANEL:DrawOverlay(width, height)
	draw.NoTexture()

	local fl = self.flash or 0

	if (fl > 0.002) then
		local accent = GetAccent()

		surface.SetDrawColor(Lerp(0.6, accent.r, 255), Lerp(0.6, accent.g, 255), Lerp(0.6, accent.b, 255), 255 * fl)
		surface.DrawRect(0, 0, width, height)
	end

	local dur = (self.mainPanel and self.mainPanel.bUsingCharacter) and 0.3 or 1.1
	local fa = 1 - math.Clamp((RealTime() - (self.openTime or 0)) / dur, 0, 1)

	if (fa > 0) then
		surface.SetDrawColor(0, 0, 0, 255 * fa ^ 1.5)
		surface.DrawRect(0, 0, width, height)
	end
end

-- расходящиеся кольца ударной волны в момент "входа в систему"
function PANEL:DrawShockwave(cx, cy, R, ar, ag, ab)
	local t = self.shockT

	if (!CFG.shockwave or !t or t < 0 or (self.loadDuration or 0) <= 0) then
		return
	end

	for i = 0, 1 do
		local p = (t - i * 0.18) / 1.5

		if (p > 0 and p < 1) then
			local e = EaseOutExpo(p)

			SmoothArc(cx, cy, R * (0.9 + e * 2.4), 0, 360, 2 + (1 - p) * 4, 160, ar, ag, ab, 200 * (1 - p) ^ 2)
		end
	end
end

-- дополнительные HUD-элементы: компас, поток данных, телеметрия
function PANEL:DrawHudExtras(width, height, ha)
	local accent = GetAccent()
	local ar, ag, ab = accent.r, accent.g, accent.b
	local now = RealTime()
	local m = 28
	local cx = math.floor(width * 0.5)

	-- компасная лента
	if (CFG.compass) then
		local halfW = math.floor(width * 0.13)
		local y = m + 34
		local hd = (now * 4 + 40) % 360
		local span = 48

		draw.NoTexture()
		surface.SetDrawColor(ar, ag, ab, 50 * ha)
		surface.DrawRect(cx - halfW, y + 14, halfW * 2, 1)

		for a = math.floor((hd - span) / 5) * 5, math.ceil((hd + span) / 5) * 5, 5 do
			local d = (a - hd) / span
			local fall = 1 - d * d

			if (fall > 0) then
				local x = math.floor(cx + d * halfW)
				local norm = a % 360
				local major = norm % 15 == 0

				surface.SetDrawColor(ar, ag, ab, (major and 190 or 90) * fall * ha)
				surface.DrawRect(x, y + (major and 6 or 9), 1, major and 8 or 5)

				if (COMPASS[norm]) then
					draw.SimpleText(COMPASS[norm], "ixIntroSmall", x, y - 8, Color(255, 255, 255, 230 * fall * ha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				elseif (major) then
					draw.SimpleText(tostring(norm), "ixIntroTiny", x, y - 6, Color(ar, ag, ab, 150 * fall * ha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
			end
		end

		draw.NoTexture()
		surface.SetDrawColor(255, 255, 255, 230 * ha)
		surface.DrawPoly({{x = cx, y = y + 14}, {x = cx + 5, y = y + 21}, {x = cx - 5, y = y + 21}})

		draw.SimpleText(string.format("%03d", math.floor(hd)), "ixIntroTiny", cx, y + 30, Color(255, 255, 255, 170 * ha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	-- бегущий поток hex-данных (левый край)
	if (CFG.hexColumns and self.hexLines) then
		if (now >= (self.nextHex or 0)) then
			self.nextHex = now + 0.11

			table.remove(self.hexLines, 1)
			self.hexLines[#self.hexLines + 1] = HexLine()
		end

		local n = #self.hexLines
		local lh = math.floor(height * 0.017)
		local x = m + 12
		local y0 = math.floor(height * 0.5 - n * lh * 0.5)

		draw.SimpleText("ПОТОК ДАННЫХ  //  RX", "ixIntroSmall", x, y0 - lh * 1.8, Color(255, 255, 255, 150 * ha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.NoTexture()
		surface.SetDrawColor(ar, ag, ab, 90 * ha)
		surface.DrawRect(x, y0 - lh, 250, 1)

		for i, line in ipairs(self.hexLines) do
			local f = i / n
			local col = (i == n) and Color(255, 255, 255, 210 * ha) or Color(ar, ag, ab, (25 + 95 * f * f) * ha)

			draw.SimpleText(line, "ixIntroMono", x, y0 + (i - 1) * lh, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
	end

	-- телеметрия (правый край)
	if (CFG.telemetry) then
		local ply = LocalPlayer()
		local ping = IsValid(ply) and ply:Ping() or 0

		self.fps = Lerp(math.min(RealFrameTime() * 2, 1), self.fps or 60, 1 / math.max(RealFrameTime(), 0.001))

		local xr = width - m - 12
		local lh = math.floor(height * 0.021)
		local y0 = math.floor(height * 0.5 - lh * 2.5)
		local rows = {
			{"ЗАДЕРЖКА", ping .. " МС"},
			{"КАДР/С", tostring(math.floor(self.fps))},
			{"КАНАЛ", "AES-256"},
			{"КВАДРАТ", "A-07"}
		}

		draw.SimpleText("ТЕЛЕМЕТРИЯ", "ixIntroSmall", xr, y0 - lh * 1.6, Color(255, 255, 255, 150 * ha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		draw.NoTexture()
		surface.SetDrawColor(ar, ag, ab, 90 * ha)
		surface.DrawRect(xr - 210, y0 - lh * 0.95, 210, 1)

		for i, row in ipairs(rows) do
			local yy = y0 + (i - 1) * lh

			draw.SimpleText(row[1], "ixIntroMono", xr - 210, yy, Color(ar, ag, ab, 140 * ha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(row[2], "ixIntroMono", xr, yy, Color(255, 255, 255, 200 * ha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		local yy = y0 + #rows * lh
		local bars = (ping <= 0 or ping < 70) and 5 or (ping < 110 and 4 or (ping < 170 and 3 or 2))

		draw.SimpleText("СИГНАЛ", "ixIntroMono", xr - 210, yy, Color(ar, ag, ab, 140 * ha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.NoTexture()

		for i = 1, 5 do
			local bh = 3 + i * 3

			if (i <= bars) then
				surface.SetDrawColor(255, 255, 255, 220 * (0.85 + 0.15 * math.sin(now * 5 + i)) * ha)
			else
				surface.SetDrawColor(ar, ag, ab, 45 * ha)
			end

			surface.DrawRect(xr - 35 + (i - 1) * 7, yy + 8 - bh, 4, bh)
		end
	end
end

function PANEL:Paint(width, height)
	surface.SetDrawColor(7, 10, 15, 255)
	surface.DrawRect(0, 0, width, height)

	self:DrawBackground(width, height)
end

function PANEL:PaintOver(width, height)
	self:DrawAtmosphere(width, height)
	self:DrawForeground(width, height)
	self:DrawOverlay(width, height)

	if (self.bClosing and self.bFromMenu) then
		surface.SetDrawColor(color_black)
		surface.DrawRect(0, 0, width, height)
	end
end

function PANEL:OnRemove()
	if (self.ambient) then
		self.ambient:Stop()
		self.ambient = nil
	end

	if (IsValid(self.channel)) then
		self.channel:Stop()
		self.channel = nil
	end
end

vgui.Register("ixCharMenu", PANEL, "EditablePanel")

if (IsValid(ix.gui.characterMenu)) then
	ix.gui.characterMenu:Remove()

	ix.gui.characterMenu = vgui.Create("ixCharMenu")
end