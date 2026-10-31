local PLUGIN = PLUGIN

local UI = {}
PLUGIN.ui = UI

UI.col = {
	bg = Color(20, 21, 26, 252),
	panel = Color(28, 30, 37),
	panel2 = Color(38, 40, 49),
	field = Color(15, 16, 20),
	line = Color(62, 65, 76),
	text = Color(236, 237, 242),
	dim = Color(142, 146, 160),
	accent = Color(90, 160, 235),
	good = Color(110, 200, 120),
	bad = Color(235, 95, 95)
}

UI.accent = UI.col.accent

function UI.S(n)
	return math.max(1, math.Round(n * ScrH() / 1080))
end

local S = UI.S

local function MakeFonts()
	local function F(name, size, weight)
		surface.CreateFont(name, {font = "Roboto", size = size, weight = weight or 500, extended = true, antialias = true})
	end

	F("ixNPC.Name", S(46), 800)
	F("ixNPC.Desc", S(20), 400)
	F("ixNPC.Text", S(30), 500)
	F("ixNPC.Opt", S(24), 500)
	F("ixNPC.Num", S(20), 800)
	F("ixNPC.Hint", S(16), 400)

	F("ixNPC.Ed", 18, 500)
	F("ixNPC.EdBold", 19, 700)
	F("ixNPC.EdSmall", 14, 500)
	F("ixNPC.EdTitle", 26, 700)
end

MakeFonts()
hook.Add("OnScreenSizeChanged", "ixNPCFonts", MakeFonts)

-- ============================================================
-- Утилиты
-- ============================================================

function UI.Accent()
	return UI.accent or UI.col.accent
end

function UI.SetAccent(c)
	UI.accent = Color(c.r, c.g, c.b)
end

