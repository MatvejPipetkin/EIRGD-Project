--[[
	КОНФИГ МЕДИЦИНЫ

	limbs      — конечности: свои HP, множитель урона по здоровью (scale), хитгруппы, зона на силуэте (rect).
	conditions — состояния: ранения (injury), болезни (disease), эффекты (buff).
	meds       — медикаменты. Предметы-медикаменты генерируются из этого списка (items/medical/sh_<id>.lua).

	Поля состояния:
		name, desc, kind, icon (файл из materials/medical/icons), color
		perLimb   — привязано к конечности (кровотечение, перелом, ожог, заражение раны)
		hps / lps — урон в секунду по общему здоровью / по HP своей конечности
		duration  — через сколько секунд проходит само (нет поля — до лечения)
		speed     — множитель скорости; noSprint / noJump — запреты
		legSpeed, legNoSprint, legNoJump — то же, но только если состояние на ноге; armSway — тряска прицела при ране руки
		progress  — {to = "id", after = секунды, chance = 0..1}: шанс перейти в другое состояние, если не лечить
		hungerDrain / thirstDrain — связь с hunger_system: сколько % шкалы сытости / воды состояние отнимает за секунду
		            (для сравнения: без болезни шкала сама тратится на ~0.016 %/с)
		courses   — КУРС ЛЕЧЕНИЯ: сколько применений препарата силы 1 нужно, чтобы вылечить. Каждое применение даёт прогресс
		            (1/courses), а пока курс не пройден, состояние ослабевает (см. treatment.ease). Без этого поля состояние
		            лечится сразу, одним применением (так сделаны кровотечения, сотрясение и контузия)
		onset     — {hunger = -10, thirst = -6, text = "..."}: разовая потеря % сытости/воды в момент заболевания (рвота и т.п.)
		fx        — экранные эффекты: blur (0..1), vignette (0..1), tint = {r, g, b, a}
		cough     — {interval = секунды}: периодический кашель

	Поля медикамента:
		target   — "limb" (применяется на часть тела, перетаскиванием на силуэт) или "self" (принимается целиком)
		groups   — на какие группы конечностей можно применять: "head", "torso", "arm", "leg"
		cures    — {id = true}: полностью убирает состояние
		downgrade— {id = "другое id"}: заменяет состояние на более лёгкое
		reduce   — {id = 0.5}: сокращает оставшееся время болезни (множитель)
		heal     — сколько HP возвращает конечности;  healHealth — сколько общего здоровья
		buff     — {id = "analgesia", duration = сек}: накладывает эффект (duration — необязательно, иначе берётся из состояния)
		uses     — сколько раз можно применить;  time — длительность применения (сек)
		procedure — id процедуры из config.procedures: вместо ожидания по шкале открывается мини-игра (шина, повязка, швы...).
		           Без этого поля препарат применяется сразу, как раньше (таблетки, аптечки, мази и прочие базовые вещи)
		potency  — сила препарата в курсе лечения (по умолчанию 1): 2 — одно применение даёт вдвое больше прогресса.
		           У «грязных» препаратов умножается на power
		thirst   — сколько % шкалы воды возвращает препарат (капельница, регидрон); у «грязных» умножается на power.
		           Препарат с thirst можно применить и без болезни, если игрок хочет пить
		dirty    — «грязный» медикамент (нестерильный, кустарный, просроченный). Поля:
			power — доля эффекта, которая сохраняется (0.5 = вдвое слабее: лечение HP, здоровье, длительность баффа, сокращение болезни)
			cure  — шанс, что каждое состояние из cures/downgrade вообще будет вылечено (иначе препарат тратится впустую)
			risks — {id состояния = шанс}: осложнения. Каждый шанс бросается отдельно, болезнь проявится не сразу
			        (через dirtyDelay секунд). Для состояний «на конечность» (infection) берётся та же часть тела.
]]

ix.medical = ix.medical or {}

local C = Color

