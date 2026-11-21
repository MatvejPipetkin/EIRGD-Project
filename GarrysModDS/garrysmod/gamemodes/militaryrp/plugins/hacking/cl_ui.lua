-- Общий набор «кисточек» интерфейса взлома: свечение, размытие фона, стеклянные панели,
-- ЭЛТ-эффекты, дуги и кольца, кнопки. Используется терминалом, играми, досье и HUD.

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

-- Детерминированный «случайный» 0..1 (для мерцания и шума без math.random).
function UI.Rand(a, b)
	local v = math.sin(a * 12.9898 + (b or 0) * 78.233) * 43758.5453

	return v - math.floor(v)
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

local GLOW = {{-2, 0}, {2, 0}, {0, -2}, {0, 2}, {-1, -1}, {1, 1}, {-1, 1}, {1, -1}}

-- Текст с мягким свечением.
function UI.Glow(str, font, x, y, col, ax, ay, power)
	local g = Color(col.r, col.g, col.b, math.floor(30 * (power or 1)))

	for _, o in ipairs(GLOW) do
		draw.SimpleText(str, font, x + o[1], y + o[2], g, ax or 0, ay or 0)
	end

	draw.SimpleText(str, font, x, y, col, ax or 0, ay or 0)
end

-- Градиентная заливка полосками. dir - куда идёт затухание от начальной кромки:
-- "down" (сверху вниз), "up", "right" (слева направо), "left". a0 - прозрачность у кромки, a1 - на другом конце.
function UI.Fade(x, y, w, h, dir, col, a0, a1, steps)
	steps = steps or 12

	local vertical = (dir == "down" or dir == "up")
	local len = vertical and h or w
	local step = len / steps

	for i = 0, steps - 1 do
		local p0, p1 = math.floor(i * step), math.floor((i + 1) * step)
		local seg = math.max(1, p1 - p0)
		local a = a0 + (a1 - a0) * ((i + 0.5) / steps)

		surface.SetDrawColor(col.r, col.g, col.b, a)

		if (dir == "down") then
			surface.DrawRect(x, y + p0, w, seg)
		elseif (dir == "up") then
			surface.DrawRect(x, y + h - p0 - seg, w, seg)
		elseif (dir == "right") then
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

-- Уголки-скобки по периметру.
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

-- Стеклянная панель: тёмная подложка, свечение сверху, рамка, уголки.
function UI.Box(x, y, w, h, accent, alpha)
	accent = accent or C.accent

	surface.SetDrawColor(5, 12, 17, alpha or 205)
	surface.DrawRect(x, y, w, h)
	UI.Fade(x, y, w, math.min(h, S(46)), "down", accent, 26, 0, 8)
	UI.Frame(x, y, w, h, UI.A(accent, 90), 1)
	UI.Brackets(x, y, w, h, accent, S(7), 1)
end

-- Подпись-«таблетка»; возвращает её ширину.
function UI.Chip(x, y, text, col, font)
	font = font or "ixHackS"

	surface.SetFont(font)

	local tw, th = surface.GetTextSize(text)
	local w, h = tw + S(18), th + S(6)

	UI.Rect(x, y, w, h, Color(col.r * 0.14, col.g * 0.14, col.b * 0.14, 225))
	UI.Frame(x, y, w, h, UI.A(col, 150), 1)
	UI.Rect(x, y, S(3), h, col)
	draw.SimpleText(text, font, x + S(11), y + h / 2, col, 0, 1)

	return w
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

-- Светящаяся линия: широкий слабый ореол + яркая сердцевина.
function UI.GlowLine(x1, y1, x2, y2, col, thick)
	thick = thick or 2

	UI.Line(x1, y1, x2, y2, UI.A(col, 26), thick * 5)
	UI.Line(x1, y1, x2, y2, UI.A(col, 70), thick * 2.6)
	UI.Line(x1, y1, x2, y2, col, thick)
end

-- ===================== Элементы =====================

-- Шкала с сегментами и бликом.
function UI.Bar(x, y, w, h, frac, col, segs)
	frac = math.Clamp(frac, 0, 1)

	UI.Rect(x, y, w, h, Color(0, 0, 0, 170))

	local fw = math.floor(w * frac)

	if (fw > 0) then
		UI.Rect(x, y, fw, h, col)
		UI.Fade(x, y, fw, h, "down", Color(255, 255, 255), 70, 0, 4)
		UI.Fade(x, y - S(5), fw, S(5), "up", col, 38, 0, 5)
	end

	if (segs) then
		surface.SetDrawColor(0, 0, 0, 170)

		for i = 1, segs - 1 do
			surface.DrawRect(x + math.floor(w * i / segs), y, 1, h)
		end
	end

	UI.Frame(x, y, w, h, UI.A(C.line, 220), 1)
