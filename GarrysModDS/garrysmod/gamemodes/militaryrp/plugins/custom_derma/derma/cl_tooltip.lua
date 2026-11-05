local animationTime = 1

local healthStates = {
	{1, "При смерти", Color(178, 28, 56)},
	{10, "На грани смерти", Color(236, 62, 56)},
	{25, "Достаточное кровотечение", Color(255, 148, 46)},
	{50, "Лёгкое ранение", Color(242, 212, 64)},
	{80, "Виднеются царапины", Color(138, 224, 126)}
}

local function GetHealthStatus(health)
	for _, state in ipairs(healthStates) do
		if (health <= state[1]) then
			return state[2], state[3]
		end
	end
end

local function Shade(color, multiplier, alpha)
	return Color(
		math.min(color.r * multiplier, 255),
		math.min(color.g * multiplier, 255),
		math.min(color.b * multiplier, 255),
		alpha or color.a
	)
end

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

local function PaintContainer(panel, width, height)
	ix.util.DrawBlur(panel, 4)

	surface.SetDrawColor(5, 12, 24, 214)
	surface.DrawRect(0, 0, width, height)

	GradientRect(0, 0, width, height, Color(40, 110, 200, 36), Color(0, 0, 0, 0), false)

	surface.SetDrawColor(255, 255, 255, 12)
	surface.DrawRect(1, 1, width - 2, 1)

	surface.SetDrawColor(34, 78, 140, 255)
	surface.DrawOutlinedRect(0, 0, width, height, 1)

	local accent = panel.arrowColor or color_white

	surface.SetDrawColor(accent)
	surface.DrawRect(0, 0, 8, 2)
	surface.DrawRect(0, 0, 2, 8)
	surface.DrawRect(width - 8, height - 2, 8, 2)
	surface.DrawRect(width - 2, height - 8, 2, 8)
end

do
	local PANEL = FindMetaTable("Panel")
	local ixChangeTooltip = ChangeTooltip
	local ixRemoveTooltip = RemoveTooltip
	local tooltip
	local lastHover

	function PANEL:SetHelixTooltip(callback)
		self:SetMouseInputEnabled(true)
		self.ixTooltip = callback
	end

	function ChangeTooltip(panel, ...) -- luacheck: globals ChangeTooltip
		if (!panel.ixTooltip) then
			return ixChangeTooltip(panel, ...)
		end

		RemoveTooltip()

		timer.Create("ixTooltip", 0.1, 1, function()
			if (!IsValid(panel) or lastHover != panel) then
				return
			end

			tooltip = vgui.Create("ixTooltip")
			panel.ixTooltip(tooltip)
			tooltip:SizeToContents()
		end)

		lastHover = panel
	end

	function RemoveTooltip() -- luacheck: globals RemoveTooltip
		if (IsValid(tooltip)) then
			tooltip:Remove()
			tooltip = nil
		end

		timer.Remove("ixTooltip")
		lastHover = nil

		return ixRemoveTooltip()
	end
end

DEFINE_BASECLASS("DLabel")
local PANEL = {}

AccessorFunc(PANEL, "backgroundColor", "BackgroundColor")
AccessorFunc(PANEL, "accentColor", "AccentColor")
AccessorFunc(PANEL, "maxWidth", "MaxWidth", FORCE_NUMBER)
AccessorFunc(PANEL, "bNoMinimal", "MinimalHidden", FORCE_BOOL)

function PANEL:Init()
	self:SetFont("ixSmallFont")
	self:SetText(L("unknown"))
	self:SetTextColor(color_white)
	self:SetTextInset(10, 0)
	self:SetContentAlignment(4)
	self:Dock(TOP)

	self.maxWidth = ScrW() * 0.2
	self.bNoMinimal = false
	self.bMinimal = false
end

function PANEL:IsMinimal()
	return self.bMinimal
end

function PANEL:SetImportant()
	self:SetFont("ixSmallTitleFont")
	self:SetExpensiveShadow(1, color_black)
	self:SetBackgroundColor(ix.config.Get("color"))
end

function PANEL:SetBackgroundColor(color)
	color = table.Copy(color)
	color.a = math.Clamp(color.a or 255, 100, 255)

	self.backgroundColor = color
end

function PANEL:SizeToContents()
	local contentWidth, contentHeight = self:GetContentSize()
	contentWidth = contentWidth + 20
	contentHeight = contentHeight + 8

	if (contentWidth > self.maxWidth) then
		self:SetWide(self.maxWidth - 4)
		self:SetTextInset(10, 0)
		self:SetWrap(true)

		self:SizeToContentsY()
	else
		self:SetSize(contentWidth, contentHeight)
	end
