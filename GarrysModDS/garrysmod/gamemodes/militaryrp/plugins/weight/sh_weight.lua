local PLUGIN = PLUGIN

--[[
	СИСТЕМА ВЕСА (общая часть)

	Вес предмета задаётся в файле предмета:
		ITEM.weight = 1.5 -- кг за одну штуку

	Дополнительно (необязательно):
		ITEM.weight = function(item) return ... end -- полный вес считается сам (кг)
		ITEM.weightIgnoreQuantity = true -- не умножать вес на количество в стаке
		item:SetData("weight", 2) -- вес конкретного экземпляра (перекрывает ITEM.weight)

	Настройки лежат в F1 -> Config -> "Система веса" (меняет администратор прямо в игре).
]]

local CATEGORY = "Система веса"

-- при изменении любой настройки сразу пересчитываем вес у всех игроков
local function OnConfigChanged()
	if (SERVER) then
		timer.Simple(0, function()
			if (ix.weight.RefreshAll) then
				ix.weight.RefreshAll()
			end
		end)
	end
end

ix.config.Add("weightEnabled", true, "Включить систему веса. Если выключено, вес не считается и никто не замедляется.", OnConfigChanged, {
	category = CATEGORY
})

ix.config.Add("weightMax", 30, "Базовый допустимый вес переноски в кг (до замедления).", OnConfigChanged, {
	data = {min = 0, max = 1000, decimals = 1},
	category = CATEGORY
})

ix.config.Add("weightAttribute", "str", "ID атрибута, который увеличивает лимит веса (например str). Пусто = не использовать.", OnConfigChanged, {
	category = CATEGORY
})

ix.config.Add("weightPerAttribute", 0.2, "Сколько кг к лимиту даёт каждое очко атрибута выше.", OnConfigChanged, {
	data = {min = 0, max = 50, decimals = 2},
	category = CATEGORY
})

ix.config.Add("weightDefault", 0.5, "Вес в кг для предметов, у которых в файле не указан ITEM.weight (0 = такие предметы ничего не весят).", OnConfigChanged, {
	data = {min = 0, max = 100, decimals = 2},
	category = CATEGORY
})

ix.config.Add("weightSlowPerKg", 4, "Замедление в процентах за каждый кг сверх лимита.", OnConfigChanged, {
	data = {min = 0, max = 100, decimals = 1},
	category = CATEGORY
})

ix.config.Add("weightMaxSlow", 70, "Максимальное замедление в процентах (100 = полностью не может двигаться).", OnConfigChanged, {
	data = {min = 0, max = 100, decimals = 0},
	category = CATEGORY
})

ix.config.Add("weightWindowOffset", 40, "На сколько пикселей поднять окно инвентаря выше (для экрана 1080p). 0 = не поднимать. Применяется при следующем открытии инвентаря.", nil, {
	data = {min = -300, max = 300, decimals = 0},
	category = CATEGORY
})

--[[
	РАСЧЁТ
]]

-- количество в стаке (та же логика, что показывает cl_inventory.lua)
function ix.weight.GetItemAmount(item)
	if (!item or item.weightIgnoreQuantity) then
		return 1
	end

	local amount

	if (isfunction(item.GetQuantity)) then
		amount = item:GetQuantity()
	end

	if (!amount and isfunction(item.GetData)) then
		amount = item:GetData("quantity") or item:GetData("amount") or item:GetData("stack")
	end

	amount = tonumber(amount or item.quantity)

	if (amount and amount > 1) then
		return amount
	end

	return 1
end

-- полный вес предмета (с учётом количества) и количество
function ix.weight.GetItemWeight(item)
	if (!item) then
		return 0, 1
	end

	local weight = item.weight

	-- предмет сам считает свой вес
	if (isfunction(weight)) then
		-- в локальную переменную: если функция ничего не вернёт, получим nil, а не ошибку tonumber()
		local result = weight(item)

		return math.max(tonumber(result) or 0, 0), 1
	end

	local unit

	if (isfunction(item.GetData)) then
		-- GetData может вернуть "ничего" (ноль значений) -> tonumber() без аргумента падает,
		-- поэтому сначала кладём результат в локальную переменную (станет nil)
		local data = item:GetData("weight")

		unit = tonumber(data)
	end

	unit = unit or tonumber(weight)

	if (unit == nil) then
		unit = ix.config.Get("weightDefault", 0.5)
	end

	local amount = ix.weight.GetItemAmount(item)

	return math.max(unit, 0) * amount, amount
