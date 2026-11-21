local PLUGIN = PLUGIN
local CFG = ix.capture.config

util.AddNetworkString("ixCapture.Request")
util.AddNetworkString("ixCapture.Sync")

PLUGIN.points = PLUGIN.points or {}
PLUGIN.nextID = PLUGIN.nextID or 1

-- ===================== Вспомогательное =====================

local function CleanName(text)
	text = string.sub(string.Trim(tostring(text or "")), 1, 200)
	text = string.gsub(text, "%c", "")

	local limit = CFG.maxNameLength

	if ((utf8.len(text) or 0) > limit) then
		text = string.sub(text, 1, utf8.offset(text, limit + 1) - 1)
	end

	return text
end

local function FactionName(fid)
	local faction = ix.faction.teams[fid]

	return faction and faction.name or tostring(fid)
end

-- Сообщение всем онлайн-бойцам фракции.
local function NotifyFaction(fid, text)
	for _, ply in ipairs(player.GetAll()) do
		local char = ply:GetCharacter()
		local faction = char and ix.faction.indices[char:GetFaction()]

		if (faction and faction.uniqueID == fid) then
			ply:Notify(text)
		end
	end
end

local function NewPoint(src)
	local owner = src.owner

	-- Фракцию могли удалить из схемы: тогда точка снова нейтральная.
	if (owner and not ix.faction.teams[owner]) then
		owner = nil
	end

	return {
		id = tonumber(src.id) or 0,
		name = CleanName(src.name) ~= "" and CleanName(src.name) or "Точка",
		x = math.Clamp(tonumber(src.x) or 0, -32768, 32768),
		y = math.Clamp(tonumber(src.y) or 0, -32768, 32768),
		z = math.Clamp(tonumber(src.z) or 0, -32768, 32768),
		radius = math.Clamp(tonumber(src.radius) or CFG.defaultRadius, 32, 4096),
		height = math.Clamp(tonumber(src.height) or CFG.defaultHeight, 16, 4096),
		owner = owner,
		since = owner and tonumber(src.since) or nil,

		-- Текущее состояние захвата (не сохраняется).
		capturer = nil,
		progress = 0,
		contested = false,
		alertAt = 0
	}
end

-- ===================== Хранилище =====================

function PLUGIN:SaveData()
	local out = {nextID = self.nextID, points = {}}

	for _, p in ipairs(self.points) do
		out.points[#out.points + 1] = {
			id = p.id, name = p.name,
			x = p.x, y = p.y, z = p.z,
			radius = p.radius, height = p.height,
			owner = p.owner, since = p.since
		}
	end

	self:SetData(out)
end

