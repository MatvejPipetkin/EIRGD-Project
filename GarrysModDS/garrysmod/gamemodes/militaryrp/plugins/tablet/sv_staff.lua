local PLUGIN = PLUGIN

-- ========== Ставка: инструменты лидеров фракции ==========
-- Лидер — боец со званием не ниже leaderFrom (ix.tablet.factions[<фракция>].leaderFrom, см. sh_plugin.lua).
-- Здесь реализовано:
--   * alertSet     — уровень боевой готовности фракции (баннер + индикатор на экране каждого бойца);
--   * beaconSet    — сигнал сбора: маячок на экране бойцов и на карте планшета;
--   * beaconClear  — снять сигнал сбора;
--   * suspend      — приостановить допуск бойца к планшету (потерян планшет, расследование);
--   * restore      — вернуть допуск;
--   * orderAck     — «принял к исполнению» (доступно любому бойцу, которому виден приказ).
-- Грифы секретности и публикация приказов с подтверждением находятся в действии "order" (sv_tablet.lua).

util.AddNetworkString("ixTablet.Alert")
util.AddNetworkString("ixTablet.Beacon")

local U = PLUGIN.util

-- ----- Рассылка состояния бойцам -----

-- Боевая готовность. target — игрок или nil (вся фракция онлайн). silent — без баннера и звука.
function PLUGIN:SendAlert(target, fid, silent)
	local alert = fid and self.db.alerts[fid]
	local level = alert and alert.level or 1

	local function Push(ply)
		net.Start("ixTablet.Alert")
			net.WriteUInt(level, 4)
			net.WriteString(alert and alert.by or "")
			net.WriteString(alert and alert.note or "")
			net.WriteBool(silent == true)
		net.Send(ply)
	end

	if (IsValid(target)) then
		Push(target)
	elseif (fid) then
		U.EachMember(fid, Push)
	end
end

-- Сигнал сбора. Если срок вышел или сигнала нет — клиенту уходит «выключено».
function PLUGIN:SendBeacon(target, fid)
	local beacon = fid and self.db.beacons[fid]
	local left = beacon and (beacon.expire - os.time()) or 0

	local function Push(ply)
		net.Start("ixTablet.Beacon")
			net.WriteBool(left > 0)

			if (left > 0) then
				net.WriteInt(math.Round(beacon.x), 32)
				net.WriteInt(math.Round(beacon.y), 32)
				net.WriteString(beacon.text or "")
				net.WriteString(beacon.by or "")
				net.WriteUInt(math.Clamp(left, 1, 65535), 16)
			end
		net.Send(ply)
	end

	if (IsValid(target)) then
		Push(target)
	elseif (fid) then
		U.EachMember(fid, Push)
	end
end

-- Состояние для только что загрузившегося игрока (fid = nil — персонаж не из состава: сбрасываем HUD).
function PLUGIN:PushStaffState(client, fid)
	self:SendAlert(client, fid, true)
	self:SendBeacon(client, fid)
end

-- ----- Запросы -----

local STAFF_ACTIONS = {
	alertSet = true, beaconSet = true, beaconClear = true, suspend = true, restore = true
}

