local PLUGIN = PLUGIN
local HACK = ix.hack

util.AddNetworkString("ixHack.S2C")
util.AddNetworkString("ixHack.C2S")

-- Активные эффекты: HACK.state[uniqueID фракции][ключ] = CurTime() окончания.
HACK.state = HACK.state or {}
-- Идущие сеансы взлома: HACK.sessions[игрок] = сеанс.
HACK.sessions = HACK.sessions or {}
-- Хакеры с активным перехватом камер: HACK.trackers[игрок] = {untilTime, victim, next}.
HACK.trackers = HACK.trackers or {}

local GRACE = 4 -- запас времени на сетевую задержку, секунды

-- =====================================================================================
--  Сеть и сообщения
-- =====================================================================================

local function Send(client, action, data)
	if (not IsValid(client)) then return end

	net.Start("ixHack.S2C")
		net.WriteString(action)
		net.WriteTable(data or {})
	net.Send(client)
end

HACK.Send = Send

function HACK.Tell(client, text, kind)
	Send(client, "msg", {text = text, kind = kind or "info"})
end

function HACK.TellFaction(fid, text, kind)
	for _, ply in ipairs(player.GetAll()) do
		if (HACK.GetFactionID(ply) == fid) then
			HACK.Tell(ply, text, kind)
		end
	end
end

-- =====================================================================================
--  Откат хакера (хранится в данных персонажа, переживает перезапуск сервера)
-- =====================================================================================

local function CooldownLeft(char)
	if (not char) then return 0 end

	return math.max(0, (char:GetData("hackNext", 0) or 0) - os.time())
end

HACK.CooldownLeft = CooldownLeft

-- =====================================================================================
--  Эффекты
-- =====================================================================================

function HACK.IsActive(fid, key)
	local effects = fid and HACK.state[fid]

	return effects ~= nil and (effects[key] or 0) > CurTime()
end

function HACK.IsPlayerAffected(client, key)
	return HACK.IsActive(HACK.GetFactionID(client), key)
end

local function BuildSyncData(client)
	local fid = HACK.GetFactionID(client)
	local effects = {}

	for key, untilTime in pairs(HACK.state[fid] or {}) do
		local left = untilTime - CurTime()

		if (left > 0) then
			effects[key] = left
		end
	end

	return {effects = effects, cooldown = CooldownLeft(client:GetCharacter())}
end

function HACK.SyncPlayer(client)
	if (IsValid(client) and client:GetCharacter()) then
		Send(client, "sync", BuildSyncData(client))
	end
end

function HACK.SyncFaction(fid)
	for _, ply in ipairs(player.GetAll()) do
		if (HACK.GetFactionID(ply) == fid) then
			HACK.SyncPlayer(ply)
		end
	end
end

function HACK.Activate(fid, key, duration)
	local effects = HACK.state[fid] or {}

	HACK.state[fid] = effects
	effects[key] = math.max(effects[key] or 0, CurTime() + duration)

	HACK.SyncFaction(fid)
end

function HACK.ClearEffects(fid)
	for id in pairs(HACK.state) do
		if (not fid or id == fid) then
			HACK.state[id] = {}
			HACK.SyncFaction(id)
		end
	end

	for client, tr in pairs(HACK.trackers) do
		if (not fid or tr.victim == fid) then
			HACK.trackers[client] = nil
			Send(client, "track", {list = {}})
		end
	end
end

local END_TEXT = {
	tablet = "СЕТЬ: связь с картографическим сервером восстановлена. Карта планшета снова доступна.",
	radio = "СЕТЬ: радиоретранслятор восстановлен. Рации снова работают.",
	power = "СЕТЬ: электропитание восстановлено."
}

-- -------------------------------------------------------------------------------------
--  Архив личных дел: данные берутся из планшета (если он установлен), иначе из игроков онлайн.
-- -------------------------------------------------------------------------------------

local function FindTablet()
	if (ix.plugin and ix.plugin.Get) then
		local p = ix.plugin.Get("tablet")

		if (p) then return p end
	end

	for _, p in pairs(ix.plugin and ix.plugin.list or {}) do
		if (type(p) == "table" and p.HandleRequest and p.BuildSync) then
			return p
		end
	end
