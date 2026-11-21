--[[
	SAM Leadership
	Команды для руководства проекта (только superadmin) в отдельной категории "Руководство".

	Установка:
	  garrysmod/addons/sam_fun_extra/lua/sam/modules/sh_leadership.lua
	(рядом с sh_fun_extra.lua). Перезапусти сервер или смени карту.

	ВАЖНО: фейковые группа, имя и пинг - ТОЛЬКО ВИЗУАЛЬНЫЕ. Реальные права и
	реальная группа игрока не меняются. Всё хранится в NW-переменных игрока, поэтому
	исчезает само, когда игрок выходит с сервера (или при смене карты).
	Отображение фейков делает плагин табов (tabranks.lua), который читает эти же
	NW-переменные.

	Команды:
	  fakegroup / unfakegroup   - фейковая группа в табе и OOC-чате
	  fakename  / unfakename    - фейковое имя в табе, OOC и IC-чате
	  fakeping  / unfakeping    - фейковый пинг в табе
	  incognito / unincognito   - быстро показаться обычным игроком (группа user)
	  unfake                    - снять все фейки сразу
	  realinfo                  - показать НАСТОЯЩИЕ данные игрока (только вам)
	  bigmsg                    - большое объявление по центру экрана у всех
	  playall                   - проиграть звук всем игрокам
	  healall                   - вылечить всех игроков
	  fov / unfov               - изменить поле зрения игрока
	  not                       - скрыть/показать ВСЕ ваши админ-действия от остальных
	                              игроков (переключатель, !not ещё раз - выключить)
	  playsong / stopsong       - музыка по ссылке или из контента в радиусе вокруг вас
	                              (!playsong 800 https://site.com/song.mp3)
	                              Игроки могут регулировать громкость: samlead_song_volume 0..1
]]

local command = sam.command
command.set_category("Руководство")

-- Эти же имена используются в плагине табов!
local NW_GROUP = "SAMLead.FakeGroup"
local NW_NAME  = "SAMLead.FakeName"
local NW_PING  = "SAMLead.FakePing"

if SERVER then
	util.AddNetworkString("SAMLead.BigMsg")
	util.AddNetworkString("SAMLead.Sound")
	util.AddNetworkString("SAMLead.Song")
	util.AddNetworkString("SAMLead.SongStop")
end

-- ============================================================
-- Вспомогательные функции
-- ============================================================

local function Announce(msg, args)
	if sam.is_command_silent then return end
	sam.player.send_message(nil, msg, args)
end

-- Личное сообщение только тому, кто выполнил команду
local function Notify(ply, msg)
	if not IsValid(ply) then
		print("[SAM Leadership] " .. msg)
	elseif ply.sam_send_message then
		ply:sam_send_message(msg)
	else
		ply:ChatPrint(msg)
	end
end

local function Names(targets)
	local list = {}
	for i = 1, #targets do
		list[i] = targets[i]:Nick()
	end
	return table.concat(list, ", ")
end

local function IsValidSoundPath(path)
	return path ~= ""
		and string.match(path, "^[%w_%-%./]+$") ~= nil
		and not string.find(path, "..", 1, true)
		and (string.EndsWith(path, ".wav") or string.EndsWith(path, ".mp3") or string.EndsWith(path, ".ogg"))
end

-- ============================================================
-- ФЕЙКОВАЯ ГРУППА
-- ============================================================

command.new("fakegroup")
	:SetPermission("fakegroup", "superadmin")
	:AddArg("player")
	:AddArg("text", {hint = "название группы, например: user"})
	:Help("Показывает игроку фейковую группу в табе и чате (только визуально, права не меняются)")
	:OnExecute(function(ply, targets, group)
		group = string.sub(string.Trim(group or ""), 1, 32)
		if group == "" then
			Notify(ply, "Укажите название группы.")
			return
		end

		for i = 1, #targets do
			targets[i]:SetNWString(NW_GROUP, group)
		end

		Notify(ply, "Фейковая группа «" .. group .. "» выдана: " .. Names(targets) .. " (до выхода с сервера, права не изменены).")
	end)
:End()

command.new("unfakegroup")
	:SetPermission("unfakegroup", "superadmin")
	:AddArg("player", {optional = true})
	:Help("Снимает фейковую группу")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			targets[i]:SetNWString(NW_GROUP, "")
		end

		Notify(ply, "Фейковая группа снята: " .. Names(targets))
	end)
