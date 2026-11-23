local PLUGIN = PLUGIN

--[[
	ВЕРСТАКИ
	bonus - добавка к шансу успеха (в процентах) для всех рецептов этого верстака.
	model - замените на свои модели (если модель не найдена, используется запасная).
]]
PLUGIN:RegisterWorkbench("mechanical", {
	name = "Слесарный верстак",
	description = "Металлообработка, инструменты, механизмы.",
	model = "models/props_wasteland/kitchen_counter001b.mdl",
	color = Color(255, 176, 66),
	bonus = 0
})

PLUGIN:RegisterWorkbench("electronics", {
	name = "Электронный стенд",
	description = "Платы, связь, паяльные работы.",
	model = "models/props_wasteland/controlroom_desk001b.mdl",
	color = Color(80, 200, 255),
	bonus = 5
})

PLUGIN:RegisterWorkbench("chemistry", {
	name = "Химический стол",
	description = "Реагенты, антисептики, смеси.",
	model = "models/props_lab/workspace003.mdl",
	color = Color(110, 225, 140),
	bonus = 0
})

PLUGIN:RegisterWorkbench("armory", {
	name = "Оружейный верстак",
	description = "Бронеэлементы и снаряжение. Требует опыта.",
	model = "models/props_c17/FurnitureTable002a.mdl",
	color = Color(235, 95, 95),
	bonus = -5
})

PLUGIN:RegisterWorkbench("medical", {
	name = "Медицинский стол",
	description = "Перевязочные материалы, шины, аптечки, хирургия.",
	model = "models/props_c17/FurnitureTable001a.mdl",
	color = Color(150, 170, 255),
	bonus = 5
})

--[[
	РЕЦЕПТЫ
	bench        - ID верстака
	result       - {uniqueID предмета = количество}
	ingredients  - {uniqueID материала = количество} (расходуются)
	tools        - {"uniqueID", ...} (нужны в инвентаре, не расходуются)
	time         - время крафта в секундах
	baseChance   - базовый шанс успеха, %
	attribScale  - сколько % шанса даёт каждая единица атрибута (по умолчанию 1)
	minLevel     - минимальное значение атрибута для рецепта
	xp           - прирост атрибута за успех (за провал вдвое меньше)
	failLoss     - доля потерянных материалов при провале (иначе берётся из конфига)
	attribute    - другой атрибут вместо "crafting" (по необязательному желанию)
	factions     - {FACTION_X, ...} ограничение по фракциям
	canCraft     - function(client, char) return false, "причина" end

	ВАЖНО: в result поставьте uniqueID предметов вашей схемы (оружие, патроны, бинты и т.д.).
	Ниже - демонстрационные предметы из папки items.
]]
PLUGIN:RegisterRecipe("repair_kit", {
	name = "Ремонтный набор", category = "Инструменты", bench = "mechanical",
	description = "Компактный набор для полевого ремонта снаряжения.",
	result = {craft_repair_kit = 1},
	ingredients = {mat_scrap_metal = 3, mat_cloth = 1},
	tools = {"tool_wrench"},
	time = 6, baseChance = 55, xp = 0.2
})

PLUGIN:RegisterRecipe("lockpick", {
	name = "Набор отмычек", category = "Инструменты", bench = "mechanical",
	description = "Тонкие стальные отмычки для замков. Требует точной работы.",
	result = {craft_lockpick = 1},
	ingredients = {mat_scrap_metal = 2, mat_wire = 1},
	tools = {"tool_wrench"},
	time = 8, baseChance = 35, minLevel = 5, xp = 0.25
})

PLUGIN:RegisterRecipe("circuit", {
	name = "Печатная плата", category = "Электроника", bench = "electronics",
	description = "Базовая плата для электронных устройств.",
	result = {craft_circuit = 1},
	ingredients = {mat_electronics = 2, mat_wire = 2},
	tools = {"tool_soldering"},
	time = 7, baseChance = 50, xp = 0.2
})

PLUGIN:RegisterRecipe("radio_kit", {
	name = "Полевой радиокомплект", category = "Электроника", bench = "electronics",
	description = "Собранный на коленке, но рабочий передатчик.",
	result = {craft_radio_kit = 1},
	ingredients = {craft_circuit = 1, mat_wire = 2, mat_plastic = 1},
	tools = {"tool_soldering"},
	time = 12, baseChance = 25, minLevel = 15, xp = 0.4
})

PLUGIN:RegisterRecipe("antiseptic", {
	name = "Антисептик", category = "Реагенты", bench = "chemistry",
	description = "Раствор для обработки ран и инструментов.",
	result = {med_antiseptic = 1},
	ingredients = {mat_chemicals = 2, mat_plastic = 1},
	time = 6, baseChance = 60, xp = 0.15
})

