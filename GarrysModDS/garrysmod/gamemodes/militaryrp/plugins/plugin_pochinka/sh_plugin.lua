local PLUGIN = PLUGIN

PLUGIN.name = "Durability"
PLUGIN.author = "AleXXX_007"
PLUGIN.description = "Adds durability for all weapons and armor."

-- HL2 Weapons bullet damage is not counted.
-- bullet.Damage = (bullet.Damage / 100) * durability
-- bullet.Damage always 0

ix.config.Add("maxValueDurability", 100, "Maximum value of the durability.", nil, {
	data = {min = 1, max = 9999},
	category = PLUGIN.name
})

ix.config.Add("decDurability", 0.5, "By how many units do reduce the durability with each shot?", nil, {
	data = {min = 0.0001, max = 100, decimals = 4},
	category = PLUGIN.name
})

ix.config.Add("unequipItemDurability", false, "Unequip the item if durability is less than zero?", nil, {
	category = PLUGIN.name
})

ix.lang.AddTable("russian", {
	['Repair'] = "Починить",
	['RepairKitInfo'] = "Восстанавливает %s%% прочности за использование. Осталось использований: %s.",
	['RepairKitOption'] = "%s | осталось %s | +%s проц.",
	['RepairKitWrong'] = 'У вас нет ремкомплекта!',
	['RepairArmorKitWrong'] = 'У вас нет ремкомплекта для брони!',
	['DurabilityUnusableTip'] = 'Оружие теперь полностью сломано!',
	['DurabilityText'] = 'Прочность',
})

ix.lang.AddTable("english", {
	['Repair'] = "Repair",
	['RepairKitInfo'] = "Restores %s%% durability per use. Uses left: %s.",
	['RepairKitOption'] = "%s | %s left | +%s pct.",
	['RepairKitWrong'] = 'You do not have a repair kit!',
	['RepairArmorKitWrong'] = 'You do not have an armor repair kit!',
	['DurabilityUnusableTip'] = 'Your weapon is now completely broken!',
	['DurabilityText'] = 'Durability',
})

-- ---------------------------------------------------------------------------
-- Общие функции (оружие и броня)
-- ---------------------------------------------------------------------------

ix.durability = ix.durability or {}

-- Максимальная прочность предмета. nil — предмет не ломается.
-- Для брони (плагин armorweight) максимум берётся из ITEM.armorStats.durability.
function ix.durability.GetMax(item)
	if (ix.armorgear and ix.armorgear.HasStats(item)) then
		return ix.armorgear.GetMaxDurability(item)
	end

	return item.maxDurability or ix.config.Get("maxValueDurability", 100)
end

-- Все инвентари персонажа в виде списка.
local function GetInventories(client)
	local character = IsValid(client) and client:GetCharacter()

	if (not character) then
		return {}
	end

	local all = character:GetInventory(true)

	if (istable(all) and all.GetItems) then
		return {all} -- вернулся один инвентарь
	end

	return istable(all) and all or {}
end

