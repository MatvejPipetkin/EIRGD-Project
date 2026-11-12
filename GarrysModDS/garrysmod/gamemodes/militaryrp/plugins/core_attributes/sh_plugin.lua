PLUGIN.name = "Основные атрибуты (RU)"
PLUGIN.author = "Claude"
PLUGIN.description = "Русские названия и расширенные механики для стандартных атрибутов Helix: Сила (str), Стамина (stm), Выносливость (end)."

ix.coreattrs = ix.coreattrs or {}

-- ============================================================
--  Бонусы атрибутов (при значении = maxAttributes).
--  Если меняете числа здесь, обновите описания в attributes/*.lua.
-- ============================================================
ix.coreattrs.perks = ix.coreattrs.perks or {
	strength = {
		holdBase = 0.35,        -- с нулевой Силой руки поднимают 35% от maxHoldWeight, с максимальной 100%
		knockdownResist = 0.5   -- Выносливость цели на максимуме вдвое снижает шанс сбития с ног
	},
	stamina = {
		runSpeed = 0.25,        -- +25% к скорости бега
		recovery = 0.5,         -- +50% к восстановлению стамины
		jumpSave = 0.5          -- -50% к цене прыжка
	},
	endurance = {
		drainSave = 0.6,        -- -60% к расходу стамины при беге
		secondWind = 0.75       -- +75% к восстановлению при одышке (когда стамина упала в ноль)
	},
	training = {
		sprintSeconds = 10,     -- каждые N секунд непрерывного бега...
		sprintEnd = 0.02,       -- ...даёт столько опыта Выносливости
		sprintStm = 0.01,       -- ...и столько опыта Стамине
		jumpStm = 0.002,        -- опыт Стамине за прыжок
		knockdownStr = 0.05     -- опыт Силе за сбитого с ног противника
	}
}

-- ============================================================
--  Настройки сервера (вкладка "Основные атрибуты").
-- ============================================================
ix.config.Add("jumpStaminaCost", 8, "Сколько стамины тратит один прыжок (до учёта атрибута Стамина). 0 отключает механику.", nil, {
	data = {min = 0, max = 50},
	category = "Основные атрибуты"
})

ix.config.Add("strengthKnockdownChance", 0.2, "Шанс сбить противника с ног ударом кулака при максимальной Силе (0 отключает механику).", nil, {
	data = {min = 0, max = 1, decimals = 2},
	category = "Основные атрибуты"
})

ix.config.Add("strengthKnockdownTime", 4, "На сколько секунд кулак сбивает противника с ног.", nil, {
	data = {min = 1, max = 15},
	category = "Основные атрибуты"
})

ix.config.Add("enduranceDamageReduction", 0.12, "Какую долю входящего урона гасит Выносливость при максимальном значении (0 отключает механику; урон от падения не затрагивается).", nil, {
	data = {min = 0, max = 0.5, decimals = 2},
	category = "Основные атрибуты"
})

-- ============================================================
--  Множители. Вызывайте их и из других плагинов.
-- ============================================================

-- Принимает игрока или персонажа, возвращает персонажа (или nil).
local function GetChar(target)
	if (istable(target) and target.GetAttribute) then
		return target
	end

	if (IsValid(target) and target:IsPlayer()) then
		return target:GetCharacter()
	end
end

-- Доля атрибута от максимума: 0.0 ... 1.0
function ix.coreattrs.GetFraction(target, key)
	local char = GetChar(target)

	if (!char) then
		return 0
	end

	local maxValue = ix.config.Get("maxAttributes", 100)
	return math.Clamp(char:GetAttribute(key, 0) / maxValue, 0, 1)
end

-- Максимальный вес предмета, который игрок может держать в руках (Сила).
function ix.coreattrs.GetHoldLimit(target)
	local base = ix.coreattrs.perks.strength.holdBase
	local fraction = ix.coreattrs.GetFraction(target, "str")

	return ix.config.Get("maxHoldWeight", 100) * (base + (1 - base) * fraction)
end

-- Шанс сбить противника с ног (Сила атакующего против Выносливости цели).
function ix.coreattrs.GetKnockdownChance(attacker, victim)
	local chance = ix.config.Get("strengthKnockdownChance", 0.2) * ix.coreattrs.GetFraction(attacker, "str")

	if (victim) then
		chance = chance * (1 - ix.coreattrs.GetFraction(victim, "end") * ix.coreattrs.perks.strength.knockdownResist)
	end

	return chance
end

-- Цена прыжка в стамине (Стамина).
function ix.coreattrs.GetJumpCost(target)
	return ix.config.Get("jumpStaminaCost", 8) * (1 - ix.coreattrs.GetFraction(target, "stm") * ix.coreattrs.perks.stamina.jumpSave)
end

-- Множитель скорости бега (Стамина).
function ix.coreattrs.GetRunSpeedMultiplier(target)
	return 1 + ix.coreattrs.GetFraction(target, "stm") * ix.coreattrs.perks.stamina.runSpeed
end

-- Доля входящего урона, которую гасит Выносливость.
function ix.coreattrs.GetDamageReduction(target)
	return ix.coreattrs.GetFraction(target, "end") * ix.config.Get("enduranceDamageReduction", 0.12)
end

-- Тот же критерий бега, что и в плагине стамины Helix.
local function IsSprinting(client)
	return client:KeyDown(IN_SPEED)
		and client:GetVelocity():LengthSqr() >= (ix.config.Get("walkSpeed") ^ 2)
		and client:OnGround()
end

-- ============================================================
--  Стамина и Выносливость: расход и восстановление
-- ============================================================

-- Вызывается плагином стамины каждые 0.25 с. Здесь мы заменяем формулу ядра:
-- в ней при Выносливости 100 расход при беге обнулялся полностью.
function PLUGIN:AdjustStaminaOffset(client, offset)
	local perks = ix.coreattrs.perks
	local bSprinting = IsSprinting(client)

	if (bSprinting) then
		offset = -ix.config.Get("staminaDrain", 1) * (1 - ix.coreattrs.GetFraction(client, "end") * perks.endurance.drainSave)

		-- Связка с атрибутом "athletics" (sh_athletics.lua), если он подключён.
		if (ix.military and ix.military.GetStaminaDrainMultiplier) then
			offset = offset * ix.military.GetStaminaDrainMultiplier(client)
		end
	else
		local mul = 1 + ix.coreattrs.GetFraction(client, "stm") * perks.stamina.recovery

		-- Второе дыхание: после полного истощения Выносливость ускоряет возвращение сил.
		if (client:GetNetVar("brth", false)) then
			mul = mul * (1 + ix.coreattrs.GetFraction(client, "end") * perks.endurance.secondWind)
		end

		if (ix.military and ix.military.GetStaminaRecoveryMultiplier) then
			mul = mul * ix.military.GetStaminaRecoveryMultiplier(client)
		end

		offset = offset * mul
	end

	-- Тренировка: непрерывный бег понемногу качает Выносливость и Стамину.
	if (SERVER and bSprinting) then
		local char = client:GetCharacter()

		if (char) then
			client.ixSprintTime = (client.ixSprintTime or 0) + 0.25

			if (client.ixSprintTime >= perks.training.sprintSeconds) then
				client.ixSprintTime = 0
				char:UpdateAttrib("end", perks.training.sprintEnd)
				char:UpdateAttrib("stm", perks.training.sprintStm)
			end
		end
	end

	return offset
end

-- ============================================================
--  Стамина: скорость бега и цена прыжка
-- ============================================================
function PLUGIN:SetupMove(client, mv, cmd)
	if (!client:GetCharacter()) then
		return
	end

	-- Скорость бега. Работает через SetupMove, поэтому действует сразу при изменении атрибута.
	if (mv:KeyDown(IN_SPEED) and !client:GetNetVar("brth", false) and client:GetMoveType() == MOVETYPE_WALK) then
		local mul = ix.coreattrs.GetRunSpeedMultiplier(client)

		if (mul != 1) then
			mv:SetMaxSpeed(mv:GetMaxSpeed() * mul)
			mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * mul)
		end
	end

	-- Прыжок тратит стамину. Без запаса сил прыгнуть нельзя.
	if (mv:KeyPressed(IN_JUMP) and client:OnGround()) then
		local cost = ix.coreattrs.GetJumpCost(client)

		if (cost > 0) then
			if (client:GetLocalVar("stm", 100) < cost) then
				mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP)))
			elseif (SERVER and client.ConsumeStamina) then
				client:ConsumeStamina(cost)
				client:GetCharacter():UpdateAttrib("stm", ix.coreattrs.perks.training.jumpStm)
			end
		end
	end
end

ix.util.Include("sv_plugin.lua")