function PLUGIN:HandleStaffRequest(client, action, data, ctx)
	local db = self.db
	local fid, id, me, cfg, by, Sync = ctx.fid, ctx.id, ctx.me, ctx.cfg, ctx.by, ctx.Sync
	local Err, Log, Persist, Clean = U.Err, U.Log, U.Persist, U.Clean

	-- ----- Приказ принят к исполнению (любой боец) -----
	if (action == "orderAck") then
		local order = db.orders[tostring(data.id or "")]

		if (!order or order.faction != fid or (order.minRank and order.minRank > me.rank)) then
			return Err(client, "Приказ не найден.")
		end

		if (!order.ack) then
			return Err(client, "Этот приказ не требует подтверждения.")
		end

		order.acks = order.acks or {}

		if (order.acks[id]) then
			return Sync()
		end

		order.acks[id] = os.time()
		Persist()

		return Sync({toast = "Приказ принят к исполнению."})
	end

	if (!STAFF_ACTIONS[action]) then return end

	-- Всё ниже — только лидеры.
	if (!ix.tablet.IsLeader(fid, me.rank)) then
		return Err(client, "Доступно только высшему командованию.")
	end

	-- ----- Боевая готовность -----
	if (action == "alertSet") then
		if ((client.ixTabletAlertNext or 0) > CurTime()) then
			return Err(client, "Не так быстро.")
		end

		local level = math.floor(tonumber(data.level) or 0)
		local info = ix.tablet.alertLevels[level]

		if (!info) then
			return Err(client, "Неизвестный уровень готовности.")
		end

		local note = Clean(data.note, 120)
		local cur = db.alerts[fid]

		if (cur and cur.level == level and (cur.note or "") == note) then
			return Err(client, "Этот уровень уже объявлен.")
		end

		if (!cur and level == 1 and note == "") then
			return Err(client, "Сейчас и так мирное время.")
		end

		client.ixTabletAlertNext = CurTime() + 3

		db.alerts[fid] = {level = level, by = by, time = os.time(), note = note}

		Log(fid, "alert", string.format("%s объявил(а): %s%s.", by, info.name, note != "" and (" — " .. note) or ""))
		Persist()

		self:SendAlert(nil, fid, false)

		U.EachMember(fid, function(ply)
			ply:Notify("Боевая готовность: " .. info.name .. (note != "" and (". " .. note) or ""))
		end)

		return Sync({toast = "Объявлено: " .. info.name})
	end

	-- ----- Сигнал сбора -----
	if (action == "beaconSet") then
		local x, y = tonumber(data.x), tonumber(data.y)

		if (!x or !y) then return end

		local dur = math.floor(tonumber(data.dur) or 0)

		if (!table.HasValue(ix.tablet.beaconDurations, dur)) then
			dur = ix.tablet.beaconDurations[1] or 5
		end

		local text = Clean(data.text, 40)

		db.beacons[fid] = {
			x = math.Clamp(x, -32768, 32768),
			y = math.Clamp(y, -32768, 32768),
			text = text, by = by, time = os.time(), expire = os.time() + dur * 60
		}

		Log(fid, "beacon", string.format("%s подал(а) сигнал сбора%s (%d мин.).", by, text != "" and (": «" .. text .. "»") or "", dur))
		Persist()

		self:SendBeacon(nil, fid)

		U.EachMember(fid, function(ply)
			ply:Notify("Сигнал сбора" .. (text != "" and (": " .. text) or "") .. ". Ориентир отмечен на экране и на карте планшета.")
		end)

		return Sync({toast = "Сигнал сбора отправлен."})
	end

	if (action == "beaconClear") then
		local beacon = db.beacons[fid]

		if (!beacon or beacon.expire <= os.time()) then
			db.beacons[fid] = nil

			return Err(client, "Активного сигнала нет.")
		end

		db.beacons[fid] = nil

		Log(fid, "beacon", by .. " снял(а) сигнал сбора.")
		Persist()

		self:SendBeacon(nil, fid)

		return Sync({toast = "Сигнал снят."})
	end

	-- ----- Приостановка допуска -----
	local tid = tostring(data.id or "")
	local entry = db.roster[tid]

	if (!entry or entry.faction != fid) then
		return Err(client, "Боец не найден.")
	end

	if (tid == id) then
		return Err(client, "Нельзя применить это к самому себе.")
	end

	local target = U.ActivePlayer(ix.char.loaded[tonumber(tid)])

	if (action == "suspend") then
		if ((entry.rank or 1) >= (me.rank or 1)) then
			return Err(client, "Нельзя приостановить допуск равному или старшему по званию.")
		end

		if (entry.suspended) then
			return Err(client, "Допуск уже приостановлен.")
		end

		entry.suspended = {by = by, time = os.time()}

		Log(fid, "suspend", string.format("%s приостановил(а) допуск к планшету: %s.", by, entry.name))
		Persist()

		-- Закрываем открытые планшеты этого владельца и забываем запомненный вход.
		for _, ply in ipairs(player.GetAll()) do
			if (ply.ixTabletOwner == tid) then
				U.Reset(ply)
				U.Send(ply, "kicked")
			end

			if (ply.ixTabletSession and ply.ixTabletSession.owner == tid) then
				ply.ixTabletSession = nil
			end
		end

		if (IsValid(target)) then
			target:Notify("Ваш допуск к планшету приостановлен командованием.")
		end

		return Sync({toast = "Допуск приостановлен: " .. entry.name})
	end

	-- restore
	if (!entry.suspended) then
		return Err(client, "Допуск не был приостановлен.")
	end

	entry.suspended = nil

	Log(fid, "suspend", string.format("%s вернул(а) допуск к планшету: %s.", by, entry.name))
	Persist()

	if (IsValid(target)) then
		target:Notify("Ваш допуск к планшету восстановлен.")
	end

	return Sync({toast = "Допуск возвращён: " .. entry.name})
end
