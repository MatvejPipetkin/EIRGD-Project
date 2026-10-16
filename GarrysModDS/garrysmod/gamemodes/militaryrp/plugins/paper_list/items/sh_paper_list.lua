ITEM.name = "Блокнот"
ITEM.model = "models/props/unicupon.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.description = ""
ITEM.category = "Бумага"
ITEM.NoRemove = true
ITEM.price = 0

ITEM.functions.use = {
	name = "Прочесть",
	icon = "icon16/pencil.png",
	OnRun = function(item)
		local client = item.player
		local id = item:GetID()
		if (id) then
			netstream.Start(client, "receivePaper", id, item:GetData("PaperData") or "")
		end
		return false
	end
}


