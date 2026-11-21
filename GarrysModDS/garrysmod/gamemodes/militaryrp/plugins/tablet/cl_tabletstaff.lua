-- Ставка: клиентская часть инструментов лидеров.
--   * HUD: баннер при смене боевой готовности, постоянный индикатор готовности и маячок сигнала сбора;
--   * вкладка «Ставка» (ix.tablet.tabs.staff) — её вызывает PANEL:SwitchTab в derma/cl_tablet.lua.
-- Серверная часть — sv_staff.lua.

ix.tablet = ix.tablet or {}
ix.tablet.tabs = ix.tablet.tabs or {}
ix.tablet.hud = ix.tablet.hud or {alert = {level = 1}}

local HUD = ix.tablet.hud
local UNITS_PER_METER = 52.49

-- ========== Приём состояния от сервера ==========

net.Receive("ixTablet.Alert", function()
	local level = net.ReadUInt(4)
	local by = net.ReadString()
	local note = net.ReadString()
	local silent = net.ReadBool()

	HUD.alert = {level = level, by = by, note = note}

	if (silent) then return end

	HUD.banner = {level = level, by = by, note = note, start = CurTime(), die = CurTime() + 9}
	surface.PlaySound(level >= 3 and "ambient/alarms/klaxon1.wav" or "buttons/button17.wav")
end)

net.Receive("ixTablet.Beacon", function()
	if (!net.ReadBool()) then
		HUD.beacon = nil

		return
	end

	local x, y = net.ReadInt(32), net.ReadInt(32)
	local text, by = net.ReadString(), net.ReadString()
	local left = net.ReadUInt(16)

	HUD.beacon = {x = x, y = y, text = text, by = by, die = CurTime() + left}

	-- Сигнал, поданный только что, сопровождаем звуком; при входе на сервер (left почти полный) тоже безвредно.
	surface.PlaySound("buttons/blip1.wav")
end)

-- ========== HUD ==========

local function DrawAlertTag(UI, S, C)
	local a = HUD.alert

	if (!a or a.level <= 1) then return end

	local lv = ix.tablet.alertLevels[a.level]

	if (!lv) then return end

	local col = ix.tablet.AlertColor(a.level)
	local pulse = a.level >= 3 and (0.7 + 0.3 * math.sin(CurTime() * 4)) or 1
	local text = "БОЕВАЯ ГОТОВНОСТЬ  |  " .. lv.short

	surface.SetFont("ixTabletS")

	local tw = surface.GetTextSize(text)
	local w, h = tw + S(32), S(26)
	local x, y = (ScrW() - w) / 2, S(10)

	UI.Box(x, y, w, h, Color(10, 13, 11, 170))
	UI.Box(x, y, w, h, ColorAlpha(col, 36 * pulse))
	UI.Outline(x, y, w, h, ColorAlpha(col, 200 * pulse))
	UI.Circle(x + S(13), y + h / 2, S(4), ColorAlpha(col, 255 * pulse), 20)
	draw.SimpleText(text, "ixTabletS", x + S(24), y + h / 2, col, 0, 1)
end

local function DrawBanner(UI, S, C)
	local b = HUD.banner

	if (!b) then return end

	local now = CurTime()

	if (now > b.die) then
		HUD.banner = nil

		return
	end

	local lv = ix.tablet.alertLevels[b.level]

	if (!lv) then return end

	local a = math.Clamp(math.min((now - b.start) * 4, (b.die - now) * 2), 0, 1)
	local col = ix.tablet.AlertColor(b.level)
	local flash = b.level >= 3 and (0.6 + 0.4 * math.sin(now * 8)) or 1
	local hasNote = b.note != ""
	local w, h = S(640), hasNote and S(142) or S(112)
	local x, y = (ScrW() - w) / 2, S(60)

	UI.Box(x, y, w, h, Color(10, 13, 11, 225 * a))
	UI.Outline(x, y, w, h, ColorAlpha(col, 255 * a))
	UI.Box(x, y, S(6), h, ColorAlpha(col, 255 * a * flash))
	UI.Box(x + w - S(6), y, S(6), h, ColorAlpha(col, 255 * a * flash))

	draw.SimpleText("СИГНАЛ ВЫСШЕГО КОМАНДОВАНИЯ", "ixTabletT", x + w / 2, y + S(18), ColorAlpha(C.dim, 255 * a), 1, 1)
	draw.SimpleText(lv.name, "ixTabletXL", x + w / 2, y + S(52), ColorAlpha(col, 255 * a), 1, 1)

	local who = b.by != "" and ("Объявил(а): " .. b.by) or ""

	draw.SimpleText(who, "ixTabletS", x + w / 2, y + S(86), ColorAlpha(C.text, 255 * a), 1, 1)

	if (hasNote) then
		draw.SimpleText(UI.Trunc(b.note, w - S(48), "ixTabletS"), "ixTabletS", x + w / 2, y + S(114), ColorAlpha(C.warn, 255 * a), 1, 1)
	end
