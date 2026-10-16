PLUGIN.name = "Weapon Select"
PLUGIN.author = "Chessnut"
PLUGIN.description = "Реалистичный выбор оружия: слоты, патроны, время на убирание и доставание, звуки снаряжения."

--[[
	Что делает плагин:
	- заменяет стандартный выбор оружия крупным списком по слотам (как в реальных шутерах);
	- оружие отсортировано по слотам SWEP.Slot / SWEP.SlotPos, цифры 1-9 выбирают слот,
	  повторное нажатие листает оружие внутри слота;
	- колесо мыши: вверх — вверх по списку, вниз — вниз; ЛКМ — взять оружие, ПКМ — закрыть список;
	- рядом с оружием показаны патроны (магазин / запас) и полоска магазина;
	- смена оружия состоит из трёх этапов:
	    1) текущее оружие опускается (время задаёт wsSwitchDelay);
	    2) оружие остаётся опущенным, пока сервер не подтвердит смену (никаких «мелькающих рук»);
	    3) новое оружие поднимается (время зависит от типа оружия и настройки wsDrawSpeed).
	  На всё это время нельзя стрелять и перезаряжаться (на сервере это тоже принудительно);
	- время доставания зависит от типа оружия (по SWEP.HoldType): ближний бой, пистолеты и гранаты
	  достаются быстро, автоматы, дробовики и спецоружие (арбалет, РПГ) — дольше;
	- задержки есть только у настоящего оружия: смена между руками, ключами и прочими
	  «не-оружиями» мгновенная, без анимации и без блокировки стрельбы;
	- если оружие не удалось сменить (например, у него не получается убраться) — придёт уведомление;
	- тихие «механические» звуки вместо интерфейсных.

	Для разработчиков:
	- SWEP.ixDrawTime = <секунды> — своё базовое время доставания у конкретного оружия;
	- SWEP.ixIsWeapon = true / false — явно указать, считать ли предмет оружием (задержки смены);
	- hook WeaponHasSwitchDelay(weapon) — вернуть true / false, чтобы решить это кодом (shared);
	- hook WeaponDrawTime(weapon) — вернуть число секунд, чтобы переопределить базовое время (shared);
	- hook WeaponCycleSound() и WeaponSelectSound(weapon) — свои звуки (client).
]]

ix.config.Add("wsSwitchDelay", 0.35, "Время убирания текущего оружия при смене (сек). Во время смены нельзя стрелять и перезаряжаться. 0 — мгновенно, без анимации.", nil, {
	data = {min = 0, max = 2, decimals = 2},
	category = PLUGIN.name
})

ix.config.Add("wsDrawSpeed", 1, "Скорость доставания оружия. 1 — стандартная, меньше 1 — медленнее (оружие достаётся дольше), больше 1 — быстрее. Базовое время зависит от типа оружия: пистолеты достаются быстрее, тяжёлое оружие — дольше. Во время доставания нельзя стрелять.", nil, {
	data = {min = 0.25, max = 4, decimals = 2},
	category = PLUGIN.name
})

ix.config.Add("wsHideTime", 3, "Через сколько секунд список оружия скрывается, если ничего не нажимать.", nil, {
	data = {min = 1, max = 10, decimals = 1},
	category = PLUGIN.name
})

ix.config.Add("wsShowAmmo", true, "Показывать патроны (в магазине / запас) рядом с оружием в списке.", nil, {
	category = PLUGIN.name
})

ix.config.Add("wsSounds", true, "Звуки при выборе оружия: щелчок при прокрутке и шорох снаряжения при смене.", nil, {
	category = PLUGIN.name
})

--[[
	ОБЩАЯ ЧАСТЬ (клиент + сервер)
	Время доставания считается одинаково на обеих сторонах: клиент по нему рисует анимацию
	и блокирует выстрелы, сервер — не даёт выстрелить раньше времени.
]]

-- базовое время доставания в секундах при скорости 1.0 (делится на настройку wsDrawSpeed)
local DRAW_TIME_DEFAULT = 0.7

-- по типу хвата оружия (SWEP.HoldType) — основной способ определить «вес» оружия
local DRAW_TIME_BY_HOLDTYPE = {
	-- быстро: ближний бой, пистолеты, гранаты
	fist = 0.3,
	knife = 0.3,
	melee = 0.35,
	melee2 = 0.4,
	grenade = 0.35,
	slam = 0.4,
	pistol = 0.4,
	revolver = 0.45,
	duel = 0.5,

	-- дольше: стрелковое оружие
	smg = 0.8,
	ar2 = 1.0,
	rpg = 1.3, -- спецоружие
	crossbow = 1.1, -- спецоружие
	shotgun = 1.1
}

-- запасной вариант, если у оружия нет известного HoldType: по слоту
local DRAW_TIME_BY_SLOT = {
	[0] = 0.4, -- ближний бой, гравипушка
	[1] = 0.5, -- пистолеты, револьверы
	[2] = 0.75, -- пистолеты-пулемёты, автоматы
	[3] = 0.9, -- дробовики, арбалеты
	[4] = 1.0, -- тяжёлое: гранатомёты и т.п.
	[5] = 0.6
}

