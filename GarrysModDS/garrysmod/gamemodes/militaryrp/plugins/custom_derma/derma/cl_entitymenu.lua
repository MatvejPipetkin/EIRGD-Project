local animationTime = 1
local padding = 32
local spacing = 6

local function GradientRect(x, y, width, height, from, to, horizontal)
	local steps = 20

	for i = 0, steps - 1 do
		local t = i / (steps - 1)

		surface.SetDrawColor(
			Lerp(t, from.r, to.r),
			Lerp(t, from.g, to.g),
			Lerp(t, from.b, to.b),
			Lerp(t, from.a, to.a)
		)

		if (horizontal) then
			local x0 = x + math.floor(width * i / steps)
			local x1 = x + math.floor(width * (i + 1) / steps)

			surface.DrawRect(x0, y, x1 - x0, height)
		else
			local y0 = y + math.floor(height * i / steps)
			local y1 = y + math.floor(height * (i + 1) / steps)

			surface.DrawRect(x, y0, width, y1 - y0)
		end
	end
end

-- entity menu button
DEFINE_BASECLASS("ixMenuButton")
local PANEL = {}

AccessorFunc(PANEL, "callback", "Callback")

function PANEL:Init()
	self:SetTall(ScrH() * 0.065)
	self:Dock(TOP)
	self:DockMargin(0, 0, 0, spacing)
	self:SetContentAlignment(4)

	self.hover = 0
end

function PANEL:DoClick()
	local bStatus = true
	local parent = ix.menu.panel
	local entity = parent:GetEntity()

	if (parent.bClosing) then
		return
	end

	if (isfunction(self.callback)) then
		bStatus = self.callback()
	end

	if (bStatus != false) then
		ix.menu.NetworkChoice(entity, self.originalText, bStatus)
	end

	parent:Remove()
end

function PANEL:SetText(text)
	self.originalText = text
	BaseClass.SetText(self, text)
end

function PANEL:Paint(width, height)
	self.hover = Lerp(math.min(FrameTime() * 12, 1), self.hover or 0, self:IsHovered() and 1 or 0)

	local f = self.hover
	local accent = ix.config.Get("color")

	surface.SetDrawColor(6, 14, 28, 120 + 50 * f)
	surface.DrawRect(0, 0, width, height)

	GradientRect(0, 0, width, height, Color(accent.r, accent.g, accent.b, 95 * f), Color(accent.r, accent.g, accent.b, 0), true)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 30 + 90 * f)
	surface.DrawOutlinedRect(0, 0, width, height, 1)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 70 + 185 * f)
	surface.DrawRect(0, 0, 2 + math.floor(2 * f), height)

	surface.SetDrawColor(255, 255, 255, 10)
	surface.DrawRect(1, 1, width - 2, 1)

	if (f > 0.05) then
		local cx, cy = width - 28 + 8 * f, height * 0.5

		surface.SetDrawColor(accent.r, accent.g, accent.b, 255 * f)
		surface.DrawLine(cx, cy - 5, cx + 5, cy)
		surface.DrawLine(cx + 5, cy, cx, cy + 5)
		surface.DrawLine(cx, cy - 4, cx + 4, cy)
		surface.DrawLine(cx + 4, cy, cx, cy + 4)
	end

	self:SetTextInset(26 + 10 * f, 0)
	self:SetTextColor(Color(Lerp(f, 178, 255), Lerp(f, 198, 255), Lerp(f, 224, 255)))
end

vgui.Register("ixEntityMenuButton", PANEL, "ixMenuButton")

-- entity menu list
DEFINE_BASECLASS("EditablePanel")
PANEL = {}

function PANEL:Init()
	self.list = {}
end

function PANEL:AddOption(text, callback)
	local panel = self:Add("ixEntityMenuButton")
	panel:SetText(text)
	panel:SetCallback(callback)
	panel:Dock(TOP)

	if (self.bPaintedManually) then
		panel:SetPaintedManually(true)
	end

	self.list[#self.list + 1] = panel
end

function PANEL:SizeToContents()
	local height = 0

	for i = 1, #self.list do
		height = height + self.list[i]:GetTall() + spacing
	end

	height = math.max(height - spacing, 0)

	self:SetSize(math.Clamp(ScrW() * 0.22, 280, ScrW() * 0.5 - padding * 2), height)
end

function PANEL:Center()
	local parent = self:GetParent()

	self:SetPos(
		ScrW() * 0.5 + padding,
		parent:GetTall() * 0.5 - self:GetTall() * 0.5
	)
end

function PANEL:SetPaintedManually(bValue)
	if (bValue) then
		for i = 1, #self.list do
			self.list[i]:SetPaintedManually(true)
		end

		self.bPaintedManually = true
	end

	BaseClass.SetPaintedManually(self, bValue)
end

function PANEL:PaintManual()
	BaseClass.PaintManual(self)
	local list = self.list

	for i = 1, #list do
		list[i]:PaintManual()
	end
end

vgui.Register("ixEntityMenuList", PANEL, "EditablePanel")

-- entity menu
DEFINE_BASECLASS("EditablePanel")
PANEL = {}

AccessorFunc(PANEL, "entity", "Entity")
AccessorFunc(PANEL, "bClosing", "IsClosing", FORCE_BOOL)
AccessorFunc(PANEL, "desiredHeight", "DesiredHeight", FORCE_NUMBER)

function PANEL:Init()
	if (IsValid(ix.menu.panel)) then
		self:Remove()
		return
	end

	-- close entity tooltip if it's open
	if (IsValid(ix.gui.entityInfo)) then
		ix.gui.entityInfo:Remove()
	end

	ix.menu.panel = self

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)

	self.list = self:Add("ixEntityMenuList")
	self.list:SetPaintedManually(true)

	self.desiredHeight = 0
	self.blur = 0
	self.alpha = 1
	self.bClosing = false
	self.lastPosition = vector_origin

	self:CreateAnimation(animationTime, {
		target = {blur = 1},
		easing = "outQuint"
	})

	self:MakePopup()
