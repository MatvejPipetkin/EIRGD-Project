-- Панель карты планшета (ixTabletMap).
-- Кладите рядом с cl_tablet.lua: plugins/tablet/derma/cl_tabletmap.lua
--
-- Что умеет:
--   * картинка карты (ix.tablet.maps[game.GetMap()]) по границам mins/maxs, без растягивания;
--   * колесо мыши - масштаб к курсору, ЛКМ + перетаскивание - сдвиг;
--   * слои: сетка, метки, «свои» (по ix.tablet.state.positions, опрашивается раз в 3 с);
--   * маленькие маркеры: свои - точки, вы - стрелка по направлению взгляда;
--   * ПКМ (deputy/commander): по пустому месту - поставить метку, по метке - удалить;
--   * внизу справа координаты курсора и ваши;
--   * границы карты считаются сами по размерам мира (game.GetWorld()); ручные mins/maxs из sh_plugin.lua
--     нужны только как переопределение.
--
-- Интерфейс, которого ждёт cl_tablet.lua: .view = {zoom, pan}, .layers, GetMe(), CenterOn(), ZoomBy().
-- view.pan - смещение центра экрана от центра картинки в долях картинки (0,0 = по центру).

local PANEL = {}

local MIN_ZOOM, MAX_ZOOM = 1, 10
local GRID_COLS = 10

-- Границы мира (мин/макс углы карты) из самой игры.
local function WorldBounds()
	local world = game.GetWorld()

	if (!world) then return end

	for _, name in ipairs({"GetModelBounds", "GetModelRenderBounds"}) do
		local fn = world[name]

		if (fn) then
			local ok, mins, maxs = pcall(fn, world)

			if (ok and isvector(mins) and isvector(maxs) and maxs.x - mins.x > 512 and maxs.y - mins.y > 512) then
				return mins, maxs
			end
		end
	end
end

function PANEL:Init()
	self.view = {zoom = 1, pan = {x = 0, y = 0}}
	self.layers = {grid = true, markers = true, allies = true}
	self.nextPoll = 0

	self:LoadMap()
end

function PANEL:LoadMap()
	local cfg = ix.tablet.maps and ix.tablet.maps[game.GetMap()]

	self.cfg = cfg
	self.mat = nil
	self.iw, self.ih = 0, 0

	if (cfg and cfg.material) then
		local mat = Material(cfg.material, "smooth")

		if (mat and !mat:IsError()) then
			self.mat = mat
			self.iw, self.ih = mat:Width(), mat:Height()
		end
	end

	if (self.iw < 1 or self.ih < 1) then
		self.iw, self.ih = 1024, 1024
	end

	local mins, maxs = cfg and cfg.mins, cfg and cfg.maxs

	self.autoBounds = false
	self.noBounds = false

	if (!mins or !maxs) then
		-- Ручные границы не заданы: считаем по размерам самой карты.
		local wmins, wmaxs = WorldBounds()

		if (wmins) then
			local minX, minY, maxX, maxY = wmins.x, wmins.y, wmaxs.x, wmaxs.y
			local aspect = self.iw / self.ih
			local W, H = maxX - minX, maxY - minY

			-- Подгоняем под пропорции картинки, чтобы она не растягивалась:
			-- расширяем меньшую сторону от центра (если пропорции уже совпадают, ничего не меняется).
			if (W / H > aspect) then
				local cy, nh = (minY + maxY) / 2, W / aspect

				minY, maxY = cy - nh / 2, cy + nh / 2
			else
				local cx, nw = (minX + maxX) / 2, H * aspect

				minX, maxX = cx - nw / 2, cx + nw / 2
			end

			mins, maxs = {minX, minY}, {maxX, maxY}
			self.autoBounds = true

			if (!ix.tablet.boundsLogged) then
				ix.tablet.boundsLogged = true

				MsgC(Color(120, 200, 120), "[Планшет] ", color_white, string.format("границы карты (авто): mins = {%d, %d}, maxs = {%d, %d}\n", minX, minY, maxX, maxY))
			end
		else
			-- Размеры мира получить не удалось: условные границы, чтобы хоть что-то было видно.
			local half = 8192

			mins = {-half * self.iw / self.ih, -half}
			maxs = {half * self.iw / self.ih, half}
			self.noBounds = true
		end
	end

	self.minX, self.minY = mins[1], mins[2]
	self.maxX, self.maxY = maxs[1], maxs[2]
