-- Общий набор «кисточек» интерфейса взлома. Стиль: минимализм - тонкие линии, много воздуха,
-- один акцентный цвет, мягкие анимации. Используется терминалом, играми, досье и HUD.

local HACK = ix.hack
local C, S = HACK.C, HACK.S

local UI = HACK.UI or {}

HACK.UI = UI

local BLUR = Material("pp/blurscreen")
local BLACK = Color(0, 0, 0)

-- ===================== Мелочи =====================

function UI.A(col, a)
	return Color(col.r, col.g, col.b, a)
end

function UI.Mul(col, k, a)
	return Color(math.min(255, col.r * k), math.min(255, col.g * k), math.min(255, col.b * k), a or 255)
end

-- Смесь двух цветов (k = 0..1).
function UI.Mix(a, b, k)
	return Color(Lerp(k, a.r, b.r), Lerp(k, a.g, b.g), Lerp(k, a.b, b.b), Lerp(k, a.a or 255, b.a or 255))
end

-- Детерминированный «случайный» 0..1 (для мерцания и шума без math.random).
function UI.Rand(a, b)
	local v = math.sin(a * 12.9898 + (b or 0) * 78.233) * 43758.5453

	return v - math.floor(v)
end

-- Плавное замедление к концу (0..1 -> 0..1).
function UI.Ease(t)
	t = math.Clamp(t, 0, 1)

	return 1 - (1 - t) ^ 3
end

-- Плавный старт и финиш.
function UI.EaseIO(t)
	t = math.Clamp(t, 0, 1)

	return t < 0.5 and 4 * t * t * t or 1 - ((-2 * t + 2) ^ 3) / 2
end

-- Подстрока по числу символов (кириллица занимает по 2 байта).
function UI.Sub(str, n)
	if (n <= 0) then return "" end

	local o = utf8.offset(str, n + 1)

	return o and string.sub(str, 1, o - 1) or str
end

function UI.Rect(x, y, w, h, col)
	surface.SetDrawColor(col)
	surface.DrawRect(x, y, w, h)
end

function UI.Frame(x, y, w, h, col, thick)
	surface.SetDrawColor(col)

	for i = 0, (thick or 1) - 1 do
		surface.DrawOutlinedRect(x + i, y + i, w - i * 2, h - i * 2)
	end
end

function UI.Text(str, font, x, y, col, ax, ay)
	draw.SimpleText(str, font, x, y, col, ax or 0, ay or 0)
end

