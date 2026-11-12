local PLUGIN = PLUGIN
local config = ix.medical.config
local limbsByID = ix.medical.limbsByID
local Key = ix.medical.Key

-- иконки и силуэт должны скачаться клиентами
for _, limb in ipairs(config.limbs) do
	local path = "materials/medical/body/" .. limb.id .. ".png"

	if (file.Exists(path, "GAME")) then
		resource.AddFile(path)
	end
end

local iconsAdded = {}

for _, def in pairs(config.conditions) do
	local path = "materials/medical/icons/" .. def.icon .. ".png"

	if (!iconsAdded[path] and file.Exists(path, "GAME")) then
		iconsAdded[path] = true
		resource.AddFile(path)
	end
end

util.AddNetworkString("ixMedProcBegin") -- сервер → клиент: открыть мини-игру
util.AddNetworkString("ixMedProcDone") -- клиент → сервер: мини-игра завершена (ошибки)
util.AddNetworkString("ixMedProcCancel") -- клиент → сервер: игрок отказался
util.AddNetworkString("ixMedProcStop") -- сервер → клиент: процедура прервана

local COUGH = {
	"ambient/voices/cough1.wav",
	"ambient/voices/cough2.wav",
	"ambient/voices/cough3.wav",
	"ambient/voices/cough4.wav"
}

--[[
	Состояние игрока: client.ixMed = {limbs = {id = hp}, cond = {key = {id, limb, left, age, rolled}}, owner = client}
	В limbs хранятся только повреждённые конечности (нет записи = полное здоровье).
	Состояние сохраняется в данных персонажа (character:GetData("medical")) и отправляется владельцу
	через client:SetLocalVar("med", ...).
]]

local function NewState(client)
	return {limbs = {}, cond = {}, owner = client}
end

function ix.medical.GetState(client)
	if (!client.ixMed) then
		client.ixMed = NewState(client)
	end

	return client.ixMed
end

local function Dirty(client)
	client.ixMedDirty = true
	client.ixMedSync = true
end

-- прервать идущую процедуру лечения (ранили, смерть, смена персонажа)
local function StopProcedure(client, tellClient)
	if (!client.ixMedProc) then
		return false
	end

	client.ixMedProc = nil
	client.ixMedBusy = nil

	if (tellClient and IsValid(client)) then
		net.Start("ixMedProcStop")
		net.Send(client)
	end

	return true
end

-- связь с hunger_system: потеря (минус) или прирост (плюс) сытости/воды, в % шкалы.
-- Если плагин голода не загружен, функции просто не найдутся и ничего не произойдёт.
local function AddNeeds(client, hunger, thirst)
	if (hunger and hunger != 0 and client.AddHungerVar) then
		client:AddHungerVar(hunger)
	end

	if (thirst and thirst != 0 and client.AddThirstVar) then
		client:AddThirstVar(thirst)
	end
end

local function Load(client, character)
	local state = NewState(client)
	local saved = character:GetData("medical")

	if (istable(saved)) then
		for id, hp in pairs(saved.limbs or {}) do
			local limb = limbsByID[id]

			if (limb and isnumber(hp) and hp < limb.maxHP) then
				state.limbs[id] = math.Clamp(hp, 0, limb.maxHP)
			end
		end

		for key, cond in pairs(saved.cond or {}) do
			local def = istable(cond) and config.conditions[cond.id]

			if (def and (!def.perLimb or limbsByID[cond.limb])) then
				state.cond[key] = {
					id = cond.id,
					limb = def.perLimb and cond.limb or nil,
					left = cond.left,
					age = cond.age or 0,
					rolled = cond.rolled,
					treat = isnumber(cond.treat) and math.Clamp(cond.treat, 0, 1) or nil
				}
			end
		end
	end

	client.ixMed = state
end

