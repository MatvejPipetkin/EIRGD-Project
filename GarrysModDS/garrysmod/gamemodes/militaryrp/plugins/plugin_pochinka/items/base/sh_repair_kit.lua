ITEM.name = "Repair Kit Base"
ITEM.category = "RepairKit"
ITEM.description = "Repair kit."
ITEM.model = "models/props_lab/box01a.mdl"
ITEM.useSound = "interface/inv_repair_kit.ogg"
ITEM.width = 1
ITEM.height = 1

-- Сколько ПРОЦЕНТОВ от максимальной прочности предмета комплект восстанавливает за одно использование.
-- (Проценты, а не единицы: у брони и оружия максимум прочности разный.)
ITEM.repairPercent = 25

-- Сколько использований в комплекте. Когда кончатся — комплект исчезает.
-- Назван "uses", а НЕ "quantity": поле quantity стандартное для Helix, и именно оно
-- вызывало дублирование цифр на иконке (рисовали и мы, и сам Helix).
ITEM.uses = 1

-- Для чего подходит ремкомплект (включите ОДИН из флагов):
ITEM.isWeaponKit = true -- Только для оружия.
ITEM.isArmorKit = false -- Только для брони (предметы плагина armorweight).

-- Остаток использований. Старые предметы хранили счётчик в data "quantity" — читаем и его.
function ITEM:GetUses()
	return self:GetData("uses", self:GetData("quantity", self.uses or 1))
end

if SERVER then
	function ITEM:UseRepair(item, ply)
		local max_dur = ix.durability.GetMax(item) or 0
		local amount = max_dur * ((self.repairPercent or 0) / 100)
		local new_dur = item:GetData("durability", max_dur) + amount

		item:SetData("durability", math.Clamp(new_dur, 0, max_dur))

		-- Броня влияет на защиту и скорость: пересчитываем после ремонта.
		if (ix.armorgear and ix.armorgear.HasStats(item)) then
			hook.Run("ArmorGearChanged", ply)
		end
	end
else
	-- Единственное место, где рисуется счётчик использований.
	function ITEM:PaintOver(item, w, h)
		local uses = item:GetUses()

		if (uses > 0) then
			draw.SimpleTextOutlined(uses, "DermaDefault", w - 5, h - 5, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, color_black)
		end
	end

	function ITEM:GetDescription()
		return Format("%s\n\n%s", self.description, L("RepairKitInfo", self.repairPercent or 0, self:GetUses()))
	end
end

function ITEM:OnInstanced(invID, x, y, item)
	item:SetData("uses", item.uses or 1)
end
