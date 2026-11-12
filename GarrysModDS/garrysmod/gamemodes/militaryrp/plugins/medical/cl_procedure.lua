--[[
	ПРОЦЕДУРЫ ЛЕЧЕНИЯ — интерактивные мини-игры (стиль как у обыска трупа в persists).

	Сервер присылает id процедуры и конечность (ixMedProcBegin), здесь открывается полноэкранная панель.
	Процедура — это список шагов из config.procedures[id].steps. Типы шагов:
		hold    — зажать ЛКМ на отмеченной точке, пока не заполнится кольцо (прижать повязку, сделать виток, привязать шину)
		tension — удерживать ЛКМ, пока растёт натяжение, и отпустить в зелёной зоне (затянуть жгут)
		align   — нажать ЛКМ, когда стрелка в зелёной зоне (совместить отломки кости)
		stitch  — нажимать ЛКМ по точке в момент, когда кольцо сожмётся (накладывать швы)

	Итог (число ошибок) отправляется на сервер (ixMedProcDone), сервер сам считает качество и применяет эффект.
	Отмена (ПКМ / ESC) ничего не расходует.
]]

local config = ix.medical.config
local limbsByID = ix.medical.limbsByID

local COLOR_DONE = Color(120, 200, 120)
local COLOR_BAD = Color(225, 85, 80)
local COLOR_TEXT = Color(190, 190, 190)
local COLOR_LIMB = Color(62, 70, 80)

local function GetAccent()
	local style = ix.menuStyle

	return (style and style.accent) or ix.config.Get("color") or Color(90, 160, 235)
end

