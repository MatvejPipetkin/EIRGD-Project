local PLUGIN = PLUGIN

PLUGIN.name = "Handcuffs"
PLUGIN.author = "Claude"
PLUGIN.description = "Наручники: интерактивное надевание/снятие на F1, скованные руки, админ-команды."
PLUGIN.readme = [[
Игрок с предметом `handcuffs` в инвентаре подходит к другому игроку и нажимает F1. Открывается мини-игра:
нужно зажать ЛКМ на каждом отмеченном участке (левое и правое запястье).
Если в руках оружие, каждый участок обрабатывается дольше (см. конфиг `cuffWeaponMultiplier`).

Скованный игрок:
- не может использовать предметы инвентаря и брать/выбрасывать их;
- не может выбирать оружие (цифры) и стрелять, в руках остаются только кулаки;
- ходит чуть медленнее, бежит трусцой (заметно медленнее обычного бега) и может прыгать;
- остаётся скованным после перезахода, пока его не освободят или он не умрёт.

Нажатие F1 на скованного игрока запускает ту же мини-игру, но для снятия наручников.
Если наручники были надеты предметом, то при снятии предмет возвращается тому, кто снимал.

## Админ-команды
/PlyCuff <игрок>   - заковать
/PlyUncuff <игрок> - освободить
]]

-- дистанция, с которой можно начать (F1)
PLUGIN.cuffRange = 96

-- множитель скорости скованного игрока: ходьба и бег (трусцой)
PLUGIN.cuffedSpeed = 0.8
PLUGIN.cuffedRunSpeed = 0.6

-- участки тела, на которых нужно удерживать ЛКМ; `bone2` + `frac` ставят маркер между двумя костями
PLUGIN.cuffZones = {
	{name = "cuffZoneLeft", bone = "ValveBiped.Bip01_L_Hand"},
	{name = "cuffZoneRight", bone = "ValveBiped.Bip01_R_Hand"}
}

-- это оружие НЕ считается "оружием в руке" (не замедляет надевание наручников)
PLUGIN.unarmedWeapons = {
	["ix_hands"] = true,
	["ix_keys"] = true,
	["gmod_tool"] = true,
	["weapon_physgun"] = true,
	["gmod_camera"] = true
}

-- поза "руки за спиной" (только визуально, клиентская манипуляция костями).
-- Значения приблизительные - при необходимости подгоните под свои модели.
PLUGIN.cuffedBones = {
	["ValveBiped.Bip01_R_UpperArm"] = Angle(-28, 18, -21),
	["ValveBiped.Bip01_L_UpperArm"] = Angle(28, 18, 21),
	["ValveBiped.Bip01_R_Forearm"] = Angle(0, -25, 0),
	["ValveBiped.Bip01_L_Forearm"] = Angle(0, -25, 0),
	["ValveBiped.Bip01_R_Hand"] = Angle(0, 0, -30),
	["ValveBiped.Bip01_L_Hand"] = Angle(0, 0, 30)
}

ix.lang.AddTable("english", {
	cuffTitleCuff = "НАДЕТЬ НАРУЧНИКИ",
	cuffTitleUncuff = "СНЯТЬ НАРУЧНИКИ",
	cuffSubtitle = "Зажмите левую кнопку мыши на отмеченных участках",
	cuffHint = "ЛКМ (удерживать) — продолжить     ПКМ / ESC — прекратить",
	cuffProgress = "Выполнено %d из %d",
	cuffArmedHint = "Оружие в руке мешает — это займёт больше времени",
	cuffZoneLeft = "Левое запястье",
	cuffZoneRight = "Правое запястье",
	cuffStage1 = "Берёте за запястье...",
	cuffStage2 = "Защёлкиваете браслет...",
	cuffStage3 = "Затягиваете...",
	uncuffStage1 = "Нащупываете замок...",
	uncuffStage2 = "Отпираете...",
	uncuffStage3 = "Снимаете браслет...",
	cuffNoItem = "У вас нет наручников.",
	cuffBusy = "Этого человека уже заковывают или освобождают.",
	cuffTargetStart = "Кто-то пытается надеть на вас наручники!",
	cuffedSelf = "Вам заковали руки за спиной.",
	uncuffedSelf = "С вас сняли наручники.",
	cuffedOther = "Вы заковали: %s.",
	uncuffedOther = "Вы сняли наручники с: %s.",
	cuffAlready = "%s уже в наручниках.",
	cuffNotCuffed = "%s не в наручниках.",
	cuffNoChar = "У этого игрока нет активного персонажа.",
	cuffedHud = "Ваши руки скованы за спиной"
})

