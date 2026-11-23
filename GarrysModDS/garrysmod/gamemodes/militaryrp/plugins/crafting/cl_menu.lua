local PLUGIN = PLUGIN

-- =====================================================================
--  ХЕЛПЕРЫ
-- =====================================================================
local function Sc(n) return math.Round(n * ScrH() / 1080) end

local function CreateFonts(font)
	font = font or "Roboto"

	local function F(name, size, weight)
		surface.CreateFont(name, {font = font, size = Sc(size), weight = weight or 500, extended = true, antialias = true})
	end

	F("ixCraftHuge", 66, 300)
	F("ixCraftBig", 54, 300)
	F("ixCraftTitle", 40, 400)
	F("ixCraftHeading", 24, 500)
	F("ixCraftText", 19, 400)
	F("ixCraftSmall", 15, 500)
	F("ixCraftTiny", 13, 600)
	F("ixCraftButton", 20, 600)
end

CreateFonts(ix.config.Get("font", "Roboto"))

function PLUGIN:LoadFonts(font)
	CreateFonts(font)
end

hook.Add("OnScreenSizeChanged", "ixCraftFonts", function()
	CreateFonts(ix.config.Get("font", "Roboto"))
end)

local C_TEXT = Color(236, 239, 244)
local C_SUB = Color(150, 158, 172)
local C_DIM = Color(96, 103, 116)
local C_LINE = Color(255, 255, 255, 16)
local C_OK = Color(120, 224, 160)
local C_BAD = Color(240, 106, 106)
local C_WARN = Color(255, 196, 92)
local C_OFF = Color(70, 75, 84)

local function Ease(t) t = math.Clamp(t, 0, 1) return 1 - (1 - t) ^ 3 end

local function EaseBack(t)
	t = math.Clamp(t, 0, 1) - 1
	return 1 + 2.70158 * t ^ 3 + 1.70158 * t ^ 2
end

local function ChanceColor(c)
	if (c >= 70) then return C_OK elseif (c >= 40) then return C_WARN end
	return C_BAD
end

