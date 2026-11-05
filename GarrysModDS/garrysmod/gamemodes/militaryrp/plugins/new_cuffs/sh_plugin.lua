local PLUGIN = PLUGIN

PLUGIN.name = "Handcuffs"
PLUGIN.author = "Claude"
PLUGIN.description = "Наручники: интерактивное надевание/снятие на F1, скованные руки, админ-команды."
PLUGIN.readme = [[
## Админ-команды
/PlyCuff <игрок>   - заковать
/PlyUncuff <игрок> - освободить
]]

-- дистанция, с которой можно начать (F1)
PLUGIN.cuffRange = 96

-- на каком расстоянии перед ведущим идёт ведомый
PLUGIN.leadDistance = 52

-- если ведомый оказался дальше этого расстояния от ведущего, его отпускает
-- (в юнитах: ~39 юнитов = 1 метр, 150 юнитов ≈ 3.8 м)
PLUGIN.leadMaxDistance = 150

-- участки тела, которые нужно осмотреть при обыске (F3); `bone2` + `frac` ставят маркер между двумя костями
PLUGIN.searchZones = {
	{name = "searchZoneJacket", bone = "ValveBiped.Bip01_Spine2"},
	{name = "searchZoneBelt", bone = "ValveBiped.Bip01_Pelvis"},
	{name = "searchZonePockets", bone = "ValveBiped.Bip01_R_Thigh", bone2 = "ValveBiped.Bip01_R_Calf", frac = 0.3},
	{name = "searchZonePouch", bone = "ValveBiped.Bip01_L_Thigh", bone2 = "ValveBiped.Bip01_L_Calf", frac = 0.3}
}

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
	cuffedHud = "Ваши руки скованы за спиной",
	cuffedLedHud = "Вас ведут за собой",
	cuffTitleLead = "ВЕСТИ ЗА СОБОЙ",
	leadStage1 = "Берёте под руку...",
	leadStage2 = "Крепко придерживаете...",
	leadStage3 = "Разворачиваете перед собой...",
	leadBusy = "Этого человека уже ведут.",
	leadAlready = "Вы уже ведёте другого человека. Отпустите его на F2.",
	leadStartedSelf = "Вас ведут за собой.",
	leadStartedOther = "Вы ведёте: %s.",
	leadStoppedSelf = "Вас больше не ведут.",
	leadStoppedOther = "Вы отпустили: %s.",
	cuffTitleSearch = "ОБЫСК",
	searchProgress = "Осмотрено %d из %d",
	searchZoneJacket = "Куртка",
	searchZoneBelt = "Пояс",
	searchZonePockets = "Карманы",
	searchZonePouch = "Подсумок",
	searchStage1 = "Нащупываете застёжку...",
	searchStage2 = "Расстёгиваете...",
	searchStage3 = "Перебираете содержимое...",
	searchBusy = "Этого человека уже обыскивают.",
	searchTargetStart = "Кто-то вас обыскивает!"
})

ix.config.Add("cuffTime", 1.5, "Сколько секунд занимает каждый участок при надевании и снятии наручников.", nil, {
	data = {min = 0.2, max = 10, decimals = 1},
	category = "Наручники"
})

ix.config.Add("cuffWeaponMultiplier", 2, "Во сколько раз дольше надеваются и снимаются наручники, если в руках оружие.", nil, {
	data = {min = 1, max = 5, decimals = 1},
	category = "Наручники"
})

ix.config.Add("cuffLeadTime", 1.5, "Сколько секунд занимает каждый участок, когда скованного берут за собой. Оружие в руках не влияет.", nil, {
	data = {min = 0.2, max = 10, decimals = 1},
	category = "Наручники"
})

ix.config.Add("cuffSearchTime", 1.5, "Сколько секунд занимает осмотр каждого участка при обыске скованного. Оружие в руках не влияет.", nil, {
	data = {min = 0.2, max = 10, decimals = 1},
	category = "Наручники"
})

-- shared
local playerMeta = FindMetaTable("Player")

function playerMeta:IsCuffed()
	return self:GetNetVar("ixCuffed", false) and true or false
end

-- скованного ведут за собой
function playerMeta:IsLed()
	return self:GetNetVar("ixLeader") != nil
end

-- игрок, который ведёт этого скованного (nil, если никто не ведёт)
function playerMeta:GetCuffLeader()
	local leader = self:GetNetVar("ixLeader")

	if (IsValid(leader)) then
		return leader
	end
end