end

function PANEL:SetOptions(options)
	for k, v in pairs(options) do
		self.list:AddOption(k, v)
	end

	self.list:SizeToContents()
	self.list:Center()
end

function PANEL:GetApproximateScreenHeight(entity, distanceSqr)
	return IsValid(entity) and
		(entity:BoundingRadius() * (entity:IsPlayer() and 1.5 or 1) or 0) / math.sqrt(distanceSqr) * self:GetTall() or 0
end

function PANEL:Think()
	local entity = self.entity
	local distance = 0

	if (IsValid(entity)) then
		local position = entity:GetPos()
		distance = LocalPlayer():GetShootPos():DistToSqr(position)

		if (distance > 65536) then
			self:Remove()
			return
		end

		self.lastPosition = position
	end

	self.desiredHeight = math.max(self.list:GetTall() + padding * 2, self:GetApproximateScreenHeight(entity, distance))
end

function PANEL:Paint(width, height) -- luacheck: ignore 312
	local selfHalf = self:GetTall() * 0.5
	local entity = self.entity
	local screenW = width

	height = self.desiredHeight + padding * 2
	width = self.blur * width

	local y = selfHalf - height * 0.5

	DisableClipping(true) -- for cheap blur
	render.SetScissorRect(0, y, width, y + height, true)
		if (IsValid(entity)) then
			cam.Start3D()
				ix.util.ResetStencilValues()
				render.SetStencilEnable(true)
				cam.IgnoreZ(true)
					render.SetStencilWriteMask(29)
					render.SetStencilTestMask(29)
					render.SetStencilReferenceValue(29)

					render.SetStencilCompareFunction(STENCIL_ALWAYS)
					render.SetStencilPassOperation(STENCIL_REPLACE)
					render.SetStencilFailOperation(STENCIL_KEEP)
					render.SetStencilZFailOperation(STENCIL_KEEP)

					entity:DrawModel()

					render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
					render.SetStencilPassOperation(STENCIL_KEEP)

					cam.Start2D()
						ix.util.DrawBlur(self, 10)
					cam.End2D()
				cam.IgnoreZ(false)
				render.SetStencilEnable(false)
			cam.End3D()
		else
			ix.util.DrawBlur(self, 10)
		end
	render.SetScissorRect(0, 0, 0, 0, false)
	DisableClipping(false)

	-- scissor again because 3d rendering messes with the clipping apparently?
	render.SetScissorRect(0, y, width, y + height, true)
		local accent = ix.config.Get("color")

		surface.SetDrawColor(4, 10, 22, 150)
		surface.DrawRect(0, y, screenW, height)

		GradientRect(0, y, screenW, height, Color(accent.r, accent.g, accent.b, 38), Color(0, 0, 0, 0), true)

		GradientRect(0, y, screenW, height * 0.25, Color(0, 0, 0, 80), Color(0, 0, 0, 0), false)
		GradientRect(0, y + height * 0.75, screenW, height * 0.25, Color(0, 0, 0, 0), Color(0, 0, 0, 80), false)

		GradientRect(0, y, screenW, 1, Color(accent.r, accent.g, accent.b, 170), Color(accent.r, accent.g, accent.b, 15), true)
		GradientRect(0, y + height - 1, screenW, 1, Color(accent.r, accent.g, accent.b, 170), Color(accent.r, accent.g, accent.b, 15), true)

		local lineX = screenW * 0.5
		local top = y + padding
		local half = (height - padding * 2) * 0.5
		local mid = top + half

		GradientRect(lineX - 2, top, 5, half, Color(accent.r, accent.g, accent.b, 0), Color(accent.r, accent.g, accent.b, 26), false)
		GradientRect(lineX - 2, mid, 5, half, Color(accent.r, accent.g, accent.b, 26), Color(accent.r, accent.g, accent.b, 0), false)
		GradientRect(lineX, top, 1, half, Color(accent.r, accent.g, accent.b, 0), Color(accent.r, accent.g, accent.b, 255), false)
		GradientRect(lineX, mid, 1, half, Color(accent.r, accent.g, accent.b, 255), Color(accent.r, accent.g, accent.b, 0), false)

		self.list:PaintManual()
	render.SetScissorRect(0, 0, 0, 0, false)
end

function PANEL:GetOverviewInfo(origin, angles)
	local entity = self.entity

	if (IsValid(entity)) then
		local radius = entity:BoundingRadius() * (entity:IsPlayer() and 0.5 or 1)
		local center = entity:LocalToWorld(entity:OBBCenter()) + LocalPlayer():GetRight() * radius

		return LerpAngle(self.bClosing and self.alpha or self.blur, angles, (center - origin):Angle())
	end

	return angles
end

function PANEL:OnMousePressed(code)
	if (code == MOUSE_LEFT) then
		self:Remove()
	end
end

function PANEL:Remove()
	if (self.bClosing) then
		return
	end

	self.bClosing = true

	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
	gui.EnableScreenClicker(false)

	self:CreateAnimation(animationTime * 0.5, {
		target = {alpha = 0},
		index = 2,
		easing = "outQuint",

		Think = function(animation, panel)
			panel:SetAlpha(panel.alpha * 255)
		end,

		OnComplete = function(animation, panel)
			ix.menu.panel = nil
			BaseClass.Remove(self)
		end
	})
end

vgui.Register("ixEntityMenu", PANEL, "EditablePanel")