local PLUGIN = PLUGIN

util.AddNetworkString("ixTablet.Open")
util.AddNetworkString("ixTablet.Request")
util.AddNetworkString("ixTablet.Response")
util.AddNetworkString("ixTablet.Bind")

resource.AddFile("materials/tablet/tablet.png")

-- ========== Хранилище ==========

local function BuildDB(saved)
	saved = saved or {}

	return {
		accounts = saved.accounts or {},
		roster = saved.roster or {},
		notes = saved.notes or {},
		markers = saved.markers or {},
		orders = saved.orders or {},
		messages = saved.messages or {},
		log = saved.log or {},
		nextID = saved.nextID or 1
	}
end

PLUGIN.db = BuildDB(PLUGIN.db)

function PLUGIN:LoadData()
	self.db = BuildDB(self:GetData(nil, true))
end

function PLUGIN:SaveData()
	self:SetData(self.db, true)
end

local function Persist()
	PLUGIN:SetData(PLUGIN.db, true)
end

local function NextID()
	local id = PLUGIN.db.nextID
	PLUGIN.db.nextID = id + 1

	return tostring(id)
end

local function Clean(value, max)
	return string.sub(string.Trim(tostring(value or "")), 1, max)
end

local function Send(client, action, data)
	net.Start("ixTablet.Response")
		net.WriteString(action)
		net.WriteTable(data or {})
	net.Send(client)
end

local function Err(client, msg)
	Send(client, "error", {msg = msg})
end

