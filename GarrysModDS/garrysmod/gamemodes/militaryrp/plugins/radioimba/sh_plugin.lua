local PLUGIN=PLUGIN
PLUGIN.name = "Radio"
PLUGIN.author = "Black Tea"
PLUGIN.desc = "You can communicate with other people in distance."
local RADIO_CHATCOLOR = Color(30, 200, 20)
local RADIO_YELLCOLOR = Color(50, 230, 40)
local RADIO_WHISCOLOR = Color(20, 140, 20)
local RADIO_OOCCOLOR  = Color(225, 30, 30)

-- This is how initialize Language in Single File.
local langkey = "russian"
do
	local langTable = {
		radioFreq = "\nЧастота",
		radioSubmit = "Подтвердить",
		radioNoRadio = "У вас нет рации.",
		radioNoRadioComm = "У вас нет рации",
		radioFormat = "%s передает по рации: \"%s\"",
	}

	table.Merge(ix.lang.stored[langkey], langTable)
end

if (CLIENT) then
	local PANEL = {}
	function PANEL:Init()
		self.number = 0
		self:SetWide(70)

		local up = self:Add("DButton")
		up:SetFont("Marlett")
		up:SetText("t")
		up:Dock(TOP)
		up:DockMargin(2, 2, 2, 2)
		up.DoClick = function(this)
			self.number = (self.number + 1)% 10
			surface.PlaySound("buttons/lightswitch2.wav")
		end

		local down = self:Add("DButton")
		down:SetFont("Marlett")
		down:SetText("u")
		down:Dock(BOTTOM)
		down:DockMargin(2, 2, 2, 2)
		down.DoClick = function(this)
			self.number = (self.number - 1)% 10
			surface.PlaySound("buttons/lightswitch2.wav")
		end

		local number = self:Add("Panel")
		number:Dock(FILL)
		number.Paint = function(this, w, h)
			draw.SimpleText(self.number, "ixDialFont", w/2, h/2, color_white, 1, 1)
		end
	end

	vgui.Register("ixRadioDial", PANEL, "DPanel")

	PANEL = {}

	function PANEL:Init()
		self:SetTitle(L("radioFreq"))
		self:SetSize(330, 220)
		self:Center()
		self:MakePopup()

		self.submit = self:Add("DButton")
		self.submit:Dock(BOTTOM)
		self.submit:DockMargin(0, 5, 0, 0)
		self.submit:SetTall(25)
		self.submit:SetText(L("radioSubmit"))
		self.submit.DoClick = function()
			local str = ""
			for i = 1, 5 do
				if (i != 4) then
					str = str .. tostring(self.dial[i].number or 0)
				else
					str = str .. "."
				end
			end
			netstream.Start("radioAdjust", str, self.itemID)

			self:Close()
		end

		self.dial = {}
		for i = 1, 5 do
			if (i != 4) then
				self.dial[i] = self:Add("ixRadioDial")
				self.dial[i]:Dock(LEFT)
				if (i != 3) then
					self.dial[i]:DockMargin(0, 0, 5, 0)
				end
			else
				local dot = self:Add("Panel")
				dot:Dock(LEFT)
				dot:SetWide(30)
				dot.Paint = function(this, w, h)
					draw.SimpleText(".", "ixDialFont", w/2, h - 10, color_white, 1, 4)
				end
			end
		end
	end

	function PANEL:Think()
		self:MoveToFront()
	end

	vgui.Register("ixRadioMenu", PANEL, "DFrame")

	surface.CreateFont("ixDialFont", {
		font = "Agency FB",
		extended = true,
		size = 100,
		weight = 1000
	})

	netstream.Hook("radioAdjust", function(freq, id)
		local adjust = vgui.Create("ixRadioMenu")

		if (id) then
			adjust.itemID = id
		end

		if (freq) then
			for i = 1, 5 do
				if (i != 4) then
					adjust.dial[i].number = tonumber(freq[i])
				end
			end
		end
	end)
