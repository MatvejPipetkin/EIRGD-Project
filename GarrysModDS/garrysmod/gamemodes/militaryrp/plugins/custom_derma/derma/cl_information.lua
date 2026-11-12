-- общий стиль меню (тот же, что в cl_menu.lua / cl_inventory.lua)
ix.menuStyle = ix.menuStyle or {accent = Color(90, 160, 235), projectName = "EIRGD"}

--[[
	НАСТРОЙКИ
	Окно личного дела почти на весь экран, в стиле cl_inventory:
	тёмная панель с размытием, акцентная шапка, карточки как ячейки инвентаря.
]]
local CFG = {
	windowWidth = 0.94, -- ширина окна в долях экрана
	windowHeight = 0.84, -- высота окна в долях экрана
	leftWidth = 430, -- ширина карточки профиля при высоте экрана 1080 (масштабируется)
	attrMinWidth = 380, -- минимальная ширина карточки характеристики при высоте 1080
	attrMinHeight = 96, -- минимальная высота карточки характеристики
	attrMaxHeight = 150, -- максимальная высота (карточки растягиваются, чтобы занять место)
	gap = 16, -- общий отступ между блоками
	profileBottom = 130, -- отступ нижних строк профиля (фракция/класс/средства) от низа карточки; больше = выше
	blur = true, -- размытие фона за окном
	characterOverview = false, -- показывать персонажа слева (окно закрывает почти весь экран, поэтому выключено)
	sounds = true,
	soundVolume = 0.4,
	revealStep = 0.035, -- задержка появления между элементами

	soundSet = {
		hover = {"buttons/blip1.wav", 0.25, 115},
		click = {"buttons/button15.wav", 0.45, 100},
		reveal = {"buttons/combine_button3.wav", 0.2, 110}
	}
}

local glowMat = Material("sprites/light_glow02_add")

local COL_GOOD = Color(110, 210, 130)
local COL_BAD = Color(225, 85, 80)
local CHAR_PATTERN = "[\1-\127\194-\253][\128-\191]*"

local function S(value)
	return math.floor(value * ScrH() / 1080 + 0.5)
end

