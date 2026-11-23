local PLUGIN = PLUGIN

PLUGIN.name = "Хакерский терминал"
PLUGIN.author = "-"
PLUGIN.description = "Особый предмет для спецклассов: взлом серверных узлов через хакерские мини-игры. "
	.. "Отключение карты планшета, глушение раций, досье на солдат противника и другие эффекты."

ix.hack = ix.hack or {}

local HACK = ix.hack

-- =====================================================================================
--  НАСТРОЙКИ
-- =====================================================================================

-- Как часто один персонаж может начать взлом (секунды). Откат начинается в момент старта,
-- поэтому прервать взлом и начать заново нельзя.
HACK.cooldown = 5 * 60

-- Пауза узла после взлома (секунды): успешно взломанный узел «восстанавливается».
HACK.nodeCooldown = 20 * 60
-- Пауза узла после проваленного взлома (сработала защита).
HACK.nodeFailCooldown = 5 * 60

-- Расстояние (в юнитах), с которого можно начать взлом, и расстояние, дальше которого сеанс обрывается.
HACK.useDistance = 140
HACK.abortDistance = 260

-- Радиус сканирования сети предметом (юниты) и пауза между сканированиями (секунды).
HACK.scanRadius = 1500
HACK.scanCooldown = 8

-- Оповещать фракцию-жертву, если взлом провален (защита узла подняла тревогу).
HACK.alertOnFail = true

-- Кто может пользоваться предметом: uniqueID классов (имя файла класса без "sh_").
-- sh_fvur_scout.lua -> "fvur_scout", sh_eir_engineer.lua -> "eir_engineer" и т.д.
HACK.classes = {
	["fvur_scout"] = true,
	["eir_engineer"] = true,
	["eir_signaller"] = true,
	["eir_spec"] = true
}

-- Дополнительно можно перечислить глобальные константы классов (CLASS_...), если так удобнее.
HACK.classGlobals = {"CLASS_FVUR_SCOUT", "CLASS_EIR_ENGINEER", "CLASS_EIR_SIGNALLER", "CLASS_EIR_SPEC"}

-- Админы могут пользоваться устройством независимо от класса (для тестов).
HACK.adminBypass = true

-- Фракции, участвующие во взломах. Ключ = uniqueID фракции, enemy = кто «жертва», если узел нейтральный.
-- Если у узла задан владелец (/HackNodeSet faction ...), жертвой всегда становится владелец.
HACK.factions = {
	["eir_republic"] = {enemy = "fvur"},
	["fvur"] = {enemy = "eir_republic"}
}

-- Сложности узлов.
HACK.difficulties = {
	{name = "НИЗКАЯ", color = Color(120, 230, 130)},
	{name = "СРЕДНЯЯ", color = Color(240, 215, 80)},
	{name = "ВЫСОКАЯ", color = Color(255, 150, 60)},
	{name = "КРАЙНЯЯ", color = Color(255, 70, 60)}
}

-- Сколько «жизней» (попыток провалить этап) даётся на взлом узла данной сложности.
HACK.lives = {5, 5, 5, 5}

-- План сеанса: по одному числу на этап = уровень мини-игры (1-4). Чем сложнее узел, тем больше этапов.
HACK.plans = {
	[1] = {1},
	[2] = {1, 2},
	[3] = {2, 2, 3},
	[4] = {3, 3, 4}
}

-- Типы узлов. durations / rewards / tiers — по сложностям 1..4.
--   tablet  - планшетная сеть: карта планшета у противника отключается (ваши 10 минут = сложность 2).
--   radio   - радиоретранслятор: рации противника перестают работать (ваши 5 минут = сложность 2).
--   archive - архив личных дел: данные о солдатах противника. Полное досье - только на КРАЙНЕЙ сложности.
--   cameras - пост видеонаблюдения: хакер на время видит контакты противника сквозь стены.
--   power   - электрощитовая: у противника не работают фонарики.
--   finance - финансовый узел: деньги переводятся взломщику.
-- models — модели для /HackNodeAdd (берётся первая; другую можно задать /HackNodeSet model <путь>).
HACK.types = {
	tablet = {
		name = "Сервер планшетной сети",
		short = "ПЛАНШЕТЫ",
		desc = "Отключает карту планшета у противника.",
		defaultDiff = 2,
		durations = {240, 600, 900, 1200},
		models = {"models/props_lab/servers.mdl"}
	},
	radio = {
		name = "Радиоретранслятор",
		short = "РАДИОСВЯЗЬ",
		desc = "Противник не может пользоваться рациями.",
		defaultDiff = 2,
		durations = {120, 300, 480, 600},
		models = {"models/props_lab/reciever_cart.mdl", "models/props_lab/reciever01a.mdl"}
	},
	archive = {
		name = "Архив личных дел",
		short = "АРХИВ",
		desc = "Данные о солдатах противника. Полное досье доступно только на крайней сложности.",
		defaultDiff = 4,
		detect = 0.6,
		models = {"models/props_silo/silo_server_d.mdl"}
	},
	cameras = {
		name = "Пост видеонаблюдения",
		short = "КАМЕРЫ",
		desc = "Контакты противника отображаются на вашем экране, даже сквозь стены.",
		defaultDiff = 3,
		durations = {60, 120, 180, 240},
		detect = 0.35,
		models = {"models/props_lab/securitybank.mdl"}
	},
	power = {
		name = "Электрощитовая",
		short = "ЭЛЕКТРОПИТАНИЕ",
		desc = "У противника отключаются фонари.",
		defaultDiff = 2,
		durations = {60, 180, 300, 420},
		models = {"models/props_c17/substation_transformer01a.mdl", "models/props_c17/substation_circuitbreaker01a.mdl"}
	},
	finance = {
		name = "Финансовый узел",
		short = "ФИНАНСЫ",
		desc = "Перехват платёжной ведомости: деньги переводятся на ваш счёт.",
		defaultDiff = 3,
		rewards = {{50, 100}, {100, 200}, {200, 350}, {350, 600}},
		detect = 0.5,
		models = {"models/props_c17/consolebox01a.mdl"}
	}
}