end

local function DrawBeacon(UI, S, C)
	local b = HUD.beacon

	if (!b) then return end

	if (CurTime() > b.die) then
		HUD.beacon = nil

		return
	end

	local ply = LocalPlayer()
	local pos = ply:GetPos()
	local dx, dy = b.x - pos.x, b.y - pos.y
	local dist = math.sqrt(dx * dx + dy * dy) / UNITS_PER_METER
	local target = Vector(b.x, b.y, pos.z + 72)
	local sw, sh = ScrW(), ScrH()
	local m = S(70)
	local sp = target:ToScreen()
	local x, y, arrow

	if (sp.visible) then
		x, y = math.Clamp(sp.x, m, sw - m), math.Clamp(sp.y, m, sh - m)

		if (sp.x < m) then
			arrow = -1
		elseif (sp.x > sw - m) then
			arrow = 1
		end
	else
		-- Цель за спиной: прижимаем маячок к краю экрана с той стороны, куда короче повернуться.
		local ang = (target - ply:EyePos()):Angle()
		local diff = math.AngleDifference(ang.y, ply:EyeAngles().y)

		x, y = diff > 0 and m or sw - m, sh * 0.4
		arrow = diff > 0 and -1 or 1
	end

	local col = C.info
	local t = (CurTime() * 1.2) % 1
	local r = S(11)

	UI.Ring(x, y, S(10) + t * S(24), ColorAlpha(col, 200 * (1 - t)), 2)

	UI.Poly(Color(0, 0, 0, 210), {{x = x, y = y - r - 2}, {x = x + r + 2, y = y}, {x = x, y = y + r + 2}, {x = x - r - 2, y = y}})
	UI.Poly(col, {{x = x, y = y - r}, {x = x + r, y = y}, {x = x, y = y + r}, {x = x - r, y = y}})

	if (arrow) then
		UI.Poly(col, {{x = x + arrow * S(24), y = y}, {x = x + arrow * S(15), y = y - S(7)}, {x = x + arrow * S(15), y = y + S(7)}})
	end

	local label = "СБОР" .. (b.text != "" and (": " .. b.text) or "")

	draw.SimpleText(label, "ixTabletS", x + 1, y - S(26) + 1, Color(0, 0, 0, 220), 1, 1)
	draw.SimpleText(label, "ixTabletS", x, y - S(26), col, 1, 1)
	draw.SimpleText(string.format("%d м", math.Round(dist)), "ixTabletT", x + 1, y + S(25) + 1, Color(0, 0, 0, 220), 1, 1)
	draw.SimpleText(string.format("%d м", math.Round(dist)), "ixTabletT", x, y + S(25), C.text, 1, 1)
end

hook.Add("HUDPaint", "ixTabletStaffHUD", function()
	local ply = LocalPlayer()

	if (!IsValid(ply) or !ply:Alive() or !ply:GetCharacter()) then return end

	local UI = ix.tablet.ui

	if (!UI) then return end

	local C, S = UI.C, UI.S

	DrawAlertTag(UI, S, C)
	DrawBanner(UI, S, C)
	DrawBeacon(UI, S, C)
end)

-- При смене персонажа сервер сам присылает актуальное состояние (или сброс) — см. PLUGIN:PushStaffState.

-- ========== Вкладка «Ставка» ==========

