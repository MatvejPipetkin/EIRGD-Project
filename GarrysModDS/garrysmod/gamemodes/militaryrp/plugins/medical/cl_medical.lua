local RECEIVER_NAME = "ixInventoryItem" -- тот же приёмник, что и у сетки инвентаря
local config = ix.medical.config
local limbsByID = ix.medical.limbsByID

local function S(value)
	return math.floor(value * ScrH() / 1080 + 0.5)
end

local function GetAccent()
	local style = ix.menuStyle

	return (style and style.accent) or ix.config.Get("color") or Color(90, 160, 235)
end

local COLOR_GOOD = Color(110, 210, 130)
local COLOR_BAD = Color(225, 85, 80)
local COLOR_SHADOW = Color(0, 0, 0, 210)

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

local function GetState()
	return LocalPlayer():GetLocalVar("med") or {limbs = {}, cond = {}}
end

-- сервер шлёт состояние редко (раз в ~10 с), поэтому оставшееся время болезни
-- досчитывается на клиенте: left из пакета минус время, прошедшее с его отправки
local function GetLeft(cond)
	if (!cond.left) then
		return nil
	end

	local stamp = GetState().stamp

	if (!stamp) then
		return cond.left
	end

	return math.max(cond.left - (CurTime() - stamp), 0)
end

-- процент пройденного курса лечения (nil, если у состояния курса нет)
local function GetTreatPercent(cond, def)
	if (!def or !def.courses) then
		return nil
	end

	return math.floor(math.Clamp(cond.treat or 0, 0, 1) * 100 + 0.5)
end

local iconCache = {}

local function GetIcon(name)
	if (iconCache[name] == nil) then
		local material = Material("medical/icons/" .. name .. ".png", "smooth mips")

		iconCache[name] = (material and !material:IsError()) and material or false
	end

	return iconCache[name]
end

-- красный → жёлтый → зелёный по доле здоровья
local function HPColor(fraction)
	fraction = math.Clamp(fraction, 0, 1)

	if (fraction > 0.5) then
		local t = (fraction - 0.5) * 2

		return Lerp(t, 235, 95), Lerp(t, 200, 205), Lerp(t, 70, 110)
	end

	local t = fraction * 2

	return Lerp(t, 215, 235), Lerp(t, 60, 200), Lerp(t, 60, 70)
end

local function FormatTime(seconds)
	seconds = math.max(math.floor(seconds), 0)

	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- медикамент, который сейчас тащат из инвентаря
local function GetDragMed()
	local dragging = dragndrop.GetDroppable()
	local panel = dragging and dragging[1]

	if (IsValid(panel) and panel.GetItemTable) then
		local item = panel:GetItemTable()

		if (item and item.medical) then
			return config.meds[item.medical], item, panel
		end
	end
end

-- применить перетащенный предмет (limbID = nil для «внутрь»)
local function TryUse(limbID, panel, item, med)
	local ok, reason = ix.medical.CanHelp(GetState(), med, limbID)

	if (!ok) then
		Notify(reason or "Сейчас это ничего не даст.")

		return
	end

	local action = med.target == "limb" and "Apply" or "Consume"

	item.player = LocalPlayer()

	local info = item.functions[action]

	if (info and (!info.OnCanRun or info.OnCanRun(item, {limb = limbID}) != false)) then
		InventoryAction(action, item.id, panel.GetInventoryID and panel:GetInventoryID() or item.invID, {limb = limbID})
	end

	item.player = nil
end

-- чем лечится состояние (для подсказки); «грязные» препараты в подсказку не попадают — на них не стоит рассчитывать
local curesCache = {}

