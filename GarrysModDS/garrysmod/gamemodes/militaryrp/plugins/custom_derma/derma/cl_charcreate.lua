local padding = ScreenScale(32)
local glowMat = Material("sprites/light_glow02_add")

--[[
	НАСТРОЙКИ ЭКРАНА СОЗДАНИЯ ПЕРСОНАЖА
	Первый этап — разделённый экран: слева синяя сторона, справа красная.
	В игре ровно две фракции: синяя — FACTION_FVUR, красная — FACTION_EIR (имя глобальной
	константы задано в factionConst у стороны).
	logo — картинка стороны: положите файл в materials/ и добавьте на сервере
	resource.AddFile("materials/файл.png"). Путь указывается относительно materials/.
	Если файла нет, логотип просто не рисуется.
]]
local CFG = {
	modelFOV = 72, -- угол обзора превью-моделей на экране выбора стороны
	modelTurn = 1, -- 1 или -1: направление поворота модели за курсором
	modelTurnMax = 16, -- максимальный поворот модели за курсором (градусы)
	hoverShift = 0.06, -- на сколько расширяется сторона при наведении (доля ширины экрана)
	pickDelay = 0.75, -- пауза после клика перед переходом дальше (сек.)
	floorY = 0.765, -- высота «пола» под моделью (доля высоты экрана)
	ringScale = 0.88, -- размер колец под моделью (1 = как раньше; уменьшите, если кольца заходят на кнопку)
	hideMenuHud = true, -- прятать HUD из cl_character (компас, телеметрию, поток данных, скобки, надписи) на время создания персонажа
	hideMenuAtmosphere = false, -- прятать ещё и атмосферу (развёртку, зерно, виньетку) на время создания персонажа
	modelScale = 0.78, -- размер превью-моделей (1 = как раньше)
	modelCenterY = 0.512, -- вертикальный центр превью-моделей (доля высоты экрана; больше = модель ниже, дальше от текста)
	modelFace = 0, -- подстройка разворота к камере в градусах (если модели смотрят чуть в сторону — подберите)
	particles = 22, -- плывущие светлые точки на каждой стороне (0 = выкл)
	gridAlpha = 1, -- прозрачность сетки (множитель, 0 = без сетки)
	logoHeight = 0.09, -- высота логотипа стороны (доля высоты экрана)

	heading = "ВЫБЕРИТЕ СТОРОНУ",
	subHeading = "НАВЕДИТЕ КУРСОР НА СТОРОНУ И НАЖМИТЕ, ЧТОБЫ ПОДТВЕРДИТЬ ВЫБОР",
	centerText = "VS", -- надпись в центральной эмблеме ("" = без надписи)
	chooseText = "ВЫБРАТЬ СТОРОНУ",
	unavailableText = "НЕДОСТУПНО",
	previewText = "ПРЕДПРОСМОТР",
	sideLabel = "СТОРОНА",

	sounds = true,
	soundVolume = 0.55,
	soundSet = {
		hover = {"buttons/blip1.wav", 0.35, 115},
		click = {"buttons/button15.wav", 0.5, 100},
		deny = {"buttons/button10.wav", 0.5, 100},
		open = {"buttons/combine_button1.wav", 0.4, 105},
		tick = {"buttons/blip2.wav", 0.18, 130},
		boom = {"ambient/machines/thumper_hit.wav", 0.55, 100},
		confirm = {"buttons/combine_button7.wav", 0.45, 100}
	},

	sides = {
		{
			name = "СИНИЕ",
			tag = "СТОРОНА 01",
			slogan = "СМЕРТЬ ВРАГАМ УЗИРСКОЙ РЕСПУБЛИКИ!",
			lines = {
				"> Свобода - это ваш девиз.",
			},
			model = "models/player/leet.mdl", -- временная модель
			factionConst = "FACTION_FVUR",
			logo = "fvur_logo.png", -- логотип слева (materials/fvur_logo.png)
			color = Color(70, 140, 235),
			dark = Color(6, 13, 28),
			mid = Color(18, 48, 102)
		},
		{
			name = "КРАСНЫЕ",
			tag = "СТОРОНА 02",
			slogan = "ВОЙНА - МИР, СВОБОДА - РАБСТВО.",
			lines = {
				"> Зачем свобода, если есть порядок?",
			},
			model = "models/player/gasmask.mdl", -- временная модель
			factionConst = "FACTION_EIR",
			logo = "eir_logo.png", -- логотип справа (materials/eir_logo.png)
			color = Color(232, 68, 68),
			dark = Color(28, 7, 9),
			mid = Color(104, 22, 28)
		}
	}
}

local function CreateFonts()
	local h = ScrH()

	surface.CreateFont("ixSplitHuge", {font = "Roboto", size = math.floor(h * 0.085), weight = 700, extended = true, antialias = true})
	surface.CreateFont("ixSplitBig", {font = "Roboto", size = math.floor(h * 0.05), weight = 700, extended = true, antialias = true})
	-- запасные размеры для длинных названий сторон
	surface.CreateFont("ixSplitName", {font = "Roboto", size = math.floor(h * 0.04), weight = 700, extended = true, antialias = true})
	surface.CreateFont("ixSplitNameS", {font = "Roboto", size = math.floor(h * 0.032), weight = 700, extended = true, antialias = true})
	surface.CreateFont("ixSplitMid", {font = "Roboto", size = math.floor(h * 0.024), weight = 600, extended = true, antialias = true})
	surface.CreateFont("ixSplitSmall", {font = "Roboto", size = math.floor(h * 0.0165), weight = 500, extended = true, antialias = true})
end

CreateFonts()

local C = TEXT_ALIGN_CENTER

local function EaseOutCubic(x)
	return 1 - (1 - x) ^ 3
end

local function EaseOutExpo(x)
	return x >= 1 and 1 or 1 - 2 ^ (-10 * x)
end

local function Upper(text)
	return (string.utf8upper or string.upper)(text)
end

