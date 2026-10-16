local PLUGIN = PLUGIN

util.AddNetworkString("ixDownChoice")

-- ---------------------------------------------------------------------------
-- Состояние
-- ---------------------------------------------------------------------------

-- client.ixDown = {
--     start     = время падения,
--     choiceEnd = конец окна выбора,
--     deathTime = время смерти (nil, пока игрок не выбрал ожидание помощи;
--                 пока nil — другие игроки помочь не могут),
--     rescuer   = игрок, который сейчас оказывает помощь
-- }

function PLUGIN:StartDowned(client)
	if (client.ixDown or !client:Alive()) then return end
	if (!client:GetCharacter()) then return end
	if (hook.Run("CanPlayerBeDowned", client) == false) then return end

	self:StopRescue(client)

	if (client:InVehicle()) then
		client:ExitVehicle()
	end

	local curTime = CurTime()

	client.ixDown = {
		start = curTime,
		choiceEnd = curTime + ix.config.Get("downChoiceTime", 30)
	}

	client:SetNetVar("ixDowned", true)
	client:SetNetVar("ixDownChoiceEnd", client.ixDown.choiceEnd)
	client:SetNetVar("ixDownDeath", 0)
	client:SetNetVar("ixDownRescued", false)

	-- без таймера: рэгдолл держится, пока игрока не поднимут или он не умрёт
	client:SetRagdolled(true)
	self:LockRagdoll(client)

	hook.Run("OnPlayerDowned", client)
end

function PLUGIN:LockRagdoll(client)
	local ragdoll = client.ixRagdoll

	if (IsValid(ragdoll)) then
		-- блокирует встроенную команду /CharGetUp
		ragdoll.ixGrace = math.huge
	end
end

function PLUGIN:ClearDowned(client)
	if (!client.ixDown) then return end

	local rescuer = client.ixDown.rescuer

	if (IsValid(rescuer)) then
		self:StopRescue(rescuer)
	end

	client.ixDown = nil

	if (IsValid(client)) then
		client:SetNetVar("ixDowned", nil)
		client:SetNetVar("ixDownChoiceEnd", nil)
		client:SetNetVar("ixDownDeath", nil)
		client:SetNetVar("ixDownRescued", nil)
	end
end

function PLUGIN:BeginWait(client)
	local down = client.ixDown

	if (!down or down.deathTime) then return end

	down.deathTime = CurTime() + ix.config.Get("downWaitTime", 60)
	client:SetNetVar("ixDownDeath", down.deathTime)
end

function PLUGIN:KillDowned(client)
	if (!client.ixDown) then return end

	self:ClearDowned(client)
	hook.Run("OnPlayerBledOut", client)

	client:Kill()
end

function PLUGIN:Revive(client, rescuer)
	if (!client.ixDown) then return end

	self:ClearDowned(client)

	local health = math.max(ix.config.Get("downReviveHealth", 15), ix.config.Get("downHealth", 5))

	client:SetHealth(math.min(health, client:GetMaxHealth()))

	if (IsValid(client.ixRagdoll)) then
		client:SetRagdolled(false)
	end

	client:NotifyLocalized("downRevived")

	if (IsValid(rescuer)) then
		local character = client:GetCharacter()

		rescuer:NotifyLocalized("downRevivedOther", character and character:GetName() or client:Name())
	end

	hook.Run("OnPlayerRevived", client, rescuer)
end

-- ---------------------------------------------------------------------------
-- Оказание помощи
-- ---------------------------------------------------------------------------

function PLUGIN:FindRescueTarget(client)
	if (!client:KeyDown(IN_USE)) then return end
	if (ix.config.Get("downRequireCrouch", true) and !client:Crouching()) then return end
	if (IsValid(client.ixRagdoll)) then return end

	local start = client:GetShootPos()
	local trace = util.TraceLine({
		start = start,
		endpos = start + client:GetAimVector() * ix.config.Get("downReviveDistance", 90),
		filter = client,
		mask = MASK_SHOT
	})

	local entity = trace.Entity

	if (!IsValid(entity)) then return end

	local target = entity:IsPlayer() and entity or entity.ixPlayer

	if (IsValid(target) and target != client and target.ixDown) then
		return target
	end
end

function PLUGIN:GetReviveItem(client)
	local itemID = ix.config.Get("downReviveItem", "")

	if (itemID == "") then
		return true
	end

	local character = client:GetCharacter()
	local inventory = character and character:GetInventory()

	return inventory and inventory:HasItem(itemID) or false
end

