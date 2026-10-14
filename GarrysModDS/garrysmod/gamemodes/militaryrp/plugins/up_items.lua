local PLUGIN = PLUGIN

PLUGIN.name = "pick up plugin"
PLUGIN.author = "Kayl"
PLUGIN.description = "Анимки при поднятии предметов/ /me на поднятие предмета"

ix.option.Add("up_items", ix.type.bool, true, {
	category = "up_items"
})


ix.chat.Register("me_chat", {
	format = "**%s %s",
	GetColor = function(speaker, text)
		return Color(255, 213, 0)
	end,
	CanHear = ix.config.Get("chatRange", 280),
	deadCanChat = true
})

function PLUGIN:CanPlayerTakeItem(client, item, itemID)
	client:ForceSequence ("pickup")
	client:EmitSound("items/itempickup.wav", 95, 150, 0.25)
	end

function PLUGIN:CanPlayerDropItem(client, item)	
	client:ForceSequence ("crouch_to_stand")
	end