end

function PANEL:SizeToContentsY()
	BaseClass.SizeToContentsY(self)
	self:SetTall(self:GetTall() + 8)
end

function PANEL:PaintBackground(width, height)
	local accent = self.accentColor
	local color = self.backgroundColor

	if (accent) then
		surface.SetDrawColor(0, 0, 0, 90)
		surface.DrawRect(0, 0, width, height)

		GradientRect(3, 0, width - 3, height, Color(accent.r, accent.g, accent.b, 40), Color(accent.r, accent.g, accent.b, 0), true)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 255)
		surface.DrawRect(0, 0, 3, height)

		if (self.flashTime) then
			local flash = 1 - (CurTime() - self.flashTime) / 0.7

			if (flash > 0) then
				surface.SetDrawColor(255, 255, 255, 70 * flash)
				surface.DrawRect(0, 0, width, height)
			else
				self.flashTime = nil
			end
		end
	elseif (color) then
		GradientRect(0, 0, width, height, Shade(color, 1.05), Shade(color, 0.55), false)

		surface.SetDrawColor(255, 255, 255, 38)
		surface.DrawRect(0, 0, width, 1)

		surface.SetDrawColor(0, 0, 0, 90)
		surface.DrawRect(0, height - 1, width, 1)
	end
end

function PANEL:Paint(width, height)
	self:PaintBackground(width, height)
end

vgui.Register("ixTooltipRow", PANEL, "DLabel")

DEFINE_BASECLASS("Panel")
PANEL = {}

AccessorFunc(PANEL, "entity", "Entity")
AccessorFunc(PANEL, "mousePadding", "MousePadding", FORCE_NUMBER)
AccessorFunc(PANEL, "bDrawArrow", "DrawArrow", FORCE_BOOL)
AccessorFunc(PANEL, "arrowColor", "ArrowColor")
AccessorFunc(PANEL, "bHideArrowWhenRaised", "HideArrowWhenRaised", FORCE_BOOL)
AccessorFunc(PANEL, "bArrowFollowEntity", "ArrowFollowEntity", FORCE_BOOL)

function PANEL:Init()
	self.fraction = 0
	self.mousePadding = 16
	self.arrowColor = ix.config.Get("color")
	self.bHideArrowWhenRaised = true
	self.bArrowFollowEntity = true
	self.bMinimal = false

	self.lastX, self.lastY = self:GetCursorPosition()
	self.arrowX, self.arrowY = ScrW() * 0.5, ScrH() * 0.5

	self:SetAlpha(0)
	self:SetSize(0, 0)
	self:SetDrawOnTop(true)
	self:SetMouseInputEnabled(false)

	self:CreateAnimation(animationTime, {
		index = 1,
		target = {fraction = 1},
		easing = "outQuint",

		Think = function(animation, panel)
			panel:SetAlpha(panel.fraction * 255)
		end
	})
end

function PANEL:IsMinimal()
	return self.bMinimal
end

function PANEL:Add(...)
	local panel = BaseClass.Add(self, ...)
	panel:SetPaintedManually(true)

	return panel
end

