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

-- ----- Значки званий -----
-- Для каждого звания в таблице icons (в том же порядке, что и ranks) задаётся значок,
-- который рисуется в клиенте кодом (картинки не нужны). Типы значков:
--   {type = "dot"}                          - точка (рядовой без знаков различия)
--   {type = "bar", n = 1}                   - n горизонтальных полосок (лычки)
--   {type = "chev", n = 2}                  - n нашивок-шевронов; bar = true добавляет планку снизу
--   {type = "pogon", stars = 2, gaps = 1}   - погон со звёздами (1-4); gaps: 1 - простой (младшие офицеры),
--                                              2 - с двумя линиями (старшие), 0 - залитый с крупными звёздами (генералы)
--   {type = "ring"}                         - кольцо
--   {type = "cross"}                        - скрещённые ножи (X)
--   {type = "arrow"}                        - стрела / торпеда
--   {type = "diamond", inner = true}        - ромб; inner = true добавляет вложенный ромб
--   {type = "star8", ring = true}           - восьмиконечная звезда; ring = true обвЫодит её кольцом
--   {type = "crown"}                        - корона
-- Если для звания значок не задан, в клиенте рисуются обычные шевроны.

-- Общая "армейская" лестница на 15 званий: рядовой, сержантско-старшинский и офицерский состав.
local ARMY_RANKS = {
	"Рядовой", "Ефрейтор",                                                    -- 1-2   рядовой состав
	"Младший сержант", "Сержант", "Старший сержант", "Старшина",              -- 3-6   сержантско-старшинский состав
	"Младший лейтенант", "Лейтенант", "Старший лейтенант", "Капитан",        -- 7-10  младшие офицеры
	"Майор", "Подполковник", "Полковник",                                     -- 11-13 старшие офицеры
	"Генерал-майор", "Генерал-лейтенант"                                      -- 14-15 высшие офицеры
}

local ARMY_ICONS = {
	{type = "dot"},                                -- Рядовой
	{type = "bar", n = 1},                         -- Ефрейтор
	{type = "chev", n = 1},                        -- Младший сержант
	{type = "chev", n = 2},                        -- Сержант
	{type = "chev", n = 3},                        -- Старший сержант
	{type = "chev", n = 3, bar = true},            -- Старшина
	{type = "pogon", stars = 1, gaps = 1},         -- Младший лейтенант
	{type = "pogon", stars = 2, gaps = 1},         -- Лейтенант
	{type = "pogon", stars = 3, gaps = 1},         -- Старший лейтенант
	{type = "pogon", stars = 4, gaps = 1},         -- Капитан
	{type = "pogon", stars = 1, gaps = 2},         -- Майор
	{type = "pogon", stars = 2, gaps = 2},         -- Подполковник
	{type = "pogon", stars = 3, gaps = 2},         -- Полковник
	{type = "pogon", stars = 1, gaps = 0},         -- Генерал-майор
	{type = "pogon", stars = 2, gaps = 0}          -- Генерал-лейтенант
}

-- Ключ = uniqueID фракции (имя файла без "sh_"): sh_fvur.lua -> "fvur".
-- Звания идут от младшего (1) к старшему. ПЕРЕИМЕНУЙТЕ под ваш сервер.
-- ВАЖНО: в базе у бойцов хранится НОМЕР звания, поэтому после смены списка
-- уже существующие бойцы сохранят свой номер (бывшая «Сержант» = 3 станет «Младший сержант»).
-- При необходимости поправьте через /TabletSetRank.
ix.tablet.factions = {
	["fvur"] = {
		ranks = table.Copy(ARMY_RANKS),
		icons = table.Copy(ARMY_ICONS)
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
		}
	},
	["eir_republic"] = {
		ranks = table.Copy(ARMY_RANKS),
		icons = table.Copy(ARMY_ICONS)
	}
}

-- Карты. Картинка — вид сверху (север = верх изображения, т.е. +Y мира).
-- mins/maxs — мировые координаты {x, y} левого-нижнего и правого-верхнего углов картинки.
-- Положите файл в materials/tablet/maps/<карта>.png
ix.tablet.maps = {
	-- ["gm_construct"] = {
	-- 	material = "tablet/maps/gm_construct.png",
	-- 	mins = {-8192, -8192},
	-- 	maxs = {8192, 8192}
	-- },
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
ix.util.Include("cl_tabletnet.lua")