--[[
	СПИСОК ПРОПОВ-КОНТЕЙНЕРОВ

	Полная форма (ix.container.Register):

		ix.container.Register("models/props_c17/lockers001a.mdl", {
			name = "Locker",                  -- название
			description = "Белый металлический шкафчик.",  -- описание в подсказке
			width = 3,                        -- размер инвентаря
			height = 5,
			interaction = "cabinet",          -- тип действия: cabinet / drawer / shelf / small (см. sh_config.lua)

			-- ВСЁ НИЖЕ - НЕОБЯЗАТЕЛЬНО, переопределяет настройки типа для этого пропа:
			time = 2,                         -- сколько секунд открывается
			material = "wood",                -- набор звуков: metal / wood / cardboard / plastic
			sounds = {open = "my/sound.wav", close = false}, -- свои звуки (false - тишина)
			animation = {open = "Open", close = "Close"},    -- sequence модели (если они у неё есть)
			OnOpen = function(entity, client) end,           -- коллбэки
			OnClose = function(entity, client) end
		})

	Ниже для краткости используются 4 короткие функции - по одной на тип действия:

		Cabinet(модель, название, описание, ширина, высота [, переопределения])
		Drawer (...)
		Shelf  (...)
		Small  (...)

	Чтобы добавить свой проп, допишите строку в нужный раздел. Если модели нет на
	сервере (не смонтирован контент), в консоли при старте появится предупреждение.
]]--

local function Add(interaction)
	return function(model, name, description, width, height, extra)
		local data = extra or {}

		data.interaction = interaction
		data.name = name
		data.description = description
		data.width = width
		data.height = height

		ix.container.Register(model, data)
	end
end

local Cabinet = Add("cabinet")
local Drawer = Add("drawer")
local Shelf = Add("shelf")
local Small = Add("small")

-- =====================================================================
-- ШКАФЫ - открываются дверцей
-- =====================================================================

Cabinet("models/props_c17/lockers001a.mdl", "Locker", "Белый металлический шкафчик.", 3, 5)

Cabinet("models/props_wasteland/controlroom_storagecloset001a.mdl", "Metal Cabinet", "Зелёный металлический шкаф.", 4, 5)
Cabinet("models/props_wasteland/controlroom_storagecloset001b.mdl", "Metal Cabinet", "Зелёный металлический шкаф.", 4, 5)

Cabinet("models/props_c17/furniturecupboard001a.mdl", "Cupboard", "Высокий деревянный буфет.", 4, 5, {material = "wood"})

Cabinet("models/props_c17/furniturefridge001a.mdl", "Refrigerator", "Металлический короб для хранения еды.", 2, 3)
Cabinet("models/props_wasteland/kitchen_fridge001a.mdl", "Large Refrigerator", "Большой металлический короб, в который влезет ещё больше еды.", 4, 5, {
	time = 1.9
})
Cabinet("models/props_c17/display_cooler01a.mdl", "Display Cooler", "Торговый холодильник со стеклянной дверцей.", 4, 4)

Cabinet("models/props_c17/furniturestove001a.mdl", "Stove", "Старая плита с духовкой.", 3, 2)
Cabinet("models/props_wasteland/kitchen_stove001a.mdl", "Kitchen Stove", "Ржавая кухонная плита с духовкой.", 3, 2)
Cabinet("models/props_wasteland/kitchen_stove002a.mdl", "Kitchen Stove", "Ржавая кухонная плита с духовкой.", 3, 2)

Cabinet("models/props_c17/furniturewashingmachine001a.mdl", "Washing Machine", "Обычная бытовая стиральная машина.", 3, 3)
Cabinet("models/props_wasteland/laundry_washer001a.mdl", "Industrial Washer", "Большая стиральная машина с круглой дверцей.", 4, 3)
Cabinet("models/props_wasteland/laundry_washer003.mdl", "Industrial Washer", "Большая стиральная машина с круглой дверцей.", 4, 3)
Cabinet("models/props_wasteland/laundry_dryer001.mdl", "Dryer", "Сушильная машина для белья.", 3, 3)
Cabinet("models/props_wasteland/laundry_dryer002.mdl", "Dryer", "Сушильная машина для белья.", 3, 3)

