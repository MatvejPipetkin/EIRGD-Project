local animationTime = 1
local matrixZScale = Vector(1, 1, 0.0001)

-- общий стиль меню (тот же акцентный цвет, что и accentColor в cl_character.lua)
ix.menuStyle = ix.menuStyle or {accent = Color(90, 160, 235), projectName = "EIRGD"}

--[[
	НАСТРОЙКИ
	Раскладка: сверху — вкладки (слева направо над областью контента) и строка подразделов,
	снизу слева — кнопки действий. Область контента осталась справа, как в оригинале,
	поэтому слева свободно место для персонажа в режиме обзора (вкладка инвентаря).
]]
local CFG = {
	marginFraction = 0.085, -- высота верхней и нижней полос в долях от высоты экрана
	barAlpha = 120, -- затемнение полос (0 = без полос)
	lineAlpha = 60, -- прозрачность тонких линий на границах полос
	showBrand = true, -- название проекта в левом верхнем углу
	showHint = true, -- подсказка про TAB в правом верхнем углу
	hintText = "TAB  —  ЗАКРЫТЬ",
	showClock = true, -- время над подсказкой
	showCharacter = true, -- имя персонажа и фракция в правом нижнем углу
	showStats = true, -- сервер / игроки / пинг по центру внизу
	sweep = true, -- медленный световой блик, бегущий по линиям полос
	contentLeft = 0, -- сколько слева оставить свободным под персонажа (доля ширины экрана; 0 = контент на всю ширину)

	-- Если контент окажется сдвинутым вправо на величину верхнего отступа, поставьте false.
	-- Предположение: ixSubpanelParent ставит подпанели в X = leftOffset + padding.
	paddingAddsToX = true
}

local function S(value)
	return math.floor(value * ScrH() / 1080 + 0.5)
end

local function GetAccent()
	return ix.menuStyle.accent or ix.config.Get("color") or Color(90, 160, 235)
end

local function EaseOutCubic(x)
	return 1 - (1 - x) ^ 3
end

local function Smooth(current, target, speed)
	return Lerp(1 - math.exp(-RealFrameTime() * speed), current, target)
end

DEFINE_BASECLASS("ixSubpanelParent")
local PANEL = {}

AccessorFunc(PANEL, "bCharacterOverview", "CharacterOverview", FORCE_BOOL)