else
	netstream.Hook("radioAdjust", function(client, freq, id)
		local inv = (client:GetChar() and client:GetChar():GetInv() or nil)

		if (inv) then
			local item

			if (id) then
				item = ix.item.instances[id]
			else
				item = inv:hasItem("radio")
			end

			local ent = item:GetEntity()

			if (item and (IsValid(ent) or item:GetOwner() == client)) then
				(ent or client):EmitSound("buttons/combine_button1.wav", 50, 170)

				item:SetData("freq", freq)
			else
				client:notify(L("radioNoRadio"))
			end
		end
	end)

	/* Do we need it?
	ix.command.add("freq", {
		syntax = "<string name> [string flags]",
		onRun = function(client, arguments)
			local inv = client:GetChar():GetInv()

			if (inv) then
				local detect = {
					"radio",
					"sradio",
					"pager"
				}

				for k, v in ipairs(detect) do
					item = inv:HasItem(v)
				end

				if (item) then


					item:SetData("freq", arguments[1], nil, nil, true)
				else
					client:notify("У вас нет рации.")
				end
			end
		end
	})
*/
end

-- Yelling out loud.
local find = {
	["radio"] = false,
	["sradio"] = true
}
local function endChatter(listener)
	timer.Simple(1, function()
		if (!listener:IsValid() or !listener:Alive()) then
			return false
		end

		listener:EmitSound("npc/metropolice/vo/off"..math.random(3)..".wav", math.random(60, 70), math.random(80, 120))
	end)
end

ix.chat.Register("radio", {
	format = "%s передает по рации: \"%s\"",
	GetColor = function(speaker, text)
		return RADIO_CHATCOLOR
	end,
	CanHear = function(self, speaker, listener)
		local dist = speaker:GetPos():Distance(listener:GetPos())
		local speakRange = ix.config.Get("chatRange", 280)
		local listenerEnts = ents.FindInSphere(listener:GetPos(), speakRange)
		local listenerInv = listener:GetChar():GetInv()
		local freq

		if (!CURFREQ or CURFREQ == "") then
			return false
		end

		if (dist <= speakRange) then
			return true
		end

		if (listenerInv) then
			for k, v in pairs(listenerInv:GetItems()) do
				if (freq) then
					break
				end

				for id, far in pairs(find) do
					if (v.uniqueID == id and v:GetData("power", false) == true) then
						if (CURFREQ == v:GetData("freq", "000.0")) then
							endChatter(listener)
							
							return true
						end

						break
					end
				end
			end
		end

		if (!freq) then
			for k, v in ipairs(listenerEnts) do
				if (freq) then
					break
				end

				if (v:GetClass() == "ix_item") then
					local itemTable = v:GetItemTable()

					for id, far in pairs(find) do
						if (far and itemTable.uniqueID == id and v:GetData("power", false) == true) then
							if (CURFREQ == v:GetData("freq", "000.0")) then
								endChatter(listener)

								return true
							end
						end
					end
				end
			end
		end

		return false
	end,
	CanSay = function(self, speaker, text)
		local schar = speaker:GetChar()
		local speakRange = ix.config.Get("chatRange", 280)
		local speakEnts = ents.FindInSphere(speaker:GetPos(), speakRange)
		local speakerInv = schar:GetInv()
		local freq

		if (speakerInv) then
			for k, v in pairs(speakerInv:GetItems()) do
				if (freq) then
					break
				end

				for id, far in pairs(find) do
					if (v.uniqueID == id and v:GetData("power", false) == true) then
						freq = v:GetData("freq", "000.0")

						break
					end
				end
			end
		end

		if (!freq) then
			for k, v in ipairs(speakEnts) do
				if (freq) then
					break
				end

				if (v:GetClass() == "ix_item") then
					local itemTable = v:GetItemTable()

					for id, far in pairs(find) do
						if (far and itemTable.uniqueID == id and v:GetData("power", false) == true) then
							freq = v:GetData("freq", "000.0")

							break
						end
					end
				end
			end
		end

		if (freq) then
			CURFREQ = freq
			speaker:EmitSound("npc/metropolice/vo/on"..math.random(2)..".wav", math.random(50, 60), math.random(80, 120))
		else
			speaker:notify(L"radioNoRadioComm")
			return false
		end
	end,
	prefix = {"/r", "/radio"},
})

