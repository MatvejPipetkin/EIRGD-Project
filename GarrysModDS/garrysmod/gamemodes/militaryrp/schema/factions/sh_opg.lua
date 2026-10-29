FACTION.name = "Козинское ОПГ"
FACTION.description = ""
FACTION.color = Color(128, 128, 128, 255)
FACTION.models = {
	"models/player/Group03/male_03.mdl",
}
FACTION.isDefault = false
FACTION.isGloballyRecognized = false

function FACTION:OnCharacterCreated(client, character)
	if (character:GetFaction() == FACTION.index) then
		local inventory = character:GetInventory()
		
		if (inventory) then
			local charName = character:GetName()
			
			local tabletData = {
				ownerName = charName,
				serial = "OPG-" .. math.random(1000, 9999) --  случайный серийник
			}
			
			inventory:Add("tablet", 1, tabletData)
		end
	end
end

FACTION_OPG = FACTION.index
