ENT.Type = "anim"
ENT.PrintName = "Верстак"
ENT.Category = "Helix"
ENT.Spawnable = false -- верстаки ставятся записями из list SpawnableEntities (см. sh_plugin.lua)
ENT.AdminOnly = true
ENT.bNoPersist = true -- сохранением занимается плагин
ENT.PopulateEntityInfo = true

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "BenchType")
	self:NetworkVar("Bool", 0, "Active")
end