-- Журнал действий фракции (виден deputy / commander).
local function Log(fid, kind, text)
	local list = PLUGIN.db.log[fid]

	if (!list) then
		list = {}
		PLUGIN.db.log[fid] = list
	end

	list[#list + 1] = {time = os.time(), kind = kind, text = text}

	while (#list > 150) do
		table.remove(list, 1)
	end
end

-- Все онлайн-игроки фракции.
local function EachMember(fid, callback)
	for _, ply in ipairs(player.GetAll()) do
		local c = ply:GetCharacter()

		if (c) then
			local f = ix.faction.indices[c:GetFaction()]

			if (f and f.uniqueID == fid) then
				callback(ply, c)
			end
		end
	end
end

-- ========== Состав / контекст ==========

function PLUGIN:EnsureRoster(char)
	local faction = ix.faction.indices[char:GetFaction()]

	if (!faction or !ix.tablet.factions[faction.uniqueID]) then
		return
	end

	local id = tostring(char:GetID())
	local entry = self.db.roster[id]

	if (!entry or entry.faction != faction.uniqueID) then
		entry = {rank = 1, reprimands = {}, commends = {}, faction = faction.uniqueID, since = os.time()}
		self.db.roster[id] = entry
	end

	entry.commends = entry.commends or {}
	entry.since = entry.since or os.time()
	entry.name = char:GetName()
	entry.model = char:GetModel()

	return entry
end

function PLUGIN:GetContext(client)
	if (!client.ixTabletOpen) then return end

	local char = client:GetCharacter()
	if (!char) then return end

	local faction = ix.faction.indices[char:GetFaction()]
	if (!faction or !ix.tablet.factions[faction.uniqueID]) then return end

	local inventory = char:GetInventory()
	if (!inventory or !inventory:HasItem("tablet")) then return end

	return char, faction.uniqueID, tostring(char:GetID())
end

function ix.tablet.Open(client)
	local char = client:GetCharacter()
	if (!char) then return end

	local faction = ix.faction.indices[char:GetFaction()]

	if (!faction or !ix.tablet.factions[faction.uniqueID]) then
		client:Notify("Планшет не принимает ваши данные доступа.")
		return
	end

	local inventory = char:GetInventory()

	if (!inventory or !inventory:HasItem("tablet")) then
		client:Notify("У вас нет служебного планшета.")
		return
	end

	PLUGIN:EnsureRoster(char)

	client.ixTabletOpen = true
	client.ixTabletAuth = nil

	net.Start("ixTablet.Open")
		net.WriteBool(PLUGIN.db.accounts[tostring(char:GetID())] != nil)
	net.Send(client)
end

function PLUGIN:PlayerLoadedCharacter(client, char, lastChar)
	client.ixTabletOpen = nil
	client.ixTabletAuth = nil

	if (lastChar) then
		local old = self.db.roster[tostring(lastChar:GetID())]

		if (old) then
			old.seen = os.time()
		end
	end

	local entry = self:EnsureRoster(char)

	if (entry) then
		entry.seen = os.time()
	end
end

function PLUGIN:PlayerDisconnected(client)
	local char = client:GetCharacter()
	local entry = char and self.db.roster[tostring(char:GetID())]

	if (entry) then
		entry.seen = os.time()
	end
end

function PLUGIN:PlayerDeath(client)
	client.ixTabletOpen = nil
	client.ixTabletAuth = nil
end

function PLUGIN:PreCharacterDeleted(client, char)
	local id = tostring(char:GetID())

	self.db.accounts[id] = nil
	self.db.roster[id] = nil
	self.db.messages[id] = nil

	for noteID, note in pairs(self.db.notes) do
		if (note.owner == id) then
			self.db.notes[noteID] = nil
		end
	end

	Persist()
end

-- ========== Сборка данных для клиента ==========

function PLUGIN:BuildSync(client, char, fid, id)
	local cfg = ix.tablet.factions[fid]
	local faction = ix.faction.indices[char:GetFaction()]
	local isCmd = ix.tablet.IsCommand(client)
	local mine = self:EnsureRoster(char)
	local db = self.db

	local out = {
		ranks = cfg.ranks,
		roster = {},
		notes = {},
		markers = {},
		orders = {},
		inbox = {},
		unread = 0,
		stats = {total = 0, online = 0},
		me = {
			id = id,
			name = char:GetName(),
			model = char:GetModel(),
			login = db.accounts[id] and db.accounts[id].login or "",
			factionName = faction.name,
			color = {r = faction.color.r, g = faction.color.g, b = faction.color.b},
			rank = mine.rank,
			rankName = cfg.ranks[mine.rank] or "?",
			canManage = isCmd,
			since = mine.since,
			reprimands = mine.reprimands,
			commends = mine.commends
		}
	}

	for rid, entry in pairs(db.roster) do
		if (entry.faction == fid) then
			local c = ix.char.loaded[tonumber(rid)]
			local ply = c and c:GetPlayer()
			local online = IsValid(ply)

			if (online) then
				entry.name = c:GetName()
				entry.model = c:GetModel()
			end

			out.stats.total = out.stats.total + 1

			if (online) then
				out.stats.online = out.stats.online + 1
			end

			local full = isCmd or rid == id

			out.roster[#out.roster + 1] = {
				id = rid,
				name = entry.name or "?",
				model = entry.model,
				rank = entry.rank,
				online = online,
				since = entry.since,
				seen = entry.seen,
				count = #entry.reprimands,
				commendCount = #entry.commends,
				reprimands = full and entry.reprimands or {},
				commends = full and entry.commends or {}
			}
		end
	end

	for nid, note in pairs(db.notes) do
		local own = note.owner == id

		if (own or (note.shared and note.faction == fid)) then
			out.notes[#out.notes + 1] = {
				id = nid,
				title = note.title,
				text = note.text,
				shared = note.shared,
				author = note.ownerName,
				time = note.time,
				canEdit = own or (isCmd and note.faction == fid)
			}
		end
	end

	for mid, marker in pairs(db.markers) do
		if (marker.faction == fid) then
			out.markers[#out.markers + 1] = {
				id = mid, x = marker.x, y = marker.y,
				text = marker.text, kind = marker.kind or 5, by = marker.by
			}
		end
	end

	for oid, order in pairs(db.orders) do
		if (order.faction == fid) then
			out.orders[#out.orders + 1] = {
				id = oid, title = order.title, text = order.text,
				priority = order.priority, pinned = order.pinned,
				by = order.by, time = order.time
			}
		end
	end

	for _, msg in ipairs(db.messages[id] or {}) do
		out.inbox[#out.inbox + 1] = {
			id = msg.id, from = msg.from, fromName = msg.fromName,
			text = msg.text, time = msg.time, read = msg.read
		}

		if (!msg.read) then
			out.unread = out.unread + 1
		end
	end

	if (isCmd) then
		out.log = db.log[fid] or {}
	end

	return out
end

function PLUGIN:SendSync(client, char, fid, id, extra)
	local data = self:BuildSync(client, char, fid, id)

	for k, v in pairs(extra or {}) do
		data[k] = v
	end

	Send(client, "sync", data)
end

-- ========== Обработка запросов ==========

function PLUGIN:HandleRequest(client, action, data)
	if (action == "close") then
		client.ixTabletOpen = nil
		client.ixTabletAuth = nil
		return
	end

	local char, fid, id = self:GetContext(client)

	if (!char) then
		client.ixTabletOpen = nil
		client.ixTabletAuth = nil
		Send(client, "kicked")
		return
	end

	local cfg = ix.tablet.factions[fid]
	local db = self.db

	-- ----- Авторизация -----
	if (action == "login" or action == "register") then
		if ((client.ixTabletLock or 0) > CurTime()) then
			return Err(client, "Слишком много попыток. Подождите.")
		end

		local login = string.lower(Clean(data.login, 24))
		local pass = Clean(data.pass, 32)

		if (action == "register") then
			if (db.accounts[id]) then
				return Err(client, "Аккаунт уже существует.")
			end

			if (#login < 3 or !string.match(login, "^[%w_%.%-]+$")) then
				return Err(client, "Логин: 3–24 символа, латиница, цифры, _ . -")
			end

			if (#pass < 4) then
				return Err(client, "Пароль должен быть не короче 4 символов.")
			end

			for _, acc in pairs(db.accounts) do
				if (acc.login == login) then
					return Err(client, "Этот логин уже занят.")
				end
			end

			local salt = util.SHA1(tostring(SysTime()) .. math.random())
			db.accounts[id] = {login = login, salt = salt, hash = util.SHA256(salt .. pass)}
			Log(fid, "account", char:GetName() .. " зарегистрировал(а) доступ к планшету.")
			Persist()
		else
			local acc = db.accounts[id]
			local ok = acc and acc.login == login and util.SHA256(acc.salt .. pass) == acc.hash

			if (!ok) then
				client.ixTabletFails = (client.ixTabletFails or 0) + 1

				if (client.ixTabletFails >= 5) then
					client.ixTabletFails = 0
					client.ixTabletLock = CurTime() + 30
				end

				return Err(client, "Неверный логин или пароль.")
			end
		end

		client.ixTabletFails = 0
		client.ixTabletAuth = id

		local entry = self:EnsureRoster(char)
		entry.seen = os.time()

		self:SendSync(client, char, fid, id)

		return
	end

	-- Всё ниже — только после входа.
	if (client.ixTabletAuth != id) then return end

	local isCmd = ix.tablet.IsCommand(client)

	if (action == "sync") then
		return self:SendSync(client, char, fid, id)
	end

	if (action == "positions") then
		local list = {}

		EachMember(fid, function(ply, c)
			if (ply:Alive()) then
				local pos = ply:GetPos()
				local entry = db.roster[tostring(c:GetID())]

				list[#list + 1] = {
					id = tostring(c:GetID()),
					name = c:GetName(),
					rank = entry and cfg.ranks[entry.rank] or "",
					x = math.Round(pos.x),
					y = math.Round(pos.y),
					yaw = math.Round(ply:EyeAngles().y)
				}
			end
		end)

		return Send(client, "positions", {list = list})
	end

	-- ----- Смена пароля -----
	if (action == "passwd") then
		local acc = db.accounts[id]
		local old, new = Clean(data.old, 32), Clean(data.new, 32)

		if (!acc or util.SHA256(acc.salt .. old) != acc.hash) then
			return Err(client, "Текущий пароль указан неверно.")
		end

		if (#new < 4) then
			return Err(client, "Новый пароль должен быть не короче 4 символов.")
		end

		acc.salt = util.SHA1(tostring(SysTime()) .. math.random())
		acc.hash = util.SHA256(acc.salt .. new)
		Persist()

		return self:SendSync(client, char, fid, id, {toast = "Пароль изменён."})
	end

	-- ----- Звания / выговоры / поощрения / сброс доступа (deputy, commander) -----
	if (action == "rank" or action == "reprimand" or action == "unreprimand"
	or action == "commend" or action == "uncommend" or action == "resetAccount") then
		if (!isCmd) then
			return Err(client, "Недостаточно прав.")
		end

		local tid = tostring(data.id or "")
		local entry = db.roster[tid]

		if (!entry or entry.faction != fid) then
			return Err(client, "Боец не найден.")
		end

		if (tid == id) then
			return Err(client, "Нельзя применять это к самому себе.")
		end

		local targetChar = ix.char.loaded[tonumber(tid)]
		local target = targetChar and targetChar:GetPlayer()
		local by = char:GetName()

		if (action == "rank") then
			local dir = tonumber(data.dir) == -1 and -1 or 1
			local old = entry.rank
			local new = math.Clamp(old + dir, 1, #cfg.ranks)

			if (new == old) then
				return Err(client, "Достигнут предел звания.")
			end

			entry.rank = new
			Log(fid, "rank", string.format("%s %s %s: %s → %s.", by, dir == 1 and "повысил(а)" or "понизил(а)", entry.name, cfg.ranks[old], cfg.ranks[new]))
			Persist()

			hook.Run("TabletRankChanged", targetChar, entry, old, new, client)

			if (IsValid(target)) then
				target:Notify(string.format("Ваше звание изменено: %s.", cfg.ranks[new]))
			end

			return self:SendSync(client, char, fid, id, {toast = string.format("%s: %s", entry.name, cfg.ranks[new])})
		end

		if (action == "reprimand" or action == "commend") then
			local isRep = action == "reprimand"
			local list = isRep and entry.reprimands or entry.commends
			local text = Clean(data.text, 200)

			if (#text < 3) then
				return Err(client, isRep and "Укажите причину выговора." or "Укажите причину поощрения.")
			end

			if (#list >= 20) then
				return Err(client, "Достигнут лимит записей (20).")
			end

			list[#list + 1] = {text = text, by = by, time = os.time()}
			Log(fid, isRep and "reprimand" or "commend", string.format("%s: %s — %s.", by, isRep and ("выговор " .. entry.name) or ("поощрение " .. entry.name), text))
			Persist()

			if (IsValid(target)) then
				target:Notify(isRep and "Вам выдан выговор. Подробности в планшете." or "Вам объявлено поощрение. Подробности в планшете.")
			end

			return self:SendSync(client, char, fid, id, {toast = isRep and "Выговор выдан." or "Поощрение объявлено."})
		end

		if (action == "unreprimand" or action == "uncommend") then
			local isRep = action == "unreprimand"
			local list = isRep and entry.reprimands or entry.commends
			local index = tonumber(data.index)

			if (!index or !list[index]) then
				return Err(client, "Запись не найдена.")
			end

			table.remove(list, index)
			Log(fid, isRep and "reprimand" or "commend", string.format("%s снял(а) %s у %s.", by, isRep and "выговор" or "поощрение", entry.name))
			Persist()

			return self:SendSync(client, char, fid, id, {toast = "Запись удалена."})
		end

		-- resetAccount
		db.accounts[tid] = nil
		Log(fid, "account", string.format("%s сбросил(а) доступ к планшету: %s.", by, entry.name))
		Persist()

		if (IsValid(target)) then
			target:Notify("Ваш доступ к планшету сброшен. Зарегистрируйтесь заново.")
		end

		return self:SendSync(client, char, fid, id, {toast = "Доступ сброшен."})
	end

	-- ----- Приказы -----
	if (action == "order") then
		if (!isCmd) then
			return Err(client, "Недостаточно прав.")
		end

		local title = Clean(data.title, 64)
		local text = string.sub(tostring(data.text or ""), 1, 800)
		local priority = math.Clamp(math.floor(tonumber(data.priority) or 1), 1, 3)

		if (#title < 3) then
			return Err(client, "Укажите заголовок приказа.")
		end

		local mineOrders, oldest = {}, nil

		for oid, o in pairs(db.orders) do
			if (o.faction == fid) then
				mineOrders[#mineOrders + 1] = oid

				if (!o.pinned and (!oldest or o.time < db.orders[oldest].time)) then
					oldest = oid
				end
			end
		end

		if (#mineOrders >= 30) then
			if (!oldest) then
				return Err(client, "Достигнут лимит приказов. Открепите или удалите старые.")
			end

			db.orders[oldest] = nil
		end

		local oid = NextID()

		db.orders[oid] = {
			faction = fid, title = title, text = text, priority = priority,
			pinned = tobool(data.pinned), by = char:GetName(), time = os.time()
		}

		Log(fid, "order", string.format("%s издал(а) приказ: «%s».", char:GetName(), title))
		Persist()

		if (priority == 3) then
			EachMember(fid, function(ply)
				ply:Notify("Срочный приказ: " .. title)
			end)
		end

		return self:SendSync(client, char, fid, id, {orderPosted = true, toast = "Приказ опубликован."})
	end

	if (action == "orderPin" or action == "orderDel") then
		local order = db.orders[tostring(data.id or "")]

		if (!isCmd or !order or order.faction != fid) then
			return Err(client, "Недостаточно прав.")
		end

		if (action == "orderPin") then
			order.pinned = !order.pinned
		else
			db.orders[tostring(data.id)] = nil
			Log(fid, "order", string.format("%s отменил(а) приказ: «%s».", char:GetName(), order.title))
		end

		Persist()

		return self:SendSync(client, char, fid, id)
	end

	-- ----- Личные сообщения -----
	if (action == "msgSend") then
		if ((client.ixTabletMsgNext or 0) > CurTime()) then
			return Err(client, "Не так быстро.")
		end

		local to = tostring(data.to or "")
		local target = db.roster[to]
		local text = string.Trim(string.sub(tostring(data.text or ""), 1, 500))

		if (!target or target.faction != fid or to == id) then
			return Err(client, "Получатель не найден.")
		end

		if (text == "") then
			return Err(client, "Сообщение пустое.")
		end

		client.ixTabletMsgNext = CurTime() + 3

		local inbox = db.messages[to]

		if (!inbox) then
			inbox = {}
			db.messages[to] = inbox
		end

		inbox[#inbox + 1] = {id = NextID(), from = id, fromName = char:GetName(), text = text, time = os.time(), read = false}

		while (#inbox > 50) do
			table.remove(inbox, 1)
		end

		Persist()

		local targetChar = ix.char.loaded[tonumber(to)]
		local ply = targetChar and targetChar:GetPlayer()

		if (IsValid(ply)) then
			ply:Notify("Новое сообщение в планшете от " .. char:GetName() .. ".")
		end

		return self:SendSync(client, char, fid, id, {sent = true, toast = "Сообщение отправлено."})
	end

	if (action == "msgRead" or action == "msgDel") then
		local inbox = db.messages[id] or {}
		local mid = tostring(data.id or "")

		for i, msg in ipairs(inbox) do
			if (msg.id == mid) then
				if (action == "msgRead") then
					msg.read = true
				else
					table.remove(inbox, i)
				end

				break
			end
		end

		Persist()

		return self:SendSync(client, char, fid, id)
	end

	-- ----- Записки -----
	if (action == "noteSave") then
		local title = Clean(data.title, 48)
		local text = string.sub(tostring(data.text or ""), 1, 2000)

		if (title == "") then
			title = "Без названия"
		end

		local note = data.id and db.notes[tostring(data.id)]

		if (note) then
			if (!(note.owner == id or (isCmd and note.faction == fid))) then
				return Err(client, "Нет прав на редактирование.")
			end
		else
			local count = 0

			for _, n in pairs(db.notes) do
				if (n.owner == id) then count = count + 1 end
			end

			if (count >= 30) then
				return Err(client, "Лимит записок (30) исчерпан.")
			end

			note = {id = NextID(), owner = id, ownerName = char:GetName(), faction = fid}
			db.notes[note.id] = note
		end

		note.title = title
		note.text = text
		note.shared = tobool(data.shared)
		note.time = os.time()
		Persist()

		return self:SendSync(client, char, fid, id, {saved = note.id, toast = "Записка сохранена."})
	end

	if (action == "noteDelete") then
		local note = db.notes[tostring(data.id or "")]

		if (!note or !(note.owner == id or (isCmd and note.faction == fid))) then
			return Err(client, "Нет прав на удаление.")
		end

		db.notes[note.id] = nil
		Persist()

		return self:SendSync(client, char, fid, id, {cleared = true, toast = "Записка удалена."})
	end

	-- ----- Метки на карте (deputy, commander) -----
	if (action == "markerAdd") then
		if (!isCmd) then
			return Err(client, "Недостаточно прав.")
		end

		local count = 0

		for _, m in pairs(db.markers) do
			if (m.faction == fid) then count = count + 1 end
		end

		if (count >= 50) then
			return Err(client, "Лимит меток (50).")
		end

		local x, y = tonumber(data.x), tonumber(data.y)
		if (!x or !y) then return end

		db.markers[NextID()] = {
			faction = fid,
			x = math.Clamp(x, -32768, 32768),
			y = math.Clamp(y, -32768, 32768),
			text = Clean(data.text, 40),
			kind = math.Clamp(math.floor(tonumber(data.kind) or 5), 1, #ix.tablet.markerKinds),
			by = char:GetName()
		}

		Log(fid, "marker", char:GetName() .. " поставил(а) метку на карте.")
		Persist()

		return self:SendSync(client, char, fid, id)
	end

	if (action == "markerDel") then
		local marker = db.markers[tostring(data.id or "")]

		if (!isCmd or !marker or marker.faction != fid) then
			return Err(client, "Недостаточно прав.")
		end

		db.markers[tostring(data.id)] = nil
		Persist()

		return self:SendSync(client, char, fid, id)
	end
end

net.Receive("ixTablet.Request", function(_, client)
	local action = net.ReadString()
	local data = net.ReadTable()

	if ((client.ixTabletNext or 0) > CurTime()) then return end
	client.ixTabletNext = CurTime() + 0.1

	if (type(data) != "table") then return end

	PLUGIN:HandleRequest(client, action, data)
end)

-- Нажатие клавиши открытия (M). Молча игнорируем, если планшета нет или фракция не подходит.
net.Receive("ixTablet.Bind", function(_, client)
	if ((client.ixTabletBindNext or 0) > CurTime()) then return end
	client.ixTabletBindNext = CurTime() + 1

	if (!client:Alive()) then return end

	local char = client:GetCharacter()
	if (!char) then return end

	local faction = ix.faction.indices[char:GetFaction()]
	if (!faction or !ix.tablet.factions[faction.uniqueID]) then return end

	local inventory = char:GetInventory()
	if (!inventory or !inventory:HasItem("tablet")) then return end

	ix.tablet.Open(client)
end)local PLUGIN = PLUGIN

util.AddNetworkString("ixTablet.Open")
util.AddNetworkString("ixTablet.Request")
util.AddNetworkString("ixTablet.Response")
util.AddNetworkString("ixTablet.Bind")

resource.AddFile("materials/tablet/tablet.png")

for _, name in ipairs({"home", "people", "flag", "mail", "doc", "map", "log", "user"}) do
	resource.AddFile("materials/tablet/icons/" .. name .. ".png")
end

-- ========== Хранилище ==========

local function BuildDB(saved)
	saved = saved or {}

	return {
		accounts = saved.accounts or {},
		roster = saved.roster or {},
		notes = saved.notes or {},
		markers = saved.markers or {},
		orders = saved.orders or {},
		messages = saved.messages or {},
		log = saved.log or {},
		nextID = saved.nextID or 1,
		serial = saved.serial or 0
	}
end

PLUGIN.db = BuildDB(PLUGIN.db)

function PLUGIN:LoadData()
	self.db = BuildDB(self:GetData(nil, true))
end

function PLUGIN:SaveData()
	self:SetData(self.db, true)
end

local function Persist()
	PLUGIN:SetData(PLUGIN.db, true)
end

local function NextID()
	local id = PLUGIN.db.nextID
	PLUGIN.db.nextID = id + 1

	return tostring(id)
end

-- Серийный номер устройства. Аккаунт привязывается именно к нему.
local function NewSerial()
	PLUGIN.db.serial = (PLUGIN.db.serial or 0) + 1
	Persist()

	return string.format("ТБ-%05d", PLUGIN.db.serial)
end

local function Clean(value, max)
	return string.sub(string.Trim(tostring(value or "")), 1, max)
end

local function Send(client, action, data)
	net.Start("ixTablet.Response")
		net.WriteString(action)
		net.WriteTable(data or {})
	net.Send(client)
end

local function Err(client, msg)
	Send(client, "error", {msg = msg})
end

local function Reset(client)
	client.ixTabletOpen = nil
	client.ixTabletAuth = nil
	client.ixTabletItem = nil
	client.ixTabletOwner = nil
end

-- Журнал действий фракции (виден deputy / commander).
local function Log(fid, kind, text)
	local list = PLUGIN.db.log[fid]

	if (!list) then
		list = {}
		PLUGIN.db.log[fid] = list
	end

	list[#list + 1] = {time = os.time(), kind = kind, text = text}

	while (#list > 150) do
		table.remove(list, 1)
	end
end

-- Все онлайн-игроки фракции.
local function EachMember(fid, callback)
	for _, ply in ipairs(player.GetAll()) do
		local c = ply:GetCharacter()

		if (c) then
			local f = ix.faction.indices[c:GetFaction()]

			if (f and f.uniqueID == fid) then
				callback(ply, c)
			end
		end
	end
end

-- ========== Состав ==========

function PLUGIN:EnsureRoster(char)
	local faction = ix.faction.indices[char:GetFaction()]

	if (!faction or !ix.tablet.factions[faction.uniqueID]) then
		return
	end

	local id = tostring(char:GetID())
	local entry = self.db.roster[id]

	if (!entry or entry.faction != faction.uniqueID) then
		entry = {rank = 1, reprimands = {}, commends = {}, faction = faction.uniqueID, since = os.time()}
		self.db.roster[id] = entry
	end

	entry.commends = entry.commends or {}
	entry.since = entry.since or os.time()
	entry.name = char:GetName()
	entry.model = char:GetModel()

	return entry
end

-- Права управления. У владельца — по его текущей группе SAM (и запоминаются);
-- у того, кто держит чужой планшет, — то, что было запомнено за владельцем.
function PLUGIN:IsCommand(client, char, id, entry)
	if (tostring(char:GetID()) == id) then
		entry.cmd = ix.tablet.IsCommand(client)
	end

	return entry.cmd == true
end

-- ========== Устройства (предметы "tablet") ==========

local function TabletItems(char)
	local list = {}
	local inventory = char:GetInventory()

	if (inventory) then
		for _, item in pairs(inventory:GetItems()) do
			if (item.uniqueID == "tablet") then
				list[#list + 1] = item
			end
		end
	end

	table.sort(list, function(a, b) return a:GetID() < b:GetID() end)

	return list
end

local function FindTabletByID(char, itemID)
	for _, item in ipairs(TabletItems(char)) do
		if (item:GetID() == itemID) then
			return item
		end
	end
end

-- Какой планшет открывать по клавише: свой рабочий → пустой → любой другой (чужой).
function PLUGIN:PickTablet(char, id)
	local acc = self.db.accounts[id]
	local own, blank, other

	for _, item in ipairs(TabletItems(char)) do
		local owner = item:GetData("owner")

		if (owner == id) then
			if (acc and acc.device and acc.device == item:GetData("serial")) then
				return item
			end

			own = own or item
		elseif (!owner) then
			blank = blank or item
		else
			other = other or item
		end
	end

	return own or blank or other
end

function PLUGIN:OwnsTablet(char, id)
	for _, item in ipairs(TabletItems(char)) do
		if (item:GetData("owner") == id) then
			return true
		end
	end

	return false
end

-- Закрепляет планшет за персонажем и запоминает его имя.
function PLUGIN:BindTablet(item, char)
	item:SetData("owner", tostring(char:GetID()))
	item:SetData("ownerName", char:GetName())
	item:SetData("issued", os.time())

	if (!item:GetData("serial")) then
		item:SetData("serial", NewSerial())
	end
end

-- Выдача нового именного планшета. Аккаунт (если есть) перепривязывается к нему.
function PLUGIN:IssueTablet(char)
	local inventory = char:GetInventory()

	if (!inventory) then
		return false, "у персонажа нет инвентаря"
	end

	local entry = self:EnsureRoster(char)

	if (!entry) then
		return false, "фракция персонажа не поддерживается планшетом"
	end

	local id = tostring(char:GetID())
	local serial = NewSerial()

	local x, y = inventory:Add("tablet", 1, {
		owner = id,
		ownerName = char:GetName(),
		serial = serial,
		issued = os.time()
	})

	if (x == false) then
		return false, tostring(y or "нет места в инвентаре")
	end

	local acc = self.db.accounts[id]

	if (acc) then
		acc.device = serial
	end

	Persist()

	return true
end

-- Планшет выдаётся каждому новому персонажу.
function PLUGIN:OnCharacterCreated(client, char)
	self:IssueTablet(char)
end

-- Открытие планшета. item — конкретное устройство (из меню предмета) или nil (по клавише).
function ix.tablet.Open(client, item)
	local char = client:GetCharacter()
	if (!char or !client:Alive()) then return end

	local id = tostring(char:GetID())

	PLUGIN:EnsureRoster(char)

	item = item or PLUGIN:PickTablet(char, id)

	if (!item) then
		client:Notify("У вас нет служебного планшета.")
		return
	end

	local owner = item:GetData("owner")

	-- Пустой планшет (выдан админом/до обновления) закрепляется за тем, кто открыл его первым.
	if (!owner) then
		if (!PLUGIN.db.roster[id]) then
			client:Notify("Планшет не принимает ваши данные доступа.")
			return
		end

		if (PLUGIN:OwnsTablet(char, id)) then
			client:Notify("У вас уже есть именной планшет. Этот не настроен.")
			return
		end

		PLUGIN:BindTablet(item, char)
		owner = id
	end

	local entry = PLUGIN.db.roster[owner]

	if (!entry or !ix.tablet.factions[entry.faction]) then
		client:Notify("Планшет не отвечает: данные его владельца недоступны.")
		return
	end

	if (!item:GetData("serial")) then
		item:SetData("serial", NewSerial())
	end

	-- Один аккаунт — одно устройство: аккаунт принимает только свой планшет.
	local acc = PLUGIN.db.accounts[owner]

	if (acc and acc.device and acc.device != item:GetData("serial")) then
		client:Notify("Этот планшет не привязан к учётной записи. Доступ закрыт.")
		return
	end

	local faction = ix.faction.teams[entry.faction]

	client.ixTabletOpen = true
	client.ixTabletAuth = nil
	client.ixTabletItem = item:GetID()
	client.ixTabletOwner = owner

	net.Start("ixTablet.Open")
		net.WriteBool(acc != nil)
		net.WriteTable({
			serial = item:GetData("serial"),
			owner = item:GetData("ownerName") or entry.name or "?",
			issued = item:GetData("issued"),
			mine = owner == id,
			faction = faction and faction.name or "—",
			color = faction and {r = faction.color.r, g = faction.color.g, b = faction.color.b} or {r = 255, g = 255, b = 255}
		})
	net.Send(client)
end

-- Проверка сессии: планшет по-прежнему в инвентаре и принадлежит тому же владельцу.
function PLUGIN:GetContext(client)
	if (!client.ixTabletOpen) then return end

	local char = client:GetCharacter()
	if (!char) then return end

	local item = FindTabletByID(char, client.ixTabletItem)
	if (!item) then return end

	local owner = item:GetData("owner")
	if (!owner or owner != client.ixTabletOwner) then return end

	local entry = self.db.roster[owner]
	if (!entry or !ix.tablet.factions[entry.faction]) then return end

	return char, entry.faction, owner, entry, item
end

function PLUGIN:PlayerLoadedCharacter(client, char, lastChar)
	Reset(client)

	if (lastChar) then
		local old = self.db.roster[tostring(lastChar:GetID())]

		if (old) then
			old.seen = os.time()
		end
	end

	local entry = self:EnsureRoster(char)

	if (entry) then
		entry.seen = os.time()
		entry.cmd = ix.tablet.IsCommand(client)
	end
end

function PLUGIN:PlayerDisconnected(client)
	local char = client:GetCharacter()
	local entry = char and self.db.roster[tostring(char:GetID())]

	if (entry) then
		entry.seen = os.time()
	end
end

function PLUGIN:PlayerDeath(client)
	Reset(client)
end

function PLUGIN:PreCharacterDeleted(client, char)
	local id = tostring(char:GetID())

	self.db.accounts[id] = nil
	self.db.roster[id] = nil
	self.db.messages[id] = nil

	for noteID, note in pairs(self.db.notes) do
		if (note.owner == id) then
			self.db.notes[noteID] = nil
		end
	end

	Persist()
end

-- ========== Сборка данных для клиента ==========

function PLUGIN:BuildSync(client, fid, id, item)
	local cfg = ix.tablet.factions[fid]
	local faction = ix.faction.teams[fid] or {name = fid, color = Color(255, 255, 255)}
	local char = client:GetCharacter()
	local db = self.db
	local mine = db.roster[id]
	local isCmd = self:IsCommand(client, char, id, mine)

	local out = {
		ranks = cfg.ranks,
		roster = {},
		notes = {},
		markers = {},
		orders = {},
		inbox = {},
		unread = 0,
		stats = {total = 0, online = 0},
		me = {
			id = id,
			name = mine.name or "?",
			model = mine.model,
			login = db.accounts[id] and db.accounts[id].login or "",
			factionName = faction.name,
			color = {r = faction.color.r, g = faction.color.g, b = faction.color.b},
			rank = mine.rank,
			rankName = cfg.ranks[mine.rank] or "?",
			canManage = isCmd,
			since = mine.since,
			reprimands = mine.reprimands,
			commends = mine.commends,
			device = {
				serial = item:GetData("serial"),
				owner = item:GetData("ownerName") or mine.name or "?",
				issued = item:GetData("issued"),
				mine = tostring(char:GetID()) == id
			}
		}
	}

	for rid, entry in pairs(db.roster) do
		if (entry.faction == fid) then
			local c = ix.char.loaded[tonumber(rid)]
			local ply = c and c:GetPlayer()
			local online = IsValid(ply)

			if (online) then
				entry.name = c:GetName()
				entry.model = c:GetModel()
			end

			out.stats.total = out.stats.total + 1

			if (online) then
				out.stats.online = out.stats.online + 1
			end

			local full = isCmd or rid == id

			out.roster[#out.roster + 1] = {
				id = rid,
				name = entry.name or "?",
				model = entry.model,
				rank = entry.rank,
				online = online,
				since = entry.since,
				seen = entry.seen,
				count = #entry.reprimands,
				commendCount = #entry.commends,
				reprimands = full and entry.reprimands or {},
				commends = full and entry.commends or {}
			}
		end
	end

	for nid, note in pairs(db.notes) do
		local own = note.owner == id

		if (own or (note.shared and note.faction == fid)) then
			out.notes[#out.notes + 1] = {
				id = nid,
				title = note.title,
				text = note.text,
				shared = note.shared,
				author = note.ownerName,
				time = note.time,
				canEdit = own or (isCmd and note.faction == fid)
			}
		end
	end

	for mid, marker in pairs(db.markers) do
		if (marker.faction == fid) then
			out.markers[#out.markers + 1] = {
				id = mid, x = marker.x, y = marker.y,
				text = marker.text, kind = marker.kind or 5, by = marker.by
			}
		end
	end

	for oid, order in pairs(db.orders) do
		if (order.faction == fid) then
			out.orders[#out.orders + 1] = {
				id = oid, title = order.title, text = order.text,
				priority = order.priority, pinned = order.pinned,
				by = order.by, time = order.time
			}
		end
	end

	for _, msg in ipairs(db.messages[id] or {}) do
		out.inbox[#out.inbox + 1] = {
			id = msg.id, from = msg.from, fromName = msg.fromName,
			text = msg.text, time = msg.time, read = msg.read
		}

		if (!msg.read) then
			out.unread = out.unread + 1
		end
	end

	if (isCmd) then
		out.log = db.log[fid] or {}
	end

	return out
end

function PLUGIN:SendSync(client, fid, id, item, extra)
	local data = self:BuildSync(client, fid, id, item)

	for k, v in pairs(extra or {}) do
		data[k] = v
	end

	Send(client, "sync", data)
end

-- ========== Обработка запросов ==========

function PLUGIN:HandleRequest(client, action, data)
	if (action == "close") then
		Reset(client)
		return
	end

	-- char — тот, кто держит планшет; id / me — владелец устройства (под ним идёт вся работа).
	local char, fid, id, me, item = self:GetContext(client)

	if (!char) then
		Reset(client)
		Send(client, "kicked")
		return
	end

	local cfg = ix.tablet.factions[fid]
	local db = self.db
	local serial = item:GetData("serial")

	local function Sync(extra)
		return self:SendSync(client, fid, id, item, extra)
	end

	-- ----- Авторизация -----
	if (action == "login" or action == "register") then
		if ((client.ixTabletLock or 0) > CurTime()) then
			return Err(client, "Слишком много попыток. Подождите.")
		end

		local login = string.lower(Clean(data.login, 24))
		local pass = Clean(data.pass, 32)
		local acc = db.accounts[id]

		if (action == "register") then
			if (acc) then
				return Err(client, "Аккаунт уже существует.")
			end

			if (tostring(char:GetID()) != id) then
				return Err(client, "Зарегистрировать доступ может только владелец планшета.")
			end

			if (#login < 3 or !string.match(login, "^[%w_%.%-]+$")) then
				return Err(client, "Логин: 3–24 символа, латиница, цифры, _ . -")
			end

			if (#pass < 4) then
				return Err(client, "Пароль должен быть не короче 4 символов.")
			end

			for _, other in pairs(db.accounts) do
				if (other.login == login) then
					return Err(client, "Этот логин уже занят.")
				end
			end

			local salt = util.SHA1(tostring(SysTime()) .. math.random())
			db.accounts[id] = {login = login, salt = salt, hash = util.SHA256(salt .. pass), device = serial}
			Log(fid, "account", me.name .. " зарегистрировал(а) доступ к планшету " .. serial .. ".")
			Persist()
		else
			if (!acc) then
				return Err(client, "Доступ ещё не зарегистрирован.")
			end

			-- Аккаунт принимает только то устройство, к которому он привязан.
			if (acc.device and acc.device != serial) then
				return Err(client, "Этот планшет не привязан к учётной записи.")
			end

			local ok = acc.login == login and util.SHA256(acc.salt .. pass) == acc.hash

			if (!ok) then
				client.ixTabletFails = (client.ixTabletFails or 0) + 1

				if (client.ixTabletFails >= 5) then
					client.ixTabletFails = 0
					client.ixTabletLock = CurTime() + 30
				end

				return Err(client, "Неверный логин или пароль.")
			end

			-- Старые аккаунты (до привязки) закрепляются за планшетом при первом входе.
			if (!acc.device) then
				acc.device = serial
			end
		end

		client.ixTabletFails = 0
		client.ixTabletAuth = id
		me.seen = os.time()
		Persist()

		return Sync()
	end

	-- Всё ниже — только после входа.
	if (client.ixTabletAuth != id) then return end

	-- Если аккаунт перепривязали к другому устройству, текущая сессия закрывается.
	local acc = db.accounts[id]

	if (!acc or acc.device != serial) then
		Reset(client)
		Send(client, "kicked")
		return
	end

	local isCmd = self:IsCommand(client, char, id, me)
	local by = me.name

	if (action == "sync") then
		return Sync()
	end

	if (action == "positions") then
		local list = {}

		EachMember(fid, function(ply, c)
			if (ply:Alive()) then
				local pos = ply:GetPos()
				local entry = db.roster[tostring(c:GetID())]

				list[#list + 1] = {
					id = tostring(c:GetID()),
					name = c:GetName(),
					rank = entry and cfg.ranks[entry.rank] or "",
					x = math.Round(pos.x),
					y = math.Round(pos.y),
					yaw = math.Round(ply:EyeAngles().y)
				}
			end
		end)

		return Send(client, "positions", {list = list})
	end

	-- ----- Смена пароля -----
	if (action == "passwd") then
		local old, new = Clean(data.old, 32), Clean(data.new, 32)

		if (util.SHA256(acc.salt .. old) != acc.hash) then
			return Err(client, "Текущий пароль указан неверно.")
		end

		if (#new < 4) then
			return Err(client, "Новый пароль должен быть не короче 4 символов.")
		end

		acc.salt = util.SHA1(tostring(SysTime()) .. math.random())
		acc.hash = util.SHA256(acc.salt .. new)
		Persist()

		return Sync({toast = "Пароль изменён."})
	end

	-- ----- Звания / выговоры / поощрения / сброс доступа (deputy, commander) -----
	if (action == "rank" or action == "reprimand" or action == "unreprimand"
	or action == "commend" or action == "uncommend" or action == "resetAccount") then
		if (!isCmd) then
			return Err(client, "Недостаточно прав.")
		end

		local tid = tostring(data.id or "")
		local entry = db.roster[tid]

		if (!entry or entry.faction != fid) then
			return Err(client, "Боец не найден.")
		end

		if (tid == id) then
			return Err(client, "Нельзя применять это к самому себе.")
		end

		local targetChar = ix.char.loaded[tonumber(tid)]
		local target = targetChar and targetChar:GetPlayer()

		if (action == "rank") then
			local dir = tonumber(data.dir) == -1 and -1 or 1
			local old = entry.rank
			local new = math.Clamp(old + dir, 1, #cfg.ranks)

			if (new == old) then
				return Err(client, "Достигнут предел звания.")
			end

			entry.rank = new
			Log(fid, "rank", string.format("%s %s %s: %s → %s.", by, dir == 1 and "повысил(а)" or "понизил(а)", entry.name, cfg.ranks[old], cfg.ranks[new]))
			Persist()

			hook.Run("TabletRankChanged", targetChar, entry, old, new, client)

			if (IsValid(target)) then
				target:Notify(string.format("Ваше звание изменено: %s.", cfg.ranks[new]))
			end

			return Sync({toast = string.format("%s: %s", entry.name, cfg.ranks[new])})
		end

		if (action == "reprimand" or action == "commend") then
			local isRep = action == "reprimand"
			local list = isRep and entry.reprimands or entry.commends
			local text = Clean(data.text, 200)

			if (#text < 3) then
				return Err(client, isRep and "Укажите причину выговора." or "Укажите причину поощрения.")
			end

			if (#list >= 20) then
				return Err(client, "Достигнут лимит записей (20).")
			end

			list[#list + 1] = {text = text, by = by, time = os.time()}
			Log(fid, isRep and "reprimand" or "commend", string.format("%s: %s — %s.", by, isRep and ("выговор " .. entry.name) or ("поощрение " .. entry.name), text))
			Persist()

			if (IsValid(target)) then
				target:Notify(isRep and "Вам выдан выговор. Подробности в планшете." or "Вам объявлено поощрение. Подробности в планшете.")
			end

			return Sync({toast = isRep and "Выговор выдан." or "Поощрение объявлено."})
		end

		if (action == "unreprimand" or action == "uncommend") then
			local isRep = action == "unreprimand"
			local list = isRep and entry.reprimands or entry.commends
			local index = tonumber(data.index)

			if (!index or !list[index]) then
				return Err(client, "Запись не найдена.")
			end

			table.remove(list, index)
			Log(fid, isRep and "reprimand" or "commend", string.format("%s снял(а) %s у %s.", by, isRep and "выговор" or "поощрение", entry.name))
			Persist()

			return Sync({toast = "Запись удалена."})
		end

		-- resetAccount: логин и пароль сбрасываются, планшет остаётся за владельцем.
		db.accounts[tid] = nil
		Log(fid, "account", string.format("%s сбросил(а) доступ к планшету: %s.", by, entry.name))
		Persist()

		if (IsValid(target)) then
			target:Notify("Ваш доступ к планшету сброшен. Зарегистрируйтесь заново.")
		end

		return Sync({toast = "Доступ сброшен."})
	end

	-- ----- Приказы -----
	if (action == "order") then
		if (!isCmd) then
			return Err(client, "Недостаточно прав.")
		end

		local title = Clean(data.title, 64)
		local text = string.sub(tostring(data.text or ""), 1, 800)
		local priority = math.Clamp(math.floor(tonumber(data.priority) or 1), 1, 3)

		if (#title < 3) then
			return Err(client, "Укажите заголовок приказа.")
		end

		local mineOrders, oldest = {}, nil

		for oid, o in pairs(db.orders) do
			if (o.faction == fid) then
				mineOrders[#mineOrders + 1] = oid

				if (!o.pinned and (!oldest or o.time < db.orders[oldest].time)) then
					oldest = oid
				end
			end
		end

		if (#mineOrders >= 30) then
			if (!oldest) then
				return Err(client, "Достигнут лимит приказов. Открепите или удалите старые.")
			end

			db.orders[oldest] = nil
		end

		local oid = NextID()

		db.orders[oid] = {
			faction = fid, title = title, text = text, priority = priority,
			pinned = tobool(data.pinned), by = by, time = os.time()
		}

		Log(fid, "order", string.format("%s издал(а) приказ: «%s».", by, title))
		Persist()

		if (priority == 3) then
			EachMember(fid, function(ply)
				ply:Notify("Срочный приказ: " .. title)
			end)
		end

		return Sync({orderPosted = true, toast = "Приказ опубликован."})
	end

	if (action == "orderPin" or action == "orderDel") then
		local order = db.orders[tostring(data.id or "")]

		if (!isCmd or !order or order.faction != fid) then
			return Err(client, "Недостаточно прав.")
		end

		if (action == "orderPin") then
			order.pinned = !order.pinned
		else
			db.orders[tostring(data.id)] = nil
			Log(fid, "order", string.format("%s отменил(а) приказ: «%s».", by, order.title))
		end

		Persist()

		return Sync()
	end

	-- ----- Личные сообщения -----
	if (action == "msgSend") then
		if ((client.ixTabletMsgNext or 0) > CurTime()) then
			return Err(client, "Не так быстро.")
		end

		local to = tostring(data.to or "")
		local target = db.roster[to]
		local text = string.Trim(string.sub(tostring(data.text or ""), 1, 500))

		if (!target or target.faction != fid or to == id) then
			return Err(client, "Получатель не найден.")
		end

		if (text == "") then
			return Err(client, "Сообщение пустое.")
		end

		client.ixTabletMsgNext = CurTime() + 3

		local inbox = db.messages[to]

		if (!inbox) then
			inbox = {}
			db.messages[to] = inbox
		end

		inbox[#inbox + 1] = {id = NextID(), from = id, fromName = by, text = text, time = os.time(), read = false}

		while (#inbox > 50) do
			table.remove(inbox, 1)
		end

		Persist()

		local targetChar = ix.char.loaded[tonumber(to)]
		local ply = targetChar and targetChar:GetPlayer()

		if (IsValid(ply)) then
			ply:Notify("Новое сообщение в планшете от " .. by .. ".")
		end

		return Sync({sent = true, toast = "Сообщение отправлено."})
	end

	if (action == "msgRead" or action == "msgDel") then
		local inbox = db.messages[id] or {}
		local mid = tostring(data.id or "")

		for i, msg in ipairs(inbox) do
			if (msg.id == mid) then
				if (action == "msgRead") then
					msg.read = true
				else
					table.remove(inbox, i)
				end

				break
			end
		end

		Persist()

		return Sync()
	end

	-- ----- Записки -----
	if (action == "noteSave") then
		local title = Clean(data.title, 48)
		local text = string.sub(tostring(data.text or ""), 1, 2000)

		if (title == "") then
			title = "Без названия"
		end

		local note = data.id and db.notes[tostring(data.id)]

		if (note) then
			if (!(note.owner == id or (isCmd and note.faction == fid))) then
				return Err(client, "Нет прав на редактирование.")
			end
		else
			local count = 0

			for _, n in pairs(db.notes) do
				if (n.owner == id) then count = count + 1 end
			end

			if (count >= 30) then
				return Err(client, "Лимит записок (30) исчерпан.")
			end

			note = {id = NextID(), owner = id, ownerName = by, faction = fid}
			db.notes[note.id] = note
		end

		note.title = title
		note.text = text
		note.shared = tobool(data.shared)
		note.time = os.time()
		Persist()

		return Sync({saved = note.id, toast = "Записка сохранена."})
	end

	if (action == "noteDelete") then
		local note = db.notes[tostring(data.id or "")]

		if (!note or !(note.owner == id or (isCmd and note.faction == fid))) then
			return Err(client, "Нет прав на удаление.")
		end

		db.notes[note.id] = nil
		Persist()

		return Sync({cleared = true, toast = "Записка удалена."})
	end

	-- ----- Метки на карте (deputy, commander) -----
	if (action == "markerAdd") then
		if (!isCmd) then
			return Err(client, "Недостаточно прав.")
		end

		local count = 0

		for _, m in pairs(db.markers) do
			if (m.faction == fid) then count = count + 1 end
		end

		if (count >= 50) then
			return Err(client, "Лимит меток (50).")
		end

		local x, y = tonumber(data.x), tonumber(data.y)
		if (!x or !y) then return end

		db.markers[NextID()] = {
			faction = fid,
			x = math.Clamp(x, -32768, 32768),
			y = math.Clamp(y, -32768, 32768),
			text = Clean(data.text, 40),
			kind = math.Clamp(math.floor(tonumber(data.kind) or 5), 1, #ix.tablet.markerKinds),
			by = by
		}

		Log(fid, "marker", by .. " поставил(а) метку на карте.")
		Persist()

		return Sync()
	end

	if (action == "markerDel") then
		local marker = db.markers[tostring(data.id or "")]

		if (!isCmd or !marker or marker.faction != fid) then
			return Err(client, "Недостаточно прав.")
		end

		db.markers[tostring(data.id)] = nil
		Persist()

		return Sync()
	end
end

net.Receive("ixTablet.Request", function(_, client)
	local action = net.ReadString()
	local data = net.ReadTable()

	if ((client.ixTabletNext or 0) > CurTime()) then return end
	client.ixTabletNext = CurTime() + 0.1

	if (type(data) != "table") then return end

	PLUGIN:HandleRequest(client, action, data)
end)

-- Нажатие клавиши открытия (M). Молча игнорируем, если планшета нет.
net.Receive("ixTablet.Bind", function(_, client)
	if ((client.ixTabletBindNext or 0) > CurTime()) then return end
	client.ixTabletBindNext = CurTime() + 1

	if (!client:Alive()) then return end
	if (!client:GetCharacter()) then return end

	ix.tablet.Open(client)
end)