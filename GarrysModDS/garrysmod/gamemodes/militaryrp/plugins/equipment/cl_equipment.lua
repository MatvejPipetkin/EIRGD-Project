local RECEIVER_NAME = "ixInventoryItem" -- тот же приёмник, что и у сетки инвентаря

ICON_RENDER_QUEUE = ICON_RENDER_QUEUE or {}

local function S(value)
	return math.floor(value * ScrH() / 1080 + 0.5)
end

local function GetAccent()
	local style = ix.menuStyle

	return (style and style.accent) or ix.config.Get("color") or Color(90, 160, 235)
end

local DEFAULT_COLOR = Color(125, 140, 160)
local COLOR_SHADOW = Color(0, 0, 0, 210)
local COLOR_TEXT = Color(255, 255, 255, 235)
local COLOR_GOOD = Color(110, 210, 130)
local COLOR_BAD = Color(225, 85, 80)

local function Notify(text)
	if (ix.util.Notify) then
		ix.util.Notify(text)
	else
		chat.AddText(text)
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

local function GetEquipment()
	return LocalPlayer():GetNetVar("equipment") or {}
end

--[[
	СЛОТ
]]
local SLOT = {}

function SLOT:Init()
	self:Receiver(RECEIVER_NAME, self.OnItemDragged)
end

function SLOT:Setup(slotData)
	self.slot = slotData

	if (slotData.icon) then
		local material = Material(slotData.icon, "smooth mips")

		if (material and !material:IsError()) then
			self.iconMaterial = material
		end
	end

	self:SetHelixTooltip(function(tooltip)
		self:PopulateTooltip(tooltip)
	end)
end

function SLOT:GetSlotColor()
	local item = self.item

	if (item and IsColor(item.invColor)) then
		return item.invColor
	end

	return self.slot.color or DEFAULT_COLOR
end

function SLOT:RebuildIcon(item)
	if (IsValid(self.icon)) then
		self.icon:Remove()
	end

	self.icon = nil
	self.item = item
	self.nameKey = nil

	if (!item) then
		return
	end

	local model = item.model or "models/props_junk/popcan01a.mdl"
	local icon = self:Add("SpawnIcon")

	icon:Dock(FILL)
	icon:DockMargin(1, 1, 1, 1)
	icon:SetModel(model, item.skin or 0)
	icon:SetMouseInputEnabled(false)
	icon.Paint = function() end
	icon.PaintOver = function() end

	self.icon = icon

	if (item.exRender and ikon) then
		icon.Icon:SetVisible(false)
		icon.Paint = function(this, width, height)
			local exIcon = ikon:GetIcon(item.uniqueID)

			if (exIcon) then
				surface.SetMaterial(exIcon)
				surface.SetDrawColor(color_white)
				surface.DrawTexturedRect(0, 0, width, height)
			else
				ikon:renderIcon(item.uniqueID, item.width, item.height, item.model, item.iconCam)
			end
		end
	elseif (item.iconCam and (!ICON_RENDER_QUEUE[string.lower(model)] or item.forceRender)) then
		ICON_RENDER_QUEUE[string.lower(model)] = true

		icon:RebuildSpawnIconEx({
			cam_pos = item.iconCam.pos,
			cam_ang = item.iconCam.ang,
			cam_fov = item.iconCam.fov
		})
	end
end

function SLOT:Think()
	local equipment = GetEquipment()
	local entry = equipment[self.slot.id]
	local item = entry and ix.item.list[entry.uid]
	local id = item and item.uniqueID

	if (self.shownID != id) then
		self.shownID = id
		self:RebuildIcon(item)
	end

	-- слот может быть перекрыт другим надетым предметом
	local _, blockerUID = ix.equipment.GetBlocker(equipment, self.slot.id)
	local blocker = blockerUID and ix.item.list[blockerUID]

	self.blockedBy = blocker and blocker.name or nil
end

