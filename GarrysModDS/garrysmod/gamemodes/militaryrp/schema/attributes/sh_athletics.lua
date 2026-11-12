ATTRIBUTE.name = "Физическая подготовка"
ATTRIBUTE.description = "Выносливость и сила солдата: расход и восстановление стамины при марш-бросках и в бою."
ATTRIBUTE.noStartBonus = true

-- ============================================================
--  Связка атрибута "athletics" с военной системой.
--  Функции возвращают множители; вызывайте их из оружия/техники/рации и т.д.
-- ============================================================

ix.military = ix.military or {}
ix.military.athletics = ix.military.athletics or {
	attribute = "athletics", -- ключ атрибута (имя файла без sh_)
	-- Сколько очков атрибута даётся за одно успешное действие.
	trainGain = 0.02
}

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
local function GetFraction(target)
	local char = GetChar(target)

	if (!char) then
		return 0
	end

	local maxValue = ix.config.Get("maxAttributes", 100)
	return math.Clamp(char:GetAttribute(ix.military.athletics.attribute, 0) / maxValue, 0, 1)
end

-- Множитель расхода стамины (меньше = дольше бегаете). До -40%.
function ix.military.GetStaminaDrainMultiplier(target)
	return 1 - GetFraction(target) * 0.4
end

-- Множитель восстановления стамины. До +60%.
function ix.military.GetStaminaRecoveryMultiplier(target)
	return 1 + GetFraction(target) * 0.6
end

-- Прокачка атрибута за успешное действие (вызывать на сервере).
function ix.military.TrainAthletics(target, mul)
	if (!SERVER) then return end

	local char = GetChar(target)

	if (char) then
		char:UpdateAttrib(ix.military.athletics.attribute, ix.military.athletics.trainGain * (mul or 1))
	end
end
