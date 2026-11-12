local PLUGIN = PLUGIN

-- пересчёт веса одного игрока; значения уходят клиенту только если изменились
function ix.weight.Refresh(client)
	local character = client:GetCharacter()
	local weight, maxWeight, slow = 0, 0, 0

	if (character and character:GetInventory() and ix.config.Get("weightEnabled", true)) then
		weight = math.Round(ix.weight.GetCharacterWeight(character), 2)
		maxWeight = math.Round(ix.weight.GetMaxWeight(client), 2)
		slow = math.Round(ix.weight.GetSlowPercent(weight, maxWeight), 1)
	end

	if (client:GetLocalVar("carryWeight") != weight) then
		client:SetLocalVar("carryWeight", weight)
	end

	if (client:GetLocalVar("carryMax") != maxWeight) then
		client:SetLocalVar("carryMax", maxWeight)
	end

	if (client:GetLocalVar("weightSlow") != slow) then
		client:SetLocalVar("weightSlow", slow)
	end
end

function ix.weight.RefreshAll()
	for _, client in ipairs(player.GetAll()) do
		if (IsValid(client)) then
			ix.weight.Refresh(client)
		end
	end
end

-- предметы добавляются, выбрасываются и меняют количество в разных местах,
-- поэтому вес просто пересчитывается несколько раз в секунду
timer.Create("ixWeightUpdate", 0.5, 0, function()
	ix.weight.RefreshAll()
end)

function PLUGIN:PlayerLoadedCharacter(client)
	timer.Simple(0.25, function()
		if (IsValid(client)) then
			ix.weight.Refresh(client)
		end
	end)
end