:End()

-- ============================================================
-- ФЕЙКОВОЕ ИМЯ
-- ============================================================

command.new("fakename")
	:SetPermission("fakename", "superadmin")
	:AddArg("player")
	:AddArg("text", {hint = "новое имя"})
	:Help("Показывает игрока под другим именем в табе и чате (только визуально)")
	:OnExecute(function(ply, targets, name)
		name = string.sub(string.Trim(name or ""), 1, 32)
		if name == "" then
			Notify(ply, "Укажите имя.")
			return
		end

		for i = 1, #targets do
			targets[i]:SetNWString(NW_NAME, name)
		end

		Notify(ply, "Фейковое имя «" .. name .. "» выдано: " .. Names(targets) .. " (до выхода с сервера).")
	end)
:End()

command.new("unfakename")
	:SetPermission("unfakename", "superadmin")
	:AddArg("player", {optional = true})
	:Help("Снимает фейковое имя")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			targets[i]:SetNWString(NW_NAME, "")
		end

		Notify(ply, "Фейковое имя снято: " .. Names(targets))
	end)
:End()

-- ============================================================
-- ФЕЙКОВЫЙ ПИНГ
-- ============================================================

command.new("fakeping")
	:SetPermission("fakeping", "superadmin")
	:AddArg("player")
	:AddArg("number", {hint = "пинг (мс)", optional = true, default = 999, min = 0, max = 9999, round = true})
	:Help("Показывает в табе фейковый пинг игрока")
	:OnExecute(function(ply, targets, ping)
		for i = 1, #targets do
			targets[i]:SetNWInt(NW_PING, ping)
		end

		Notify(ply, "Фейковый пинг " .. ping .. " мс выдан: " .. Names(targets))
	end)
:End()

command.new("unfakeping")
	:SetPermission("unfakeping", "superadmin")
	:AddArg("player", {optional = true})
	:Help("Снимает фейковый пинг")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			targets[i]:SetNWInt(NW_PING, -1)
		end

		Notify(ply, "Фейковый пинг снят: " .. Names(targets))
	end)
:End()

-- ============================================================
-- ИНКОГНИТО
-- ============================================================

command.new("incognito")
	:SetPermission("incognito", "superadmin")
	:AddArg("player", {optional = true})
	:Help("Показывает в табе и чате группу user (удобно наблюдать за игроками незаметно)")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			targets[i]:SetNWString(NW_GROUP, "user")
		end

		Notify(ply, "Режим инкогнито включён: " .. Names(targets))
	end)
:End()

command.new("unincognito")
	:SetPermission("unincognito", "superadmin")
	:AddArg("player", {optional = true})
	:Help("Выключает режим инкогнито")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			targets[i]:SetNWString(NW_GROUP, "")
		end

		Notify(ply, "Режим инкогнито выключен: " .. Names(targets))
	end)
:End()

-- unfake - снять всё сразу
command.new("unfake")
	:SetPermission("unfake", "superadmin")
	:AddArg("player", {optional = true})
	:Help("Снимает все фейки (группа, имя, пинг)")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			targets[i]:SetNWString(NW_GROUP, "")
			targets[i]:SetNWString(NW_NAME, "")
			targets[i]:SetNWInt(NW_PING, -1)
		end

		Notify(ply, "Все фейки сняты: " .. Names(targets))
	end)
:End()

-- realinfo - настоящие данные (видите только вы)
command.new("realinfo")
	:SetPermission("realinfo", "superadmin")
	:AddArg("player", {single_target = true})
	:Help("Показывает настоящие данные игрока и его фейки (видно только вам)")
	:OnExecute(function(ply, targets)
		local target = targets[1]
		if not IsValid(target) then return end

		local fakeGroup = target:GetNWString(NW_GROUP, "")
		local fakeName = target:GetNWString(NW_NAME, "")
		local fakePing = target:GetNWInt(NW_PING, -1)

		Notify(ply, string.format(
			"%s | %s | группа: %s | фейк-группа: %s | фейк-имя: %s | фейк-пинг: %s",
			target:Nick(),
			target:SteamID(),
			target:GetUserGroup(),
			fakeGroup ~= "" and fakeGroup or "нет",
			fakeName ~= "" and fakeName or "нет",
			fakePing >= 0 and tostring(fakePing) or "нет"
		))
	end)
