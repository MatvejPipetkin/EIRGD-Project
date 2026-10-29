FACTION.name = "Эйренхаймское Государство"
FACTION.description = ""
FACTION.color = Color(255, 0, 0, 255)
FACTION.pay = 50
FACTION.models = {
	"models/player/gasmask.mdl",
	"models/player/riot.mdl",
	"models/player/swat.mdl",
	"models/player/urban.mdl",
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
				serial = "EIR-" .. math.random(1000, 9999) --  случайный серийник
			}
			
			inventory:Add("tablet", 1, tabletData)
		end
	end
end

FACTION_EIR = FACTION.index
