PLUGIN.name = "Item List"
PLUGIN.author = "Schwarz Kruppzo"
PLUGIN.description = "Adds a Q-menu tab for all items."

CAMI.RegisterPrivilege({
	Name = "Helix - Item SpawnMenu",
	MinAccess = "superadmin"
})

cleanup.Register("ixItems")

ix.util.Include("sv_plugin.lua")

if (CLIENT) then
	local PLUGIN = PLUGIN

	local icons = {
		["Остальное"] = "application_view_tile",
		["Руды"] = "map",
		["Поставочное"] = "package",
		["Ремкомплекты"] = "database",
		["Мусор"] = "bin_empty",
		["Музыкальные касеты"] = "dvd",
		["Медикоменты"] = "heart",
		["Компоненты"] = "plugin",
		["Навыки"] = "pill",
		["Инструменты"] = "wrench_orange",
		["Ингредиент"] = "basket",
		["Рем наборы"] = "timeline_marker",
		["Бумага"] = "money",
		["Навыки"] = "book_addresses",
		["[TFA] Оружие"] = "gun",
		["[TFA] Обвесы"] = "gun",
		["[LCD] Оружие"] = "gun",
		["Боеприпасы"] = "bricks",
		["[FOOD] Еда"] = "cup",
		["Рюкзаки"] = "box",
		["Книги"] = "book_open",
		["Верстаки"] = "drive",
		["Медикаменты"] = "pill",
		["Развлечение"] = "dvd",
		["Музыкальные кассеты"] = "music",
		["[Униформа] Гражданская"] = "tag_green",
		["[Униформа] Гражданская оборона"] = "tag_blue",
		["[Униформа] Партия союз"] = "tag_pink",
		["[Униформа] Гражданский союз рабочих"] = "tag_yellow",
		["[Униформа] Сопротивления"] = "tag_orange",
		["[Униформа] Сверхчеловеческого отдела"] = "tag_red",
		["[Униформа] Повязки"] = "tag_purple",
		["[Униформа] Shori"] = "tag_red",
		["[Униформа] HECU"] = "tag_green",
		["[Униформа] HEAVEN"] = "tag_purple",
		["[Униформа] Легион смерти"] = "tag_purple",
		["[Униформа] Приверженцы"] = "tag_orange",
		["[Униформа] Теневого рая"] = "tag_pink",
		["[Униформа] Командос"] = "tag_red",
		["[Униформа] Личных персонажей"] = "tag",
	}

	spawnmenu.AddContentType("ixItem", function(container, item)
		if (!item.name) then return end

		local slot = vgui.Create("Panel", container)
		slot:SetSize(100, 100)
		slot.Paint = function(t, w, h)
			local hovered

			if (t:IsHovered() or t.icon and t.icon:IsHovered()) then
				hovered = ix.config.Get("color")
			end

			derma.SkinFunc("PaintButton2", t, w, h, hovered)
		end

		local icon = slot:Add('SpawnIcon')
		slot.icon = icon

		icon:SetSize(92, 92 * 1.4)
		icon:SetZPos(1)
		icon:Dock(FILL)
		icon:DockMargin(5, 5, 5, 10)
		icon:InvalidateLayout(true)
		icon:SetModel(item:GetModel(), item:GetSkin())

		icon:SetHelixTooltip(function(tooltip)
			ix.hud.PopulateItemTooltip(tooltip, item)
		end)

		icon.OnMousePressed = function(this, code)
			if !(CAMI.PlayerHasAccess(LocalPlayer(), "Helix - Item SpawnMenu", nil)) then return end

			if (code == MOUSE_LEFT) then
				net.Start("MenuItemSpawn")
					net.WriteString(item.uniqueID)
				net.SendToServer()

				surface.PlaySound("ui/buttonclickrelease.wav")
			elseif (code == MOUSE_RIGHT) then
				local menu = DermaMenu()

				local give_self = menu:AddSubMenu("Дать себе")

				if (item.isStackable) then
					give_self:AddOption("Stack x" .. (item.maxQuantity or 16), function()
						net.Start("MenuItemGive")
							net.WriteString(item.uniqueID)
							net.WriteBool(true)
						net.SendToServer()
					end)
				end

				give_self:AddOption("One", function()
					net.Start("MenuItemGive")
						net.WriteString(item.uniqueID)
						net.WriteBool(false)
					net.SendToServer()
				end)

				menu:AddSpacer()

				local copy = menu:AddSubMenu("Копировать в буфер обмена")
				copy:AddOption("Model", function() SetClipboardText(item.model) end)
				copy:AddOption("ItemID", function() SetClipboardText(item.uniqueID) end)

				menu:Open()			
			end
		end

		icon.Paint = function(t, w, h) end
		icon.PaintOver = function(t, w, h) end

		if (IsValid(container)) then
			container:Add(slot)
		end

		return slot
	end)

	spawnmenu.AddCreationTab("Предметы", function()
		local base = vgui.Create("SpawnmenuContentPanel")
		local tree = base.ContentNavBar.Tree
		local categories = {}

		vgui.Create("ItemSearchBar", base.ContentNavBar)

		for _, v in SortedPairsByMemberValue(ix.item.list, "category") do
			if (!categories[v.category]) then
				categories[v.category] = true

				local node = tree:AddNode(L(v.category), icons[v.category] and ("icon16/" .. icons[v.category] .. ".png") or "icon16/brick.png")

				node.DoPopulate = function(self)
					if (self.Container) then return end

					self.Container = vgui.Create("ContentContainer", base)
					self.Container:SetVisible(false)
					self.Container:SetTriggerSpawnlistChange(false)

					for _, itemTable in SortedPairsByMemberValue(ix.item.list, "name") do
						if (itemTable.category == v.category) then
							spawnmenu.CreateContentIcon("ixItem", self.Container, itemTable)
						end
					end
				end

				node.DoClick = function(self)
					self:DoPopulate()
					base:SwitchPanel(self.Container)
				end
			end
		end

		local FirstNode = tree:Root():GetChildNode(0)

		if (IsValid(FirstNode)) then
			FirstNode:InternalDoClick()
		end

		PLUGIN:PopulateContent(base, tree, nil)

		return base
	end, "icon16/script_key.png")

	timer.Simple(0, function()
		RunConsoleCommand("spawnmenu_reload")
	end)
end