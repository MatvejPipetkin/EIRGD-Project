ENT.Type = "anim"
ENT.PrintName = "Узел сети (взлом)"
ENT.Author = "-"
ENT.Category = "Helix"
ENT.Spawnable = false -- узлы ставятся записями из list SpawnableEntities (см. sh_plugin.lua)
ENT.AdminOnly = true
ENT.PhysgunDisabled = false
ENT.bNoPersist = true -- сохраняется плагином (SaveData), а не системой постоянных пропов Helix

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "NodeType")
	self:NetworkVar("String", 1, "NodeName")
	self:NetworkVar("String", 2, "OwnerFaction")
	self:NetworkVar("Int", 0, "Difficulty")
	self:NetworkVar("Bool", 0, "Cooling")
	self:NetworkVar("Bool", 1, "Busy")
end
