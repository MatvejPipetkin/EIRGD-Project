local PLUGIN = PLUGIN

PLUGIN.name = "Hide hud"
PLUGIN.description = "Check ammo"
PLUGIN.schema = "Any"
PLUGIN.author = "Lan0ther"

function PLUGIN:CanDrawAmmoHUD(weapon)
	return false
end
