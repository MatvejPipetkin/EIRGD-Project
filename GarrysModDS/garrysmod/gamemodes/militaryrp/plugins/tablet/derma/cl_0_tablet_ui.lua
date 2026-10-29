-- Библиотека интерфейса планшета: цвета, шрифты, примитивы, иконки, кнопки и карта.
-- Имя файла начинается с "cl_0", чтобы загрузиться раньше cl_tablet.lua.

ix.tablet = ix.tablet or {}

local UI = {}
ix.tablet.ui = UI

local C = {
	bg = Color(12, 14, 12),
	panel = Color(21, 25, 21),
	panel2 = Color(29, 34, 29),
	line = Color(46, 54, 45),
	text = Color(218, 223, 213),
	dim = Color(128, 138, 124),
	accent = Color(139, 168, 98),
	danger = Color(198, 86, 74),
	warn = Color(214, 168, 72),
	ok = Color(112, 190, 112),
	info = Color(96, 152, 206)
}

UI.C = C

local function S(n)
	return math.max(1, math.Round(n * ScrH() / 1080))
end

UI.S = S

local function CreateFonts()
	surface.CreateFont("ixTabletT", {font = "Arial", size = S(13), weight = 500, extended = true})
	surface.CreateFont("ixTabletS", {font = "Arial", size = S(16), weight = 500, extended = true})
	surface.CreateFont("ixTabletM", {font = "Arial", size = S(19), weight = 600, extended = true})
	surface.CreateFont("ixTabletL", {font = "Arial", size = S(25), weight = 600, extended = true})
	surface.CreateFont("ixTabletXL", {font = "Arial", size = S(34), weight = 700, extended = true})
	surface.CreateFont("ixTabletClock", {font = "Arial", size = S(72), weight = 300, extended = true})
	surface.CreateFont("ixTabletMono", {font = "Courier New", size = S(14), weight = 500, extended = true})
end

CreateFonts()
hook.Add("OnScreenSizeChanged", "ixTabletFonts", CreateFonts)

-- ========== Примитивы ==========

local function Box(x, y, w, h, col)
	surface.SetDrawColor(col)
	surface.DrawRect(x, y, w, h)
end

local function Outline(x, y, w, h, col)
	surface.SetDrawColor(col)
	surface.DrawOutlinedRect(x, y, w, h, 1)
end