ix.chat.Register("radioyell", {
	format = "%s кричит в рацию: \"%s\"",
	GetColor = function(speaker, text)
		return RADIO_YELLCOLOR
	end,
	CanHear = function(self, speaker, listener)
		local dist = speaker:GetPos():Distance(listener:GetPos())
		local speakRange = ix.config.Get("chatRange", 280) * 2
		local listenerEnts = ents.FindInSphere(listener:GetPos(), speakRange)
		local listenerInv = listener:GetChar():GetInv()
		local freq

		if (!CURFREQ or CURFREQ == "") then
			return false
		end

		if (dist <= speakRange) then
			return true
		end

		if (listenerInv) then
			for k, v in pairs(listenerInv:GetItems()) do
				if (freq) then
					break
				end

				for id, far in pairs(find) do
					if (v.uniqueID == id and v:GetData("power", false) == true) then
						if (CURFREQ == v:GetData("freq", "000.0")) then
							endChatter(listener)
							
							return true
						end

						break
					end
				end
			end
		end

		if (!freq) then
			for k, v in ipairs(listenerEnts) do
				if (freq) then
					break
				end

				if (v:GetClass() == "ix_item") then
					local itemTable = v:GetItemTable()

					for id, far in pairs(find) do
						if (far and itemTable.uniqueID == id and v:GetData("power", false) == true) then
							if (CURFREQ == v:GetData("freq", "000.0")) then
								endChatter(listener)

								return true
							end
						end
					end
				end
			end
		end

		return false
	end,
	CanSay = function(self, speaker, text)
		local schar = speaker:GetChar()
		local speakRange = ix.config.Get("chatRange", 280) * 2
		local speakEnts = ents.FindInSphere(speaker:GetPos(), speakRange)
		local speakerInv = schar:GetInv()
		local freq

		if (speakerInv) then
			for k, v in pairs(speakerInv:GetItems()) do
				if (freq) then
					break
				end

				for id, far in pairs(find) do
					if (v.uniqueID == id and v:GetData("power", false) == true) then
						freq = v:GetData("freq", "000.0")

						break
					end
				end
			end
		end

		if (!freq) then
			for k, v in ipairs(speakEnts) do
				if (freq) then
					break
				end

				if (v:GetClass() == "ix_item") then
					local itemTable = v:GetItemTable()

					for id, far in pairs(find) do
						if (far and itemTable.uniqueID == id and v:GetData("power", false) == true) then
							freq = v:GetData("freq", "000.0")

							break
						end
					end
				end
			end
		end

		if (freq) then
			CURFREQ = freq
			speaker:EmitSound("npc/metropolice/vo/on"..math.random(2)..".wav", math.random(50, 60), math.random(80, 120))
		else
			speaker:notify(L"radioNoRadioComm")
			return false
		end
	end,
	prefix = {"/ry", "/radioyell"},
})

ix.chat.Register("radiowhisper", {
	format = "%s шепчет в рацию: \"%s\"",
    GetColor = function(speaker, text)
		return RADIO_WHISCOLOR
	end,
	CanHear = function(self, speaker, listener)
		local dist = speaker:GetPos():Distance(listener:GetPos())
		local speakRange = ix.config.Get("chatRange", 280) * 0.25
		local listenerEnts = ents.FindInSphere(listener:GetPos(), speakRange)
		local listenerInv = listener:GetChar():GetInv()
		local freq

		if (!CURFREQ or CURFREQ == "") then
			return false
		end

		if (dist <= speakRange) then
			return true
		end

		if (listenerInv) then
			for k, v in pairs(listenerInv:GetItems()) do
				if (freq) then
					break
				end

				for id, far in pairs(find) do
					if (v.uniqueID == id and v:GetData("power", false) == true) then
						if (CURFREQ == v:GetData("freq", "000.0")) then
							endChatter(listener)
							
							return true
						end

						break
					end
				end
			end
		end

		if (!freq) then
			for k, v in ipairs(listenerEnts) do
				if (freq) then
					break
				end

				if (v:GetClass() == "ix_item") then
					local itemTable = v:GetItemTable()

					for id, far in pairs(find) do
						if (far and itemTable.uniqueID == id and v:GetData("power", false) == true) then
							if (CURFREQ == v:GetData("freq", "000.0")) then
								endChatter(listener)

								return true
							end
						end
					end
				end
			end
		end

		return false
	end,
	CanSay = function(self, speaker, text)
		local schar = speaker:GetChar()
		local speakRange = ix.config.Get("chatRange", 280) * 0.25
		local speakEnts = ents.FindInSphere(speaker:GetPos(), speakRange)
		local speakerInv = schar:GetInv()
		local freq

		if (speakerInv) then
			for k, v in pairs(speakerInv:GetItems()) do
				if (freq) then
					break
				end

				for id, far in pairs(find) do
					if (v.uniqueID == id and v:GetData("power", false) == true) then
						freq = v:GetData("freq", "000.0")

						break
					end
				end
			end
		end

		if (!freq) then
			for k, v in ipairs(speakEnts) do
				if (freq) then
					break
				end

				if (v:GetClass() == "ix_item") then
					local itemTable = v:GetItemTable()

					for id, far in pairs(find) do
						if (far and itemTable.uniqueID == id and v:GetData("power", false) == true) then
							freq = v:GetData("freq", "000.0")

							break
						end
					end
				end
			end
		end

		if (freq) then
			CURFREQ = freq
			speaker:EmitSound("npc/metropolice/vo/on"..math.random(2)..".wav", math.random(50, 60), math.random(80, 120))
		else
			speaker:notify(L"radioNoRadioComm")
			return false
		end
	end,
	prefix = {"/rw", "/radiowhisper"},
})