ix.config.Add("cuffTime", 1.5, "How long it takes to handle each part of the handcuffs, in seconds.", nil, {
	data = {min = 0.2, max = 10, decimals = 1},
	category = "Handcuffs"
})

ix.config.Add("cuffWeaponMultiplier", 2, "Time multiplier when the person cuffing holds a weapon in their hands.", nil, {
	data = {min = 1, max = 5, decimals = 1},
	category = "Handcuffs"
})

-- shared
local playerMeta = FindMetaTable("Player")

function playerMeta:IsCuffed()
	return self:GetNetVar("ixCuffed", false) and true or false
end

-- во сколько раз дольше придётся возиться, если в руках оружие
function PLUGIN:GetCuffMultiplier(client)
	local weapon = client:GetActiveWeapon()

	if (IsValid(weapon) and !self.unarmedWeapons[weapon:GetClass()]) then
		return ix.config.Get("cuffWeaponMultiplier", 2)
	end

	return 1
end

-- скованные руки: никаких действий с предметами
function PLUGIN:CanPlayerInteractItem(client, action, item, data)
	if (client:IsCuffed()) then
		return false
	end
end

-- скованные руки: нельзя стрелять, бить и перезаряжаться
function PLUGIN:StartCommand(client, cmd)
	if (client:IsCuffed()) then
		cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(bit.bor(IN_ATTACK, IN_ATTACK2, IN_RELOAD))))
	end
end

-- скованный ходит чуть медленнее обычного и бегает трусцой (прыгать можно)
function PLUGIN:SetupMove(client, mv)
	if (client:IsCuffed()) then
		local multiplier = mv:KeyDown(IN_SPEED) and self.cuffedRunSpeed or self.cuffedSpeed
		local speed = mv:GetMaxClientSpeed() * multiplier

		mv:SetMaxClientSpeed(speed)
		mv:SetMaxSpeed(speed)
	end
end

-- admin commands
ix.command.Add("PlyCuff", {
	description = "Заковать игрока в наручники.",
	adminOnly = true,
	arguments = ix.type.player,
	OnRun = function(self, client, target)
		if (!target:GetCharacter()) then
			return "@cuffNoChar"
		end

		if (target:IsCuffed()) then
			return "@cuffAlready", target:GetName()
		end

		PLUGIN:SetCuffed(target, true, "admin")

		return "@cuffedOther", target:GetName()
	end
})

ix.command.Add("PlyUncuff", {
	description = "Снять наручники с игрока.",
	adminOnly = true,
	arguments = ix.type.player,
	OnRun = function(self, client, target)
		if (!target:IsCuffed()) then
			return "@cuffNotCuffed", target:GetName()
		end

		PLUGIN:SetCuffed(target, false)

		return "@uncuffedOther", target:GetName()
	end
})

