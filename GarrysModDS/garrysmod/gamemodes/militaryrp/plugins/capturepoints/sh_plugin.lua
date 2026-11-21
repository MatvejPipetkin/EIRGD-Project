local PLUGIN = PLUGIN

PLUGIN.name = "Захват точек"
PLUGIN.author = "-"
PLUGIN.description = "Точки на карте, которые фракции захватывают, удерживая зону. Владельцы точек отображаются на карте служебного планшета."

ix.capture = ix.capture or {}

-- ===================== Настройки =====================
-- Настройки лежат в конфиге сервера Helix: F1 -> Конфиг -> категория «Захват точек»
-- (нужны права на изменение конфига). Значения меняются на лету и сохраняются сами.
-- Остальной код читает их через ix.capture.config.<имя>, как раньше.

local CATEGORY = "Захват точек"

-- имя в ix.capture.config = {ключ в ix.config, значение по умолчанию, описание, min, max, знаков после запятой}
local SETTINGS = {
	-- Какие фракции могут захватывать точки: uniqueID через запятую, например "fvur, opg".
	-- Пусто - берутся фракции из ix.tablet.factions (те же, что пользуются планшетом).
	factions = {"capFactions", "", "Фракции-участники (uniqueID через запятую). Пусто - фракции планшета."},

	defaultRadius = {"capDefaultRadius", 256, "Радиус зоны новой точки (ед. Source).", 32, 4096, 0},
	defaultHeight = {"capDefaultHeight", 128, "Допустимая разница по высоте от центра новой точки (вверх и вниз).", 16, 4096, 0},

	captureTime = {"capCaptureTime", 90, "Секунд, за которые ОДИН боец захватывает точку с нуля.", 1, 3600, 0},
	extraPlayerBonus = {"capExtraBonus", 0.5, "Каждый следующий боец в зоне добавляет это к скорости (0.5 = +50%).", 0, 5, 2},
	maxSpeed = {"capMaxSpeed", 3, "Потолок множителя скорости захвата (3 = втрое быстрее).", 1, 20, 1},
	restoreTime = {"capRestoreTime", 60, "Секунд, за которые прогресс сходит со 100% до 0, если зону покинули.", 1, 3600, 0},

	allowVehicles = {"capAllowVehicles", true, "Считать ли игроков в транспорте."},
	tick = {"capTick", 1, "Как часто (сек) проверять зоны.", 0.25, 5, 2},
	alertCooldown = {"capAlertCooldown", 60, "Не чаще раза в N секунд предупреждать владельцев об атаке.", 0, 3600, 0},
	maxPoints = {"capMaxPoints", 30, "Максимум точек на карте.", 1, 255, 0},
	maxNameLength = {"capMaxNameLength", 32, "Максимальная длина названия точки.", 4, 64, 0}
}

local KEYS = {}

for name, def in pairs(SETTINGS) do
	local data = {category = CATEGORY}

	if (isnumber(def[2])) then
		data.data = {min = def[4], max = def[5], decimals = def[6]}
	end

	KEYS[name] = def[1]
	ix.config.Add(def[1], def[2], def[3], nil, data)
end