function PANEL:Init()
	if (IsValid(ix.gui.menu)) then
		ix.gui.menu:Remove()
	end

	ix.gui.menu = self

	-- properties
	self.manualChildren = {}
	self.noAnchor = CurTime() + 0.4
	self.anchorMode = true
	self.rotationOffset = Angle(0, 180, 0)
	self.projectedTexturePosition = Vector(0, 0, 6)
	self.projectedTextureRotation = Angle(-45, 60, 0)

	self.bCharacterOverview = false
	self.bOverviewOut = false
	self.overviewFraction = 0

	self.currentAlpha = 0
	self.currentBlur = 0
	self.barFrac = 0

	-- геометрия
	local width, height = ScrW(), ScrH()
	local side = ScreenScale(16)
	local margin = math.max(side, math.floor(height * CFG.marginFraction))

	self.sidePadding = side
	self.margin = margin
	self.contentX = math.floor(width * CFG.contentLeft + side)
	self.contentW = width - self.contentX - side
	self.contentH = height - margin * 2

	self.tabsY = math.floor(margin * 0.17)
	self.tabsH = math.floor(margin * 0.44)
	self.sectionY = self.tabsY + self.tabsH + math.floor(margin * 0.02)
	self.sectionH = math.floor(margin * 0.27)

	-- setup
	self:SetPadding(margin, true)
	self:SetSize(width, height)
	self:SetPos(0, 0)
	self:SetLeftOffset(CFG.paddingAddsToX and (self.contentX - margin) or self.contentX)

	-- защита от кликов в верхнем и нижнем отступах
	self.guardTop = self:Add("Panel")
	self.guardTop:SetPos(0, 0)
	self.guardTop:SetSize(width, margin)

	self.guardBottom = self:Add("Panel")
	self.guardBottom:SetPos(0, height - margin)
	self.guardBottom:SetSize(width, margin)

	-- верхняя панель: вкладки + подразделы
	self.topBar = self:Add("Panel")
	self.topBar:SetSize(width, margin)
	self.topBar:SetPaintedManually(true)
	self.topBar.Paint = function(panel, w, h)
		self:PaintTopBar(w, h)
	end

	self.tabs = self.topBar:Add("Panel")
	self.tabs:SetPos(self.contentX, self.tabsY)
	self.tabs:SetSize(self.contentW, self.tabsH)
	self.tabs.buttons = {}
	self.tabs.Paint = function(panel, w, h)
		self:PaintTabIndicator(panel, w, h)
	end

	self.sectionBar = self.topBar:Add("Panel")
	self.sectionBar:SetPos(self.contentX, self.sectionY)
	self.sectionBar:SetSize(self.contentW, self.sectionH)

	-- нижняя панель: кнопки действий
	self.bottomBar = self:Add("Panel")
	self.bottomBar:SetSize(width, margin)
	self.bottomBar:SetPaintedManually(true)
	self.bottomBar.Paint = function(panel, w, h)
		self:PaintBottomBar(w, h)
	end

	local close = self.bottomBar:Add("ixMenuLinkButton")
	close:SetText("return")
	close:SizeToContents()
	close:SetPos(side, math.floor((margin - close:GetTall()) * 0.5))
	close.revealStart = RealTime() + 0.55
	close.DoClick = function()
		self:Remove()
	end

	local characters = self.bottomBar:Add("ixMenuLinkButton")
	characters:SetText("characters")
	characters:SizeToContents()
	characters:SetPos(side + close:GetWide() + S(36), math.floor((margin - characters:GetTall()) * 0.5))
	characters.revealStart = RealTime() + 0.65
	characters.DoClick = function()
		self:Remove()
		vgui.Create("ixCharMenu")
	end

	self:UpdateBars()
	self:PopulateTabs()

	self:MakePopup()
	self:OnOpened()
end

function PANEL:OnOpened()
	self:SetAlpha(0)

	self:CreateAnimation(animationTime, {
		target = {currentAlpha = 255},
		easing = "outQuint",

		Think = function(animation, panel)
			panel:SetAlpha(panel.currentAlpha)
		end
	})

	-- верхняя и нижняя полосы плавно выезжают за края экрана
	self:CreateAnimation(animationTime * 1.2, {
		index = 4,
		target = {barFrac = 1},
		easing = "outQuint",

		Think = function(animation, panel)
			panel:UpdateBars()
		end
	})
end

-- положение полос зависит от barFrac (0 = за экраном, 1 = на месте)
function PANEL:UpdateBars()
	local offset = self.margin * (1 - self.barFrac)

	if (IsValid(self.topBar)) then
		self.topBar:SetPos(0, -offset)
	end

	if (IsValid(self.bottomBar)) then
		self.bottomBar:SetPos(0, self:GetTall() - self.margin + offset)
	end
end

function PANEL:GetActiveTab()
	return (self:GetActiveSubpanel() or {}).subpanelName
end

function PANEL:TransitionSubpanel(id)
	local lastSubpanel = self:GetActiveSubpanel()

	-- don't transition to the same panel
	if (IsValid(lastSubpanel) and lastSubpanel.subpanelID == id) then
		return
	end

	local subpanel = self:GetSubpanel(id)

	if (IsValid(subpanel)) then
		if (!subpanel.bPopulated) then
			-- we need to set the size of the subpanel if it's a section since it will be 0, 0
			if (subpanel.sectionParent) then
				subpanel:SetSize(self:GetStandardSubpanelSize())
			end

			local info = subpanel.info
			subpanel.Paint = nil

			if (istable(info) and info.Create) then
				info:Create(subpanel)
			elseif (isfunction(info)) then
				info(subpanel)
			end

			hook.Run("MenuSubpanelCreated", subpanel.subpanelName, subpanel)
			subpanel.bPopulated = true
		end

		-- only play whoosh sound only when the menu was already open
		if (IsValid(lastSubpanel)) then
			LocalPlayer():EmitSound("Helix.Whoosh")
		end

		self:SetActiveSubpanel(id)
	end

	subpanel = self:GetActiveSubpanel()

	local info = subpanel.info
	local bHideBackground = istable(info) and (info.bHideBackground != nil and info.bHideBackground or false) or false

	if (bHideBackground) then
		self:HideBackground()
	else
		self:ShowBackground()
	end

	-- call hooks if we've changed subpanel
	if (IsValid(lastSubpanel) and istable(lastSubpanel.info) and lastSubpanel.info.OnDeselected) then
		lastSubpanel.info:OnDeselected(lastSubpanel)
	end

	if (IsValid(subpanel) and istable(subpanel.info) and subpanel.info.OnSelected) then
		subpanel.info:OnSelected(subpanel)
	end

	ix.gui.lastMenuTab = id