ix.chat.Register("radioooc", {
	format = "%s передает по рации (НонРП): \"%s\"",
	GetColor = function(self, speaker, text)
		return RADIO_WHISCOLOR
	end,
	CanHear = function(self, speaker, listener)
		local dist = speaker:GetPos():Distance(listener:GetPos())
		local speakRange = ix.config.Get("chatRange", 280) * 0.25
		local listenerEnts = ents.FindInSphere(listener:GetPos(), speakRange)
		local listenerInv = listener:GetChar():GetInv()
		local freq

		if (!CURFREQ or CURFREQ == "") then
			return false
		end

		if (dist <= speakRange) then
			return true
		end

		if (listenerInv) then
			for k, v in pairs(listenerInv:GetItems()) do
				if (freq) then
					break
				end

				for id, far in pairs(find) do
					if (v.uniqueID == id and v:GetData("power", false) == true) then
						if (CURFREQ == v:GetData("freq", "000.0")) then
							endChatter(listener)
							
							return true
						end

						break
					end
				end
			end
		end

		if (!freq) then
			for k, v in ipairs(listenerEnts) do
				if (freq) then
					break
				end

				if (v:GetClass() == "ix_item") then
					local itemTable = v:GetItemTable()

					for id, far in pairs(find) do
						if (far and itemTable.uniqueID == id and v:GetData("power", false) == true) then
							if (CURFREQ == v:GetData("freq", "000.0")) then
								endChatter(listener)

								return true
							end
						end
					end
				end
			end
		end

		return false
	end,
	CanSay = function(self, speaker, text)
		local schar = speaker:GetChar()
		local speakRange = ix.config.Get("chatRange", 280)
		local speakEnts = ents.FindInSphere(speaker:GetPos(), speakRange)
		local speakerInv = schar:GetInv()
		local freq

		if (speakerInv) then
			for k, v in pairs(speakerInv:GetItems()) do
				if (freq) then
					break
				end

				for id, far in pairs(find) do
					if (v.uniqueID == id and v:GetData("power", false) == true) then
						freq = v:GetData("freq", "000.0")

						break
					end
				end
			end
		end

		if (!freq) then
			for k, v in ipairs(speakEnts) do
				if (freq) then
					break
				end

				if (v:GetClass() == "ix_item") then
					local itemTable = v:GetItemTable()

					for id, far in pairs(find) do
						if (far and itemTable.uniqueID == id and v:GetData("power", false) == true) then
							freq = v:GetData("freq", "000.0")

							break
						end
					end
				end
			end
		end

		if (freq) then
			CURFREQ = freq
			speaker:EmitSound("npc/metropolice/vo/on"..math.random(2)..".wav", math.random(50, 60), math.random(80, 120))
		else
			speaker:notify(L"radioNoRadioComm")
			return false
		end
	end,
	prefix = {"/rooc", "/radioooc", "/ro"},
})

local RADIO_OOCCOLOR  = Color(225, 30, 30)



