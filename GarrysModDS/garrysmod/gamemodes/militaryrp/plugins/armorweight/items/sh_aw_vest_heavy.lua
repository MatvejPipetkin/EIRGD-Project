ITEM.name = "Тяжёлый бронежилет"
ITEM.description = "Плитоносец с керамическими пластинами. Серьёзная защита торса ценой подвижности."
ITEM.model = "models/props_c17/BriefCase001a.mdl"
ITEM.width = 3
ITEM.height = 3
ITEM.base = "base_armorweight"

ITEM.armorStats = {
	slot = "body",         -- слот
	weight = 11,           -- вес, кг
	protection = 60,       -- бронирование, %
	blast = 20,            -- взрывоустойчивость, %
	ergonomics = -8,       -- эргономика, % к скорости
	coverage = {"torso"},  -- грудь и живот
	durability = 150,      -- макс. прочность (если не писать — берётся общая, по умолчанию 100)
}
