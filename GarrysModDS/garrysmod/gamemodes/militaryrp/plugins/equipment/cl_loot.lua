local function S(value)
	return math.floor(value * ScrH() / 1080 + 0.5)
end

--[[
	ПАНЕЛЬ ОБЫСКА: снаряжение цели (трупа или живого игрока).
	Клик по предмету — забрать в свой инвентарь, «ЗАБРАТЬ ВСЁ» — снять всё, что влезет.

	Два вида:
	  • у трупа рядом открыто хранилище на весь экран — панель становится компактной полосой
	    (все слоты в один ряд) над хранилищем или под ним и ничего не перекрывает;
	  • у живого игрока хранилища нет — по центру экрана полная панель с моделью персонажа.
]]

local MARGIN = 10

local function ToEquipment(slots)
	local equipment = {}

	for slotID, uid in pairs(slots) do
		equipment[slotID] = {uid = uid}
	end

	return equipment
end

local function Place(panel)
	local width, height = panel:GetSize()
	local storage = panel.compact and ix.gui.openedStorage
	local x, y

	if (IsValid(storage)) then
		local storageX, storageY = storage:GetPos()
		local storageW, storageH = storage:GetSize()
		local below = storageY + storageH + S(8)

		x = storageX + storageW * 0.5 - width * 0.5

		if (storageY - S(8) - height >= S(6)) then
			y = storageY - S(8) - height -- над хранилищем
		elseif (below + height <= ScrH() - S(6)) then
			y = below -- под хранилищем
		else
			y = S(6)
		end
	else
		x = ScrW() * 0.5 - width * 0.5
		y = ScrH() * 0.5 - height * 0.5
	end

	panel:SetPos(
		math.Clamp(x, S(MARGIN), math.max(ScrW() - width - S(MARGIN), S(MARGIN))),
		math.Clamp(y, S(6), math.max(ScrH() - height - S(6), S(6)))
	)
end

local function CloseLoot(panel, notifyServer)
	if (!IsValid(panel) or panel.closing) then
		return
	end

	panel.closing = true

	if (notifyServer) then
		RunConsoleCommand("ix_loot_close")
	end

	panel:SetMouseInputEnabled(false)
	panel:SetKeyboardInputEnabled(false)
	panel:AlphaTo(0, 0.15, 0, function()
		if (IsValid(panel)) then
			panel:Remove()
		end
	end)
end

-- размер слота компактной панели: по ширине хранилища и по свободной высоте над/под ним
local function GetCompactSize(storage)
	local config = ix.equipment.config
	local maxSize = S(config.ui.slotSize)
	local storageX, storageY = storage:GetPos()
	local storageW, storageH = storage:GetSize()
	local maxWidth = math.min(ScrW() - S(MARGIN) * 2, math.max(storageW, S(700)))

	-- ширина панели линейна по размеру слота: находим размер, при котором она влезает
	local baseWidth = ix.equipment.GetCompactMetrics(0)
	local perSlot = (ix.equipment.GetCompactMetrics(100) - baseWidth) / 100
	local sizeByWidth = math.floor((maxWidth - baseWidth) / perSlot)

	-- по высоте: берём большую из свободных областей
	local _, baseHeight = ix.equipment.GetCompactMetrics(0)
	local free = math.max(storageY - S(14), ScrH() - (storageY + storageH) - S(14))
	local sizeByHeight = math.floor(free - baseHeight)

	return math.max(math.min(maxSize, sizeByWidth, sizeByHeight), S(44))
end

local pending = 0

local function OpenLootPanel(entity, isPlayer, slots, name, attempt)
	local panel = ix.gui.equipmentLoot

	-- уже открыта для этой цели: просто обновляем слоты (после того, как что-то забрали)
	if (IsValid(panel) and !panel.closing and panel.lootEntity == entity) then
		panel.lootEquipment = ToEquipment(slots)

		return
	end

	attempt = attempt or 0

	-- у трупа сначала должно появиться хранилище — от него зависит раскладка
	if (!isPlayer and !IsValid(ix.gui.openedStorage) and attempt < 20) then
		pending = pending + 1

		local ticket = pending

		timer.Simple(0.05, function()
			if (ticket == pending) then
				OpenLootPanel(entity, isPlayer, slots, name, attempt + 1)
			end
		end)

		return
	end

	pending = pending + 1

	if (!IsValid(entity)) then
		return
	end

	if (IsValid(panel)) then
		panel:Remove()
	end

	local storage = ix.gui.openedStorage
	local compact = !isPlayer and IsValid(storage)

	panel = vgui.Create("ixEquipment")
	panel.lootEntity = entity
	panel.lootEquipment = ToEquipment(slots)
	panel.hadStorage = IsValid(storage)
	panel.compact = compact

	ix.gui.equipmentLoot = panel

	local title = isPlayer and "ОБЫСК" or "ТЕЛО"

	if (isstring(name) and name != "") then
		title = title .. " — " .. name
	end

	panel:Setup(ScrH() - S(120), {
		loot = true,
		compact = compact,
		size = compact and GetCompactSize(storage) or nil,
		title = title,
		getEquipment = function()
			return IsValid(panel) and panel.lootEquipment or {}
		end,
		getEntity = function()
			return IsValid(panel) and panel.lootEntity or nil
		end,
		onClose = function()
			CloseLoot(panel, true)
		end
	})

	panel:MakePopup()
	panel:SetKeyboardInputEnabled(true)
	panel:SetAlpha(0)
	panel:AlphaTo(255, 0.2, 0)

	Place(panel)

	panel.OnKeyCodePressed = function(this, key)
		if (key == KEY_ESCAPE) then
			gui.HideGameUI()
			CloseLoot(this, true)
		end
	end

	panel.nextPlace = 0

	panel.Think = function(this)
		if (this.closing) then
			return
		end

		-- цель пропала (труп исчез) или хранилище трупа закрыли — закрываем и панель
		if (!IsValid(this.lootEntity)) then
			CloseLoot(this, true)

			return
		end

		local storageOpen = IsValid(ix.gui.openedStorage)

		if (this.hadStorage and !storageOpen) then
			CloseLoot(this, true)

			return
		end

		this.hadStorage = storageOpen

		-- хранилище может менять размер/позицию при открытии — подстраиваемся
		if (this.nextPlace < RealTime()) then
			this.nextPlace = RealTime() + 0.1

			Place(this)
		end
	end
end

net.Receive("ixEquipmentLoot", function()
	local entity = net.ReadEntity()
	local isPlayer = net.ReadBool()
	local slots = net.ReadTable()
	local name = net.ReadString()

	if (IsValid(entity)) then
		OpenLootPanel(entity, isPlayer, slots, name)
	end
end)

net.Receive("ixEquipmentLootClose", function()
	pending = pending + 1

	CloseLoot(ix.gui.equipmentLoot, false)
end)
