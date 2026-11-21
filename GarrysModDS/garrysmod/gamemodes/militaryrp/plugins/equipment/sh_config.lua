--[[
	КОНФИГ СНАРЯЖЕНИЯ

	1) slots  — список слотов тела. x / y — позиция слота в сетке панели (колонка / ряд, с единицы). Панель стоит слева.
	            icon — путь к иконке относительно папки materials (белый PNG на прозрачном фоне,
	            рекомендуется 128x128; цвет подставляется автоматически под акцент меню).
	            Порядок в списке = приоритет при наложении бодигрупп.
	2) items  — настройки предметов по их uniqueID (имя файла sh_<uniqueID>.lua).
	            slot       — id слота, в который надевается предмет (обязательно)
	            blocks     — слоты, которые предмет перекрывает (шлем-«аквариум» блокирует face)
	            armor      — сколько брони даёт (добавляется при надевании, снимается при снятии)
	            bodygroups — {["имя группы"] = значение} или {[номер] = значение}
	            wear       — модель на теле игрока:
	                         {model = "...", bonemerge = true}                              -- сращивание с костями
	                         {model = "...", bone = "ValveBiped.Bip01_Head1",
	                          pos = Vector(0, 0, 0), ang = Angle(0, 0, 0), scale = 1}       -- крепление к кости
	            weapon     — класс оружия (SWEP) для слотов оружия. Для предметов с ITEM.class и ITEM.weaponCategory
	                         слот и класс определяются сами (см. weapons.categories), вписывать их сюда не нужно;
	                         запись в items нужна только чтобы переопределить слот/класс для конкретного оружия.
	            Те же параметры можно задать прямо в файле предмета: ITEM.equipSlot, ITEM.equipBlocks,
	            ITEM.equipArmor, ITEM.equipBodygroups, ITEM.equipWear, ITEM.equipWeapon. Значения из этого конфига приоритетнее.

	Слоты оружия: в списке slots помечены weapon = true, стоят отдельным рядом под моделью персонажа.
	weight — относительная ширина слота в ряду (основное оружие шире пистолета и ножа).
]]

ix.equipment = ix.equipment or {}

ix.equipment.config = {
	title = "СНАРЯЖЕНИЕ",

	sounds = {
		equip = "npc/combine_soldier/gear3.wav",
		unequip = "npc/combine_soldier/gear5.wav"
	},

	ui = {
		gap = 6, -- расстояние между слотами (при высоте экрана 1080)
		slotSize = 110, -- размер слота (при высоте экрана 1080); уменьшается, если панель не влезает по высоте
		offsetX = 0, -- отступ панели от левого края области контента
		preview = true, -- модель персонажа между колонками слотов
		previewWidth = 240, -- ширина области с моделью (при высоте экрана 1080)
		previewZoom = 2, -- масштаб модели в предпросмотре (больше — крупнее)
		weaponHeight = 92 -- высота слотов оружия (при высоте экрана 1080)
	},

	weapons = {
		-- Оружие определяется автоматически по полям предмета (items/weapons/sh_*.lua):
		--   ITEM.weaponCategory — какая это пушка; ITEM.class — класс SWEP, который выдаётся игроку.
		-- Здесь — в какой слот попадает каждая категория. Категории, которых нет в списке
		-- (например grenade), остаются на стандартной логике base_weapons.
		categories = {
			primary = "primary",
			sidearm = "secondary",
			melee = "melee"
		},

		defaultClip = 0, -- сколько патронов в магазине, когда оружие надето впервые (0 — пустое, как в base_weapons)
		weaponTitle = "ОРУЖИЕ" -- подпись над рядом слотов оружия
	},

	slots = {
		{id = "head", name = "Голова", short = "ГОЛОВА", description = "Шлемы, каски, береты", icon = "equipment/slots/head.png", x = 1, y = 1},
		{id = "face", name = "Лицо", short = "ЛИЦО", description = "Очки, маски, балаклавы", icon = "equipment/slots/face.png", x = 2, y = 1},
		{id = "headset", name = "Гарнитура", short = "ГАРНИТУРА", description = "Наушники, рации, гарнитуры", icon = "equipment/slots/headset.png", x = 1, y = 2},
		{id = "gloves", name = "Перчатки", short = "ПЕРЧАТКИ", description = "Тактические перчатки", icon = "equipment/slots/gloves.png", x = 2, y = 2},
		{id = "backpack", name = "Рюкзак", short = "РЮКЗАК", description = "Рюкзаки и ранцы", icon = "equipment/slots/backpack.png", x = 2, y = 4},

		{id = "armor", name = "Бронежилет", short = "БРОНЯ", description = "Бронежилеты и плитоноски", icon = "equipment/slots/armor.png", x = 1, y = 3},
		{id = "uniform", name = "Форма", short = "ФОРМА", description = "Куртки и камуфляж", icon = "equipment/slots/uniform.png", x = 2, y = 3},
		{id = "rig", name = "Разгрузка", short = "РАЗГРУЗКА", description = "Разгрузочные жилеты и ремни", icon = "equipment/slots/rig.png", x = 1, y = 4},
		{id = "legs", name = "Ноги", short = "НОГИ", description = "Штаны, наколенники", icon = "equipment/slots/legs.png", x = 1, y = 5},
		{id = "feet", name = "Обувь", short = "ОБУВЬ", description = "Берцы и ботинки", icon = "equipment/slots/feet.png", x = 2, y = 5},

		-- слоты оружия (отдельный ряд под персонажем)
		{id = "primary", name = "Основное оружие", short = "ОСНОВНОЕ", description = "Автоматы, дробовики, ПП, снайперские винтовки, РПГ", icon = "equipment/slots/primary.png", weapon = true, weight = 2},
		{id = "secondary", name = "Второстепенное оружие", short = "ПИСТОЛЕТ", description = "Пистолеты и револьверы", icon = "equipment/slots/secondary.png", weapon = true, weight = 1},
		{id = "melee", name = "Холодное оружие", short = "ХОЛОДНОЕ", description = "Ножи, топоры, мачете, дубинки", icon = "equipment/slots/melee.png", weapon = true, weight = 1}
	},

	items = {
		-- ключ — uniqueID предмета (sh_<uniqueID>.lua)
		["helmet_example"] = {
			slot = "head"
			-- blocks = {"face"},
			-- armor = 10,
			-- bodygroups = {["helmet"] = 1},
			-- wear = {model = "models/props_junk/PopCan01a.mdl", bone = "ValveBiped.Bip01_Head1", pos = Vector(0, 0, 0), ang = Angle(0, 0, 0), scale = 1}
		},

		["vest_example"] = {
			slot = "armor",
			armor = 40
		},

		["boots_example"] = {
			slot = "feet"
		}
	}
}