:End()

-- ============================================================
-- СКРЫТЫЕ АДМИН-ДЕЙСТВИЯ (!not)
-- ============================================================
-- Пока режим включён, сообщения вида "{A} кикнул {T}" / "{A} забанил {T}" и т.п.
-- от ВАШИХ команд не показываются другим игрокам. Их видите только вы
-- (и они пишутся в консоль сервера). Режим живёт до выхода с сервера или смены карты.

local NOT_FIELD = "SAMLead.Stealth"

if SERVER then
	-- не оборачиваем второй раз при перезагрузке файла
	sam.SAMLead_OrigSendMessage = sam.SAMLead_OrigSendMessage or sam.player.send_message
	local orig_send_message = sam.SAMLead_OrigSendMessage

	function sam.player.send_message(ply, msg, tbl)
		-- ply == nil значит "всем игрокам"
		if ply == nil and istable(tbl) then
			local admin = tbl.A
			if isentity(admin) and IsValid(admin) and admin:IsPlayer() and admin[NOT_FIELD] then
				orig_send_message(admin, msg, tbl)        -- видит сам админ
				orig_send_message(sam.console, msg, tbl)  -- и консоль сервера
				return
			end
		end

		return orig_send_message(ply, msg, tbl)
	end
end

command.new("not")
	:SetPermission("not", "superadmin")
	:Help("Скрывает/показывает все ваши админ-действия от остальных игроков (переключатель)")
	:OnExecute(function(ply)
		if not IsValid(ply) then
			Notify(ply, "Эту команду может использовать только игрок.")
			return
		end

		ply[NOT_FIELD] = not ply[NOT_FIELD]

		if ply[NOT_FIELD] then
			Notify(ply, "Скрытый режим ВКЛЮЧЁН: ваши админ-действия не видны другим игрокам. Напишите !not ещё раз, чтобы выключить.")
		else
			Notify(ply, "Скрытый режим ВЫКЛЮЧЕН: ваши админ-действия снова видны всем.")
		end
	end)
:End()

-- ============================================================
-- СОБЫТИЯ И ОБЪЯВЛЕНИЯ
-- ============================================================

command.new("bigmsg")
	:SetPermission("bigmsg", "superadmin")
	:AddArg("text", {hint = "текст объявления"})
	:Help("Большое объявление от руководства по центру экрана у всех игроков")
	:OnExecute(function(ply, text)
		text = string.sub(string.Trim(text or ""), 1, 200)
		if text == "" then return end

		net.Start("SAMLead.BigMsg")
			net.WriteString(text)
		net.Broadcast()
	end)
:End()

command.new("playall")
	:SetPermission("playall", "superadmin")
	:AddArg("text", {hint = "путь к звуку, например ambient/alarms/warningbell1.wav"})
	:Help("Проигрывает звук всем игрокам")
	:OnExecute(function(ply, path)
		path = string.Trim(path or "")

		if not IsValidSoundPath(path) then
			Notify(ply, "Неверный путь к звуку. Пример: ambient/alarms/warningbell1.wav")
			return
		end

		net.Start("SAMLead.Sound")
			net.WriteString(path)
		net.Broadcast()
	end)
:End()

command.new("healall")
	:SetPermission("healall", "superadmin")
	:Help("Лечит всех живых игроков до максимума здоровья")
	:OnExecute(function(ply)
		local count = 0

		for _, p in ipairs(player.GetAll()) do
			if p:Alive() then
				p:SetHealth(p:GetMaxHealth())
				count = count + 1
			end
		end

		Announce("{A} вылечил всех игроков ({V})", {A = ply, V = count})
	end)
:End()