end

-- ----- Геометрия -----

-- Прямоугольник картинки на панели (с учётом масштаба и сдвига).
function PANEL:GetRect()
	local w, h = self:GetSize()
	local fit = math.min(w / self.iw, h / self.ih)
	local view = self.view
	local dw, dh = self.iw * fit * view.zoom, self.ih * fit * view.zoom
	local u, v = 0.5 + view.pan.x, 0.5 + view.pan.y

	return w / 2 - u * dw, h / 2 - v * dh, dw, dh
end

function PANEL:WorldToScreen(x, y)
	local l, t, dw, dh = self:GetRect()
	local u = (x - self.minX) / (self.maxX - self.minX)
	local v = 1 - (y - self.minY) / (self.maxY - self.minY)

	return l + u * dw, t + v * dh
end

function PANEL:ScreenToWorld(sx, sy)
	local l, t, dw, dh = self:GetRect()
	local u, v = (sx - l) / dw, (sy - t) / dh

	return self.minX + u * (self.maxX - self.minX), self.minY + (1 - v) * (self.maxY - self.minY)
end

function PANEL:ClampView()
	local view = self.view
	local w, h = self:GetSize()

	view.zoom = math.Clamp(view.zoom, MIN_ZOOM, MAX_ZOOM)

	if (w < 2 or h < 2) then return end

	local fit = math.min(w / self.iw, h / self.ih)
	local dw, dh = self.iw * fit * view.zoom, self.ih * fit * view.zoom

	-- Если картинка меньше панели по оси - центрируем, иначе не даём показать пустоту за краем.
	if (dw <= w) then
		view.pan.x = 0
	else
		local lim = 0.5 - w / (2 * dw)

		view.pan.x = math.Clamp(view.pan.x, -lim, lim)
	end

	if (dh <= h) then
		view.pan.y = 0
	else
		local lim = 0.5 - h / (2 * dh)

		view.pan.y = math.Clamp(view.pan.y, -lim, lim)
	end
end

function PANEL:ZoomAt(factor, sx, sy)
	local view = self.view
	local w, h = self:GetSize()

	sx, sy = sx or w / 2, sy or h / 2

	local l, t, dw, dh = self:GetRect()
	local u, v = (sx - l) / dw, (sy - t) / dh

	view.zoom = math.Clamp(view.zoom * factor, MIN_ZOOM, MAX_ZOOM)

	local fit = math.min(w / self.iw, h / self.ih)

	dw, dh = self.iw * fit * view.zoom, self.ih * fit * view.zoom
	view.pan.x = (w / 2 - (sx - u * dw)) / dw - 0.5
	view.pan.y = (h / 2 - (sy - v * dh)) / dh - 0.5

	self:ClampView()
end

function PANEL:ZoomBy(factor)
	self:ZoomAt(factor)
end

function PANEL:CenterOn(x, y, zoom)
	if (zoom) then
		self.view.zoom = math.Clamp(zoom, MIN_ZOOM, MAX_ZOOM)
	end

	self.view.pan.x = (x - self.minX) / (self.maxX - self.minX) - 0.5
	self.view.pan.y = (1 - (y - self.minY) / (self.maxY - self.minY)) - 0.5

	self:ClampView()
end

function PANEL:GetMe()
	local ply = LocalPlayer()

	if (!IsValid(ply)) then return end

	local pos = ply:GetPos()

	return {x = pos.x, y = pos.y, yaw = ply:EyeAngles().y}
end

-- ----- Поиск объектов под курсором -----

function PANEL:CanManage()
	local st = ix.tablet.state

	return st and st.me and st.me.canManage or false
end