end

function PANEL:SetCharacterOverview(bValue, length)
	bValue = tobool(bValue)
	length = length or animationTime

	if (bValue) then
		if (!IsValid(self.projectedTexture)) then
			self.projectedTexture = ProjectedTexture()
		end

		local faction = ix.faction.indices[LocalPlayer():Team()]
		local color = faction and faction.color or color_white

		self.projectedTexture:SetEnableShadows(false)
		self.projectedTexture:SetNearZ(12)
		self.projectedTexture:SetFarZ(64)
		self.projectedTexture:SetFOV(90)
		self.projectedTexture:SetColor(color)
		self.projectedTexture:SetTexture("effects/flashlight/soft")

		self:CreateAnimation(length, {
			index = 3,
			target = {overviewFraction = 1},
			easing = "outQuint",
			bIgnoreConfig = true
		})

		self.bOverviewOut = false
		self.bCharacterOverview = true
	else
		self:CreateAnimation(length, {
			index = 3,
			target = {overviewFraction = 0},
			easing = "outQuint",
			bIgnoreConfig = true,

			OnComplete = function(animation, panel)
				panel.bCharacterOverview = false

				if (IsValid(panel.projectedTexture)) then
					panel.projectedTexture:Remove()
				end
			end
		})

		self.bOverviewOut = true
	end
end

function PANEL:GetOverviewInfo(origin, angles, fov)
	local originAngles = Angle(0, angles.yaw, angles.roll)
	local target = LocalPlayer():GetObserverTarget()
	local fraction = self.overviewFraction
	local bDrawPlayer = ((fraction > 0.2) or (!self.bOverviewOut and (fraction > 0.2))) and !IsValid(target)
	local forward = originAngles:Forward() * 58 - originAngles:Right() * 16
	forward.z = 0

	local newOrigin

	if (IsValid(target)) then
		newOrigin = target:GetPos() + forward
	else
		newOrigin = origin - LocalPlayer():OBBCenter() * 0.6 + forward
	end

	local newAngles = originAngles + self.rotationOffset
	newAngles.pitch = 5
	newAngles.roll = 0

	return LerpVector(fraction, origin, newOrigin), LerpAngle(fraction, angles, newAngles), Lerp(fraction, fov, 90), bDrawPlayer
end

function PANEL:HideBackground()
	self:CreateAnimation(animationTime, {
		index = 2,
		target = {currentBlur = 0},
		easing = "outQuint"
	})
end

function PANEL:ShowBackground()
	self:CreateAnimation(animationTime, {
		index = 2,
		target = {currentBlur = 1},
		easing = "outQuint"
	})
end

function PANEL:GetStandardSubpanelSize()
	return self.contentW, self.contentH
end

