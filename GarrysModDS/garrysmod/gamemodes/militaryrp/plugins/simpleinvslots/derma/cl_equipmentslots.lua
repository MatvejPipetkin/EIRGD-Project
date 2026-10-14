local PLUGIN = PLUGIN

-- общий стиль меню (тот же, что в cl_inventory.lua / cl_menu.lua)
ix.menuStyle = ix.menuStyle or {accent = Color(90, 160, 235), projectName = "EIRGD"}

--[[
	НАСТРОЙКИ (все размеры указаны для экрана 1080p и сами масштабируются под разрешение)
]]
local CFG = {
	-- ячейка слота
	slotCell = 100,

	-- панель экипировки в меню инвентаря (привязана к экрану, а не к другим панелям)
	plateX = 48, -- отступ от левого края (как у верхней строки меню)
	plateY = 100, -- отступ от верха (на одной линии с панелью "Инвентарь")

	-- внутренние отступы панели
	headerH = 40, -- высота шапки
	padX = 20, -- боковые отступы
	padY = 14, -- отступ под шапкой и над низом
	gapX = 14, -- расстояние между колонками
	gapY = 10, -- расстояние между рядами
	labelH = 20, -- высота подписи над слотом

	-- 3D-модель персонажа между колонками слотов (с кнопками поворота "<" ">")
	showCharModel = true,
	modelW = 220, -- ширина области модели
	charFOV = 15, -- чем меньше, тем крупнее модель
	charCamOffset = Vector(40, 50, 10), -- смещение камеры (вправо, вперёд, вниз)
	charLookOffset = Vector(0, 0, 0) -- смещение точки, на которую смотрит камера
}

--[[
	РАСКЛАДКА
	Ключ = имя слота из PLUGIN.slots (регистр важен!).
	col - колонка (1 = левая, 2 = правая), row - ряд сверху вниз.
	key - необязательно: цифра/клавиша в правом верхнем углу слота.

	Если слота здесь нет, он встанет по своим location/pos из sh_plugin.lua.
]]
local LAYOUT = {
	Head = {col = 1, row = 1},
	Eyes = {col = 1, row = 2},
	Face = {col = 1, row = 3},
	Torso = {col = 1, row = 4},

	Hands = {col = 2, row = 1},
	Legs = {col = 2, row = 2},
	Shoes = {col = 2, row = 3},
	Outfit = {col = 2, row = 4}
}

local COLOR_PLATE = Color(8, 14, 28, 225)
local COLOR_HEADER = Color(6, 11, 22, 245)
local COLOR_LABEL = Color(150, 178, 212, 235)
local COLOR_TITLE = Color(235, 242, 252)
local COLOR_KEY = Color(255, 255, 255, 170)

local function S(value)
	return math.floor(value * ScrH() / 1080 + 0.5)
end

local function GetAccent()
	return ix.menuStyle.accent or ix.config.Get("color") or Color(90, 160, 235)
end

-- позиция слота в сетке: из LAYOUT или из location/pos самого плагина
local function GetGridPos(name, tSlot)
	local cfg = LAYOUT[name]

	if (cfg) then
		return cfg.col or 1, cfg.row or 1
	end

	local isRight = RIGHT != nil and tSlot.location == RIGHT

	return isRight and 2 or 1, tSlot.pos or 1
end

local PANEL = {}
DEFINE_BASECLASS("DFrame")

function PANEL:Init()
	self.panels = {} -- имя слота -> панель ixInventory
	self.holders = {} -- имя слота -> контейнер (подпись + панель)
	self.panelW, self.panelH = 0, 0
	self.plateTitle = L("slotsEquipmentSlots")
	self.filled = 0
	self.screenMode = false

	-- стандартные элементы DFrame скрыты, шапку рисуем сами
	self:SetTitle("")
	self:ShowCloseButton(false)
	self:SetDraggable(false)
	self:SetSizable(false)
	self:DockPadding(0, 0, 0, 0)
	self.lblTitle:SetVisible(false)

	for name, tSlot in SortedPairsByMemberValue(PLUGIN.slots, "pos") do
		self:CreateSlot(name, tSlot)
	end

	self:LayoutSlots()