local function Save(client)
	local character = client:GetCharacter()
	local state = client.ixMed

	if (!character or !state) then
		return
	end

	local data = {limbs = table.Copy(state.limbs), cond = {}}

	for key, cond in pairs(state.cond) do
		data.cond[key] = {id = cond.id, limb = cond.limb, left = cond.left, age = cond.age, rolled = cond.rolled, treat = cond.treat}
	end

	character:SetData("medical", data, true)
	client.ixMedDirty = false
end

local function Sync(client)
	local state = ix.medical.GetState(client)
	local speed, noSprint, noJump, sway = ix.medical.Evaluate(state)
	local cond = {}

	for key, c in pairs(state.cond) do
		cond[key] = {id = c.id, limb = c.limb, left = c.left and math.ceil(c.left) or nil, treat = c.treat}
	end

	client:SetLocalVar("med", {
		stamp = CurTime(), -- момент отправки: клиент досчитывает оставшееся время сам
		limbs = table.Copy(state.limbs),
		cond = cond,
		speed = speed,
		noSprint = noSprint,
		noJump = noJump,
		sway = sway
	})

	client.ixMedSync = false
end

-- случайная конечность с учётом весов; groups — {leg = true} чтобы ограничить группы
local function RandomLimb(groups)
	local total = 0

	for _, limb in ipairs(config.limbs) do
		if (!groups or groups[limb.group]) then
			total = total + limb.weight
		end
	end

	local roll = math.Rand(0, total)

	for _, limb in ipairs(config.limbs) do
		if (!groups or groups[limb.group]) then
			roll = roll - limb.weight

			if (roll <= 0) then
				return limb.id
			end
		end
	end

	return config.limbs[1].id
end

--[[
	СОСТОЯНИЯ
]]
function ix.medical.HasCondition(client, id, limbID)
	return ix.medical.GetState(client).cond[Key(id, limbID)] != nil
end

function ix.medical.AddCondition(client, id, limbID, bSilent)
	local def = config.conditions[id]

	if (!IsValid(client) or !client:GetCharacter() or !def) then
		return false
	end

	local state = ix.medical.GetState(client)

	if (def.perLimb) then
		if (!limbID or !limbsByID[limbID]) then
			limbID = RandomLimb()
		end
	else
		limbID = nil
	end

	-- сильное кровотечение вытесняет слабое, а слабое поверх сильного не накладывается
	if (id == "bleed_light" and state.cond[Key("bleed_heavy", limbID)]) then
		return false
	end

	if (id == "bleed_heavy") then
		state.cond[Key("bleed_light", limbID)] = nil
	end

	local key = Key(id, limbID)
	local existing = state.cond[key]

	if (existing) then
		if (def.duration) then
			existing.left = def.duration
		end

		existing.treat = nil -- рецидив: курс лечения начинается заново

		Dirty(client)
		Sync(client)

		return true
	end

	state.cond[key] = {id = id, limb = limbID, left = def.duration, age = 0}

	if (!bSilent) then
		local limbName = limbID and (" (" .. limbsByID[limbID].name .. ")") or ""

		if (def.kind == "disease") then
			client:Notify("Вы заболели: " .. def.name .. limbName .. ".")
		elseif (def.kind == "buff") then
			client:Notify("Эффект: " .. def.name .. ".")
		else
			client:Notify("Получено: " .. def.name .. limbName .. ".")
		end
	end

	-- рвота и т.п.: разовая потеря сытости/воды в момент заболевания
	if (def.onset) then
		AddNeeds(client, def.onset.hunger, def.onset.thirst)

		if (def.onset.text and !bSilent) then
			client:Notify(def.onset.text)
		end
	end

	Dirty(client)
	Sync(client)

	hook.Run("MedicalConditionAdded", client, id, limbID)

	return true
end

function ix.medical.RemoveCondition(client, id, limbID)
	local state = ix.medical.GetState(client)
	local key = Key(id, limbID)

	if (!state.cond[key]) then
		return false
	end

	state.cond[key] = nil

	Dirty(client)
	Sync(client)

	hook.Run("MedicalConditionRemoved", client, id, limbID)

	return true
end

