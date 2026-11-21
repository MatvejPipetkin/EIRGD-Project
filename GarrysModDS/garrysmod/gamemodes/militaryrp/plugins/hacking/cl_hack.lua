local PLUGIN = PLUGIN
local HACK = ix.hack

HACK.client = HACK.client or {
	effects = {},     -- [ключ] = CurTime() окончания (для моей фракции)
	cooldownEnd = 0,  -- когда снова можно взламывать
	track = {},       -- контакты от «камер»
	trackUntil = 0,
	scan = nil        -- результат сканирования сети
}

local CL = HACK.client

HACK.handlers = HACK.handlers or {}

-- =====================================================================================
--  Масштаб, палитра, шрифты
-- =====================================================================================

function HACK.S(n)
	return math.Round(n * ScrH() / 1080)
end

local S = HACK.S

HACK.C = {
	bg = Color(4, 9, 13),
	panel = Color(9, 19, 26),
	panel2 = Color(14, 30, 38),
	line = Color(22, 104, 112),
	text = Color(168, 255, 238),
	dim = Color(76, 146, 148),
	faint = Color(24, 54, 62),
	accent = Color(0, 255, 214),
	warn = Color(255, 196, 64),
	bad = Color(255, 72, 84),
	good = Color(96, 255, 160),
	cyan = Color(90, 220, 255)
}

local C = HACK.C

local function CreateFonts()
	local function F(name, size, weight)
		surface.CreateFont(name, {font = "Consolas", size = S(size), weight = weight or 500, extended = true, antialias = true})
	end

	F("ixHackXS", 13)
	F("ixHackS", 16)
	F("ixHackM", 21, 700)
	F("ixHackL", 30, 700)
	F("ixHackXL", 54, 800)
	F("ixHackHUD", 18, 700)
end

CreateFonts()
hook.Add("OnScreenSizeChanged", "ixHackFonts", CreateFonts)

-- =====================================================================================
--  Состояние
-- =====================================================================================

function HACK.GetCooldownLeft()
	return math.max(0, CL.cooldownEnd - CurTime())
end

function HACK.EffectLeft(key)
	return math.max(0, (CL.effects[key] or 0) - CurTime())
end

function HACK.IsBlackout()
	return HACK.EffectLeft("tablet") > 0
end

-- =====================================================================================
--  Планшет: вкладка карты при блэкауте
-- =====================================================================================

local function RefreshTabletMap()
	local tablet = ix.tablet and ix.tablet.panel

	if (IsValid(tablet) and tablet.tab == "map" and ix.tablet.state and tablet.SwitchTab) then
		tablet:SwitchTab("map", true)
	end
end

-- Блэкаут закончился: просим у сервера свежие данные (метки), он ответит "sync" и вкладка обновится.
local function RestoreTablet()
	if (IsValid(ix.tablet and ix.tablet.panel) and ix.tablet.state and ix.tablet.Send) then
		ix.tablet.Send("sync")
	end

	RefreshTabletMap()
end

local function BuildNoSignal(tablet, p)
	local finished = false

	p.Paint = function(_, w, h)
		surface.SetDrawColor(6, 8, 7, 255)
		surface.DrawRect(0, 0, w, h)

		-- «Снег».
		for _ = 1, 70 do
			surface.SetDrawColor(120, 150, 125, math.random(6, 26))
			surface.DrawRect(math.random(0, w), math.random(0, h), math.random(10, 70), math.random(1, 2))
		end

		-- Бегущая полоса развёртки.
		surface.SetDrawColor(120, 255, 150, 14)
		surface.DrawRect(0, (SysTime() * 150) % h, w, S(8))

		local blink = (math.floor(SysTime() * 1.6) % 2 == 0) and 255 or 150

		draw.SimpleText("НЕТ СИГНАЛА", "ixHackXL", w / 2, h / 2 - S(54), Color(255, 84, 72, blink), 1, 1)
		draw.SimpleText("Связь с картографическим сервером потеряна", "ixHackM", w / 2, h / 2 + S(6), Color(190, 200, 190), 1, 1)
		draw.SimpleText("Карта и положение бойцов недоступны", "ixHackS", w / 2, h / 2 + S(38), Color(125, 138, 126), 1, 1)
		draw.SimpleText("Восстановление через " .. HACK.FormatTime(HACK.EffectLeft("tablet")), "ixHackM",
			w / 2, h / 2 + S(82), Color(232, 180, 60), 1, 1)
	end

	p.Think = function()
		if (finished or HACK.IsBlackout()) then return end

		finished = true

		timer.Simple(0, RestoreTablet)
	end
end

local function PatchTablet()
	local panel = vgui.GetControlTable("ixMilTablet")

	if (not panel or not panel.Tab_map) then return false end

	if (panel.ixHackPatched) then return true end

	panel.ixHackPatched = true

	local original = panel.Tab_map

	panel.Tab_map = function(self, p)
		if (HACK.IsBlackout()) then
			return BuildNoSignal(self, p)
		end

		return original(self, p)
	end

	return true
