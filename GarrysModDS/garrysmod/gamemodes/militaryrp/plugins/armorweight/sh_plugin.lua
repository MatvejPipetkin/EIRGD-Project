local PLUGIN = PLUGIN

PLUGIN.name = "Armor & Weight"
PLUGIN.author = "Server"
PLUGIN.description = "Вес и характеристики брони: замедление от веса, бронирование по зонам, взрывоустойчивость, эргономика, износ."

ix.armorgear = ix.armorgear or {}
local gear = ix.armorgear

-- ---------------------------------------------------------------------------
-- Зоны покрытия
-- В ITEM.armorStats.coverage указываются имена зон (ключи таблицы gear.zones).
-- ---------------------------------------------------------------------------

gear.hitGroups = {
	HITGROUP_HEAD, HITGROUP_CHEST, HITGROUP_STOMACH,
	HITGROUP_LEFTARM, HITGROUP_RIGHTARM,
	HITGROUP_LEFTLEG, HITGROUP_RIGHTLEG
}

gear.zones = {
	head = {HITGROUP_HEAD},
	chest = {HITGROUP_CHEST},
	stomach = {HITGROUP_STOMACH},
	torso = {HITGROUP_CHEST, HITGROUP_STOMACH},
	arms = {HITGROUP_LEFTARM, HITGROUP_RIGHTARM},
	legs = {HITGROUP_LEFTLEG, HITGROUP_RIGHTLEG},
	all = gear.hitGroups
}

gear.zoneNames = {
	head = "голова",
	chest = "грудь",
	stomach = "живот",
	torso = "торс",
	arms = "руки",
	legs = "ноги",
	all = "всё тело"
}

-- Попадания без точной зоны считаем попаданием в грудь.
gear.hitGroupAlias = {
	[HITGROUP_GENERIC] = HITGROUP_CHEST,
	[HITGROUP_GEAR] = HITGROUP_CHEST
}

-- Типы урона, которые режет бронирование (процент брони).
gear.armorDamageTypes = bit.bor(DMG_BULLET, DMG_BUCKSHOT, DMG_SNIPER, DMG_SLASH, DMG_CLUB)
-- Типы урона, которые режет взрывоустойчивость.
gear.blastDamageTypes = bit.bor(DMG_BLAST, DMG_BLAST_SURFACE)

