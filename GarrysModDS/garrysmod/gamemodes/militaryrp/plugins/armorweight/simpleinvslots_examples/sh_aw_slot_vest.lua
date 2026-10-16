-- Пример для Simple Inventory Slots.
-- Положите файл в simpleinvslots/items/slot_clothing/ — база base_slot_clothing подставится сама.
-- Надевается перетаскиванием в слот «Торс».

ITEM.name = "Бронежилет"
ITEM.description = "Бронежилет в слот торса."
ITEM.slot = "Torso"

-- Характеристики плагина armorweight (слот здесь задаёт ITEM.slot выше, в armorStats его писать не нужно):
ITEM.armorStats = {
	weight = 9,            -- вес, кг
	protection = 50,       -- бронирование, %
	blast = 15,            -- взрывоустойчивость, %
	ergonomics = -6,       -- эргономика, % к скорости
	coverage = {"torso"},  -- закрытые зоны
	durability = 120,      -- макс. прочность (необязательно)
}

-- ITEM.maxArmor НЕ задаём (по умолчанию 0): иначе вместе с нашей бронёй будет
-- работать и стандартная броня Garry's Mod, и защита посчитается дважды.
