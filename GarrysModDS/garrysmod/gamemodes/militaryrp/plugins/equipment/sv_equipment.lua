local PLUGIN = PLUGIN
local config = ix.equipment.config

--[[
	Надетые предметы НЕ лежат в инвентаре: при надевании предмет удаляется из сетки,
	а его uniqueID и данные (item.data) записываются в данные персонажа
	(character:GetData("equipment")) — {slotID = {uid = "...", data = {...}}}.
	При снятии предмет создаётся заново (с теми же данными) и кладётся в инвентарь.
]]

-- иконки слотов должны скачаться клиентами
for _, slot in ipairs(config.slots) do
	if (slot.icon and file.Exists("materials/" .. slot.icon, "GAME")) then
		resource.AddFile("materials/" .. slot.icon)
	end
end

-- {slotID = {uid = ..., data = {...}}}
function ix.equipment.GetEquipped(client)
	client.ixEquipped = client.ixEquipped or {}

	return client.ixEquipped
end

-- бодигруппы из надетых предметов; исходные значения запоминаются и возвращаются при снятии
local function ApplyBodygroups(client)
	client.ixEquipSaved = client.ixEquipSaved or {}

	local saved = client.ixEquipSaved
	local equipped = ix.equipment.GetEquipped(client)
	local desired = {}

	for _, slot in ipairs(config.slots) do
		local entry = equipped[slot.id]

		if (entry) then
			for key, value in pairs(ix.equipment.GetItemData(entry.uid).bodygroups or {}) do
				local index = isnumber(key) and key or client:FindBodygroupByName(key)

				if (index and index >= 0) then
					desired[index] = value
				end
			end
		end
	end

	for index, value in pairs(desired) do
		if (saved[index] == nil) then
			saved[index] = client:GetBodygroup(index)
		end

		client:SetBodygroup(index, value)
	end

	for index, original in pairs(saved) do
		if (desired[index] == nil) then
			client:SetBodygroup(index, original)
			saved[index] = nil
		end
	end
end

-- отправляем клиентам, что надето (для интерфейса и отрисовки на теле)
local function Sync(client)
	local data = {}

	for slotID, entry in pairs(ix.equipment.GetEquipped(client)) do
		data[slotID] = {uid = entry.uid}
	end

	client:SetNetVar("equipment", data)
end

-- сохраняем надетое в данные персонажа
local function Save(client)
	local character = client:GetCharacter()

	if (!character) then
		return
	end

	local data = {}

	for slotID, entry in pairs(ix.equipment.GetEquipped(client)) do
		data[slotID] = {uid = entry.uid, data = entry.data}
	end

	character:SetData("equipment", data)
end

function ix.equipment.Refresh(client)
	ApplyBodygroups(client)
	Sync(client)
end

local function SubtractArmor(client, uid)
	local armor = ix.equipment.GetItemData(uid).armor

	if (armor and armor > 0) then
		client:SetArmor(math.max(client:Armor() - armor, 0))
	end
end

-- снять предмет из слота: он возвращается в инвентарь. Если места нет — остаётся надетым.
-- возвращает true, либо false и текст причины
function ix.equipment.Unequip(client, slotID)
	local character = IsValid(client) and client:GetCharacter()

	if (!character) then
		return false, "Нет активного персонажа."
	end

	local entry = ix.equipment.GetEquipped(client)[slotID]

	if (!entry) then
		-- интерфейс и сервер разошлись во мнениях — обновляем интерфейс
		Sync(client)

		return false, "В слоте «" .. tostring(slotID) .. "» на сервере ничего нет (интерфейс обновлён)."
	end

	local itemTable = ix.item.list[entry.uid]

	if (itemTable and hook.Run("CanEquipmentUnequip", client, itemTable) == false) then
		return false, "Снятие запрещено (хук CanEquipmentUnequip)."
	end

	local inventory = character:GetInventory()

	if (!inventory) then
		return false, "Инвентарь персонажа недоступен."
	end

	-- сначала кладём предмет в инвентарь
	local added = inventory:Add(entry.uid, 1, entry.data)

	if (!added) then
		return false, string.format("Нет места в инвентаре, чтобы снять: %s.", itemTable and itemTable.name or entry.uid)
	end

	ix.equipment.GetEquipped(client)[slotID] = nil

	SubtractArmor(client, entry.uid)
	Save(client)
	ix.equipment.Refresh(client)

	if (config.sounds.unequip) then
		client:EmitSound(config.sounds.unequip, 60)
	end

	hook.Run("EquipmentUnequipped", client, itemTable, slotID)

	return true
end