function PANEL:FindMarker(mx, my)
	local st = ix.tablet.state

	if (!st or !st.markers or !self.layers.markers) then return end

	local r = ix.tablet.ui.S(10)

	for i = #st.markers, 1, -1 do
		local m = st.markers[i]
		local sx, sy = self:WorldToScreen(m.x, m.y)

		if ((mx - sx) ^ 2 + (my - sy) ^ 2 <= r * r) then return m end
	end
end

function PANEL:FindAlly(mx, my)
	local st = ix.tablet.state

	if (!st or !st.positions or !self.layers.allies) then return end

	local r = ix.tablet.ui.S(8)
	local myId = st.me and tostring(st.me.id)

	for _, p in ipairs(st.positions) do
		-- Себя не подсвечиваем: вы показаны стрелкой.
		if (tostring(p.id) != myId) then
			local sx, sy = self:WorldToScreen(p.x, p.y)

			if ((mx - sx) ^ 2 + (my - sy) ^ 2 <= r * r) then return p end
		end
	end
end

-- ----- Ввод -----

function PANEL:OnMouseWheeled(delta)
	local mx, my = self:LocalCursorPos()

	self:ZoomAt(delta > 0 and 1.25 or 0.8, mx, my)
end

function PANEL:OnMousePressed(code)
	local mx, my = self:LocalCursorPos()

	if (code == MOUSE_LEFT) then
		if (IsValid(self.dialog)) then self.dialog:Remove() end

		self.drag = {mx = mx, my = my, px = self.view.pan.x, py = self.view.pan.y}
		self:MouseCapture(true)
	elseif (code == MOUSE_RIGHT) then
		if (!self:CanManage()) then return end

		local marker = self:FindMarker(mx, my)

		if (marker) then
			ix.tablet.Send("markerDel", {id = marker.id})
		else
			local wx, wy = self:ScreenToWorld(mx, my)

			self:OpenDialog(mx, my, math.Round(wx), math.Round(wy))
		end
	end
end

function PANEL:OnMouseReleased(code)
	if (code == MOUSE_LEFT) then
		self.drag = nil
		self:MouseCapture(false)
	end
end

function PANEL:OnCursorMoved(x, y)
	local drag = self.drag

	if (!drag) then return end

	local _, _, dw, dh = self:GetRect()

	self.view.pan.x = drag.px - (x - drag.mx) / dw
	self.view.pan.y = drag.py - (y - drag.my) / dh
	self:ClampView()
end

function PANEL:Think()
	-- Позиции бойцов фракции запрашиваем у сервера, пока включён слой «Свои».
	if (self.layers.allies and CurTime() >= self.nextPoll) then
		self.nextPoll = CurTime() + 3
		ix.tablet.Send("positions")
	end

	-- Хук для сторонних плагинов (например, точки захвата).
	hook.Run("TabletMapThink", self)
end

-- ----- Диалог добавления метки -----