function PANEL:SetupTab(name, info, sectionParent)
	local bTable = istable(info)
	local buttonColor = (bTable and info.buttonColor) or GetAccent()
	local bDefault = (bTable and info.bDefault) or false
	local qualifiedName = sectionParent and (sectionParent.name .. "/" .. name) or name

	-- setup subpanels without populating them so we can retain the order
	local subpanel = self:AddSubpanel(qualifiedName, true)
	local id = subpanel.subpanelID
	subpanel.info = info
	subpanel.sectionParent = sectionParent and qualifiedName
	subpanel:SetPaintedManually(true)
	subpanel:SetTitle(nil)

	if (sectionParent) then
		-- hide section subpanels if they haven't been populated to seeing more subpanels than necessary
		-- fly by as you navigate tabs in the menu
		subpanel:SetSize(0, 0)
	else
		subpanel:SetSize(self:GetStandardSubpanelSize())

		-- this is called while the subpanel has not been populated
		subpanel.Paint = function(panel, width, height)
			derma.SkinFunc("PaintPlaceholderPanel", panel, width, height)
		end
	end

	local button

	if (sectionParent) then
		button = sectionParent:AddSection(L(name))
		name = qualifiedName
	else
		button = self.tabs:Add("ixMenuSelectionButton")
		button.sectionHost = self.sectionBar
		button:SetText(L(name))
		button:SizeToContents()
		button:Dock(LEFT)
		button:SetButtonList(self.tabs.buttons)
		button:SetBackgroundColor(buttonColor)

		-- вкладки появляются по очереди
		self.tabCount = (self.tabCount or 0) + 1
		button.revealStart = RealTime() + 0.2 + self.tabCount * 0.06
		button.tabIndex = self.tabCount
	end

	button.name = name
	button.id = id
	button.OnSelected = function()
		self:TransitionSubpanel(id)
	end

	if (bTable and info.PopulateTabButton) then
		local classPaint = button.Paint

		info:PopulateTabButton(button)

		-- свой Paint из PopulateTabButton (например, у settings) отключает анимации новой кнопки:
		-- убираем его и вместо верхней линии рисуем разделитель
		if (button.Paint != classPaint) then
			button.Paint = nil
			button.bSeparator = true
		end
	end

	-- don't allow sections in sections
	if (sectionParent or !bTable or !info.Sections) then
		return bDefault, button, subpanel
	end

	-- create button sections
	for sectionName, sectionInfo in pairs(info.Sections) do
		self:SetupTab(sectionName, sectionInfo, button)
	end

	return bDefault, button, subpanel
end