-- Каждый тип узла - отдельная запись во вкладке «Энтити» (Q-меню), категория «EIRGD | Сервера - хакинг».
-- Узел создаётся со сложностью по умолчанию; изменить: /HackNodeSet difficulty <1-4>.
for id, data in pairs(HACK.types) do
	list.Set("SpawnableEntities", "ix_hacknode_" .. id, {
		PrintName = data.name,
		ClassName = "ix_hacknode",
		Category = "EIRGD | Сервера - хакинг",
		AdminOnly = true,
		KeyValues = {nodetype = id}
	})
end

-- Что даёт архив на разных сложностях.
HACK.archiveTiers = {
	[1] = "численность и число бойцов в сети",
	[2] = "численность и структура по званиям",
	[3] = "имена и звания личного состава",
	[4] = "ПОЛНОЕ ДОСЬЕ: имена, звания, статус, должность, взыскания, дата зачисления"
}

-- =====================================================================================
--  ОБЩИЕ ФУНКЦИИ
-- =====================================================================================

function HACK.GetFactionID(client)
	local char = IsValid(client) and client:GetCharacter()

	if (not char) then return end

	local faction = ix.faction.indices[char:GetFaction()]

	return faction and faction.uniqueID
end

function HACK.GetClassID(client)
	local char = IsValid(client) and client:GetCharacter()

	if (not char) then return end

	local class = ix.class.list[char:GetClass()]

	return class and class.uniqueID
end

function HACK.CanUse(client)
	if (not IsValid(client)) then return false end

	local char = client:GetCharacter()

	if (not char) then return false end

	if (HACK.adminBypass and client:IsAdmin()) then return true end

	local classID = HACK.GetClassID(client)

	if (classID and HACK.classes[classID]) then return true end

	local index = char:GetClass()

	for _, name in ipairs(HACK.classGlobals) do
		if (_G[name] ~= nil and _G[name] == index) then return true end
	end

	return false
end

function HACK.FormatTime(sec)
	sec = math.max(0, math.floor((tonumber(sec) or 0) + 0.5))

	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

