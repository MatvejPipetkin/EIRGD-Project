local PLUGIN = PLUGIN

PLUGIN.name = "Persistent Corpses"
PLUGIN.author = "`impulse"
PLUGIN.description = "Makes player corpses stay on the map after the player has respawned."
PLUGIN.license = [[
Copyright 2018 - 2020 Igor Radovanovic

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]
PLUGIN.readme = [[
Makes player corpses stay on the map after the player has respawned. Items can also be set to drop into the ragdoll's inventory
upon death.

## Enabling drops
To allow items to be put into a corpse's inventory when a player dies, you must set the `dropItemsOnDeath` config to `true`,
and then add `ITEM.bDropOnDeath = true` to any item that you want to be placed into the inventory.

## Searching
Pressing USE on a corpse starts an interactive search. Markers are shown on the body (jacket, belt, pockets, pouch) and the
player has to hold the left mouse button on each of them. Once every part is searched, the corpse inventory opens.
]]

PLUGIN.hardCorpseMax = 64
PLUGIN.searchRange = 128

-- size of the corpse inventory (8 x 5 = 40 cells)
PLUGIN.corpseInvWidth = 8
PLUGIN.corpseInvHeight = 5

-- parts of the body that must be searched; `bone2` + `frac` place the marker between two bones
PLUGIN.searchZones = {
	{name = "corpseZoneJacket", bone = "ValveBiped.Bip01_Spine2"},
	{name = "corpseZoneBelt", bone = "ValveBiped.Bip01_Pelvis"},
	{name = "corpseZonePockets", bone = "ValveBiped.Bip01_R_Thigh", bone2 = "ValveBiped.Bip01_R_Calf", frac = 0.3},
	{name = "corpseZonePouch", bone = "ValveBiped.Bip01_L_Thigh", bone2 = "ValveBiped.Bip01_L_Calf", frac = 0.3}
}

ix.lang.AddTable("english", {
	corpseSearchTitle = "ОБЫСК ТЕЛА",
	corpseSearchSubtitle = "Зажмите левую кнопку мыши на отмеченных участках",
	corpseSearchHint = "ЛКМ (удерживать) — обыскать     ПКМ / ESC — прекратить",
	corpseSearchProgress = "Осмотрено %d из %d",
	corpseZoneJacket = "Куртка",
	corpseZoneBelt = "Пояс",
	corpseZonePockets = "Карманы",
	corpseZonePouch = "Подсумок",
	corpseStage1 = "Нащупываете застёжку...",
	corpseStage2 = "Расстёгиваете...",
	corpseStage3 = "Перебираете содержимое...",
	corpseBusy = "Это тело уже кто-то обыскивает."
})

ix.config.Add("corpseMax", 8, "Maximum number of corpses that are allowed to be spawned.", nil, {
	data = {min = 0, max = PLUGIN.hardCorpseMax},
	category = "Persistent Corpses"
})

ix.config.Add("corpseDecayTime", 60, "How long it takes for a corpse to decay in seconds. Set to 0 to never decay.", nil, {
	data = {min = 0, max = 1800},
	category = "Persistent Corpses"
})

ix.config.Add("corpseSearchTime", 1.5, "How long it takes to search each part of a corpse, in seconds.", nil, {
	data = {min = 0, max = 10, decimals = 1},
	category = "Persistent Corpses"
})

ix.config.Add("dropItemsOnDeath", true, "Whether or not to drop specific items on death.", nil, {
	category = "Persistent Corpses"
})

if (SERVER) then
	util.AddNetworkString("ixCorpseSearchBegin")
	util.AddNetworkString("ixCorpseSearchZone")
	util.AddNetworkString("ixCorpseSearchCancel")
	util.AddNetworkString("ixCorpseSearchStop")

	PLUGIN.corpses = {}
	PLUGIN.inventorySeq = 0

	-- disable the regular hl2 ragdolls
	function PLUGIN:ShouldSpawnClientRagdoll(client)
		return false
	end

	function PLUGIN:PlayerSpawn(client)
		client:SetLocalVar("ragdoll", nil)
	end

	function PLUGIN:ShouldRemoveRagdollOnDeath(client)
		return false
	end

	function PLUGIN:PlayerInitialSpawn(client)
		self:CleanupCorpses()
	end

	function PLUGIN:CleanupCorpses(maxCorpses)
		maxCorpses = maxCorpses or ix.config.Get("corpseMax", 8)
		local toRemove = {}

		if (#self.corpses > maxCorpses) then
			for k, v in ipairs(self.corpses) do
				if (!IsValid(v)) then
					toRemove[#toRemove + 1] = k
				elseif (#self.corpses - #toRemove > maxCorpses) then
					v:Remove()
					toRemove[#toRemove + 1] = k
				end
			end
		end

		for i = #toRemove, 1, -1 do
			table.remove(self.corpses, toRemove[i])
		end
	end

	function PLUGIN:RemoveEquippableItem(client, item)
		if (item.Unequip) then
			item:Unequip(client)
		elseif (item.RemoveOutfit) then
			item:RemoveOutfit(client)
		elseif (item.RemovePart) then
			item:RemovePart(client)
		end
	end

	function PLUGIN:DoPlayerDeath(client, attacker, damageinfo)
		if (hook.Run("ShouldSpawnPlayerCorpse") == false) then
			return
		end

		-- remove old corpse if we've hit the limit
		local maxCorpses = ix.config.Get("corpseMax", 8)

		if (maxCorpses == 0) then
			return
		end

		local entity = IsValid(client.ixRagdoll) and client.ixRagdoll or client:CreateServerRagdoll()
		local decayTime = ix.config.Get("corpseDecayTime", 60)
		local uniqueID = "ixCorpseDecay" .. entity:EntIndex()

		entity:RemoveCallOnRemove("fixer")
		entity:CallOnRemove("ixPersistentCorpse", function(ragdoll)
			if (IsValid(ragdoll.ixSearcher)) then
				PLUGIN:StopCorpseSearch(ragdoll.ixSearcher, true)
			end

			if (ragdoll.ixInventory) then
				ix.storage.Close(ragdoll.ixInventory)
			end

			if (IsValid(client) and !client:Alive()) then
				client:SetLocalVar("ragdoll", nil)
			end

			local index

			for k, v in ipairs(PLUGIN.corpses) do
				if (v == ragdoll) then
					index = k
					break
				end
			end

			if (index) then
				table.remove(PLUGIN.corpses, index)
			end

			if (timer.Exists(uniqueID)) then
				timer.Remove(uniqueID)
			end
		end)

		-- start decay process only if we have a time set
		if (decayTime > 0) then
			timer.Create(uniqueID, decayTime, 1, function()
				if (IsValid(entity)) then
					entity:Remove()
				else
					timer.Remove(uniqueID)
				end
			end)
		end

		-- remove reference to ragdoll so it isn't removed on spawn when SetRagdolled is called
		client.ixRagdoll = nil
		-- remove reference to the player so no more damage can be dealt
		entity.ixPlayer = nil

		self.corpses[#self.corpses + 1] = entity

		-- clean up old corpses after we've added this one
		if (#self.corpses >= maxCorpses) then
			self:CleanupCorpses(maxCorpses)
		end

		hook.Run("OnPlayerCorpseCreated", client, entity)
	end

	-- moves a random part of the character's backpack items into the corpse inventory
	function PLUGIN:DropBackpackItems(client, character, inventory)
		local charInventory = character:GetInventory()

		if (!charInventory) then
			return
		end

		local removableItems = {}
		local seen = {}

		-- an item that takes several cells is stored in several slots, so skip duplicates
		for _, slot in pairs(charInventory.slots) do
			for _, item in pairs(slot) do
				if (!item.NoRemove and !seen[item.id]) then
					seen[item.id] = true
					removableItems[#removableItems + 1] = item
				end
			end
		end

		local itemsToDrop = math.floor(#removableItems * 0.3)

		for i = #removableItems, 2, -1 do
			local j = math.random(i)
			removableItems[i], removableItems[j] = removableItems[j], removableItems[i]
		end

		for i = 1, itemsToDrop do
			local item = removableItems[i]

			-- the corpse inventory is small, so look for a free spot instead of reusing the old coordinates
			local x, y = inventory:FindEmptySlot(item.width, item.height)

			if (x) then
				local ok, err = pcall(item.Transfer, item, inventory:GetID(), x, y)

				if (!ok) then
					ErrorNoHalt("[Corpses] failed to transfer item: " .. tostring(err) .. "\n")
				end
			end
		end
	end

	-- moves one equipped item into the corpse inventory
	function PLUGIN:DropEquippedItem(client, equipInventory, inventory, item)
		local x, y = inventory:FindEmptySlot(item.width, item.height)

		if (!x) then
			return
		end

		self:RemoveEquippableItem(client, item)

		item.gridX, item.gridY = x, y
		item.invID = inventory:GetID()

		if (item.equip_slot_id) then
			equipInventory.slots[item.equip_slot_id] = nil
		end

		item.equip_slot_id = nil

		local query = mysql:Update("ix_items")
			query:Update("inventory_id", 0)
			query:Where("item_id", item.id)
			query:Limit(1)
		query:Execute()

		for x2 = 0, item.width - 1 do
			for y2 = 0, item.height - 1 do
				inventory.slots[x + x2] = inventory.slots[x + x2] or {}
				inventory.slots[x + x2][y + y2] = item
			end
		end
	end

	-- gives a small chance to lose equipped items
	function PLUGIN:DropEquippedItems(client, character, inventory)
		local equipInventory = character.GetEquipInventory and character:GetEquipInventory()

		if (!equipInventory) then
			return
		end

		local equipped = {}

		-- collect first, the inventory is modified while dropping
		local ok, err = pcall(function()
			for _, item in equipInventory:Iter() do
				equipped[#equipped + 1] = item
			end
		end)

		if (!ok) then
			ErrorNoHalt("[Corpses] failed to read equipment: " .. tostring(err) .. "\n")
			return
		end

		for _, item in ipairs(equipped) do
			if (math.random(1, 100) <= 5) then
				local dropped, dropErr = pcall(self.DropEquippedItem, self, client, equipInventory, inventory, item)

				if (!dropped) then
					ErrorNoHalt("[Corpses] failed to drop equipped item: " .. tostring(dropErr) .. "\n")
				end
			end
		end
	end

	function PLUGIN:OnPlayerCorpseCreated(client, entity)
		local character = client:GetCharacter()

		if (!character) then
			return
		end

		-- create the corpse inventory first, so the body can be searched even if dropping items fails
		self.inventorySeq = self.inventorySeq + 1

		local inventory = ix.item.CreateInv(self.corpseInvWidth, self.corpseInvHeight, os.time() + self.inventorySeq)
		inventory.noSave = true

		entity.ixInventory = inventory

		if (!ix.config.Get("dropItemsOnDeath", false)) then
			return
		end

		client:SetLocalVar("ragdoll", entity:EntIndex())

		local ok, err = pcall(self.DropBackpackItems, self, client, character, inventory)

		if (!ok) then
			ErrorNoHalt("[Corpses] failed to drop backpack items: " .. tostring(err) .. "\n")
		end

		ok, err = pcall(self.DropEquippedItems, self, client, character, inventory)

		if (!ok) then
			ErrorNoHalt("[Corpses] failed to drop equipped items: " .. tostring(err) .. "\n")
		end
	end

	-- interactive search
	function PLUGIN:CanReachCorpse(client, entity)
		return client:GetShootPos():DistToSqr(entity:WorldSpaceCenter()) <= (self.searchRange + 32) ^ 2
	end

	function PLUGIN:StartCorpseSearch(client, entity)
		client.ixCorpseSearch = {
			entity = entity,
			done = {},
			count = 0,
			last = CurTime()
		}

		entity.ixSearcher = client
		entity:EmitSound("physics/body/body_medium_impact_soft" .. math.random(1, 7) .. ".wav", 55, math.random(92, 108))

		net.Start("ixCorpseSearchBegin")
			net.WriteEntity(entity)
		net.Send(client)
	end

	function PLUGIN:StopCorpseSearch(client, tellClient)
		local search = client.ixCorpseSearch

		if (!search) then
			return
		end

		client.ixCorpseSearch = nil

		if (IsValid(search.entity) and search.entity.ixSearcher == client) then
			search.entity.ixSearcher = nil
		end

		if (tellClient and IsValid(client)) then
			net.Start("ixCorpseSearchStop")
			net.Send(client)
		end
	end

	function PLUGIN:FinishCorpseSearch(client, entity)
		local inventory = entity.ixInventory

		self:StopCorpseSearch(client, false)

		if (!inventory or ix.storage.InUse(inventory)) then
			client:NotifyLocalized("corpseBusy")
			return
		end

		ix.storage.Open(client, inventory, {
			entity = entity,
			name = "Corpse",
			searchTime = 0
		})
	end

	function PLUGIN:OnCorpseZoneSearched(client, index)
		local search = client.ixCorpseSearch

		if (!search) then
			return
		end

		local entity = search.entity

		if (!IsValid(entity) or !client:Alive() or !self:CanReachCorpse(client, entity)) then
			self:StopCorpseSearch(client, true)
			return
		end

		if (!self.searchZones[index] or search.done[index]) then
			return
		end

		-- a zone can't be finished faster than the time it takes to search it
		local zoneTime = math.max(ix.config.Get("corpseSearchTime", 1.5), 0.05)

		if (CurTime() - search.last < zoneTime * 0.8) then
			return
		end

		search.done[index] = true
		search.count = search.count + 1
		search.last = CurTime()

		entity:EmitSound("npc/combine_soldier/gear" .. math.random(1, 6) .. ".wav", 55, math.random(92, 108))

		if (search.count >= #self.searchZones) then
			self:FinishCorpseSearch(client, entity)
		end
	end

	function PLUGIN:PlayerDeath(client)
		self:StopCorpseSearch(client, true)
	end

	function PLUGIN:PlayerDisconnected(client)
		self:StopCorpseSearch(client, false)
	end

	net.Receive("ixCorpseSearchZone", function(_, client)
		PLUGIN:OnCorpseZoneSearched(client, net.ReadUInt(4))
	end)

	net.Receive("ixCorpseSearchCancel", function(_, client)
		PLUGIN:StopCorpseSearch(client, false)
	end)

	function PLUGIN:PlayerUse(client, entity)
		if (entity:GetClass() != "prop_ragdoll" or !entity.ixInventory) then
			return
		end

		if (client.ixCorpseSearch) then
			return false
		end

		local searcher = entity.ixSearcher

		if (ix.storage.InUse(entity.ixInventory) or (IsValid(searcher) and searcher != client and searcher.ixCorpseSearch)) then
			if ((client.ixCorpseBusyNotify or 0) < CurTime()) then
				client.ixCorpseBusyNotify = CurTime() + 1
				client:NotifyLocalized("corpseBusy")
			end

			return false
		end

		self:StartCorpseSearch(client, entity)

		return false
	end
end

if (CLIENT) then
	local COLOR_DONE = Color(120, 200, 120)
	local COLOR_TEXT = Color(190, 190, 190)

	PLUGIN.viewBlend = 0

	-- drawing helpers
	local function DrawDisk(x, y, radius, color)
		local points = {}

		for i = 0, 31 do
			local angle = math.rad(i * 360 / 32)
			points[#points + 1] = {x = x + math.cos(angle) * radius, y = y + math.sin(angle) * radius}
		end

		draw.NoTexture()
		surface.SetDrawColor(color)
		surface.DrawPoly(points)
	end

	-- angles are in degrees, 0 is the top, clockwise
	local function DrawArc(x, y, radius, thickness, startAng, endAng, color)
		local segments = math.max(4, math.floor(math.abs(endAng - startAng) / 6))
		local step = (endAng - startAng) / segments
		local inner = radius - thickness

		draw.NoTexture()
		surface.SetDrawColor(color)

		for i = 0, segments - 1 do
			local a1 = math.rad(startAng + step * i - 90)
			local a2 = math.rad(startAng + step * (i + 1) - 90)
			local c1, s1, c2, s2 = math.cos(a1), math.sin(a1), math.cos(a2), math.sin(a2)

			surface.DrawPoly({
				{x = x + c1 * radius, y = y + s1 * radius},
				{x = x + c2 * radius, y = y + s2 * radius},
				{x = x + c2 * inner, y = y + s2 * inner},
				{x = x + c1 * inner, y = y + s1 * inner}
			})
		end
	end

	local function DrawFade(x, y, width, height, alpha, fromBottom)
		local steps = 32
		local stepHeight = math.ceil(height / steps)

		for i = 0, steps - 1 do
			surface.SetDrawColor(0, 0, 0, alpha * (1 - i / steps) ^ 2)

			if (fromBottom) then
				surface.DrawRect(x, y + height - (i + 1) * stepHeight, width, stepHeight)
			else
				surface.DrawRect(x, y + i * stepHeight, width, stepHeight)
			end
		end
	end

	local function DrawCheck(x, y, size, color)
		surface.SetDrawColor(color)

		local x1, y1 = x - size * 0.45, y + size * 0.02
		local x2, y2 = x - size * 0.1, y + size * 0.38
		local x3, y3 = x + size * 0.5, y - size * 0.36

		for offset = -1, 1 do
			surface.DrawLine(x1, y1 + offset, x2, y2 + offset)
			surface.DrawLine(x2, y2 + offset, x3, y3 + offset)
		end
	end

	local function GetBonePos(entity, name)
		local bone = entity:LookupBone(name)

		if (bone) then
			local matrix = entity:GetBoneMatrix(bone)

			if (matrix) then
				return matrix:GetTranslation()
			end

			return (entity:GetBonePosition(bone))
		end
	end

	local function GetZonePos(entity, zone)
		local pos = GetBonePos(entity, zone.bone)

		if (pos and zone.bone2) then
			local pos2 = GetBonePos(entity, zone.bone2)

			if (pos2) then
				pos = LerpVector(zone.frac or 0.5, pos, pos2)
			end
		end

		return pos or entity:WorldSpaceCenter()
	end

	-- panel
	local PANEL = {}

	function PANEL:Init()
		self:SetSize(ScrW(), ScrH())
		self:SetPos(0, 0)
		self:SetAlpha(0)
		self:AlphaTo(255, 0.35, 0)
		self:MakePopup()

		self.zones = {}
		self.doneCount = 0
		self.hover = nil
		self.active = nil
		self.wasDown = false
		self.closing = false
		self.nextRustle = 0
	end

	function PANEL:Setup(entity)
		self.entity = entity

		for i, zone in ipairs(PLUGIN.searchZones) do
			self.zones[i] = {
				name = L(zone.name),
				progress = 0,
				done = false,
				scale = 0.6,
				x = 0,
				y = 0,
				radius = 24,
				visible = false
			}
		end
	end

	function PANEL:Close(cancel)
		if (self.closing) then
			return
		end

		self.closing = true

		if (cancel) then
			net.Start("ixCorpseSearchCancel")
			net.SendToServer()
		end

		self:SetMouseInputEnabled(false)
		self:SetKeyboardInputEnabled(false)
		self:AlphaTo(0, 0.25, 0, function()
			if (IsValid(self)) then
				self:Remove()
			end
		end)
	end

	function PANEL:CompleteZone(index)
		local state = self.zones[index]

		state.done = true
		state.progress = 1
		state.scale = 1.45
		self.doneCount = self.doneCount + 1

		surface.PlaySound("ui/buttonclickrelease.wav")

		net.Start("ixCorpseSearchZone")
			net.WriteUInt(index, 4)
		net.SendToServer()

		if (self.doneCount >= #self.zones) then
			self:Close(false)
		end
	end

	function PANEL:OnKeyCodePressed(key)
		if (key == KEY_ESCAPE) then
			gui.HideGameUI()
			self:Close(true)
		end
	end

	function PANEL:OnMousePressed(code)
		if (code == MOUSE_RIGHT) then
			self:Close(true)
		end
	end

	function PANEL:Think()
		if (self.closing) then
			return
		end

		local client = LocalPlayer()
		local entity = self.entity

		if (!IsValid(entity) or !IsValid(client) or !client:Alive()
		or client:GetShootPos():DistToSqr(entity:WorldSpaceCenter()) > (PLUGIN.searchRange + 16) ^ 2) then
			self:Close(true)
			return
		end

		local dt = FrameTime()
		local eyePos = client:EyePos()
		local scale = ScrH() / 1080
		local cursorX, cursorY = self:CursorPos()
		local zoneTime = math.max(ix.config.Get("corpseSearchTime", 1.5), 0.05)

		-- marker positions follow the corpse bones
		for i, zone in ipairs(PLUGIN.searchZones) do
			local state = self.zones[i]
			local pos = GetZonePos(entity, zone)
			local screen = pos:ToScreen()

			state.x, state.y, state.visible = screen.x, screen.y, screen.visible
			state.radius = math.Clamp(120 / math.max(eyePos:Distance(pos), 1), 0.65, 1.35) * 26 * scale
		end

		-- the marker under the cursor
		local best = math.huge
		self.hover = nil

		for i, state in ipairs(self.zones) do
			if (state.visible and !state.done) then
				local dist = (state.x - cursorX) ^ 2 + (state.y - cursorY) ^ 2

				if (dist < (state.radius * 1.15) ^ 2 and dist < best) then
					best = dist
					self.hover = i
				end
			end
		end

		self:SetCursor(self.hover and "hand" or "arrow")

		-- holding the left mouse button
		local down = input.IsMouseDown(MOUSE_LEFT)

		if (down and !self.wasDown and self.hover) then
			self.active = self.hover
		end

		if (!down) then
			self.active = nil
		end

		self.wasDown = down

		if (self.active) then
			local state = self.zones[self.active]
			local dist = (state.x - cursorX) ^ 2 + (state.y - cursorY) ^ 2

			-- the hand slipped off the spot, the search is interrupted
			if (!state.visible or dist > (state.radius * 2) ^ 2) then
				self.active = nil
			else
				state.progress = math.min(state.progress + dt / zoneTime, 1)

				if (CurTime() >= self.nextRustle) then
					self.nextRustle = CurTime() + math.Rand(0.22, 0.45)
					client:EmitSound("physics/cardboard/cardboard_box_impact_soft" .. math.random(1, 7) .. ".wav",
						50, math.random(90, 115), 0.45, CHAN_ITEM)
				end

				if (state.progress >= 1) then
					local index = self.active

					self.active = nil
					self:CompleteZone(index)
				end
			end
		end

		for i, state in ipairs(self.zones) do
			-- unfinished progress slowly fades away
			if (!state.done and i != self.active) then
				state.progress = math.max(state.progress - dt * 1.5 / zoneTime, 0)
			end

			local target = 1

			if (state.done) then
				target = 0.85
			elseif (self.active == i) then
				target = 1.25
			elseif (self.hover == i) then
				target = 1.15
			end

			state.scale = Lerp(math.min(dt * 12, 1), state.scale, target)
		end
	end

	function PANEL:Paint(width, height)
		local scale = height / 1080
		local accent = ix.config.Get("color", Color(75, 119, 190))
		local time = CurTime()
		local total = #self.zones

		surface.SetDrawColor(0, 0, 0, 70)
		surface.DrawRect(0, 0, width, height)

		DrawFade(0, 0, width, 240 * scale, 190, false)
		DrawFade(0, height - 200 * scale, width, 200 * scale, 190, true)

		-- header
		draw.SimpleText(L("corpseSearchTitle"), "ixBigFont", width / 2, 70 * scale, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 255)
		surface.DrawRect(width / 2 - 70 * scale, 100 * scale, 140 * scale, math.max(2, 2 * scale))

		draw.SimpleText(L("corpseSearchSubtitle"), "ixSmallFont", width / 2, 122 * scale, COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		-- overall progress
		local segW, segH, gap = 44 * scale, math.max(3, 4 * scale), 8 * scale
		local startX = width / 2 - (total * segW + (total - 1) * gap) / 2

		for i, state in ipairs(self.zones) do
			local sx = startX + (i - 1) * (segW + gap)
			local fill = state.done and 1 or state.progress

			surface.SetDrawColor(255, 255, 255, 40)
			surface.DrawRect(sx, 150 * scale, segW, segH)

			if (fill > 0) then
				surface.SetDrawColor(state.done and COLOR_DONE or accent)
				surface.DrawRect(sx, 150 * scale, segW * fill, segH)
			end
		end

		draw.SimpleText(L("corpseSearchProgress", self.doneCount, total), "ixSmallFont", width / 2, 172 * scale,
			COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		-- markers on the body
		for i, state in ipairs(self.zones) do
			if (state.visible) then
				local x, y = state.x, state.y
				local radius = state.radius * state.scale
				local thin = math.max(2, 2 * scale)
				local thick = math.max(3, 5 * scale)

				if (state.done) then
					DrawArc(x, y, radius, thin, 0, 360, Color(COLOR_DONE.r, COLOR_DONE.g, COLOR_DONE.b, 150))
					DrawCheck(x, y, radius * 0.7, COLOR_DONE)

					draw.SimpleText(state.name, "ixSmallFont", x, y + radius + 14 * scale,
						Color(COLOR_DONE.r, COLOR_DONE.g, COLOR_DONE.b, 170), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				else
					local pulse = math.sin(time * 3 + i * 1.3) * 0.5 + 0.5
					local hovered = self.hover == i or self.active == i

					DrawDisk(x, y, radius, Color(0, 0, 0, hovered and 150 or 100))

					-- idle ring and the expanding "breathing" ring
					if (hovered) then
						DrawArc(x, y, radius, thin + 1, 0, 360, accent)
					else
						DrawArc(x, y, radius, thin, 0, 360, Color(255, 255, 255, 90 + pulse * 80))
						DrawArc(x, y, radius + pulse * 10 * scale, math.max(1, 1.5 * scale), 0, 360,
							Color(255, 255, 255, (1 - pulse) * 70))
					end

					DrawDisk(x, y, 3.5 * scale + (hovered and 1 or 0), Color(255, 255, 255, 220))

					-- search progress
					if (state.progress > 0) then
						DrawArc(x, y, radius + thick * 0.5, thick, 0, 360, Color(255, 255, 255, 35))
						DrawArc(x, y, radius + thick * 0.5, thick, 0, 360 * state.progress, accent)
					end

					-- label
					if (hovered) then
						surface.SetFont("ixMediumFont")
						local nameW, nameH = surface.GetTextSize(state.name)
						local padX, padY = 14 * scale, 8 * scale
						local lineX = x + radius + thick + 8 * scale
						local plateX = lineX + 14 * scale
						local plateH = nameH + padY * 2
						local extra = ""

						if (self.active == i) then
							extra = L("corpseStage" .. math.min(3, math.floor(state.progress * 3) + 1))
						end

						surface.SetFont("ixSmallFont")
						local extraW, extraH = surface.GetTextSize(extra)
						local plateW = math.max(nameW, extraW) + padX * 2

						if (extra != "") then
							plateH = plateH + extraH + 2 * scale
						end

						surface.SetDrawColor(accent.r, accent.g, accent.b, 200)
						surface.DrawRect(lineX, y, 14 * scale, math.max(1, 2 * scale))

						surface.SetDrawColor(0, 0, 0, 190)
						surface.DrawRect(plateX, y - plateH / 2, plateW, plateH)

						surface.SetDrawColor(accent.r, accent.g, accent.b, 255)
						surface.DrawRect(plateX, y - plateH / 2, math.max(2, 3 * scale), plateH)

						draw.SimpleText(state.name, "ixMediumFont", plateX + padX, y - plateH / 2 + padY,
							color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

						if (extra != "") then
							draw.SimpleText(extra, "ixSmallFont", plateX + padX, y - plateH / 2 + padY + nameH + 2 * scale,
								COLOR_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
						end
					end
				end
			end
		end

		-- footer
		draw.SimpleText(L("corpseSearchHint"), "ixSmallFont", width / 2, height - 70 * scale,
			COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	vgui.Register("ixCorpseSearch", PANEL, "EditablePanel")

	-- camera: the player leans over the body while searching
	function PLUGIN:Think()
		local panel = self.searchPanel
		local target = (IsValid(panel) and !panel.closing) and 1 or 0

		self.viewBlend = Lerp(math.min(FrameTime() * 4, 1), self.viewBlend, target)
	end

	function PLUGIN:CalcView(client, origin, angles, fov)
		local blend = self.viewBlend
		local entity = self.viewEntity

		if (blend <= 0.002 or !IsValid(entity)) then
			return
		end

		local ease = blend * blend * (3 - 2 * blend)
		local newOrigin = origin - Vector(0, 0, 18 * ease)
		local newAngles = LerpAngle(ease * 0.9, angles, (entity:WorldSpaceCenter() - newOrigin):Angle())

		-- slight breathing
		newAngles.p = newAngles.p + math.sin(CurTime() * 1.4) * 0.15 * ease

		return {
			origin = newOrigin,
			angles = newAngles,
			fov = fov - 8 * ease,
			drawviewer = false
		}
	end

	function PLUGIN:PreDrawViewModel()
		if (self.viewBlend > 0.05) then
			return true
		end
	end

	net.Receive("ixCorpseSearchBegin", function()
		local entity = net.ReadEntity()

		if (!IsValid(entity)) then
			return
		end

		if (IsValid(PLUGIN.searchPanel)) then
			PLUGIN.searchPanel:Remove()
		end

		PLUGIN.viewEntity = entity
		PLUGIN.searchPanel = vgui.Create("ixCorpseSearch")
		PLUGIN.searchPanel:Setup(entity)
	end)

	net.Receive("ixCorpseSearchStop", function()
		if (IsValid(PLUGIN.searchPanel)) then
			PLUGIN.searchPanel:Close(false)
		end
	end)
end