-- перетаскивание предмета из сетки инвентаря на слот
function SLOT:OnItemDragged(panels, bDropped, command, x, y)
	local panel = panels[1]

	if (!IsValid(panel) or !panel.GetItemTable) then
		return
	end

	local item = panel:GetItemTable()

	if (!item) then
		return
	end

	local itemSlot = ix.equipment.GetItemSlot(item)
	local ok = itemSlot == self.slot.id and !self.blockedBy

	if (!bDropped) then
		self.dragHover = RealTime()
		self.dragOk = ok

		return
	end

	self.dragHover = nil

	if (ok) then
		item.player = LocalPlayer()

		local info = item.functions.Equip

		if (info and (!info.OnCanRun or info.OnCanRun(item) != false)) then
			InventoryAction("Equip", item.id, panel:GetInventoryID())
		end

		item.player = nil
	elseif (self.blockedBy) then
		Notify("Слот «" .. self.slot.name .. "» перекрыт: " .. self.blockedBy .. ".")
	elseif (!itemSlot) then
		Notify("Этот предмет нельзя надеть.")
	elseif (itemSlot != self.slot.id) then
		Notify("Этот предмет не подходит для слота «" .. self.slot.name .. "».")
	end
end

function SLOT:OnMousePressed(code)
	if (code == MOUSE_RIGHT) then
		self:DoRightClick()
	end
end

function SLOT:DoRightClick()
	if (!self.item) then
		return
	end

	local menu = DermaMenu()

	menu:AddOption("Снять", function()
		RunConsoleCommand("ix_equipment_unequip", self.slot.id)
	end):SetImage("icon16/cross.png")

	menu:Open()
end

function SLOT:PopulateTooltip(tooltip)
	local item = self.item
	local title = tooltip:AddRow("name")

	title:SetImportant()
	title:SizeToContents()

	local description = tooltip:AddRow("description")

	if (item) then
		title:SetText(item.GetName and item:GetName() or item.name or self.slot.name)
		description:SetText(item.description or "")
	else
		title:SetText(self.slot.name)
		description:SetText(self.blockedBy and ("Слот перекрыт: " .. self.blockedBy) or (self.slot.description or "Слот пуст"))
	end

	title:SizeToContents()
	description:SizeToContents()

	if (item) then
		local hint = tooltip:AddRow("equipHint")
		hint:SetText("ПКМ — снять")
		hint:SizeToContents()
	end
end