command.new("fov")
	:SetPermission("fov", "superadmin")
	:AddArg("player")
	:AddArg("number", {hint = "градусы (обычно 90)", optional = true, default = 130, min = 10, max = 170, round = true})
	:Help("Меняет поле зрения игрока (рыбий глаз или бинокль)")
	:OnExecute(function(ply, targets, fov)
		for i = 1, #targets do
			targets[i]:SetFOV(fov, 0.5)
		end

		Announce("{A} изменил поле зрения {T} ({V})", {A = ply, T = targets, V = fov})
	end)
:End()

command.new("unfov")
	:SetPermission("unfov", "superadmin")
	:AddArg("player", {optional = true})
	:Help("Возвращает обычное поле зрения")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			targets[i]:SetFOV(0, 0.5)
		end

		Announce("{A} вернул обычное поле зрения {T}", {A = ply, T = targets})
	end)
:End()

-- ============================================================
-- МУЗЫКА В РАДИУСЕ (playsong / stopsong)
-- ============================================================
-- !playsong <радиус> <ссылка или путь>
--   ссылка: прямая ссылка на аудиофайл (.mp3 / .ogg / .wav), http:// или https://
--           (страницы YouTube, VK, Spotify и т.п. НЕ работают - нужен прямой файл)
--   путь:   звук из контента сервера/игры, например ambient/alarms/warningbell1.wav
-- Музыка играет из точки, где стоял админ в момент команды. Чем дальше игрок от
-- этой точки, тем тише; за пределами радиуса звука нет.

local MAX_SONGS = 5 -- одновременно играющих песен (старые останавливаются)
local song_counter = 0

local function IsValidSongURL(url)
	return #url <= 400
		and string.match(url, "^https?://[%w%-%._~:/%?#%[%]@!%$&'%(%)%*%+,;=%%]+$") ~= nil
end

command.new("playsong")
	:SetPermission("playsong", "superadmin")
	:AddArg("number", {hint = "радиус (50-10000)", min = 50, max = 10000, round = true})
	:AddArg("text", {hint = "ссылка на mp3/ogg/wav или путь к звуку"})
	:Help("Включает песню по ссылке или из контента в заданном радиусе вокруг вас")
	:OnExecute(function(ply, radius, source)
		if not IsValid(ply) then
			Notify(ply, "Эту команду может использовать только игрок (музыка играет из вашей позиции).")
			return
		end

		source = string.Trim(source or "")
		local is_url = string.match(source, "^https?://") ~= nil

		if is_url then
			if not IsValidSongURL(source) then
				Notify(ply, "Неверная ссылка. Нужна прямая ссылка на аудиофайл (http/https), без пробелов.")
				return
			end
		else
			source = string.gsub(source, "^sound/", "")
			if not IsValidSoundPath(source) then
				Notify(ply, "Неверный путь к звуку. Пример: ambient/alarms/warningbell1.wav")
				return
			end
		end

		song_counter = song_counter + 1

		net.Start("SAMLead.Song")
			net.WriteUInt(song_counter % 65536, 16)
			net.WriteBool(is_url)
			net.WriteString(source)
			net.WriteVector(ply:GetPos())
			net.WriteUInt(radius, 16)
		net.Broadcast()

		local label = is_url and (string.match(source, "^https?://([^/]+)") or source) or source
		Announce("{A} включил музыку ({V}) в радиусе {V_2}", {A = ply, V = label, V_2 = radius})
	end)
:End()

command.new("stopsong")
	:SetPermission("stopsong", "superadmin")
	:Help("Останавливает всю музыку, включённую через playsong")
	:OnExecute(function(ply)
		net.Start("SAMLead.SongStop")
		net.Broadcast()

		Announce("{A} остановил музыку", {A = ply})
	end)
:End()

