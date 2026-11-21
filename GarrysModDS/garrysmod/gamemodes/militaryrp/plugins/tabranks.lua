local PLUGIN = PLUGIN
PLUGIN.name = "Tab Rank"

PLUGIN.ranks = {
	["superadmin"] = 
		{
			col = Color(84,204,252,120),
			icon = "interval_ui/chat_icons/star.png",
		},
	["Руководство"] = 
		{
			col = Color(84,204,252,120),
			icon = "interval_ui/chat_icons/star.png",
		},
	["Global Team"] = 
		{
			col = Color(84,204,252,120),
			icon = "interval_ui/chat_icons/star.png",
		},
	["Super Team"] = 
		{
			col = Color(84,204,252,120),
			icon = "interval_ui/chat_icons/star.png",
		},
	["Спец Админ"] = 
		{
			col = Color(84,204,252,120),
			icon = "interval_ui/chat_icons/moderator.png",
		},
	["Спец Ивентолог"] = 
		{
			col = Color(84,204,252,120),
			icon = "interval_ui/chat_icons/paintbrush.png",
		},
	["Спец Куратор"] = 
		{
			col = Color(84,204,252,120),
			icon = "interval_ui/chat_icons/moderator.png",
		},
	["Старший Админ"] = 
		{
			col = Color(113, 54, 138,120),
			icon = "interval_ui/chat_icons/moderator.png",
		},
	["Старший Ивентолог"] = 
		{
			col = Color(113, 54, 138,120),
			icon = "interval_ui/chat_icons/paintbrush.png",
		},
	["Старший Куратор"] = 
		{
			col = Color(113, 54, 138,120),
			icon = "interval_ui/chat_icons/moderator.png",
		},
	["Младший Админ"] = 
		{
			col = Color(113, 54, 138,120),
			icon = "interval_ui/chat_icons/moderator.png",
		},
	["Младший Ивентолог"] = 
		{
			col = Color(113, 54, 138,120),
			icon = "interval_ui/chat_icons/paintbrush.png",
		},
	["Младший Куратор"] = 
		{
			col = Color(0,0,0,120),
			icon = "interval_ui/chat_icons/moderator.png",
		},
	["sponsor blessed"] = 
		{
			col = Color(0,120,0,120),
			icon = "interval_ui/chat_icons/heart.png",
		},
	["sponsor inversive"] = 
		{
			col = Color(0,120,0,120),
			icon = "interval_ui/chat_icons/heart.png",
		},
	["user"] = 
		{
			col = Color(60,60,60,120),
			icon = "interval_ui/chat_icons/message_icon.png",
		},
}


-- Фейковые данные, которые выдаёт SAM-модуль sh_leadership.lua (только визуально).
-- Хранятся в NW-переменных, поэтому пропадают сами, когда игрок выходит с сервера.
local NW_GROUP = "SAMLead.FakeGroup"
local NW_NAME  = "SAMLead.FakeName"
local NW_PING  = "SAMLead.FakePing"

-- Возвращает группу для отображения и true, если она фейковая
function PLUGIN:GetDisplayGroup(client)
	local fake = client:GetNWString(NW_GROUP, "")
	if fake ~= "" then
		return fake, true
	end

	return client:GetUserGroup(), false
end

-- Возвращает фейковое имя или nil
function PLUGIN:GetDisplayName(client)
	local fake = client:GetNWString(NW_NAME, "")
	if fake ~= "" then
		return fake
	end
end

-- Имя в IC-чате (Helix берёт его через этот хук)
function PLUGIN:GetCharacterName(speaker, chatType)
	if IsValid(speaker) then
		return self:GetDisplayName(speaker)
	end
end