--[[ рисование ]]
local function DrawDisk(x, y, radius, color)
	local points = {}

	for i = 0, 31 do
		local angle = math.rad(i * 360 / 32)
		points[#points + 1] = {x = x + math.cos(angle) * radius, y = y + math.sin(angle) * radius}
	end

	draw.NoTexture()
	surface.SetDrawColor(color)
	surface.DrawPoly(points)
end

-- углы в градусах, 0 — сверху, по часовой стрелке
local function DrawArc(x, y, radius, thickness, startAng, endAng, color)
	local segments = math.max(4, math.floor(math.abs(endAng - startAng) / 6))
	local step = (endAng - startAng) / segments
	local inner = radius - thickness

	draw.NoTexture()
	surface.SetDrawColor(color)

	for i = 0, segments - 1 do
		local a1 = math.rad(startAng + step * i - 90)
		local a2 = math.rad(startAng + step * (i + 1) - 90)
		local c1, s1, c2, s2 = math.cos(a1), math.sin(a1), math.cos(a2), math.sin(a2)

		surface.DrawPoly({
			{x = x + c1 * radius, y = y + s1 * radius},
			{x = x + c2 * radius, y = y + s2 * radius},
			{x = x + c2 * inner, y = y + s2 * inner},
			{x = x + c1 * inner, y = y + s1 * inner}
		})
	end
end

local function DrawFade(x, y, width, height, alpha, fromBottom)
	local steps = 32
	local stepHeight = math.ceil(height / steps)

	for i = 0, steps - 1 do
		surface.SetDrawColor(0, 0, 0, alpha * (1 - i / steps) ^ 2)

		if (fromBottom) then
			surface.DrawRect(x, y + height - (i + 1) * stepHeight, width, stepHeight)
		else
			surface.DrawRect(x, y + i * stepHeight, width, stepHeight)
		end
	end
end

local function DrawCheck(x, y, size, color)
	surface.SetDrawColor(color)

	local x1, y1 = x - size * 0.45, y + size * 0.02
	local x2, y2 = x - size * 0.1, y + size * 0.38
	local x3, y3 = x + size * 0.5, y - size * 0.36

	for offset = -1, 1 do
		surface.DrawLine(x1, y1 + offset, x2, y2 + offset)
		surface.DrawLine(x2, y2 + offset, x3, y3 + offset)
	end
end

-- размеры конечности на экране (доля высоты экрана)
local GEOMETRY = {
	arm = {w = 0.12, h = 0.60},
	leg = {w = 0.14, h = 0.64},
	torso = {w = 0.32, h = 0.40},
	head = {w = 0.20, h = 0.26}
}

local HINTS = {
	hold = "ЛКМ (удерживать) — выполнить действие     ПКМ / ESC — прекратить",
	tension = "ЛКМ (удерживать) — затягивать, отпустить в зелёной зоне     ПКМ / ESC — прекратить",
	align = "ЛКМ — когда стрелка в зелёной зоне     ПКМ / ESC — прекратить",
	stitch = "ЛКМ по точке — когда кольцо сожмётся     ПКМ / ESC — прекратить"
}

local PANEL = {}

function PANEL:Init()
	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:SetAlpha(0)
	self:AlphaTo(255, 0.3, 0)
	self:MakePopup()

	self.stepIndex = 1
	self.state = {}
	self.done = {}
	self.mistakes = 0
	self.flash = 0
	self.boneOff = 1
	self.closing = false
	self.finished = false
	self.nextRustle = 0
	-- если кнопка уже зажата (отпустили перетаскивание), это не считается нажатием
	self.wasDown = input.IsMouseDown(MOUSE_LEFT)
	self:UpdateGeometry()
end

function PANEL:Setup(procID, limbID)
	self.proc = config.procedures and config.procedures[procID]
	self.limb = limbsByID[limbID]
	self.geo = GEOMETRY[self.limb and self.limb.group or "arm"]
	self.rules = config.procedureRules or {maxMistakes = 6}

	if (!self.proc) then
		self:Close(true)

		return
	end

	for _, step in ipairs(self.proc.steps) do
		if (step.type == "align") then
			self.hasBone = true

			break
		end
	end

	self:InitStep()
end

function PANEL:UpdateGeometry()
	local geo = self.geo or GEOMETRY.arm
	local W, H = ScrW(), ScrH()

	self.scale = H / 1080
	self.lw = geo.w * H
	self.lh = geo.h * H
	self.cx = W * 0.5
	self.top = H * 0.5 - self.lh * 0.5 + H * 0.04
end

-- u: 0..1 сверху вниз по конечности, v: -1..1 слева направо
function PANEL:Pos(u, v)
	return self.cx + (v or 0) * self.lw * 0.5, self.top + (u or 0.5) * self.lh
end

function PANEL:InitStep()
	local step = self.proc.steps[self.stepIndex]
	local st = {}

	if (step) then
		if (step.type == "hold") then
			st.progress = 0
		elseif (step.type == "tension") then
			st.value = 0
			st.held = false
			st.needRelease = false
		elseif (step.type == "align") then
			st.t = math.Rand(0, 6)
			st.hits = step.hits or 1
			st.zone = math.Rand(0.3, 0.7)
		elseif (step.type == "stitch") then
			st.i = 1
			st.t = -0.5 -- небольшая пауза перед каждым швом
		end
	end

	self.state = st
end

function PANEL:Mistake(text)
	self.mistakes = self.mistakes + 1
	self.flash = 1
	self.message = {text = text or "Ошибка", till = CurTime() + 1.3}

	surface.PlaySound("buttons/button10.wav")

	if (self.mistakes >= (self.rules.maxMistakes or 6)) then
		self:Finish(true)
	end
end

function PANEL:CompleteStep()
	self.done[self.stepIndex] = true
	self.stepIndex = self.stepIndex + 1

	surface.PlaySound("ui/buttonclickrelease.wav")

	if (self.stepIndex > #self.proc.steps) then
		self:Finish(false)
	else
		self:InitStep()
	end
end

function PANEL:Finish(failed)
	if (self.finished) then
		return
	end

	self.finished = true
	self.failed = failed
	self.closeAt = CurTime() + 0.9

	net.Start("ixMedProcDone")
		net.WriteUInt(math.min(self.mistakes, 15), 4)
		net.WriteBool(failed and true or false)
	net.SendToServer()
end

function PANEL:Close(cancel)
	if (self.closing) then
		return
	end

	self.closing = true

	if (cancel and !self.finished) then
		net.Start("ixMedProcCancel")
		net.SendToServer()
	end

	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
	self:AlphaTo(0, 0.25, 0, function()
		if (IsValid(self)) then
			self:Remove()
		end
	end)
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		gui.HideGameUI()
		self:Close(true)
	end
end

function PANEL:OnMousePressed(code)
	if (code == MOUSE_RIGHT) then
		self:Close(true)
	end
end

function PANEL:Rustle(client)
	if (CurTime() >= self.nextRustle) then
		self.nextRustle = CurTime() + math.Rand(0.22, 0.45)
		client:EmitSound("physics/cardboard/cardboard_box_impact_soft" .. math.random(1, 7) .. ".wav",
			50, math.random(90, 115), 0.45, CHAN_ITEM)
	end
end

-- позиция i-го шва (точки идут вдоль раны)
function PANEL:StitchPos(step, index)
	local count = math.max(step.count or 5, 2)
	local span = step.span or 0.36
	local u = 0.5 - span * 0.5 + span * (index - 1) / (count - 1)

	return self:Pos(u, step.v or 0)
end

function PANEL:Think()
	if (self.closing) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive()) then
		self:Close(true)

		return
	end

	if (self.finished) then
		if (CurTime() >= self.closeAt) then
			self:Close(false)
		end

		return
	end

	self:UpdateGeometry()

	local dt = FrameTime()
	local s = self.scale
	local down = input.IsMouseDown(MOUSE_LEFT)
	local edge = down and !self.wasDown -- нажали именно сейчас
	local mx, my = self:CursorPos()
	local step = self.proc.steps[self.stepIndex]
	local st = self.state
	local hover = false

	if (step.type == "hold") then
		local x, y = self:Pos(step.u, step.v)
		local radius = (step.radius or 24) * s
		local dist = (x - mx) ^ 2 + (y - my) ^ 2

		hover = dist < (radius * 1.15) ^ 2

		if (edge and hover) then
			st.active = true
		end

		if (!down) then
			st.active = false
		end

		if (st.active) then
			-- рука соскользнула — действие прервано
			if (dist > (radius * 2) ^ 2) then
				st.active = false
			else
				st.progress = math.min(st.progress + dt * (ix.medical.GetSelfHealMultiplier and ix.medical.GetSelfHealMultiplier(client) or 1) / (step.time or 1), 1)
				self:Rustle(client)

				if (st.progress >= 1) then
					self:CompleteStep()
				end
			end
		end

		if (!st.active and !self.finished and self.state == st) then
			st.progress = math.max(st.progress - dt * 1.5 / (step.time or 1), 0)
		end
	elseif (step.type == "tension") then
		local zone = step.zone or {0.55, 0.8}

		if (st.needRelease) then
			if (!down) then
				st.needRelease = false
			end
		elseif (down and (st.held or !self.wasDown)) then
			st.held = true
			st.value = st.value + dt * (step.speed or 0.45)
			self:Rustle(client)

			if (st.value >= 1) then
				-- перетянули
				st.value = 0
				st.held = false
				st.needRelease = true
				self:Mistake("Перетянули")
			end
		elseif (st.held) then
			st.held = false

			if (st.value >= zone[1] and st.value <= zone[2]) then
				self:CompleteStep()
			elseif (st.value > zone[2]) then
				st.value = 0
				self:Mistake("Слишком туго")
			end
			-- слишком слабо: можно затянуть ещё, натяжение медленно спадает
		end

		if (!st.held and self.state == st) then
			st.value = math.max(st.value - dt * 0.5, 0)
		end
	elseif (step.type == "align") then
		st.t = st.t + dt * (step.speed or 1.7)

		local needle = 0.5 + 0.5 * math.sin(st.t)
		local width = step.width or 0.16

		if (edge) then
			if (math.abs(needle - st.zone) <= width * 0.5) then
				st.hits = st.hits - 1
				st.zone = math.Rand(0.25, 0.75)
				surface.PlaySound("physics/body/body_medium_impact_hard" .. math.random(1, 6) .. ".wav")

				if (st.hits <= 0) then
					self:CompleteStep()
				end
			else
				self:Mistake("Не совпало")
			end
		end
	elseif (step.type == "stitch") then
		local window = step.window or 1.15

		st.t = st.t + dt

		if (st.t >= window) then
			-- кольцо сжалось, а шов не сделан
			st.t = -0.5
			self:Mistake("Пропустили шов")
		elseif (edge and st.t >= 0) then
			local x, y = self:StitchPos(step, st.i)
			local radius = (step.radius or 24) * s

			if ((x - mx) ^ 2 + (y - my) ^ 2 < (radius * 1.7) ^ 2) then
				if (st.t / window >= 0.68) then
					st.i = st.i + 1
					st.t = -0.5
					client:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(1, 4) .. ".wav", 50, math.random(95, 115), 0.5)

					if (st.i > (step.count or 5)) then
						self:CompleteStep()
					end
				else
					st.t = -0.5
					self:Mistake("Не в ритм")
				end
			end
		end

		hover = true
	end

	self:SetCursor((hover or step.type == "stitch") and "hand" or "arrow")

	self.wasDown = down
	self.flash = math.max(self.flash - dt * 2, 0)

	-- сломанная кость сходится по мере совмещения
	if (self.hasBone) then
		local target = 0

		for i, other in ipairs(self.proc.steps) do
			if (other.type == "align") then
				if (self.done[i]) then
					target = 0
				elseif (i == self.stepIndex) then
					target = (self.state.hits or 1) / (other.hits or 1)
				else
					target = 1
				end

				break
			end
		end

		self.boneOff = Lerp(math.min(dt * 6, 1), self.boneOff, target)
	end