--[[
	ЗДОРОВЬЕ КОНЕЧНОСТЕЙ
]]
local function OnLimbDown(client, limb)
	client:Notify(limb.name .. " выведена из строя.")

	if (limb.group == "arm" or limb.group == "leg") then
		ix.medical.AddCondition(client, "fracture", limb.id)
	end

	if (limb.vital) then
		timer.Simple(0, function()
			if (IsValid(client) and client:Alive()) then
				client:Kill()
			end
		end)
	end
end

function ix.medical.DamageLimb(client, limbID, amount)
	local limb = limbsByID[limbID]

	if (!limb or amount <= 0) then
		return
	end

	local state = ix.medical.GetState(client)
	local before = ix.medical.GetLimbHP(state, limbID)
	local after = math.max(before - amount, 0)

	state.limbs[limbID] = after

	Dirty(client)

	if (before > 0 and after <= 0) then
		OnLimbDown(client, limb)
	end
end

function ix.medical.HealLimb(client, limbID, amount)
	local limb = limbsByID[limbID]

	if (!limb or amount <= 0) then
		return
	end

	local state = ix.medical.GetState(client)
	local hp = math.min(ix.medical.GetLimbHP(state, limbID) + amount, limb.maxHP)

	state.limbs[limbID] = hp < limb.maxHP and hp or nil

	Dirty(client)
end

-- полностью вылечить игрока (админ-команда, респавн)
function ix.medical.Reset(client)
	client.ixMed = NewState(client)
	client.ixMedHAcc = 0

	Dirty(client)
	Sync(client)
	Save(client)
end

local function HasBit(value, mask)
	return bit.band(value, mask) != 0
end

-- реакция на полученный урон: HP конечности, кровотечение, переломы, сотрясение, ожоги
function ix.medical.OnDamage(client, limbID, amount, dmginfo)
	local limb = limbsByID[limbID]
	local rules = config.damage
	local dtype = dmginfo:GetDamageType()

	ix.medical.DamageLimb(client, limbID, amount)

	if (HasBit(dtype, rules.bleedMask)) then
		local chance = math.Clamp(rules.bleedBase + amount * rules.bleedPerDamage, 0, 0.95)

		if (math.random() < chance) then
			local heavy = amount >= rules.heavyDamage or math.random() < rules.heavyChance

			ix.medical.AddCondition(client, heavy and "bleed_heavy" or "bleed_light", limbID)
		end
	end

	if (limb.group == "leg" and HasBit(dtype, DMG_FALL) and amount >= rules.fractureFall and math.random() < 0.6) then
		ix.medical.AddCondition(client, "fracture", limbID)
	elseif ((limb.group == "leg" or limb.group == "arm") and HasBit(dtype, bit.bor(DMG_CLUB, DMG_CRUSH))
	and amount >= rules.fractureBlunt and math.random() < 0.3) then
		ix.medical.AddCondition(client, "fracture", limbID)
	end

	if (limb.group == "head" and amount >= rules.concussion
	and HasBit(dtype, bit.bor(DMG_BULLET, DMG_CLUB, DMG_BLAST, DMG_CRUSH)) and math.random() < 0.4) then
		ix.medical.AddCondition(client, "concussion")
	end

	if (HasBit(dtype, DMG_BLAST) and amount >= rules.contusion and math.random() < 0.6) then
		ix.medical.AddCondition(client, "contusion")
	end

	if (HasBit(dtype, bit.bor(DMG_BURN, DMG_SLOWBURN, DMG_PLASMA)) and math.random() < 0.15) then
		ix.medical.AddCondition(client, "burn", limbID)
	end
end

