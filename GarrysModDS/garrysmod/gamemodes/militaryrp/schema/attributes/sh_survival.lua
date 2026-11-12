ATTRIBUTE.name = "Выживание"
ATTRIBUTE.description = "Способность держаться в полевых условиях: голод, жажда, холод и истощение."
ATTRIBUTE.noStartBonus = true

-- ============================================================
--  Связка атрибута "survival" с военной системой.
--  Функции возвращают множители; вызывайте их из оружия/техники/рации и т.д.
-- ============================================================

ix.military = ix.military or {}
ix.military.survival = ix.military.survival or {
	attribute = "survival", -- ключ атрибута (имя файла без sh_)
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
	return math.Clamp(char:GetAttribute(ix.military.survival.attribute, 0) / maxValue, 0, 1)
end

-- Множитель расхода голода/жажды. До -40%.
function ix.military.GetNeedsDrainMultiplier(target)
	return 1 - GetFraction(target) * 0.4
end

-- Множитель урона от холода/непогоды. До -50%.
function ix.military.GetColdDamageMultiplier(target)
	return 1 - GetFraction(target) * 0.5
end

-- Прокачка атрибута за успешное действие (вызывать на сервере).
function ix.military.TrainSurvival(target, mul)
	if (!SERVER) then return end

	local char = GetChar(target)

	if (char) then
		char:UpdateAttrib(ix.military.survival.attribute, ix.military.survival.trainGain * (mul or 1))
	end
end
