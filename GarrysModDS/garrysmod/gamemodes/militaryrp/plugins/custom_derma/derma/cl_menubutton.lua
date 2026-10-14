-- общий стиль меню (тот же акцентный цвет, что и accentColor в cl_character.lua)
ix.menuStyle = ix.menuStyle or {accent = Color(90, 160, 235), projectName = "EIRGD"}

local buttonPadding = ScreenScale(14) * 0.5

-- масштаб под разрешение (за основу взято 1080p)
local function S(value)
	return math.floor(value * ScrH() / 1080 + 0.5)
end

local function GetAccent()
	return ix.menuStyle.accent or ix.config.Get("color") or Color(90, 160, 235)
end

local function EaseOutCubic(x)
	return 1 - (1 - x) ^ 3
end

-- плавное приближение к цели, не зависит от FPS
local function Smooth(current, target, speed)
	return Lerp(1 - math.exp(-RealFrameTime() * speed), current, target)
end

local function PlayUI(path, pitch, volume)
	local ply = LocalPlayer()

	if (IsValid(ply)) then
		ply:EmitSound(path, 75, pitch, volume, CHAN_AUTO)
	end
end

local function CreateMenuFonts()
	local h = ScrH()

	surface.CreateFont("ixMenuTabFont", {font = "Roboto", size = math.max(14, math.floor(h * 0.0185)), weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixMenuTabFontSmall", {font = "Roboto", size = math.max(11, math.floor(h * 0.0135)), weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixMenuLinkFont", {font = "Roboto", size = math.max(12, math.floor(h * 0.0155)), weight = 500, extended = true, antialias = true})
	surface.CreateFont("ixMenuTinyFont", {font = "Roboto", size = math.max(10, math.floor(h * 0.0115)), weight = 500, extended = true, antialias = true})
end

CreateMenuFonts()
hook.Add("OnScreenSizeChanged", "ixMenuButtonFonts", CreateMenuFonts)

--[[
	ixMenuButton — базовая кнопка. Оставлена без изменений,
	чтобы не сломать cl_character.lua (там она стилизуется отдельно).
]]
DEFINE_BASECLASS("DButton")
local PANEL = {}

AccessorFunc(PANEL, "backgroundColor", "BackgroundColor")
AccessorFunc(PANEL, "backgroundAlpha", "BackgroundAlpha")

function PANEL:Init()
	self:SetFont("ixMenuButtonFont")
	self:SetTextColor(color_white)
	self:SetPaintBackground(false)
	self:SetContentAlignment(4)
	self:SetTextInset(buttonPadding, 0)

	self.padding = {32, 12, 32, 12} -- left, top, right, bottom
	self.backgroundColor = Color(0, 0, 0)
	self.backgroundAlpha = 128
	self.currentBackgroundAlpha = 0
end

function PANEL:GetPadding()
	return self.padding
end

function PANEL:SetPadding(left, top, right, bottom)
	self.padding = {
		left or self.padding[1],
		top or self.padding[2],
		right or self.padding[3],
		bottom or self.padding[4]
	}
end

function PANEL:SetText(text, noTranslation)
	BaseClass.SetText(self, noTranslation and text:utf8upper() or L(text):utf8upper())
end

function PANEL:SizeToContents()
	BaseClass.SizeToContents(self)

	local width, height = self:GetSize()
	self:SetSize(width + self.padding[1] + self.padding[3], height + self.padding[2] + self.padding[4])
end

function PANEL:PaintBackground(width, height)
	surface.SetDrawColor(ColorAlpha(self.backgroundColor, self.currentBackgroundAlpha))
	surface.DrawRect(0, 0, width, height)
end

function PANEL:Paint(width, height)
	self:PaintBackground(width, height)
	BaseClass.Paint(self, width, height)
end

function PANEL:SetTextColorInternal(color)
	BaseClass.SetTextColor(self, color)
	self:SetFGColor(color)
end

function PANEL:SetTextColor(color)
	self:SetTextColorInternal(color)
	self.color = color
end

function PANEL:SetDisabled(bValue)
	local color = self.color

	if (bValue) then
		self:SetTextColorInternal(Color(math.max(color.r - 60, 0), math.max(color.g - 60, 0), math.max(color.b - 60, 0)))
	else
		self:SetTextColorInternal(color)
	end

	BaseClass.SetDisabled(self, bValue)
end

function PANEL:OnCursorEntered()
	if (self:GetDisabled()) then
		return
	end

	local color = self:GetTextColor()
	self:SetTextColorInternal(Color(math.max(color.r - 25, 0), math.max(color.g - 25, 0), math.max(color.b - 25, 0)))

	self:CreateAnimation(0.15, {
		target = {currentBackgroundAlpha = self.backgroundAlpha}
	})

	LocalPlayer():EmitSound("Helix.Rollover")
end

function PANEL:OnCursorExited()
	if (self:GetDisabled()) then
		return
	end

	if (self.color) then
		self:SetTextColor(self.color)
	else
		self:SetTextColor(color_white)
	end

	self:CreateAnimation(0.15, {
		target = {currentBackgroundAlpha = 0}
	})
end

function PANEL:OnMousePressed(code)
	if (self:GetDisabled()) then
		return
	end

	if (self.color) then
		self:SetTextColor(self.color)
	else
		self:SetTextColor(ix.config.Get("color"))
	end

	LocalPlayer():EmitSound("Helix.Press")

	if (code == MOUSE_LEFT and self.DoClick) then
		self:DoClick(self)
	elseif (code == MOUSE_RIGHT and self.DoRightClick) then
		self:DoRightClick(self)
	end
end

function PANEL:OnMouseReleased(key)
	if (self:GetDisabled()) then
		return
	end

	if (self.color) then
		self:SetTextColor(self.color)
	else
		self:SetTextColor(color_white)
	end
end

vgui.Register("ixMenuButton", PANEL, "DButton")

--[[
	ixMenuSelectionButton — вкладка верхней панели меню.
	Только текст: цвет плавно меняется при наведении, активная вкладка
	подчёркивается общей линией, которая скользит между вкладками (рисуется в cl_menu).
]]
DEFINE_BASECLASS("ixMenuButton")
PANEL = {}

AccessorFunc(PANEL, "backgroundColor", "BackgroundColor")
AccessorFunc(PANEL, "selected", "Selected", FORCE_BOOL)
AccessorFunc(PANEL, "buttonList", "ButtonList")

function PANEL:Init()
	self:SetFont("ixMenuTabFont")
	self:SetContentAlignment(5)
	self:SetTextInset(0, 0)

	self.padding = {S(18), 0, S(18), 0}
	self.backgroundColor = GetAccent()
	self.selected = false
	self.buttonList = {}
	self.sectionPanel = nil -- подразделы этой вкладки; создаётся только если они есть
	self.sectionHost = nil -- панель, в которой размещается строка подразделов (задаётся в cl_menu)

	self.hoverFrac = 0
	self.activeFrac = 0
	self.pressFrac = 0
	self.revealStart = RealTime()
end

-- вкладка считается активной, если выбрана она сама или один из её подразделов
function PANEL:IsActive()
	if (self.selected) then
		return true
	end

	if (self.sectionPanel) then
		for _, v in ipairs(self.buttonList) do
			if (IsValid(v) and v.selected and v.sectionParent == self) then
				return true
			end
		end
	end

	return false
end

function PANEL:Paint(width, height)
	local hover = self:IsHovered() and 1 or 0
	local active = self:IsActive()

	self.hoverFrac = Smooth(self.hoverFrac, hover, 14)
	self.activeFrac = Smooth(self.activeFrac, active and 1 or 0, 10)
	self.pressFrac = Smooth(self.pressFrac, 0, 9)

	local hf, af, pf = self.hoverFrac, self.activeFrac, self.pressFrac
	local reveal = EaseOutCubic(math.Clamp((RealTime() - self.revealStart) / 0.6, 0, 1))
	local color = self.backgroundColor or GetAccent()

	self:SetTextColorInternal(Color(255, 255, 255, math.floor(math.Clamp(140 + 65 * hf + 50 * af - 50 * pf, 0, 255) * reveal)))

	draw.NoTexture()

	-- тонкие разделители между вкладками (у вкладки с bSeparator, например settings, заметнее)
	if (self.bSeparator or (self.tabIndex and self.tabIndex > 1)) then
		local tall = self.bSeparator and math.floor(height * 0.6) or math.floor(height * 0.3)

		surface.SetDrawColor(255, 255, 255, (self.bSeparator and 60 or 25) * reveal)
		surface.DrawRect(0, math.floor((height - tall) * 0.5), 1, tall)
	end

	if (hf > 0.01) then
		-- едва заметная подложка
		surface.SetDrawColor(color.r, color.g, color.b, 14 * hf * reveal)
		surface.DrawRect(0, 0, width, height)

		-- тонкая линия, расходящаяся от центра (только у неактивных)
		local inset = self.padding[1]
		local lineWidth = math.floor((width - inset * 2) * EaseOutCubic(hf))

		surface.SetDrawColor(color.r, color.g, color.b, 120 * hf * reveal * (1 - af))
		surface.DrawRect(math.floor((width - lineWidth) * 0.5), height - 1, lineWidth, 1)
	end

	-- подразделы подчёркиваем сами (у основных вкладок это делает скользящая линия)
	if (self.sectionParent and af > 0.01) then
		local inset = self.padding[1]

		surface.SetDrawColor(color.r, color.g, color.b, 200 * af * reveal)
		surface.DrawRect(inset, height - 1, width - inset * 2, 1)
	end
end

function PANEL:SetSelected(bValue, bSelectedSection)
	self.selected = bValue

	if (bValue) then
		self:OnSelected()

		if (self.sectionPanel) then
			self.sectionPanel:Show()
		elseif (self.sectionParent) then
			self.sectionParent.sectionPanel:Show()
		end
	elseif (self.sectionPanel and self.sectionPanel:IsVisible() and !bSelectedSection) then
		self.sectionPanel:Hide()
	end
end

function PANEL:SetButtonList(list, bNoAdd)
	if (!bNoAdd) then
		list[#list + 1] = self
	end

	self.buttonList = list
end

function PANEL:GetSectionPanel()
	return self.sectionPanel
end

function PANEL:AddSection(name)
	if (!IsValid(self.sectionPanel)) then
		local host = IsValid(self.sectionHost) and self.sectionHost or self:GetParent()

		self.sectionPanel = vgui.Create("ixMenuSelectionList", host)
		self.sectionPanel:SetParentButton(self)
	end

	return self.sectionPanel:AddButton(name, self.buttonList)
end

function PANEL:OnCursorEntered()
	PlayUI("buttons/blip1.wav", 115, 0.2)
end

function PANEL:OnCursorExited()
end

function PANEL:OnMouseReleased()
end

function PANEL:OnMousePressed(key)
	for _, v in pairs(self.buttonList) do
		if (IsValid(v) and v != self) then
			v:SetSelected(false, self.sectionParent == v)
		end
	end

	self:SetSelected(true)

	self.pressFrac = 1
	PlayUI("buttons/button15.wav", 100, 0.28)

	if (key == MOUSE_LEFT and self.DoClick) then
		self:DoClick(self)
	elseif (key == MOUSE_RIGHT and self.DoRightClick) then
		self:DoRightClick(self)
	end
end

function PANEL:OnSelected()
end

vgui.Register("ixMenuSelectionButton", PANEL, "ixMenuButton")

--[[
	ixMenuSelectionList — строка подразделов под вкладкой.
	Появляется плавным fade-in с лёгким сдвигом и встаёт под родительскую вкладку.
]]
PANEL = {}
AccessorFunc(PANEL, "parent", "ParentButton")

function PANEL:Init()
	self.parent = nil -- кнопка, которая управляет этим списком
	self.targetWidth = 0
	self.fade = 0

	local host = self:GetParent()

	self:SetTall(IsValid(host) and host:GetTall() or 0)
	self:SetVisible(false)
	self:SetAlpha(0)
end

function PANEL:AddButton(name, buttonList)
	assert(IsValid(self.parent), "attempted to add button to ixMenuSelectionList without a ParentButton")
	assert(buttonList ~= nil, "attempted to add button to ixMenuSelectionList without a buttonList")

	local button = self:Add("ixMenuSelectionButton")
	button.sectionParent = self.parent
	button:SetFont("ixMenuTabFontSmall")
	button:SetPadding(S(14), 0, S(14), 0)
	button:Dock(LEFT)
	button:SetText(name)
	button:SizeToContents()
	button:SetButtonList(buttonList)
	button:SetBackgroundColor(self.parent:GetBackgroundColor())

	self.targetWidth = self.targetWidth + button:GetWide()
	self:SetWide(self.targetWidth)

	return button
end

-- ставим список под родительскую вкладку и не даём ему выйти за границы строки
function PANEL:UpdatePosition()
	local host = self:GetParent()
	local x = IsValid(self.parent) and self.parent:GetX() or 0

	x = math.max(math.min(x, host:GetWide() - self:GetWide()), 0)
	self:SetPos(x, math.floor((1 - self.fade) * -S(6)))
end

function PANEL:Show()
	self:SetVisible(true)
	self:UpdatePosition()

	self:CreateAnimation(0.35, {
		index = 1,
		target = {fade = 1},
		easing = "outQuart",

		Think = function(animation, panel)
			panel:SetAlpha(255 * panel.fade)
			panel:UpdatePosition()
		end
	})
end

function PANEL:Hide()
	self:CreateAnimation(0.15, {
		index = 1,
		target = {fade = 0},
		easing = "outQuint",

		Think = function(animation, panel)
			panel:SetAlpha(255 * panel.fade)
			panel:UpdatePosition()
		end,

		OnComplete = function(animation, panel)
			panel:SetVisible(false)
		end
	})
end

vgui.Register("ixMenuSelectionList", PANEL, "Panel")

--[[
	ixMenuLinkButton — маленькая текстовая кнопка для действий (вернуться, персонажи).
	Слева тонкая линия: при наведении она удлиняется и плавно сдвигает текст вправо.
]]
DEFINE_BASECLASS("DButton")
PANEL = {}

function PANEL:Init()
	self:SetPaintBackground(false)
	self:SetCursor("hand")

	self.label = ""
	self.font = "ixMenuLinkFont"
	self.hoverFrac = 0
	self.pressFrac = 0
	self.revealStart = RealTime()
end

function PANEL:SetText(text, noTranslation)
	text = tostring(text or "")

	if (text == "" or noTranslation) then
		self.label = text:utf8upper()
	else
		self.label = L(text):utf8upper()
	end

	BaseClass.SetText(self, "")
end

function PANEL:SizeToContents()
	surface.SetFont(self.font)

	local textWidth, textHeight = surface.GetTextSize(self.label)

	self:SetSize(S(30) + S(10) + textWidth + 2, textHeight + S(16))
end

function PANEL:Paint(width, height)
	local disabled = self:GetDisabled()

	self.hoverFrac = Smooth(self.hoverFrac, (!disabled and self:IsHovered()) and 1 or 0, 12)
	self.pressFrac = Smooth(self.pressFrac, 0, 9)

	local hf, pf = self.hoverFrac, self.pressFrac
	local ef = EaseOutCubic(hf)
	local reveal = EaseOutCubic(math.Clamp((RealTime() - self.revealStart) / 0.6, 0, 1))
	local accent = GetAccent()
	local k = disabled and 0.35 or 1

	local lineLength = math.floor(Lerp(ef, S(12), S(30)))
	local centerY = math.floor(height * 0.5)

	draw.NoTexture()
	surface.SetDrawColor(accent.r, accent.g, accent.b, (170 + 85 * hf) * reveal * k)
	surface.DrawRect(0, centerY, lineLength, 1)

	-- угловые скобки вокруг кнопки при наведении
	if (hf > 0.02) then
		local len = S(5)
		local bx = -S(8)
		local bw = width + S(8)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 200 * hf * reveal * k)
		surface.DrawRect(bx, 0, len, 1)
		surface.DrawRect(bx, 0, 1, len)
		surface.DrawRect(bx + bw - len, 0, len, 1)
		surface.DrawRect(bx + bw - 1, 0, 1, len)
		surface.DrawRect(bx, height - 1, len, 1)
		surface.DrawRect(bx, height - len, 1, len)
		surface.DrawRect(bx + bw - len, height - 1, len, 1)
		surface.DrawRect(bx + bw - 1, height - len, 1, len)
	end

	draw.SimpleText(
		self.label, self.font, lineLength + S(10), centerY,
		Color(255, 255, 255, math.floor(math.Clamp(160 + 95 * hf - 70 * pf, 0, 255) * reveal * k)),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
	)
end

function PANEL:OnCursorEntered()
	if (!self:GetDisabled()) then
		PlayUI("buttons/blip1.wav", 115, 0.2)
	end
end

function PANEL:OnMousePressed(code)
	if (self:GetDisabled()) then
		return
	end

	self.pressFrac = 1
	PlayUI("buttons/button15.wav", 100, 0.28)

	if (code == MOUSE_LEFT and self.DoClick) then
		self:DoClick(self)
	elseif (code == MOUSE_RIGHT and self.DoRightClick) then
		self:DoRightClick(self)
	end
end

function PANEL:OnMouseReleased()
end

vgui.Register("ixMenuLinkButton", PANEL, "DButton")