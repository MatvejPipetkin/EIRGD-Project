
ITEM.name = "Фонарик"
ITEM.model = Model("models/willardnetworks/skills/flashlight.mdl")
ITEM.width = 1
ITEM.height = 1
ITEM.description = "Обычный фонарик. Достаточно хорошо светит"
ITEM.category = "Инструменты"
ITEM.bDropOnDeath = true
ITEM:Hook("drop", function(item)
	item.player:Flashlight(false)
end)