Cabinet("models/props_wasteland/kitchen_counter001a.mdl", "Kitchen Counter", "Столешница со шкафчиками внизу.", 4, 3, {material = "wood"})
Cabinet("models/props_wasteland/kitchen_counter001b.mdl", "Kitchen Counter", "Столешница со шкафчиками внизу.", 4, 3, {material = "wood"})
Cabinet("models/props_wasteland/kitchen_counter001c.mdl", "Kitchen Counter", "Столешница со шкафчиками внизу.", 4, 3, {material = "wood"})
Cabinet("models/props_wasteland/kitchen_counter001d.mdl", "Kitchen Counter", "Столешница со шкафчиками внизу.", 4, 3, {material = "wood"})

-- =====================================================================
-- ЯЩИКИ - выдвигаются
-- =====================================================================

Drawer("models/props_c17/furnituredresser001a.mdl", "Dresser", "Деревянный комод с несколькими ящиками.", 4, 4)
Drawer("models/props_c17/furnituredrawer001a.mdl", "Chest of Drawers", "Высокий комод.", 3, 4)
Drawer("models/props_c17/furnituredrawer002a.mdl", "Small Chest of Drawers", "Небольшой комод.", 3, 2)
Drawer("models/props_c17/furnituredrawer003a.mdl", "Bedside Drawers", "Маленькая тумба с ящиками.", 3, 2)

Drawer("models/props_wasteland/controlroom_filecabinet001a.mdl", "File Cabinet", "Металлическая картотека.", 5, 3, {material = "metal"})
Drawer("models/props_wasteland/controlroom_filecabinet002a.mdl", "File Cabinet", "Металлическая картотека.", 3, 6, {material = "metal"})
Drawer("models/props_lab/filecabinet02.mdl", "File Cabinet", "Металлическая картотека.", 5, 3, {material = "metal"})
Drawer("models/props_lab/partsbin01.mdl", "Parts Bin", "Ящик с маленькими отделениями для деталей.", 4, 3, {material = "metal", time = 1})

Drawer("models/props_interiors/furniture_desk01a.mdl", "Desk", "Письменный стол с ящиками.", 4, 2)
Drawer("models/props_interiors/furniture_vanity01a.mdl", "Vanity", "Туалетный столик с ящиком.", 3, 2)

-- =====================================================================
-- СТЕЛЛАЖИ - предметы берутся с открытых полок
-- =====================================================================

Shelf("models/props_c17/furnitureshelf001a.mdl", "Shelf", "Деревянная полка.", 4, 3)
Shelf("models/props_c17/furnitureshelf001b.mdl", "Shelf", "Деревянная полка.", 4, 3)
Shelf("models/props_c17/furnitureshelf002a.mdl", "Small Shelf", "Небольшая настенная полка.", 3, 2)
Shelf("models/props_c17/shelfunit01a.mdl", "Shelving Unit", "Металлический стеллаж.", 6, 4)

Shelf("models/props_wasteland/kitchen_shelf001a.mdl", "Kitchen Shelf", "Открытая полка для кухонной утвари.", 4, 3)
Shelf("models/props_wasteland/kitchen_shelf002a.mdl", "Kitchen Shelf", "Открытая полка для кухонной утвари.", 4, 3)
Shelf("models/props_wasteland/prison_shelf002a.mdl", "Prison Shelf", "Голая металлическая полка.", 3, 3)

Shelf("models/props_interiors/furniture_shelf01a.mdl", "Bookshelf", "Полка, заставленная пыльными книгами.", 4, 4)

-- =====================================================================
-- НЕБОЛЬШИЕ КОНТЕЙНЕРЫ - крышка, клапан, замок
-- =====================================================================

-- ящики
Small("models/props_junk/wood_crate001a.mdl", "Crate", "Простой деревянный ящик.", 4, 4, {material = "wood"})
Small("models/props_junk/wood_crate001a_damagedmax.mdl", "Damaged Crate", "Сломанный деревянный ящик.", 3, 3, {material = "wood"})
Small("models/props_junk/wood_crate002a.mdl", "Small Crate", "Небольшой деревянный ящик.", 3, 3, {material = "wood"})
Small("models/props_junk/plasticcrate01a.mdl", "Plastic Crate", "Пластиковый ящик.", 3, 3, {material = "plastic"})
Small("models/Items/item_item_crate.mdl", "Item Crate", "Ящик для хранения личных вещей.", 5, 3, {material = "wood"})
Small("models/props_forest/footlocker01_closed.mdl", "Footlocker", "Небольшой сундук для хранения вещей.", 5, 3, {material = "wood"})

