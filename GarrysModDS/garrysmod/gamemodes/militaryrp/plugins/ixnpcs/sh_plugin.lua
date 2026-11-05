PLUGIN.name = "NPC System"
PLUGIN.author = "Claude"
PLUGIN.description = "NPC с диалогами, заданиями и магазином. Спавн через Q-меню, настройка — только superadmin."

-- глобальная ссылка, чтобы её видела сущность ix_npc
ix.npcsys = PLUGIN

CAMI.RegisterPrivilege({
	Name = "Helix - Manage NPC System",
	MinAccess = "superadmin"
})

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_ui.lua")
ix.util.Include("cl_dialogue.lua")
ix.util.Include("cl_editor.lua")
ix.util.Include("cl_shop.lua")
ix.util.Include("cl_plugin.lua")

-- Только superadmin (жёсткая проверка + привилегия CAMI для админ-модов).
function PLUGIN:CanManage(client)
	if (!IsValid(client) or !client:IsSuperAdmin()) then return false end

	return CAMI.PlayerHasAccess(client, "Helix - Manage NPC System", nil) != false
end

-- ============================================================
-- Контекстное меню (C + ПКМ по NPC → "Edit NPC"), как "Edit Vendor"
-- ============================================================

properties.Add("npc_edit", {
	MenuLabel = "Edit NPC",
	Order = 999,
	MenuIcon = "icon16/user_edit.png",

	Filter = function(self, entity, client)
		if (!IsValid(entity)) then return false end
		if (entity:GetClass() != "ix_npc") then return false end
		if (!gamemode.Call("CanProperty", client, "npc_edit", entity)) then return false end

		return ix.npcsys:CanManage(client)
	end,

	Action = function(self, entity)
		self:MsgStart()
			net.WriteEntity(entity)
		self:MsgEnd()
	end,

	Receive = function(self, length, client)
		local entity = net.ReadEntity()

		if (!IsValid(entity)) then return end
		if (!self:Filter(entity, client)) then return end

		ix.npcsys:SendEditor(client, entity)
	end
})

-- ============================================================
-- Команды
-- ============================================================

ix.command.Add("NPCList", {
	description = "Список всех NPC на карте. Только superadmin.",
	superAdminOnly = true,
	OnRun = function(self, client)
		for _, ent in ipairs(ents.FindByClass("ix_npc")) do
			local p = ent:GetPos()
			client:ChatPrint(string.format("[NPC] %s — %d %d %d", ent:GetDisplayName(), p.x, p.y, p.z))
		end
	end
})

-- Для всех игроков
ix.command.Add("QuestLog", {
	description = "Показывает ваши активные задания.",
	OnRun = function(self, client)
		local char = client:GetCharacter()
		if (!char) then return end

		local found = false

		for _, q in pairs(char:GetData("npcQuests", {})) do
			if (q.state == "active") then
				found = true
				client:ChatPrint("• " .. q.name)

				for i = 1, #q.obj do
					client:ChatPrint("    – " .. ix.npcsys:ObjectiveText(char, q, i))
				end
			end
		end

		if (!found) then
			return "У вас нет активных заданий."
		end
	end
})
