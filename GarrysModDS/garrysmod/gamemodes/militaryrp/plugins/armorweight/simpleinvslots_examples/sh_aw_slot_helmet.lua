-- Пример для Simple Inventory Slots.
-- Положите файл в simpleinvslots/items/slot_clothing/ — база base_slot_clothing подставится сама.
-- Надевается перетаскиванием в слот «Голова».

ITEM.name = "Тактическая каска"
ITEM.description = "Каска в слот головы."
ITEM.slot = "Head"

ITEM.armorStats = {
	weight = 1.4,          -- вес, кг
	protection = 35,       -- бронирование, %
	blast = 10,            -- взрывоустойчивость, %
	ergonomics = -1,       -- эргономика, % к скорости
	coverage = {"head"},   -- закрытые зоны
}