PLUGIN:RegisterRecipe("gunpowder", {
	name = "Порох", category = "Реагенты", bench = "chemistry",
	description = "Смесь для патронов. Ошибка в пропорциях — потеря реагентов.",
	result = {mat_gunpowder = 2},
	ingredients = {mat_chemicals = 3},
	time = 10, baseChance = 30, minLevel = 10, xp = 0.3, failLoss = 0.8
})

PLUGIN:RegisterRecipe("armor_plate", {
	name = "Бронепластина", category = "Броня", bench = "armory",
	description = "Стальная пластина для бронежилета.",
	result = {craft_armor_plate = 1},
	ingredients = {mat_steel_plate = 2, mat_scrap_metal = 2, mat_cloth = 1},
	tools = {"tool_wrench"},
	time = 12, baseChance = 35, minLevel = 5, xp = 0.35
})

PLUGIN:RegisterRecipe("armor_plate_hv", {
	name = "Усиленная бронепластина", category = "Броня", bench = "armory",
	description = "Многослойная пластина с повышенной стойкостью.",
	result = {craft_armor_plate_hv = 1},
	ingredients = {craft_armor_plate = 1, mat_steel_plate = 2, craft_circuit = 1},
	tools = {"tool_wrench"},
	time = 18, baseChance = 20, minLevel = 20, xp = 0.6
})

-- ===================== МЕДИЦИНА (предметы из плагина medical) =====================

PLUGIN:RegisterRecipe("med_bandage", {
	name = "Бинт", category = "Перевязка", bench = "medical",
	description = "Стерильные бинты из чистой ткани.",
	result = {med_bandage = 2},
	ingredients = {mat_cloth = 2},
	time = 4, baseChance = 75, xp = 0.15
})

PLUGIN:RegisterRecipe("med_field_dressing", {
	name = "Перевязочный пакет", category = "Перевязка", bench = "medical",
	description = "Стерильный пакет в плёнке для остановки кровотечения.",
	result = {med_field_dressing = 1},
	ingredients = {mat_cloth = 2, mat_plastic = 1},
	time = 6, baseChance = 55, xp = 0.2
})

PLUGIN:RegisterRecipe("med_hemostatic", {
	name = "Гемостатическая повязка", category = "Перевязка", bench = "medical",
	description = "Повязка, пропитанная кровоостанавливающим составом.",
	result = {med_hemostatic = 1},
	ingredients = {mat_cloth = 2, mat_chemicals = 1},
	time = 7, baseChance = 45, minLevel = 5, xp = 0.25
})

PLUGIN:RegisterRecipe("med_tourniquet", {
	name = "Жгут", category = "Перевязка", bench = "medical",
	description = "Прочный жгут для конечностей.",
	result = {med_tourniquet = 1},
	ingredients = {mat_cloth = 1, mat_scrap_metal = 1},
	time = 5, baseChance = 60, xp = 0.2
})

PLUGIN:RegisterRecipe("med_splint", {
	name = "Шина", category = "Фиксация", bench = "medical",
	description = "Лёгкая шина для сломанной руки или ноги.",
	result = {med_splint = 1},
	ingredients = {mat_plastic = 2, mat_cloth = 1},
	time = 6, baseChance = 55, xp = 0.2
})

PLUGIN:RegisterRecipe("med_plaster_cast", {
	name = "Гипсовая повязка", category = "Фиксация", bench = "medical",
	description = "Надёжная фиксация перелома. Требует аккуратности.",
	result = {med_plaster_cast = 1},
	ingredients = {mat_chemicals = 2, mat_cloth = 2},
	time = 9, baseChance = 40, minLevel = 8, xp = 0.3
})

PLUGIN:RegisterRecipe("med_suture_kit", {
	name = "Набор для швов", category = "Хирургия", bench = "medical",
	description = "Иглы, нить и зажимы.",
	result = {med_suture_kit = 1},
	ingredients = {mat_scrap_metal = 2, mat_wire = 1, mat_cloth = 1},
	time = 10, baseChance = 30, minLevel = 12, xp = 0.35
})

PLUGIN:RegisterRecipe("med_medkit", {
	name = "Аптечка", category = "Хирургия", bench = "medical",
	description = "Собранная из готовых средств полевая аптечка.",
	result = {med_medkit = 1},
	ingredients = {med_bandage = 1, med_antiseptic = 1, med_painkiller = 1},
	time = 10, baseChance = 35, minLevel = 10, xp = 0.35
})

