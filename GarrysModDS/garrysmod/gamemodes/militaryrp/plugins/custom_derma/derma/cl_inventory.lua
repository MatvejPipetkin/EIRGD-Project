local RECEIVER_NAME = "ixInventoryItem"

-- общий стиль меню (тот же, что в cl_menu.lua / cl_character.lua)
ix.menuStyle = ix.menuStyle or {accent = Color(90, 160, 235), projectName = "EIRGD"}

--[[
	НАСТРОЙКИ
	Дизайн инвентаря: тёмная панель с акцентными линиями и уголками как в cl_menu,
	сетка и предметы в стиле Escape from Tarkov (цветная подложка по категории,
	короткое имя в левом верхнем углу, количество в правом нижнем).
]]
local CFG = {
	cellSize = 110, -- размер одной ячейки в пикселях при высоте экрана 1080 (масштабируется под разрешение; было 64)
	showNames = true, -- короткое название предмета в левом верхнем углу
	showCount = true, -- количество / стак в правом нижнем углу
	itemFillAlpha = 55, -- сила цветной подложки предмета
	gridAlpha = 16, -- прозрачность линий сетки
	columnMinWidth = 0, -- минимальная ширина правой колонки в долях ширины контента (0 = ровно по ширине инвентаря)
	characterOverview = true -- показывать персонажа слева, пока открыта вкладка инвентаря
}

local function S(value)
	return math.floor(value * ScrH() / 1080 + 0.5)
end

local function GetAccent()
	return ix.menuStyle.accent or ix.config.Get("color") or Color(90, 160, 235)
end

-- цвета подложки предметов по категории (ключ — категория в нижнем регистре).
-- Для отдельного предмета можно задать ITEM.invColor = Color(r, g, b)
local DEFAULT_COLOR = Color(125, 140, 160)
local CATEGORY_COLORS = {
	["weapons"] = Color(205, 85, 75),
	["weapon"] = Color(205, 85, 75),
	["оружие"] = Color(205, 85, 75),
	["ammo"] = Color(215, 165, 60),
	["ammunition"] = Color(215, 165, 60),
	["боеприпасы"] = Color(215, 165, 60),
	["medical"] = Color(95, 200, 120),
	["медицина"] = Color(95, 200, 120),
	["consumables"] = Color(150, 190, 90),
	["food"] = Color(150, 190, 90),
	["еда"] = Color(150, 190, 90),
	["clothing"] = Color(90, 150, 225),
	["одежда"] = Color(90, 150, 225),
	["tools"] = Color(170, 130, 215),
	["инструменты"] = Color(170, 130, 215)
}

local COLOR_SHADOW = Color(0, 0, 0, 210)
local COLOR_TEXT = Color(255, 255, 255, 235)
local COLOR_GOOD = Color(110, 210, 130)
local COLOR_BAD = Color(225, 85, 80)

local function GetItemColor(item)
	if (!item) then
		return DEFAULT_COLOR
	end

	if (IsColor(item.invColor)) then
		return item.invColor
	end

	if (item.isBag) then
		return GetAccent()
	end

	local category = item.category

	if (isstring(category)) then
		category = category.utf8lower and category:utf8lower() or category:lower()

		return CATEGORY_COLORS[category] or DEFAULT_COLOR
	end

	return DEFAULT_COLOR
end

-- количество предметов в стаке (если схема его поддерживает)
local function GetItemAmount(item)
	if (!item) then
		return
	end

	local amount

	if (isfunction(item.GetQuantity)) then
		amount = item:GetQuantity()
	end

	if (!amount and isfunction(item.GetData)) then
		amount = item:GetData("quantity") or item:GetData("amount") or item:GetData("stack")
	end

	amount = tonumber(amount or item.quantity)

	if (amount and amount > 1) then
		return math.floor(amount)
	end
end