function PLUGIN:InitializedConfig()
	local class = ix.chat.classes['ooc']

	if not class then return end

	class.OnChatAdd = function(self, speaker, text)
		-- @todo remove and fix actual cause of speaker being nil
		if (!IsValid(speaker)) then
			return
		end

		-- группа и имя берутся с учётом фейков
		local uGroup = PLUGIN:GetDisplayGroup(speaker)
		local find = PLUGIN.ranks[uGroup]
		local fakeName = PLUGIN:GetDisplayName(speaker)

		local icon = Material(find and find.icon or "icon16/user.png")

		local args = {icon}

		if find and find.chatAdd then
			args[#args + 1] = find.col
			args[#args + 1] = find.chatAdd
			args[#args + 1] = Color(255, 50, 50)
			args[#args + 1] = " [OOC] "
		else
			args[#args + 1] = Color(255, 50, 50)
			args[#args + 1] = "[OOC] "
		end

		if fakeName then
			args[#args + 1] = team.GetColor(speaker:Team())
			args[#args + 1] = fakeName
		else
			args[#args + 1] = speaker
		end

		args[#args + 1] = color_white
		args[#args + 1] = ": "..text

		chat.AddText(unpack(args))

	end
	--PrintTable(ix.chat.classes['ooc'])
end

PLUGIN:InitializedConfig()

function PLUGIN:GetPlayerIcon(client)
	local rank = self:GetDisplayGroup(client)

	if self.ranks[rank] then
		return self.ranks[rank].icon or ""
	end
end

if CLIENT then
	function ix.hud.PopulatePlayerTooltip(tooltip, client)
		-- руководство (superadmin) видит настоящие данные рядом с фейковыми
		local viewerIsStaff = IsValid(LocalPlayer()) and LocalPlayer():IsSuperAdmin()

		local fakeName = PLUGIN:GetDisplayName(client)
		local nameText = fakeName or client:SteamName()
		if fakeName and viewerIsStaff then
			nameText = nameText .. " (реально: " .. client:SteamName() .. ")"
		end

		-- при фейковом имени настоящая аватарка скрыта от обычных игроков
		local showAvatar = (not fakeName) or viewerIsStaff

		local name = tooltip:AddRow("name")
		name:SetImportant()
		name:SetText(nameText)
		name:SetBackgroundColor(Color(44, 44, 44))
		name:SizeToContents()

		local nameHeight = name:GetTall()
		if showAvatar then
			name:SetTextInset(nameHeight + 4, 0)
			name:SetWide(name:GetWide() + nameHeight + 4)

			local avatar = name:Add("AvatarImage")
			avatar:Dock(LEFT)
			avatar:SetPlayer(client, nameHeight)
			avatar:SetSize(name:GetTall(), name:GetTall())
		end

		local realGroup = client:GetUserGroup()
		local displayGroup, isFakeGroup = PLUGIN:GetDisplayGroup(client)
		local rankData = PLUGIN.ranks[displayGroup]

		-- фейковая группа, которой нет в списке ranks, показывается как обычная
		if not rankData and isFakeGroup then
			rankData = {col = Color(60,60,60,120), icon = "icon16/user.png"}
		end

		if rankData then
			local rank = displayGroup
			local icon = Material(hook.Run("GetPlayerIcon",client) or rankData.icon or "icon16/heart.png")
			rank = string.gsub(rank,"^%l",string.upper)
			if isFakeGroup and viewerIsStaff then
				rank = rank .. " (реально: " .. realGroup .. ")"
			end
			local tabRank = tooltip:AddRow("rank")
			tabRank:SetText(rank)
			tabRank:SetBackgroundColor(rankData.col or Color(0,0,0))
			tabRank:SizeToContents()
			local w,h = tabRank:GetSize()
			tabRank:SetTextInset(16+4,0)
			tabRank:SetWide(tabRank:GetWide() + 16+4)

			local dIcon = tabRank:Add("DImage")
			dIcon:SetMaterial(icon)
			dIcon:SetSize(16,16)
			dIcon:SetPos((h/2)-(16/2),(h/2)-(16/2))
		end

		local currentPing = client:Ping()

		local fakePing = client:GetNWInt(NW_PING, -1)
		if fakePing >= 0 then
			currentPing = fakePing
		end

		local ping = tooltip:AddRow("ping")
		ping:SetText(L("ping", currentPing))
		ping.Paint = function(_, width, height)
			surface.SetDrawColor(ColorAlpha(derma.GetColor(
				currentPing < 110 and "Success" or (currentPing < 165 and "Warning" or "Error")
			, tooltip), 22))
			surface.DrawRect(0, 0, width, height)
		end
		ping:SizeToContents()

		tooltip:SizeToContents()

		hook.Run("PopulatePlayerTooltip", client, tooltip)
	end
end