local function CreateInfoFonts()
	surface.CreateFont("ixInfoTitle", {font = "Roboto", size = S(22), weight = 600, extended = true, antialias = true})
	surface.CreateFont("ixInfoName", {font = "Roboto", size = S(40), weight = 600, extended = true, antialias = true})
	surface.CreateFont("ixInfoValue", {font = "Roboto", size = S(25), weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixInfoMid", {font = "Roboto", size = S(21), weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixInfoText", {font = "Roboto", size = S(19), weight = 400, extended = true, antialias = true})
	surface.CreateFont("ixInfoSmall", {font = "Roboto", size = S(16), weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixInfoTiny", {font = "Roboto", size = S(13), weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixInfoMono", {font = "Roboto", size = S(14), weight = 400, extended = true, antialias = true})
end

CreateInfoFonts()
hook.Add("OnScreenSizeChanged", "ixCharInfoFonts", CreateInfoFonts)

local function EaseOutCubic(x)
	return 1 - (1 - x) ^ 3
end

local function GetAccent()
	return ix.menuStyle.accent or ix.config.Get("color") or Color(90, 160, 235)
end

local function Upper(text)
	return (string.utf8upper or string.upper)(text)
end

local function ReadableColor(c)
	local accent = GetAccent()

	if (!c) then
		return accent.r, accent.g, accent.b
	end

	local lum = c.r * 0.3 + c.g * 0.59 + c.b * 0.11

	if (lum < 45) then
		return accent.r, accent.g, accent.b
	end

	return c.r, c.g, c.b
end

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

local function SplitChars(text)
	local chars = {}

	for ch in string.gmatch(text or "", CHAR_PATTERN) do
		chars[#chars + 1] = ch
	end

	return chars
end

-- подбирает шрифт из списка, а если не влезает совсем — обрезает с многоточием
local function FitText(text, fonts, maxW)
	for _, f in ipairs(fonts) do
		surface.SetFont(f)

		if (surface.GetTextSize(text) <= maxW) then
			return text, f
		end
	end

	local f = fonts[#fonts]

	surface.SetFont(f)

	local chars = SplitChars(text)
	local count = #chars

	while (count > 1) do
		count = count - 1

		local candidate = table.concat(chars, "", 1, count) .. "…"

		if (surface.GetTextSize(candidate) <= maxW) then
			return candidate, f
		end
	end

	return chars[1] and (chars[1] .. "…") or text, f
end

local function BreakWord(word, maxW)
	local parts, cur = {}, ""

	for _, ch in ipairs(SplitChars(word)) do
		if (cur != "" and surface.GetTextSize(cur .. ch) > maxW) then
			parts[#parts + 1] = cur
			cur = ch
		else
			cur = cur .. ch
		end
	end

	if (cur != "") then
		parts[#parts + 1] = cur
	end

	return parts
end

local function WrapText(text, font, maxW)
	surface.SetFont(font)

	local lines = {}

	text = string.Replace(text or "", "\r", "")

	for paragraph in string.gmatch(text .. "\n", "(.-)\n") do
		local line = ""

		for word in string.gmatch(paragraph, "%S+") do
			if (surface.GetTextSize(word) > maxW) then
				if (line != "") then
					lines[#lines + 1] = line
					line = ""
				end

				local parts = BreakWord(word, maxW)

				if (#parts > 0) then
					for i = 1, #parts - 1 do
						lines[#lines + 1] = parts[i]
					end

					line = parts[#parts]
				else
					line = word
				end
			else
				local test = line == "" and word or (line .. " " .. word)

				if (line != "" and surface.GetTextSize(test) > maxW) then
					lines[#lines + 1] = line
					line = word
				else
					line = test
				end
			end
		end

		lines[#lines + 1] = line
	end

	return lines
end

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

-- сглаженная дуга (кольцо) с мягкими краями
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

local function DrawFade(x, y, w, h, r, g, b, a, fromLeft)
	local n = 24
	local sw = math.ceil(w / n)

	draw.NoTexture()

	for i = 0, n - 1 do
		local f = fromLeft and (1 - i / n) or (i / n)

		surface.SetDrawColor(r, g, b, a * f * f)
		surface.DrawRect(x + i * sw, y, sw + 1, h)
	end
end

-- яркие уголки как в cl_inventory
local function DrawCorners(w, h, len, r, g, b, a)
	surface.SetDrawColor(r, g, b, a)
	surface.DrawRect(0, 0, len, 1)
	surface.DrawRect(0, 0, 1, len)
	surface.DrawRect(w - len, 0, len, 1)
	surface.DrawRect(w - 1, 0, 1, len)
	surface.DrawRect(0, h - 1, len, 1)
	surface.DrawRect(0, h - len, 1, len)
	surface.DrawRect(w - len, h - 1, len, 1)
	surface.DrawRect(w - 1, h - len, 1, len)
end

-- плавное наведение (0..1)
local function Hover(pnl, speed)
	pnl.hoverFrac = Lerp(math.min(RealFrameTime() * (speed or 10), 1), pnl.hoverFrac or 0, pnl:IsHovered() and 1 or 0)

	return pnl.hoverFrac
end

-- карточка как ячейка инвентаря: тёмная основа, заливка, рамка (при наведении — акцентная)
local function DrawCard(w, h, hov, ar, ag, ab)
	draw.NoTexture()
	surface.SetDrawColor(0, 0, 0, 110)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(22, 27, 34, 170 + 40 * hov)
	surface.DrawRect(1, 1, w - 2, h - 2)
	surface.SetDrawColor(Lerp(hov, 255, ar), Lerp(hov, 255, ag), Lerp(hov, 255, ab), 16 + 184 * hov)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
end

-- ============================================================
-- Скролл с тонкой полосой и плавной прокруткой колесом
-- ============================================================
local scrollBase = baseclass.Get("DScrollPanel")
local PANEL = {}

function PANEL:Init()
	local bar = self:GetVBar()

	bar:SetWide(S(4))
	bar:SetHideButtons(true)

	bar.Paint = function(this, w, h)
		draw.NoTexture()
		surface.SetDrawColor(255, 255, 255, 8)
		surface.DrawRect(0, 0, w, h)
	end

	bar.btnGrip.Paint = function(this, w, h)
		local accent = GetAccent()

		draw.NoTexture()
		surface.SetDrawColor(accent.r, accent.g, accent.b, this.Depressed and 230 or 140)
		surface.DrawRect(0, 0, w, h)
	end
end

function PANEL:PerformLayout(w, h)
	if (scrollBase.PerformLayout) then
		scrollBase.PerformLayout(self, w, h)
	end

	if (self.onLayout and self.lastLayoutH != h) then
		self.lastLayoutH = h
		self.onLayout(self)
	end
end

function PANEL:OnMouseWheeled(delta)
	local bar = self:GetVBar()
	local maxScroll = math.max(self:GetCanvas():GetTall() - self:GetTall(), 0)

	self.targetScroll = math.Clamp((self.targetScroll or bar:GetScroll()) - delta * S(90), 0, maxScroll)

	return true
end

function PANEL:Think()
	if (!self.targetScroll) then
		return
	end

	local bar = self:GetVBar()
	local cur = bar:GetScroll()
	local new = Lerp(math.min(RealFrameTime() * 12, 1), cur, self.targetScroll)

	if (math.abs(new - self.targetScroll) < 0.5) then
		new = self.targetScroll
		self.targetScroll = nil
	end

	bar:SetScroll(new)
end

vgui.Register("ixInfoScroll", PANEL, "DScrollPanel")

-- ============================================================
-- Заголовок раздела: маркер, текст, линия, текст справа
-- ============================================================
PANEL = {}

function PANEL:Init()
	self:SetTall(S(26))

	self.text = ""
	self.rightText = ""
end

function PANEL:SetText(text)
	self.text = text or ""
end

function PANEL:SetRightText(text)
	self.rightText = text or ""
end

function PANEL:SizeToContents()
end

function PANEL:Paint(w, h)
	local accent = GetAccent()
	local mid = math.floor(h * 0.5)

	draw.NoTexture()
	surface.SetDrawColor(accent.r, accent.g, accent.b, 230)
	surface.DrawRect(0, mid - S(6), 2, S(12))

	surface.SetFont("ixInfoSmall")

	local tw = surface.GetTextSize(self.text)

	draw.SimpleText(self.text, "ixInfoSmall", S(10), mid, Color(255, 255, 255, 190), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local rw = 0

	if (self.rightText != "") then
		surface.SetFont("ixInfoMono")
		rw = surface.GetTextSize(self.rightText) + S(10)

		draw.SimpleText(self.rightText, "ixInfoMono", w, mid, Color(accent.r, accent.g, accent.b, 220), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	local x0 = S(10) + tw + S(12)
	local x1 = w - rw

	if (x1 > x0) then
		draw.NoTexture()
		surface.SetDrawColor(255, 255, 255, 18)
		surface.DrawRect(x0, mid, x1 - x0, 1)
	end
end

vgui.Register("ixInfoSection", PANEL, "Panel")

-- ============================================================
-- Шапка окна (текст; фон и линия рисуются в корневой панели)
-- ============================================================
PANEL = {}

function PANEL:Init()
	self:SetTall(S(52))

	self.text = ""
	self.nextTime = 0
	self:Refresh()
end

function PANEL:Refresh()
	local format = ix.option.Get("24hourTime", false) and "%A, %B %d, %Y. %H:%M" or "%A, %B %d, %Y. %I:%M %p"

	self.text = ix.date.GetFormatted(format)
end

function PANEL:SizeToContents()
end

function PANEL:Think()
	if (self.nextTime < CurTime()) then
		self:Refresh()
		self.nextTime = CurTime() + 0.5
	end
end

function PANEL:Paint(w, h)
	local cy = math.floor(h * 0.5)

	draw.SimpleText("ЛИЧНОЕ ДЕЛО", "ixInfoTitle", S(24), cy, Color(255, 255, 255, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(self.text, "ixInfoSmall", w - S(20), cy, Color(255, 255, 255, 130), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

vgui.Register("ixInfoHeader", PANEL, "Panel")

-- ============================================================
-- Карточка профиля (левая колонка): фон с оттенком цвета фракции
-- ============================================================
PANEL = {}

function PANEL:Init()
	self.color = nil

	self:DockPadding(S(20), S(8), S(20), S(12))
end

function PANEL:Paint(w, h)
	local r, g, b = ReadableColor(self.color)

	draw.NoTexture()
	surface.SetDrawColor(0, 0, 0, 110)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(22, 27, 34, 190)
	surface.DrawRect(1, 1, w - 2, h - 2)

	-- вертикальный оттенок фракции сверху
	local n = 24
	local sh = math.ceil(h * 0.55 / n)

	for i = 0, n - 1 do
		surface.SetDrawColor(r, g, b, 34 * (1 - i / n) ^ 2)
		surface.DrawRect(1, 1 + i * sh, w - 2, sh)
	end

	surface.SetDrawColor(r, g, b, 255)
	surface.DrawRect(0, 0, w, 2)

	surface.SetDrawColor(255, 255, 255, 16)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
end

vgui.Register("ixInfoProfile", PANEL, "Panel")

-- ============================================================
-- Эмблема, имя и номер дела (занимает всё свободное место карточки профиля)
-- ============================================================
PANEL = {}

function PANEL:Init()
	self.text = ""
	self.idText = ""
	self.initial = ""
	self.backgroundColor = Color(0, 0, 0, 150)
end

function PANEL:SetText(text)
	self.text = text or ""
end

function PANEL:SetData(idText, initial)
	self.idText = idText or ""
	self.initial = initial or ""
end

function PANEL:SizeToContents()
end

function PANEL:Paint(w, h)
	local fr, fg, fb = ReadableColor(self.backgroundColor)
	local R = math.Clamp(math.floor(math.min(w, h) * 0.2), S(26), S(62))
	local nameText, nameFont = FitText(self.text, {"ixInfoName", "ixInfoValue", "ixInfoMid"}, w)

	surface.SetFont(nameFont)

	local _, nh = surface.GetTextSize(nameText)
	local blockH = R * 2 + S(20) + nh + S(8) + S(14)
	local cx = math.floor(w * 0.5)
	local cy = math.floor((h - blockH) * 0.5) + R

	-- мягкое свечение под эмблемой
	surface.SetMaterial(glowMat)
	surface.SetDrawColor(fr, fg, fb, 40)
	surface.DrawTexturedRect(cx - R * 2.2, cy - R * 2.2, R * 4.4, R * 4.4)
	draw.NoTexture()

	SmoothArc(cx, cy, R, 0, 360, 2, 64, fr, fg, fb, 220)
	SmoothArc(cx, cy, R - S(8), 0, 360, 1, 56, 255, 255, 255, 28)

	draw.SimpleText(self.initial, "ixInfoName", cx, cy, Color(255, 255, 255, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local ny = cy + R + S(20)

	draw.SimpleText(nameText, nameFont, cx, ny, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	draw.SimpleText(self.idText, "ixInfoMono", cx, ny + nh + S(8), Color(255, 255, 255, 115), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end

vgui.Register("ixInfoPlate", PANEL, "Panel")

-- ============================================================
-- Строка таблицы данных (подпись над значением), используется в профиле
-- ============================================================
PANEL = {}

function PANEL:Init()
	self:SetTall(S(62))
	self:SetMouseInputEnabled(true)

	self.label = ""
	self.text = ""
	self.stripe = nil
	self.hoverFrac = 0
end

function PANEL:SetLabelText(text)
	self.label = text or ""
end

function PANEL:SetText(text)
	self.text = tostring(text or "")
end

function PANEL:SetStripe(color)
	self.stripe = color
end

function PANEL:SetList()
end

function PANEL:SizeToContents()
end

function PANEL:OnCursorEntered()
	PlayUI("hover", 1.15, 0.45)
end

function PANEL:Paint(w, h)
	local hov = Hover(self)

	draw.NoTexture()
	surface.SetDrawColor(255, 255, 255, 6 * hov)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(255, 255, 255, 16)
	surface.DrawRect(0, 0, w, 1)

	draw.SimpleText(self.label, "ixInfoTiny", 0, math.floor(h * 0.31), Color(255, 255, 255, 115), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local fitText, font = FitText(self.text, {"ixInfoValue", "ixInfoMid", "ixInfoSmall"}, w)
	local c = self.stripe and Color(ReadableColor(self.stripe)) or color_white

	draw.SimpleText(fitText, font, 0, math.floor(h * 0.68), Color(c.r, c.g, c.b, 235 + 20 * hov), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

vgui.Register("ixInfoTile", PANEL, "Panel")

-- ============================================================
-- Описание внешности (клик — изменить)
-- ============================================================
PANEL = {}

function PANEL:Init()
	self.rawText = ""
	self.lines = {}
	self.hoverFrac = 0
	self.maxW = S(600)
	self.wrapW = -1
	self.headerH = S(32)
	self.pad = S(20)

	self:SetMouseInputEnabled(true)
	self:SetCursor("hand")
	self:SetTall(self.headerH + S(52))
end

function PANEL:SetText(text)
	self.rawText = text or ""
end

function PANEL:SizeToContents()
	local w = self:GetWide()

	if (w <= 0) then
		w = self.maxW or 0
	end

	if (w <= 0) then
		return
	end

	self.wrapW = w

	local text = self.rawText

	self.bEmpty = string.Trim(text) == ""

	if (self.bEmpty) then
		text = "ОПИСАНИЕ НЕ ЗАДАНО. НАЖМИТЕ, ЧТОБЫ ДОБАВИТЬ."
	end

	self.lines = WrapText(text, "ixInfoText", w - self.pad * 2)

	surface.SetFont("ixInfoText")

	local _, th = surface.GetTextSize("A")

	self.lineH = th + S(4)
	self:SetTall(self.headerH + S(10) + #self.lines * self.lineH + S(16))
end

function PANEL:PerformLayout(w, h)
	if (w > 0 and w != self.wrapW) then
		self.maxW = w
		self:SizeToContents()
	end
end

function PANEL:OnCursorEntered()
	PlayUI("hover", 1.05, 0.7)
end

function PANEL:OnMousePressed(code)
	if (code == MOUSE_LEFT) then
		PlayUI("click")
		ix.command.Send("CharDesc")

		if (IsValid(ix.gui.menu)) then
			ix.gui.menu:Remove()
		end
	end
end

function PANEL:Paint(w, h)
	local accent = GetAccent()
	local ar, ag, ab = accent.r, accent.g, accent.b
	local pad = self.pad
	local hov = Hover(self)

	DrawCard(w, h, hov, ar, ag, ab)

	surface.SetDrawColor(ar, ag, ab, 110 + 145 * hov)
	surface.DrawRect(0, 0, S(2), h)

	local hy = math.floor(self.headerH * 0.5) + S(2)

	draw.SimpleText("ВНЕШНИЕ ДАННЫЕ", "ixInfoTiny", pad, hy, Color(255, 255, 255, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText("ЛКМ — ИЗМЕНИТЬ", "ixInfoTiny", w - pad, hy, Color(ar, ag, ab, 230 * hov), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	local col = self.bEmpty and Color(255, 255, 255, 90) or Color(255, 255, 255, 225)
	local lh = self.lineH or S(23)

	for i, line in ipairs(self.lines) do
		if (line != "") then
			draw.SimpleText(line, "ixInfoText", pad, self.headerH + S(10) + (i - 1) * lh, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
	end
end

vgui.Register("ixInfoDescription", PANEL, "Panel")

-- ============================================================
-- Сетка карточек: колонки по ширине, высота строк растягивается под доступное место
-- ============================================================
PANEL = {}

function PANEL:Init()
	self.minCellW = S(380)
	self.gap = S(12)
	self.rowH = S(96)
	self.minRowH = S(96)
	self.maxRowH = S(150)
	self.viewport = nil
end

function PANEL:GetVisibleTiles()
	local list = {}

	for _, v in ipairs(self:GetChildren()) do
		if (IsValid(v) and v:IsVisible()) then
			list[#list + 1] = v
		end
	end

	return list
end

function PANEL:SizeToContents()
	self:InvalidateLayout(true)
end

function PANEL:PerformLayout(w, h)
	local tiles = self:GetVisibleTiles()
	local cols = math.max(math.floor((w + self.gap) / (self.minCellW + self.gap)), 1)

	cols = math.max(math.min(cols, #tiles), 1)

	local rows = math.max(math.ceil(#tiles / cols), 1)
	local rowH = self.rowH

	if (IsValid(self.viewport) and self.viewport:GetTall() > 0) then
		rowH = math.Clamp(math.floor((self.viewport:GetTall() - self.gap * (rows - 1)) / rows), self.minRowH, self.maxRowH)
	end

	local cw = math.floor((w - self.gap * (cols - 1)) / cols)

	for i, v in ipairs(tiles) do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)

		v:SetPos(col * (cw + self.gap), row * (rowH + self.gap))
		v:SetSize(cw, rowH)
	end

	local need = rows * rowH + (rows - 1) * self.gap

	if (self:GetTall() != need) then
		self:SetTall(need)
	end
end

vgui.Register("ixInfoGrid", PANEL, "Panel")

-- ============================================================
-- Карточка характеристики
-- ============================================================
PANEL = {}

function PANEL:Init()
	self:SetTall(S(96))
	self:SetMouseInputEnabled(true)

	self.label = ""
	self.value = 0
	self.boost = 0
	self.max = 100
	self.hoverFrac = 0
	self.animStart = RealTime()
	self.delay = 0
	self.curLo = 0
	self.curHi = 0
end

function PANEL:SetData(label, value, boost, maximum)
	self.label = label or ""
	self.value = value or 0
	self.boost = boost or 0
	self.max = math.max(maximum or 100, 0.0001)
end

function PANEL:Replay(delay)
	self.animStart = RealTime()
	self.delay = delay or 0
	self.curLo = 0
	self.curHi = 0
end

function PANEL:SizeToContents()
end

function PANEL:OnCursorEntered()
	PlayUI("hover", 1.2, 0.35)
end

function PANEL:Paint(w, h)
	local accent = GetAccent()
	local ar, ag, ab = accent.r, accent.g, accent.b
	local pad = S(18)
	local hov = Hover(self)
	local t = EaseOutCubic(math.Clamp((RealTime() - self.animStart - self.delay) / 0.8, 0, 1))

	DrawCard(w, h, hov, ar, ag, ab)

	surface.SetDrawColor(ar, ag, ab, 255 * hov)
	surface.DrawRect(0, 0, S(2), h)

	local bx, bw = pad, w - pad * 2
	local bh = S(6)
	local by = h - bh - S(16)

	local value, boost = self.value, self.boost
	local base = value - boost
	local lo, hi = math.min(value, base), math.max(value, base)
	local k = math.min(RealFrameTime() * 10, 1)

	self.curLo = Lerp(k, self.curLo or 0, math.Clamp(lo / self.max, 0, 1) * t)
	self.curHi = Lerp(k, self.curHi or 0, math.Clamp(hi / self.max, 0, 1) * t)

	local loF, hiF = self.curLo, self.curHi

	-- полоска
	surface.SetDrawColor(255, 255, 255, 16)
	surface.DrawRect(bx, by, bw, bh)

	surface.SetDrawColor(ar, ag, ab, 235)
	surface.DrawRect(bx, by, math.floor(bw * loF), bh)

	if (boost != 0 and hiF > loF) then
		local c = boost > 0 and COL_GOOD or COL_BAD

		surface.SetDrawColor(c.r, c.g, c.b, 235)
		surface.DrawRect(bx + math.floor(bw * loF), by, math.ceil(bw * (hiF - loF)), bh)
	end

	-- верхняя строка: название и процент
	local topY = S(24)
	local pct = string.format("%d%%", math.floor(value / self.max * 100 + 0.5))

	surface.SetFont("ixInfoMid")

	local pw = surface.GetTextSize(pct)
	local label = FitText(Upper(self.label), {"ixInfoSmall"}, w - pad * 2 - pw - S(16))

	draw.SimpleText(label, "ixInfoSmall", pad, topY, Color(255, 255, 255, 190), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(pct, "ixInfoMid", w - pad, topY, Color(255, 255, 255, 235), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	-- значение крупно между строкой названия и полоской
	local space = by - S(44)
	local vfont = space >= S(46) and "ixInfoName" or "ixInfoValue"
	local vy = S(44) + math.floor(space * 0.5)
	local vtext = string.format("%.1f", value)

	surface.SetFont(vfont)

	local vw = surface.GetTextSize(vtext)

	draw.SimpleText(vtext, vfont, pad, vy, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(string.format("/ %.1f", self.max), "ixInfoMono", pad + vw + S(8), vy + S(4), Color(255, 255, 255, 110), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	if (boost != 0) then
		local c = boost > 0 and COL_GOOD or COL_BAD

		draw.SimpleText(string.format("%s%.1f", boost > 0 and "+" or "", boost), "ixInfoMid", w - pad, vy, Color(c.r, c.g, c.b, 240), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("ixInfoAttribute", PANEL, "Panel")

-- строки, которые добавляют плагины через CreateCharacterInfo
local function StyleRow(row, index)
	row.Paint = function(this, w, h)
		local accent = GetAccent()

		draw.NoTexture()
		surface.SetDrawColor(255, 255, 255, 6)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(accent.r, accent.g, accent.b, 120)
		surface.DrawRect(0, 0, S(2), h)
		surface.SetDrawColor(255, 255, 255, 14)
		surface.DrawRect(0, h - 1, w, 1)
	end
end

-- ============================================================
-- Основная панель
-- ============================================================
PANEL = {}

local function StackHeight(this)
	local height = 0

	for _, v in ipairs(this:GetChildren()) do
		if (IsValid(v) and v:IsVisible()) then
			local _, top, _, bottom = v:GetDockMargin()
			height = height + v:GetTall() + top + bottom
		end
	end

	this:SetTall(height)
end

function PANEL:Init()
	local gap = S(CFG.gap)
	local pad = S(20)

	self:SetSize(math.floor(ScrW() * CFG.windowWidth), math.floor(ScrH() * CFG.windowHeight))
	self:Recenter()

	self.revealList = {}
	self.rowCounter = 0

	local function Reg(pnl)
		self.revealList[#self.revealList + 1] = pnl

		return pnl
	end

	local suppress = {}
	hook.Run("CanCreateCharacterInfo", suppress)

	-- шапка
	self.header = Reg(self:Add("ixInfoHeader"))
	self.header:Dock(TOP)

	-- тело: слева карточка профиля, справа описание и характеристики
	self.body = self:Add("Panel")
	self.body:Dock(FILL)
	self.body:DockPadding(pad, pad, pad, pad)

	self.profile = Reg(self.body:Add("ixInfoProfile"))
	self.profile:Dock(LEFT)
	self.profile:SetWide(S(CFG.leftWidth))
	self.profile:DockMargin(0, 0, pad, 0)
	self.profile:DockPadding(S(20), S(8), S(20), S(CFG.profileBottom))

	self.right = self.body:Add("Panel")
	self.right:Dock(FILL)

	-- нижняя часть профиля: строки докаются снизу вверх (первая добавленная — самая нижняя)
	if (!suppress.characterInfo) then
		if (!suppress.money) then
			self.money = self.profile:Add("ixInfoTile")
			self.money:Dock(BOTTOM)
		end

		if (!suppress.class) then
			self.class = self.profile:Add("ixInfoTile")
			self.class:Dock(BOTTOM)
		end

		if (!suppress.faction) then
			self.faction = self.profile:Add("ixInfoTile")
			self.faction:Dock(BOTTOM)
		end

		self.characterInfo = self.profile:Add("Panel")
		self.characterInfo.list = {}
		self.characterInfo:Dock(BOTTOM)
		self.characterInfo:DockMargin(0, 0, 0, S(8))
		self.characterInfo.SizeToContents = StackHeight

		self.extraHeader = self.profile:Add("ixInfoSection")
		self.extraHeader:SetText("ДОПОЛНИТЕЛЬНО")
		self.extraHeader:Dock(BOTTOM)
		self.extraHeader:DockMargin(0, 0, 0, S(8))

		hook.Run("CreateCharacterInfo", self.characterInfo)
		self:RefreshExtra()
	end

	-- эмблема, имя и номер дела занимают всё оставшееся место
	if (!suppress.name) then
		self.name = self.profile:Add("ixInfoPlate")
		self.name:Dock(FILL)
	end

	if (!suppress.description) then
		self.description = Reg(self.right:Add("ixInfoDescription"))
		self.description:Dock(TOP)
		self.description:DockMargin(0, 0, 0, gap)
	end

	if (!suppress.attributes) then
		local character = LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()
		local list = ix.attributes and ix.attributes.list

		if (character and list and table.Count(list) > 0) then
			self.attrHeader = Reg(self.right:Add("ixInfoSection"))
			self.attrHeader:SetText("ХАРАКТЕРИСТИКИ")
			self.attrHeader:Dock(TOP)
			self.attrHeader:DockMargin(0, 0, 0, S(10))

			self.attrScroll = self.right:Add("ixInfoScroll")
			self.attrScroll:Dock(FILL)

			self.attributes = self.attrScroll:Add("ixInfoGrid")
			self.attributes.viewport = self.attrScroll
			self.attributes.minCellW = S(CFG.attrMinWidth)
			self.attributes.minRowH = S(CFG.attrMinHeight)
			self.attributes.maxRowH = S(CFG.attrMaxHeight)
			self.attributes.gap = S(12)
			self.attributes.bars = {}
			self.attributes:Dock(TOP)

			local grid = self.attributes

			self.attrScroll.onLayout = function()
				if (IsValid(grid)) then
					grid:InvalidateLayout()
				end
			end

			for k, v in SortedPairsByMemberValue(list, "name") do
				local bar = Reg(self.attributes:Add("ixInfoAttribute"))
				bar.attributeID = k

				if (isstring(v.description) and v.description != "") then
					bar:SetTooltip(L2(v.description) or v.description)
				end

				self.attributes.bars[#self.attributes.bars + 1] = bar
			end

			self.attributes:SizeToContents()
			self:UpdateAttributes(character)
		end
	end

	hook.Run("CreateCharacterInfoCategory", self.right)
end

function PANEL:GetCanvas()
	return self.right
end

function PANEL:Recenter()
	local parent = self:GetParent()

	if (!IsValid(parent)) then
		return
	end

	local px, py = parent:LocalToScreen(0, 0)

	if (self.lastPX == px and self.lastPY == py) then
		return
	end

	self.lastPX, self.lastPY = px, py

	self:SetPos(math.floor((ScrW() - self:GetWide()) * 0.5 - px), math.floor((ScrH() - self:GetTall()) * 0.5 - py))
end

function PANEL:RefreshExtra()
	local info = self.characterInfo

	if (!IsValid(info)) then
		return
	end

	local count = 0

	for _, row in ipairs(info:GetChildren()) do
		if (IsValid(row)) then
			if (!row.ixInfoStyled) then
				self.rowCounter = self.rowCounter + 1
				row.ixInfoStyled = true

				StyleRow(row, self.rowCounter)
			end

			if (row:IsVisible()) then
				count = count + 1
			end
		end
	end

	info:SetVisible(count > 0)
	info:SizeToContents()

	if (IsValid(self.extraHeader)) then
		self.extraHeader:SetVisible(count > 0)
		self.extraHeader:SetRightText(count > 0 and string.format("%02d", count) or "")
	end

	if (IsValid(self.profile)) then
		self.profile:InvalidateLayout()
	end
end

function PANEL:UpdateAttributes(character)
	if (!IsValid(self.attributes) or !character) then
		return
	end

	local boost = character:GetBoosts() or {}
	local sumPct, count = 0, 0

	for _, bar in ipairs(self.attributes.bars) do
		local k = bar.attributeID
		local def = ix.attributes.list[k]

		if (def) then
			local attributeBoost = 0

			if (boost[k]) then
				for _, bValue in pairs(boost[k]) do
					attributeBoost = attributeBoost + bValue
				end
			end

			local value = character:GetAttribute(k, 0)
			local maximum = def.maxValue or ix.config.Get("maxAttributes", 100)

			bar:SetData(L(def.name), value, attributeBoost, maximum)

			sumPct = sumPct + value / math.max(maximum, 0.0001) * 100
			count = count + 1
		end
	end

	if (IsValid(self.attrHeader) and count > 0) then
		self.attrHeader:SetRightText(string.format("СРЕДНЕЕ  %d%%", math.floor(sumPct / count + 0.5)))
	end
end

function PANEL:UpdateLive()
	local ply = LocalPlayer()

	if (!IsValid(ply)) then
		return
	end

	local character = ply.GetCharacter and ply:GetCharacter()

	if (character) then
		if (IsValid(self.money)) then
			self.money:SetText(ix.currency.Get(character:GetMoney()))
		end

		self:UpdateAttributes(character)
	end
end

function PANEL:Think()
	self:Recenter()

	local now = CurTime()

	if ((self.nextLive or 0) > now) then
		return
	end

	self.nextLive = now + 0.25
	self:UpdateLive()
end

function PANEL:Update(character)
	if (!character) then
		return
	end

	self.lastPX = nil
	self:Recenter()

	local faction = ix.faction.indices[character:GetFaction()]
	local class = ix.class.list[character:GetClass()]
	local factionName = faction and Upper(L(faction.name)) or "—"
	local bShowClass = class and (!faction or class.name != faction.name)
	local className = bShowClass and Upper(L(class.name)) or ""

	if (IsValid(self.profile)) then
		self.profile.color = faction and faction.color or nil
	end

	if (IsValid(self.name)) then
		local initial = SplitChars(factionName)[1] or ""

		self.name:SetText(character:GetName())
		self.name:SetData(string.format("№ %06d", character:GetID() or 0), initial)

		if (faction) then
			self.name.backgroundColor = ColorAlpha(faction.color, 150) or Color(0, 0, 0, 150)
		end
	end

	if (IsValid(self.description)) then
		self.description:SetText(character:GetDescription())
		self.description:SizeToContents()
	end

	if (IsValid(self.faction)) then
		self.faction:SetLabelText("ФРАКЦИЯ")
		self.faction:SetText(factionName)
		self.faction:SetStripe(faction and faction.color or nil)
	end

	if (IsValid(self.class)) then
		if (bShowClass) then
			self.class:SetLabelText("КЛАСС")
			self.class:SetText(className)
			self.class:SetVisible(true)
		else
			self.class:SetVisible(false)
		end
	end

	if (IsValid(self.money)) then
		self.money:SetLabelText("СРЕДСТВА")
		self.money:SetText(ix.currency.Get(character:GetMoney()))
	end

	if (IsValid(self.profile)) then
		self.profile:InvalidateLayout()
	end

	self:UpdateLive()

	hook.Run("UpdateCharacterInfo", self.characterInfo, character)

	if (IsValid(self.characterInfo)) then
		self:RefreshExtra()
	end

	hook.Run("UpdateCharacterInfoCategory", self, character)
end

function PANEL:Reveal()
	local step = math.min(CFG.revealStep, 1 / math.max(#self.revealList, 1))

	for i, pnl in ipairs(self.revealList) do
		if (IsValid(pnl)) then
			pnl.revealA = 0
			pnl:SetAlpha(0)

			timer.Simple((i - 1) * step, function()
				if (!IsValid(pnl)) then
					return
				end

				if (pnl.Replay) then
					pnl:Replay()
				end

				pnl:CreateAnimation(0.45, {
					index = 30,
					target = {revealA = 255},
					easing = "outCubic",

					Think = function(animation, panel)
						panel:SetAlpha(panel.revealA)
					end,

					OnComplete = function(animation, panel)
						panel:SetAlpha(255)
					end
				})
			end)
		end
	end

	PlayUI("reveal")
end

function PANEL:OnSubpanelRightClick()
	properties.OpenEntityMenu(LocalPlayer())
end

-- фон и шапка в стиле cl_inventory
function PANEL:Paint(w, h)
	if (CFG.blur and ix.util.DrawBlur) then
		ix.util.DrawBlur(self, 6)
	end

	local accent = GetAccent()
	local headerH = IsValid(self.header) and self.header:GetTall() or S(52)
	local cy = math.floor(headerH * 0.5)

	draw.NoTexture()

	surface.SetDrawColor(8, 11, 16, 215)
	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(0, 0, 0, 90)
	surface.DrawRect(0, 0, w, headerH)

	-- мягкое свечение под линией шапки
	for i = 1, 6 do
		surface.SetDrawColor(accent.r, accent.g, accent.b, 16 * (1 - i / 6) ^ 2)
		surface.DrawRect(1, headerH + i - 1, w - 2, 1)
	end

	surface.SetDrawColor(accent.r, accent.g, accent.b, 60)
	surface.DrawRect(0, headerH - 1, w, 1)

	-- яркий отрезок на линии и маркер у заголовка
	surface.SetDrawColor(accent.r, accent.g, accent.b, 230)
	surface.DrawRect(S(8), headerH - 2, S(40), 3)
	surface.DrawRect(S(8), cy - S(7), 2, S(14))
end

function PANEL:PaintOver(w, h)
	local accent = GetAccent()

	draw.NoTexture()

	surface.SetDrawColor(accent.r, accent.g, accent.b, 45)
	surface.DrawOutlinedRect(0, 0, w, h, 1)

	DrawCorners(w, h, S(10), accent.r, accent.g, accent.b, 230)
end

vgui.Register("ixCharacterInfo", PANEL, "Panel")

hook.Add("CreateMenuButtons", "ixCharInfo", function(tabs)
	tabs["you"] = {
		bHideBackground = true,
		buttonColor = team.GetColor(LocalPlayer():Team()),
		Create = function(info, container)
			container.infoPanel = container:Add("ixCharacterInfo")

			container.OnMouseReleased = function(this, key)
				if (key == MOUSE_RIGHT) then
					this.infoPanel:OnSubpanelRightClick()
				end
			end
		end,
		OnSelected = function(info, container)
			container.infoPanel:Update(LocalPlayer():GetCharacter())
			container.infoPanel:Reveal()

			if (IsValid(ix.gui.menu)) then
				ix.gui.menu:SetCharacterOverview(CFG.characterOverview)
			end
		end,
		OnDeselected = function(info, container)
			if (IsValid(ix.gui.menu)) then
				ix.gui.menu:SetCharacterOverview(false)
			end
		end
	}
end)