function PANEL:PopulateTabs()
	local default
	local tabs = {}

	hook.Run("CreateMenuButtons", tabs)

	for name, info in SortedPairs(tabs) do
		local bDefault, button = self:SetupTab(name, info)

		if (bDefault) then
			default = button
		end
	end

	-- вкладки по центру области контента
	local totalWidth = 0

	for _, child in ipairs(self.tabs:GetChildren()) do
		totalWidth = totalWidth + child:GetWide()
	end

	self.tabs:DockPadding(math.max(math.floor((self.contentW - totalWidth) * 0.5), 0), 0, 0, 0)

	-- раскладываем вкладки сразу, чтобы скользящая линия сразу знала их позиции
	self.tabs:InvalidateLayout(true)

	if (ix.gui.lastMenuTab) then
		for i = 1, #self.tabs.buttons do
			local button = self.tabs.buttons[i]

			if (button.id == ix.gui.lastMenuTab) then
				default = button
				break
			end
		end
	end

	if (!IsValid(default) and #self.tabs.buttons > 0) then
		default = self.tabs.buttons[1]
	end

	if (IsValid(default)) then
		default:SetSelected(true)
		self:SetActiveSubpanel(default.id, 0)
	end

	self.topBar:MoveToFront()
	self.bottomBar:MoveToFront()
	self.guardTop:MoveToBefore(self.topBar)
	self.guardBottom:MoveToBefore(self.bottomBar)
end

function PANEL:AddManuallyPaintedChild(panel)
	panel:SetParent(self)
	panel:SetPaintedManually(true)

	self.manualChildren[#self.manualChildren + 1] = panel
end

function PANEL:OnKeyCodePressed(key)
	self.noAnchor = CurTime() + 0.5

	if (key == KEY_TAB) then
		self:Remove()
	end
end

function PANEL:Think()
	if (IsValid(self.projectedTexture)) then
		local forward = LocalPlayer():GetForward()
		forward.z = 0

		local right = LocalPlayer():GetRight()
		right.z = 0

		self.projectedTexture:SetBrightness(self.overviewFraction * 4)
		self.projectedTexture:SetPos(LocalPlayer():GetPos() + right * 16 - forward * 8 + self.projectedTexturePosition)
		self.projectedTexture:SetAngles(forward:Angle() + self.projectedTextureRotation)
		self.projectedTexture:Update()
	end

	if (self.bClosing) then
		return
	end

	local bTabDown = input.IsKeyDown(KEY_TAB)

	if (bTabDown and (self.noAnchor or CurTime() + 0.4) < CurTime() and self.anchorMode) then
		self.anchorMode = false
		surface.PlaySound("buttons/lightswitch2.wav")
	end

	if ((!self.anchorMode and !bTabDown) or gui.IsGameUIVisible()) then
		self:Remove()

		if (ix.option.Get("escCloseMenu", false)) then
			gui.HideGameUI()
		end
	end
end

-- затемнённые полосы сверху и снизу и тонкие линии на их границах
function PANEL:PaintBars(width, height)
	local f = self.barFrac
	local m = self.margin
	local offset = m * (1 - f)
	local accent = GetAccent()

	draw.NoTexture()

	if (CFG.barAlpha > 0) then
		surface.SetDrawColor(7, 10, 15, CFG.barAlpha)
		surface.DrawRect(0, -offset, width, m)
		surface.DrawRect(0, height - m + offset, width, m)
	end

	if (CFG.lineAlpha > 0) then
		-- линии разрастаются от центра к краям
		local lineWidth = math.floor(width * f)
		local x = math.floor((width - lineWidth) * 0.5)

		surface.SetDrawColor(accent.r, accent.g, accent.b, CFG.lineAlpha)
		surface.DrawRect(x, math.floor(m - offset) - 1, lineWidth, 1)
		surface.DrawRect(x, math.floor(height - m + offset), lineWidth, 1)

		-- яркие отрезки и засечки на линиях
		local side = self.sidePadding
		local seg = S(60)
		local ty = math.floor(m - offset) - 1
		local by = math.floor(height - m + offset)
		local tick = S(6)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 230 * f)
		surface.DrawRect(side, ty - 1, seg, 3)
		surface.DrawRect(width - side - seg, by - 1, seg, 3)

		-- мягкое свечение у линий
		for i = 1, 10 do
			local glow = 20 * (1 - i / 10) ^ 2 * f

			surface.SetDrawColor(accent.r, accent.g, accent.b, glow)
			surface.DrawRect(0, ty - i * 3, width, 3)
			surface.DrawRect(0, by + 1 + (i - 1) * 3, width, 3)
		end

		-- блик, медленно бегущий по линиям
		if (CFG.sweep) then
			local parts = 16
			local seg = S(160) / parts
			local head = ((RealTime() * 0.09) % 1.6 - 0.3) * width

			for i = 0, parts - 1 do
				local x = head + i * seg

				if (x >= 0 and x + seg <= width) then
					local k = math.sin((i + 0.5) / parts * math.pi)

					surface.SetDrawColor(accent.r, accent.g, accent.b, 170 * k * f)
					surface.DrawRect(math.floor(x), by, math.ceil(seg) + 1, 1)
					surface.DrawRect(math.floor(width - x - seg), ty, math.ceil(seg) + 1, 1)
				end
			end
		end

		surface.SetDrawColor(accent.r, accent.g, accent.b, 110 * f)
		surface.DrawRect(side, ty - tick, 1, tick)
		surface.DrawRect(width - side - 1, ty - tick, 1, tick)
		surface.DrawRect(side, by + 1, 1, tick)
		surface.DrawRect(width - side - 1, by + 1, 1, tick)
	end
end

function PANEL:PaintTopBar(width, height)
	local a = math.Clamp(self.barFrac, 0, 1)
	local accent = GetAccent()
	local centerY = self.tabsY + math.floor(self.tabsH * 0.5)

	if (CFG.showBrand and ix.menuStyle.projectName) then
		local x = self.sidePadding

		draw.NoTexture()
		surface.SetDrawColor(accent.r, accent.g, accent.b, 255 * a)
		surface.DrawRect(x, centerY - S(8), 2, S(16))

		draw.SimpleText(ix.menuStyle.projectName, "ixMenuTabFont", x + S(12), centerY, Color(255, 255, 255, 200 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local right = width - self.sidePadding

	if (CFG.showClock) then
		draw.SimpleText(os.date("%H:%M"), "ixMenuLinkFont", right, centerY - S(7), Color(255, 255, 255, 190 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	if (CFG.showHint) then
		draw.SimpleText(CFG.hintText, "ixMenuTinyFont", right, centerY + (CFG.showClock and S(9) or 0), Color(255, 255, 255, 90 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

-- нижняя панель: статистика по центру, имя персонажа и фракция справа
function PANEL:PaintBottomBar(width, height)
	local a = math.Clamp(self.barFrac, 0, 1)
	local accent = GetAccent()
	local centerY = math.floor(height * 0.5)
	local ply = LocalPlayer()

	if (CFG.showStats) then
		local name = GetHostName() or ""

		if ((utf8.len(name) or 0) > 24) then
			name = name:sub(1, (utf8.offset(name, 25) or (#name + 1)) - 1) .. "…"
		end

		local columns = {
			{"СЕРВЕР", name},
			{"ИГРОКИ", #player.GetAll() .. " / " .. game.MaxPlayers()},
			{"ПИНГ", ply:Ping() .. " МС"}
		}

		local gap = S(48)
		local widths = {}
		local total = gap * (#columns - 1)

		for i, column in ipairs(columns) do
			surface.SetFont("ixMenuTinyFont")
			local lw = surface.GetTextSize(column[1])
			surface.SetFont("ixMenuTabFontSmall")
			local vw = surface.GetTextSize(column[2])

			widths[i] = math.max(lw, vw)
			total = total + widths[i]
		end

		local x = math.floor((width - total) * 0.5)

		draw.NoTexture()

		for i, column in ipairs(columns) do
			local cx = x + math.floor(widths[i] * 0.5)

			draw.SimpleText(column[1], "ixMenuTinyFont", cx, centerY - S(8), Color(accent.r, accent.g, accent.b, 190 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(column[2], "ixMenuTabFontSmall", cx, centerY + S(8), Color(255, 255, 255, 200 * a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			x = x + widths[i]

			if (i < #columns) then
				surface.SetDrawColor(255, 255, 255, 30 * a)
				surface.DrawRect(x + math.floor(gap * 0.5), centerY - S(12), 1, S(24))
				x = x + gap
			end
		end
	end

	if (!CFG.showCharacter) then
		return
	end

	local character = ply.GetCharacter and ply:GetCharacter()

	if (!character) then
		return
	end

	local right = width - self.sidePadding
	local faction = ix.faction.indices[ply:Team()]

	draw.NoTexture()
	surface.SetDrawColor(accent.r, accent.g, accent.b, 255 * a)
	surface.DrawRect(right - 2, centerY - S(14), 2, S(28))

	draw.SimpleText(character:GetName(), "ixMenuLinkFont", right - S(12), centerY - (faction and S(7) or 0), Color(255, 255, 255, 210 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	if (faction) then
		draw.SimpleText(L(faction.name):utf8upper(), "ixMenuTinyFont", right - S(12), centerY + S(9), Color(accent.r, accent.g, accent.b, 200 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

-- линия под активной вкладкой плавно скользит между вкладками
function PANEL:PaintTabIndicator(panel, width, height)
	local a = math.Clamp(self.barFrac, 0, 1)
	local target

	for _, button in ipairs(panel.buttons) do
		if (IsValid(button) and button.selected) then
			target = button.sectionParent or button
			break
		end
	end

	draw.NoTexture()

	-- тонкая базовая линия
	surface.SetDrawColor(255, 255, 255, 18 * a)
	surface.DrawRect(0, height - 1, width, 1)

	if (!IsValid(target)) then
		return
	end

	local x, w = target:GetX(), target:GetWide()

	if (!panel.indicatorX) then
		panel.indicatorX, panel.indicatorW = x, w
	end

	panel.indicatorX = Smooth(panel.indicatorX, x, 12)
	panel.indicatorW = Smooth(panel.indicatorW, w, 12)

	local color = target:GetBackgroundColor() or GetAccent()
	local inset = target.padding and target.padding[1] or 0

	local ix0 = math.floor(panel.indicatorX + inset)
	local iw = math.max(math.floor(panel.indicatorW - inset * 2), 1)

	-- мягкое свечение над линией
	for i = 1, 8 do
		surface.SetDrawColor(color.r, color.g, color.b, 5 * (9 - i) / 8 * 2.2 * a)
		surface.DrawRect(ix0, height - 2 - i, iw, 1)
	end

	surface.SetDrawColor(color.r, color.g, color.b, 255 * a)
	surface.DrawRect(ix0, height - 2, iw, 2)

	-- засечки на концах линии
	surface.DrawRect(ix0, height - 7, 1, 5)
	surface.DrawRect(ix0 + iw - 1, height - 7, 1, 5)
end

function PANEL:Paint(width, height)
	derma.SkinFunc("PaintMenuBackground", self, width, height, self.currentBlur)

	local bShouldScale = self.currentAlpha != 255

	if (bShouldScale) then
		local currentScale = Lerp(self.currentAlpha / 255, 0.96, 1)
		local matrix = Matrix()

		matrix:Scale(matrixZScale * currentScale)
		matrix:Translate(Vector(
			ScrW() * 0.5 - (ScrW() * currentScale * 0.5),
			ScrH() * 0.5 - (ScrH() * currentScale * 0.5),
			1
		))

		cam.PushModelMatrix(matrix)
	end

	BaseClass.Paint(self, width, height)
	self:PaintBars(width, height)
	self:PaintSubpanels(width, height)
	self.topBar:PaintManual()
	self.bottomBar:PaintManual()

	for i = 1, #self.manualChildren do
		self.manualChildren[i]:PaintManual()
	end

	if (IsValid(ix.gui.inv1) and ix.gui.inv1.childPanels) then
		for i = 1, #ix.gui.inv1.childPanels do
			local panel = ix.gui.inv1.childPanels[i]

			if (IsValid(panel)) then
				panel:PaintManual()
			end
		end
	end

	if (bShouldScale) then
		cam.PopModelMatrix()
	end
end

function PANEL:PerformLayout()
end

function PANEL:Remove()
	self.bClosing = true
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
	self:SetCharacterOverview(false, animationTime * 0.5)

	-- remove input from opened child panels since they grab focus
	if (IsValid(ix.gui.inv1) and ix.gui.inv1.childPanels) then
		for i = 1, #ix.gui.inv1.childPanels do
			local panel = ix.gui.inv1.childPanels[i]

			if (IsValid(panel)) then
				panel:SetMouseInputEnabled(false)
				panel:SetKeyboardInputEnabled(false)
			end
		end
	end

	CloseDermaMenus()
	gui.EnableScreenClicker(false)

	self:CreateAnimation(animationTime * 0.5, {
		index = 2,
		target = {currentBlur = 0},
		easing = "outQuint"
	})

	-- полосы уезжают обратно за края экрана
	self:CreateAnimation(animationTime * 0.5, {
		index = 4,
		target = {barFrac = 0},
		easing = "outQuint",

		Think = function(animation, panel)
			panel:UpdateBars()
		end
	})

	self:CreateAnimation(animationTime * 0.5, {
		target = {currentAlpha = 0},
		easing = "outQuint",

		-- we don't animate the blur because blurring doesn't draw things
		-- with amount < 1 very well, resulting in jarring transition
		Think = function(animation, panel)
			panel:SetAlpha(panel.currentAlpha)
		end,

		OnComplete = function(animation, panel)
			if (IsValid(panel.projectedTexture)) then
				panel.projectedTexture:Remove()
			end

			BaseClass.Remove(panel)
		end
	})
end

vgui.Register("ixMenu", PANEL, "ixSubpanelParent")

if (IsValid(ix.gui.menu)) then
	ix.gui.menu:Remove()
end

ix.gui.lastMenuTab = nil