ix.medical.config = {
	tickInterval = 2, -- как часто обрабатываются кровотечения и болезни (сек)
	saveInterval = 30, -- как часто сохраняются данные (сек)
	resetOnDeath = true, -- после смерти все конечности и состояния сбрасываются
	minSpeed = 0.35, -- ниже этого множителя скорость не падает
	maxIcons = 14, -- максимум плиток состояний в интерфейсе
	showCures = true, -- показывать в подсказке состояния, чем оно лечится

	-- курс лечения (поле courses у состояния, potency у препарата)
	treatment = {
		ease = 0.6 -- насколько полный прогресс ослабляет болезнь: урон, расход воды/сытости, замедление, шанс осложнения (0.6 = на 60%)
	},

	-- «грязные» медикаменты (поле dirty у препарата)
	dirtyDelay = {30, 120}, -- через сколько секунд после применения проявляется осложнение (мин, макс)
	dirtyRiskScale = 1, -- множитель всех шансов осложнений (0 — осложнений нет, 2 — вдвое чаще)

	-- уроны, шансы
	damage = {
		bleedMask = bit.bor(DMG_BULLET, DMG_BUCKSHOT, DMG_SLASH, DMG_BLAST),
		bleedBase = 0.10, -- базовый шанс кровотечения от одного попадания
		bleedPerDamage = 0.012, -- + за каждую единицу урона
		heavyDamage = 25, -- от этого урона по конечности кровотечение сильное
		heavyChance = 0.15, -- шанс сильного кровотечения от меньшего урона
		fractureFall = 15, -- падение с таким уроном по ногам может сломать ногу
		fractureBlunt = 15, -- удар/давление с таким уроном по рукам и ногам
		concussion = 15, -- урон по голове для шанса сотрясения
		contusion = 10 -- урон взрывом для шанса контузии
	},

	-- случайные заболевания (раз в interval секунд у каждого игрока шанс chance; pool — веса)
	ambient = {
		enabled = true,
		interval = 600,
		chance = 0.04,
		pool = {cold = 5, flu = 2, food_poison = 1}
	},

	-- мини-игры лечения (препарат с полем procedure = "id"). Правила и качество:
	-- каждая ошибка снижает качество; от качества зависят сила препарата, шанс сработать и риск осложнений.
	procedureRules = {
		enabled = true, -- false: вернуться к обычному ожиданию по шкале
		maxMistakes = 6, -- столько ошибок — процедура провалена, материал израсходован впустую
		mistakePenalty = 0.15, -- сколько качества отнимает каждая ошибка
		minQuality = 0.25 -- качество не падает ниже (если процедура не провалена)
	},

	--[[
		Шаги процедуры (u: 0..1 сверху вниз по конечности, v: -1..1 слева направо):
			hold    {label, u, v, time, mark = "pad"|"band"|"strap"|"board", radius}
			tension {label, zone = {от, до}, speed}
			align   {label, hits, width, speed}
			stitch  {label, count, span, window}
		wound = true — на конечности рисуется рана, которая бледнеет по мере лечения.
	]]
	procedures = {
		wrap = {title = "НАЛОЖЕНИЕ ПОВЯЗКИ", wound = true, color = C(235, 235, 225), steps = {
			{type = "hold", label = "Прижмите повязку к ране", u = 0.5, v = 0, time = 1.2, mark = "pad"},
			{type = "hold", label = "Первый виток", u = 0.36, v = 0, time = 0.9, mark = "band"},
			{type = "hold", label = "Второй виток", u = 0.5, v = 0, time = 0.9, mark = "band"},
			{type = "hold", label = "Третий виток", u = 0.64, v = 0, time = 0.9, mark = "band"}
		}},
		hemostatic = {title = "ГЕМОСТАТИЧЕСКАЯ ПОВЯЗКА", wound = true, color = C(225, 215, 190), steps = {
			{type = "hold", label = "Заполните рану гемостатиком", u = 0.5, v = 0, time = 1.6, mark = "pad"},
			{type = "hold", label = "Прижмите и держите, пока кровь не остановится", u = 0.5, v = 0, time = 2.6, radius = 32},
			{type = "hold", label = "Закрепите повязку", u = 0.38, v = 0, time = 0.9, mark = "band"},
			{type = "hold", label = "Закрепите повязку", u = 0.62, v = 0, time = 0.9, mark = "band"}
		}},
		tourniquet = {title = "НАЛОЖЕНИЕ ЖГУТА", wound = true, color = C(70, 90, 70), steps = {
			{type = "hold", label = "Наложите жгут выше раны", u = 0.25, v = 0, time = 0.9, mark = "band"},
			{type = "tension", label = "Затяните, пока кровь не остановится", zone = {0.55, 0.8}, speed = 0.45},
			{type = "hold", label = "Зафиксируйте застёжку", u = 0.25, v = 0, time = 0.7}
		}},
		splint = {title = "НАЛОЖЕНИЕ ШИНЫ", color = C(235, 235, 225), steps = {
			{type = "align", label = "Совместите отломки кости", hits = 1, width = 0.16, speed = 1.7},
			{type = "hold", label = "Приложите шину слева", u = 0.5, v = -0.95, time = 1.0, mark = "board", color = C(176, 130, 84)},
			{type = "hold", label = "Приложите шину справа", u = 0.5, v = 0.95, time = 1.0, mark = "board", color = C(176, 130, 84)},
			{type = "hold", label = "Привяжите шину выше перелома", u = 0.3, v = 0, time = 0.9, mark = "strap"},
			{type = "hold", label = "Привяжите шину у перелома", u = 0.5, v = 0, time = 0.9, mark = "strap"},
			{type = "hold", label = "Привяжите шину ниже перелома", u = 0.7, v = 0, time = 0.9, mark = "strap"}
		}},
		cast = {title = "НАЛОЖЕНИЕ ГИПСА", color = C(240, 240, 245), steps = {
			{type = "align", label = "Совместите отломки кости", hits = 2, width = 0.14, speed = 1.9},
			{type = "hold", label = "Первый слой гипса", u = 0.2, v = 0, time = 0.9, mark = "band"},
			{type = "hold", label = "Второй слой гипса", u = 0.35, v = 0, time = 0.9, mark = "band"},
			{type = "hold", label = "Третий слой гипса", u = 0.5, v = 0, time = 0.9, mark = "band"},
			{type = "hold", label = "Четвёртый слой гипса", u = 0.65, v = 0, time = 0.9, mark = "band"},
			{type = "hold", label = "Последний слой гипса", u = 0.8, v = 0, time = 0.9, mark = "band"}
		}},
		suture = {title = "НАЛОЖЕНИЕ ШВОВ", wound = true, color = C(235, 235, 225), steps = {
			{type = "hold", label = "Обработайте края раны", u = 0.5, v = 0, time = 1.0, mark = "pad"},
			{type = "stitch", label = "Накладывайте швы в ритм", count = 5, span = 0.36, window = 1.15},
			{type = "hold", label = "Перевяжите шов", u = 0.5, v = 0, time = 0.9, mark = "band"}
		}},
		surgery = {title = "ХИРУРГИЧЕСКАЯ ОПЕРАЦИЯ", wound = true, maxTime = 180, color = C(225, 235, 235), steps = {
			{type = "hold", label = "Обработайте операционное поле", u = 0.5, v = 0, time = 1.2, mark = "pad"},
			{type = "hold", label = "Раскройте рану зажимами", u = 0.42, v = 0, time = 1.5, radius = 28},
			{type = "hold", label = "Остановите кровотечение", u = 0.58, v = 0, time = 1.5, radius = 28},
			{type = "stitch", label = "Зашейте рану, швы в ритм", count = 7, span = 0.4, window = 1.0},
			{type = "hold", label = "Наложите повязку", u = 0.5, v = 0, time = 1.0, mark = "band"}
		}},
		disinfect = {title = "ОБРАБОТКА РАНЫ", wound = true, color = C(210, 225, 235), steps = {
			{type = "hold", label = "Промойте рану", u = 0.5, v = 0, time = 1.0, radius = 30},
			{type = "hold", label = "Обработайте верхний край", u = 0.4, v = 0, time = 0.8},
			{type = "hold", label = "Обработайте нижний край", u = 0.6, v = 0, time = 0.8}
		}},
		gel = {title = "ЛЕЧЕНИЕ ОЖОГА", wound = true, color = C(150, 215, 235), steps = {
			{type = "hold", label = "Нанесите гель на ожог", u = 0.5, v = 0, time = 1.0, mark = "pad", radius = 28},
			{type = "hold", label = "Распределите гель выше", u = 0.4, v = 0, time = 0.8},
			{type = "hold", label = "Распределите гель ниже", u = 0.6, v = 0, time = 0.8}
		}}
	},

	limbs = {
		{id = "head", name = "Голова", short = "ГОЛОВА", group = "head", maxHP = 40, scale = 2.0, weight = 0.05, vital = true,
			hitgroups = {HITGROUP_HEAD}, rect = {74, 6, 52, 64}},
		{id = "chest", name = "Грудь", short = "ГРУДЬ", group = "torso", maxHP = 100, scale = 1.0, weight = 0.25, vital = true,
			hitgroups = {HITGROUP_CHEST}, rect = {56, 76, 88, 96}},
		{id = "stomach", name = "Живот", short = "ЖИВОТ", group = "torso", maxHP = 80, scale = 0.9, weight = 0.15,
			hitgroups = {HITGROUP_STOMACH}, rect = {66, 172, 68, 68}},
		{id = "left_arm", name = "Левая рука", short = "Л. РУКА", group = "arm", maxHP = 60, scale = 0.7, weight = 0.10,
			hitgroups = {HITGROUP_LEFTARM}, rect = {12, 80, 52, 166}},
		{id = "right_arm", name = "Правая рука", short = "П. РУКА", group = "arm", maxHP = 60, scale = 0.7, weight = 0.10,
			hitgroups = {HITGROUP_RIGHTARM}, rect = {136, 80, 52, 166}},
		{id = "left_leg", name = "Левая нога", short = "Л. НОГА", group = "leg", maxHP = 70, scale = 0.6, weight = 0.175,
			hitgroups = {HITGROUP_LEFTLEG}, rect = {62, 240, 39, 154}},
		{id = "right_leg", name = "Правая нога", short = "П. НОГА", group = "leg", maxHP = 70, scale = 0.6, weight = 0.175,
			hitgroups = {HITGROUP_RIGHTLEG}, rect = {99, 240, 39, 154}}
	},

	conditions = {
		-- ===== РАНЕНИЯ =====
		bleed_light = {name = "Кровотечение", kind = "injury", icon = "drop", color = C(225, 70, 70), perLimb = true,
			desc = "Рана кровоточит. Остановите кровь повязкой, иначе возможно заражение.",
			hps = 0.12, lps = 0.10, progress = {to = "infection", after = 180, chance = 0.35}, fx = {vignette = 0.2},
			thirstDrain = 0.008},
		bleed_heavy = {name = "Сильное кровотечение", kind = "injury", icon = "drop", color = C(255, 35, 35), perLimb = true,
			desc = "Обильная кровопотеря. Нужен жгут или гемостатическая повязка.",
			hps = 0.45, lps = 0.30, progress = {to = "anemia", after = 60, chance = 1}, fx = {vignette = 0.55},
			thirstDrain = 0.03},
		fracture = {name = "Перелом", kind = "injury", courses = 2, icon = "bone", color = C(235, 200, 120), perLimb = true,
			desc = "Кость сломана. Нужна шина. Перелом ноги мешает бегать и прыгать, руки — сбивает прицел.",
			legSpeed = 0.6, legNoSprint = true, legNoJump = true, armSway = true},
		burn = {name = "Ожог", kind = "injury", courses = 3, icon = "flame", color = C(255, 140, 50), perLimb = true,
			desc = "Ожог причиняет боль и медленно разрушает ткани. Поможет противоожоговый гель.",
			hps = 0.05, lps = 0.08, progress = {to = "infection", after = 240, chance = 0.3}},
		concussion = {name = "Сотрясение мозга", kind = "injury", icon = "spiral", color = C(190, 150, 255),
			desc = "Темнеет в глазах, движения вялые. Проходит само или от нашатыря.",
			duration = 300, speed = 0.92, fx = {blur = 0.35}},
		contusion = {name = "Контузия", kind = "injury", icon = "wave", color = C(170, 170, 200),
			desc = "Звон в ушах и мутное зрение после взрыва.",
			duration = 150, speed = 0.85, fx = {blur = 0.55, tint = {110, 110, 130, 0.25}}},

		-- ===== ЭФФЕКТЫ =====
		analgesia = {name = "Обезболивание", kind = "buff", icon = "pill", color = C(120, 220, 140),
			desc = "Боль приглушена: переломы и повреждённые ноги не замедляют вас.", duration = 240},

		-- ===== БОЛЕЗНИ =====
		cold = {name = "Простуда", kind = "disease", courses = 2, icon = "virus", color = C(150, 200, 230),
			desc = "Насморк, кашель, слабость.", duration = 900, speed = 0.96, cough = {interval = 28}, thirstDrain = 0.004,
			progress = {to = "pneumonia", after = 600, chance = 0.12}},
		flu = {name = "Грипп", kind = "disease", courses = 3, icon = "virus", color = C(120, 220, 120),
			desc = "Жар и ломота во всём теле.", duration = 1500, speed = 0.9, hps = 0.03, cough = {interval = 22}, thirstDrain = 0.012, hungerDrain = 0.006,
			fx = {blur = 0.1, tint = {60, 140, 60, 0.12}}, progress = {to = "pneumonia", after = 700, chance = 0.25}},
		pneumonia = {name = "Пневмония", kind = "disease", courses = 4, icon = "lungs", color = C(210, 110, 140),
			desc = "Воспаление лёгких: тяжело дышать, невозможно бежать.", speed = 0.8, noSprint = true, hps = 0.12, thirstDrain = 0.01,
			cough = {interval = 12}, fx = {blur = 0.15}},
		food_poison = {name = "Пищевое отравление", kind = "disease", courses = 2, icon = "stomach", color = C(170, 200, 80),
			desc = "Тошнота и слабость, организм теряет воду и силы. Поможет активированный уголь.", duration = 420, speed = 0.92, hps = 0.2,
			hungerDrain = 0.02, thirstDrain = 0.03, onset = {hunger = -10, thirst = -6, text = "Вас вырвало."}},
		dysentery = {name = "Дизентерия", kind = "disease", courses = 3, icon = "stomach", color = C(200, 160, 70),
			desc = "Сильное обезвоживание. Лечится антибиотиками и регидратацией.", duration = 1200, speed = 0.9, hps = 0.15,
			hungerDrain = 0.02, thirstDrain = 0.045, onset = {thirst = -8, text = "Живот скрутило, организм стремительно теряет влагу."}},
		malaria = {name = "Малярия", kind = "disease", courses = 3, icon = "mosquito", color = C(230, 190, 90),
			desc = "Лихорадка волнами. Нужны противомалярийные препараты.", duration = 2400, speed = 0.88, hps = 0.04, thirstDrain = 0.01, hungerDrain = 0.005,
			fx = {blur = 0.12, tint = {200, 150, 60, 0.12}}},
		tetanus = {name = "Столбняк", kind = "disease", courses = 2, icon = "biohazard", color = C(220, 90, 90),
			desc = "Судороги мышц. Лечится сывороткой.", speed = 0.7, noJump = true, hps = 0.2, fx = {blur = 0.2}},
		infection = {name = "Заражение раны", kind = "disease", courses = 3, icon = "biohazard", color = C(170, 200, 60), perLimb = true,
			desc = "Рана воспалилась. Нужен антисептик или антибиотик.", lps = 0.12, hps = 0.03,
			progress = {to = "tetanus", after = 400, chance = 0.25}},
		hepatitis = {name = "Гепатит", kind = "disease", courses = 4, icon = "virus", color = C(230, 210, 80),
			desc = "Поражение печени. Нужен гепатопротектор.", speed = 0.95, hps = 0.05, hungerDrain = 0.01},
		heatstroke = {name = "Тепловой удар", kind = "disease", courses = 2, icon = "thermo", color = C(255, 120, 70),
			desc = "Перегрев организма, сильная жажда. Нужна регидратация.", duration = 300, speed = 0.8, hps = 0.2, thirstDrain = 0.08,
			fx = {blur = 0.2, tint = {255, 90, 40, 0.15}}},
		hypothermia = {name = "Переохлаждение", kind = "disease", courses = 1, icon = "snow", color = C(110, 180, 255),
			desc = "Дрожь и онемение. Согрейтесь термоодеялом.", duration = 600, speed = 0.85, hps = 0.1, hungerDrain = 0.03,
			fx = {tint = {60, 110, 255, 0.18}}},
		anemia = {name = "Анемия", kind = "disease", courses = 2, icon = "anemia", color = C(210, 80, 100),
			desc = "Последствия кровопотери: слабость, мутное зрение.", duration = 900, speed = 0.9, fx = {blur = 0.15}}
	},

	meds = {
		bandage = {name = "Бинт", procedure = "wrap", desc = "Останавливает слабое кровотечение, сильное — делает слабым.", model = "models/props_lab/box01a.mdl",
			width = 1, height = 1, target = "limb", time = 3, uses = 1,
			cures = {bleed_light = true}, downgrade = {bleed_heavy = "bleed_light"}},
		hemostatic = {name = "Гемостатическая повязка", procedure = "hemostatic", desc = "Останавливает любое кровотечение.", model = "models/props_lab/box01b.mdl",
			width = 1, height = 1, target = "limb", time = 4, uses = 1,
			cures = {bleed_light = true, bleed_heavy = true}},
		tourniquet = {name = "Жгут", procedure = "tourniquet", desc = "Пережимает конечность и останавливает кровь. Только руки и ноги.", model = "models/props_junk/cardboard_box002a.mdl",
			width = 1, height = 1, target = "limb", groups = {"arm", "leg"}, time = 3, uses = 1,
			cures = {bleed_light = true, bleed_heavy = true}},
		splint = {name = "Шина", procedure = "splint", desc = "Фиксирует сломанную руку или ногу.", model = "models/props_junk/cardboard_box001a.mdl",
			width = 1, height = 3, target = "limb", groups = {"arm", "leg"}, time = 6, uses = 1,
			cures = {fracture = true}},
		medkit = {name = "Аптечка", desc = "Восстанавливает здоровье конечности и останавливает кровь.", model = "models/items/healthkit.mdl",
			width = 2, height = 2, target = "limb", time = 5, uses = 3, heal = 45, healHealth = 20,
			cures = {bleed_light = true}, downgrade = {bleed_heavy = "bleed_light"}},
		painkiller = {name = "Обезболивающее", desc = "Приглушает боль на несколько минут.", model = "models/props_junk/garbage_plasticbottle002a.mdl",
			width = 1, height = 1, target = "self", time = 2, uses = 4, buff = {id = "analgesia"}},
		antibiotic = {name = "Антибиотик", desc = "Лечит заражение ран, пневмонию и дизентерию.", model = "models/props_junk/garbage_plasticbottle001a.mdl",
			width = 1, height = 1, target = "self", time = 2, uses = 4,
			cures = {infection = true, pneumonia = true, dysentery = true}},
		antipyretic = {name = "Жаропонижающее", desc = "Лечит простуду и ослабляет грипп.", model = "models/props_junk/garbage_plasticbottle003a.mdl",
			width = 1, height = 1, target = "self", time = 2, uses = 4,
			cures = {cold = true}, reduce = {flu = 0.5}},
		antiviral = {name = "Противовирусное", desc = "Лечит грипп.", model = "models/props_lab/jar01b.mdl",
			width = 1, height = 1, target = "self", time = 2, uses = 3, cures = {flu = true}},
		charcoal = {name = "Активированный уголь", desc = "Лечит пищевое отравление.", model = "models/props_junk/garbage_metalcan001a.mdl",
			width = 1, height = 1, target = "self", time = 2, uses = 3, cures = {food_poison = true}},
		rehydration = {name = "Регидрон", desc = "Лечит тепловой удар и ослабляет дизентерию и отравление.", model = "models/props_junk/garbage_glassbottle002a.mdl",
			width = 1, height = 1, target = "self", time = 3, uses = 3,
			thirst = 30, cures = {heatstroke = true}, reduce = {dysentery = 0.4, food_poison = 0.5}},
		antimalarial = {name = "Противомалярийное", desc = "Лечит малярию.", model = "models/props_lab/jar01a.mdl",
			width = 1, height = 1, target = "self", time = 2, uses = 3, cures = {malaria = true}},
		antiseptic = {name = "Антисептик", procedure = "disinfect", desc = "Обеззараживает рану и снимает заражение.", model = "models/props_junk/garbage_glassbottle001a.mdl",
			width = 1, height = 1, target = "limb", time = 3, uses = 3, cures = {infection = true}},
		burn_gel = {name = "Противоожоговый гель", procedure = "gel", desc = "Охлаждает и лечит ожоги.", model = "models/props_junk/garbage_milkcarton001a.mdl",
			width = 1, height = 1, target = "limb", time = 3, uses = 3, heal = 10, cures = {burn = true}},
		tetanus_serum = {name = "Противостолбнячная сыворотка", potency = 2, desc = "Лечит столбняк.", model = "models/healthvial.mdl",
			width = 1, height = 1, target = "self", time = 3, uses = 1, cures = {tetanus = true}},
		hepatoprotector = {name = "Гепатопротектор", desc = "Лечит гепатит.", model = "models/props_junk/glassbottle01a.mdl",
			width = 1, height = 1, target = "self", time = 2, uses = 4, cures = {hepatitis = true}},
		thermal_blanket = {name = "Термоодеяло", desc = "Согревает при переохлаждении.", model = "models/props_junk/cardboard_box003a.mdl",
			width = 2, height = 2, target = "self", time = 5, uses = 1, cures = {hypothermia = true}},
		blood_bag = {name = "Пакет крови", potency = 2, desc = "Восполняет кровопотерю и лечит анемию.", model = "models/props_junk/garbage_milkcarton002a.mdl",
			width = 1, height = 2, target = "self", time = 8, uses = 1, healHealth = 15, cures = {anemia = true}},
		ammonia = {name = "Нашатырный спирт", desc = "Приводит в чувство при сотрясении и контузии.", model = "models/props_junk/garbage_glassbottle003a.mdl",
			width = 1, height = 1, target = "self", time = 2, uses = 3, cures = {concussion = true, contusion = true}},
		-- ===== НОВЫЕ ПРЕПАРАТЫ =====
		field_dressing = {name = "Перевязочный пакет", procedure = "wrap", desc = "Стерильный пакет: останавливает кровотечение и немного затягивает рану. Хватает на два раза.", model = "models/weapons/w_package.mdl",
			width = 1, height = 1, target = "limb", time = 3, uses = 2, heal = 10,
			cures = {bleed_light = true}, downgrade = {bleed_heavy = "bleed_light"}},
		suture_kit = {name = "Набор для швов", procedure = "suture", desc = "Иглы, нить и зажимы: останавливает любое кровотечение и восстанавливает ткани. Применяется долго.", model = "models/props_c17/briefcase001a.mdl",
			width = 2, height = 1, target = "limb", time = 9, uses = 3, heal = 25,
			cures = {bleed_light = true, bleed_heavy = true}},
		surgeon_kit = {name = "Хирургический набор", procedure = "surgery", potency = 2, desc = "Полевая операционная в ящике: останавливает кровь, снимает заражение и сильно восстанавливает конечность.", model = "models/items/item_item_crate.mdl",
			width = 3, height = 2, target = "limb", time = 14, uses = 3, heal = 70,
			cures = {bleed_light = true, bleed_heavy = true, infection = true}},
		plaster_cast = {name = "Гипсовая повязка", procedure = "cast", potency = 2, desc = "Надёжно фиксирует перелом и помогает кости срастись. Только руки и ноги.", model = "models/props_junk/cardboard_box004a.mdl",
			width = 1, height = 2, target = "limb", groups = {"arm", "leg"}, time = 10, uses = 1, heal = 15,
			cures = {fracture = true}},
		ointment = {name = "Заживляющая мазь", desc = "Ускоряет заживление тканей. Кровь не останавливает.", model = "models/props_junk/garbage_metalcan002a.mdl",
			width = 1, height = 1, target = "limb", time = 3, uses = 4, heal = 20},
		morphine = {name = "Морфин", desc = "Сильное обезболивающее в шприц-тюбике. Действует втрое дольше обычного.", model = "models/items/flare.mdl",
			width = 1, height = 1, target = "self", time = 1, uses = 1, buff = {id = "analgesia", duration = 720}},
		adrenaline = {name = "Адреналин", desc = "Встряхивает организм: возвращает ясность после сотрясения и контузии и немного бодрит.", model = "models/items/battery.mdl",
			width = 1, height = 1, target = "self", time = 1, uses = 1, healHealth = 20,
			cures = {concussion = true, contusion = true}},
		saline = {name = "Физраствор", potency = 2, desc = "Капельница: лечит тепловой удар, облегчает отравление и дизентерию, прибавляет сил.", model = "models/props_junk/garbage_bag001a.mdl",
			width = 1, height = 2, target = "self", time = 7, uses = 1, healHealth = 10, thirst = 20,
			cures = {heatstroke = true}, reduce = {dysentery = 0.5, food_poison = 0.5}},
		plasma = {name = "Плазма крови", desc = "Восполняет кровопотерю и лечит анемию. Менее эффективна, чем целый пакет крови, зато занимает меньше места.", model = "models/props_junk/garbage_takeoutcarton001a.mdl",
			width = 1, height = 1, target = "self", time = 5, uses = 1, healHealth = 10, cures = {anemia = true}},
		interferon = {name = "Интерферон", potency = 1.5, desc = "Противовирусный порошок: лечит простуду и грипп.", model = "models/props_junk/garbage_coffeemug001a.mdl",
			width = 1, height = 1, target = "self", time = 2, uses = 2, cures = {cold = true, flu = true}},
		quinine = {name = "Хинин", desc = "Старое средство от малярии: не лечит полностью, но сильно сокращает болезнь.", model = "models/items/boxmrounds.mdl",
			width = 1, height = 1, target = "self", time = 2, uses = 4, reduce = {malaria = 0.35}},
		vitamins = {name = "Витаминный комплекс", desc = "Укрепляет иммунитет: сокращает простуду, грипп и анемию.", model = "models/items/boxsrounds.mdl",
			width = 1, height = 1, target = "self", time = 1, uses = 6, healHealth = 3,
			reduce = {cold = 0.7, flu = 0.8, anemia = 0.7}},
		heating_pad = {name = "Химическая грелка", desc = "Быстро согревает при переохлаждении. Компактнее термоодеяла.", model = "models/props_junk/popcan01a.mdl",
			width = 1, height = 1, target = "self", time = 4, uses = 1, cures = {hypothermia = true}},
		cold_compress = {name = "Охлаждающий пакет", desc = "Сбивает жар при тепловом ударе.", model = "models/props_lab/binderblue.mdl",
			width = 1, height = 1, target = "self", time = 3, uses = 2, cures = {heatstroke = true}},

		-- ===== «ГРЯЗНЫЕ» МЕДИКАМЕНТЫ: слабее, подводят, а иногда вредят =====
		dirty_bandage = {name = "Грязный бинт", procedure = "wrap", desc = "Серая от грязи тряпка. Кровь остановит не всегда, а рана может загноиться.", model = "models/props_junk/garbage_newspaper001a.mdl",
			width = 1, height = 1, target = "limb", time = 4, uses = 1,
			cures = {bleed_light = true}, downgrade = {bleed_heavy = "bleed_light"},
			dirty = {power = 0.5, cure = 0.6, risks = {infection = 0.18, tetanus = 0.04}}},
		dirty_tourniquet = {name = "Самодельный жгут", procedure = "tourniquet", desc = "Ремень и палка. Пережимает, но грязь и ржавчина в рану тоже попадают.", model = "models/props_junk/cardboard_box002b.mdl",
			width = 1, height = 1, target = "limb", groups = {"arm", "leg"}, time = 4, uses = 1,
			cures = {bleed_light = true, bleed_heavy = true},
			dirty = {power = 0.5, cure = 0.65, risks = {infection = 0.12, tetanus = 0.05}}},
		dirty_splint = {name = "Самодельная шина", procedure = "splint", desc = "Доски и верёвка. Фиксирует кое-как, зато ржавые гвозди и занозы в комплекте.", model = "models/props_junk/wood_crate001a.mdl",
			width = 1, height = 3, target = "limb", groups = {"arm", "leg"}, time = 8, uses = 1,
			cures = {fracture = true},
			dirty = {power = 0.5, cure = 0.6, risks = {tetanus = 0.06, infection = 0.05}}},
		dirty_antiseptic = {name = "Мутный антисептик", procedure = "disinfect", desc = "Жидкость из бутыли без этикетки. Может обеззаразить, а может и наоборот.", model = "models/props_junk/metal_paintcan001a.mdl",
			width = 1, height = 1, target = "limb", time = 3, uses = 3, cures = {infection = true},
			dirty = {power = 0.5, cure = 0.5, risks = {infection = 0.12, hepatitis = 0.04}}},
		moonshine = {name = "Самогон", desc = "Крепкий, мутный, домашний. Жжёт рану так, что иногда помогает.", model = "models/props_junk/glassjug01.mdl",
			width = 1, height = 2, target = "limb", time = 2, uses = 3, cures = {infection = true},
			dirty = {power = 0.5, cure = 0.45, risks = {hepatitis = 0.06}}},
		dirty_salve = {name = "Подозрительная мазь", procedure = "gel", desc = "Баночка с чем-то жирным и неопределённого цвета. Ожог холодит, но не всегда лечит.", model = "models/props_junk/terracotta01.mdl",
			width = 1, height = 1, target = "limb", time = 3, uses = 3, heal = 10, cures = {burn = true},
			dirty = {power = 0.5, cure = 0.5, risks = {infection = 0.15}}},
		dirty_kit = {name = "Потрёпанная аптечка", desc = "Чемоданчик, который явно уже побывал в деле. Половины содержимого нет, остальное вызывает сомнения.", model = "models/props_c17/suitcase_passenger_physics.mdl",
			width = 2, height = 2, target = "limb", time = 6, uses = 3, heal = 45, healHealth = 20,
			cures = {bleed_light = true}, downgrade = {bleed_heavy = "bleed_light"},
			dirty = {power = 0.55, cure = 0.6, risks = {infection = 0.10, tetanus = 0.03, hepatitis = 0.03}}},
		dirty_painkiller = {name = "Просроченное обезболивающее", desc = "Таблетки в пакете без инструкции. Боль приглушат ненадолго.", model = "models/props_lab/partsbin01.mdl",
			width = 1, height = 1, target = "self", time = 2, uses = 4, buff = {id = "analgesia"},
			dirty = {power = 0.5, risks = {hepatitis = 0.05, food_poison = 0.10}}},
		dirty_antibiotic = {name = "Контрафактный антибиотик", desc = "Блистер с чужими буквами. Работает через раз, и печень вам за это спасибо не скажет.", model = "models/props_lab/binderredlabel.mdl",
			width = 1, height = 1, target = "self", time = 2, uses = 4,
			cures = {infection = true, pneumonia = true, dysentery = true},
			dirty = {power = 0.5, cure = 0.45, risks = {hepatitis = 0.06, food_poison = 0.08}}},
		dirty_antipyretic = {name = "Порошок «от простуды»", desc = "Что-то белое в бумажном свёртке. Простуду, возможно, прогонит.", model = "models/props_lab/bindergreen.mdl",
			width = 1, height = 1, target = "self", time = 2, uses = 3,
			cures = {cold = true}, reduce = {flu = 0.5},
			dirty = {power = 0.6, cure = 0.55, risks = {food_poison = 0.10, hepatitis = 0.03}}},
		dirty_water = {name = "Мутная вода", desc = "Ведро воды из ближайшей лужи. Жар сбивает, но кто знает, что в ней плавает.", model = "models/props_junk/metalbucket01a.mdl",
			width = 2, height = 2, target = "self", time = 3, uses = 2, healHealth = 5, thirst = 25, cures = {heatstroke = true},
			dirty = {power = 0.6, cure = 0.6, risks = {dysentery = 0.20, food_poison = 0.15, hepatitis = 0.04}}},
		dirty_syringe = {name = "Б/у шприц с морфином", desc = "Использованный шприц, найденный в чужих вещах. Боль уйдёт, а вот что останется — вопрос.", model = "models/crossbow_bolt.mdl",
			width = 1, height = 1, target = "self", time = 1, uses = 1, buff = {id = "analgesia", duration = 720},
			dirty = {power = 0.6, risks = {hepatitis = 0.12, infection = 0.10, tetanus = 0.03}}},
		dirty_blood = {name = "Пакет крови без маркировки", desc = "Неизвестно, чья кровь и сколько она здесь лежит. Анемию поправит, но с последствиями.", model = "models/props_junk/metalbucket02a.mdl",
			width = 1, height = 2, target = "self", time = 8, uses = 1, healHealth = 15, cures = {anemia = true},
			dirty = {power = 0.7, cure = 0.7, risks = {hepatitis = 0.15, malaria = 0.06}}},
		dirty_blanket = {name = "Грязное одеяло", desc = "Волглое и вонючее, но всё же одеяло. Согреет не сразу и не до конца.", model = "models/props_junk/cardboard_box003b.mdl",
			width = 2, height = 2, target = "self", time = 6, uses = 1, cures = {hypothermia = true},
			dirty = {power = 0.5, cure = 0.5, risks = {cold = 0.15, flu = 0.05}}}
	}
}