function PANEL:AddRow(id)
	local panel = self:Add("ixTooltipRow")
	panel.id = id
	panel:SetZPos(#self:GetChildren() * 10)

	return panel
end

function PANEL:AddRowAfter(after, id)
	local panel = self:AddRow(id)
	after = self:GetRow(after)

	if (!IsValid(after)) then
		return panel
	end

	panel:SetZPos(after:GetZPos() + 1)

	return panel
end

function PANEL:RemoveVanillaInjuryRow()
	local previous = self:GetRow("injureText")

	if (IsValid(previous)) then
		previous:SetSize(0, 0)
		previous:Remove()
	end
end

function PANEL:UpdateHealthRow(client)
	local text, color

	if (client:Alive()) then
		text, color = GetHealthStatus(client:Health())
	end

	if (text == self.healthText) then
		return
	end

	local hadText = self.healthText
	self.healthText = text

	local row = self:GetRow("health")

	if (!text) then
		if (IsValid(row)) then
			row:SetSize(0, 0)
			row:Remove()
		end

		self:SizeToContents()
		return
	end

	if (!IsValid(row)) then
		row = self:AddRowAfter("name", "health")
		row:SetExpensiveShadow(1, Color(0, 0, 0, 200))
	end

	row:SetText(text)
	row:SetTextColor(color)
	row:SetAccentColor(color)
	row:SizeToContents()

	if (hadText) then
		row.flashTime = CurTime()
	end

	self:SizeToContents()
end

function PANEL:SetEntity(entity)
	if (!IsValid(entity)) then
		self.bEntity = false
		return
	end

	if (IsValid(ix.menu.panel)) then
		self:Remove()
		return
	end

	if (entity:IsPlayer()) then
		local character = entity:GetCharacter()

		if (character) then
			hook.Run("PopulateImportantCharacterInfo", entity, character, self)
			hook.Run("PopulateCharacterInfo", entity, character, self)

			self:RemoveVanillaInjuryRow()
			self:UpdateHealthRow(entity)
			self.bCharacterInfo = true
		end
	else
		if (entity.OnPopulateEntityInfo) then
			entity:OnPopulateEntityInfo(self)
		else
			hook.Run("PopulateEntityInfo", entity, self)
		end
	end

	self:SizeToContents()

	self.entity = entity
	self.bEntity = true
end

function PANEL:PaintUnder(width, height)
end

function PANEL:Paint(width, height)
	self:PaintUnder()

	self.bRaised = LocalPlayer():IsWepRaised()

	if (!self.bClosing) then
		if (self.bEntity and IsValid(self.entity) and self.bArrowFollowEntity) then
			local entity = self.entity
			local position = select(1, entity:GetBonePosition(entity:LookupBone("ValveBiped.Bip01_Spine") or -1)) or
				entity:LocalToWorld(entity:OBBCenter())

			position = position:ToScreen()
			self.arrowX = math.Clamp(position.x, 0, ScrW())
			self.arrowY = math.Clamp(position.y, 0, ScrH())
		end
	end

	if (self.bDrawArrow or (self.bDrawArrow and self.bRaised and !self.bHideArrowWhenRaised)) then
		local x, y = self:ScreenToLocal(self.arrowX, self.arrowY)
		local color = self.arrowColor
		local fraction = self.fraction

		DisableClipping(true)
			surface.SetDrawColor(color.r, color.g, color.b, 60)
			surface.DrawLine(0, 1, x * fraction, y * fraction + 1)
			surface.DrawLine(0, -1, x * fraction, y * fraction - 1)

			surface.SetDrawColor(color)
			surface.DrawLine(0, 0, x * fraction, y * fraction)
			surface.DrawRect((x - 3) * fraction, (y - 3) * fraction, 6, 6)

			surface.SetDrawColor(color.r, color.g, color.b, 90)
			surface.DrawOutlinedRect((x - 6) * fraction, (y - 6) * fraction, 12, 12, 1)

			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawRect((x - 1) * fraction, (y - 1) * fraction, 2, 2)
		DisableClipping(false)
	end

	local x, y = self:GetPos()

	render.SetScissorRect(x, y, x + width * self.fraction, y + height, true)
		PaintContainer(self, width, height)

		for _, v in ipairs(self:GetChildren()) do
			if (IsValid(v)) then
				v:PaintManual()
			end
		end
	render.SetScissorRect(0, 0, 0, 0, false)
end

function PANEL:GetCursorPosition()
	local width, height = self:GetSize()
	local mouseX, mouseY = gui.MousePos()

	return math.Clamp(mouseX + self.mousePadding, 0, ScrW() - width), math.Clamp(mouseY, 0, ScrH() - height)
end

function PANEL:Think()
	if (!self.bEntity) then
		if (!vgui.CursorVisible()) then
			self:SetPos(self.lastX, self.lastY)

			if (!self.bClosing) then
				self:Remove()
			end
		else
			local newX, newY = self:GetCursorPosition()

			self:SetPos(newX, newY)
			self.lastX, self.lastY = newX, newY
		end

		self:MoveToFront()
	elseif (IsValid(self.entity) and !self.bClosing) then
		if (self.bCharacterInfo) then
			self:UpdateHealthRow(self.entity)
		end

		if (self.bRaised) then
			self:SetPos(
				ScrW() * 0.5 - self:GetWide() * 0.5,
				math.min(ScrH() * 0.5 + self:GetTall() + 32, ScrH() - self:GetTall())
			)
		else
			local entity = self.entity
			local min, max = entity:GetRotatedAABB(entity:OBBMins() * 0.5, entity:OBBMaxs() * 0.5)
			min = entity:LocalToWorld(min):ToScreen().x
			max = entity:LocalToWorld(max):ToScreen().x

			self:SetPos(
				math.Clamp(math.max(min, max), ScrW() * 0.5 + 64, ScrW() - self:GetWide()),
				ScrH() * 0.5 - self:GetTall() * 0.5
			)
		end
	end
end

function PANEL:GetRow(id)
	for _, v in ipairs(self:GetChildren()) do
		if (IsValid(v) and v.id == id) then
			return v
		end
	end
end

function PANEL:SizeToContents()
	local height = 0
	local width = 0

	for _, v in ipairs(self:GetChildren()) do
		if (v:GetWide() > width) then
			width = v:GetWide()
		end

		height = height + v:GetTall()
	end

	self:SetSize(width, height)
end

function PANEL:Remove()
	if (self.bClosing) then
		return
	end

	self.bClosing = true
	self:CreateAnimation(animationTime * 0.5, {
		target = {fraction = 0},
		easing = "outQuint",

		Think = function(animation, panel)
			panel:SetAlpha(panel.fraction * 255)
		end,

		OnComplete = function(animation, panel)
			BaseClass.Remove(panel)
		end
	})
end

vgui.Register("ixTooltip", PANEL, "Panel")

PANEL = {}

function PANEL:Init()
	self.bMinimal = true
	self.ixAlpha = 0

	self:SetExpensiveShadow(1, color_black)
	self:SetContentAlignment(5)
end

function PANEL:SetImportant()
	self:SetFont("ixMinimalTitleFont")
	self:SetBackgroundColor(ix.config.Get("color"))
end

function PANEL:SetBackgroundColor(color)
	color = table.Copy(color)
	color.a = math.Clamp(color.a or 255, 100, 255)

	self:SetTextColor(color)
	self.backgroundColor = color
end

function PANEL:PaintBackground()
end

vgui.Register("ixTooltipMinimalRow", PANEL, "ixTooltipRow")

DEFINE_BASECLASS("ixTooltip")
PANEL = {}

function PANEL:Init()
	self.bMinimal = true

	self:CreateAnimation(animationTime, {
		index = 1,
		target = {fraction = 1},
		easing = "outQuint",
	})

	self:SetAlpha(255)
end

function PANEL:Add(...)
	local panel = BaseClass.Add(self, ...)
	panel:SetPaintedManually(false)

	return panel
end

function PANEL:AddRow(id)
	local panel = self:Add("ixTooltipMinimalRow")
	panel.id = id
	panel:SetZPos(#self:GetChildren() * 10)

	return panel
end

function PANEL:Paint(width, height)
	self:PaintUnder()

	derma.SkinFunc("PaintTooltipMinimalBackground", self, width, height)
end

function PANEL:Think()
end

function PANEL:SizeToContents()
	for _, v in ipairs(self:GetChildren()) do
		if (v.bNoMinimal) then
			v:Remove()
		end
	end

	BaseClass.SizeToContents(self)
	self:SetPos(ScrW() * 0.5 - self:GetWide() * 0.5, ScrH() * 0.5 + self.mousePadding)

	local children = self:GetChildren()

	table.sort(children, function(a, b)
		return a:GetZPos() < b:GetZPos()
	end)

	local i = 1
	local count = table.Count(children)

	for _, v in ipairs(children) do
		v.ixAlpha = v.ixAlpha or 0

		v:CreateAnimation((animationTime / count) * i, {
			easing = "inSine",
			target = {ixAlpha = 255},
			Think = function(animation, panel)
				panel:SetAlpha(panel.ixAlpha)
			end
		})

		i = i + 1
	end
end

DEFINE_BASECLASS("Panel")
function PANEL:Remove()
	if (self.bClosing) then
		return
	end

	self.bClosing = true

	local children = self:GetChildren()

	table.sort(children, function(a, b)
		return a:GetZPos() > b:GetZPos()
	end)

	local duration = animationTime * 0.5
	local i = 1
	local count = table.Count(children)

	for _, v in ipairs(children) do
		v.ixAlpha = v.ixAlpha or 255

		v:CreateAnimation(duration / count * i, {
			target = {ixAlpha = 0},
			Think = function(animation, panel)
				panel:SetAlpha(panel.ixAlpha)
			end
		})

		i = i + 1
	end

	self:CreateAnimation(duration, {
		target = {fraction = 0},
		OnComplete = function(animation, panel)
			BaseClass.Remove(panel)
		end
	})
end

vgui.Register("ixTooltipMinimal", PANEL, "ixTooltip")