end

local MAX_DOSSIER = 100

function HACK.BuildDossier(victim, tier)
	local faction = ix.faction.teams[victim]
	local out = {
		faction = faction and faction.name or victim,
		time = os.time(),
		tier = tier,
		total = 0,
		online = 0,
		ranks = {},
		list = {}
	}

	local tablet = FindTablet()
	local cfg = ix.tablet and ix.tablet.factions and ix.tablet.factions[victim]
	local rankNames = cfg and cfg.ranks or {}
	local rows = {}
	local seen = {}

	-- Кто сейчас в сети (по персонажам).
	local onlineByChar = {}

	for _, ply in ipairs(player.GetAll()) do
		local char = ply:GetCharacter()

		if (char and HACK.GetFactionID(ply) == victim) then
			onlineByChar[tostring(char:GetID())] = {ply = ply, char = char}
		end
	end

	if (tablet and tablet.db and tablet.db.roster) then
		for id, entry in pairs(tablet.db.roster) do
			if (entry.faction == victim) then
				local on = onlineByChar[tostring(id)]
				local class

				if (on) then
					local c = ix.class.list[on.char:GetClass()]

					class = c and c.name
				end

				rows[#rows + 1] = {
					name = on and on.char:GetName() or entry.name or "?",
					rank = rankNames[entry.rank] or tostring(entry.rank or "?"),
					rankIdx = entry.rank or 1,
					online = on ~= nil,
					class = class,
					since = entry.since,
					seen = entry.seen,
					rep = entry.reprimands and #entry.reprimands or 0,
					com = entry.commends and #entry.commends or 0
				}

				seen[tostring(id)] = true
			end
		end
	end

	-- Игроки онлайн, которых нет в базе планшета (или планшета нет совсем).
	for id, on in pairs(onlineByChar) do
		if (not seen[id]) then
			local c = ix.class.list[on.char:GetClass()]

			rows[#rows + 1] = {
				name = on.char:GetName(),
				rank = "—",
				rankIdx = 0,
				online = true,
				class = c and c.name
			}
		end
	end

	table.sort(rows, function(a, b)
		if (a.rankIdx ~= b.rankIdx) then return a.rankIdx > b.rankIdx end

		return tostring(a.name) < tostring(b.name)
	end)

	out.total = #rows

	local byRank = {}

	for _, row in ipairs(rows) do
		if (row.online) then out.online = out.online + 1 end

		byRank[row.rankIdx] = byRank[row.rankIdx] or {name = row.rank, count = 0, idx = row.rankIdx}
		byRank[row.rankIdx].count = byRank[row.rankIdx].count + 1
	end

	if (tier >= 2) then
		for _, v in pairs(byRank) do out.ranks[#out.ranks + 1] = v end

		table.sort(out.ranks, function(a, b) return a.idx > b.idx end)
	end

	if (tier >= 3) then
		for i, row in ipairs(rows) do
			if (i > MAX_DOSSIER) then
				out.truncated = true

				break
			end

			if (tier >= 4) then
				out.list[#out.list + 1] = row
			else
				out.list[#out.list + 1] = {name = row.name, rank = row.rank, rankIdx = row.rankIdx}
			end
		end
	end

	return out
end

-- -------------------------------------------------------------------------------------
--  Сами эффекты. ctx: client, char, node, item, victim, victimName, diff, duration.
--  Возвращают таблицу для экрана результата: {title, lines, dossier}.
-- -------------------------------------------------------------------------------------

local EFFECTS = {}

EFFECTS.tablet = function(ctx)
	HACK.Activate(ctx.victim, "tablet", ctx.duration)
	HACK.TellFaction(ctx.victim, "СЕТЬ: потеряна связь с картографическим сервером. Карта планшета недоступна.", "bad")

	return {
		title = "КАРТА ОТКЛЮЧЕНА",
		lines = {
			"Сеть планшетов «" .. ctx.victimName .. "» потеряла связь с картографическим сервером.",
			"Карта и положение бойцов недоступны: " .. HACK.FormatTime(ctx.duration) .. "."
		}
	}
end

EFFECTS.radio = function(ctx)
	HACK.Activate(ctx.victim, "radio", ctx.duration)
	HACK.TellFaction(ctx.victim, "СЕТЬ: радиоретранслятор выведен из строя. Эфир забит помехами.", "bad")

	return {
		title = "РАДИОСВЯЗЬ ПОДАВЛЕНА",
		lines = {
			"Рации «" .. ctx.victimName .. "» не могут передавать и принимать.",
			"Помехи продлятся: " .. HACK.FormatTime(ctx.duration) .. "."
		}
	}
end

EFFECTS.power = function(ctx)
	HACK.Activate(ctx.victim, "power", ctx.duration)
	HACK.TellFaction(ctx.victim, "СЕТЬ: авария на электрощитовой. Освещение и фонари отключены.", "bad")

	for _, ply in ipairs(player.GetAll()) do
		if (HACK.GetFactionID(ply) == ctx.victim and ply:FlashlightIsOn()) then
			ply:Flashlight(false)
		end
	end

	return {
		title = "ЭЛЕКТРОПИТАНИЕ ОТКЛЮЧЕНО",
		lines = {
			"У бойцов «" .. ctx.victimName .. "» не работают фонари.",
			"Отключение продлится: " .. HACK.FormatTime(ctx.duration) .. "."
		}
	}
end

EFFECTS.cameras = function(ctx)
	HACK.trackers[ctx.client] = {untilTime = CurTime() + ctx.duration, victim = ctx.victim, nextPush = 0}

	return {
		title = "КАМЕРЫ ПЕРЕХВАЧЕНЫ",
		lines = {
			"Видеопоток противника выведен на ваш терминал.",
			"Контакты «" .. ctx.victimName .. "» отмечаются на экране, даже сквозь стены: " .. HACK.FormatTime(ctx.duration) .. "."
		}
	}
end

EFFECTS.finance = function(ctx)
	local range = HACK.types.finance.rewards[ctx.diff] or {50, 100}
	local amount = math.random(range[1], range[2])

	ctx.char:GiveMoney(amount)

	return {
		title = "ВЕДОМОСТЬ ПЕРЕХВАЧЕНА",
		lines = {
			"Платёжная ведомость «" .. ctx.victimName .. "» перенаправлена на ваш счёт.",
			"Получено: " .. ix.currency.Get(amount) .. "."
		}
	}
end

EFFECTS.archive = function(ctx)
	local dossier = HACK.BuildDossier(ctx.victim, ctx.diff)

	if (ctx.item) then
		ctx.item:SetData("dossier", dossier)
	end

	return {
		title = "ДАННЫЕ ПОЛУЧЕНЫ",
		lines = {
			"Из архива «" .. ctx.victimName .. "» получено: " .. (HACK.archiveTiers[ctx.diff] or "данные") .. ".",
			ctx.diff >= 4 and "Досье сохранено в устройстве (функция «Открыть досье»)."
				or "Сведения сохранены в устройстве (функция «Открыть досье»). Для полного досье нужен узел КРАЙНЕЙ сложности."
		},
		dossier = dossier
	}
end

HACK.effects = EFFECTS

-- =====================================================================================
--  Сеанс взлома
-- =====================================================================================

local function NodeDistance(client, node)
	local eye = client:GetShootPos()

	return node:NearestPoint(eye):Distance(eye)
end

function HACK.FindDevice(client)
	local char = client:GetCharacter()
	local inv = char and char:GetInventory()

	if (not inv) then return end

	local items = inv:GetItemsByUniqueID("hacktool")

	return items and items[1]
end

function HACK.TraceNode(client)
	local tr = client:GetEyeTrace()

	if (IsValid(tr.Entity) and tr.Entity:GetClass() == "ix_hacknode") then
		return tr.Entity
	end
end

-- Узел, к которому обращается игрок: тот, на который он смотрит, иначе ближайший рядом.
function HACK.AimedNode(client)
	local node = HACK.TraceNode(client)

	if (IsValid(node) and NodeDistance(client, node) <= HACK.useDistance) then
		return node
	end

	local best, bestDist

	for _, ent in ipairs(ents.FindInSphere(client:GetPos(), HACK.useDistance + 60)) do
		if (ent:GetClass() == "ix_hacknode") then
			local d = NodeDistance(client, ent)

			if (d <= HACK.useDistance and (not bestDist or d < bestDist)) then
				best, bestDist = ent, d
			end
		end
	end

	return best
end

local function SendResult(client, data)
	Send(client, "result", data)
end

-- Завершение сеанса. outcome: "success" | "fail" | "abort".
local function Cleanup(session, nodeCooldown)
	HACK.sessions[session.client] = nil

	local node = session.node

	if (IsValid(node)) then
		node:SetBusy(false)

		if (nodeCooldown and nodeCooldown > 0) then
			node.nextHack = CurTime() + nodeCooldown
			node:SetCooling(true)
		end
	end
end

function HACK.Abort(client, reason)
	local session = HACK.sessions[client]

	if (not session) then return end

	Cleanup(session, 0)

	if (IsValid(client)) then
		SendResult(client, {
			success = false,
			title = "СОЕДИНЕНИЕ РАЗОРВАНО",
			lines = {reason or "Сеанс прерван."}
		})
	end
end

function HACK.AbortNode(node)
	for _, session in pairs(HACK.sessions) do
		if (session.node == node) then
			HACK.Abort(session.client, "Узел отключён.")
		end
	end
end

local function BeginStage(session, afterFail, reason)
	local step = session.plan[session.stage]
	local game = HACK.games[step.game]
	local public, secret = game.Generate(step.level)

	session.game = step.game
	session.secret = secret
	session.startedAt = CurTime()
	session.deadline = CurTime() + public.time + GRACE

	Send(session.client, afterFail and "stagefail" or "stage", {
		stage = session.stage,
		stages = #session.plan,
		lives = session.lives,
		game = step.game,
		gameName = game.name,
		level = step.level,
		time = public.time,
		puzzle = public,
		reason = reason
	})
end

local function Succeed(session)
	local client, node = session.client, session.node
	local typeId = IsValid(node) and node:GetNodeType() or ""
	local effect = EFFECTS[typeId]
	local victimFaction = ix.faction.teams[session.victim]

	local ctx = {
		client = client,
		char = session.char,
		node = node,
		item = session.item,
		victim = session.victim,
		victimName = victimFaction and victimFaction.name or session.victim,
		diff = session.diff,
		duration = HACK.Duration(typeId, session.diff)
	}

	local ok, result = true, nil

	if (effect) then
		ok, result = pcall(effect, ctx)
	else
		ok, result = false, "нет обработчика для типа «" .. typeId .. "»"
	end

	Cleanup(session, HACK.nodeCooldown)

	if (not ok) then
		ErrorNoHalt("[Hack] ошибка эффекта: " .. tostring(result) .. "\n")

		SendResult(client, {
			success = false,
			title = "СБОЙ ТЕРМИНАЛА",
			lines = {"Взлом удался, но эффект не применился. Сообщите администратору."}
		})

		return
	end

	local detect = HACK.types[typeId] and HACK.types[typeId].detect

	if (detect and math.random() < detect) then
		HACK.TellFaction(session.victim,
			"СЕТЬ: зафиксирован несанкционированный доступ к узлу «" .. node:GetNodeName() .. "».", "warn")
	end

	result.success = true
	SendResult(client, result)

	hook.Run("HackSucceeded", client, node, session.victim, typeId, session.diff)
end

local function Fail(session, reason)
	local client, node = session.client, session.node

	Cleanup(session, HACK.nodeFailCooldown)

	if (HACK.alertOnFail and IsValid(node)) then
		HACK.TellFaction(session.victim,
			"ТРЕВОГА: защита узла «" .. node:GetNodeName() .. "» отразила попытку взлома!", "bad")
	end

	SendResult(client, {
		success = false,
		title = "ДОСТУП ЗАБЛОКИРОВАН",
		lines = {
			reason == "time" and "Время вышло: система обнаружила вторжение." or "Система защиты обнаружила вторжение и закрыла канал.",
			"Узел поднял тревогу."
		}
	})

	hook.Run("HackFailed", client, node, session.victim)
end

local function StageFail(session, reason)
	session.lives = session.lives - 1

	if (session.lives <= 0) then
		return Fail(session, reason)
	end

	BeginStage(session, true, reason)
end

local function StageWin(session)
	session.stage = session.stage + 1

	if (session.stage > #session.plan) then
		return Succeed(session)
	end

	BeginStage(session, false)
end

function HACK.TryStart(client, node, item)
	if (not IsValid(client) or not IsValid(node) or node:GetClass() ~= "ix_hacknode") then return end

	local char = client:GetCharacter()

	if (not char or not client:Alive()) then return end

	if (HACK.sessions[client]) then
		return HACK.Tell(client, "Сеанс взлома уже идёт.", "bad")
	end

	if (not HACK.CanUse(client)) then
		return HACK.Tell(client, "Вы не обучены работе с этим устройством.", "bad")
	end

	local fid = HACK.GetFactionID(client)
	local fcfg = HACK.factions[fid]

	if (not fcfg) then
		return HACK.Tell(client, "Ваша фракция не ведёт сетевых операций.", "bad")
	end

	item = item or HACK.FindDevice(client)

	if (not item) then
		return HACK.Tell(client, "Узел защищён паролем. Нужно устройство взлома.", "bad")
	end

	local left = CooldownLeft(char)

	if (left > 0) then
		return HACK.Tell(client, "Устройство перезаряжается. Следующий взлом через " .. HACK.FormatTime(left) .. ".", "warn")
	end

	if (NodeDistance(client, node) > HACK.useDistance) then
		return HACK.Tell(client, "Подойдите ближе к узлу.", "warn")
	end

	if (node:GetBusy()) then
		return HACK.Tell(client, "К узлу уже подключён другой терминал.", "warn")
	end

	if (node:GetCooling()) then
		local rest = math.max(0, (node.nextHack or 0) - CurTime())

		return HACK.Tell(client, "Узел восстанавливается после атаки. Подождите " .. HACK.FormatTime(rest) .. ".", "warn")
	end

	local owner = node:GetOwnerFaction()
	local victim

	if (owner ~= "") then
		if (owner == fid) then
			return HACK.Tell(client, "Это узел вашей фракции.", "warn")
		end

		victim = owner
	else
		victim = fcfg.enemy
	end

	if (not victim or not ix.faction.teams[victim]) then
		return HACK.Tell(client, "Цель не определена: у вашей фракции нет противника.", "bad")
	end

	local diff = math.Clamp(node:GetDifficulty(), 1, #HACK.difficulties)
	local plan = HACK.PlanStages(diff)
	local typeInfo = HACK.types[node:GetNodeType()]
	local owned = ix.faction.teams[victim]

	local session = {
		client = client,
		char = char,
		node = node,
		item = item,
		diff = diff,
		victim = victim,
		plan = plan,
		stage = 1,
		lives = HACK.lives[diff] or 3
	}

	HACK.sessions[client] = session
	node:SetBusy(true)

	-- Откат считается с момента старта: прервать взлом и начать заново нельзя.
	char:SetData("hackNext", os.time() + HACK.cooldown)
	HACK.SyncPlayer(client)

	Send(client, "open", {
		node = {
			name = node:GetNodeName(),
			type = node:GetNodeType(),
			typeName = typeInfo and typeInfo.name or "?",
			desc = typeInfo and typeInfo.desc or "",
			diff = diff,
			owner = owned and owned.name or victim
		},
		stages = #plan,
		lives = session.lives
	})

	BeginStage(session, false)
end

function HACK.OnNodeUse(client, node)
	if (not client:GetCharacter()) then return end

	if (not HACK.FindDevice(client)) then
		return HACK.Tell(client, "Узел защищён паролем. Нужно устройство взлома.", "warn")
	end

	HACK.TryStart(client, node)
end

-- -------------------------------------------------------------------------------------
--  Сканирование сети
-- -------------------------------------------------------------------------------------

function HACK.Scan(client)
	if (not HACK.CanUse(client)) then return end

	if ((client.ixHackScanNext or 0) > CurTime()) then
		return HACK.Tell(client, "Сканер перегрет. Подождите несколько секунд.", "warn")
	end

	client.ixHackScanNext = CurTime() + HACK.scanCooldown

	local pos = client:GetPos()
	local list = {}

	for _, node in ipairs(ents.FindInSphere(pos, HACK.scanRadius)) do
		if (node:GetClass() == "ix_hacknode") then
			local owner = ix.faction.teams[node:GetOwnerFaction()]

			list[#list + 1] = {
				pos = node:GetPos(),
				name = node:GetNodeName(),
				type = node:GetNodeType(),
				diff = node:GetDifficulty(),
				owner = owner and owner.name or nil,
				cooling = node:GetCooling()
			}
		end
	end

	table.sort(list, function(a, b) return a.pos:DistToSqr(pos) < b.pos:DistToSqr(pos) end)

	Send(client, "scan", {list = list})
end

-- =====================================================================================
--  Запросы клиента
-- =====================================================================================

function HACK.HandleRequest(client, action, data)
	if (action == "abort") then
		return HACK.Abort(client, "Вы отключились от узла.")
	end

	local session = HACK.sessions[client]

	if (not session) then return end

	if (action ~= "submit" and action ~= "guess") then return end

	if (CurTime() > session.deadline) then
		return StageFail(session, "time")
	end

	local game = HACK.games[session.game]
	local status, reply = game.Handle(session.secret, action, data, CurTime() - session.startedAt)

	if (reply) then
		Send(client, "feedback", reply)
	end

	if (status == "win") then
		StageWin(session)
	elseif (status == "fail") then
		StageFail(session, "wrong")
	end
end

net.Receive("ixHack.C2S", function(_, client)
	if ((client.ixHackNext or 0) > CurTime()) then return end

	client.ixHackNext = CurTime() + 0.05

	local action = net.ReadString()
	local data = net.ReadTable()

	if (type(data) ~= "table") then return end

	HACK.HandleRequest(client, action, data)
end)

-- =====================================================================================
--  Таймер: контроль сеансов, окончание эффектов, перехват камер
-- =====================================================================================

local function TrackPush(client, tr)
	local list = {}

	for _, ply in ipairs(player.GetAll()) do
		if (ply ~= client and ply:Alive() and ply:GetMoveType() ~= MOVETYPE_NOCLIP
		and HACK.GetFactionID(ply) == tr.victim) then
			list[#list + 1] = {pos = ply:GetPos() + Vector(0, 0, 40)}
		end
	end

	Send(client, "track", {list = list, left = math.max(0, tr.untilTime - CurTime())})
end

timer.Create("ixHackTick", 0.5, 0, function()
	local now = CurTime()

	-- Сеансы.
	for client, session in pairs(HACK.sessions) do
		if (not IsValid(client) or not client:Alive() or client:GetCharacter() ~= session.char) then
			HACK.Abort(client, "Сеанс прерван.")
		elseif (not IsValid(session.node)) then
			HACK.Abort(client, "Узел недоступен.")
		elseif (NodeDistance(client, session.node) > HACK.abortDistance) then
			HACK.Abort(client, "Вы слишком далеко от узла: соединение потеряно.")
		elseif (now > session.deadline) then
			StageFail(session, "time")
		end
	end

	-- Эффекты.
	for fid, effects in pairs(HACK.state) do
		local changed = false

		for key, untilTime in pairs(effects) do
			if (untilTime <= now) then
				effects[key] = nil
				changed = true

				if (END_TEXT[key]) then
					HACK.TellFaction(fid, END_TEXT[key], "good")
				end
			end
		end

		if (changed) then
			HACK.SyncFaction(fid)
		end
	end

	-- Перехват камер.
	for client, tr in pairs(HACK.trackers) do
		if (not IsValid(client) or not client:GetCharacter()) then
			HACK.trackers[client] = nil
		elseif (tr.untilTime <= now) then
			HACK.trackers[client] = nil
			Send(client, "track", {list = {}})
			HACK.Tell(client, "Видеопоток прерван: канал перехвата закрыт.", "warn")
		elseif (now >= tr.nextPush) then
			tr.nextPush = now + 2
			TrackPush(client, tr)
		end
	end

	-- Узлы после восстановления.
	for _, node in ipairs(ents.FindByClass("ix_hacknode")) do
		if (node:GetCooling() and now >= (node.nextHack or 0)) then
			node:SetCooling(false)
		end
	end
end)

-- =====================================================================================
--  Хуки плагина
-- =====================================================================================

function PLUGIN:PlayerDisconnected(client)
	HACK.Abort(client, "Сеанс прерван.")
	HACK.trackers[client] = nil
end

function PLUGIN:PlayerDeath(client)
	HACK.Abort(client, "Сеанс прерван.")
end

function PLUGIN:PlayerLoadedCharacter(client)
	HACK.Abort(client, "Сеанс прерван.")
	HACK.trackers[client] = nil

	timer.Simple(1, function()
		HACK.SyncPlayer(client)
	end)
end

-- Электрощитовая: фонари противника не включаются.
function PLUGIN:PlayerSwitchFlashlight(client, enabled)
	if (enabled and HACK.IsPlayerAffected(client, "power")) then
		return false
	end
end

-- =====================================================================================
--  Интеграция с планшетом и рацией (без правки их файлов)
-- =====================================================================================

local function PatchTablet()
	local tablet = FindTablet()

	if (not tablet) then
		return MsgC(Color(255, 200, 80), "[Hack] плагин планшета не найден: отключение карты не будет работать.\n")
	end

	if (tablet.ixHackPatched) then return end

	tablet.ixHackPatched = true

	local handle, build = tablet.HandleRequest, tablet.BuildSync

	-- Запросы карты (позиции, метки) при блэкауте не выполняются.
	tablet.HandleRequest = function(self, client, action, data)
		if (action == "positions" or action == "markerAdd" or action == "markerDel") then
			local _, fid = self:GetContext(client)

			if (fid and HACK.IsActive(fid, "tablet")) then
				if (action == "positions") then
					net.Start("ixTablet.Response")
						net.WriteString("positions")
						net.WriteTable({list = {}})
					net.Send(client)
				else
					net.Start("ixTablet.Response")
						net.WriteString("error")
						net.WriteTable({msg = "Нет сигнала: карта недоступна."})
					net.Send(client)
				end

				return
			end
		end

		return handle(self, client, action, data)
	end

	-- Метки не уходят на клиент, пока карта отключена.
	tablet.BuildSync = function(self, client, fid, id, item)
		local out = build(self, client, fid, id, item)

		if (HACK.IsActive(fid, "tablet")) then
			out.markers = {}
		end

		return out
	end
end

-- Рация: голос идёт через хук "RadioMoment", текст — через ix.chat классы радио.
local RADIO_RANGE = {radio = 1, radioyell = 2, radiowhisper = 0.25, radioooc = 0.25}

local function RadioJammed(a, b)
	return HACK.IsPlayerAffected(a, "radio") or HACK.IsPlayerAffected(b, "radio")
end

local function PatchRadio()
	if (HACK.radioPatched) then return end

	local patched = false
	local voice = hook.GetTable()["PlayerCanHearPlayersVoice"]
	local original = voice and voice["RadioMoment"]

	if (original) then
		hook.Add("PlayerCanHearPlayersVoice", "RadioMoment", function(listener, talker)
			if (RadioJammed(listener, talker)) then return end

			return original(listener, talker)
		end)

		patched = true
	end

	for id, mult in pairs(RADIO_RANGE) do
		local class = ix.chat.classes[id]

		if (class and not class.ixHackPatched) then
			class.ixHackPatched = true

			local canSay, canHear = class.CanSay, class.CanHear

			class.CanSay = function(self, speaker, text, data)
				if (HACK.IsPlayerAffected(speaker, "radio")) then
					speaker:Notify("Эфир забит помехами. Связи нет.")

					return false
				end

				if (canSay) then return canSay(self, speaker, text, data) end
			end

			class.CanHear = function(self, speaker, listener, data)
				if (RadioJammed(speaker, listener)) then
					-- Помехи глушат только саму радиосвязь: вживую рядом стоящий по-прежнему слышит.
					local range = ix.config.Get("chatRange", 280) * mult

					return speaker:GetPos():DistToSqr(listener:GetPos()) <= range * range
				end

				if (canHear) then return canHear(self, speaker, listener, data) end
			end

			patched = true
		end
	end

	if (patched) then
		HACK.radioPatched = true
	else
		MsgC(Color(255, 200, 80), "[Hack] плагин рации не найден: глушение связи не будет работать.\n")
	end
end

local function PatchAll()
	PatchTablet()
	PatchRadio()
end

function PLUGIN:InitializedPlugins()
	PatchAll()
end

-- Страховка: если хук InitializedPlugins отработал раньше нашей регистрации.
timer.Simple(5, PatchAll)

-- =====================================================================================
--  Узлы на карте: создание и сохранение
-- =====================================================================================

HACK.nodeCounter = HACK.nodeCounter or 0

function HACK.NextNodeName()
	HACK.nodeCounter = HACK.nodeCounter + 1

	return string.format("УЗЕЛ-%02d", HACK.nodeCounter)
end

function HACK.CreateNode(d)
	local node = ents.Create("ix_hacknode")

	if (not IsValid(node)) then return end

	node:SetPos(d.pos)
	node:SetAngles(d.ang or Angle(0, 0, 0))
	node:Spawn()
	node:Setup(d)

	return node
end

function HACK.CreateNodeAtTrace(client, typeId, diff, owner)
	local info = HACK.types[typeId]
	local tr = client:GetEyeTrace()

	diff = math.Clamp(math.floor(tonumber(diff) or info.defaultDiff), 1, #HACK.difficulties)

	local node = HACK.CreateNode({
		type = typeId,
		diff = diff,
		faction = owner or "",
		name = HACK.NextNodeName(),
		model = info.models[1],
		pos = tr.HitPos,
		ang = Angle(0, client:EyeAngles().y + 180, 0)
	})

	if (IsValid(node)) then
		-- Ставим на землю: поднимаем на нижнюю точку модели.
		node:SetPos(tr.HitPos + Vector(0, 0, -node:OBBMins().z))

		PLUGIN:SaveData()
	end

	return node
end

-- Позиции храним обычными числами: так они гарантированно переживают JSON.
local function PackVec(v) return {v.x, v.y, v.z} end
local function PackAng(a) return {a.p, a.y, a.r} end

local function UnpackVec(t)
	if (isvector(t)) then return t end

	if (type(t) == "table" and tonumber(t[1]) and tonumber(t[2]) and tonumber(t[3])) then
		return Vector(t[1], t[2], t[3])
	end
end

local function UnpackAng(t)
	if (isangle(t)) then return t end

	if (type(t) == "table" and tonumber(t[1]) and tonumber(t[2]) and tonumber(t[3])) then
		return Angle(t[1], t[2], t[3])
	end

	return Angle(0, 0, 0)
end

function PLUGIN:SaveData()
	local data = {}

	for _, node in ipairs(ents.FindByClass("ix_hacknode")) do
		data[#data + 1] = {
			type = node:GetNodeType(),
			diff = node:GetDifficulty(),
			faction = node:GetOwnerFaction(),
			name = node:GetNodeName(),
			model = node:GetModel(),
			pos = PackVec(node:GetPos()),
			ang = PackAng(node:GetAngles())
		}
	end

	self:SetData(data)
end

function PLUGIN:LoadData()
	for _, d in ipairs(self:GetData() or {}) do
		local pos = UnpackVec(d.pos)

		if (pos and HACK.types[d.type]) then
			d.pos = pos
			d.ang = UnpackAng(d.ang)

			HACK.CreateNode(d)

			local num = tonumber(string.match(d.name or "", "^УЗЕЛ%-(%d+)$"))

			if (num and num > HACK.nodeCounter) then
				HACK.nodeCounter = num
			end
		end
	end
end