function gear.CoverageText(coverage)
	local names = {}

	for _, zone in ipairs(coverage or {}) do
		names[#names + 1] = gear.zoneNames[zone] or tostring(zone)
	end

	if (#names == 0) then
		return "нет"
	end

	return table.concat(names, ", ")
end

-- ---------------------------------------------------------------------------
-- Цвета характеристик — всё настраивается здесь
-- ---------------------------------------------------------------------------

gear.colors = {
	bad = Color(235, 80, 70),       -- плохо (красный)
	mid = Color(240, 200, 70),      -- средне (жёлтый)
	good = Color(100, 220, 110),    -- хорошо (зелёный)
	neutral = Color(190, 190, 190), -- характеристики нет (серый)
	info = Color(120, 180, 255),    -- справочная строка (покрытие)
	equipped = Color(110, 255, 110) -- «Надето»
}

-- Шкала окраски: при каком значении характеристика «хуже некуда» (красная)
-- и при каком «лучше некуда» (зелёная). Между ними цвет меняется плавно.
gear.statScale = {
	weight = {best = 0, worst = 30},  -- кг: чем легче, тем зеленее
	armor = {best = 80, worst = 0},   -- % бронирования
	blast = {best = 80, worst = 0},   -- % взрывоустойчивости
	ergo = {best = 0, worst = -15}    -- % эргономики: минус — красный
}

-- Названия состояния брони. Берётся первая строка, у которой доля прочности >= порога.
gear.conditionNames = {
	{0.8, "Отличное"},
	{0.55, "Хорошее"},
	{0.3, "Изношенное"},
	{0.0001, "Критическое"},
	{0, "Сломано"}
}

function gear.MixColor(a, b, t)
	return Color(
		math.Round(Lerp(t, a.r, b.r)),
		math.Round(Lerp(t, a.g, b.g)),
		math.Round(Lerp(t, a.b, b.b))
	)
end

-- frac: 0 — плохо (красный), 0.5 — средне (жёлтый), 1 — хорошо (зелёный)
function gear.FractionColor(frac)
	frac = math.Clamp(frac, 0, 1)

	local c = gear.colors

	if (frac < 0.5) then
		return gear.MixColor(c.bad, c.mid, frac * 2)
	end

	return gear.MixColor(c.mid, c.good, (frac - 0.5) * 2)
end

function gear.StatColor(stat, value)
	local scale = gear.statScale[stat]

	return gear.FractionColor((value - scale.worst) / (scale.best - scale.worst))
end

function gear.ConditionName(cond)
	for _, entry in ipairs(gear.conditionNames) do
		if (cond >= entry[1]) then
			return entry[2]
		end
	end

	return "Сломано"
end

-- ---------------------------------------------------------------------------
-- Характеристики предмета
--
-- Основной способ — один блок в файле предмета:
--
--   ITEM.armorStats = {
--       slot = "body",          -- слот (в одном слоте носится один предмет)
--       weight = 11,            -- вес, кг
--       protection = 60,        -- бронирование, %
--       blast = 20,             -- взрывоустойчивость, %
--       ergonomics = -8,        -- эргономика, % к скорости
--       coverage = {"torso"},   -- закрытые зоны
--       durability = 150,       -- макс. прочность (false — не изнашивается)
--   }
--
-- Старые плоские поля (ITEM.armorWeight, armorPercent, blastResist, ergonomics,
-- coverage, armorSlot, maxDurability) по-прежнему работают как запасной вариант.
-- ---------------------------------------------------------------------------

gear.knownKeys = {
	slot = true, weight = true, protection = true, blast = true,
	ergonomics = true, coverage = true, durability = true
}

function gear.GetStats(item)
	local block = istable(item.armorStats) and item.armorStats or {}

	local function pick(key, legacy, default)
		if (block[key] ~= nil) then
			return block[key]
		end

		if (item[legacy] ~= nil) then
			return item[legacy]
		end

		return default
	end

	local coverage = pick("coverage", "coverage", {})

	if (isstring(coverage)) then
		coverage = {coverage}
	end

	return {
		slot = pick("slot", "armorSlot", "body"),
		weight = math.max(pick("weight", "armorWeight", 0), 0),
		armor = math.Clamp(pick("protection", "armorPercent", 0), 0, 100),
		blast = math.Clamp(pick("blast", "blastResist", 0), 0, 100),
		ergo = pick("ergonomics", "ergonomics", 0),
		coverage = istable(coverage) and coverage or {}
	}
end

-- Предмет учитывается плагином, если у него задана хотя бы одна из характеристик.
-- Так работают и предметы с базой base_armorweight, и любая другая база
-- (например, одежда из Simple Inventory Slots) — достаточно добавить ITEM.armorStats.
function gear.HasStats(item)
	return item.isArmorGear == true
		or item.armorStats ~= nil
		or item.armorWeight ~= nil
		or item.armorPercent ~= nil
		or item.blastResist ~= nil
		or item.ergonomics ~= nil
end

-- ---------------------------------------------------------------------------
-- Прочность (состояние) брони
-- Хранится в данных предмета под ключом "durability" — как у оружия
-- в плагине починки, поэтому ремкомплекты работают и для брони.
-- ---------------------------------------------------------------------------

-- Максимальная прочность; nil — предмет не изнашивается (armorStats.durability = false).
function gear.GetMaxDurability(item)
	local block = istable(item.armorStats) and item.armorStats or {}

	if (block.durability == false) then
		return nil
	end

	return block.durability or item.maxDurability or ix.config.Get("maxValueDurability", 100)
end

-- Текущая прочность и максимум (nil, если предмет не изнашивается).
function gear.GetDurability(item)
	local max = gear.GetMaxDurability(item)

	if (not max) then
		return nil
	end

	return math.Clamp(item:GetData("durability", max), 0, max), max
end

-- Состояние от 0 до 1 (1 — как новое). nil, если предмет не изнашивается.
function gear.GetCondition(item)
	local durability, max = gear.GetDurability(item)

	if (not durability) then
		return nil
	end

	return durability / max
end

-- ---------------------------------------------------------------------------
-- Строки с характеристиками (для тултипа): {text = "...", color = Color}
-- ---------------------------------------------------------------------------

function gear.GetStatRows(item)
	local stats = gear.GetStats(item)
	local cond = gear.GetCondition(item)
	local c = gear.colors
	local rows = {}

	local function add(text, color)
		rows[#rows + 1] = {text = text, color = color}
	end

	-- Вес
	add(string.format("Вес: %.1f кг", stats.weight), gear.StatColor("weight", stats.weight))

	-- Бронирование и взрывоустойчивость: показываем и реальное значение с учётом износа
	local function protection(label, stat, base)
		local now = base * (cond or 1)
		local text = string.format("%s: %g%%", label, base)

		if (cond and cond < 1 and base > 0) then
			text = string.format("%s: %g%% (из %g%%)", label, math.Round(now, 1), base)
		end

		add(text, base > 0 and gear.StatColor(stat, now) or c.neutral)
	end

	protection("Бронирование", "armor", stats.armor)
	protection("Взрывоустойчивость", "blast", stats.blast)

	-- Эргономика
	add(string.format("Эргономика: %+g%% к скорости", stats.ergo), gear.StatColor("ergo", stats.ergo))

	-- Покрытие
	add("Покрытие: " .. gear.CoverageText(stats.coverage), c.info)

	-- Состояние
	if (cond) then
		add(string.format("Состояние: %d%% (%s)", math.floor(cond * 100 + 0.5), gear.ConditionName(cond)),
			gear.FractionColor(cond))
	end

	if (item:GetData("equip")) then
		add("[Надето]", c.equipped)
	end

	return rows
end

-- Те же строки без цвета (для чата, логов и т.п.).
function gear.GetStatLines(item)
	local lines = {}

	for _, row in ipairs(gear.GetStatRows(item)) do
		lines[#lines + 1] = row.text
	end

	return lines
end

-- Краткая сводка по весу и скорости (работает на обеих сторонах через netvar).
function gear.GetSummary(client)
	local weight = client:GetNetVar("armorWeight", 0)
	local speed = client:GetNetVar("armorSpeed", 1)

	return string.format("Вес снаряжения: %.1f кг | Скорость: %d%%", weight, math.Round(speed * 100))
end

-- Проверка ITEM.armorStats: ловит опечатки в названиях параметров и зон.
function gear.ValidateItem(id, item)
	local block = item.armorStats

	if (not istable(block)) then
		return
	end

	local warn = gear.colors.mid

	for key in pairs(block) do
		if (not gear.knownKeys[key]) then
			MsgC(warn, "[armorweight] ", color_white, id, ": неизвестный параметр armorStats.", tostring(key), "\n")
		end
	end

	local coverage = block.coverage

	if (isstring(coverage)) then
		coverage = {coverage}
	end

	for _, zone in ipairs(coverage or {}) do
		if (not gear.zones[zone]) then
			MsgC(warn, "[armorweight] ", color_white, id, ": неизвестная зона покрытия \"", tostring(zone), "\"\n")
		end
	end
end

-- ---------------------------------------------------------------------------
-- Настройки (меню конфигурации Helix, категория «Броня и вес»)
-- ---------------------------------------------------------------------------

local function refresh()
	if (SERVER) then
		PLUGIN:RefreshAll()
	end
end

ix.config.Add("armorFreeWeight", 6, "Вес экипировки (кг), до которого скорость не снижается.", refresh, {
	data = {min = 0, max = 100, decimals = 1},
	category = "Броня и вес"
})

ix.config.Add("armorSlowPerKg", 1.2, "Сколько процентов скорости теряется за каждый кг сверх свободного веса.", refresh, {
	data = {min = 0, max = 10, decimals = 2},
	category = "Броня и вес"
})

ix.config.Add("armorMinSpeed", 40, "Минимальная скорость (в % от обычной), ниже которой экипировка не замедлит.", refresh, {
	data = {min = 10, max = 100},
	category = "Броня и вес"
})

ix.config.Add("armorNoSprintWeight", 40, "Вес экипировки (кг), начиная с которого бег отключается (0 — не отключать).", refresh, {
	data = {min = 0, max = 200, decimals = 1},
	category = "Броня и вес"
})

ix.config.Add("armorMaxReduction", 90, "Максимальный процент урона, который может игнорировать броня (и взрывоустойчивость).", refresh, {
	data = {min = 10, max = 100},
	category = "Броня и вес"
})

ix.config.Add("armorWearRate", 0.15, "Скорость износа брони: прочность, которую теряет предмет за 1 ед. урона, который он должен поглотить (урон × бронирование предмета). 0 — броня не изнашивается.", nil, {
	data = {min = 0, max = 5, decimals = 3},
	category = "Броня и вес"
})

-- ---------------------------------------------------------------------------
-- Замедление (shared: нужно и клиенту для предикшена движения)
-- ---------------------------------------------------------------------------

function PLUGIN:SetupMove(client, mv, cmd)
	local mult = client:GetNetVar("armorSpeed", 1)
	local noSprint = client:GetNetVar("armorNoSprint", false)

	if (mult >= 1 and not noSprint) then
		return
	end

	local maxSpeed = mv:GetMaxSpeed()

	if (noSprint) then
		maxSpeed = math.min(maxSpeed, client:GetWalkSpeed())
	end

	maxSpeed = maxSpeed * mult

	mv:SetMaxSpeed(maxSpeed)
	mv:SetMaxClientSpeed(maxSpeed)
end

-- ---------------------------------------------------------------------------
-- Подготовка предметов (обе стороны)
-- ---------------------------------------------------------------------------

function PLUGIN:InitializedPlugins()
	for id, item in pairs(ix.item.list) do
		if (gear.HasStats(item)) then
			if (SERVER) then
				gear.ValidateItem(id, item)
			end

			-- Полоска состояния на иконке: подключаем ко всем предметам с характеристиками,
			-- в том числе к чужим базам (одежда из слотов) — их PaintOver сохраняется.
			if (CLIENT and not item.ixConditionBar) then
				item.ixConditionBar = true

				local oldPaint = item.PaintOver

				item.PaintOver = function(panel, itemObj, w, h)
					if (oldPaint) then
						oldPaint(panel, itemObj, w, h)
					end

					gear.PaintCondition(itemObj, w, h)
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Клиент: тултип с цветными характеристиками и полоска состояния
-- ---------------------------------------------------------------------------

if (CLIENT) then
	function PLUGIN:PopulateItemTooltip(tooltip, item)
		if (not gear.HasStats(item)) then
			return
		end

		local after = "description"

		for i, row in ipairs(gear.GetStatRows(item)) do
			local id = "armorgear" .. i
			local panel = tooltip:AddRowAfter(after, id)

			panel:SetText(row.text)
			panel:SetTextColor(row.color)
			panel:SizeToContents()

			after = id
		end
	end

	-- Полоска состояния внизу иконки предмета (красная → жёлтая → зелёная).
	function gear.PaintCondition(item, w, h)
		local cond = gear.GetCondition(item)

		if (not cond) then
			return
		end

		local color = gear.FractionColor(cond)

		surface.SetDrawColor(0, 0, 0, 160)
		surface.DrawRect(0, h - 4, w, 4)

		surface.SetDrawColor(color.r, color.g, color.b, 255)
		surface.DrawRect(0, h - 4, w * cond, 4)
	end
end

-- ---------------------------------------------------------------------------
-- Сервер: расчёт характеристик, урон, износ, команда
-- ---------------------------------------------------------------------------

if (SERVER) then
	-- Пересчитывает вес, скорость и защиту по надетым предметам.
	function PLUGIN:UpdateArmor(client)
		if (not IsValid(client)) then
			return
		end

		local floorMult = 1 - math.Clamp(ix.config.Get("armorMaxReduction", 90), 0, 100) / 100
		local stats = {weight = 0, ergo = 0, blast = 1, zones = {}, layers = {}, blastItems = {}}

		for _, hitGroup in ipairs(gear.hitGroups) do
			stats.zones[hitGroup] = 1
			stats.layers[hitGroup] = {} -- предметы, которые изнашиваются при попадании в эту зону
		end

		local character = client:GetCharacter()

		-- Смотрим ВСЕ инвентари персонажа: основной, сумки и слоты экипировки
		-- (в Simple Inventory Slots надетое лежит в отдельных инвентарях-слотах).
		local inventories = {}

		if (character) then
			local all = character:GetInventory(true)

			if (istable(all) and all.GetItems) then
				inventories[1] = all -- вернулся один инвентарь
			elseif (istable(all)) then
				inventories = all
			end
		end

		for _, inventory in pairs(inventories) do
			for _, item in pairs(inventory:GetItems()) do
				if (gear.HasStats(item) and item:GetData("equip")) then
					local s = gear.GetStats(item)

					-- Чем сильнее изношен предмет, тем хуже он защищает; сломанный не защищает вовсе.
					local cond = gear.GetCondition(item) or 1
					local armor = s.armor / 100 * cond
					local blast = s.blast / 100 * cond

					stats.weight = stats.weight + s.weight
					stats.ergo = stats.ergo + s.ergo
					-- Слои брони складываются с убывающей отдачей: 1 - (1-a)*(1-b)
					stats.blast = stats.blast * (1 - blast)

					if (blast > 0) then
						stats.blastItems[#stats.blastItems + 1] = item
					end

					local covered = {}

					for _, zone in ipairs(s.coverage) do
						for _, hitGroup in ipairs(gear.zones[zone] or {}) do
							covered[hitGroup] = true
						end
					end

					for hitGroup in pairs(covered) do
						stats.zones[hitGroup] = stats.zones[hitGroup] * (1 - armor)

						if (armor > 0) then
							table.insert(stats.layers[hitGroup], item)
						end
					end
				end
			end
		end

		-- Потолок защиты
		stats.blast = math.max(stats.blast, floorMult)

		for hitGroup, mult in pairs(stats.zones) do
			stats.zones[hitGroup] = math.max(mult, floorMult)
		end

		-- Скорость: эргономика (в %) и штраф за вес сверх свободного
		local freeWeight = ix.config.Get("armorFreeWeight", 6)
		local perKg = ix.config.Get("armorSlowPerKg", 1.2)
		local minSpeed = ix.config.Get("armorMinSpeed", 40) / 100
		local noSprintWeight = ix.config.Get("armorNoSprintWeight", 40)

		local overweight = math.max(stats.weight - freeWeight, 0)
		local speed = 1 + stats.ergo / 100 - overweight * perKg / 100

		stats.speed = math.Clamp(speed, minSpeed, 1)
		stats.noSprint = noSprintWeight > 0 and stats.weight >= noSprintWeight

		client.ixArmorStats = stats

		client:SetNetVar("armorWeight", stats.weight)
		client:SetNetVar("armorSpeed", stats.speed)
		client:SetNetVar("armorNoSprint", stats.noSprint)
	end

	function PLUGIN:RefreshAll()
		for _, client in ipairs(player.GetAll()) do
			if (client:GetCharacter()) then
				self:UpdateArmor(client)
			end
		end
	end

	-- Вызывается предметами при надевании/снятии и плагином починки после ремонта.
	function PLUGIN:ArmorGearChanged(client)
		self:UpdateArmor(client)
	end

	function PLUGIN:PlayerLoadedCharacter(client, character, lastChar)
		timer.Simple(0.25, function()
			if (IsValid(client)) then
				self:UpdateArmor(client)
			end
		end)
	end

	-- Предмет переложили между инвентарями (в том числе в слот экипировки и обратно).
	-- Небольшая задержка: другие плагины (Simple Inventory Slots) выставляют
	-- состояние «надето» в своём обработчике этого же хука.
	function PLUGIN:OnItemTransferred(item, curInv, inventory)
		timer.Simple(0.1, function()
			for _, inv in ipairs({curInv, inventory}) do
				local owner = inv and inv.owner and ix.char.loaded[inv.owner]
				local client = owner and owner:GetPlayer()

				if (IsValid(client)) then
					self:UpdateArmor(client)
				end
			end
		end)
	end

	-- Страховка: если предмет удалили/переместили в обход обычных действий.
	timer.Create("ixArmorGearRefresh", 3, 0, function()
		PLUGIN:RefreshAll()
	end)

	-- -----------------------------------------------------------------------
	-- Износ
	-- Прочность сразу меняется в памяти, а в базу и клиенту уходит раз в секунду —
	-- чтобы очередь из пуль не заваливала базу запросами.
	-- -----------------------------------------------------------------------

	-- damage — входящий урон; stat — какая защита изнашивается ("armor" или "blast").
	-- Износ считается от номинальной защиты предмета, а не от текущей: так даже
	-- сильно изношенная броня в конце концов доходит до «Сломано».
	function PLUGIN:WearItems(client, items, damage, stat)
		local rate = ix.config.Get("armorWearRate", 0.15)

		if (not items or #items == 0 or damage <= 0 or rate <= 0) then
			return
		end

		local changed = false

		for _, item in ipairs(items) do
			if (ix.item.instances[item.id] == item) then
				local durability = gear.GetDurability(item)

				if (durability and durability > 0) then
					local wear = damage * gear.GetStats(item)[stat] / 100 * rate
					local new = math.max(durability - wear, 0)

					item.data = item.data or {}
					item.data.durability = new

					client.ixArmorDirty = client.ixArmorDirty or {}
					client.ixArmorDirty[item] = true
					changed = true

					if (new <= 0) then
						client:Notify(item:GetName() .. " полностью разрушен и больше не защищает!")
					end
				end
			end
		end

		if (changed) then
			self:QueueFlush(client)
		end
	end

	function PLUGIN:QueueFlush(client)
		local name = "ixArmorWear" .. client:UserID()

		if (timer.Exists(name)) then
			return
		end

		timer.Create(name, 1, 1, function()
			if (not IsValid(client)) then
				return
			end

			local dirty = client.ixArmorDirty
			client.ixArmorDirty = nil

			for item in pairs(dirty or {}) do
				if (ix.item.instances[item.id] == item) then
					item:SetData("durability", item:GetData("durability", 0))
				end
			end

			self:UpdateArmor(client)
		end)
	end

	-- -----------------------------------------------------------------------
	-- Урон
	-- -----------------------------------------------------------------------

	-- Hitgroup известен только в ScalePlayerDamage, который вызывается
	-- сразу перед EntityTakeDamage в том же тике — запоминаем его.
	function PLUGIN:ScalePlayerDamage(client, hitGroup, dmgInfo)
		client.ixArmorHitGroup = hitGroup
		client.ixArmorHitTime = CurTime()
	end

	function PLUGIN:EntityTakeDamage(target, dmgInfo)
		if (not IsValid(target) or not target:IsPlayer() or not target:GetCharacter()) then
			return
		end

		local stats = target.ixArmorStats

		if (not stats) then
			return
		end

		local dmgType = dmgInfo:GetDamageType()
		local mult = 1
		local worn -- предметы, которые изнашиваются от этого урона
		local wornStat -- какая защита изнашивается: "armor" или "blast"

		if (bit.band(dmgType, gear.blastDamageTypes) ~= 0) then
			mult = stats.blast
			worn = stats.blastItems
			wornStat = "blast"
		elseif (bit.band(dmgType, gear.armorDamageTypes) ~= 0) then
			local hitGroup = HITGROUP_CHEST

			if (target.ixArmorHitTime == CurTime() and target.ixArmorHitGroup) then
				hitGroup = gear.hitGroupAlias[target.ixArmorHitGroup] or target.ixArmorHitGroup
			end

			mult = stats.zones[hitGroup] or 1
			worn = stats.layers[hitGroup]
			wornStat = "armor"
		end

		target.ixArmorHitGroup = nil
		target.ixArmorHitTime = nil

		if (mult < 1) then
			local before = dmgInfo:GetDamage()

			dmgInfo:ScaleDamage(mult)

			self:WearItems(target, worn, before, wornStat)
		end
	end

	-- Текстовый отчёт для команды /ArmorStats
	function PLUGIN:GetReport(client)
		if (not client.ixArmorStats) then
			self:UpdateArmor(client)
		end

		local stats = client.ixArmorStats
		local zones = stats.zones

		local function pct(mult)
			return math.Round((1 - mult) * 100)
		end

		return {
			string.format("Вес снаряжения: %.1f кг (без штрафа до %.1f кг)", stats.weight, ix.config.Get("armorFreeWeight", 6)),
			string.format("Скорость ходьбы/бега: %d%% от обычной", math.Round(stats.speed * 100)),
			stats.noSprint and "Бег недоступен: снаряжение слишком тяжёлое." or "Бег доступен.",
			string.format("Бронирование — голова: %d%%, грудь: %d%%, живот: %d%%, руки: %d%%, ноги: %d%%",
				pct(zones[HITGROUP_HEAD]),
				pct(zones[HITGROUP_CHEST]),
				pct(zones[HITGROUP_STOMACH]),
				pct(math.max(zones[HITGROUP_LEFTARM], zones[HITGROUP_RIGHTARM])),
				pct(math.max(zones[HITGROUP_LEFTLEG], zones[HITGROUP_RIGHTLEG]))
			),
			string.format("Взрывоустойчивость: %d%%", pct(stats.blast))
		}
	end
end

ix.command.Add("ArmorStats", {
	description = "Показать вес, скорость и защиту вашей экипировки.",
	OnRun = function(self, client)
		for _, line in ipairs(PLUGIN:GetReport(client)) do
			client:ChatPrint(line)
		end
	end
})