-- исключения по классу оружия (имеют приоритет над слотом), например: weapon_crowbar = 0.3
local DRAW_TIME_BY_CLASS = {}

-- предметы, которые НЕ считаются оружием: между ними и при доставании их никаких задержек.
-- Добавьте сюда классы своих «не-оружий» (рация, фонарик, чемоданчик и т.п.)
local NON_WEAPON_CLASSES = {
	ix_hands = true,
	ix_keys = true,
	weapon_fists = true,
	weapon_physgun = true,
	gmod_tool = true,
	gmod_camera = true
}

local function GetSlot(weapon)
	local slot = weapon.Slot

	if (!isnumber(slot) and weapon.GetSlot) then
		slot = weapon:GetSlot()
	end

	return isnumber(slot) and slot or 0
end

local function GetSlotPos(weapon)
	local pos = weapon.SlotPos

	if (!isnumber(pos) and weapon.GetSlotPos) then
		pos = weapon:GetSlotPos()
	end

	return isnumber(pos) and pos or 0
end

local function GetHoldType(weapon)
	-- статичное поле SWEP надёжнее: некоторые базы оружия меняют хват на лету (бег, прицеливание)
	local holdType = weapon.HoldType

	if (!isstring(holdType) and weapon.GetHoldType) then
		holdType = weapon:GetHoldType()
	end

	return isstring(holdType) and holdType:lower() or nil
end

-- настоящее ли это оружие (у него есть задержки на убирание и доставание)
function PLUGIN:IsRealWeapon(weapon)
	if (!IsValid(weapon)) then
		return false
	end

	local custom = hook.Run("WeaponHasSwitchDelay", weapon)

	if (isbool(custom)) then
		return custom
	end

	if (isbool(weapon.ixIsWeapon)) then
		return weapon.ixIsWeapon
	end

	return !NON_WEAPON_CLASSES[weapon:GetClass()]
end

-- сколько секунд достаётся оружие (с учётом настройки скорости доставания); у не-оружия — 0
function PLUGIN:GetDrawTime(weapon)
	if (!self:IsRealWeapon(weapon)) then
		return 0
	end

	local base = hook.Run("WeaponDrawTime", weapon)

	if (!isnumber(base)) then
		base = isnumber(weapon.ixDrawTime) and weapon.ixDrawTime
			or DRAW_TIME_BY_CLASS[weapon:GetClass()]
			or DRAW_TIME_BY_HOLDTYPE[GetHoldType(weapon)]
			or DRAW_TIME_BY_SLOT[GetSlot(weapon)]
			or DRAW_TIME_DEFAULT
	end

	return math.max(base, 0) / math.max(ix.config.Get("wsDrawSpeed", 1), 0.1)
end

if (SERVER) then
	-- на сервере не даём стрелять, пока оружие не достали до конца (защита от обхода на клиенте)
	function PLUGIN:PlayerSwitchWeapon(client, oldWeapon, newWeapon)
		if (!IsValid(newWeapon)) then
			return
		end

		local drawTime = self:GetDrawTime(newWeapon)

		if (drawTime <= 0) then
			return
		end

		-- к следующему тику оружие уже будет активным и отработает свой Deploy
		timer.Simple(0, function()
			if (!IsValid(client) or !IsValid(newWeapon) or client:GetActiveWeapon() != newWeapon) then
				return
			end

			local readyAt = CurTime() + drawTime

			if (newWeapon:GetNextPrimaryFire() < readyAt) then
				newWeapon:SetNextPrimaryFire(readyAt)
			end

			if (newWeapon:GetNextSecondaryFire() < readyAt) then
				newWeapon:SetNextSecondaryFire(readyAt)
			end
		end)
	end
end