ix.tablet.tabs.staff = function(self, p)
	local UI = ix.tablet.ui
	local C, S = UI.C, UI.S
	local Box = UI.Box
	local Label, Card, PageHeader = UI.Label, UI.Card, UI.PageHeader
	local StyleEntry, StyleScroll = UI.StyleEntry, UI.StyleScroll
	local Trunc, Ago = UI.Trunc, UI.Ago

	local st = ix.tablet.state
	local me = st.me

	PageHeader(p, "Ставка командования", me.rankName .. "  |  высшее командование")

	local scroll = p:Add("DScrollPanel")
	scroll:Dock(FILL)
	StyleScroll(scroll)

	local function NewCard(title, tall)
		local c = Card(scroll, title)

		c:Dock(TOP)
		c:SetTall(tall)
		c:DockMargin(0, 0, S(8), S(10))

		return c
	end

	-- ----- 1. Боевая готовность -----
	local levels = ix.tablet.alertLevels
	local alert = st.alert or {level = 1}
	local sel = alert.level or 1
	local c1 = NewCard("БОЕВАЯ ГОТОВНОСТЬ ФРАКЦИИ", S(190))

	local stat = c1:Add("EditablePanel")
	stat:Dock(TOP)
	stat:SetTall(S(46))

	stat.Paint = function(_, w)
		local lv = levels[alert.level or 1] or levels[1]
		local col = ix.tablet.AlertColor(alert.level or 1)
		local sub = "Объявлений не было"

		if (alert.by and alert.by != "") then
			sub = "Объявил(а): " .. alert.by .. (alert.time and ("  |  " .. Ago(alert.time)) or "")

			if (alert.note and alert.note != "") then
				sub = sub .. "  |  " .. alert.note
			end
		end

		UI.Circle(S(7), S(12), S(5), col, 24)
		draw.SimpleText("Сейчас: " .. lv.name, "ixTabletM", S(20), S(12), col, 0, 1)
		draw.SimpleText(Trunc(sub, w - S(20), "ixTabletT"), "ixTabletT", S(20), S(34), C.dim, 0, 1)
	end

	local row = c1:Add("EditablePanel")
	row:Dock(TOP)
	row:SetTall(S(34))

	local togs = {}

	for i, lv in ipairs(levels) do
		local t = row:Add("ixTabletToggle")

		t:SetLabel(lv.short)
		t.col = ix.tablet.AlertColor(i)
		t.on = i == sel
		t.DoClick = function()
			sel = i

			for k, b in ipairs(togs) do b.on = k == sel end
		end

		togs[i] = t
	end

	row.PerformLayout = function(_, w, h)
		local gap = S(6)
		local bw = (w - gap * (#togs - 1)) / #togs

		for i, t in ipairs(togs) do
			t:SetPos((i - 1) * (bw + gap), 0)
			t:SetSize(bw, h)
		end
	end

	local erow = c1:Add("EditablePanel")
	erow:Dock(TOP)
	erow:SetTall(S(32))
	erow:DockMargin(0, S(8), 0, 0)

	local pub = erow:Add("ixTabletButton")
	pub:Dock(RIGHT)
	pub:SetWide(S(150))
	pub:SetLabel("Объявить")

	local note = erow:Add("DTextEntry")
	note:Dock(FILL)
	note:DockMargin(0, 0, S(8), 0)
	StyleEntry(note)
	note.ph = "Пояснение для бойцов (необязательно, до 120 символов)"

	pub.DoClick = function()
		ix.tablet.Send("alertSet", {level = sel, note = note:GetValue()})
	end

	-- ----- 2. Сигнал сбора -----
	local c2 = NewCard("СИГНАЛ СБОРА", S(140))

	local info = c2:Add("EditablePanel")
	info:Dock(TOP)
	info:SetTall(S(52))

	info.Paint = function(_, w)
		local b = st.beacon

		if (b) then
			local left = math.max(0, (b.left or 0) - (CurTime() - (st.recv or CurTime())))

			draw.SimpleText("Активен" .. ((b.text or "") != "" and (": " .. b.text) or ""), "ixTabletM", 0, S(12), C.info, 0, 1)
			draw.SimpleText(Trunc(string.format("X: %d  Y: %d   |   осталось %d:%02d   |   подал(а): %s", b.x, b.y, math.floor(left / 60), math.floor(left) % 60, b.by or "?"), w, "ixTabletT"),
				"ixTabletT", 0, S(36), C.dim, 0, 1)
		else
			draw.SimpleText("Сигнал не подан", "ixTabletM", 0, S(12), C.dim, 0, 1)
			draw.SimpleText(Trunc("Карта → ПКМ по нужной точке → «Сигнал сбора». Маячок появится на экране каждого бойца в сети.", w, "ixTabletT"),
				"ixTabletT", 0, S(36), C.dim, 0, 1)
		end
	end

	local brow = c2:Add("EditablePanel")
	brow:Dock(TOP)
	brow:SetTall(S(32))
	brow:DockMargin(0, S(6), 0, 0)

	local open = brow:Add("ixTabletButton")
	open:Dock(LEFT)
	open:SetWide(S(160))
	open:SetLabel("Открыть карту")
	open.col = C.info
	open.DoClick = function() self:SwitchTab("map") end

	local clear = brow:Add("ixTabletButton")
	clear:Dock(LEFT)
	clear:DockMargin(S(6), 0, 0, 0)
	clear:SetWide(S(160))
	clear:SetLabel("Снять сигнал")
	clear.col = C.danger
	clear:SetEnabled(st.beacon != nil)
	clear.DoClick = function() ix.tablet.Send("beaconClear") end

	-- ----- 3. Приказы с подтверждением -----
	local acks = {}

	for _, o in ipairs(st.orders) do
		if (o.ack and o.ackTotal) then acks[#acks + 1] = o end
	end

	table.sort(acks, function(a, b) return a.time > b.time end)

	local ROW = S(68)
	local c3 = NewCard("ПРИКАЗЫ С ПОДТВЕРЖДЕНИЕМ", S(46) + (#acks == 0 and S(28) or #acks * (ROW + S(6))))

	if (#acks == 0) then
		local l = Label(c3, "Нет приказов, ожидающих подтверждения. Опубликуйте приказ с пометкой «Требует подтверждения».", "ixTabletS", C.dim)
		l:Dock(TOP)
	end

	for _, o in ipairs(acks) do
		local r = c3:Add("EditablePanel")

		r:Dock(TOP)
		r:SetTall(ROW)
		r:DockMargin(0, 0, 0, S(6))

		local full = #o.ackPending > 0 and ("Не подтвердили: " .. table.concat(o.ackPending, ", ")) or "Все подтвердили"

		r:SetTooltip(full)

		r.Paint = function(_, w, h)
			local done = o.ackDone >= o.ackTotal
			local col = done and C.ok or C.warn
			local frac = o.ackTotal > 0 and (o.ackDone / o.ackTotal) or 1

			Box(0, 0, w, h, Color(255, 255, 255, 5))
			Box(0, 0, S(3), h, col)

			draw.SimpleText(Trunc(o.title, w - S(150), "ixTabletS"), "ixTabletS", S(14), S(14), C.text, 0, 1)
			draw.SimpleText(string.format("%d / %d", o.ackDone, o.ackTotal), "ixTabletM", w - S(10), S(14), col, TEXT_ALIGN_RIGHT, 1)

			Box(S(14), S(30), w - S(24), S(5), C.line)
			Box(S(14), S(30), (w - S(24)) * frac, S(5), col)

			draw.SimpleText(Trunc(full, w - S(24), "ixTabletT"), "ixTabletT", S(14), S(50), C.dim, 0, 1)
		end
	end

	-- ----- 4. Приостановленный допуск -----
	local susp = {}

	for _, e in ipairs(st.roster) do
		if (e.suspended) then susp[#susp + 1] = e end
	end

	table.sort(susp, function(a, b) return (a.name or "") < (b.name or "") end)

	local c4 = NewCard("ДОПУСК К ПЛАНШЕТУ ПРИОСТАНОВЛЕН", S(46) + (#susp == 0 and S(28) or #susp * S(46)))

	if (#susp == 0) then
		local l = Label(c4, "Таких бойцов нет. Приостановить допуск можно во вкладке «Состав» (кнопка в карточке бойца).", "ixTabletS", C.dim)
		l:Dock(TOP)
	end

	for _, e in ipairs(susp) do
		local r = c4:Add("EditablePanel")

		r:Dock(TOP)
		r:SetTall(S(40))
		r:DockMargin(0, 0, 0, S(6))

		r.Paint = function(_, w, h)
			Box(0, 0, w, h, Color(255, 255, 255, 5))
			Box(0, 0, S(3), h, C.danger)
			draw.SimpleText(Trunc(e.name or "?", w - S(190), "ixTabletS"), "ixTabletS", S(14), S(12), C.text, 0, 1)
			draw.SimpleText(st.ranks[e.rank] or "?", "ixTabletT", S(14), S(29), C.dim, 0, 1)
		end

		local back = r:Add("ixTabletButton")
		back:SetSize(S(150), S(26))
		back:SetLabel("Вернуть допуск")
		back.col = C.ok
		back.DoClick = function() ix.tablet.Send("restore", {id = e.id}) end

		r.PerformLayout = function(_, w, h) back:SetPos(w - S(158), (h - S(26)) / 2) end
	end
end
