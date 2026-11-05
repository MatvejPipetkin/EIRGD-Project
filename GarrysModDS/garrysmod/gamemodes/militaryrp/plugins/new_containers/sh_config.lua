--[[
	=====================================================================
	КОНФИГ СИСТЕМЫ КОНТЕЙНЕРОВ
	=====================================================================

	Как это работает:
	  1. Игрок нажимает E на контейнер.
	  2. Запускается простое действие (см. ix.container.interactions ниже):
	     игрок проигрывает жест, внизу появляется полоска прогресса,
	     пока он стоит рядом и смотрит на контейнер.
	  3. Когда действие закончилось, контейнер "открывается": играет звук,
	     (если есть) анимация модели, и открывается инвентарь.
	  4. Когда игрок закрывает инвентарь, контейнер закрывается (звук/анимация).
	  Если игрок отвернулся, отошёл или сдвинулся слишком далеко - действие
	  прерывается и инвентарь не открывается.

	Какое именно действие выполняется - определяет поле `interaction`
	у пропа в sh_definitions.lua. Всего 4 типа:

	  cabinet - открытие шкафа (двери: шкафы, холодильники, плиты, стиралки)
	  drawer  - выдвигание ящика (комоды, картотеки, тумбы, столы)
	  shelf   - взятие предмета со стеллажа (открытые полки, без дверей)
	  small   - открытие чего-то небольшого (ящик, коробка, чемодан, бак, касса)

	Любой параметр типа можно переопределить для конкретного пропа - просто
	добавьте такое же поле в его описание (см. sh_definitions.lua).

	Общие настройки, которые меняются прямо в игре (меню конфига Helix, вкладка
	"Containers"): containerSave, containerTimeScale.

	---------------------------------------------------------------------
	ПОЛЯ ТИПА ВЗАИМОДЕЙСТВИЯ
	---------------------------------------------------------------------
	name        Название типа (для администраторов и логов).
	text        Ключ фразы для полоски прогресса (см. languages/). Если ключа
	            нет - выводится как обычный текст.
	time        Сколько секунд длится действие. Умножается на containerTimeScale.
	distance    Максимальная дистанция до контейнера (в юнитах) во время действия.
	maxMove     Насколько далеко игрок может сместиться от места начала (юниты).
	            nil/false - не проверять.
	gesture     Анимация игрока (жест) - имя ACT_* строкой или число.
	            false - без жеста.
	material    Набор звуков из ix.container.materials (metal/wood/cardboard/plastic).
	sounds      Переопределение звуков: start / open / close / locked.
	            Значение: строка, список строк (выбирается случайная) или
	            false (звук отключён). Если ключа нет - берётся из material.
	soundLevel  Громкость звука (dB, как в Entity:EmitSound).
	closeDelay  Через сколько секунд после закрытия инвентаря контейнер
	            "закрывается" (звук + анимация).
	animation   Анимация самого пропа, если у модели есть такие sequence:
	            {open = "Open", close = "Close"}. Для моделей без анимаций - не нужно.
]]--

-- Тип по умолчанию для пропа, у которого `interaction` не указан или указан неверно.
ix.container.defaultInteraction = "small"

-- Генерирует список вида {"путь1.wav", "путь2.wav", ...}
local function Sounds(path, from, to)
	local list = {}

	for i = from, to do
		list[#list + 1] = path .. i .. ".wav"
	end

	return list
end

--[[
	Наборы звуков по материалу. Выбираются полем `material` у типа или у пропа.
	start - в момент начала действия (взялся за ручку, потянул)
	open  - в момент, когда контейнер открылся
	close - когда контейнер закрыли
]]--
ix.container.materials = {
	metal = {
		start = Sounds("physics/metal/metal_solid_impact_soft", 1, 3),
		open = Sounds("physics/metal/metal_box_impact_soft", 1, 3),
		close = Sounds("physics/metal/metal_box_impact_hard", 1, 3)
	},
	wood = {
		start = Sounds("physics/wood/wood_plank_impact_soft", 1, 3),
		open = Sounds("physics/wood/wood_box_impact_soft", 1, 3),
		close = Sounds("physics/wood/wood_box_impact_hard", 1, 3)
	},
	cardboard = {
		start = Sounds("physics/cardboard/cardboard_box_impact_soft", 1, 3),
		open = Sounds("physics/cardboard/cardboard_box_impact_soft", 4, 6),
		close = Sounds("physics/cardboard/cardboard_box_impact_soft", 1, 3)
	},
	plastic = {
		start = Sounds("physics/plastic/plastic_box_impact_soft", 1, 4),
		open = Sounds("physics/plastic/plastic_box_impact_soft", 1, 4),
		close = Sounds("physics/plastic/plastic_box_impact_hard", 1, 4)
	}
}

--[[
	Четыре типа взаимодействия.
	Жесты (gesture) подобраны по смыслу; если на вашей модели игрока выглядит
	не так - поменяйте строку на любой другой ACT_GMOD_GESTURE_* / ACT_HL2MP_GESTURE_*.
]]--
ix.container.interactions = {
	-- ОТКРЫТИЕ ШКАФА: взяться за ручку, потянуть дверцу на себя.
	cabinet = {
		name = "Cabinet",
		text = "containerActionCabinet",
		time = 1.6,
		distance = 100,
		maxMove = 48,
		gesture = "ACT_GMOD_GESTURE_BECON",
		material = "metal",
		sounds = {
			start = "doors/door_latch1.wav",
			locked = "doors/default_locked.wav"
		},
		soundLevel = 65,
		closeDelay = 0.3
	},

	-- ВЫДВИГАНИЕ ЯЩИКА: наклониться и выдвинуть ящик.
	drawer = {
		name = "Drawer",
		text = "containerActionDrawer",
		time = 1.2,
		distance = 90,
		maxMove = 48,
		gesture = "ACT_GMOD_GESTURE_ITEM_DROP",
		material = "wood",
		sounds = {
			locked = "doors/default_locked.wav"
		},
		soundLevel = 60,
		closeDelay = 0.3
	},

	-- ВЗЯТИЕ СО СТЕЛЛАЖА: протянуть руку и взять предмет с полки.
	-- Дверей нет, поэтому звуков открытия/закрытия тоже нет - только шорох.
	shelf = {
		name = "Shelf",
		text = "containerActionShelf",
		time = 0.9,
		distance = 90,
		maxMove = 48,
		gesture = "ACT_GMOD_GESTURE_ITEM_PLACE",
		material = "cardboard",
		sounds = {
			open = false,
			close = false,
			locked = "doors/default_locked.wav"
		},
		soundLevel = 55,
		closeDelay = 0
	},

	-- ОТКРЫТИЕ ЧЕГО-ТО НЕБОЛЬШОГО: поднять крышку, откинуть клапан, открыть замок.
	small = {
		name = "Small container",
		text = "containerActionSmall",
		time = 0.7,
		distance = 90,
		maxMove = 48,
		gesture = "ACT_GMOD_GESTURE_ITEM_GIVE",
		material = "cardboard",
		sounds = {
			locked = "doors/default_locked.wav"
		},
		soundLevel = 60,
		closeDelay = 0.2
	}
}
