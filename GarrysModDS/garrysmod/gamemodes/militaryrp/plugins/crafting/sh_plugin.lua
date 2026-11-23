PLUGIN.name = "Крафт"
PLUGIN.author = "Schema"
PLUGIN.description = "Система крафта: верстаки, атрибут «Ремесло», материалы и анимации создания предметов."

PLUGIN.workbenches = PLUGIN.workbenches or {}
PLUGIN.recipes = PLUGIN.recipes or {}

ix.config.Add("craftMaxDistance", 160, "Максимальная дистанция до верстака при крафте.", nil, {
	data = {min = 64, max = 512}, category = "Крафт"
})
ix.config.Add("craftTimeMultiplier", 1, "Множитель времени крафта (1 = как в рецептах).", nil, {
	data = {min = 0.1, max = 5, decimals = 1}, category = "Крафт"
})
ix.config.Add("craftSkillBonus", 5, "Бонус к шансу за точное попадание в мини-игре крафта (%, за одну точку; 0 - выключить мини-игру).", nil, {
	data = {min = 0, max = 15}, category = "Крафт"
})
ix.config.Add("craftFailLoss", 0.5, "Какая доля материалов теряется при провале (0 - ничего, 1 - всё).", nil, {
	data = {min = 0, max = 1, decimals = 2}, category = "Крафт"
})

function PLUGIN:RegisterWorkbench(id, data)
	data.id = id
	data.color = data.color or Color(90, 170, 255)
	self.workbenches[id] = data
end

function PLUGIN:RegisterRecipe(id, data)
	data.id = id
	data.ingredients = data.ingredients or {}
	data.result = data.result or {}
	self.recipes[id] = data
end

function PLUGIN:GetBenchRecipes(benchID)
	local out = {}

	for _, recipe in pairs(self.recipes) do
		if (recipe.bench == benchID) then
			out[#out + 1] = recipe
		end
	end

	table.sort(out, function(a, b)
		local ca, cb = a.category or "", b.category or ""
		if (ca != cb) then return ca < cb end
		return (a.name or a.id) < (b.name or b.id)
	end)

	return out
end

-- Разбор шанса успеха: база рецепта + значение атрибута * масштаб + бонус верстака.
function PLUGIN:GetChanceBreakdown(client, recipe)
	local char = client:GetCharacter()
	local value = char and char:GetAttribute(recipe.attribute or "crafting", 0) or 0
	local bench = self.workbenches[recipe.bench]

	local base = recipe.baseChance or 40
	local skill = value * (recipe.attribScale or 1)
	local benchBonus = bench and bench.bonus or 0

	return base, skill, benchBonus, math.Clamp(base + skill + benchBonus, 5, 100)
end

-- Шанс успеха в процентах (без мини-игры).
function PLUGIN:GetCraftChance(client, recipe)
	local _, _, _, total = self:GetChanceBreakdown(client, recipe)
	return total
end

-- Контрольные точки мини-игры: положение на шкале прогресса (0..1).
PLUGIN.checkpoints = {0.3, 0.55, 0.8}

-- Половина ширины зоны контрольной точки (в долях прогресса); не уже ~0.45 с в каждую сторону.
function PLUGIN:GetCheckHalfWidth(duration)
	return math.max(0.045, 0.45 / math.max(duration, 1))
end

-- Общая проверка (клиент: для интерфейса, сервер: перед стартом и в конце крафта).
function PLUGIN:CanCraft(client, recipe)
	local char = client:GetCharacter()
	if (!char) then return false, "Нет персонажа." end

	local inv = char:GetInventory()
	if (!inv) then return false, "Нет инвентаря." end

	local attrID = recipe.attribute or "crafting"
	local attrData = ix.attributes.list[attrID]
	local level = char:GetAttribute(attrID, 0)

	if ((recipe.minLevel or 0) > level) then
		return false, string.format("Нужен навык «%s»: %d", attrData and attrData.name or attrID, recipe.minLevel)
	end

	if (recipe.factions and !table.HasValue(recipe.factions, char:GetFaction())) then
		return false, "Ваша фракция не знает этот рецепт."
	end

	if (recipe.canCraft) then
		local ok, why = recipe.canCraft(client, char)
		if (ok == false) then return false, why or "Недоступно." end
	end

	for _, toolID in ipairs(recipe.tools or {}) do
		if (inv:GetItemCount(toolID) < 1) then
			local item = ix.item.list[toolID]
			return false, "Нужен инструмент: " .. (item and item.name or toolID)
		end
	end

	for id, qty in pairs(recipe.ingredients) do
		if (inv:GetItemCount(id) < qty) then
			return false, "Не хватает материалов."
		end
	end

	return true
end

ix.command.Add("WorkbenchAdd", {
	description = "Создать верстак. Типы: mechanical, electronics, chemistry, armory, medical.",
	adminOnly = true,
	arguments = ix.type.string,
	OnRun = function(self, client, benchID)
		local plugin = ix.plugin.Get("crafting")
		benchID = benchID:lower()

		if (!plugin.workbenches[benchID]) then
			return "Неизвестный тип. Доступные: " .. table.concat(table.GetKeys(plugin.workbenches), ", ")
		end

		local tr = client:GetEyeTrace()
		local ent = ents.Create("ix_workbench")
		local ang = (client:GetPos() - tr.HitPos):Angle()
		ang.p, ang.r = 0, 0

		ent:SetPos(tr.HitPos + tr.HitNormal * 4)
		ent:SetAngles(ang)
		ent:Spawn()
		ent:SetType(benchID)
		ent:DropToFloor()

		plugin:SaveData()

		return "Верстак создан: " .. plugin.workbenches[benchID].name
	end
})

ix.command.Add("WorkbenchRemove", {
	description = "Удалить верстак, на который вы смотрите.",
	adminOnly = true,
	OnRun = function(self, client)
		local ent = client:GetEyeTrace().Entity

		if (!IsValid(ent) or ent:GetClass() != "ix_workbench") then
			return "Вы не смотрите на верстак."
		end

		ent:Remove()
		ix.plugin.Get("crafting"):SaveData()

		return "Верстак удалён."
	end
})

ix.util.Include("sh_config.lua")

-- Каждый тип верстака - отдельная запись во вкладке «Энтити» (категория «EIRGD | Верстаки»).
for id, data in pairs(PLUGIN.workbenches) do
	list.Set("SpawnableEntities", "ix_workbench_" .. id, {
		PrintName = data.name,
		ClassName = "ix_workbench",
		Category = "EIRGD | Верстаки",
		AdminOnly = true,
		KeyValues = {benchtype = id}
	})
end
ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_menu.lua")