end

--[[ отметки на конечности: пад, виток, шина ]]
function PANEL:DrawMark(kind, u, v, color, alpha)
	local x, y = self:Pos(u, v)
	local s, H = self.scale, ScrH()

	surface.SetDrawColor(color.r, color.g, color.b, 235 * alpha)

	if (kind == "band") then
		surface.DrawRect(self.cx - self.lw * 0.5 - 5 * s, y - 0.016 * H, self.lw + 10 * s, 0.032 * H)
		surface.SetDrawColor(0, 0, 0, 60 * alpha)
		surface.DrawRect(self.cx - self.lw * 0.5 - 5 * s, y + 0.012 * H, self.lw + 10 * s, 0.004 * H)
	elseif (kind == "strap") then
		surface.DrawRect(self.cx - self.lw * 0.5 - 6 * s, y - 0.008 * H, self.lw + 12 * s, 0.016 * H)
	elseif (kind == "pad") then
		local r = 0.04 * H

		surface.DrawRect(x - r, y - r, r * 2, r * 2)
		surface.SetDrawColor(0, 0, 0, 50 * alpha)
		surface.DrawOutlinedRect(x - r, y - r, r * 2, r * 2, 1)
	elseif (kind == "board") then
		local bw = self.lw * 0.17

		surface.DrawRect(x - bw * 0.5, self.top + self.lh * 0.06, bw, self.lh * 0.88)
		surface.SetDrawColor(0, 0, 0, 70 * alpha)
		surface.DrawOutlinedRect(x - bw * 0.5, self.top + self.lh * 0.06, bw, self.lh * 0.88, 1)
	end