function PANEL:OpenDialog(sx, sy, wx, wy)
	if (IsValid(self.dialog)) then self.dialog:Remove() end

	local UI = ix.tablet.ui
	local C, S = UI.C, UI.S
	local kinds = ix.tablet.markerKinds
	local dw, dh = S(360), S(170)
	local d = self:Add("EditablePanel")

	d:SetSize(dw, dh)
	d:SetPos(math.Clamp(sx + S(10), S(6), math.max(S(6), self:GetWide() - dw - S(6))),
		math.Clamp(sy - dh / 2, S(6), math.max(S(6), self:GetTall() - dh - S(6))))
	d.kind = 1
	self.dialog = d

	d.Paint = function(_, w, h)
		UI.Box(0, 0, w, h, Color(14, 18, 22, 250))
		UI.Outline(0, 0, w, h, C.line)
		draw.SimpleText("НОВАЯ МЕТКА", "ixTabletT", S(10), S(13), C.dim, 0, 1)
		draw.SimpleText(string.format("X: %d  Y: %d", wx, wy), "ixTabletMono", w - S(10), S(13), C.dim, TEXT_ALIGN_RIGHT, 1)
	end

	local gap = S(4)
	local bw = (dw - S(20) - gap * (#kinds - 1)) / #kinds

	for i, name in ipairs(kinds) do
		local b = d:Add("DButton")

		b:SetText("")
		b:SetPos(S(10) + (i - 1) * (bw + gap), S(28))
		b:SetSize(bw, S(52))
		b.Paint = function(s, w, h)
			local on = d.kind == i

			UI.Box(0, 0, w, h, on and ColorAlpha(C.accent, 50) or Color(255, 255, 255, s:IsHovered() and 14 or 6))

			if (on) then UI.Outline(0, 0, w, h, C.accent) end

			UI.DrawMarker(i, w / 2, S(18), S(5))
			draw.SimpleText(name, "ixTabletT", w / 2, h - S(12), on and C.text or C.dim, TEXT_ALIGN_CENTER, 1)
		end
		b.DoClick = function() d.kind = i end
	end

	local entry = d:Add("DTextEntry")

	entry:SetPos(S(10), S(90))
	entry:SetSize(dw - S(20), S(30))
	UI.StyleEntry(entry, "ixTabletM")
	entry:SetPlaceholderText("Подпись (до 40 символов)")
	entry.OnTextChanged = function(s)
		local v = s:GetValue()

		if ((utf8.len(v) or 0) > 40) then
			s:SetText(string.sub(v, 1, utf8.offset(v, 41) - 1))
			s:SetCaretPos(#s:GetValue())
		end
	end

	local function Submit()
		ix.tablet.Send("markerAdd", {x = wx, y = wy, text = entry:GetValue(), kind = d.kind})
		d:Remove()
	end

	entry.OnEnter = Submit

	local ok = d:Add("ixTabletButton")

	ok:SetPos(S(10), S(130))
	ok:SetSize((dw - S(26)) / 2, S(32))
	ok:SetLabel("Поставить")
	ok.DoClick = Submit

	local cancel = d:Add("ixTabletButton")

	cancel:SetPos(S(16) + (dw - S(26)) / 2, S(130))
	cancel:SetSize((dw - S(26)) / 2, S(32))
	cancel:SetLabel("Отмена")
	cancel.DoClick = function() d:Remove() end

	entry:RequestFocus()
end

-- ----- Отрисовка -----

-- Закрашенный треугольник (порядок вершин правим под требование DrawPoly - по часовой).
local function Tri(x1, y1, x2, y2, x3, y3, col)
	if ((x2 - x1) * (y3 - y1) - (y2 - y1) * (x3 - x1) < 0) then
		x2, y2, x3, y3 = x3, y3, x2, y2
	end

	draw.NoTexture()
	surface.SetDrawColor(col)
	surface.DrawPoly({{x = x1, y = y1}, {x = x2, y = y2}, {x = x3, y = y3}})
end

-- Стрелка игрока: остриё по направлению взгляда (север карты - вверх, +X - вправо).
local function Arrow(cx, cy, yaw, size, col)
	local rad = math.rad(yaw)
	local dx, dy = math.cos(rad), -math.sin(rad)
	local px, py = -dy, dx
	local tipX, tipY = cx + dx * size, cy + dy * size
	local bx, by = cx - dx * size * 0.7, cy - dy * size * 0.7

	Tri(tipX, tipY, bx + px * size * 0.65, by + py * size * 0.65, bx - px * size * 0.65, by - py * size * 0.65, col)
end

local function Tooltip(x, y, lines, maxW, maxH)
	local UI = ix.tablet.ui
	local C, S = UI.C, UI.S
	local lh = S(16)
	local tw = 0

	surface.SetFont("ixTabletS")

	for _, line in ipairs(lines) do
		tw = math.max(tw, (surface.GetTextSize(line[1])))
	end

	local w, h = tw + S(16), #lines * lh + S(10)

	x, y = x + S(14), y + S(14)

	if (x + w > maxW) then x = x - w - S(28) end
	if (y + h > maxH) then y = y - h - S(28) end

	UI.Box(x, y, w, h, Color(12, 16, 20, 245))
	UI.Outline(x, y, w, h, C.line)

	for i, line in ipairs(lines) do
		draw.SimpleText(line[1], "ixTabletS", x + S(8), y + S(5) + (i - 1) * lh, line[2] or C.text)
	end
end

-- Плашка с текстом поверх карты. ax: 0 - слева, 1 - по центру, 2 - справа; ay: 0 - сверху, 2 - снизу.
local function Chip(x, y, text, font, col, ax, ay)
	local S = ix.tablet.ui.S

	surface.SetFont(font)

	local tw, th = surface.GetTextSize(text)
	local w, h = tw + S(14), th + S(8)
	local bx = ax == 1 and (x - w / 2) or (ax == 2 and (x - w) or x)
	local by = ay == 2 and (y - h) or y

	surface.SetDrawColor(0, 0, 0, 165)
	surface.DrawRect(bx, by, w, h)
	draw.SimpleText(text, font, bx + w / 2, by + h / 2, col, 1, 1)

	return h
end

function PANEL:Paint(w, h)
	local UI = ix.tablet.ui

	if (!UI) then return end

	local C, S = UI.C, UI.S
	local st = ix.tablet.state
	local view = self.view
	local mx, my = self:LocalCursorPos()
	local hovered = self:IsHovered() or self.drag

	surface.SetDrawColor(10, 13, 16, 255)
	surface.DrawRect(0, 0, w, h)

	local l, t, dw, dh = self:GetRect()

	-- Картинка карты
	if (self.mat) then
		surface.SetMaterial(self.mat)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(l, t, dw, dh)
	else
		surface.SetDrawColor(24, 28, 32, 255)
		surface.DrawRect(l, t, dw, dh)
		draw.SimpleText("Картинка карты не найдена: " .. game.GetMap(), "ixTabletS", w / 2, h / 2, C.warn, TEXT_ALIGN_CENTER, 1)
	end

	-- Сетка по всей картинке
	if (self.layers.grid) then
		local rows = math.max(1, math.Round(GRID_COLS * self.ih / self.iw))

		surface.SetDrawColor(255, 255, 255, 38)

		for i = 0, GRID_COLS do
			surface.DrawRect(math.floor(l + dw * i / GRID_COLS), t, 1, dh)
		end

		for j = 0, rows do
			surface.DrawRect(l, math.floor(t + dh * j / rows), dw, 1)
		end

		-- Подписи ячеек: буквы сверху, цифры слева (привязаны к краю панели).
		local letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

		for i = 1, GRID_COLS do
			local cx = l + dw * (i - 0.5) / GRID_COLS

			if (cx > S(8) and cx < w - S(8)) then
				local ch = string.sub(letters, i, i)

				draw.SimpleText(ch, "ixTabletT", cx + 1, S(7) + 1, Color(0, 0, 0, 200), 1, 1)
				draw.SimpleText(ch, "ixTabletT", cx, S(7), Color(255, 255, 255, 190), 1, 1)
			end
		end

		for j = 1, rows do
			local cy = t + dh * (j - 0.5) / rows

			if (cy > S(8) and cy < h - S(8)) then
				draw.SimpleText(j, "ixTabletT", S(8) + 1, cy + 1, Color(0, 0, 0, 200), 1, 1)
				draw.SimpleText(j, "ixTabletT", S(8), cy, Color(255, 255, 255, 190), 1, 1)
			end
		end
	end

	local tipLines

	-- Слои сторонних плагинов (рисуются под метками и бойцами).
	hook.Run("TabletMapPaint", self, w, h)

	-- Метки
	if (self.layers.markers and st and st.markers) then
		for _, m in ipairs(st.markers) do
			local sx, sy = self:WorldToScreen(m.x, m.y)

			if (sx > -S(20) and sx < w + S(20) and sy > -S(20) and sy < h + S(20)) then
				UI.DrawMarker(m.kind or 5, sx, sy, S(5))

				if (m.text and m.text != "" and view.zoom >= 1.6) then
					draw.SimpleText(m.text, "ixTabletT", sx + S(9), sy + 1, Color(0, 0, 0, 200), 0, 1)
					draw.SimpleText(m.text, "ixTabletT", sx + S(9), sy, C.text, 0, 1)
				end
			end
		end
	end

	-- Свои: маленькие точки
	if (self.layers.allies and st and st.positions) then
		local col = st.me and st.me.color or C.accent
		local myId = st.me and tostring(st.me.id)

		for _, p in ipairs(st.positions) do
			if (tostring(p.id) != myId) then
				local sx, sy = self:WorldToScreen(p.x, p.y)

				if (sx > -S(10) and sx < w + S(10) and sy > -S(10) and sy < h + S(10)) then
					UI.Circle(sx, sy, S(3) + 1, Color(0, 0, 0, 200), 16)
					UI.Circle(sx, sy, S(3), col, 16)

					if (view.zoom >= 2.5) then
						draw.SimpleText(p.name or "?", "ixTabletT", sx + S(7), sy + 1, Color(0, 0, 0, 200), 0, 1)
						draw.SimpleText(p.name or "?", "ixTabletT", sx + S(7), sy, C.text, 0, 1)
					end
				end
			end
		end
	end

	-- Вы: небольшая стрелка по направлению взгляда
	local me = self:GetMe()

	if (me) then
		local sx, sy = self:WorldToScreen(me.x, me.y)

		Arrow(sx, sy, me.yaw, S(6) * 1.3, Color(0, 0, 0, 220))
		Arrow(sx, sy, me.yaw, S(6), Color(255, 255, 255, 255))
	end

	-- Подсказка под курсором
	if (hovered and !self.drag) then
		local m = self:FindMarker(mx, my)
		local a = !m and self:FindAlly(mx, my)

		if (m) then
			tipLines = {{(ix.tablet.markerKinds[m.kind] or "Метка") .. ((m.text or "") != "" and (": " .. m.text) or "")}}

			if (m.by and m.by != "") then
				tipLines[#tipLines + 1] = {"Поставил(а): " .. m.by, C.dim}
			end

			if (self:CanManage()) then
				tipLines[#tipLines + 1] = {"ПКМ - удалить", C.dim}
			end
		elseif (a) then
			tipLines = {{a.name or "?"}}

			if (a.rank and a.rank != "") then
				tipLines[#tipLines + 1] = {a.rank, C.dim}
			end
		else
			-- Подсказка от сторонних плагинов: хук возвращает список строк {{текст, [цвет]}, ...}.
			tipLines = hook.Run("TabletMapTooltip", self, mx, my)
		end

		if (tipLines) then
			Tooltip(mx, my, tipLines, w, h)
		end
	end

	-- Компас: север всегда сверху
	local ccx, ccy = w - S(26), S(28)

	UI.Circle(ccx, ccy, S(15), Color(0, 0, 0, 150), 24)
	UI.Ring(ccx, ccy, S(15), ColorAlpha(C.line, 220), 1, 24)
	Tri(ccx, ccy - S(11), ccx - S(4), ccy + S(1), ccx + S(4), ccy + S(1), C.accent)
	draw.SimpleText("С", "ixTabletT", ccx, ccy + S(7), C.text, 1, 1)

	-- Предупреждение и подсказки
	if (self.noBounds) then
		Chip(S(8), S(8), "Границы карты не определены: укажите mins/maxs в sh_plugin.lua", "ixTabletT", C.warn, 0, 0)
	end

	if (self:CanManage()) then
		Chip(S(8), h - S(8), "ПКМ - поставить метку", "ixTabletT", C.dim, 0, 2)
	end

	local info = ""

	if (hovered) then
		local wx, wy = self:ScreenToWorld(mx, my)

		info = string.format("курсор %d, %d", wx, wy)
	end

	if (me) then
		info = info .. (info != "" and "   " or "") .. string.format("вы %d, %d", me.x, me.y)
	end

	Chip(w - S(8), h - S(8), info, "ixTabletMono", C.dim, 2, 2)
end

local function Register()
	vgui.Register("ixTabletMap", PANEL, "EditablePanel")
end

Register()

-- Повторная регистрация после загрузки всех плагинов: наша панель перекрывает любую другую
-- с тем же именем, если она где-то осталась.
hook.Add("InitializedPlugins", "ixTabletMapRegister", Register)