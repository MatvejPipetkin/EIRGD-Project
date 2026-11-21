-- Библиотека интерфейса планшета: ix.tablet.ui, шрифты и панели ixTabletButton / ixTabletToggle.
-- Её ждёт derma/cl_tablet.lua (первая строка: local UI = ix.tablet.ui).
-- Файл лежит в plugins/tablet/libs/: Helix загружает libs/ РАНЬШЕ derma/ и sh_plugin.lua,
-- поэтому к моменту выполнения derma/cl_tablet.lua ix.tablet.ui уже существует.
-- Подключать его вручную в sh_plugin.lua не нужно (и нельзя: sh_plugin.lua грузится после derma/).

ix.tablet = ix.tablet or {}

local UI = {}

ix.tablet.ui = UI

-- ----- Масштаб и палитра -----

function UI.S(n)
	return math.Round(n * ScrH() / 1080)
end

local S = UI.S

UI.C = {
	bg = Color(10, 13, 11),
	panel = Color(19, 24, 21),
	line = Color(46, 56, 48),
	text = Color(214, 222, 208),
	dim = Color(125, 138, 126),
	accent = Color(126, 196, 92),
	ok = Color(96, 200, 120),
	warn = Color(232, 180, 60),
	danger = Color(224, 84, 72),
	info = Color(90, 170, 220)
}

local C = UI.C

-- ----- Шрифты -----

local function CreateFonts()
	local function F(name, size, weight, font)
		surface.CreateFont(name, {font = font or "Arial", size = S(size), weight = weight or 500, extended = true, antialias = true})
	end

	F("ixTabletT", 13)
	F("ixTabletS", 15)
	F("ixTabletM", 19, 600)
	F("ixTabletL", 26, 600)
	F("ixTabletXL", 40, 600)
	F("ixTabletClock", 76, 300)
	F("ixTabletMono", 14, 500, "Consolas")
end

CreateFonts()
hook.Add("OnScreenSizeChanged", "ixTabletUIFonts", CreateFonts)

-- ----- Примитивы -----

function UI.Box(x, y, w, h, col)
	surface.SetDrawColor(col)
	surface.DrawRect(x, y, w, h)
end

function UI.Outline(x, y, w, h, col)
	surface.SetDrawColor(col)
	surface.DrawOutlinedRect(x, y, w, h)
end

local Box, Outline = UI.Box, UI.Outline