-- Текст с разрядкой между буквами (ax: 0 - слева, 1 - по центру, 2 - справа). Возвращает ширину.
function UI.Track(str, font, x, y, col, space, ax, ay)
	surface.SetFont(font)

	local chars, widths, total = {}, {}, 0

	for _, cp in utf8.codes(str) do
		local ch = utf8.char(cp)
		local cw = surface.GetTextSize(ch)

		chars[#chars + 1] = ch
		widths[#widths + 1] = cw
		total = total + cw + space
	end

	total = math.max(0, total - space)

	local px = x

	if (ax == 1) then
		px = x - total / 2
	elseif (ax == 2) then
		px = x - total
	end

	for i, ch in ipairs(chars) do
		draw.SimpleText(ch, font, px, y, col, 0, ay or 0)
		px = px + widths[i] + space
	end

	return total
end

local GLOW = {{-2, 0}, {2, 0}, {0, -2}, {0, 2}, {-1, -1}, {1, 1}, {-1, 1}, {1, -1}}

-- Текст с очень мягким свечением.
function UI.Glow(str, font, x, y, col, ax, ay, power)
	local g = Color(col.r, col.g, col.b, math.floor(16 * (power or 1)))

	for _, o in ipairs(GLOW) do
		draw.SimpleText(str, font, x + o[1], y + o[2], g, ax or 0, ay or 0)
	end

	draw.SimpleText(str, font, x, y, col, ax or 0, ay or 0)
end

-- Плавная градиентная заливка. dir - куда идёт затухание от начальной кромки:
-- "down" (сверху вниз), "up", "right" (слева направо), "left". a0 - прозрачность у кромки, a1 - на другом конце.
-- Вертикальные градиенты рисуются текстурой (без полос). Если свечение окажется с противоположной стороны,
-- поставьте UI.GradFlip = true.
local GRAD_D = Material("vgui/gradient-d")
local GRAD_U = Material("vgui/gradient-u")

UI.GradFlip = false

function UI.Fade(x, y, w, h, dir, col, a0, a1, steps)
	local vertical = (dir == "down" or dir == "up")

	if (vertical and w > 0 and h > 0) then
		local base, delta = math.min(a0, a1), math.abs(a0 - a1)

		-- Какой стороной должна быть «плотная» часть градиента: сверху или снизу.
		local denseTop = ((dir == "down") == (a0 >= a1))

		if (UI.GradFlip) then denseTop = not denseTop end

		if (base > 0) then
			surface.SetDrawColor(col.r, col.g, col.b, base)
			surface.DrawRect(x, y, w, h)
		end

		if (delta > 0) then
			draw.NoTexture()
			surface.SetMaterial(denseTop and GRAD_D or GRAD_U)
			surface.SetDrawColor(col.r, col.g, col.b, delta)
			surface.DrawTexturedRect(x, y, w, h)
		end

		return
	end

	-- Горизонтальные: полосками, но мелкими (шаг около 3 px), чтобы не было ступенек.
	steps = math.Clamp(math.floor(w / S(3)), 8, 96)

	local step = w / steps

	for i = 0, steps - 1 do
		local p0, p1 = math.floor(i * step), math.floor((i + 1) * step)
		local seg = math.max(1, p1 - p0)
		local a = a0 + (a1 - a0) * ((i + 0.5) / steps)

		surface.SetDrawColor(col.r, col.g, col.b, a)

		if (dir == "right") then
			surface.DrawRect(x + p0, y, seg, h)
		else
			surface.DrawRect(x + w - p0 - seg, y, seg, h)
		end
	end
end

-- Размытие того, что находится позади панели.
function UI.Blur(panel, passes, amount)
	local x, y = panel:LocalToScreen(0, 0)

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(BLUR)

	for i = 1, passes do
		BLUR:SetFloat("$blur", (i / passes) * amount)
		BLUR:Recompute()
		render.UpdateScreenEffectTexture()
		surface.DrawTexturedRect(-x, -y, ScrW(), ScrH())
	end
end

-- Уголки-скобки по периметру (в минималистичном стиле почти не используются).
function UI.Brackets(x, y, w, h, col, len, thick)
	len = len or S(14)
	thick = thick or 2

	surface.SetDrawColor(col)
	surface.DrawRect(x, y, len, thick)
	surface.DrawRect(x, y, thick, len)
	surface.DrawRect(x + w - len, y, len, thick)
	surface.DrawRect(x + w - thick, y, thick, len)
	surface.DrawRect(x, y + h - thick, len, thick)
	surface.DrawRect(x, y + h - len, thick, len)
	surface.DrawRect(x + w - len, y + h - thick, len, thick)
	surface.DrawRect(x + w - thick, y + h - len, thick, len)
end

-- Лёгкая панель: едва заметная подложка, тонкая рамка и короткая акцентная черта сверху слева.
function UI.Box(x, y, w, h, accent, alpha)
	accent = accent or C.accent

	surface.SetDrawColor(8, 18, 24, math.min(alpha or 120, 120))
	surface.DrawRect(x, y, w, h)
	UI.Frame(x, y, w, h, UI.A(accent, 36), 1)

	surface.SetDrawColor(accent)
	surface.DrawRect(x, y, S(26), 2)
end

-- Подпись: цветная точка и текст; возвращает занятую ширину.
function UI.Chip(x, y, text, col, font, alpha)
	font = font or "ixHackS"
	alpha = alpha or 1

	surface.SetFont(font)

	local tw, th = surface.GetTextSize(text)

	UI.Disc(x + S(4), y + th / 2, S(3), UI.A(col, math.floor(255 * alpha)), 14)
	draw.SimpleText(text, font, x + S(16), y, UI.A(C.text, math.floor(190 * alpha)), 0, 0)

	return tw + S(16)
end

-- ===================== Полигоны, дуги, линии =====================

-- DrawPoly рисует только по часовой стрелке: при необходимости разворачиваем.
function UI.Poly(pts)
	local area = 0

	for i = 1, #pts do
		local a, b = pts[i], pts[i % #pts + 1]

		area = area + (a.x * b.y - b.x * a.y)
	end

	if (area < 0) then
		local rev = {}

		for i = #pts, 1, -1 do rev[#rev + 1] = pts[i] end

		pts = rev
	end

	surface.DrawPoly(pts)
end

function UI.Diamond(x, y, r, col)
	draw.NoTexture()
	surface.SetDrawColor(col)
	UI.Poly({{x = x, y = y - r}, {x = x + r, y = y}, {x = x, y = y + r}, {x = x - r, y = y}})
end

function UI.Disc(cx, cy, r, col, seg)
	seg = seg or 32

	local pts = {}

	for i = 0, seg - 1 do
		local a = math.rad(i / seg * 360)

		pts[#pts + 1] = {x = cx + math.cos(a) * r, y = cy + math.sin(a) * r}
	end

	draw.NoTexture()
	surface.SetDrawColor(col)
	UI.Poly(pts)
end

-- Дуга толщиной thick от угла from до to (градусы; 0 - вправо, дальше по часовой стрелке).
function UI.Arc(cx, cy, r, thick, from, to, col, perSeg)
	local ro, ri = r + thick / 2, math.max(0, r - thick / 2)
	local span = to - from
	local seg = math.max(2, math.ceil(math.abs(span) / (perSeg or 6)))

	draw.NoTexture()
	surface.SetDrawColor(col)

	for i = 0, seg - 1 do
		local a1 = math.rad(from + span * i / seg)
		local a2 = math.rad(from + span * (i + 1) / seg)
		local c1, s1, c2, s2 = math.cos(a1), math.sin(a1), math.cos(a2), math.sin(a2)

		UI.Poly({
			{x = cx + c1 * ro, y = cy + s1 * ro},
			{x = cx + c2 * ro, y = cy + s2 * ro},
			{x = cx + c2 * ri, y = cy + s2 * ri},
			{x = cx + c1 * ri, y = cy + s1 * ri}
		})
	end
end

function UI.Ring(cx, cy, r, col, thick, seg)
	UI.Arc(cx, cy, r, thick or 1, 0, 360, col, 360 / (seg or 48))
end

function UI.Line(x1, y1, x2, y2, col, thick)
	thick = thick or 1

	if (thick <= 1) then
		surface.SetDrawColor(col)
		surface.DrawLine(x1, y1, x2, y2)

		return
	end

	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)

	if (len < 0.01) then return end

	local nx, ny = -dy / len * thick / 2, dx / len * thick / 2

	draw.NoTexture()
	surface.SetDrawColor(col)
	UI.Poly({
		{x = x1 + nx, y = y1 + ny}, {x = x2 + nx, y = y2 + ny},
		{x = x2 - nx, y = y2 - ny}, {x = x1 - nx, y = y1 - ny}
	})
end

-- Линия, «прорисованная» на долю k (0..1) от начала.
function UI.LinePart(x1, y1, x2, y2, col, thick, k)
	k = math.Clamp(k, 0, 1)

	if (k <= 0) then return end

	UI.Line(x1, y1, x1 + (x2 - x1) * k, y1 + (y2 - y1) * k, col, thick)
end

-- Светящаяся линия: слабый ореол + яркая сердцевина.
function UI.GlowLine(x1, y1, x2, y2, col, thick)
	thick = thick or 2

	UI.Line(x1, y1, x2, y2, UI.A(col, 18), thick * 4.4)
	UI.Line(x1, y1, x2, y2, UI.A(col, 50), thick * 2.2)
	UI.Line(x1, y1, x2, y2, col, thick)
end

-- ===================== Элементы =====================

-- Тонкая шкала. segs оставлен для совместимости и не рисуется.
function UI.Bar(x, y, w, h, frac, col, segs)
	frac = math.Clamp(frac, 0, 1)

	UI.Rect(x, y, w, h, Color(255, 255, 255, 14))

	local fw = math.floor(w * frac)

	if (fw > 0) then
		UI.Rect(x, y, fw, h, UI.A(col, 230))
		UI.Rect(math.max(x, x + fw - S(2)), y, math.min(fw, S(2)), h, Color(255, 255, 255, 120))
	end
end

-- Ряд кружков-индикаторов (этапы, попытки). cur - индекс «текущего» (пульсирует).
function UI.Pips(x, y, count, filled, size, gap, col, cur)
	for i = 1, count do
		local cx = x + (i - 1) * (size * 2 + gap) + size
		local on = i <= filled
		local r = size * 0.72

		if (on) then
			local k = (i == cur) and (0.65 + 0.35 * math.sin(SysTime() * 6)) or 1

			if (i == cur) then
				UI.Disc(cx, y, r + S(3) + k * S(2), UI.A(col, 26 * k), 20)
			end

			UI.Disc(cx, y, r, UI.Mul(col, k), 20)
		else
			UI.Ring(cx, y, r, UI.A(C.dim, 150), 1, 24)
		end
	end
end

-- Столбики «шестнадцатеричного потока» для атмосферы (в новом стиле не используется, оставлено для совместимости).
function UI.HexStream(x, y, rows, col, font)
	font = font or "ixHackXS"

	local t = math.floor(SysTime() * 5)

	for i = 0, rows - 1 do
		local n = i + t
		local line = string.format("%04X  %02X %02X %02X %02X",
			math.floor(UI.Rand(n, 1) * 65535), math.floor(UI.Rand(n, 2) * 255),
			math.floor(UI.Rand(n, 3) * 255), math.floor(UI.Rand(n, 4) * 255), math.floor(UI.Rand(n, 5) * 255))

		draw.SimpleText(line, font, x, y + i * S(14), UI.A(col, 70 - i * 3), 0, 0)
	end
end

-- Медленно плывущие вверх точки: тихая «жизнь» на фоне.
function UI.Particles(w, h, count)
	local now = SysTime()

	for i = 1, count or 36 do
		local speed = S(7) + UI.Rand(i, 2) * S(18)
		local x = UI.Rand(i, 1) * w + math.sin(now * 0.3 + i) * S(10)
		local y = h - ((now * speed + UI.Rand(i, 3) * h) % h)
		local edge = math.min(1, y / (h * 0.25), (h - y) / (h * 0.15))
		local a = (10 + UI.Rand(i, 4) * 34) * math.max(0, edge)
		local size = UI.Rand(i, 5) > 0.82 and 2 or 1

		surface.SetDrawColor(C.accent.r, C.accent.g, C.accent.b, a)
		surface.DrawRect(x, y, size, size)
	end
end

-- ===================== Окно =====================

-- Фон окна: сильное размытие, тёмная подложка, едва заметное сияние сверху и снизу, частицы, тонкая рамка.
function UI.Window(panel, w, h)
	UI.Blur(panel, 5, 5)

	surface.SetDrawColor(2, 6, 9, 238)
	surface.DrawRect(0, 0, w, h)

	-- Свечение только у самых краёв окна, подальше от центра экрана.
	UI.Fade(0, 0, w, h * 0.07, "down", C.cyan, 5, 0)
	UI.Fade(0, h * 0.93, w, h * 0.07, "up", C.cyan, 9, 0)

	UI.Particles(w, h, 36)

	UI.Frame(0, 0, w, h, UI.A(C.line, 70), 1)
end

-- Поверх всего: мягкая виньетка по краям.
function UI.Overlay(w, h)
	local e = S(170)

	UI.Fade(0, 0, w, e, "down", BLACK, 80, 0)
	UI.Fade(0, h - e, w, e, "up", BLACK, 80, 0)
	UI.Fade(0, 0, S(120), h, "right", BLACK, 55, 0)
	UI.Fade(w - S(120), 0, S(120), h, "left", BLACK, 55, 0)
end

-- ===================== Кнопка =====================

-- Минималистичная кнопка: тонкая рамка, при наведении подсвечивается и «выезжает» линия снизу.
function HACK.MakeButton(parent, label, fn)
	local b = vgui.Create("DButton", parent)

	b:SetText("")
	b.label = label
	b.hover = 0

	b.DoClick = function(self)
		surface.PlaySound("buttons/button14.wav")
		self.pressAt = SysTime()
		fn(self)
	end

	b.OnCursorEntered = function(self)
		if (not self:GetDisabled()) then
			surface.PlaySound("buttons/button15.wav")
		end
	end

	b.Paint = function(self, w, h)
		local disabled = self:GetDisabled()
		local want = (self:IsHovered() and not disabled) and 1 or 0

		self.hover = Lerp(math.min(1, FrameTime() * 12), self.hover, want)

		local k = self.hover
		local press = self.pressAt and math.max(0, 1 - (SysTime() - self.pressAt) / 0.25) or 0

		if (k > 0.01 or press > 0) then
			UI.Rect(0, 0, w, h, UI.A(C.accent, 14 * k + 40 * press))
		end

		UI.Frame(0, 0, w, h, UI.A(k > 0.5 and C.accent or C.line, 60 + 150 * k), 1)

		if (k > 0.01) then
			local lw = w * k

			UI.Rect((w - lw) / 2, h - 2, lw, 2, C.accent)
		end

		local col = disabled and C.faint or UI.Mix(C.dim, C.text, k)

		UI.Track(self.label, "ixHackS", w / 2, h / 2, col, S(2) + k * S(1), 1, 1)
	end

	return b
end