PLUGIN:RegisterRecipe("med_surgeon_kit", {
	name = "Хирургический набор", category = "Хирургия", bench = "medical",
	description = "Полевая операционная в ящике. Очень сложная сборка.",
	result = {med_surgeon_kit = 1},
	ingredients = {med_suture_kit = 1, med_antiseptic = 1, mat_steel_plate = 1, mat_cloth = 2},
	time = 20, baseChance = 15, minLevel = 25, xp = 0.7, failLoss = 0.7
})

PLUGIN:RegisterRecipe("med_painkiller", {
	name = "Обезболивающее", category = "Препараты", bench = "chemistry",
	description = "Таблетки для приглушения боли.",
	result = {med_painkiller = 1},
	ingredients = {mat_chemicals = 2, mat_plastic = 1},
	time = 6, baseChance = 45, minLevel = 5, xp = 0.2
})

PLUGIN:RegisterRecipe("med_antipyretic", {
	name = "Жаропонижающее", category = "Препараты", bench = "chemistry",
	description = "Средство от простуды и жара.",
	result = {med_antipyretic = 1},
	ingredients = {mat_chemicals = 2, mat_plastic = 1},
	time = 6, baseChance = 45, minLevel = 5, xp = 0.2
})

PLUGIN:RegisterRecipe("med_rehydration", {
	name = "Регидрон", category = "Препараты", bench = "chemistry",
	description = "Солевой раствор для восстановления водного баланса.",
	result = {med_rehydration = 1},
	ingredients = {mat_chemicals = 1, mat_plastic = 1},
	time = 5, baseChance = 55, xp = 0.15
})

PLUGIN:RegisterRecipe("med_burn_gel", {
	name = "Противоожоговый гель", category = "Препараты", bench = "chemistry",
	description = "Охлаждающий гель для ожогов.",
	result = {med_burn_gel = 1},
	ingredients = {mat_chemicals = 2, mat_plastic = 1},
	time = 7, baseChance = 45, minLevel = 8, xp = 0.25
})

PLUGIN:RegisterRecipe("med_ointment", {
	name = "Заживляющая мазь", category = "Препараты", bench = "chemistry",
	description = "Мазь для ускорения заживления тканей.",
	result = {med_ointment = 1},
	ingredients = {mat_chemicals = 2, mat_cloth = 1},
	time = 7, baseChance = 45, minLevel = 5, xp = 0.2
})

PLUGIN:RegisterRecipe("med_ammonia", {
	name = "Нашатырный спирт", category = "Препараты", bench = "chemistry",
	description = "Приводит в чувство.",
	result = {med_ammonia = 1},
	ingredients = {mat_chemicals = 1, mat_plastic = 1},
	time = 5, baseChance = 60, xp = 0.15
})

PLUGIN:RegisterRecipe("med_vitamins", {
	name = "Витаминный комплекс", category = "Препараты", bench = "chemistry",
	description = "Укрепляет иммунитет.",
	result = {med_vitamins = 1},
	ingredients = {mat_chemicals = 2, mat_plastic = 1},
	time = 6, baseChance = 50, minLevel = 3, xp = 0.15
})

PLUGIN:RegisterRecipe("med_antibiotic", {
	name = "Антибиотик", category = "Сильнодействующие", bench = "chemistry",
	description = "Против заражения ран и инфекций. Нужна точность в дозировке.",
	result = {med_antibiotic = 1},
	ingredients = {mat_chemicals = 3, mat_plastic = 1},
	time = 12, baseChance = 25, minLevel = 15, xp = 0.4, failLoss = 0.7
})

PLUGIN:RegisterRecipe("med_antiviral", {
	name = "Противовирусное", category = "Сильнодействующие", bench = "chemistry",
	description = "Лечит грипп.",
	result = {med_antiviral = 1},
	ingredients = {mat_chemicals = 3, mat_plastic = 1},
	time = 12, baseChance = 25, minLevel = 18, xp = 0.4, failLoss = 0.7
})

PLUGIN:RegisterRecipe("med_adrenaline", {
	name = "Адреналин", category = "Сильнодействующие", bench = "chemistry",
	description = "Встряхивает организм. Очень сложный синтез.",
	result = {med_adrenaline = 1},
	ingredients = {mat_chemicals = 3, mat_plastic = 1, mat_electronics = 1},
	time = 14, baseChance = 18, minLevel = 22, xp = 0.6, failLoss = 0.8
})

PLUGIN:RegisterRecipe("med_morphine", {
	name = "Морфин", category = "Сильнодействующие", bench = "chemistry",
	description = "Сильное обезболивающее. Очень сложный синтез.",
	result = {med_morphine = 1},
	ingredients = {mat_chemicals = 4, mat_plastic = 1},
	time = 15, baseChance = 15, minLevel = 25, xp = 0.7, failLoss = 0.8
})
