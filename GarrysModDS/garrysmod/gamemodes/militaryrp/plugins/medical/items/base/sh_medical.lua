ITEM.name = "Медикамент"
ITEM.description = "Медицинский предмет."
ITEM.category = "Медицина"
ITEM.model = "models/healthvial.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.invColor = Color(105, 175, 200) -- цвет подложки в сетке инвентаря

-- id медикамента из ix.medical.config.meds (sh_config.lua); задаётся в файле предмета
ITEM.medical = nil

function ITEM:GetMed()
	return self.medical and ix.medical.config.meds[self.medical]
end

function ITEM:PopulateTooltip(tooltip)
	local med = self:GetMed()

	if (med and (med.uses or 1) > 1) then
		local row = tooltip.AddRowAfter and tooltip:AddRowAfter("description", "medUses") or tooltip:AddRow("medUses")
		row:SetText("Использований: " .. self:GetData("uses", med.uses))
		row:SizeToContents()
	end

	if (med and med.target == "limb") then
		local row = tooltip.AddRowAfter and tooltip:AddRowAfter("description", "medHint") or tooltip:AddRow("medHint")
		row:SetText("Перетащите на часть тела в инвентаре")
		row:SizeToContents()
	end

	if (med and med.dirty) then
		local row = tooltip.AddRowAfter and tooltip:AddRowAfter("description", "medDirty") or tooltip:AddRow("medDirty")
		row:SetText("Нестерильно: эффект слабее, возможны осложнения")
		row:SizeToContents()
	end
end

-- медикамент на часть тела: ПКМ → «Применить на…» или перетаскивание на силуэт в инвентаре
ITEM.functions.Apply = {
	name = "Применить на...",
	icon = "icon16/heart_add.png",
	isMulti = true,
	multiOptions = function(item, client)
		local med = item:GetMed()
		local options = {}

		if (med and med.target == "limb") then
			for _, limb in ipairs(ix.medical.config.limbs) do
				if (!med.groups or table.HasValue(med.groups, limb.group)) then
					options[#options + 1] = {name = limb.name, data = {limb = limb.id}}
				end
			end
		end

		return options
	end,
	OnCanRun = function(item, data)
		local med = item:GetMed()

		return IsValid(item.player) and med != nil and med.target == "limb" and !IsValid(item.entity)
	end,
	OnRun = function(item, data)
		ix.medical.Use(item.player, item, istable(data) and data.limb or nil)

		-- предмет расходуется после применения внутри ix.medical.Use
		return false
	end
}

-- медикамент «внутрь»: действует на весь организм
ITEM.functions.Consume = {
	name = "Принять",
	icon = "icon16/pill.png",
	OnCanRun = function(item)
		local med = item:GetMed()

		return IsValid(item.player) and med != nil and med.target == "self" and !IsValid(item.entity)
	end,
	OnRun = function(item)
		ix.medical.Use(item.player, item)

		return false
	end
}
