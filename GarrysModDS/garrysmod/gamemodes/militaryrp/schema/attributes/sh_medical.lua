ATTRIBUTE.name = "Медицинские знания"
ATTRIBUTE.description = "Определяет, насколько быстро и эффективно вы лечите себя: бинты, медикаменты и первая помощь."
ATTRIBUTE.noStartBonus = true

-- ============================================================
--  Связка атрибута с медицинской системой.
--  Чем выше атрибут "medical", тем быстрее персонаж лечит СЕБЯ.
-- ============================================================

ix.medical = ix.medical or {}
ix.medical.attribute = "medical" -- ключ атрибута (имя файла без sh_)

ix.medical.selfHeal = ix.medical.selfHeal or {
	-- Бонус при максимальном атрибуте: 1.0 = +100% (то есть лечение в 2 раза быстрее).
	maxBonus = 1.0,
	-- Нижний предел времени лечения (секунды), чтобы не было мгновенных бинтов.
	minTime = 0.75,
	-- Сколько очков атрибута даётся за одно успешное лечение.
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

-- Множитель скорости самолечения: 1.0 (атрибут 0) ... 1 + maxBonus (атрибут максимум).
function ix.medical.GetSelfHealMultiplier(target)
	local char = GetChar(target)

	if (!char) then
		return 1
	end

	local maxValue = ix.config.Get("maxAttributes", 100)
	local fraction = math.Clamp(char:GetAttribute(ix.medical.attribute, 0) / maxValue, 0, 1)

	return 1 + fraction * ix.medical.selfHeal.maxBonus
end

-- Время лечения. Влияет только если лекарь лечит сам себя.
-- healer, target — игроки; baseTime — базовое время (сек).
function ix.medical.GetHealTime(healer, target, baseTime)
	if (healer != target) then
		return baseTime
	end

	return math.max(ix.medical.selfHeal.minTime, baseTime / ix.medical.GetSelfHealMultiplier(healer))
end

-- Количество восстановленного HP (если лечение идёт «за тик»/мгновенно). Только для самолечения.
function ix.medical.GetHealAmount(healer, target, baseAmount)
	if (healer != target) then
		return baseAmount
	end

	return baseAmount * ix.medical.GetSelfHealMultiplier(healer)
end

-- Прокачка атрибута за успешное лечение (вызывать на сервере).
function ix.medical.TrainOnHeal(healer, mul)
	if (!SERVER) then return end

	local char = GetChar(healer)

	if (char) then
		char:UpdateAttrib(ix.medical.attribute, ix.medical.selfHeal.trainGain * (mul or 1))
	end
end