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

-- Ключ = uniqueID фракции (имя файла без "sh_"): sh_fvur.lua -> "fvur".
-- Звания идут от младшего (1) к старшему. ПЕРЕИМЕНУЙТЕ под ваш сервер.
ix.tablet.factions = {
	["fvur"] = {
		ranks = {"Боец", "Ефрейтор", "Сержант", "Лейтенант", "Капитан", "Майор"}
	},
	["opg"] = {
		ranks = {"Шестёрка", "Боец", "Бригадир", "Авторитет", "Смотрящий"}
	},
	["eir_republic"] = {
		ranks = {"Рядовой", "Ефрейтор", "Сержант", "Лейтенант", "Капитан", "Майор"}
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