--[[
	МЕДИКАМЕНТЫ
]]
-- «грязный» медикамент: осложнения не проявляются сразу, а через dirtyDelay секунд
-- (болезни «на конечность», вроде заражения раны, садятся на ту же часть тела)
local function RollDirtyRisks(client, med, limbID, quality)
	local dirty = med.dirty
	local risks = dirty and dirty.risks or {}
	local riskMul = 1

	if (quality) then
		-- небрежная работа: у «грязных» препаратов осложнения вероятнее,
		-- а плохо наложенная повязка или шина может занести инфекцию и у чистых
		riskMul = 2 - quality

		if (quality < 0.6 and med.target == "limb") then
			risks = table.Copy(risks)
			risks.infection = math.max(risks.infection or 0, (0.6 - quality) * 0.4)
		end
	end

	if (!next(risks)) then
		return
	end

	dirty = {risks = risks}

	local character = client:GetCharacter()
	local scale = config.dirtyRiskScale or 1
	local delay = config.dirtyDelay or {30, 120}

	for id, chance in pairs(dirty.risks) do
		if (config.conditions[id] and math.random() < chance * scale * riskMul) then
			timer.Simple(math.Rand(delay[1], delay[2]), function()
				if (!IsValid(client) or !client:Alive() or client:GetCharacter() != character) then
					return
				end

				ix.medical.AddCondition(client, id, limbID)
			end)
		end
	end
end

