local UI = ix.tablet.ui
local C, S = UI.C, UI.S
local Box, Outline, Circle, Ring, Poly = UI.Box, UI.Outline, UI.Circle, UI.Ring, UI.Poly
local Label, Card, PageHeader, Avatar = UI.Label, UI.Card, UI.PageHeader, UI.Avatar
local StyleEntry, StyleScroll = UI.StyleEntry, UI.StyleScroll
local Wrap, Trunc, Lower, Ago, DateStr = UI.Wrap, UI.Trunc, UI.Lower, UI.Ago, UI.DateStr
local Chevrons, Pill = UI.Chevrons, UI.Pill

local PR_COL = {C.dim, C.warn, C.danger}
local PR_NAME = {"Обычный", "Важный", "Срочный"}
local PR_TAG = {"", "ВАЖНО", "СРОЧНО"}

local LOG_KIND = {
	rank = {"ЗВАНИЕ", C.accent},
	reprimand = {"ВЫГОВОР", C.danger},
	commend = {"ПООЩРЕНИЕ", C.ok},
	order = {"ПРИКАЗ", C.warn},
	account = {"ДОСТУП", C.info},
	marker = {"КАРТА", C.dim}
}

local DAYS = {"воскресенье", "понедельник", "вторник", "среда", "четверг", "пятница", "суббота"}
local MONTHS = {"января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"}

local function DateLong()
	local t = os.date("*t")

	return string.format("%s, %d %s %d", DAYS[t.wday], t.day, MONTHS[t.month], t.year)
end

-- Сглаженная линия: два прохода (широкий полупрозрачный + тонкий плотный),
-- чтобы убрать "лесенку" на диагоналях. Вершины идут по часовой (требование DrawPoly).
local function SoftLine(x1, y1, x2, y2, thick, col)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)

	if (len < 0.01) then return end

	dx, dy = dx / len, dy / len

	draw.NoTexture()

	for pass = 1, 2 do
		local hw = (pass == 1 and thick + 1.2 or thick) * 0.5
		local nx, ny = -dy * hw, dx * hw

		surface.SetDrawColor(col.r, col.g, col.b, pass == 1 and col.a * 0.3 or col.a)
		surface.DrawPoly({
			{x = x1 - nx, y = y1 - ny},
			{x = x2 - nx, y = y2 - ny},
			{x = x2 + nx, y = y2 + ny},
			{x = x1 + nx, y = y1 + ny}
		})
	end
end

