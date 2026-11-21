local PLUGIN = PLUGIN

-- ========== Зарплата по званию ==========
-- Суммы лежат в ix.tablet.factions[<фракция>].pay (индекс = номер звания), см. sh_plugin.lua.
-- FACTION.pay у фракций больше не используется — его нужно удалить из sh_*.lua.

-- Сколько положено персонажу за одну выплату (0 — если он не в составе или у звания нет суммы).
function PLUGIN:GetRankPay(char)
	local entry = self.db.roster[tostring(char:GetID())]

	if (!entry) then return 0 end

	-- Запись состава должна относиться к текущей фракции персонажа.
	local faction = ix.faction.indices[char:GetFaction()]

	if (!faction or faction.uniqueID != entry.faction) then return 0 end

	local cfg = ix.tablet.factions[entry.faction]
	local pay = cfg and cfg.pay and cfg.pay[entry.rank]

	return math.max(math.floor(tonumber(pay) or 0), 0)
end

function PLUGIN:PayRoll()
	for _, client in ipairs(player.GetAll()) do
		local char = client:GetCharacter()

		if (!char) then continue end

		local faction = ix.faction.indices[char:GetFaction()]

		if (!faction) then continue end

		local amount = self:GetRankPay(char)

		if (amount <= 0) then continue end

		-- Сохраняем возможность запретить выплату другими плагинами (например, за AFK).
		if (hook.Run("CanPlayerEarnSalary", client, faction) == false) then continue end

		char:SetMoney(char:GetMoney() + amount)

		local text = (ix.currency and ix.currency.Get) and ix.currency.Get(amount) or tostring(amount)

		client:Notify("Вы получили зарплату: " .. text .. ".")
	end
end

timer.Create("ixTabletPayroll", math.max(tonumber(ix.tablet.payInterval) or 300, 10), 0, function()
	PLUGIN:PayRoll()
end)
