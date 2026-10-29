--[[
	Интерфейс поставщика — оформление в стилистике cl_character
	(сине-стальной HUD, скобки, шевроны, развёртка, звуки интерфейса).

	Сетевая логика (ixVendorTrade / ixVendorClose) и API панелей (ixVendor, ixVendorItem)
	не менялись: Setup, addItem, removeItem, activeSell / activeBuy, OnItemSelected,
	SetReadOnly, SetCallback и т.д. работают как раньше.

	Все цвета, звуки, тайминги и надписи вынесены в начало файла.
]]

local glowMat = Material("sprites/light_glow02_add")

-- ============================================================
-- Настройки
-- ============================================================

local CFG = {
	accentColor = Color(90, 160, 235), -- основной цвет (как в cl_character); удалите строку, чтобы брать цвет из конфига Helix
	fallbackColor = Color(90, 160, 235),

	good = Color(120, 214, 150),       -- рост средств / продажа
	bad = Color(236, 102, 96),         -- нехватка средств / нет в наличии

	openTime = 0.6,                    -- длительность появления окна
	closeTime = 0.22,                  -- длительность закрытия окна
	rowStagger = 0.04,                 -- задержка между появлением соседних строк списка
	scanlines = true,                  -- лёгкая ЭЛТ-развёртка поверх окна
	grid = true,                       -- тактическая сетка на фоне

	sounds = true,
	soundVolume = 0.55,
	soundSet = {
		hover = {"buttons/blip1.wav", 0.30, 115},
		click = {"buttons/button15.wav", 0.50, 100},
		deny = {"buttons/button10.wav", 0.50, 100},
		open = {"buttons/combine_button1.wav", 0.40, 105},
		back = {"buttons/combine_button2.wav", 0.40, 95},
		tick = {"buttons/blip2.wav", 0.18, 130},
		confirm = {"buttons/combine_button7.wav", 0.40, 100}
	}
}

-- Надписи. «purchase», «sell», «you» берутся из системы локализации Helix.
local STR = {
	subtitle = "ИНТЕНДАНТСКИЙ ПУНКТ",
	vendor = "ПОСТАВЩИК",
	client = "КЛИЕНТ",
	funds = "ФОНДЫ",
	unlimited = "БЕЗ ЛИМИТА",
	readOnly = "ТОЛЬКО ПРОСМОТР",
	sellingCol = "НА СКЛАДЕ",
	buyingCol = "ВАШ ИНВЕНТАРЬ",
	emptySell = "СКЛАД ПУСТ",
	emptyBuy = "НЕТ ПОДХОДЯЩИХ ПРЕДМЕТОВ",
	stock = "Остаток",
	noLimit = "без лимита",
	owned = "В инвентаре",
	soldOut = "НЕТ В НАЛИЧИИ",
	full = "СКЛАД ПОЛОН",
	priceSell = "ЦЕНА",
	priceBuy = "ВЫКУП",

	pickItem = "ВЫБЕРИТЕ ПРЕДМЕТ",
	pickHint = "Нажмите на позицию в списке",
	noDesc = "Описание отсутствует.",
	barStock = "ОСТАТОК НА СКЛАДЕ",
	barCapacity = "ЗАПОЛНЕННОСТЬ СКЛАДА",
	barUnlimited = "БЕЗ ОГРАНИЧЕНИЯ ПО ЗАПАСУ",

	reasonPick = "ВЫБЕРИТЕ ПРЕДМЕТ",
	reasonReadOnly = "ТОЛЬКО ПРОСМОТР",
	reasonNoFunds = "НЕДОСТАТОЧНО СРЕДСТВ",
	reasonVendorNoFunds = "У ПОСТАВЩИКА НЕТ СРЕДСТВ",

	footerLeft = "КАНАЛ ТОРГОВЛИ: ЗАЩИЩЁН  //  ОПЕРАЦИИ ФИКСИРУЮТСЯ"
}

-- ============================================================
-- Размеры
-- ============================================================

local PAD = 14
local TOP_H = 58
local BOT_H = 24
local GAP = 30
local HEAD_H = 58
local BAR_H = 28
local CARD_H = 200
local ROW_H = 60

-- ============================================================
-- Шрифты
-- ============================================================

local function CreateFonts()
	local h = ScrH()

	local function make(name, font, factor, weight)
		surface.CreateFont(name, {
			font = font,
			size = math.max(11, math.floor(h * factor)),
			weight = weight,
			extended = true,
			antialias = true
		})
	end

	make("ixVendorTitle", "Roboto", 0.026, 700)
	make("ixVendorName", "Roboto", 0.0185, 600)
	make("ixVendorText", "Roboto", 0.0155, 500)
	make("ixVendorSmall", "Roboto", 0.0125, 500)
	make("ixVendorTiny", "Roboto", 0.011, 500)
	make("ixVendorButton", "Roboto", 0.0175, 700)
	make("ixVendorMono", "Courier New", 0.0125, 500)
end

CreateFonts()
hook.Add("LoadFonts", "ixVendorFonts", CreateFonts)
hook.Add("OnScreenSizeChanged", "ixVendorFonts", CreateFonts)

-- ============================================================
-- Вспомогательные функции
-- ============================================================

local function GetAccent()
	return CFG.accentColor or ix.config.Get("color") or CFG.fallbackColor
end

local function AccentRGB()
	local c = GetAccent()

	return c.r, c.g, c.b
end

local function Upper(text)
	return (string.utf8upper or string.upper)(text or "")
end

local function Clamp01(x)
	return math.Clamp(x, 0, 1)
end

local function EaseOutCubic(x)
	return 1 - (1 - x) ^ 3
end

local function EaseInOutSine(x)
	return -(math.cos(math.pi * x) - 1) / 2
end

-- прогресс 0..1 отрезка [start, start + duration] на временной шкале t
local function Step(t, start, duration)
	return Clamp01((t - start) / duration)
end

-- плавное приближение значения к цели (не зависит от частоты кадров)
local function Approach(current, target, speed)
	return Lerp(math.min(RealFrameTime() * speed, 1), current, target)
end