function UI.HexToColor(hex)
	hex = string.gsub(tostring(hex or ""), "#", "")

	if (#hex != 6) then return Color(90, 160, 235) end

	return Color(tonumber(hex:sub(1, 2), 16) or 90, tonumber(hex:sub(3, 4), 16) or 160, tonumber(hex:sub(5, 6), 16) or 235)
end

function UI.ColorToHex(c)
	return string.format("#%02X%02X%02X", c.r, c.g, c.b)
end

function UI.ItemName(uid)
	if (!uid or uid == "") then return "Выбрать предмет…" end

	local def = ix.item.list[uid]

	return def and L(def.name) or uid
end

function UI.Wrap(text, font, maxW)
	surface.SetFont(font)

	local lines = {}

	for _, para in ipairs(string.Explode("\n", tostring(text))) do
		local line = ""

		for _, word in ipairs(string.Explode(" ", para)) do
			local try = (line == "") and word or (line .. " " .. word)

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

-- Собственная работа с UTF-8 (utf8.offset в GMod ведёт себя нестабильно)
local function CharSize(b)
	if (b >= 240) then return 4 end
	if (b >= 224) then return 3 end
	if (b >= 192) then return 2 end

	return 1
end

function UI.UTF8Len(s)
	local count, i, len = 0, 1, #s

	while (i <= len) do
		count = count + 1
		i = i + CharSize(string.byte(s, i))
	end

	return count
end

function UI.UTF8Sub(s, n)
	if (n <= 0) then return "" end

	local count, i, len = 0, 1, #s

	while (i <= len) do
		count = count + 1

		if (count > n) then return string.sub(s, 1, i - 1) end

		i = i + CharSize(string.byte(s, i))
	end

	return s
end

-- Теги вариантов ответа (иконка + цвет)
UI.TAGS = {
	shop = {"icon16/cart.png", Color(110, 190, 255)},
	quest = {"icon16/exclamation.png", Color(255, 210, 80)},
	turnin = {"icon16/tick.png", Color(120, 220, 130)},
	leave = {"icon16/door_out.png", Color(175, 175, 185)},
	talk = {"icon16/comment.png", Color(205, 205, 215)}
}

function UI.OptionTag(opt)
	for _, a in ipairs(opt.actions or {}) do
		if (a.type == "openShop") then return "shop" end
		if (a.type == "completeQuest") then return "turnin" end
		if (a.type == "startQuest") then return "quest" end
	end

	if (!opt.next or opt.next == "") then return "leave" end

	return "talk"
end

local mats = {}

function UI.Mat(path)
	mats[path] = mats[path] or Material(path)

	return mats[path]
end

local function Noop() end

-- ============================================================
-- Виджеты
-- ============================================================

function UI.Label(parent, text, font, color)
	local l = vgui.Create("DLabel", parent)
	l:SetFont(font or "ixNPC.Ed")
	l:SetTextColor(color or UI.col.text)
	l:SetText(text)
	l:SizeToContents()
	l:Dock(TOP)

	return l
end

function UI.Hint(parent, text)
	local l = vgui.Create("DLabel", parent)
	l:SetFont("ixNPC.EdSmall")
	l:SetTextColor(UI.col.dim)
	l:SetText(text)
	l:SetWrap(true)
	l:SetAutoStretchVertical(true)
	l:Dock(TOP)
	l:DockMargin(0, 0, 0, 6)

	return l
end

function UI.Section(parent, text)
	local p = vgui.Create("DPanel", parent)
	p:Dock(TOP)
	p:SetTall(32)
	p:DockMargin(0, 16, 0, 6)

	p.Paint = function(s, w, h)
		local a = UI.Accent()

		surface.SetDrawColor(a)
		surface.DrawRect(0, 6, 4, h - 12)
		draw.SimpleText(text, "ixNPC.EdBold", 14, h / 2, UI.col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	return p
end

function UI.Row(parent, h)
	local r = vgui.Create("DPanel", parent)
	r:Dock(TOP)
	r:SetTall(h or 32)
	r:DockMargin(0, 0, 0, 6)
	r.Paint = Noop

	return r
end

function UI.Card(parent, h, pad)
	local c = vgui.Create("DPanel", parent)
	c:Dock(TOP)
	c:SetTall(h)
	c:DockMargin(0, 0, 0, 8)
	c:DockPadding(pad or 10, pad or 10, pad or 10, pad or 10)

	c.Paint = function(s, w, hh)
		draw.RoundedBox(6, 0, 0, w, hh, UI.col.panel2)

		if (s.stripe) then
			draw.RoundedBoxEx(6, 0, 0, 4, hh, s.stripe, true, false, true, false)
		end
	end

	return c
end

function UI.Entry(parent, value, placeholder, onChange, multiline)
	local e = vgui.Create("DTextEntry", parent)
	e:SetFont("ixNPC.Ed")
	e:SetText(tostring(value or ""))
	e:SetMultiline(multiline == true)

	e.Paint = function(s, w, h)
		draw.RoundedBox(4, 0, 0, w, h, UI.col.field)

		if (s:HasFocus()) then
			surface.SetDrawColor(UI.Accent())
			surface.DrawOutlinedRect(0, 0, w, h, 1)
		end

		s:DrawTextEntryText(UI.col.text, UI.Accent(), UI.col.text)

		if (s:GetText() == "" and placeholder) then
			draw.SimpleText(placeholder, "ixNPC.Ed", 5, multiline and 6 or h / 2, Color(255, 255, 255, 45), TEXT_ALIGN_LEFT, multiline and TEXT_ALIGN_TOP or TEXT_ALIGN_CENTER)
		end
	end

	e.OnChange = function(s)
		if (onChange) then onChange(s:GetText()) end
	end

	return e
end

function UI.NumEntry(parent, value, placeholder, onChange)
	local e = UI.Entry(parent, value, placeholder, onChange)
	e:SetNumeric(true)

	return e
end

function UI.Field(parent, label, value, placeholder, onChange, multiline, height)
	local l = UI.Label(parent, label, "ixNPC.EdSmall", UI.col.dim)
	l:DockMargin(0, 8, 0, 3)

	local e = UI.Entry(parent, value, placeholder, onChange, multiline)
	e:Dock(TOP)
	e:SetTall(height or 32)

	return e
end

function UI.Button(parent, text, onClick, kind)
	local b = vgui.Create("DButton", parent)
	b:SetText("")
	b.label = text
	b.kind = kind
	b.hov = 0

	b.Paint = function(s, w, h)
		s.hov = Lerp(FrameTime() * 12, s.hov, s:IsHovered() and 1 or 0)

		local a = UI.Accent()
		local base = UI.col.panel2
		local bg, fg

		if (s.kind == "accent") then
			bg = Color(a.r, a.g, a.b, 215 + 40 * s.hov)
			fg = Color(18, 18, 22)
		elseif (s.kind == "danger") then
			bg = Color(150 + 50 * s.hov, 55, 55, 230)
			fg = color_white
		else
			bg = Color(base.r + 22 * s.hov, base.g + 22 * s.hov, base.b + 26 * s.hov)
			fg = UI.col.text
		end

		draw.RoundedBox(5, 0, 0, w, h, bg)
		draw.SimpleText(s.label, "ixNPC.Ed", w / 2, h / 2, fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	b.DoClick = function(s)
		surface.PlaySound("ui/buttonclickrelease.wav")

		if (onClick) then onClick(s) end
	end

	return b
end

function UI.IconButton(parent, icon, onClick, kind)
	local b = UI.Button(parent, "", onClick, kind)
	local mat = UI.Mat(icon)
	local basePaint = b.Paint

	b.Paint = function(s, w, h)
		basePaint(s, w, h)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(mat)
		surface.DrawTexturedRect(w / 2 - 8, h / 2 - 8, 16, 16)
	end

	b:SetWide(34)

	return b
end

function UI.Toggle(parent, text, value, onChange)
	local b = vgui.Create("DButton", parent)
	b:SetText("")
	b.val = value == true
	b.t = b.val and 1 or 0

	b.Paint = function(s, w, h)
		s.t = Lerp(FrameTime() * 14, s.t, s.val and 1 or 0)

		local a = UI.Accent()
		local tw, th = 40, 20
		local y = (h - th) / 2

		draw.RoundedBox(th / 2, 0, y, tw, th, Color(60 + (a.r - 60) * s.t, 62 + (a.g - 62) * s.t, 72 + (a.b - 72) * s.t))
		draw.RoundedBox(8, 2 + s.t * (tw - th), y + 2, th - 4, th - 4, color_white)
		draw.SimpleText(text, "ixNPC.Ed", tw + 10, h / 2, UI.col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	b.DoClick = function(s)
		s.val = !s.val

		if (onChange) then onChange(s.val) end
	end

	return b
end

-- options = { {"Подпись", значение}, ... }
function UI.Combo(parent, options, selected, onChange, placeholder)
	local c = vgui.Create("DComboBox", parent)
	c:SetFont("ixNPC.Ed")
	c:SetTextColor(UI.col.text)
	c:SetSortItems(false)

	local found = false

	for _, o in ipairs(options) do
		local isSel = (o[2] == selected)

		if (isSel) then found = true end

		c:AddChoice(o[1], o[2], isSel)
	end

	if (!found) then c:SetValue(placeholder or "—") end

	c.Paint = function(s, w, h)
		draw.RoundedBox(4, 0, 0, w, h, UI.col.field)

		if (s:IsMenuOpen()) then
			surface.SetDrawColor(UI.Accent())
			surface.DrawOutlinedRect(0, 0, w, h, 1)
		end
	end

	c.OnSelect = function(_, _, text, data)
		if (onChange) then onChange(data, text) end
	end

	return c
end

function UI.Scroll(parent)
	local s = vgui.Create("DScrollPanel", parent)
	local vbar = s:GetVBar()

	vbar:SetWide(6)
	vbar:SetHideButtons(true)
	vbar.Paint = function(self, w, h) draw.RoundedBox(3, 0, 0, w, h, Color(0, 0, 0, 90)) end
	vbar.btnGrip.Paint = function(self, w, h) draw.RoundedBox(3, 0, 0, w, h, UI.Accent()) end

	return s
end

-- Модальное окно поверх всего. Возвращает (оверлей, контейнер).
function UI.Modal(title, w, h)
	local ov = vgui.Create("EditablePanel")
	ov:SetSize(ScrW(), ScrH())
	ov:MakePopup()
	ov.t = 0

	ov.Paint = function(s, sw, sh)
		s.t = Lerp(FrameTime() * 12, s.t, 1)
		surface.SetDrawColor(0, 0, 0, 185 * s.t)
		surface.DrawRect(0, 0, sw, sh)
	end

	local box = vgui.Create("DPanel", ov)
	box:SetSize(w, h)
	box:Center()
	box:DockPadding(18, 58, 18, 18)

	box.Paint = function(s, bw, bh)
		draw.RoundedBox(10, 0, 0, bw, bh, UI.col.bg)
		draw.RoundedBoxEx(10, 0, 0, bw, 44, UI.col.panel, true, true, false, false)
		surface.SetDrawColor(UI.Accent())
		surface.DrawRect(0, 44, bw, 2)
		draw.SimpleText(title, "ixNPC.EdBold", 18, 22, UI.col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local x = UI.Button(box, "X", function() ov:Remove() end)
	x:SetSize(34, 28)
	x:SetPos(w - 44, 8)

	return ov, box
end

-- Выбор предмета из ix.item.list
function UI.ItemPicker(callback)
	local ov, box = UI.Modal("Выбор предмета", 600, 600)

	local search = UI.Entry(box, "", "Поиск по названию или ID…")
	search:Dock(TOP)
	search:SetTall(34)
	search:RequestFocus()

	local list = vgui.Create("DListView", box)
	list:Dock(FILL)
	list:DockMargin(0, 8, 0, 8)
	list:SetMultiSelect(false)
	list:AddColumn("Название")
	list:AddColumn("ID"):SetFixedWidth(200)

	local function Fill(q)
		list:Clear()

		q = tostring(q or "")

		local lq = string.lower(q)
		local rows = {}

		for id, it in pairs(ix.item.list) do
			local name = L(it.name)

			if (q == "" or string.find(string.lower(name), lq, 1, true) or string.find(name, q, 1, true) or string.find(string.lower(id), lq, 1, true)) then
				rows[#rows + 1] = {name, id}
			end
		end

		table.sort(rows, function(a, b) return a[1] < b[1] end)

		for _, r in ipairs(rows) do list:AddLine(r[1], r[2]) end
	end

	Fill("")
	search.OnChange = function(s) Fill(s:GetText()) end

	local function Pick(line)
		if (!line) then return end

		callback(line:GetColumnText(2))
		ov:Remove()
	end

	list.DoDoubleClick = function(_, _, line) Pick(line) end

	local pick = UI.Button(box, "Выбрать", function()
		local id = list:GetSelectedLine()

		Pick(id and list:GetLine(id))
	end, "accent")
	pick:Dock(BOTTOM)
	pick:SetTall(38)
end
