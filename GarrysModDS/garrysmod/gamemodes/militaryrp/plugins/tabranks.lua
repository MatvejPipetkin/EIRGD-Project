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


function PLUGIN:InitializedConfig()
	local class = ix.chat.classes['ooc']

	if not class then return end

	class.OnChatAdd = function(self, speaker, text)
		-- @todo remove and fix actual cause of speaker being nil
		if (!IsValid(speaker)) then
			return
		end

		icon = Material(self.ranks~=nil and self.ranks[speaker:GetUserGroup()]~= nil and self.ranks[speaker:GetUserGroup()].icon or "icon16/user.png")

		local uGroup = speaker:GetUserGroup()
		local find = PLUGIN.ranks[uGroup]

		if find and find.chatAdd then
			chat.AddText(icon,find.col,find.chatAdd,Color(255, 50, 50), " [OOC] ", speaker, color_white, ": "..text)
			return
		end

		chat.AddText(icon, Color(255, 50, 50), "[OOC] ", speaker, color_white, ": "..text)

	end
	--PrintTable(ix.chat.classes['ooc'])
end

PLUGIN:InitializedConfig()

function PLUGIN:GetPlayerIcon(client)
	local rank = client:GetUserGroup()

	if self.ranks[rank] then
		return self.ranks[rank].icon or ""
	end
end

if CLIENT then
	function ix.hud.PopulatePlayerTooltip(tooltip, client)
		local name = tooltip:AddRow("name")
		name:SetImportant()
		name:SetText(client:SteamName())
		name:SetBackgroundColor(Color(44, 44, 44))
		name:SizeToContents()

		local nameHeight = name:GetTall()
		name:SetTextInset(nameHeight + 4, 0)
		name:SetWide(name:GetWide() + nameHeight + 4)

		local avatar = name:Add("AvatarImage")
		avatar:Dock(LEFT)
		avatar:SetPlayer(client, nameHeight)
		avatar:SetSize(name:GetTall(), name:GetTall())

		if PLUGIN.ranks[client:GetUserGroup()] then
			local rank = client:GetUserGroup()
			local icon = Material(hook.Run("GetPlayerIcon",client) or "icon16/heart.png")
			rank = string.gsub(rank,"^%l",string.upper)
			local tabRank = tooltip:AddRow("rank")
			tabRank:SetText(rank)
			tabRank:SetBackgroundColor(PLUGIN.ranks[client:GetUserGroup()].col or Color(0,0,0))
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