-- Список подходящих ремкомплектов игрока (с остатком использований), у которых меньше всего использований — первыми.
-- kitFlag: "isWeaponKit" (для оружия) или "isArmorKit" (для брони).
function ix.durability.GetKits(client, kitFlag)
	local kits = {}

	for _, inventory in pairs(GetInventories(client)) do
		for _, item in pairs(inventory:GetItems()) do
			if (item.base == "base_repair_kit" and item[kitFlag] and item:GetUses() > 0) then
				kits[#kits + 1] = item
			end
		end
	end

	table.sort(kits, function(a, b)
		local ua, ub = a:GetUses(), b:GetUses()

		if (ua ~= ub) then
			return ua < ub
		end

		return a.id < b.id
	end)

	return kits
end

-- Ремкомплект по id (то, что игрок выбрал в меню). Проверяет, что он реально у игрока и нужного типа.
-- Без kitID вернёт первый подходящий (совместимость со старым вызовом).
function ix.durability.FindKit(client, kitFlag, kitID)
	local kits = ix.durability.GetKits(client, kitFlag)

	if (kitID == nil) then
		return kits[1]
	end

	for _, kit in ipairs(kits) do
		if (kit.id == kitID) then
			return kit
		end
	end
end

-- Функция «Починить» для предмета. Одна и та же для оружия и брони,
-- отличаются только тип ремкомплекта и сообщение об его отсутствии.
-- Игрок выбирает, КАКИМ комплектом чинить (подменю), если их несколько видов.
local function MakeRepairFunction(kitFlag, wrongKitPhrase, isArmor)
	return {
		name = "Repair",
		tip = "equipTip",
		icon = "icon16/bullet_wrench.png",
		isMulti = true,
		multiOptions = function(item, client)
			local options = {}
			local seen = {}

			for _, kit in ipairs(ix.durability.GetKits(client or item.player, kitFlag)) do
				-- Одинаковые комплекты не дублируем: предлагаем самый начатый.
				if (not seen[kit.uniqueID]) then
					seen[kit.uniqueID] = true

					options[#options + 1] = {
						name = L("RepairKitOption", kit.name, kit:GetUses(), kit.repairPercent or 0),
						icon = "icon16/box.png",
						data = {kitID = kit.id}
					}
				end
			end

			return options
		end,
		OnRun = function(item, data)
			local client = item.player
			local itemKit = ix.durability.FindKit(client, kitFlag, istable(data) and data.kitID or nil)

			if (itemKit) then
				local uses = itemKit:GetUses() - 1

				if (uses < 1) then
					itemKit:Remove()
				else
					itemKit:SetData("uses", uses)
					itemKit:SetData("quantity", nil) -- убираем старый счётчик у уже существующих предметов
				end

				if (itemKit.UseRepair) then
					itemKit:UseRepair(item, client)
				end

				if (itemKit.useSound) then
					client:EmitSound(itemKit.useSound, 110)
				end
			else
				client:NotifyLocalized(wrongKitPhrase)
			end

			return false
		end,

		OnCanRun = function(item)
			-- Броню, лежащую на земле, не чиним.
			if (isArmor and IsValid(item.entity)) then
				return false
			end

			local maxDurability = ix.durability.GetMax(item)

			if (not maxDurability or item:GetData("durability", maxDurability) >= maxDurability) then
				return false
			end

			return #ix.durability.GetKits(item.player, kitFlag) > 0
		end
	}
end

if (SERVER) then
	function PLUGIN:Tick()
		local curTime = CurTime()

		for _, v in ipairs(player.GetAll()) do
			if (curTime >= (v.ixNextTickDurability or 0) and v:Alive() and v:GetCharacter()) then
				local weapon = v:GetActiveWeapon()

				if (IsValid(weapon) and weapon.ixItem and weapon.ixItem.isWeapon) then
					local canShoot = weapon.ixItem:GetData("durability", weapon.ixItem.maxDurability or ix.config.Get("maxValueDurability", 100)) > 0

					if (!v:IsWepRaised()) then
						canShoot = false
					end

					if (canShoot ~= v:CanShootWeapon()) then
						v:SetNetVar("canShoot", canShoot)
					end
				end

				v.ixNextTickDurability = curTime + 0.1
			end
		end
	end

	function PLUGIN:EntityFireBullets(entity, bullet)
		if (IsValid(entity) and entity:IsPlayer()) then
			local weapon = entity:GetActiveWeapon()

			if (IsValid(weapon) and weapon.ixItem) then
				local item = weapon.ixItem

				if (item.isWeapon) then
					local durability = item:GetData("durability", item.maxDurability or ix.config.Get("maxValueDurability", 100))
					local oldDurability = durability
					local originalDamage = bullet.Damage

					bullet.Damage = (originalDamage / 100) * durability
					bullet.Spread = bullet.Spread * (1 + (1 - (0.01 * durability)))

					if (math.random(1, 16) == 1) then
						durability = math.max(0, durability - ix.config.Get("decDurability", 1))
					end

					if (oldDurability ~= durability) then
						item:SetData("durability", durability)
					end

					if (oldDurability > 0 and durability == 0) then
						entity:SetNetVar("canShoot", false)
						entity:NotifyLocalized('DurabilityUnusableTip')
					end

					if (ix.config.Get("unequipItemDurability", false) and durability < 1 and item.Unequip) then
						item:Unequip(entity)
					end
				end
			end
		end
	end
else
	-- Прочность оружия в подсказке. Для брони состояние показывает плагин armorweight.
	function PLUGIN:PopulateItemTooltip(tooltip, item)
		if (!item.isWeapon) then
			return
		end

		local panel = tooltip:AddRowAfter("description", "durability")
		local maxDurability = item.maxDurability or ix.config.Get("maxValueDurability", 100)
		local durability = math.Clamp(math.floor(item:GetData("durability", maxDurability)), 0, maxDurability)
		durability = math.max(0, math.floor((durability / maxDurability) * 100))

		panel:SetText(Format("%s: %s%% / 100%%", L("DurabilityText"), durability))
		panel:SetBackgroundColor(Color(219, 52, 52))
		panel:SizeToContents()
	end
end

-- function PLUGIN:InitializedPlugins()
function PLUGIN:RefreshWeapons()
	for _, v in pairs(ix.item.list) do
		if (v.isWeapon and v.IsTFA) then
			-- Максимум у каждого оружия свой (раньше значение «перетекало» на следующие предметы).
			local maxDurability = v.maxDurability or ix.config.Get("maxValueDurability", 100)

			if CLIENT then
				function v:PaintOver(item, w, h)
					if item.equip_slot_id ~= nil then
						surface.SetDrawColor(110, 255, 110, 100)
						surface.DrawRect(w - 14, h - 14, 8, 8)
					end

					local durability = item:GetData("durability", maxDurability)
					local durabilityPercent = math.Clamp(durability / maxDurability, 0, 1)

					if (durabilityPercent > 0) then
						-- 255 = полный канал цвета: красный -> зелёный по доле прочности
						local durabilityColor = Color(255 * (1 - durabilityPercent), 255 * durabilityPercent, 0, 255)

						surface.SetDrawColor(durabilityColor)
						surface.DrawRect(0, h - 2, w * durabilityPercent, 2)
					end
				end
			end

			v.functions.repairweapon = MakeRepairFunction("isWeaponKit", "RepairKitWrong", false)
		end
	end
end

-- Добавляет функцию «Починить» всей броне (предметам с характеристиками armorweight):
-- и с базой base_armorweight, и одежде из Simple Inventory Slots.
function PLUGIN:RefreshArmor()
	if (not ix.armorgear) then
		return
	end

	for _, v in pairs(ix.item.list) do
		if (ix.armorgear.HasStats(v)) then
			v.functions.repairarmor = MakeRepairFunction("isArmorKit", "RepairArmorKitWrong", true)
		end
	end
end

timer.Simple(1, function()
	PLUGIN:RefreshWeapons()
	PLUGIN:RefreshArmor()
end)

function PLUGIN:CanPlayerEquipItem(_, itemObj)
	if (ix.config.Get("unequipItemDurability", false)) then
		return itemObj:GetData("durability", ix.config.Get("maxValueDurability", 100)) > 0
	end
end
