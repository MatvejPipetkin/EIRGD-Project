CLASS.name = "Боец спецназа"
CLASS.description = "Элитное подразделение для особых задач: штурм, захват, зачистка."
CLASS.faction = FACTION_EIR
CLASS.isDefault = false

function CLASS:OnSpawn(client)
    client:SetMaxHealth(150)
    client:SetMaxArmor(150)
end

CLASS_EIR_SPEC = CLASS.index