-- регистр для кириллицы (string.upper/lower её не понимают)
local function MapCase(s, upper)
	local out = {}

	for _, c in utf8.codes(s) do
		if (upper) then
			if (c >= 0x430 and c <= 0x44F) then c = c - 32
			elseif (c == 0x451) then c = 0x401
			elseif (c == 0x456) then c = 0x406
			elseif (c == 0x457) then c = 0x407
			elseif (c == 0x454) then c = 0x404
			elseif (c == 0x491) then c = 0x490
			elseif (c >= 97 and c <= 122) then c = c - 32 end
		else
			if (c >= 0x410 and c <= 0x42F) then c = c + 32
			elseif (c == 0x401) then c = 0x451
			elseif (c == 0x406) then c = 0x456
			elseif (c == 0x407) then c = 0x457
			elseif (c == 0x404) then c = 0x454
			elseif (c == 0x490) then c = 0x491
			elseif (c >= 65 and c <= 90) then c = c + 32 end
		end

		out[#out + 1] = utf8.char(c)
	end

	return table.concat(out)
end

local function Up(s) return MapCase(s or "", true) end
local function Low(s) return MapCase(s or "", false) end

-- текст с разрядкой
local function DrawSpaced(text, font, x, y, col, spacing, align)
	surface.SetFont(font)
	local chars, total = {}, 0

	for _, c in utf8.codes(text) do
		local ch = utf8.char(c)
		local w = surface.GetTextSize(ch)
		chars[#chars + 1] = {ch, w}
		total = total + w + spacing
	end

	total = total - spacing
	local cx = x
	if (align == TEXT_ALIGN_CENTER) then cx = x - total / 2 elseif (align == TEXT_ALIGN_RIGHT) then cx = x - total end

	for _, d in ipairs(chars) do
		draw.SimpleText(d[1], font, cx, y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		cx = cx + d[2] + spacing
	end

	return total
end

local function DrawArc(cx, cy, r, thick, a0, a1, col, seg)
	seg = seg or math.max(6, math.floor(math.abs(a1 - a0) / 5))
	local step = (a1 - a0) / seg
	local ri = r - thick

	draw.NoTexture()
	surface.SetDrawColor(col)

	for i = 0, seg - 1 do
		local s = math.rad(a0 + i * step)
		local e = math.rad(a0 + (i + 1) * step)

		surface.DrawPoly({
			{x = cx + math.cos(s) * r, y = cy + math.sin(s) * r},
			{x = cx + math.cos(e) * r, y = cy + math.sin(e) * r},
			{x = cx + math.cos(e) * ri, y = cy + math.sin(e) * ri},
			{x = cx + math.cos(s) * ri, y = cy + math.sin(s) * ri}
		})
	end
end

local function DrawCircle(cx, cy, r, col, seg)
	seg = seg or 40
	local pts = {}

	for i = 0, seg - 1 do
		local a = math.rad(i / seg * 360)
		pts[#pts + 1] = {x = cx + math.cos(a) * r, y = cy + math.sin(a) * r}
	end

	draw.NoTexture()
	surface.SetDrawColor(col)
	surface.DrawPoly(pts)
end

-- очень мягкое свечение: гладкий радиальный спрайт вместо наложенных кругов (без колец и полос)
local glowMat = Material("sprites/light_glow02_add")

local function DrawGlow(cx, cy, r, col, alpha)
	local k = alpha / 255 * 2.8
	r = r * 1.3

	surface.SetMaterial(glowMat)
	surface.SetDrawColor(col.r * k, col.g * k, col.b * k, 255)
	surface.DrawTexturedRect(cx - r, cy - r, r * 2, r * 2)
end

local function StyleButton(btn, text, color)
	btn:SetText("")
	btn.label = text
	btn.hover = 0

	btn.Paint = function(s, w, h)
		local enabled = s:IsEnabled()
		local c = enabled and color or C_OFF
		s.hover = Lerp(FrameTime() * 10, s.hover, (s:IsHovered() and enabled) and 1 or 0)

		surface.SetDrawColor(c.r, c.g, c.b, 22 + 20 * s.hover)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(c.r, c.g, c.b, 255)
		surface.DrawRect(0, h - 2, w * (0.25 + 0.75 * s.hover), 2)
		surface.SetDrawColor(c.r, c.g, c.b, 70 + 150 * s.hover)
		surface.DrawOutlinedRect(0, 0, w, h, 1)

		DrawSpaced(Up(s.label), "ixCraftButton", w / 2, h / 2, enabled and C_TEXT or C_DIM, 3, TEXT_ALIGN_CENTER)
	end

	btn.OnMousePressed = function(s, code)
		if (s:IsEnabled()) then surface.PlaySound("buttons/button15.wav") end
		DButton.OnMousePressed(s, code)
	end
end

local function StyleScroll(scroll)
	local bar = scroll:GetVBar()
	bar:SetWide(Sc(3))
	bar:SetHideButtons(true)
	bar.Paint = function() end
	bar.btnGrip.Paint = function(_, w, h)
		surface.SetDrawColor(255, 255, 255, 36)
		surface.DrawRect(0, 0, w, h)
	end
end

local function LocalInventory()
	local char = LocalPlayer():GetCharacter()
	return char and char:GetInventory()
end

local function ItemOf(recipe)
	local id = next(recipe.result)
	return id and ix.item.list[id], id
end

-- вращающаяся 3D-модель предмета
local function SetupModel(mp, item, dist)
	if (!item) then return end

	mp:SetModel(item.model)
	local ent = mp.Entity
	if (!IsValid(ent)) then return end

	if (item.skin) then ent:SetSkin(item.skin) end

	local mn, mx = ent:GetRenderBounds()
	local radius = math.max((mx - mn):Length() * 0.5, 1)

	mp.mcenter = (mn + mx) * 0.5
	mp:SetFOV(30)
	mp:SetLookAt(Vector(0, 0, 0))
	mp:SetCamPos(Vector(0.75, 0.75, 0.38):GetNormalized() * radius * (dist or 5.0))
	mp:SetAmbientLight(Color(90, 96, 108))
	mp:SetDirectionalLight(BOX_TOP, Color(255, 255, 255))
	mp:SetDirectionalLight(BOX_FRONT, Color(150, 160, 180))
	mp:SetDirectionalLight(BOX_RIGHT, Color(90, 100, 120))
	mp.rotSpeed = 26

	function mp:LayoutEntity(e)
		e:SetAngles(Angle(0, (CurTime() * self.rotSpeed) % 360, 0))
		e:SetPos(Vector(0, 0, 0))
		e:SetPos(-(e:LocalToWorld(self.mcenter) - e:GetPos()) + Vector(0, 0, math.sin(CurTime() * 1.4) * radius * 0.04))
	end
end

-- =====================================================================
--  ОВЕРЛЕЙ КРАФТА (интерактивная сборка)
-- =====================================================================
local OVERLAY = {}

local STAGES = {
	{0.22, "Подготовка материалов"},
	{0.50, "Обработка"},
	{0.80, "Сборка"},
	{1.01, "Контроль качества"}
}

function OVERLAY:Setup(menu, recipe, duration)
	self.menu = menu
	self.recipe = recipe
	self.accent = menu.accent
	self.duration = duration
	self.startTime = CurTime()
	self.sparks, self.floaters, self.flyers = {}, {}, {}
	self.bonus = 0
	self.nextHit = 0
	self.skillBonus = ix.config.Get("craftSkillBonus", 5)
	self.half = PLUGIN:GetCheckHalfWidth(duration)
	self.baseChance = PLUGIN:GetCraftChance(LocalPlayer(), recipe)
	self.zones = {}
	self.lastP = 0

	for i, c in ipairs(PLUGIN.checkpoints) do
		self.zones[i] = {c = c}
	end

	self:SetAlpha(0)
	self:AlphaTo(255, 0.35, 0)
	self:SetKeyboardInputEnabled(true)

	local item = ItemOf(recipe)

	self.model = self:Add("DModelPanel")
	self.model:SetMouseInputEnabled(false)
	SetupModel(self.model, item, 4.2)
	self.model.rotSpeed = 40

	-- ингредиенты "летят" в центр
	for i, ing in ipairs(menu.ingRows or {}) do
		if (IsValid(ing.panel)) then
			local sx, sy = ing.panel:LocalToScreen(Sc(34), ing.panel:GetTall() / 2)
			local lx, ly = self:ScreenToLocal(sx, sy)
			local it = ix.item.list[ing.id]
			local icon = self:Add("ixSpawnIcon")

			icon:SetMouseInputEnabled(false)
			icon:SetSize(Sc(44), Sc(44))
			icon:SetAlpha(0)
			if (it) then icon:SetModel(it.model, it.skin or 0) end

			self.flyers[#self.flyers + 1] = {
				icon = icon, x0 = lx, y0 = ly, delay = 0.25 + (i - 1) * 0.16, dur = 1.0,
				side = (i % 2 == 0) and 1 or -1, arrived = false
			}
		end
	end

	self.btnCancel = self:Add("DButton")
	StyleButton(self.btnCancel, "Отмена", C_BAD)
	self.btnCancel:SetSize(Sc(200), Sc(46))
	self.btnCancel.DoClick = function() self:CancelCraft() end

	self.btnClose = self:Add("DButton")
	StyleButton(self.btnClose, "Продолжить", self.accent)
	self.btnClose:SetSize(Sc(210), Sc(48))
	self.btnClose:SetVisible(false)
	self.btnClose.DoClick = function() menu:EndCraft() end

	self.btnAgain = self:Add("DButton")
	StyleButton(self.btnAgain, "Ещё раз", C_OK)
	self.btnAgain:SetSize(Sc(210), Sc(48))
	self.btnAgain:SetVisible(false)
	self.btnAgain.DoClick = function()
		menu:EndCraft()
		menu:RequestCraft()
	end

	surface.PlaySound("ambient/energy/weld1.wav")
end

function OVERLAY:CancelCraft()
	if (self.result != nil or self.cancelled) then return end

	self.cancelled = true
	net.Start("ixCraftCancel")
	net.SendToServer()
end

function OVERLAY:Spark(x, y, count, col, speed, gravity, spread)
	for _ = 1, count do
		local a = math.Rand(0, math.pi * 2)
		local sp = math.Rand(0.25, 1) * speed

		self.sparks[#self.sparks + 1] = {
			x = x, y = y, vx = math.cos(a) * sp, vy = math.sin(a) * sp * (spread or 1),
			life = 0, max = math.Rand(0.4, 1.1), size = math.Rand(2, 4.5), col = col, g = gravity or 0
		}
	end
end

function OVERLAY:Float(text, x, y, col)
	self.floaters[#self.floaters + 1] = {text = text, x = x, y = y, col = col, t0 = CurTime()}
end

-- нажатие в мини-игре
function OVERLAY:Hit()
	if (self.result != nil or self.cancelled or self.skillBonus <= 0) then return end

	local now = CurTime()
	if (now < self.nextHit) then return end
	self.nextHit = now + 0.25

	local p = (now - self.startTime) / self.duration

	for i, z in ipairs(self.zones) do
		local d = math.abs(p - z.c)

		if (!z.state and d <= self.half) then
			local perfect = d <= self.half * 0.35
			z.state = perfect and "perfect" or "good"
			z.hitTime = now

			local gain = (perfect and 1 or 0.5) * self.skillBonus
			self.bonus = self.bonus + gain

			local ang = math.rad(-90 + 360 * z.c)
			local zx, zy = self.cx + math.cos(ang) * self.R, self.cy + math.sin(ang) * self.R

			self:Spark(zx, zy, perfect and 26 or 12, C_OK, Sc(260), Sc(120))
			self:Float((perfect and "ИДЕАЛЬНО  +" or "ХОРОШО  +") .. gain .. "%", self.cx, self.cy + self.R + Sc(4), perfect and C_OK or C_WARN)
			surface.PlaySound(perfect and "buttons/button14.wav" or "buttons/button15.wav")

			net.Start("ixCraftHit")
				net.WriteUInt(i, 2)
			net.SendToServer()
			return
		end
	end

	self:Float("МИМО", self.cx, self.cy + self.R + Sc(4), C_BAD)
	self.missFlash = now
	surface.PlaySound("buttons/button8.wav")
end

function OVERLAY:OnMousePressed(code)
	if (code == MOUSE_LEFT) then self:Hit() end
end

function OVERLAY:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		if (self.result == nil) then self:CancelCraft() else self.menu:EndCraft() end
	end
end

function OVERLAY:ShowResult(success, chance, bonus)
	self.result = success
	self.resultTime = CurTime()
	self.finalChance = chance
	self.finalBonus = bonus
	self.btnCancel:SetVisible(false)

	if (success) then
		self:Spark(self.cx, self.cy, 90, C_OK, Sc(620), Sc(220))
		self:Spark(self.cx, self.cy, 40, C_TEXT, Sc(420), Sc(120))
		surface.PlaySound("buttons/button14.wav")
		surface.PlaySound("items/ammo_pickup.wav")
	else
		self:Spark(self.cx, self.cy, 36, C_BAD, Sc(320), Sc(560))
		surface.PlaySound("buttons/button8.wav")
	end
end

local function Bezier(a, c, b, t)
	local u = 1 - t
	return u * u * a + 2 * u * t * c + t * t * b
end

function OVERLAY:Think()
	local now, dt = CurTime(), FrameTime()
	local w, h = self:GetSize()
	local cx, cy = w / 2, h * 0.45
	local S = math.min(w, h) * 0.34
	local R = S * 0.64
	local p = math.Clamp((now - self.startTime) / self.duration, 0, 1)

	self.cx, self.cy, self.R, self.S = cx, cy, R, S
	self.progress = self.result != nil and 1 or p

	-- тряска при провале
	self.shake = 0
	if (self.result == false) then
		local t = now - self.resultTime
		if (t < 0.6) then self.shake = math.sin(t * 60) * (1 - t / 0.6) * Sc(14) end
	end

	-- модель: силуэт -> готовый предмет
	local size = S
	local v = 0.12 + 0.88 * Ease(self.progress)

	if (self.result == true) then
		local t = (now - self.resultTime) / 0.7
		size = S * (0.85 + 0.2 * EaseBack(t))
		v = 1
	elseif (self.result == false) then
		v = 0.25
	end

	if (self.result == nil and p < 1) then
		v = v * (0.92 + 0.08 * math.sin(now * 18)) -- лёгкое мерцание при работе
	end

	self.model:SetSize(size, size)
	self.model:SetPos(cx + self.shake - size / 2, cy - size / 2)
	self.model:SetColor(Color(v * 255, v * 255, v * 255, 255))

	-- мини-игра: пропущенные зоны
	if (self.skillBonus > 0) then
		for _, z in ipairs(self.zones) do
			if (!z.state and p > z.c + self.half) then
				z.state = "miss"
				z.hitTime = now
			end
		end

		local down = input.IsKeyDown(KEY_SPACE)
		if (down and !self.spaceDown) then self:Hit() end
		self.spaceDown = down
	end

	-- летящие ингредиенты
	for _, f in ipairs(self.flyers) do
		local t = (now - self.startTime - f.delay) / f.dur

		if (t <= 0 or f.arrived) then
			f.icon:SetAlpha(0)
		else
			local e = Ease(t)
			local ctrlX = (f.x0 + cx) / 2 + f.side * Sc(120)
			local ctrlY = math.min(f.y0, cy) - Sc(120)
			local x = Bezier(f.x0, ctrlX, cx, e)
			local y = Bezier(f.y0, ctrlY, cy, e)
			local sz = Lerp(e, Sc(46), Sc(16))

			f.icon:SetSize(sz, sz)
			f.icon:SetPos(x - sz / 2, y - sz / 2)
			f.icon:SetAlpha(255 * math.min(1, t * 6) * (1 - math.max(0, (t - 0.8) / 0.2)))

			if (math.random() < 0.7) then self:Spark(x, y, 1, self.accent, Sc(40), 0) end

			if (t >= 1) then
				f.arrived = true
				f.icon:SetAlpha(0)
				self:Spark(cx, cy, 14, self.accent, Sc(180), Sc(60))
			end
		end
	end

	-- искры на конце кольца
	if (self.result == nil and p < 1) then
		local ang = math.rad(-90 + 360 * p)
		self:Spark(cx + math.cos(ang) * R, cy + math.sin(ang) * R, 2, self.accent, Sc(150), Sc(240))
	end

	for i = #self.sparks, 1, -1 do
		local s = self.sparks[i]
		s.life = s.life + dt

		if (s.life >= s.max) then
			table.remove(self.sparks, i)
		else
			s.vy = s.vy + s.g * dt
			s.x = s.x + s.vx * dt
			s.y = s.y + s.vy * dt
		end
	end

	for i = #self.floaters, 1, -1 do
		if (now - self.floaters[i].t0 > 1.3) then table.remove(self.floaters, i) end
	end

	-- кнопки
	self.btnCancel:SetPos(w / 2 - Sc(100), h - Sc(96))

	if (self.result != nil and now - self.resultTime > 1.0) then
		if (!self.btnClose:IsVisible()) then
			self.btnClose:SetVisible(true)
			self.btnClose:SetAlpha(0)
			self.btnClose:AlphaTo(255, 0.35, 0)

			if (self.result and self.menu.selected and PLUGIN:CanCraft(LocalPlayer(), self.menu.selected)) then
				self.btnAgain:SetVisible(true)
				self.btnAgain:SetAlpha(0)
				self.btnAgain:AlphaTo(255, 0.35, 0)
			end
		end

		if (self.btnAgain:IsVisible()) then
			self.btnAgain:SetPos(w / 2 - Sc(220), h - Sc(96))
			self.btnClose:SetPos(w / 2 + Sc(10), h - Sc(96))
		else
			self.btnClose:SetPos(w / 2 - Sc(105), h - Sc(96))
		end
	end
end

function OVERLAY:Paint(w, h)
	local now = CurTime()
	local acc = self.accent
	local cx, cy, R = (self.cx or w / 2) + (self.shake or 0), self.cy or h * 0.45, self.R or Sc(200)
	local p = self.progress or 0

	surface.SetDrawColor(7, 9, 12, 246)
	surface.DrawRect(0, 0, w, h)

	local mainCol = acc
	if (self.result == true) then mainCol = C_OK elseif (self.result == false) then mainCol = C_BAD end

	-- свечение за предметом, усиливается по ходу работы
	DrawGlow(cx, cy, R * (1.15 + 0.2 * p), mainCol, 14 + 30 * p)

	-- тонкие кольца
	DrawArc(cx, cy, R + Sc(46), 1, 0, 360, Color(255, 255, 255, 10), 100)
	DrawArc(cx, cy, R - Sc(34), 1, 0, 360, Color(255, 255, 255, 10), 100)

	for i = 0, 3 do
		local a = now * 24 + i * 90
		DrawArc(cx, cy, R + Sc(46), 2, a, a + 16, ColorAlpha(mainCol, 160), 6)
	end

	-- основное кольцо
	DrawArc(cx, cy, R, Sc(4), 0, 360, Color(255, 255, 255, 22), 100)
	if (p > 0.002) then DrawArc(cx, cy, R, Sc(4), -90, -90 + 360 * p, mainCol) end

	-- зоны мини-игры
	if (self.skillBonus > 0 and self.result == nil) then
		for _, z in ipairs(self.zones) do
			local a0 = -90 + 360 * (z.c - self.half)
			local a1 = -90 + 360 * (z.c + self.half)
			local near = p > z.c - self.half - 0.1 and p <= z.c + self.half
			local inside = math.abs(p - z.c) <= self.half

			if (z.state == "perfect" or z.state == "good") then
				local f = 1 - math.min(1, (now - z.hitTime) / 0.6)
				DrawArc(cx, cy, R + Sc(10), Sc(18), a0, a1, ColorAlpha(C_OK, z.state == "perfect" and 200 or 130), 16)
				if (f > 0) then DrawArc(cx, cy, R + Sc(10) + Sc(14) * (1 - f), Sc(3), a0, a1, ColorAlpha(C_OK, 220 * f), 16) end
			elseif (z.state == "miss") then
				DrawArc(cx, cy, R + Sc(10), Sc(18), a0, a1, ColorAlpha(C_BAD, 70), 16)
			else
				local alpha = 55
				if (inside) then alpha = 210 + 40 * math.sin(now * 16)
				elseif (near) then alpha = 90 + 60 * math.sin(now * 10) end

				DrawArc(cx, cy, R + Sc(10), Sc(18), a0, a1, ColorAlpha(acc, alpha), 16)

				-- центр зоны (идеальное попадание)
				DrawArc(cx, cy, R + Sc(10), Sc(18), -90 + 360 * (z.c - self.half * 0.35), -90 + 360 * (z.c + self.half * 0.35), Color(255, 255, 255, inside and 230 or 90), 8)
			end
		end
	end

	-- головка прогресса
	if (self.result == nil) then
		local ang = math.rad(-90 + 360 * p)
		local hx, hy = cx + math.cos(ang) * R, cy + math.sin(ang) * R
		DrawGlow(hx, hy, Sc(22), acc, 80)
		DrawCircle(hx, hy, Sc(6), C_TEXT, 16)
	end

	-- результат: волны и вспышка
	if (self.result != nil) then
		local t = now - self.resultTime

		if (self.result) then
			for i = 0, 2 do
				local tt = t - i * 0.2

				if (tt > 0 and tt < 1.2) then
					DrawArc(cx, cy, R * (1 + tt * 1.1), Sc(3), 0, 360, ColorAlpha(C_OK, 190 * (1 - tt / 1.2)), 100)
				end
			end
		end

		if (t < 0.4) then
			local c = self.result and Color(255, 255, 255) or C_BAD
			surface.SetDrawColor(c.r, c.g, c.b, (self.result and 100 or 60) * (1 - t / 0.4))
			surface.DrawRect(0, 0, w, h)
		end
	end

	-- верх: текущий шанс и подсказка
	local curChance = math.min(100, (self.baseChance or 0) + (self.bonus or 0))
	local chanceCol = ChanceColor(curChance)

	DrawSpaced(Up("Шанс успеха"), "ixCraftTiny", w / 2, Sc(70), C_SUB, 3, TEXT_ALIGN_CENTER)
	draw.SimpleText(math.floor(self.finalChance or curChance) .. "%", "ixCraftBig", w / 2, Sc(116), chanceCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	if (self.bonus > 0 or (self.finalBonus or 0) > 0) then
		draw.SimpleText("мастерство в мини-игре  +" .. (self.finalBonus or self.bonus) .. "%", "ixCraftSmall", w / 2, Sc(158), C_OK, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	-- низ: стадия и проценты / итог
	local ty = cy + R + Sc(64)

	if (self.result == nil) then
		local stage = STAGES[#STAGES][2]

		for _, st in ipairs(STAGES) do
			if (p < st[1]) then stage = st[2] break end
		end

		DrawSpaced(Up(stage), "ixCraftSmall", w / 2, ty, C_TEXT, 3, TEXT_ALIGN_CENTER)
		draw.SimpleText(math.floor(p * 100) .. "%", "ixCraftHuge", w / 2, ty + Sc(60), mainCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		if (self.skillBonus > 0 and p < 0.9) then
			local pulse = 0.65 + 0.35 * math.sin(now * 4)
			local text = "в светлой зоне нажмите"
			surface.SetFont("ixCraftSmall")
			local tw = surface.GetTextSize(text)
			local kw, kh = Sc(110), Sc(34)
			local total = tw + Sc(14) + kw
			local x0 = w / 2 - total / 2
			local y0 = h - Sc(150)

			draw.SimpleText(text, "ixCraftSmall", x0, y0, ColorAlpha(C_SUB, 255 * pulse), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.RoundedBox(6, x0 + tw + Sc(14), y0 - kh / 2, kw, kh, ColorAlpha(acc, 40 + 60 * pulse))
			surface.SetDrawColor(acc.r, acc.g, acc.b, 200)
			surface.DrawOutlinedRect(x0 + tw + Sc(14), y0 - kh / 2, kw, kh, 1)
			DrawSpaced("ПРОБЕЛ", "ixCraftTiny", x0 + tw + Sc(14) + kw / 2, y0, C_TEXT, 2, TEXT_ALIGN_CENTER)
		end
	else
		local t = math.min(1, (now - self.resultTime) / 0.45)
		local a = 255 * Ease(t)
		local names = {}

		for id, qty in pairs(self.recipe.result) do
			local item = ix.item.list[id]
			names[#names + 1] = (item and item.name or id) .. (qty > 1 and (" ×" .. qty) or "")
		end

		if (self.result) then
			DrawSpaced("ГОТОВО", "ixCraftBig", w / 2 + (self.shake or 0), ty + Sc(20), ColorAlpha(C_OK, a), 10, TEXT_ALIGN_CENTER)
			draw.SimpleText(table.concat(names, ", "), "ixCraftHeading", w / 2, ty + Sc(76), ColorAlpha(C_TEXT, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		else
			DrawSpaced("НЕУДАЧА", "ixCraftBig", w / 2 + (self.shake or 0), ty + Sc(20), ColorAlpha(C_BAD, a), 10, TEXT_ALIGN_CENTER)
			draw.SimpleText("Часть материалов утрачена", "ixCraftHeading", w / 2, ty + Sc(76), ColorAlpha(C_SUB, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
end

-- искры, всплывающие подписи и промах рисуются поверх модели
function OVERLAY:PaintOver(w, h)
	local now = CurTime()
	draw.NoTexture()

	for _, s in ipairs(self.sparks) do
		surface.SetDrawColor(s.col.r, s.col.g, s.col.b, 255 * (1 - s.life / s.max))
		surface.DrawRect(s.x, s.y, s.size, s.size)
	end

	for _, f in ipairs(self.floaters) do
		local t = (now - f.t0) / 1.3
		draw.SimpleText(f.text, "ixCraftHeading", f.x, f.y - Sc(46) * Ease(t), ColorAlpha(f.col, 255 * (1 - t)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	if (self.missFlash and now - self.missFlash < 0.25) then
		surface.SetDrawColor(C_BAD.r, C_BAD.g, C_BAD.b, 28 * (1 - (now - self.missFlash) / 0.25))
		surface.DrawRect(0, 0, w, h)
	end
end

vgui.Register("ixCraftOverlay", OVERLAY, "EditablePanel")

-- =====================================================================
--  ГЛАВНОЕ МЕНЮ
-- =====================================================================
local PANEL = {}

function PANEL:Init()
	if (IsValid(ix.gui.craftMenu)) then ix.gui.craftMenu:Remove() end
	ix.gui.craftMenu = self

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()
	self:DockPadding(Sc(100), Sc(44), Sc(100), Sc(64))

	self.bornTime = CurTime()
	self.nextRefresh = 0
	self.rows = {}
	self.ingRows = {}
	self.filter = ""

	self:SetAlpha(0)
	self:AlphaTo(255, 0.3, 0)
	surface.PlaySound("buttons/button17.wav")
end

function PANEL:Setup(entity)
	self.entity = entity
	self.benchID = entity:GetBenchType()
	self.bench = PLUGIN.workbenches[self.benchID] or {name = "Верстак", color = Color(90, 170, 255)}
	self.accent = self.bench.color
	self.recipes = PLUGIN:GetBenchRecipes(self.benchID)

	self.categories = {}
	local seen = {}

	for _, r in ipairs(self.recipes) do
		local c = r.category or "Разное"

		if (!seen[c]) then
			seen[c] = true
			self.categories[#self.categories + 1] = c
		end
	end

	self:BuildTop()

	local body = self:Add("DPanel")
	body:Dock(FILL)
	body:DockMargin(0, Sc(24), 0, 0)
	body.Paint = function() end

	self:BuildLeft(body)
	self:BuildRight(body)
	self:BuildStage(body)

	self:FillList()
end

-- ---------------- верхняя панель ----------------
function PANEL:BuildTop()
	local top = self:Add("DPanel")
	top:Dock(TOP)
	top:SetTall(Sc(92))

	local tabs = top:Add("DPanel")
	tabs.Paint = function(s, w, h)
		-- скользящее подчёркивание активной вкладки
		local target = s.activeBtn
		if (IsValid(target)) then
			local tx, tw = target:GetPos(), target:GetWide()
			s.ux = Lerp(FrameTime() * 12, s.ux or tx, tx)
			s.uw = Lerp(FrameTime() * 12, s.uw or tw, tw)
			surface.SetDrawColor(self.accent)
			surface.DrawRect(s.ux + Sc(14), h - 2, s.uw - Sc(28), 2)
		end
	end

	local function AddTab(label, category)
		local b = tabs:Add("DButton")
		b:SetText("")
		b.category = category
		surface.SetFont("ixCraftTiny")
		b:SetWide(select(1, surface.GetTextSize(Up(label))) + #label * Sc(2) + Sc(36))
		b:Dock(LEFT)
		b.Paint = function(s, w, h)
			local active = self.category == category
			DrawSpaced(Up(label), "ixCraftTiny", w / 2, h / 2 - Sc(2),
				active and C_TEXT or (s:IsHovered() and C_SUB or C_DIM), 2, TEXT_ALIGN_CENTER)
		end
		b.DoClick = function()
			surface.PlaySound("buttons/button15.wav")
			self.category = category
			tabs.activeBtn = b
			self:FillList()
		end

		if (category == nil) then tabs.activeBtn = b end
		return b
	end

	AddTab("Все", nil)
	for _, c in ipairs(self.categories) do AddTab(c, c) end

	local tw = 0
	for _, c in ipairs(tabs:GetChildren()) do tw = tw + c:GetWide() end
	tabs:SetSize(tw, Sc(44))

	top.PerformLayout = function(s, w, h)
		tabs:SetPos((w - tw) / 2, h - Sc(52))
	end

	local close = top:Add("DButton")
	close:Dock(RIGHT)
	close:SetWide(Sc(56))
	close:SetText("")
	close.hover = 0
	close.Paint = function(s, w, h)
		s.hover = Lerp(FrameTime() * 10, s.hover, s:IsHovered() and 1 or 0)
		local c = s.hover > 0.5 and C_TEXT or C_DIM
		local m = Sc(8)
		surface.SetDrawColor(c)
		surface.DrawLine(w - m * 2 - 2, h / 2 - m - Sc(24), w - 2, h / 2 + m - Sc(24))
		surface.DrawLine(w - m * 2 - 2, h / 2 + m - Sc(24), w - 2, h / 2 - m - Sc(24))
	end
	close.DoClick = function() self:Remove() end

	top.Paint = function(s, w, h)
		local k = Ease((CurTime() - self.bornTime) / 0.8)

		draw.SimpleText(self.bench.name, "ixCraftTitle", 0, Sc(30), C_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		DrawSpaced(Up(self.bench.description or ""), "ixCraftTiny", 2, Sc(66), C_DIM, 2, TEXT_ALIGN_LEFT)

		surface.SetDrawColor(C_LINE)
		surface.DrawRect(0, h - 1, w, 1)
		surface.SetDrawColor(self.accent)
		surface.DrawRect(0, h - 1, Sc(120) * k, 1)

		local char = LocalPlayer():GetCharacter()
		local val = char and char:GetAttribute("crafting", 0) or 0
		local maxv = ix.config.Get("maxAttributes", 100)
		local rx = w - Sc(72)

		DrawSpaced(Up("Ремесло"), "ixCraftTiny", rx, Sc(18), C_DIM, 2, TEXT_ALIGN_RIGHT)
		draw.SimpleText(string.format("%.1f", val), "ixCraftHeading", rx, Sc(42), C_TEXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(255, 255, 255, 20)
		surface.DrawRect(rx - Sc(160), Sc(62), Sc(160), 2)
		surface.SetDrawColor(self.accent)
		surface.DrawRect(rx - Sc(160), Sc(62), Sc(160) * math.Clamp(val / maxv, 0, 1), 2)
	end
end

-- ---------------- левая колонка: поиск и список ----------------
function PANEL:BuildLeft(body)
	local left = body:Add("DPanel")
	left:Dock(LEFT)
	left:SetWide(math.max(Sc(420), ScrW() * 0.23))
	left:DockPadding(0, 0, Sc(24), 0)
	left.Paint = function() end

	local search = left:Add("DTextEntry")
	search:Dock(TOP)
	search:SetTall(Sc(44))
	search:SetFont("ixCraftText")
	search:SetPaintBackground(false)
	search:SetTextColor(C_TEXT)
	search:SetCursorColor(C_TEXT)
	search:SetUpdateOnType(true)
	search.Paint = function(s, w, h)
		surface.SetDrawColor(255, 255, 255, s:HasFocus() and 70 or 22)
		surface.DrawRect(0, h - 1, w, 1)

		if (s:GetText() == "" and !s:HasFocus()) then
			draw.SimpleText("Поиск рецепта…", "ixCraftText", Sc(2), h / 2, C_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		s:DrawTextEntryText(C_TEXT, self.accent, C_TEXT)
	end
	search.OnValueChange = function(s, text)
		self.filter = text
		self:FillList()
	end

	self.list = left:Add("DScrollPanel")
	self.list:Dock(FILL)
	self.list:DockMargin(0, Sc(10), 0, 0)
	StyleScroll(self.list)
end

function PANEL:FillList()
	self.list:Clear()
	self.rows = {}

	local filter = Low(self.filter or "")
	local last, count, first = nil, 0, nil
	local visible = {}

	for _, recipe in ipairs(self.recipes) do
		if (self.category and recipe.category != self.category) then continue end
		if (filter != "" and !Low(recipe.name or recipe.id):find(filter, 1, true)) then continue end

		if (!self.category and recipe.category != last) then
			last = recipe.category

			local cat = self.list:Add("DPanel")
			cat:Dock(TOP)
			cat:SetTall(Sc(40))
			cat.Paint = function(s, w, h)
				DrawSpaced(Up(recipe.category or "Разное"), "ixCraftTiny", Sc(2), h - Sc(12), self.accent, 3, TEXT_ALIGN_LEFT)
			end
		end

		visible[recipe] = true
		first = first or recipe
		count = count + 1

		local row = self.list:Add("DButton")
		row:Dock(TOP)
		row:DockMargin(0, 0, 0, Sc(2))
		row:SetTall(Sc(72))
		row:SetText("")
		row.recipe = recipe
		row.hover, row.sel = 0, 0

		local item = ItemOf(recipe)
		local icon = row:Add("ixSpawnIcon")
		icon:SetPos(Sc(10), Sc(10))
		icon:SetSize(Sc(52), Sc(52))
		icon:SetMouseInputEnabled(false)
		if (item) then icon:SetModel(item.model, item.skin or 0) end

		row.Paint = function(s, w, h)
			s.hover = Lerp(FrameTime() * 10, s.hover, s:IsHovered() and 1 or 0)
			s.sel = Lerp(FrameTime() * 10, s.sel, self.selected == recipe and 1 or 0)

			surface.SetDrawColor(255, 255, 255, 4 + 8 * s.hover + 10 * s.sel)
			surface.DrawRect(0, 0, w, h)

			surface.SetDrawColor(self.accent.r, self.accent.g, self.accent.b, 255 * s.sel)
			surface.DrawRect(0, h * (1 - s.sel) / 2, 2, h * s.sel)

			local locked = s.canMake == false
			local off = Sc(8) * s.hover + Sc(6) * s.sel
			icon:SetPos(Sc(10) + off, Sc(10))
			icon:SetAlpha(locked and 110 or 255)

			draw.SimpleText(recipe.name or recipe.id, "ixCraftText", Sc(78) + off, h / 2 - Sc(11),
				locked and C_SUB or C_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			if (locked and s.reason) then
				draw.SimpleText(s.reason, "ixCraftTiny", Sc(78) + off, h / 2 + Sc(13), C_BAD, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			else
				local chance = PLUGIN:GetCraftChance(LocalPlayer(), recipe)
				draw.SimpleText(math.floor(chance) .. "% шанс", "ixCraftTiny", Sc(78) + off, h / 2 + Sc(13), ChanceColor(chance), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			if (!locked and s.canMake) then
				DrawCircle(w - Sc(16), h / 2, Sc(3), C_OK, 12)
			end
		end

		row.DoClick = function()
			if (self.crafting) then return end
			surface.PlaySound("buttons/button15.wav")
			self:SelectRecipe(recipe)
		end

		row:SetAlpha(0)
		row:AlphaTo(255, 0.25, count * 0.025)
		self.rows[#self.rows + 1] = row
	end

	if (count == 0) then
		local empty = self.list:Add("DPanel")
		empty:Dock(TOP)
		empty:SetTall(Sc(80))
		empty.Paint = function(s, w, h)
			draw.SimpleText("Ничего не найдено", "ixCraftText", Sc(2), Sc(30), C_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	if (first and (!self.selected or !visible[self.selected])) then
		self:SelectRecipe(first)
	end

	self:RefreshStates()
end

-- ---------------- центр: предмет ----------------
function PANEL:BuildStage(body)
	local stage = body:Add("DPanel")
	stage:Dock(FILL)
	self.stage = stage

	self.stageModel = stage:Add("DModelPanel")
	self.stageModel:SetMouseInputEnabled(false)

	stage.PerformLayout = function(s, w, h)
		local size = math.min(w * 0.85, h * 0.58)
		s.mpSize, s.mpY = size, Sc(6)
		self.stageModel:SetSize(size, size)
		self.stageModel:SetPos((w - size) / 2, s.mpY)
		s.lines = nil
	end

	stage.Paint = function(s, w, h)
		local now = CurTime()
		local recipe = self.selected
		local size, my = s.mpSize or Sc(400), s.mpY or 0
		local cx, cy = w / 2, my + size / 2
		local k = Ease((now - (self.switchTime or 0)) / 0.4)

		DrawGlow(cx, cy, size * 0.62, self.accent, 22)
		DrawArc(cx, cy, size * 0.52, 1, 0, 360, Color(255, 255, 255, 18), 100)

		local a = math.rad(now * 18)
		DrawCircle(cx + math.cos(a) * size * 0.52, cy + math.sin(a) * size * 0.52, Sc(3), ColorAlpha(self.accent, 220), 10)

		if (!recipe) then
			draw.SimpleText("Для этого верстака нет рецептов.", "ixCraftHeading", cx, cy, C_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			return
		end

		local y = my + size + Sc(34)
		local alpha = 255 * k
		local yo = Sc(14) * (1 - k)

		DrawSpaced(Up(recipe.category or ""), "ixCraftTiny", cx, y + yo, ColorAlpha(self.accent, alpha), 4, TEXT_ALIGN_CENTER)
		draw.SimpleText(recipe.name or recipe.id, "ixCraftTitle", cx, y + Sc(40) + yo, ColorAlpha(C_TEXT, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local names = {}
		for id, qty in pairs(recipe.result) do
			local it = ix.item.list[id]
			names[#names + 1] = (it and it.name or id) .. (qty > 1 and (" ×" .. qty) or "")
		end

		draw.SimpleText(table.concat(names, ", "), "ixCraftSmall", cx, y + Sc(76) + yo, ColorAlpha(C_SUB, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		if (!s.lines) then
			s.lines = ix.util.WrapText(recipe.description or "", math.min(w * 0.8, Sc(640)), "ixCraftText")
		end

		for i, line in ipairs(s.lines) do
			draw.SimpleText(line, "ixCraftText", cx, y + Sc(116) + (i - 1) * Sc(26) + yo, ColorAlpha(C_SUB, alpha * 0.9), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
end

-- ---------------- правая колонка: шанс, материалы, кнопка ----------------
function PANEL:BuildRight(body)
	local right = body:Add("DPanel")
	right:Dock(RIGHT)
	right:SetWide(math.max(Sc(420), ScrW() * 0.23))
	right:DockPadding(Sc(24), 0, 0, 0)
	right.Paint = function() end

	-- шанс
	local gauge = right:Add("DPanel")
	gauge:Dock(TOP)
	gauge:SetTall(Sc(352))
	gauge.Paint = function(s, w, h)
		local recipe = self.selected
		if (!recipe) then return end

		DrawSpaced(Up("Шанс успеха"), "ixCraftTiny", 0, Sc(14), C_DIM, 3, TEXT_ALIGN_LEFT)

		local base, skill, bench, total = PLUGIN:GetChanceBreakdown(LocalPlayer(), recipe)
		self.displayChance = Lerp(FrameTime() * 7, self.displayChance or 0, total)

		local col = ChanceColor(total)
		local cx, cy, r = w / 2, Sc(140), Sc(88)
		local frac = math.Clamp(self.displayChance / 100, 0.002, 1)

		DrawArc(cx, cy, r, Sc(6), 135, 405, Color(255, 255, 255, 18), 70)
		DrawArc(cx, cy, r, Sc(6), 135, 135 + 270 * frac, col, 70)

		local ka = math.rad(135 + 270 * frac)
		DrawGlow(cx + math.cos(ka) * (r - Sc(3)), cy + math.sin(ka) * (r - Sc(3)), Sc(16), col, 70)
		DrawCircle(cx + math.cos(ka) * (r - Sc(3)), cy + math.sin(ka) * (r - Sc(3)), Sc(5), C_TEXT, 14)

		draw.SimpleText(math.floor(self.displayChance + 0.5) .. "%", "ixCraftHuge", cx, cy - Sc(2), C_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local y = Sc(262)
		local function Row(label, value, vcol)
			draw.SimpleText(label, "ixCraftSmall", 0, y, C_SUB, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(value, "ixCraftSmall", w, y, vcol or C_TEXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			y = y + Sc(25)
		end

		Row("Рецепт", math.floor(base) .. "%")
		Row("Мастерство", "+" .. math.floor(skill * 10) / 10 .. "%", C_OK)
		if (bench != 0) then Row("Верстак", (bench > 0 and "+" or "") .. bench .. "%", bench > 0 and C_OK or C_BAD) end

		local mg = ix.config.Get("craftSkillBonus", 5)
		if (mg > 0) then Row("Мини-игра", "до +" .. mg * #PLUGIN.checkpoints .. "%", self.accent) end
	end
	self.gauge = gauge

	-- кнопка
	local bottom = right:Add("DPanel")
	bottom:Dock(BOTTOM)
	bottom:SetTall(Sc(112))
	bottom.Paint = function(s, w, h)
		if (self.reason and !self.canMake and !self.crafting) then
			draw.SimpleText(self.reason, "ixCraftSmall", w / 2, Sc(14), C_BAD, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		elseif (self.selected) then
			local time = (self.selected.time or 5) * ix.config.Get("craftTimeMultiplier", 1)
			draw.SimpleText("Время: " .. math.Round(time, 1) .. " с", "ixCraftSmall", w / 2, Sc(14), C_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	self.btnCraft = bottom:Add("DButton")
	StyleButton(self.btnCraft, "Создать", self.accent)
	self.btnCraft:Dock(BOTTOM)
	self.btnCraft:SetTall(Sc(62))
	self.btnCraft.DoClick = function() self:RequestCraft() end

	-- материалы
	self.ingScroll = right:Add("DScrollPanel")
	self.ingScroll:Dock(FILL)
	StyleScroll(self.ingScroll)
end

local function AddItemRow(parent, id, need, isTool, accent, index)
	local row = parent:Add("DPanel")
	row:Dock(TOP)
	row:DockMargin(0, 0, Sc(8), Sc(6))
	row:SetTall(Sc(58))

	local item = ix.item.list[id]
	local icon = row:Add("ixSpawnIcon")
	icon:SetPos(Sc(6), Sc(7))
	icon:SetSize(Sc(44), Sc(44))
	icon:SetMouseInputEnabled(false)
	if (item) then icon:SetModel(item.model, item.skin or 0) end

	row.fill = 0

	row.Paint = function(s, w, h)
		local inv = LocalInventory()
		local have = inv and inv:GetItemCount(id) or 0
		local ok = have >= need
		local col = ok and C_OK or C_BAD
		s.fill = Lerp(FrameTime() * 8, s.fill, math.min(1, have / need))

		surface.SetDrawColor(255, 255, 255, 5)
		surface.DrawRect(0, 0, w, h)

		draw.SimpleText(item and item.name or id, "ixCraftText", Sc(62), h / 2 - Sc(8), ok and C_TEXT or C_SUB, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(isTool and (ok and "есть" or "нет") or (have .. " / " .. need), "ixCraftSmall", w - Sc(12), h / 2 - Sc(8), col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		-- шкала наличия
		surface.SetDrawColor(255, 255, 255, 16)
		surface.DrawRect(Sc(62), h - Sc(14), w - Sc(74), 2)
		surface.SetDrawColor(col)
		surface.DrawRect(Sc(62), h - Sc(14), (w - Sc(74)) * s.fill, 2)
	end

	row:SetAlpha(0)
	row:AlphaTo(255, 0.25, 0.04 * index)

	return row
end

function PANEL:SelectRecipe(recipe)
	self.selected = recipe
	self.displayChance = 0
	self.switchTime = CurTime()
	self.ingRows = {}

	local item = ItemOf(recipe)

	SetupModel(self.stageModel, item)
	self.stageModel:SetAlpha(0)
	self.stageModel:AlphaTo(255, 0.35, 0)
	self.stage.lines = nil

	self.ingScroll:Clear()

	local function Label(text)
		local l = self.ingScroll:Add("DPanel")
		l:Dock(TOP)
		l:SetTall(Sc(34))
		l.Paint = function(s, w, h)
			DrawSpaced(Up(text), "ixCraftTiny", Sc(2), h - Sc(10), C_DIM, 3, TEXT_ALIGN_LEFT)
		end
	end

	Label("Материалы")

	local n = 0
	for id, qty in SortedPairs(recipe.ingredients) do
		n = n + 1
		local row = AddItemRow(self.ingScroll, id, qty, false, self.accent, n)
		self.ingRows[#self.ingRows + 1] = {id = id, panel = row}
	end

	if (recipe.tools and #recipe.tools > 0) then
		Label("Инструменты — не расходуются")

		for _, id in ipairs(recipe.tools) do
			n = n + 1
			AddItemRow(self.ingScroll, id, 1, true, self.accent, n)
		end
	end

	self:RefreshStates()
end

function PANEL:RefreshStates()
	for _, row in ipairs(self.rows) do
		if (IsValid(row)) then
			row.canMake, row.reason = PLUGIN:CanCraft(LocalPlayer(), row.recipe)
		end
	end

	if (self.btnCraft and self.selected) then
		self.canMake, self.reason = PLUGIN:CanCraft(LocalPlayer(), self.selected)
		self.btnCraft:SetEnabled(self.canMake and !self.crafting)
	end
end

-- ---------------- крафт ----------------
function PANEL:RequestCraft()
	if (self.crafting or self.pending or !self.selected) then return end
	if (!PLUGIN:CanCraft(LocalPlayer(), self.selected)) then return end

	self.pending = true
	net.Start("ixCraftRequest")
		net.WriteEntity(self.entity)
		net.WriteString(self.selected.id)
	net.SendToServer()
end

function PANEL:StartCraft(recipeID, duration)
	local recipe = PLUGIN.recipes[recipeID]
	if (!recipe) then return end

	self.pending = false
	self.crafting = true
	self.btnCraft:SetEnabled(false)

	self.overlay = vgui.Create("ixCraftOverlay", self)
	self.overlay:SetPos(0, 0)
	self.overlay:SetSize(self:GetSize())
	self.overlay:SetZPos(100)
	self.overlay:Setup(self, recipe, duration)
end

function PANEL:EndCraft()
	self.crafting = false
	self.pending = false

	if (IsValid(self.overlay)) then
		self.overlay:Remove()
	end

	self:RefreshStates()
end

function PANEL:Think()
	if (CurTime() >= self.nextRefresh) then
		self.nextRefresh = CurTime() + 0.4
		self:RefreshStates()

		if (!IsValid(self.entity) or (!self.crafting and
		LocalPlayer():GetPos():Distance(self.entity:GetPos()) > ix.config.Get("craftMaxDistance", 160) + 64)) then
			self:Remove()
		end
	end
end

function PANEL:OnKeyCodePressed(key)
	if (self.crafting and IsValid(self.overlay)) then
		self.overlay:OnKeyCodePressed(key)
		if (key == KEY_SPACE) then self.overlay:Hit() end
	elseif (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function PANEL:OnRemove()
	if (self.crafting and IsValid(self.overlay) and self.overlay.result == nil) then
		net.Start("ixCraftCancel")
		net.SendToServer()
	end

	if (ix.gui.craftMenu == self) then ix.gui.craftMenu = nil end
end

function PANEL:Paint(w, h)
	if (ix.util.DrawBlur) then
		ix.util.DrawBlur(self, Sc(8))
	end

	surface.SetDrawColor(8, 10, 14, 236)
	surface.DrawRect(0, 0, w, h)

	if (self.accent) then
		DrawGlow(w * 0.5, h * 0.42, h * 0.62, self.accent, 12)
	end
end

vgui.Register("ixCraftMenu", PANEL, "EditablePanel")

-- =====================================================================
--  СЕТЬ
-- =====================================================================
net.Receive("ixCraftOpen", function()
	local ent = net.ReadEntity()
	if (!IsValid(ent)) then return end

	local menu = vgui.Create("ixCraftMenu")
	menu:Setup(ent)
end)

net.Receive("ixCraftBegin", function()
	local id, duration = net.ReadString(), net.ReadFloat()

	if (IsValid(ix.gui.craftMenu)) then
		ix.gui.craftMenu:StartCraft(id, duration)
	end
end)

net.Receive("ixCraftResult", function()
	local success = net.ReadBool()
	net.ReadString()
	local chance, bonus = net.ReadFloat(), net.ReadFloat()
	local menu = ix.gui.craftMenu

	if (IsValid(menu) and IsValid(menu.overlay)) then
		menu.overlay:ShowResult(success, chance, bonus)
	end
end)

net.Receive("ixCraftAbort", function()
	local reason = net.ReadString()
	local menu = ix.gui.craftMenu

	if (IsValid(menu)) then
		menu:EndCraft()
	end

	if (reason != "") then
		surface.PlaySound("buttons/button10.wav")
	end
end)