-- Контур замкнутого многоугольника из сглаженных линий + круглые стыки.
local function SoftOutline(pts, thick, col)
	for i = 1, #pts do
		local a, b = pts[i], pts[i % #pts + 1]

		SoftLine(a.x, a.y, b.x, b.y, thick, col)
		Circle(a.x, a.y, thick * 0.5, col, 16)
	end
end

local function Greeting()
	local h = tonumber(os.date("%H"))

	if (h < 6) then return "Доброй ночи" end
	if (h < 12) then return "Доброе утро" end
	if (h < 18) then return "Добрый день" end

	return "Добрый вечер"
end

local function SortOrders(list)
	local t = table.Copy(list)

	table.sort(t, function(a, b)
		local ap, bp = a.pinned and true or false, b.pinned and true or false

		if (ap != bp) then return ap end

		return a.time > b.time
	end)

	return t
end

-- Списки выговоров / поощрений.
local function AddEntries(scroll, list, col, emptyText, onDelete)
	if (#list == 0) then
		local l = Label(scroll, emptyText, "ixTabletS", C.dim)
		l:Dock(TOP)

		return
	end

	for i = #list, 1, -1 do
		local rec = list[i]
		local lines = Wrap(rec.text, S(340), "ixTabletS")
		local row = scroll:Add("EditablePanel")

		row:Dock(TOP)
		row:DockMargin(0, 0, S(8), S(6))
		row:SetTall(S(34) + #lines * S(18))

		row.Paint = function(_, w, h)
			Box(0, 0, w, h, C.panel)
			Outline(0, 0, w, h, C.line)
			Box(0, 0, S(3), h, col)
			draw.SimpleText(rec.by .. " — " .. DateStr(rec.time), "ixTabletT", S(14), S(8), C.dim)

			for k, line in ipairs(lines) do
				draw.SimpleText(line, "ixTabletS", S(14), S(26) + (k - 1) * S(18), C.text)
			end
		end

		if (onDelete) then
			local del = row:Add("ixTabletButton")
			del:SetSize(S(60), S(22))
			del:SetLabel("Снять")
			del.col = C.danger
			del.DoClick = function() onDelete(i) end

			row.PerformLayout = function(_, w) del:SetPos(w - S(68), S(6)) end
		end
	end
end

-- ========== Основной планшет ==========

local PANEL = {}

function PANEL:Init()
	local h = ScrH() * 0.82
	local w = h * 1600 / 1067

	if (w > ScrW() * 0.96) then
		w = ScrW() * 0.96
		h = w * 1067 / 1600
	end

	self:SetSize(w, h)
	self:Center()

	-- Затемнение фона; клик по нему закрывает планшет.
	self.backdrop = vgui.Create("DPanel")
	self.backdrop:SetSize(ScrW(), ScrH())
	self.backdrop:SetPos(0, 0)
	self.backdrop:MakePopup()
	self.backdrop:SetKeyboardInputEnabled(false)
	self.backdrop:SetAlpha(0)
	self.backdrop:AlphaTo(255, 0.25, 0)
	self.backdrop.Paint = function(_, sw, sh)
		surface.SetDrawColor(0, 0, 0, 150)
		surface.DrawRect(0, 0, sw, sh)
	end
	self.backdrop.OnMousePressed = function(_, code)
		if (code == MOUSE_LEFT) then self:Close() end
	end

	self:MakePopup()
	self:SetAlpha(0)
	self:AlphaTo(255, 0.25, 0)

	self.frame = Material("tablet/tablet.png", "smooth mips")
	self.tab = "home"
	self.mapView = nil
	self.mapLayers = {grid = true, markers = true, allies = true}
	self.battery = math.random(58, 96)

	-- Область "стекла" на картинке планшета.
	self.screen = self:Add("EditablePanel")
	self.screen:SetPos(w * 0.150, h * 0.160)
	self.screen:SetSize(w * 0.712, h * 0.675)

	self.screen.Paint = function(_, sw, sh)
		Box(0, 0, sw, sh, C.bg)
	end

	-- Блики стекла и всплывающие уведомления.
	self.screen.PaintOver = function(_, sw, sh)
		Outline(0, 0, sw, sh, Color(0, 0, 0, 160))

		local t = self.toast

		if (t and CurTime() < t.die) then
			local a = math.Clamp((t.die - CurTime()) * 4, 0, 1) * 255

			surface.SetFont("ixTabletS")
			local tw = surface.GetTextSize(t.text)
			local bx, by, bw, bh = sw / 2 - tw / 2 - S(16), sh - S(50), tw + S(32), S(34)

			Box(bx, by, bw, bh, Color(C.panel.r, C.panel.g, C.panel.b, a))
			Outline(bx, by, bw, bh, ColorAlpha(t.col, a))
			Box(bx, by, S(3), bh, ColorAlpha(t.col, a))
			draw.SimpleText(t.text, "ixTabletS", sw / 2, by + bh / 2, ColorAlpha(t.col, a), 1, 1)
		end
	end

	-- Строка состояния
	local bar = self.screen:Add("EditablePanel")
	bar:Dock(TOP)
	bar:SetTall(S(22))
	bar.Paint = function(_, bw, bh)
		Box(0, 0, bw, bh, Color(8, 10, 8))

		for i = 1, 4 do
			Box(S(10) + (i - 1) * S(5), bh - S(5) - i * S(3), S(3), i * S(3), i <= 3 and C.text or C.line)
		end

		draw.SimpleText("ЗАЩИЩЁННАЯ СЕТЬ", "ixTabletT", S(36), bh / 2, C.dim, 0, 1)

		local x = bw - S(10)
		draw.SimpleText(os.date("%H:%M"), "ixTabletT", x, bh / 2, C.text, TEXT_ALIGN_RIGHT, 1)

		x = x - S(48)
		Outline(x - S(22), bh / 2 - S(5), S(20), S(10), C.dim)
		Box(x - S(2), bh / 2 - S(2), S(2), S(4), C.dim)
		Box(x - S(21), bh / 2 - S(4), S(18) * self.battery / 100, S(8), self.battery > 25 and C.ok or C.danger)
		draw.SimpleText(self.battery .. "%", "ixTabletT", x - S(28), bh / 2, C.dim, TEXT_ALIGN_RIGHT, 1)

		local st = ix.tablet.state

		if (st and st.unread > 0) then
			local mx = x - S(78)
			UI.Icon("mail", mx, bh / 2 - S(7), S(14), C.warn)
			draw.SimpleText(st.unread, "ixTabletT", mx + S(18), bh / 2, C.warn, 0, 1)
		end
	end

	self.area = self.screen:Add("EditablePanel")
	self.area:Dock(FILL)

	-- Кнопка питания на рамке закрывает планшет.
	local power = self:Add("DButton")
	power:SetText("")
	power:SetPos(w * 0.903, h * 0.515)
	power:SetSize(w * 0.045, h * 0.075)
	power:SetTooltip("Выключить")
	power.Paint = function() end
	power.DoClick = function() self:Close() end
end

function PANEL:Paint(w, h)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(self.frame)

	-- Анизотропная фильтрация убирает пикселизацию рамки при масштабировании.
	render.PushFilterMag(TEXFILTER.ANISOTROPIC)
	render.PushFilterMin(TEXFILTER.ANISOTROPIC)
	surface.DrawTexturedRect(0, 0, w, h)
	render.PopFilterMin()
	render.PopFilterMag()
end

function PANEL:Think()
	if (!self.closing and input.IsKeyDown(KEY_ESCAPE)) then
		gui.HideGameUI()
		self:Close()
	end
end

function PANEL:Close()
	if (self.closing) then return end

	self.closing = true
	ix.tablet.Send("close")
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)

	if (IsValid(self.backdrop)) then
		self.backdrop:AlphaTo(0, 0.15, 0)
	end

	self:AlphaTo(0, 0.15, 0, function()
		if (IsValid(self)) then self:Remove() end
	end)
end

function PANEL:OnRemove()
	if (IsValid(self.backdrop)) then
		self.backdrop:Remove()
	end

	if (ix.tablet.panel == self) then
		ix.tablet.panel = nil
	end
end

function PANEL:Toast(text, isError)
	self.toast = {text = text, col = isError and C.danger or C.ok, die = CurTime() + 3}
end

function PANEL:ClearScreen()
	self.area:Clear()
	self.inMain = false
end

function PANEL:OnResponse(action, data)
	if (action == "sync") then
		local old = ix.tablet.state

		data.positions = old and old.positions or {}
		data.me.color = Color(data.me.color.r, data.me.color.g, data.me.color.b)
		ix.tablet.state = data

		if (data.saved) then
			self.selNote = data.saved
		elseif (data.cleared) then
			self.selNote = nil
		end

		if (data.orderPosted) then
			self.orderCompose = false
		end

		if (data.sent) then
			self.msgMode = "inbox"
			self.msgTo = nil
		end

		if (data.toast) then
			self:Toast(data.toast, false)
		end

		if (!self.inMain) then
			self:ShowMain()
		else
			self:RefreshSidebar()
			self:SwitchTab(self.tab, true)
		end
	elseif (action == "error") then
		self:Toast(data.msg or "Ошибка", true)
	elseif (action == "positions") then
		if (ix.tablet.state) then
			ix.tablet.state.positions = data.list or {}
		end
	elseif (action == "kicked") then
		self:Close()
	end
end

-- ----- Экран входа -----

function PANEL:ShowLogin()
	self:ClearScreen()

	local register = !self.hasAccount
	local char = LocalPlayer():GetCharacter()
	local faction = char and ix.faction.indices[char:GetFaction()]
	local fname = faction and faction.name or "—"
	local fcol = faction and faction.color or C.accent

	local p = self.area:Add("EditablePanel")
	p:Dock(FILL)

	p.Paint = function(_, w, h)
		-- Верхняя плашка
		Box(0, 0, w, S(24), C.panel)
		Box(0, S(24), w, 1, C.line)
		draw.SimpleText("ТОЛЬКО ДЛЯ СЛУЖЕБНОГО ПОЛЬЗОВАНИЯ", "ixTabletT", w / 2, S(12), C.warn, 1, 1)

		-- Левая часть: часы и фракция
		local lx = S(48)
		draw.SimpleText(os.date("%H:%M"), "ixTabletClock", lx, h * 0.2, C.text)
		draw.SimpleText(DateLong(), "ixTabletM", lx + S(4), h * 0.2 + S(80), C.dim)

		local sy = h * 0.2 + S(140)
		local sh = S(46)

		local shield = {
			{x = lx, y = sy}, {x = lx + sh, y = sy}, {x = lx + sh, y = sy + sh * 0.55},
			{x = lx + sh / 2, y = sy + sh * 1.1}, {x = lx, y = sy + sh * 0.55}
		}

		Poly(ColorAlpha(fcol, 60), shield)
		SoftOutline(shield, S(2), ColorAlpha(fcol, 255))

		draw.SimpleText(fname, "ixTabletM", lx + sh + S(16), sy + S(4), C.text)
		draw.SimpleText("Служебный терминал", "ixTabletS", lx + sh + S(16), sy + S(28), C.dim)

		-- Разделитель
		Box(w * 0.5, S(48), 1, h - S(96), C.line)

		draw.SimpleText("Несанкционированный доступ преследуется.", "ixTabletT", lx, h - S(24), C.dim, 0, 1)
	end

	local box = p:Add("EditablePanel")
	box:SetSize(S(320), register and S(330) or S(270))

	box.Paint = function(_, w)
		draw.SimpleText(register and "Регистрация" or "Авторизация", "ixTabletL", 0, 0, C.text)
		draw.SimpleText(register and "Создайте логин и пароль для персонажа" or "Введите данные доступа", "ixTabletS", 0, S(32), C.dim)
		Box(0, S(60), S(44), 1, C.accent)
	end

	p.PerformLayout = function(_, w, h)
		box:SetPos(w * 0.5 + (w * 0.5 - box:GetWide()) / 2, (h - box:GetTall()) / 2 + S(12))
	end

	local login = box:Add("DTextEntry")
	login:SetPos(0, S(80))
	login:SetSize(S(320), S(42))
	StyleEntry(login, "ixTabletM")
	login.ph = "Логин"

	local pass = box:Add("DTextEntry")
	pass:SetPos(0, S(132))
	pass:SetSize(S(320), S(42))
	StyleEntry(pass, "ixTabletM")
	pass.isPassword = true
	pass.ph = "Пароль"

	local y = S(188)

	if (register) then
		local hint = Label(box, "Логин: 3–24 символа (латиница, цифры, _ . -).\nПароль: от 4 символов. Данные привязаны\nк вашему персонажу.", "ixTabletT", C.dim)
		hint:SetPos(0, y)
		y = y + S(58)
	end

	local go = box:Add("ixTabletButton")
	go:SetPos(0, y + S(8))
	go:SetSize(S(320), S(42))
	go:SetLabel(register and "Зарегистрироваться" or "Войти")

	local function Submit()
		ix.tablet.Send(register and "register" or "login", {login = login:GetValue(), pass = pass:GetValue()})
	end

	go.DoClick = Submit
	login.OnEnter = function() pass:RequestFocus() end
	pass.OnEnter = Submit

	login:RequestFocus()
end

-- ----- Экран загрузки после входа -----

function PANEL:StartBoot()
	local sw, sh = self.screen:GetSize()
	local boot = self.screen:Add("EditablePanel")

	boot:SetPos(0, S(22))
	boot:SetSize(sw, sh - S(22))
	boot:SetZPos(100)
	boot.start = CurTime()

	local steps = {"Проверка ключа доступа…", "Синхронизация данных…", "Загрузка профиля…", "Готово"}

	boot.Paint = function(s, w, h)
		local t = CurTime() - s.start
		local prog = math.Clamp(t / 1.3, 0, 1)
		local cx, cy = w / 2, h / 2 - S(24)

		Box(0, 0, w, h, C.bg)
		Ring(cx, cy, S(34), ColorAlpha(C.accent, 70))
		Circle(cx, cy, S(5), C.accent)

		-- Дуга спиннера: много коротких сегментов со сглаженной толщиной.
		for i = 0, 29 do
			local a1, a2 = t * 4 + i * 0.04, t * 4 + (i + 1) * 0.04

			SoftLine(cx + math.cos(a1) * S(34), cy + math.sin(a1) * S(34), cx + math.cos(a2) * S(34), cy + math.sin(a2) * S(34), S(2), ColorAlpha(C.accent, 255 - i * 8))
		end

		local bw = S(240)
		Outline(cx - bw / 2, cy + S(62), bw, S(6), C.line)
		Box(cx - bw / 2 + 1, cy + S(63), (bw - 2) * prog, S(4), C.accent)

		draw.SimpleText(steps[math.min(#steps, 1 + math.floor(prog * #steps))], "ixTabletS", cx, cy + S(84), C.dim, 1, 1)
	end

	boot.Think = function(s)
		if (CurTime() - s.start > 1.5 and !s.fading) then
			s.fading = true
			s:AlphaTo(0, 0.3, 0, function()
				if (IsValid(s)) then s:Remove() end
			end)
		end
	end
end

-- ----- Главный экран -----

function PANEL:ShowMain()
	self:ClearScreen()
	self.inMain = true

	local top = self.area:Add("EditablePanel")
	top:Dock(TOP)
	top:SetTall(S(46))
	top.Paint = function(_, w, h)
		local me = ix.tablet.state.me

		Box(0, 0, w, h, C.panel)
		Box(0, h - 1, w, 1, C.line)
		Circle(S(20), h / 2, S(4), me.color, 32)
		draw.SimpleText(me.factionName, "ixTabletS", S(32), h / 2, C.text, 0, 1)
		draw.SimpleText(me.rankName .. " — " .. me.name, "ixTabletS", w - S(110), h / 2, C.dim, TEXT_ALIGN_RIGHT, 1)
	end

	local out = top:Add("ixTabletButton")
	out:SetSize(S(80), S(28))
	out:SetLabel("Выйти")
	out.col = C.dim
	out.DoClick = function() self:Close() end
	top.PerformLayout = function(_, w, h) out:SetPos(w - S(92), (h - S(28)) / 2) end

	self.side = self.area:Add("EditablePanel")
	self.side:Dock(LEFT)
	self.side:SetWide(S(168))
	self.side.Paint = function(_, w, h)
		Box(w - 1, 0, 1, h, C.line)
	end

	self:RefreshSidebar()

	self.content = self.area:Add("EditablePanel")
	self.content:Dock(FILL)
	self.content:DockPadding(S(16), S(14), S(16), S(14))

	self:SwitchTab(self.tab, true)

	if (!self.booted) then
		self.booted = true
		self:StartBoot()
	end
end

function PANEL:RefreshSidebar()
	local st = ix.tablet.state
	self.side:Clear()

	local tabs = {
		{"home", "Главная", "home"},
		{"roster", "Состав", "people"},
		{"orders", "Приказы", "flag"},
		{"messages", "Сообщения", "mail"},
		{"notes", "Записки", "doc"},
		{"map", "Карта", "map"}
	}

	if (st.me.canManage) then
		tabs[#tabs + 1] = {"log", "Журнал", "log"}
	end

	tabs[#tabs + 1] = {"profile", "Профиль", "user"}

	for _, t in ipairs(tabs) do
		local b = self.side:Add("DButton")
		b:SetText("")
		b:Dock(TOP)
		b:SetTall(S(44))
		b.hover = 0
		b.bar = self.tab == t[1] and 1 or 0

		b.Think = function(s)
			s.hover = Lerp(FrameTime() * 12, s.hover, s:IsHovered() and 1 or 0)
			s.bar = Lerp(FrameTime() * 12, s.bar, self.tab == t[1] and 1 or 0)
		end

		b.Paint = function(s, w, h)
			Box(0, 0, w - 1, h, ColorAlpha(C.accent, s.bar * 18 + s.hover * 10))
			Box(0, h * (1 - s.bar) / 2, S(3), h * s.bar, C.accent)

			local col = s.bar > 0.5 and C.text or C.dim
			UI.Icon(t[3], S(18), h / 2 - S(9), S(18), s.bar > 0.5 and C.accent or C.dim)
			draw.SimpleText(t[2], "ixTabletS", S(48), h / 2, col, 0, 1)

			if (t[1] == "messages" and ix.tablet.state.unread > 0) then
				local bx = w - S(26)

				Circle(bx, h / 2, S(9), C.warn)
				draw.SimpleText(ix.tablet.state.unread, "ixTabletT", bx, h / 2, Color(20, 20, 20), 1, 1)
			end
		end

		b.DoClick = function()
			if (self.tab != t[1]) then
				self:SwitchTab(t[1])
			end
		end
	end
end

function PANEL:SwitchTab(name, refresh)
	if (name == "log" and !ix.tablet.state.me.canManage) then
		name = "home"
	end

	self.tab = name
	self.content:Clear()

	local p = self.content:Add("EditablePanel")
	p:Dock(FILL)
	self["Tab_" .. name](self, p)

	if (!refresh) then
		p:SetAlpha(0)
		p:AlphaTo(255, 0.18, 0)
	end
end

-- ----- Вкладка: Главная -----

function PANEL:Tab_home(p)
	local st = ix.tablet.state
	local me = st.me

	local top = p:Add("EditablePanel")
	top:Dock(TOP)
	top:SetTall(S(104))
	top:DockMargin(0, 0, 0, S(10))

	top.Paint = function(_, w, h)
		Box(0, 0, w, h, C.panel)
		Outline(0, 0, w, h, C.line)
		Box(0, 0, S(3), h, me.color)

		draw.SimpleText(Greeting() .. ",", "ixTabletS", S(110), S(16), C.dim)
		draw.SimpleText(me.name, "ixTabletL", S(110), S(34), C.text)
		draw.SimpleText(me.rankName .. "  |  " .. me.factionName, "ixTabletS", S(110), S(70), C.accent)

		Chevrons(w - S(64), S(20), me.rank, C.accent, S(34))
		draw.SimpleText("звание " .. me.rank .. "/" .. #st.ranks, "ixTabletT", w - S(47), h - S(14), C.dim, 1, 1)
	end

	local av = Avatar(top, me.model, S(76))
	av:SetPos(S(18), S(14))

	local stats = p:Add("EditablePanel")
	stats:Dock(TOP)
	stats:SetTall(S(64))
	stats:DockMargin(0, 0, 0, S(10))

	local items = {
		{"В СОСТАВЕ", st.stats.total, C.text, "roster"},
		{"НА СВЯЗИ", st.stats.online, C.ok, "roster"},
		{"СООБЩЕНИЙ", st.unread, st.unread > 0 and C.warn or C.dim, "messages"},
		{"ПРИКАЗОВ", #st.orders, C.accent, "orders"}
	}

	local btns = {}

	for i, it in ipairs(items) do
		local b = stats:Add("DButton")
		b:SetText("")
		b.hover = 0

		b.Think = function(s) s.hover = Lerp(FrameTime() * 12, s.hover, s:IsHovered() and 1 or 0) end

		b.Paint = function(s, w, h)
			Box(0, 0, w, h, ColorAlpha(C.accent, s.hover * 12))
			Box(0, 0, w, h, C.panel)
			Box(0, 0, w, h, ColorAlpha(C.accent, s.hover * 14))
			Outline(0, 0, w, h, s.hover > 0.5 and C.accent or C.line)
			draw.SimpleText(it[1], "ixTabletT", S(12), S(14), C.dim, 0, 1)
			draw.SimpleText(it[2], "ixTabletXL", S(12), h - S(8), it[3], 0, TEXT_ALIGN_BOTTOM)
		end

		b.DoClick = function() self:SwitchTab(it[4]) end
		btns[i] = b
	end

	stats.PerformLayout = function(_, w, h)
		local gap = S(8)
		local bw = (w - gap * 3) / 4

		for i, b in ipairs(btns) do
			b:SetPos((i - 1) * (bw + gap), 0)
			b:SetSize(bw, h)
		end
	end

	local row = p:Add("EditablePanel")
	row:Dock(FILL)

	local left = Card(row, "ПОСЛЕДНИЕ ПРИКАЗЫ")
	left:Dock(LEFT)

	local right = Card(row, "НА СВЯЗИ")
	right:Dock(FILL)
	right:DockMargin(S(10), 0, 0, 0)

	row.PerformLayout = function(_, w) left:SetWide(w * 0.58) end

	local orders = SortOrders(st.orders)

	if (#orders == 0) then
		local l = Label(left, "Активных приказов нет", "ixTabletS", C.dim)
		l:Dock(TOP)
	end

	for i = 1, math.min(3, #orders) do
		local o = orders[i]
		local r = left:Add("DButton")

		r:SetText("")
		r:Dock(TOP)
		r:SetTall(S(50))
		r:DockMargin(0, 0, 0, S(6))
		r.hover = 0

		r.Think = function(s) s.hover = Lerp(FrameTime() * 12, s.hover, s:IsHovered() and 1 or 0) end

		r.Paint = function(s, w, h)
			Box(0, 0, w, h, ColorAlpha(C.accent, s.hover * 14))
			Box(0, 0, S(3), h, PR_COL[o.priority] or C.dim)

			local tx = w - S(8)
			if (o.pinned) then tx = Pill(tx, S(7), "ЗАКРЕПЛЁН", C.accent) end
			if (o.priority > 1) then Pill(tx, S(7), PR_TAG[o.priority], PR_COL[o.priority]) end

			draw.SimpleText(Trunc(o.title, w - S(150), "ixTabletS"), "ixTabletS", S(12), S(14), C.text, 0, 1)
			draw.SimpleText(Trunc(o.text, w - S(24), "ixTabletT"), "ixTabletT", S(12), S(32), C.dim, 0, 1)
			draw.SimpleText(Ago(o.time), "ixTabletT", w - S(8), h - S(10), C.dim, TEXT_ALIGN_RIGHT, 1)
		end

		r.DoClick = function() self:SwitchTab("orders") end
	end

	local scroll = right:Add("DScrollPanel")
	scroll:Dock(FILL)
	StyleScroll(scroll)

	local online = {}

	for _, e in ipairs(st.roster) do
		if (e.online) then online[#online + 1] = e end
	end

	table.sort(online, function(a, b) return a.rank > b.rank end)

	if (#online == 0) then
		local l = Label(scroll, "Никого нет на связи", "ixTabletS", C.dim)
		l:Dock(TOP)
	end

	for _, e in ipairs(online) do
		local r = scroll:Add("EditablePanel")

		r:Dock(TOP)
		r:SetTall(S(36))
		r:DockMargin(0, 0, S(6), 0)

		r.Paint = function(_, w, h)
			Circle(S(6), h / 2, S(4), C.ok, 32)
			draw.SimpleText(Trunc(e.name, w - S(50), "ixTabletS"), "ixTabletS", S(18), h / 2 - S(7), C.text, 0, 1)
			draw.SimpleText(st.ranks[e.rank] or "?", "ixTabletT", S(18), h / 2 + S(9), C.dim, 0, 1)
			Chevrons(w - S(24), h / 2 - S(8), math.min(e.rank, 3), C.dim, S(14))
		end
	end
end

-- ----- Вкладка: Профиль -----

function PANEL:Tab_profile(p)
	local st = ix.tablet.state
	local me = st.me

	PageHeader(p, "Профиль", "логин: " .. me.login .. "   |   ID: " .. tostring(me.id))

	local info = p:Add("EditablePanel")
	info:Dock(TOP)
	info:SetTall(S(104))
	info:DockMargin(0, 0, 0, S(10))

	info.Paint = function(_, w, h)
		Box(0, 0, w, h, C.panel)
		Outline(0, 0, w, h, C.line)

		draw.SimpleText(me.name, "ixTabletL", S(110), S(10), C.text)
		draw.SimpleText(me.rankName .. "  (" .. me.rank .. "/" .. #st.ranks .. ")", "ixTabletS", S(110), S(44), C.accent)
		draw.SimpleText("В составе с " .. os.date("%d.%m.%Y", me.since), "ixTabletT", S(110), S(66), C.dim)
		draw.SimpleText("Доступ: " .. (me.canManage and "командный состав" or "стандартный"), "ixTabletT", S(110), S(82), C.dim)

		Chevrons(w - S(60), S(18), me.rank, C.accent, S(32))
	end

	local av = Avatar(info, me.model, S(76))
	av:SetPos(S(18), S(14))

	-- Смена пароля
	local pw = Card(p, "СМЕНА ПАРОЛЯ")
	pw:Dock(BOTTOM)
	pw:SetTall(S(92))
	pw:DockMargin(0, S(10), 0, 0)

	local row = pw:Add("EditablePanel")
	row:Dock(TOP)
	row:SetTall(S(34))

	local old = row:Add("DTextEntry")
	old:Dock(LEFT)
	old:SetWide(S(200))
	StyleEntry(old)
	old.isPassword = true
	old.ph = "Текущий пароль"

	local new = row:Add("DTextEntry")
	new:Dock(LEFT)
	new:DockMargin(S(8), 0, 0, 0)
	new:SetWide(S(200))
	StyleEntry(new)
	new.isPassword = true
	new.ph = "Новый пароль"

	local go = row:Add("ixTabletButton")
	go:Dock(FILL)
	go:DockMargin(S(8), 0, 0, 0)
	go:SetLabel("Изменить")
	go.DoClick = function()
		ix.tablet.Send("passwd", {old = old:GetValue(), new = new:GetValue()})
	end

	-- Выговоры / поощрения
	local mode = self.profileList or "rep"
	local tog = p:Add("EditablePanel")
	tog:Dock(TOP)
	tog:SetTall(S(30))
	tog:DockMargin(0, 0, 0, S(8))

	local tRep = tog:Add("ixTabletToggle")
	tRep:Dock(LEFT)
	tRep:SetWide(S(170))
	tRep:SetLabel("Выговоры (" .. #me.reprimands .. ")")
	tRep.col = C.danger
	tRep.on = mode == "rep"

	local tCom = tog:Add("ixTabletToggle")
	tCom:Dock(LEFT)
	tCom:DockMargin(S(8), 0, 0, 0)
	tCom:SetWide(S(170))
	tCom:SetLabel("Поощрения (" .. #me.commends .. ")")
	tCom.col = C.ok
	tCom.on = mode == "com"

	tRep.DoClick = function() self.profileList = "rep" self:SwitchTab("profile", true) end
	tCom.DoClick = function() self.profileList = "com" self:SwitchTab("profile", true) end

	local scroll = p:Add("DScrollPanel")
	scroll:Dock(FILL)
	StyleScroll(scroll)

	if (mode == "rep") then
		AddEntries(scroll, me.reprimands, C.danger, "Выговоров нет")
	else
		AddEntries(scroll, me.commends, C.ok, "Поощрений пока нет")
	end
end

-- ----- Вкладка: Состав -----

function PANEL:Tab_roster(p)
	local st = ix.tablet.state

	PageHeader(p, "Личный состав", st.stats.total .. " чел.   |   на связи: " .. st.stats.online)

	local left = p:Add("EditablePanel")
	left:Dock(LEFT)
	left:SetWide(S(300))
	left:DockMargin(0, 0, S(14), 0)

	local search = left:Add("DTextEntry")
	search:Dock(TOP)
	search:SetTall(S(32))
	search:DockMargin(0, 0, S(8), S(6))
	StyleEntry(search)
	search.ph = "Поиск по имени"
	search:SetText(self.rosterSearch or "")

	local filt = left:Add("EditablePanel")
	filt:Dock(TOP)
	filt:SetTall(S(28))
	filt:DockMargin(0, 0, S(8), S(6))

	local fAll = filt:Add("ixTabletToggle")
	fAll:Dock(LEFT)
	fAll:SetWide(S(136))
	fAll:SetLabel("Все")
	fAll.on = !self.rosterOnline

	local fOn = filt:Add("ixTabletToggle")
	fOn:Dock(FILL)
	fOn:DockMargin(S(6), 0, 0, 0)
	fOn:SetLabel("На связи")
	fOn.col = C.ok
	fOn.on = self.rosterOnline and true or false

	local list = left:Add("DScrollPanel")
	list:Dock(FILL)
	StyleScroll(list)

	local detail = p:Add("EditablePanel")
	detail:Dock(FILL)

	local function Detail()
		detail:Clear()

		local e

		for _, v in ipairs(st.roster) do
			if (v.id == self.selRoster) then e = v break end
		end

		if (!e) then
			local l = Label(detail, "Выберите бойца из списка", "ixTabletS", C.dim)
			l:Dock(TOP)

			return
		end

		local me = st.me
		local manage = me.canManage and e.id != me.id

		local head = detail:Add("EditablePanel")
		head:Dock(TOP)
		head:SetTall(S(84))

		head.Paint = function(_, w)
			draw.SimpleText(Trunc(e.name, w - S(170), "ixTabletL"), "ixTabletL", S(88), S(2), C.text)
			draw.SimpleText((st.ranks[e.rank] or "?") .. "  (" .. e.rank .. "/" .. #st.ranks .. ")", "ixTabletS", S(88), S(34), C.accent)
			draw.SimpleText("В составе с " .. os.date("%d.%m.%Y", e.since or 0) .. "   |   ID: " .. tostring(e.id), "ixTabletT", S(88), S(54), C.dim)
			draw.SimpleText(e.online and "На связи" or ("Не в сети  |  был(а) в сети: " .. (e.seen and Ago(e.seen) or "давно")), "ixTabletT", S(88), S(68), e.online and C.ok or C.dim)

			Chevrons(w - S(40), S(8), e.rank, C.accent, S(26))
		end

		local av = Avatar(head, e.model, S(76))
		av:SetPos(0, 0)

		if (e.id != me.id) then
			local bar = detail:Add("EditablePanel")
			bar:Dock(TOP)
			bar:SetTall(S(32))
			bar:DockMargin(0, S(6), 0, 0)

			if (manage) then
				local up = bar:Add("ixTabletButton")
				up:Dock(LEFT)
				up:SetWide(S(100))
				up:SetLabel("Повысить")
				up:SetEnabled(e.rank < #st.ranks)
				up.DoClick = function() ix.tablet.Send("rank", {id = e.id, dir = 1}) end

				local down = bar:Add("ixTabletButton")
				down:Dock(LEFT)
				down:DockMargin(S(6), 0, 0, 0)
				down:SetWide(S(100))
				down:SetLabel("Понизить")
				down.col = C.danger
				down:SetEnabled(e.rank > 1)
				down.DoClick = function() ix.tablet.Send("rank", {id = e.id, dir = -1}) end
			end

			local msg = bar:Add("ixTabletButton")
			msg:Dock(RIGHT)
			msg:SetWide(S(100))
			msg:SetLabel("Написать")
			msg.col = C.info
			msg.DoClick = function()
				self.msgMode = "compose"
				self.msgTo = e.id
				self:SwitchTab("messages")
			end
		end

		local reason

		if (manage) then
			reason = detail:Add("DTextEntry")
			reason:Dock(TOP)
			reason:DockMargin(0, S(8), 0, 0)
			reason:SetTall(S(32))
			StyleEntry(reason)
			reason.ph = "Причина (выговор / поощрение)"

			local act = detail:Add("EditablePanel")
			act:Dock(TOP)
			act:SetTall(S(32))
			act:DockMargin(0, S(6), 0, 0)

			local rep = act:Add("ixTabletButton")
			rep:Dock(LEFT)
			rep:SetWide(S(140))
			rep:SetLabel("Выдать выговор")
			rep.col = C.danger
			rep.DoClick = function() ix.tablet.Send("reprimand", {id = e.id, text = reason:GetValue()}) end

			local com = act:Add("ixTabletButton")
			com:Dock(LEFT)
			com:DockMargin(S(6), 0, 0, 0)
			com:SetWide(S(140))
			com:SetLabel("Поощрить")
			com.col = C.ok
			com.DoClick = function() ix.tablet.Send("commend", {id = e.id, text = reason:GetValue()}) end

			local reset = act:Add("ixTabletButton")
			reset:Dock(RIGHT)
			reset:SetWide(S(110))
			reset:SetLabel("Сброс доступа")
			reset.col = C.dim
			reset.DoClick = function()
				Derma_Query("Сбросить логин и пароль бойца «" .. e.name .. "»? Он зарегистрирует новые данные при следующем входе.", "Сброс доступа", "Сбросить", function()
					ix.tablet.Send("resetAccount", {id = e.id})
				end, "Отмена")
			end
		end

		local mode = self.rosterList or "rep"
		local tog = detail:Add("EditablePanel")
		tog:Dock(TOP)
		tog:SetTall(S(28))
		tog:DockMargin(0, S(10), 0, S(6))

		local tRep = tog:Add("ixTabletToggle")
		tRep:Dock(LEFT)
		tRep:SetWide(S(150))
		tRep:SetLabel("Выговоры (" .. e.count .. ")")
		tRep.col = C.danger
		tRep.on = mode == "rep"

		local tCom = tog:Add("ixTabletToggle")
		tCom:Dock(LEFT)
		tCom:DockMargin(S(6), 0, 0, 0)
		tCom:SetWide(S(150))
		tCom:SetLabel("Поощрения (" .. e.commendCount .. ")")
		tCom.col = C.ok
		tCom.on = mode == "com"

		tRep.DoClick = function() self.rosterList = "rep" Detail() end
		tCom.DoClick = function() self.rosterList = "com" Detail() end

		if (me.canManage or e.id == me.id) then
			local scroll = detail:Add("DScrollPanel")
			scroll:Dock(FILL)
			StyleScroll(scroll)

			if (mode == "rep") then
				AddEntries(scroll, e.reprimands, C.danger, "Выговоров нет", manage and function(index)
					ix.tablet.Send("unreprimand", {id = e.id, index = index})
				end or nil)
			else
				AddEntries(scroll, e.commends, C.ok, "Поощрений нет", manage and function(index)
					ix.tablet.Send("uncommend", {id = e.id, index = index})
				end or nil)
			end
		end
	end

	local function Fill()
		list:Clear()

		local q = Lower(self.rosterSearch or "")
		local entries = {}

		for _, e in ipairs(st.roster) do
			if ((!self.rosterOnline or e.online) and (q == "" or string.find(Lower(e.name), q, 1, true))) then
				entries[#entries + 1] = e
			end
		end

		table.sort(entries, function(a, b)
			if (a.rank != b.rank) then return a.rank > b.rank end
			return a.name < b.name
		end)

		for _, e in ipairs(entries) do
			local row = list:Add("DButton")

			row:SetText("")
			row:Dock(TOP)
			row:SetTall(S(46))
			row:DockMargin(0, 0, S(8), S(4))
			row.hover = 0

			row.Think = function(s) s.hover = Lerp(FrameTime() * 12, s.hover, s:IsHovered() and 1 or 0) end

			row.Paint = function(s, w, h)
				local sel = self.selRoster == e.id

				Box(0, 0, w, h, ColorAlpha(C.accent, sel and 28 or s.hover * 14))
				Outline(0, 0, w, h, sel and C.accent or C.line)

				Circle(S(14), h / 2, S(4), e.online and C.ok or C.line, 32)
				draw.SimpleText(Trunc(e.name, w - S(110), "ixTabletS"), "ixTabletS", S(28), h / 2 - S(8), C.text, 0, 1)
				local rankText = st.ranks[e.rank] or "?"

				draw.SimpleText(rankText, "ixTabletT", S(28), h / 2 + S(9), C.dim, 0, 1)

				-- Подпись для игроков, которых нет на сервере.
				if (!e.online) then
					surface.SetFont("ixTabletT")
					local rw = surface.GetTextSize(rankText)

					draw.SimpleText("·  Не в сети", "ixTabletT", S(28) + rw + S(6), h / 2 + S(9), C.danger, 0, 1)
				end

				Chevrons(w - S(26), h / 2 - S(10), math.min(e.rank, 4), C.dim, S(14))

				if (e.count > 0) then
					draw.SimpleText("В:" .. e.count, "ixTabletT", w - S(40), h / 2 - S(6), C.danger, TEXT_ALIGN_RIGHT, 1)
				end

				if (e.commendCount > 0) then
					draw.SimpleText("П:" .. e.commendCount, "ixTabletT", w - S(40), h / 2 + S(8), C.ok, TEXT_ALIGN_RIGHT, 1)
				end
			end

			row.DoClick = function()
				self.selRoster = e.id
				Detail()
			end
		end
	end

	search.OnChange = function()
		self.rosterSearch = search:GetValue()
		Fill()
	end

	fAll.DoClick = function()
		self.rosterOnline = false
		fAll.on, fOn.on = true, false
		Fill()
	end

	fOn.DoClick = function()
		self.rosterOnline = true
		fAll.on, fOn.on = false, true
		Fill()
	end

	Fill()
	Detail()
end

-- ----- Вкладка: Приказы -----

function PANEL:Tab_orders(p)
	local st = ix.tablet.state
	local head = PageHeader(p, "Приказы и объявления", #st.orders .. " актуальных")

	if (st.me.canManage) then
		local nb = head:Add("ixTabletButton")
		nb:Dock(RIGHT)
		nb:DockMargin(0, S(6), 0, S(8))
		nb:SetWide(S(150))
		nb:SetLabel(self.orderCompose and "Отмена" or "+ Новый приказ")
		nb.DoClick = function()
			self.orderCompose = !self.orderCompose
			self:SwitchTab("orders", true)
		end

		head.subOffset = S(166)
	end

	if (self.orderCompose and st.me.canManage) then
		local card = Card(p, "НОВЫЙ ПРИКАЗ")
		card:Dock(TOP)
		card:SetTall(S(212))
		card:DockMargin(0, 0, 0, S(10))

		local title = card:Add("DTextEntry")
		title:Dock(TOP)
		title:SetTall(S(32))
		StyleEntry(title)
		title.ph = "Заголовок приказа"

		local body = card:Add("DTextEntry")
		body:Dock(TOP)
		body:SetTall(S(70))
		body:DockMargin(0, S(6), 0, 0)
		body:SetMultiline(true)
		StyleEntry(body)
		body.ph = "Текст приказа…"

		local row = card:Add("EditablePanel")
		row:Dock(TOP)
		row:SetTall(S(32))
		row:DockMargin(0, S(8), 0, 0)

		local pr, pinned = 1, false
		local togs = {}

		for i, name in ipairs(PR_NAME) do
			local t = row:Add("ixTabletToggle")
			t:Dock(LEFT)
			t:SetWide(S(92))
			t:DockMargin(0, 0, S(6), 0)
			t:SetLabel(name)
			t.col = PR_COL[i] == C.dim and C.accent or PR_COL[i]
			t.on = i == pr
			togs[i] = t

			t.DoClick = function()
				pr = i

				for k, b in ipairs(togs) do b.on = k == pr end
			end
		end

		local pin = row:Add("ixTabletToggle")
		pin:Dock(LEFT)
		pin:SetWide(S(110))
		pin:SetLabel("Закрепить")
		pin.DoClick = function()
			pinned = !pinned
			pin.on = pinned
		end

		local pub = row:Add("ixTabletButton")
		pub:Dock(RIGHT)
		pub:SetWide(S(130))
		pub:SetLabel("Опубликовать")
		pub.DoClick = function()
			ix.tablet.Send("order", {title = title:GetValue(), text = body:GetValue(), priority = pr, pinned = pinned})
		end
	end

	local scroll = p:Add("DScrollPanel")
	scroll:Dock(FILL)
	StyleScroll(scroll)

	local orders = SortOrders(st.orders)

	if (#orders == 0) then
		local l = Label(scroll, "Активных приказов нет", "ixTabletS", C.dim)
		l:Dock(TOP)
	end

	for _, o in ipairs(orders) do
		local lines = Wrap(o.text, S(560), "ixTabletS")
		local row = scroll:Add("EditablePanel")

		row:Dock(TOP)
		row:DockMargin(0, 0, S(8), S(8))
		row:SetTall(S(58) + #lines * S(18))

		row.Paint = function(_, w, h)
			Box(0, 0, w, h, C.panel)
			Outline(0, 0, w, h, C.line)
			Box(0, 0, S(4), h, PR_COL[o.priority] or C.dim)

			draw.SimpleText(Trunc(o.title, w - S(330), "ixTabletM"), "ixTabletM", S(16), S(10), C.text)
			draw.SimpleText(o.by .. " — " .. DateStr(o.time), "ixTabletT", S(16), S(34), C.dim)

			for i, l in ipairs(lines) do
				draw.SimpleText(l, "ixTabletS", S(16), S(54) + (i - 1) * S(18), C.text)
			end

			local tx = w - (st.me.canManage and S(176) or S(12))
			if (o.pinned) then tx = Pill(tx, S(10), "ЗАКРЕПЛЁН", C.accent) end
			if (o.priority > 1) then Pill(tx, S(10), PR_TAG[o.priority], PR_COL[o.priority]) end
		end

		if (st.me.canManage) then
			local del = row:Add("ixTabletButton")
			del:SetSize(S(64), S(24))
			del:SetLabel("Удалить")
			del.col = C.danger
			del.DoClick = function() ix.tablet.Send("orderDel", {id = o.id}) end

			local pin = row:Add("ixTabletButton")
			pin:SetSize(S(96), S(24))
			pin:SetLabel(o.pinned and "Открепить" or "Закрепить")
			pin.col = C.dim
			pin.DoClick = function() ix.tablet.Send("orderPin", {id = o.id}) end

			row.PerformLayout = function(_, w)
				del:SetPos(w - S(72), S(8))
				pin:SetPos(w - S(72) - S(102), S(8))
			end
		end
	end
end

-- ----- Вкладка: Сообщения -----

function PANEL:Tab_messages(p)
	local st = ix.tablet.state

	PageHeader(p, "Сообщения", st.unread > 0 and (st.unread .. " непрочитанных") or "новых нет")

	local mode = self.msgMode or "inbox"

	local left = p:Add("EditablePanel")
	left:Dock(LEFT)
	left:SetWide(S(250))
	left:DockMargin(0, 0, S(14), 0)

	local tabs = left:Add("EditablePanel")
	tabs:Dock(TOP)
	tabs:SetTall(S(30))
	tabs:DockMargin(0, 0, S(8), S(8))

	local tIn = tabs:Add("ixTabletToggle")
	tIn:Dock(LEFT)
	tIn:SetWide(S(116))
	tIn:SetLabel("Входящие")
	tIn.on = mode == "inbox"
	tIn.DoClick = function() self.msgMode = "inbox" self:SwitchTab("messages", true) end

	local tNew = tabs:Add("ixTabletToggle")
	tNew:Dock(FILL)
	tNew:DockMargin(S(6), 0, 0, 0)
	tNew:SetLabel("Написать")
	tNew.on = mode == "compose"
	tNew.DoClick = function() self.msgMode = "compose" self:SwitchTab("messages", true) end

	local right = p:Add("EditablePanel")
	right:Dock(FILL)

	if (mode == "inbox") then
		local inbox = table.Copy(st.inbox)
		table.sort(inbox, function(a, b) return a.time > b.time end)

		local list = left:Add("DScrollPanel")
		list:Dock(FILL)
		StyleScroll(list)

		local cur

		if (#inbox == 0) then
			local l = Label(list, "Входящих нет", "ixTabletS", C.dim)
			l:Dock(TOP)
		end

		for _, m in ipairs(inbox) do
			if (m.id == self.selMsg) then cur = m end

			local row = list:Add("DButton")

			row:SetText("")
			row:Dock(TOP)
			row:SetTall(S(54))
			row:DockMargin(0, 0, S(8), S(4))
			row.hover = 0

			row.Think = function(s) s.hover = Lerp(FrameTime() * 12, s.hover, s:IsHovered() and 1 or 0) end

			row.Paint = function(s, w, h)
				local sel = self.selMsg == m.id

				Box(0, 0, w, h, ColorAlpha(C.accent, sel and 28 or s.hover * 14))
				Outline(0, 0, w, h, sel and C.accent or C.line)

				if (!m.read) then Circle(S(12), S(14), S(4), C.warn, 32) end

				draw.SimpleText(Trunc(m.fromName, w - S(24), "ixTabletS"), "ixTabletS", S(24), S(14), m.read and C.dim or C.text, 0, 1)
				draw.SimpleText(Trunc(m.text, w - S(20), "ixTabletT"), "ixTabletT", S(12), S(32), C.dim, 0, 1)
				draw.SimpleText(Ago(m.time), "ixTabletT", S(12), S(46), C.dim, 0, 1)
			end

			row.DoClick = function()
				self.selMsg = m.id

				if (!m.read) then
					ix.tablet.Send("msgRead", {id = m.id})
				else
					self:SwitchTab("messages", true)
				end
			end
		end

		if (!cur) then
			local l = Label(right, "Выберите сообщение", "ixTabletS", C.dim)
			l:Dock(TOP)

			return
		end

		local head = right:Add("EditablePanel")
		head:Dock(TOP)
		head:SetTall(S(52))
		head.Paint = function(_, w, h)
			draw.SimpleText(cur.fromName, "ixTabletL", 0, S(2), C.text)
			draw.SimpleText(DateStr(cur.time), "ixTabletT", 0, S(34), C.dim)
			Box(0, h - 1, w, 1, C.line)
		end

		local bar = right:Add("EditablePanel")
		bar:Dock(BOTTOM)
		bar:SetTall(S(32))
		bar:DockMargin(0, S(8), 0, 0)

		local reply = bar:Add("ixTabletButton")
		reply:Dock(LEFT)
		reply:SetWide(S(110))
		reply:SetLabel("Ответить")
		reply.DoClick = function()
			self.msgMode = "compose"
			self.msgTo = cur.from
			self:SwitchTab("messages", true)
		end

		local del = bar:Add("ixTabletButton")
		del:Dock(RIGHT)
		del:SetWide(S(100))
		del:SetLabel("Удалить")
		del.col = C.danger
		del.DoClick = function()
			self.selMsg = nil
			ix.tablet.Send("msgDel", {id = cur.id})
		end

		local scroll = right:Add("DScrollPanel")
		scroll:Dock(FILL)
		scroll:DockMargin(0, S(10), 0, 0)
		StyleScroll(scroll)

		local lines = Wrap(cur.text, S(420), "ixTabletS")
		local body = scroll:Add("EditablePanel")

		body:Dock(TOP)
		body:SetTall(#lines * S(20) + S(10))
		body.Paint = function()
			for i, l in ipairs(lines) do
				draw.SimpleText(l, "ixTabletS", 0, (i - 1) * S(20), C.text)
			end
		end

		return
	end

	-- Режим "Написать": выбор получателя + текст
	local search = left:Add("DTextEntry")
	search:Dock(TOP)
	search:SetTall(S(30))
	search:DockMargin(0, 0, S(8), S(6))
	StyleEntry(search)
	search.ph = "Поиск получателя"

	local list = left:Add("DScrollPanel")
	list:Dock(FILL)
	StyleScroll(list)

	local function Fill()
		list:Clear()

		local q = Lower(search:GetValue())
		local entries = {}

		for _, e in ipairs(st.roster) do
			if (e.id != st.me.id and (q == "" or string.find(Lower(e.name), q, 1, true))) then
				entries[#entries + 1] = e
			end
		end

		table.sort(entries, function(a, b) return a.name < b.name end)

		for _, e in ipairs(entries) do
			local row = list:Add("DButton")

			row:SetText("")
			row:Dock(TOP)
			row:SetTall(S(38))
			row:DockMargin(0, 0, S(8), S(4))
			row.hover = 0

			row.Think = function(s) s.hover = Lerp(FrameTime() * 12, s.hover, s:IsHovered() and 1 or 0) end

			row.Paint = function(s, w, h)
				local sel = self.msgTo == e.id

				Box(0, 0, w, h, ColorAlpha(C.accent, sel and 28 or s.hover * 14))
				Outline(0, 0, w, h, sel and C.accent or C.line)
				Circle(S(12), h / 2, S(4), e.online and C.ok or C.line, 32)
				draw.SimpleText(Trunc(e.name, w - S(30), "ixTabletS"), "ixTabletS", S(24), h / 2 - S(6), C.text, 0, 1)
				draw.SimpleText(st.ranks[e.rank] or "?", "ixTabletT", S(24), h / 2 + S(9), C.dim, 0, 1)
			end

			row.DoClick = function() self.msgTo = e.id end
		end
	end

	search.OnChange = Fill
	Fill()

	local target

	for _, e in ipairs(st.roster) do
		if (e.id == self.msgTo) then target = e end
	end

	local to = right:Add("EditablePanel")
	to:Dock(TOP)
	to:SetTall(S(34))
	to.Paint = function(_, w, h)
		local t

		for _, e in ipairs(st.roster) do
			if (e.id == self.msgTo) then t = e end
		end

		draw.SimpleText("Кому:", "ixTabletS", 0, h / 2, C.dim, 0, 1)
		draw.SimpleText(t and t.name or "выберите получателя слева", "ixTabletM", S(52), h / 2, t and C.text or C.dim, 0, 1)
	end

	local bar = right:Add("EditablePanel")
	bar:Dock(BOTTOM)
	bar:SetTall(S(32))
	bar:DockMargin(0, S(8), 0, 0)

	local body = right:Add("DTextEntry")
	body:Dock(FILL)
	body:SetMultiline(true)
	StyleEntry(body)
	body.ph = "Текст сообщения…"

	local send = bar:Add("ixTabletButton")
	send:Dock(RIGHT)
	send:SetWide(S(130))
	send:SetLabel("Отправить")
	send.DoClick = function()
		if (!self.msgTo) then
			self:Toast("Выберите получателя.", true)
			return
		end

		ix.tablet.Send("msgSend", {to = self.msgTo, text = body:GetValue()})
	end

	bar.Paint = function(_, w, h)
		draw.SimpleText((utf8.len(body:GetValue()) or 0) .. "/500", "ixTabletT", S(2), h / 2, C.dim, 0, 1)
	end
end

-- ----- Вкладка: Записки -----

function PANEL:Tab_notes(p)
	local st = ix.tablet.state

	PageHeader(p, "Записки", #st.notes .. " шт.")

	local left = p:Add("EditablePanel")
	left:Dock(LEFT)
	left:SetWide(S(230))
	left:DockMargin(0, 0, S(14), 0)

	local new = left:Add("ixTabletButton")
	new:Dock(TOP)
	new:SetTall(S(34))
	new:DockMargin(0, 0, S(8), S(8))
	new:SetLabel("+ Новая записка")
	new.DoClick = function()
		self.selNote = nil
		self:SwitchTab("notes", true)
	end

	local list = left:Add("DScrollPanel")
	list:Dock(FILL)
	StyleScroll(list)

	local right = p:Add("EditablePanel")
	right:Dock(FILL)

	local notes = table.Copy(st.notes)
	table.sort(notes, function(a, b) return (a.time or 0) > (b.time or 0) end)

	local cur

	for _, n in ipairs(notes) do
		if (n.id == self.selNote) then cur = n end

		local row = list:Add("DButton")

		row:SetText("")
		row:Dock(TOP)
		row:SetTall(S(48))
		row:DockMargin(0, 0, S(8), S(4))
		row.hover = 0

		row.Think = function(s) s.hover = Lerp(FrameTime() * 12, s.hover, s:IsHovered() and 1 or 0) end

		row.Paint = function(s, w, h)
			local sel = self.selNote == n.id

			Box(0, 0, w, h, ColorAlpha(C.accent, sel and 28 or s.hover * 14))
			Outline(0, 0, w, h, sel and C.accent or C.line)
			draw.SimpleText(Trunc(n.title, w - S(20), "ixTabletS"), "ixTabletS", S(10), h / 2 - S(8), C.text, 0, 1)
			draw.SimpleText((n.shared and "общая" or "личная") .. "  |  " .. Ago(n.time), "ixTabletT", S(10), h / 2 + S(10), n.shared and C.accent or C.dim, 0, 1)
		end

		row.DoClick = function()
			self.selNote = n.id
			self:SwitchTab("notes", true)
		end
	end

	local canEdit = !cur or cur.canEdit
	local shared = cur and cur.shared or false

	local title = right:Add("DTextEntry")
	title:Dock(TOP)
	title:SetTall(S(36))
	StyleEntry(title, "ixTabletM")
	title.ph = "Заголовок"
	title:SetText(cur and cur.title or "")
	title:SetEditable(canEdit)

	local bar = right:Add("EditablePanel")
	bar:Dock(BOTTOM)
	bar:SetTall(S(34))
	bar:DockMargin(0, S(8), 0, 0)

	local body = right:Add("DTextEntry")
	body:Dock(FILL)
	body:DockMargin(0, S(8), 0, 0)
	body:SetMultiline(true)
	StyleEntry(body)
	body.ph = "Текст записки…"
	body:SetText(cur and cur.text or "")
	body:SetEditable(canEdit)

	bar.Paint = function(_, w, h)
		draw.SimpleText((utf8.len(body:GetValue()) or 0) .. "/2000", "ixTabletT", w / 2, h / 2, C.dim, 1, 1)
	end

	if (canEdit) then
		local save = bar:Add("ixTabletButton")
		save:Dock(RIGHT)
		save:SetWide(S(110))
		save:SetLabel("Сохранить")
		save.DoClick = function()
			ix.tablet.Send("noteSave", {id = cur and cur.id, title = title:GetValue(), text = body:GetValue(), shared = shared})
		end

		if (cur) then
			local del = bar:Add("ixTabletButton")
			del:Dock(RIGHT)
			del:DockMargin(0, 0, S(8), 0)
			del:SetWide(S(100))
			del:SetLabel("Удалить")
			del.col = C.danger
			del.DoClick = function() ix.tablet.Send("noteDelete", {id = cur.id}) end
		end

		local share = bar:Add("ixTabletToggle")
		share:Dock(LEFT)
		share:SetWide(S(210))

		local function UpdateShare()
			share:SetLabel(shared and "Видна фракции: да" or "Видна фракции: нет")
			share.on = shared
		end

		share.DoClick = function()
			shared = !shared
			UpdateShare()
		end

		UpdateShare()
	elseif (cur) then
		local info = Label(bar, "Автор: " .. (cur.author or "?") .. " (только чтение)", "ixTabletS", C.dim)
		info:Dock(LEFT)
	end
end

-- ----- Вкладка: Карта -----

function PANEL:Tab_map(p)
	self.mapView = self.mapView or {zoom = 1, pan = {x = 0, y = 0}}

	local map

	local bar = p:Add("EditablePanel")
	bar:Dock(TOP)
	bar:SetTall(S(32))
	bar:DockMargin(0, 0, 0, S(8))

	local function Btn(label, w, fn)
		local b = bar:Add("ixTabletButton")
		b:Dock(LEFT)
		b:SetWide(w)
		b:DockMargin(0, 0, S(6), 0)
		b:SetLabel(label)
		b.DoClick = fn

		return b
	end

	Btn("К себе", S(76), function()
		local me = map:GetMe()

		if (me) then map:CenterOn(me.x, me.y, math.max(map.view.zoom, 2)) end
	end)

	Btn("+", S(34), function() map:ZoomBy(1.4) end)
	Btn("−", S(34), function() map:ZoomBy(1 / 1.4) end)

	local function Layer(label, key, w)
		local t = bar:Add("ixTabletToggle")
		t:Dock(LEFT)
		t:SetWide(w)
		t:DockMargin(S(6), 0, 0, 0)
		t:SetLabel(label)
		t.on = self.mapLayers[key]
		t.DoClick = function()
			self.mapLayers[key] = !self.mapLayers[key]
			t.on = self.mapLayers[key]
		end
	end

	Layer("Сетка", "grid", S(70))
	Layer("Метки", "markers", S(70))
	Layer("Свои", "allies", S(66))

	-- Легенда меток справа
	bar.Paint = function(_, w, h)
		local x = w - S(6)

		for i = #ix.tablet.markerKinds, 1, -1 do
			local name = ix.tablet.markerKinds[i]

			surface.SetFont("ixTabletT")
			local tw = surface.GetTextSize(name)

			draw.SimpleText(name, "ixTabletT", x, h / 2, C.dim, TEXT_ALIGN_RIGHT, 1)
			UI.DrawMarker(i, x - tw - S(12), h / 2, S(4))
			x = x - tw - S(28)
		end
	end

	map = p:Add("ixTabletMap")
	map:Dock(FILL)
	map.view = self.mapView
	map.layers = self.mapLayers

	map.PaintOver = function(_, w, h)
		Outline(0, 0, w, h, C.line)
	end
end

-- ----- Вкладка: Журнал (deputy / commander) -----

function PANEL:Tab_log(p)
	local st = ix.tablet.state
	local log = st.log or {}

	PageHeader(p, "Журнал действий", #log .. " записей")

	local scroll = p:Add("DScrollPanel")
	scroll:Dock(FILL)
	StyleScroll(scroll)

	if (#log == 0) then
		local l = Label(scroll, "Журнал пуст", "ixTabletS", C.dim)
		l:Dock(TOP)

		return
	end

	for i = #log, 1, -1 do
		local rec = log[i]
		local kind = LOG_KIND[rec.kind] or {"ПРОЧЕЕ", C.dim}
		local lines = Wrap(rec.text, S(500), "ixTabletS")
		local row = scroll:Add("EditablePanel")

		row:Dock(TOP)
		row:DockMargin(0, 0, S(8), S(4))
		row:SetTall(math.max(S(36), #lines * S(18) + S(18)))

		row.Paint = function(_, w, h)
			Box(0, 0, w, h, C.panel)
			Box(0, 0, S(3), h, kind[2])
			draw.SimpleText(DateStr(rec.time), "ixTabletMono", S(14), S(10), C.dim, 0, 1)
			Pill(S(232), (h - S(18)) / 2, kind[1], kind[2])

			for k, line in ipairs(lines) do
				draw.SimpleText(line, "ixTabletS", S(246), S(9) + (k - 1) * S(18), C.text)
			end
		end
	end
end

vgui.Register("ixMilTablet", PANEL, "EditablePanel")