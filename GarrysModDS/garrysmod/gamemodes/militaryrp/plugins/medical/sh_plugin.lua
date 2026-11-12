PLUGIN.name = "Medical"
PLUGIN.author = "Claude"
PLUGIN.description = "Повреждения по конечностям, кровотечения, болезни, медикаменты и интерфейс состояния тела."

ix.medical = ix.medical or {}

-- конфиг (libs/sh_medical_config.lua) Helix подгружает раньше items/ и sh_plugin.lua,
-- иначе предметы не смогут прочитать ix.medical.config на момент своей загрузки

local config = ix.medical.config

ix.medical.limbsByID = {}

for _, limb in ipairs(config.limbs) do
	ix.medical.limbsByID[limb.id] = limb
end

local limbsByID = ix.medical.limbsByID

-- ключ состояния: id или id:limb для состояний, привязанных к конечности
function ix.medical.Key(id, limbID)
	return limbID and (id .. ":" .. limbID) or id
end

function ix.medical.GetLimbHP(state, limbID)
	local limb = limbsByID[limbID]

	return state.limbs[limbID] or (limb and limb.maxHP or 0)
end

-- минимальное время, за которое процедуру вообще можно выполнить (сервер отсекает «мгновенные» ответы)
function ix.medical.ProcedureMinTime(proc, client)
	local total = 0

	for _, step in ipairs(proc.steps) do
		if (step.type == "hold") then
			total = total + (step.time or 1)
		elseif (step.type == "stitch") then
			total = total + (step.count or 5) * 0.35
		elseif (step.type == "tension") then
			total = total + 0.6
		else
			total = total + 0.3 * (step.hits or 1)
		end
	end

	-- чем выше атрибут «Медицинские знания», тем быстрее можно закончить (см. attributes/sh_medical.lua)
	local mul = (client and ix.medical.GetSelfHealMultiplier) and ix.medical.GetSelfHealMultiplier(client) or 1

	return total * 0.75 / mul
end

-- насколько состояние ещё «в силе» (1 — не лечили, меньше — идёт курс лечения)
function ix.medical.Severity(cond)
	return 1 - (cond.treat or 0) * ((config.treatment or {}).ease or 0.6)
end

-- итоговые эффекты состояния: множитель скорости, запрет бега/прыжка, тряска прицела
function ix.medical.Evaluate(state)
	local speed, noSprint, noJump, sway = 1, false, false, false
	local analgesia = false

	for _, cond in pairs(state.cond) do
		if (cond.id == "analgesia") then
			analgesia = true

			break
		end
	end

	for _, cond in pairs(state.cond) do
		local def = config.conditions[cond.id]

		if (def and !(analgesia and def.kind == "injury")) then
			local limb = cond.limb and limbsByID[cond.limb]

			local sev = ix.medical.Severity(cond)

			if (def.speed) then speed = speed * (1 - (1 - def.speed) * sev) end
			if (def.noSprint) then noSprint = true end
			if (def.noJump) then noJump = true end

			if (limb and limb.group == "leg") then
				if (def.legSpeed) then speed = speed * (1 - (1 - def.legSpeed) * sev) end
				if (def.legNoSprint) then noSprint = true end
				if (def.legNoJump) then noJump = true end
			elseif (limb and limb.group == "arm" and def.armSway) then
				sway = true
			end
		end
	end

	-- конечность с нулевым HP
	if (!analgesia) then
		for _, limb in ipairs(config.limbs) do
			if (ix.medical.GetLimbHP(state, limb.id) <= 0) then
				if (limb.group == "leg") then
					speed = speed * 0.7
					noSprint = true
					noJump = true
				elseif (limb.group == "arm") then
					sway = true
				end
			end
		end
	end

	return math.max(speed, config.minSpeed), noSprint, noJump, sway
end

-- может ли медикамент что-то дать (на конечность limbID для target = "limb").
-- возвращает true либо false и причину
function ix.medical.CanHelp(state, med, limbID)
	if (!med) then
		return false, "Это не медицинский предмет."
	end

	local limb

	if (med.target == "limb") then
		limb = limbID and limbsByID[limbID]

		if (!limb) then
			return false, "Перетащите на нужную часть тела."
		end

		if (med.groups and !table.HasValue(med.groups, limb.group)) then
			return false, "Это нельзя применить на эту часть тела."
		end

		if (med.heal and ix.medical.GetLimbHP(state, limbID) < limb.maxHP) then
			return true
		end
	end

	for _, cond in pairs(state.cond) do
		local def = config.conditions[cond.id]
		local relevant

		if (med.target == "limb") then
			relevant = def and def.perLimb and cond.limb == limbID
		else
			relevant = def != nil
		end

		if (relevant and ((med.cures and med.cures[cond.id]) or (med.downgrade and med.downgrade[cond.id])
		or (med.reduce and med.reduce[cond.id] and cond.left))) then
			return true
		end
	end

	if (med.buff and !state.cond[med.buff.id]) then
		return true
	end

	-- препарат с водой (капельница, регидрон) полезен и тому, кто просто хочет пить
	if (med.thirst) then
		local client = CLIENT and LocalPlayer() or state.owner

		if (IsValid(client) and client.GetThirstVar and client:GetThirstVar(true) < 85) then
			return true
		end
	end

	if (med.healHealth) then
		local client = CLIENT and LocalPlayer() or state.owner

		if (IsValid(client) and client:Health() < client:GetMaxHealth()) then
			return true
		end
	end

	return false, "Сейчас это ничего не даст."
end

-- замедление и запрет прыжка/бега по состоянию (считается на сервере и приходит клиенту для предсказания)
function PLUGIN:SetupMove(client, mv, cmd)
	local med = client:GetLocalVar("med")

	if (!med) then
		return
	end

	if (med.noSprint) then
		local walk = client:GetWalkSpeed()

		if (mv:GetMaxClientSpeed() > walk) then
			mv:SetMaxClientSpeed(walk)
			mv:SetMaxSpeed(walk)
		end
	end

	local speed = med.speed or 1

	if (speed < 1) then
		mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * speed)
		mv:SetMaxSpeed(mv:GetMaxSpeed() * speed)
	end

	if (med.noJump and bit.band(mv:GetButtons(), IN_JUMP) != 0) then
		mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP)))
	end
end

ix.util.Include("sh_commands.lua")
ix.util.Include("sv_medical.lua")
ix.util.Include("cl_medical.lua")
ix.util.Include("cl_procedure.lua")
ix.util.Include("cl_effects.lua")