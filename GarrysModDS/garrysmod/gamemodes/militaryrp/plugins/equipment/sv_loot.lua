local PLUGIN = PLUGIN
local config = ix.equipment.config

--[[
	ОБЫСК И СНЯТИЕ СНАРЯЖЕНИЯ С ДРУГИХ ИГРОКОВ

	Цель обыска — труп (prop_ragdoll с entity.ixEquipped) или живой игрок (беспомощный: в наручниках или повален).
	Сам интерактивный обыск (маркеры на теле) делает плагин Persistent Corpses, а когда он закончен,
	вызывает ix.equipment.OpenLoot(client, target, entity, validator): у обыскивающего открывается панель
	со снаряжением цели, предметы забираются кликом в его инвентарь.

	Смерть: снаряжение игрока переходит на труп (конфиг corpseEquipmentDrop) — иначе снимать с трупа нечего.
]]

ix.equipment.lootRange = 200 -- максимальная дистанция до цели, пока открыта панель

util.AddNetworkString("ixEquipmentLoot")
util.AddNetworkString("ixEquipmentLootClose")

ix.config.Add("corpseEquipmentDrop", true, "Снаряжение игрока остаётся на трупе после смерти (его можно снять при обыске).", nil, {
	category = "Persistent Corpses"
})

-- таблица надетого у цели: у игрока — его слоты, у трупа — entity.ixEquipped
local function GetHolderEquipped(target)
	if (target:IsPlayer()) then
		return ix.equipment.GetEquipped(target)
	end

	target.ixEquipped = target.ixEquipped or {}

	return target.ixEquipped
end

function ix.equipment.GetTargetEquipped(target)
	return GetHolderEquipped(target)
end

local function SendLoot(client)
	local loot = client.ixLoot

	if (!loot or !IsValid(loot.target) or !IsValid(loot.entity)) then
		return
	end

	local slots = {}

	for slotID, entry in pairs(GetHolderEquipped(loot.target)) do
		slots[slotID] = entry.uid
	end

	-- имя владельца для заголовка панели
	local name = ""

	if (loot.target:IsPlayer()) then
		local character = loot.target:GetCharacter()

		name = character and character:GetName() or loot.target:Name()
	else
		name = loot.entity.ixCorpseName or ""
	end

	net.Start("ixEquipmentLoot")
		net.WriteEntity(loot.entity)
		net.WriteBool(loot.target:IsPlayer())
		net.WriteTable(slots)
		net.WriteString(name)
	net.Send(client)
end

-- открыть панель снаряжения цели.
-- entity — то, на что смотрит обыскивающий (труп или игрок/его рэгдолл), validator(client, target) — можно ли ещё обыскивать
function ix.equipment.OpenLoot(client, target, entity, validator)
	if (!IsValid(client) or !IsValid(target)) then
		return false
	end

	client.ixLoot = {
		target = target,
		entity = IsValid(entity) and entity or target,
		validator = validator
	}

	SendLoot(client)

	return true
end

function ix.equipment.CloseLoot(client, tellClient)
	if (!IsValid(client)) then
		return
	end

	client.ixLoot = nil

	if (tellClient) then
		net.Start("ixEquipmentLootClose")
		net.Send(client)
	end
end

-- проверка сессии: возвращает цель или nil (и закрывает панель, если обыск уже невозможен)
local function GetLootTarget(client)
	local loot = client.ixLoot

	if (!loot) then
		return
	end

	local target, entity = loot.target, loot.entity

	if (!IsValid(target) or !IsValid(entity) or !client:Alive() or !client:GetCharacter()
	or client:GetShootPos():DistToSqr(entity:WorldSpaceCenter()) > ix.equipment.lootRange ^ 2
	or (target:IsPlayer() and (!target:Alive() or !target:GetCharacter()))
	or (loot.validator and loot.validator(client, target) == false)) then
		ix.equipment.CloseLoot(client, true)

		return
	end

	return target, entity
end