function HACK.Difficulty(diff)
	return HACK.difficulties[math.Clamp(math.floor(tonumber(diff) or 1), 1, #HACK.difficulties)]
end

function HACK.Duration(typeId, diff)
	local t = HACK.types[typeId]

	return t and t.durations and t.durations[math.Clamp(diff, 1, 4)] or 0
end

-- Сколько секунд осталось до следующего взлома. На сервере переопределяется в sv_hack.lua,
-- на клиенте — в cl_hack.lua.
function HACK.GetCooldownLeft()
	return 0
end

-- Фракция из текста команды: uniqueID, "" (нейтральный) или nil (ошибка).
function HACK.ResolveFaction(text)
	text = string.lower(string.Trim(tostring(text or "")))

	if (text == "" or text == "none" or text == "-" or text == "нет") then
		return ""
	end

	if (ix.faction.teams[text]) then
		return text
	end
end

-- =====================================================================================
--  КОМАНДЫ АДМИНИСТРАТОРА
-- =====================================================================================

local function TypeList()
	local out = {}

	for id in pairs(HACK.types) do
		out[#out + 1] = id
	end

	table.sort(out)

	return table.concat(out, ", ")
end

ix.command.Add("HackNodeAdd", {
	description = "Создать узел взлома там, куда вы смотрите. Использование: /HackNodeAdd <тип> [сложность 1-4] [фракция|none]",
	adminOnly = true,
	arguments = {
		ix.type.string,
		bit.bor(ix.type.number, ix.type.optional),
		bit.bor(ix.type.string, ix.type.optional)
	},
	OnRun = function(self, client, typeId, diff, faction)
		typeId = string.lower(typeId)

		if (not HACK.types[typeId]) then
			return "Неизвестный тип узла. Доступно: " .. TypeList() .. "."
		end

		local owner = HACK.ResolveFaction(faction)

		if (owner == nil) then
			return "Неизвестная фракция. Укажите uniqueID фракции (например fvur) или none."
		end

		local node = HACK.CreateNodeAtTrace(client, typeId, diff, owner)

		if (not IsValid(node)) then
			return "Не удалось создать узел."
		end

		return string.format("Узел «%s» создан (тип %s, сложность %d).", node:GetNodeName(), typeId, node:GetDifficulty())
	end
})

ix.command.Add("HackNodeRemove", {
	description = "Удалить узел взлома, на который вы смотрите.",
	adminOnly = true,
	OnRun = function(self, client)
		local node = HACK.TraceNode(client)

		if (not IsValid(node)) then
			return "Наведите прицел на узел."
		end

		local name = node:GetNodeName()

		HACK.AbortNode(node)
		node:Remove()
		PLUGIN:SaveData()

		return "Узел «" .. name .. "» удалён."
	end
})

ix.command.Add("HackNodeSet", {
	description = "Изменить узел, на который вы смотрите. Использование: /HackNodeSet <difficulty|type|faction|name|model> <значение>",
	adminOnly = true,
	arguments = {ix.type.string, ix.type.text},
	OnRun = function(self, client, key, value)
		local node = HACK.TraceNode(client)

		if (not IsValid(node)) then
			return "Наведите прицел на узел."
		end

		key = string.lower(key)
		value = string.Trim(value)

		if (key == "difficulty" or key == "diff" or key == "сложность") then
			local d = tonumber(value)

			if (not d or d < 1 or d > #HACK.difficulties) then
				return "Сложность — число от 1 до " .. #HACK.difficulties .. "."
			end

			node:SetDifficulty(math.floor(d))
		elseif (key == "type" or key == "тип") then
			value = string.lower(value)

			if (not HACK.types[value]) then
				return "Неизвестный тип. Доступно: " .. TypeList() .. "."
			end

			node:SetNodeType(value)
		elseif (key == "faction" or key == "фракция") then
			local owner = HACK.ResolveFaction(value)

			if (owner == nil) then
				return "Неизвестная фракция. Укажите uniqueID фракции или none."
			end

			node:SetOwnerFaction(owner)
		elseif (key == "name" or key == "имя") then
			if (value == "") then return "Укажите название." end

			node:SetNodeName(string.sub(value, 1, 40))
		elseif (key == "model" or key == "модель") then
			if (not util.IsValidModel(value)) then
				return "Такой модели нет на сервере."
			end

			node:SetNodeModel(value)
		else
			return "Параметр: difficulty, type, faction, name или model."
		end

		PLUGIN:SaveData()

		return "Узел «" .. node:GetNodeName() .. "» обновлён."
	end
})

ix.command.Add("HackNodeList", {
	description = "Показать все узлы взлома на карте.",
	adminOnly = true,
	OnRun = function(self, client)
		local nodes = ents.FindByClass("ix_hacknode")

		if (#nodes == 0) then
			return "Узлов нет. Создайте: /HackNodeAdd <тип> [сложность] [фракция]."
		end

		for _, node in ipairs(nodes) do
			local owner = node:GetOwnerFaction()
			local pos = node:GetPos()

			client:ChatPrint(string.format("#%d «%s» | тип %s | сложность %d | владелец %s | (%d, %d, %d)%s",
				node:EntIndex(), node:GetNodeName(), node:GetNodeType(), node:GetDifficulty(),
				owner ~= "" and owner or "нет", pos.x, pos.y, pos.z,
				node:GetCooling() and " | ВОССТАНАВЛИВАЕТСЯ" or ""))
		end
	end
})

ix.command.Add("HackResetCooldown", {
	description = "Сбросить откат взлома персонажу. Использование: /HackResetCooldown <персонаж>",
	adminOnly = true,
	arguments = ix.type.character,
	OnRun = function(self, client, target)
		target:SetData("hackNext", 0)

		local ply = target:GetPlayer()

		if (IsValid(ply)) then
			HACK.SyncPlayer(ply)
		end

		return "Откат сброшен: " .. target:GetName() .. "."
	end
})

ix.command.Add("HackClearEffects", {
	description = "Снять все активные эффекты взлома (глушение, блэкаут карты и т.д.). Использование: /HackClearEffects [фракция]",
	adminOnly = true,
	arguments = bit.bor(ix.type.string, ix.type.optional),
	OnRun = function(self, client, faction)
		local fid = HACK.ResolveFaction(faction)

		if (fid == nil) then
			return "Неизвестная фракция."
		end

		HACK.ClearEffects(fid ~= "" and fid or nil)

		return "Эффекты сняты."
	end
})

ix.util.Include("sv_games.lua")
ix.util.Include("sv_hack.lua")
ix.util.Include("cl_hack.lua")
ix.util.Include("cl_ui.lua")
ix.util.Include("cl_games.lua")
ix.util.Include("cl_terminal.lua")