function SLOT:Paint(width, height)
	local accent = GetAccent()
	local slot = self.slot
	local item = self.item
	local color = self:GetSlotColor()

	draw.NoTexture()

	-- основа ячейки
	surface.SetDrawColor(22, 27, 34, 235)
	surface.DrawRect(0, 0, width, height)

	if (item) then
		surface.SetDrawColor(0, 0, 0, 110)
		surface.DrawRect(1, 1, width - 2, height - 2)

		surface.SetDrawColor(color.r, color.g, color.b, 55)
		surface.DrawRect(1, 1, width - 2, height - 2)
	else
		-- иконка слота + подпись
		if (self.iconMaterial) then
			local size = math.floor(math.min(width, height) * 0.56)

			surface.SetMaterial(self.iconMaterial)
			surface.SetDrawColor(accent.r, accent.g, accent.b, self.blockedBy and 25 or 95)
			surface.DrawTexturedRect(math.floor((width - size) * 0.5), math.floor((height - size) * 0.5) - S(6), size, size)
		end

		draw.SimpleText(slot.short or slot.name, "ixMenuTinyFont", width * 0.5, height - S(5), Color(255, 255, 255, self.blockedBy and 40 or 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

		if (self.blockedBy) then
			surface.SetDrawColor(0, 0, 0, 120)
			surface.DrawRect(1, 1, width - 2, height - 2)

			draw.SimpleText("ПЕРЕКРЫТО", "ixMenuTinyFont", width * 0.5, S(6), Color(COLOR_BAD.r, COLOR_BAD.g, COLOR_BAD.b, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end
	end
end

function SLOT:PaintOver(width, height)
	local accent = GetAccent()
	local item = self.item
	local color = self:GetSlotColor()

	draw.NoTexture()

	local dragging = dragndrop.GetDroppable()
	local dragPanel = dragging and dragging[1]
	local dragItem = IsValid(dragPanel) and dragPanel.GetItemTable and dragPanel:GetItemTable()

	if (self.dragHover and RealTime() - self.dragHover < 0.1) then
		-- предмет над слотом: зелёный — подходит, красный — нет
		local previewColor = self.dragOk and COLOR_GOOD or COLOR_BAD

		surface.SetDrawColor(previewColor.r, previewColor.g, previewColor.b, 40)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(previewColor.r, previewColor.g, previewColor.b, 200)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
	elseif (dragItem and ix.equipment.GetItemSlot(dragItem) == self.slot.id and !self.blockedBy) then
		-- подсказка: сюда можно надеть перетаскиваемый предмет
		local pulse = 90 + 70 * math.abs(math.sin(RealTime() * 3))

		surface.SetDrawColor(COLOR_GOOD.r, COLOR_GOOD.g, COLOR_GOOD.b, pulse)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
	elseif (self:IsHovered()) then
		surface.SetDrawColor(255, 255, 255, 18)
		surface.DrawRect(1, 1, width - 2, height - 2)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 255)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
	elseif (item) then
		surface.SetDrawColor(color.r, color.g, color.b, 150)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
	else
		surface.SetDrawColor(255, 255, 255, 16)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
	end

	if (item) then
		local name = item.GetName and item:GetName() or item.name or ""
		local key = name .. "|" .. width

		if (self.nameKey != key) then
			self.nameKey = key
			self.shortName = FitText(name, "ixMenuTinyFont", width - S(8))
		end

		draw.SimpleText(self.shortName, "ixMenuTinyFont", S(4) + 1, S(3) + 1, COLOR_SHADOW, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(self.shortName, "ixMenuTinyFont", S(4), S(3), COLOR_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		local label = self.slot.short or self.slot.name

		draw.SimpleText(label, "ixMenuTinyFont", S(4) + 1, height - S(3) + 1, COLOR_SHADOW, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		draw.SimpleText(label, "ixMenuTinyFont", S(4), height - S(3), Color(accent.r, accent.g, accent.b, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	end
end

vgui.Register("ixEquipmentSlot", SLOT, "DPanel")

--[[
	ПРЕДПРОСМОТР ПЕРСОНАЖА
	Полная модель игрока между колонками слотов: бодигруппы, скин и модели из wear
	повторяют то, что надето на персонаже. ЛКМ + движение мыши — повернуть, ПКМ — сбросить поворот.
]]
local PREVIEW = {}
local BasePreview = baseclass.Get("DModelPanel")

function PREVIEW:Init()
	self.yaw = 0
	self.wearStore = {}

	self:SetFOV(30)
	self:SetAmbientLight(Color(85, 85, 90))
end

function PREVIEW:FitCamera()
	local ent = self.Entity

	if (!IsValid(ent)) then
		return
	end

	local mins, maxs = ent:GetRenderBounds()
	local height = maxs.z - mins.z
	local width = maxs.y - mins.y
	local center = (mins + maxs) * 0.5
	local fov = 30
	local tangent = math.tan(math.rad(fov * 0.5))
	local aspect = self:GetWide() / math.max(self:GetTall(), 1)
	local zoom = ix.equipment.config.ui.previewZoom or 1

	-- дистанция так, чтобы модель целиком поместилась и по высоте, и по ширине
	local distance = math.max(height * 1.12 / (2 * tangent), width * 1.25 / (2 * tangent * aspect)) / zoom

	self:SetFOV(fov)
	self:SetLookAt(center)
	self:SetCamPos(center + Vector(distance, 0, 0))
end

function PREVIEW:PerformLayout(width, height)
	self:FitCamera()
end

-- подгружаем модель игрока, если она сменилась (смена персонажа)
function PREVIEW:Think()
	local model = LocalPlayer():GetModel()

	if (self.modelName != model) then
		self.modelName = model
		self:SetModel(model)

		local ent = self.Entity

		if (IsValid(ent)) then
			local sequence = ent:LookupSequence("idle_all_01")

			if (sequence <= 0) then
				sequence = ent:SelectWeightedSequence(ACT_HL2MP_IDLE)
			end

			if (sequence > 0) then
				ent:ResetSequence(sequence)
			end
		end

		self:FitCamera()
	end
end

function PREVIEW:LayoutEntity(ent)
	local client = LocalPlayer()

	if (self.dragging) then
		local x = gui.MouseX()

		self.yaw = self.yaw + (x - self.lastX) * 0.8
		self.lastX = x
	end

	ent:SetAngles(Angle(0, self.yaw, 0))
	ent:SetSkin(client:GetSkin())

	-- бодигруппы берём у настоящего игрока: сервер уже применил их из надетых предметов
	for i = 0, ent:GetNumBodyGroups() - 1 do
		ent:SetBodygroup(i, client:GetBodygroup(i))
	end

	self:RunAnimation()
end

function PREVIEW:PostDrawModel(ent)
	ix.equipment.DrawWear(ent, self.wearStore, GetEquipment())
end

function PREVIEW:OnMousePressed(code)
	if (code == MOUSE_LEFT) then
		self.dragging = true
		self.lastX = gui.MouseX()
		self:MouseCapture(true)
	elseif (code == MOUSE_RIGHT) then
		self.yaw = 0
	end
end

function PREVIEW:OnMouseReleased(code)
	if (code == MOUSE_LEFT) then
		self.dragging = false
		self:MouseCapture(false)
	end
end

-- итоговая прозрачность: 0 — меню закрывается, иначе произведение альф всех родительских панелей
function PREVIEW:GetEffectiveAlpha()
	local menu = ix.gui.menu

	if (IsValid(menu) and menu.bClosing) then
		return 0
	end

	local alpha = 1
	local panel = self

	while (IsValid(panel)) do
		alpha = alpha * (panel:GetAlpha() / 255)
		panel = panel:GetParent()
	end

	return alpha
end

function PREVIEW:Paint(width, height)
	local accent = GetAccent()

	draw.NoTexture()

	surface.SetDrawColor(14, 18, 25, 235)
	surface.DrawRect(0, 0, width, height)

	-- мягкое свечение у «пола»
	for i = 1, 24 do
		surface.SetDrawColor(accent.r, accent.g, accent.b, 26 * (1 - i / 24) ^ 2)
		surface.DrawRect(0, height - i * S(3), width, S(3))
	end

	-- 3D-модель не подчиняется альфе панелей, поэтому гасим её сами вместе с меню
	local alpha = self:GetEffectiveAlpha()

	if (alpha <= 0.02) then
		return
	end

	self:SetColor(Color(255, 255, 255, math.floor(255 * alpha)))

	BasePreview.Paint(self, width, height)
end

function PREVIEW:PaintOver(width, height)
	draw.NoTexture()

	surface.SetDrawColor(255, 255, 255, 16)
	surface.DrawOutlinedRect(0, 0, width, height, 1)

	draw.SimpleText("ЛКМ — ПОВОРОТ", "ixMenuTinyFont", width * 0.5, height - S(6), Color(255, 255, 255, 70), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
end

function PREVIEW:OnRemove()
	ix.equipment.ClearWear(self.wearStore)

	if (BasePreview.OnRemove) then
		BasePreview.OnRemove(self)
	end
end

vgui.Register("ixEquipmentPreview", PREVIEW, "DModelPanel")

--[[
	ПАНЕЛЬ СНАРЯЖЕНИЯ
]]
local PANEL = {}

function PANEL:Init()
	self.headerH = S(34)
	self.slotPanels = {}
end

function PANEL:Setup(maxHeight)
	local config = ix.equipment.config
	local gap = S(config.ui.gap)
	local columns, rows = 1, 1

	for _, slot in ipairs(config.slots) do
		columns = math.max(columns, slot.x or 1)
		rows = math.max(rows, slot.y or 1)
	end

	local offsetY = self.headerH + S(6)
	local size = S(config.ui.slotSize)

	-- если панель не помещается по высоте — уменьшаем слоты
	if (maxHeight) then
		local fit = math.floor((maxHeight - offsetY - S(6) - gap * (rows - 1)) / rows)

		size = math.max(math.min(size, fit), S(40))
	end

	-- между первой и второй колонками слотов — модель персонажа
	local previewWidth = (config.ui.preview != false and columns >= 2) and S(config.ui.previewWidth or 240) or 0
	local previewShift = previewWidth > 0 and (previewWidth + gap) or 0

	local width = columns * size + gap * (columns - 1) + previewShift + 8
	local offsetX = 4
	local gridHeight = rows * size + gap * (rows - 1)

	self:SetSize(width, offsetY + gridHeight + S(6))

	if (previewWidth > 0) then
		local preview = self:Add("ixEquipmentPreview")

		preview:SetPos(offsetX + size + gap, offsetY)
		preview:SetSize(previewWidth, gridHeight)

		self.preview = preview
	end

	for _, slot in ipairs(config.slots) do
		local column = slot.x or 1
		local panel = self:Add("ixEquipmentSlot")

		panel:Setup(slot)
		panel:SetSize(size, size)
		panel:SetPos(
			offsetX + (column - 1) * (size + gap) + (column > 1 and previewShift or 0),
			offsetY + ((slot.y or 1) - 1) * (size + gap)
		)

		self.slotPanels[#self.slotPanels + 1] = panel
	end
end

-- рамка в стиле панелей инвентаря: тёмный фон, шапка, акцентные линии и уголки
function PANEL:Paint(width, height)
	local accent = GetAccent()
	local headerH = self.headerH
	local centerY = math.floor(headerH * 0.5)

	draw.NoTexture()

	surface.SetDrawColor(8, 11, 16, 215)
	surface.DrawRect(0, 0, width, height)

	-- шапка
	surface.SetDrawColor(0, 0, 0, 90)
	surface.DrawRect(0, 0, width, headerH)

	for i = 1, 6 do
		surface.SetDrawColor(accent.r, accent.g, accent.b, 16 * (1 - i / 6) ^ 2)
		surface.DrawRect(1, headerH + i - 1, width - 2, 1)
	end

	surface.SetDrawColor(accent.r, accent.g, accent.b, 60)
	surface.DrawRect(0, headerH - 1, width, 1)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 230)
	surface.DrawRect(S(8), headerH - 2, S(40), 3)
	surface.DrawRect(S(8), centerY - S(7), 2, S(14))

	draw.SimpleText(ix.equipment.config.title or "СНАРЯЖЕНИЕ", "ixMenuTabFontSmall", S(20), centerY, Color(255, 255, 255, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local worn = 0

	for _ in pairs(GetEquipment()) do
		worn = worn + 1
	end

	draw.SimpleText("НАДЕТО  " .. worn .. " / " .. #ix.equipment.config.slots, "ixMenuTinyFont", width - S(10), centerY, Color(accent.r, accent.g, accent.b, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	-- внешняя рамка
	surface.SetDrawColor(accent.r, accent.g, accent.b, 45)
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

vgui.Register("ixEquipment", PANEL, "EditablePanel")

-- cl_inventory.lua вызывает этот хук при создании вкладки; берём родителя колонки инвентаря
-- (область контента вкладки) и ставим панель снаряжения у её левого края
hook.Add("CreateInventoryFooter", "ixEquipment", function(canvas, inventoryPanel)
	if (!IsValid(canvas)) then
		return
	end

	local container = canvas:GetParent()

	if (!IsValid(container)) then
		return
	end

	local panel = container:Add("ixEquipment")
	panel:Setup(container:GetTall() > 0 and (container:GetTall() - S(8)) or nil)
	panel:SetPos(ix.equipment.config.ui.offsetX and S(ix.equipment.config.ui.offsetX) or 0, S(8))

	ix.gui.equipment = panel
end)
