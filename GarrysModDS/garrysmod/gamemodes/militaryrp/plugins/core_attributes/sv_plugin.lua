-- ============================================================
--  Сила: подъём предметов и сбивание с ног
-- ============================================================

-- Слишком тяжёлые для вашей Силы предметы руки не поднимут.
-- Возврат nil оставляет решение стандартной проверке Helix.
function PLUGIN:CanPlayerHoldObject(client, entity)
	local physics = entity:GetPhysicsObject()

	if (IsValid(physics) and physics:GetMass() > ix.coreattrs.GetHoldLimit(client)) then
		if ((client.ixHoldWarn or 0) < CurTime()) then
			client.ixHoldWarn = CurTime() + 2
			client:Notify("Слишком тяжело, вам не хватает силы.")
		end

		return false
	end
end

-- Сильный удар кулаком может сбить игрока с ног.
function PLUGIN:PlayerThrowPunch(client, trace)
	local target = trace.Entity

	if (!IsValid(target) or !target:IsPlayer() or !target:GetCharacter() or !client:GetCharacter()) then
		return
	end

	if (IsValid(target.ixRagdoll) or (target.ixKnockGrace or 0) > CurTime()) then
		return
	end

	local chance = ix.coreattrs.GetKnockdownChance(client, target)

	if (chance > 0 and math.random() < chance) then
		local time = ix.config.Get("strengthKnockdownTime", 4)

		-- После падения у цели короткая неуязвимость к повторному сбиванию.
		target.ixKnockGrace = CurTime() + time + 10
		target:SetRagdolled(true, time)

		client:Notify("Вы сбили противника с ног!")
		target:Notify("Вас сбили с ног!")

		client:GetCharacter():UpdateAttrib("str", ix.coreattrs.perks.training.knockdownStr)
	end
end

-- ============================================================
--  Выносливость: стойкость к урону
-- ============================================================
function PLUGIN:EntityTakeDamage(entity, dmgInfo)
	if (IsValid(entity) and entity:IsPlayer() and !dmgInfo:IsFallDamage()) then
		local reduction = ix.coreattrs.GetDamageReduction(entity)

		if (reduction > 0) then
			dmgInfo:ScaleDamage(1 - reduction)
		end
	end
end
