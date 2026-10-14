
local PLUGIN = PLUGIN

function PLUGIN:LoadData()
	self:LoadLootingSystem()
end

function PLUGIN:SaveData()
	self:SaveLootingSystem()
end

netstream.Hook("EditLootingSysten", function(client, entity, data)
	if client:IsAdmin() or client:IsSuperAdmin() then
		entity.data = data
		entity:SetModel(data.model)
		entity:SetSolid(SOLID_VPHYSICS)
		entity:PhysicsInit(SOLID_VPHYSICS)
		entity:SetUseType(SIMPLE_USE)

		local phys = entity:GetPhysicsObject()
		phys:EnableMotion(false)
		phys:Sleep()

		if (IsValid(phys)) then
			phys:Wake()
		end

		entity:SetNetVar("name", data.name)
		entity:SetNetVar("desc", data.desc)
		entity:SetNetVar("show", data.showtext)

		PLUGIN:SaveData()

		client:Notify("Вы успешно изменили Entity Looting.")
	end
end)