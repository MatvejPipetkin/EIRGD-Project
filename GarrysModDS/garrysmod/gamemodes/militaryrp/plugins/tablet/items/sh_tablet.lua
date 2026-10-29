ITEM.name = "Служебный планшет"
ITEM.description = "Защищённый армейский планшет. Открывается клавишей M, доступ по личному логину и паролю."
ITEM.model = "models/props_lab/clipboard.mdl" -- замените на модель планшета, если есть
ITEM.width = 2
ITEM.height = 1
ITEM.category = "Снаряжение"
ITEM.bDropOnDeath = true

-- Планшет именной: при выдаче в данных предмета запоминаются владелец и серийный номер.
function ITEM:GetDescription()
	local owner = self:GetData("ownerName")
	local serial = self:GetData("serial")

	if (!owner) then
		return self.description .. "\n\nНе закреплён за владельцем: привяжется к тому, кто откроет его первым."
	end

	return self.description .. "\n\nИменной планшет."
		.. "\nЗакреплён за: " .. owner .. "."
		.. (serial and ("\nСерийный номер: " .. serial .. ".") or "")
end

-- Открыть конкретный планшет (нужно, если в инвентаре их несколько, например чужой).
ITEM.functions.Open = {
	name = "Открыть",
	icon = "icon16/application_view_tile.png",
	OnRun = function(item)
		if (SERVER and IsValid(item.player)) then
			ix.tablet.Open(item.player, item)
		end

		return false
	end
}