-- во сколько раз дольше придётся возиться, если в руках оружие
function PLUGIN:GetCuffMultiplier(client)
	local weapon = client:GetActiveWeapon()

	if (IsValid(weapon) and !self.unarmedWeapons[weapon:GetClass()]) then
		return ix.config.Get("cuffWeaponMultiplier", 2)
	end

	return 1
end

-- конфиги времени для режимов, где оружие в руках не влияет на скорость
local fixedZoneTime = {lead = "cuffLeadTime", search = "cuffSearchTime"}

-- время на один участок: при ведении и обыске оружие в руках на него не влияет
function PLUGIN:GetZoneTime(client, mode)
	if (fixedZoneTime[mode]) then
		return math.max(ix.config.Get(fixedZoneTime[mode], 1.5), 0.05)
	end

	return math.max(ix.config.Get("cuffTime", 1.5) * self:GetCuffMultiplier(client), 0.05)
end

-- участки, которые нужно пройти в этом режиме мини-игры
function PLUGIN:GetZones(mode)
	return mode == "search" and self.searchZones or self.cuffZones
end

-- куда должен смотреть ведомый: туда же, куда смотрит ведущий
function PLUGIN:GetLeadAngles(client)
	local leader = client:GetCuffLeader()

	if (leader) then
		local angles = leader:EyeAngles()

		return Angle(angles.p, angles.y, 0)
	end

	-- ведущий не виден (далеко/вышел): остаёмся на последнем направлении
	return Angle(0, client:GetNetVar("ixLeadYaw", 0), 0)
end

-- ведущий и ведомый не сталкиваются (нужен включённый SetCustomCollisionCheck у обоих)
function PLUGIN:ShouldCollide(ent1, ent2)
	if (ent1:IsPlayer() and ent2:IsPlayer() and (ent1:IsLed() or ent2:IsLed())) then
		if (ent1:GetCuffLeader() == ent2 or ent2:GetCuffLeader() == ent1) then
			return false
		end
	end
end

-- кого ведёт этот игрок
function PLUGIN:GetLedPlayer(client)
	for _, ply in ipairs(player.GetAll()) do
		if (ply:GetNetVar("ixLeader") == client) then
			return ply
		end
	end
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

		-- ведомый: ни своего движения, ни прыжка, ни поворота камеры
		if (client:IsLed()) then
			cmd:SetForwardMove(0)
			cmd:SetSideMove(0)
			cmd:SetUpMove(0)
			cmd:SetMouseX(0)
			cmd:SetMouseY(0)
			cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(bit.bor(IN_JUMP, IN_DUCK, IN_SPEED))))
			cmd:SetViewAngles(self:GetLeadAngles(client))
		end
	end
end

-- скованный ходит чуть медленнее обычного и бегает трусцой (прыгать можно)
function PLUGIN:SetupMove(client, mv)
	if (client:IsCuffed()) then
		local multiplier = mv:KeyDown(IN_SPEED) and self.cuffedRunSpeed or self.cuffedSpeed
		local speed = mv:GetMaxClientSpeed() * multiplier

		mv:SetMaxClientSpeed(speed)
		mv:SetMaxSpeed(speed)

		local leader = client:GetCuffLeader()

		if (leader) then
			self:MoveLed(client, leader, mv)
		end
	end
end

