ITEM.name = "CID карта"
ITEM.model = Model("models/sky/cid.mdl")
ITEM.description = "Пластиковая карточка, что выполняет роль документа. На ней имеется символ Альянса, а так-же данные гражданина."
ITEM.category = "Технологии Альянса"
ITEM.NoRemove = true
ITEM.bDropOnDeath = false
function ITEM:GetDescription()
	return self.description
end

function ITEM:IsCWU()
	return self:GetData("cwu", false)
end

function ITEM:IsCombine()
	return self:GetData("cca", false)
end

--dynamiC MODELS BRUH
function ITEM:GetModel()
	if self:IsCWU() then
		return "models/sky/cwuid.mdl"
	elseif self:IsCombine() then
		return "models/dorado/tarjetazero.mdl"
	else
		return self.model
	end
end

function ITEM:PopulateTooltip(tooltip)
	if not self:IsCWU() and not self:IsCombine() then
		local data = tooltip:AddRow("data")
		data:SetBackgroundColor(derma.GetColor("Success", tooltip))
		data:SetText("ФИО: " .. self:GetData("citizen_name", "ERROR. Code-198") .. "\nНомер: " .. self:GetData("cid", "00000") .. "\nДата выпуска: " .. self:GetData("issue_date", "Unissued"))
		data:SetFont("BudgetLabel")
		data:SetExpensiveShadow(0.5)
		data:SizeToContents()
	end

	if self:IsCWU() then
		local data = tooltip:AddRow("data")
		data:SetBackgroundColor(derma.GetColor("Success", tooltip))
		data:SetText("ФИО: " .. self:GetData("citizen_name", "ERROR. Code-198 (B)") .. "\nНомер: " .. self:GetData("cid", "00000") .. "\nДата выпуска: " .. self:GetData("issue_date", "ERROR. Code-198 (B)") .. "\nНомер работника: " .. self:GetData("worker_id", "ERROR. Code-198 (B)"))
		data:SetFont("BudgetLabel")
		data:SetExpensiveShadow(0.5)
		data:SizeToContents()
	end

	if self:IsCombine() then
		local data = tooltip:AddRow("data")
		data:SetBackgroundColor(derma.GetColor("Success", tooltip))
		data:SetText("Unit Identifier: " .. string.match(self:GetData("citizen_name", "ERROR. Code-198 (C)"), "%d%d%d") .. "\nUnit Rank: " .. self:GetCPRank() .. "\nIssue Date: " .. self:GetData("issue_date", "ERROR. Code-198 (C)") .. "\nFull Identifier: " .. self:GetCPName() .. "\nService Number: " .. self:GetData("service_number", "ERROR. Code-198 (C)"))
		data:SetFont("BudgetLabel")
		data:SetExpensiveShadow(0.5)
		data:SizeToContents()
	end

	local warning = tooltip:AddRow("warning")
	warning:SetBackgroundColor(derma.GetColor("Error", tooltip))
	warning:SetText("Внимание! При потери карты вам будет выдан штраф за потерю или порчу имущества Альянса, так-же вам придется пройти в Участок ГО и пройти пере-регистрацию!")
	warning:SetFont("DermaDefault")
	warning:SetExpensiveShadow(0.5)
	warning:SizeToContents()

	if self:IsCombine() then
		local warning2 = tooltip:AddRow("warning2")
		warning2:SetBackgroundColor(derma.GetColor("Error", tooltip))
		warning2:SetText("Внимание! Потеря данной карты карается трибуналом, всегда держите ее при себе.")
		warning2:SetFont("DermaDefault")
		warning2:SetExpensiveShadow(0.5)
		warning2:SizeToContents()
	end
end

function ITEM:GetAssociatedCharacter()
	return self:GetData("associated_character", false)
end

--[[-------------------------------------------------------------------------
There will always be an associated character because these are -ONLY- given on spawn.
---------------------------------------------------------------------------]]
function ITEM:GetCPName()
	if ix.char.loaded[self:GetAssociatedCharacter()] then
		return ix.char.loaded[self:GetAssociatedCharacter()]:GetName()
	else
		return self:GetData("citizen_name", false)
	end
end

function ITEM:GetCPRank()
	local name = self:GetCPName()
	return string.match(name, "%p%a%a%p") or string.match(name, "%p%d%d%p")
end

function Schema:CharacterVarChanged(character, key, oldValue, value)
	local client = character:GetPlayer()
	if (key == "name") then
		local factionTable = ix.faction.Get(client:Team())

		if (factionTable.OnNameChanged) then
			factionTable:OnNameChanged(client, oldValue, value)
		end
	end
end

hook.Add("CharacterVarChanged", "ixCPIDUpdate", function(char, key, oldValue, value)
	if key == "name" then
		local inv = char:GetInventory():GetItems()
		for k, v in pairs(inv) do
			if v.uniqueID == "cid" then
				if v:GetAssociatedCharacter() and v:GetAssociatedCharacter() == char:GetID() then
					v:SetData("citizen_name", value)
					char:GetPlayer():Notify("You have had your rank updated and your ID card has been changed to appropriately affect it.")
				end
			end
		end
	end
end)