-- ============================================================
-- Клиентская часть
-- ============================================================
if CLIENT then
	surface.CreateFont("SAMLead.Title", {
		font = "Roboto", size = 34, weight = 800, extended = true,
	})
	surface.CreateFont("SAMLead.Text", {
		font = "Roboto", size = 28, weight = 600, extended = true,
	})

	local function Wrap(text, font, max_width)
		surface.SetFont(font)

		local lines, line = {}, ""
		for word in string.gmatch(text, "%S+") do
			local test = (line == "") and word or (line .. " " .. word)
			if line ~= "" and surface.GetTextSize(test) > max_width then
				lines[#lines + 1] = line
				line = word
			else
				line = test
			end
		end
		if line ~= "" then lines[#lines + 1] = line end

		return lines
	end

	net.Receive("SAMLead.BigMsg", function()
		local text = net.ReadString()

		local lines = Wrap(text, "SAMLead.Text", ScrW() * 0.7)
		local start, life = CurTime(), 8

		surface.PlaySound("buttons/combine_button1.wav")

		hook.Add("HUDPaint", "SAMLead.BigMsg", function()
			local t = CurTime() - start
			if t > life then
				hook.Remove("HUDPaint", "SAMLead.BigMsg")
				return
			end

			local alpha = 255 * math.Clamp(math.min(t / 0.4, (life - t) / 1), 0, 1)
			local black = Color(0, 0, 0, alpha)
			local x, y = ScrW() / 2, ScrH() * 0.16

			draw.SimpleTextOutlined("ОБЪЯВЛЕНИЕ РУКОВОДСТВА", "SAMLead.Title", x, y, Color(255, 200, 60, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, black)

			for i, line in ipairs(lines) do
				draw.SimpleTextOutlined(line, "SAMLead.Text", x, y + 20 + i * 34, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, black)
			end
		end)
	end)

	net.Receive("SAMLead.Sound", function()
		local path = net.ReadString()
		if path ~= "" then
			surface.PlaySound(path)
		end
	end)

	-- --------------------------------------------------------
	-- Музыка в радиусе
	-- --------------------------------------------------------
	local songs = {}

	local volume_cvar = CreateClientConVar(
		"samlead_song_volume", "1", true, false,
		"Громкость музыки от руководства (0 - выключить, 1 - максимум)", 0, 1
	)

	local function StopSong(song)
		song.dead = true
		if IsValid(song.channel) then
			song.channel:Stop()
		end
	end

	net.Receive("SAMLead.Song", function()
		net.ReadUInt(16) -- id (зарезервировано)
		local is_url = net.ReadBool()
		local source = net.ReadString()
		local pos = net.ReadVector()
		local radius = net.ReadUInt(16)

		if source == "" or radius <= 0 then return end
		if volume_cvar:GetFloat() <= 0 then return end

		local song = {pos = pos, radius = radius}
		songs[#songs + 1] = song

		while #songs > MAX_SONGS do
			StopSong(table.remove(songs, 1))
		end

		local function loaded(channel, _, err)
			if not IsValid(channel) then
				song.dead = true
				print("[SAM Leadership] Не удалось проиграть музыку: " .. tostring(err))
				return
			end

			if song.dead then
				channel:Stop()
				return
			end

			song.channel = channel
			channel:SetVolume(0)
			channel:Play()
			song.started = true
		end

		if is_url then
			sound.PlayURL(source, "noplay", loaded)
		else
			sound.PlayFile("sound/" .. source, "noplay", loaded)
		end
	end)

	net.Receive("SAMLead.SongStop", function()
		for i = 1, #songs do
			StopSong(songs[i])
		end
		table.Empty(songs)
	end)

	hook.Add("Think", "SAMLead.Songs", function()
		local count = #songs
		if count == 0 then return end

		local lp = LocalPlayer()
		if not IsValid(lp) then return end

		local eye = lp:EyePos()
		local base = volume_cvar:GetFloat()

		for i = count, 1, -1 do
			local song = songs[i]
			local channel = song.channel

			if song.dead then
				table.remove(songs, i)
			elseif IsValid(channel) then
				if song.started and channel:GetState() == GMOD_CHANNEL_STOPPED then
					-- песня закончилась
					table.remove(songs, i)
				else
					-- полная громкость в центре (первые 20% радиуса), дальше затухание до нуля
					local k = math.Clamp((1 - eye:Distance(song.pos) / song.radius) / 0.8, 0, 1)
					channel:SetVolume(k * k * base)
				end
			end
		end
	end)
end