end

-- Панель планшета регистрируется при загрузке плагинов; на всякий случай пробуем несколько раз.
function PLUGIN:InitializedPlugins()
	if (PatchTablet()) then return end

	local tries = 0

	timer.Create("ixHackPatchTablet", 2, 15, function()
		tries = tries + 1

		if (PatchTablet()) then
			timer.Remove("ixHackPatchTablet")
		end
	end)
end

-- =====================================================================================
--  Сообщения сервера
-- =====================================================================================

local KIND_COLOR = {
	info = Color(120, 205, 255),
	good = Color(110, 255, 140),
	warn = Color(255, 210, 80),
	bad = Color(255, 92, 80)
}

local KIND_SOUND = {
	info = "buttons/button17.wav",
	good = "buttons/button14.wav",
	warn = "buttons/button17.wav",
	bad = "buttons/button10.wav"
}

HACK.handlers.msg = function(data)
	chat.AddText(Color(90, 255, 150), "[СЕТЬ] ", KIND_COLOR[data.kind] or KIND_COLOR.info, tostring(data.text))
	surface.PlaySound(KIND_SOUND[data.kind] or KIND_SOUND.info)
end

HACK.handlers.sync = function(data)
	local was = HACK.IsBlackout()

	CL.effects = {}

	for key, left in pairs(data.effects or {}) do
		CL.effects[key] = CurTime() + left
	end

	CL.cooldownEnd = CurTime() + (data.cooldown or 0)

	PatchTablet()

	-- Блэкаут начался: подменяем уже открытую карту.
	if (not was and HACK.IsBlackout()) then
		RefreshTabletMap()
	end
end

HACK.handlers.track = function(data)
	CL.track = data.list or {}
	CL.trackUntil = CurTime() + (data.left or 0) + 1
end

