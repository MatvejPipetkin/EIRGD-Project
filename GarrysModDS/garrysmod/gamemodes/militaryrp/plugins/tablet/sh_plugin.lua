local PLUGIN = PLUGIN

PLUGIN.name = "Служебный планшет"
PLUGIN.author = "-"
PLUGIN.description = "Служебный планшет для фракций: логин/пароль, состав, звания, выговоры, записки и карта."

ix.tablet = ix.tablet or {}

-- Клавиша открытия планшета (английская M). Нужен предмет "tablet" в инвентаре.
ix.tablet.key = KEY_M

-- RP-описание устройства. Показывается на экране входа и во вкладке «Профиль → Устройство».
ix.tablet.description = "Именной служебный планшет, выданный при зачислении в состав. "
	.. "Закреплён за одним бойцом и привязан к его личной учётной записи: войти с другого устройства нельзя. "
	.. "Доступ — только по логину и паролю владельца. "
	.. "Передача планшета посторонним запрещена, о потере немедленно докладывать командованию."

-- Типы меток на карте (порядок важен — на него завязаны иконки в интерфейсе).
ix.tablet.markerKinds = {"Цель", "Опасность", "Сбор", "База", "Заметка"}

-- Ранги SAM, которым доступно управление составом (повышение/понижение/выговоры).
ix.tablet.commandGroups = {
	["deputy"] = true,
	["commander"] = true,
	["superadmin"] = true
}
--
ix.tablet.payInterval = 300 -- секунды между выплатами (поставьте то же, что у вас в настройке salaryInterval)

-- ----- Значки званий -----
-- Для каждого звания в таблице icons (в том же порядке, что и ranks) задаётся значок,
-- который рисуется в клиенте кодом (картинки не нужны). Типы значков:
--   {type = "dot"}                          - точка (рядовой без знаков различия)
--   {type = "bar", n = 1}                   - n горизонтальных полосок (лычки)
--   {type = "chev", n = 2}                  - n нашивок-шевронов; bar = true добавляет планку снизу
--   {type = "pogon", stars = 2, gaps = 1}   - погон со звёздами (1-4); gaps: 1 - простой (младшие офицеры),
--                                              2 - с двумя линиями (старшие), 0 - залитый с крупными звёздами (генералы, 1-4)
--                                              stripe = true - погон прапорщика (поперечная планка и 1-2 звезды)
--   {type = "star5", ring = true}           - большая пятиконечная звезда; ring = true обводит её кольцом (маршал)
--   {type = "ring"}                         - кольцо
--   {type = "cross"}                        - скрещённые ножи (X)
--   {type = "arrow"}                        - стрела / торпеда
--   {type = "diamond", inner = true}        - ромб; inner = true добавляет вложенный ромб
--   {type = "star8", ring = true}           - восьмиконечная звезда; ring = true обвЫодит её кольцом
--   {type = "crown"}                        - корона
-- Если для звания значок не задан, в клиенте рисуются обычные шевроны.

-- Общая "армейская" лестница на 22 звания: рядовой, сержантско-старшинский, прапорщики и офицерский состав.
local ARMY_RANKS = {
	"Рядовой", "Ефрейтор", "Старший ефрейтор",                                -- 1-3   рядовой состав
	"Младший сержант", "Сержант", "Старший сержант", "Старшина", "Главный сержант", -- 4-8 сержантско-старшинский состав
	"Прапорщик", "Старший прапорщик",                                         -- 9-10  прапорщики
	"Младший лейтенант", "Лейтенант", "Старший лейтенант", "Капитан",        -- 11-14 младшие офицеры
	"Майор", "Подполковник", "Полковник",                                     -- 15-17 старшие офицеры
	"Генерал-майор", "Генерал-лейтенант", "Генерал-полковник", "Генерал армии", "Маршал" -- 18-22 высшие офицеры
}

local ARMY_ICONS = {
	{type = "dot"},                                -- 1  Рядовой
	{type = "bar", n = 1},                         -- 2  Ефрейтор
	{type = "bar", n = 2},                         -- 3  Старший ефрейтор
	{type = "chev", n = 1},                        -- 4  Младший сержант
	{type = "chev", n = 2},                        -- 5  Сержант
	{type = "chev", n = 3},                        -- 6  Старший сержант
	{type = "chev", n = 3, bar = true},            -- 7  Старшина
	{type = "chev", n = 4},                        -- 8  Главный сержант
	{type = "pogon", stars = 1, gaps = 1, stripe = true}, -- 9  Прапорщик
	{type = "pogon", stars = 2, gaps = 1, stripe = true}, -- 10 Старший прапорщик
	{type = "pogon", stars = 1, gaps = 1},         -- 11 Младший лейтенант
	{type = "pogon", stars = 2, gaps = 1},         -- 12 Лейтенант
	{type = "pogon", stars = 3, gaps = 1},         -- 13 Старший лейтенант
	{type = "pogon", stars = 4, gaps = 1},         -- 14 Капитан
	{type = "pogon", stars = 1, gaps = 2},         -- 15 Майор
	{type = "pogon", stars = 2, gaps = 2},         -- 16 Подполковник
	{type = "pogon", stars = 3, gaps = 2},         -- 17 Полковник
	{type = "pogon", stars = 1, gaps = 0},         -- 18 Генерал-майор
	{type = "pogon", stars = 2, gaps = 0},         -- 19 Генерал-лейтенант
	{type = "pogon", stars = 3, gaps = 0},         -- 20 Генерал-полковник
	{type = "pogon", stars = 4, gaps = 0},         -- 21 Генерал армии
	{type = "star5", ring = true}                  -- 22 Маршал
}