-- ведомый идёт к точке перед ведущим, подстраиваясь под его скорость
function PLUGIN:MoveLed(client, leader, mv)
	local forward = Angle(0, leader:EyeAngles().y, 0):Forward()
	local diff = leader:GetPos() + forward * self.leadDistance - mv:GetOrigin()
	local velocity = leader:GetVelocity()
	local vertical = mv:GetVelocity().z

	diff.z = 0
	velocity.z = 0
	velocity = velocity + diff * 6

	if (velocity:Length() > 400) then
		velocity = velocity:GetNormalized() * 400
	end

	-- вертикальной скоростью занимается физика (ступеньки, падение)
	velocity.z = vertical
	mv:SetVelocity(velocity)
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

		-- заковали/освободили: ведомого больше не ведут, а скованный ведущий никого не ведёт
		self:SetLeader(client, nil, true)
		self:ReleaseLed(client, bSilent)

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

	-- вести скованного игрока за собой; leader = nil - отпустить
	function PLUGIN:SetLeader(client, leader, bSilent)
		local old = client:GetNetVar("ixLeader")

		if (old == nil and !IsValid(leader)) then
			return
		end

		if (IsValid(leader)) then
			local angles = Angle(0, leader:EyeAngles().y, 0)
			local goal = leader:GetPos() + angles:Forward() * self.leadDistance
			local mins, maxs = client:GetHull()
			local trace = util.TraceHull({
				start = leader:GetPos(),
				endpos = goal,
				mins = mins,
				maxs = maxs,
				filter = {leader, client},
				mask = MASK_PLAYERSOLID
			})

			-- ведомый сразу оказывается перед ведущим, если там есть место
			if (!trace.Hit) then
				client:SetPos(goal)
			end

			client:SetVelocity(-client:GetVelocity())
			client:SetNetVar("ixLeadYaw", angles.y)
			client:SetNetVar("ixLeader", leader)
			client:SnapEyeAngles(angles)

			-- у ведомого отключаются столкновения с игроками и предметами, иначе ведущего дёргает на ходу
			-- (группа коллизии передаётся клиентам, поэтому предсказание движения не расходится с сервером)
			client:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
			client:SetCustomCollisionCheck(true)
			leader:SetCustomCollisionCheck(true)
			client:CollisionRulesChanged()
			leader:CollisionRulesChanged()

			if (!bSilent) then
				client:NotifyLocalized("leadStartedSelf")
				leader:NotifyLocalized("leadStartedOther", client:GetName())
			end
		else
			client:SetNetVar("ixLeader", nil)
			client:SetNetVar("ixLeadYaw", nil)

			-- столкновения снова обычные
			client:SetCollisionGroup(COLLISION_GROUP_PLAYER)
			client:SetCustomCollisionCheck(false)
			client:CollisionRulesChanged()

			if (IsValid(old)) then
				old:SetCustomCollisionCheck(false)
				old:CollisionRulesChanged()
			end

			if (!bSilent) then
				client:NotifyLocalized("leadStoppedSelf")

				if (IsValid(old)) then
					old:NotifyLocalized("leadStoppedOther", client:GetName())
				end
			end
		end
	end

	-- отпускает всех, кого ведёт этот игрок
	function PLUGIN:ReleaseLed(client, bSilent)
		for _, ply in ipairs(player.GetAll()) do
			if (ply:GetNetVar("ixLeader") == client) then
				self:SetLeader(ply, nil, bSilent)
			end
		end
	end

	-- следим, чтобы ведомый не остался привязанным к ушедшему/мёртвому/скованному ведущему
	function PLUGIN:PlayerTick(client)
		if (!client:IsLed()) then
			return
		end

		local leader = client:GetCuffLeader()

		if (!leader or !leader:Alive() or leader:IsCuffed() or !client:Alive() or !client:IsCuffed()
		or leader:GetPos():DistToSqr(client:GetPos()) > self.leadMaxDistance ^ 2) then
			self:SetLeader(client, nil)
			return
		end

		-- другой код не должен вернуть ведомому столкновения
		if (client:GetCollisionGroup() != COLLISION_GROUP_DEBRIS_TRIGGER) then
			client:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
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
		self:ReleaseLed(client, true)
		self:SetLeader(client, nil, true)

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

	-- труп ведомого создаётся с его скоростью (до 400 ед/с) и импульсом от попадания,
	-- поэтому сразу после смерти обнуляем скорость всех частей трупа
	function PLUGIN:PlayerDeath(client)
		if (client:IsLed()) then
			local ragdoll = client:GetRagdollEntity()

			if (IsValid(ragdoll)) then
				for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
					local phys = ragdoll:GetPhysicsObjectNum(i)

					if (IsValid(phys)) then
						phys:SetVelocity(vector_origin)
						phys:AddAngleVelocity(-phys:GetAngleVelocity())
					end
				end
			end
		end

		self:ReleaseLed(client)
		self:SetLeader(client, nil, true)

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
		self:ReleaseLed(client, true)

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

	-- инвентарь, который открывается после обыска
	function PLUGIN:GetSearchInventory(target)
		local character = target:GetCharacter()

		return character and character:GetInventory()
	end

	-- request: "lead" (F2), "search" (F3) или что-то другое (F1: надеть/снять наручники)
	function PLUGIN:BeginCuffAction(client, target, request)
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

		-- F2 на того, кого уже ведёшь, отпускает его (расстояние не важно)
		if (request == "lead" and target:GetCuffLeader() == client) then
			self:SetLeader(target, nil)
			return
		end

		if (!self:CanReachTarget(client, target, 48)) then
			return
		end

		local mode = "cuff"

		if (request == "search") then
			local inventory = self:GetSearchInventory(target)

			if (!target:IsCuffed() or !inventory) then
				return
			end

			if (ix.storage.InUse(inventory)) then
				client:NotifyLocalized("searchBusy")
				return
			end

			mode = "search"
		elseif (request == "lead") then
			if (!target:IsCuffed()) then
				return
			end

			if (target:IsLed()) then
				client:NotifyLocalized("leadBusy")
				return
			end

			if (self:GetLedPlayer(client)) then
				client:NotifyLocalized("leadAlready")
				return
			end

			mode = "lead"
		elseif (target:IsCuffed()) then
			mode = "uncuff"
		end

		if (mode == "cuff" and !self:GetCuffItem(client)) then
			client:NotifyLocalized("cuffNoItem")
			return
		end

		if ((IsValid(target.ixCuffer) and target.ixCuffer != client) or target.ixCuffAction) then
			client:NotifyLocalized("cuffBusy")
			return
		end

		client.ixCuffAction = {
			target = target,
			mode = mode,
			done = {},
			count = 0,
			last = CurTime()
		}

		target.ixCuffer = client
		target:EmitSound("physics/metal/metal_solid_impact_soft" .. math.random(1, 3) .. ".wav", 55, math.random(92, 108))

		if (mode == "cuff") then
			target:NotifyLocalized("cuffTargetStart")
		elseif (mode == "search") then
			target:NotifyLocalized("searchTargetStart")
		end

		net.Start("ixCuffBegin")
			net.WriteEntity(target)
			net.WriteString(mode)
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

	function PLUGIN:FinishCuffAction(client, target, mode)
		self:StopCuffAction(client, false)

		if (mode == "lead") then
			if (target:IsCuffed() and !target:IsLed()) then
				self:SetLeader(target, client)
			end

			return
		end

		-- обыск закончен: обыскивающему открывается инвентарь скованного
		if (mode == "search") then
			local inventory = self:GetSearchInventory(target)

			if (!target:IsCuffed() or !inventory) then
				return
			end

			if (ix.storage.InUse(inventory)) then
				client:NotifyLocalized("searchBusy")
				return
			end

			ix.storage.Open(client, inventory, {
				entity = target,
				name = target:GetName(),
				searchTime = 0
			})

			return
		end

		if (mode == "uncuff") then
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
		or target:IsCuffed() != (action.mode != "cuff") or (action.mode == "lead" and target:IsLed())
		or !self:CanReachTarget(client, target, 48)) then
			self:StopCuffAction(client, true)
			return
		end

		if (!self:GetZones(action.mode)[index] or action.done[index]) then
			return
		end

		-- участок нельзя закончить быстрее, чем положено (с учётом оружия в руках)
		local zoneTime = self:GetZoneTime(client, action.mode)

		if (CurTime() - action.last < zoneTime * 0.8) then
			return
		end

		action.done[index] = true
		action.count = action.count + 1
		action.last = CurTime()

		if (action.mode == "search") then
			target:EmitSound("npc/combine_soldier/gear" .. math.random(1, 6) .. ".wav", 55, math.random(92, 108))
		else
			target:EmitSound("physics/metal/metal_solid_impact_soft" .. math.random(1, 3) .. ".wav", 55, math.random(92, 108))
		end

		if (action.count >= #self:GetZones(action.mode)) then
			self:FinishCuffAction(client, target, action.mode)
		end
	end

	net.Receive("ixCuffStart", function(_, client)
		local target = net.ReadEntity()
		local request = net.ReadString()

		PLUGIN:BeginCuffAction(client, target, request)
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

	-- заголовок и подписи этапов для каждого режима мини-игры
	local MODE_TITLE = {cuff = "cuffTitleCuff", uncuff = "cuffTitleUncuff", lead = "cuffTitleLead", search = "cuffTitleSearch"}
	local MODE_STAGE = {cuff = "cuffStage", uncuff = "uncuffStage", lead = "leadStage", search = "searchStage"}

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
		self.mode = "cuff"
	end

	function PANEL:Setup(entity, mode)
		self.entity = entity
		self.mode = mode

		for i, zone in ipairs(PLUGIN:GetZones(mode)) do
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
		or entity:IsCuffed() != (self.mode != "cuff") or (self.mode == "lead" and entity:IsLed())
		or client:GetShootPos():DistToSqr(entity:WorldSpaceCenter()) > (PLUGIN.cuffRange + 40) ^ 2) then
			self:Close(true)
			return
		end

		local dt = FrameTime()
		local eyePos = client:EyePos()
		local scale = ScrH() / 1080
		local cursorX, cursorY = self:CursorPos()
		local zoneTime = PLUGIN:GetZoneTime(client, self.mode)

		-- marker positions follow the target's bones
		for i, zone in ipairs(PLUGIN:GetZones(self.mode)) do
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
					local sound = self.mode == "search"
						and ("physics/cardboard/cardboard_box_impact_soft" .. math.random(1, 7))
						or ("physics/metal/metal_solid_impact_soft" .. math.random(1, 3))

					client:EmitSound(sound .. ".wav", 50, math.random(90, 115), 0.45, CHAN_ITEM)
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
		draw.SimpleText(L(MODE_TITLE[self.mode]), "ixBigFont", width / 2, 70 * scale,
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

		draw.SimpleText(L(self.mode == "search" and "searchProgress" or "cuffProgress", self.doneCount, total), "ixSmallFont", width / 2, 172 * scale,
			COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		-- weapon in hands slows everything down
		if (self.mode != "lead" and IsValid(client) and PLUGIN:GetCuffMultiplier(client) > 1) then
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
							extra = L(MODE_STAGE[self.mode] .. math.min(3, math.floor(state.progress * 3) + 1))
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

		-- F1 - надеть/снять наручники, F2 - повести скованного / отпустить, F3 - обыскать скованного
		local lead = bind:find("gm_showteam") != nil
		local search = bind:find("gm_showspare1") != nil

		if (!pressed or (!lead and !search and !bind:find("gm_showhelp"))) then
			return
		end

		if (IsValid(self.cuffPanel)) then
			return true
		end

		if (!client:Alive() or client:IsCuffed()) then
			return
		end

		-- F2 отпускает того, кого ведёшь (на него можно не смотреть)
		if (lead) then
			local led = self:GetLedPlayer(client)

			if (led) then
				net.Start("ixCuffStart")
					net.WriteEntity(led)
					net.WriteString("lead")
				net.SendToServer()

				return true
			end
		end

		local target = self:GetCuffTarget(client)

		if (!target) then
			return
		end

		-- F3 работает только на скованных
		if (search and !target:IsCuffed()) then
			return
		end

		-- F2 работает только на скованных, которых ещё никто не ведёт
		if (lead and (!target:IsCuffed() or target:IsLed())) then
			return
		end

		if (!lead and !search and !target:IsCuffed()) then
			local character = client:GetCharacter()
			local inventory = character and character:GetInventory()

			-- без наручников F1 открывает обычное меню
			if (!inventory or !inventory:HasItem("handcuffs")) then
				return
			end
		end

		net.Start("ixCuffStart")
			net.WriteEntity(target)
			net.WriteString(search and "search" or (lead and "lead" or "cuff"))
		net.SendToServer()

		return true
	end

	net.Receive("ixCuffBegin", function()
		local entity = net.ReadEntity()
		local mode = net.ReadString()

		if (!IsValid(entity)) then
			return
		end

		if (IsValid(PLUGIN.cuffPanel)) then
			PLUGIN.cuffPanel:Remove()
		end

		PLUGIN.cuffPanel = vgui.Create("ixCuffAction")
		PLUGIN.cuffPanel:Setup(entity, mode)
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

	-- на клиенте тоже включаем свою проверку столкновений для пары ведущий/ведомый,
	-- чтобы предсказание движения совпадало с сервером
	function PLUGIN:Think()
		if (CurTime() < (self.nextCollisionThink or 0)) then
			return
		end

		self.nextCollisionThink = CurTime() + 0.2

		local client = LocalPlayer()

		if (!IsValid(client)) then
			return
		end

		local other = client:GetCuffLeader() or self:GetLedPlayer(client)

		if (IsValid(other)) then
			client:SetCustomCollisionCheck(true)
			other:SetCustomCollisionCheck(true)
			self.collisionOther = other
		elseif (self.collisionOther) then
			client:SetCustomCollisionCheck(false)

			if (IsValid(self.collisionOther)) then
				self.collisionOther:SetCustomCollisionCheck(false)
			end

			self.collisionOther = nil
		end
	end

	-- ведомый не может двигать камерой: она повторяет взгляд ведущего
	function PLUGIN:CreateMove(cmd)
		local client = LocalPlayer()

		if (IsValid(client) and client:IsCuffed() and client:IsLed()) then
			cmd:SetViewAngles(PLUGIN:GetLeadAngles(client))
		end
	end

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

		draw.SimpleText(L(client:IsLed() and "cuffedLedHud" or "cuffedHud"), "ixSmallFont", ScrW() / 2, ScrH() - 120 * (ScrH() / 1080),
			Color(220, 120, 120, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end