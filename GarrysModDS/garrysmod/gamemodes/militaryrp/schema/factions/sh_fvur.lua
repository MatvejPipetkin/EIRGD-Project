FACTION.name = "Фронт Возрождения Узирской Республики"
FACTION.description = ""
FACTION.color = Color(30, 144, 255, 255)
FACTION.models = {
	"models/player/arctic.mdl",
	"models/player/guerilla.mdl",
	"models/player/leet.mdl",
	"models/player/phoenix.mdl",
}
FACTION.isDefault = true
FACTION.isGloballyRecognized = false

function FACTION:OnCharacterCreated(client, character)
	if (character:GetFaction() == FACTION.index) then
		local inventory = character:GetInventory()
		
		if (inventory) then
			local charName = character:GetName()
			
			local tabletData = {
				ownerName = charName,
				serial = "FVUR-" .. math.random(1000, 9999) --  случайный серийник
			}
			
			inventory:Add("tablet", 1, tabletData)
		end
	end
end

FACTION_FVUR = FACTION.index