-- забрать предмет из слота цели в инвентарь обыскивающего. Возвращает true либо false и причину
function ix.equipment.Take(client, target, slotID)
	local equipped = GetHolderEquipped(target)
	local entry = equipped[slotID]

	if (!entry) then
		return false, "В этом слоте уже ничего нет."
	end

	local itemTable = ix.item.list[entry.uid]

	if (hook.Run("CanEquipmentTake", client, target, itemTable, slotID) == false) then
		return false, "Вы не можете забрать этот предмет."
	end

	if (target:IsPlayer()) then
		-- живой игрок: обычное снятие, но предмет падает в инвентарь обыскивающего
		local ok, reason = ix.equipment.Unequip(target, slotID, client)

		if (ok) then
			hook.Run("EquipmentTaken", client, target, itemTable, slotID)
		end

		return ok, reason
	end

	local character = client:GetCharacter()
	local inventory = character and character:GetInventory()

	if (!inventory) then
		return false, "Инвентарь персонажа недоступен."
	end

	if (!inventory:Add(entry.uid, 1, entry.data)) then
		return false, string.format("Нет места в инвентаре, чтобы забрать: %s.", itemTable and itemTable.name or entry.uid)
	end

	equipped[slotID] = nil

	if (config.sounds.unequip) then
		target:EmitSound(config.sounds.unequip, 60)
	end

	hook.Run("EquipmentTaken", client, target, itemTable, slotID)

	return true
end

concommand.Add("ix_equipment_take", function(client, command, arguments)
	if (!IsValid(client) or !isstring(arguments[1]) or (client.ixLootNext or 0) > CurTime()) then
		return
	end

	client.ixLootNext = CurTime() + 0.2

	local target = GetLootTarget(client)

	if (!target) then
		return
	end

	local itemTable = ix.item.list[(GetHolderEquipped(target)[arguments[1]] or {}).uid]
	local ok, reason = ix.equipment.Take(client, target, arguments[1])

	if (ok) then
		client:Notify("Вы забрали: " .. (itemTable and itemTable.name or "предмет") .. ".")
	else
		client:Notify(reason or "Не удалось забрать предмет.")
	end

	SendLoot(client)
end)

concommand.Add("ix_equipment_takeall", function(client)
	if (!IsValid(client) or (client.ixLootNext or 0) > CurTime()) then
		return
	end

	client.ixLootNext = CurTime() + 0.5

	local target = GetLootTarget(client)

	if (!target) then
		return
	end

	local taken, failReason = 0, nil

	-- в порядке слотов из конфига
	for _, slot in ipairs(config.slots) do
		if (GetHolderEquipped(target)[slot.id]) then
			local ok, reason = ix.equipment.Take(client, target, slot.id)

			if (ok) then
				taken = taken + 1
			else
				failReason = reason
			end
		end
	end

	if (taken > 0) then
		client:Notify("Вы забрали предметов: " .. taken .. ".")
	end

	if (failReason) then
		client:Notify(failReason)
	elseif (taken == 0) then
		client:Notify("Снимать больше нечего.")
	end

	SendLoot(client)
end)

concommand.Add("ix_loot_close", function(client)
	ix.equipment.CloseLoot(client, false)
end)

-- обыск прервался (цель убежала, умер кто-то из двоих, труп пропал)
timer.Create("ixEquipmentLootWatch", 0.5, 0, function()
	for _, client in ipairs(player.GetAll()) do
		if (client.ixLoot) then
			GetLootTarget(client)
		end
	end
end)

-- при смерти снаряжение переходит на труп
function PLUGIN:OnPlayerCorpseCreated(client, entity)
	if (!ix.config.Get("corpseEquipmentDrop", true) or !IsValid(entity)) then
		return
	end

	local equipped = ix.equipment.GetEquipped(client)

	if (table.IsEmpty(equipped)) then
		return
	end

	-- запоминаем патроны в магазинах, пока оружие ещё у игрока
	ix.equipment.CaptureAmmo(client)

	entity.ixEquipped = {}

	for slotID, entry in pairs(equipped) do
		entity.ixEquipped[slotID] = {uid = entry.uid, data = table.Copy(entry.data or {})}
	end

	client.ixEquipped = {}

	ix.equipment.SaveState(client)
	ix.equipment.Refresh(client)
end
