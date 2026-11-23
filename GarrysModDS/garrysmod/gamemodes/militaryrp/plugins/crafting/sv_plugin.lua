local PLUGIN = PLUGIN

util.AddNetworkString("ixCraftOpen")
util.AddNetworkString("ixCraftRequest")
util.AddNetworkString("ixCraftBegin")
util.AddNetworkString("ixCraftResult")
util.AddNetworkString("ixCraftCancel")
util.AddNetworkString("ixCraftHit")
util.AddNetworkString("ixCraftAbort")

function PLUGIN:OpenBench(client, ent)
	if (!client:GetCharacter() or client.ixCraft or client:IsRestricted()) then return end

	net.Start("ixCraftOpen")
		net.WriteEntity(ent)
	net.Send(client)
end

function PLUGIN:RemoveItems(inventory, uniqueID, count)
	local removed = 0

	for _, item in pairs(inventory:GetItemsByUniqueID(uniqueID)) do
		if (removed >= count) then break end

		item:Remove()
		removed = removed + 1
	end
end

local function SendAbort(client, reason)
	net.Start("ixCraftAbort")
		net.WriteString(reason or "")
	net.Send(client)
end

local function StopCraft(client, reason, silent)
	local state = client.ixCraft
	if (!state) then return end

	timer.Remove(state.timerName)
	client.ixCraft = nil

	if (IsValid(state.bench)) then
		state.bench:SetActive(false)
	end

	if (IsValid(client) and !silent) then
		SendAbort(client, reason)
	end
end

local function FinishCraft(client)
	local state = client.ixCraft
	local recipe, bench = state.recipe, state.bench

	StopCraft(client, nil, true)

	local ok, why = PLUGIN:CanCraft(client, recipe)

	if (!ok) then
		client:Notify(why)
		SendAbort(client, why)
		return
	end

	local char = client:GetCharacter()
	local inventory = char:GetInventory()
	local attrID = recipe.attribute or "crafting"
	local xp = recipe.xp or 0.15
	local bonus = state.bonus or 0
	local chance = math.Clamp(PLUGIN:GetCraftChance(client, recipe) + bonus, 5, 100)
	local success = math.Rand(0, 100) <= chance

	if (success) then
		for id, qty in pairs(recipe.ingredients) do
			PLUGIN:RemoveItems(inventory, id, qty)
		end

		for id, qty in pairs(recipe.result) do
			for _ = 1, qty do
				if (!inventory:Add(id)) then
					ix.item.Spawn(id, bench:GetPos() + bench:GetUp() * 50 + VectorRand() * 8)
				end
			end
		end

		char:UpdateAttrib(attrID, xp)
	else
		local loss = recipe.failLoss or ix.config.Get("craftFailLoss", 0.5)

		for id, qty in pairs(recipe.ingredients) do
			PLUGIN:RemoveItems(inventory, id, math.floor(qty * loss + 0.5))
		end

		char:UpdateAttrib(attrID, xp * 0.5)
	end

	if (IsValid(bench)) then
		bench:EmitSound(success and "buttons/button9.wav" or "buttons/button10.wav", 70)
	end

	net.Start("ixCraftResult")
		net.WriteBool(success)
		net.WriteString(recipe.id)
		net.WriteFloat(chance)
		net.WriteFloat(bonus)
	net.Send(client)
end

net.Receive("ixCraftRequest", function(_, client)
	local ent = net.ReadEntity()
	local recipe = PLUGIN.recipes[net.ReadString()]
	local maxDist = ix.config.Get("craftMaxDistance", 160)

	if (client.ixCraft or !recipe) then return end
	if (!IsValid(ent) or ent:GetClass() != "ix_workbench" or recipe.bench != ent:GetBenchType()) then return end

	if (!client:Alive() or client:IsRestricted() or client:GetPos():Distance(ent:GetPos()) > maxDist + 32) then
		SendAbort(client, "")
		return
	end

	local ok, why = PLUGIN:CanCraft(client, recipe)

	if (!ok) then
		client:Notify(why)
		SendAbort(client, why)
		return
	end

	local duration = math.max(1, (recipe.time or 5) * ix.config.Get("craftTimeMultiplier", 1))
	local timerName = "ixCraft" .. client:SteamID64()

	client.ixCraft = {
		recipe = recipe, bench = ent, start = CurTime(), duration = duration, finish = CurTime() + duration,
		timerName = timerName, nextSound = 0, bonus = 0, hits = {}
	}
	ent:SetActive(true)

	net.Start("ixCraftBegin")
		net.WriteString(recipe.id)
		net.WriteFloat(duration)
	net.Send(client)

	timer.Create(timerName, 0.2, 0, function()
		local state = IsValid(client) and client.ixCraft

		if (!state) then
			timer.Remove(timerName)
			if (IsValid(ent)) then ent:SetActive(false) end
			return
		end

		if (!IsValid(ent) or !client:Alive() or client:IsRestricted()
		or client:GetPos():Distance(ent:GetPos()) > maxDist + 48) then
			StopCraft(client, "Крафт прерван.")
			return
		end

		if (CurTime() >= state.nextSound) then
			ent:EmitSound("ambient/energy/weld" .. math.random(1, 2) .. ".wav", 60, math.random(95, 110), 0.5)
			state.nextSound = CurTime() + math.Rand(0.6, 1.1)
		end

		if (CurTime() >= state.finish) then
			FinishCraft(client)
		end
	end)
end)

-- Мини-игра: клиент сообщает о нажатии в контрольной точке, оценку времени делает сервер.
net.Receive("ixCraftHit", function(_, client)
	local state = client.ixCraft
	local index = net.ReadUInt(2)
	local maxBonus = ix.config.Get("craftSkillBonus", 5)

	if (!state or maxBonus <= 0 or !PLUGIN.checkpoints[index] or state.hits[index]) then return end

	local p = (CurTime() - state.start) / state.duration
	local half = PLUGIN:GetCheckHalfWidth(state.duration)
	local dist = math.abs(p - PLUGIN.checkpoints[index])
	local tolerance = 0.03 -- запас на пинг

	if (dist > half + tolerance) then return end

	state.hits[index] = true
	state.bonus = state.bonus + ((dist <= half * 0.35 + tolerance) and 1 or 0.5) * maxBonus
end)

net.Receive("ixCraftCancel", function(_, client)
	StopCraft(client, "")
end)

function PLUGIN:PlayerDisconnected(client)
	StopCraft(client, nil, true)
end

function PLUGIN:SaveData()
	local data = {}

	for _, ent in ipairs(ents.FindByClass("ix_workbench")) do
		data[#data + 1] = {ent:GetPos(), ent:GetAngles(), ent:GetBenchType()}
	end

	self:SetData(data)
end

function PLUGIN:LoadData()
	for _, v in ipairs(self:GetData() or {}) do
		local ent = ents.Create("ix_workbench")
		ent:SetPos(v[1])
		ent:SetAngles(v[2])
		ent:Spawn()
		ent:SetType(v[3])
	end
end