if CLIENT then 
	local red = Color(235,175,75)
	function PLUGIN:HUDPaint()
		local p = LocalPlayer()
		if !p:Alive() then return end;
		local char = p:GetCharacter()
		if !char then return end;
		local item = char:GetInventory()
		if !item then return end;
		item = item:GetItemsByUniqueID('radio')
		for _, x in ipairs(item) do
			if x:GetData("power") then
				item = x
				goto found
			end 
		end
		do return end;
		::found::

		if item && item:GetData("power") then
			local w, h = ScrW(), ScrH()
			local canHear = char:GetData("RadioTalking", true)
			local canListen = char:GetData("RadioListen", true)
			-- draw.SimpleText('Частота: ' .. item:GetData("freq", "000,0"), 'ixToolTipText',  20, h*.9, color_white, 0, 1)
			draw.SimpleText('Вас слышат (Кнопка "M")', 'ixToolTipText',  20, h*.90,canHear && Color(75,235,75) || red, 0, 1)
			draw.SimpleText('Вы слушаете (Кнопка "N")', 'ixToolTipText',  20, h*.94, canListen && Color(75,235,75) || red, 0, 1)
		end
	end
	function PLUGIN:PlayerStartVoice(g)
		local p = LocalPlayer()
		if g ~= p then return end;
		if !p:Alive() then return end;
		local char = p:GetCharacter()
		if !char then return end;
		if !char:GetData("RadioTalking", true) then return end;
		local item = char:GetInventory()
		if !item then return end;
		item = item:GetItemsByUniqueID('radio')
		for _, x in ipairs(item) do
			if x:GetData("power") then
				item = x
				goto found
			end 
		end
		do return end;
		::found::
		g:EmitSound("npc/metropolice/vo/on"..math.random(2)..".wav", math.random(50, 60), math.random(80, 120))
	end
	function PLUGIN:PlayerEndVoice(g)
		local p = LocalPlayer()
		if g ~= p then return end;
		if !p:Alive() then return end;
		local char = p:GetCharacter()
		if !char then return end;
		if !char:GetData("RadioTalking", true) then return end;
		local item = char:GetInventory()
		if !item then return end;
		item = item:GetItemsByUniqueID('radio')
		for _, x in ipairs(item) do
			if x:GetData("power") then
				item = x
				goto found
			end 
		end
		do return end;
		::found::
		g:EmitSound("npc/metropolice/vo/off"..math.random(3)..".wav", math.random(60, 70), math.random(80, 120))
	end
	return 
end


local function adjustradio(p,k)
	if !p:Alive() then return end;
	if (p.BTNCD||0) > CurTime() then return end;
	if k == KEY_M then
		p.BTNCD = CurTime() + .5
		local c1 = p:GetChar()
		if !c1 then return end;
		local inv_listener = c1:GetInventory()
		if !inv_listener then return end;
		c1:SetData("RadioTalking", !c1:GetData("RadioTalking", true))
	elseif k == KEY_N then
		p.BTNCD = CurTime() + .5
		local c1 = p:GetChar()
		if !c1 then return end;
		local inv_listener = c1:GetInventory()
		if !inv_listener then return end;
		c1:SetData("RadioListen", !c1:GetData("RadioListen", true))
	end
end

hook.Add("PlayerButtonDown", "RadioAdjust", adjustradio)


hook.Add("PlayerCanHearPlayersVoice", "RadioMoment", function(list, talk)
	-- print(list,talk)
	if !list:Alive() || !talk:Alive() then return end;
	local c1, c2 = list:GetChar(), talk:GetCharacter()
	if !c1 || !c2 then return end;
	if !c2:GetData("RadioTalking", true) then return end;
	if !c1:GetData("RadioListen", true) then return end;
	local inv_listener, inv_talker = c1:GetInventory(), c2:GetInventory()

	if !inv_listener || !inv_talker then return end;
	
	local talker_radio = inv_talker:GetItemsByUniqueID('radio')
	-- print(true)
	for z, x in ipairs(talker_radio) do
		if x:GetData("power") && (x:GetData("freq", "000,0") ~= '000,0' && x:GetData("freq", "000,0") ~= '000.0') then
			talker_radio = x:GetData("freq", "000,0")
			goto next
		end
	end
	do return end
	::next::

	local listener_radio = inv_listener:GetItemsByUniqueID('radio')
	for z, x in ipairs(listener_radio) do
		if x:GetData("power") && (x:GetData("freq", "000,0") ~= '000,0' && x:GetData("freq", "000,0") ~= '000.0') then
			listener_radio = x:GetData("freq", "000,0")
			goto skip
		end
	end
	do return end
	::skip::

	if !talker_radio || !listener_radio then return end; 
	if talker_radio == listener_radio then return true end;
	-- for z, x in ipairs() do
	-- 	if x:GetData('power') then rand = x:GetData('')
	-- end
end)