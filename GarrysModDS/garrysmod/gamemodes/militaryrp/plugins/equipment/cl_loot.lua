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

-- реальные границы окон хранилища на экране. Сам ixStorageView может быть размером с весь экран,
-- поэтому считаем по видимым дочерним панелям (сетки трупа и инвентаря), а не по нему самому
local function GetStorageBounds()
	local storage = ix.gui.openedStorage

	if (!IsValid(storage)) then
		return
	end

	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	local screenW, screenH = ScrW(), ScrH()

	local function walk(panel, depth)
		for _, child in ipairs(panel:GetChildren()) do
			if (IsValid(child) and child:IsVisible() and child != ix.gui.equipmentLoot) then
				local w, h = child:GetSize()

				if (w >= screenW * 0.9 and h >= screenH * 0.9) then
					if (depth < 3) then
						walk(child, depth + 1)
					end
				elseif (w > S(150) and h > S(150)) then
					local x, y = child:LocalToScreen(0, 0)

					minX = math.min(minX, x)
					minY = math.min(minY, y)
					maxX = math.max(maxX, x + w)
					maxY = math.max(maxY, y + h)
				end
			end
		end
	end

	walk(storage, 0)

	if (minX == math.huge) then
		local x, y = storage:LocalToScreen(0, 0)
		local w, h = storage:GetSize()

		return x, y, w, h
	end

	return minX, minY, maxX - minX, maxY - minY
end

local function Place(panel)
	local width, height = panel:GetSize()
	local storageX, storageY, storageW, storageH = nil, nil, nil, nil
	local x, y

	if (panel.compact) then
		storageX, storageY, storageW, storageH = GetStorageBounds()
	end

	if (storageX) then
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

local CLOSE_TIME = 0.25

local fading = {}

-- прозрачность задаётся нами каждый кадр по общему таймеру: окна не могут «моргнуть» обратно,
-- даже если их собственный код пытается вернуть им прозрачность, и все гаснут строго синхронно
local function ApplyFade(target, now)
	if (!IsValid(target)) then
		return true
	end

	local progress = math.Clamp((now - target.ixLootFadeStart) / CLOSE_TIME, 0, 1)

	if (progress >= 1) then
		target:SetAlpha(0)
		target:SetVisible(false)
		(target.ixLootRemove or target.Remove)(target)

		return true
	end

	-- плавная кривая (быстрее не нужно, чем ease in-out)
	target:SetAlpha(math.floor(255 * (1 - progress * progress * (3 - 2 * progress))))
end

hook.Add("Think", "ixEquipmentLootFade", function()
	local now = RealTime()

	for i = #fading, 1, -1 do
		if (ApplyFade(fading[i], now)) then
			table.remove(fading, i)
		end
	end
end)

-- гасит панель и в конце убирает её (для хранилища — его оригинальным Remove)
local function FadeOut(target, startTime)
	if (!IsValid(target) or target.ixLootFading) then
		return
	end

	target.ixLootFading = true
	target.ixLootFadeStart = startTime
	target:SetMouseInputEnabled(false)
	target:SetKeyboardInputEnabled(false)

	-- собственный Think окна выполняется раньше нашего — поверх него ставим прозрачность ещё раз
	local think = target.Think

	target.Think = function(this, ...)
		if (think) then
			think(this, ...)
		end

		if (IsValid(this) and this.ixLootFadeStart) then
			ApplyFade(this, RealTime())
		end
	end

	fading[#fading + 1] = target
end

-- закрывает панель обыска и окна хранилища ОДНОВРЕМЕННО, с одним и тем же затуханием
local function CloseLoot(panel, notifyServer)
	if (!IsValid(panel) or panel.closing) then
		return
	end

	panel.closing = true

	if (notifyServer) then
		RunConsoleCommand("ix_loot_close")
	end

	local startTime = RealTime()

	FadeOut(panel, startTime)

	local storage = ix.gui.openedStorage

	if (IsValid(storage)) then
		FadeOut(storage, startTime)

		-- инвентарь игрока может быть отдельной панелью, не дочерней хранилищу
		local inventory = ix.gui.inv1

		if (IsValid(inventory) and inventory != storage and !inventory:HasParent(storage)) then
			FadeOut(inventory, startTime)
		end
	end
end

-- любое закрытие хранилища (ESC, кнопка, сервер) идёт через общее плавное закрытие вместе с панелью обыска
local function HookStorage(storage)
	if (!IsValid(storage) or storage.ixLootHooked) then
		return
	end

	storage.ixLootHooked = true
	storage.ixLootRemove = storage.Remove

	storage.Remove = function(this)
		local loot = ix.gui.equipmentLoot

		-- уже гаснет: окончательно уберём в конце затухания
		if (this.ixLootFading) then
			return
		end

		if (IsValid(loot) and !loot.closing) then
			CloseLoot(loot, true)

			return
		end

		this.ixLootRemove(this)
	end
end

-- размер слота компактной панели: по ширине хранилища и по свободной высоте над/под ним
local function GetCompactSize()
	local config = ix.equipment.config
	local maxSize = S(config.ui.slotSize)
	local _, storageY, _, storageH = GetStorageBounds()

	if (!storageY) then
		return maxSize
	end

	-- окна хранилища на момент создания могут быть ещё не выложены, поэтому ширину берём по экрану
	local maxWidth = ScrW() - S(MARGIN) * 2

	-- ширина панели линейна по размеру слота: находим размер, при котором она влезает
	local baseWidth, baseHeight = ix.equipment.GetCompactMetrics(0)
	local perSlot = (ix.equipment.GetCompactMetrics(100) - baseWidth) / 100
	local sizeByWidth = math.floor((maxWidth - baseWidth) / perSlot)

	-- по высоте: берём большую из свободных областей
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

	-- сначала должно появиться хранилище (если оно есть) — от него зависит раскладка;
	-- у игрока ждём недолго: хранилища может и не быть
	if (!IsValid(ix.gui.openedStorage) and attempt < (isPlayer and 10 or 20)) then
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
	local compact = IsValid(storage)

	panel = vgui.Create("ixEquipment")
	panel.lootEntity = entity
	panel.lootEquipment = ToEquipment(slots)
	panel.hadStorage = IsValid(storage)
	panel.compact = compact

	ix.gui.equipmentLoot = panel

	HookStorage(storage)

	local title = isPlayer and "ОБЫСК" or "ТЕЛО"

	if (isstring(name) and name != "") then
		title = title .. " — " .. name
	end

	panel:Setup(ScrH() - S(120), {
		loot = true,
		compact = compact,
		size = compact and GetCompactSize() or nil,
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