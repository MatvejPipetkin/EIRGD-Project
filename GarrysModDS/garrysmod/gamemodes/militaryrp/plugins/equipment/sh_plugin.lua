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
		data.weapon = itemTable.equipWeapon
	end

	-- оружие: слот берётся из ITEM.weaponCategory, класс SWEP — из ITEM.class
	if (itemTable and itemTable.class and itemTable.weaponCategory) then
		local categories = ix.equipment.config.weapons and ix.equipment.config.weapons.categories
		local weaponSlot = categories and categories[itemTable.weaponCategory]

		if (weaponSlot) then
			data.slot = data.slot or weaponSlot
			data.weapon = data.weapon or itemTable.class
		end
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

-- оружие из base_weapons: «Надеть» теперь кладёт его в слот оружия вместо стандартной логики
function PLUGIN:InitializedPlugins()
	for _, itemTable in pairs(ix.item.list) do
		local slotID = itemTable.class and itemTable.weaponCategory and ix.equipment.GetItemSlot(itemTable)
		local slot = slotID and ix.equipment.GetSlot(slotID)

		if (slot and slot.weapon) then
			-- свои копии функций, чтобы не затронуть базовый предмет и остальное оружие
			itemTable.functions = table.Copy(itemTable.functions or {})

			itemTable.functions.EquipUn = nil
			itemTable.functions.Equip = {
				name = "Надеть",
				icon = "icon16/tick.png",
				OnRun = function(item)
					local client = item.player
					local ok, reason = ix.equipment.Equip(client, item)

					if (!ok and reason) then
						client:Notify(reason)
					end

					-- предмет уже убран из инвентаря самим Equip
					return false
				end,
				OnCanRun = function(item)
					local client = item.player

					return !IsValid(item.entity) and IsValid(client)
						and ix.equipment.GetItemSlot(item) != nil
						and hook.Run("CanEquipmentEquip", client, item) != false
				end
			}

			-- базовое снятие оружия при удалении предмета не нужно: оружием управляет слот
			itemTable.OnRemoved = function() end
		end
	end
end

ix.util.Include("sv_equipment.lua")
ix.util.Include("cl_equipment.lua")
ix.util.Include("cl_wear.lua")
ix.util.Include("sv_loot.lua")
ix.util.Include("cl_loot.lua")