-- обрезает текст по ширине с многоточием (с учётом UTF-8)
local function FitText(text, font, maxWidth)
	surface.SetFont(font)

	if (surface.GetTextSize(text) <= maxWidth) then
		return text
	end

	local length = utf8.len(text) or #text

	while (length > 1) do
		length = length - 1

		local cut = text:sub(1, (utf8.offset(text, length + 1) or (#text + 1)) - 1) .. "…"

		if (surface.GetTextSize(cut) <= maxWidth) then
			return cut
		end
	end

	return "…"
end

-- The queue for the rendered icons.
ICON_RENDER_QUEUE = ICON_RENDER_QUEUE or {}

-- To make making inventory variant, This must be followed up.
local function RenderNewIcon(panel, itemTable)
	local model = itemTable:GetModel()

	-- re-render icons
	if ((itemTable.iconCam and !ICON_RENDER_QUEUE[string.lower(model)]) or itemTable.forceRender) then
		local iconCam = itemTable.iconCam
		iconCam = {
			cam_pos = iconCam.pos,
			cam_ang = iconCam.ang,
			cam_fov = iconCam.fov,
		}
		ICON_RENDER_QUEUE[string.lower(model)] = true

		panel.Icon:RebuildSpawnIconEx(
			iconCam
		)
	end
end

local function InventoryAction(action, itemID, invID, data)
	net.Start("ixInventoryAction")
		net.WriteString(action)
		net.WriteUInt(itemID, 32)
		net.WriteUInt(invID, 32)
		net.WriteTable(data or {})
	net.SendToServer()
end

local PANEL = {}

AccessorFunc(PANEL, "itemTable", "ItemTable")
AccessorFunc(PANEL, "inventoryID", "InventoryID")

function PANEL:Init()
	self:Droppable(RECEIVER_NAME)
end

function PANEL:OnMousePressed(code)
	if (code == MOUSE_LEFT and self:IsDraggable()) then
		self:MouseCapture(true)
		self:DragMousePress(code)

		self.clickX, self.clickY = input.GetCursorPos()
	elseif (code == MOUSE_RIGHT and self.DoRightClick) then
		self:DoRightClick()
	end
end

function PANEL:OnMouseReleased(code)
	-- move the item into the world if we're dropping on something that doesn't handle inventory item drops
	if (!dragndrop.m_ReceiverSlot or dragndrop.m_ReceiverSlot.Name != RECEIVER_NAME) then
		self:OnDrop(dragndrop.IsDragging())
	end

	self:DragMouseRelease(code)
	self:SetZPos(99)
	self:MouseCapture(false)
end

function PANEL:DoRightClick()
	local itemTable = self.itemTable
	local inventory = self.inventoryID

	if (itemTable and inventory) then
		itemTable.player = LocalPlayer()

		local menu = DermaMenu()
		local override = hook.Run("CreateItemInteractionMenu", self, menu, itemTable)

		if (override == true) then
			if (menu.Remove) then
				menu:Remove()
			end

			return
		end

		for k, v in SortedPairs(itemTable.functions) do
			if (k == "drop" or k == "combine" or (v.OnCanRun and v.OnCanRun(itemTable) == false)) then
				continue
			end

			-- is Multi-Option Function
			if (v.isMulti) then
				local subMenu, subMenuOption = menu:AddSubMenu(L(v.name or k), function()
					itemTable.player = LocalPlayer()
						local send = true

						if (v.OnClick) then
							send = v.OnClick(itemTable)
						end

						if (v.sound) then
							surface.PlaySound(v.sound)
						end

						if (send != false) then
							InventoryAction(k, itemTable.id, inventory)
						end
					itemTable.player = nil
				end)
				subMenuOption:SetImage(v.icon or "icon16/brick.png")

				if (v.multiOptions) then
					local options = isfunction(v.multiOptions) and v.multiOptions(itemTable, LocalPlayer()) or v.multiOptions

					for _, sub in pairs(options) do
						subMenu:AddOption(L(sub.name or "subOption"), function()
							itemTable.player = LocalPlayer()
								local send = true

								if (sub.OnClick) then
									send = sub.OnClick(itemTable)
								end

								if (sub.sound) then
									surface.PlaySound(sub.sound)
								end

								if (send != false) then
									InventoryAction(k, itemTable.id, inventory, sub.data)
								end
							itemTable.player = nil
						end)
					end
				end
			else
				menu:AddOption(L(v.name or k), function()
					itemTable.player = LocalPlayer()
						local send = true

						if (v.OnClick) then
							send = v.OnClick(itemTable)
						end

						if (v.sound) then
							surface.PlaySound(v.sound)
						end

						if (send != false) then
							InventoryAction(k, itemTable.id, inventory)
						end
					itemTable.player = nil
				end):SetImage(v.icon or "icon16/brick.png")
			end
		end

		-- we want drop to show up as the last option
		local info = itemTable.functions.drop

		if (info and info.OnCanRun and info.OnCanRun(itemTable) != false) then
			menu:AddOption(L(info.name or "drop"), function()
				itemTable.player = LocalPlayer()
					local send = true

					if (info.OnClick) then
						send = info.OnClick(itemTable)
					end

					if (info.sound) then
						surface.PlaySound(info.sound)
					end

					if (send != false) then
						InventoryAction("drop", itemTable.id, inventory)
					end
				itemTable.player = nil
			end):SetImage(info.icon or "icon16/brick.png")
		end

		menu:Open()
		itemTable.player = nil
	end
end

function PANEL:OnDrop(bDragging, inventoryPanel, inventory, gridX, gridY)
	local item = self.itemTable

	if (!item or !bDragging) then
		return
	end

	if (!IsValid(inventoryPanel)) then
		local inventoryID = self.inventoryID

		if (inventoryID) then
			InventoryAction("drop", item.id, inventoryID, {})
		end
	elseif (inventoryPanel:IsAllEmpty(gridX, gridY, item.width, item.height, self)) then
		local oldX, oldY = self.gridX, self.gridY

		if (oldX != gridX or oldY != gridY or self.inventoryID != inventoryPanel.invID) then
			self:Move(gridX, gridY, inventoryPanel)
		end
	elseif (inventoryPanel.combineItem) then
		local combineItem = inventoryPanel.combineItem
		local inventoryID = combineItem.invID

		if (inventoryID) then
			combineItem.player = LocalPlayer()
				if (combineItem.functions.combine.sound) then
					surface.PlaySound(combineItem.functions.combine.sound)
				end

				InventoryAction("combine", combineItem.id, inventoryID, {item.id})
			combineItem.player = nil
		end
	end
end

function PANEL:Move(newX, newY, givenInventory, bNoSend)
	local iconSize = givenInventory.iconSize
	local oldX, oldY = self.gridX, self.gridY
	local oldParent = self:GetParent()

	if (givenInventory:OnTransfer(oldX, oldY, newX, newY, oldParent, bNoSend) == false) then
		return
	end

	local x = (newX - 1) * iconSize + 4
	local y = (newY - 1) * iconSize + givenInventory:GetPadding(2)

	self.gridX = newX
	self.gridY = newY

	self:SetParent(givenInventory)
	self:SetPos(x, y)

	if (self.slots) then
		for _, v in ipairs(self.slots) do
			if (IsValid(v) and v.item == self) then
				v.item = nil
			end
		end
	end

	self.slots = {}

	for currentX = 1, self.gridW do
		for currentY = 1, self.gridH do
			local slot = givenInventory.slots[self.gridX + currentX - 1][self.gridY + currentY - 1]

			slot.item = self
			self.slots[#self.slots + 1] = slot
		end
	end
end

-- короткое имя предмета, обрезанное по ширине иконки (кэшируется)
function PANEL:GetShortName(maxWidth)
	local item = self.itemTable
	local name = item and (item.GetName and item:GetName() or item.name) or ""
	local key = name .. "|" .. math.floor(maxWidth)

	if (self.nameKey != key) then
		self.nameKey = key
		self.shortName = FitText(name, "ixMenuTinyFont", maxWidth)
	end

	return self.shortName
end

-- верхний слой: рамка, название, количество (поверх иконки модели)
function PANEL:PaintOver(width, height)
	local itemTable = self.itemTable

	if (!itemTable) then
		return
	end

	local color = GetItemColor(itemTable)
	local accent = GetAccent()

	draw.NoTexture()

	if (self:IsHovered()) then
		surface.SetDrawColor(255, 255, 255, 18)
		surface.DrawRect(1, 1, width - 2, height - 2)
		surface.SetDrawColor(accent.r, accent.g, accent.b, 255)
	else
		surface.SetDrawColor(color.r, color.g, color.b, 150)
	end

	surface.DrawOutlinedRect(0, 0, width, height, 1)

	if (CFG.showNames) then
		local name = self:GetShortName(width - S(8))

		draw.SimpleText(name, "ixMenuTinyFont", S(4) + 1, S(3) + 1, COLOR_SHADOW, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(name, "ixMenuTinyFont", S(4), S(3), COLOR_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	if (CFG.showCount) then
		local amount = GetItemAmount(itemTable)

		if (amount) then
			local text = amount .. "x"

			draw.SimpleText(text, "ixMenuTinyFont", width - S(4) + 1, height - S(3) + 1, COLOR_SHADOW, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
			draw.SimpleText(text, "ixMenuTinyFont", width - S(4), height - S(3), COLOR_TEXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		end
	end

	if (itemTable.PaintOver) then
		itemTable.PaintOver(self, itemTable, width, height)
	end
end

function PANEL:ExtraPaint(width, height)
end

-- подложка предмета: тёмная основа + цветная заливка по категории
function PANEL:Paint(width, height)
	local color = GetItemColor(self.itemTable)

	draw.NoTexture()

	surface.SetDrawColor(0, 0, 0, 110)
	surface.DrawRect(1, 1, width - 2, height - 2)

	surface.SetDrawColor(color.r, color.g, color.b, CFG.itemFillAlpha)
	surface.DrawRect(1, 1, width - 2, height - 2)

	self:ExtraPaint(width, height)
end

vgui.Register("ixItemIcon", PANEL, "SpawnIcon")

PANEL = {}
DEFINE_BASECLASS("DFrame")

AccessorFunc(PANEL, "iconSize", "IconSize", FORCE_NUMBER)
AccessorFunc(PANEL, "bHighlighted", "Highlighted", FORCE_BOOL)

function PANEL:Init()
	self.headerH = S(34)

	self:SetIconSize(S(CFG.cellSize))
	self:ShowCloseButton(false)
	self:SetDraggable(true)
	self:SetSizable(true)
	self:SetTitle(L"inv")
	self:Receiver(RECEIVER_NAME, self.ReceiveDrop)

	self.btnMinim:SetVisible(false)
	self.btnMinim:SetMouseInputEnabled(false)
	self.btnMaxim:SetVisible(false)
	self.btnMaxim:SetMouseInputEnabled(false)

	-- кнопка закрытия в стиле меню (используется у сумок)
	self.btnClose:SetText("")
	self.btnClose.Paint = function(button, width, height)
		local accent = GetAccent()
		local cx, cy, r = width * 0.5, height * 0.5, S(5)

		surface.SetDrawColor(accent.r, accent.g, accent.b, button:IsHovered() and 255 or 150)
		surface.DrawLine(cx - r, cy - r, cx + r, cy + r)
		surface.DrawLine(cx - r, cy + r, cx + r, cy - r)
	end

	self.panels = {}
end

-- показываем только кнопку закрытия, кнопки сворачивания остаются скрытыми
function PANEL:ShowCloseButton(bShow)
	self.btnClose:SetVisible(bShow)
end

function PANEL:GetPadding(index)
	return select(index, self:GetDockPadding())
end

-- заголовок рисуем сами в Paint, поэтому стандартную надпись DFrame скрываем
function PANEL:SetTitle(text)
	self.headerH = self.headerH or S(34)

	if (text == nil) then
		self.titleText = nil

		self.lblTitle:SetText("")
		self.lblTitle:SetVisible(false)

		self:DockPadding(4, 4, 4, 4)
	else
		local title = tostring(text)

		self.titleText = title.utf8upper and title:utf8upper() or title:upper()

		self.lblTitle:SetText(title)
		self.lblTitle:SetVisible(false)

		self:DockPadding(4, self.headerH, 4, 4)
	end
end

function PANEL:FitParent(invWidth, invHeight)
	local parent = self:GetParent()

	if (!IsValid(parent)) then
		return
	end

	local width, height = parent:GetSize()
	local padding = 4
	local iconSize

	if (invWidth > invHeight) then
		iconSize = (width - padding * 2) / invWidth
	elseif (invHeight > invWidth) then
		iconSize = (height - padding * 2) / invHeight
	else
		-- we use height because the titlebar will make it more tall than it is wide
		iconSize = (height - padding * 2) / invHeight - 4
	end

	self:SetSize(iconSize * invWidth + padding * 2, iconSize * invHeight + padding * 2)
	self:SetIconSize(iconSize)
end

function PANEL:OnRemove()
	if (self.childPanels) then
		for _, v in ipairs(self.childPanels) do
			if (v != self) then
				v:Remove()
			end
		end
	end
end

function PANEL:ViewOnly()
	self.viewOnly = true

	for _, icon in pairs(self.panels) do
		icon.OnMousePressed = nil
		icon.OnMouseReleased = nil
		icon.doRightClick = nil
	end
end

function PANEL:SetInventory(inventory, bFitParent)
	if (inventory.slots) then
		local invWidth, invHeight = inventory:GetSize()
		self.invID = inventory:GetID()

		if (IsValid(ix.gui.inv1) and ix.gui.inv1.childPanels and inventory != LocalPlayer():GetCharacter():GetInventory()) then
			self:SetIconSize(ix.gui.inv1:GetIconSize())
			self:SetPaintedManually(true)
			self.bNoBackgroundBlur = true

			ix.gui.inv1.childPanels[#ix.gui.inv1.childPanels + 1] = self
		elseif (bFitParent) then
			self:FitParent(invWidth, invHeight)
		else
			self:SetSize(self.iconSize, self.iconSize)
		end

		self:SetGridSize(invWidth, invHeight)

		for x, items in pairs(inventory.slots) do
			for y, data in pairs(items) do
				if (!data.id) then continue end

				local item = ix.item.instances[data.id]

				if (item and !IsValid(self.panels[item.id])) then
					local icon = self:AddIcon(item:GetModel() or "models/props_junk/popcan01a.mdl",
						x, y, item.width, item.height, item:GetSkin())

					if (IsValid(icon)) then
						icon:SetHelixTooltip(function(tooltip)
							ix.hud.PopulateItemTooltip(tooltip, item)
						end)

						self.panels[item.id] = icon
					end
				end
			end
		end
	end
end

function PANEL:SetGridSize(w, h)
	local iconSize = self.iconSize
	local newWidth = w * iconSize + 8
	local newHeight = h * iconSize + self:GetPadding(2) + self:GetPadding(4)

	self.gridW = w
	self.gridH = h

	self:SetSize(newWidth, newHeight)
	self:SetMinWidth(newWidth)
	self:SetMinHeight(newHeight)
	self:BuildSlots()
end

function PANEL:PerformLayout(width, height)
	BaseClass.PerformLayout(self, width, height)

	-- кнопка закрытия — квадрат в правой части шапки
	if (IsValid(self.btnClose)) then
		local size = self.headerH or S(34)

		self.btnClose:SetSize(size, size)
		self.btnClose:SetPos(width - size, 0)
	end

	if (self.Sizing and self.gridW and self.gridH) then
		local newWidth = (width - 8) / self.gridW
		local newHeight = (height - self:GetPadding(2) - self:GetPadding(4)) / self.gridH

		self:SetIconSize((newWidth + newHeight) / 2)
		self:RebuildItems()
	end
end

function PANEL:BuildSlots()
	local iconSize = self.iconSize

	self.slots = self.slots or {}

	for _, v in ipairs(self.slots) do
		for _, v2 in ipairs(v) do
			v2:Remove()
		end
	end

	self.slots = {}

	for x = 1, self.gridW do
		self.slots[x] = {}

		for y = 1, self.gridH do
			local slot = self:Add("DPanel")
			slot:SetZPos(-999)
			slot.gridX = x
			slot.gridY = y
			slot:SetPos((x - 1) * iconSize + 4, (y - 1) * iconSize + self:GetPadding(2))
			slot:SetSize(iconSize, iconSize)

			-- сетка рисуется целиком в Paint инвентаря, сами ячейки ничего не рисуют
			slot.Paint = function() end

			self.slots[x][y] = slot
		end
	end
end

function PANEL:RebuildItems()
	local iconSize = self.iconSize

	for x = 1, self.gridW do
		for y = 1, self.gridH do
			local slot = self.slots[x][y]

			slot:SetPos((x - 1) * iconSize + 4, (y - 1) * iconSize + self:GetPadding(2))
			slot:SetSize(iconSize, iconSize)
		end
	end

	for _, v in pairs(self.panels) do
		if (IsValid(v)) then
			v:SetPos(self.slots[v.gridX][v.gridY]:GetPos())
			v:SetSize(v.gridW * iconSize, v.gridH * iconSize)
		end
	end
end

-- сколько ячеек занято предметами
function PANEL:GetUsedSlots()
	local used = 0

	for _, icon in pairs(self.panels) do
		if (IsValid(icon) and icon.gridW and icon.gridH) then
			used = used + icon.gridW * icon.gridH
		end
	end

	return used
end

function PANEL:PaintDragPreview(width, height, mouseX, mouseY, itemPanel)
	local iconSize = self.iconSize
	local half = iconSize * 0.5
	local item = itemPanel:GetItemTable()

	if (item) then
		local inventory = ix.item.inventories[self.invID]
		local dropX = math.ceil((mouseX - 4 - (itemPanel.gridW - 1) * half) / iconSize)
		local dropY = math.ceil((mouseY - self:GetPadding(2) - (itemPanel.gridH - 1) * half) / iconSize)

		local hoveredPanel = vgui.GetHoveredPanel()

		draw.NoTexture()

		if (IsValid(hoveredPanel) and hoveredPanel != itemPanel and hoveredPanel.GetItemTable) then
			local hoveredItem = hoveredPanel:GetItemTable()

			if (hoveredItem) then
				local info = hoveredItem.functions.combine

				if (info and info.OnCanRun and info.OnCanRun(hoveredItem, {item.id}) != false) then
					local accent = GetAccent()

					surface.SetDrawColor(accent.r, accent.g, accent.b, 40)
					surface.DrawRect(
						hoveredPanel.x,
						hoveredPanel.y,
						hoveredPanel:GetWide(),
						hoveredPanel:GetTall()
					)

					surface.SetDrawColor(accent.r, accent.g, accent.b, 220)
					surface.DrawOutlinedRect(
						hoveredPanel.x,
						hoveredPanel.y,
						hoveredPanel:GetWide(),
						hoveredPanel:GetTall(),
						1
					)

					self.combineItem = hoveredItem

					return
				end
			end
		end

		self.combineItem = nil

		-- don't draw grid if we're dragging it out of bounds
		if (inventory) then
			local invWidth, invHeight = inventory:GetSize()

			if (dropX < 1 or dropY < 1 or
				dropX + itemPanel.gridW - 1 > invWidth or
				dropY + itemPanel.gridH - 1 > invHeight) then
				return
			end
		end

		local bEmpty = true

		for x = 0, itemPanel.gridW - 1 do
			for y = 0, itemPanel.gridH - 1 do
				local x2 = dropX + x
				local y2 = dropY + y

				bEmpty = self:IsEmpty(x2, y2, itemPanel)

				if (!bEmpty) then
					-- no need to iterate further since we know something is blocking the hovered grid cells, break through both loops
					goto finish
				end
			end
		end

		::finish::
		local previewColor = bEmpty and COLOR_GOOD or COLOR_BAD
		local px = (dropX - 1) * iconSize + 4
		local py = (dropY - 1) * iconSize + self:GetPadding(2)

		surface.SetDrawColor(previewColor.r, previewColor.g, previewColor.b, 40)
		surface.DrawRect(px, py, itemPanel:GetWide(), itemPanel:GetTall())

		surface.SetDrawColor(previewColor.r, previewColor.g, previewColor.b, 200)
		surface.DrawOutlinedRect(px, py, itemPanel:GetWide(), itemPanel:GetTall(), 1)
	end
end

function PANEL:PaintOver(width, height)
	local panel = self.previewPanel

	if (IsValid(panel)) then
		local itemPanel = (dragndrop.GetDroppable() or {})[1]

		if (IsValid(itemPanel)) then
			self:PaintDragPreview(width, height, self.previewX, self.previewY, itemPanel)
		end
	end

	self.previewPanel = nil
end

-- панель контейнера: тёмный фон, шапка с заголовком, сетка в стиле Tarkov, акцентные линии и уголки как в cl_menu
function PANEL:Paint(width, height)
	if (!self.bNoBackgroundBlur and ix.util.DrawBlur) then
		ix.util.DrawBlur(self, 6)
	end

	local accent = GetAccent()
	local headerH = self.titleText and self.headerH or 0

	draw.NoTexture()

	-- фон
	surface.SetDrawColor(8, 11, 16, 215)
	surface.DrawRect(0, 0, width, height)

	-- сетка ячеек
	if (self.gridW and self.gridH and self.iconSize) then
		local iconSize = self.iconSize
		local gx, gy = 4, self:GetPadding(2)
		local gw, gh = self.gridW * iconSize, self.gridH * iconSize

		surface.SetDrawColor(22, 27, 34, 235)
		surface.DrawRect(gx, gy, math.floor(gw), math.floor(gh))

		surface.SetDrawColor(255, 255, 255, CFG.gridAlpha)

		for x = 0, self.gridW do
			surface.DrawRect(math.floor(gx + x * iconSize), gy, 1, math.floor(gh) + 1)
		end

		for y = 0, self.gridH do
			surface.DrawRect(gx, math.floor(gy + y * iconSize), math.floor(gw) + 1, 1)
		end
	end

	-- шапка
	if (headerH > 0) then
		local centerY = math.floor(headerH * 0.5)

		surface.SetDrawColor(0, 0, 0, 90)
		surface.DrawRect(0, 0, width, headerH)

		-- мягкое свечение под линией шапки
		for i = 1, 6 do
			surface.SetDrawColor(accent.r, accent.g, accent.b, 16 * (1 - i / 6) ^ 2)
			surface.DrawRect(1, headerH + i - 1, width - 2, 1)
		end

		surface.SetDrawColor(accent.r, accent.g, accent.b, 60)
		surface.DrawRect(0, headerH - 1, width, 1)

		-- яркий отрезок на линии и маркер у заголовка
		surface.SetDrawColor(accent.r, accent.g, accent.b, 230)
		surface.DrawRect(S(8), headerH - 2, S(40), 3)
		surface.DrawRect(S(8), centerY - S(7), 2, S(14))

		draw.SimpleText(self.titleText, "ixMenuTabFontSmall", S(20), centerY, Color(255, 255, 255, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (self.gridW and self.gridH) then
			local rightX = width - S(10) - (IsValid(self.btnClose) and self.btnClose:IsVisible() and headerH or 0)
			local text = "ЯЧЕЙКИ  " .. self:GetUsedSlots() .. " / " .. (self.gridW * self.gridH)

			draw.SimpleText(text, "ixMenuTinyFont", rightX, centerY, Color(accent.r, accent.g, accent.b, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end

	-- внешняя рамка
	surface.SetDrawColor(accent.r, accent.g, accent.b, self.bHighlighted and 200 or 45)
	surface.DrawOutlinedRect(0, 0, width, height, 1)

	-- яркие уголки
	local corner = S(10)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 230)
	surface.DrawRect(0, 0, corner, 1)
	surface.DrawRect(0, 0, 1, corner)
	surface.DrawRect(width - corner, 0, corner, 1)
	surface.DrawRect(width - 1, 0, 1, corner)
	surface.DrawRect(0, height - 1, corner, 1)
	surface.DrawRect(0, height - corner, 1, corner)
	surface.DrawRect(width - corner, height - 1, corner, 1)
	surface.DrawRect(width - 1, height - corner, 1, corner)
end

function PANEL:IsEmpty(x, y, this)
	return (self.slots[x] and self.slots[x][y]) and (!IsValid(self.slots[x][y].item) or self.slots[x][y].item == this)
end

function PANEL:IsAllEmpty(x, y, width, height, this)
	for x2 = 0, width - 1 do
		for y2 = 0, height - 1 do
			if (!self:IsEmpty(x + x2, y + y2, this)) then
				return false
			end
		end
	end

	return true
end

function PANEL:OnTransfer(oldX, oldY, x, y, oldInventory, noSend)
	local inventories = ix.item.inventories
	local inventory = inventories[oldInventory.invID]
	local inventory2 = inventories[self.invID]
	local item

	if (inventory) then
		item = inventory:GetItemAt(oldX, oldY)

		if (!item) then
			return false
		end

		if (hook.Run("CanTransferItem", item, inventories[oldInventory.invID], inventories[self.invID]) == false) then
			return false, "notAllowed"
		end

		if (item.CanTransfer and
			item:CanTransfer(inventory, inventory != inventory2 and inventory2 or nil) == false) then
			return false
		end
	end

	if (!noSend) then
		net.Start("ixInventoryMove")
			net.WriteUInt(oldX, 6)
			net.WriteUInt(oldY, 6)
			net.WriteUInt(x, 6)
			net.WriteUInt(y, 6)
			net.WriteUInt(oldInventory.invID, 32)
			net.WriteUInt(self != oldInventory and self.invID or oldInventory.invID, 32)
		net.SendToServer()
	end

	if (inventory) then
		inventory.slots[oldX][oldY] = nil
	end

	if (item and inventory2) then
		inventory2.slots[x] = inventory2.slots[x] or {}
		inventory2.slots[x][y] = item
	end
end

function PANEL:AddIcon(model, x, y, w, h, skin)
	local iconSize = self.iconSize

	w = w or 1
	h = h or 1

	if (self.slots[x] and self.slots[x][y]) then
		local panel = self:Add("ixItemIcon")
		panel:SetSize(w * iconSize, h * iconSize)
		panel:SetZPos(999)
		panel:InvalidateLayout(true)
		panel:SetModel(model, skin)
		panel:SetPos(self.slots[x][y]:GetPos())
		panel.gridX = x
		panel.gridY = y
		panel.gridW = w
		panel.gridH = h

		local inventory = ix.item.inventories[self.invID]

		if (!inventory) then
			return
		end

		local itemTable = inventory:GetItemAt(panel.gridX, panel.gridY)

		panel:SetInventoryID(inventory:GetID())
		panel:SetItemTable(itemTable)

		if (self.panels[itemTable:GetID()]) then
			self.panels[itemTable:GetID()]:Remove()
		end

		if (itemTable.exRender) then
			panel.Icon:SetVisible(false)
			panel.ExtraPaint = function(this, panelX, panelY)
				local exIcon = ikon:GetIcon(itemTable.uniqueID)
				if (exIcon) then
					surface.SetMaterial(exIcon)
					surface.SetDrawColor(color_white)
					surface.DrawTexturedRect(0, 0, panelX, panelY)
				else
					ikon:renderIcon(
						itemTable.uniqueID,
						itemTable.width,
						itemTable.height,
						itemTable:GetModel(),
						itemTable.iconCam
					)
				end
			end
		else
			-- yeah..
			RenderNewIcon(panel, itemTable)
		end

		panel.slots = {}

		for i = 0, w - 1 do
			for i2 = 0, h - 1 do
				local slot = self.slots[x + i] and self.slots[x + i][y + i2]

				if (IsValid(slot)) then
					slot.item = panel
					panel.slots[#panel.slots + 1] = slot
				else
					for _, v in ipairs(panel.slots) do
						v.item = nil
					end

					panel:Remove()

					return
				end
			end
		end

		return panel
	end
end

function PANEL:ReceiveDrop(panels, bDropped, menuIndex, x, y)
	local panel = panels[1]

	if (!IsValid(panel)) then
		self.previewPanel = nil
		return
	end

	if (bDropped) then
		local inventory = ix.item.inventories[self.invID]

		if (inventory and panel.OnDrop) then
			local half = self.iconSize * 0.5
			local dropX = math.ceil((x - 4 - (panel.gridW - 1) * half) / self.iconSize)
			local dropY = math.ceil((y - self:GetPadding(2) - (panel.gridH - 1) * half) / self.iconSize)

			panel:OnDrop(true, self, inventory, dropX, dropY)
		end

		self.previewPanel = nil
	else
		self.previewPanel = panel
		self.previewX = x
		self.previewY = y
	end
end

vgui.Register("ixInventory", PANEL, "DFrame")

hook.Add("CreateMenuButtons", "ixInventory", function(tabs)
	if (hook.Run("CanPlayerViewInventory") == false) then
		return
	end

	tabs["inv"] = {
		bDefault = true,
		Create = function(info, container)
			-- колонка прижата к правому краю области контента, слева остаётся место под персонажа
			local canvas = container:Add("DTileLayout")
			local canvasLayout = canvas.PerformLayout
			canvas.PerformLayout = nil -- we'll layout after we add the panels instead of each time one is added
			canvas:SetBorder(0)
			canvas:SetSpaceX(S(6))
			canvas:SetSpaceY(S(6))
			canvas:Dock(RIGHT)
			canvas:DockMargin(0, S(8), 0, 0)

			ix.gui.menuInventoryContainer = canvas

			local panel = canvas:Add("ixInventory")
			panel:SetPos(0, 0)
			panel:SetDraggable(false)
			panel:SetSizable(false)
			panel:SetTitle(L"inv")
			panel.bNoBackgroundBlur = true
			panel.childPanels = {}

			local inventory = LocalPlayer():GetCharacter():GetInventory()

			if (inventory) then
				panel:SetInventory(inventory)
			end

			ix.gui.inv1 = panel

			-- ширина колонки = ширина основного инвентаря (сумки встают под ним)
			canvas:SetWide(math.max(panel:GetWide(), math.floor(container:GetWide() * CFG.columnMinWidth)))

			if (inventory and ix.option.Get("openBags", true)) then
				for k, _ in inventory:Iter() do
					if (!k.isBag) then
						continue
					end

					k.functions.View.OnClick(k)
				end
			end

			canvas.PerformLayout = canvasLayout
			canvas:Layout()
		end,

		-- персонаж слева, пока открыт инвентарь
		OnSelected = function(info, container)
			if (CFG.characterOverview and IsValid(ix.gui.menu)) then
				ix.gui.menu:SetCharacterOverview(true)
			end
		end,

		OnDeselected = function(info, container)
			if (CFG.characterOverview and IsValid(ix.gui.menu)) then
				ix.gui.menu:SetCharacterOverview(false)
			end
		end
	}
end)

hook.Add("PostRenderVGUI", "ixInvHelper", function()
	local pnl = ix.gui.inv1

	hook.Run("PostDrawInventory", pnl)
end)