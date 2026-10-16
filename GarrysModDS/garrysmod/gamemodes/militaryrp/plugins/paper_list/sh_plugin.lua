local PLUGIN = PLUGIN
PLUGIN.name = "Лист бумаги"
PLUGIN.author = "Subleader"
PLUGIN.desc = "Возможность создавать записки."
PAPERLIMIT = 3000

if CLIENT then
	netstream.Hook("receivePaper", function(id, contents)
		local paper = vgui.Create("paperRead")
		paper:setText(contents, id)
	end)
else
	netstream.Hook("paperSendText", function(client, id, contents)
		if (string.len(contents) <= PAPERLIMIT) then
			local char = client:GetCharacter()
			local inv = char:GetInventory()
			local items = inv:GetItems()
			for k, v in pairs(items) do
				if (v:GetID() == id) then
					client:Notify("Вы написали что-то")
					v:SetData("PaperData", contents)
				end
			end
			for k, v in pairs(ents.GetAll()) do
				if v:GetClass() == "ix_item" then
					local itemID = v.ixItemID
					local item = ix.item.instances[itemID]
					if (itemID == id) then
						client:Notify("Вы написали что-то")
						item:SetData("PaperData", contents)
					end
				end
			end
		end
	end)
end