ix.capture.config = setmetatable({}, {
	__index = function(_, name)
		-- Фракции: строка из конфига -> список uniqueID (nil, если пусто).
		if (name == "factions") then
			local list = {}

			for fid in string.gmatch(tostring(ix.config.Get(KEYS.factions, "")), "[^,;%s]+") do
				list[#list + 1] = fid
			end

			return #list > 0 and list or nil
		end

		if (KEYS[name]) then
			return ix.config.Get(KEYS[name], SETTINGS[name][2])
		end
	end
})

local CFG = ix.capture.config

-- Множество uniqueID фракций, которые участвуют в захвате.
function ix.capture.GetFactions()
	local set = {}

	if (istable(CFG.factions)) then
		for _, fid in ipairs(CFG.factions) do
			if (ix.faction.teams[fid]) then set[fid] = true end
		end
	elseif (ix.tablet and ix.tablet.factions) then
		for fid in pairs(ix.tablet.factions) do
			if (ix.faction.teams[fid]) then set[fid] = true end
		end
	else
		for fid in pairs(ix.faction.teams) do set[fid] = true end
	end

	return set
end

-- Нижний регистр с учётом кириллицы (string.lower её не понижает).
function ix.capture.Lower(text)
	return (string.gsub(string.lower(tostring(text or "")), utf8.charpattern, function(ch)
		local ok, cp = pcall(utf8.codepoint, ch)

		if (not ok) then return ch end
		if (cp >= 0x410 and cp <= 0x42F) then return utf8.char(cp + 32) end
		if (cp == 0x401) then return utf8.char(0x451) end

		return ch
	end))
end

-- Поиск фракции по uniqueID или по части названия (регистр не важен).
function ix.capture.FindFaction(query)
	query = ix.capture.Lower(string.Trim(tostring(query or "")))

	if (query == "") then return end

	local allowed = ix.capture.GetFactions()

	if (allowed[query]) then return query end

	for fid in pairs(allowed) do
		local faction = ix.faction.teams[fid]

		if (string.lower(fid) == query
		or (faction and string.find(ix.capture.Lower(faction.name), query, 1, true))) then
			return fid
		end
	end
end

-- ===================== Команды (только для админов) =====================

local NO_OWNER = {["none"] = true, ["нет"] = true, ["-"] = true, ["0"] = true}

ix.command.Add("CapPointAdd", {
	description = "Создать точку захвата в вашей позиции. Использование: /CapPointAdd <название>",
	adminOnly = true,
	arguments = ix.type.text,
	OnRun = function(self, client, name)
		local point, err = PLUGIN:AddPoint(client:GetPos(), name)

		if (not point) then return err end

		return string.format("Точка #%d «%s» создана. Радиус %d, высота ±%d. Настроить: /CapPointRadius.",
			point.id, point.name, point.radius, point.height)
	end
})

ix.command.Add("CapPointRemove", {
	description = "Удалить точку захвата. Использование: /CapPointRemove <номер>",
	adminOnly = true,
	arguments = ix.type.number,
	OnRun = function(self, client, id)
		local point = PLUGIN:GetPoint(math.floor(id))

		if (not point) then return "Точка с таким номером не найдена. Список: /CapPointList." end

		PLUGIN:RemovePoint(point)

		return string.format("Точка #%d «%s» удалена.", point.id, point.name)
	end
})

ix.command.Add("CapPointMove", {
	description = "Перенести точку захвата в вашу позицию. Использование: /CapPointMove <номер>",
	adminOnly = true,
	arguments = ix.type.number,
	OnRun = function(self, client, id)
		local point = PLUGIN:GetPoint(math.floor(id))

		if (not point) then return "Точка с таким номером не найдена. Список: /CapPointList." end

		PLUGIN:MovePoint(point, client:GetPos())

		return string.format("Точка #%d «%s» перенесена.", point.id, point.name)
	end
})

ix.command.Add("CapPointRadius", {
	description = "Задать размер зоны. Использование: /CapPointRadius <номер> <радиус> [высота]",
	adminOnly = true,
	arguments = {ix.type.number, ix.type.number, bit.bor(ix.type.number, ix.type.optional)},
	OnRun = function(self, client, id, radius, height)
		local point = PLUGIN:GetPoint(math.floor(id))

		if (not point) then return "Точка с таким номером не найдена. Список: /CapPointList." end

		PLUGIN:ResizePoint(point, radius, height)

		return string.format("Точка #%d «%s»: радиус %d, высота ±%d.", point.id, point.name, point.radius, point.height)
	end
})

ix.command.Add("CapPointOwner", {
	description = "Назначить владельца точки (или none, чтобы сделать нейтральной). Использование: /CapPointOwner <номер> <фракция|none>",
	adminOnly = true,
	arguments = {ix.type.number, ix.type.text},
	OnRun = function(self, client, id, who)
		local point = PLUGIN:GetPoint(math.floor(id))

		if (not point) then return "Точка с таким номером не найдена. Список: /CapPointList." end

		if (NO_OWNER[ix.capture.Lower(string.Trim(who))]) then
			PLUGIN:SetOwner(point, nil)

			return string.format("Точка #%d «%s» теперь нейтральная.", point.id, point.name)
		end

		local fid = ix.capture.FindFaction(who)

		if (not fid) then
			local ids = {}

			for key in pairs(ix.capture.GetFactions()) do ids[#ids + 1] = key end

			table.sort(ids)

			return "Фракция не найдена. Доступны: " .. table.concat(ids, ", ") .. "."
		end

		PLUGIN:SetOwner(point, fid)

		return string.format("Точка #%d «%s» передана фракции «%s».", point.id, point.name, ix.faction.teams[fid].name)
	end
})

ix.command.Add("CapPointList", {
	description = "Показать все точки захвата, их владельцев и прогресс.",
	adminOnly = true,
	OnRun = function(self, client)
		local points = PLUGIN.points

		if (#points == 0) then return "Точек захвата нет. Создать: /CapPointAdd <название>." end

		for _, point in ipairs(points) do
			local owner = point.owner and ix.faction.teams[point.owner]
			local line = string.format("#%d «%s» — владелец: %s | (%d, %d, %d) r=%d h=±%d",
				point.id, point.name, owner and owner.name or "нейтральная",
				point.x, point.y, point.z, point.radius, point.height)

			if (point.capturer) then
				line = line .. string.format(" | захват: %s %d%%",
					ix.faction.teams[point.capturer] and ix.faction.teams[point.capturer].name or point.capturer,
					math.floor(point.progress * 100))
			end

			if (point.contested) then line = line .. " | СПОР" end

			client:ChatPrint(line)
		end
	end
})

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
