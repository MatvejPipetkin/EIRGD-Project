
ENT.Type = "anim"
ENT.PrintName = "Container"
ENT.Category = "Helix"
ENT.Spawnable = false
ENT.bNoPersist = true

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "ID")
	self:NetworkVar("Bool", 0, "Locked")
	self:NetworkVar("String", 0, "DisplayName")
end

--- Returns the definition (sh_definitions.lua) of this container.
function ENT:GetDefinition()
	return ix.container.GetDefinition(self:GetModel())
end

--- Returns the final interaction settings (interaction type from sh_config.lua + per-prop overrides).
function ENT:GetSettings()
	return ix.container.GetSettings(self:GetDefinition())
end

if (SERVER) then
	function ENT:Initialize()
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self.receivers = {}
		self.Sessions = {}
		self.PasswordAttempts = {}

		local model = self:GetModel()
		local definition = model and ix.container.stored[model:lower()]

		if (definition) then
			self:SetDisplayName(definition.name)
		end

		local physObj = self:GetPhysicsObject()

		if (IsValid(physObj)) then
			physObj:EnableMotion(true)
			physObj:Wake()
		end
	end

	function ENT:SetInventory(inventory)
		if (inventory) then
			self:SetID(inventory:GetID())
		end
	end

	function ENT:SetMoney(amount)
		self.money = math.max(0, math.Round(tonumber(amount) or 0))
	end

	function ENT:GetMoney()
		return self.money or 0
	end

	function ENT:OnRemove()
		local index = self:GetID()

		if (!ix.shuttingDown and !self.ixIsSafe and ix.entityDataLoaded and index) then
			local inventory = ix.item.inventories[index]

			if (inventory) then
				ix.item.inventories[index] = nil

				local query = mysql:Delete("ix_items")
					query:Where("inventory_id", index)
				query:Execute()

				query = mysql:Delete("ix_inventories")
					query:Where("inventory_id", index)
				query:Execute()

				hook.Run("ContainerRemoved", self, inventory)
			end
		end
	end

	-- ---------------------------------------------------------------------
	-- Sounds and prop animation
	-- ---------------------------------------------------------------------

	--- Plays one of the configured sounds ("start", "open", "close", "locked") at the container.
	function ENT:PlayContainerSound(key, settings)
		settings = settings or self:GetSettings()

		if (!settings) then
			return
		end

		local sound = ix.container.GetSound(settings, key)

		if (sound) then
			self:EmitSound(sound, settings.soundLevel, math.random(95, 105))
		end
	end

	--- Plays a sequence of the model by name. Returns false if the model doesn't have it.
	function ENT:PlayContainerSequence(name)
		if (!isstring(name) or name == "") then
			return false
		end

		local sequence = self:LookupSequence(name)

		if (sequence and sequence > -1) then
			self:ResetSequence(sequence)

			return true
		end

		return false
	end

	--- Switches the visual state of the container (door/lid open or closed): sound + model animation.
	function ENT:SetContainerOpen(bOpen)
		if (self.ixIsOpen == bOpen) then
			return
		end

		self.ixIsOpen = bOpen

		local settings = self:GetSettings()

		if (!settings) then
			return
		end

		self:PlayContainerSound(bOpen and "open" or "close", settings)
		self:PlayContainerSequence(settings.animation[bOpen and "open" or "close"])
	end

	-- ---------------------------------------------------------------------
	-- Opening: a short action first, the inventory afterwards
	-- ---------------------------------------------------------------------

	--- Starts the opening action for a player: gesture, progress bar, and the inventory opens when it's done.
	-- The action is cancelled if the player dies, looks away, walks away or moves too far.
	function ENT:BeginInteraction(client)
		local inventory = self:GetInventory()
		local character = client:GetCharacter()
		local settings = self:GetSettings()

		if (!inventory or !character or !settings) then
			return
		end

		-- already open for this player, or already doing something with a container
		if (client.ixOpenStorage == inventory or client.ixContainerAction) then
			return
		end

		if (ix.storage.InUse(inventory) or (IsValid(self.ixInteractor) and self.ixInteractor != client)) then
			client:NotifyLocalized("storageInUse")

			return
		end

		if (hook.Run("CanPlayerOpenContainer", client, self) == false) then
			return
		end

		local duration = settings.time * ix.config.Get("containerTimeScale", 1)

		self:PlayContainerSound("start", settings)

		-- too short for a progress bar (or time scale is 0): open right away
		if (duration < 0.2) then
			self:OpenInventory(client)

			return
		end

		local timerID = "ixContainerAction" .. client:EntIndex()
		local charID = character:GetID()
		local startPos = client:GetPos()
		local maxMove = tonumber(settings.maxMove)

		client.ixContainerAction = self
		self.ixInteractor = client

		hook.Run("PlayerContainerInteractionStarted", client, self, settings)

		ix.container.PlayGesture(client, settings)
		client:SetAction(L(settings.text or "containerActionSmall", client), duration)

		local function Stop(bCancelled)
			timer.Remove(timerID)

			if (IsValid(client)) then
				client.ixContainerAction = nil

				if (bCancelled) then
					client:SetAction()
					ix.container.PlayGesture(client, nil, true)
				end
			end

			if (IsValid(self)) then
				self.ixInteractor = nil

				if (bCancelled and IsValid(client)) then
					hook.Run("PlayerContainerInteractionCancelled", client, self, settings)
				end
			end
		end

		local function IsStillValid()
			if (!IsValid(client) or !IsValid(self) or !client:Alive()) then
				return false
			end

			local currentCharacter = client:GetCharacter()

			if (!currentCharacter or currentCharacter:GetID() != charID) then
				return false
			end

			local eyePos = client:GetShootPos()

			if (self:NearestPoint(eyePos):Distance(eyePos) > settings.distance) then
				return false
			end

			if (maxMove and maxMove > 0 and client:GetPos():Distance(startPos) > maxMove) then
				return false
			end

			-- the player has to keep looking at the container
			local trace = client:GetEyeTrace()

			return trace.Entity == self or client:GetUseEntity() == self
		end

		-- one check every 0.1s; rounded so the action ends together with the progress bar
		timer.Create(timerID, 0.1, math.max(1, math.Round(duration / 0.1)), function()
			if (!IsStillValid()) then
				Stop(true)
			elseif (timer.RepsLeft(timerID) == 0) then
				Stop(false)
				self:OpenInventory(client)
			end
		end)
	end

	--- Opens the inventory for the player right now (no action). Normally called when the opening action is finished.
	function ENT:OpenInventory(activator)
		local inventory = self:GetInventory()

		if (!inventory or !IsValid(activator)) then
			return
		end

		local name = self:GetDisplayName()
		local character = activator:GetCharacter()

		if (!character) then
			return
		end

		ix.storage.Open(activator, inventory, {
			name = name,
			entity = self,
			searchTime = 0,
			data = {money = self:GetMoney()},
			OnPlayerOpen = function(client)
				self:OnContainerOpened(client)
			end,
			OnPlayerClose = function(client)
				self:OnContainerClosed(client)
			end
		})

		-- ix.storage.Open refuses (and notifies the player) if somebody else is using the container
		if (ix.storage.InUseBy(inventory, activator)) then
			if (self:GetLocked()) then
				self.Sessions = self.Sessions or {}
				self.Sessions[character:GetID()] = true
			end

			ix.log.Add(activator, "openContainer", name, inventory:GetID())
		end
	end

	--- Called when a player has the container open (the inventory UI is about to show).
	function ENT:OnContainerOpened(client)
		timer.Remove("ixContainerClose" .. self:EntIndex())

		local definition = self:GetDefinition()

		self:SetContainerOpen(true)

		if (definition and definition.OnOpen) then
			definition.OnOpen(self, client)
		end

		hook.Run("PlayerContainerOpened", client, self)
	end

	--- Called when a player closes the container (or it was closed by force).
	function ENT:OnContainerClosed(client)
		local definition = self:GetDefinition()
		local settings = self:GetSettings()

		if (definition and definition.OnClose) then
			definition.OnClose(self, client)
		end

		if (IsValid(client)) then
			ix.log.Add(client, "closeContainer", self:GetDisplayName(), self:GetID())
		end

		-- close the door/lid shortly after the last player has left
		local timerID = "ixContainerClose" .. self:EntIndex()

		timer.Create(timerID, settings and settings.closeDelay or 0, 1, function()
			if (!IsValid(self)) then
				return
			end

			local inventory = self:GetInventory()

			if (!inventory or !ix.storage.InUse(inventory)) then
				self:SetContainerOpen(false)
			end
		end)
	end

	function ENT:Use(activator)
		local inventory = self:GetInventory()

		if (!inventory or (activator.ixNextOpen or 0) >= CurTime()) then
			return
		end

		local character = activator:GetCharacter()

		if (character) then
			if (self:GetLocked() and !self.Sessions[character:GetID()]) then
				self:PlayContainerSound("locked")

				if (!self.keypad) then
					net.Start("ixContainerPassword")
						net.WriteEntity(self)
					net.Send(activator)
				end
			else
				self:BeginInteraction(activator)
			end
		end

		activator.ixNextOpen = CurTime() + 1
	end
