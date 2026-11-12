PLUGIN.name = "Литература и обучение"
PLUGIN.author = "Claude"
PLUGIN.description = "Книги, газеты и документы прокачивают атрибуты. Новые атрибуты (ловкость, скрытность, эрудиция) дают пассивные бонусы."

ix.readables = ix.readables or {}

-- ============================================================
--  Бонусы атрибутов (при атрибуте = maxAttributes).
--  Если меняете числа здесь, обновите описания в attributes/*.lua.
-- ============================================================
ix.readables.perks = ix.readables.perks or {
	agility = {
		speed = 0.12,      -- +12% к скорости ходьбы/бега
		jump = 0.15,       -- +15% к высоте прыжка
		fallDamage = 0.5   -- -50% урона от падения
	},
	stealth = {
		crouchSpeed = 0.35, -- +35% к скорости в приседе
		silentAt = 0.5      -- с этой доли атрибута шаги в приседе/медленной ходьбе (ALT) бесшумны
	},
	erudition = {
		readTime = 0.4,    -- -40% ко времени чтения
		xpBonus = 0.3      -- +30% к опыту за прочитанное
	}
}

-- ============================================================
--  Настройки сервера (вкладка "Чтение" в конфиге Helix).
-- ============================================================
ix.config.Add("readXPScale", 1, "Общий множитель опыта атрибутов за чтение книг, газет и документов.", nil, {
	data = {min = 0, max = 10, decimals = 2},
	category = "Чтение"
})

ix.config.Add("readTimeScale", 1, "Общий множитель времени чтения.", nil, {
	data = {min = 0.1, max = 5, decimals = 2},
	category = "Чтение"
})

ix.config.Add("rereadFactor", 0.25, "Какую долю опыта получает персонаж при повторном прочтении того же материала.", nil, {
	data = {min = 0, max = 1, decimals = 2},
	category = "Чтение"
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
function ix.readables.GetFraction(target, key)
	local char = GetChar(target)

	if (!char) then
		return 0
	end

	local maxValue = ix.config.Get("maxAttributes", 100)
	return math.Clamp(char:GetAttribute(key, 0) / maxValue, 0, 1)
end

-- Множитель времени чтения (Эрудиция).
function ix.readables.GetReadTimeMultiplier(target)
	return 1 - ix.readables.GetFraction(target, "erudition") * ix.readables.perks.erudition.readTime
end

-- Множитель опыта за чтение (Эрудиция).
function ix.readables.GetXPMultiplier(target)
	return 1 + ix.readables.GetFraction(target, "erudition") * ix.readables.perks.erudition.xpBonus
end

-- Множитель скорости передвижения (Ловкость + Скрытность в приседе).
function ix.readables.GetSpeedMultiplier(target, bCrouching)
	local perks = ix.readables.perks
	local mul = 1 + ix.readables.GetFraction(target, "agility") * perks.agility.speed

	if (bCrouching) then
		mul = mul * (1 + ix.readables.GetFraction(target, "stealth") * perks.stealth.crouchSpeed)
	end

	return mul
end

-- Множитель высоты прыжка (Ловкость).
function ix.readables.GetJumpMultiplier(target)
	return 1 + ix.readables.GetFraction(target, "agility") * ix.readables.perks.agility.jump
end

-- Множитель урона от падения (Ловкость).
function ix.readables.GetFallDamageMultiplier(target)
	return 1 - ix.readables.GetFraction(target, "agility") * ix.readables.perks.agility.fallDamage
end

-- Бесшумные шаги (Скрытность).
function ix.readables.IsSilentStep(client)
	if (ix.readables.GetFraction(client, "stealth") < ix.readables.perks.stealth.silentAt) then
		return false
	end

	return client:Crouching() or client:KeyDown(IN_WALK)
end

-- ============================================================
--  Хуки
-- ============================================================

-- Скорость передвижения. Работает через SetupMove, поэтому не конфликтует
-- со стаминой Helix, которая сама переключает run/walk speed.
function PLUGIN:SetupMove(client, mv, cmd)
	if (client:GetMoveType() != MOVETYPE_WALK or !client:GetCharacter()) then
		return
	end

	local mul = ix.readables.GetSpeedMultiplier(client, mv:KeyDown(IN_DUCK))

	if (mul == 1) then
		return
	end

	mv:SetMaxSpeed(mv:GetMaxSpeed() * mul)
	mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * mul)
end

function PLUGIN:PlayerFootstep(client, position, foot, soundName, volume)
	if (ix.readables.IsSilentStep(client)) then
		return true
	end
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
