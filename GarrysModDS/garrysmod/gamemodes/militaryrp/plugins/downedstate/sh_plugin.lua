local PLUGIN = PLUGIN

PLUGIN.name = "Downed State"
PLUGIN.author = "Claude"
PLUGIN.description = "Критическое состояние: при HP ниже порога игрок падает в рэгдолл и обязан выбрать смерть или ожидание помощи. Пока выбор не сделан (или выбрана смерть), другие игроки помочь не могут. Выстрел в голову и взрывы убивают мгновенно, без критического состояния."

local phrases = {
	downedState = "Критическое состояние",

	downTitle = "ВЫ БЕЗ СОЗНАНИЯ",
	downChoiceHint = "Выберите: умереть или ждать помощи. Осталось: %s с.",
	downWaitHint = "Вы ждёте помощи. Смерть наступит через %s с.",
	downRescuedHint = "Вам оказывают медицинскую помощь...",
	downBtnDie = "УМЕРЕТЬ",
	downBtnDieConfirm = "ТОЧНО?",
	downBtnWait = "ЖДАТЬ ПОМОЩИ",

	downReviving = "Оказание медицинской помощи...",
	downReviveHint = "Удерживайте [%s], чтобы оказать помощь",
	downReviveHintCrouch = "Присядьте и удерживайте [%s], чтобы оказать помощь",
	downRevived = "Вас привели в чувство.",
	downRevivedOther = "Вы привели в чувство: %s.",
	downNeedItem = "Для оказания помощи нужен предмет: %s.",
	downNotWaiting = "Пострадавший ещё не запросил помощь.",

	cfgDownHealth = "Порог критического состояния (HP)",
	cfgDownChoiceTime = "Время на выбор (сек)",
	cfgDownWaitTime = "Время ожидания помощи (сек)",
	cfgDownReviveTime = "Время оказания помощи (сек)",
	cfgDownReviveHealth = "Здоровье после помощи",
	cfgDownReviveDistance = "Дистанция оказания помощи",
	cfgDownRequireCrouch = "Помогать только сидя",
	cfgDownLethalToDown = "Смертельный урон вводит в критическое состояние",
	cfgDownKillOnHeadshot = "Мгновенная смерть от выстрела в голову",
	cfgDownKillOnExplosion = "Мгновенная смерть от взрыва",
	cfgDownInvulnerable = "Неуязвимость в критическом состоянии",
	cfgDownReviveItem = "Предмет для оказания помощи"
}

ix.lang.AddTable("russian", phrases)
ix.lang.AddTable("english", phrases)

ix.config.Add("downHealth", 5, "Если здоровье игрока опускается ниже этого значения — он падает в критическое состояние.", nil, {
	data = {min = 2, max = 50},
	category = "downedState"
})

ix.config.Add("downChoiceTime", 30, "Сколько секунд у игрока на обязательный выбор: умереть или ждать помощи. Пока выбор не сделан, помочь ему нельзя. Не успел выбрать — умирает.", nil, {
	data = {min = 5, max = 300},
	category = "downedState"
})

ix.config.Add("downWaitTime", 60, "Сколько секунд игрок ждёт помощи после выбора. Если помощь не пришла — он умирает.", nil, {
	data = {min = 5, max = 900},
	category = "downedState"
})

ix.config.Add("downReviveTime", 8, "Сколько секунд нужно удерживать кнопку использования (E), чтобы поднять игрока.", nil, {
	data = {min = 1, max = 60},
	category = "downedState"
})

ix.config.Add("downReviveHealth", 15, "Сколько здоровья у игрока после оказания помощи (не меньше порога критического состояния).", nil, {
	data = {min = 1, max = 100},
	category = "downedState"
})

ix.config.Add("downReviveDistance", 90, "Максимальная дистанция, с которой можно оказать помощь.", nil, {
	data = {min = 40, max = 200},
	category = "downedState"
})

ix.config.Add("downRequireCrouch", true, "Помогающий должен сидеть, чтобы оказывать помощь.", nil, {
	category = "downedState"
})

ix.config.Add("downLethalToDown", true, "Урон, который должен был убить игрока, вместо этого оставляет ему 1 HP и вводит в критическое состояние.", nil, {
	category = "downedState"
})

ix.config.Add("downKillOnHeadshot", true, "Смертельный урон в голову убивает игрока сразу, без критического состояния. Лежащего в критическом состоянии любое попадание в голову тоже добивает.", nil, {
	category = "downedState"
})

ix.config.Add("downKillOnExplosion", true, "Смертельный урон от взрыва (граната, РПГ, бочка и т. п.) убивает игрока сразу, без критического состояния. Лежащего в критическом состоянии любой взрыв тоже добивает.", nil, {
	category = "downedState"
})

ix.config.Add("downInvulnerable", true, "Игрок в критическом состоянии не получает урон (добивание невозможно).", nil, {
	category = "downedState"
})

ix.config.Add("downReviveItem", "", "uniqueID предмета, который тратится на оказание помощи (например, medkit). Пусто — предмет не нужен.", nil, {
	category = "downedState"
})

local playerMeta = FindMetaTable("Player")

-- Находится ли игрок в критическом состоянии (доступно и на клиенте, и на сервере).
function playerMeta:IsDowned()
	return self:GetNetVar("ixDowned", false) == true
end

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