local function Circle(x, y, r, col, seg)
	seg = seg or 24
	local poly = {}

	for i = 0, seg - 1 do
		local a = math.rad(i / seg * 360)
		poly[#poly + 1] = {x = x + math.cos(a) * r, y = y + math.sin(a) * r}
	end

	draw.NoTexture()
	surface.SetDrawColor(col)
	surface.DrawPoly(poly)
end

local function Ring(x, y, r, col, seg)
	seg = seg or 24
	surface.SetDrawColor(col)

	local px, py = x + r, y

	for i = 1, seg do
		local a = math.rad(i / seg * 360)
		local nx, ny = x + math.cos(a) * r, y + math.sin(a) * r

		surface.DrawLine(px, py, nx, ny)
		px, py = nx, ny
	end
end

local function Poly(col, points)
	draw.NoTexture()
	surface.SetDrawColor(col)
	surface.DrawPoly(points)
end

UI.Box, UI.Outline, UI.Circle, UI.Ring, UI.Poly = Box, Outline, Circle, Ring, Poly

-- Нашивка звания: n шевронов (остриём вниз).
function UI.Chevrons(x, y, n, col, w)
	surface.SetDrawColor(col)

	for i = 0, n - 1 do
		local yy = y + i * S(5)

		for t = 0, 1 do
			surface.DrawLine(x, yy + t, x + w / 2, yy + w * 0.3 + t)
			surface.DrawLine(x + w / 2, yy + w * 0.3 + t, x + w, yy + t)
		end
	end
end

-- Плашка-тег. x — правый край, возвращает левый край (с отступом).
function UI.Pill(x, y, text, col)
	surface.SetFont("ixTabletT")
	local tw = surface.GetTextSize(text)
	local w, h = tw + S(14), S(18)

	Box(x - w, y, w, h, ColorAlpha(col, 26))
	Outline(x - w, y, w, h, ColorAlpha(col, 140))
	draw.SimpleText(text, "ixTabletT", x - w / 2, y + h / 2, col, 1, 1)

	return x - w - S(6)
end

-- ========== Иконки (векторные, без текстур) ==========

local Icons = {}

function Icons.home(x, y, s, c)
	surface.SetDrawColor(c)
	surface.DrawLine(x, y + s * 0.48, x + s * 0.5, y + s * 0.1)
	surface.DrawLine(x + s * 0.5, y + s * 0.1, x + s, y + s * 0.48)
	surface.DrawOutlinedRect(x + s * 0.17, y + s * 0.48, s * 0.66, s * 0.46, 1)
	surface.DrawOutlinedRect(x + s * 0.42, y + s * 0.66, s * 0.16, s * 0.28, 1)
end

function Icons.user(x, y, s, c)
	Ring(x + s * 0.5, y + s * 0.3, s * 0.2, c)
	surface.SetDrawColor(c)
	surface.DrawOutlinedRect(x + s * 0.2, y + s * 0.58, s * 0.6, s * 0.36, 1)
end

function Icons.people(x, y, s, c)
	Ring(x + s * 0.34, y + s * 0.3, s * 0.16, c)
	Ring(x + s * 0.7, y + s * 0.34, s * 0.12, c)
	surface.SetDrawColor(c)
	surface.DrawOutlinedRect(x + s * 0.08, y + s * 0.55, s * 0.5, s * 0.38, 1)
	surface.DrawOutlinedRect(x + s * 0.64, y + s * 0.58, s * 0.3, s * 0.3, 1)
end

function Icons.doc(x, y, s, c)
	surface.SetDrawColor(c)
	surface.DrawOutlinedRect(x + s * 0.2, y + s * 0.08, s * 0.6, s * 0.84, 1)

	for i = 0, 2 do
		local yy = y + s * (0.3 + i * 0.2)
		surface.DrawLine(x + s * 0.32, yy, x + s * 0.68, yy)
	end
end

function Icons.map(x, y, s, c)
	Ring(x + s * 0.5, y + s * 0.38, s * 0.26, c)
	surface.SetDrawColor(c)
	surface.DrawLine(x + s * 0.28, y + s * 0.52, x + s * 0.5, y + s * 0.94)
	surface.DrawLine(x + s * 0.72, y + s * 0.52, x + s * 0.5, y + s * 0.94)
	surface.DrawRect(x + s * 0.46, y + s * 0.34, s * 0.08, s * 0.08)
end

function Icons.mail(x, y, s, c)
	surface.SetDrawColor(c)
	surface.DrawOutlinedRect(x + s * 0.06, y + s * 0.2, s * 0.88, s * 0.6, 1)
	surface.DrawLine(x + s * 0.06, y + s * 0.2, x + s * 0.5, y + s * 0.55)
	surface.DrawLine(x + s * 0.94, y + s * 0.2, x + s * 0.5, y + s * 0.55)
end

function Icons.flag(x, y, s, c)
	surface.SetDrawColor(c)
	surface.DrawLine(x + s * 0.25, y + s * 0.08, x + s * 0.25, y + s * 0.95)
	surface.DrawOutlinedRect(x + s * 0.25, y + s * 0.12, s * 0.6, s * 0.4, 1)
	surface.DrawLine(x + s * 0.25, y + s * 0.32, x + s * 0.85, y + s * 0.32)
end

function Icons.log(x, y, s, c)
	surface.SetDrawColor(c)

	for i = 0, 2 do
		local yy = y + s * (0.22 + i * 0.28)
		surface.DrawRect(x + s * 0.1, yy - 1, 2, 2)
		surface.DrawLine(x + s * 0.28, yy, x + s * 0.92, yy)
	end
end

function UI.Icon(name, x, y, s, col)
	if (Icons[name]) then
		Icons[name](x, y, s, col)
	end
end

-- Иконки меток карты. kind: 1 цель, 2 опасность, 3 сбор, 4 база, 5 заметка.
UI.KIND_COL = {C.danger, C.warn, C.ok, C.info, C.text}

function UI.DrawMarker(kind, x, y, r, col)
	col = col or UI.KIND_COL[kind] or C.text

	if (kind == 1) then
		Ring(x, y, r, col)
		surface.SetDrawColor(col)
		surface.DrawLine(x - r - 3, y, x + r + 3, y)
		surface.DrawLine(x, y - r - 3, x, y + r + 3)
		Circle(x, y, 2, col, 8)
	elseif (kind == 2) then
		Poly(col, {{x = x, y = y - r - 1}, {x = x + r + 2, y = y + r}, {x = x - r - 2, y = y + r}})
		draw.SimpleText("!", "ixTabletT", x, y + 2, Color(18, 18, 18), 1, 1)
	elseif (kind == 3) then
		Box(x - r, y - r, r * 2, r * 2, col)
		Outline(x - r, y - r, r * 2, r * 2, Color(0, 0, 0, 140))
	elseif (kind == 4) then
		Poly(col, {{x = x, y = y - r - 2}, {x = x + r + 2, y = y}, {x = x, y = y + r + 2}, {x = x - r - 2, y = y}})
	else
		Circle(x, y, r, col)
		Ring(x, y, r, Color(0, 0, 0, 140))
	end
end

-- ========== Текст ==========

-- Перенос по словам с учётом \n.
function UI.Wrap(text, width, font)
	surface.SetFont(font)

	local lines = {}

	for para in (tostring(text) .. "\n"):gmatch("(.-)\n") do
		local line = ""

		for word in para:gmatch("%S+") do
			local test = line == "" and word or (line .. " " .. word)

			if (surface.GetTextSize(test) > width and line != "") then
				lines[#lines + 1] = line
				line = word
			else
				line = test
			end
		end

		lines[#lines + 1] = line
	end

	return lines
end

-- Обрезка одной строки до ширины с многоточием (UTF-8 безопасно).
function UI.Trunc(text, width, font)
	text = string.gsub(tostring(text), "%s+", " ")
	surface.SetFont(font)

	if (surface.GetTextSize(text) <= width) then
		return text
	end

	local len = utf8.len(text) or #text

	while (len > 1) do
		len = len - 1

		local cut = string.sub(text, 1, (utf8.offset(text, len + 1) or (#text + 1)) - 1) .. "…"

		if (surface.GetTextSize(cut) <= width) then
			return cut
		end
	end

	return "…"
end

-- Нижний регистр с кириллицей (для поиска).
function UI.Lower(s)
	local ok, res = pcall(function()
		local t = {}

		for _, c in ipairs({utf8.codepoint(s, 1, -1)}) do
			if (c >= 0x410 and c <= 0x42F) then
				c = c + 0x20
			elseif (c >= 0x400 and c <= 0x40F) then
				c = c + 0x50
			elseif (c >= 65 and c <= 90) then
				c = c + 32
			end

			t[#t + 1] = utf8.char(c)
		end

		return table.concat(t)
	end)

	return ok and res or string.lower(s)
end

function UI.Ago(t)
	local d = os.time() - (t or 0)

	if (d < 60) then return "только что" end
	if (d < 3600) then return math.floor(d / 60) .. " мин. назад" end
	if (d < 86400) then return math.floor(d / 3600) .. " ч. назад" end

	return math.floor(d / 86400) .. " дн. назад"
end

function UI.DateStr(t)
	return os.date("%d.%m.%Y %H:%M", t or 0)
end

-- ========== Виджеты ==========

function UI.Label(parent, text, font, col)
	local l = parent:Add("DLabel")
	l:SetText(text)
	l:SetFont(font)
	l:SetTextColor(col)
	l:SizeToContents()

	return l
end

function UI.StyleScroll(scroll)
	local bar = scroll:GetVBar()
	bar:SetWide(S(6))
	bar:SetHideButtons(true)
	bar.Paint = function() end
	bar.btnGrip.Paint = function(_, w, h) Box(0, 0, w, h, C.line) end
end

-- Поле ввода. Для пароля: entry.isPassword = true (каретка при этом всегда в конце).
function UI.StyleEntry(e, font)
	e:SetFont(font or "ixTabletS")

	e.Paint = function(s, w, h)
		Box(0, 0, w, h, C.panel)
		Outline(0, 0, w, h, s:HasFocus() and C.accent or C.line)

		if (s.isPassword) then
			local txt = string.rep("•", utf8.len(s:GetText()) or #s:GetText())

			surface.SetFont(s:GetFont())
			local tw = surface.GetTextSize(txt)

			s:DrawTextEntryText(Color(0, 0, 0, 0), C.accent, Color(0, 0, 0, 0))
			draw.SimpleText(txt, s:GetFont(), 3, h / 2, C.text, 0, 1)

			if (s:HasFocus() and math.floor(CurTime() * 2) % 2 == 0) then
				Box(4 + tw, 5, 1, h - 10, C.accent)
			end
		else
			s:DrawTextEntryText(C.text, C.accent, C.text)
		end

		if (s.ph and s:GetText() == "" and !s:HasFocus()) then
			draw.SimpleText(s.ph, s:GetFont(), 4, s:IsMultiline() and S(4) or h / 2, C.dim, 0, s:IsMultiline() and TEXT_ALIGN_TOP or 1)
		end
	end
end

-- Карточка с заголовком.
function UI.Card(parent, title)
	local c = parent:Add("EditablePanel")
	c.title = title

	c.Paint = function(s, w, h)
		Box(0, 0, w, h, C.panel)
		Outline(0, 0, w, h, C.line)

		if (s.title) then
			Box(0, 0, S(3), S(28), C.accent)
			draw.SimpleText(s.title, "ixTabletT", S(14), S(14), C.dim, 0, 1)
			Box(S(14), S(28), w - S(28), 1, C.line)
		end
	end

	c:DockPadding(S(14), title and S(38) or S(12), S(14), S(12))

	return c
end

-- Заголовок страницы. Возвращает панель; sub — подпись справа.
function UI.PageHeader(p, title, sub)
	local h = p:Add("EditablePanel")
	h:Dock(TOP)
	h:SetTall(S(44))
	h:DockMargin(0, 0, 0, S(10))

	h.Paint = function(s, w, hh)
		draw.SimpleText(title, "ixTabletL", 0, S(2), C.text)

		if (sub) then
			draw.SimpleText(sub, "ixTabletS", w - (s.subOffset or 0), S(14), C.dim, TEXT_ALIGN_RIGHT)
		end

		Box(0, hh - 1, w, 1, C.line)
		Box(0, hh - 1, S(44), 1, C.accent)
	end

	return h
end

-- Аватар по модели персонажа.
function UI.Avatar(parent, model, size)
	local img = parent:Add("ModelImage")
	img:SetSize(size, size)
	img:SetModel(model or "models/player/group01/male_01.mdl")
	img.PaintOver = function(_, w, h) Outline(0, 0, w, h, C.line) end

	return img
end

-- Кнопка
local BTN = {}

function BTN:Init()
	self:SetText("")
	self.hover = 0
	self.label = ""
	self.col = C.accent
end

function BTN:SetLabel(text)
	self.label = text
end

function BTN:Think()
	self.hover = Lerp(FrameTime() * 12, self.hover, (self:IsHovered() and self:IsEnabled()) and 1 or 0)
end

function BTN:Paint(w, h)
	local a = self:IsEnabled() and 1 or 0.3

	Box(0, 0, w, h, ColorAlpha(self.col, (14 + self.hover * 40) * a))
	Outline(0, 0, w, h, ColorAlpha(self.col, (90 + self.hover * 120) * a))
	draw.SimpleText(self.label, "ixTabletS", w / 2, h / 2, ColorAlpha(self.col, 255 * a), 1, 1)
end

vgui.Register("ixTabletButton", BTN, "DButton")

-- Переключатель (кнопка с состоянием on)
local TOG = {}

function TOG:Init()
	self:SetText("")
	self.hover = 0
	self.label = ""
	self.on = false
	self.col = C.accent
end

function TOG:SetLabel(text)
	self.label = text
end

function TOG:Think()
	self.hover = Lerp(FrameTime() * 12, self.hover, self:IsHovered() and 1 or 0)
end

function TOG:Paint(w, h)
	if (self.on) then
		Box(0, 0, w, h, ColorAlpha(self.col, 38))
		Outline(0, 0, w, h, self.col)
	else
		Box(0, 0, w, h, ColorAlpha(C.panel2, 150 + self.hover * 105))
		Outline(0, 0, w, h, C.line)
	end

	draw.SimpleText(self.label, "ixTabletS", w / 2, h / 2, self.on and self.col or C.dim, 1, 1)
end

vgui.Register("ixTabletToggle", TOG, "DButton")

-- ========== Карта ==========

local MAP = {}
local LETTERS = "ABCDEFGH"
local UNITS_PER_METER = 52.49

function MAP:Init()
	self.data = ix.tablet.maps[game.GetMap()]
	self.mat = self.data and Material(self.data.material, "smooth") or nil

	local mins = self.data and self.data.mins or {-16384, -16384}
	local maxs = self.data and self.data.maxs or {16384, 16384}

	self.min = {x = mins[1], y = mins[2]}
	self.max = {x = maxs[1], y = maxs[2]}
	self.nextPoll = 0
	self.view = {zoom = 1, pan = {x = 0, y = 0}}
	self.layers = {grid = true, markers = true, allies = true}
end

function MAP:GetBase()
	local w, h = self:GetSize()
	local aspect = (self.max.x - self.min.x) / (self.max.y - self.min.y)
	local bw, bh = w, w / aspect

	if (bh > h) then
		bh = h
		bw = h * aspect
	end

	return bw, bh
end

function MAP:WorldToPanel(x, y)
	local w, h = self:GetSize()
	local bw, bh = self:GetBase()
	local u = (x - self.min.x) / (self.max.x - self.min.x)
	local v = (self.max.y - y) / (self.max.y - self.min.y)
	local view = self.view

	return w / 2 + view.pan.x + (u - 0.5) * bw * view.zoom, h / 2 + view.pan.y + (v - 0.5) * bh * view.zoom
end

function MAP:PanelToWorld(px, py)
	local w, h = self:GetSize()
	local bw, bh = self:GetBase()
	local view = self.view
	local u = (px - w / 2 - view.pan.x) / (bw * view.zoom) + 0.5
	local v = (py - h / 2 - view.pan.y) / (bh * view.zoom) + 0.5

	return self.min.x + u * (self.max.x - self.min.x), self.max.y - v * (self.max.y - self.min.y)
end

function MAP:GetSector(x, y)
	local col = math.Clamp(math.floor((x - self.min.x) / (self.max.x - self.min.x) * 8), 0, 7)
	local row = math.Clamp(math.floor((self.max.y - y) / (self.max.y - self.min.y) * 8), 0, 7)

	return string.sub(LETTERS, col + 1, col + 1) .. (row + 1)
end

function MAP:GetMe()
	local st = ix.tablet.state

	for _, p in ipairs(st and st.positions or {}) do
		if (p.id == st.me.id) then return p end
	end
end

function MAP:CenterOn(x, y, zoom)
	if (zoom) then
		self.view.zoom = zoom
	end

	self.view.pan = {x = 0, y = 0}

	local w, h = self:GetSize()
	local nx, ny = self:WorldToPanel(x, y)

	self.view.pan.x = w / 2 - nx
	self.view.pan.y = h / 2 - ny
end

function MAP:ZoomBy(f, mx, my)
	local w, h = self:GetSize()
	mx, my = mx or w / 2, my or h / 2

	local wx, wy = self:PanelToWorld(mx, my)
	self.view.zoom = math.Clamp(self.view.zoom * f, 0.5, 10)

	local nx, ny = self:WorldToPanel(wx, wy)
	self.view.pan.x = self.view.pan.x + (mx - nx)
	self.view.pan.y = self.view.pan.y + (my - ny)
end

function MAP:Think()
	if (CurTime() >= self.nextPoll) then
		self.nextPoll = CurTime() + 2
		ix.tablet.Send("positions")
	end

	if (self.dragging) then
		if (!input.IsMouseDown(MOUSE_LEFT)) then
			self.dragging = false
			self:MouseCapture(false)
		else
			local mx, my = self:CursorPos()
			self.view.pan.x = self.view.pan.x + (mx - self.lastX)
			self.view.pan.y = self.view.pan.y + (my - self.lastY)
			self.lastX, self.lastY = mx, my
		end
	end

	-- Однократно центрируемся на себе, когда пришли позиции.
	if (!self.view.centered) then
		local me = self:GetMe()

		if (me) then
			self:CenterOn(me.x, me.y, 2)
			self.view.centered = true
		end
	end
end

function MAP:OpenAdd(px, py, wx, wy)
	local pw, ph = S(272), S(158)
	local pop = self:Add("EditablePanel")
	local kind = 5

	self.pop = pop
	pop:SetSize(pw, ph)
	pop:SetPos(math.Clamp(px, 0, self:GetWide() - pw), math.Clamp(py, 0, self:GetTall() - ph))

	pop.Paint = function(_, w, h)
		Box(0, 0, w, h, C.panel)
		Outline(0, 0, w, h, C.accent)
		draw.SimpleText("МЕТКА: " .. string.upper(ix.tablet.markerKinds[kind] or ""), "ixTabletT", S(10), S(12), C.dim, 0, 1)
	end

	for i = 1, #ix.tablet.markerKinds do
		local b = pop:Add("DButton")
		b:SetText("")
		b:SetPos(S(10) + (i - 1) * S(50), S(28))
		b:SetSize(S(46), S(38))
		b:SetTooltip(ix.tablet.markerKinds[i])

		b.Paint = function(_, w, h)
			local sel = kind == i
			local col = UI.KIND_COL[i]

			Box(0, 0, w, h, sel and ColorAlpha(col, 40) or C.panel2)
			Outline(0, 0, w, h, sel and col or C.line)
			UI.DrawMarker(i, w / 2, h / 2, S(6))
		end

		b.DoClick = function() kind = i end
	end

	local entry = pop:Add("DTextEntry")
	entry:SetPos(S(10), S(76))
	entry:SetSize(pw - S(20), S(30))
	UI.StyleEntry(entry)
	entry.ph = "Подпись"

	local function Submit()
		ix.tablet.Send("markerAdd", {x = wx, y = wy, text = entry:GetValue(), kind = kind})
		pop:Remove()
	end

	entry.OnEnter = Submit
	entry:RequestFocus()

	local ok = pop:Add("ixTabletButton")
	ok:SetPos(S(10), S(114))
	ok:SetSize(pw - S(20), S(32))
	ok:SetLabel("Поставить метку")
	ok.DoClick = Submit
end

function MAP:OpenDelete(marker, px, py)
	local pw, ph = S(240), S(92)
	local pop = self:Add("EditablePanel")

	self.pop = pop
	pop:SetSize(pw, ph)
	pop:SetPos(math.Clamp(px, 0, self:GetWide() - pw), math.Clamp(py, 0, self:GetTall() - ph))

	pop.Paint = function(_, w, h)
		Box(0, 0, w, h, C.panel)
		Outline(0, 0, w, h, C.danger)
		draw.SimpleText(UI.Trunc((ix.tablet.markerKinds[marker.kind or 5] or "") .. ": " .. marker.text, w - S(20), "ixTabletS"), "ixTabletS", S(10), S(18), C.text, 0, 1)
		draw.SimpleText(marker.by or "", "ixTabletT", S(10), S(38), C.dim, 0, 1)
	end

	local del = pop:Add("ixTabletButton")
	del:SetPos(S(10), S(52))
	del:SetSize(pw - S(20), S(30))
	del:SetLabel("Удалить метку")
	del.col = C.danger
	del.DoClick = function()
		ix.tablet.Send("markerDel", {id = marker.id})
		pop:Remove()
	end
end

function MAP:OnMousePressed(code)
	if (IsValid(self.pop)) then
		self.pop:Remove()
	end

	local st = ix.tablet.state

	if (code == MOUSE_LEFT) then
		self.dragging = true
		self.lastX, self.lastY = self:CursorPos()
		self:MouseCapture(true)
	elseif (code == MOUSE_RIGHT and st and st.me.canManage) then
		local mx, my = self:CursorPos()

		if (self.layers.markers) then
			for _, m in ipairs(st.markers) do
				local px, py = self:WorldToPanel(m.x, m.y)

				if (math.abs(px - mx) < S(10) and math.abs(py - my) < S(10)) then
					return self:OpenDelete(m, mx, my)
				end
			end
		end

		local wx, wy = self:PanelToWorld(mx, my)
		self:OpenAdd(mx, my, wx, wy)
	end
end

function MAP:OnMouseWheeled(delta)
	local mx, my = self:CursorPos()
	self:ZoomBy(delta > 0 and 1.2 or 1 / 1.2, mx, my)
end

function MAP:Paint(w, h)
	local st = ix.tablet.state
	Box(0, 0, w, h, Color(9, 11, 9))

	local bw, bh = self:GetBase()
	local zoom = self.view.zoom
	local mw, mh = bw * zoom, bh * zoom
	local x0 = w / 2 + self.view.pan.x - mw / 2
	local y0 = h / 2 + self.view.pan.y - mh / 2

	if (self.mat and !self.mat:IsError()) then
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(self.mat)
		surface.DrawTexturedRect(x0, y0, mw, mh)
	else
		Box(x0, y0, mw, mh, C.panel)
	end

	-- Сетка секторов A–H / 1–8
	if (self.layers.grid) then
		local dx, dy = self.max.x - self.min.x, self.max.y - self.min.y
		local top, bottom = math.max(0, y0), math.min(h, y0 + mh)
		local left, right = math.max(0, x0), math.min(w, x0 + mw)

		for i = 0, 8 do
			local px = self:WorldToPanel(self.min.x + dx * i / 8, 0)
			local _, py = self:WorldToPanel(0, self.max.y - dy * i / 8)

			surface.SetDrawColor(255, 255, 255, 24)

			if (px >= 0 and px <= w) then
				surface.DrawLine(px, top, px, bottom)
			end

			if (py >= 0 and py <= h) then
				surface.DrawLine(left, py, right, py)
			end

			if (i < 8) then
				local cx = self:WorldToPanel(self.min.x + dx * (i + 0.5) / 8, 0)
				local _, cy = self:WorldToPanel(0, self.max.y - dy * (i + 0.5) / 8)

				if (cx > S(12) and cx < w - S(12)) then
					draw.SimpleText(string.sub(LETTERS, i + 1, i + 1), "ixTabletMono", cx, S(4), ColorAlpha(C.text, 140), 1)
				end

				if (cy > S(16) and cy < h - S(12)) then
					draw.SimpleText(tostring(i + 1), "ixTabletMono", S(6), cy, ColorAlpha(C.text, 140), 0, 1)
				end
			end
		end
	end

	if (!st) then return end

	local mx, my = self:CursorPos()
	local inside = self:IsHovered() and !self.dragging
	local hover

	if (self.layers.markers) then
		for _, m in ipairs(st.markers) do
			local px, py = self:WorldToPanel(m.x, m.y)

			UI.DrawMarker(m.kind or 5, px, py, S(6))
			draw.SimpleText(m.text, "ixTabletT", px, py + S(10), C.text, 1, 0)

			if (inside and math.abs(px - mx) < S(10) and math.abs(py - my) < S(10)) then
				hover = {
					x = px, y = py,
					lines = {(ix.tablet.markerKinds[m.kind or 5] or "") .. ": " .. m.text, "Поставил(а): " .. (m.by or "?"), self:GetSector(m.x, m.y)}
				}
			end
		end
	end

	if (self.layers.allies) then
		local me = self:GetMe()

		for _, p in ipairs(st.positions or {}) do
			local px, py = self:WorldToPanel(p.x, p.y)
			local isMe = p.id == st.me.id
			local col = isMe and Color(255, 255, 255) or st.me.color
			local r = isMe and S(6) or S(5)
			local rad = math.rad(p.yaw)

			-- направление взгляда
			surface.SetDrawColor(ColorAlpha(col, 200))
			surface.DrawLine(px, py, px + math.cos(rad) * S(16), py - math.sin(rad) * S(16))

			Ring(px, py, r + S(3), ColorAlpha(col, 90))
			Circle(px, py, r, col)
			draw.SimpleText(p.name, "ixTabletT", px, py - S(12), col, 1, TEXT_ALIGN_BOTTOM)

			if (inside and math.abs(px - mx) < S(10) and math.abs(py - my) < S(10)) then
				local lines = {p.name, p.rank or ""}

				if (me and !isMe) then
					local dist = math.sqrt((p.x - me.x) ^ 2 + (p.y - me.y) ^ 2) / UNITS_PER_METER
					lines[#lines + 1] = "Дистанция: " .. math.Round(dist) .. " м"
				end

				hover = {x = px, y = py, lines = lines}
			end
		end
	end

	-- Подсказка
	if (hover) then
		surface.SetFont("ixTabletS")

		local tw = 0

		for _, l in ipairs(hover.lines) do
			tw = math.max(tw, (surface.GetTextSize(l)))
		end

		local bw2, bh2 = tw + S(20), #hover.lines * S(18) + S(14)
		local bx = math.Clamp(hover.x + S(14), 0, w - bw2)
		local by = math.Clamp(hover.y - S(10), 0, h - bh2)

		Box(bx, by, bw2, bh2, Color(14, 17, 14, 240))
		Outline(bx, by, bw2, bh2, C.accent)

		for i, l in ipairs(hover.lines) do
			draw.SimpleText(l, "ixTabletS", bx + S(10), by + S(7) + (i - 1) * S(18), i == 1 and C.text or C.dim)
		end
	end

	-- Компас
	local cx, cy, cr = w - S(36), S(40), S(16)

	Ring(cx, cy, cr, C.dim)
	Poly(C.accent, {{x = cx, y = cy - cr}, {x = cx + S(5), y = cy}, {x = cx - S(5), y = cy}})
	draw.SimpleText("N", "ixTabletT", cx, cy - cr - S(9), C.accent, 1, 1)

	-- Масштабная линейка
	local ppu = bw * zoom / (self.max.x - self.min.x)

	for _, meters in ipairs({10, 25, 50, 100, 250, 500, 1000, 2500, 5000}) do
		local len = meters * UNITS_PER_METER * ppu

		if (len >= S(70) or meters == 5000) then
			local bx, by = w - S(16) - len, h - S(18)

			surface.SetDrawColor(C.text)
			surface.DrawLine(bx, by, bx + len, by)
			surface.DrawLine(bx, by - S(4), bx, by + S(4))
			surface.DrawLine(bx + len, by - S(4), bx + len, by + S(4))
			draw.SimpleText(meters .. " м", "ixTabletT", bx + len / 2, by - S(6), C.text, 1, TEXT_ALIGN_BOTTOM)

			break
		end
	end

	-- Информация
	local info = string.format("x%.1f", zoom)

	if (!self.mat) then
		info = info .. "   |   Карта «" .. game.GetMap() .. "» не настроена (ix.tablet.maps)"
	end

	draw.SimpleText(info, "ixTabletT", S(8), h - S(14), C.dim, 0, 1)

	-- Координаты под курсором
	if (self:IsHovered()) then
		local wx, wy = self:PanelToWorld(mx, my)
		draw.SimpleText(string.format("%s   X %d   Y %d", self:GetSector(wx, wy), wx, wy), "ixTabletMono", S(8), h - S(32), C.accent, 0, 1)
	end
end

vgui.Register("ixTabletMap", MAP, "EditablePanel")