if (SERVER) then
	util.AddNetworkString("ixCuffStart")
	util.AddNetworkString("ixCuffBegin")
	util.AddNetworkString("ixCuffZone")
	util.AddNetworkString("ixCuffCancel")
	util.AddNetworkString("ixCuffStop")

	function PLUGIN:GetCuffItem(client)
		local character = client:GetCharacter()
		local inventory = character and character:GetInventory()

		if (inventory) then
			return inventory:HasItem("handcuffs")
		end
	end

	-- возвращает наручники тому, кто их снял
	function PLUGIN:ReturnCuffItem(client)
		local character = client:GetCharacter()
		local inventory = character and character:GetInventory()

		if (inventory and inventory:Add("handcuffs")) then
			return
		end

		ix.item.Spawn("handcuffs", client:GetShootPos() + client:GetAimVector() * 48)
	end

	-- state: true/false, kind: "item" (надеты предметом) или "admin"
	function PLUGIN:SetCuffed(client, state, kind, bSilent)
		local character = client:GetCharacter()

		-- прерываем любые начатые действия с этим игроком
		if (IsValid(client.ixCuffer)) then
			self:StopCuffAction(client.ixCuffer, true)
		end

		if (client.ixCuffAction) then
			self:StopCuffAction(client, true)
		end

		if (state) then
			-- в руках остаются только кулаки
			if (client:HasWeapon("ix_hands")) then
				client:SelectWeapon("ix_hands")
			else
				client:SetActiveWeapon(NULL)
			end

			if (client.SetWepRaised) then
				client:SetWepRaised(false)
			end

			client:SetNetVar("ixCuffed", true)

			if (character) then
				character:SetData("cuffed", kind or "admin")
			end

			if (!bSilent) then
				client:NotifyLocalized("cuffedSelf")
			end

			hook.Run("OnPlayerCuffed", client)
		else
			client:SetNetVar("ixCuffed", nil)

			if (character) then
				character:SetData("cuffed")
			end

			if (!bSilent) then
				client:NotifyLocalized("uncuffedSelf")
			end

			hook.Run("OnPlayerUncuffed", client)
		end
	end

	-- скованный может переключиться только на кулаки
	function PLUGIN:PlayerSwitchWeapon(client, oldWeapon, newWeapon)
		if (client:IsCuffed() and (!IsValid(newWeapon) or newWeapon:GetClass() != "ix_hands")) then
			return true
		end
	end

	function PLUGIN:PlayerLoadedCharacter(client, character, lastChar)
		-- состояние предыдущего персонажа не должно переходить на нового
		if (IsValid(client.ixCuffer)) then
			self:StopCuffAction(client.ixCuffer, true)
		end

		if (client.ixCuffAction) then
			self:StopCuffAction(client, true)
		end

		client:SetNetVar("ixCuffed", nil)

		local kind = character:GetData("cuffed")

		if (kind) then
			timer.Simple(0.25, function()
				if (IsValid(client) and client:GetCharacter() == character) then
					self:SetCuffed(client, true, kind, true)
				end
			end)
		end
	end

	function PLUGIN:PlayerDeath(client)
		if (IsValid(client.ixCuffer)) then
			self:StopCuffAction(client.ixCuffer, true)
		end

		if (client.ixCuffAction) then
			self:StopCuffAction(client, true)
		end

		if (client:IsCuffed()) then
			self:SetCuffed(client, false, nil, true)
		end
	end

	function PLUGIN:PlayerDisconnected(client)
		if (IsValid(client.ixCuffer)) then
			self:StopCuffAction(client.ixCuffer, true)
		end

		if (client.ixCuffAction) then
			self:StopCuffAction(client, false)
		end
	end

	-- interactive cuffing
	function PLUGIN:CanReachTarget(client, target, extra)
		return client:GetShootPos():DistToSqr(target:WorldSpaceCenter()) <= (self.cuffRange + extra) ^ 2
	end

	function PLUGIN:BeginCuffAction(client, target)
		if ((client.ixCuffNext or 0) > CurTime()) then
			return
		end

		client.ixCuffNext = CurTime() + 1

		if (client.ixCuffAction or !IsValid(client) or !client:Alive() or !client:GetCharacter() or client:IsCuffed()) then
			return
		end

		if (!IsValid(target) or !target:IsPlayer() or target == client or !target:Alive() or !target:GetCharacter()) then
			return
		end

		if (!self:CanReachTarget(client, target, 48)) then
			return
		end

		local uncuff = target:IsCuffed()

		if (!uncuff and !self:GetCuffItem(client)) then
			client:NotifyLocalized("cuffNoItem")
			return
		end

		if ((IsValid(target.ixCuffer) and target.ixCuffer != client) or target.ixCuffAction) then
			client:NotifyLocalized("cuffBusy")
			return
		end

		client.ixCuffAction = {
			target = target,
			uncuff = uncuff,
			done = {},
			count = 0,
			last = CurTime()
		}

		target.ixCuffer = client
		target:EmitSound("physics/metal/metal_solid_impact_soft" .. math.random(1, 3) .. ".wav", 55, math.random(92, 108))

		if (!uncuff) then
			target:NotifyLocalized("cuffTargetStart")
		end

		net.Start("ixCuffBegin")
			net.WriteEntity(target)
			net.WriteBool(uncuff)
		net.Send(client)
	end

	function PLUGIN:StopCuffAction(client, tellClient)
		local action = client.ixCuffAction

		if (!action) then
			return
		end

		client.ixCuffAction = nil

		if (IsValid(action.target) and action.target.ixCuffer == client) then
			action.target.ixCuffer = nil
		end

		if (tellClient and IsValid(client)) then
			net.Start("ixCuffStop")
			net.Send(client)
		end
	end

	function PLUGIN:FinishCuffAction(client, target, uncuff)
		self:StopCuffAction(client, false)

		if (uncuff) then
			if (!target:IsCuffed()) then
				return
			end

			local character = target:GetCharacter()
			local kind = character and character:GetData("cuffed")

			self:SetCuffed(target, false)

			-- наручники, надетые предметом, возвращаются тому, кто их снял
			if (kind == "item") then
				self:ReturnCuffItem(client)
			end

			client:NotifyLocalized("uncuffedOther", target:GetName())
		else
			if (target:IsCuffed()) then
				return
			end

			local item = self:GetCuffItem(client)

			if (!item) then
				client:NotifyLocalized("cuffNoItem")
				return
			end

			item:Remove()

			self:SetCuffed(target, true, "item")
			client:NotifyLocalized("cuffedOther", target:GetName())
		end

		target:EmitSound("physics/metal/metal_solid_impact_hard" .. math.random(1, 3) .. ".wav", 60, math.random(92, 108))
	end

	function PLUGIN:OnCuffZoneDone(client, index)
		local action = client.ixCuffAction

		if (!action) then
			return
		end

		local target = action.target

		if (!IsValid(target) or !target:Alive() or !client:Alive() or client:IsCuffed()
		or target:IsCuffed() != action.uncuff or !self:CanReachTarget(client, target, 48)) then
			self:StopCuffAction(client, true)
			return
		end

		if (!self.cuffZones[index] or action.done[index]) then
			return
		end

		-- участок нельзя закончить быстрее, чем положено (с учётом оружия в руках)
		local zoneTime = math.max(ix.config.Get("cuffTime", 1.5) * self:GetCuffMultiplier(client), 0.05)

		if (CurTime() - action.last < zoneTime * 0.8) then
			return
		end

		action.done[index] = true
		action.count = action.count + 1
		action.last = CurTime()

		target:EmitSound("physics/metal/metal_solid_impact_soft" .. math.random(1, 3) .. ".wav", 55, math.random(92, 108))

		if (action.count >= #self.cuffZones) then
			self:FinishCuffAction(client, target, action.uncuff)
		end
	end

	net.Receive("ixCuffStart", function(_, client)
		PLUGIN:BeginCuffAction(client, net.ReadEntity())
	end)

	net.Receive("ixCuffZone", function(_, client)
		PLUGIN:OnCuffZoneDone(client, net.ReadUInt(4))
	end)

	net.Receive("ixCuffCancel", function(_, client)
		PLUGIN:StopCuffAction(client, false)
	end)
end

if (CLIENT) then
	local COLOR_DONE = Color(120, 200, 120)
	local COLOR_TEXT = Color(190, 190, 190)
	local COLOR_WARN = Color(230, 170, 80)

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

	-- игрок, на которого смотрит клиент (если он достаточно близко)
	function PLUGIN:GetCuffTarget(client)
		local trace = util.TraceLine({
			start = client:GetShootPos(),
			endpos = client:GetShootPos() + client:GetAimVector() * self.cuffRange,
			filter = client
		})

		local entity = trace.Entity

		if (IsValid(entity) and entity:IsPlayer() and entity:Alive()) then
			return entity
		end
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
		self.uncuff = false
	end

	function PANEL:Setup(entity, uncuff)
		self.entity = entity
		self.uncuff = uncuff

		for i, zone in ipairs(PLUGIN.cuffZones) do
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
			net.Start("ixCuffCancel")
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

		net.Start("ixCuffZone")
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

		if (!IsValid(entity) or !IsValid(client) or !client:Alive() or !entity:Alive() or client:IsCuffed()
		or entity:IsCuffed() != self.uncuff
		or client:GetShootPos():DistToSqr(entity:WorldSpaceCenter()) > (PLUGIN.cuffRange + 40) ^ 2) then
			self:Close(true)
			return
		end

		local dt = FrameTime()
		local eyePos = client:EyePos()
		local scale = ScrH() / 1080
		local cursorX, cursorY = self:CursorPos()
		local zoneTime = math.max(ix.config.Get("cuffTime", 1.5) * PLUGIN:GetCuffMultiplier(client), 0.05)

		-- marker positions follow the target's bones
		for i, zone in ipairs(PLUGIN.cuffZones) do
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

			-- the hand slipped off the spot, the action is interrupted
			if (!state.visible or dist > (state.radius * 2) ^ 2) then
				self.active = nil
			else
				state.progress = math.min(state.progress + dt / zoneTime, 1)

				if (CurTime() >= self.nextRustle) then
					self.nextRustle = CurTime() + math.Rand(0.22, 0.45)
					client:EmitSound("physics/metal/metal_solid_impact_soft" .. math.random(1, 3) .. ".wav",
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
		local client = LocalPlayer()

		surface.SetDrawColor(0, 0, 0, 70)
		surface.DrawRect(0, 0, width, height)

		DrawFade(0, 0, width, 240 * scale, 190, false)
		DrawFade(0, height - 200 * scale, width, 200 * scale, 190, true)

		-- header
		draw.SimpleText(L(self.uncuff and "cuffTitleUncuff" or "cuffTitleCuff"), "ixBigFont", width / 2, 70 * scale,
			color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 255)
		surface.DrawRect(width / 2 - 70 * scale, 100 * scale, 140 * scale, math.max(2, 2 * scale))

		draw.SimpleText(L("cuffSubtitle"), "ixSmallFont", width / 2, 122 * scale, COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

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

		draw.SimpleText(L("cuffProgress", self.doneCount, total), "ixSmallFont", width / 2, 172 * scale,
			COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		-- weapon in hands slows everything down
		if (IsValid(client) and PLUGIN:GetCuffMultiplier(client) > 1) then
			draw.SimpleText(L("cuffArmedHint"), "ixSmallFont", width / 2, 194 * scale,
				COLOR_WARN, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

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

					-- progress
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
							extra = L((self.uncuff and "uncuffStage" or "cuffStage") .. math.min(3, math.floor(state.progress * 3) + 1))
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
		draw.SimpleText(L("cuffHint"), "ixSmallFont", width / 2, height - 70 * scale,
			COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	vgui.Register("ixCuffAction", PANEL, "EditablePanel")

	-- F1 рядом с игроком запускает мини-игру; в остальных случаях открывается обычное меню
	function PLUGIN:PlayerBindPress(client, bind, pressed)
		bind = bind:lower()

		-- скованный не выбирает оружие
		if (client:IsCuffed() and (bind:find("slot") or bind:find("invprev") or bind:find("invnext"))) then
			return true
		end

		if (!pressed or !bind:find("gm_showhelp")) then
			return
		end

		if (IsValid(self.cuffPanel)) then
			return true
		end

		if (!client:Alive() or client:IsCuffed()) then
			return
		end

		local target = self:GetCuffTarget(client)

		if (!target) then
			return
		end

		if (!target:IsCuffed()) then
			local character = client:GetCharacter()
			local inventory = character and character:GetInventory()

			-- без наручников F1 открывает обычное меню
			if (!inventory or !inventory:HasItem("handcuffs")) then
				return
			end
		end

		net.Start("ixCuffStart")
			net.WriteEntity(target)
		net.SendToServer()

		return true
	end

	net.Receive("ixCuffBegin", function()
		local entity = net.ReadEntity()
		local uncuff = net.ReadBool()

		if (!IsValid(entity)) then
			return
		end

		if (IsValid(PLUGIN.cuffPanel)) then
			PLUGIN.cuffPanel:Remove()
		end

		PLUGIN.cuffPanel = vgui.Create("ixCuffAction")
		PLUGIN.cuffPanel:Setup(entity, uncuff)
	end)

	net.Receive("ixCuffStop", function()
		if (IsValid(PLUGIN.cuffPanel)) then
			PLUGIN.cuffPanel:Close(false)
		end
	end)

	-- руки за спиной (клиентская поза)
	function PLUGIN:ApplyCuffBones(client, cuffed)
		client.ixCuffBones = cuffed

		for name, angle in pairs(self.cuffedBones) do
			local bone = client:LookupBone(name)

			if (bone) then
				client:ManipulateBoneAngles(bone, cuffed and angle or Angle(0, 0, 0))
			end
		end
	end

	function PLUGIN:PrePlayerDraw(client)
		local cuffed = client:IsCuffed()

		if (cuffed != (client.ixCuffBones or false)) then
			self:ApplyCuffBones(client, cuffed)
		end
	end

	-- Настройка позы в реальном времени (меняет всех скованных игроков, которых вы видите).
	-- ix_cuffbone <ru|lu|rf|lf|rh|lh> <pitch> <yaw> <roll> [single]
	--   ru/lu = плечо правой/левой руки, rf/lf = предплечье, rh/lh = кисть.
	--   По умолчанию значения сразу зеркалятся на вторую руку (pitch и roll с обратным знаком),
	--   добавьте `single`, чтобы изменить только одну руку.
	-- ix_cuffbone_print - выводит готовую таблицу в консоль, чтобы вставить в PLUGIN.cuffedBones.
	local boneAliases = {
		ru = "ValveBiped.Bip01_R_UpperArm", lu = "ValveBiped.Bip01_L_UpperArm",
		rf = "ValveBiped.Bip01_R_Forearm", lf = "ValveBiped.Bip01_L_Forearm",
		rh = "ValveBiped.Bip01_R_Hand", lh = "ValveBiped.Bip01_L_Hand"
	}

	local mirrorAliases = {ru = "lu", lu = "ru", rf = "lf", lf = "rf", rh = "lh", lh = "rh"}
	local aliasOrder = {"ru", "lu", "rf", "lf", "rh", "lh"}

	concommand.Add("ix_cuffbone", function(client, command, args)
		local alias = tostring(args[1] or ""):lower()
		local name = boneAliases[alias]

		if (!name) then
			MsgN("Использование: ix_cuffbone <ru|lu|rf|lf|rh|lh> <pitch> <yaw> <roll> [single]")
			return
		end

		local pitch, yaw, roll = tonumber(args[2]) or 0, tonumber(args[3]) or 0, tonumber(args[4]) or 0

		PLUGIN.cuffedBones[name] = Angle(pitch, yaw, roll)

		if (tostring(args[5]):lower() != "single") then
			PLUGIN.cuffedBones[boneAliases[mirrorAliases[alias]]] = Angle(-pitch, yaw, -roll)
		end

		for _, ply in ipairs(player.GetAll()) do
			if (ply:IsCuffed()) then
				PLUGIN:ApplyCuffBones(ply, true)
			end
		end
	end)

	concommand.Add("ix_cuffbone_print", function()
		MsgN("PLUGIN.cuffedBones = {")

		for _, alias in ipairs(aliasOrder) do
			local name = boneAliases[alias]
			local angle = PLUGIN.cuffedBones[name] or Angle(0, 0, 0)

			MsgN(string.format("\t[\"%s\"] = Angle(%g, %g, %g)%s", name, angle.p, angle.y, angle.r,
				alias == "lh" and "" or ","))
		end

		MsgN("}")
	end)

	-- у скованного нет рук перед глазами
	function PLUGIN:PreDrawViewModel()
		local client = LocalPlayer()

		if (IsValid(client) and client:IsCuffed()) then
			return true
		end
	end

	function PLUGIN:HUDPaint()
		local client = LocalPlayer()

		if (!IsValid(client) or !client:IsCuffed()) then
			return
		end

		draw.SimpleText(L("cuffedHud"), "ixSmallFont", ScrW() / 2, ScrH() - 120 * (ScrH() / 1080),
			Color(220, 120, 120, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end