-- надеть предмет из инвентаря: предмет удаляется из сетки и занимает слот.
-- возвращает true, либо false и текст причины
function ix.equipment.Equip(client, item)
	local character = IsValid(client) and client:GetCharacter()

	if (!character or !item) then
		return false
	end

	local slotID = ix.equipment.GetItemSlot(item)

	if (!slotID) then
		return false, "Этот предмет нельзя надеть."
	end

	if (IsValid(item.entity) or !item.invID or item.invID == 0) then
		return false
	end

	if (hook.Run("CanEquipmentEquip", client, item) == false) then
		return false
	end

	local equipped = ix.equipment.GetEquipped(client)
	local slot = ix.equipment.GetSlot(slotID)

	-- слот перекрыт другим предметом
	local blockerSlot = ix.equipment.GetBlocker(equipped, slotID)

	if (blockerSlot) then
		local blocker = ix.item.list[equipped[blockerSlot].uid]

		return false, string.format("Слот «%s» перекрыт: %s.", slot.name, blocker and blocker.name or blockerSlot)
	end

	local data = ix.equipment.GetItemData(item)

	-- освобождаем слот (обмен) и слоты, которые перекроет новый предмет: их предметы вернутся в инвентарь
	local toClear = {slotID}

	for _, blockedSlot in ipairs(data.blocks or {}) do
		toClear[#toClear + 1] = blockedSlot
	end

	for _, clearSlot in ipairs(toClear) do
		if (equipped[clearSlot]) then
			local ok, reason = ix.equipment.Unequip(client, clearSlot)

			if (!ok) then
				return false, reason
			end
		end
	end

	-- запоминаем предмет и убираем его из инвентаря
	local entry = {uid = item.uniqueID, data = table.Copy(item.data or {})}

	item:Remove()

	equipped[slotID] = entry

	if (data.armor and data.armor > 0) then
		local maxArmor = client.GetMaxArmor and client:GetMaxArmor() or 100

		client:SetArmor(math.min(client:Armor() + data.armor, math.max(maxArmor, 100)))
	end

	Save(client)
	ix.equipment.Refresh(client)

	if (config.sounds.equip) then
		client:EmitSound(config.sounds.equip, 60)
	end

	hook.Run("EquipmentEquipped", client, ix.item.list[entry.uid], slotID)

	return true
end

-- восстановить состояние из данных персонажа (загрузка персонажа, респавн)
function ix.equipment.Rebuild(client)
	if (!IsValid(client)) then
		return
	end

	local character = client:GetCharacter()

	client.ixEquipped = {}

	if (character) then
		local bChanged = false

		for slotID, entry in pairs(character:GetData("equipment", {})) do
			local itemTable = istable(entry) and entry.uid and ix.item.list[entry.uid]

			if (itemTable and ix.equipment.GetItemSlot(entry.uid) == slotID) then
				client.ixEquipped[slotID] = {uid = entry.uid, data = entry.data or {}}
			else
				-- предмет удалили из игры или его слот изменился в конфиге: возвращаем в инвентарь, если можем
				bChanged = true

				local inventory = character:GetInventory()

				if (itemTable and inventory) then
					inventory:Add(entry.uid, 1, entry.data)
				end
			end
		end

		if (bChanged) then
			Save(client)
		end
	end

	ix.equipment.Refresh(client)
end

-- снять предмет из слота по запросу интерфейса.
-- консольная команда вместо net-сообщения: новые net-строки не доходят до клиентов, уже сидящих на сервере
-- (после горячей перезагрузки плагина), а консольные команды работают сразу
concommand.Add("ix_equipment_unequip", function(client, command, arguments)
	if (!IsValid(client)) then
		return
	end

	local slotID = arguments[1]

	if (!isstring(slotID) or (client.ixEquipNext or 0) > CurTime()) then
		return
	end

	client.ixEquipNext = CurTime() + 0.25

	local ok, reason = ix.equipment.Unequip(client, slotID)

	if (!ok) then
		client:Notify(reason or "Не удалось снять предмет.")
	end
end)

function PLUGIN:PlayerLoadout(client)
	-- при респавне модель сбрасывается, бодигруппы нужно выставить заново
	client.ixEquipSaved = {}

	timer.Simple(0.1, function()
		ix.equipment.Rebuild(client)
	end)
end

function PLUGIN:PlayerLoadedCharacter(client, character, lastChar)
	client.ixEquipSaved = {}
	client.ixEquipped = {}
	client:SetNetVar("equipment", {})

	timer.Simple(0.25, function()
		ix.equipment.Rebuild(client)
	end)
end