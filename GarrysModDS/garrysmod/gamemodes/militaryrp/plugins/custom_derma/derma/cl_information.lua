local glowMat = Material("sprites/light_glow02_add")

local CFG = {
	accentColor = Color(90, 160, 235),
	fallbackColor = Color(90, 160, 235),
	sounds = true,
	soundVolume = 0.55,
	scanlines = true,
	revealStep = 0.05,
	windowWidth = 0.5,
	windowHeight = 0.82,

	soundSet = {
		hover = {"buttons/blip1.wav", 0.3, 115},
		click = {"buttons/button15.wav", 0.5, 100},
		tick = {"buttons/blip2.wav", 0.16, 130},
		open = {"buttons/combine_button1.wav", 0.4, 105},
		reveal = {"buttons/combine_button3.wav", 0.25, 110}
	}
}

local COL_GOOD = Color(110, 225, 150)
local COL_BAD = Color(235, 85, 85)
local CHAR_PATTERN = "[\1-\127\194-\253][\128-\191]*"

local function CreateInfoFonts()
	local h = ScrH()

	surface.CreateFont("ixInfoName", {font = "Roboto", size = math.floor(h * 0.04), weight = 700, extended = true, antialias = true})
	surface.CreateFont("ixInfoValue", {font = "Roboto", size = math.floor(h * 0.0255), weight = 600, extended = true, antialias = true})
	surface.CreateFont("ixInfoMid", {font = "Roboto", size = math.floor(h * 0.0215), weight = 600, extended = true, antialias = true})
	surface.CreateFont("ixInfoText", {font = "Roboto", size = math.floor(h * 0.0185), weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixInfoSmall", {font = "Roboto", size = math.floor(h * 0.0155), weight = 600, extended = true, antialias = true})
	surface.CreateFont("ixInfoTiny", {font = "Roboto", size = math.floor(h * 0.0125), weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixInfoMono", {font = "Courier New", size = math.floor(h * 0.0135), weight = 500, extended = true, antialias = true})
end

CreateInfoFonts()
hook.Add("OnScreenSizeChanged", "ixCharInfoFonts", CreateInfoFonts)

local function EaseOutCubic(x)
	return 1 - (1 - x) ^ 3
end

local function GetAccent()
	return CFG.accentColor or ix.config.Get("color") or CFG.fallbackColor
end

local function Upper(text)
	return (string.utf8upper or string.upper)(text)
end

local function GetPad()
	return math.floor(ScrW() * 0.009)
end

local function ReadableColor(c)
	local accent = GetAccent()

	if (!c) then
		return accent.r, accent.g, accent.b
	end

	local lum = c.r * 0.3 + c.g * 0.59 + c.b * 0.11

	if (lum < 45) then
		return accent.r, accent.g, accent.b
	end

	return c.r, c.g, c.b
end

local lastPlayed = {}

local function PlayUI(key, pitchMul, volMul)
	if (!CFG.sounds) then
		return
	end

	local def = CFG.soundSet and CFG.soundSet[key]

	if (!def) then
		return
	end

	local now = RealTime()

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

local function SplitChars(text)
	local chars = {}

	for ch in string.gmatch(text or "", CHAR_PATTERN) do
		chars[#chars + 1] = ch
	end

	return chars
end

local function TypeText(text, p)
	if (p >= 1) then
		return text
	end

	local chars = SplitChars(text)
	local n = math.floor(#chars * math.Clamp(p, 0, 1))

	if (n >= #chars) then
		return text
	end

	return table.concat(chars, "", 1, n)
end

local function Typed(pnl, text, dur)
	local st = pnl.typeStart

	if (!st) then
		return text
	end

	return TypeText(text, (RealTime() - st) / (dur or 0.5))
end

local function FitText(text, fonts, maxW)
	for _, f in ipairs(fonts) do
		surface.SetFont(f)

		if (surface.GetTextSize(text) <= maxW) then
			return text, f
		end
	end

	local f = fonts[#fonts]

	surface.SetFont(f)

	local chars = SplitChars(text)
	local count = #chars

	while (count > 1) do
		count = count - 1

		local candidate = table.concat(chars, "", 1, count) .. "…"

		if (surface.GetTextSize(candidate) <= maxW) then
			return candidate, f
		end
	end

	return chars[1] and (chars[1] .. "…") or text, f
end

local function BreakWord(word, maxW)
	local parts, cur = {}, ""

	for _, ch in ipairs(SplitChars(word)) do
		if (cur != "" and surface.GetTextSize(cur .. ch) > maxW) then
			parts[#parts + 1] = cur
			cur = ch
		else
			cur = cur .. ch
		end
	end

	if (cur != "") then
		parts[#parts + 1] = cur
	end

	return parts
end

local function WrapText(text, font, maxW)
	surface.SetFont(font)

	local lines = {}

	text = string.Replace(text or "", "\r", "")

	for paragraph in string.gmatch(text .. "\n", "(.-)\n") do
		local line = ""

		for word in string.gmatch(paragraph, "%S+") do
			if (surface.GetTextSize(word) > maxW) then
				if (line != "") then
					lines[#lines + 1] = line
					line = ""
				end

				local parts = BreakWord(word, maxW)

				if (#parts > 0) then
					for i = 1, #parts - 1 do
						lines[#lines + 1] = parts[i]
					end

					line = parts[#parts]
				else
					line = word
				end
			else
				local test = line == "" and word or (line .. " " .. word)

				if (line != "" and surface.GetTextSize(test) > maxW) then
					lines[#lines + 1] = line
					line = word
				else
					line = test
				end
			end
		end

		lines[#lines + 1] = line
	end

	return lines
end

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

local function RingBand(cx, cy, rIn, rOut, a0, step, seg)
	if (rOut <= 0) then
		return
	end

	rIn = math.max(rIn, 0)

	local c0, s0 = math.cos(a0), math.sin(a0)

	for i = 1, seg do
		local a = a0 + step * i
		local c1, s1 = math.cos(a), math.sin(a)

		SetQuad(
			cx + c0 * rOut, cy + s0 * rOut,
			cx + c1 * rOut, cy + s1 * rOut,
			cx + c1 * rIn, cy + s1 * rIn,
			cx + c0 * rIn, cy + s0 * rIn
		)

		c0, s0 = c1, s1
	end
end

local function SmoothArc(cx, cy, r, deg0, deg1, thick, seg, cr, cg, cb, ca)
	if (ca <= 0 or deg1 <= deg0) then
		return
	end

	local a0 = math.rad(deg0)
	local step = math.rad(deg1 - deg0) / seg
	local half = thick * 0.5

	draw.NoTexture()
	surface.SetDrawColor(cr, cg, cb, ca)
	RingBand(cx, cy, r - half, r + half, a0, step, seg)

	for _, f in ipairs(FEATHER) do
		surface.SetDrawColor(cr, cg, cb, ca * f[3])
		RingBand(cx, cy, r + half + f[1], r + half + f[2], a0, step, seg)
		RingBand(cx, cy, r - half - f[2], r - half - f[1], a0, step, seg)
	end
end

local function DrawBrackets(x, y, w, h, len, r, g, b, a)
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

local function DrawFade(x, y, w, h, r, g, b, a, fromLeft)
	local n = 24
	local sw = math.ceil(w / n)

	draw.NoTexture()

	for i = 0, n - 1 do
		local f = fromLeft and (1 - i / n) or (i / n)

		surface.SetDrawColor(r, g, b, a * f * f)
		surface.DrawRect(x + i * sw, y, sw + 1, h)
	end
end

local PANEL = {}

function PANEL:Init()
	self:SetTall(math.floor(ScrH() * 0.028))

	self.text = ""
	self.rightText = ""
end

function PANEL:SetText(text)
	self.text = text or ""
end

function PANEL:SetRightText(text)
	self.rightText = text or ""
end

function PANEL:SizeToContents()
end

function PANEL:Paint(w, h)
	local accent = GetAccent()
	local ar, ag, ab = accent.r, accent.g, accent.b
	local now = RealTime()
	local mid = math.floor(h * 0.5)

	draw.NoTexture()
	surface.SetDrawColor(255, 255, 255, 140 + 100 * (0.5 + 0.5 * math.sin(now * 3)))
	surface.DrawRect(0, mid - 3, 6, 6)

	surface.SetFont("ixInfoSmall")

	local fullW = surface.GetTextSize(self.text)

	draw.SimpleText(Typed(self, self.text, 0.5), "ixInfoSmall", 16, mid, Color(255, 255, 255, 215), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local rw = 0

	if (self.rightText != "") then
		surface.SetFont("ixInfoMono")
		rw = surface.GetTextSize(self.rightText) + 14

		draw.SimpleText(self.rightText, "ixInfoMono", w, mid, Color(ar, ag, ab, 210), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	local x0 = 16 + fullW + 14
	local x1 = w - rw

	if (x1 > x0) then
		draw.NoTexture()
		surface.SetDrawColor(ar, ag, ab, 70)
		surface.DrawRect(x0, mid, x1 - x0, 1)
		surface.DrawRect(x0, mid - 3, 1, 7)
		surface.DrawRect(x1 - 1, mid - 3, 1, 7)
	end
end

vgui.Register("ixInfoSection", PANEL, "Panel")

PANEL = {}

function PANEL:Init()
	self:SetTall(math.floor(ScrH() * 0.034))

	self.text = ""
	self.nextTime = 0
	self:Refresh()
end

function PANEL:Refresh()
	local format = ix.option.Get("24hourTime", false) and "%A, %B %d, %Y. %H:%M" or "%A, %B %d, %Y. %I:%M %p"

	self.text = ix.date.GetFormatted(format)
end

function PANEL:SizeToContents()
end

function PANEL:Think()
	if (self.nextTime < CurTime()) then
		self:Refresh()
		self.nextTime = CurTime() + 0.5
	end
end

function PANEL:Paint(w, h)
	local accent = GetAccent()
	local ar, ag, ab = accent.r, accent.g, accent.b
	local now = RealTime()
	local mid = math.floor(h * 0.5)

	draw.NoTexture()
	surface.SetDrawColor(0, 0, 0, 140)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(ar, ag, ab, 16)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(ar, ag, ab, 70)
	surface.DrawOutlinedRect(0, 0, w, h, 1)

	DrawBrackets(0, 0, w, h, 8, 255, 255, 255, 150)

	surface.SetDrawColor(255, 255, 255, 120 + 110 * (0.5 + 0.5 * math.sin(now * 3.2)))
	surface.DrawRect(14, mid - 3, 7, 7)

	draw.SimpleText("СИСТЕМНОЕ ВРЕМЯ", "ixInfoTiny", 30, mid, Color(ar, ag, ab, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(self.text, "ixInfoMid", math.floor(w * 0.5), mid, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText("ЛОКАЛЬНОЕ  " .. os.date("%H:%M:%S"), "ixInfoMono", w - 16, mid, Color(255, 255, 255, 170), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

vgui.Register("ixInfoClock", PANEL, "Panel")

PANEL = {}

function PANEL:Init()
	self:SetTall(math.floor(ScrH() * 0.125))

	self.text = ""
	self.idText = ""
	self.subText = ""
	self.initial = ""
	self.backgroundColor = Color(0, 0, 0, 150)
end

function PANEL:SetText(text)
	self.text = text or ""
end

function PANEL:SetData(idText, subText, initial)
	self.idText = idText or ""
	self.subText = subText or ""
	self.initial = initial or ""
end

function PANEL:SizeToContents()
end

function PANEL:Paint(w, h)
	local accent = GetAccent()
	local ar, ag, ab = accent.r, accent.g, accent.b
	local fr, fg, fb = ReadableColor(self.backgroundColor)
	local now = RealTime()
	local R = math.floor(h * 0.33)
	local bx, by = w - R - 44, math.floor(h * 0.5)

	draw.NoTexture()
	surface.SetDrawColor(7, 10, 15, 205)
	surface.DrawRect(0, 0, w, h)

	DrawFade(0, 0, math.floor(w * 0.7), h, fr, fg, fb, 95, true)

	surface.SetDrawColor(ar, ag, ab, 90)
	surface.DrawRect(0, 0, w, 1)
	surface.DrawRect(0, h - 1, w, 1)

	surface.SetDrawColor(fr, fg, fb, 255)
	surface.DrawRect(0, 0, 6, h)
	surface.SetDrawColor(255, 255, 255, 90)
	surface.DrawRect(6, 0, 1, h)

	DrawBrackets(0, 0, w, h, 14, ar, ag, ab, 170)

	local tx = 30
	local maxW = bx - R - 40 - tx

	draw.SimpleText(Typed(self, self.idText, 0.6), "ixInfoMono", tx, math.floor(h * 0.2), Color(ar, ag, ab, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local nameText, nameFont = FitText(self.text, {"ixInfoName", "ixInfoValue", "ixInfoMid"}, maxW)
	local typedName = Typed(self, nameText, 0.7)

	draw.SimpleText(typedName, nameFont, tx + 2, math.floor(h * 0.5) + 2, Color(0, 0, 0, 160), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(typedName, nameFont, tx, math.floor(h * 0.5), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local subText, subFont = FitText(self.subText, {"ixInfoSmall", "ixInfoTiny"}, maxW)

	draw.SimpleText(Typed(self, subText, 0.8), subFont, tx, math.floor(h * 0.8), Color(255, 255, 255, 190), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	surface.SetMaterial(glowMat)
	surface.SetDrawColor(fr, fg, fb, 30)
	surface.DrawTexturedRect(bx - R * 1.8, by - R * 1.8, R * 3.6, R * 3.6)
	draw.NoTexture()

	SmoothArc(bx, by, R, 0, 360, 1.5, 48, ar, ag, ab, 130)

	for i = 0, 3 do
		local s = now * 30 + i * 90

		SmoothArc(bx, by, R + 8, s, s + 40, 2.5, 10, 255, 255, 255, 200)
	end

	for i = 0, 5 do
		local s = -now * 45 + i * 60

		SmoothArc(bx, by, R - 9, s, s + 22, 1.5, 6, ar, ag, ab, 150)
	end

	draw.SimpleText(self.initial, "ixInfoName", bx, by, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

vgui.Register("ixInfoPlate", PANEL, "Panel")

PANEL = {}

function PANEL:Init()
	self.rawText = ""
	self.lines = {}
	self.hoverFrac = 0
	self.maxW = 0
	self.wrapW = -1
	self.headerH = math.floor(ScrH() * 0.03)
	self.pad = 16

	self:SetMouseInputEnabled(true)
	self:SetCursor("hand")
	self:SetTall(self.headerH + 40)
end

function PANEL:SetText(text)
	self.rawText = text or ""
end

function PANEL:SizeToContents()
	local w = self:GetWide()

	if (w <= 0) then
		w = self.maxW or 0
	end

	if (w <= 0) then
		return
	end

	self.wrapW = w

	local text = self.rawText

	self.bEmpty = string.Trim(text) == ""

	if (self.bEmpty) then
		text = "ОПИСАНИЕ НЕ ЗАДАНО. НАЖМИТЕ, ЧТОБЫ ДОБАВИТЬ."
	end

	self.lines = WrapText(text, "ixInfoText", w - self.pad * 2 - 8)

	surface.SetFont("ixInfoText")

	local _, th = surface.GetTextSize("A")

	self.lineH = th + 3
	self:SetTall(self.headerH + 10 + #self.lines * self.lineH + self.pad)
end

function PANEL:PerformLayout(w, h)
	if (w > 0 and w != self.wrapW) then
		self.maxW = w
		self:SizeToContents()
	end
end

function PANEL:OnCursorEntered()
	PlayUI("hover", 1.05, 0.7)
end

function PANEL:OnMousePressed(code)
	if (code == MOUSE_LEFT) then
		PlayUI("click")
		ix.command.Send("CharDesc")

		if (IsValid(ix.gui.menu)) then
			ix.gui.menu:Remove()
		end
	end
end

function PANEL:Paint(w, h)
	local accent = GetAccent()
	local ar, ag, ab = accent.r, accent.g, accent.b
	local pad = self.pad

	self.hoverFrac = Lerp(math.min(RealFrameTime() * 12, 1), self.hoverFrac, self:IsHovered() and 1 or 0)

	local hov = self.hoverFrac

	draw.NoTexture()
	surface.SetDrawColor(0, 0, 0, 150)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(ar, ag, ab, 14 + 26 * hov)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(ar, ag, ab, 70 + 100 * hov)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
	surface.SetDrawColor(255, 255, 255, 70 + 185 * hov)
	surface.DrawRect(0, 0, 4, h)

	if (hov > 0.02) then
		DrawBrackets(0, 0, w, h, math.floor(10 * hov), 255, 255, 255, 200 * hov)
	end

	local hy = math.floor(self.headerH * 0.5)

	draw.SimpleText("ВНЕШНИЕ ДАННЫЕ", "ixInfoTiny", pad + 4, hy, Color(ar, ag, ab, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText("[ ЛКМ — ИЗМЕНИТЬ ОПИСАНИЕ ]", "ixInfoTiny", w - pad, hy, Color(255, 255, 255, 70 + 170 * hov), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	draw.NoTexture()
	surface.SetDrawColor(ar, ag, ab, 55)
	surface.DrawRect(pad + 4, self.headerH, w - (pad + 4) * 2, 1)

	local col = self.bEmpty and Color(255, 255, 255, 90) or Color(255, 255, 255, 225)
	local lh = self.lineH or 20

	for i, line in ipairs(self.lines) do
		if (line != "") then
			draw.SimpleText(line, "ixInfoText", pad + 4, self.headerH + 10 + (i - 1) * lh, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
	end
end

vgui.Register("ixInfoDescription", PANEL, "Panel")

PANEL = {}

function PANEL:Init()
	self:SetTall(math.floor(ScrH() * 0.07))
	self:SetMouseInputEnabled(true)

	self.label = ""
	self.text = ""
	self.stripe = nil
	self.hoverFrac = 0
end

function PANEL:SetLabelText(text)
	self.label = text or ""
end

function PANEL:SetText(text)
	self.text = tostring(text or "")
end

function PANEL:SetStripe(color)
	self.stripe = color
end

function PANEL:SetList()
end

function PANEL:SizeToContents()
end

function PANEL:OnCursorEntered()
	PlayUI("hover", 1.15, 0.45)
end

function PANEL:Paint(w, h)
	local accent = GetAccent()
	local ar, ag, ab = accent.r, accent.g, accent.b
	local sr, sg, sb = ReadableColor(self.stripe)

	self.hoverFrac = Lerp(math.min(RealFrameTime() * 12, 1), self.hoverFrac, self:IsHovered() and 1 or 0)

	local hov = self.hoverFrac

	draw.NoTexture()
	surface.SetDrawColor(0, 0, 0, 150)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(ar, ag, ab, 12 + 22 * hov)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(ar, ag, ab, 60 + 100 * hov)
	surface.DrawOutlinedRect(0, 0, w, h, 1)

	surface.SetDrawColor(sr, sg, sb, 255)
	surface.DrawRect(0, 0, 4 + math.floor(3 * hov), h)

	local bl = 8 + math.floor(4 * hov)

	surface.SetDrawColor(255, 255, 255, 110 + 120 * hov)
	surface.DrawRect(w - bl - 1, 0, bl, 2)
	surface.DrawRect(w - 2, 0, 2, bl)
	surface.DrawRect(w - bl - 1, h - 2, bl, 2)
	surface.DrawRect(w - 2, h - bl, 2, bl)

	draw.SimpleText(self.label, "ixInfoTiny", 18, math.floor(h * 0.28), Color(ar, ag, ab, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local fitText, font = FitText(self.text, {"ixInfoValue", "ixInfoMid", "ixInfoSmall"}, w - 18 - 22)

	draw.SimpleText(Typed(self, fitText, 0.5), font, 18, math.floor(h * 0.68), Color(255, 255, 255, 235 + 20 * hov), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

vgui.Register("ixInfoTile", PANEL, "Panel")

PANEL = {}

function PANEL:Init()
	self.cols = 3
	self.gap = 8
	self.rowH = math.floor(ScrH() * 0.07)
end

function PANEL:GetVisibleTiles()
	local list = {}

	for _, v in ipairs(self:GetChildren()) do
		if (IsValid(v) and v:IsVisible()) then
			list[#list + 1] = v
		end
	end

	return list
end

function PANEL:SizeToContents()
	local rows = math.max(math.ceil(#self:GetVisibleTiles() / self.cols), 1)

	self:SetTall(rows * self.rowH + (rows - 1) * self.gap)
	self:InvalidateLayout(true)
end

function PANEL:PerformLayout(w, h)
	local cw = math.floor((w - self.gap * (self.cols - 1)) / self.cols)

	for i, v in ipairs(self:GetVisibleTiles()) do
		local col = (i - 1) % self.cols
		local row = math.floor((i - 1) / self.cols)

		v:SetPos(col * (cw + self.gap), row * (self.rowH + self.gap))
		v:SetSize(cw, self.rowH)
	end
end

vgui.Register("ixInfoGrid", PANEL, "Panel")

PANEL = {}

function PANEL:Init()
	self:SetTall(math.floor(ScrH() * 0.05))
	self:SetMouseInputEnabled(true)

	self.label = ""
	self.value = 0
	self.boost = 0
	self.max = 100
	self.hoverFrac = 0
	self.animStart = RealTime()
	self.delay = 0
end

function PANEL:SetData(label, value, boost, maximum)
	self.label = label or ""
	self.value = value or 0
	self.boost = boost or 0
	self.max = math.max(maximum or 100, 0.0001)
end

function PANEL:Replay(delay)
	self.animStart = RealTime()
	self.delay = delay or 0
end

function PANEL:SizeToContents()
end

function PANEL:OnCursorEntered()
	PlayUI("hover", 1.2, 0.35)
end

function PANEL:Paint(w, h)
	local accent = GetAccent()
	local ar, ag, ab = accent.r, accent.g, accent.b
	local pad = 14

	self.hoverFrac = Lerp(math.min(RealFrameTime() * 12, 1), self.hoverFrac, self:IsHovered() and 1 or 0)

	local hov = self.hoverFrac
	local t = EaseOutCubic(math.Clamp((RealTime() - self.animStart - self.delay) / 0.9, 0, 1))

	draw.NoTexture()
	surface.SetDrawColor(0, 0, 0, 140)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(ar, ag, ab, 10 + 20 * hov)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(ar, ag, ab, 50 + 100 * hov)
	surface.DrawOutlinedRect(0, 0, w, h, 1)
	surface.SetDrawColor(255, 255, 255, 70 + 185 * hov)
	surface.DrawRect(0, 0, 3 + math.floor(2 * hov), h)

	local bx, bw = pad, w - pad * 2
	local bh = 6
	local by = h - bh - 9

	local value, boost = self.value, self.boost
	local base = value - boost
	local lo, hi = math.min(value, base), math.max(value, base)
	local loF = math.Clamp(lo / self.max, 0, 1) * t
	local hiF = math.Clamp(hi / self.max, 0, 1) * t

	surface.SetDrawColor(ar, ag, ab, 35)
	surface.DrawRect(bx, by, bw, bh)

	surface.SetDrawColor(255, 255, 255, 235)
	surface.DrawRect(bx, by, math.floor(bw * loF), bh)

	if (boost != 0 and hiF > loF) then
		local c = boost > 0 and COL_GOOD or COL_BAD

		surface.SetDrawColor(c.r, c.g, c.b, 235)
		surface.DrawRect(bx + math.floor(bw * loF), by, math.floor(bw * (hiF - loF)), bh)
	end

	surface.SetDrawColor(7, 10, 15, 200)

	for i = 1, 19 do
		surface.DrawRect(bx + math.floor(bw * i / 20), by, 1, bh)
	end

	if (hiF > 0.005) then
		surface.SetMaterial(glowMat)
		surface.SetDrawColor(255, 255, 255, 110 * t)
		surface.DrawTexturedRect(bx + bw * hiF - 14, by + bh * 0.5 - 14, 28, 28)
		draw.NoTexture()
	end

	surface.SetDrawColor(ar, ag, ab, 120)
	surface.DrawOutlinedRect(bx - 1, by - 1, bw + 2, bh + 2, 1)

	local ty = math.floor((by - 3) * 0.5) + 1
	local pct = string.format("%d%%", math.floor(value / self.max * 100 + 0.5))
	local nums = string.format("%.1f / %.1f", value, self.max)

	surface.SetFont("ixInfoSmall")

	local pw = surface.GetTextSize(pct)

	draw.SimpleText(Upper(self.label), "ixInfoSmall", pad, ty, Color(255, 255, 255, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(pct, "ixInfoSmall", w - pad, ty, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	draw.SimpleText(nums, "ixInfoMono", w - pad - pw - 14, ty, Color(ar, ag, ab, 220), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	if (boost != 0) then
		surface.SetFont("ixInfoMono")

		local nw = surface.GetTextSize(nums)
		local c = boost > 0 and COL_GOOD or COL_BAD

		draw.SimpleText(string.format("%s%.1f", boost > 0 and "+" or "", boost), "ixInfoMono", w - pad - pw - 14 - nw - 12, ty, Color(c.r, c.g, c.b, 240), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("ixInfoAttribute", PANEL, "Panel")

local function StyleRow(row, index)
	row.Paint = function(this, w, h)
		local accent = GetAccent()

		draw.NoTexture()
		surface.SetDrawColor(0, 0, 0, 140)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(accent.r, accent.g, accent.b, 10 + (index % 2) * 10)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(255, 255, 255, 90)
		surface.DrawRect(0, 0, 3, h)
		surface.SetDrawColor(accent.r, accent.g, accent.b, 50)
		surface.DrawRect(0, h - 1, w, 1)
	end
end

PANEL = {}

local scrollBase = baseclass.Get("DScrollPanel")

function PANEL:Init()
	local parent = self:GetParent()
	local pad = GetPad()

	self:SetSize(math.floor(ScrW() * CFG.windowWidth), math.floor(ScrH() * CFG.windowHeight))
	self:Recenter()

	self.VBar:SetWide(0)

	self.revealList = {}
	self.rowCounter = 0

	local innerW = self:GetWide() - pad * 2

	local function Reg(pnl)
		self.revealList[#self.revealList + 1] = pnl

		return pnl
	end

	local suppress = {}
	hook.Run("CanCreateCharacterInfo", suppress)

	if (!suppress.time) then
		self.time = Reg(self:Add("ixInfoClock"))
		self.time:Dock(TOP)
		self.time:DockMargin(0, 0, 0, 12)
	end

	if (!suppress.name) then
		self.name = Reg(self:Add("ixInfoPlate"))
		self.name:Dock(TOP)
		self.name:DockMargin(0, 0, 0, 10)
	end

	if (!suppress.description) then
		self.description = Reg(self:Add("ixInfoDescription"))
		self.description.maxW = innerW
		self.description:Dock(TOP)
		self.description:DockMargin(0, 0, 0, 8)
	end

	if (!suppress.characterInfo) then
		self.dataHeader = Reg(self:Add("ixInfoSection"))
		self.dataHeader:SetText("ДАННЫЕ ПЕРСОНАЖА")
		self.dataHeader:Dock(TOP)
		self.dataHeader:DockMargin(0, 12, 0, 8)

		self.dataGrid = self:Add("ixInfoGrid")
		self.dataGrid:Dock(TOP)

		if (!suppress.faction) then
			self.faction = Reg(self.dataGrid:Add("ixInfoTile"))
		end

		if (!suppress.class) then
			self.class = Reg(self.dataGrid:Add("ixInfoTile"))
		end

		if (!suppress.money) then
			self.money = Reg(self.dataGrid:Add("ixInfoTile"))
		end

		if (!suppress.operator) then
			self.operator = Reg(self.dataGrid:Add("ixInfoTile"))
		end

		if (!suppress.ping) then
			self.ping = Reg(self.dataGrid:Add("ixInfoTile"))
		end

		self.dataGrid:SizeToContents()

		self.extraHeader = Reg(self:Add("ixInfoSection"))
		self.extraHeader:SetText("ДОПОЛНИТЕЛЬНО")
		self.extraHeader:Dock(TOP)
		self.extraHeader:DockMargin(0, 12, 0, 8)

		self.characterInfo = Reg(self:Add("Panel"))
		self.characterInfo.list = {}
		self.characterInfo:Dock(TOP)
		self.characterInfo.SizeToContents = function(this)
			local height = 0

			for _, v in ipairs(this:GetChildren()) do
				if (IsValid(v) and v:IsVisible()) then
					local _, top, _, bottom = v:GetDockMargin()
					height = height + v:GetTall() + top + bottom
				end
			end

			this:SetTall(height)
		end

		hook.Run("CreateCharacterInfo", self.characterInfo)
		self:RefreshExtra()
	end

	if (!suppress.attributes) then
		local character = LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()
		local list = ix.attributes and ix.attributes.list

		if (character and list and table.Count(list) > 0) then
			self.attrHeader = Reg(self:Add("ixInfoSection"))
			self.attrHeader:SetText("ХАРАКТЕРИСТИКИ")
			self.attrHeader:Dock(TOP)
			self.attrHeader:DockMargin(0, 12, 0, 8)

			self.attributes = self:Add("Panel")
			self.attributes:Dock(TOP)
			self.attributes.bars = {}
			self.attributes.SizeToContents = function(this)
				local height = 0

				for _, v in ipairs(this:GetChildren()) do
					if (IsValid(v) and v:IsVisible()) then
						local _, top, _, bottom = v:GetDockMargin()
						height = height + v:GetTall() + top + bottom
					end
				end

				this:SetTall(height)
			end

			local bFirst = true

			for k, v in SortedPairsByMemberValue(list, "name") do
				local bar = Reg(self.attributes:Add("ixInfoAttribute"))
				bar:Dock(TOP)
				bar:DockMargin(0, bFirst and 0 or 4, 0, 0)
				bar.attributeID = k

				if (isstring(v.description) and v.description != "") then
					bar:SetTooltip(L(v.description))
				end

				bFirst = false
				self.attributes.bars[#self.attributes.bars + 1] = bar
			end

			self.attributes:SizeToContents()
			self:UpdateAttributes(character)
		end
	end

	hook.Run("CreateCharacterInfoCategory", self)

	local children = self:GetCanvas():GetChildren()

	for i, child in ipairs(children) do
		local l, t, r, b = child:GetDockMargin()

		child:DockMargin(l + pad, t + (i == 1 and pad or 0), r + pad, b + (i == #children and pad or 0))
	end
end

function PANEL:Recenter()
	local parent = self:GetParent()

	if (!IsValid(parent)) then
		return
	end

	local px, py = parent:LocalToScreen(0, 0)

	if (self.lastPX == px and self.lastPY == py) then
		return
	end

	self.lastPX, self.lastPY = px, py

	self:SetPos(math.floor((ScrW() - self:GetWide()) * 0.5 - px), math.floor((ScrH() - self:GetTall()) * 0.5 - py))
end

function PANEL:RefreshExtra()
	local info = self.characterInfo

	if (!IsValid(info)) then
		return
	end

	local count = 0

	for _, row in ipairs(info:GetChildren()) do
		if (IsValid(row)) then
			if (!row.ixInfoStyled) then
				self.rowCounter = self.rowCounter + 1
				row.ixInfoStyled = true

				StyleRow(row, self.rowCounter)
			end

			if (row:IsVisible()) then
				count = count + 1
			end
		end
	end

	info:SetVisible(count > 0)
	info:SizeToContents()

	if (IsValid(self.extraHeader)) then
		self.extraHeader:SetVisible(count > 0)
		self.extraHeader:SetRightText(count > 0 and string.format("%02d", count) or "")
	end
end

function PANEL:UpdateAttributes(character)
	if (!IsValid(self.attributes) or !character) then
		return
	end

	local boost = character:GetBoosts() or {}
	local sumPct, count = 0, 0

	for _, bar in ipairs(self.attributes.bars) do
		local k = bar.attributeID
		local def = ix.attributes.list[k]

		if (def) then
			local attributeBoost = 0

			if (boost[k]) then
				for _, bValue in pairs(boost[k]) do
					attributeBoost = attributeBoost + bValue
				end
			end

			local value = character:GetAttribute(k, 0)
			local maximum = def.maxValue or ix.config.Get("maxAttributes", 100)

			bar:SetData(L(def.name), value, attributeBoost, maximum)

			sumPct = sumPct + value / math.max(maximum, 0.0001) * 100
			count = count + 1
		end
	end

	if (IsValid(self.attrHeader) and count > 0) then
		self.attrHeader:SetRightText(string.format("СРЕДНЕЕ  %d%%", math.floor(sumPct / count + 0.5)))
	end
end

function PANEL:UpdateLive()
	local ply = LocalPlayer()

	if (!IsValid(ply)) then
		return
	end

	if (IsValid(self.ping)) then
		self.ping:SetLabelText("ЗАДЕРЖКА")
		self.ping:SetText(ply:Ping() .. " МС")
	end

	local character = ply.GetCharacter and ply:GetCharacter()

	if (character) then
		if (IsValid(self.money)) then
			self.money:SetText(ix.currency.Get(character:GetMoney()))
		end

		self:UpdateAttributes(character)
	end
end

function PANEL:Think()
	if (scrollBase.Think) then
		scrollBase.Think(self)
	end

	self:Recenter()

	local now = CurTime()

	if ((self.nextLive or 0) > now) then
		return
	end

	self.nextLive = now + 0.25
	self:UpdateLive()
end

function PANEL:Update(character)
	if (!character) then
		return
	end

	self.lastPX = nil
	self:Recenter()

	local faction = ix.faction.indices[character:GetFaction()]
	local class = ix.class.list[character:GetClass()]
	local factionName = faction and Upper(L(faction.name)) or "—"
	local bShowClass = class and (!faction or class.name != faction.name)
	local className = bShowClass and Upper(L(class.name)) or ""

	if (IsValid(self.name)) then
		local sub = factionName

		if (bShowClass) then
			sub = sub .. "  //  " .. className
		end

		local initial = SplitChars(factionName)[1] or ""

		self.name:SetText(character:GetName())
		self.name:SetData(string.format("ЛИЧНОЕ ДЕЛО  //  № %06d", character:GetID() or 0), sub, initial)

		if (faction) then
			self.name.backgroundColor = ColorAlpha(faction.color, 150) or Color(0, 0, 0, 150)
		end
	end

	if (IsValid(self.description)) then
		self.description:SetText(character:GetDescription())
		self.description:SizeToContents()
	end

	if (IsValid(self.faction)) then
		self.faction:SetLabelText("ФРАКЦИЯ")
		self.faction:SetText(factionName)
		self.faction:SetStripe(faction and faction.color or nil)
	end

	if (IsValid(self.class)) then
		if (bShowClass) then
			self.class:SetLabelText("КЛАСС")
			self.class:SetText(className)
			self.class:SetVisible(true)
		else
			self.class:SetVisible(false)
		end
	end

	if (IsValid(self.money)) then
		self.money:SetLabelText("СРЕДСТВА")
		self.money:SetText(ix.currency.Get(character:GetMoney()))
	end

	if (IsValid(self.operator)) then
		self.operator:SetLabelText("STEAM-НИК")
		self.operator:SetText(LocalPlayer():SteamName())
	end

	if (IsValid(self.dataGrid)) then
		self.dataGrid:SizeToContents()
	end

	self:UpdateLive()

	hook.Run("UpdateCharacterInfo", self.characterInfo, character)

	if (IsValid(self.characterInfo)) then
		self:RefreshExtra()
	end

	hook.Run("UpdateCharacterInfoCategory", self, character)
end

function PANEL:Reveal()
	for i, pnl in ipairs(self.revealList) do
		if (IsValid(pnl)) then
			pnl.revealA = 0
			pnl.typeStart = nil
			pnl:SetAlpha(0)

			timer.Simple((i - 1) * (CFG.revealStep or 0.05), function()
				if (!IsValid(pnl)) then
					return
				end

				pnl.typeStart = RealTime()

				if (pnl.Replay) then
					pnl:Replay()
				end

				if (i % 3 == 1) then
					PlayUI("tick", 0.8 + i * 0.03, 0.8)
				end

				pnl:CreateAnimation(0.5, {
					index = 30,
					target = {revealA = 255},
					easing = "outCubic",

					Think = function(animation, panel)
						panel:SetAlpha(panel.revealA)
					end,

					OnComplete = function(animation, panel)
						panel:SetAlpha(255)
					end
				})
			end)
		end
	end

	PlayUI("reveal")
end

function PANEL:OnSubpanelRightClick()
	properties.OpenEntityMenu(LocalPlayer())
end

function PANEL:Paint(w, h)
	local accent = GetAccent()
	local ar, ag, ab = accent.r, accent.g, accent.b

	draw.NoTexture()
	surface.SetDrawColor(7, 10, 15, 215)
	surface.DrawRect(0, 0, w, h)

	DrawFade(0, 0, math.floor(w * 0.35), h, ar, ag, ab, 14, true)

	local step = math.max(math.floor(ScrH() / 12), 48)

	for gx = 0, w, step do
		surface.SetDrawColor(ar, ag, ab, (gx / step) % 4 == 0 and 6 or 2.5)
		surface.DrawRect(gx, 0, 1, h)
	end

	for gy = 0, h, step do
		surface.SetDrawColor(ar, ag, ab, (gy / step) % 4 == 0 and 6 or 2.5)
		surface.DrawRect(0, gy, w, 1)
	end
end

function PANEL:PaintOver(w, h)
	local accent = GetAccent()
	local ar, ag, ab = accent.r, accent.g, accent.b
	local now = RealTime()

	draw.NoTexture()

	if (CFG.scanlines) then
		surface.SetDrawColor(0, 0, 0, 12)

		for y = 0, h, 3 do
			surface.DrawRect(0, y, w, 1)
		end

		local bandH = h * 0.16
		local y0 = ((now * h * 0.07) % (h + bandH)) - bandH
		local parts = 14

		for i = 0, parts - 1 do
			local f = math.sin((i + 0.5) / parts * math.pi)

			surface.SetDrawColor(ar, ag, ab, 5 * f)
			surface.DrawRect(0, y0 + i * bandH / parts, w, math.ceil(bandH / parts) + 1)
		end
	end

	surface.SetDrawColor(ar, ag, ab, 110)
	surface.DrawOutlinedRect(0, 0, w, h, 1)

	DrawBrackets(0, 0, w, h, 18, ar, ag, ab, 200)
end

vgui.Register("ixCharacterInfo", PANEL, "DScrollPanel")

hook.Add("CreateMenuButtons", "ixCharInfo", function(tabs)
	tabs["you"] = {
		bHideBackground = true,
		buttonColor = team.GetColor(LocalPlayer():Team()),
		Create = function(info, container)
			container.infoPanel = container:Add("ixCharacterInfo")

			container.OnMouseReleased = function(this, key)
				if (key == MOUSE_RIGHT) then
					this.infoPanel:OnSubpanelRightClick()
				end
			end
		end,
		OnSelected = function(info, container)
			container.infoPanel:Update(LocalPlayer():GetCharacter())
			container.infoPanel:Reveal()
			ix.gui.menu:SetCharacterOverview(true)
		end,
		OnDeselected = function(info, container)
			ix.gui.menu:SetCharacterOverview(false)
		end
	}
end)