-- эффект «печатной машинки» с учётом UTF-8
local function TypeText(text, p)
	local len = utf8.len(text) or #text
	local n = math.floor(len * Clamp01(p))

	if (n >= len) then
		return text
	end

	return text:sub(1, (utf8.offset(text, n + 1) or (#text + 1)) - 1)
end

-- текст с выравниванием и числовым цветом (без создания таблиц Color); возвращает ширину и высоту
local function Txt(text, font, x, y, r, g, b, a, ax, ay)
	if (a <= 0 or text == "") then
		return 0, 0
	end

	surface.SetFont(font)

	local tw, th = surface.GetTextSize(text)

	if (ax == TEXT_ALIGN_CENTER) then
		x = x - tw * 0.5
	elseif (ax == TEXT_ALIGN_RIGHT) then
		x = x - tw
	end

	if (ay == TEXT_ALIGN_CENTER) then
		y = y - th * 0.5
	elseif (ay == TEXT_ALIGN_BOTTOM) then
		y = y - th
	end

	surface.SetTextColor(r, g, b, a)
	surface.SetTextPos(math.floor(x), math.floor(y))
	surface.DrawText(text)

	return tw, th
end

local function ClipText(text, font, maxW)
	surface.SetFont(font)

	if (surface.GetTextSize(text) <= maxW) then
		return text
	end

	local len = utf8.len(text) or #text

	while (len > 1) do
		len = len - 1

		local part = text:sub(1, (utf8.offset(text, len + 1) or (#text + 1)) - 1) .. "…"

		if (surface.GetTextSize(part) <= maxW) then
			return part
		end
	end

	return "…"
end

-- перенос по словам; maxLines ограничивает число строк (последняя получает «…»)
local function WrapText(text, font, maxW, maxLines)
	surface.SetFont(font)

	text = string.gsub(text or "", "%s+", " ")

	local lines, line, cut = {}, "", false

	for word in string.gmatch(text, "%S+") do
		local test = (line == "") and word or (line .. " " .. word)

		if (surface.GetTextSize(test) > maxW and line ~= "") then
			lines[#lines + 1] = line
			line = word

			if (#lines >= maxLines) then
				cut = true
				break
			end
		else
			line = test
		end
	end

	if (not cut and line ~= "") then
		lines[#lines + 1] = line
	end

	if (cut) then
		lines[#lines] = ClipText(lines[#lines] .. "…", font, maxW)
	end

	return lines
end

-- ---------- сглаженные линии (как в cl_character) ----------

local FEATHER = {{0, 0.6, 0.45}, {0.6, 1.3, 0.14}}
local quad = {{x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}}

local function SetQuad(x1, y1, x2, y2, x3, y3, x4, y4)
	local q = quad

	q[1].x, q[1].y = x1, y1
	q[2].x, q[2].y = x2, y2
	q[3].x, q[3].y = x3, y3
	q[4].x, q[4].y = x4, y4

	surface.DrawPoly(q)
end

local function LineBand(x1, y1, x2, y2, nx, ny, o1, o2)
	SetQuad(x1 + nx * o1, y1 + ny * o1, x2 + nx * o1, y2 + ny * o1, x2 + nx * o2, y2 + ny * o2, x1 + nx * o2, y1 + ny * o2)
end

local function SmoothLine(x1, y1, x2, y2, thick, r, g, b, a)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)

	if (len < 0.001 or a <= 0) then
		return
	end

	local nx, ny = -dy / len, dx / len
	local half = thick * 0.5

	draw.NoTexture()
	surface.SetDrawColor(r, g, b, a)
	LineBand(x1, y1, x2, y2, nx, ny, -half, half)

	for _, f in ipairs(FEATHER) do
		surface.SetDrawColor(r, g, b, a * f[3])
		LineBand(x1, y1, x2, y2, nx, ny, half + f[1], half + f[2])
		LineBand(x1, y1, x2, y2, nx, ny, -half - f[2], -half - f[1])
	end
end

-- шеврон, направленный вправо (dir = 1) или влево (dir = -1)
local function DrawChevron(cx, cy, s, dir, thick, r, g, b, a)
	SmoothLine(cx - s * 0.5 * dir, cy - s, cx + s * 0.5 * dir, cy, thick, r, g, b, a)
	SmoothLine(cx + s * 0.5 * dir, cy, cx - s * 0.5 * dir, cy + s, thick, r, g, b, a)
end

local function DrawBrackets(x, y, w, h, len, r, g, b, a)
	if (len < 1 or a <= 0) then
		return
	end

	len = math.floor(len)

	surface.SetDrawColor(r, g, b, a)

	surface.DrawRect(x, y, len, 2)
	surface.DrawRect(x, y, 2, len)
	surface.DrawRect(x + w - len, y, len, 2)
	surface.DrawRect(x + w - 2, y, 2, len)
	surface.DrawRect(x, y + h - 2, len, 2)
	surface.DrawRect(x, y + h - len, 2, len)
	surface.DrawRect(x + w - len, y + h - 2, len, 2)
	surface.DrawRect(x + w - 2, y + h - len, 2, len)
end

-- ---------- звук ----------

local lastPlayed = {}

local function PlayUI(key, pitchMul, volMul)
	if (not CFG.sounds) then
		return
	end

	local def = CFG.soundSet and CFG.soundSet[key]

	if (not def) then
		return
	end

	local now = RealTime()

	-- защита от «залпа» одинаковых звуков
	if (lastPlayed[key] and now - lastPlayed[key] < 0.05) then
		return
	end

	lastPlayed[key] = now

	local vol = math.Clamp(def[2] * (volMul or 1) * (CFG.soundVolume or 1), 0, 1)
	local pitch = math.Clamp(def[3] * (pitchMul or 1), 40, 255)
	local ply = LocalPlayer()

	if (IsValid(ply)) then
		ply:EmitSound(def[1], 75, pitch, vol, CHAN_AUTO)
	else
		surface.PlaySound(def[1])
	end
end

local function CountValid(list)
	local count = 0

	for _, panel in pairs(list) do
		if (IsValid(panel)) then
			count = count + 1
		end
	end

	return count
end

local function GetCharacter()
	local ply = LocalPlayer()

	return IsValid(ply) and ply.GetCharacter and ply:GetCharacter() or nil
end

-- ============================================================
-- Кнопка действия (купить / продать)
-- ============================================================

local function StyleActionButton(button, frame, selectionKey, tint)
	button.hoverFrac = 0
	button.pressFrac = 0
	button.readyFrac = 0

	button.OnCursorEntered = function(this)
		this.shineStart = RealTime()

		if (this:IsEnabled() and IsValid(frame[selectionKey])) then
			PlayUI("hover", math.Rand(0.96, 1.06))
		end
	end

	button.OnMousePressed = function(this, code)
		if (code == MOUSE_LEFT) then
			if (this:IsEnabled() and IsValid(frame[selectionKey])) then
				PlayUI("click")
				this.pressFrac = 1
			else
				PlayUI("deny")
			end
		end

		DButton.OnMousePressed(this, code)
	end

	button.Paint = function(this, w, h)
		local sel = frame[selectionKey]
		local valid = IsValid(sel)
		local enabled = this:IsEnabled()
		local blocked = valid and (sel.noFunds or sel.soldOut or sel.full)
		local ready = enabled and valid and not blocked
		local now = RealTime()

		-- цвет кнопки: готова / заблокирована
		local cr, cg, cb = tint.r, tint.g, tint.b

		if (valid and blocked and enabled) then
			cr, cg, cb = CFG.bad.r, CFG.bad.g, CFG.bad.b
		elseif (not ready) then
			cr, cg, cb = 120, 134, 150
		end

		this.hoverFrac = Approach(this.hoverFrac, (ready and this:IsHovered()) and 1 or 0, 14)
		this.pressFrac = Approach(this.pressFrac, 0, 7)
		this.readyFrac = Approach(this.readyFrac, ready and 1 or 0, 8)

		local f = this.hoverFrac
		local ef = EaseOutCubic(f)
		local pf = this.pressFrac
		local k = 0.45 + 0.55 * this.readyFrac

		draw.NoTexture()

		surface.SetDrawColor(cr, cg, cb, (16 + 34 * f) * k)
		surface.DrawRect(0, 0, w, h)

		-- заливка, выезжающая слева при наведении
		if (ef > 0.01) then
			surface.SetDrawColor(cr, cg, cb, 44 * ef)
			surface.DrawRect(0, 0, math.floor(w * ef), h)
		end

		-- блик
		if (f > 0.05 and ready) then
			local st = (now - (this.shineStart or now)) * 1.7

			if (st < 1) then
				local sx = math.floor(-40 + (w + 80) * EaseOutCubic(st))

				for i = 0, 7 do
					local x = sx + i * 5

					if (x >= 0 and x < w) then
						surface.SetDrawColor(255, 255, 255, 38 * math.sin((i + 0.5) / 8 * math.pi) * f)
						surface.DrawRect(x, 0, 5, h)
					end
				end
			end
		end

		-- рамка с «дыханием»
		local breathe = ready and (0.5 + 0.5 * math.sin(now * 1.6)) or 0

		surface.SetDrawColor(cr, cg, cb, (104 + 10 * breathe + 108 * f) * k)
		surface.DrawOutlinedRect(0, 0, w, h, 1)

		-- маркер слева
		surface.SetDrawColor(255, 255, 255, (70 + 185 * f) * k)
		surface.DrawRect(0, 0, 4 + math.floor(3 * ef), h)

		-- скобки справа при наведении
		if (ef > 0.02) then
			local bl = math.floor(10 * ef)

			surface.SetDrawColor(255, 255, 255, 200 * ef)
			surface.DrawRect(w - bl - 1, 0, bl, 2)
			surface.DrawRect(w - 2, 0, 2, bl)
			surface.DrawRect(w - bl - 1, h - 2, bl, 2)
			surface.DrawRect(w - 2, h - bl, 2, bl)
		end

		-- вспышка при нажатии
		if (pf > 0.01) then
			surface.SetDrawColor(255, 255, 255, 70 * pf)
			surface.DrawRect(0, 0, w, h)
		end

		-- подпись
		local textY = h * 0.5 + pf
		local caption = Upper(this.caption or "")
		local capX = 22 + math.floor(4 * ef)
		local capW = Txt(caption, "ixVendorButton", capX, textY, 255, 255, 255, (150 + 105 * f) * k, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		-- шевроны рядом с подписью
		if (ef > 0.02) then
			DrawChevron(capX + capW + 14 - 6 * (1 - ef), textY, 5, 1, 1.5, 255, 255, 255, 230 * ef)
		end

		-- справа: цена или причина недоступности
		if (ready) then
			Txt(ix.currency.Get(sel.price or 0), "ixVendorButton", w - 16, textY, 255, 255, 255, 235, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		else
			local reason

			if (not enabled) then
				reason = STR.reasonReadOnly
			elseif (not valid) then
				reason = STR.reasonPick
			elseif (sel.soldOut) then
				reason = STR.soldOut
			elseif (sel.full) then
				reason = STR.full
			else
				reason = sel.isLocal and STR.reasonVendorNoFunds or STR.reasonNoFunds
			end

			Txt(reason, "ixVendorSmall", w - 16, textY, cr, cg, cb, 220, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		return true
	end
end

-- ============================================================
-- Карточка выбранного предмета
-- ============================================================

local function BuildCard(frame, col, role, selectionKey, tint)
	local card = col:Add("DPanel")
	card:SetTall(CARD_H)
	card:Dock(BOTTOM)

	card.selFade = 0
	card.barShown = 0
	card.changeAt = 0
	card.snapshot = nil
	card.lines = {}

	card.icon = card:Add("SpawnIcon")
	card.icon:SetSize(76, 76)
	card.icon:SetPos(16, 16)
	card.icon:SetModel("models/error.mdl")
	card.icon:SetMouseInputEnabled(false)
	card.icon:SetAlpha(0)

	card.button = card:Add("DButton")
	card.button:SetText("")
	card.button:SetSize(100, 44)
	StyleActionButton(card.button, frame, selectionKey, tint)

	card.PerformLayout = function(this, w, h)
		this.button:SetPos(12, h - 12 - 44)
		this.button:SetSize(w - 24, 44)
	end

	card.Think = function(this)
		local sel = frame[selectionKey]

		if (not IsValid(sel)) then
			sel = nil
		end

		if (sel ~= this.current) then
			this.current = sel
			this.changeAt = RealTime()

			if (sel) then
				this.snapshot = {
					name = sel.itemName or "",
					desc = sel.itemDesc or "",
					model = sel.itemModel,
					skin = sel.itemSkin
				}

				if (sel.itemModel) then
					this.icon:SetModel(sel.itemModel, sel.itemSkin or 0)
				end

				local descW = this:GetWide() - 108 - 16
				this.lines = WrapText(
					(this.snapshot.desc ~= "" and this.snapshot.desc or STR.noDesc),
					"ixVendorSmall", descW, 3
				)

				PlayUI("tick", math.Rand(0.95, 1.1))
			end
		end

		this.selFade = Approach(this.selFade, sel and 1 or 0, 10)
		this.icon:SetAlpha(255 * this.selFade)
	end

	card.Paint = function(this, w, h)
		local ar, ag, ab = AccentRGB()
		local now = RealTime()
		local sel = this.current
		local snap = this.snapshot
		local fade = this.selFade
		local cf = EaseOutCubic(Clamp01((now - this.changeAt) / 0.35))
		local ox = (1 - cf) * 14

		draw.NoTexture()

		surface.SetDrawColor(8, 13, 21, 235)
		surface.DrawRect(0, 0, w, h)

		surface.SetDrawColor(ar, ag, ab, 90)
		surface.DrawRect(0, 0, w, 1)

		-- рамка иконки
		local ix0, iy0, isz = 12, 12, 84

		surface.SetDrawColor(5, 8, 13, 255)
		surface.DrawRect(ix0, iy0, isz, isz)

		if (fade > 0.02 and snap) then
			surface.SetDrawColor(ar, ag, ab, 22 * fade)
			surface.DrawRect(ix0, iy0, isz, isz)

			surface.SetDrawColor(ar, ag, ab, 120 * fade)
			surface.DrawOutlinedRect(ix0, iy0, isz, isz, 1)

			DrawBrackets(ix0 - 2, iy0 - 2, isz + 4, isz + 4, 10 + 4 * (1 - cf), ar, ag, ab, 230 * fade)
		end

		-- пустое состояние
		if (fade < 0.98) then
			local e = 1 - fade
			local dash = (now * 14) % 8

			surface.SetDrawColor(ar, ag, ab, 90 * e)

			for d = 0, isz, 8 do
				local p = d + dash

				if (p + 4 <= isz) then
					surface.DrawRect(ix0 + p, iy0, 4, 1)
					surface.DrawRect(ix0 + isz - p - 4, iy0 + isz - 1, 4, 1)
					surface.DrawRect(ix0, iy0 + isz - p - 4, 1, 4)
					surface.DrawRect(ix0 + isz - 1, iy0 + p, 1, 4)
				end
			end

			Txt("?", "ixVendorTitle", ix0 + isz * 0.5, iy0 + isz * 0.5, ar, ag, ab, 70 * e, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			local pulse = 0.5 + 0.5 * math.sin(now * 2)

			Txt(STR.pickItem, "ixVendorName", 112, 20, 255, 255, 255, (150 + 70 * pulse) * e, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			Txt(STR.pickHint, "ixVendorSmall", 112, 46, ar, ag, ab, 150 * e, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		if (fade <= 0.02 or not snap) then
			return
		end

		-- цена справа
		local priceText = ix.currency.Get((sel and sel.price) or 0)
		local blocked = sel and (sel.noFunds or sel.soldOut or sel.full)
		local pr, pg, pb = 255, 255, 255

		if (blocked) then
			pr, pg, pb = CFG.bad.r, CFG.bad.g, CFG.bad.b
		end

		local priceW = Txt(priceText, "ixVendorName", w - 14 + ox, 14, pr, pg, pb, 255 * fade * cf, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		local priceLabel = (sel and sel.isLocal) and STR.priceBuy or STR.priceSell

		Txt(priceLabel, "ixVendorTiny", w - 14 + ox, 38, ar, ag, ab, 170 * fade * cf, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

		-- название (печатается) и строка статуса
		local nameMax = w - 112 - 14 - math.max(priceW, 60) - 16
		local name = ClipText(snap.name, "ixVendorName", nameMax)

		Txt(TypeText(name, Clamp01((now - this.changeAt) / 0.28)), "ixVendorName", 112 + ox, 14, 255, 255, 255, 255 * fade * cf, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		if (sel and sel.subText) then
			local sc = sel.subBad and CFG.bad or GetAccent()

			Txt(sel.subText, "ixVendorSmall", 112 + ox, 38, sc.r, sc.g, sc.b, 220 * fade * cf, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		-- описание
		for i, line in ipairs(this.lines) do
			Txt(line, "ixVendorSmall", 112 + ox, 56 + (i - 1) * 16, 220, 228, 238, 170 * fade * cf, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		-- полоса запаса
		local by = 124
		local bx, bw = 12, w - 24

		Txt(sel and sel.barLabel or "", "ixVendorTiny", bx, by - 16, ar, ag, ab, 170 * fade, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		local target = (sel and sel.barFrac) or 1

		this.barShown = Approach(this.barShown, target, 8)

		surface.SetDrawColor(ar, ag, ab, 38 * fade)
		surface.DrawRect(bx, by, bw, 5)

		if (sel and sel.barFrac) then
			local fillW = math.floor(bw * this.barShown)
			local low = sel.barFrac <= 0.2

			if (low) then
				surface.SetDrawColor(CFG.bad.r, CFG.bad.g, CFG.bad.b, 235 * fade)
			else
				surface.SetDrawColor(255, 255, 255, 235 * fade)
			end

			surface.DrawRect(bx, by, fillW, 5)

			-- сегментные деления
			surface.SetDrawColor(7, 10, 15, 190 * fade)

			for i = 1, 19 do
				surface.DrawRect(bx + math.floor(bw * i / 20), by, 1, 5)
			end
		else
			-- бесконечный запас: бегущие штрихи
			local off = (now * 22) % 12

			surface.SetDrawColor(ar, ag, ab, 150 * fade)

			for d = -12, bw, 12 do
				local x = bx + d + off

				if (x >= bx and x + 6 <= bx + bw) then
					surface.DrawRect(x, by, 6, 5)
				end
			end
		end

		surface.SetDrawColor(ar, ag, ab, 140 * fade)
		surface.DrawOutlinedRect(bx - 1, by - 1, bw + 2, 7, 1)
	end

	return card
end

-- ============================================================
-- Основное окно
-- ============================================================

local PANEL = {}

AccessorFunc(PANEL, "bReadOnly", "ReadOnly", FORCE_BOOL)

local function BuildColumn(frame, role, title, emptyText, selectionKey, tint, captionText)
	local colW = frame.colW

	local col = frame:Add("DPanel")
	col:SetWide(colW)
	col:Dock(role == "vendor" and LEFT or RIGHT)

	col.role = role
	col.count = 0
	col.shownCount = 0
	col:SetAlpha(0)

	col.Paint = function(this, w, h)
		local ar, ag, ab = AccentRGB()
		local now = RealTime()

		surface.SetDrawColor(7, 12, 20, 205)
		surface.DrawRect(0, 0, w, h)

		-- мелкая сетка внутри колонки
		if (CFG.grid) then
			surface.SetDrawColor(ar, ag, ab, 3)

			for gx = 0, w, 22 do
				surface.DrawRect(gx, 0, 1, h)
			end

			for gy = HEAD_H + BAR_H, h, 22 do
				surface.DrawRect(0, gy, w, 1)
			end
		end

		-- пустой список
		if (this.count == 0) then
			local top = HEAD_H + BAR_H
			local midY = top + (h - top - CARD_H) * 0.5
			local blink = (math.floor(now * 2) % 2 == 0) and "_" or " "
			local typed = TypeText(emptyText, Step(now - (this.emptyAt or now), 0, 0.5))

			Txt(typed .. blink, "ixVendorText", w * 0.5, midY, ar, ag, ab, 150, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		else
			this.emptyAt = nil
		end

		if (this.count == 0 and not this.emptyAt) then
			this.emptyAt = now
		end
	end

	col.PaintOver = function(this, w, h)
		local ar, ag, ab = AccentRGB()
		local grow = EaseOutCubic(Step(RealTime() - frame.openStart, 0.25, 0.5))

		surface.SetDrawColor(ar, ag, ab, 70)
		surface.DrawOutlinedRect(0, 0, w, h, 1)

		DrawBrackets(0, 0, w, h, 12 * grow, ar, ag, ab, 220)
	end

	-- ---------- шапка с фондами ----------
	local head = col:Add("DPanel")
	head:SetTall(HEAD_H)
	head:Dock(TOP)

	head.Paint = function(this, w, h)
		frame:PaintFundsHead(role, captionText, w, h)
	end

	-- ---------- заголовок списка ----------
	local bar = col:Add("DPanel")
	bar:SetTall(BAR_H)
	bar:Dock(TOP)

	bar.Paint = function(this, w, h)
		local ar, ag, ab = AccentRGB()
		local now = RealTime()

		surface.SetDrawColor(4, 7, 12, 235)
		surface.DrawRect(0, 0, w, h)

		-- пульсирующий квадрат
		local pulse = 0.5 + 0.5 * math.sin(now * 3 + (role == "vendor" and 0 or 1.6))

		surface.SetDrawColor(255, 255, 255, 120 + 110 * pulse)
		surface.DrawRect(14, h * 0.5 - 3, 6, 6)

		Txt(title, "ixVendorSmall", 30, h * 0.5, 255, 255, 255, 230, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		Txt(string.format("[%02d]", math.Round(col.shownCount)), "ixVendorMono", w - 14, h * 0.5, ar, ag, ab, 200, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		-- нижняя линия и бегущий сегмент
		surface.SetDrawColor(ar, ag, ab, 60)
		surface.DrawRect(0, h - 1, w, 1)

		local sx = ((now * 0.22 + (role == "vendor" and 0 or 0.5)) % 1) * (w + 80) - 80

		for i = 0, 7 do
			local x = sx + i * 10

			if (x >= 0 and x < w) then
				surface.SetDrawColor(255, 255, 255, 150 * math.sin((i + 0.5) / 8 * math.pi))
				surface.DrawRect(x, h - 1, 10, 1)
			end
		end
	end

	-- ---------- карточка выбранного предмета ----------
	local card = BuildCard(frame, col, role, selectionKey, tint)

	-- ---------- список ----------
	local scroll = col:Add("DScrollPanel")
	scroll:Dock(FILL)
	scroll:DockMargin(3, 3, 3, 3)

	local vbar = scroll:GetVBar()
	vbar:SetWide(5)
	vbar:SetHideButtons(true)

	vbar.Paint = function(_, w, h)
		local ar, ag, ab = AccentRGB()

		surface.SetDrawColor(ar, ag, ab, 18)
		surface.DrawRect(0, 0, w, h)
	end

	vbar.btnGrip.Paint = function(this, w, h)
		local ar, ag, ab = AccentRGB()

		this.hoverFrac = Approach(this.hoverFrac or 0, (this:IsHovered() or this.Depressed) and 1 or 0, 12)

		surface.SetDrawColor(ar, ag, ab, 110 + 100 * this.hoverFrac)
		surface.DrawRect(0, 0, w, h)
	end

	local list = scroll:Add("DListLayout")
	list:Dock(TOP)
	list:DockPadding(0, 0, 0, 4)

	return col, scroll, list, card
end

function PANEL:Init()
	local sw, sh = ScrW(), ScrH()
	local w = math.min(math.max(math.floor(sw * 0.66), 920), sw - 20)
	local h = math.min(math.max(math.floor(sh * 0.82), 660), sh - 20)

	self:SetSize(w, h)

	self.homeX = math.floor((sw - w) * 0.5)
	self.homeY = math.floor((sh - h) * 0.5)

	self:SetPos(self.homeX, self.homeY + 28)
	self:SetTitle("")
	self:ShowCloseButton(false)
	self:SetDraggable(false)
	self:MakePopup()
	self:DockPadding(PAD, TOP_H + PAD, PAD, BOT_H + 6)
	self.lblTitle:SetVisible(false)

	-- таймлайн появления
	self.openStart = RealTime()
	self.closing = nil
	self.tradeAt = -10
	self:SetAlpha(0)

	-- анимируемые фонды
	self.funds = {
		vendor = {popups = {}},
		client = {popups = {}}
	}

	self.colW = math.floor((w - PAD * 2 - GAP) / 2)

	PlayUI("open")

	-- ---------- кнопка закрытия ----------
	self.closeButton = self:Add("DButton")
	self.closeButton:SetText("")
	self.closeButton:SetSize(34, 26)
	self.closeButton:SetPos(w - PAD - 34, math.floor((TOP_H - 26) * 0.5))
	self.closeButton.hoverFrac = 0

	self.closeButton.OnCursorEntered = function()
		PlayUI("hover", 1.05)
	end

	self.closeButton.DoClick = function()
		self:Close()
	end

	self.closeButton.Paint = function(this, cw, ch)
		local ar, ag, ab = AccentRGB()
		local bad = CFG.bad

		this.hoverFrac = Approach(this.hoverFrac, this:IsHovered() and 1 or 0, 14)

		local f = this.hoverFrac

		surface.SetDrawColor(Lerp(f, ar, bad.r), Lerp(f, ag, bad.g), Lerp(f, ab, bad.b), 28 + 60 * f)
		surface.DrawRect(0, 0, cw, ch)

		surface.SetDrawColor(Lerp(f, ar, bad.r), Lerp(f, ag, bad.g), Lerp(f, ab, bad.b), 130 + 110 * f)
		surface.DrawOutlinedRect(0, 0, cw, ch, 1)

		local s = 5 + f * 1.5

		SmoothLine(cw * 0.5 - s, ch * 0.5 - s, cw * 0.5 + s, ch * 0.5 + s, 1.5, 255, 255, 255, 190 + 65 * f)
		SmoothLine(cw * 0.5 - s, ch * 0.5 + s, cw * 0.5 + s, ch * 0.5 - s, 1.5, 255, 255, 255, 190 + 65 * f)

		return true
	end

	-- ---------- колонки ----------
	self.sellingCol, self.selling, self.sellingItems, self.sellingCard =
		BuildColumn(self, "vendor", STR.sellingCol, STR.emptySell, "activeSell", GetAccent(), STR.vendor)

	self.buyingCol, self.buying, self.buyingItems, self.buyingCard =
		BuildColumn(self, "client", STR.buyingCol, STR.emptyBuy, "activeBuy", CFG.good, STR.client)

	-- Текст «purchase»: поставщик продаёт предмет нам.
	self.vendorSell = self.sellingCard.button
	self.vendorSell.caption = L"purchase"

	self.vendorSell.DoClick = function(this)
		if (IsValid(self.activeSell)) then
			self.tradeAt = RealTime()

			net.Start("ixVendorTrade")
				net.WriteString(self.activeSell.item)
				net.WriteBool(false)
			net.SendToServer()
		end
	end

	self.vendorBuy = self.buyingCard.button
	self.vendorBuy.caption = L"sell"

	self.vendorBuy.DoClick = function(this)
		if (IsValid(self.activeBuy)) then
			self.tradeAt = RealTime()

			net.Start("ixVendorTrade")
				net.WriteString(self.activeBuy.item)
				net.WriteBool(true)
			net.SendToServer()
		end
	end

	self.sellingList = {}
	self.buyingList = {}
	self.rowCounter = {selling = 0, buying = 0}
end

-- ---------- шапка колонки: название и фонды ----------
function PANEL:PaintFundsHead(role, caption, w, h)
	local ar, ag, ab = AccentRGB()
	local now = RealTime()
	local fund = self.funds[role]
	local el = now - self.openStart
	local start = (role == "vendor") and 0.2 or 0.35

	surface.SetDrawColor(10, 18, 30, 230)
	surface.DrawRect(0, 0, w, h)

	-- акцентная полоса слева «вырастает» при появлении
	surface.SetDrawColor(ar, ag, ab, 230)
	surface.DrawRect(0, 0, 3, math.floor(h * EaseOutCubic(Step(el, start, 0.4))))

	-- нижняя линия выезжает слева направо
	surface.SetDrawColor(ar, ag, ab, 120)
	surface.DrawRect(0, h - 1, math.floor(w * EaseOutCubic(Step(el, start, 0.6))), 1)

	Txt(caption, "ixVendorTiny", 16, 9, ar, ag, ab, 180, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	Txt(STR.funds, "ixVendorTiny", w - 14, 9, ar, ag, ab, 180, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

	-- значение фондов
	local valueText

	if (fund.unlimited) then
		valueText = STR.unlimited
	elseif (fund.shown) then
		valueText = ix.currency.Get(math.Round(fund.shown))
	else
		valueText = "—"
	end

	-- кратковременная вспышка при изменении
	local flash = Clamp01(1 - (now - (fund.changedAt or -10)) / 0.7)
	local up = (fund.lastDelta or 0) >= 0
	local fr = Lerp(flash, 255, up and CFG.good.r or CFG.bad.r)
	local fg = Lerp(flash, 255, up and CFG.good.g or CFG.bad.g)
	local fb = Lerp(flash, 255, up and CFG.good.b or CFG.bad.b)

	local valueW = Txt(valueText, "ixVendorName", w - 14, 26, fr, fg, fb, 255, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

	-- имя
	local nameText = (role == "vendor") and (self.vendorNameText or "") or (self.ourNameText or "")

	Txt(ClipText(nameText, "ixVendorName", w - valueW - 80), "ixVendorName", 16, 26, 255, 255, 255, 240, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	-- всплывающие «+/−» при изменении фондов
	for i = #fund.popups, 1, -1 do
		local p = fund.popups[i]
		local age = now - p.start

		if (age > 1.6) then
			table.remove(fund.popups, i)
		else
			local rise = EaseOutCubic(Clamp01(age / 0.5))
			local alpha = 255 * (1 - Step(age, 0.9, 0.7))
			local col = p.delta >= 0 and CFG.good or CFG.bad
			local sign = p.delta >= 0 and "+" or "−"

			Txt(sign .. ix.currency.Get(math.abs(p.delta)), "ixVendorSmall",
				w - 14 - valueW - 14, 36 - 14 * rise, col.r, col.g, col.b, alpha, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end
end

function PANEL:Paint(w, h)
	local ar, ag, ab = AccentRGB()
	local now = RealTime()
	local el = self.closing and 10 or (now - self.openStart)

	if (ix.util and ix.util.DrawBlur) then
		ix.util.DrawBlur(self, 4)
	end

	surface.SetDrawColor(6, 9, 14, 246)
	surface.DrawRect(0, 0, w, h)

	-- мягкое свечение
	local breathe = 0.5 + 0.5 * math.sin(now * 0.6)

	surface.SetMaterial(glowMat)
	surface.SetDrawColor(ar, ag, ab, 13 + 5 * breathe)
	surface.DrawTexturedRect(-w * 0.2, -h * 0.45, w * 0.85, h * 0.9)
	surface.SetDrawColor(ar, ag, ab, 8)
	surface.DrawTexturedRect(w * 0.45, h * 0.5, w * 0.75, h * 0.8)
	draw.NoTexture()

	-- тактическая сетка
	if (CFG.grid) then
		local step = 44

		for gx = 0, w, step do
			surface.SetDrawColor(ar, ag, ab, (gx / step) % 4 == 0 and 6 or 3)
			surface.DrawRect(gx, 0, 1, h)
		end

		for gy = 0, h, step do
			surface.SetDrawColor(ar, ag, ab, (gy / step) % 4 == 0 and 6 or 3)
			surface.DrawRect(0, gy, w, 1)
		end
	end

	-- ---------- верхняя полоса ----------
	local mid = TOP_H * 0.5

	surface.SetDrawColor(ar, ag, ab, 16)
	surface.DrawRect(0, 0, w, TOP_H)

	surface.SetDrawColor(ar, ag, ab, 150)
	surface.DrawRect(0, TOP_H, math.floor(w * EaseOutCubic(Step(el, 0, 0.6))), 1)

	-- шевроны (мигают по очереди)
	local c1 = 0.5 + 0.5 * math.sin(now * 3)
	local c2 = 0.5 + 0.5 * math.sin(now * 3 - 0.9)

	DrawChevron(28, mid, 8, 1, 2, 255, 255, 255, 110 + 120 * c1)
	DrawChevron(40, mid, 8, 1, 2, ar, ag, ab, 110 + 120 * c2)

	-- название и подзаголовок
	local title = Upper(self.lblTitle:GetText())
	local titleP = Step(el, 0.15, 0.5)

	surface.SetFont("ixVendorTitle")

	local titleW = surface.GetTextSize(title)

	Txt(TypeText(title, titleP), "ixVendorTitle", 62, mid, 255, 255, 255, 255, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local subA = EaseOutCubic(Step(el, 0.5, 0.4))

	surface.SetDrawColor(ar, ag, ab, 120 * subA)
	surface.DrawRect(62 + titleW + 14, 14, 1, TOP_H - 28)
	Txt(STR.subtitle, "ixVendorSmall", 62 + titleW + 28, mid, ar, ag, ab, 200 * subA, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	-- правая часть: номер поста и режим просмотра
	local right = w - PAD - 34 - 18

	if (IsValid(self.entity)) then
		local tag = string.format("№ %04d", self.entity:EntIndex())
		local tagW = Txt(tag, "ixVendorMono", right, mid, 255, 255, 255, 150, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		right = right - tagW - 20
	end

	if (self:GetReadOnly()) then
		surface.SetFont("ixVendorSmall")

		local stampW, stampH = surface.GetTextSize(STR.readOnly)
		local pulse = 0.5 + 0.5 * math.sin(now * 3)
		local bad = CFG.bad

		surface.SetDrawColor(bad.r, bad.g, bad.b, 22 + 20 * pulse)
		surface.DrawRect(right - stampW - 20, mid - stampH * 0.5 - 5, stampW + 20, stampH + 10)

		surface.SetDrawColor(bad.r, bad.g, bad.b, 170 + 70 * pulse)
		surface.DrawOutlinedRect(right - stampW - 20, mid - stampH * 0.5 - 5, stampW + 20, stampH + 10, 1)

		Txt(STR.readOnly, "ixVendorSmall", right - 10, mid, bad.r, bad.g, bad.b, 230, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	-- ---------- центральный разделитель с обменом ----------
	local cx = math.floor(w * 0.5)
	local top = TOP_H + PAD + 6
	local bottom = h - BOT_H - 10
	local reveal = EaseOutCubic(Step(el, 0.3, 0.6))
	local lineEnd = top + (bottom - top) * reveal

	surface.SetDrawColor(ar, ag, ab, 70)

	for y = top, lineEnd, 8 do
		surface.DrawRect(cx, y, 1, 4)
	end

	local cy = TOP_H + PAD + HEAD_H + BAR_H + (h - TOP_H - PAD - HEAD_H - BAR_H - CARD_H - BOT_H) * 0.5
	local pulseT = 1 - Clamp01((now - self.tradeAt) / 0.9)
	local sway = math.sin(now * 2) * 2
	local arrowA = (90 + 165 * pulseT) * reveal

	if (pulseT > 0.01) then
		surface.SetMaterial(glowMat)
		surface.SetDrawColor(ar, ag, ab, 140 * pulseT)
		surface.DrawTexturedRect(cx - 34, cy - 34, 68, 68)
		draw.NoTexture()
	end

	surface.SetDrawColor(6, 9, 14, 255)
	surface.DrawRect(cx - 12, cy - 26, 25, 52)

	-- стрелки «поставщик ⇄ клиент»
	SmoothLine(cx - 8 + sway, cy - 9, cx + 8 + sway, cy - 9, 1.5, 255, 255, 255, arrowA)
	SmoothLine(cx + 3 + sway, cy - 14, cx + 8 + sway, cy - 9, 1.5, 255, 255, 255, arrowA)
	SmoothLine(cx + 3 + sway, cy - 4, cx + 8 + sway, cy - 9, 1.5, 255, 255, 255, arrowA)

	SmoothLine(cx + 8 - sway, cy + 9, cx - 8 - sway, cy + 9, 1.5, ar, ag, ab, arrowA)
	SmoothLine(cx - 3 - sway, cy + 4, cx - 8 - sway, cy + 9, 1.5, ar, ag, ab, arrowA)
	SmoothLine(cx - 3 - sway, cy + 14, cx - 8 - sway, cy + 9, 1.5, ar, ag, ab, arrowA)

	-- ---------- нижняя полоса ----------
	local by = h - BOT_H * 0.5 - 2
	local botA = EaseOutCubic(Step(el, 0.45, 0.5))

	surface.SetDrawColor(ar, ag, ab, 50 * botA)
	surface.DrawRect(PAD, h - BOT_H - 4, math.floor((w - PAD * 2) * botA), 1)

	local pulse = 0.5 + 0.5 * math.sin(now * 3.2)

	surface.SetDrawColor(255, 255, 255, (120 + 110 * pulse) * botA)
	surface.DrawRect(PAD + 2, by - 3, 6, 6)

	Txt(TypeText(STR.footerLeft, Step(el, 0.5, 0.8)), "ixVendorTiny", PAD + 16, by, 255, 255, 255, 140 * botA, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	Txt(os.date("%H:%M:%S"), "ixVendorMono", w - PAD - 2, by, ar, ag, ab, 190 * botA, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

function PANEL:PaintOver(w, h)
	local ar, ag, ab = AccentRGB()
	local now = RealTime()
	local el = self.closing and 10 or (now - self.openStart)
	local grow = EaseOutCubic(Step(el, 0.05, 0.55))

	-- внешняя рамка и угловые скобки
	surface.SetDrawColor(ar, ag, ab, 80)
	surface.DrawOutlinedRect(0, 0, w, h, 1)

	DrawBrackets(0, 0, w, h, 24 * grow, ar, ag, ab, 230)

	-- развёртка
	if (CFG.scanlines) then
		surface.SetDrawColor(0, 0, 0, 14)

		for y = 0, h, 4 do
			surface.DrawRect(0, y, w, 1)
		end

		local bandH = h * 0.14
		local y0 = ((now * h * 0.09) % (h + bandH)) - bandH
		local parts = 12

		for i = 0, parts - 1 do
			local f = math.sin((i + 0.5) / parts * math.pi)

			surface.SetDrawColor(ar, ag, ab, 5 * f)
			surface.DrawRect(0, y0 + i * bandH / parts, w, math.ceil(bandH / parts) + 1)
		end
	end

	-- вспышка в момент открытия
	local flash = 1 - Step(el, 0, 0.25)

	if (flash > 0.01) then
		surface.SetDrawColor(ar, ag, ab, 40 * flash)
		surface.DrawRect(0, 0, w, h)
	end
end

function PANEL:Close()
	if (self.closing) then
		return
	end

	self.closing = RealTime()
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)

	PlayUI("back")
end

-- ---------- фонды ----------

function PANEL:SetFund(role, value)
	local fund = self.funds[role]

	if (value == nil) then
		fund.unlimited = true
		fund.target = nil

		return
	end

	fund.unlimited = false

	if (fund.target ~= nil and value ~= fund.target) then
		local delta = value - fund.target

		fund.popups[#fund.popups + 1] = {delta = delta, start = RealTime()}
		fund.changedAt = RealTime()
		fund.lastDelta = delta

		if (role == "client") then
			PlayUI("confirm", delta > 0 and 1.1 or 0.92)
		end
	end

	if (fund.shown == nil) then
		fund.shown = value
	end

	fund.target = value
end

function PANEL:UpdateHeader()
	local entity = self.entity

	if (not IsValid(entity)) then
		return
	end

	local name = entity:GetDisplayName()

	self:SetTitle(name)
	self.vendorNameText = name
	self.ourNameText = L"you"

	local character = GetCharacter()

	self:SetFund("vendor", entity.money)
	self:SetFund("client", character and character:GetMoney() or nil)
end

function PANEL:addItem(uniqueID, listID)
	local entity = self.entity
	local items = entity.items
	local data = items[uniqueID]
	local character = GetCharacter()

	if ((not listID or listID == "selling") and not IsValid(self.sellingList[uniqueID])
	and ix.item.list[uniqueID]) then
		if (data and data[VENDOR_MODE] and data[VENDOR_MODE] ~= VENDOR_BUYONLY) then
			local item = self.sellingItems:Add("ixVendorItem")
			item:Setup(uniqueID)
			item:SetRevealDelay(self:NextRowDelay("selling"))

			self.sellingList[uniqueID] = item
			self.sellingItems:InvalidateLayout()
		end
	end

	if ((not listID or listID == "buying") and not IsValid(self.buyingList[uniqueID])
	and character and character:GetInventory():HasItem(uniqueID)) then
		if (data and data[VENDOR_MODE] and data[VENDOR_MODE] ~= VENDOR_SELLONLY) then
			local item = self.buyingItems:Add("ixVendorItem")
			item:Setup(uniqueID)
			item.isLocal = true
			item:Refresh()
			item:SetRevealDelay(self:NextRowDelay("buying"))

			self.buyingList[uniqueID] = item
			self.buyingItems:InvalidateLayout()
		end
	end
end

-- задержка появления строки: пока окно открывается, строки «выезжают» по очереди
function PANEL:NextRowDelay(key)
	local n = self.rowCounter[key]

	self.rowCounter[key] = n + 1

	if (RealTime() - self.openStart > CFG.openTime + 0.4) then
		return 0
	end

	return 0.3 + math.min(n, 12) * CFG.rowStagger
end

function PANEL:removeItem(uniqueID, listID)
	if (not listID or listID == "selling") then
		if (IsValid(self.sellingList[uniqueID])) then
			self.sellingList[uniqueID]:Dismiss()
		end
	end

	if (not listID or listID == "buying") then
		if (IsValid(self.buyingList[uniqueID])) then
			self.buyingList[uniqueID]:Dismiss()
		end
	end
end

function PANEL:Setup(entity)
	self.entity = entity

	self.vendorBuy:SetEnabled(not self:GetReadOnly())
	self.vendorSell:SetEnabled(not self:GetReadOnly())

	self:UpdateHeader()

	for k, _ in SortedPairs(entity.items) do
		self:addItem(k, "selling")
	end

	local character = GetCharacter()

	if (character) then
		for _, v in SortedPairs(character:GetInventory():GetItems()) do
			self:addItem(v.uniqueID, "buying")
		end
	end

	self.sellingCol.count = CountValid(self.sellingList)
	self.buyingCol.count = CountValid(self.buyingList)
	self.sellingCol.shownCount = 0
	self.buyingCol.shownCount = 0
end

function PANEL:OnRemove()
	net.Start("ixVendorClose")
	net.SendToServer()

	if (IsValid(ix.gui.vendorEditor)) then
		ix.gui.vendorEditor:Remove()
	end
end

function PANEL:Think()
	local now = RealTime()
	local entity = self.entity

	if (not IsValid(entity)) then
		self:Remove()

		return
	end

	-- ---------- появление / закрытие ----------
	if (self.closing) then
		local t = Clamp01((now - self.closing) / CFG.closeTime)

		self:SetAlpha(255 * (1 - EaseInOutSine(t)))
		self:SetPos(self.homeX, self.homeY + 18 * EaseInOutSine(t))

		if (t >= 1) then
			self:Remove()

			return
		end
	else
		local el = now - self.openStart
		local t = Clamp01(el / CFG.openTime)

		self:SetAlpha(255 * Clamp01(t * 3.5))
		self:SetPos(self.homeX, self.homeY + 28 * (1 - EaseOutCubic(Clamp01(t * 1.6))))

		-- колонки появляются по очереди
		self.sellingCol:SetAlpha(255 * EaseOutCubic(Step(el, 0.15, 0.4)))
		self.buyingCol:SetAlpha(255 * EaseOutCubic(Step(el, 0.3, 0.4)))
	end

	-- ---------- плавные счётчики ----------
	for _, fund in pairs(self.funds) do
		if (fund.shown and fund.target) then
			fund.shown = Approach(fund.shown, fund.target, 7)

			if (math.abs(fund.shown - fund.target) < 0.5) then
				fund.shown = fund.target
			end
		end
	end

	self.sellingCol.shownCount = Approach(self.sellingCol.shownCount, self.sellingCol.count, 10)
	self.buyingCol.shownCount = Approach(self.buyingCol.shownCount, self.buyingCol.count, 10)

	if ((self.nextUpdate or 0) < CurTime()) then
		self:UpdateHeader()

		self.sellingCol.count = CountValid(self.sellingList)
		self.buyingCol.count = CountValid(self.buyingList)

		self.nextUpdate = CurTime() + 0.25
	end
end

function PANEL:OnItemSelected(panel)
	PlayUI("click")
end

vgui.Register("ixVendor", PANEL, "DFrame")

-- ============================================================
-- Строка предмета
-- ============================================================

PANEL = {}

function PANEL:Init()
	self:SetTall(ROW_H)
	self:DockMargin(4, 4, 4, 0)

	self.hover = 0
	self.selFrac = 0
	self.barShown = 0
	self.revealAt = RealTime()
	self.reveal = 0

	self:SetAlpha(0)

	self.icon = self:Add("SpawnIcon")
	self.icon:SetPos(11, 8)
	self.icon:SetSize(42, 42)
	self.icon:SetModel("models/error.mdl")

	self.click = self:Add("DButton")
	self.click:Dock(FILL)
	self.click:SetText("")
	self.click.Paint = function() end

	self.click.OnCursorEntered = function()
		if (not self.dying) then
			PlayUI("hover", math.Rand(0.96, 1.06), 0.8)
		end
	end

	self.click.DoClick = function(this)
		local frame = ix.gui.vendor

		if (self.dying or not IsValid(frame)) then
			return
		end

		if (self.isLocal) then
			frame.activeBuy = self
		else
			frame.activeSell = self
		end

		frame:OnItemSelected(self)
	end
end

function PANEL:SetRevealDelay(delay)
	self.revealAt = RealTime() + (delay or 0)
end

function PANEL:SetCallback(callback)
	self.click.DoClick = function(this)
		callback()
		self.selected = true
	end
end

function PANEL:Setup(uniqueID)
	local item = ix.item.list[uniqueID]

	if (item) then
		self.item = uniqueID
		self.itemName = item:GetName()
		self.itemModel = item:GetModel()
		self.itemSkin = item:GetSkin()

		local ok, desc = pcall(item.GetDescription, item)

		if (ok and isstring(desc)) then
			self.itemDesc = desc
		else
			self.itemDesc = item.description or ""
		end

		self.icon:SetModel(self.itemModel, self.itemSkin)

		self.click:SetHelixTooltip(function(tooltip)
			ix.hud.PopulateItemTooltip(tooltip, item)

			local entity = ix.gui.vendor.entity

			if (entity and entity.items[self.item] and entity.items[self.item][VENDOR_MAXSTOCK]) then
				local info = entity.items[self.item]
				local stock = tooltip:AddRowAfter("name", "stock")

				stock:SetText(string.format("%s: %d/%d", STR.stock, info[VENDOR_STOCK], info[VENDOR_MAXSTOCK]))
				stock:SetBackgroundColor(derma.GetColor("Info", self))
				stock:SizeToContents()
			end
		end)

		self:Refresh()
	end
end

-- Обновляет цену, остатки и признаки «не хватает денег / нет в наличии».
function PANEL:Refresh()
	local frame = ix.gui.vendor

	if (not self.item or not IsValid(frame) or not IsValid(frame.entity)) then
		return
	end

	local entity = frame.entity
	local character = GetCharacter()

	if (not character) then
		return
	end

	local info = entity.items[self.item]
	local price = entity:GetPrice(self.item, self.isLocal) or 0

	self.price = price
	self.maxStock = info and info[VENDOR_MAXSTOCK]
	self.stock = info and info[VENDOR_STOCK]

	if (self.isLocal) then
		self.count = character:GetInventory():GetItemCount(self.item)
		-- поставщик не может заплатить
		self.noFunds = entity.money ~= nil and entity.money < price
		-- на складе поставщика нет места
		self.full = self.maxStock ~= nil and (self.stock or 0) >= self.maxStock
		self.soldOut = false
	else
		self.noFunds = character:GetMoney() < price
		self.soldOut = self.maxStock ~= nil and (self.stock or 0) <= 0
		self.full = false
	end

	-- вторая строка (общая для строки списка и карточки)
	self.subBad = false

	if (self.isLocal) then
		self.subText = string.format("%s: x%d", STR.owned, self.count or 0)

		if (self.full) then
			self.subText = STR.full
			self.subBad = true
		end
	elseif (self.soldOut) then
		self.subText = STR.soldOut
		self.subBad = true
	elseif (self.maxStock) then
		self.subText = string.format("%s: %d/%d", STR.stock, self.stock or 0, self.maxStock)
	else
		self.subText = string.format("%s: %s", STR.stock, STR.noLimit)
	end

	-- полоса запаса
	if (self.maxStock and self.maxStock > 0) then
		self.barFrac = Clamp01((self.stock or 0) / self.maxStock)
		self.barLabel = string.format("%s  %d / %d", self.isLocal and STR.barCapacity or STR.barStock, self.stock or 0, self.maxStock)
	else
		self.barFrac = nil
		self.barLabel = STR.barUnlimited
	end
end

-- Плавно убирает строку из списка.
function PANEL:Dismiss()
	if (self.dying) then
		return
	end

	self.dying = RealTime()

	local frame = ix.gui.vendor

	if (IsValid(frame)) then
		local list = self.isLocal and frame.buyingList or frame.sellingList

		if (list and list[self.item] == self) then
			list[self.item] = nil
		end

		if (frame.activeBuy == self) then
			frame.activeBuy = nil
		end

		if (frame.activeSell == self) then
			frame.activeSell = nil
		end
	end

	self.click:SetMouseInputEnabled(false)
end

function PANEL:Think()
	local now = RealTime()

	-- плавное удаление
	if (self.dying) then
		local t = Clamp01((now - self.dying) / 0.28)
		local parent = self:GetParent()

		self:SetAlpha(255 * (1 - t))
		self:SetTall(math.max(0, math.floor(ROW_H * (1 - EaseInOutSine(t)))))
		self:DockMargin(4, math.floor(4 * (1 - t)), 4, 0)

		if (IsValid(parent)) then
			parent:InvalidateLayout()
		end

		if (t >= 1) then
			self:Remove()
		end

		return
	end

	-- плавное появление
	if (self.reveal < 1) then
		self.reveal = Clamp01((now - self.revealAt) / 0.4)
		self:SetAlpha(255 * EaseOutCubic(self.reveal))
	end

	if ((self.nextUpdate or 0) < CurTime()) then
		local frame = IsValid(ix.gui.vendor) and ix.gui.vendor
		local character = GetCharacter()

		if (frame and frame.entity and self.isLocal and character) then
			local count = character:GetInventory():GetItemCount(self.item)

			if (count == 0) then
				self:Dismiss()

				return
			end
		end

		self:Refresh()
		self.nextUpdate = CurTime() + 0.1
	end
end

function PANEL:Paint(w, h)
	local frame = ix.gui.vendor
	local selected = IsValid(frame) and (frame.activeBuy == self or frame.activeSell == self)
	local ar, ag, ab = AccentRGB()
	local now = RealTime()
	local blocked = self.noFunds or self.soldOut or self.full

	self.hover = Approach(self.hover, self.click:IsHovered() and 1 or 0, 14)
	self.selFrac = Approach(self.selFrac, selected and 1 or 0, 12)

	-- момент выбора: запоминаем для блика
	if (selected and not self.wasSelected) then
		self.selAt = now
	end

	self.wasSelected = selected

	local hv = EaseOutCubic(self.hover)
	local sf = self.selFrac

	draw.NoTexture()

	-- основа
	surface.SetDrawColor(9, 15, 25, 200)
	surface.DrawRect(0, 0, w, h)

	-- заливка, выезжающая слева при наведении
	if (hv > 0.01) then
		surface.SetDrawColor(ar, ag, ab, 22 * hv)
		surface.DrawRect(0, 0, math.floor(w * hv), h)
	end

	-- выбранная позиция
	if (sf > 0.01) then
		surface.SetDrawColor(ar, ag, ab, 40 * sf)
		surface.DrawRect(0, 0, math.floor(w * EaseOutCubic(sf)), h)

		-- блик, пробегающий при выборе
		local st = (now - (self.selAt or now)) * 2.2

		if (st < 1) then
			local sx = math.floor(-40 + (w + 80) * EaseOutCubic(st))

			for i = 0, 7 do
				local x = sx + i * 5

				if (x >= 0 and x < w) then
					surface.SetDrawColor(255, 255, 255, 34 * math.sin((i + 0.5) / 8 * math.pi))
					surface.DrawRect(x, 0, 5, h)
				end
			end
		end
	end

	-- рамка
	local edge = math.max(sf, hv * 0.55)

	surface.SetDrawColor(ar, ag, ab, 44 + 150 * edge)
	surface.DrawOutlinedRect(0, 0, w, h, 1)

	-- маркер слева
	surface.SetDrawColor(255, 255, 255, 70 + 185 * math.max(sf, hv))
	surface.DrawRect(0, 0, 3 + math.floor(hv * 2 + sf * 2), h)

	-- рамка под иконку
	surface.SetDrawColor(5, 8, 13, 255)
	surface.DrawRect(9, 6, 46, 46)
	surface.SetDrawColor(ar, ag, ab, 70 + 150 * sf)
	surface.DrawOutlinedRect(9, 6, 46, 46, 1)

	-- число экземпляров на иконке
	if (self.isLocal and (self.count or 0) > 1) then
		local label = "x" .. self.count

		surface.SetFont("ixVendorTiny")

		local lw, lh = surface.GetTextSize(label)

		surface.SetDrawColor(5, 8, 13, 230)
		surface.DrawRect(55 - lw - 6, 52 - lh - 2, lw + 6, lh + 2)
		Txt(label, "ixVendorTiny", 52, 51, 255, 255, 255, 240, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	end

	-- название
	local priceW = 0

	if (self.price) then
		surface.SetFont("ixVendorName")
		priceW = surface.GetTextSize(ix.currency.Get(self.price))
	end

	local nameMax = w - 68 - priceW - 28

	Txt(ClipText(self.itemName or "", "ixVendorText", nameMax), "ixVendorText", 68, 10, 255, 255, 255, 235, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	-- вторая строка
	local sc = self.subBad and CFG.bad or GetAccent()

	Txt(self.subText or "", "ixVendorSmall", 68, h - 24, sc.r, sc.g, sc.b, self.subBad and 230 or 190, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	-- цена справа
	if (self.price) then
		local pr, pg, pb = 255, 255, 255

		if (blocked) then
			pr, pg, pb = CFG.bad.r, CFG.bad.g, CFG.bad.b
		end

		Txt(ix.currency.Get(self.price), "ixVendorName", w - 14, 8, pr, pg, pb, 245, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		Txt(self.isLocal and STR.priceBuy or STR.priceSell, "ixVendorTiny", w - 14, h - 22, ar, ag, ab, 170, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	end

	-- тонкая полоса запаса у нижнего края
	if (self.barFrac) then
		self.barShown = Approach(self.barShown, self.barFrac, 8)

		surface.SetDrawColor(ar, ag, ab, 30)
		surface.DrawRect(68, h - 5, w - 68 - 14, 2)

		if (self.barFrac <= 0.2) then
			surface.SetDrawColor(CFG.bad.r, CFG.bad.g, CFG.bad.b, 230)
		else
			surface.SetDrawColor(ar, ag, ab, 200)
		end

		surface.DrawRect(68, h - 5, math.floor((w - 68 - 14) * self.barShown), 2)
	end

	-- скобки у выбранной позиции
	if (sf > 0.02) then
		DrawBrackets(0, 0, w, h, 7 * sf, 255, 255, 255, 220 * sf)
	end

	-- линия появления
	if (self.reveal < 1) then
		surface.SetDrawColor(ar, ag, ab, 220 * (1 - self.reveal))
		surface.DrawRect(0, 0, math.floor(w * EaseOutCubic(self.reveal)), 1)
	end
end

function PANEL:PaintOver(w, h)
	-- недоступные позиции затемняются
	if (self.soldOut or self.full) then
		surface.SetDrawColor(0, 0, 0, 120)
		surface.DrawRect(0, 0, w, h)
	end
end

vgui.Register("ixVendorItem", PANEL, "DPanel")