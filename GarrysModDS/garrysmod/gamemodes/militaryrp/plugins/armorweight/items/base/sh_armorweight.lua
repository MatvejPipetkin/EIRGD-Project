ITEM.name = "Снаряжение"
ITEM.description = "Предмет экипировки."
ITEM.category = "Броня"
ITEM.model = "models/props_c17/BriefCase001a.mdl"
ITEM.width = 2
ITEM.height = 2

-- Метка для плагина: этот предмет учитывается в расчётах.
ITEM.isArmorGear = true

--[[
	ХАРАКТЕРИСТИКИ ЗАДАЮТСЯ В ФАЙЛЕ ПРЕДМЕТА ОДНИМ БЛОКОМ (шаблон для копирования):

	ITEM.armorStats = {
		slot = "body",         -- Слот: в одном слоте носится один предмет (body, head, ...)
		weight = 11,           -- Вес, кг. Складывается по всем надетым предметам
		protection = 60,       -- Бронирование, %: доля урона пуль/дроби/ножей/дубинок, которая игнорируется
		blast = 20,            -- Взрывоустойчивость, %: доля урона от взрывов, которая игнорируется
		ergonomics = -8,       -- Эргономика, % к скорости (минус — замедляет)
		coverage = {"torso"},  -- Какие зоны закрывает: head, chest, stomach, torso, arms, legs, all
		durability = 150,      -- Макс. прочность. Не пишите, чтобы взять общую; false — не изнашивается
	}

	Не нужная характеристика просто не пишется (по умолчанию 0).
	Цвета в подсказке предмета и шкалы для них настраиваются в sh_plugin.lua (gear.colors, gear.statScale).
]]
ITEM.armorStats = {}

-- Состояние (полоска на иконке и строка «Состояние» в подсказке) рисуется плагином само.
if (CLIENT) then
	function ITEM:PaintOver(item, w, h)
		if (item:GetData("equip")) then
			surface.SetDrawColor(110, 255, 110, 100)
			surface.DrawRect(w - 14, h - 14, 8, 8)
		end
	end
end

-- Надетое снаряжение нельзя выбросить.
ITEM:Hook("drop", function(item)
	if (item:GetData("equip")) then
		item.player:Notify("Сначала снимите это снаряжение.")

		return false
	end
end)

-- Надетое снаряжение нельзя переложить в другой инвентарь.
function ITEM:CanTransfer(oldInventory, newInventory)
	if (newInventory and newInventory:GetID() ~= self.invID and self:GetData("equip")) then
		return false
	end

	return true
end

ITEM.functions.Equip = {
	name = "Надеть",
	tip = "Надеть это снаряжение",
	icon = "icon16/tick.png",
	OnRun = function(item)
		local client = item.player
		local inventory = client:GetCharacter():GetInventory()
		local gear = ix.armorgear
		local slot = gear.GetStats(item).slot

		for _, other in pairs(inventory:GetItems()) do
			if (other.id ~= item.id and other.isArmorGear and gear.GetStats(other).slot == slot
			and other:GetData("equip")) then
				client:Notify("Слот занят: " .. other:GetName() .. ". Сначала снимите его.")

				return false
			end
		end

		item:SetData("equip", true)
		hook.Run("ArmorGearChanged", client)
		client:EmitSound("items/ammo_pickup.wav", 60)
		client:Notify(gear.GetSummary(client))

		return false
	end,
	OnCanRun = function(item)
		local client = item.player

		return not IsValid(item.entity)
			and IsValid(client)
			and item.invID == client:GetCharacter():GetInventory():GetID()
			and item:GetData("equip") ~= true
	end
}

ITEM.functions.Unequip = {
	name = "Снять",
	tip = "Снять это снаряжение",
	icon = "icon16/cross.png",
	OnRun = function(item)
		local client = item.player

		item:SetData("equip", false)
		hook.Run("ArmorGearChanged", client)
		client:EmitSound("items/ammo_pickup.wav", 60)
		client:Notify(ix.armorgear.GetSummary(client))

		return false
	end,
	OnCanRun = function(item)
		return not IsValid(item.entity)
			and IsValid(item.player)
			and item:GetData("equip") == true
	end
}
