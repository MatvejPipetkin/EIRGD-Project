ITEM.name = "Миграционный билет"
ITEM.model = Model("models/illusion/eftcontainers/intel.mdl")
ITEM.description = "Папка с документами о переводе."
ITEM.category = "Технологии Альянса"
ITEM.NoRemove = true
function ITEM:GetDescription()
	return self.description
end
function ITEM:PopulateTooltip(tooltip)
	local data = tooltip:AddRow("data")
	data:SetBackgroundColor(derma.GetColor("Success", tooltip))
	data:SetText("ФИО: " .. self:GetData("citizen_name", "Unissued") .. "\nНомер: " .. self:GetData("unique", "00000") .. "\nДата выпуска: " .. self:GetData("issue_date", "Unissued"))
	data:SetFont("BudgetLabel")
	data:SetExpensiveShadow(0.5 )
	data:SizeToContents()

	local data2 = tooltip:AddRow("data2")
	data2:SetBackgroundColor(derma.GetColor("Warning", tooltip))
	data2:SetText("Данный документ нужно сдать сотруднику ГО в Отделении ГО, дабы получить CID. В случае потери, вы будете вынуждены выплатить штраф!")
	data2:SetFont("DermaDefault")
	data2:SetExpensiveShadow(0.5)
	data2:SizeToContents()



end