local function GetCures(id)
	if (!curesCache[id]) then
		local names = {}

		for _, med in SortedPairs(config.meds) do
			if (!med.dirty and ((med.cures and med.cures[id]) or (med.downgrade and med.downgrade[id]))) then
				names[#names + 1] = med.name
			end
		end

		curesCache[id] = table.concat(names, ", ")
	end

	return curesCache[id]
end

--[[
	ЗОНА КОНЕЧНОСТИ НА СИЛУЭТЕ
]]
local LIMB = {}

function LIMB:Init()
	self:Receiver(RECEIVER_NAME, self.OnItemDragged)
end

function LIMB:Setup(limb)
	self.limb = limb

	local material = Material("medical/body/" .. limb.id .. ".png", "smooth mips")

	if (material and !material:IsError()) then
		self.material = material
	end

	self:SetHelixTooltip(function(tooltip)
		self:PopulateTooltip(tooltip)
	end)
end

function LIMB:GetConditions()
	local list = {}

	for _, cond in pairs(GetState().cond) do
		if (cond.limb == self.limb.id and config.conditions[cond.id]) then
			list[#list + 1] = cond
		end
	end

	table.sort(list, function(a, b) return a.id < b.id end)

	return list
end

function LIMB:PopulateTooltip(tooltip)
	local limb = self.limb
	local hp = GetState().limbs[limb.id] or limb.maxHP

	local title = tooltip:AddRow("name")
	title:SetImportant()
	title:SetText(limb.name)
	title:SizeToContents()

	local row = tooltip:AddRow("limbHP")
	row:SetText(string.format("Здоровье: %d / %d", math.ceil(hp), limb.maxHP))
	row:SizeToContents()

	for _, cond in ipairs(self:GetConditions()) do
		local conditionRow = tooltip:AddRow("cond_" .. cond.id)
		conditionRow:SetText("• " .. config.conditions[cond.id].name)
		conditionRow:SizeToContents()
	end
end

function LIMB:OnItemDragged(panels, bDropped, command, x, y)
	local panel = panels[1]

	if (!IsValid(panel) or !panel.GetItemTable) then
		return
	end

	local item = panel:GetItemTable()

	if (!item) then
		return
	end

	local med = item.medical and config.meds[item.medical]

	if (!bDropped) then
		self.dragHover = RealTime()
		self.dragOk = med != nil and (ix.medical.CanHelp(GetState(), med, self.limb.id))

		return
	end

	self.dragHover = nil

	if (!med) then
		Notify("Это не медицинский предмет.")

		return
	end

	TryUse(self.limb.id, panel, item, med)
end

function LIMB:Paint(width, height)
	local state = GetState()
	local limb = self.limb
	local hp = state.limbs[limb.id] or limb.maxHP
	local r, g, b = HPColor(hp / limb.maxHP)

	if (self.material) then
		surface.SetMaterial(self.material)
		surface.SetDrawColor(r, g, b, self:IsHovered() and 255 or 225)
		surface.DrawTexturedRect(0, 0, width, height)
	else
		draw.NoTexture()
		surface.SetDrawColor(r, g, b, 140)
		surface.DrawRect(0, 0, width, height)
	end

	-- подсветка: куда можно применить перетаскиваемый медикамент
	local med = GetDragMed()
	local previewColor, alpha

	if (self.dragHover and RealTime() - self.dragHover < 0.1) then
		previewColor = self.dragOk and COLOR_GOOD or COLOR_BAD
		alpha = 150
	elseif (med and ix.medical.CanHelp(state, med, limb.id)) then
		previewColor = COLOR_GOOD
		alpha = 70 + 70 * math.abs(math.sin(RealTime() * 3))
	end

	if (previewColor) then
		if (self.material) then
			surface.SetMaterial(self.material)
		else
			draw.NoTexture()
		end

		surface.SetDrawColor(previewColor.r, previewColor.g, previewColor.b, alpha)
		surface.DrawTexturedRect(0, 0, width, height)
	end

	-- значки состояний на этой конечности
	local conditions = self:GetConditions()
	local size = S(18)
	local gap = S(2)
	local count = math.min(#conditions, math.max(math.floor((width + gap) / (size + gap)), 1))
	local x = math.floor((width - (count * size + (count - 1) * gap)) * 0.5)
	local y = math.floor((height - size) * 0.5)

	for i = 1, count do
		local def = config.conditions[conditions[i].id]
		local icon = def and GetIcon(def.icon)

		if (icon) then
			surface.SetMaterial(icon)
			surface.SetDrawColor(0, 0, 0, 210)
			surface.DrawTexturedRect(x + 1, y + 1, size, size)
			surface.SetDrawColor(def.color.r, def.color.g, def.color.b, 255)
			surface.DrawTexturedRect(x, y, size, size)
		end

		x = x + size + gap
	end
end

vgui.Register("ixMedicalLimb", LIMB, "DPanel")

--[[
	ПЛИТКА СОСТОЯНИЯ
]]
local TILE = {}

function TILE:Setup(key)
	self.key = key

	self:SetHelixTooltip(function(tooltip)
		self:PopulateTooltip(tooltip)
	end)
end

function TILE:GetCondition()
	local cond = GetState().cond[self.key]

	return cond, cond and config.conditions[cond.id]
end

function TILE:PopulateTooltip(tooltip)
	local cond, def = self:GetCondition()

	if (!def) then
		return
	end

	local title = tooltip:AddRow("name")
	title:SetImportant()
	title:SetText(def.name)

	if (title.SetBackgroundColor) then
		title:SetBackgroundColor(def.color)
	end

	title:SizeToContents()

	local kinds = {injury = "Ранение", disease = "Болезнь", buff = "Эффект"}
	local kind = tooltip:AddRow("kind")
	kind:SetText((kinds[def.kind] or "") .. (cond.limb and (" — " .. limbsByID[cond.limb].name) or ""))
	kind:SizeToContents()

	local description = tooltip:AddRow("description")
	description:SetText(def.desc or "")
	description:SizeToContents()

	-- прогресс курса лечения сразу под описанием болезни
	if (def.courses) then
		local row = tooltip:AddRow("treat")
		row:SetText("Вылечено: " .. GetTreatPercent(cond, def) .. "%")
		row:SizeToContents()

		-- строка обновляется, пока подсказка открыта: прогресс меняется, когда вы применяете препарат
		local tile, shown = self, nil

		row.Think = function(this)
			if (!IsValid(tile)) then
				return
			end

			local c, d = tile:GetCondition()
			local percent = c and GetTreatPercent(c, d)

			if (percent and percent != shown) then
				shown = percent
				this:SetText("Вылечено: " .. percent .. "%")
				this:SizeToContents()
			end
		end
	end

	if (cond.left) then
		local left = tooltip:AddRow("left")
		left:SetText("Осталось: " .. FormatTime(GetLeft(cond)))
		left:SizeToContents()

		local tile, shown = self, nil

		left.Think = function(this)
			if (!IsValid(tile)) then
				return
			end

			local c = tile:GetCondition()
			local text = c and c.left and FormatTime(GetLeft(c))

			if (text and text != shown) then
				shown = text
				this:SetText("Осталось: " .. text)
				this:SizeToContents()
			end
		end
	end

	if (config.showCures and def.kind != "buff") then
		local cures = GetCures(cond.id)

		if (cures != "") then
			local row = tooltip:AddRow("cures")
			row:SetText("Чем лечить: " .. cures)
			row:SizeToContents()
		end
	end
end

function TILE:Paint(width, height)
	local cond, def = self:GetCondition()

	if (!def) then
		return
	end

	local color = def.color
	local accent = GetAccent()

	draw.NoTexture()
	surface.SetDrawColor(22, 27, 34, 235)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(color.r, color.g, color.b, 38)
	surface.DrawRect(1, 1, width - 2, height - 2)

	local icon = GetIcon(def.icon)

	if (icon) then
		local size = math.floor(math.min(width, height) * 0.62)

		surface.SetMaterial(icon)
		surface.SetDrawColor(color.r, color.g, color.b, 255)
		surface.DrawTexturedRect(math.floor((width - size) * 0.5), S(3), size, size)
	end

	-- полоска прогресса лечения вдоль верхнего края плитки
	if (def.courses and (cond.treat or 0) > 0) then
		surface.SetDrawColor(110, 225, 130, 255)
		surface.DrawRect(1, 1, math.max(math.floor((width - 2) * cond.treat), 1), math.max(S(2), 2))
	end

	-- процент вылеченного: внизу, если нет таймера; иначе в верхнем углу
	local percent = GetTreatPercent(cond, def)

	if (percent) then
		local text = percent .. "%"
		local good = Color(120, 235, 140, 255)

		if (cond.left) then
			draw.SimpleText(text, "ixMenuTinyFont", width - S(3) + 1, S(4) + 1, COLOR_SHADOW, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
			draw.SimpleText(text, "ixMenuTinyFont", width - S(3), S(4), good, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		else
			draw.SimpleText(text, "ixMenuTinyFont", width * 0.5 + 1, height - S(2) + 1, COLOR_SHADOW, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
			draw.SimpleText(text, "ixMenuTinyFont", width * 0.5, height - S(2), good, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		end
	end

	if (cond.left) then
		local text = FormatTime(GetLeft(cond))

		draw.SimpleText(text, "ixMenuTinyFont", width * 0.5 + 1, height - S(2) + 1, COLOR_SHADOW, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		draw.SimpleText(text, "ixMenuTinyFont", width * 0.5, height - S(2), Color(255, 255, 255, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
	end

	if (self:IsHovered()) then
		surface.SetDrawColor(accent.r, accent.g, accent.b, 255)
	else
		surface.SetDrawColor(color.r, color.g, color.b, 130)
	end

	surface.DrawOutlinedRect(0, 0, width, height, 1)
end

vgui.Register("ixMedicalTile", TILE, "DPanel")

--[[
	ПАНЕЛЬ «СОСТОЯНИЕ ТЕЛА»
]]
local PANEL = {}

function PANEL:Init()
	self.headerH = S(34)
	self.zones = {}
	self.tiles = {}
	self.signature = ""
	self.nextCheck = 0

	self:Receiver(RECEIVER_NAME, self.OnItemDragged)
end

function PANEL:Setup(canvas)
	self.canvas = canvas

	for _, limb in ipairs(config.limbs) do
		local zone = self:Add("ixMedicalLimb")
		zone:Setup(limb)

		self.zones[#self.zones + 1] = zone
	end
end

-- перетаскивание «внутрь» (target = self) можно бросить в любое место панели
function PANEL:OnItemDragged(panels, bDropped, command, x, y)
	if (!bDropped) then
		return
	end

	local panel = panels[1]
	local item = IsValid(panel) and panel.GetItemTable and panel:GetItemTable()

	if (!item) then
		return
	end

	local med = item.medical and config.meds[item.medical]

	if (!med) then
		Notify("Это не медицинский предмет.")
	elseif (med.target == "limb") then
		Notify("Перетащите на нужную часть тела.")
	else
		TryUse(nil, panel, item, med)
	end
end

function PANEL:ApplyLayout(width, height)
	local pad = S(10)
	local tilesH = S(96)
	local bodyTop = self.headerH + pad
	local bodyH = height - bodyTop - tilesH - pad
	local scale = bodyH / 400
	local bodyW = math.floor(200 * scale)

	self:SetSize(width, height)

	self.bodyRect = {x = pad, y = bodyTop, w = bodyW, h = bodyH}
	self.listRect = {x = pad * 2 + bodyW, y = bodyTop, w = width - pad * 3 - bodyW, h = bodyH}
	self.tilesRect = {x = pad, y = height - tilesH, w = width - pad * 2, h = tilesH - pad}

	for _, zone in ipairs(self.zones) do
		local rect = zone.limb.rect

		zone:SetPos(math.floor(pad + rect[1] * scale), math.floor(bodyTop + rect[2] * scale))
		zone:SetSize(math.ceil(rect[3] * scale), math.ceil(rect[4] * scale))
	end

	self.signature = nil
end

function PANEL:RebuildTiles()
	for _, tile in ipairs(self.tiles) do
		if (IsValid(tile)) then
			tile:Remove()
		end
	end

	self.tiles = {}

	local keys = {}

	for key in pairs(GetState().cond) do
		keys[#keys + 1] = key
	end

	table.sort(keys)

	local rect = self.tilesRect
	local size = S(40)
	local gap = S(6)
	local labelH = S(18)
	local columns = math.max(math.floor((rect.w + gap) / (size + gap)), 1)
	local maxTiles = math.min(config.maxIcons, columns * 2)

	self.overflow = math.max(#keys - maxTiles, 0)

	for i = 1, math.min(#keys, maxTiles) do
		local tile = self:Add("ixMedicalTile")

		tile:Setup(keys[i])
		tile:SetSize(size, size)
		tile:SetPos(rect.x + ((i - 1) % columns) * (size + gap), rect.y + labelH + math.floor((i - 1) / columns) * (size + gap))

		self.tiles[#self.tiles + 1] = tile
	end
end

function PANEL:Think()
	local equipment = ix.gui.equipment
	local x = IsValid(equipment) and (equipment:GetX() + equipment:GetWide() + S(10)) or 0
	local height = IsValid(equipment) and equipment:GetTall() or S(620)
	local width = S(440)

	-- не залезаем на колонку инвентаря
	if (IsValid(self.canvas)) then
		local limit = self.canvas:GetX() - x - S(10)

		if (limit > 0) then
			width = math.min(width, limit)
		end
	end

	width = math.max(width, S(300))

	if (self:GetX() != x or self:GetY() != S(8)) then
		self:SetPos(x, S(8))
	end

	if (self:GetWide() != width or self:GetTall() != height) then
		self:ApplyLayout(width, height)
	end

	if (CurTime() >= self.nextCheck) then
		self.nextCheck = CurTime() + 0.2

		local keys = {}

		for key in pairs(GetState().cond) do
			keys[#keys + 1] = key
		end

		table.sort(keys)

		local signature = table.concat(keys, "|")

		if (signature != self.signature) then
			self.signature = signature
			self:RebuildTiles()
		end
	end
end

function PANEL:Paint(width, height)
	local accent = GetAccent()
	local headerH = self.headerH
	local centerY = math.floor(headerH * 0.5)
	local state = GetState()

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

	draw.SimpleText("СОСТОЯНИЕ ТЕЛА", "ixMenuTabFontSmall", S(20), centerY, Color(255, 255, 255, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local count = table.Count(state.cond)

	draw.SimpleText(count > 0 and ("СОСТОЯНИЙ  " .. count) or "В НОРМЕ", "ixMenuTinyFont", width - S(10), centerY,
		count > 0 and Color(235, 170, 90, 230) or Color(accent.r, accent.g, accent.b, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	if (!self.bodyRect) then
		return
	end

	-- подложка под силуэт
	local body = self.bodyRect

	surface.SetDrawColor(14, 18, 25, 235)
	surface.DrawRect(body.x - S(4), body.y - S(4), body.w + S(8), body.h + S(8))
	surface.SetDrawColor(255, 255, 255, 16)
	surface.DrawOutlinedRect(body.x - S(4), body.y - S(4), body.w + S(8), body.h + S(8), 1)

	if (GetDragMed()) then
		draw.SimpleText("НА ЧАСТЬ ТЕЛА", "ixMenuTinyFont", body.x + body.w * 0.5, body.y + body.h + S(2), Color(COLOR_GOOD.r, COLOR_GOOD.g, COLOR_GOOD.b, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end

	-- список HP конечностей
	local list = self.listRect
	local rowH = list.h / #config.limbs

	for index, limb in ipairs(config.limbs) do
		local y = math.floor(list.y + (index - 1) * rowH)
		local hp = state.limbs[limb.id] or limb.maxHP
		local r, g, b = HPColor(hp / limb.maxHP)
		local barY = y + S(20)
		local barH = S(8)

		draw.SimpleText(limb.short, "ixMenuTinyFont", list.x, y + S(3), Color(255, 255, 255, 190), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText(math.ceil(hp) .. " / " .. limb.maxHP, "ixMenuTinyFont", list.x + list.w, y + S(3), Color(r, g, b, 235), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

		surface.SetDrawColor(0, 0, 0, 150)
		surface.DrawRect(list.x, barY, list.w, barH)

		surface.SetDrawColor(r, g, b, 235)
		surface.DrawRect(list.x + 1, barY + 1, math.max((list.w - 2) * (hp / limb.maxHP), 0), barH - 2)

		surface.SetDrawColor(255, 255, 255, 22)
		surface.DrawOutlinedRect(list.x, barY, list.w, barH, 1)
	end

	-- заголовок плиток состояний
	local tiles = self.tilesRect

	surface.SetDrawColor(accent.r, accent.g, accent.b, 45)
	surface.DrawRect(tiles.x, tiles.y - S(4), tiles.w, 1)

	draw.SimpleText("АКТИВНЫЕ СОСТОЯНИЯ", "ixMenuTinyFont", tiles.x, tiles.y, Color(255, 255, 255, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	if (count == 0) then
		draw.SimpleText("Ранений и болезней нет", "ixMenuTinyFont", tiles.x, tiles.y + S(26), Color(255, 255, 255, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	elseif ((self.overflow or 0) > 0) then
		draw.SimpleText("+" .. self.overflow, "ixMenuTinyFont", tiles.x + tiles.w, tiles.y, Color(235, 170, 90, 230), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	end

	-- внешняя рамка и уголки
	surface.SetDrawColor(accent.r, accent.g, accent.b, 45)
	surface.DrawOutlinedRect(0, 0, width, height, 1)

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

vgui.Register("ixMedical", PANEL, "EditablePanel")

-- панель встаёт справа от панели снаряжения (если она есть) и слева от колонки инвентаря
hook.Add("CreateInventoryFooter", "ixMedical", function(canvas, inventoryPanel)
	if (!IsValid(canvas)) then
		return
	end

	local container = canvas:GetParent()

	if (!IsValid(container)) then
		return
	end

	local panel = container:Add("ixMedical")
	panel:Setup(canvas)
	panel:SetPos(0, S(8))

	ix.gui.medical = panel
end)