-- Зарплата за одну выплату. Индекс = номер звания (тот же порядок, что в ARMY_RANKS).
local ARMY_PAY = {
	50, 55, 60,                              -- 1-3   рядовой состав
	70, 80, 90, 100, 110,                    -- 4-8   сержантско-старшинский состав
	120, 135,                                -- 9-10  прапорщики
	150, 165, 180, 200,                      -- 11-14 младшие офицеры
	230, 260, 290,                           -- 15-17 старшие офицеры
	330, 370, 420, 480, 550                  -- 18-22 высшие офицеры
}

-- ----- Перенос номеров званий (армейская лестница выросла с 15 до 22) -----
-- В базе у бойцов хранится НОМЕР звания, а новые звания вставлены в середину лестницы.
-- Чтобы никого не понизило, при первом запуске номера один раз переносятся по этой таблице:
-- индекс = старый номер, значение = новый номер. Сработает один раз (метка хранится в базе планшета).
-- Если вы потом снова меняете лестницу — задайте новую метку в rankLadder и новую таблицу переноса.
ix.tablet.rankLadder = "army22"

local ARMY_MIGRATION = {1, 2, 4, 5, 6, 7, 11, 12, 13, 14, 15, 16, 17, 18, 19}

ix.tablet.rankMigration = {
	["fvur"] = ARMY_MIGRATION,
	["eir_republic"] = ARMY_MIGRATION
}

-- Ключ = uniqueID фракции (имя файла без "sh_"): sh_fvur.lua -> "fvur".
-- Звания идут от младшего (1) к старшему. ПЕРЕИМЕНУЙТЕ под ваш сервер.
-- ВАЖНО: в базе у бойцов хранится НОМЕР звания, поэтому после смены списка
-- уже существующие бойцы сохранят свой номер (бывшая «Сержант» = 3 станет «Младший сержант»).
-- При необходимости поправьте через /TabletSetRank.
ix.tablet.factions = {
	["fvur"] = {
		ranks = table.Copy(ARMY_RANKS),
		icons = table.Copy(ARMY_ICONS),
		pay = table.Copy(ARMY_PAY)
	},
	["opg"] = {
		-- 8 званий, у ОПГ свой набор значков (не армейский).
		ranks = {"Шестёрка", "Боец", "Торпеда", "Бригадир", "Решала", "Авторитет", "Смотрящий", "Пахан"},
		icons = {
			{type = "ring"},                          -- Шестёрка
			{type = "cross"},                         -- Боец
			{type = "arrow"},                         -- Торпеда
			{type = "diamond"},                       -- Бригадир
			{type = "diamond", inner = true},         -- Решала
			{type = "star8"},                         -- Авторитет
			{type = "star8", ring = true},            -- Смотрящий
			{type = "crown"}                          -- Пахан
		},
		-- Зарплата ОПГ ниже армейской (8 значений — по одному на каждое звание).
		pay = {20, 25, 30, 35, 40, 50, 60, 70}
	},
	["eir_republic"] = {
		ranks = table.Copy(ARMY_RANKS),
		icons = table.Copy(ARMY_ICONS),
		pay = table.Copy(ARMY_PAY)
	}
}

-- Карты. Картинка — вид сверху (север = верх изображения, т.е. +Y мира).
-- Положите файл в materials/tablet/maps/<карта>.png
-- mins/maxs — мировые координаты {x, y} левого-нижнего и правого-верхнего углов картинки.
-- Они посчитаны по двум известным точкам (макушка маяка и мост), масштаб около 23.96 ед. на пиксель.
-- Если mins/maxs убрать, границы возьмутся из размеров мира (game.GetWorld()), но у этой карты
-- картинка покрывает мир иначе, и маркеры уезжают.
ix.tablet.maps = {
	["rp_eirgd_map"] = {
		material = "tablet/maps/map.png",
		mins = {-15533, -12133},   -- левый нижний угол картинки (x, y)
		maxs = {15542, 13718}      -- правый верхний угол картинки (x, y)
	}
}

