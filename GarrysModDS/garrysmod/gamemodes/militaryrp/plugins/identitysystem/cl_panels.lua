
--[[-------------------------------------------------------------------------
			CID CREATOR
		---------------------------------------------------------------------------]]
local PANEL = {}

function PANEL:Init()
	ix.gui.cidcreator = self
	self:SetSize(ScrW() / 4, ScrH() / 7)
	self:Center()
	self:MakePopup()
	self:SetBackgroundBlur(true)
	self.toptext = self:Add("DLabel")
	self.toptext:SetContentAlignment(5)
	self.toptext:Dock(TOP)
	self.toptext:SetText("Терминал создания CID")
	self.toptext:SetExpensiveShadow(2)
	self.toptext:SetFont("ixSmallFont")
	self.toptext:SetTall(32)
	self.nametext = self:Add("DLabel")
	self.nametext:SetContentAlignment(5)
	self.nametext:Dock(TOP)
	self.nametext:SetText("Введите имя")
	self.nametext:SetExpensiveShadow(2)
	self.nametext:SetFont("ixSmallFont")
	self.nameinput = self:Add("DTextEntry")
	self.nameinput:Dock(TOP)
	self.itemswang = self:Add("DComboBox")
	self.itemswang:Dock(BOTTOM)
	self.itemswang:SetValue("Или вставьте билет в отсек.")

	self.itemswang.OnSelect = function()
		self.nameinput:SetDisabled(true)
		self.nameinput:SetText("")
	end

	self.submitbutton = self:Add("DButton")
	self.submitbutton:Dock(BOTTOM)
	self.submitbutton:SetText("Подтвердить")

	for k, v in pairs(LocalPlayer():GetCharacter():GetInventory():GetItems()) do
		if v.uniqueID == "transfer_papers" then
			self.itemswang:AddChoice(v:GetData("citizen_name", "ERROR. Code-198"))
		end
	end

	function self.submitbutton:DoClick()
		if string.len(ix.gui.cidcreator.nameinput:GetText()) == 0 and not ix.gui.cidcreator.itemswang:GetSelected() then
			return
		end

		if string.len(ix.gui.cidcreator.nameinput:GetText()) > 1 then
			netstream.Start("SubmitNewCID", {ix.gui.cidcreator.nameinput:GetText()})
			ix.gui.cidcreator:Close()
		elseif ix.gui.cidcreator.itemswang:GetSelected() ~= "Or select a transfer card." then
			netstream.Start("SubmitNewCID", {ix.gui.cidcreator.itemswang:GetSelected()})
			ix.gui.cidcreator:Close()
		else
			LocalPlayer():Notify("You need to input a name or select a transfer card!")
		end
	end
end

vgui.Register("ixCIDCreater", PANEL, "DFrame")
--[[ LOYALTY KIOSK ]]
local PANEL = {}

function PANEL:Init()
	ix.gui.loyalty = self
	self:SetSize(ScrW() / 2.8, ScrH() / 2)
	self:Center()
	self:MakePopup()
	self.infotext = self:Add("DLabel")
	self.infotext:Dock(TOP)
	self.infotext:SetContentAlignment(5)
	self.infotext:SetText("Click on an icon to receive it's item, or hover over it to get more information.")
	self.infotext:SetFont("ixSmallFont")
	self.infotext:SetExpensiveShadow(1)

	self.infotext.Paint = function(this, w, h)
		surface.SetDrawColor(0, 0, 0, 75)
		surface.DrawRect(0, 0, w, h)
	end

	--self:MakePopup()
	--self:SetTitle("Crafting")
	self.LoyaltyList = self:Add("DPanelList")
	self.LoyaltyList:Dock(FILL)
	self.LoyaltyList:SetSpacing(2)
	self.LoyaltyList:SetPadding(5)
	local w, h = self:GetSize()
	self.LoyaltyList:DockMargin(0, 0, 0, 0)
	self.LoyaltyList:EnableHorizontal(true)
	self.LoyaltyList:EnableVerticalScrollbar(true)

	--[[for i = 1, 50 do
		self:AddItem("Test Item Man", "models/humans/group02/male_02.mdl", "Description", {
			["cid"] = 3,
			["chinese_takeout"] = 1
		}, {
			["cid"] = 1
		})
	end--]]
	for k, v in pairs(STORED_LOYALTY) do
		--printTable(v)
		if v.data.factions then
			for k2, v2 in pairs(v.data.factions) do
				if LocalPlayer():Team() == v2 then
					self:AddItem(v["name"], v["model"], v["desc"], v["results"], v["id"], v["cooldown"], v["data"])
				end
			end
		end

		if not v.data.factions then
			self:AddItem(v["name"], v["model"], v["desc"], v["results"], v["id"], v["cooldown"], v["data"])
		end
	end

	self.CIDList = self:Add("DComboBox")
	self.CIDList:Dock(BOTTOM)
	self.CIDList:SetText("Select the CID you want to use for this transaction.")

	for k, v in pairs(LocalPlayer():GetCharacter():GetInventory():GetItems()) do
		if v.uniqueID == "cid" then
			if v:GetData("citizen_name") and v:GetData("cid") then
				local str = v:GetData("citizen_name") .. " #" .. v:GetData("cid")
				self.CIDList:AddChoice(str, v)
			end
		end
	end

	ix.gui.cidlist = self.CIDList

	function self.CIDList:OnSelect(index, value, data)
		print("test")
		print(self:GetSelected())
		print(data)
		ix.gui.loyalty.cid = data:GetID()
	end
