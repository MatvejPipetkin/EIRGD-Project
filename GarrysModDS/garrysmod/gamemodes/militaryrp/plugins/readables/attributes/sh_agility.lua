ATTRIBUTE.name = "Ловкость"
ATTRIBUTE.description = "Проворство и координация. Бонусы на максимуме: скорость ходьбы и бега +12%, высота прыжка +15%, урон от падения -50%."
ATTRIBUTE.noStartBonus = true

-- Высота прыжка. Скорость и урон от падения обрабатываются в sh_plugin.lua / sv_plugin.lua.
-- Множители лежат в ix.readables.perks (sh_plugin.lua).
function ATTRIBUTE:OnSetup(client, value)
	local maxValue = ix.config.Get("maxAttributes", 100)
	local fraction = math.Clamp(value / maxValue, 0, 1)

	client:SetJumpPower(ix.config.Get("jumpPower", 200) * (1 + fraction * ix.readables.perks.agility.jump))
end