function ix.tablet.IsCommand(client)
	local group = client.sam_getrank and client:sam_getrank() or client:GetUserGroup()

	return ix.tablet.commandGroups[string.lower(tostring(group or ""))] == true
end

ix.command.Add("TabletIssue", {
	description = "Выдать персонажу новый именной планшет (старый перестанет работать).",
	adminOnly = true,
	arguments = ix.type.character,
	OnRun = function(self, client, target)
		local ok, err = PLUGIN:IssueTablet(target)

		if (ok) then
			return "Планшет выдан: " .. target:GetName() .. "."
		end

		return "Не удалось выдать планшет: " .. tostring(err or "нет места в инвентаре") .. "."
	end
})

-- ----- Админские команды: боец ищется по нику (можно часть ника, регистр не важен). -----
-- Ник идёт последним аргументом, поэтому кавычки при пробелах не нужны.

ix.command.Add("TabletResetAccount", {
	description = "Удалить аккаунт планшета (логин и пароль) у бойца по нику. Использование: /TabletResetAccount <ник>",
	adminOnly = true,
	arguments = ix.type.text,
	OnRun = function(self, client, name)
		local id, entry, err = PLUGIN:FindRosterByName(name, client)

		if (!id) then return err end

		local _, msg = PLUGIN:AdminResetAccount(client, id, entry)

		return msg
	end
})

ix.command.Add("TabletRemove", {
	description = "ПОЛНОСТЬЮ удалить бойца из планшета: аккаунт, звание, выговоры, поощрения, сообщения и записки. Использование: /TabletRemove <ник>",
	adminOnly = true,
	arguments = ix.type.text,
	OnRun = function(self, client, name)
		local id, entry, err = PLUGIN:FindRosterByName(name, client)

		if (!id) then return err end

		local _, msg = PLUGIN:AdminRemove(client, id, entry)

		return msg
	end
})

ix.command.Add("TabletRestore", {
	description = "Вернуть исключённого бойца в состав планшета (начнёт со звания 1). Использование: /TabletRestore <ник персонажа на сервере>",
	adminOnly = true,
	arguments = ix.type.character,
	OnRun = function(self, client, target)
		local _, msg = PLUGIN:AdminRestore(client, target)

		return msg
	end
})

ix.command.Add("TabletSetRank", {
	description = "Установить звание бойцу (номером или названием). Использование: /TabletSetRank <звание> <ник>",
	adminOnly = true,
	arguments = {ix.type.string, ix.type.text},
	OnRun = function(self, client, rank, name)
		local id, entry, err = PLUGIN:FindRosterByName(name, client)

		if (!id) then return err end

		local _, msg = PLUGIN:AdminSetRank(client, id, entry, rank)

		return msg
	end
})

local CLEAR_KINDS = {
	rep = "rep", reprimands = "rep", ["выговоры"] = "rep", ["выговор"] = "rep",
	com = "com", commends = "com", ["поощрения"] = "com", ["поощрение"] = "com",
	all = "all", ["все"] = "all"
}

ix.command.Add("TabletClearRecords", {
	description = "Очистить записи бойца: rep (выговоры), com (поощрения) или all. Использование: /TabletClearRecords <rep|com|all> <ник>",
	adminOnly = true,
	arguments = {ix.type.string, ix.type.text},
	OnRun = function(self, client, kind, name)
		local mode = CLEAR_KINDS[string.lower(kind)]

		if (!mode) then
			return "Укажите, что очистить: rep (выговоры), com (поощрения) или all."
		end

		local id, entry, err = PLUGIN:FindRosterByName(name, client)

		if (!id) then return err end

		local _, msg = PLUGIN:AdminClearRecords(client, id, entry, mode)

		return msg
	end
})

ix.command.Add("TabletInfo", {
	description = "Показать данные бойца в планшете: звание, аккаунт, устройство, записи. Использование: /TabletInfo <ник>",
	adminOnly = true,
	arguments = ix.type.text,
	OnRun = function(self, client, name)
		local id, entry, err = PLUGIN:FindRosterByName(name, client)

		if (!id) then return err end

		for _, line in ipairs(PLUGIN:AdminInfoLines(id, entry)) do
			client:ChatPrint(line)
		end
	end
})

ix.util.Include("sv_tablet.lua")
ix.util.Include("sv_migrate.lua")
ix.util.Include("sv_payroll.lua")
ix.util.Include("cl_tabletnet.lua")

-- ВАЖНО: порядок загрузки плагина в Helix - libs/ -> items/ -> derma/ -> и только ПОТОМ sh_plugin.lua.
-- Поэтому библиотека интерфейса лежит в libs/cl_tabletui.lua (она должна быть готова до derma/cl_tablet.lua),
-- а панели - в derma/. Helix подключает их сам, вручную include'ить их здесь не нужно.