end

function PANEL:AddItem(name, icon, desc, results, id, cooldown, data)
	--[[-------------------------------------------------------------------------
	Structure:
	1: Item Name
	2: Icon
	3: Description
	4: Requirements
	5: Results
	---------------------------------------------------------------------------]]
	--	print(self.LoyaltyList)

	self.test = self.LoyaltyList:Add("ixLoyaltyItem")
	self.test:SetItem(name, icon, desc, results, id, cooldown)
	self.LoyaltyList:AddItem(self.test)

	if data.disables then
		for k, v in pairs(data.disables) do
			local icon = ix.gui.gui_icons[v]
			if icon then
				icon:Remove()
			end
		end
	end

	--self.test:Dock(FILL)
	--self.test2 = self:Add("DPanel")
	--self.test2:Dock(FILL)
end

vgui.Register("ixLoyalty", PANEL, "DFrame")
local PANEL = {}

function PANEL:Init()
	self:SetSize(128, 128)
	self.Icon = self:Add("SpawnIcon")
	self.Icon:SetModel("models/player.mdl")
	self.Icon:SetSize(72, 72)
	self.Icon:Center()

	function self.Icon:DoClick()
		local parent = self:GetParent()
		--parent:SetItem("Test Name", "models/humans/group01/male_01.mdl", "Test Description", {"Test Requirements"})
		local cid = ix.gui.loyalty.cid
		local ent = ix.gui.loyalty.ent
		netstream.Start("ixLoyaltyMachine", {parent.results, parent.id, parent.cooldown, ent, cid})
	end

	self.name = self:Add("DLabel")
	self.name:Dock(BOTTOM)
	self.name:SetText("Piece of Cloth")
	self.name:SetContentAlignment(5)
	self.name:SetTextColor(color_white)
	self.name:SetFont("ixSmallFont")
	self.name:SetExpensiveShadow(1, Color(0, 0, 0, 200))

	self.name.Paint = function(this, w, h)
		surface.SetDrawColor(0, 0, 0, 75)
		surface.DrawRect(0, 0, w, h)
	end
end
ix.gui.gui_icons = {}
function PANEL:SetItem(name, icon, desc, results, id, cooldown)
	ix.gui.gui_icons[id] = self
	self.name:SetText(name)
	self.Icon:SetModel(icon)
	self.description = desc
	self.requirements = req
	self.results = results
	self.skill = skill
	self.id = id

	if cooldown then
		self.cooldown = cooldown
	end

	self.Icon:SetHelixTooltip(function(tooltip)
		local title = tooltip:AddRow("title")
		title:SetImportant()
		title:SetText(self.name:GetText())
		title:SetBackgroundColor(ix.config.Get("color"))
		title:SizeToContents()
		local description = tooltip:AddRow("description")
		description:SetText(self.description)
		description:SizeToContents()
	end)
end

vgui.Register("ixLoyaltyItem", PANEL, "DPanel")
--end
--vgui.Create("ixLoyalty")