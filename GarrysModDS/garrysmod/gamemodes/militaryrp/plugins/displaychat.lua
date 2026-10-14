local PLUGIN = PLUGIN

PLUGIN.name = "Text Display"
PLUGIN.description = "Текст над головой"
PLUGIN.author = ""


ix.option.Add("OverHeadText", ix.type.bool, true, { -- Отображение текста над головой
	category = "Text Display"
})

ix.option.Add("MessageLimit", ix.type.number, 256, { -- Лимит длины сообщения
	category = "Text Display",
	min = 10, max = 2048
})

ix.option.Add("DissapearTime", ix.type.number, 0.4, { -- Длительность на символ
	category = "Text Display",
	min = 0.01, max = 1, decimals = 2
})

if (SERVER) then return end
surface.CreateFont("awDisplayChat32", {	font = ix.config.Get("generalFont"),	size = 32,
	extended = true,
	weight = 1000
})

local stored = PLUGIN.chatDisplay or {}
PLUGIN.chatDisplay = stored

local function GetColor(info)
	local ct = info.chatType
	return (ct == "y" and Color(238,59,59)) or (ct == "w" and Color(71,71,71)) or color_white
end

local InCorrectChatType = {
	["ooc"] = true,
	["looc"] = true,
	["broadcast"] = true,
	["dispatch"] = true,
	["curfew"] = true,
}

function PLUGIN:MessageReceived(client, messageInfo)

	if !InCorrectChatType[messageInfo.chatType] and (IsValid(client) and ix.option.Get("OverHeadText", false)) then
		if (hook.Run("ShouldChatMessageDisplay", client, messageInfo) != false) then
			local maxLen = ix.option.Get("MessageLimit")
			local text = messageInfo.text
			local textLen = string.utf8len(text)
			local duration = math.max(2, math.min(textLen, maxLen) * ix.option.Get("DissapearTime"))

			stored[client] = {
				text = textLen > maxLen and utf8.sub(text, 1, ix.option.Get("MessageLimit")).."..." or text,
				-- color = class and class.color or color_white,
				color = GetColor(messageInfo),
				font = messageInfo.chatType == "y" and "awDisplayChat32" or "ixGenericFont",
				fadeTime = duration
			}
		end
	end
end

function PLUGIN:ShouldChatMessageDisplay(client, messageInfo)
	if (messageInfo.anonymous) then
		return false
	end
	if (LocalPlayer():EyePos():DistToSqr(client:EyePos()) >= 300 * 300) then
		return false
	end
	if client:GetMoveType() == MOVETYPE_NOCLIP then
		return false
	end
end

function PLUGIN:HUDPaint()
	if (ix.option.Get("OverHeadText", false) and stored and !table.IsEmpty(stored)) then
		local client = LocalPlayer()
		local clientPos = client:EyePos()
		local scrW = ScrW()
		local cx, cy = scrW * 0.5, ScrH() * 0.5
		local toRem = {}

		for k, v in pairs(stored) do
			if (IsValid(k)) then
				local targetPos = hook.Run("GetTypingIndicatorPosition", k)
				local pos = targetPos:ToScreen()
				local distSqr = clientPos:DistToSqr(targetPos)

				if (distSqr <= 300 * 300) then
					local camMult = (1 - math.Distance(cx, cy, pos.x, pos.y) / scrW * 1.5)
					local distanceMult = (1 - distSqr * 0.003 * 0.003) -- 0.003 == 1/300
					local alpha = 255 * camMult * distanceMult * math.min(v.fadeTime, 1)
					local col1, col2 = ColorAlpha(v.color, alpha), Color(0, 0, 0, alpha)
					local font = v.font

				surface.SetFont(font)

				local fullW, fullH = surface.GetTextSize(v.text)
				local lines = ix.util.WrapText(v.text, scrW * 0.25, font)
				local offset = 4
				local curY = pos.y - ((fullH + offset) * #lines) / 2

				for k1, v1 in pairs(lines) do
					local w, h = surface.GetTextSize(v1)

					draw.SimpleTextOutlined(v1, font, pos.x - w / 2, curY, col1, nil, nil, 1, col2)

					curY = curY + h + offset
				end

				v.fadeTime = v.fadeTime - FrameTime()

					if (v.fadeTime <= 0) then
						table.insert(toRem, k)
					end
				else
					table.insert(toRem, k)
				end
			else
				table.insert(toRem, k)
			end
		end

		for k, v in pairs(toRem) do
			stored[v] = nil
		end
	end
end
