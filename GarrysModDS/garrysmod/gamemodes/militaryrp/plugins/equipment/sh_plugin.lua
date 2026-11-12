PLUGIN.name = "Equipment"
PLUGIN.author = "Claude"
PLUGIN.description = "Система снаряжения: слоты экипировки на теле, иконки слотов и конфиг предметов."

ix.equipment = ix.equipment or {}

ix.util.Include("sh_config.lua")

-- слоты по id
ix.equipment.slotsByID = {}

for _, slot in ipairs(ix.equipment.config.slots) do
	ix.equipment.slotsByID[slot.id] = slot
end

function ix.equipment.GetSlot(id)
	return ix.equipment.slotsByID[id]
end

-- параметры снаряжения предмета: поля ITEM.equip* + запись из конфига (конфиг приоритетнее).
-- принимает таблицу/экземпляр предмета или uniqueID
function ix.equipment.GetItemData(item)
	local itemTable = item
	local uniqueID = item

	if (isstring(item)) then
		itemTable = ix.item.list[item]
	elseif (istable(item)) then
		uniqueID = item.uniqueID
	end

	local data = {}

	if (itemTable) then
		data.slot = itemTable.equipSlot
		data.blocks = itemTable.equipBlocks
		data.armor = itemTable.equipArmor
		data.bodygroups = itemTable.equipBodygroups
		data.wear = itemTable.equipWear
	end

	for key, value in pairs(ix.equipment.config.items[uniqueID] or {}) do
		data[key] = value
	end

	return data
end

-- id слота, в который надевается предмет (nil, если предмет не снаряжение или слот не существует)
function ix.equipment.GetItemSlot(item)
	local slot = ix.equipment.GetItemData(item).slot

	if (slot and ix.equipment.slotsByID[slot]) then
		return slot
	end
end

-- equipped: {slotID = предмет} (сервер) или {slotID = {uid = ...}} (клиент).
-- возвращает слот и uniqueID надетого предмета, который перекрывает slotID
function ix.equipment.GetBlocker(equipped, slotID)
	for otherSlot, entry in pairs(equipped or {}) do
		local uid = entry.uid or entry.uniqueID
		local blocks = uid and ix.equipment.GetItemData(uid).blocks

		if (otherSlot != slotID and blocks and table.HasValue(blocks, slotID)) then
			return otherSlot, uid
		end
	end
end

ix.util.Include("sv_equipment.lua")
ix.util.Include("cl_equipment.lua")
ix.util.Include("cl_wear.lua")
