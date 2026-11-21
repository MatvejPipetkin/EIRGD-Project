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

	function PANEL:Init()
		self:SetSize(math.min(S(1060), ScrW() - S(40)), math.min(S(720), ScrH() - S(40)))
		self:Center()
		self:MakePopup()
		self:SetKeyboardInputEnabled(true)

		self.mode = "connect"       -- connect -> game -> result
		self.opened = CurTime()
		self.stage, self.stages = 0, 1
		self.lives, self.maxLives = 3, 3
		self.deadline, self.total = 0, 1
		self.finished = false
		self.ip = "10.0.0.1"

		self.area = vgui.Create("EditablePanel", self)
		self.area.Paint = function() end

		self.disc = HACK.MakeButton(self, "ОТКЛЮЧИТЬСЯ", function() self:Disconnect() end)

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
		local top = S(118)

		self.area:SetPos(S(20), top)
		self.area:SetSize(w - S(40), h - top - S(44))

		self.disc:SetSize(S(170), S(32))
		self.disc:SetPos(w - S(170) - S(16), S(12))

		if (IsValid(self.btnDossier)) then
			self.btnDossier:SetSize(S(240), S(40))
			self.btnDossier:SetPos(w / 2 - S(250), h - S(92))
		end

		if (IsValid(self.btnClose)) then
			self.btnClose:SetSize(S(200), S(40))
			self.btnClose:SetPos(self.btnDossier and (w / 2 + S(10)) or (w / 2 - S(100)), h - S(92))
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
		game:AlphaTo(255, 0.35, 0)
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
		self.banner = {text = text, col = col, start = CurTime(), untilTime = CurTime() + (seconds or 1.5)}
	end

	function PANEL:ShowResult(d)
		self.mode = "result"
		self.result = d
		self.resultAt = CurTime()
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

	function PANEL:PaintHeader(w)
		local info = self.info or {}
		local node = info.node or {}
		local diff = HACK.Difficulty(node.diff or 1)

		-- Эмблема.
		UI.Diamond(S(36), S(34), S(15), UI.A(C.accent, 40))
		UI.Diamond(S(36), S(34), S(11), C.accent)
		UI.Diamond(S(36), S(34), S(7), C.bg)
		UI.Diamond(S(36), S(34), S(3), C.accent)

		UI.Glow("ТЕРМИНАЛ ВЗЛОМА", "ixHackL", S(64), S(14), C.text, 0, 0, 1)
		Text(tostring(node.name or "—") .. "  ·  " .. tostring(node.typeName or ""), "ixHackM", S(66), S(50), C.dim)

		local x = S(24)

		x = x + UI.Chip(x, S(80), "ЗАЩИТА: " .. diff.name, diff.color) + S(8)
		x = x + UI.Chip(x, S(80), "ЦЕЛЬ: " .. tostring(node.owner or "—"), C.dim) + S(8)
		UI.Chip(x, S(80), "УЗЕЛ " .. self.ip, C.cyan)

		-- Разделитель с бегущим бликом.
		Rect(S(16), S(110), w - S(32), 1, UI.A(C.line, 200))

		local k = (SysTime() * 0.3) % 1

		Rect(S(16) + (w - S(32) - S(120)) * k, S(109), S(120), 3, UI.A(C.accent, 150))
	end

	function PANEL:PaintStatus(w)
		local cw, ch = S(430), S(58)
		local x, y = w - cw - S(16), S(50)

		UI.Box(x, y, cw, ch, C.accent, 190)

		UI.Glow("ЭТАП " .. self.stage .. "/" .. self.stages, "ixHackM", x + S(14), y + S(7), C.text, 0, 0, 0.7)
		Text(self.gameName or "", "ixHackS", x + S(124), y + S(11), C.dim)

		local total = self.maxLives * (S(12) + S(6)) - S(6)

		UI.Pips(x + cw - S(14) - total, y + S(17), self.maxLives, self.lives, S(6), S(6),
			self.lives <= 1 and C.bad or C.good)

		local left = math.max(0, self.deadline - CurTime())
		local frac = math.Clamp(left / self.total, 0, 1)
		local col = frac > 0.3 and C.accent or (frac > 0.15 and C.warn or C.bad)

		if (frac <= 0.15 and math.floor(SysTime() * 3) % 2 == 0) then
			col = UI.Mul(col, 0.6)
		end

		UI.Bar(x + S(14), y + S(38), cw - S(100), S(10), frac, col, 30)
		Text(HACK.FormatTime(left), "ixHackM", x + cw - S(14), y + S(43), col, TEXT_ALIGN_RIGHT, 1)
	end

	function PANEL:PaintBoot(w, h)
		local t = CurTime() - self.opened
		local x, y = S(64), S(170)

		for i, line in ipairs(BOOT) do
			local start = (i - 1) * BOOT_STEP

			if (t >= start) then
				local txt = string.format(line, self.ip)
				local done = t >= start + BOOT_STEP
				local count = utf8.len(txt) or #txt
				local shown = done and txt or UI.Sub(txt, math.floor((t - start) / BOOT_STEP * count))

				Text("> " .. shown, "ixHackM", x, y, C.text)

				if (done) then
					Text("[ OK ]", "ixHackM", x + S(560), y, C.good)
				end

				y = y + S(34)
			end
		end

		UI.HexStream(w - S(250), S(150), 24, C.accent)

		-- Индикатор подключения.
		local cx, cy = w / 2, h - S(150)
		local frac = math.Clamp(t / BOOT_END, 0, 1)

		UI.Ring(cx - S(190), cy, S(14), UI.A(C.line, 200), 2)
		UI.Arc(cx - S(190), cy, S(14), 4, SysTime() * 300, SysTime() * 300 + 100, C.accent)
		UI.Glow("УСТАНАВЛИВАЕТСЯ СОЕДИНЕНИЕ", "ixHackM", cx - S(160), cy - S(2), C.text, 0, 1, 0.8)
		UI.Bar(cx - S(200), cy + S(24), S(400), S(8), frac, C.accent, 20)
	end

	function PANEL:PaintResult(w, h)
		local d = self.result or {}
		local col = d.success and C.good or C.bad
		local t = CurTime() - (self.resultAt or CurTime())
		local cx, cy = w / 2, S(190)

		if (d.success) then
			for i = 0, 2 do
				local k = (t * 0.55 + i / 3) % 1

				UI.Ring(cx, cy, S(36) + k * S(110), UI.A(col, 130 * (1 - k)), 2)
			end

			UI.Ring(cx, cy, S(40), UI.A(col, 220), 3)
			UI.Line(cx - S(18), cy + S(2), cx - S(5), cy + S(16), col, 5)
			UI.Line(cx - S(5), cy + S(16), cx + S(20), cy - S(14), col, 5)
		else
			local pulse = 0.6 + 0.4 * math.sin(t * 6)

			UI.Ring(cx, cy, S(40), UI.A(col, 220 * pulse), 3)
			UI.Line(cx - S(15), cy - S(15), cx + S(15), cy + S(15), col, 5)
			UI.Line(cx - S(15), cy + S(15), cx + S(15), cy - S(15), col, 5)
		end

		local title = tostring(d.title or "")
		local ty = cy + S(88)

		if (not d.success and UI.Rand(math.floor(SysTime() * 8), 3) < 0.3) then
			local j = S(3)

			Text(title, "ixHackXL", cx + j, ty, UI.A(C.cyan, 120), 1, 1)
			Text(title, "ixHackXL", cx - j, ty, UI.A(C.bad, 160), 1, 1)
		end

		UI.Glow(title, "ixHackXL", cx, ty, col, 1, 1, 1.4)

		self.lineCache = self.lineCache or {}

		local pieces = {}

		for i, line in ipairs(d.lines or {}) do
			self.lineCache[i] = self.lineCache[i] or Wrap(line, "ixHackM", w - S(220))

			for _, piece in ipairs(self.lineCache[i]) do pieces[#pieces + 1] = piece end

			pieces[#pieces + 1] = false
		end

		local bh = S(24)

		for _, piece in ipairs(pieces) do bh = bh + (piece and S(30) or S(10)) end

		local bw = w - S(180)
		local by = ty + S(46)

		UI.Box(w / 2 - bw / 2, by, bw, bh, col, 190)

		local y = by + S(14)

		for _, piece in ipairs(pieces) do
			if (piece) then
				Text(piece, "ixHackM", w / 2, y, C.text, 1, 0)

				y = y + S(30)
			else
				y = y + S(10)
			end
		end
	end

	function PANEL:PaintFooter(w, h)
		local y = h - S(30)

		Rect(S(16), y - S(4), w - S(32), 1, UI.A(C.line, 120))

		if (self.mode == "result") then
			Text("СЕАНС ЗАВЕРШЁН", "ixHackXS", S(24), y + S(5), C.dim)

			return
		end

		local ping = 14 + math.floor(UI.Rand(math.floor(SysTime() * 2), 7) * 26)
		local packets = math.floor((CurTime() - self.opened) * 37)

		Text(string.format("СЕАНС ЗАШИФРОВАН  ·  AES-256  ·  ПИНГ %d мс  ·  ПАКЕТОВ %d", ping, packets),
			"ixHackXS", S(24), y + S(5), C.dim)
		Text("ESC — ОТКЛЮЧИТЬСЯ", "ixHackXS", w - S(24), y + S(5), C.dim, TEXT_ALIGN_RIGHT)
	end

	function PANEL:Paint(w, h)
		UI.Window(self, w, h)
		self:PaintHeader(w)

		if (self.mode == "connect") then
			self:PaintBoot(w, h)
		elseif (self.mode == "game") then
			self:PaintStatus(w)
		else
			self:PaintResult(w, h)
		end

		self:PaintFooter(w, h)
	end

	function PANEL:PaintOver(w, h)
		UI.Overlay(w, h)

		local banner = self.banner

		if (not banner) then return end

		if (CurTime() > banner.untilTime) then
			self.banner = nil

			return
		end

		local k = math.min(1, (CurTime() - banner.start) / 0.18)
		local bh = S(76) * k
		local y = S(118) + (h - S(118)) / 2 - bh / 2

		Rect(0, y, w, bh, Color(0, 0, 0, 215))
		UI.Fade(0, y, w, bh, "down", banner.col, 40, 0, 8)
		Rect(0, y, w, 2, banner.col)
		Rect(0, y + bh - 2, w, 2, banner.col)

		if (k >= 1) then
			UI.Glow(banner.text, "ixHackL", w / 2, y + bh / 2, banner.col, 1, 1, 1.4)
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
