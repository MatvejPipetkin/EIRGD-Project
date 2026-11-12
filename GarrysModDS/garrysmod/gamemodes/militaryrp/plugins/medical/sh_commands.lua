ix.command.Add("MedicalHeal", {
	description = "Полностью вылечить персонажа (все конечности и состояния).",
	adminOnly = true,
	arguments = {bit.bor(ix.type.character, ix.type.optional)},
	OnRun = function(self, client, target)
		local victim = target and target:GetPlayer() or client

		if (!IsValid(victim) or !victim:GetCharacter()) then
			return "Персонаж не найден."
		end

		ix.medical.Reset(victim)
		victim:SetHealth(victim:GetMaxHealth())

		return "Вылечен: " .. victim:GetCharacter():GetName() .. "."
	end
})

ix.command.Add("MedicalAdd", {
	description = "Выдать состояние: MedicalAdd <персонаж> <id состояния> [id конечности].",
	adminOnly = true,
	arguments = {
		ix.type.character,
		ix.type.string,
		bit.bor(ix.type.string, ix.type.optional)
	},
	OnRun = function(self, client, target, conditionID, limbID)
		local victim = target:GetPlayer()

		if (!IsValid(victim)) then
			return "Игрок не найден."
		end

		if (!ix.medical.config.conditions[conditionID]) then
			local ids = {}

			for id in pairs(ix.medical.config.conditions) do
				ids[#ids + 1] = id
			end

			table.sort(ids)

			return "Нет такого состояния. Доступны: " .. table.concat(ids, ", ")
		end

		if (limbID and !ix.medical.limbsByID[limbID]) then
			return "Нет такой конечности. Доступны: head, chest, stomach, left_arm, right_arm, left_leg, right_leg"
		end

		ix.medical.AddCondition(victim, conditionID, limbID)

		return "Выдано: " .. conditionID .. "."
	end
})

ix.command.Add("MedicalCheck", {
	description = "Показать состояние тела персонажа.",
	adminOnly = true,
	arguments = {bit.bor(ix.type.character, ix.type.optional)},
	OnRun = function(self, client, target)
		local victim = target and target:GetPlayer() or client

		if (!IsValid(victim) or !victim:GetCharacter()) then
			return "Персонаж не найден."
		end

		local state = ix.medical.GetState(victim)
		local lines = {}

		for _, limb in ipairs(ix.medical.config.limbs) do
			lines[#lines + 1] = string.format("%s: %d/%d", limb.name, math.floor(ix.medical.GetLimbHP(state, limb.id)), limb.maxHP)
		end

		for key in pairs(state.cond) do
			lines[#lines + 1] = "• " .. key
		end

		return table.concat(lines, "; ")
	end
})