HACK.handlers.scan = function(data)
	CL.scan = {list = data.list or {}, untilTime = CurTime() + 20}

	if (#CL.scan.list == 0) then
		chat.AddText(Color(90, 255, 150), "[СЕТЬ] ", KIND_COLOR.warn, "Сканирование завершено: узлов поблизости нет.")
	else
		chat.AddText(Color(90, 255, 150), "[СЕТЬ] ", KIND_COLOR.good, "Найдено узлов: " .. #CL.scan.list .. ". Метки на экране 20 с.")
	end

	surface.PlaySound("buttons/combine_button1.wav")
end

net.Receive("ixHack.S2C", function()
	local action = net.ReadString()
	local data = net.ReadTable()
	local handler = HACK.handlers[action]

	if (handler) then
		handler(data)
	end
end)

function HACK.SendToServer(action, data)
	net.Start("ixHack.C2S")
		net.WriteString(action)
		net.WriteTable(data or {})
	net.SendToServer()
end

-- =====================================================================================
--  HUD
-- =====================================================================================

local STATUS = {
	tablet = "КАРТА ПЛАНШЕТА ОТКЛЮЧЕНА",
	radio = "РАДИОСВЯЗЬ ПОДАВЛЕНА",
	power = "ЭЛЕКТРОПИТАНИЕ ОТКЛЮЧЕНО"
}

local STATUS_ORDER = {"tablet", "radio", "power"}

local function UI() return HACK.UI end

local function Marker(pos, col, line1, line2)
	local sp = pos:ToScreen()

	if (not sp.visible) then return end

	local ui = UI()
	local r = S(10)
	local pulse = 0.6 + 0.4 * math.sin(SysTime() * 4)

	ui.Brackets(sp.x - r - 2, sp.y - r - 2, (r + 2) * 2, (r + 2) * 2, ui.A(col, 110 + 120 * pulse), S(6), 2)
	ui.Diamond(sp.x, sp.y, S(4), col)

	surface.SetFont("ixHackHUD")

	local w1 = surface.GetTextSize(line1)
	local w2 = line2 and surface.GetTextSize(line2) or 0
	local bw = math.max(w1, w2) + S(16)
	local bh = line2 and S(42) or S(24)
	local bx, by = sp.x - bw / 2, sp.y - r - S(12) - bh

	surface.SetDrawColor(col.r, col.g, col.b, 120)
	surface.DrawLine(sp.x, by + bh, sp.x, sp.y - r - 2)

	ui.Rect(bx, by, bw, bh, Color(4, 10, 14, 215))
	ui.Rect(bx, by, bw, 2, col)
	ui.Frame(bx, by, bw, bh, ui.A(col, 80), 1)

	draw.SimpleText(line1, "ixHackHUD", sp.x, by + S(4), col, 1, 0)

	if (line2) then
		draw.SimpleText(line2, "ixHackHUD", sp.x, by + S(22), C.text, 1, 0)
	end
end

local function DrawStatus()
	local ui = UI()
	local bw, bh = S(310), S(52)
	local x, y = ScrW() - bw - S(24), ScrH() * 0.33

	for _, key in ipairs(STATUS_ORDER) do
		local left = HACK.EffectLeft(key)

		if (left > 0) then
			local blink = (math.floor(SysTime() * 2) % 2 == 0) and 1 or 0.55
			local red = ui.A(C.bad, 255 * blink)

			ui.Box(x, y, bw, bh, C.bad, 225)
			ui.Rect(x, y, S(4), bh, red)
			draw.SimpleText("⚠ " .. STATUS[key], "ixHackHUD", x + S(16), y + S(8), red, 0, 0)
			draw.SimpleText("восстановление " .. HACK.FormatTime(left), "ixHackHUD", x + S(16), y + S(28), C.warn, 0, 0)

			y = y + bh + S(8)
		end
	end
end

local function DrawTrack()
	if (CurTime() > CL.trackUntil or #CL.track == 0) then return end

	local ui = UI()
	local lp = LocalPlayer()

	for _, contact in ipairs(CL.track) do
		local meters = math.floor(lp:GetPos():Distance(contact.pos) * 0.01905)

		Marker(contact.pos, Color(255, 120, 60), "КОНТАКТ", meters .. " м")
	end

	local bw, bh = S(340), S(40)
	local x = ScrW() / 2 - bw / 2

	ui.Box(x, S(20), bw, bh, C.warn, 220)
	draw.SimpleText("ПЕРЕХВАТ КАМЕР  ·  " .. HACK.FormatTime(CL.trackUntil - CurTime() - 1), "ixHackHUD",
		ScrW() / 2, S(20) + bh / 2, C.warn, 1, 1)
end

local function DrawScan()
	if (not CL.scan) then return end

	if (CurTime() > CL.scan.untilTime) then
		CL.scan = nil

		return
	end

	local lp = LocalPlayer()

	for _, node in ipairs(CL.scan.list) do
		local diff = HACK.Difficulty(node.diff)
		local info = HACK.types[node.type]
		local meters = math.floor(lp:GetPos():Distance(node.pos) * 0.01905)
		local label = node.name .. "  [" .. (info and info.short or "?") .. "]"

		Marker(node.pos + Vector(0, 0, 30), node.cooling and C.bad or diff.color, label,
			diff.name .. " · " .. meters .. " м" .. (node.owner and (" · " .. node.owner) or ""))
	end
end

local function DrawNodeInfo()
	local lp = LocalPlayer()

	if (not HACK.CanUse(lp)) then return end

	local tr = lp:GetEyeTrace()
	local node = tr.Entity

	if (not IsValid(node) or node:GetClass() ~= "ix_hacknode") then return end

	if (lp:GetShootPos():Distance(tr.HitPos) > 260) then return end

	local ui = UI()
	local info = HACK.types[node:GetNodeType()]
	local diff = HACK.Difficulty(node:GetDifficulty())
	local owner = ix.faction.teams[node:GetOwnerFaction()]
	local w, h = S(300), S(136)
	local x, y = ScrW() / 2 + S(44), ScrH() / 2 - h / 2
	local status, scol

	if (node:GetBusy()) then
		status, scol = "ЗАНЯТ", C.warn
	elseif (node:GetCooling()) then
		status, scol = "ВОССТАНАВЛИВАЕТСЯ", C.bad
	else
		status, scol = "ГОТОВ К ВЗЛОМУ", C.good
	end

	-- Выноска от центра экрана к панели.
	surface.SetDrawColor(C.accent.r, C.accent.g, C.accent.b, 110)
	surface.DrawLine(ScrW() / 2 + S(10), ScrH() / 2, x, ScrH() / 2)

	ui.Box(x, y, w, h, scol, 215)
	ui.Glow(node:GetNodeName(), "ixHackM", x + S(14), y + S(10), C.text, 0, 0, 0.8)
	draw.SimpleText(info and info.name or "?", "ixHackHUD", x + S(14), y + S(36), C.dim, 0, 0)

	ui.Chip(x + S(14), y + S(60), "ЗАЩИТА: " .. diff.name, diff.color, "ixHackHUD")
	draw.SimpleText("Владелец: " .. (owner and owner.name or "нейтральный"), "ixHackHUD", x + S(14), y + S(86), C.dim, 0, 0)

	ui.Rect(x + S(14), y + h - S(26), S(3), S(14), scol)
	draw.SimpleText(status, "ixHackHUD", x + S(24), y + h - S(26), scol, 0, 0)
end

function PLUGIN:HUDPaint()
	if (not LocalPlayer():GetCharacter()) then return end

	DrawStatus()
	DrawTrack()
	DrawScan()
	DrawNodeInfo()
end