function PLUGIN:StartRescue(client, target)
	local down = target.ixDown

	if (!down) then return end

	-- помощь возможна только после того, как пострадавший сам выбрал «Ждать помощи»
	if (!down.deathTime) then
		if ((client.ixDownNotWaiting or 0) < CurTime()) then
			client.ixDownNotWaiting = CurTime() + 3
			client:NotifyLocalized("downNotWaiting")
		end

		return
	end

	if (IsValid(down.rescuer) and down.rescuer != client) then return end
	if (hook.Run("CanPlayerReviveDowned", client, target) == false) then return end

	local itemID = ix.config.Get("downReviveItem", "")

	if (itemID != "" and !self:GetReviveItem(client)) then
		if ((client.ixDownNoItem or 0) < CurTime()) then
			local itemTable = ix.item.list[itemID]

			client.ixDownNoItem = CurTime() + 3
			client:NotifyLocalized("downNeedItem", itemTable and L(itemTable.name, client) or itemID)
		end

		return
	end

	local time = ix.config.Get("downReviveTime", 8)

	client.ixRescue = {target = target, finish = CurTime() + time}
	down.rescuer = client

	target:SetNetVar("ixDownRescued", true)
	client:SetAction("@downReviving", time)
end

function PLUGIN:StopRescue(client)
	local rescue = client.ixRescue

	if (!rescue) then return end

	client.ixRescue = nil

	if (IsValid(client)) then
		client:SetAction(false)
	end

	local target = rescue.target

	if (IsValid(target) and target.ixDown and target.ixDown.rescuer == client) then
		target.ixDown.rescuer = nil
		target:SetNetVar("ixDownRescued", false)
	end
end

function PLUGIN:FinishRescue(client)
	local rescue = client.ixRescue

	if (!rescue) then return end

	local target = rescue.target
	local itemID = ix.config.Get("downReviveItem", "")

	if (itemID != "") then
		local item = self:GetReviveItem(client)

		if (!item or item == true) then
			self:StopRescue(client)
			return
		end

		item:Remove()
	end

	self:StopRescue(client)

	if (IsValid(target)) then
		self:Revive(target, client)
	end
end

function PLUGIN:UpdateRescuer(client, curTime)
	local rescue = client.ixRescue
	local target = self:FindRescueTarget(client)

	if (!target) then
		if (rescue) then
			self:StopRescue(client)
		end

		return
	end

	if (rescue) then
		if (rescue.target != target) then
			self:StopRescue(client)
		elseif (curTime >= rescue.finish) then
			self:FinishRescue(client)
			return
		else
			return
		end
	end

	self:StartRescue(client, target)
end

-- ---------------------------------------------------------------------------
-- Основной цикл
-- ---------------------------------------------------------------------------

function PLUGIN:UpdatePlayer(client, curTime)
	local down = client.ixDown

	if (!client:Alive() or !client:GetCharacter()) then
		self:StopRescue(client)

		if (down) then
			self:ClearDowned(client)
		end

		return
	end

	if (!down) then
		local health = client:Health()

		if (health > 0 and health < ix.config.Get("downHealth", 5)) then
			self:StartDowned(client)
		else
			self:UpdateRescuer(client, curTime)
		end

		return
	end

	self:StopRescue(client)

	-- здоровье подняли извне (админ, скрипт) — считаем, что игрок стабилизирован
	if (client:Health() >= ix.config.Get("downHealth", 5)) then
		self:Revive(client)
		return
	end

	-- не даём встать раньше времени
	if (!IsValid(client.ixRagdoll)) then
		client:SetRagdolled(true)
	end

	self:LockRagdoll(client)

	if (!down.deathTime) then
		-- выбор обязателен: не выбрал за отведённое время — умирает.
		-- Ожидание помощи автоматически не включается никогда.
		if (curTime >= down.choiceEnd) then
			self:KillDowned(client)
		end
	elseif (curTime >= down.deathTime and !IsValid(down.rescuer)) then
		-- пока идёт оказание помощи, таймер смерти «замирает»
		self:KillDowned(client)
	end
end

function PLUGIN:Think()
	local curTime = CurTime()

	if ((self.nextDownScan or 0) > curTime) then return end
	self.nextDownScan = curTime + 0.1

	for _, client in ipairs(player.GetAll()) do
		self:UpdatePlayer(client, curTime)
	end
end

-- ---------------------------------------------------------------------------
-- Хуки
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Мгновенная смерть: выстрел в голову и взрывы
-- Такой урон не вводит в критическое состояние — игрок умирает сразу и спасти
-- его нельзя. Включается настройками downKillOnHeadshot / downKillOnExplosion.
-- ---------------------------------------------------------------------------

local EXPLOSION_TYPES = bit.bor(DMG_BLAST, DMG_BLAST_SURFACE)
local MELEE_TYPES = bit.bor(DMG_SLASH, DMG_CLUB)

