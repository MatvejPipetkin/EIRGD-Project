ITEM.name = "Снаряжение"
ITEM.description = "Предмет снаряжения."
ITEM.category = "Снаряжение"
ITEM.model = "models/props_c17/BriefCase001a.mdl"
ITEM.width = 2
ITEM.height = 2
ITEM.invColor = Color(125, 165, 105) -- цвет подложки в сетке и в слоте; можно переопределить в предмете

-- слот и остальные параметры берутся из sh_config.lua (ix.equipment.config.items[uniqueID])
-- или из полей ITEM.equipSlot / equipBlocks / equipArmor / equipBodygroups / equipWear.
-- Надетый предмет удаляется из инвентаря и хранится в слоте; при снятии возвращается в инвентарь.

function ITEM:PopulateTooltip(tooltip)
	if (!ix.equipment) then
		return
	end

	local slot = ix.equipment.GetSlot(ix.equipment.GetItemSlot(self) or "")

	if (slot) then
		local row = tooltip.AddRowAfter and tooltip:AddRowAfter("description", "equipSlot") or tooltip:AddRow("equipSlot")
		row:SetText("Слот: " .. slot.name)
		row:SizeToContents()
	end
end

ITEM.functions.Equip = {
	name = "Надеть",
	icon = "icon16/tick.png",
	OnRun = function(item)
		local client = item.player
		local ok, reason = ix.equipment.Equip(client, item)

		if (!ok and reason) then
			client:Notify(reason)
		end

		-- предмет уже убран из инвентаря самим Equip
		return false
	end,
	OnCanRun = function(item)
		local client = item.player

		return !IsValid(item.entity) and IsValid(client)
			and ix.equipment.GetItemSlot(item) != nil
			and hook.Run("CanEquipmentEquip", client, item) != false
	end
}