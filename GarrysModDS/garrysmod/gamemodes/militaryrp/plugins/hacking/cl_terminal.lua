-- Окно терминала взлома и окно досье.
-- Сервер присылает: open (узел), stage / stagefail (очередная головоломка), feedback (ответ на попытку),
-- result (итог). Сами головоломки рисуют панели ixHackG_* из cl_games.lua.

local HACK = ix.hack
local C, S, UI = HACK.C, HACK.S, HACK.UI

local function Rect(x, y, w, h, col)
	surface.SetDrawColor(col)
	surface.DrawRect(x, y, w, h)
end

local function Frame(x, y, w, h, col, thick)
	surface.SetDrawColor(col)

	for i = 0, (thick or 1) - 1 do
		surface.DrawOutlinedRect(x + i, y + i, w - i * 2, h - i * 2)
	end
end

local function Text(str, font, x, y, col, ax, ay)
	draw.SimpleText(str, font, x, y, col, ax or 0, ay or 0)
end

-- Перенос текста по словам под заданную ширину.
local function Wrap(str, font, maxw)
	surface.SetFont(font)

	local lines, line = {}, ""

	for word in string.gmatch(tostring(str or ""), "%S+") do
		local try = (line == "") and word or (line .. " " .. word)

		if (surface.GetTextSize(try) > maxw and line ~= "") then
			lines[#lines + 1] = line
			line = word
		else
			line = try
		end
	end

	if (line ~= "") then
		lines[#lines + 1] = line
	end

	return lines
end

local function DateText(stamp, withTime)
	stamp = tonumber(stamp)

	if (not stamp or stamp <= 0) then return "—" end

	return os.date(withTime and "%d.%m.%y %H:%M" or "%d.%m.%y", stamp)
end

local function StyleScroll(scroll)
	local bar = scroll:GetVBar()

	bar:SetWide(S(8))
	bar.Paint = function(_, w, h) Rect(0, 0, w, h, UI.A(C.panel, 200)) end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(_, w, h)
		Rect(0, 0, w, h, UI.A(C.accent, 90))
		Frame(0, 0, w, h, UI.A(C.accent, 160), 1)
	end
end

-- =====================================================================================
--  Окно терминала
-- =====================================================================================

local TERM

do
	local PANEL = {}

	-- Строки «загрузки» перед первой головоломкой (шаг, с / общее время, с).
	local BOOT = {
		"Инициализация защищённого канала",
		"Обход периметра брандмауэра",
		"Рукопожатие с узлом %s",
		"Подбор ключа сеанса",
		"Доступ к консоли получен"
	}

	local BOOT_STEP, BOOT_END = 0.3, 1.7

	-- Поля и области окна (в «S»-единицах считаются при раскладке).
	local function Pad() return S(64) end
	local function Top() return S(206) end
	local function Bottom() return S(96) end

	-- Появление элемента с задержкой: 0..1 (плавно).
	local function Reveal(self, delay, dur)
		return UI.Ease((SysTime() - self.openAt - delay) / (dur or 0.45))
	end

	function PANEL:Init()
		self:SetSize(ScrW() - S(48), ScrH() - S(48))
		self:Center()
		self:MakePopup()
		self:SetKeyboardInputEnabled(true)

		self.mode = "connect"       -- connect -> game -> result
		self.opened = CurTime()
		self.openAt = SysTime()
		self.stage, self.stages = 0, 1
		self.lives, self.maxLives = 3, 3
		self.deadline, self.total = 0, 1
		self.finished = false
		self.ip = "10.0.0.1"
		self.stageAt = 0

		self.area = vgui.Create("EditablePanel", self)
		self.area.Paint = function() end

		self.disc = HACK.MakeButton(self, "ОТКЛЮЧИТЬСЯ", function() self:Disconnect() end)

		-- Плавное появление всего окна.
		self:SetAlpha(0)
		self:AlphaTo(255, 0.6, 0)

		self:InvalidateLayout(true)
	end

	function PANEL:Open(d)
		self.info = d
		self.maxLives = d.lives or 3
		self.lives = self.maxLives
		self.stages = d.stages or 1

		-- Правдоподобный адрес узла, стабильно получаемый из его названия.
		local h = tonumber(util.CRC(tostring(d.node and d.node.name or "node"))) or 0

		self.ip = string.format("10.%d.%d.%d", h % 200 + 10, math.floor(h / 200) % 250, math.floor(h / 50000) % 250 + 2)

		surface.PlaySound("buttons/combine_button1.wav")
	end

	function PANEL:PerformLayout(w, h)
		local pad, top, bottom = Pad(), Top(), Bottom()
		local freeH = h - top - bottom

		-- Область головоломки: по центру, не шире и не выше разумного предела.
		local aw = math.min(w - pad * 2, S(1280))
		local ah = math.min(freeH, S(700))

		self.area:SetSize(aw, ah)
		self.area:SetPos((w - aw) / 2, top + (freeH - ah) / 2)

		self.disc:SetSize(S(200), S(36))
		self.disc:SetPos(w - pad - S(200), h - S(70))

		local by = h - S(176)

		if (IsValid(self.btnDossier)) then
			self.btnDossier:SetSize(S(250), S(46))
			self.btnDossier:SetPos(w / 2 - S(260), by)
		end

		if (IsValid(self.btnClose)) then
			self.btnClose:SetSize(S(210), S(46))
			self.btnClose:SetPos(self.btnDossier and (w / 2 + S(10)) or (w / 2 - S(105)), by)
		end
	end

	-- Первый этап ждёт окончания «загрузки», остальные запускаются сразу.
	function PANEL:SetStage(d, failed)
		if (self.mode == "connect" and CurTime() < self.opened + BOOT_END) then
			self.queued = {d = d, failed = failed}

			return
		end

		self:BuildStage(d, failed)
	end

	function PANEL:Think()
		if (self.queued and CurTime() >= self.opened + BOOT_END) then
			local q = self.queued

			self.queued = nil
			self:BuildStage(q.d, q.failed)
		end
	end

	-- Новый этап (или повтор после ошибки).
	function PANEL:BuildStage(d, failed)
		self.mode = "game"
		self.stage = d.stage or 1
		self.stages = d.stages or self.stages
		self.lives = d.lives or self.lives
		self.gameName = d.gameName
		self.level = d.level
		self.total = math.max(1, d.time or 60)
		self.deadline = CurTime() + self.total
		self.stageAt = SysTime()

		if (IsValid(self.game)) then
			self.game:Remove()
		end

		local game = vgui.Create("ixHackG_" .. tostring(d.game), self.area)

		if (not IsValid(game)) then
			ErrorNoHalt("[Hack] нет панели мини-игры: " .. tostring(d.game) .. "\n")
			HACK.SendToServer("abort")

			return
		end

		game:Dock(FILL)
		game:Setup(d.puzzle or {})
		game:SetAlpha(0)
		game:AlphaTo(255, 0.5, 0.08)
		self.game = game

		if (failed) then
			local text = (d.reason == "time") and "ВРЕМЯ ВЫШЛО" or "ОШИБКА"

			self:Banner(text .. " · ОСТАЛОСЬ ПОПЫТОК: " .. tostring(self.lives), C.bad, 1.8)
			surface.PlaySound("buttons/button10.wav")
		elseif (self.stage > 1) then
			self:Banner("ЭТАП ПРОЙДЕН", C.good, 1.4)
			surface.PlaySound("buttons/button14.wav")
		end
	end

	function PANEL:Banner(text, col, seconds)
		self.banner = {text = text, col = col, start = SysTime(), untilTime = SysTime() + (seconds or 1.5)}
	end

	function PANEL:ShowResult(d)
		self.mode = "result"
		self.result = d
		self.resultAt = SysTime()
		self.finished = true
		self.banner = nil
		self.queued = nil

		if (IsValid(self.game)) then
			self.game:Remove()
		end

		self.disc:SetVisible(false)

		self.btnClose = HACK.MakeButton(self, "ЗАКРЫТЬ", function() self:Remove() end)

		if (d.dossier) then
			self.btnDossier = HACK.MakeButton(self, "ОТКРЫТЬ ДОСЬЕ", function()
				HACK.OpenDossier(d.dossier)
				self:Remove()
			end)
		end

		-- Кнопки появляются после итогового текста.
		for _, b in ipairs({self.btnClose, self.btnDossier}) do
			if (IsValid(b)) then
				b:SetAlpha(0)
				b:AlphaTo(255, 0.5, 1.3)
			end
		end

		self.lineCache = nil
		self:InvalidateLayout(true)

		surface.PlaySound(d.success and "buttons/combine_button3.wav" or "buttons/button10.wav")
	end

	function PANEL:Disconnect()
		if (self.mode ~= "result") then
			self.finished = true
			HACK.SendToServer("abort")
		end

		self:Remove()
	end

	function PANEL:OnRemove()
		-- Окно закрыто любым способом посреди взлома — сообщаем серверу.
		if (not self.finished) then
			self.finished = true
			HACK.SendToServer("abort")
		end

		if (TERM == self) then TERM = nil end
	end

	function PANEL:OnKeyCodePressed(key)
		if (key == KEY_ESCAPE) then
			gui.HideGameUI()
			self:Disconnect()

			return
		end

		if (IsValid(self.game) and self.game.OnKey) then
			self.game:OnKey(key)
		end
	end

	-- ---------------------------------------------------------------- рисование

	-- Шапка: название, подзаголовок, метки. Элементы появляются по очереди.
	function PANEL:PaintHeader(w)
		local info = self.info or {}
		local node = info.node or {}
		local diff = HACK.Difficulty(node.diff or 1)
		local pad = Pad()

		local a1, a2, a3 = Reveal(self, 0.10), Reveal(self, 0.22), Reveal(self, 0.34)

		UI.Track("ТЕРМИНАЛ ВЗЛОМА", "ixHackS", pad, S(46) + (1 - a1) * S(10), UI.A(C.accent, math.floor(220 * a1)), S(5))
		UI.Text(tostring(node.name or "—"), "ixHackT", pad - S(2), S(68) + (1 - a2) * S(12), UI.A(C.text, math.floor(255 * a2)))

		local x, y = pad, S(124)

		x = x + UI.Chip(x, y, "ЗАЩИТА · " .. diff.name, diff.color, nil, a3) + S(30)
		x = x + UI.Chip(x, y, "ЦЕЛЬ · " .. tostring(node.owner or "—"), C.dim, nil, a3) + S(30)

		if (node.typeName and node.typeName ~= "") then
			x = x + UI.Chip(x, y, tostring(node.typeName), C.dim, nil, a3) + S(30)
		end

		UI.Chip(x, y, "УЗЕЛ " .. self.ip, C.cyan, nil, a3)
	end

	-- Тонкая временная линия во всю ширину и подписи под ней.
	function PANEL:PaintTimeline(w)
		local pad = Pad()
		local lw = w - pad * 2
		local ly = S(168)
		local a = Reveal(self, 0.30, 0.6)

		-- Линия «прорисовывается» от левого края.
		local shown = lw * a

		UI.Rect(pad, ly, shown, 1, Color(255, 255, 255, 26))

		if (self.mode == "connect") then
			local frac = math.Clamp((CurTime() - self.opened) / BOOT_END, 0, 1)

			UI.Rect(pad, ly - 1, shown * UI.Ease(frac), 3, UI.A(C.accent, 230))

			return
		end

		if (self.mode == "result") then
			local col = (self.result and self.result.success) and C.good or C.bad
			local k = UI.Ease((SysTime() - (self.resultAt or SysTime())) / 0.8)

			UI.Rect(pad, ly - 1, lw * k, 3, UI.A(col, 230))

			return
		end

		local left = math.max(0, self.deadline - CurTime())
		local frac = math.Clamp(left / self.total, 0, 1)
		local col = frac > 0.3 and C.accent or (frac > 0.15 and C.warn or C.bad)

		if (frac <= 0.15 and math.floor(SysTime() * 3) % 2 == 0) then
			col = UI.Mul(col, 0.6)
		end

		local fw = lw * frac

		UI.Rect(pad, ly - 1, fw, 3, UI.A(col, 230))
		UI.Disc(pad + fw, ly, S(4), col, 14)
		UI.Disc(pad + fw, ly, S(9), UI.A(col, 28), 18)

		-- Подписи: этап и игра слева, время справа.
		local ty = ly + S(16)

		UI.Track(string.format("ЭТАП %02d / %02d", self.stage, self.stages), "ixHackS", pad, ty, C.dim, S(3))
		UI.Text(tostring(self.gameName or ""), "ixHackS", pad + S(200), ty, UI.A(C.text, 200))
		UI.Text(HACK.FormatTime(left), "ixHackM", w - pad, ty - S(4), col, TEXT_ALIGN_RIGHT)
	end

	-- Подключение: кольцо с процентами и бегущая строка текущего шага.
	function PANEL:PaintBoot(w, h)
		local t = CurTime() - self.opened
		local frac = math.Clamp(t / BOOT_END, 0, 1)
		local top, bottom = Top(), Bottom()
		local cx, cy = w / 2, top + (h - top - bottom) / 2 - S(28)
		local R = S(112)
		local appear = Reveal(self, 0.15, 0.6)
		local now = SysTime()

		UI.Ring(cx, cy, R, UI.A(C.line, math.floor(70 * appear)), 1, 96)

		-- Внешние «бегущие» дуги.
		local rot = now * 80

		UI.Arc(cx, cy, R + S(16), 1, rot, rot + 54, UI.A(C.accent, math.floor(150 * appear)), 3)
		UI.Arc(cx, cy, R + S(16), 1, rot + 180, rot + 214, UI.A(C.accent, math.floor(70 * appear)), 3)
		UI.Arc(cx, cy, R - S(16), 1, -rot * 1.4, -rot * 1.4 + 36, UI.A(C.cyan, math.floor(90 * appear)), 3)

		-- Прогресс.
		local pk = UI.EaseIO(frac)

		if (pk > 0.002) then
			UI.Arc(cx, cy, R, 3, -90, -90 + 360 * pk, UI.A(C.accent, 240), 3)

			local ea = math.rad(-90 + 360 * pk)

			UI.Disc(cx + math.cos(ea) * R, cy + math.sin(ea) * R, S(5), C.accent, 14)
			UI.Disc(cx + math.cos(ea) * R, cy + math.sin(ea) * R, S(11), UI.A(C.accent, 30), 18)
		end

		-- Проценты.
		local pct = math.floor(pk * 100)

		UI.Text(tostring(pct), "ixHackD", cx, cy - S(4), UI.A(C.text, math.floor(255 * appear)), 1, 1)
		UI.Track("ПОДКЛЮЧЕНИЕ", "ixHackXS", cx, cy + S(52), UI.A(C.dim, math.floor(230 * appear)), S(4), 1, 1)

		-- Текущий шаг.
		local idx = math.Clamp(math.floor(t / BOOT_STEP) + 1, 1, #BOOT)
		local start = (idx - 1) * BOOT_STEP
		local txt = string.format(BOOT[idx], self.ip)
		local count = utf8.len(txt) or #txt
		local shown = UI.Sub(txt, math.floor(math.Clamp((t - start) / (BOOT_STEP * 0.8), 0, 1) * count))
		local sy = cy + R + S(64)

		UI.Track(string.format("%02d / %02d", idx, #BOOT), "ixHackXS", cx, sy - S(26), UI.A(C.dim, 200), S(3), 1, 1)
		UI.Text(shown, "ixHackM", cx, sy, UI.A(C.text, 230), 1, 1)
	end

	-- Итог: кольцо «прорисовывается», появляется галочка/крест, заголовок и строки по очереди.
	function PANEL:PaintResult(w, h)
		local d = self.result or {}
		local col = d.success and C.good or C.bad
		local t = SysTime() - (self.resultAt or SysTime())
		local cx, cy = w / 2, S(300)
		local R = S(52)

		UI.Ring(cx, cy, R, UI.A(col, 40), 1, 64)
		UI.Arc(cx, cy, R, 3, -90, -90 + 360 * UI.Ease(t / 0.8), UI.A(col, 240), 3)

		if (d.success) then
			local p1, p2, p3 = {cx - S(19), cy + S(2)}, {cx - S(6), cy + S(16)}, {cx + S(21), cy - S(14)}

			UI.LinePart(p1[1], p1[2], p2[1], p2[2], col, 4, (t - 0.55) / 0.18)
			UI.LinePart(p2[1], p2[2], p3[1], p3[2], col, 4, (t - 0.72) / 0.24)

			-- Тихая рябь после завершения.
			if (t > 0.95) then
				local k = ((t - 0.95) * 0.5) % 1

				UI.Ring(cx, cy, R + k * S(90), UI.A(col, math.floor(90 * (1 - k))), 1, 64)
			end
		else
			local a = S(15)

			UI.LinePart(cx - a, cy - a, cx + a, cy + a, col, 4, (t - 0.55) / 0.2)
			UI.LinePart(cx - a, cy + a, cx + a, cy - a, col, 4, (t - 0.72) / 0.2)

			if (t > 0.95) then
				local pulse = 0.5 + 0.5 * math.sin((t - 0.95) * 5)

				UI.Ring(cx, cy, R + S(8) + pulse * S(6), UI.A(col, math.floor(60 * (1 - pulse * 0.5))), 1, 64)
			end
		end

		-- Заголовок.
		local ta = UI.Ease((t - 0.6) / 0.5)
		local ty = cy + S(108) + (1 - ta) * S(14)

		UI.Text(tostring(d.title or ""), "ixHackT2", cx, ty, UI.A(col, math.floor(255 * ta)), 1, 1)

		-- Строки по очереди.
		self.lineCache = self.lineCache or {}

		local maxw = math.min(S(900), w - Pad() * 2)
		local y = ty + S(56)
		local n = 0

		for i, line in ipairs(d.lines or {}) do
			self.lineCache[i] = self.lineCache[i] or Wrap(line, "ixHackM", maxw)

			for _, piece in ipairs(self.lineCache[i]) do
				n = n + 1

				local la = UI.Ease((t - 0.95 - n * 0.07) / 0.4)

				UI.Text(piece, "ixHackM", cx, y + (1 - la) * S(8), UI.A(C.text, math.floor(225 * la)), 1, 0)

				y = y + S(30)
			end

			y = y + S(12)
		end
	end

	function PANEL:PaintFooter(w, h)
		local pad = Pad()
		local y = h - S(52)
		local a = Reveal(self, 0.45, 0.5)

		if (self.mode == "result") then
			UI.Track("СЕАНС ЗАВЕРШЁН", "ixHackXS", w / 2, y + S(4), UI.A(C.dim, math.floor(220 * a)), S(5), 1, 1)

			return
		end

		-- Попытки.
		UI.Track("ПОПЫТКИ", "ixHackS", pad, y + S(2), UI.A(C.dim, math.floor(230 * a)), S(3), 0, 1)

		UI.Pips(pad + S(120), y + S(2), self.maxLives, self.lives, S(6), S(8),
			self.lives <= 1 and C.bad or C.good)

		-- Служебная строка посередине.
		local ping = 14 + math.floor(UI.Rand(math.floor(SysTime() * 2), 7) * 26)
		local packets = math.floor((CurTime() - self.opened) * 37)

		UI.Track(string.format("AES-256  ·  %d МС  ·  %d ПАКЕТОВ", ping, packets), "ixHackXS", w / 2, y + S(4),
			UI.A(C.dim, math.floor(170 * a)), S(3), 1, 1)
	end

	function PANEL:Paint(w, h)
		UI.Window(self, w, h)

		-- Верхняя акцентная линия «раскрывается» от центра при открытии.
		local ok = UI.Ease((SysTime() - self.openAt) / 0.8)

		UI.Rect(w / 2 - w * ok / 2, 0, w * ok, 2, UI.A(C.accent, math.floor(60 + 180 * (1 - ok))))

		self:PaintHeader(w)
		self:PaintTimeline(w)

		if (self.mode == "connect") then
			self:PaintBoot(w, h)
		elseif (self.mode == "result") then
			self:PaintResult(w, h)
		end

		self:PaintFooter(w, h)
	end

	function PANEL:PaintOver(w, h)
		UI.Overlay(w, h)

		-- Вспышка-линия при смене этапа: раскрывается над областью задания.
		local st = SysTime() - self.stageAt

		if (self.mode == "game" and st >= 0 and st < 0.7 and IsValid(self.area)) then
			local ax, ay = self.area:GetPos()
			local aw = self.area:GetWide()
			local k = UI.Ease(st / 0.45)

			UI.Rect(ax + aw / 2 - aw * k / 2, ay - S(6), aw * k, 1, UI.A(C.accent, math.floor(200 * (1 - st / 0.7))))
		end

		local banner = self.banner

		if (not banner) then return end

		local now = SysTime()

		if (now > banner.untilTime) then
			self.banner = nil

			return
		end

		local k = UI.Ease((now - banner.start) / 0.28)
		local af = math.min(1, (banner.untilTime - now) / 0.25)
		local top, bottom = Top(), Bottom()
		local cy = top + (h - top - bottom) / 2
		local hh = S(46) * k

		Rect(0, cy - hh, w, hh * 2, Color(0, 0, 0, math.floor(200 * af)))
		Rect(w / 2 - w * k / 2, cy - hh, w * k, 1, UI.A(banner.col, math.floor(200 * af)))
		Rect(w / 2 - w * k / 2, cy + hh - 1, w * k, 1, UI.A(banner.col, math.floor(200 * af)))

		if (k > 0.6) then
			local ta = math.Clamp((k - 0.6) / 0.4, 0, 1) * af

			UI.Track(banner.text, "ixHackL", w / 2, cy, UI.A(banner.col, math.floor(255 * ta)), S(6), 1, 1)
		end
	end

	vgui.Register("ixHackTerminal", PANEL, "EditablePanel")
end

-- =====================================================================================
--  Обработчики сообщений сервера
-- =====================================================================================

HACK.handlers.open = function(d)
	if (IsValid(TERM)) then
		TERM.finished = true
		TERM:Remove()
	end

	TERM = vgui.Create("ixHackTerminal")
	TERM:Open(d)
end

HACK.handlers.stage = function(d)
	if (IsValid(TERM)) then
		TERM:SetStage(d, false)
	else
		-- Окна нет, а сервер ждёт ответа: закрываем сеанс.
		HACK.SendToServer("abort")
	end
end

HACK.handlers.stagefail = function(d)
	if (IsValid(TERM)) then
		TERM:SetStage(d, true)
	else
		HACK.SendToServer("abort")
	end
end

HACK.handlers.feedback = function(d)
	if (IsValid(TERM) and IsValid(TERM.game) and TERM.game.OnFeedback) then
		TERM.game:OnFeedback(d)
	end
end

HACK.handlers.result = function(d)
	if (IsValid(TERM)) then
		TERM:ShowResult(d)

		return
	end

	-- Окно уже закрыто (например, игрок сам отключился): показываем итог в чате.
	local col = d.success and C.good or C.bad

	chat.AddText(Color(90, 255, 150), "[СЕТЬ] ", col, tostring(d.title or ""), color_white, " — " .. table.concat(d.lines or {}, " "))

	if (d.dossier) then
		HACK.OpenDossier(d.dossier)
	end
end

-- =====================================================================================
--  Окно досье
-- =====================================================================================

local DOSSIER

do
	local PANEL = {}

	-- Колонки списка бойцов: заголовок, ширина (доля), функция значения.
	local function Columns(tier)
		local cols = {
			{"№", 0.05, function(row, i) return tostring(i) end},
			{"ЗВАНИЕ", tier >= 4 and 0.17 or 0.34, function(row) return tostring(row.rank or "—") end},
			{"ИМЯ", tier >= 4 and 0.28 or 0.61, function(row) return tostring(row.name or "?") end}
		}

		if (tier >= 4) then
			cols[#cols + 1] = {"ДОЛЖНОСТЬ", 0.16, function(row) return tostring(row.class or "—") end}
			cols[#cols + 1] = {"СТАТУС", 0.10, function(row) return row.online and "В СЕТИ" or "НЕ В СЕТИ" end,
				function(row) return row.online and C.good or C.dim end}
			cols[#cols + 1] = {"ЗАЧИСЛЕН", 0.09, function(row) return DateText(row.since) end}
			cols[#cols + 1] = {"ВЗЫСК/ПООЩР", 0.15, function(row) return (row.rep or 0) .. " / " .. (row.com or 0) end}
		end

		return cols
	end

	function PANEL:Init()
		self:SetSize(math.min(S(1100), ScrW() - S(40)), math.min(S(740), ScrH() - S(40)))
		self:Center()
		self:MakePopup()

		self.close = HACK.MakeButton(self, "ЗАКРЫТЬ", function() self:Remove() end)
	end

	function PANEL:OnKeyCodePressed(key)
		if (key == KEY_ESCAPE) then
			gui.HideGameUI()
			self:Remove()
		end
	end

	function PANEL:OnRemove()
		if (DOSSIER == self) then DOSSIER = nil end
	end

	function PANEL:Setup(d)
		self.d = d

		local tier = d.tier or 1

		if (tier >= 3 and #(d.list or {}) > 0) then
			local scroll = vgui.Create("DScrollPanel", self)

			StyleScroll(scroll)

			self.scroll = scroll
			self.cols = Columns(tier)

			for i, row in ipairs(d.list) do
				local line = scroll:Add("EditablePanel")

				line:Dock(TOP)
				line:SetTall(S(30))
				line:DockMargin(0, 0, S(6), S(2))

				line.Paint = function(p, w, h)
					Rect(0, 0, w, h, (i % 2 == 0) and C.panel or C.bg)

					if (tier >= 4 and row.online) then
						Rect(0, 0, S(3), h, C.good)
					end

					local x = S(10)

					for _, col in ipairs(self.cols) do
						local cw = (w - S(20)) * col[2]
						local color = col[4] and col[4](row) or C.text

						-- Длинные значения обрезаем по ширине колонки.
						local value = col[3](row, i)

						surface.SetFont("ixHackS")

						while (#value > 1 and surface.GetTextSize(value) > cw - S(8)) do
							value = string.sub(value, 1, -2)
						end

						Text(value, "ixHackS", x, h / 2, color, 0, 1)

						x = x + cw
					end
				end
			end
		end

		self:InvalidateLayout(true)
	end

	function PANEL:PerformLayout(w, h)
		self.close:SetSize(S(150), S(34))
		self.close:SetPos(w - S(166), S(14))

		if (IsValid(self.scroll)) then
			local top = S(190)
			local left = (self.d.ranks and #self.d.ranks > 0) and S(300) or S(16)

			self.scroll:SetPos(left, top + S(30))
			self.scroll:SetSize(w - left - S(16), h - top - S(30) - S(16))
		end
	end

	function PANEL:PaintOver(w, h)
		UI.Overlay(w, h)
	end

	function PANEL:Paint(w, h)
		UI.Window(self, w, h)

		local d = self.d

		if (not d) then return end

		local tier = d.tier or 1

		UI.Glow("ДОСЬЕ: " .. tostring(d.faction or "?"), "ixHackL", S(20), S(10), C.text, 0, 0, 1)
		Text("Получено " .. DateText(d.time, true) .. "  ·  уровень доступа " .. tier .. "/4", "ixHackS", S(22), S(48), C.dim)
		Text(HACK.archiveTiers[tier] or "", "ixHackS", S(22), S(70), C.warn)

		surface.SetDrawColor(C.line)
		surface.DrawRect(S(16), S(100), w - S(32), 1)

		-- Сводка.
		Text("ЛИЧНЫЙ СОСТАВ", "ixHackS", S(22), S(118), C.dim)
		Text(tostring(d.total or 0), "ixHackXL", S(22), S(134), C.text)

		Text("В СЕТИ", "ixHackS", S(220), S(118), C.dim)
		Text(tostring(d.online or 0), "ixHackXL", S(220), S(134), C.good)

		if (tier < 3) then
			Text("Имена и звания личного состава недоступны. Для них нужен узел более высокой сложности.",
				"ixHackS", S(22), S(214), C.dim)
		end

		-- Структура по званиям.
		local ranks = d.ranks or {}

		if (#ranks > 0) then
			local x, y, rw = S(22), S(190), S(260)
			local max = 1

			for _, r in ipairs(ranks) do max = math.max(max, r.count or 0) end

			Text("ПО ЗВАНИЯМ", "ixHackS", x, y, C.dim)

			y = y + S(28)

			for _, r in ipairs(ranks) do
				if (y > h - S(40)) then break end

				Rect(x, y, rw, S(24), C.panel)
				Rect(x, y, rw * ((r.count or 0) / max), S(24), C.faint)
				Text(tostring(r.name), "ixHackS", x + S(6), y + S(12), C.text, 0, 1)
				Text(tostring(r.count), "ixHackS", x + rw - S(6), y + S(12), C.good, TEXT_ALIGN_RIGHT, 1)

				y = y + S(28)
			end
		end

		-- Шапка таблицы.
		if (self.cols) then
			local left = (#ranks > 0) and S(300) or S(16)
			local tw = w - left - S(16) - S(6)
			local x = left + S(10)

			Rect(left, S(190), w - left - S(16), S(26), C.panel)

			for _, col in ipairs(self.cols) do
				Text(col[1], "ixHackS", x, S(203), C.dim, 0, 1)

				x = x + (tw - S(20)) * col[2]
			end

			if (d.truncated) then
				Text("Список обрезан: показаны первые " .. #(d.list or {}) .. " записей.", "ixHackS", left, h - S(14), C.warn, 0, 1)
			end
		end
	end

	vgui.Register("ixHackDossier", PANEL, "EditablePanel")
end

function HACK.OpenDossier(d)
	if (type(d) ~= "table") then return end

	if (IsValid(DOSSIER)) then
		DOSSIER:Remove()
	end

	DOSSIER = vgui.Create("ixHackDossier")
	DOSSIER:Setup(d)
end
