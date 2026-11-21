-- Клиентские панели мини-игр. Головоломка приходит от сервера; ответ уходит на сервер,
-- он же решает, выиграно или проиграно. Панель получает Setup(public), может иметь OnKey(key)
-- и OnFeedback(data) (ответ сервера на попытку). Общая отрисовка - в cl_ui.lua (HACK.UI).

local HACK = ix.hack
local C, S, UI = HACK.C, HACK.S, HACK.UI
local Rect, Frame, Text, Glow, A = UI.Rect, UI.Frame, UI.Text, UI.Glow, UI.A

local TAU = math.pi * 2

local function Inside(mx, my, x, y, w, h)
	return mx >= x and mx <= x + w and my >= y and my <= y + h
end

-- Строка подсказки сверху игры.
local function Hint(self, str, w)
	Text(str, "ixHackS", w / 2, S(12), C.dim, 1, 1)
	Rect(S(40), S(26), w - S(80), 1, A(C.line, 120))
end

-- =====================================================================================
--  1. ПОДБОР ПАРОЛЯ (дамп памяти: найти пароль по числу совпавших букв)
-- =====================================================================================

do
	local PANEL = {}

	local COLS, ROWS, WIDTH = 2, 15, 17
	local JUNK = "!@#$%^&*()_+-=[]{};:<>,./?|~"

	local function Rng(seed)
		local s = seed % 2147483647

		if (s <= 0) then s = s + 2147483646 end

		return function(n)
			s = (s * 48271) % 2147483647

			return (s % n) + 1
		end
	end

	function PANEL:Setup(p)
		self.p = p
		self.history = {}
		self.tried = {}
		self.flash = {}
		self.pending = false
		self:Build()
	end

	-- Дамп строим по зерну от сервера: мусор и места слов случайные, но одинаковые при каждой отрисовке.
	function PANEL:Build()
		local p = self.p
		local rnd = Rng(p.seed or 1)
		local total = COLS * ROWS
		local order = {}

		for i = 1, total do order[i] = i end

		for i = total, 2, -1 do
			local j = rnd(i)

			order[i], order[j] = order[j], order[i]
		end

		local rows = {}

		for r = 1, total do
			local chars = {}

			for k = 1, WIDTH do
				local n = rnd(#JUNK)

				chars[k] = string.sub(JUNK, n, n)
			end

			rows[r] = {chars = chars, addr = string.format("0x%04X", 0xF4A0 + (r - 1) * WIDTH)}
		end

		for i, word in ipairs(p.words) do
			local row = rows[order[i]]
			local start = rnd(WIDTH - #word + 1)

			for k = 1, #word do
				row.chars[start + k - 1] = string.sub(word, k, k)
			end

			row.word = {text = word, start = start, len = #word}
		end

		for _, row in ipairs(rows) do
			row.text = table.concat(row.chars)
		end

		self.rows = rows
	end

	function PANEL:Metrics()
		surface.SetFont("ixHackM")

		local cw, ch = surface.GetTextSize("0")
		local rowH = math.floor(ch * 1.12)
		local addrW = cw * 8

		return cw, rowH, addrW, addrW + cw * WIDTH + S(30)
	end

	function PANEL:WordAt(mx, my)
		local cw, rowH, addrW, colW = self:Metrics()

		for r, row in ipairs(self.rows) do
			if (row.word) then
				local c = math.floor((r - 1) / ROWS)
				local rr = (r - 1) % ROWS
				local x = S(24) + c * colW + addrW + cw * (row.word.start - 1)
				local y = S(44) + rr * rowH

				if (Inside(mx, my, x - 2, y, cw * row.word.len + 4, rowH)) then
					return row.word.text, x, y
				end
			end
		end
	end

	function PANEL:OnMousePressed(code)
		if (code ~= MOUSE_LEFT or self.pending or self.done) then return end

		local word = self:WordAt(self:CursorPos())

		if (not word or self.tried[word]) then return end

		self.pending = true
		surface.PlaySound("buttons/button17.wav")
		HACK.SendToServer("submit", {word = word})
	end

	function PANEL:OnFeedback(d)
		self.pending = false

		if (type(d) ~= "table" or not d.word) then return end

		self.tried[d.word] = d.like
		self.history[#self.history + 1] = {word = d.word, like = d.like}
		self.flash[d.word] = CurTime() + 0.6

		if (d.like >= self.p.len) then
			self.done = true
			surface.PlaySound("buttons/button14.wav")
		else
			surface.PlaySound("buttons/button10.wav")
		end
	end

	function PANEL:Paint(w, h)
		local p = self.p

		if (not p) then return end

		Hint(self, "НАЙДИТЕ ПАРОЛЬ В ДАМПЕ ПАМЯТИ  ·  УЗЕЛ СООБЩАЕТ, СКОЛЬКО БУКВ СТОИТ НА СВОЁМ МЕСТЕ", w)

		local cw, rowH, addrW, colW = self:Metrics()
		local mx, my = self:CursorPos()
		local hover = (not self.pending and not self.done) and self:WordAt(mx, my) or nil

		for r, row in ipairs(self.rows) do
			local c = math.floor((r - 1) / ROWS)
			local rr = (r - 1) % ROWS
			local x = S(24) + c * colW
			local y = S(44) + rr * rowH
			local tx = x + addrW

			Text(row.addr, "ixHackM", x, y, C.faint)

			if (not row.word) then
				Text(row.text, "ixHackM", tx, y, A(C.dim, 150))
			else
				local wd = row.word
				local before = string.sub(row.text, 1, wd.start - 1)
				local after = string.sub(row.text, wd.start + wd.len)
				local wx = tx + cw * (wd.start - 1)
				local like = self.tried[wd.text]

				Text(before, "ixHackM", tx, y, A(C.dim, 150))
				Text(after, "ixHackM", wx + cw * wd.len, y, A(C.dim, 150))

				if (like) then
					Rect(wx - 2, y, cw * wd.len + 4, rowH, A(C.bad, 26))
					Text(wd.text, "ixHackM", wx, y, A(C.bad, 170))
					Rect(wx, y + rowH / 2, cw * wd.len, 1, A(C.bad, 170))
				elseif (hover == wd.text) then
					Rect(wx - 2, y, cw * wd.len + 4, rowH, A(C.accent, 70))
					Frame(wx - 2, y, cw * wd.len + 4, rowH, C.accent, 1)
					Text(wd.text, "ixHackM", wx, y, C.bg)
				else
					Text(wd.text, "ixHackM", wx, y, C.text)
				end

				if ((self.flash[wd.text] or 0) > CurTime()) then
					Rect(wx - 2, y, cw * wd.len + 4, rowH, A(C.warn, 60))
				end
			end
		end

		-- Журнал попыток справа.
		local lx = S(24) + COLS * colW + S(4)
		local lw = w - lx - S(16)

		UI.Box(lx, S(40), lw, h - S(54), C.accent, 200)
		Glow("ЖУРНАЛ ВХОДА", "ixHackM", lx + S(14), S(50), C.text, 0, 0, 0.7)

		local left = p.attempts - #self.history

		Text("ПОПЫТОК:", "ixHackS", lx + S(14), S(84), C.dim)
		UI.Pips(lx + S(100), S(92), p.attempts, left, S(6), S(6), left <= 1 and C.bad or C.accent)

		local y = S(116)
		local first = math.max(1, #self.history - 7)

		for i = first, #self.history do
			local e = self.history[i]
			local full = e.like >= p.len

			Text("> " .. e.word, "ixHackM", lx + S(14), y, full and C.good or C.text)
			Text(e.like .. "/" .. p.len, "ixHackM", lx + lw - S(14), y, full and C.good or (e.like > 0 and C.warn or C.dim), TEXT_ALIGN_RIGHT)

			UI.Bar(lx + S(14), y + S(24), lw - S(28), S(4), e.like / p.len, full and C.good or C.accent)

			y = y + S(42)
		end

		if (#self.history == 0) then
			Text("Выберите слово в дампе —", "ixHackS", lx + S(14), y, C.dim)
			Text("узел покажет совпадения.", "ixHackS", lx + S(14), y + S(20), C.dim)
		end

		local blink = (math.floor(SysTime() * 2) % 2 == 0) and "_" or " "

		Text("> " .. (hover or "") .. blink, "ixHackM", lx + S(14), h - S(52), C.accent)
	end

	vgui.Register("ixHackG_crack", PANEL, "EditablePanel")
end

-- =====================================================================================
--  2. ДЕШИФРОВКА (шифр-диск)
-- =====================================================================================

do
	local PANEL = {}

	local function Letter(i) return string.char(65 + i % 26) end

	function PANEL:Setup(p)
		self.p = p
		self.typed = ""
		self.wrongUntil = 0
		self.pending = false

		-- Реальный сдвиг клиент знает по подсказке; стартовое положение диска делаем заведомо неверным.
		local k = (string.byte(p.hintCipher) - string.byte(p.hintPlain)) % 26

		self.r = (k + math.random(6, 20)) % 26
		self.disp = self.r
		self.left = p.tries
		self.inCipher = {}

		for i = 1, #p.cipher do
			self.inCipher[string.byte(p.cipher, i) - 65] = true
		end
	end

	function PANEL:Geo()
		local w, h = self:GetSize()

		return w * 0.3, h * 0.5 + S(4), math.min(h * 0.44, w * 0.27)
	end

	function PANEL:Rotate(d)
		self.r = (self.r + d) % 26
		surface.PlaySound("buttons/button16.wav")
	end

	function PANEL:OnMouseWheeled(delta)
		self:Rotate(delta > 0 and 1 or -1)
	end

	function PANEL:ButtonRects()
		local cx, cy, R = self:Geo()
		local bw, bh = S(90), S(34)

		return {x = cx - R * 0.5 - bw / 2, y = cy + R + S(14), w = bw, h = bh, d = -1, label = "◄"},
			{x = cx + R * 0.5 - bw / 2, y = cy + R + S(14), w = bw, h = bh, d = 1, label = "►"}
	end

	function PANEL:OnMousePressed(code)
		if (code ~= MOUSE_LEFT) then return end

		local mx, my = self:CursorPos()

		for _, b in ipairs({self:ButtonRects()}) do
			if (Inside(mx, my, b.x, b.y, b.w, b.h)) then
				self:Rotate(b.d)

				return
			end
		end
	end

	function PANEL:Add(ch)
		if (self.pending or #self.typed >= #self.p.cipher) then return end

		self.typed = self.typed .. ch
		surface.PlaySound("buttons/button17.wav")

		if (#self.typed == #self.p.cipher) then
			self.pending = true
			HACK.SendToServer("submit", {guess = self.typed})
		end
	end

	function PANEL:OnKey(key)
		if (key >= KEY_A and key <= KEY_Z) then
			self:Add(string.char(65 + key - KEY_A))
		elseif (key == KEY_BACKSPACE) then
			if (not self.pending and #self.typed > 0) then
				self.typed = string.sub(self.typed, 1, -2)
			end
		elseif (key == KEY_LEFT) then
			self:Rotate(-1)
		elseif (key == KEY_RIGHT) then
			self:Rotate(1)
		end
	end

	function PANEL:OnFeedback(d)
		self.pending = false

		if (type(d) == "table" and d.wrong) then
			self.typed = ""
			self.left = d.left
			self.wrongUntil = CurTime() + 0.8
			surface.PlaySound("buttons/button10.wav")
		end
	end

	function PANEL:Paint(w, h)
		local p = self.p

		if (not p) then return end

		Hint(self, "ВЫСТАВЬТЕ ДИСК ПО ИЗВЕСТНОЙ ПАРЕ, ПРОЧТИТЕ СООБЩЕНИЕ И ВВЕДИТЕ ЕГО  ·  ◄ ► / КОЛЕСО МЫШИ — ВРАЩЕНИЕ", w)

		-- Плавное вращение к целевому положению по кратчайшему пути.
		local diff = ((self.r - self.disp + 13) % 26) - 13

		self.disp = self.disp + diff * math.min(1, FrameTime() * 10)

		local cx, cy, R = self:Geo()
		local step = 360 / 26
		local hintC = string.byte(p.hintCipher) - 65
		local hintP = string.byte(p.hintPlain) - 65

		-- Корпус диска.
		UI.Disc(cx, cy, R + S(8), C.panel)
		UI.Ring(cx, cy, R + S(8), A(C.accent, 90), 2, 72)
		UI.Disc(cx, cy, R * 0.77, C.panel2)
		UI.Disc(cx, cy, R * 0.36, C.bg)
		UI.Ring(cx, cy, R * 0.77, A(C.line, 220), 2, 72)
		UI.Ring(cx, cy, R * 0.36, A(C.accent, 120), 2, 48)

		-- Деления.
		for i = 0, 51 do
			local a = math.rad(-90 + i * (360 / 52))
			local r1, r2 = R * 0.995, R * (i % 2 == 0 and 0.94 or 0.97)

			UI.Line(cx + math.cos(a) * r1, cy + math.sin(a) * r1, cx + math.cos(a) * r2, cy + math.sin(a) * r2, A(C.dim, 120), 1)
		end

		-- Внешнее кольцо (открытый алфавит) - неподвижное.
		for i = 0, 25 do
			local a = math.rad(-90 + i * step)
			local x, y = cx + math.cos(a) * R * 0.86, cy + math.sin(a) * R * 0.86

			if (i == hintP) then
				UI.Disc(x, y, S(16), A(C.accent, 60))
				Glow(Letter(i), "ixHackM", x, y, C.accent, 1, 1, 1.2)
			else
				Text(Letter(i), "ixHackM", x, y, C.text, 1, 1)
			end
		end

		-- Внутреннее кольцо (шифр) - вращается.
		for j = 0, 25 do
			local a = math.rad(-90 + (j - self.disp) * step)
			local x, y = cx + math.cos(a) * R * 0.58, cy + math.sin(a) * R * 0.58

			if (j == hintC) then
				UI.Disc(x, y, S(15), A(C.accent, 60))
				Glow(Letter(j), "ixHackM", x, y, C.accent, 1, 1, 1.2)
			elseif (self.inCipher[j]) then
				Text(Letter(j), "ixHackM", x, y, C.warn, 1, 1)
			else
				Text(Letter(j), "ixHackM", x, y, A(C.dim, 200), 1, 1)
			end
		end

		-- Совмещение подсказки: линия между парой букв, когда они стоят друг против друга.
		local ia = math.rad(-90 + hintP * step)
		local jx = (hintC - self.disp) * step

		if (math.abs(((jx - hintP * step + 180) % 360) - 180) < 3) then
			UI.GlowLine(cx + math.cos(ia) * R * 0.5, cy + math.sin(ia) * R * 0.5,
				cx + math.cos(ia) * R * 0.94, cy + math.sin(ia) * R * 0.94, C.good, 2)
		end

		Text("ШИФР", "ixHackS", cx, cy - S(10), C.dim, 1, 1)
		Glow("+" .. self.r, "ixHackL", cx, cy + S(12), C.accent, 1, 1, 0.8)

		-- Кнопки вращения.
		local mx, my = self:CursorPos()

		for _, b in ipairs({self:ButtonRects()}) do
			local hov = Inside(mx, my, b.x, b.y, b.w, b.h)

			Rect(b.x, b.y, b.w, b.h, hov and A(C.accent, 50) or C.panel)
			Frame(b.x, b.y, b.w, b.h, hov and C.accent or C.line, 1)
			Text(b.label, "ixHackM", b.x + b.w / 2, b.y + b.h / 2, C.text, 1, 1)
		end

		-- Правая колонка: перехваченное сообщение, подсказка, ввод.
		local rx = w * 0.58
		local rw = w - rx - S(20)

		UI.Box(rx, S(44), rw, S(112), C.warn, 200)
		Text("ПЕРЕХВАЧЕННОЕ СООБЩЕНИЕ", "ixHackS", rx + S(14), S(54), C.dim)

		local n = #p.cipher
		local bw = math.min(S(50), (rw - S(28) - (n - 1) * S(6)) / n)

		for i = 1, n do
			local x = rx + S(14) + (i - 1) * (bw + S(6))

			Rect(x, S(82), bw, S(56), C.bg)
			Frame(x, S(82), bw, S(56), A(C.warn, 150), 1)
			Glow(string.sub(p.cipher, i, i), "ixHackL", x + bw / 2, S(110), C.warn, 1, 1, 0.8)
		end

		UI.Box(rx, S(170), rw, S(64), C.accent, 200)
		Text("ИЗВЕСТНАЯ ПАРА", "ixHackS", rx + S(14), S(180), C.dim)
		Text("«" .. p.hintCipher .. "»  в открытом тексте  —  «" .. p.hintPlain .. "»", "ixHackM", rx + S(14), S(202), C.accent)

		local wrong = self.wrongUntil > CurTime()
		local ox = wrong and math.sin(SysTime() * 60) * S(4) or 0

		Text("ВАШ ОТВЕТ", "ixHackS", rx, S(260), C.dim)

		for i = 1, n do
			local x = rx + (i - 1) * (bw + S(6)) + ox
			local ch = string.sub(self.typed, i, i)

			Rect(x, S(282), bw, S(56), wrong and A(C.bad, 40) or C.panel)
			Frame(x, S(282), bw, S(56), wrong and C.bad or (ch ~= "" and C.accent or C.line), 1)

			if (ch ~= "") then
				Glow(ch, "ixHackL", x + bw / 2, S(310), wrong and C.bad or C.text, 1, 1, 0.8)
			elseif (i == #self.typed + 1) then
				Rect(x + bw / 2 - S(8), S(330), S(16), 2, A(C.accent, (math.floor(SysTime() * 2) % 2 == 0) and 255 or 60))
			end
		end

		Text("ПОПЫТОК:", "ixHackS", rx, S(358), C.dim)
		UI.Pips(rx + S(86), S(366), p.tries, self.left, S(6), S(6), self.left <= 1 and C.bad or C.accent)

		if (wrong) then
			Text("НЕВЕРНО", "ixHackM", rx + rw, S(358), C.bad, TEXT_ALIGN_RIGHT)
		end

		Text("Вводите буквы с клавиатуры.", "ixHackS", rx, S(396), C.faint)
		Text("Стёрли — BACKSPACE.", "ixHackS", rx, S(416), C.faint)
	end

	vgui.Register("ixHackG_cipher", PANEL, "EditablePanel")
end

-- =====================================================================================
--  3. НАСТРОЙКА СИГНАЛА (осциллограф)
-- =====================================================================================

do
	local PANEL = {}

	local function Sliders(p)
		local list = {
			{key = "f", label = "ЧАСТОТА", min = p.fmin, max = p.fmax, step = 0.02, tol = p.tolF,
				fmt = function(v) return string.format("%.2f Гц", v) end},
			{key = "a", label = "АМПЛИТУДА", min = 0.2, max = 1.0, step = 0.01, tol = p.tolA,
				fmt = function(v) return string.format("%d%%", math.Round(v * 100)) end}
		}

		if (p.useP) then
			list[3] = {key = "p", label = "ФАЗА", min = 0, max = TAU, step = 0.05, tol = p.tolP, circular = true,
				fmt = function(v) return string.format("%d°", math.Round(math.deg(v)) % 360) end}
		end

		return list
	end

	local function Dist(sl, a, b)
		if (sl.circular) then
			local d = math.abs(a - b) % TAU

			return math.min(d, TAU - d)
		end

		return math.abs(a - b)
	end

	function PANEL:Setup(p)
		self.p = p
		self.sliders = Sliders(p)
		self.v = {}
		self.lockT = 0
		self.sent = false

		local target = {f = p.f, a = p.a, p = p.p}

		-- Стартовые значения заведомо далеки от цели.
		for _, sl in ipairs(self.sliders) do
			local t = target[sl.key]

			if (sl.circular) then
				self.v[sl.key] = (t + math.pi * math.Rand(0.5, 1.5)) % TAU
			else
				local range = sl.max - sl.min
				local off = range * math.Rand(0.25, 0.45) * ((math.random() < 0.5) and -1 or 1)
				local v = math.Clamp(t + off, sl.min, sl.max)

				if (Dist(sl, v, t) < sl.tol * 3) then v = math.Clamp(t - off, sl.min, sl.max) end

				self.v[sl.key] = v
			end
		end
	end

	function PANEL:Geo()
		local w, h = self:GetSize()
		local sh = math.floor(h * 0.44)

		return S(16), S(38), w - S(32), sh, S(38) + sh + S(34)
	end

	function PANEL:SliderRect(i)
		local w = self:GetWide()
		local _, _, _, _, y0 = self:Geo()

		return S(180), y0 + (i - 1) * S(50), w - S(180) - S(190), S(22)
	end

	function PANEL:SetFromMouse(i, mx)
		local sl = self.sliders[i]
		local x, _, tw = self:SliderRect(i)
		local k = math.Clamp((mx - x) / tw, 0, 1)

		self.v[sl.key] = sl.min + (sl.max - sl.min) * k
	end

	function PANEL:SliderAt(mx, my)
		for i = 1, #self.sliders do
			local x, y, tw, th = self:SliderRect(i)

			if (Inside(mx, my, x - S(12), y - S(10), tw + S(24), th + S(20))) then return i end
		end
	end

	function PANEL:OnMousePressed(code)
		if (code ~= MOUSE_LEFT or self.sent) then return end

		local mx, my = self:CursorPos()
		local i = self:SliderAt(mx, my)

		if (i) then
			self.drag = i
			self:SetFromMouse(i, mx)
		end
	end

	function PANEL:OnMouseWheeled(delta)
		if (self.sent) then return end

		local i = self:SliderAt(self:CursorPos())

		if (not i) then return end

		local sl = self.sliders[i]
		local v = self.v[sl.key] + delta * sl.step

		if (sl.circular) then
			v = v % TAU
		else
			v = math.Clamp(v, sl.min, sl.max)
		end

		self.v[sl.key] = v
	end

	-- Наибольшее отклонение, выраженное в допусках: <= 1 значит «в допуске».
	function PANEL:Error()
		local p = self.p
		local target = {f = p.f, a = p.a, p = p.p}
		local e = 0

		for _, sl in ipairs(self.sliders) do
			e = math.max(e, Dist(sl, self.v[sl.key], target[sl.key]) / sl.tol)
		end

		return e
	end

	function PANEL:Think()
		if (self.sent or not self.p) then return end

		if (self.drag) then
			if (input.IsMouseDown(MOUSE_LEFT)) then
				self:SetFromMouse(self.drag, (self:CursorPos()))
			else
				self.drag = nil
			end
		end

		local dt = FrameTime()

		if (self:Error() <= 1) then
			self.lockT = self.lockT + dt

			if (self.lockT >= self.p.hold) then
				self.sent = true
				surface.PlaySound("buttons/button14.wav")
				HACK.SendToServer("submit", {f = self.v.f, a = self.v.a, p = self.v.p or 0})
			end
		else
			self.lockT = math.max(0, self.lockT - dt * 2)
		end
	end

	local function WaveY(a, f, ph, k) return a * math.sin(TAU * f * k + ph) end

	function PANEL:Paint(w, h)
		local p = self.p

		if (not p) then return end

		Hint(self, "ПОДГОНИТЕ СВОЙ СИГНАЛ ПОД ЭТАЛОН И УДЕРЖИВАЙТЕ СОВПАДЕНИЕ  ·  ТЯНИТЕ ПОЛЗУНКИ, КОЛЕСО МЫШИ — ТОЧНО", w)

		local sx, sy, sw, sh = self:Geo()
		local locked = self:Error() <= 1

		-- Экран осциллографа.
		Rect(sx, sy, sw, sh, Color(2, 8, 10, 235))
		surface.SetDrawColor(C.accent.r, C.accent.g, C.accent.b, 16)

		for i = 1, 11 do surface.DrawRect(sx + math.floor(sw * i / 12), sy, 1, sh) end
		for i = 1, 7 do surface.DrawRect(sx, sy + math.floor(sh * i / 8), sw, 1) end

		surface.SetDrawColor(C.accent.r, C.accent.g, C.accent.b, 50)
		surface.DrawRect(sx, sy + math.floor(sh / 2), sw, 1)
		surface.DrawRect(sx + math.floor(sw / 2), sy, 1, sh)
		UI.Frame(sx, sy, sw, sh, A(C.line, 230), 1)
		UI.Brackets(sx, sy, sw, sh, C.accent, S(14), 2)

		local amp = sh * 0.42
		local cy = sy + sh / 2
		local N = 140

		-- Эталон (пунктир, янтарный).
		local prevx, prevy
		local tcol = A(C.warn, 200)

		for i = 0, N do
			local k = i / N
			local x, y = sx + sw * k, cy - WaveY(p.a, p.f, p.p, k) * amp

			if (prevx and i % 4 ~= 0) then
				UI.Line(prevx, prevy, x, y, tcol, 1)
			end

			prevx, prevy = x, y
		end

		-- Ваш сигнал (свечение).
		local pcol = locked and C.good or C.accent

		prevx, prevy = nil, nil

		for i = 0, N do
			local k = i / N
			local x, y = sx + sw * k, cy - WaveY(self.v.a, self.v.f, self.v.p or 0, k) * amp

			if (prevx) then
				UI.Line(prevx, prevy - 2, x, y - 2, A(pcol, 36), 1)
				UI.Line(prevx, prevy + 2, x, y + 2, A(pcol, 36), 1)
				UI.Line(prevx, prevy - 1, x, y - 1, A(pcol, 90), 1)
				UI.Line(prevx, prevy + 1, x, y + 1, A(pcol, 90), 1)
				UI.Line(prevx, prevy, x, y, pcol, 1)
			end

			prevx, prevy = x, y
		end

		Text("● ЭТАЛОН", "ixHackS", sx + S(14), sy + S(10), C.warn)
		Text("● ВАШ СИГНАЛ", "ixHackS", sx + S(120), sy + S(10), pcol)

		-- Индикатор захвата в углу экрана.
		local ex, ey = sx + sw - S(46), sy + S(44)

		UI.Ring(ex, ey, S(22), A(C.line, 200), 2)

		if (self.lockT > 0) then
			UI.Arc(ex, ey, S(22), 4, -90, -90 + 360 * math.min(1, self.lockT / p.hold), C.good)
		end

		Text(locked and "ЗАХВАТ" or "ПОИСК", "ixHackXS", ex, ey + S(36), locked and C.good or C.dim, 1, 1)

		-- Ползунки.
		local mx, my = self:CursorPos()

		for i, sl in ipairs(self.sliders) do
			local x, y, tw, th = self:SliderRect(i)
			local v = self.v[sl.key]
			local k = (v - sl.min) / (sl.max - sl.min)
			local kx = x + tw * k
			local hot = self.drag == i or Inside(mx, my, x - S(12), y - S(10), tw + S(24), th + S(20))

			Text(sl.label, "ixHackM", S(30), y + th / 2, hot and C.text or C.dim, 0, 1)
			Rect(x, y + th / 2 - S(3), tw, S(6), C.bg)
			Rect(x, y + th / 2 - S(3), tw * k, S(6), A(C.accent, 140))
			Frame(x, y + th / 2 - S(3), tw, S(6), A(C.line, 220), 1)

			UI.Diamond(kx, y + th / 2, S(14), A(C.accent, hot and 70 or 30))
			UI.Diamond(kx, y + th / 2, S(10), hot and C.accent or C.text)
			UI.Diamond(kx, y + th / 2, S(5), C.bg)

			Text(sl.fmt(v), "ixHackM", x + tw + S(24), y + th / 2, C.text, 0, 1)
		end

		-- Точность.
		local e = self:Error()
		local quality = e <= 1 and 1 or math.Clamp(1 - (e - 1) / 3, 0, 1)
		local by = h - S(30)

		Text("СИНХРОНИЗАЦИЯ", "ixHackS", S(30), by + S(8), C.dim, 0, 1)
		UI.Bar(S(180), by, w - S(180) - S(190), S(16), quality, locked and C.good or (quality > 0.5 and C.warn or C.bad), 20)
		Text(math.floor(quality * 100) .. "%", "ixHackM", w - S(166), by + S(8), locked and C.good or C.text, 0, 1)
	end

	vgui.Register("ixHackG_tune", PANEL, "EditablePanel")
end

-- =====================================================================================
--  4. МАРШРУТ (провести пакет через сеть)
-- =====================================================================================

do
	local PANEL = {}

	function PANEL:Setup(p)
		self.p = p
		self.path = {{p.start[1], p.start[2]}}
		self.visited = {[(p.start[1] - 1) * p.cols + p.start[2]] = true}
		self.isCheck = {}
		self.got = 0
		self.sent = false
		self.msgUntil = 0

		for _, ck in ipairs(p.checks) do
			self.isCheck[(ck[1] - 1) * p.cols + ck[2]] = true
		end

		self.reset = HACK.MakeButton(self, "СБРОС", function() self:Reset() end)
	end

	function PANEL:PerformLayout(w, h)
		if (IsValid(self.reset)) then
			self.reset:SetSize(S(120), S(30))
			self.reset:SetPos(w - S(136), h - S(40))
		end
	end

	function PANEL:Key(r, c) return (r - 1) * self.p.cols + c end

	function PANEL:Reset()
		local p = self.p

		self.path = {{p.start[1], p.start[2]}}
		self.visited = {[self:Key(p.start[1], p.start[2])] = true}
		self.got = 0
	end

	function PANEL:Geo()
		local w, h = self:GetSize()
		local p = self.p
		local cell = math.min(math.floor((w - S(40)) / p.cols), math.floor((h - S(110)) / p.rows), S(86))

		return math.floor((w - cell * p.cols) / 2), S(44), cell
	end

	function PANEL:Center(r, c)
		local gx, gy, cell = self:Geo()

		return gx + (c - 0.5) * cell, gy + (r - 0.5) * cell
	end

	function PANEL:CellAt(mx, my)
		local gx, gy, cell = self:Geo()

		if (mx < gx or my < gy) then return end

		local c, r = math.floor((mx - gx) / cell) + 1, math.floor((my - gy) / cell) + 1

		if (c < 1 or c > self.p.cols or r < 1 or r > self.p.rows) then return end

		return r, c
	end

	function PANEL:Pop()
		local last = table.remove(self.path)

		self.visited[self:Key(last[1], last[2])] = nil

		if (self.isCheck[self:Key(last[1], last[2])]) then self.got = self.got - 1 end
	end

	-- Попытка шага/отката в клетку; click - прямой клик (разрешает откат на любую клетку пути).
	function PANEL:Step(r, c, click)
		local p = self.p
		local head = self.path[#self.path]

		if (r == head[1] and c == head[2]) then return end

		local key = self:Key(r, c)

		if (self.visited[key]) then
			local prev = self.path[#self.path - 1]

			if (prev and prev[1] == r and prev[2] == c) then
				self:Pop()
				surface.PlaySound("buttons/button15.wav")
			elseif (click) then
				while (#self.path > 1 and not (self.path[#self.path][1] == r and self.path[#self.path][2] == c)) do
					self:Pop()
				end

				surface.PlaySound("buttons/button15.wav")
			end

			return
		end

		if (p.walls[r][c] == 1) then
			if (click) then surface.PlaySound("buttons/button10.wav") end

			return
		end

		-- Через цель дальше не идём.
		if (head[1] == p.goal[1] and head[2] == p.goal[2]) then return end

		if (math.abs(r - head[1]) + math.abs(c - head[2]) ~= 1) then return end

		self.path[#self.path + 1] = {r, c}
		self.visited[key] = true
		surface.PlaySound("buttons/button17.wav")

		if (self.isCheck[key]) then
			self.got = self.got + 1
			surface.PlaySound("buttons/button14.wav")
		end

		if (r == p.goal[1] and c == p.goal[2]) then
			if (self.got >= #p.checks) then
				self.sent = true
				HACK.SendToServer("submit", {path = self.path})
			else
				self.msg = "НЕ ВСЕ КЛЮЧЕВЫЕ УЗЛЫ ПРОЙДЕНЫ"
				self.msgUntil = CurTime() + 2
				surface.PlaySound("buttons/button10.wav")
			end
		end
	end

	function PANEL:OnMousePressed(code)
		if (self.sent) then return end

		if (code == MOUSE_RIGHT) then
			if (#self.path > 1) then
				self:Pop()
				surface.PlaySound("buttons/button15.wav")
			end

			return
		end

		if (code ~= MOUSE_LEFT) then return end

		self.dragging = true

		local r, c = self:CellAt(self:CursorPos())

		if (r) then self:Step(r, c, true) end
	end

	function PANEL:Think()
		if (not self.dragging or self.sent) then return end

		if (not input.IsMouseDown(MOUSE_LEFT)) then
			self.dragging = false

			return
		end

		local r, c = self:CellAt(self:CursorPos())

		if (r) then self:Step(r, c, false) end
	end

	function PANEL:OnKey(key)
		if (key == KEY_BACKSPACE and not self.sent and #self.path > 1) then
			self:Pop()
			surface.PlaySound("buttons/button15.wav")
		end
	end

	function PANEL:Paint(w, h)
		local p = self.p

		if (not p) then return end

		Hint(self, "ПРОВЕДИТЕ ПАКЕТ ОТ ВХОДА К ЦЕЛИ  ·  ОБХОДИТЕ ЗАЩИТУ, ЗАХОДИТЕ В КЛЮЧЕВЫЕ УЗЛЫ  ·  ПКМ / BACKSPACE — ШАГ НАЗАД", w)

		local _, _, cell = self:Geo()
		local head = self.path[#self.path]
		local atGoal = head[1] == p.goal[1] and head[2] == p.goal[2]
		local t = SysTime()

		-- Дорожки между узлами.
		for r = 1, p.rows do
			for c = 1, p.cols do
				if (p.walls[r][c] == 0) then
					local x, y = self:Center(r, c)

					if (c < p.cols and p.walls[r][c + 1] == 0) then
						UI.Line(x, y, x + cell, y, A(C.line, 110), 1)
					end

					if (r < p.rows and p.walls[r + 1][c] == 0) then
						UI.Line(x, y, x, y + cell, A(C.line, 110), 1)
					end
				end
			end
		end

		-- Пройденный путь.
		for i = 2, #self.path do
			local a, b = self.path[i - 1], self.path[i]
			local x1, y1 = self:Center(a[1], a[2])
			local x2, y2 = self:Center(b[1], b[2])

			UI.GlowLine(x1, y1, x2, y2, C.accent, 3)

			local k = (t * 1.6 + i * 0.37) % 1

			UI.Disc(x1 + (x2 - x1) * k, y1 + (y2 - y1) * k, S(3), C.text, 8)
		end

		-- Клетки.
		local mx, my = self:CursorPos()
		local hr, hc = self:CellAt(mx, my)

		for r = 1, p.rows do
			for c = 1, p.cols do
				local x, y = self:Center(r, c)
				local key = self:Key(r, c)
				local rad = cell * 0.4

				if (p.walls[r][c] == 1) then
					-- Узел защиты («лёд»).
					local pulse = 0.6 + 0.4 * math.sin(t * 3 + r * 1.7 + c)

					UI.Rect(x - rad * 0.8, y - rad * 0.8, rad * 1.6, rad * 1.6, A(C.bad, 30 + 22 * pulse))
					UI.Frame(x - rad * 0.8, y - rad * 0.8, rad * 1.6, rad * 1.6, A(C.bad, 150), 1)
					UI.Line(x - rad * 0.5, y - rad * 0.5, x + rad * 0.5, y + rad * 0.5, A(C.bad, 200), 1)
					UI.Line(x - rad * 0.5, y + rad * 0.5, x + rad * 0.5, y - rad * 0.5, A(C.bad, 200), 1)
				elseif (r == p.start[1] and c == p.start[2]) then
					UI.Disc(x, y, rad * 0.62, A(C.good, 50))
					UI.Ring(x, y, rad * 0.62, C.good, 2)
					Text("ВХОД", "ixHackXS", x, y, C.good, 1, 1)
				elseif (r == p.goal[1] and c == p.goal[2]) then
					local ring = rad * (0.7 + 0.12 * math.sin(t * 3))

					UI.Ring(x, y, ring, A(C.cyan, 200), 2)
					UI.Ring(x, y, rad * 0.46, C.cyan, 2)
					Text("ЦЕЛЬ", "ixHackXS", x, y, C.cyan, 1, 1)
				elseif (self.isCheck[key]) then
					local done = self.visited[key]

					UI.Diamond(x, y, rad * 0.78, A(C.warn, done and 90 or 30))
					UI.Diamond(x, y, rad * 0.56, done and C.warn or A(C.warn, 140))
					UI.Diamond(x, y, rad * 0.3, done and C.bg or A(C.bg, 230))
				else
					local on = self.visited[key]

					UI.Disc(x, y, cell * (on and 0.1 or 0.07), on and C.accent or A(C.dim, 200), 12)
				end

				-- Подсветка возможных шагов.
				if (not self.sent and p.walls[r][c] == 0 and not self.visited[key] and not atGoal
				and math.abs(r - head[1]) + math.abs(c - head[2]) == 1) then
					UI.Ring(x, y, cell * (0.2 + 0.04 * math.sin(t * 5)), A(C.accent, 120), 1, 24)
				end

				if (hr == r and hc == c and p.walls[r][c] == 0) then
					UI.Ring(x, y, cell * 0.3, A(C.text, 110), 1, 24)
				end
			end
		end

		-- Голова пути.
		local hx, hy = self:Center(head[1], head[2])

		UI.Ring(hx, hy, cell * (0.24 + 0.05 * math.sin(t * 6)), C.accent, 2, 32)
		UI.Disc(hx, hy, cell * 0.12, C.text, 16)

		-- Нижняя строка.
		local line = string.format("ШАГОВ: %d", #self.path - 1)

		if (#p.checks > 0) then
			line = line .. string.format("   ·   КЛЮЧЕВЫЕ УЗЛЫ: %d/%d", self.got, #p.checks)
		end

		Text(line, "ixHackM", S(24), h - S(26), C.text, 0, 1)

		if (self.msgUntil > CurTime()) then
			Text(self.msg, "ixHackM", w / 2, h - S(26), C.warn, 1, 1)
		end
	end

	vgui.Register("ixHackG_route", PANEL, "EditablePanel")
end

-- =====================================================================================
--  5. ВЗЛОМ ЗАМКА (стрелка по кругу)
-- =====================================================================================

do
	local PANEL = {}

	local function NeedleAngle(rd, t)
		return (rd.phase + rd.dir * rd.speed * t) % 360
	end

	function PANEL:Setup(p)
		self.p = p
		self.round = 1
		self.t0 = CurTime()
		self.hits = {}
		self.misses = 0
		self.sent = false
		self.pauseUntil = 0
		self.frozen = nil
		self.flashUntil = 0
		self.flashCol = C.good
	end

	function PANEL:Press()
		if (self.sent or self.pauseUntil > CurTime()) then return end

		local p = self.p
		local rd = p.rounds[self.round]
		local t = CurTime() - self.t0
		local ang = NeedleAngle(rd, t)
		local diff = math.abs(((ang - rd.center + 540) % 360) - 180)

		if (diff <= rd.width / 2) then
			self.hits[#self.hits + 1] = t
			self.frozen = ang
			self.flashUntil = CurTime() + 0.5
			self.flashCol = C.good
			surface.PlaySound("buttons/button14.wav")

			if (self.round >= #p.rounds) then
				self.sent = true
				HACK.SendToServer("submit", {hits = self.hits})
			else
				self.pauseUntil = CurTime() + 0.55
			end
		else
			self.misses = self.misses + 1
			self.flashUntil = CurTime() + 0.35
			self.flashCol = C.bad
			surface.PlaySound("buttons/button10.wav")

			if (self.misses >= p.misses) then
				self.sent = true
				HACK.SendToServer("submit", {fail = true})
			end
		end
	end

	function PANEL:Think()
		if (self.pauseUntil > 0 and CurTime() >= self.pauseUntil and not self.sent) then
			self.pauseUntil = 0
			self.frozen = nil
			self.round = self.round + 1
			self.t0 = CurTime()
		end
	end

	function PANEL:OnMousePressed(code)
		if (code == MOUSE_LEFT) then self:Press() end
	end

	function PANEL:OnKey(key)
		if (key == KEY_SPACE) then self:Press() end
	end

	-- Точка на окружности; 0° - вверх, дальше по часовой стрелке.
	local function Pt(cx, cy, r, deg)
		local a = math.rad(deg - 90)

		return cx + math.cos(a) * r, cy + math.sin(a) * r
	end

	function PANEL:Paint(w, h)
		local p = self.p

		if (not p) then return end

		Hint(self, "НАЖМИТЕ ПРОБЕЛ ИЛИ ЛКМ, КОГДА СТРЕЛКА ВНУТРИ СВЕТЯЩЕГОСЯ СЕКТОРА  ·  КАЖДЫЙ ШТИФТ УСКОРЯЕТ СТРЕЛКУ", w)

		local cx, cy = w / 2, h / 2 + S(8)
		local R = math.min(h * 0.4, S(200))
		local rd = p.rounds[math.min(self.round, #p.rounds)]
		local now = CurTime()
		local paused = self.pauseUntil > now or self.sent
		local ang = self.frozen or NeedleAngle(rd, now - self.t0)
		local flash = self.flashUntil > now

		-- Корпус замка.
		UI.Disc(cx, cy, R + S(18), C.panel)
		UI.Ring(cx, cy, R + S(18), A(C.accent, 70), 2, 90)
		UI.Ring(cx, cy, R + S(8), A(C.line, 200), 1, 90)
		UI.Disc(cx, cy, R, C.bg)

		if (flash) then
			UI.Disc(cx, cy, R, A(self.flashCol, 40 * (self.flashUntil - now) / 0.4))
		end

		-- Деления.
		for i = 0, 71 do
			local major = i % 6 == 0
			local x1, y1 = Pt(cx, cy, R, i * 5)
			local x2, y2 = Pt(cx, cy, R - (major and S(16) or S(8)), i * 5)

			UI.Line(x1, y1, x2, y2, A(C.dim, major and 220 or 110), 1)
		end

		-- Целевой сектор (UI.Arc считает от «3 часов», поэтому -90°).
		local from, to = rd.center - rd.width / 2 - 90, rd.center + rd.width / 2 - 90

		UI.Arc(cx, cy, R - S(30), S(30), from, to, A(C.good, 40), 3)
		UI.Arc(cx, cy, R - S(30), S(8), from, to, C.good, 3)
		UI.Arc(cx, cy, R - S(6), S(4), from, to, A(C.good, 180), 3)

		-- Шлейф и стрелка.
		for k = 1, 10 do
			local x, y = Pt(cx, cy, R - S(12), ang - rd.dir * k * (paused and 0 or 3))

			UI.Line(cx, cy, x, y, A(C.accent, 24 - k * 2), 3)
		end

		local nx, ny = Pt(cx, cy, R - S(4), ang)

		UI.GlowLine(cx, cy, nx, ny, flash and self.flashCol or C.accent, 2)
		UI.Disc(nx, ny, S(5), flash and self.flashCol or C.text, 12)

		-- Ось.
		UI.Disc(cx, cy, S(34), C.panel2)
		UI.Ring(cx, cy, S(34), A(C.accent, 160), 2, 36)
		Glow(self.round .. "/" .. #p.rounds, "ixHackM", cx, cy, C.text, 1, 1, 0.8)

		-- Штифты и попытки.
		Text("ШТИФТЫ", "ixHackS", S(40), h - S(66), C.dim)
		UI.Pips(S(40), h - S(40), #p.rounds, #self.hits, S(9), S(8), C.good, self.round)

		local left = p.misses - self.misses

		Text("ПОПЫТКИ", "ixHackS", w - S(40), h - S(66), C.dim, TEXT_ALIGN_RIGHT)
		UI.Pips(w - S(40) - p.misses * S(26) + S(8), h - S(40), p.misses, left, S(8), S(8), left <= 1 and C.bad or C.accent)

		Text("СКОРОСТЬ " .. rd.speed .. "°/с", "ixHackS", cx, h - S(30), C.dim, 1, 1)
	end

	vgui.Register("ixHackG_lock", PANEL, "EditablePanel")
end