end

-- Ряд ромбов-индикаторов (этапы, попытки). cur - индекс «текущего» (пульсирует).
function UI.Pips(x, y, count, filled, size, gap, col, cur)
	for i = 1, count do
		local cx = x + (i - 1) * (size * 2 + gap) + size
		local on = i <= filled

		if (on) then
			local k = (i == cur) and (0.65 + 0.35 * math.sin(SysTime() * 6)) or 1

			UI.Diamond(cx, y, size + 3, UI.A(col, 40 * k))
			UI.Diamond(cx, y, size, UI.Mul(col, k))
		else
			UI.Diamond(cx, y, size, C.faint)
			UI.Diamond(cx, y, size - 2, C.bg)
		end
	end
end

-- Столбики «шестнадцатеричного потока» для атмосферы.
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

-- ===================== Окно и ЭЛТ-эффекты =====================

-- Фон окна: размытие, затемнение, свечение, сетка, рамка.
function UI.Window(panel, w, h)
	UI.Blur(panel, 4, 4)

	surface.SetDrawColor(3, 8, 12, 226)
	surface.DrawRect(0, 0, w, h)

	UI.Fade(0, 0, w, S(280), "down", C.accent, 20, 0, 14)
	UI.Fade(0, h - S(180), w, S(180), "up", C.cyan, 12, 0, 10)

	surface.SetDrawColor(C.accent.r, C.accent.g, C.accent.b, 9)

	local g = S(36)

	for gx = g, w, g do surface.DrawRect(gx, 0, 1, h) end
	for gy = g, h, g do surface.DrawRect(0, gy, w, 1) end

	UI.Frame(0, 0, w, h, UI.A(C.line, 230), 1)
	UI.Brackets(0, 0, w, h, C.accent, S(22), 2)
end

-- Поверх всего: строки развёртки, бегущая полоса, виньетка, редкие помехи.
function UI.Overlay(w, h)
	surface.SetDrawColor(0, 0, 0, 52)

	for y = 0, h, S(3) do
		surface.DrawRect(0, y, w, 1)
	end

	local band = S(110)
	local by = ((SysTime() * S(55)) % (h + band)) - band

	UI.Fade(0, by, w, band, "down", C.accent, 0, 14, 10)

	local e = S(90)

	UI.Fade(0, 0, w, e, "down", BLACK, 120, 0, 9)
	UI.Fade(0, h - e, w, e, "up", BLACK, 120, 0, 9)
	UI.Fade(0, 0, e, h, "right", BLACK, 110, 0, 9)
	UI.Fade(w - e, 0, e, h, "left", BLACK, 110, 0, 9)

	local slot = math.floor(SysTime() * 3)

	if (UI.Rand(slot, 1) < 0.16) then
		local gy = math.floor(UI.Rand(slot, 2) * h)
		local gh = S(2) + math.floor(UI.Rand(slot, 3) * S(9))

		surface.SetDrawColor(C.accent.r, C.accent.g, C.accent.b, 20)
		surface.DrawRect(0, gy, w, gh)
		surface.SetDrawColor(255, 255, 255, 9)
		surface.DrawRect(0, gy + gh, w, 1)
	end
end

-- ===================== Кнопка =====================

function HACK.MakeButton(parent, label, fn)
	local b = vgui.Create("DButton", parent)

	b:SetText("")
	b.label = label
	b.hover = 0

	b.DoClick = function(self)
		surface.PlaySound("buttons/button14.wav")
		fn(self)
	end

	b.Paint = function(self, w, h)
		local disabled = self:GetDisabled()
		local want = (self:IsHovered() and not disabled) and 1 or 0

		self.hover = Lerp(math.min(1, FrameTime() * 14), self.hover, want)

		local k = self.hover

		UI.Rect(0, 0, w, h, Color(7, 16, 22, 235))

		if (k > 0.02) then
			UI.Fade(0, 0, w, h, "right", C.accent, 58 * k, 6 * k, 10)
		end

		UI.Frame(0, 0, w, h, UI.A(k > 0.5 and C.accent or C.line, 230), 1)
		UI.Rect(0, 0, S(3), h, disabled and C.faint or C.accent)

		if (k > 0.5) then
			UI.Brackets(0, 0, w, h, C.accent, S(6), 1)
		end

		draw.SimpleText(self.label, "ixHackS", w / 2, h / 2, disabled and C.dim or C.text, 1, 1)
	end

	return b
end
