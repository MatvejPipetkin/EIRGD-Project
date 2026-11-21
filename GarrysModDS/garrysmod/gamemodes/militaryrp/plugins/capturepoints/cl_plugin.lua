local PLUGIN = PLUGIN

ix.capture = ix.capture or {}
ix.capture.points = ix.capture.points or {}

local NEUTRAL_COLOR = Color(150, 156, 150)
local POLL_DELAY = 1

-- ===================== Приём данных =====================

net.Receive("ixCapture.Sync", function()
	local list = {}

	for i = 1, net.ReadUInt(8) do
		local p = {}

		p.id = net.ReadUInt(32)
		p.name = net.ReadString()
		p.x = net.ReadInt(20)
		p.y = net.ReadInt(20)
		p.z = net.ReadInt(20)
		p.radius = net.ReadUInt(13)
		p.height = net.ReadUInt(13)
		p.owner = net.ReadString()
		p.since = net.ReadUInt(32)
		p.capturer = net.ReadString()
		p.progress = net.ReadUInt(7) / 100
		p.contested = net.ReadBool()

		list[#list + 1] = p
	end

	ix.capture.points = list
end)

local function Request()
	net.Start("ixCapture.Request")
	net.SendToServer()
end

-- Название и цвет фракции по uniqueID (пустая строка - нейтральная).
local function FactionInfo(fid)
	local faction = fid ~= "" and ix.faction.teams[fid]

	if (faction) then
		return tostring(faction.name), faction.color
	end

	return "Нейтральная", NEUTRAL_COLOR
end

-- ===================== Слой на карте планшета =====================

local function LayerOn(map)
	return map.layers == nil or map.layers.points ~= false
end

-- Дуга толщиной thick от угла from до to (градусы, 0 - вправо, по часовой стрелке).
local function Arc(cx, cy, r, thick, from, to, col)
	local ro, ri = r + thick / 2, math.max(0, r - thick / 2)
	local span = to - from
	local seg = math.max(2, math.ceil(math.abs(span) / 10))

	draw.NoTexture()
	surface.SetDrawColor(col)

	for i = 0, seg - 1 do
		local a1 = math.rad(from + span * i / seg)
		local a2 = math.rad(from + span * (i + 1) / seg)
		local c1, s1, c2, s2 = math.cos(a1), math.sin(a1), math.cos(a2), math.sin(a2)

		surface.DrawPoly({
			{x = cx + c1 * ro, y = cy + s1 * ro},
			{x = cx + c2 * ro, y = cy + s2 * ro},
			{x = cx + c2 * ri, y = cy + s2 * ri},
			{x = cx + c1 * ri, y = cy + s1 * ri}
		})
	end
end

-- Подпись под значком точки.
local function Label(x, y, text, col)
	local S = ix.tablet.ui.S

	surface.SetFont("ixTabletT")

	local tw, th = surface.GetTextSize(text)
	local w, h = tw + S(10), th + S(4)

	surface.SetDrawColor(0, 0, 0, 170)
	surface.DrawRect(x - w / 2, y, w, h)
	draw.SimpleText(text, "ixTabletT", x, y + h / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- Переключатель слоя «Точки» (создаётся на панели карты один раз) и опрос сервера.
hook.Add("TabletMapThink", "ixCaptureMap", function(map)
	local UI = ix.tablet and ix.tablet.ui

	if (not UI) then return end

	if (not IsValid(map.capToggle)) then
		local toggle = map:Add("ixTabletToggle")

		toggle:SetLabel("Точки")
		toggle.on = LayerOn(map)
		toggle.DoClick = function(this)
			local on = not LayerOn(map)

			map.layers.points = on
			this.on = on
		end

		map.capToggle = toggle
	end

	local S = UI.S

	-- Под компасом, в правом верхнем углу карты.
	map.capToggle:SetSize(S(70), S(24))
	map.capToggle:SetPos(map:GetWide() - S(70) - S(8), S(50))

	if (LayerOn(map) and CurTime() >= (ix.capture.nextPoll or 0)) then
		ix.capture.nextPoll = CurTime() + POLL_DELAY
		Request()
	end
end)

hook.Add("TabletMapPaint", "ixCapturePaint", function(map, w, h)
	if (not LayerOn(map)) then return end

	local UI = ix.tablet.ui
	local C, S = UI.C, UI.S
	local l, t, dw = map:GetRect()
	local pxPerUnit = dw / (map.maxX - map.minX)
	local pulse = 0.5 + 0.5 * math.sin(CurTime() * 6)
	local icon = S(9)

	for _, p in ipairs(ix.capture.points) do
		local sx, sy = map:WorldToScreen(p.x, p.y)
		local zone = p.radius * pxPerUnit
		local reach = math.max(zone, S(40))

		if (sx > -reach and sx < w + reach and sy > -reach and sy < h + reach) then
			local _, col = FactionInfo(p.owner)
			local owned = p.owner ~= ""

			-- Зона захвата (если на экране она крупнее значка).
			if (zone > icon + S(3)) then
				UI.Circle(sx, sy, zone, ColorAlpha(p.contested and C.warn or col, 34), 40)
				UI.Ring(sx, sy, zone, ColorAlpha(p.contested and C.warn or col, 150), 1, 40)
			end

			-- Значок: тёмная подложка и диск цвета владельца.
			UI.Circle(sx, sy, icon + 2, Color(0, 0, 0, 225), 24)
			UI.Circle(sx, sy, icon, owned and ColorAlpha(col, 235) or Color(60, 64, 60, 235), 24)

			-- Флажок на диске (цвет подбирается по яркости фона).
			local lum = owned and (col.r * 0.299 + col.g * 0.587 + col.b * 0.114) or 0
			local glyph = lum > 150 and Color(18, 18, 18) or Color(240, 240, 240)
			local px, py = math.Round(sx - S(2)), math.Round(sy - S(5))

			surface.SetDrawColor(glyph)
			surface.DrawRect(px, py, math.max(1, S(2)), S(10))
			UI.Poly(glyph, {
				{x = px + S(2), y = py},
				{x = px + S(8), y = py + S(3)},
				{x = px + S(2), y = py + S(6)}
			})

			-- Прогресс захвата: дуга цвета захватчика по часовой стрелке от «12 часов».
			if (p.capturer ~= "" and p.progress > 0) then
				local _, capCol = FactionInfo(p.capturer)

				Arc(sx, sy, icon + S(5), S(3), 0, 360, Color(0, 0, 0, 170))
				Arc(sx, sy, icon + S(5), S(3), -90, -90 + 360 * p.progress, capCol)
			end

			-- Спор: пульсирующее жёлтое кольцо.
			if (p.contested) then
				UI.Ring(sx, sy, icon + S(10) + pulse * S(2), ColorAlpha(C.warn, 110 + pulse * 130), 2, 32)
			end

			local text = p.name

			if (p.capturer ~= "" and p.progress > 0) then
				text = text .. "  " .. math.floor(p.progress * 100) .. "%"
			end

			Label(sx, sy + icon + S(9), text, p.contested and C.warn or C.text)
		end
	end
end)

hook.Add("TabletMapTooltip", "ixCaptureTip", function(map, mx, my)
	if (not LayerOn(map)) then return end

	local UI = ix.tablet.ui
	local C, S = UI.C, UI.S
	local r = S(14)
	local points = ix.capture.points

	for i = #points, 1, -1 do
		local p = points[i]
		local sx, sy = map:WorldToScreen(p.x, p.y)

		if ((mx - sx) ^ 2 + (my - sy) ^ 2 <= r * r) then
			local ownerName = FactionInfo(p.owner)
			local lines = {
				{"Точка: " .. p.name},
				{"Владелец: " .. ownerName, p.owner ~= "" and C.text or C.dim}
			}

			if (p.owner ~= "" and p.since > 0) then
				lines[#lines + 1] = {"Удерживается: " .. UI.Ago(p.since), C.dim}
			end

			if (p.capturer ~= "" and p.progress > 0) then
				lines[#lines + 1] = {string.format("Захват: %s — %d%%", FactionInfo(p.capturer), math.floor(p.progress * 100)), C.info}
			end

			if (p.contested) then
				lines[#lines + 1] = {"Идёт борьба: в зоне несколько фракций", C.warn}
			end

			return lines
		end
	end
end)

-- ===================== Зоны в мире (только админы) =====================
-- Включить: ix_capture_zones 1. Помогает подобрать радиус и высоту.

local zonesVar = CreateClientConVar("ix_capture_zones", "0", false, false, "Показывать зоны точек захвата в мире (только админы).")

hook.Add("PostDrawTranslucentRenderables", "ixCaptureZones", function(bDepth, bSkybox)
	if (bSkybox or not zonesVar:GetBool()) then return end

	local client = LocalPlayer()

	if (not IsValid(client) or not client:IsAdmin()) then return end

	if (CurTime() >= (ix.capture.nextZonePoll or 0)) then
		ix.capture.nextZonePoll = CurTime() + 2
		Request()
	end

	render.SetColorMaterial()

	local segments = 32

	for _, p in ipairs(ix.capture.points) do
		local _, col = FactionInfo(p.owner)
		local low, high = p.z - p.height, p.z + p.height
		local prevLow, prevHigh

		for i = 0, segments do
			local a = i / segments * math.pi * 2
			local x, y = p.x + math.cos(a) * p.radius, p.y + math.sin(a) * p.radius
			local pointLow, pointHigh = Vector(x, y, low), Vector(x, y, high)

			if (prevLow) then
				render.DrawLine(prevLow, pointLow, col, true)
				render.DrawLine(prevHigh, pointHigh, col, true)
			end

			if (i % 8 == 0) then
				render.DrawLine(pointLow, pointHigh, col, true)
			end

			prevLow, prevHigh = pointLow, pointHigh
		end
	end
end)