local function ApplyMedication(client, med, limbID, quality)
	local state = ix.medical.GetState(client)
	local removed, added, treated = {}, {}, {}

	-- у «грязных» препаратов эффект слабее, а лечение срабатывает не всегда
	local dirty = med.dirty
	local power = dirty and (dirty.power or 0.5) or 1
	local cureChance = dirty and (dirty.cure or 1) or 1
	local failed = 0

	-- качество выполнения процедуры (мини-игры): небрежная работа слабее и реже срабатывает
	if (quality) then
		power = power * (0.5 + 0.5 * quality)
		cureChance = cureChance * (0.6 + 0.4 * quality)
	end

	for key, cond in pairs(state.cond) do
		local def = config.conditions[cond.id]
		local relevant

		if (med.target == "limb") then
			relevant = def and def.perLimb and cond.limb == limbID
		else
			relevant = def != nil
		end

		if (relevant) then
			if (med.cures and med.cures[cond.id]) then
				if (math.random() <= cureChance) then
					if (def.courses) then
						-- курс лечения: каждое применение добавляет прогресс, вылечивается по достижении 100%
						cond.treat = math.min((cond.treat or 0) + (med.potency or 1) * power / def.courses, 1)

						if (cond.treat >= 0.999) then
							removed[#removed + 1] = key
						end

						treated[#treated + 1] = {def.name, math.floor(cond.treat * 100 + 0.5), cond.treat >= 0.999}
					else
						removed[#removed + 1] = key
					end
				else
					failed = failed + 1
				end
			elseif (med.downgrade and med.downgrade[cond.id]) then
				if (math.random() <= cureChance) then
					removed[#removed + 1] = key
					added[#added + 1] = {med.downgrade[cond.id], cond.limb}
				else
					failed = failed + 1
				end
			elseif (med.reduce and med.reduce[cond.id] and cond.left) then
				cond.left = cond.left * (1 - (1 - med.reduce[cond.id]) * power)
			end
		end
	end

	for _, key in ipairs(removed) do
		state.cond[key] = nil
	end

	for _, entry in ipairs(added) do
		ix.medical.AddCondition(client, entry[1], entry[2], true)
	end

	if (med.heal and limbID) then
		ix.medical.HealLimb(client, limbID, math.max(math.floor(med.heal * power + 0.5), 1))
	end

	if (med.healHealth) then
		client:SetHealth(math.min(client:GetMaxHealth(), client:Health() + math.floor(med.healHealth * power + 0.5)))
	end

	if (med.thirst) then
		AddNeeds(client, nil, med.thirst * power)
	end

	if (med.buff) then
		ix.medical.AddCondition(client, med.buff.id, nil, true)

		local buff = state.cond[Key(med.buff.id)]
		local duration = med.buff.duration or (config.conditions[med.buff.id] or {}).duration

		if (buff and duration) then
			buff.left = duration * power
		end
	end

	Dirty(client)
	Sync(client)

	client:EmitSound("items/smallmedkit1.wav", 60)
	client:Notify("Применено: " .. med.name .. "." .. (!quality and "" or (quality >= 0.95 and " Сделано идеально."
		or (quality >= 0.6 and " Сделано добротно." or " Сделано небрежно."))))

	for _, entry in ipairs(treated) do
		client:Notify(entry[3] and ("Вылечено: " .. entry[1] .. ".") or ("Лечение: " .. entry[1] .. " — " .. entry[2] .. "%."))
	end

	if (failed > 0) then
		client:Notify(#removed > 0 and "Средство подействовало лишь частично." or "Средство не помогло.")
	end

	RollDirtyRisks(client, med, limbID, quality)

	hook.Run("MedicalMedicationUsed", client, med, limbID)
end

-- применить предмет-медикамент (limbID — для target = "limb"); после задержки предмет расходуется
function ix.medical.Use(client, item, limbID)
	local character = client:GetCharacter()
	local med = item and config.meds[item.medical]

	if (!character or !med) then
		return
	end

	if ((client.ixMedBusy or 0) > CurTime()) then
		client:Notify("Вы уже заняты.")

		return
	end

	local ok, reason = ix.medical.CanHelp(ix.medical.GetState(client), med, limbID)

	if (!ok) then
		client:Notify(reason or "Сейчас это ничего не даст.")

		return
	end

	local itemID = item.id

	local function Finish(quality, failed)
		client.ixMedBusy = nil

		if (!IsValid(client) or !client:Alive() or client:GetCharacter() != character) then
			return
		end

		local current = ix.item.instances[itemID]

		if (!current or !current.invID or current.invID == 0) then
			return
		end

		local owner = current.GetOwner and current:GetOwner()

		if (IsValid(owner) and owner != client) then
			return
		end

		local stillOk, stillReason = ix.medical.CanHelp(ix.medical.GetState(client), med, limbID)

		if (!stillOk) then
			client:Notify(stillReason or "Сейчас это ничего не даст.")

			return
		end

		if (failed) then
			client:Notify("Не получилось: " .. med.name .. " испорчено.")
		else
			ApplyMedication(client, med, limbID, quality)

			-- успешное лечение понемногу прокачивает атрибут «Медицинские знания»
			ix.medical.TrainOnHeal(client, quality or 1)
		end

		local uses = current:GetData("uses", med.uses or 1) - 1

		if (uses <= 0) then
			current:Remove()
		else
			current:SetData("uses", uses)
		end
	end

	local rules = config.procedureRules
	local proc = rules and rules.enabled and med.procedure and config.procedures[med.procedure]

	if (proc) then
		-- процедура-мини-игра: клиент играет, сервер проверяет время и считает качество
		local expires = CurTime() + (proc.maxTime or 120)

		client.ixMedProc = {id = med.procedure, start = CurTime(), expires = expires,
			min = ix.medical.ProcedureMinTime(proc, client), finish = Finish}
		client.ixMedBusy = expires

		net.Start("ixMedProcBegin")
			net.WriteString(med.procedure)
			net.WriteString(limbID or "")
		net.Send(client)

		return
	end

	if ((med.time or 0) > 0) then
		-- время применения сокращается атрибутом «Медицинские знания»
		local time = ix.medical.GetHealTime(client, client, med.time)

		client.ixMedBusy = CurTime() + time + 1
		client:SetAction("Применение: " .. med.name, time, function() Finish() end)
	else
		Finish()
	end
end

net.Receive("ixMedProcDone", function(_, client)
	local mistakes = net.ReadUInt(4)
	local failed = net.ReadBool()
	local proc = client.ixMedProc

	if (!proc) then
		return
	end

	client.ixMedProc = nil

	local rules = config.procedureRules

	if (CurTime() > proc.expires) then
		client.ixMedBusy = nil
		client:Notify("Вы слишком долго возились, ничего не вышло.")

		return
	end

	if (CurTime() - proc.start < proc.min) then
		client.ixMedBusy = nil
		client:Notify("Вы действовали слишком поспешно, ничего не вышло.")

		return
	end

	mistakes = math.min(mistakes, rules.maxMistakes)
	failed = failed or mistakes >= rules.maxMistakes

	local quality = math.Clamp(1 - mistakes * rules.mistakePenalty, rules.minQuality, 1)

	proc.finish(quality, failed)
end)

net.Receive("ixMedProcCancel", function(_, client)
	StopProcedure(client, false)
end)

--[[
	УРОН ПО ЧАСТЯМ ТЕЛА
]]
local hitgroupToLimb = {}

for _, limb in ipairs(config.limbs) do
	for _, hitgroup in ipairs(limb.hitgroups) do
		hitgroupToLimb[hitgroup] = limb.id
	end
end

-- масштаб урона по здоровью зависит от части тела (в ноги меньше, в голову больше)
function PLUGIN:ScalePlayerDamage(client, hitgroup, dmginfo)
	local limbID = hitgroupToLimb[hitgroup]

	if (!limbID or !client:GetCharacter()) then
		return
	end

	dmginfo:ScaleDamage(limbsByID[limbID].scale)

	client.ixMedHit = {limb = limbID, tick = engine.TickCount()}

	-- true — отключаем стандартное масштабирование по хитгруппам
	return true
end

function PLUGIN:PostEntityTakeDamage(entity, dmginfo, bTook)
	if (!bTook or !entity:IsPlayer() or !entity:Alive() or !entity:GetCharacter()) then
		return
	end

	local amount = dmginfo:GetDamage()

	if (amount <= 0) then
		return
	end

	if (StopProcedure(entity, true)) then
		entity:Notify("Вас отвлекли, процедура прервана.")
	end

	local hit = entity.ixMedHit
	local limbID

	entity.ixMedHit = nil

	if (hit and hit.tick == engine.TickCount()) then
		limbID = hit.limb
	elseif (HasBit(dmginfo:GetDamageType(), DMG_FALL)) then
		limbID = RandomLimb({leg = true})
	else
		limbID = RandomLimb()
	end

	ix.medical.OnDamage(entity, limbID, amount, dmginfo)
end

--[[
	ТИКИ: кровотечения, болезни, прогрессирование
]]
local function ProcessPlayer(client, interval)
	local state = client.ixMed
	local limbDamage, toAdd, recovered = {}, {}, {}
	local healthDamage, hungerLoss, thirstLoss = 0, 0, 0

	for key, cond in pairs(state.cond) do
		local def = config.conditions[cond.id]

		if (!def) then
			state.cond[key] = nil
		else
			cond.age = (cond.age or 0) + interval

			local sev = ix.medical.Severity(cond)

			if (def.hps) then
				healthDamage = healthDamage + def.hps * interval * sev
			end

			if (def.hungerDrain) then
				hungerLoss = hungerLoss + def.hungerDrain * interval * sev
			end

			if (def.thirstDrain) then
				thirstLoss = thirstLoss + def.thirstDrain * interval * sev
			end

			if (def.lps and cond.limb) then
				limbDamage[cond.limb] = (limbDamage[cond.limb] or 0) + def.lps * interval * sev
			end

			if (def.duration) then
				cond.left = (cond.left or def.duration) - interval

				if (cond.left <= 0) then
					state.cond[key] = nil
					recovered[#recovered + 1] = def.name
				end
			end

			local progress = def.progress

			if (progress and !cond.rolled and cond.age >= progress.after) then
				cond.rolled = true

				if (math.random() < progress.chance * sev) then
					toAdd[#toAdd + 1] = {progress.to, cond.limb}
				end
			end

			if (def.cough) then
				cond.coughNext = (cond.coughNext or math.Rand(2, def.cough.interval)) - interval

				if (cond.coughNext <= 0) then
					cond.coughNext = def.cough.interval * math.Rand(0.7, 1.3)
					client:EmitSound(COUGH[math.random(#COUGH)], 60)
				end
			end
		end
	end

	-- изменения применяем после обхода, чтобы не менять таблицу во время pairs
	for limbID, amount in pairs(limbDamage) do
		ix.medical.DamageLimb(client, limbID, amount)
	end

	for _, entry in ipairs(toAdd) do
		ix.medical.AddCondition(client, entry[1], entry[2])
	end

	for _, name in ipairs(recovered) do
		client:Notify("Состояние прошло: " .. name .. ".")
	end

	if (#recovered > 0) then
		Dirty(client)
	end

	if (hungerLoss > 0 or thirstLoss > 0) then
		AddNeeds(client, -hungerLoss, -thirstLoss)
	end

	if (healthDamage > 0) then
		client.ixMedHAcc = (client.ixMedHAcc or 0) + healthDamage

		local whole = math.floor(client.ixMedHAcc)

		if (whole >= 1) then
			client.ixMedHAcc = client.ixMedHAcc - whole

			local health = client:Health() - whole

			if (health <= 0) then
				client:Kill()

				return
			end

			client:SetHealth(health)
		end
	end

	local _, _, _, sway = ix.medical.Evaluate(state)

	if (sway) then
		client:ViewPunch(Angle(math.Rand(-1.2, 1.2), math.Rand(-1.2, 1.2), 0))
	end

	client.ixMedTicks = (client.ixMedTicks or 0) + 1

	if (client.ixMedSync or (client.ixMedTicks % 5 == 0 and next(state.cond) != nil)) then
		Sync(client)
	end

	if (client.ixMedDirty and CurTime() >= (client.ixMedNextSave or 0)) then
		client.ixMedNextSave = CurTime() + config.saveInterval
		Save(client)
	end
end

timer.Create("ixMedicalTick", config.tickInterval, 0, function()
	for _, client in ipairs(player.GetAll()) do
		if (client.ixMed and client:GetCharacter() and client:Alive()) then
			ProcessPlayer(client, config.tickInterval)
		end
	end
end)

-- случайные заболевания
timer.Create("ixMedicalAmbient", config.ambient.interval, 0, function()
	local ambient = config.ambient

	if (!ambient.enabled) then
		return
	end

	local total = 0

	for _, weight in pairs(ambient.pool) do
		total = total + weight
	end

	for _, client in ipairs(player.GetAll()) do
		if (client:GetCharacter() and client:Alive() and math.random() < ambient.chance) then
			local roll = math.Rand(0, total)

			for id, weight in pairs(ambient.pool) do
				roll = roll - weight

				if (roll <= 0) then
					ix.medical.AddCondition(client, id)

					break
				end
			end
		end
	end
end)

--[[
	ЗАГРУЗКА / СОХРАНЕНИЕ
]]
function PLUGIN:PlayerLoadedCharacter(client, character, lastChar)
	Load(client, character)

	client.ixMedHAcc = 0
	StopProcedure(client, true)
	client.ixMedBusy = nil

	Sync(client)

	timer.Simple(0.5, function()
		if (IsValid(client) and client:GetCharacter() == character) then
			Sync(client)
		end
	end)
end

function PLUGIN:PlayerDeath(client)
	StopProcedure(client, true)

	if (config.resetOnDeath) then
		client.ixMedReset = true
	end
end

function PLUGIN:PlayerLoadout(client)
	if (client.ixMedReset and client:GetCharacter()) then
		client.ixMedReset = nil

		ix.medical.Reset(client)
	end

	timer.Simple(0.3, function()
		if (IsValid(client) and client:GetCharacter()) then
			Sync(client)
		end
	end)
end

function PLUGIN:CharacterPreSave(character)
	local client = character:GetPlayer()

	if (IsValid(client) and client.ixMed) then
		Save(client)
	end
end

function PLUGIN:PlayerDisconnected(client)
	StopProcedure(client, false)

	if (client.ixMed) then
		Save(client)
	end
end