-- попал ли удар в голову рэгдолла (для лежащих игроков, у которых нет хитгрупп)
local function IsRagdollHeadHit(ragdoll, dmgInfo)
	if (!dmgInfo:IsBulletDamage() and bit.band(dmgInfo:GetDamageType(), MELEE_TYPES) == 0) then
		return false
	end

	local bone = ragdoll:LookupBone("ValveBiped.Bip01_Head1")

	if (!bone) then return false end

	local headPhys = ragdoll:TranslateBoneToPhysBone(bone)

	if (!headPhys or headPhys < 0) then return false end

	local pos = dmgInfo:GetDamagePosition()
	local nearest, nearestDist

	for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local phys = ragdoll:GetPhysicsObjectNum(i)

		if (IsValid(phys)) then
			local dist = phys:GetPos():DistToSqr(pos)

			if (!nearestDist or dist < nearestDist) then
				nearest, nearestDist = i, dist
			end
		end
	end

	return nearest == headPhys
end

function PLUGIN:IsInstantKill(client, dmgInfo)
	if (ix.config.Get("downKillOnExplosion", true) and bit.band(dmgInfo:GetDamageType(), EXPLOSION_TYPES) != 0) then
		return true
	end

	if (ix.config.Get("downKillOnHeadshot", true) and (client.ixHeadHit or 0) > CurTime()) then
		return true
	end

	return false
end

-- хитгруппа обычного (стоящего) игрока: приходит до EntityTakeDamage
function PLUGIN:ScalePlayerDamage(client, hitGroup, dmgInfo)
	if (hitGroup == HITGROUP_HEAD) then
		client.ixHeadHit = CurTime() + 0.2
	end
end

function PLUGIN:EntityTakeDamage(entity, dmgInfo)
	if (!IsValid(entity)) then return end

	-- удар по рэгдоллу игрока: Helix передаёт его самому игроку, отметим попадание в голову
	if (entity:IsRagdoll()) then
		local owner = entity.ixPlayer

		if (IsValid(owner) and IsRagdollHeadHit(entity, dmgInfo)) then
			owner.ixHeadHit = CurTime() + 0.2
		end

		return
	end

	if (!entity:IsPlayer() or !entity:GetCharacter()) then return end

	if (entity.ixDown) then
		-- лежачего добивает голова или взрыв — даже при включённой неуязвимости
		if (dmgInfo:GetDamage() > 0 and self:IsInstantKill(entity, dmgInfo)) then
			-- с запасом на броню, чтобы смерть была гарантированной
			dmgInfo:SetDamage(math.max(dmgInfo:GetDamage(), (entity:Health() + entity:Armor()) * 5 + 10))
			return
		end

		if (ix.config.Get("downInvulnerable", true)) then
			return true
		end

		return
	end

	if (!ix.config.Get("downLethalToDown", true)) then return end
	if (hook.Run("CanPlayerBeDowned", entity, dmgInfo) == false) then return end

	local health = entity:Health()

	if (health - dmgInfo:GetDamage() < 1) then
		-- смертельный удар в голову или взрыв — настоящая смерть без критического состояния
		if (self:IsInstantKill(entity, dmgInfo)) then
			return
		end

		-- обычный смертельный удар → оставляем 1 HP, дальше игрока подхватит основной цикл
		dmgInfo:SetDamage(math.max(health - 1, 0))
	end
end

function PLUGIN:PlayerDeath(client)
	self:StopRescue(client)
	self:ClearDowned(client)
end

function PLUGIN:PlayerDisconnected(client)
	self:StopRescue(client)
	self:ClearDowned(client)
end

function PLUGIN:PlayerLoadedCharacter(client)
	self:StopRescue(client)
	self:ClearDowned(client)
end

function PLUGIN:CanPlayerInteractItem(client)
	if (client.ixDown) then
		return false
	end
end

-- E по лежащему игроку не должна ни брать его в руки, ни вызывать другие действия
function PLUGIN:PlayerUse(client, entity)
	if (IsValid(entity) and (entity.ixPlayer and entity.ixPlayer.ixDown or (entity:IsPlayer() and entity.ixDown))) then
		return false
	end
end

function PLUGIN:AllowPlayerPickup(client, entity)
	if (IsValid(entity) and entity.ixPlayer and entity.ixPlayer.ixDown) then
		return false
	end
end

net.Receive("ixDownChoice", function(_, client)
	local down = client.ixDown

	if (!down) then return end

	local die = net.ReadBool()

	if (die) then
		PLUGIN:KillDowned(client)
	elseif (!down.deathTime) then
		PLUGIN:BeginWait(client)
	end
end)