-- эффект «печатной машинки» с учётом UTF-8
local function TypeText(text, p)
	local len = utf8.len(text) or #text
	local n = math.floor(len * math.Clamp(p, 0, 1))

	if (n >= len) then
		return text
	end

	return text:sub(1, (utf8.offset(text, n + 1) or (#text + 1)) - 1)
end

-- вертикаль заголовка: ниже компасной ленты из cl_character (она занимает примерно верхние 100 px)
local function HeadingY(h)
	if (CFG.hideMenuHud) then
		return math.floor(h * 0.07)
	end

	return math.max(math.floor(h * 0.125), 128)
end

-- на время создания персонажа гасит (плавно) часть рисования меню cl_character: метод оборачивается на самом меню,
-- сам cl_character не меняется. Флаг menu.ixHideHud выставляет панель создания.
local function HookMenuDraw(menu, method, enabled)
	local base = menu[method]

	if (!base or menu["ixHooked_" .. method]) then
		return
	end

	menu["ixHooked_" .. method] = true

	local keepKey = "ixKeep_" .. method

	menu[keepKey] = 1

	menu[method] = function(this, w, h)
		local target = (enabled() and this.ixHideHud) and 0 or 1

		this[keepKey] = Lerp(math.min(RealFrameTime() * 8, 1), this[keepKey], target)

		if (this[keepKey] < 0.01) then
			return
		end

		local old = surface.GetAlphaMultiplier()

		surface.SetAlphaMultiplier(old * this[keepKey])
			base(this, w, h)
		surface.SetAlphaMultiplier(old)
	end
end

-- перенос по словам
local function WrapText(text, font, maxW)
	local lines, cur = {}, ""

	surface.SetFont(font)

	for word in string.gmatch(text, "%S+") do
		local try = (cur == "") and word or (cur .. " " .. word)

		if (cur != "" and surface.GetTextSize(try) > maxW) then
			lines[#lines + 1] = cur
			cur = word
		else
			cur = try
		end
	end

	if (cur != "") then
		lines[#lines + 1] = cur
	end

	return lines
end

-- подбирает самый крупный шрифт, в который название влезает в одну строку; если не влезло нигде — переносит по словам
-- возвращает: шрифт, список строк, ширину самой длинной строки, высоту строки
local NAME_FONTS = {"ixSplitHuge", "ixSplitBig", "ixSplitName", "ixSplitNameS"}

local function FitName(text, maxW)
	for _, font in ipairs(NAME_FONTS) do
		surface.SetFont(font)

		local tw, th = surface.GetTextSize(text)

		if (tw <= maxW) then
			return font, {text}, tw, th
		end
	end

	local font = NAME_FONTS[#NAME_FONTS]
	local lines = WrapText(text, font, maxW)
	local tw, th = 0, select(2, surface.GetTextSize(text))

	for _, line in ipairs(lines) do
		tw = math.max(tw, (surface.GetTextSize(line)))
	end

	return font, lines, tw, th
end

-- угол, при котором модель смотрит прямо на камеру превью.
-- Камера DModelPanel стоит по диагонали (~45°), поэтому yaw = 0 даёт вид «вполоборота»
local function FaceYaw(panel, entity)
	local cam = panel.GetCamPos and panel:GetCamPos()

	if (cam) then
		local dir = cam - entity:GetPos()

		if (math.abs(dir.x) + math.abs(dir.y) > 0.01) then
			return math.deg(math.atan2(dir.y, dir.x)) + CFG.modelFace
		end
	end

	return 45 + CFG.modelFace
end

--[[
	СГЛАЖЕННАЯ ОТРИСОВКА (как в cl_character): ядро линии + два полупрозрачных края
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

-- sq — сжатие по вертикали (1 = круг, <1 = эллипс)
local function RingBand(cx, cy, rIn, rOut, a0, step, seg, sq)
	if (rOut <= 0) then
		return
	end

	rIn = math.max(rIn, 0)
	sq = sq or 1

	local c0, s0 = math.cos(a0), math.sin(a0)

	for i = 1, seg do
		local a = a0 + step * i
		local c1, s1 = math.cos(a), math.sin(a)

		SetQuad(
			cx + c0 * rOut, cy + s0 * rOut * sq,
			cx + c1 * rOut, cy + s1 * rOut * sq,
			cx + c1 * rIn, cy + s1 * rIn * sq,
			cx + c0 * rIn, cy + s0 * rIn * sq
		)

		c0, s0 = c1, s1
	end
end

local function SmoothArc(cx, cy, r, deg0, deg1, thick, seg, cr, cg, cb, ca, sq)
	if (ca <= 0 or deg1 <= deg0) then
		return
	end

	local a0 = math.rad(deg0)
	local step = math.rad(deg1 - deg0) / seg
	local half = thick * 0.5

	draw.NoTexture()
	surface.SetDrawColor(cr, cg, cb, ca)
	RingBand(cx, cy, r - half, r + half, a0, step, seg, sq)

	for _, f in ipairs(FEATHER) do
		surface.SetDrawColor(cr, cg, cb, ca * f[3])
		RingBand(cx, cy, r + half + f[1], r + half + f[2], a0, step, seg, sq)
		RingBand(cx, cy, r - half - f[2], r - half - f[1], a0, step, seg, sq)
	end
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

-- логотип стороны: материал ищется один раз; если файла нет, логотип не рисуется
local function GetLogo(side)
	if (side.logoMat == nil) then
		side.logoMat = false

		if (side.logo and side.logo != "") then
			local mat = Material(side.logo, "smooth mips")

			if (mat and !mat:IsError()) then
				side.logoMat = mat
			end
		end
	end

	return side.logoMat
end

-- рисует логотип по центру (cx, cy) высотой h, не шире maxW; возвращает итоговую ширину
local function DrawLogo(mat, cx, cy, h, c, a, glow, maxW)
	local w = h * mat:Width() / math.max(mat:Height(), 1)

	if (maxW and w > maxW) then
		h = h * maxW / w
		w = maxW
	end

	if (glow and glow > 0) then
		local gs = h * 2.4

		surface.SetMaterial(glowMat)
		surface.SetDrawColor(c.r, c.g, c.b, glow)
		surface.DrawTexturedRect(cx - gs * 0.5, cy - gs * 0.5, gs, gs)
	end

	-- целочисленные координаты и анизотропная фильтрация: картинка без размытия
	render.PushFilterMag(TEXFILTER.ANISOTROPIC)
	render.PushFilterMin(TEXFILTER.ANISOTROPIC)
		surface.SetMaterial(mat)
		surface.SetDrawColor(255, 255, 255, a)
		surface.DrawTexturedRect(math.Round(cx - w * 0.5), math.Round(cy - h * 0.5), math.Round(w), math.Round(h))
	render.PopFilterMin()
	render.PopFilterMag()

	draw.NoTexture()

	return w
end

local lastPlayed = {}

local function PlayUI(key, pitchMul, volMul)
	local def = CFG.soundSet[key]

	if (!CFG.sounds or !def) then
		return
	end

	local now = RealTime()

	-- защита от «залпа» одинаковых звуков в один кадр
	if (lastPlayed[key] and now - lastPlayed[key] < 0.05) then
		return
	end

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

-- кнопка в стиле меню из cl_character; getAccent возвращает текущий акцентный цвет
local function StyleButton(button, getAccent)
	button.hoverFrac = 0
	button.pressFrac = 0

	local basePressed = button.OnMousePressed

	button.OnCursorEntered = function(this)
		this.shineStart = RealTime()

		if (!this:GetDisabled()) then
			PlayUI("hover", math.Rand(0.96, 1.06))
		end
	end

	button.OnCursorExited = function() end

	button.OnMousePressed = function(this, code)
		if (code == MOUSE_LEFT) then
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
		local accent = getAccent()
		local k = disabled and 0.3 or 1
		local now = RealTime()
		local dt = RealFrameTime()

		this.hoverFrac = Lerp(math.min(dt * 14, 1), this.hoverFrac, target)
		this.pressFrac = Lerp(math.min(dt * 7, 1), this.pressFrac, 0)

		local f = this.hoverFrac
		local ef = EaseOutCubic(f)
		local pf = this.pressFrac
		local y, bh = 3, h - 6

		draw.NoTexture()

		surface.SetDrawColor(accent.r, accent.g, accent.b, (16 + 34 * f) * k)
		surface.DrawRect(0, y, w, bh)

		-- заливка, выезжающая слева при наведении
		if (ef > 0.01) then
			surface.SetDrawColor(accent.r, accent.g, accent.b, 40 * ef * k)
			surface.DrawRect(0, y, math.floor(w * ef), bh)
		end

		-- одиночный блик
		if (f > 0.05 and !disabled) then
			local st = (now - (this.shineStart or now)) * 1.7

			if (st < 1) then
				local sx = math.floor(-40 + (w + 80) * EaseOutCubic(st))

				for i = 0, 7 do
					local x = sx + i * 5

					if (x >= 0 and x < w) then
						surface.SetDrawColor(255, 255, 255, 38 * math.sin((i + 0.5) / 8 * math.pi) * f)
						surface.DrawRect(x, y, 5, bh)
					end
				end
			end
		end

		-- рамка с лёгким «дыханием»
		local breathe = 0.5 + 0.5 * math.sin(now * 1.6 + h)

		surface.SetDrawColor(accent.r, accent.g, accent.b, (104 + 8 * breathe + 108 * f) * k)
		surface.DrawOutlinedRect(0, y, w, bh, 1)

		-- маркер слева
		surface.SetDrawColor(255, 255, 255, (70 + 185 * f) * k)
		surface.DrawRect(0, y, 4 + math.floor(3 * ef), bh)

		-- скобки справа при наведении
		if (ef > 0.02 and w > 24) then
			local bl = math.floor(10 * ef)

			surface.SetDrawColor(255, 255, 255, 200 * ef * k)
			surface.DrawRect(w - bl - 1, y, bl, 2)
			surface.DrawRect(w - 2, y, 2, bl)
			surface.DrawRect(w - bl - 1, y + bh - 2, bl, 2)
			surface.DrawRect(w - 2, y + bh - bl, 2, bl)
		end

		-- вспышка при нажатии
		if (pf > 0.01) then
			surface.SetDrawColor(255, 255, 255, 70 * pf * k)
			surface.DrawRect(0, y, w, bh)
		end

		local text = this:GetText()
		local font = this:GetFont()
		local tx = w * 0.5
		local ty = h * 0.5 + pf

		surface.SetFont(font)

		local tw = surface.GetTextSize(text)

		draw.SimpleText(text, font, tx + 1, ty + 1, Color(0, 0, 0, 150 * k), C, C)
		draw.SimpleText(text, font, tx, ty, Color(255, 255, 255, (200 + 55 * f) * k), C, C)

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

--[[
	ЭКРАН ВЫБОРА СТОРОНЫ
	Разделённый экран: синие слева, красные справа. Сторона под курсором расширяется,
	подсвечивается, её модель поворачивается за курсором. Клик — выбор фракции.
]]
local SPLIT = {}

function SPLIT:Init()
	self.entries = {false, false}
	self.hover = {0, 0}
	self.shine = {-10, -10}
	self.hoverSide = 0
	self.rawSide = 0
	self.split = 0.5
	self.pick = 0
	self.pickStart = 0
	self.proceeded = false
	self.shownAt = RealTime()
	self.inset = 0
	self.models = {}
	self.particles = {}

	for i, side in ipairs(CFG.sides) do
		local mp = self:Add("ixModelPanel")
		mp:SetModel(side.model)
		mp:SetFOV(CFG.modelFOV)
		mp.PaintModel = mp.Paint
		mp:SetMouseInputEnabled(false)
		mp.yaw = 0

		-- плавный поворот модели за курсором
		mp.LayoutEntity = function(this, entity)
			this:RunAnimation()

			if (IsValid(entity)) then
				-- базовый разворот лицом к камере + плавный поворот за курсором
				entity:SetAngles(Angle(0, FaceYaw(this, entity) + (this.yaw or 0), 0))
			end
		end

		self.models[i] = mp
		self.particles[i] = {}

		for n = 1, CFG.particles do
			self.particles[i][n] = {
				fx = math.Rand(0.05, 0.95),
				y = math.Rand(0, ScrH()),
				speed = math.Rand(8, 26),
				size = math.Rand(6, 16),
				phase = math.Rand(0, math.pi * 2),
				a = math.Rand(25, 70)
			}
		end
	end
end

-- list[1], list[2] = {faction = индекс, name = название, side = номер стороны} либо false
function SPLIT:SetSides(list)
	self.entries = {list[1] or false, list[2] or false}
end

function SPLIT:OnSelect(side, entry)
end

function SPLIT:OnProceed(side)
end

function SPLIT:IsBusy()
	return self.pick != 0 and !self.proceeded
end

function SPLIT:Reset()
	self.pick = 0
	self.proceeded = false
	self.hoverSide = 0
	self.shownAt = RealTime()
	self.fadeOutAt = nil

	self:SetMouseInputEnabled(true)
end

-- плавно гасит экран выбора (при переходе к следующему этапу), затем прячет панель
function SPLIT:FadeOut()
	if (self.fadeOutAt) then
		return
	end

	self.fadeOutAt = RealTime()
	self:SetMouseInputEnabled(false)
end

function SPLIT:Choose(side)
	self.pick = side
	self.pickStart = RealTime()
	self.proceeded = false

	PlayUI("confirm")
	PlayUI("boom", 1.1)

	self:OnSelect(side, self.entries[side])
end

function SPLIT:OnMousePressed(code)
	if (code != MOUSE_LEFT or self.pick != 0) then
		return
	end

	local side = self.rawSide

	if (side == 0) then
		return
	end

	if (!self.entries[side]) then
		PlayUI("deny")

		return
	end

	self:Choose(side)
end

function SPLIT:UpdateModels(now, dt, mx, hovered)
	local w, h = self:GetSize()
	local sx = w * self.split

	for i = 1, 2 do
		local mp = self.models[i]
		local x0 = (i == 1) and 0 or sx
		local sw = (i == 1) and sx or (w - sx)
		local hv = EaseOutCubic(self.hover[i])
		local unf = EaseOutCubic(self.hover[3 - i])
		local mw = math.min(h * 0.78 * CFG.modelScale * (1 + 0.05 * hv), math.max(sw, 1))
		local mh = h * 0.88 * CFG.modelScale * (1 + 0.05 * hv)
		local cx = x0 + sw * 0.5

		mp:SetVisible(sw > 60)
		mp:SetSize(mw, mh)
		mp:SetPos(cx - mw * 0.5, h * CFG.modelCenterY - mh * 0.5)

		local rel = hovered and math.Clamp((mx - cx) / (w * 0.35), -1, 1) or 0
		local want = CFG.modelTurn * (rel * CFG.modelTurnMax * (0.35 + 0.65 * hv) + math.sin(now * 0.8 + i * 2) * 2.5)

		mp.yaw = Lerp(math.min(dt * 5, 1), mp.yaw or 0, want)
		mp.brightness = 0.7 + 0.45 * hv - 0.3 * unf
	end
end

function SPLIT:Think()
	local now = RealTime()
	local dt = math.min(RealFrameTime(), 0.05)

	if (self.fadeOutAt and now - self.fadeOutAt >= 0.4) then
		self.fadeOutAt = nil
		self:SetVisible(false)

		return
	end
	local w = self:GetWide()
	local mx = self:CursorPos()
	local hovered = self:IsHovered()
	local raw = 0

	if (hovered and self.pick == 0) then
		raw = (mx < w * self.split) and 1 or 2
	end

	self.rawSide = raw

	local side = (raw != 0 and self.entries[raw]) and raw or 0

	if (side != self.hoverSide) then
		self.hoverSide = side

		if (side != 0) then
			self.shine[side] = now
			PlayUI("hover", side == 1 and 1 or 0.92)
		end
	end

	self:SetCursor(side != 0 and "hand" or "arrow")

	for i = 1, 2 do
		local want = (self.pick == i or (self.pick == 0 and side == i)) and 1 or 0

		self.hover[i] = Lerp(math.min(dt * 9, 1), self.hover[i], want)
	end

	local target = 0.5

	if (self.pick == 1) then
		target = 1
	elseif (self.pick == 2) then
		target = 0
	elseif (side == 1) then
		target = 0.5 + CFG.hoverShift
	elseif (side == 2) then
		target = 0.5 - CFG.hoverShift
	end

	self.split = Lerp(math.min(dt * (self.pick != 0 and 5 or 7), 1), self.split, target)

	if (self.pick != 0 and !self.proceeded and now - self.pickStart >= CFG.pickDelay) then
		self.proceeded = true
		self:OnProceed(self.pick)
	end

	self:UpdateModels(now, dt, mx, hovered)
end

-- фон одной стороны (рисуется внутри scissor)
function SPLIT:DrawSideBack(i, x0, sw, w, h, now, dt)
	local side = CFG.sides[i]
	local c = side.color
	local hv = EaseOutCubic(self.hover[i])
	local cx = x0 + sw * 0.5

	draw.NoTexture()
	surface.SetDrawColor(side.dark.r, side.dark.g, side.dark.b, 255)
	surface.DrawRect(x0, 0, sw, h)

	-- вертикальный градиент: светлее к низу
	local n = 24
	local bh = math.ceil(h / n)

	for k = 0, n - 1 do
		local f = ((k + 1) / n) ^ 2

		surface.SetDrawColor(side.mid.r, side.mid.g, side.mid.b, (90 + 90 * hv) * f)
		surface.DrawRect(x0, k * bh, sw, bh)
	end

	-- тактическая сетка
	local step = math.max(math.floor(h / 12), 48)

	for gx = 0, w, step do
		if (gx >= x0 - 1 and gx <= x0 + sw) then
			local major = (gx / step) % 4 == 0

			surface.SetDrawColor(c.r, c.g, c.b, (major and 9 or 4) * CFG.gridAlpha * (1 + hv))
			surface.DrawRect(gx, 0, 1, h)
		end
	end

	for gy = 0, h, step do
		local major = (gy / step) % 4 == 0

		surface.SetDrawColor(c.r, c.g, c.b, (major and 9 or 4) * CFG.gridAlpha * (1 + hv))
		surface.DrawRect(x0, gy, sw, 1)
	end

	-- свечение за моделью и на полу
	local gs = h * (1.15 + 0.25 * hv)

	surface.SetMaterial(glowMat)
	surface.SetDrawColor(c.r, c.g, c.b, 38 + 70 * hv)
	surface.DrawTexturedRect(cx - gs * 0.5, h * CFG.modelCenterY - gs * 0.5, gs, gs)
	surface.SetDrawColor(c.r, c.g, c.b, 30 + 60 * hv)
	surface.DrawTexturedRect(cx - gs * 0.4, h * CFG.floorY - gs * 0.1, gs * 0.8, gs * 0.2)

	-- плывущие светлые точки
	local list = self.particles[i]

	if (#list > 0) then
		for _, p in ipairs(list) do
			p.y = p.y - p.speed * dt * (1 + hv * 1.8)

			if (p.y < -20) then
				p.y = h + 20
			end

			local px = x0 + p.fx * sw + math.sin(now * 0.4 + p.phase) * 14
			local tw = 0.6 + 0.4 * math.sin(now * 1.1 + p.phase * 3)

			surface.SetDrawColor(c.r, c.g, c.b, p.a * tw * (0.6 + 0.8 * hv))
			surface.DrawTexturedRect(px - p.size * 0.5, p.y - p.size * 0.5, p.size, p.size)
		end
	end

	draw.NoTexture()

	-- кольца на «полу» под моделью
	local fy = h * CFG.floorY
	local rx = math.min(sw * 0.34, h * 0.42) * CFG.ringScale * (1 + 0.08 * hv)

	SmoothArc(cx, fy, rx, 0, 360, 2, 90, c.r, c.g, c.b, 90 + 110 * hv, 0.2)
	SmoothArc(cx, fy, rx * 0.72, 0, 360, 1, 72, 255, 255, 255, 30 + 60 * hv, 0.2)

	for k = 0, 5 do
		local s = now * (30 + 40 * hv) + k * 60

		SmoothArc(cx, fy, rx * 1.12, s, s + 22, 3, 10, 255, 255, 255, 60 + 150 * hv, 0.2)
	end

	-- блик, пробегающий по стороне при наведении
	local st = (now - self.shine[i]) * 1.4

	if (st >= 0 and st < 1 and hv > 0.05) then
		local sxp = x0 - 120 + (sw + 240) * EaseOutCubic(st)

		draw.NoTexture()

		for k = 0, 9 do
			surface.SetDrawColor(255, 255, 255, 26 * math.sin((k + 0.5) / 10 * math.pi))
			surface.DrawRect(sxp + k * 8, 0, 8, h)
		end
	end

	-- медленная сканирующая линия при наведении
	if (hv > 0.02) then
		local y = (now * h * 0.22) % h

		for k = 0, 9 do
			surface.SetDrawColor(c.r, c.g, c.b, 22 * hv * (1 - k / 10))
			surface.DrawRect(x0, y - k * 3, sw, 3)
		end

		surface.SetDrawColor(c.r, c.g, c.b, 70 * hv)
		surface.DrawRect(x0, y, sw, 2)
	end
end

-- интерфейс стороны поверх модели
function SPLIT:DrawSideHUD(i, x0, sw, w, h, now)
	local side = CFG.sides[i]
	local c = side.color
	local entry = self.entries[i]
	local hv = EaseOutCubic(self.hover[i])
	local unf = EaseOutCubic(self.hover[3 - i])
	local cx = math.floor(x0 + sw * 0.5)

	draw.NoTexture()

	-- затемнение невыбранной / недоступной стороны
	local darkA = 170 * unf + (entry and 0 or 110)

	if (darkA > 0) then
		surface.SetDrawColor(0, 0, 0, darkA)
		surface.DrawRect(x0, 0, sw, h)
	end

	-- вспышка и ударные кольца при выборе
	if (self.pick == i) then
		local t = now - self.pickStart
		local fa = (1 - math.Clamp(t / 0.6, 0, 1)) ^ 2

		if (fa > 0) then
			surface.SetDrawColor(255, 255, 255, 100 * fa)
			surface.DrawRect(x0, 0, sw, h)
		end

		for r = 0, 1 do
			local p = (t - r * 0.15) / 1.1

			if (p > 0 and p < 1) then
				SmoothArc(cx, h * 0.5, h * 0.12 + EaseOutExpo(p) * h * 0.75, 0, 360, 2 + (1 - p) * 5, 140, c.r, c.g, c.b, 220 * (1 - p) ^ 2)
			end
		end
	end

	local vis = math.Clamp((sw - w * 0.12) / (w * 0.12), 0, 1)

	if (vis <= 0) then
		return
	end

	local k = (1 - 0.55 * unf) * (entry and 1 or 0.45) * vis
	local breathe = 0.5 + 0.5 * math.sin(now * 1.6 + i)

	-- плашка выбора внизу (геометрия считается здесь, чтобы от неё зависела нижняя граница рамки)
	local pw = math.floor(math.min(sw * 0.56, h * 0.5))
	local ph = math.floor(h * 0.056)
	local px = math.floor(cx - pw * 0.5)
	local py = math.floor(h - self.inset - 22 - ph - h * 0.03)

	-- угловые скобки стороны, растут при наведении.
	-- От внешних краёв экрана отступаем сильнее, чтобы не налезать на угловые скобки HUD из cl_character;
	-- сверху — под заголовком, снизу — над надписью «ДОСТУП ОГРАНИЧЕН»
	local edge = CFG.hideMenuHud and 28 or 56
	local frameL = (i == 1) and (x0 + edge) or (x0 + 18)
	local frameR = (i == 2) and (x0 + sw - edge) or (x0 + sw - 18)
	local frameT = HeadingY(h) + 52
	local frameB = py + ph + 20

	draw.NoTexture()
	DrawBrackets(frameL, frameT, frameR - frameL, frameB - frameT, math.floor(26 + 24 * hv), c.r, c.g, c.b, (80 + 170 * hv) * k)

	-- метка, название, подчёркивание, девиз
	local name = Upper(entry and entry.name or side.name)

	-- ширина считается от узкой стороны, а не от текущей: шрифт не «прыгает» при наведении
	local font, nameLines, tw, th = FitName(name, math.floor(w * 0.5 * 0.82))
	local lineStep = math.floor(th * 0.92)
	local topY = HeadingY(h) + 62
	local tagY = topY
	local logo = GetLogo(side)

	-- логотип стороны над названием (текст сдвигается вниз, если логотип есть)
	if (logo) then
		local lh = h * CFG.logoHeight
		local bob = math.sin(now * 1.2 + i * 2) * 3

		DrawLogo(logo, cx, topY + lh * 0.5 + bob - 4 * hv, lh * (1 + 0.12 * hv), c, (210 + 45 * hv) * k, (30 + 70 * hv) * k, sw * 0.5)

		tagY = math.floor(topY + lh + 24)
	end
	local nameY = math.floor(tagY + 18 + th * 0.5 - 6 * hv)

	draw.SimpleText(side.tag, "ixSplitSmall", cx, tagY, Color(c.r, c.g, c.b, (170 + 60 * hv) * k), C, C)

	-- «глитч» названия в момент наведения
	local gl = math.Clamp(1 - (now - self.shine[i]) / 0.28, 0, 1)

	for n, line in ipairs(nameLines) do
		local ly = nameY + (n - 1) * lineStep

		if (gl > 0 and hv > 0.05) then
			local off = 3 + gl * 6

			draw.SimpleText(line, font, cx - off, ly, Color(255, 50, 70, 120 * gl), C, C)
			draw.SimpleText(line, font, cx + off, ly, Color(50, 220, 255, 120 * gl), C, C)
		end

		draw.SimpleText(line, font, cx + 2, ly + 2, Color(0, 0, 0, 160 * k), C, C)
		draw.SimpleText(line, font, cx, ly, Color(255, 255, 255, (200 + 55 * hv) * k), C, C)
	end

	local ulY = math.floor(nameY + (#nameLines - 1) * lineStep + th * 0.5 + 4)
	local lw = math.floor((tw + 60) * (0.3 + 0.7 * hv))

	draw.NoTexture()
	surface.SetDrawColor(c.r, c.g, c.b, (150 + 100 * hv) * k)
	surface.DrawRect(cx - math.floor(lw * 0.5), ulY, lw, 2)
	surface.SetDrawColor(255, 255, 255, 220 * k)
	surface.DrawRect(cx - math.floor(lw * 0.5) - 5, ulY - 1, 4, 4)
	surface.DrawRect(cx + math.floor(lw * 0.5) + 1, ulY - 1, 4, 4)

	local sloganY = ulY + 22

	draw.SimpleText(side.slogan, "ixSplitSmall", cx, sloganY, Color(255, 255, 255, (120 + 60 * hv) * k), C, C)

	-- строки данных печатаются при наведении
	local lineH = math.floor(h * 0.027)

	for n, line in ipairs(side.lines) do
		local p = (hv - 0.15 * (n - 1)) / 0.55

		if (p > 0) then
			surface.SetFont("ixSplitSmall")

			local fullW = surface.GetTextSize(line)

			draw.SimpleText(TypeText(line, p), "ixSplitSmall", math.floor(cx - fullW * 0.5), sloganY + 30 + (n - 1) * lineH, Color(c.r, c.g, c.b, 210 * math.min(p, 1) * k), TEXT_ALIGN_LEFT, C)
		end
	end

	-- плашка выбора
	draw.NoTexture()
	surface.SetDrawColor(c.r, c.g, c.b, (16 + 30 * hv) * k)
	surface.DrawRect(px, py, pw, ph)

	if (hv > 0.01) then
		surface.SetDrawColor(c.r, c.g, c.b, 70 * hv * k)
		surface.DrawRect(px, py, math.floor(pw * hv), ph)
	end

	surface.SetDrawColor(c.r, c.g, c.b, (100 + 8 * breathe + 140 * hv) * k)
	surface.DrawOutlinedRect(px, py, pw, ph, 1)
	surface.SetDrawColor(255, 255, 255, (70 + 185 * hv) * k)
	surface.DrawRect(px, py, 4 + math.floor(3 * hv), ph)

	local label = entry and CFG.chooseText or CFG.unavailableText

	surface.SetFont("ixSplitMid")

	local lwid = surface.GetTextSize(label)

	draw.SimpleText(label, "ixSplitMid", cx + 1, py + ph * 0.5 + 1, Color(0, 0, 0, 150 * k), C, C)
	draw.SimpleText(label, "ixSplitMid", cx, py + ph * 0.5, Color(255, 255, 255, (190 + 65 * hv) * k), C, C)

	if (hv > 0.02 and entry) then
		local off = 26 - 10 * hv
		local lx, rx = cx - lwid * 0.5 - off, cx + lwid * 0.5 + off
		local ty = py + ph * 0.5

		SmoothLine(lx, ty - 5, lx + 5, ty, 1.5, 255, 255, 255, 230 * hv * k)
		SmoothLine(lx + 5, ty, lx, ty + 5, 1.5, 255, 255, 255, 230 * hv * k)
		SmoothLine(rx, ty - 5, rx - 5, ty, 1.5, 255, 255, 255, 230 * hv * k)
		SmoothLine(rx - 5, ty, rx, ty + 5, 1.5, 255, 255, 255, 230 * hv * k)
	end
end

-- светящийся шов между сторонами и эмблема в центре
function SPLIT:DrawCenter(sx, w, h, now)
	local edge = math.min(self.split, 1 - self.split)
	local vis = math.Clamp(edge / 0.1, 0, 1)

	if (vis <= 0) then
		return
	end

	local b, r = CFG.sides[1].color, CFG.sides[2].color
	local hl, hr = self.hover[1], self.hover[2]

	draw.NoTexture()

	for k = 0, 13 do
		local f = (1 - k / 14) ^ 2

		surface.SetDrawColor(b.r, b.g, b.b, (60 + 60 * hl) * f * vis)
		surface.DrawRect(sx - 3 * (k + 1), 0, 3, h)
		surface.SetDrawColor(r.r, r.g, r.b, (60 + 60 * hr) * f * vis)
		surface.DrawRect(sx + 3 * k, 0, 3, h)
	end

	surface.SetDrawColor(255, 255, 255, 220 * vis)
	surface.DrawRect(sx - 1, 0, 2, h)

	-- световой импульс, бегущий по шву
	local py = ((now * 0.33) % 1) * (h + 240) - 240

	for k = 0, 11 do
		surface.SetDrawColor(255, 255, 255, 120 * math.sin((k + 0.5) / 12 * math.pi) * vis)
		surface.DrawRect(sx - 2, py + k * 20, 4, 20)
	end

	-- эмблема
	local fade = vis

	if (self.pick != 0) then
		fade = fade * (1 - math.Clamp((now - self.pickStart) / 0.35, 0, 1))
	end

	if (fade <= 0) then
		return
	end

	local ey = math.floor(h * 0.5)
	local er = math.floor(h * 0.055)

	SmoothArc(sx, ey, er * 0.5, 0, 360, er, 64, 7, 10, 15, 235 * fade)
	SmoothArc(sx, ey, er, 0, 360, 2, 64, 255, 255, 255, 200 * fade)

	for k = 0, 3 do
		local s = now * 28 + k * 90
		local col = (k % 2 == 0) and b or r

		SmoothArc(sx, ey, er + 9, s, s + 52, 3, 12, col.r, col.g, col.b, 220 * fade)
	end

	for k = 0, 5 do
		local s = -now * 20 + k * 60

		SmoothArc(sx, ey, er + 17, s, s + 14, 1, 6, 255, 255, 255, 110 * fade)
	end

	if (CFG.centerText != "") then
		draw.SimpleText(CFG.centerText, "ixSplitMid", sx, ey, Color(255, 255, 255, 240 * fade), C, C)
	end
end

function SPLIT:DrawHeading(w, h, now)
	local fade = 1

	if (self.pick != 0) then
		fade = 1 - math.Clamp((now - self.pickStart) / 0.35, 0, 1)
	end

	if (fade <= 0) then
		return
	end

	local p = (now - self.shownAt - 0.15) / 0.9
	local cx = math.floor(w * 0.5)
	local y = HeadingY(h)
	local text = TypeText(CFG.heading, p)
	local b, r = CFG.sides[1].color, CFG.sides[2].color

	surface.SetFont("ixSplitMid")

	local tw = surface.GetTextSize(CFG.heading)
	local lineLen = math.floor(w * 0.1)
	local la = math.Clamp(p, 0, 1) * fade

	draw.NoTexture()
	surface.SetDrawColor(b.r, b.g, b.b, 150 * la)
	surface.DrawRect(cx - math.floor(tw * 0.5) - 26 - lineLen, y, lineLen, 2)
	surface.SetDrawColor(r.r, r.g, r.b, 150 * la)
	surface.DrawRect(cx + math.floor(tw * 0.5) + 26, y, lineLen, 2)

	surface.SetDrawColor(255, 255, 255, (120 + 110 * (0.5 + 0.5 * math.sin(now * 3.2))) * la)
	surface.DrawRect(cx - math.floor(tw * 0.5) - 20, y - 3, 7, 7)
	surface.DrawRect(cx + math.floor(tw * 0.5) + 13, y - 3, 7, 7)

	draw.SimpleText(text, "ixSplitMid", cx, y, Color(255, 255, 255, 235 * fade), C, C)
	draw.SimpleText(TypeText(CFG.subHeading, (p - 0.25) / 0.75), "ixSplitSmall", cx, y + 28, Color(255, 255, 255, 130 * fade), C, C)
end

function SPLIT:Paint(w, h)
	local now = RealTime()
	local dt = math.min(RealFrameTime(), 0.05)
	local sx = math.floor(w * self.split)

	surface.SetDrawColor(7, 10, 15, 255)
	surface.DrawRect(0, 0, w, h)

	for i = 1, 2 do
		local x0 = (i == 1) and 0 or sx
		local sw = (i == 1) and sx or (w - sx)

		if (sw > 2) then
			local px, py = self:LocalToScreen(x0, 0)

			render.SetScissorRect(px, py, px + sw, py + h, true)
			self:DrawSideBack(i, x0, sw, w, h, now, dt)
			render.SetScissorRect(0, 0, 0, 0, false)
		end
	end
end

function SPLIT:PaintOver(w, h)
	local now = RealTime()
	local sx = math.floor(w * self.split)

	for i = 1, 2 do
		local x0 = (i == 1) and 0 or sx
		local sw = (i == 1) and sx or (w - sx)

		if (sw > 2) then
			self:DrawSideHUD(i, x0, sw, w, h, now)
		end
	end

	self:DrawCenter(sx, w, h, now)
	self:DrawHeading(w, h, now)

	-- плавный уход в тёмный фон при переходе к следующему этапу
	if (self.fadeOutAt) then
		local fo = math.Clamp((now - self.fadeOutAt) / 0.35, 0, 1)

		draw.NoTexture()
		surface.SetDrawColor(7, 10, 15, 255 * fo)
		surface.DrawRect(0, 0, w, h)
	end

	-- плавное появление из чёрного
	local fa = 1 - math.Clamp((now - self.shownAt) / 0.45, 0, 1)

	if (fa > 0) then
		draw.NoTexture()
		surface.SetDrawColor(0, 0, 0, 255 * fa ^ 1.5)
		surface.DrawRect(0, 0, w, h)
	end
end

vgui.Register("ixCharSideSelect", SPLIT, "EditablePanel")

--[[
	ПАНЕЛЬ СОЗДАНИЯ ПЕРСОНАЖА
]]
DEFINE_BASECLASS("ixCharMenuPanel")
local PANEL = {}

function PANEL:Init()
	local parent = self:GetParent()
	local halfWidth = parent:GetWide() * 0.5 - (padding * 2)
	local halfHeight = parent:GetTall() * 0.5 - (padding * 2)
	local modelFOV = (ScrW() > ScrH() * 1.8) and 100 or 78

	self:ResetPayload(true)

	self.factionButtons = {}
	self.repopulatePanels = {}
	self.currentPage = ""

	-- главное меню (cl_character) под экраном создания не нужно: прячем его, когда открывается создание,
	-- и показываем снова, когда его возвращают (Undim)
	local main = parent.mainPanel

	if (IsValid(main) and !main.ixCreateHooked) then
		local baseUndim = main.OnUndim

		main.ixCreateHooked = true
		main.OnUndim = function(this, ...)
			this:SetVisible(true)

			-- возвращаемся в главное меню — HUD снова нужен
			parent.ixHideHud = false

			if (baseUndim) then
				return baseUndim(this, ...)
			end
		end
	end

	-- HUD и атмосфера cl_character на время создания персонажа
	HookMenuDraw(parent, "DrawForeground", function() return CFG.hideMenuHud end)
	HookMenuDraw(parent, "DrawAtmosphere", function() return CFG.hideMenuAtmosphere end)

	local startColor = CFG.sides[1].color

	self.curAccent = Color(startColor.r, startColor.g, startColor.b)
	self.accentTarget = startColor

	-- faction selection subpanel (разделённый экран)
	self.factionPanel = self:AddSubpanel("faction", true)
	self.factionPanel:SetTitle("chooseFaction")
	self.factionPanel.OnSetActive = function()
		self.currentPage = "faction"

		-- if we only have one faction, we are always selecting that one so we can skip to the description section
		if (#self.factionButtons == 1) then
			self:ShowFactionPage(false)
			self:SetActiveSubpanel("description", 0)

			return
		end

		self:ShowFactionPage(true)
		self:LayoutFaction()
	end

	-- стандартный заголовок здесь не нужен: у экрана свой
	for _, child in ipairs(self.factionPanel:GetChildren()) do
		if (IsValid(child)) then
			child:SetVisible(false)
		end
	end

	-- экран выбора стороны кладём прямо на панель создания, а не в подпанель: у подпанели есть отступ (padding),
	-- из-за которого экран обрезался и не растягивался на весь экран
	self.sideSelect = self:Add("ixCharSideSelect")
	self.sideSelect:SetPos(0, 0)
	self.sideSelect:SetSize(parent:GetWide(), parent:GetTall())
	self.sideSelect.OnSelect = function(this, side, entry)
		self:SelectFaction(entry.faction)
	end
	self.sideSelect.OnProceed = function(this, side)
		self.progress:IncrementProgress()

		self:Populate()
		self:SetActiveSubpanel("description")
		self:ShowFactionPage(false, true)
	end

	local factionBack = self:Add("ixMenuButton")
	factionBack:SetText("return")
	factionBack:SizeToContents()
	factionBack:SetSize(math.floor(math.max(factionBack:GetWide(), ScrW() * 0.12)), factionBack:GetTall())
	factionBack:MoveToFront()
	StyleButton(factionBack, function() return self.curAccent end)
	factionBack.DoClick = function()
		if (self.sideSelect:IsBusy()) then
			return
		end

		self.progress:DecrementProgress()

		self:SetActiveSubpanel("faction", 0)
		self:SlideDown()

		parent.mainPanel:Undim()
	end

	self.factionBack = factionBack

	-- character customization subpanel
	self.description = self:AddSubpanel("description")
	self.description:SetTitle("chooseDescription")
	self.description.OnSetActive = function()
		self.currentPage = "description"
		self:ShowFactionPage(false, true)
	end

	local descriptionModelList = self.description:Add("Panel")
	descriptionModelList:Dock(LEFT)
	descriptionModelList:SetSize(halfWidth, halfHeight)
	self:StyleModelFrame(descriptionModelList)

	local descriptionBack = descriptionModelList:Add("ixMenuButton")
	descriptionBack:SetText("return")
	descriptionBack:SetContentAlignment(4)
	descriptionBack:SizeToContents()
	descriptionBack:Dock(BOTTOM)
	self:StyleNav(descriptionBack, halfWidth, false)
	descriptionModelList.navH = descriptionBack:GetTall()
	descriptionBack.DoClick = function()
		self.progress:DecrementProgress()

		if (#self.factionButtons == 1) then
			factionBack:DoClick()
		else
			self:SetActiveSubpanel("faction")
		end
	end

	self.descriptionModel = descriptionModelList:Add("ixModelPanel")
	self.descriptionModel:Dock(FILL)
	self.descriptionModel:SetModel(CFG.sides[1].model)
	self.descriptionModel:SetFOV(modelFOV - 13)
	self.descriptionModel.PaintModel = self.descriptionModel.Paint

	self.descriptionPanel = self.description:Add("Panel")
	self.descriptionPanel:SetWide(halfWidth + padding * 2)
	self.descriptionPanel:Dock(RIGHT)

	local descriptionProceed = self.descriptionPanel:Add("ixMenuButton")
	descriptionProceed:SetText("proceed")
	descriptionProceed:SetContentAlignment(6)
	descriptionProceed:SizeToContents()
	descriptionProceed:Dock(BOTTOM)
	self:StyleNav(descriptionProceed, halfWidth + padding * 2, true)
	descriptionProceed.DoClick = function()
		if (self:VerifyProgression("description")) then
			-- there are no panels on the attributes section other than the create button, so we can just create the character
			if (#self.attributesPanel:GetChildren() < 2) then
				self:SendPayload()
				return
			end

			self.progress:IncrementProgress()
			self:SetActiveSubpanel("attributes")
		end
	end

	-- attributes subpanel
	self.attributes = self:AddSubpanel("attributes")
	self.attributes:SetTitle("chooseSkills")
	self.attributes.OnSetActive = function()
		self.currentPage = "attributes"
		self:ShowFactionPage(false, true)
	end

	local attributesModelList = self.attributes:Add("Panel")
	attributesModelList:Dock(LEFT)
	attributesModelList:SetSize(halfWidth, halfHeight)
	self:StyleModelFrame(attributesModelList)

	local attributesBack = attributesModelList:Add("ixMenuButton")
	attributesBack:SetText("return")
	attributesBack:SetContentAlignment(4)
	attributesBack:SizeToContents()
	attributesBack:Dock(BOTTOM)
	self:StyleNav(attributesBack, halfWidth, false)
	attributesModelList.navH = attributesBack:GetTall()
	attributesBack.DoClick = function()
		self.progress:DecrementProgress()
		self:SetActiveSubpanel("description")
	end

	self.attributesModel = attributesModelList:Add("ixModelPanel")
	self.attributesModel:Dock(FILL)
	self.attributesModel:SetModel(CFG.sides[1].model)
	self.attributesModel:SetFOV(modelFOV - 13)
	self.attributesModel.PaintModel = self.attributesModel.Paint

	self.attributesPanel = self.attributes:Add("Panel")
	self.attributesPanel:SetWide(halfWidth + padding * 2)
	self.attributesPanel:Dock(RIGHT)

	local create = self.attributesPanel:Add("ixMenuButton")
	create:SetText("finish")
	create:SetContentAlignment(6)
	create:SizeToContents()
	create:Dock(BOTTOM)
	self:StyleNav(create, halfWidth + padding * 2, true)
	create.DoClick = function()
		self:SendPayload()
	end

	-- creation progress panel
	self.progress = self:Add("ixSegmentedProgress")
	self.progress:SetBarColor(self.curAccent)
	self.progress:SetSize(parent:GetWide(), 0)
	self.progress:SizeToContents()
	self.progress:SetPos(0, parent:GetTall() - self.progress:GetTall())

	self:LayoutFaction()

	-- setup payload hooks
	self:AddPayloadHook("model", function(value)
		local faction = ix.faction.indices[self.payload.faction]

		if (faction) then
			local model = faction:GetModels(LocalPlayer())[value]

			-- если у фракции нет такой модели — берём модель стороны
			if (model == nil) then
				model = (self:GetSideData()).model
			end

			-- assuming bodygroups
			if (istable(model)) then
				self.descriptionModel:SetModel(model[1], model[2] or 0, model[3])
				self.attributesModel:SetModel(model[1], model[2] or 0, model[3])
			else
				self.descriptionModel:SetModel(model)
				self.attributesModel:SetModel(model)
			end
		end
	end)

	-- setup character creation hooks
	net.Receive("ixCharacterAuthed", function()
		timer.Remove("ixCharacterCreateTimeout")
		self.awaitingResponse = false

		local id = net.ReadUInt(32)
		local indices = net.ReadUInt(6)
		local charList = {}

		for _ = 1, indices do
			charList[#charList + 1] = net.ReadUInt(32)
		end

		ix.characters = charList

		self:SlideDown()

		if (!IsValid(self) or !IsValid(parent)) then
			return
		end

		if (LocalPlayer():GetCharacter()) then
			parent.mainPanel:Undim()
			parent:ShowNotice(2, L("charCreated"))
		elseif (id) then
			self.bMenuShouldClose = true

			net.Start("ixCharacterChoose")
				net.WriteUInt(id, 32)
			net.SendToServer()
		else
			self:SlideDown()
		end
	end)

	net.Receive("ixCharacterAuthFailed", function()
		timer.Remove("ixCharacterCreateTimeout")
		self.awaitingResponse = false

		local fault = net.ReadString()
		local args = net.ReadTable()

		self:SlideDown()

		parent.mainPanel:Undim()
		parent:ShowNotice(3, L(fault, unpack(args)))
	end)
end

-- кнопка навигации в стиле меню: уменьшаем растянутую докингом кнопку до нормальной ширины
function PANEL:StyleNav(button, containerWidth, bRight)
	local bw = math.floor(math.max(button:GetWide(), ScrW() * 0.13))
	local margin = math.max(containerWidth - bw, 0)

	if (bRight) then
		button:DockMargin(margin, 0, 0, 0)
	else
		button:DockMargin(0, 0, margin, 0)
	end

	StyleButton(button, function() return self.curAccent end)
end

-- декоративная рамка вокруг превью модели
function PANEL:StyleModelFrame(container)
	local owner = self

	container.Paint = function(panel, w, h)
		local c = owner.curAccent
		local now = RealTime()
		local mh = math.max(h - (panel.navH or 0) - 6, 10)
		local breathe = 0.5 + 0.5 * math.sin(now * 1.4)
		local gs = math.min(w, mh) * 1.3

		surface.SetMaterial(glowMat)
		surface.SetDrawColor(c.r, c.g, c.b, 30 + 8 * breathe)
		surface.DrawTexturedRect(w * 0.5 - gs * 0.5, mh * 0.5 - gs * 0.5, gs, gs)
		draw.NoTexture()

		-- кольца на полу
		local fy = mh * 0.88
		local rx = w * 0.3

		SmoothArc(w * 0.5, fy, rx, 0, 360, 2, 80, c.r, c.g, c.b, 110, 0.2)
		SmoothArc(w * 0.5, fy, rx * 0.7, 0, 360, 1, 60, 255, 255, 255, 45, 0.2)

		for k = 0, 3 do
			local s = now * 35 + k * 90

			SmoothArc(w * 0.5, fy, rx * 1.12, s, s + 24, 3, 10, 255, 255, 255, 140, 0.2)
		end

		-- вертикальный луч с затухающим следом
		local sx = ((now * 0.12) % 1) * w

		draw.NoTexture()

		for j = 0, 9 do
			surface.SetDrawColor(c.r, c.g, c.b, 14 * (1 - j / 10))
			surface.DrawRect(sx - j * 4, 0, 4, mh)
		end

		surface.SetDrawColor(c.r, c.g, c.b, 60)
		surface.DrawRect(sx, 0, 1, mh)
	end

	container.PaintOver = function(panel, w, h)
		local c = owner.curAccent
		local mh = math.max(h - (panel.navH or 0) - 6, 10)
		local side, entry = owner:GetSideData()
		local name = Upper(entry and entry.name or side.name)

		draw.NoTexture()
		DrawBrackets(0, 0, w, mh, 24, c.r, c.g, c.b, 200)

		draw.SimpleText(CFG.previewText .. "  //  " .. name, "ixSplitSmall", 14, 12, Color(255, 255, 255, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
end

-- экран выбора стороны живёт не в подпанели, поэтому показываем/прячем его вручную
function PANEL:ShowFactionPage(bShow, bFade)
	local sel, back = self.sideSelect, self.factionBack

	if (!IsValid(sel)) then
		return
	end

	if (bShow) then
		sel:Reset()
		sel:SetVisible(true)

		if (IsValid(back)) then
			back:SetVisible(true)
		end
	else
		if (IsValid(back)) then
			back:SetVisible(false)
		end

		if (bFade) then
			sel:FadeOut()
		else
			sel:SetVisible(false)
		end
	end
end

-- расположение элементов экрана выбора стороны (нужен размер полосы прогресса)
function PANEL:LayoutFaction()
	local parent = self:GetParent()
	local inset = IsValid(self.progress) and self.progress:GetTall() or 0

	if (IsValid(self.sideSelect)) then
		self.sideSelect.inset = inset
	end

	-- кнопка «назад» — в левом верхнем углу (внизу она налезала на плашку выбора стороны)
	if (IsValid(self.factionBack)) then
		self.factionBack:SetPos(40, CFG.hideMenuHud and 40 or 84)
	end
end

-- сторона и запись выбранной фракции
function PANEL:GetSideData()
	local index = self.payload and self.payload.faction

	for _, entry in ipairs(self.factionButtons) do
		if (entry.faction == index) then
			return CFG.sides[entry.side], entry
		end
	end

	return CFG.sides[1]
end

function PANEL:UpdateAccent()
	local side = self:GetSideData()

	self.accentTarget = side.color

	if (IsValid(self.progress)) then
		self.progress:SetBarColor(side.color)
	end
end

function PANEL:SelectFaction(index)
	local faction = ix.faction.indices[index]

	if (!faction) then
		return
	end

	local models = faction:GetModels(LocalPlayer())

	self.lastFaction = index

	self.payload:Set("faction", index)
	self.payload:Set("model", math.random(1, math.max(#models, 1)))

	self:UpdateAccent()
end

function PANEL:SendPayload()
	if (self.awaitingResponse or !self:VerifyProgression()) then
		return
	end

	self.awaitingResponse = true

	timer.Create("ixCharacterCreateTimeout", 10, 1, function()
		if (IsValid(self) and self.awaitingResponse) then
			local parent = self:GetParent()

			self.awaitingResponse = false
			self:SlideDown()

			parent.mainPanel:Undim()
			parent:ShowNotice(3, L("unknownError"))
		end
	end)

	self.payload:Prepare()

	net.Start("ixCharacterCreate")
	net.WriteUInt(table.Count(self.payload), 8)

	for k, v in pairs(self.payload) do
		net.WriteString(k)
		net.WriteType(v)
	end

	net.SendToServer()
end

function PANEL:OnSlideUp()
	-- главное меню исчезает, пока открыто создание персонажа
	local menu = self:GetParent()
	local main = menu.mainPanel

	if (IsValid(main)) then
		main:SetVisible(false)
	end

	menu.ixHideHud = true

	self:ResetPayload()
	self:Populate()
	self.progress:SetProgress(1)
	self.sideSelect:Reset()

	-- the faction subpanel will skip to next subpanel if there is only one faction to choose from,
	-- so we don't have to worry about it here
	self:SetActiveSubpanel("faction", 0)
end

function PANEL:OnSlideDown()
	local menu = self:GetParent()

	if (IsValid(menu)) then
		menu.ixHideHud = false
	end
end

function PANEL:ResetPayload(bWithHooks)
	if (bWithHooks) then
		self.hooks = {}
	end

	self.payload = {}

	-- TODO: eh..
	function self.payload.Set(payload, key, value)
		self:SetPayload(key, value)
	end

	function self.payload.AddHook(payload, key, callback)
		self:AddPayloadHook(key, callback)
	end

	function self.payload.Prepare(payload)
		self.payload.Set = nil
		self.payload.AddHook = nil
		self.payload.Prepare = nil
	end
end

function PANEL:SetPayload(key, value)
	self.payload[key] = value
	self:RunPayloadHook(key, value)
end

function PANEL:AddPayloadHook(key, callback)
	if (!self.hooks[key]) then
		self.hooks[key] = {}
	end

	self.hooks[key][#self.hooks[key] + 1] = callback
end

function PANEL:RunPayloadHook(key, value)
	local hooks = self.hooks[key] or {}

	for _, v in ipairs(hooks) do
		v(value)
	end
end

function PANEL:GetContainerPanel(name)
	-- TODO: yuck
	if (name == "description") then
		return self.descriptionPanel
	elseif (name == "attributes") then
		return self.attributesPanel
	end

	return self.descriptionPanel
end

function PANEL:AttachCleanup(panel)
	self.repopulatePanels[#self.repopulatePanels + 1] = panel
end

-- привязывает стороны к фракциям через глобальные константы (FACTION_FVUR, FACTION_EIR)
function PANEL:BuildFactionEntries()
	local list = {}

	self.factionButtons = {}

	for i, side in ipairs(CFG.sides) do
		local index = side.factionConst and _G[side.factionConst]
		local faction = index and ix.faction.indices[index]

		if (faction and ix.faction.HasWhitelist(faction.index)) then
			list[i] = {faction = faction.index, name = L(faction.name), side = i}
			self.factionButtons[#self.factionButtons + 1] = list[i]
		else
			list[i] = false
		end
	end

	return list
end

function PANEL:Populate()
	-- setup sides for the faction panel
	self.sideSelect:SetSides(self:BuildFactionEntries())

	-- remove panels created for character vars
	for i = 1, #self.repopulatePanels do
		if (IsValid(self.repopulatePanels[i])) then
			self.repopulatePanels[i]:Remove()
		end
	end

	self.repopulatePanels = {}

	-- payload is empty (fresh creation or we attempted to send it) - preselect a faction so the character vars can be built.
	-- the player confirms the real choice on the split screen, after which we populate again
	if (!self.payload.faction and #self.factionButtons > 0) then
		local pick

		for _, entry in ipairs(self.factionButtons) do
			if (entry.faction == self.lastFaction) then
				pick = entry

				break
			end
		end

		if (!pick) then
			for _, entry in ipairs(self.factionButtons) do
				if (ix.faction.indices[entry.faction].isDefault) then
					pick = entry

					break
				end
			end
		end

		pick = pick or self.factionButtons[1]

		self:SelectFaction(pick.faction)
	end

	local zPos = 1

	-- set up character vars
	for k, v in SortedPairsByMemberValue(ix.char.vars, "index") do
		if (!v.bNoDisplay and k != "__SortedIndex") then
			local container = self:GetContainerPanel(v.category or "description")

			if (v.ShouldDisplay and v:ShouldDisplay(container, self.payload) == false) then
				continue
			end

			local panel

			-- if the var has a custom way of displaying, we'll use that instead
			if (v.OnDisplay) then
				panel = v:OnDisplay(container, self.payload)
			elseif (isstring(v.default)) then
				panel = container:Add("ixTextEntry")
				panel:Dock(TOP)
				panel:SetFont("ixMenuButtonHugeFont")
				panel:SetUpdateOnType(true)
				panel.OnValueChange = function(this, text)
					self.payload:Set(k, text)
				end
			end

			if (IsValid(panel)) then
				-- add label for entry
				local label = container:Add("DLabel")
				label:SetFont("ixMenuButtonLabelFont")
				label:SetText(L(k):utf8upper())
				label:SizeToContents()
				label:DockMargin(0, 16, 0, 2)
				label:Dock(TOP)

				-- we need to set the docking order so the label is above the panel
				label:SetZPos(zPos - 1)
				panel:SetZPos(zPos)

				self:AttachCleanup(label)
				self:AttachCleanup(panel)

				if (v.OnPostSetup) then
					v:OnPostSetup(panel, self.payload)
				end

				zPos = zPos + 2
			end
		end
	end

	if (!self.bInitialPopulate) then
		-- setup progress bar segments
		if (#self.factionButtons > 1) then
			self.progress:AddSegment("@faction")
		end

		self.progress:AddSegment("@description")

		if (#self.attributesPanel:GetChildren() > 1) then
			self.progress:AddSegment("@skills")
		end

		-- we don't need to show the progress bar if there's only one segment
		if (#self.progress:GetSegments() == 1) then
			self.progress:SetVisible(false)
		end

		self:LayoutFaction()
	end

	self.bInitialPopulate = true
end

function PANEL:VerifyProgression(name)
	for k, v in SortedPairsByMemberValue(ix.char.vars, "index") do
		if (name ~= nil and (v.category or "description") != name) then
			continue
		end

		local value = self.payload[k]

		if (!v.bNoDisplay or v.OnValidate) then
			if (v.OnValidate) then
				local result = {v:OnValidate(value, self.payload, LocalPlayer())}

				if (result[1] == false) then
					self:GetParent():ShowNotice(3, L(unpack(result, 2)))
					return false
				end
			end

			self.payload[k] = value
		end
	end

	return true
end

function PANEL:Paint(width, height)
	-- плавная смена акцентного цвета под выбранную сторону
	local t, c = self.accentTarget, self.curAccent
	local k = math.min(RealFrameTime() * 6, 1)

	c.r = Lerp(k, c.r, t.r)
	c.g = Lerp(k, c.g, t.g)
	c.b = Lerp(k, c.b, t.b)

	surface.SetDrawColor(7, 10, 15, 255)
	surface.DrawRect(0, 0, width, height)

	-- свечение под моделью
	local hw = width * 0.5 - padding * 2
	local gs = height * 1.5

	surface.SetMaterial(glowMat)
	surface.SetDrawColor(c.r, c.g, c.b, 22)
	surface.DrawTexturedRect(padding + hw * 0.5 - gs * 0.5, height * 0.5 - gs * 0.5, gs, gs)
	draw.NoTexture()

	-- тактическая сетка
	local step = math.max(math.floor(height / 12), 48)

	for gx = 0, width, step do
		local major = (gx / step) % 4 == 0

		surface.SetDrawColor(c.r, c.g, c.b, (major and 6 or 2.5) * CFG.gridAlpha)
		surface.DrawRect(gx, 0, 1, height)
	end

	for gy = 0, height, step do
		local major = (gy / step) % 4 == 0

		surface.SetDrawColor(c.r, c.g, c.b, (major and 6 or 2.5) * CFG.gridAlpha)
		surface.DrawRect(0, gy, width, 1)
	end

	-- угловые скобки и верхняя линия
	local m, l = 28, 42

	surface.SetDrawColor(c.r, c.g, c.b, 200)
	surface.DrawRect(m, m, l, 2)
	surface.DrawRect(m, m, 2, l)
	surface.DrawRect(width - m - l, m, l, 2)
	surface.DrawRect(width - m - 2, m, 2, l)
	surface.DrawRect(m, height - m - 2, l, 2)
	surface.DrawRect(m, height - m - l, 2, l)
	surface.DrawRect(width - m - l, height - m - 2, l, 2)
	surface.DrawRect(width - m - 2, height - m - l, 2, l)

	surface.SetDrawColor(c.r, c.g, c.b, 60)
	surface.DrawRect(m + l + 8, m, width - (m + l + 8) * 2, 1)

	BaseClass.Paint(self, width, height)
end

function PANEL:PaintOver(width, height)
	if (self.currentPage != "description" and self.currentPage != "attributes") then
		return
	end

	local side, entry = self:GetSideData()
	local c = self.curAccent
	local text = CFG.sideLabel .. "  //  " .. Upper(entry and entry.name or side.name)
	local m = 28
	local now = RealTime()

	surface.SetFont("ixSplitSmall")

	local tw = surface.GetTextSize(text)
	local x = width - m - 12 - tw
	local logo = GetLogo(side)

	if (logo) then
		local lh = 34
		local lw = lh * logo:Width() / math.max(logo:Height(), 1)

		DrawLogo(logo, x - 34 - lw * 0.5, m + 18, lh, c, 230)
	end

	draw.NoTexture()
	surface.SetDrawColor(255, 255, 255, 120 + 110 * (0.5 + 0.5 * math.sin(now * 3.2)))
	surface.DrawRect(x - 16, m + 14, 7, 7)
	surface.SetDrawColor(c.r, c.g, c.b, 90)
	surface.DrawRect(x - 16, m + 34, tw + 16, 1)

	draw.SimpleText(text, "ixSplitSmall", x, m + 8, Color(255, 255, 255, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

vgui.Register("ixCharMenuNew", PANEL, "ixCharMenuPanel")