end

-- маркер текущего шага
function PANEL:DrawMarker(x, y, radius, progress, hovered, accent)
	local s = self.scale
	local pulse = math.sin(CurTime() * 3) * 0.5 + 0.5
	local thin = math.max(2, 2 * s)
	local thick = math.max(3, 5 * s)

	DrawDisk(x, y, radius, Color(0, 0, 0, hovered and 150 or 100))

	if (hovered) then
		DrawArc(x, y, radius, thin + 1, 0, 360, accent)
	else
		DrawArc(x, y, radius, thin, 0, 360, Color(255, 255, 255, 90 + pulse * 80))
		DrawArc(x, y, radius + pulse * 10 * s, math.max(1, 1.5 * s), 0, 360, Color(255, 255, 255, (1 - pulse) * 70))
	end

	DrawDisk(x, y, 3.5 * s + (hovered and 1 or 0), Color(255, 255, 255, 220))

	if (progress and progress > 0) then
		DrawArc(x, y, radius + thick * 0.5, thick, 0, 360, Color(255, 255, 255, 35))
		DrawArc(x, y, radius + thick * 0.5, thick, 0, 360 * progress, accent)
	end
end

function PANEL:Paint(width, height)
	if (!self.proc) then
		return
	end

	local s = self.scale
	local accent = GetAccent()
	local steps = self.proc.steps
	local total = #steps
	local H = height
	local lw, lh, cx, top = self.lw, self.lh, self.cx, self.top
	local left = cx - lw * 0.5
	local mx, my = self:CursorPos()

	surface.SetDrawColor(0, 0, 0, 90)
	surface.DrawRect(0, 0, width, height)

	DrawFade(0, 0, width, 260 * s, 190, false)
	DrawFade(0, height - 200 * s, width, 200 * s, 190, true)

	-- заголовок
	draw.SimpleText(self.proc.title or "ЛЕЧЕНИЕ", "ixBigFont", width / 2, 64 * s, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 255)
	surface.DrawRect(width / 2 - 70 * s, 94 * s, 140 * s, math.max(2, 2 * s))

	draw.SimpleText(self.limb and self.limb.name or "", "ixSmallFont", width / 2, 114 * s, COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local current = steps[math.min(self.stepIndex, total)]

	draw.SimpleText(self.finished and "" or (current.label or ""), "ixMediumFont", width / 2, 148 * s, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	-- прогресс по шагам
	local segW, segH, gap = 44 * s, math.max(3, 4 * s), 8 * s
	local startX = width / 2 - (total * segW + (total - 1) * gap) / 2

	for i = 1, total do
		local sx = startX + (i - 1) * (segW + gap)
		local fill = 0

		if (self.done[i]) then
			fill = 1
		elseif (i == self.stepIndex and self.state.progress) then
			fill = self.state.progress
		end

		surface.SetDrawColor(255, 255, 255, 40)
		surface.DrawRect(sx, 182 * s, segW, segH)

		if (fill > 0) then
			surface.SetDrawColor(self.done[i] and COLOR_DONE or accent)
			surface.DrawRect(sx, 182 * s, segW * fill, segH)
		end
	end

	-- ошибки
	local maxMistakes = self.rules.maxMistakes or 6
	local dotGap = 14 * s
	local dotX = width / 2 - (maxMistakes - 1) * dotGap / 2

	for i = 1, maxMistakes do
		DrawDisk(dotX + (i - 1) * dotGap, 206 * s, 3.5 * s,
			i <= self.mistakes and COLOR_BAD or Color(255, 255, 255, 40))
	end

	-- конечность
	local rad = math.min(lw, lh) * 0.35

	draw.RoundedBox(rad, left, top, lw, lh, Color(accent.r, accent.g, accent.b, 90))
	draw.RoundedBox(rad, left + 2, top + 2, lw - 4, lh - 4, COLOR_LIMB)

	-- сломанная кость
	if (self.hasBone) then
		local off = self.boneOff * 0.07 * H
		local bw = math.max(5 * s, 4)
		local y1, ym, y2 = top + lh * 0.1, top + lh * 0.5, top + lh * 0.9

		surface.SetDrawColor(236, 230, 214, 255)
		surface.DrawRect(cx - bw * 0.5, y1, bw, ym - y1)
		surface.DrawRect(cx + off - bw * 0.5, ym, bw, y2 - ym)

		if (math.abs(off) > 2) then
			for k = -1, 1 do
				surface.DrawLine(cx + k, ym, cx + off + k, ym + 3)
			end

			surface.SetDrawColor(COLOR_BAD.r, COLOR_BAD.g, COLOR_BAD.b, 200 * math.min(self.boneOff * 2, 1))
			surface.DrawRect(cx - bw * 1.4, ym - 2 * s, bw * 2.8 + off, 3 * s)
		end
	end

	-- рана (бледнеет по мере лечения)
	if (self.proc.wound) then
		local doneCount = 0

		for i = 1, total do
			if (self.done[i]) then
				doneCount = doneCount + 1
			end
		end

		local fade = 1 - doneCount / total
		local wx, wy = self:Pos(0.5, 0)

		DrawDisk(wx, wy, 0.046 * H, Color(150, 26, 26, 235 * fade))
		DrawDisk(wx, wy, 0.028 * H, Color(95, 12, 12, 235 * fade))
	end

	-- уже сделанные шаги: повязки, шины, швы
	for i, step in ipairs(steps) do
		local color = step.color or self.proc.color or Color(235, 235, 225)

		if (step.type == "hold" and step.mark) then
			local alpha

			if (self.done[i]) then
				alpha = 1
			elseif (i == self.stepIndex and self.state.progress and self.state.progress > 0) then
				alpha = self.state.progress * 0.8
			end

			if (alpha) then
				self:DrawMark(step.mark, step.u, step.v, color, alpha)
			end
		elseif (step.type == "stitch") then
			local count = step.count or 5

			for j = 1, count do
				if (self.done[i] or (i == self.stepIndex and j < self.state.i)) then
					local x, y = self:StitchPos(step, j)
					local len = 0.034 * H

					surface.SetDrawColor(20, 20, 20, 255)

					for k = -1, 1 do
						surface.DrawLine(x - len, y + k, x + len, y + k)
					end

					surface.DrawLine(x - len, y - 5 * s, x - len, y + 5 * s)
					surface.DrawLine(x + len, y - 5 * s, x + len, y + 5 * s)
				end
			end
		end
	end

	-- текущий шаг
	if (!self.finished) then
		local step = steps[self.stepIndex]
		local st = self.state

		if (step.type == "hold") then
			local x, y = self:Pos(step.u, step.v)
			local radius = (step.radius or 24) * s
			local hovered = st.active or ((x - mx) ^ 2 + (y - my) ^ 2 < (radius * 1.15) ^ 2)

			self:DrawMarker(x, y, radius * (st.active and 1.15 or 1), st.progress, hovered, accent)
		elseif (step.type == "tension") then
			local zone = step.zone or {0.55, 0.8}
			local gx, gy = cx + lw * 0.5 + 130 * s, top + lh * 0.1
			local gw, gh = 28 * s, lh * 0.8
			local inZone = st.value >= zone[1] and st.value <= zone[2]

			surface.SetDrawColor(0, 0, 0, 170)
			surface.DrawRect(gx - 4, gy - 4, gw + 8, gh + 8)

			surface.SetDrawColor(255, 255, 255, 30)
			surface.DrawRect(gx, gy, gw, gh)

			surface.SetDrawColor(COLOR_DONE.r, COLOR_DONE.g, COLOR_DONE.b, 90)
			surface.DrawRect(gx, gy + gh * (1 - zone[2]), gw, gh * (zone[2] - zone[1]))

			local fillColor = inZone and COLOR_DONE or accent

			surface.SetDrawColor(fillColor.r, fillColor.g, fillColor.b, 255)
			surface.DrawRect(gx, gy + gh * (1 - st.value), gw, gh * st.value)

			draw.SimpleText("НАТЯЖЕНИЕ", "ixSmallFont", gx + gw * 0.5, gy + gh + 18 * s, COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		elseif (step.type == "align") then
			local tw = 460 * s
			local tx, ty = cx - tw * 0.5, top + lh + 56 * s
			local width2 = step.width or 0.16
			local needle = 0.5 + 0.5 * math.sin(st.t)

			surface.SetDrawColor(0, 0, 0, 170)
			surface.DrawRect(tx - 4, ty - 4, tw + 8, 22 * s + 8)

			surface.SetDrawColor(255, 255, 255, 30)
			surface.DrawRect(tx, ty, tw, 22 * s)

			surface.SetDrawColor(COLOR_DONE.r, COLOR_DONE.g, COLOR_DONE.b, 150)
			surface.DrawRect(tx + tw * (st.zone - width2 * 0.5), ty, tw * width2, 22 * s)

			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawRect(tx + tw * needle - 2, ty - 8 * s, 4, 22 * s + 16 * s)

			if ((step.hits or 1) > 1) then
				draw.SimpleText(st.hits .. " ост.", "ixSmallFont", cx, ty + 44 * s, COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		elseif (step.type == "stitch") then
			local x, y = self:StitchPos(step, st.i)
			local radius = (step.radius or 24) * s
			local window = step.window or 1.15
			local p = math.Clamp(st.t / window, 0, 1)

			self:DrawMarker(x, y, radius, nil, true, accent)

			if (st.t >= 0) then
				local ready = p >= 0.68
				local color = ready and COLOR_DONE or Color(255, 255, 255, 220)

				DrawArc(x, y, radius * (1 + 1.6 * (1 - p)), math.max(2, 3 * s), 0, 360, color)
			end

			draw.SimpleText(st.i .. " / " .. (step.count or 5), "ixSmallFont", x + radius + 18 * s, y, COLOR_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	-- сообщение об ошибке
	if (self.message and CurTime() < self.message.till) then
		draw.SimpleText(self.message.text, "ixMediumFont", width / 2, top + lh + 120 * s, COLOR_BAD, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	-- подсказка
	local hint = self.finished and "" or HINTS[steps[math.min(self.stepIndex, total)].type] or ""

	draw.SimpleText(hint, "ixSmallFont", width / 2, height - 70 * s, COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	-- красная вспышка при ошибке
	if (self.flash > 0) then
		surface.SetDrawColor(COLOR_BAD.r, COLOR_BAD.g, COLOR_BAD.b, 70 * self.flash)
		surface.DrawRect(0, 0, width, height)
	end

	-- итог
	if (self.finished) then
		local text, color

		if (self.failed) then
			text, color = "НЕ ПОЛУЧИЛОСЬ", COLOR_BAD
		elseif (self.mistakes == 0) then
			text, color = "ИДЕАЛЬНО", COLOR_DONE
		elseif (self.mistakes <= 2) then
			text, color = "ГОТОВО", COLOR_DONE
		else
			text, color = "ГОТОВО, НО НЕАККУРАТНО", Color(235, 200, 90)
		end

		draw.SimpleText(text, "ixBigFont", width / 2, height / 2, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("ixMedicalProcedure", PANEL, "EditablePanel")

net.Receive("ixMedProcBegin", function()
	local procID, limbID = net.ReadString(), net.ReadString()

	if (IsValid(ix.medical.procPanel)) then
		ix.medical.procPanel:Remove()
	end

	ix.medical.procPanel = vgui.Create("ixMedicalProcedure")
	ix.medical.procPanel:Setup(procID, limbID)
end)

-- сервер прервал процедуру (вас ранили, вы погибли)
net.Receive("ixMedProcStop", function()
	if (IsValid(ix.medical.procPanel)) then
		ix.medical.procPanel:Close(false)
	end
end)