end

-- режим "в меню": панель привязана к экрану, без кнопки закрытия
function PANEL:SetScreenMode()
	self.screenMode = true
	self.host = self:GetParent()
	self.plateTitle = L("slotsEquipmentSlots")

	self:ShowCloseButton(false)

	if (CFG.showCharModel and !IsValid(self.modelPanel)) then
		self.modelPanel = vgui.Create("ixEquipmentSlotsCharModel", self)

		if (ix.gui.inv1 and IsValid(ix.gui.inv1)) then
			ix.gui.inv1.charModel = self.modelPanel
		end
	end

	self:LayoutSlots()
	self:UpdateScreenPos(true)
end

-- режим "окно" (обыск / чужая экипировка): отдельное окно с кнопкой закрытия
function PANEL:SetTitle(text)
	if (text and text != "") then
		self.plateTitle = text
	end

	BaseClass.SetTitle(self, "")
end

function PANEL:EnableCloseButton()
	self:ShowCloseButton(true)

	local close = self.btnClose

	if (IsValid(close)) then
		close:SetText("")
		close.Paint = function(this, width, height)
			local accent = GetAccent()
			local a = this:IsHovered() and 255 or 150
			local m = S(9)

			surface.SetDrawColor(accent.r, accent.g, accent.b, a)
			surface.DrawLine(m, m, width - m, height - m)
			surface.DrawLine(width - m, m, m, height - m)
		end
	end
end

function PANEL:PerformLayout(width, height)
	BaseClass.PerformLayout(self, width, height)

	if (IsValid(self.btnClose) and self.btnClose:IsVisible()) then
		local size = S(CFG.headerH)

		self.btnClose:SetSize(size, size)
		self.btnClose:SetPos(width - size, 0)
	end
end