else
	ENT.PopulateEntityInfo = true

	local COLOR_LOCKED = Color(200, 38, 19, 200)
	local COLOR_UNLOCKED = Color(135, 211, 124, 200)

	function ENT:OnPopulateEntityInfo(tooltip)
		local definition = self:GetDefinition()
		local bLocked = self:GetLocked()

		surface.SetFont("ixIconsSmall")

		local iconText = bLocked and "P" or "Q"
		local iconWidth, iconHeight = surface.GetTextSize(iconText)

		-- minimal tooltips have centered text so we'll draw the icon above the name instead
		if (tooltip:IsMinimal()) then
			local icon = tooltip:AddRow("icon")
			icon:SetFont("ixIconsSmall")
			icon:SetTextColor(bLocked and COLOR_LOCKED or COLOR_UNLOCKED)
			icon:SetText(iconText)
			icon:SizeToContents()
		end

		local title = tooltip:AddRow("name")
		title:SetImportant()
		title:SetText(self:GetDisplayName())
		title:SetBackgroundColor(ix.config.Get("color"))
		title:SetTextInset(iconWidth + 8, 0)
		title:SizeToContents()

		if (!tooltip:IsMinimal()) then
			title.Paint = function(panel, width, height)
				panel:PaintBackground(width, height)

				surface.SetFont("ixIconsSmall")
				surface.SetTextColor(bLocked and COLOR_LOCKED or COLOR_UNLOCKED)
				surface.SetTextPos(4, height * 0.5 - iconHeight * 0.5)
				surface.DrawText(iconText)
			end
		end

		local description = tooltip:AddRow("description")
		description:SetText(definition and definition.description or "")
		description:SizeToContents()
	end
end

function ENT:GetInventory()
	return ix.item.inventories[self:GetID()]
end
