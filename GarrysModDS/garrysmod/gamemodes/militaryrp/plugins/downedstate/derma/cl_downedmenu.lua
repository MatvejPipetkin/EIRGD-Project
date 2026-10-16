local PANEL = {}

local HOLD_TIME = 1.6 -- сколько секунд нужно удерживать кнопку «Умереть»

local function UI()
	return ix.downedUI
end

local function SendChoice(die)
	net.Start("ixDownChoice")
		net.WriteBool(die)
	net.SendToServer()
end

local function IsBusy()
	local client = LocalPlayer()

	return IsValid(client) and client:GetNetVar("ixDownRescued", false)
end

--[[
	Оформление кнопки в стиле меню персонажа: плашка с рамкой, заливка и блик
	при наведении, маркер слева, скобки справа, шевроны вокруг текста.
	def.color — цвет кнопки, def.title/def.sub — функции, возвращающие тексты,
	def.hold — если задано, кнопку нужно удерживать столько секунд.
]]
local function StyleButton(button, def)
	button.hoverFrac = 0
	button.pressFrac = 0
	button.holdFrac = 0
	button.reveal = 0
	button.holding = false

	button:SetText("")

	button.OnCursorEntered = function(this)
		this.shineStart = RealTime()

		if (!IsBusy()) then
			UI().PlayUI("hover", math.Rand(0.96, 1.06))
		end
	end

	button.OnCursorExited = function(this)
		this.holding = false
	end

	button.OnMousePressed = function(this, code)
		if (code != MOUSE_LEFT or this.reveal < 0.9) then return end

		if (IsBusy()) then
			UI().PlayUI("deny")
			return
		end

		UI().PlayUI("click")
		this.pressFrac = 1

		if (def.hold) then
			this.holding = true
			this.holdStart = RealTime()
			this.nextTick = 0.3
		else
			def.onActivate(this)
		end
	end

	button.OnMouseReleased = function(this, code)
		if (code == MOUSE_LEFT) then
			this.holding = false
		end
	end

	button.Think = function(this)
		local dt = math.min(RealFrameTime() * 10, 1)

		if (this.holding) then
			if (!input.IsMouseDown(MOUSE_LEFT) or IsBusy()) then
				this.holding = false
			else
				local held = RealTime() - this.holdStart

				this.holdFrac = math.Clamp(held / def.hold, 0, 1)

				if (held >= this.nextTick and this.holdFrac < 1) then
					UI().PlayUI("tick", 0.9 + this.holdFrac * 0.5, 0.8)
					this.nextTick = this.nextTick + 0.3
				end

				if (this.holdFrac >= 1) then
					this.holding = false
					UI().PlayUI("confirm")
					def.onActivate(this)
				end

				return
			end
		end

		this.holdFrac = Lerp(dt, this.holdFrac, 0)
	end

	button.Paint = function(this, w, h)
		local busy = IsBusy()
		local k = busy and 0.35 or 1
		local target = (!busy and this:IsHovered()) and 1 or 0
		local c = def.color
		local now = RealTime()

		this.hoverFrac = Lerp(math.min(RealFrameTime() * 14, 1), this.hoverFrac, target)
		this.pressFrac = Lerp(math.min(RealFrameTime() * 7, 1), this.pressFrac, 0)

		local f = this.hoverFrac
		local ef = UI().EaseOutCubic(f)
		local pf = this.pressFrac
		local ww = math.floor(w * UI().EaseOutCubic(this.reveal))
		local y, bh = 3, h - 6

		if (ww < 4) then return true end

		draw.NoTexture()

		-- тёмная подложка + тонированная плашка
		surface.SetDrawColor(7, 10, 15, 200)
		surface.DrawRect(0, y, ww, bh)

		surface.SetDrawColor(c.r, c.g, c.b, (16 + 34 * f) * k)
		surface.DrawRect(0, y, ww, bh)

		-- заливка, выезжающая слева при наведении
		if (ef > 0.01) then
			surface.SetDrawColor(c.r, c.g, c.b, 40 * ef * k)
			surface.DrawRect(0, y, math.floor(ww * ef), bh)
		end

		-- заливка удержания
		if (this.holdFrac > 0.002) then
			local hw = math.floor(ww * this.holdFrac)

			surface.SetDrawColor(c.r, c.g, c.b, 120)
			surface.DrawRect(0, y, hw, bh)
			surface.SetDrawColor(255, 255, 255, 230)
			surface.DrawRect(math.max(hw - 2, 0), y, 2, bh)
		end

		-- одиночный блик при наведении
		if (f > 0.05 and !busy) then
			local st = (now - (this.shineStart or now)) * 1.7

			if (st < 1) then
				local sx = math.floor(-40 + (ww + 80) * UI().EaseOutCubic(st))

				for i = 0, 7 do
					local x = sx + i * 5

					if (x >= 0 and x < ww) then
						surface.SetDrawColor(255, 255, 255, 38 * math.sin((i + 0.5) / 8 * math.pi) * f)
						surface.DrawRect(x, y, 5, bh)
					end
				end
			end
		end

		-- рамка с «дыханием»
		local breathe = 0.5 + 0.5 * math.sin(now * 1.6 + h)

		surface.SetDrawColor(c.r, c.g, c.b, (104 + 8 * breathe + 108 * f) * k)
		surface.DrawOutlinedRect(0, y, ww, bh, 1)

		-- маркер слева
		surface.SetDrawColor(255, 255, 255, (70 + 185 * f) * k)
		surface.DrawRect(0, y, 4 + math.floor(3 * ef), bh)

		-- скобки справа
		if (ef > 0.02 and ww > 24) then
			local bl = math.floor(10 * ef)

			surface.SetDrawColor(255, 255, 255, 200 * ef * k)
			surface.DrawRect(ww - bl - 1, y, bl, 2)
			surface.DrawRect(ww - 2, y, 2, bl)
			surface.DrawRect(ww - bl - 1, y + bh - 2, bl, 2)
			surface.DrawRect(ww - 2, y + bh - bl, 2, bl)
		end

		if (pf > 0.01) then
			surface.SetDrawColor(255, 255, 255, 70 * pf * k)
			surface.DrawRect(0, y, ww, bh)
		end

		-- тексты (проявляются вместе с плашкой)
		local ta = math.Clamp((this.reveal - 0.5) / 0.5, 0, 1)

		if (ta > 0.01) then
			local title = def.title()
			local sub = busy and L("dnBtnBusy") or def.sub()
			local tx = w * 0.5 + 3
			local ty = h * 0.38 + pf

			surface.SetFont("ixDownMid")

			local tw = surface.GetTextSize(title)

			draw.SimpleText(title, "ixDownMid", tx + 1, ty + 1, Color(0, 0, 0, 150 * k * ta), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(title, "ixDownMid", tx, ty, Color(255, 255, 255, (200 + 55 * f) * k * ta), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(sub, "ixDownTiny", tx, h * 0.72, Color(c.r, c.g, c.b, (170 + 60 * f) * k * ta), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			-- шевроны по бокам текста
			if (ef > 0.02) then
				local off = 26 - 10 * ef
				local lx, rx = tx - tw * 0.5 - off, tx + tw * 0.5 + off

				UI().SmoothLine(lx, ty - 5, lx + 5, ty, 1.5, 255, 255, 255, 230 * ef * k)
				UI().SmoothLine(lx + 5, ty, lx, ty + 5, 1.5, 255, 255, 255, 230 * ef * k)
				UI().SmoothLine(rx, ty - 5, rx - 5, ty, 1.5, 255, 255, 255, 230 * ef * k)
				UI().SmoothLine(rx - 5, ty, rx, ty + 5, 1.5, 255, 255, 255, 230 * ef * k)
			end
		end

		return true
	end
end

function PANEL:Init()
	local scrW, scrH = ScrW(), ScrH()

	self.panelW = math.floor(math.min(scrW * 0.5, 860))
	self.panelH = math.floor(scrH * 0.085)
	self.gap = 20
	self.waitVis = 1

	self:SetSize(self.panelW, self.panelH)
	self:SetPos(scrW * 0.5 - self.panelW * 0.5, scrH * 0.79)

	-- мышь нужна для кнопок, клавиатура остаётся игре (чат, бинды)
	self:MakePopup()
	self:SetKeyboardInputEnabled(false)

	local bw = math.floor((self.panelW - self.gap) * 0.5)

	self.waitButton = self:Add("DButton")
	self.waitButton:SetSize(bw, self.panelH)
	self.waitButton:SetPos(bw + self.gap, 0)

	StyleButton(self.waitButton, {
		color = Color(90, 160, 235),
		title = function() return L("dnBtnWait") end,
		sub = function() return L("dnBtnWaitSub") end,
		onActivate = function()
			SendChoice(false)
		end
	})

	self.dieButton = self:Add("DButton")
	self.dieButton:SetSize(bw, self.panelH)
	self.dieButton:SetPos(0, 0)
	self.dieX = 0

	StyleButton(self.dieButton, {
		color = Color(214, 66, 58),
		hold = HOLD_TIME,
		title = function() return L("dnBtnDie") end,
		sub = function() return L("dnBtnDieSub") end,
		onActivate = function()
			SendChoice(true)
		end
	})
end

function PANEL:Think()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or !client:IsDowned()) then
		self:Remove()
		return
	end

	local ui = UI()
	local fade = ui and ui.GetFade() or 1
	local blackout = ui and ui.GetBlackout() or 0
	local a = math.Clamp((fade - 0.55) / 0.35, 0, 1)

	self:SetAlpha(255 * a * (1 - blackout * 0.85))
	self:SetMouseInputEnabled(a > 0.6)

	-- плашки «выезжают» по очереди после затемнения
	local dt = RealFrameTime() * 2.4
	local waitTarget = a > 0.01 and 1 or 0

	self.dieButton.reveal = math.Approach(self.dieButton.reveal, waitTarget, dt)

	if (self.dieButton.reveal > 0.3) then
		self.waitButton.reveal = math.Approach(self.waitButton.reveal, waitTarget, dt)
	end

	-- после выбора ожидания остаётся только «Умереть» — уезжает в центр
	local waiting = client:GetNetVar("ixDownDeath", 0) > 0
	local bw = self.dieButton:GetWide()
	local lerp = math.min(RealFrameTime() * 8, 1)

	self.dieX = Lerp(lerp, self.dieX, waiting and (self.panelW - bw) * 0.5 or 0)
	self.dieButton:SetPos(math.floor(self.dieX), 0)

	self.waitVis = Lerp(lerp, self.waitVis, waiting and 0 or 1)
	self.waitButton:SetAlpha(255 * self.waitVis)
	self.waitButton:SetVisible(self.waitVis > 0.02)
	self.waitButton:SetMouseInputEnabled(!waiting)
end

function PANEL:Paint()
end

vgui.Register("ixDownedMenu", PANEL, "EditablePanel")