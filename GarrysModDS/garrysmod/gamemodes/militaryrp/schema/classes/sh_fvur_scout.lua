CLASS.name = "Разведчик"
CLASS.description = "Скрытное наблюдение, поиск маршрутов и сбор сведений о противнике."
CLASS.faction = FACTION_FVUR
CLASS.isDefault = false

function CLASS:OnSpawn(client)
    client:SetMoveSpeed(290)
    client:SetRunSpeed(320)
end

CLASS_FVUR_SCOUT = CLASS.index