if (CLIENT) then
	-- общий стиль меню (тот же, что в cl_menu.lua / cl_inventory.lua)
	ix.menuStyle = ix.menuStyle or {accent = Color(90, 160, 235), projectName = "EIRGD"}

	--[[
		НАСТРОЙКИ ВНЕШНЕГО ВИДА
		Размеры указаны для высоты экрана 1080 и масштабируются под разрешение.
	]]
	local CFG = {
		width = 400, -- ширина строки списка
		rowH = 46, -- высота строки
		gap = 4, -- расстояние между строками
		marginX = 56, -- отступ списка от правого края экрана
		anchorY = 0.5, -- вертикальное положение выбранной строки (0 — верх экрана, 1 — низ)
		fadeDist = 5, -- на каком расстоянии от выбранной строки остальные растворяются
		minAlpha = 0.45, -- насколько заметны соседние строки (0 — совсем прозрачные)
		infoPad = 12, -- внутренний отступ блока с инструкцией
		blur = 3, -- размытие фона под списком (0 — выключено)

		-- анимация оружия в руках при смене (полностью опущенное положение)
		lowerDown = 20, -- насколько уходит вниз
		lowerBack = 4, -- насколько уходит назад
		lowerPitch = 32, -- наклон ствола вниз (градусы)
		lowerRoll = -8, -- крен (градусы)
		lowerSway = 1.5, -- лёгкое смещение вбок в середине движения

		-- ожидание подтверждения смены от сервера
		waitTimeout = 1, -- базовое время ожидания (сек), к нему добавляется пинг
		waitRetries = 2, -- сколько раз повторить запрос, прежде чем сдаться

		cycleSound = "weapons/smg1/switch_single.wav", -- щелчок при прокрутке списка
		deniedSound = "common/wpn_denyselect.wav", -- нельзя сменить оружие прямо сейчас
		confirmSounds = { -- шорох снаряжения при смене оружия
			"npc/combine_soldier/gear1.wav",
			"npc/combine_soldier/gear2.wav",
			"npc/combine_soldier/gear3.wav",
			"npc/combine_soldier/gear4.wav",
			"npc/combine_soldier/gear5.wav",
			"npc/combine_soldier/gear6.wav"
		}
	}

	-- этапы смены оружия
	local STATE_LOWER = 1 -- текущее оружие опускается
	local STATE_WAIT = 2 -- ждём, пока сервер подтвердит смену (оружие скрыто)
	local STATE_DRAW = 3 -- новое оружие поднимается

	PLUGIN.index = PLUGIN.index or 1
	PLUGIN.deltaIndex = PLUGIN.deltaIndex or PLUGIN.index
	PLUGIN.infoAlpha = PLUGIN.infoAlpha or 0
	PLUGIN.alpha = PLUGIN.alpha or 0
	PLUGIN.alphaDelta = PLUGIN.alphaDelta or PLUGIN.alpha
	PLUGIN.fadeTime = PLUGIN.fadeTime or 0

	local COLOR_LOW = Color(235, 90, 80)

	-- переиспользуемые цвета и кэши, чтобы не создавать мусор каждый кадр
	local colShadow = Color(0, 0, 0, 255)
	local colText = Color(255, 255, 255, 255)
	local nameCache = {}
	local fitCache = {}
	local ammoInfo = {}
	local rows = {}

	local function MemoTable(format)
		return setmetatable({}, {
			__index = function(t, key)
				local value = format and (format .. key) or tostring(key)

				t[key] = value

				return value
			end
		})
	end

	local numStr = MemoTable()
	local reserveStr = MemoTable("/ ")

	local function S(value)
		return math.floor(value * ScrH() / 1080 + 0.5)
	end

	local function GetAccent()
		return ix.menuStyle.accent or ix.config.Get("color") or Color(90, 160, 235)
	end

	function PLUGIN:LoadFonts(font, genericFont)
		-- кэши зависят от шрифтов и разрешения
		table.Empty(fitCache)
		table.Empty(nameCache)

		-- старый шрифт оставлен, чтобы не ломать другие файлы, которые могут его использовать
		surface.CreateFont("ixWeaponSelectFont", {
			font = font,
			size = ScreenScale(16),
			extended = true,
			weight = 1000
		})

		surface.CreateFont("ixWSName", {
			font = font,
			size = math.max(math.floor(ScrH() * 0.0225), 15),
			extended = true,
			weight = 700
		})

		surface.CreateFont("ixWSSmall", {
			font = font,
			size = math.max(math.floor(ScrH() * 0.0145), 11),
			extended = true,
			weight = 600
		})

		surface.CreateFont("ixWSSlot", {
			font = font,
			size = math.max(math.floor(ScrH() * 0.0215), 14),
			extended = true,
			weight = 800
		})
	end

	function PLUGIN:HUDShouldDraw(name)
		if (name == "CHudWeaponSelection") then
			return false
		end
	end

	-- обрезает текст по ширине с многоточием (с учётом UTF-8); результат кэшируется
	local function FitText(text, font, maxWidth)
		local byFont = fitCache[font]

		if (!byFont) then
			byFont = {}
			fitCache[font] = byFont
		end

		local byText = byFont[text]

		if (!byText) then
			byText = {}
			byFont[text] = byText
		end

		local cached = byText[maxWidth]

		if (cached) then
			return cached
		end

		surface.SetFont(font)

		local result

		if (surface.GetTextSize(text) <= maxWidth) then
			result = text
		else
			local length = utf8.len(text) or #text

			result = "…"

			while (length > 1) do
				length = length - 1

				local cut = text:sub(1, (utf8.offset(text, length + 1) or (#text + 1)) - 1) .. "…"

				if (surface.GetTextSize(cut) <= maxWidth) then
					result = cut

					break
				end
			end
		end

		byText[maxWidth] = result

		return result
	end

	local function DrawShadowText(text, font, x, y, r, g, b, a, alignX, alignY)
		colShadow.a = a * 0.85
		draw.SimpleText(text, font, x + 1, y + 1, colShadow, alignX, alignY)

		colText.r, colText.g, colText.b, colText.a = r, g, b, a
		draw.SimpleText(text, font, x, y, colText, alignX, alignY)
	end

	local function GetWeaponName(weapon)
		local printName = weapon:GetPrintName()
		local cached = nameCache[printName]

		if (!cached) then
			local name = language.GetPhrase(printName)

			cached = name.utf8upper and name:utf8upper() or name:upper()
			nameCache[printName] = cached
		end

		return cached
	end

	local function SortWeapons(a, b)
		local slotA, slotB = GetSlot(a), GetSlot(b)

		if (slotA != slotB) then
			return slotA < slotB
		end

		local posA, posB = GetSlotPos(a), GetSlotPos(b)

		if (posA != posB) then
			return posA < posB
		end

		return a:GetClass() < b:GetClass()
	end

	-- оружие игрока, отсортированное по слотам. Список кэшируется и обновляется 4 раза в секунду
	-- (или сразу, если какое-то оружие исчезло / передан force)
	local weaponList, weaponListTime = {}, 0

	local function GetWeaponList(client, force)
		local now = CurTime()
		local valid = !force and now < weaponListTime

		if (valid) then
			for i = 1, #weaponList do
				if (!IsValid(weaponList[i])) then
					valid = false

					break
				end
			end
		end

		if (!valid) then
			table.Empty(weaponList)

			for _, weapon in ipairs(client:GetWeapons()) do
				if (IsValid(weapon)) then
					weaponList[#weaponList + 1] = weapon
				end
			end

			table.sort(weaponList, SortWeapons)
			weaponListTime = now + 0.25
		end

		return weaponList
	end

	local function IndexOf(list, weapon)
		for i = 1, #list do
			if (list[i] == weapon) then
				return i
			end
		end
	end

	-- патроны оружия: магазин, запас, признак «мало / пусто» (таблица переиспользуется)
	local function GetAmmoInfo(client, weapon)
		local clip = weapon:Clip1()
		local ammoType = weapon:GetPrimaryAmmoType()

		if (clip < 0 and ammoType < 0) then
			return nil
		end

		local reserve = ammoType >= 0 and client:GetAmmoCount(ammoType) or 0

		ammoInfo.reserve = reserve

		if (clip >= 0) then
			local maxClip = weapon:GetMaxClip1()

			ammoInfo.clip = clip
			ammoInfo.maxClip = maxClip
			ammoInfo.low = clip == 0 or (maxClip > 0 and clip / maxClip <= 0.25)
		else
			ammoInfo.clip = nil
			ammoInfo.maxClip = 0
			ammoInfo.low = reserve == 0
		end

		return ammoInfo
	end

	local function PlaySound(path, pitch, volume)
		if (!ix.config.Get("wsSounds", true) or !path) then
			return
		end

		local client = LocalPlayer()

		if (IsValid(client)) then
			client:EmitSound(path, 45, pitch or 100, volume or 0.4)
		end
	end

	function PLUGIN:GetSelectedIndex(list)
		local index = IndexOf(list, self.selected)

		if (!index) then
			local client = LocalPlayer()

			index = IsValid(client) and IndexOf(list, client:GetActiveWeapon()) or 1
			self.selected = list[index]
		end

		return index
	end

	-- вызывается при каждой смене выбранного оружия в списке
	function PLUGIN:OnIndexChanged(weapon)
		self.alpha = 1
		self.fadeTime = CurTime() + ix.config.Get("wsHideTime", 3)
		self.markup = nil

		if (IsValid(weapon)) then
			local instructions = weapon.Instructions
			local text = ""

			if (isstring(instructions) and instructions:find("%S")) then
				local color = GetAccent()

				text = text .. string.format(
					"<font=ixItemBoldFont><color=%d,%d,%d>%s</font></color>\n%s\n",
					color.r, color.g, color.b, L("Instructions"), instructions
				)
			end

			if (text != "") then
				self.markup = markup.Parse("<font=ixItemDescFont>" .. text, S(CFG.width) - S(CFG.infoPad) * 2 - 4)
				self.infoAlpha = 0
			end

			local source, pitch = hook.Run("WeaponCycleSound")

			PlaySound(source or CFG.cycleSound, pitch, 0.35)
		end
	end

	function PLUGIN:Select(weapon)
		self.selected = weapon
		self:OnIndexChanged(weapon)
	end

	-- прокрутка списка колесом мыши
	function PLUGIN:Cycle(list, direction)
		local client = LocalPlayer()
		local current

		if (self.alpha <= 0) then
			current = IndexOf(list, client:GetActiveWeapon()) or 1
			self.deltaIndex = current
			self.selected = list[current]
		else
			current = self:GetSelectedIndex(list)
		end

		local target = current + direction

		if (target < 1) then
			target = #list
		elseif (target > #list) then
			target = 1
		end

		self:Select(list[target])
	end

	-- выбор слота цифрой: повторное нажатие листает оружие внутри слота
	function PLUGIN:SelectSlot(list, slotNumber)
		local client = LocalPlayer()
		local candidates = {}

		for i = 1, #list do
			if (GetSlot(list[i]) + 1 == slotNumber) then
				candidates[#candidates + 1] = i
			end
		end

		if (#candidates == 0) then
			return false
		end

		local current

		if (self.alpha <= 0) then
			current = IndexOf(list, client:GetActiveWeapon())
			self.deltaIndex = current or candidates[1]
		else
			current = self:GetSelectedIndex(list)
		end

		local target = candidates[1]

		for k, index in ipairs(candidates) do
			if (index == current) then
				target = candidates[k % #candidates + 1]

				break
			end
		end

		self:Select(list[target])

		return true
	end

	--[[
		СМЕНА ОРУЖИЯ
		LOWER -> (CreateMove отправляет SelectWeapon) -> WAIT -> (сервер подтвердил) -> DRAW -> конец.
		В течение всех трёх этапов стрелять и перезаряжаться нельзя.
	]]
	function PLUGIN:ResetSwitch()
		self.swState = nil
		self.swTarget = nil
	end

	-- подтверждение выбора: оружие опускается, затем достаётся новое
	function PLUGIN:ConfirmSelection()
		local client = LocalPlayer()
		local weapon = self.selected

		self.alpha = 0

		if (!IsValid(weapon) or weapon == client:GetActiveWeapon()) then
			return
		end

		-- пока идёт смена с задержкой, выбрать другое оружие нельзя
		if (self.swState and self.swBlock) then
			PlaySound(CFG.deniedSound, 100, 0.3)

			return
		end

		local active = client:GetActiveWeapon()

		-- убирание — только если в руках настоящее оружие, доставание — только если достаём настоящее
		local lowerTime = (IsValid(active) and self:IsRealWeapon(active)) and ix.config.Get("wsSwitchDelay", 0.35) or 0
		local drawTime = self:GetDrawTime(weapon)

		self.swTarget = weapon
		self.swState = STATE_LOWER
		self.swStart = CurTime()
		self.swLowerTime = lowerTime
		self.swDrawTime = drawTime
		-- если задержек нет (например, руки -> ключи), смена мгновенная: без анимации, звука и блокировки
		self.swBlock = lowerTime > 0 or drawTime > 0

		if (self.swBlock) then
			local source = hook.Run("WeaponSelectSound", weapon) or CFG.confirmSounds[math.random(#CFG.confirmSounds)]

			PlaySound(source, math.random(96, 104), 0.5)
		end
	end

	-- запрос на смену ушёл на сервер, ждём подтверждения (оружие остаётся опущенным)
	function PLUGIN:BeginWait()
		local client = LocalPlayer()

		self.swState = STATE_WAIT
		self.swStart = CurTime()
		self.swTries = 0
		self.swRetry = CurTime() + CFG.waitTimeout + (IsValid(client) and client:Ping() or 0) / 500
	end

	-- сервер сменил оружие: поднимаем новое
	function PLUGIN:BeginDraw()
		self.swState = STATE_DRAW
		self.swStart = CurTime()
		self.swEnd = self.swStart + self.swDrawTime

		if (self.swDrawTime > 0) then
			PlaySound(CFG.confirmSounds[math.random(#CFG.confirmSounds)], math.random(104, 112), 0.3)
		end
	end

	-- отрисовка одной строки списка
	function PLUGIN:DrawRow(client, activeWeapon, weapon, showAmmo, x, y, w, h, alpha, selMix, accent)
		x, y = math.floor(x), math.floor(y)

		local r = Lerp(selMix, 150, accent.r)
		local g = Lerp(selMix, 165, accent.g)
		local b = Lerp(selMix, 185, accent.b)
		local active = weapon == activeWeapon
		local centerY = y + h * 0.5

		draw.NoTexture()

		-- подложка и цветная заливка выбранной строки
		surface.SetDrawColor(6, 9, 14, (205 + 40 * selMix) * alpha)
		surface.DrawRect(x, y, w, h)

		if (selMix > 0.01) then
			surface.SetDrawColor(accent.r, accent.g, accent.b, 55 * selMix * alpha)
			surface.DrawRect(x, y, w, h)
		end

		-- блок с номером слота
		surface.SetDrawColor(0, 0, 0, 110 * alpha)
		surface.DrawRect(x, y, h, h)

		-- полоска слева и рамка
		surface.SetDrawColor(r, g, b, Lerp(selMix, 110, 255) * alpha)
		surface.DrawRect(x, y, 4, h)

		surface.SetDrawColor(r, g, b, Lerp(selMix, 55, 235) * alpha)
		surface.DrawOutlinedRect(x, y, w, h, 1)

		if (selMix > 0.05) then
			local corner = S(9)

			surface.SetDrawColor(accent.r, accent.g, accent.b, 255 * selMix * alpha)
			surface.DrawRect(x + w - corner, y, corner, 2)
			surface.DrawRect(x + w - 2, y, 2, corner)
			surface.DrawRect(x + w - corner, y + h - 2, corner, 2)
			surface.DrawRect(x + w - 2, y + h - corner, 2, corner)
		end

		-- номер слота
		DrawShadowText(
			numStr[GetSlot(weapon) + 1], "ixWSSlot", x + h * 0.5 + 2, centerY,
			255, 255, 255, Lerp(selMix, 150, 255) * alpha, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
		)

		-- патроны справа: магазин крупно, запас мелко, снизу полоска магазина
		local textX = x + h + S(14)
		local rightX = x + w - S(12)
		local ammoWidth = 0

		if (showAmmo) then
			local info = GetAmmoInfo(client, weapon)

			if (info) then
				local mr, mg, mb = 255, 255, 255

				if (info.low) then
					mr, mg, mb = COLOR_LOW.r, COLOR_LOW.g, COLOR_LOW.b
				end

				if (info.clip != nil) then
					local main = numStr[info.clip]
					local reserveText = reserveStr[info.reserve]

					surface.SetFont("ixWSSmall")
					local reserveW = surface.GetTextSize(reserveText)

					DrawShadowText(
						reserveText, "ixWSSmall", rightX, centerY + S(1),
						200, 210, 225, 200 * alpha, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
					)

					surface.SetFont("ixWSName")
					local mainW = surface.GetTextSize(main)

					DrawShadowText(
						main, "ixWSName", rightX - reserveW - S(6), centerY - S(1),
						mr, mg, mb, 255 * alpha, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
					)

					ammoWidth = reserveW + mainW + S(6)

					if (info.maxClip > 0) then
						local barX, barW = textX, rightX - textX
						local barY = y + h - S(7)
						local fill = math.Clamp(info.clip / info.maxClip, 0, 1)

						surface.SetDrawColor(0, 0, 0, 150 * alpha)
						surface.DrawRect(barX, barY, barW, S(3))

						surface.SetDrawColor(mr, mg, mb, (info.low and 255 or 210) * alpha)
						surface.DrawRect(barX, barY, math.floor(barW * fill), S(3))
					end
				else
					local main = numStr[info.reserve]

					surface.SetFont("ixWSName")
					ammoWidth = surface.GetTextSize(main)

					DrawShadowText(
						main, "ixWSName", rightX, centerY,
						mr, mg, mb, 255 * alpha, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
					)
				end
			end
		end

		-- название; у оружия в руках под ним подпись
		local name = FitText(GetWeaponName(weapon), "ixWSName", w - h - S(14) - ammoWidth - S(26))
		local nameY = active and (y + h * 0.36) or centerY

		DrawShadowText(
			name, "ixWSName", textX, nameY,
			255, 255, 255, Lerp(selMix, 185, 255) * alpha, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
		)

		if (active) then
			DrawShadowText(
				"В РУКАХ", "ixWSSmall", textX, y + h * 0.7,
				accent.r, accent.g, accent.b, 255 * alpha, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
			)
		end
	end

	-- индикатор смены оружия по центру экрана: убирание + ожидание + доставание в одной полоске
	function PLUGIN:DrawSwitch()
		local weapon = self.swTarget

		if (!IsValid(weapon)) then
			return
		end

		local state = self.swState
		local now = CurTime()
		local lowerTime, drawTime = self.swLowerTime, self.swDrawTime
		local total = lowerTime + drawTime
		local done

		if (state == STATE_LOWER) then
			done = math.Clamp(now - self.swStart, 0, lowerTime)
		elseif (state == STATE_WAIT) then
			done = lowerTime
		else
			done = lowerTime + math.Clamp(now - self.swStart, 0, drawTime)
		end

		local progress = total > 0 and done / total or 1
		local accent = GetAccent()
		local w, h = S(300), S(64)
		local x, y = math.floor(ScrW() * 0.5 - w * 0.5), math.floor(ScrH() * 0.66)

		draw.NoTexture()

		surface.SetDrawColor(6, 9, 14, 215)
		surface.DrawRect(x, y, w, h)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 235)
		surface.DrawRect(x, y, 4, h)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 70)
		surface.DrawOutlinedRect(x, y, w, h, 1)

		DrawShadowText(
			state == STATE_LOWER and "УБИРАЕМ ОРУЖИЕ" or "ДОСТАЁМ ОРУЖИЕ", "ixWSSmall", x + S(16), y + S(14),
			accent.r, accent.g, accent.b, 255, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
		)

		DrawShadowText(
			FitText(GetWeaponName(weapon), "ixWSName", w - S(32)), "ixWSName", x + S(16), y + S(34),
			255, 255, 255, 255, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
		)

		surface.SetDrawColor(0, 0, 0, 160)
		surface.DrawRect(x + S(16), y + h - S(10), w - S(32), S(3))

		surface.SetDrawColor(accent.r, accent.g, accent.b, 255)
		surface.DrawRect(x + S(16), y + h - S(10), math.floor((w - S(32)) * progress), S(3))
	end

	function PLUGIN:HUDPaint()
		local frameTime = FrameTime()

		if (self.swState and self.swBlock) then
			self:DrawSwitch()
		end

		self.alphaDelta = Lerp(frameTime * 10, self.alphaDelta, self.alpha)

		local fraction = self.alphaDelta

		if (fraction <= 0.01) then
			return
		end

		local client = LocalPlayer()

		if (!IsValid(client)) then
			return
		end

		local list = GetWeaponList(client)

		if (#list == 0) then
			self.alpha = 0

			return
		end

		local selected = self:GetSelectedIndex(list)

		self.index = selected
		self.deltaIndex = Lerp(frameTime * 14, self.deltaIndex, selected)

		local accent = GetAccent()
		local activeWeapon = client:GetActiveWeapon()
		local showAmmo = ix.config.Get("wsShowAmmo", true)
		local width, rowH, gap = S(CFG.width), S(CFG.rowH), S(CFG.gap)
		local pad = S(CFG.infoPad)
		local step = rowH + gap
		local x = ScrW() - width - S(CFG.marginX)
		local centerY = math.floor(ScrH() * CFG.anchorY - rowH * 0.5)

		-- блок с инструкцией раздвигает строки ниже выбранной
		self.infoAlpha = Lerp(frameTime * 3, self.infoAlpha, self.markup and 255 or 0)

		local infoMix = self.infoAlpha / 255
		local infoFull = 0
		local markupH = 0

		if (self.markup) then
			local _, h = self.markup:Size()

			markupH = h
			infoFull = markupH + pad * 2 + gap
		end

		local infoShift = infoFull * infoMix
		local count = 0
		local minY, maxY = math.huge, -math.huge

		for i = 1, #list do
			local rel = i - self.deltaIndex
			local dist = math.abs(rel)
			local near = math.Clamp(1 - dist / CFG.fadeDist, 0, 1)
			local alpha = fraction * (CFG.minAlpha + (1 - CFG.minAlpha) * near) * (near > 0 and 1 or 0)

			if (alpha > 0.01) then
				local y = centerY + rel * step + infoShift * math.Clamp(rel, 0, 1)

				count = count + 1

				local row = rows[count]

				if (!row) then
					row = {}
					rows[count] = row
				end

				row.i, row.y, row.alpha, row.selMix = i, y, alpha, math.Clamp(1 - dist, 0, 1)

				minY = math.min(minY, y)
				maxY = math.max(maxY, y + rowH)
			end
		end

		local boxY = math.floor(centerY + (selected - self.deltaIndex) * step + rowH + gap)
		local boxH = math.floor((markupH + pad * 2) * infoMix)

		if (self.markup and infoMix > 0.01) then
			maxY = math.max(maxY, boxY + boxH)
		end

		-- размытие фона под списком
		if (CFG.blur > 0 and ix.util.DrawBlurAt and minY < maxY) then
			ix.util.DrawBlurAt(x - S(8), minY - S(8), width + S(16), maxY - minY + S(16), CFG.blur * fraction)
		end

		for n = 1, count do
			local row = rows[n]

			self:DrawRow(client, activeWeapon, list[row.i], showAmmo, x, row.y, width, rowH, row.alpha, row.selMix, accent)
		end

		if (self.markup and infoMix > 0.01) then
			local infoAlpha = fraction * infoMix

			draw.NoTexture()

			surface.SetDrawColor(6, 9, 14, 225 * infoAlpha)
			surface.DrawRect(x, boxY, width, boxH)

			surface.SetDrawColor(accent.r, accent.g, accent.b, 70 * infoAlpha)
			surface.DrawOutlinedRect(x, boxY, width, boxH, 1)

			surface.SetDrawColor(accent.r, accent.g, accent.b, 255 * infoAlpha)
			surface.DrawRect(x, boxY, 4, boxH)

			render.SetScissorRect(x, boxY, x + width, boxY + boxH, true)
				self.markup:Draw(x + pad + 4, boxY + pad, 0, 0, self.infoAlpha * fraction)
			render.SetScissorRect(0, 0, 0, 0, false)
		end
	end

	function PLUGIN:PlayerBindPress(client, bind, pressed)
		if (!pressed) then
			return
		end

		bind = bind:lower()

		local slot = tonumber(bind:match("^slot(%d+)$"))
		local bAttack = bind:find("^%+attack") != nil
		local bPrev, bNext

		if (!slot and !bAttack) then
			bPrev = bind:find("invprev", 1, true) != nil
			bNext = !bPrev and bind:find("invnext", 1, true) != nil

			if (!bPrev and !bNext) then
				return
			end
		end

		if (!client:Alive() or client:InVehicle()) then
			return
		end

		-- в рэгдолле оружием не пользуются
		if (client.IsRagdolled and client:IsRagdolled()) then
			self.alpha = 0

			return
		end

		local currentWeapon = client:GetActiveWeapon()
		local bValid = IsValid(currentWeapon)

		if (bValid and currentWeapon:GetClass() == "weapon_physgun" and client:KeyDown(IN_ATTACK)) then
			return
		end

		if (bAttack) then
			if (self.alpha <= 0) then
				return
			end

			-- ПКМ закрывает список без смены оружия, ЛКМ подтверждает выбор
			if (bind:find("^%+attack2")) then
				self.alpha = 0
			else
				self:ConfirmSelection()
			end

			return true
		end

		-- пока оружие меняется (с задержкой), выбирать другое нельзя
		if (self.swState and self.swBlock) then
			return true
		end

		if (bPrev or bNext) then
			-- колесо мыши отдаём инструментам, которые его используют
			if (bValid and currentWeapon:GetClass() == "gmod_tool") then
				local tool = client:GetTool()

				if (tool and tool.Scroll != nil) then
					return
				end
			end
		end

		local list = GetWeaponList(client, true)

		if (#list == 0) then
			return
		end

		if (bPrev or bNext) then
			self:Cycle(list, bPrev and -1 or 1)

			return true
		end

		if (slot and self:SelectSlot(list, slot)) then
			return true
		end
	end

	-- во время смены нельзя стрелять и перезаряжаться; когда опускание закончилось — отправляем смену.
	-- CreateMove вызывается ровно один раз на каждую реально отправляемую команду
	function PLUGIN:CreateMove(cmd)
		local state = self.swState

		if (!state) then
			return
		end

		if (self.swBlock) then
			cmd:RemoveKey(IN_ATTACK)
			cmd:RemoveKey(IN_ATTACK2)
			cmd:RemoveKey(IN_RELOAD)
		end

		if (state == STATE_LOWER and CurTime() >= self.swStart + self.swLowerTime) then
			local weapon = self.swTarget

			if (IsValid(weapon)) then
				cmd:SelectWeapon(weapon)
				self:BeginWait()
			else
				self:ResetSwitch()
			end
		end
	end

	local function SmoothStep(p)
		return p * p * (3 - 2 * p)
	end

	local function SmootherStep(p)
		return p * p * p * (p * (6 * p - 15) + 10)
	end

	-- оружие в руках опускается, остаётся скрытым пока идёт смена, затем плавно поднимается.
	-- Благодаря этапу WAIT на экране никогда не «мелькают» руки или старое оружие
	function PLUGIN:CalcViewModelView(weapon, viewModel, oldPos, oldAng, pos, ang)
		local state = self.swState

		if (!state or !self.swBlock) then
			return
		end

		local amount -- 0 — оружие в обычном положении, 1 — полностью опущено

		if (state == STATE_LOWER) then
			-- у «не-оружия» в руках (руки, ключи) опускания нет
			if (self.swLowerTime <= 0) then
				return
			end

			local progress = math.Clamp((CurTime() - self.swStart) / math.max(self.swLowerTime, 0.01), 0, 1)

			amount = SmoothStep(progress)
		elseif (state == STATE_WAIT) then
			if (self.swLowerTime <= 0) then
				return
			end

			amount = 1
		else
			-- «не-оружие» появляется сразу, без подъёма
			if (self.swDrawTime <= 0) then
				return
			end

			local progress = math.Clamp((CurTime() - self.swStart) / math.max(self.swDrawTime, 0.01), 0, 1)

			amount = 1 - SmootherStep(progress)
		end

		if (amount <= 0) then
			return
		end

		local sway = CFG.lowerSway * math.sin(amount * math.pi)

		return pos - ang:Up() * (CFG.lowerDown * amount) - ang:Forward() * (CFG.lowerBack * amount) + ang:Right() * sway,
			Angle(ang.p + CFG.lowerPitch * amount, ang.y, ang.r + CFG.lowerRoll * amount)
	end

	function PLUGIN:Think()
		local client = LocalPlayer()

		if (!IsValid(client)) then
			return
		end

		if (!client:Alive() or client:InVehicle() or (client.IsRagdolled and client:IsRagdolled())) then
			self.alpha = 0
			self:ResetSwitch()

			return
		end

		local state = self.swState

		if (state) then
			local target = self.swTarget
			local now = CurTime()

			if (!IsValid(target)) then
				self:ResetSwitch()
			elseif (state == STATE_DRAW) then
				if (now >= self.swEnd) then
					self:ResetSwitch()
				end
			elseif (client:GetActiveWeapon() == target) then
				-- сервер подтвердил смену — поднимаем новое оружие
				self:BeginDraw()
			elseif (state == STATE_LOWER) then
				-- страховка: если CreateMove по какой-то причине не сработал, выбираем оружие напрямую
				if (now > self.swStart + self.swLowerTime + 0.75) then
					input.SelectWeapon(target)
					self:BeginWait()
				end
			elseif (now > self.swRetry) then
				-- сервер долго не подтверждает смену: повторяем запрос ограниченное число раз
				if (self.swTries < CFG.waitRetries) then
					self.swTries = self.swTries + 1
					self.swRetry = now + CFG.waitTimeout + client:Ping() / 500

					input.SelectWeapon(target)
				else
					self:ResetSwitch()

					PlaySound(CFG.deniedSound, 100, 0.4)

					if (ix.util.Notify) then
						ix.util.Notify("Не удалось сменить оружие: текущее оружие сейчас нельзя убрать.")
					end
				end
			end
		end

		if (self.alpha > 0) then
			if (IsValid(ix.gui.menu) or self.fadeTime < CurTime()) then
				self.alpha = 0
			end
		end
	end

	function PLUGIN:ScoreboardShow()
		self.alpha = 0
	end

	function PLUGIN:ShouldPopulateEntityInfo(entity)
		if (self.alpha > 0) then
			return false
		end
	end
end