-- ящики для боеприпасов: у моделей есть анимации Open/Close
local ammoAnimation = {open = "Open", close = "Close"}
local ammoSounds = {open = "items/ammocrate_open.wav", close = "items/ammocrate_close.wav"}

Small("models/items/ammocrate_smg1.mdl", "Ammo Crate", "Тяжёлый ящик для хранения боеприпасов.", 5, 3, {
	material = "metal", animation = ammoAnimation, sounds = ammoSounds
})
Small("models/items/ammocrate_ar2.mdl", "AR2 Ammo Crate", "Тяжёлый ящик для хранения боеприпасов.", 5, 3, {
	material = "metal", animation = ammoAnimation, sounds = ammoSounds
})
Small("models/items/ammocrate_grenade.mdl", "Grenade Crate", "Тяжёлый ящик для хранения гранат.", 4, 3, {
	material = "metal", animation = ammoAnimation, sounds = ammoSounds
})
Small("models/items/ammocrate_rockets.mdl", "Rocket Crate", "Тяжёлый ящик для хранения ракет.", 5, 3, {
	material = "metal", animation = ammoAnimation, sounds = ammoSounds
})

-- коробки
Small("models/props_junk/cardboard_box001a.mdl", "Cardboard Box", "Картонная коробка.", 3, 3)
Small("models/props_junk/cardboard_box001b.mdl", "Cardboard Box", "Картонная коробка.", 3, 3)
Small("models/props_junk/cardboard_box002a.mdl", "Small Cardboard Box", "Маленькая картонная коробка.", 2, 2)
Small("models/props_junk/cardboard_box003a.mdl", "Cardboard Box", "Картонная коробка.", 3, 2)
Small("models/props_junk/cardboard_box004a.mdl", "Large Cardboard Box", "Большая картонная коробка.", 4, 3)
Small("models/props_lab/box01a.mdl", "Lab Box", "Прочная коробка с крышкой.", 3, 2)

-- чемоданы
Small("models/props_c17/suitcase001a.mdl", "Suitcase", "Старый кожаный чемодан.", 3, 2)
Small("models/props_c17/suitcase_passenger_physics.mdl", "Passenger Suitcase", "Большой дорожный чемодан.", 4, 3)
Small("models/props_c17/briefcase001a.mdl", "Briefcase", "Портфель с застёжкой.", 3, 2)

-- баки, ведра, бочки
Small("models/props_junk/trashbin01a.mdl", "Trash Bin", "А что вы рассчитываете здесь найти?", 2, 2, {material = "metal"})
Small("models/props_trainstation/trashcan_indoor001a.mdl", "Trash Can", "Общественная урна.", 2, 2, {material = "metal"})
Small("models/props_junk/trashdumpster01a.mdl", "Dumpster", "Мусорный контейнер для отходов. От него исходит неприятный запах.", 6, 3, {
	material = "metal", time = 1.1
})
Small("models/props_junk/trashdumpster02.mdl", "Large Dumpster", "Большой мусорный контейнер, переполненный отходами.", 6, 4, {
	material = "metal", time = 1.2
})
Small("models/props_junk/garbage_bag001a.mdl", "Garbage Bag", "Мешок с мусором. Возможно, кто-то выбросил в него что-то полезное.", 2, 2, {material = "plastic"})
Small("models/props_junk/metalbucket01a.mdl", "Metal Bucket", "Помятое металлическое ведро.", 2, 2, {material = "metal"})
Small("models/props_junk/metalbucket02a.mdl", "Small Bucket", "Маленькое металлическое ведро.", 2, 2, {material = "metal"})
Small("models/props_c17/oildrum001.mdl", "Oil Drum", "Бочка со съёмной крышкой.", 3, 3, {material = "metal"})

-- корзины
Small("models/props_wasteland/laundry_basket001.mdl", "Laundry Basket", "Корзина для грязного белья.", 3, 3, {material = "plastic"})
Small("models/props_wasteland/laundry_cart001.mdl", "Laundry Cart", "Тележка для перевозки белья.", 4, 3, {material = "metal"})
Small("models/props_wasteland/laundry_cart002.mdl", "Laundry Cart", "Тележка для перевозки белья.", 4, 3, {material = "metal"})

-- прочее
Small("models/props_c17/cashregister01a.mdl", "Cash Register", "Касса с кнопками и выдвижным ящиком.", 2, 1, {
	material = "metal",
	sounds = {start = "buttons/button15.wav"}
})