end

-- инвентарь внутри сумки (nil, если предмет не сумка)
local function GetBagInventory(item)
	if (!item.isBag) then
		return
	end

	if (isfunction(item.GetInventory)) then
		return item:GetInventory()
	end

	if (isfunction(item.GetData)) then
		return ix.item.inventories[item:GetData("id")]
	end
end

-- вес всех предметов инвентаря, включая содержимое сумок
function ix.weight.GetInventoryWeight(inventory, seen)
	if (!inventory) then
		return 0
	end

	seen = seen or {}

	local items

	if (isfunction(inventory.GetItems)) then
		items = inventory:GetItems()
	else
		items = inventory.items
	end

	local total = 0

	for _, item in pairs(items or {}) do
		-- seen защищает от двойного учёта (GetItems может уже включать содержимое сумок)
		if (istable(item) and item.id and !seen[item.id]) then
			seen[item.id] = true

			total = total + ix.weight.GetItemWeight(item)

			local bagInventory = GetBagInventory(item)

			if (bagInventory and bagInventory != inventory) then
				total = total + ix.weight.GetInventoryWeight(bagInventory, seen)
			end
		end
	end

	return total
end

function ix.weight.GetCharacterWeight(character)
	if (!character) then
		return 0
	end

	return ix.weight.GetInventoryWeight(character:GetInventory())
end

-- лимит веса игрока (кг)
function ix.weight.GetMaxWeight(client)
	local maxWeight = ix.config.Get("weightMax", 30)
	local character = client:GetCharacter()
	local attribute = ix.config.Get("weightAttribute", "")
	local perPoint = ix.config.Get("weightPerAttribute", 0)

	if (character and isstring(attribute) and attribute != "" and perPoint > 0
	and ix.attributes and ix.attributes.list[attribute]) then
		maxWeight = maxWeight + character:GetAttribute(attribute, 0) * perPoint
	end

	-- точка расширения для других плагинов (рюкзаки, перки, одежда и т.д.)
	local custom = hook.Run("GetPlayerMaxWeight", client, maxWeight)

	if (isnumber(custom)) then
		maxWeight = custom
	end

	return math.max(maxWeight, 0)
end

-- замедление в процентах (0..100) для заданного веса и лимита
function ix.weight.GetSlowPercent(weight, maxWeight)
	if (!ix.config.Get("weightEnabled", true)) then
		return 0
	end

	local over = weight - maxWeight

	if (over <= 0) then
		return 0
	end

	local slow = math.Clamp(over * ix.config.Get("weightSlowPerKg", 4), 0, ix.config.Get("weightMaxSlow", 70))

	return math.Clamp(slow, 0, 100)
end

-- "12.5" вместо "12.500000001"
function ix.weight.Format(value)
	return tostring(math.Round(value or 0, 1))
end

--[[
	МЕТОДЫ ИГРОКА
	Значения считает сервер и присылает владельцу (SetLocalVar), поэтому они доступны и на клиенте.
]]
local playerMeta = FindMetaTable("Player")

function playerMeta:GetCarryWeight()
	return self:GetLocalVar("carryWeight", 0)
end

function playerMeta:GetMaxCarryWeight()
	return self:GetLocalVar("carryMax", ix.config.Get("weightMax", 30))
end

-- замедление в процентах
function playerMeta:GetWeightSlow()
	return self:GetLocalVar("weightSlow", 0)
end

function playerMeta:IsOverweight()
	return self:GetWeightSlow() > 0 or self:GetCarryWeight() > self:GetMaxCarryWeight()
end

--[[
	ЗАМЕДЛЕНИЕ
	Масштабируем максимальную скорость движения (работает и с ходьбой, и с бегом, и с приседом).
]]
function PLUGIN:SetupMove(client, mv)
	local slow = client:GetWeightSlow()

	if (slow <= 0 or client:GetMoveType() == MOVETYPE_NOCLIP) then
		return
	end

	local multiplier = math.max(1 - slow / 100, 0)

	mv:SetMaxSpeed(mv:GetMaxSpeed() * multiplier)
	mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * multiplier)
end
