local PLUGIN = PLUGIN

-- ========== Однократный перенос номеров званий ==========
-- В базе планшета у бойца хранится НОМЕР звания. Когда в лестницу вставляют новые звания,
-- старые номера начинают указывать на другие звания (был «Лейтенант» = 8, стал «Прапорщик» = 8).
-- Эта функция один раз переписывает номера по таблице ix.tablet.rankMigration (см. sh_plugin.lua)
-- и запоминает метку ix.tablet.rankLadder в базе, чтобы не переносить повторно.

function PLUGIN:MigrateRanks()
	local version = ix.tablet.rankLadder
	local maps = ix.tablet.rankMigration

	if (not version or not maps) then return end
	if (self.db.rankLadder == version) then return end

	local changed = 0

	for _, entry in pairs(self.db.roster) do
		local map = maps[entry.faction]

		if (map) then
			local new = map[entry.rank]

			if (new and new ~= entry.rank) then
				entry.rank = new
				changed = changed + 1
			end

			-- Звание, изменённое, пока бойца не было на сервере, тоже хранит номера.
			local pending = entry.pendingRank

			if (pending) then
				pending.from = map[pending.from] or pending.from
				pending.to = map[pending.to] or pending.to
			end
		end
	end

	self.db.rankLadder = version
	self:SetData(self.db, true)

	print(string.format("[Планшет] Лестница званий обновлена (%s): перенесено бойцов — %d.", tostring(version), changed))
end