function PANEL:Paint(width, height)
	local accent = GetAccent()
	local headerH = S(CFG.headerH)

	-- фон и рамка
	surface.SetDrawColor(COLOR_PLATE)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 170)
	surface.DrawOutlinedRect(0, 0, width, height, 1)

	-- шапка
	surface.SetDrawColor(COLOR_HEADER)
	surface.DrawRect(1, 1, width - 2, headerH - 1)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 255)
	surface.DrawRect(S(8), S(11), S(2), headerH - S(22)) -- вертикальная метка слева
	surface.DrawRect(1, headerH - 1, S(40), 2) -- короткая подчёркивающая линия

	surface.SetDrawColor(accent.r, accent.g, accent.b, 120)
	surface.DrawRect(S(40) + 1, headerH, width - S(40) - 2, 1)

	draw.SimpleText(self.plateTitle, "ixMenuTinyFont", S(18), headerH * 0.5, COLOR_TITLE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	if (!(IsValid(self.btnClose) and self.btnClose:IsVisible())) then
		draw.SimpleText(L("slotsCounter", self.filled, table.Count(self.panels)), "ixMenuTinyFont",
			width - S(12), headerH * 0.5, accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

function PANEL:CreateSlot(name, tSlot)
	local cfg = LAYOUT[name] or {}
	local labelH = S(CFG.labelH)
	local cell = S(CFG.slotCell)

	-- контейнер: подпись сверху + сама сетка слота
	local holder = vgui.Create("DPanel", self)
	holder:NoClipping(true)
	holder.label = cfg.label or L("slots" .. name)
	holder.Paint = function(this, width, height)
		draw.SimpleText(this.label, "ixMenuTinyFont", S(2), labelH * 0.5, COLOR_LABEL, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local panel = vgui.Create("ixInventory", holder)

	-- фиксируем размер ячейки слота (ixInventory:SetInventory подменяет его размером основного инвентаря)
	local setIconSize = panel.SetIconSize

	panel.fixedIconSize = cell
	panel.SetIconSize = function(this, size)
		setIconSize(this, this.fixedIconSize or size)
	end

	panel:SetIconSize(cell)
	panel:SetTitle(nil) -- без шапки, подпись рисует контейнер
	panel:SetDraggable(false)
	panel:SetSizable(false)
	panel.bNoBackgroundBlur = true
	panel:SetSize(cell + 8, cell + 8)
	panel:SetPos(0, labelH)

	if (cfg.key) then
		local paintOver = panel.PaintOver

		panel.PaintOver = function(this, width, height)
			if (paintOver) then paintOver(this, width, height) end

			draw.SimpleText(cfg.key, "ixMenuTinyFont", width - S(7), S(6), COLOR_KEY, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		end
	end

	holder:SetSize(panel:GetWide(), labelH + panel:GetTall())

	self.holders[name] = holder
	self.panels[name] = panel
end

-- раскладывает слоты по сетке 2 x 4 внутри панели и подгоняет размер панели под содержимое
function PANEL:LayoutSlots()
	local gapX, gapY = S(CFG.gapX), S(CFG.gapY)
	local padX, padY = S(CFG.padX), S(CFG.padY)
	local headerH = S(CFG.headerH)

	local modelPanel = IsValid(self.modelPanel) and self.modelPanel
	local extra = modelPanel and (S(CFG.modelW) + gapX) or 0

	local grid, maxCol, maxRow = {}, 1, 1
	local colW, rowH = 0, 0

	for name, holder in pairs(self.holders) do
		local col, row = GetGridPos(name, PLUGIN.slots[name] or {})

		grid[#grid + 1] = {holder = holder, col = col, row = row}

		maxCol, maxRow = math.max(maxCol, col), math.max(maxRow, row)
		colW = math.max(colW, holder:GetWide())
		rowH = math.max(rowH, holder:GetTall())
	end

	for _, entry in ipairs(grid) do
		entry.holder:SetPos(
			padX + (entry.col - 1) * (colW + gapX) + (entry.col >= 2 and extra or 0),
			headerH + padY + (entry.row - 1) * (rowH + gapY)
		)
	end

	local gridH = maxRow * rowH + (maxRow - 1) * gapY

	if (modelPanel) then
		modelPanel:SetPos(padX + colW + gapX, headerH + padY + S(CFG.labelH))
		modelPanel:SetSize(S(CFG.modelW), gridH - S(CFG.labelH))
	else
		extra = 0
	end

	self.panelW = padX * 2 + maxCol * colW + (maxCol - 1) * gapX + (maxCol >= 2 and extra or 0)
	self.panelH = headerH + padY * 2 + gridH

	self:SetSize(self.panelW, self.panelH)
end

-- в меню панель всегда стоит на одном и том же месте экрана, даже если родитель двигается/анимируется
function PANEL:UpdateScreenPos(bForce)
	if (!self.screenMode or !IsValid(self.host)) then return end

	local x, y = self.host:ScreenToLocal(S(CFG.plateX), S(CFG.plateY))

	if (bForce or x != self.lastX or y != self.lastY) then
		self.lastX, self.lastY = x, y
		self:SetPos(x, y)
	end
end

function PANEL:Think()
	BaseClass.Think(self)

	self:UpdateScreenPos()

	-- счётчик занятых слотов
	if ((self.nextCount or 0) < CurTime()) then
		self.nextCount = CurTime() + 0.25

		local filled = 0

		for _, panel in pairs(self.panels) do
			local inventory = IsValid(panel) and panel.GetInventory and panel:GetInventory()

			if (inventory and inventory.GetItems and next(inventory:GetItems())) then
				filled = filled + 1
			end
		end

		self.filled = filled
	end
end

function PANEL:SetInventory(ids)
	for name, panel in pairs(self.panels) do
		local id = ids[name]

		if (!id or !IsValid(panel)) then continue end

		local inventory = ix.item.inventories[id]

		if (!inventory) then continue end

		panel:SetInventory(inventory)
		panel.id = id
		ix.gui["inv" .. id] = panel

		-- размер слота теперь известен (зависит от инвентаря), подгоняем контейнер
		self.holders[name]:SetSize(panel:GetWide(), S(CFG.labelH) + panel:GetTall())
	end

	self:LayoutSlots()
	self:UpdateScreenPos(true)
end

vgui.Register("ixEquipmentSlots", PANEL, "DFrame")

-- конфиг доступен для cl_plugin.lua
PLUGIN.slotsCFG = CFG

PANEL = {}

local CHAR_TIMER = "ixSimpleInvSlots_UpdateCharModel"

-- модель пересоздаём только при смене модели, остальное (скин, бодигруппы) обновляем на месте
local function ApplyAppearance(panel)
	local client = LocalPlayer()

	if (!IsValid(client) or !IsValid(panel.Entity)) then return end

	if (string.lower(panel.Entity:GetModel() or "") != string.lower(client:GetModel())) then
		panel:SetModel(client:GetModel())
		panel.baseAngles = nil

		if (!IsValid(panel.Entity)) then return end
	end

	panel.Entity:SetSkin(client:GetSkin())

	for _, v in pairs(client:GetBodyGroups()) do
		panel.Entity:SetBodygroup(v.id, client:GetBodygroup(v.id))
	end
end

-- кнопки "<" ">" для поворота персонажа (зажать — вращать)
local function CreateRotateButton(panel, direction)
	local button = panel:Add("DButton")

	button:SetText(direction < 0 and "<" or ">")
	button:SetFont("ixMenuTinyFont")
	button:SetTextColor(color_white)
	button.Paint = function(this, width, height)
		local accent = GetAccent()

		draw.NoTexture()

		surface.SetDrawColor(accent.r, accent.g, accent.b, this:IsDown() and 80 or (this:IsHovered() and 45 or 18))
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 200)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
	end
	button.Think = function(this)
		if (this:IsDown()) then
			panel.yaw = ((panel.yaw or 0) + direction * FrameTime() * 120) % 360
		end
	end

	return button
end

function PANEL:Init()
	local character = LocalPlayer():GetCharacter()
	if !character then return end

	self:SetModel(LocalPlayer():GetModel())

	for index, value in pairs(character:GetData("groups", {})) do
		self.Entity:SetBodygroup(index, value or 0)
	end

	self.Entity:SetSkin(LocalPlayer():GetSkin())
	self:SetFOV(PLUGIN.slotsCFG.charFOV or 25)
	self.PaintModel = self.Paint

	self.Paint = function(this, width, height)
		local accent = GetAccent()

		surface.SetDrawColor(5, 10, 20, 210)
		surface.DrawRect(0, 0, width, height)

		this:PaintModel(width, height)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 90)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
	end

	self:SetCamPos(self:GetCamPos() + (PLUGIN.slotsCFG.charCamOffset or vector_origin))
	self:SetLookAt(self:GetLookAt() + (PLUGIN.slotsCFG.charLookOffset or vector_origin))

	self.standardAngles = self.Entity:GetAngles()
	self.yaw = 0

	self.rotateLeft = CreateRotateButton(self, -1)
	self.rotateRight = CreateRotateButton(self, 1)

	timer.Create(CHAR_TIMER, 0.1, 0, function()
		if (IsValid(self)) then
			ApplyAppearance(self)
		else
			timer.Remove(CHAR_TIMER)
		end
	end)
end

function PANEL:PerformLayout(width, height)
	local base = baseclass.Get("ixModelPanel")

	if (base and base.PerformLayout) then
		base.PerformLayout(self, width, height)
	end

	if (IsValid(self.rotateLeft) and IsValid(self.rotateRight)) then
		local size, margin = S(32), S(6)

		self.rotateLeft:SetSize(size, size)
		self.rotateLeft:SetPos(margin, height - size - margin)

		self.rotateRight:SetSize(size, size)
		self.rotateRight:SetPos(width - size - margin, height - size - margin)
	end
end

function PANEL:LayoutEntity(entity)
	local base = baseclass.Get("ixModelPanel")

	if (base and base.LayoutEntity) then
		base.LayoutEntity(self, entity)
	end

	-- базовый угол запоминаем один раз, поворот добавляем поверх (иначе накапливался бы каждый кадр)
	if (!self.baseAngles or self.baseAngleEntity != entity) then
		self.baseAngles = entity:GetAngles()
		self.baseAngleEntity = entity
	end

	entity:SetAngles(self.baseAngles + Angle(0, self.yaw or 0, 0))
end

function PANEL:OnRemove()
	timer.Remove(CHAR_TIMER)
end

vgui.Register("ixEquipmentSlotsCharModel", PANEL, "ixModelPanel")
