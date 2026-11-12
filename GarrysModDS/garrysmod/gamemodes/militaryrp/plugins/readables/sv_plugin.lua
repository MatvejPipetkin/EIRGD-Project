util.AddNetworkString("ixReadableOpen")

-- Минимальное время чтения (сек), чтобы не было мгновенного чтения.
ix.readables.minReadTime = 2

local function FormatTime(seconds)
	local total = math.ceil(seconds / 60)
	local hours = math.floor(total / 60)
	local minutes = total % 60

	if (hours > 0) then
		return string.format("%d ч %d мин", hours, minutes)
	end

	return string.format("%d мин", math.max(minutes, 1))
end

-- Запись о прочтении материала персонажем: {n = сколько раз, t = когда последний раз (os.time)}.
function ix.readables.GetRecord(char, uniqueID)
	local log = char:GetData("readLog", {})
	return log[uniqueID] or {n = 0, t = 0}
end

-- Сколько секунд осталось до того, как материал снова даст опыт.
function ix.readables.GetCooldownLeft(char, item)
	local record = ix.readables.GetRecord(char, item.uniqueID)

	if (record.n < 1) then
		return 0
	end

	return math.max(0, record.t + (item.cooldown or 0) - os.time())
end

-- Возвращает true или false + причина.
function ix.readables.CanRead(client, item)
	local char = client:GetCharacter()

	if (!char or !client:Alive()) then
		return false, "Сейчас вы не можете читать."
	end

	if (client.ixReading and CurTime() < (client.ixReadingUntil or 0)) then
		return false, "Вы уже заняты чтением."
	end

	for key, required in pairs(item.requirements or {}) do
		if (char:GetAttribute(key, 0) < required) then
			local attribute = ix.attributes.list[key]

			return false, string.format(
				"Материал слишком сложен для вас. Нужен навык «%s» не ниже %s.",
				attribute and attribute.name or key, required
			)
		end
	end

	local left = ix.readables.GetCooldownLeft(char, item)

	if (left > 0) then
		return false, string.format(
			"Вы недавно читали это. Новых знаний не будет ещё %s.%s",
			FormatTime(left), item.content and " Можно просто просмотреть." or ""
		)
	end

	return true
end

-- Открывает текст материала у игрока (без выдачи опыта).
function ix.readables.OpenContent(client, item)
	if (!item.content or item.content == "") then
		return
	end

	net.Start("ixReadableOpen")
		net.WriteString(item:GetName())
		net.WriteString(item.content)
	net.Send(client)
end

-- Начинает чтение: показывает полосу действия, по окончании выдаёт опыт.
function ix.readables.StartReading(client, item)
	local ok, reason = ix.readables.CanRead(client, item)

	if (!ok) then
		client:Notify(reason)
		return
	end

	local char = client:GetCharacter()
	local time = (item.readTime or 8) * ix.config.Get("readTimeScale", 1) * ix.readables.GetReadTimeMultiplier(client)
	time = math.max(ix.readables.minReadTime, time)

	client.ixReading = item
	client.ixReadingUntil = CurTime() + time + 1

	client:SetAction("Вы читаете: " .. item:GetName(), time, function()
		if (!IsValid(client) or client.ixReading != item) then
			return
		end

		client.ixReading = nil

		if (!client:Alive() or client:GetCharacter() != char or item:GetOwner() != client) then
			return
		end

		ix.readables.FinishReading(client, item)
	end)
end

-- Отмена чтения (урон, смерть).
function ix.readables.CancelReading(client)
	if (client.ixReading) then
		client.ixReading = nil
		client:SetAction(false)
		client:Notify("Вас отвлекли, чтение прервано.")
	end
end

-- Выдаёт опыт и записывает прочтение.
function ix.readables.FinishReading(client, item)
	local char = client:GetCharacter()
	local id = item.uniqueID

	local log = table.Copy(char:GetData("readLog", {}))
	local record = log[id] or {n = 0, t = 0}
	local bRepeat = record.n > 0

	local scale = ix.config.Get("readXPScale", 1) * ix.readables.GetXPMultiplier(client)

	if (bRepeat) then
		scale = scale * ix.config.Get("rereadFactor", 0.25)
	end

	local gained = {}

	for key, amount in SortedPairs(item.attributes or {}) do
		local attribute = ix.attributes.list[key]

		if (attribute) then
			local value = amount * scale

			char:UpdateAttrib(key, value)
			gained[#gained + 1] = string.format("%s +%.2f", attribute.name, value)
		end
	end

	record.n = record.n + 1
	record.t = os.time()
	log[id] = record
	char:SetData("readLog", log)

	local text = string.format("Вы прочли «%s»", item:GetName())

	if (#gained > 0) then
		text = text .. ": " .. table.concat(gained, ", ")
	end

	if (bRepeat) then
		text = text .. " (повторное чтение)"
	end

	client:Notify(text)
	ix.readables.OpenContent(client, item)

	hook.Run("PlayerReadMaterial", client, item, scale)
end

-- Чтение прерывается, если игрок получил урон.
function PLUGIN:PlayerHurt(client, attacker, health, damage)
	ix.readables.CancelReading(client)
end

function PLUGIN:PlayerDeath(client)
	client.ixReading = nil
end

-- Ловкость снижает урон от падения.
function PLUGIN:EntityTakeDamage(entity, dmgInfo)
	if (IsValid(entity) and entity:IsPlayer() and dmgInfo:IsFallDamage()) then
		local mul = ix.readables.GetFallDamageMultiplier(entity)

		if (mul < 1) then
			dmgInfo:ScaleDamage(mul)
		end
	end
end