-- Закрашенный многоугольник; порядок вершин правим под требование DrawPoly (по часовой).
function UI.Poly(col, pts)
	local area = 0

	for i = 1, #pts do
		local a, b = pts[i], pts[i % #pts + 1]

		area = area + (a.x * b.y - b.x * a.y)
	end

	if (area < 0) then
		local rev = {}

		for i = #pts, 1, -1 do rev[#rev + 1] = pts[i] end

		pts = rev
	end

	draw.NoTexture()
	surface.SetDrawColor(col)
	surface.DrawPoly(pts)
end

local Poly = UI.Poly

function UI.Circle(x, y, r, col, seg)
	seg = seg or 24

	local pts = {}

	for i = 0, seg - 1 do
		local a = i * math.pi * 2 / seg

		pts[#pts + 1] = {x = x + math.cos(a) * r, y = y + math.sin(a) * r}
	end

	Poly(col, pts)
end

local Circle = UI.Circle

-- Кольцо толщиной thick (по умолчанию 2 px).
function UI.Ring(x, y, r, col, thick, seg)
	thick = thick or 2
	seg = seg or 48

	local ro, ri = r + thick / 2, math.max(0, r - thick / 2)

	draw.NoTexture()
	surface.SetDrawColor(col)

	for i = 0, seg - 1 do
		local a1, a2 = i * math.pi * 2 / seg, (i + 1) * math.pi * 2 / seg

		surface.DrawPoly({
			{x = x + math.cos(a1) * ro, y = y + math.sin(a1) * ro},
			{x = x + math.cos(a2) * ro, y = y + math.sin(a2) * ro},
			{x = x + math.cos(a2) * ri, y = y + math.sin(a2) * ri},
			{x = x + math.cos(a1) * ri, y = y + math.sin(a1) * ri}
		})
	end
end

-- Линия заданной толщины.
local function ThickLine(x1, y1, x2, y2, th, col)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)

	if (len < 0.01) then return end

	local nx, ny = -dy / len * th / 2, dx / len * th / 2

	Poly(col, {
		{x = x1 - nx, y = y1 - ny}, {x = x2 - nx, y = y2 - ny},
		{x = x2 + nx, y = y2 + ny}, {x = x1 + nx, y = y1 + ny}
	})
end

-- ----- Текст -----

function UI.Lower(s)
	s = tostring(s or "")

	local out = {}

	for _, cp in utf8.codes(s, true) do
		if (cp >= 0x410 and cp <= 0x42F) then
			cp = cp + 32
		elseif (cp == 0x401) then
			cp = 0x451
		elseif (cp >= 65 and cp <= 90) then
			cp = cp + 32
		end

		out[#out + 1] = utf8.char(cp)
	end

	return table.concat(out)
end

function UI.Trunc(text, maxW, font)
	text = tostring(text or "")

	surface.SetFont(font or "ixTabletS")

	if (surface.GetTextSize(text) <= maxW) then return text end

	local len = utf8.len(text) or #text
	local lo, hi = 0, len

	while (lo < hi) do
		local mid = math.ceil((lo + hi) / 2)
		local cut = utf8.offset(text, mid + 1) or (#text + 1)

		if (surface.GetTextSize(string.sub(text, 1, cut - 1) .. "…") <= maxW) then
			lo = mid
		else
			hi = mid - 1
		end
	end

	local cut = utf8.offset(text, lo + 1) or (#text + 1)

	return string.sub(text, 1, cut - 1) .. "…"
end

-- Перенос по словам; \n сохраняется. Возвращает таблицу строк.
function UI.Wrap(text, maxW, font)
	surface.SetFont(font or "ixTabletS")

	local lines = {}

	for _, para in ipairs(string.Explode("\n", tostring(text or ""), false)) do
		local line = ""

		for word in string.gmatch(para, "%S+") do
			local try = line == "" and word or (line .. " " .. word)

			if (line != "" and surface.GetTextSize(try) > maxW) then
				lines[#lines + 1] = line
				line = word
			else
				line = try
			end
		end

		lines[#lines + 1] = line
	end

	return lines
end

function UI.DateStr(ts)
	return os.date("%d.%m.%Y %H:%M", tonumber(ts) or 0)
end

function UI.Ago(ts)
	local d = os.time() - (tonumber(ts) or 0)

	if (d < 60) then return "только что" end
	if (d < 3600) then return math.floor(d / 60) .. " мин. назад" end
	if (d < 86400) then return math.floor(d / 3600) .. " ч. назад" end

	return math.floor(d / 86400) .. " дн. назад"
end

-- ----- Знаки и значки -----

-- Нашивки-шевроны: n штук, вписаны в квадрат size x size с левым верхним углом (x, y).
function UI.Chevrons(x, y, n, col, size)
	n = math.max(1, n or 1)

	local th = math.max(2, size * 0.11)
	local half = size * 0.34
	local step = size * 0.2
	local total = (n - 1) * step + size * 0.28
	local top = y + (size - total) / 2
	local cx = x + size / 2

	for i = 0, n - 1 do
		local ty = top + i * step

		ThickLine(cx - half, ty + size * 0.28, cx, ty, th, col)
		ThickLine(cx, ty, cx + half, ty + size * 0.28, th, col)
	end
end

-- Маркер метки на карте: kind - индекс из ix.tablet.markerKinds, size - радиус.
local MARKER_COL = {
	[1] = Color(224, 84, 72),
	[2] = Color(232, 180, 60),
	[3] = Color(90, 170, 220),
	[4] = Color(96, 200, 120),
	[5] = Color(190, 196, 188)
}

function UI.DrawMarker(kind, x, y, size)
	local col = MARKER_COL[kind] or C.dim
	local dark = Color(0, 0, 0, 210)
	local r = size

	if (kind == 1) then
		-- Цель: кольцо с точкой
		Circle(x, y, r + 1.5, dark, 20)
		UI.Ring(x, y, r, col, 2, 20)
		Circle(x, y, r * 0.35, col, 12)
	elseif (kind == 2) then
		-- Опасность: треугольник
		Poly(dark, {{x = x, y = y - r - 2}, {x = x + r + 2, y = y + r}, {x = x - r - 2, y = y + r}})
		Poly(col, {{x = x, y = y - r}, {x = x + r, y = y + r - 1}, {x = x - r, y = y + r - 1}})
	elseif (kind == 3) then
		-- Сбор: ромб
		Poly(dark, {{x = x, y = y - r - 2}, {x = x + r + 2, y = y}, {x = x, y = y + r + 2}, {x = x - r - 2, y = y}})
		Poly(col, {{x = x, y = y - r}, {x = x + r, y = y}, {x = x, y = y + r}, {x = x - r, y = y}})
	elseif (kind == 4) then
		-- База: квадрат
		Box(x - r - 1, y - r - 1, r * 2 + 2, r * 2 + 2, dark)
		Box(x - r, y - r, r * 2, r * 2, col)
	else
		-- Заметка: точка
		Circle(x, y, r * 0.8 + 1.5, dark, 16)
		Circle(x, y, r * 0.8, col, 16)
	end
end

-- Иконки вкладок: пиксельные, на сетке 16x16. Каждая клетка привязана к целым пикселям,
-- поэтому линии ровные при любом масштабе. Формат прямоугольника: {x, y, w, h, [прозрачность]}.
local ICONS = {
	home = {
		{7, 1, 2, 1}, {6, 2, 4, 1}, {5, 3, 6, 1}, {4, 4, 8, 1}, {3, 5, 10, 1}, {2, 6, 12, 1}, {1, 7, 14, 1},
		{3, 8, 1, 7}, {12, 8, 1, 7}, {3, 14, 10, 1}, {7, 10, 2, 4}
	},
	people = {
		{4, 2, 3, 1}, {3, 3, 5, 3}, {4, 6, 3, 1}, {3, 8, 5, 1}, {2, 9, 7, 5},
		{10, 3, 3, 1, 0.65}, {9, 4, 5, 3, 0.65}, {10, 7, 3, 1, 0.65}, {10, 9, 4, 1, 0.65}, {9, 10, 6, 4, 0.65}
	},
	flag = {
		{3, 1, 2, 14},
		{5, 2, 9, 1}, {5, 3, 8, 1}, {5, 4, 7, 1}, {5, 5, 6, 1}, {5, 6, 5, 1}, {5, 7, 4, 1}, {5, 8, 3, 1}
	},
	mail = {
		{1, 3, 14, 1}, {1, 12, 14, 1}, {1, 3, 1, 10}, {14, 3, 1, 10},
		{2, 4, 1, 1}, {3, 5, 1, 1}, {4, 6, 1, 1}, {5, 7, 1, 1}, {6, 8, 4, 1},
		{10, 7, 1, 1}, {11, 6, 1, 1}, {12, 5, 1, 1}, {13, 4, 1, 1}
	},
	doc = {
		{3, 1, 10, 1}, {3, 14, 10, 1}, {3, 1, 1, 14}, {12, 1, 1, 14},
		{5, 5, 6, 1}, {5, 8, 6, 1}, {5, 11, 4, 1}
	},
	map = {
		{1, 3, 14, 1}, {1, 12, 14, 1}, {1, 3, 1, 10}, {14, 3, 1, 10},
		{5, 3, 1, 10, 0.6}, {10, 3, 1, 10, 0.6}, {7, 6, 2, 4}
	},
	log = {
		{1, 3, 2, 2}, {1, 7, 2, 2}, {1, 11, 2, 2},
		{5, 3, 10, 2}, {5, 7, 10, 2}, {5, 11, 7, 2}
	},
	user = {
		{6, 1, 4, 1}, {5, 2, 6, 4}, {6, 6, 4, 1},
		{4, 9, 8, 1}, {3, 10, 10, 5}
	}
}

function UI.Icon(name, x, y, s, col)
	local rects = ICONS[name] or ICONS.log
	local u = s / 16

	for _, r in ipairs(rects) do
		local x1 = math.floor(x + r[1] * u + 0.5)
		local y1 = math.floor(y + r[2] * u + 0.5)
		local x2 = math.floor(x + (r[1] + r[3]) * u + 0.5)
		local y2 = math.floor(y + (r[2] + r[4]) * u + 0.5)

		surface.SetDrawColor(col.r, col.g, col.b, col.a * (r[5] or 1))
		surface.DrawRect(x1, y1, math.max(1, x2 - x1), math.max(1, y2 - y1))
	end
end

-- Плашка-метка (ВАЖНО, ЗАКРЕПЛЁН и т.п.). x - ПРАВЫЙ край, y - верх.
-- Возвращает правый край для следующей плашки (чтобы ставить их цепочкой влево).
function UI.Pill(x, y, text, col)
	text = tostring(text or "")
	col = col or C.dim

	surface.SetFont("ixTabletT")

	local tw = surface.GetTextSize(text)
	local w, h = tw + S(14), S(18)
	local x0 = x - w

	Box(x0, y, w, h, ColorAlpha(col, 28))
	Outline(x0, y, w, h, ColorAlpha(col, 160))
	draw.SimpleText(text, "ixTabletT", x0 + w / 2, y + h / 2, col, 1, 1)

	return x0 - S(6)
end

-- ----- Готовые элементы -----

function UI.Label(parent, text, font, col)
	local l = parent:Add("DLabel")

	l:SetFont(font or "ixTabletS")
	l:SetTextColor(col or C.text)
	l:SetText(text or "")
	l:SizeToContents()
	l:SetTall(l:GetTall() + S(4))

	return l
end

function UI.Card(parent, title)
	local p = parent:Add("EditablePanel")

	p:DockPadding(S(12), S(34), S(12), S(12))
	p.Paint = function(_, w, h)
		Box(0, 0, w, h, C.panel)
		Outline(0, 0, w, h, C.line)
		draw.SimpleText(title or "", "ixTabletT", S(12), S(17), C.dim, 0, 1)
		Box(S(12), S(30), w - S(24), 1, C.line)
	end

	return p
end

-- Заголовок страницы: название слева, подпись справа (head.subOffset - отступ справа под кнопки).
function UI.PageHeader(parent, title, sub)
	local p = parent:Add("EditablePanel")

	p:Dock(TOP)
	p:SetTall(S(48))
	p:DockMargin(0, 0, 0, S(10))
	p.Paint = function(s, w, h)
		draw.SimpleText(title or "", "ixTabletL", 0, h / 2 - S(2), C.text, 0, 1)
		draw.SimpleText(sub or "", "ixTabletS", w - (s.subOffset or 0), h / 2 + S(2), C.dim, TEXT_ALIGN_RIGHT, 1)
		Box(0, h - 1, w, 1, C.line)
	end

	return p
end

-- Портрет персонажа (голова модели) в квадрате size x size.
function UI.Avatar(parent, model, size)
	local p = parent:Add("EditablePanel")

	p:SetSize(size, size)
	p.Paint = function(_, w, h)
		Box(0, 0, w, h, Color(12, 16, 13))
	end
	p.PaintOver = function(_, w, h)
		Outline(0, 0, w, h, C.line)
	end

	if (model and model != "") then
		local m = p:Add("DModelPanel")

		m:Dock(FILL)
		m:SetModel(model)
		m:SetFOV(26)
		m.LayoutEntity = function() end

		local ent = m:GetEntity()

		if (IsValid(ent)) then
			local bone = ent:LookupBone("ValveBiped.Bip01_Head1")
			local pos = bone and ent:GetBonePosition(bone) or (ent:GetPos() + Vector(0, 0, 64))

			m:SetLookAt(pos)
			m:SetCamPos(pos + Vector(26, 0, 1))
		end
	end

	return p
end

-- Оформление поля ввода. font - шрифт (по умолчанию ixTabletS).
-- Подсказка берётся из entry.ph, для пароля поставьте entry.isPassword = true.
function UI.StyleEntry(entry, font)
	font = font or "ixTabletS"

	entry:SetFont(font)
	entry:SetTextColor(C.text)
	entry:SetCursorColor(C.accent)
	entry:SetHighlightColor(ColorAlpha(C.accent, 90))
	entry:SetDrawLanguageID(false)

	entry.Paint = function(s, w, h)
		Box(0, 0, w, h, Color(12, 16, 13))
		Outline(0, 0, w, h, s:HasFocus() and C.accent or C.line)

		local val = s:GetValue()
		local multi = s:IsMultiline()

		if (s.isPassword) then
			s:DrawTextEntryText(Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0))

			local dots = string.rep("•", utf8.len(val) or #val)

			surface.SetFont(font)

			local tw, th = surface.GetTextSize(dots)

			draw.SimpleText(dots, font, S(4), h / 2, C.text, 0, 1)

			if (s:HasFocus() and math.floor(CurTime() * 2) % 2 == 0) then
				Box(S(4) + tw + 1, (h - th) / 2, 1, th, C.accent)
			end
		else
			s:DrawTextEntryText(C.text, ColorAlpha(C.accent, 90), C.accent)
		end

		if (val == "" and s.ph) then
			draw.SimpleText(s.ph, font, S(4), multi and S(4) or h / 2, ColorAlpha(C.dim, 160), 0, multi and TEXT_ALIGN_TOP or 1)
		end
	end
end

function UI.StyleScroll(scroll)
	local bar = scroll:GetVBar()

	bar:SetWide(S(6))
	bar:SetHideButtons(true)
	bar.Paint = function(_, w, h) Box(0, 0, w, h, Color(255, 255, 255, 8)) end
	bar.btnGrip.Paint = function(s, w, h)
		Box(0, 0, w, h, ColorAlpha(C.accent, s:IsHovered() and 170 or 100))
	end
end

-- ----- Панели: кнопка и переключатель -----

local BUTTON = {}

function BUTTON:Init()
	self:SetText("")
	self.hover = 0
	self.label = ""
end

function BUTTON:SetLabel(text)
	self.label = text or ""
end

function BUTTON:GetLabel()
	return self.label
end

function BUTTON:Think()
	self.hover = Lerp(FrameTime() * 12, self.hover, (self:IsHovered() and self:IsEnabled()) and 1 or 0)
end

function BUTTON:Paint(w, h)
	local col = self.col or C.accent

	if (!self:IsEnabled()) then col = C.line end

	Box(0, 0, w, h, ColorAlpha(col, 16 + self.hover * 44))
	Outline(0, 0, w, h, ColorAlpha(col, 150 + self.hover * 105))
	draw.SimpleText(self.label, "ixTabletS", w / 2, h / 2, self:IsEnabled() and C.text or C.dim, 1, 1)
end

vgui.Register("ixTabletButton", BUTTON, "DButton")

local TOGGLE = {}

function TOGGLE:Init()
	self:SetText("")
	self.hover = 0
	self.label = ""
	self.on = false
end

function TOGGLE:SetLabel(text)
	self.label = text or ""
end

function TOGGLE:GetLabel()
	return self.label
end

function TOGGLE:Think()
	self.hover = Lerp(FrameTime() * 12, self.hover, self:IsHovered() and 1 or 0)
end

function TOGGLE:Paint(w, h)
	local col = self.col or C.accent

	if (self.on) then
		Box(0, 0, w, h, ColorAlpha(col, 40 + self.hover * 20))
		Outline(0, 0, w, h, col)
	else
		Box(0, 0, w, h, Color(255, 255, 255, 5 + self.hover * 12))
		Outline(0, 0, w, h, C.line)
	end

	draw.SimpleText(self.label, "ixTabletS", w / 2, h / 2, self.on and C.text or C.dim, 1, 1)
end

vgui.Register("ixTabletToggle", TOGGLE, "DButton")