function PLUGIN:LoadData()
	local data = self:GetData({}) or {}

	self.points = {}
	self.nextID = tonumber(data.nextID) or 1

	for _, saved in ipairs(data.points or {}) do
		local point = NewPoint(saved)

		if (point.id > 0) then
			self.points[#self.points + 1] = point
			self.nextID = math.max(self.nextID, point.id + 1)
		end
	end
end

-- ===================== Управление точками =====================

function PLUGIN:GetPoint(id)
	for _, p in ipairs(self.points) do
		if (p.id == id) then return p end
	end
end

function PLUGIN:AddPoint(pos, name)
	name = CleanName(name)

	if (name == "") then
		return nil, "Укажите название точки."
	end

	if (#self.points >= CFG.maxPoints) then
		return nil, "Достигнут лимит точек (" .. CFG.maxPoints .. ")."
	end

	local point = NewPoint({
		id = self.nextID, name = name,
		x = pos.x, y = pos.y, z = pos.z
	})

	self.nextID = self.nextID + 1
	self.points[#self.points + 1] = point
	self:SaveData()

	return point
end

function PLUGIN:RemovePoint(point)
	table.RemoveByValue(self.points, point)
	self:SaveData()
end

function PLUGIN:MovePoint(point, pos)
	point.x = math.Clamp(pos.x, -32768, 32768)
	point.y = math.Clamp(pos.y, -32768, 32768)
	point.z = math.Clamp(pos.z, -32768, 32768)
	point.capturer, point.progress = nil, 0
	self:SaveData()
end

function PLUGIN:ResizePoint(point, radius, height)
	point.radius = math.Clamp(math.floor(radius), 32, 4096)

	if (height) then
		point.height = math.Clamp(math.floor(height), 16, 4096)
	end

	self:SaveData()
end

-- Назначение владельца админом (fid = nil - сделать нейтральной). Хук захвата не вызывается.
function PLUGIN:SetOwner(point, fid)
	point.owner = fid
	point.since = fid and os.time() or nil
	point.capturer, point.progress = nil, 0
	self:SaveData()
end

-- ===================== Логика захвата =====================

-- Один шаг для одной точки.
-- counts: {[uniqueID фракции] = число бойцов в зоне}, dt: секунд с прошлого шага.
-- Возвращает таблицу события {type = "captured", faction = ..., previous = ...} или nil.
function PLUGIN:Advance(point, counts, dt)
	local present, total = nil, 0

	for fid, n in pairs(counts) do
		if (n > 0) then
			present = fid
			total = total + 1
		end
	end

	point.contested = total > 1

	-- Спор: в зоне несколько фракций, прогресс замирает.
	if (total > 1) then return end

	-- Зона пуста: чужой прогресс постепенно сходит на нет.
	if (total == 0) then
		if (point.capturer) then
			point.progress = point.progress - dt / CFG.restoreTime

			if (point.progress <= 0) then
				point.progress, point.capturer = 0, nil
			end
		end

		return
	end

	local n = counts[present]
	local speed = math.min(1 + (n - 1) * CFG.extraPlayerBonus, CFG.maxSpeed)
	local step = dt / CFG.captureTime * speed

	-- Владелец в зоне: сбивает прогресс захватчика.
	if (present == point.owner) then
		if (point.capturer) then
			point.progress = point.progress - step

			if (point.progress <= 0) then
				point.progress, point.capturer = 0, nil
			end
		end

		return
	end

	-- В зоне чужая фракция, а прогресс набирает другая: сначала сбиваем его.
	if (point.capturer and point.capturer ~= present) then
		point.progress = point.progress - step

		if (point.progress <= 0) then
			point.progress = 0
			point.capturer = present
		end

		return
	end

	point.capturer = present
	point.progress = point.progress + step

	if (point.progress >= 1) then
		local previous = point.owner

		point.owner = present
		point.since = os.time()
		point.capturer, point.progress = nil, 0

		return {type = "captured", faction = present, previous = previous}
	end
end

-- Кто сейчас может захватывать: {ply = игрок, fid = uniqueID, pos = Vector}.
local function CollectParticipants()
	local allowed = ix.capture.GetFactions()
	local list = {}

	for _, ply in ipairs(player.GetAll()) do
		local char = ply:GetCharacter()

		if (char and ply:Alive() and ply:GetMoveType() ~= MOVETYPE_NOCLIP
		and (CFG.allowVehicles or not ply:InVehicle())) then
			local faction = ix.faction.indices[char:GetFaction()]

			if (faction and allowed[faction.uniqueID]) then
				list[#list + 1] = {ply = ply, fid = faction.uniqueID, pos = ply:GetPos()}
			end
		end
	end

	return list
end

local function CountPresence(point, participants)
	local counts = {}
	local r2 = point.radius * point.radius

	for _, part in ipairs(participants) do
		local dx, dy = part.pos.x - point.x, part.pos.y - point.y

		if (dx * dx + dy * dy <= r2 and math.abs(part.pos.z - point.z) <= point.height) then
			counts[part.fid] = (counts[part.fid] or 0) + 1
		end
	end

	return counts
end

function PLUGIN:OnCaptured(point, fid, previous)
	NotifyFaction(fid, string.format("Точка «%s» захвачена вашей фракцией.", point.name))

	if (previous) then
		NotifyFaction(previous, string.format("Точка «%s» потеряна: её захватила фракция «%s».", point.name, FactionName(fid)))
	end

	-- Хук для наград, логов и т.д.: CapturePointCaptured(point, newFactionID, oldFactionID)
	hook.Run("CapturePointCaptured", point, fid, previous)
end

-- ВАЖНО: метод нельзя называть Tick - в Helix методы плагина становятся хуками,
-- а GM:Tick вызывается ~66 раз в секунду, из-за чего захват шёл в десятки раз быстрее.
function PLUGIN:CaptureTick()
	if (#self.points == 0) then return end

	local participants = CollectParticipants()
	local now = CurTime()
	local changed = false

	for _, point in ipairs(self.points) do
		local event = self:Advance(point, CountPresence(point, participants), CFG.tick)

		if (event) then
			changed = true
			self:OnCaptured(point, event.faction, event.previous)
		end

		-- Предупреждение владельцам: точку атакуют.
		if (point.owner and point.capturer and point.capturer ~= point.owner and now >= point.alertAt) then
			point.alertAt = now + CFG.alertCooldown

			NotifyFaction(point.owner, string.format("Точка «%s» атакована! Противник: «%s».", point.name, FactionName(point.capturer)))
		end
	end

	if (changed) then
		self:SaveData()
	end
end

timer.Create("ixCapturePointsTick", CFG.tick, 0, function()
	PLUGIN:CaptureTick()

	-- Интервал можно менять на лету в конфиге сервера.
	timer.Adjust("ixCapturePointsTick", CFG.tick)
end)

-- Для других плагинов: список точек (только чтение).
function ix.capture.GetPoints()
	return PLUGIN.points
end

-- ===================== Передача данных на планшет =====================

-- Видеть точки могут: бойцы с открытым и авторизованным планшетом, а также админы (для настройки зон).
function PLUGIN:CanView(client)
	if (not client:GetCharacter()) then return false end

	if (client.ixTabletOpen and client.ixTabletAuth and client.ixTabletAuth == client.ixTabletOwner) then
		return true
	end

	return client:IsAdmin()
end

function PLUGIN:SendPoints(client)
	net.Start("ixCapture.Sync")
		net.WriteUInt(#self.points, 8)

		for _, p in ipairs(self.points) do
			net.WriteUInt(p.id, 32)
			net.WriteString(p.name)
			net.WriteInt(math.Round(p.x), 20)
			net.WriteInt(math.Round(p.y), 20)
			net.WriteInt(math.Round(p.z), 20)
			net.WriteUInt(math.Round(p.radius), 13)
			net.WriteUInt(math.Round(p.height), 13)
			net.WriteString(p.owner or "")
			net.WriteUInt(p.since or 0, 32)
			net.WriteString(p.capturer or "")
			net.WriteUInt(math.Clamp(math.Round(p.progress * 100), 0, 100), 7)
			net.WriteBool(p.contested)
		end
	net.Send(client)
end

net.Receive("ixCapture.Request", function(_, client)
	if ((client.ixCapNext or 0) > CurTime()) then return end
	client.ixCapNext = CurTime() + 0.5

	if (not PLUGIN:CanView(client)) then return end

	PLUGIN:SendPoints(client)
end)
