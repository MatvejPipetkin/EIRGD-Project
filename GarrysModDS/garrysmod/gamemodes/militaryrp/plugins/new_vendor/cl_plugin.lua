local PLUGIN = PLUGIN
local UI = PLUGIN.ui

-- ============================================================
-- Приём данных диалога от сервера (само окно — в cl_dialogue.lua)
-- ============================================================

net.Receive("ixNPCNode", function()
	local ent = net.ReadEntity()
	local name = net.ReadString()
	local desc = net.ReadString()
	local color = net.ReadColor()
	local text = net.ReadString()
	local count = net.ReadUInt(5)
	local opts = {}

	for i = 1, count do
		opts[i] = {text = net.ReadString(), tag = net.ReadString()}
	end

	PLUGIN:ShowDialogue(ent, name, desc, color, text, opts)
end)

net.Receive("ixNPCClose", function()
	if (IsValid(PLUGIN.dialogue)) then PLUGIN.dialogue:Close(true) end
end)
