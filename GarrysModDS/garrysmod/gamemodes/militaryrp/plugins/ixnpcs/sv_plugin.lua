local PLUGIN = PLUGIN

for _, name in ipairs({"ixNPCNode", "ixNPCChoose", "ixNPCClose", "ixNPCShop", "ixNPCTrade", "ixNPCEditOpen", "ixNPCEditSave"}) do
	util.AddNetworkString(name)
end

local USE_DIST = 220
local DEFAULT_MODEL = "models/Humans/Group01/male_07.mdl"

-- ============================================================
-- Утилиты и очистка данных (всё, что приходит от редактора, проходит через Sanitize)
-- ============================================================

local function S(v, max)
	if (v == nil) then return "" end
	return string.sub(tostring(v), 1, max or 256)
end

local function N(v, min, max, default)
	v = tonumber(v)
	if (!v) then return default end
	return math.Clamp(math.floor(v), min, max)
end

local ACTIONS = {
	giveMoney = true, takeMoney = true, giveItem = true, takeItem = true,
	startQuest = true, completeQuest = true, openShop = true,
	vehicleMenu = true, returnVehicle = true
}

local function SanitizeCond(c)
	if (!istable(c)) then return nil end

	return {
		faction = S(c.faction, 128),
		quest = S(c.quest, 64),
		state = S(c.state, 16),
		item = S(c.item, 64),
		amount = N(c.amount, 1, 999, 1),
		money = N(c.money, 0, 100000000, 0)
	}
end

local function SanitizeAction(a)
	if (!istable(a) or !ACTIONS[a.type]) then return nil end

	return {
		type = a.type,
		value = N(a.value, 0, 100000000, 0),
		item = S(a.item, 64),
		amount = N(a.amount, 1, 999, 1),
		quest = S(a.quest, 64)
	}
end

local function SanitizeAccess(a)
	local out = {factions = {}, classes = {}, message = ""}

	if (!istable(a)) then return out end

	for _, key in ipairs({"factions", "classes"}) do
		local count = 0

		if (istable(a[key])) then
			for uid, flag in pairs(a[key]) do
				if (flag == true and count < 64) then
					count = count + 1
					out[key][S(uid, 64)] = true
				end
			end
		end
	end

	out.message = S(a.message, 200)

	return out
end

function PLUGIN:NewDefRaw(name)
	return {
		name = (name and name != "") and name or "Новый NPC",
		desc = "Торговец",
		model = DEFAULT_MODEL,
		skin = 0,
		noBubble = false,
		color = "#5AA0EB",
		access = {factions = {}, classes = {}, message = ""},
		vehicles = {points = {}, list = {}, menuText = "Какая техника вам нужна?", refund = 50},
		dialogue = {
			start = "start",
			nodes = {
				start = {
					text = "Здравствуй, {player}! Чем могу помочь?",
					options = {
						{text = "Покажи, что продаёшь.", actions = {{type = "openShop"}}},
						{text = "Есть работа?", next = "work"},
						{text = "Ничего, прощай."}
					}
				},
				work = {
					text = "Принеси мне 2 бутылки воды — заплачу.",
					options = {
						{text = "Берусь.", cond = {quest = "water", state = "none"}, actions = {{type = "startQuest", quest = "water"}}, next = "start"},
						{text = "Вот твоя вода.", cond = {quest = "water", state = "ready"}, actions = {{type = "completeQuest", quest = "water"}}, next = "start"},
						{text = "Назад.", next = "start"}
					}
				}
			}
		},
		quests = {
			{
				id = "water", name = "Вода для торговца", desc = "Принесите 2 бутылки воды.",
				objectives = {{type = "item", item = "water", amount = 2, consume = true}},
				rewards = {money = 100, items = {}},
				repeatable = true, cooldown = 600
			}
		},
		shop = {
			items = {
				{item = "water", buy = 20, sell = 8, stock = -1, max = -1}
			}
		}
	}
end

-- Новый NPC (всегда очищенный, чтобы у всех вариантов были actions/cond)
function PLUGIN:NewDef(name)
	return (self:Sanitize(self:NewDefRaw(name)))
end

-- возвращает def, ошибку, список предупреждений
function PLUGIN:Sanitize(def)
	if (!istable(def)) then return nil, "Неверный формат данных." end

	local warns = {}
	local out = {
		name = S(def.name, 64), desc = S(def.desc, 256), model = S(def.model, 200),
		skin = N(def.skin, 0, 63, 0), noBubble = def.noBubble == true,
		color = (string.match(S(def.color, 7), "^#%x%x%x%x%x%x$") and S(def.color, 7) != "#F0A030") and S(def.color, 7) or "#5AA0EB",
		dialogue = {start = "start", nodes = {}}, quests = {}, shop = {items = {}}
	}

	if (out.name == "") then out.name = "NPC" end
	if (out.model == "") then out.model = DEFAULT_MODEL end

	-- Диалоги
	local dlg = istable(def.dialogue) and def.dialogue or {}
	out.dialogue.start = S(dlg.start != nil and dlg.start or "start", 64)

	local count = 0

	if (istable(dlg.nodes)) then
		for id, node in pairs(dlg.nodes) do
			if (istable(node) and count < 200) then
				count = count + 1

				local n = {text = S(node.text, 1024), options = {}}

				if (istable(node.options)) then
					for i, opt in ipairs(node.options) do
						if (i > 12) then break end

						if (istable(opt)) then
							local o = {text = S(opt.text, 200), cond = SanitizeCond(opt.cond), actions = {}}

							if (opt.next != nil and opt.next != "") then
								o.next = S(opt.next, 64)
							end

							if (istable(opt.actions)) then
								for j, a in ipairs(opt.actions) do
									if (j > 10) then break end

									local sa = SanitizeAction(a)
									if (sa) then o.actions[#o.actions + 1] = sa end
								end
							end

							n.options[#n.options + 1] = o
						end
					end
				end

				out.dialogue.nodes[S(id, 64)] = n
			end
		end
	end

	if (!out.dialogue.nodes[out.dialogue.start]) then
		return nil, "Не найден стартовый узел диалога '" .. out.dialogue.start .. "'."
	end

	for id, node in pairs(out.dialogue.nodes) do
		for _, o in ipairs(node.options) do
			if (o.next and !out.dialogue.nodes[o.next]) then
				warns[#warns + 1] = "Узел '" .. id .. "': переход на несуществующий узел '" .. o.next .. "'."
			end
		end
	end

	-- Задания
	local seen = {}

	if (istable(def.quests)) then
		for i, q in ipairs(def.quests) do
			if (i > 50) then break end

			local id = istable(q) and S(q.id, 64) or ""

			if (id != "" and !seen[id]) then
				seen[id] = true

				local sq = {
					id = id, name = S(q.name, 100), desc = S(q.desc, 400),
					objectives = {}, rewards = {money = 0, items = {}},
					repeatable = q.repeatable == true, cooldown = N(q.cooldown, 0, 31536000, 0)
				}

				if (istable(q.objectives)) then
					for j, o in ipairs(q.objectives) do
						if (j > 8) then break end

						if (istable(o) and (o.type == "item" or o.type == "kill")) then
							local so = {
								type = o.type, item = S(o.item, 64), class = S(o.class, 64),
								amount = N(o.amount, 1, 9999, 1), consume = o.consume == true, text = S(o.text, 200)
							}

							if (so.type == "item" and !ix.item.list[so.item]) then
								warns[#warns + 1] = "Задание '" .. id .. "': неизвестный предмет '" .. so.item .. "'."
							end

							sq.objectives[#sq.objectives + 1] = so
						end
					end
				end

				if (istable(q.rewards)) then
					sq.rewards.money = N(q.rewards.money, 0, 100000000, 0)

					if (istable(q.rewards.items)) then
						for j, it in ipairs(q.rewards.items) do
							if (j > 10) then break end

							if (istable(it) and S(it.item, 64) != "") then
								local item = S(it.item, 64)

								if (!ix.item.list[item]) then
									warns[#warns + 1] = "Задание '" .. id .. "': неизвестная награда '" .. item .. "'."
								end

								sq.rewards.items[#sq.rewards.items + 1] = {item = item, amount = N(it.amount, 1, 999, 1)}
							end
						end
					end
				end

				out.quests[#out.quests + 1] = sq
			end
		end
	end

	-- Магазин
	if (istable(def.shop) and istable(def.shop.items)) then
		for i, it in ipairs(def.shop.items) do
			if (i > 100) then break end

			if (istable(it) and S(it.item, 64) != "") then
				local item = S(it.item, 64)

				if (!ix.item.list[item]) then
					warns[#warns + 1] = "Магазин: неизвестный предмет '" .. item .. "'."
				end

				local stock = N(it.stock, -1, 1000000, -1)
				local max = -1

				if (stock >= 0) then
					max = math.max(N(it.max, 0, 1000000, stock), stock)
				end

				out.shop.items[#out.shop.items + 1] = {
					item = item,
					buy = N(it.buy, -1, 100000000, -1),    -- цена для игрока при покупке (-1 = не продаётся)
					sell = N(it.sell, -1, 100000000, -1),  -- сколько получит игрок при продаже (-1 = не скупается)
					stock = stock,                         -- остаток (-1 = бесконечно)
					max = max                              -- вместимость склада (для продажи NPC)
				}
			end
		end
	end

	-- Доступ по фракциям / классам
	out.access = SanitizeAccess(def.access)

	-- Техника
	local veh = istable(def.vehicles) and def.vehicles or {}

	out.vehicles = {points = {}, list = {}, menuText = S(veh.menuText, 300), refund = N(veh.refund, 0, 100, 50)}

	if (istable(veh.points)) then
		for i, p in ipairs(veh.points) do
			if (i > 12) then break end

			if (istable(p) and tonumber(p.x) and tonumber(p.y) and tonumber(p.z)) then
				out.vehicles.points[#out.vehicles.points + 1] = {
					x = math.Clamp(tonumber(p.x), -1000000, 1000000),
					y = math.Clamp(tonumber(p.y), -1000000, 1000000),
					z = math.Clamp(tonumber(p.z), -1000000, 1000000),
					yaw = math.Clamp(tonumber(p.yaw) or 0, -360, 360)
				}
			end
		end
	end

	local seenVeh = {}

	if (istable(veh.list)) then
		for i, v in ipairs(veh.list) do
			if (i > 20) then break end

			local id = istable(v) and S(v.id, 64) or ""

			if (id != "" and !seenVeh[id]) then
				seenVeh[id] = true

				local sv = {
					id = id, name = S(v.name, 64),
					kind = (v.kind == "simfphys" or v.kind == "jeep") and v.kind or "entity",
					class = S(v.class, 128), model = S(v.model, 200), script = S(v.script, 200),
					cost = N(v.cost, 0, 100000000, 0),
					cooldown = N(v.cooldown, 0, 604800, 0),
					limit = N(v.limit, 1, 10, 1),
					access = SanitizeAccess(v.access)
				}

				if (sv.name == "") then sv.name = id end

				if (sv.kind != "jeep" and sv.class == "") then
					warns[#warns + 1] = "Техника '" .. id .. "': не указан класс."
				elseif (sv.kind == "entity" and !scripted_ents.Get(sv.class)) then
					warns[#warns + 1] = "Техника '" .. id .. "': класс '" .. sv.class .. "' не найден на сервере."
				end

				out.vehicles.list[#out.vehicles.list + 1] = sv
			end
		end
	end

	return out, nil, warns
end

-- ============================================================
-- Задания
-- ============================================================

function PLUGIN:GetQuestDef(def, id)
	for _, q in ipairs(def.quests) do
		if (q.id == id) then return q end
	end
end

-- "none" | "active" | "ready" | "done"
function PLUGIN:GetQuestState(char, id)
	local data = char:GetData("npcQuests", {})[id]

	if (!data) then return "none" end

	if (data.state == "active") then
		for i = 1, #data.obj do
			if (self:ObjectiveProgress(char, data, i) < data.obj[i].amount) then
				return "active"
			end
		end

		return "ready"
	end

	if (data.repeatable and (os.time() - (data.doneAt or 0)) >= (data.cooldown or 0)) then
		return "none"
	end

	return "done"
end

function PLUGIN:ObjectiveProgress(char, data, i)
	local o = data.obj[i]

	if (o.type == "item") then
		local inv = char:GetInventory()
		return inv and inv:GetItemCount(o.item) or 0
	end

	return data.progress and data.progress[i] or 0
end

function PLUGIN:ObjectiveText(char, data, i)
	local o = data.obj[i]
	local have = math.min(self:ObjectiveProgress(char, data, i), o.amount)
	local what

	if (o.text and o.text != "") then
		what = o.text
	elseif (o.type == "item") then
		local def = ix.item.list[o.item]
		what = "Принести: " .. (def and def.name or o.item)
	else
		what = "Убить: " .. o.class
	end

	return what .. " (" .. have .. "/" .. o.amount .. ")"
end

function PLUGIN:StartQuest(client, def, id)
	local char = client:GetCharacter()
	local q = self:GetQuestDef(def, id)

	if (!q) then return false, "Задание не найдено." end
	if (self:GetQuestState(char, id) != "none") then return false, "Вы уже взяли или выполнили это задание." end

	local all = char:GetData("npcQuests", {})
	local obj = {}

	for i, o in ipairs(q.objectives) do obj[i] = table.Copy(o) end

	all[id] = {
		state = "active", name = q.name, desc = q.desc, obj = obj, progress = {},
		repeatable = q.repeatable, cooldown = q.cooldown, startedAt = os.time()
	}

	char:SetData("npcQuests", all)
	client:Notify("Новое задание: " .. q.name)

	return true
end

function PLUGIN:CompleteQuest(client, def, id)
	local char = client:GetCharacter()
	local q = self:GetQuestDef(def, id)

	if (!q) then return false, "Задание не найдено." end
	if (self:GetQuestState(char, id) != "ready") then return false, "Условия задания не выполнены." end

	local all = char:GetData("npcQuests", {})
	local data = all[id]

	for _, o in ipairs(data.obj) do
		if (o.type == "item" and o.consume and !self:TakeItems(char, o.item, o.amount)) then
			return false, "Не хватает предметов."
		end
	end

	if (q.rewards.money > 0) then char:GiveMoney(q.rewards.money) end

	for _, it in ipairs(q.rewards.items) do
		self:GiveItems(client, it.item, it.amount)
	end

	data.state = "done"
	data.doneAt = os.time()
	char:SetData("npcQuests", all)

	client:Notify("Задание выполнено: " .. q.name)

	return true
end

function PLUGIN:AddKill(client, class)
	local char = client:GetCharacter()
	if (!char) then return end

	local all = char:GetData("npcQuests")
	if (!istable(all)) then return end

	local changed = false

	for _, q in pairs(all) do
		if (q.state == "active") then
			for i, o in ipairs(q.obj) do
				q.progress = q.progress or {}

				if (o.type == "kill" and o.class == class and (q.progress[i] or 0) < o.amount) then
					q.progress[i] = (q.progress[i] or 0) + 1
					changed = true

					client:Notify(q.name .. ": " .. q.progress[i] .. "/" .. o.amount)
				end
			end
		end
	end

	if (changed) then char:SetData("npcQuests", all) end
end

function PLUGIN:OnNPCKilled(npc, attacker)
	if (IsValid(attacker) and attacker:IsPlayer()) then
		self:AddKill(attacker, npc:GetClass())
	end
end

function PLUGIN:PlayerDeath(victim, inflictor, attacker)
	if (IsValid(attacker) and attacker:IsPlayer() and attacker != victim) then
		self:AddKill(attacker, "player")
	end
end

-- ============================================================
-- Предметы
-- ============================================================

function PLUGIN:GiveItems(client, uniqueID, amount)
	local inv = client:GetCharacter():GetInventory()

	for _ = 1, amount do
		if (!inv:Add(uniqueID)) then
			ix.item.Spawn(uniqueID, client:GetShootPos() + client:GetAimVector() * 40)
		end
	end
end

function PLUGIN:TakeItems(char, uniqueID, amount)
	local inv = char:GetInventory()

	if (!inv or inv:GetItemCount(uniqueID) < amount) then return false end

	local removed = 0

	for _, item in pairs(inv:GetItemsByUniqueID(uniqueID)) do
		if (removed >= amount) then break end

		item:Remove()
		removed = removed + 1
	end

	return true
end

-- ============================================================
-- Диалоги
-- ============================================================

function PLUGIN:Format(text, client, def)
	local char = client:GetCharacter()

	text = string.Replace(text, "{player}", char and char:GetName() or client:Name())
	text = string.Replace(text, "{money}", ix.currency.Get(char and char:GetMoney() or 0))
	text = string.Replace(text, "{npc}", def.name)

	return text
end

function PLUGIN:CheckCond(client, cond)
	if (!cond) then return true end

	local char = client:GetCharacter()
	if (!char) then return false end

	if (cond.faction and cond.faction != "") then
		local faction = ix.faction.indices[char:GetFaction()]
		local ok = false

		for _, id in ipairs(string.Explode(",", cond.faction)) do
			if (faction and faction.uniqueID == string.Trim(id)) then ok = true break end
		end

		if (!ok) then return false end
	end

	if (cond.quest and cond.quest != "") then
		local want = (cond.state and cond.state != "") and cond.state or "active"

		if (self:GetQuestState(char, cond.quest) != want) then return false end
	end

	if (cond.item and cond.item != "") then
		local inv = char:GetInventory()

		if (!inv or inv:GetItemCount(cond.item) < (cond.amount or 1)) then return false end
	end

	if (cond.money and cond.money > 0 and !char:HasMoney(cond.money)) then return false end

	return true
end

-- Доступ по фракциям и классам.
-- Фракция отмечена — доступ всей фракции. Если у фракции отмечены отдельные классы,
-- доступ получают только они. Класс без отмеченной фракции получает доступ сам по себе.
function PLUGIN:CheckAccess(client, acc)
	if (!acc) then return true end

	local factions, classes = acc.factions or {}, acc.classes or {}

	if (next(factions) == nil and next(classes) == nil) then return true end

	local char = client:GetCharacter()

	if (!char) then return false end

	local factionIndex = char:GetFaction()
	local faction = ix.faction.indices[factionIndex]
	local class = ix.class.list[char:GetClass()]
	local classOK = class != nil and classes[class.uniqueID] == true

	if (faction and factions[faction.uniqueID]) then
		for _, c in ipairs(ix.class.list) do
			if (c.faction == factionIndex and classes[c.uniqueID]) then
				return classOK -- у фракции есть отмеченные классы
			end
		end

		return true
	end

	return classOK
end

function PLUGIN:DenyMessage(def)
	local msg = def.access and def.access.message or ""

	return msg != "" and msg or "Этот человек не хочет с вами разговаривать."
end

function PLUGIN:ValidSession(client)
	local ent = client.ixNPCEnt

	if (!IsValid(ent) or ent:GetClass() != "ix_npc" or !client:GetCharacter()) then return false end
	if (client:GetPos():DistToSqr(ent:GetPos()) > USE_DIST * USE_DIST) then return false end

	return self:CheckAccess(client, ent.npcDef.access)
end

function PLUGIN:Open(client, ent)
	if (!client:GetCharacter()) then return end
	if ((client.ixNPCNextUse or 0) > CurTime()) then return end

	client.ixNPCNextUse = CurTime() + 0.5

	if (!self:CheckAccess(client, ent.npcDef.access)) then
		client:Notify(self:DenyMessage(ent.npcDef))
		return
	end

	client.ixNPCEnt = ent

	self:SendNode(client, ent, ent.npcDef.dialogue.start)
end

function PLUGIN:Close(client)
	client.ixNPCEnt = nil
	client.ixNPCNode = nil
	client.ixNPCMode = nil
	client.ixNPCVisible = nil
end

local function OptionTag(opt)
	for _, a in ipairs(opt.actions or {}) do
		if (a.type == "openShop") then return "shop" end
		if (a.type == "vehicleMenu" or a.type == "returnVehicle") then return "vehicle" end
		if (a.type == "completeQuest") then return "turnin" end
		if (a.type == "startQuest") then return "quest" end
	end

	if (!opt.next or opt.next == "") then return "leave" end

	return "talk"
end

local function HexColor(hex)
	return Color(tonumber(hex:sub(2, 3), 16) or 90, tonumber(hex:sub(4, 5), 16) or 160, tonumber(hex:sub(6, 7), 16) or 235)
end

-- Отправка реплики и вариантов игроку (opts = {{text=, tag=}, ...}, до 31 штуки)
function PLUGIN:Transmit(client, ent, text, opts)
	local def = ent.npcDef

	net.Start("ixNPCNode")
		net.WriteEntity(ent)
		net.WriteString(def.name)
		net.WriteString(def.desc)
		net.WriteColor(HexColor(def.color or "#5AA0EB"))
		net.WriteString(self:Format(text, client, def))
		net.WriteUInt(#opts, 5)

		for _, o in ipairs(opts) do
			net.WriteString(o.text)
			net.WriteString(o.tag)
		end
	net.Send(client)
end

function PLUGIN:SendNode(client, ent, nodeID)
	local def = ent.npcDef
	local node = def.dialogue.nodes[nodeID]

	if (!node) then
		client:Notify("Диалог не настроен.")
		return
	end

	local opts, visible = {}, {}

	for i, opt in ipairs(node.options) do
		if (self:CheckCond(client, opt.cond)) then
			opts[#opts + 1] = {text = self:Format(opt.text, client, def), tag = OptionTag(opt)}
			visible[#visible + 1] = i
		end
	end

	client.ixNPCNode = nodeID
	client.ixNPCMode = nil
	client.ixNPCVisible = visible

	self:Transmit(client, ent, node.text, opts)
end

net.Receive("ixNPCChoose", function(_, client)
	local idx = net.ReadUInt(5)

	if (!PLUGIN:ValidSession(client)) then return end

	local ent = client.ixNPCEnt
	local def = ent.npcDef

	-- меню выдачи техники
	if (client.ixNPCMode == "vehicles") then
		local real = client.ixNPCVisible and client.ixNPCVisible[idx]

		if (real == nil) then return end

		if (real == 0) then
			PLUGIN:SendNode(client, ent, client.ixNPCNode)
			return
		end

		local veh = def.vehicles.list[real]

		if (!veh) then return end

		local ok, err = PLUGIN:SpawnVehicle(client, ent, veh)

		if (ok) then
			net.Start("ixNPCClose") net.Send(client)
			PLUGIN:Close(client)
		else
			client:Notify(err or "Не удалось выдать технику.")
			PLUGIN:SendVehicleNode(client, ent)
		end

		return
	end

	local node = def.dialogue.nodes[client.ixNPCNode]
	local real = client.ixNPCVisible and client.ixNPCVisible[idx]
	local opt = real and node and node.options[real]

	if (!opt or !PLUGIN:CheckCond(client, opt.cond)) then return end

	local ctx = {}

	for _, act in ipairs(opt.actions or {}) do
		local ok, err = PLUGIN:RunAction(client, ent, act, ctx)

		if (!ok) then
			client:Notify(err or "Действие не выполнено.")
			PLUGIN:SendNode(client, ent, client.ixNPCNode)
			return
		end
	end

	if (ctx.shop) then
		PLUGIN:SendShop(client, ent)
	elseif (ctx.vehicles) then
		PLUGIN:SendVehicleNode(client, ent)
	elseif (opt.next and def.dialogue.nodes[opt.next]) then
		PLUGIN:SendNode(client, ent, opt.next)
	else
		net.Start("ixNPCClose") net.Send(client)
		PLUGIN:Close(client)
	end
end)

net.Receive("ixNPCClose", function(_, client)
	PLUGIN:Close(client)
end)

function PLUGIN:RunAction(client, ent, a, ctx)
	local char = client:GetCharacter()
	local t = a.type

	if (t == "giveMoney") then
		char:GiveMoney(a.value)
	elseif (t == "takeMoney") then
		if (!char:HasMoney(a.value)) then return false, "Недостаточно средств." end

		char:TakeMoney(a.value)
	elseif (t == "giveItem") then
		if (!ix.item.list[a.item]) then return false, "Предмет не существует: " .. a.item end

		self:GiveItems(client, a.item, a.amount)
	elseif (t == "takeItem") then
		if (!self:TakeItems(char, a.item, a.amount)) then return false, "Не хватает предметов." end
	elseif (t == "startQuest") then
		return self:StartQuest(client, ent.npcDef, a.quest)
	elseif (t == "completeQuest") then
		return self:CompleteQuest(client, ent.npcDef, a.quest)
	elseif (t == "openShop") then
		ctx.shop = true
	elseif (t == "vehicleMenu") then
		if (#ent.npcDef.vehicles.list == 0) then return false, "У этого NPC нет техники." end

		ctx.vehicles = true
	elseif (t == "returnVehicle") then
		return self:ReturnVehicles(client, ent)
	end

	return true
end

-- ============================================================
-- Техника
-- ============================================================

PLUGIN.spawned = PLUGIN.spawned or {}

local function IsVehicleEnt(e)
	return e:IsVehicle() or e.IsSimfphyscar or e.LVS or e.IsGlideVehicle or e.ixNPCVeh
end

function PLUGIN:VehicleCooldownLeft(char, veh)
	local last = char:GetData("npcVehCD", {})[veh.id] or 0

	return math.max(0, math.ceil(last + veh.cooldown - os.time()))
end

-- первая свободная точка; если точек нет вовсе — перед NPC
function PLUGIN:FindSpawnPoint(ent)
	local points = ent.npcDef.vehicles.points

	for _, p in ipairs(points) do
		local pos = Vector(p.x, p.y, p.z)
		local busy = false

		for _, e in ipairs(ents.FindInSphere(pos, 130)) do
			if (IsVehicleEnt(e)) then
				busy = true
				break
			end
		end

		if (!busy) then return pos, Angle(0, p.yaw, 0) end
	end

	if (#points == 0) then
		return ent:GetPos() + ent:GetForward() * 180 + Vector(0, 0, 12), Angle(0, ent:GetAngles().y, 0)
	end
end

function PLUGIN:CreateVehicle(client, veh, pos, ang)
	local v

	if (veh.kind == "simfphys") then
		if (simfphys and simfphys.SpawnVehicleSimple) then
			v = simfphys.SpawnVehicleSimple(veh.class, pos, ang)
		elseif (simfphys and simfphys.SpawnVehicle) then
			local vt = (list.Get("simfphys_vehicles") or {})[veh.class]

			if (vt) then
				v = simfphys.SpawnVehicle(client, pos, ang, vt.Model, vt.Class, veh.class, vt, true)
			end
		end
	elseif (veh.kind == "jeep") then
		v = ents.Create("prop_vehicle_jeep")

		if (IsValid(v)) then
			v:SetModel(veh.model != "" and veh.model or "models/buggy.mdl")
			v:SetKeyValue("vehiclescript", veh.script != "" and veh.script or "scripts/vehicles/jeep_test.txt")
			v:SetKeyValue("limitview", "0")
			v:SetPos(pos)
			v:SetAngles(Angle(0, ang.y - 90, 0))
			v:Spawn()
			v:Activate()
		end
	else
		v = ents.Create(veh.class)

		if (IsValid(v)) then
			if (veh.model != "") then v:SetModel(veh.model) end

			v:SetPos(pos)
			v:SetAngles(ang)
			v:Spawn()
			v:Activate()
		end
	end

	return IsValid(v) and v or nil
end

function PLUGIN:SpawnVehicle(client, ent, veh)
	local char = client:GetCharacter()

	if (!self:CheckAccess(client, veh.access)) then return false, "У вас нет допуска к этой технике." end

	local wait = self:VehicleCooldownLeft(char, veh)

	if (wait > 0) then
		return false, string.format("Техника будет доступна через %d:%02d.", math.floor(wait / 60), wait % 60)
	end

	local active = 0

	for i = #self.spawned, 1, -1 do
		local v = self.spawned[i]

		if (!IsValid(v)) then
			table.remove(self.spawned, i)
		elseif (v.ixNPCChar == char:GetID() and v.ixNPCVehID == veh.id) then
			active = active + 1
		end
	end

	if (active >= veh.limit) then return false, "Вы уже получили эту технику. Сдайте её, чтобы взять новую." end
	if (veh.cost > 0 and !char:HasMoney(veh.cost)) then return false, "Недостаточно средств." end

	local pos, ang = self:FindSpawnPoint(ent)

	if (!pos) then return false, "Все места для техники заняты. Попробуйте позже." end

	local v = self:CreateVehicle(client, veh, pos, ang)

	if (!v) then return false, "Не удалось создать технику — обратитесь к администратору." end

	if (veh.cost > 0) then char:TakeMoney(veh.cost) end

	v.ixNPCVeh = true
	v.ixNPCChar = char:GetID()
	v.ixNPCVehID = veh.id
	v.ixNPCSource = ent
	v.ixNPCCost = veh.cost

	if (v.CPPISetOwner) then v:CPPISetOwner(client) end
	if (v.SetCreator) then v:SetCreator(client) end

	self.spawned[#self.spawned + 1] = v

	local cds = char:GetData("npcVehCD", {})
	cds[veh.id] = os.time()
	char:SetData("npcVehCD", cds)

	client:Notify("Техника выдана: " .. veh.name)

	return true
end

-- Сдача техники: убирает технику игрока, выданную этим NPC и стоящую поблизости
function PLUGIN:ReturnVehicles(client, ent)
	local char = client:GetCharacter()
	local percent = ent.npcDef.vehicles.refund
	local count, refund = 0, 0

	for i = #self.spawned, 1, -1 do
		local v = self.spawned[i]

		if (!IsValid(v)) then
			table.remove(self.spawned, i)
		elseif (v.ixNPCChar == char:GetID() and v.ixNPCSource == ent and v:GetPos():DistToSqr(ent:GetPos()) <= 900 * 900) then
			refund = refund + math.floor((v.ixNPCCost or 0) * percent / 100)
			count = count + 1

			v:Remove()
			table.remove(self.spawned, i)
		end
	end

	if (count == 0) then return false, "Ваша техника должна стоять рядом с NPC." end

	if (refund > 0) then
		char:GiveMoney(refund)
		client:Notify("Техника сдана. Возвращено: " .. ix.currency.Get(refund))
	else
		client:Notify("Техника сдана.")
	end

	return true
end

function PLUGIN:SendVehicleNode(client, ent)
	local def = ent.npcDef
	local char = client:GetCharacter()
	local opts, visible = {}, {}

	for i, v in ipairs(def.vehicles.list) do
		if (self:CheckAccess(client, v.access)) then
			local text = v.name .. "  —  " .. (v.cost > 0 and ix.currency.Get(v.cost) or "бесплатно")
			local wait = self:VehicleCooldownLeft(char, v)

			if (wait > 0) then
				text = text .. string.format("  (через %d:%02d)", math.floor(wait / 60), wait % 60)
			end

			opts[#opts + 1] = {text = text, tag = "vehicle"}
			visible[#visible + 1] = i
		end
	end

	local text = def.vehicles.menuText != "" and def.vehicles.menuText or "Какая техника вам нужна?"

	if (#opts == 0) then text = "Для вас сейчас нет доступной техники." end

	opts[#opts + 1] = {text = "Назад", tag = "leave"}
	visible[#visible + 1] = 0

	client.ixNPCMode = "vehicles"
	client.ixNPCVisible = visible

	self:Transmit(client, ent, text, opts)
end

-- ============================================================
-- Магазин
-- ============================================================

function PLUGIN:SendShop(client, ent)
	local char = client:GetCharacter()
	local inv = char:GetInventory()
	local items = ent.npcDef.shop.items

	net.Start("ixNPCShop")
		net.WriteEntity(ent)
		net.WriteColor(HexColor(ent.npcDef.color or "#5AA0EB"))
		net.WriteUInt(#items, 8)

		for i, it in ipairs(items) do
			net.WriteUInt(i, 8)
			net.WriteString(it.item)
			net.WriteInt(it.buy, 32)
			net.WriteInt(it.sell, 32)
			net.WriteInt(it.stock, 32)
			net.WriteInt(it.max or -1, 32)
			net.WriteUInt(math.min(inv and inv:GetItemCount(it.item) or 0, 65535), 16)
		end
	net.Send(client)
end

net.Receive("ixNPCTrade", function(_, client)
	local buying = net.ReadBool()
	local idx = net.ReadUInt(8)
	local amount = math.Clamp(net.ReadUInt(8), 1, 50)

	if (!PLUGIN:ValidSession(client)) then return end

	local ent = client.ixNPCEnt
	local entry = ent.npcDef.shop.items[idx]
	if (!entry or !ix.item.list[entry.item]) then return end

	local char = client:GetCharacter()
	local inv = char:GetInventory()

	if (buying) then
		if (entry.buy < 0) then return client:Notify("Этот предмет не продаётся.") end
		if (entry.stock >= 0 and entry.stock < amount) then return client:Notify("Нет столько в наличии.") end
		if (!char:HasMoney(entry.buy * amount)) then return client:Notify("Недостаточно средств.") end

		local given = 0

		for _ = 1, amount do
			if (inv:Add(entry.item)) then given = given + 1 else break end
		end

		if (given == 0) then return client:Notify("В инвентаре нет места.") end

		char:TakeMoney(entry.buy * given)

		if (entry.stock >= 0) then entry.stock = entry.stock - given end
	else
		if (entry.sell < 0) then return client:Notify("Этот предмет не скупается.") end
		if (entry.stock >= 0 and (entry.max or -1) >= 0 and entry.stock + amount > entry.max) then
			return client:Notify("Склад NPC переполнен.")
		end
		if (!PLUGIN:TakeItems(char, entry.item, amount)) then return client:Notify("У вас нет столько предметов.") end

		char:GiveMoney(entry.sell * amount)

		if (entry.stock >= 0) then entry.stock = entry.stock + amount end
	end

	PLUGIN:SendShop(client, ent)
end)

-- ============================================================
-- Редактор (только superadmin — проверяется при открытии И при сохранении)
-- ============================================================

function PLUGIN:SendEditor(client, ent)
	if (!self:CanManage(client)) then return end

	local data = util.Compress(util.TableToJSON(ent.npcDef))

	if (#data > 60000) then
		return client:Notify("Конфиг NPC слишком большой.")
	end

	net.Start("ixNPCEditOpen")
		net.WriteEntity(ent)
		net.WriteUInt(#data, 16)
		net.WriteData(data, #data)
	net.Send(client)
end

net.Receive("ixNPCEditSave", function(_, client)
	if (!PLUGIN:CanManage(client)) then return end

	local ent = net.ReadEntity()
	local len = net.ReadUInt(16)
	local data = net.ReadData(len)

	if (!IsValid(ent) or ent:GetClass() != "ix_npc") then return end

	local json = util.Decompress(data, 262144)
	local tbl = json and util.JSONToTable(json)
	local def, err, warns = PLUGIN:Sanitize(tbl)

	if (!def) then
		return client:Notify("Ошибка: " .. tostring(err))
	end

	ent:SetDef(def)
	PLUGIN:SaveData()

	client:Notify("NPC сохранён и применён.")

	for _, w in ipairs(warns) do
		client:ChatPrint("[NPC] Предупреждение: " .. w)
	end
end)

-- ============================================================
-- Сохранение / загрузка / защита
-- ============================================================

function PLUGIN:SaveData()
	local data = {}

	for _, ent in ipairs(ents.FindByClass("ix_npc")) do
		if (ent.npcDef) then
			data[#data + 1] = {pos = ent:GetPos(), ang = ent:GetAngles(), def = ent.npcDef}
		end
	end

	self:SetData(data)
end

function PLUGIN:LoadData()
	for _, v in ipairs(self:GetData() or {}) do
		local def = self:Sanitize(v.def) or self:NewDef()
		local ent = ents.Create("ix_npc")

		ent:SetPos(v.pos)
		ent:SetAngles(v.ang)
		ent:Spawn()
		ent:SetDef(def)
	end
end

function PLUGIN:PhysgunPickup(client, ent)
	if (ent:GetClass() == "ix_npc") then return client:IsSuperAdmin() end
end

function PLUGIN:CanTool(client, trace)
	local ent = trace.Entity

	if (IsValid(ent) and ent:GetClass() == "ix_npc" and !client:IsSuperAdmin()) then return false end
end

function PLUGIN:CanProperty(client, property, ent)
	if (IsValid(ent) and ent:GetClass() == "ix_npc" and !client:IsSuperAdmin()) then return false end
end

-- Q-меню: спавнить ix_npc может только superadmin (даже если обычный admin видит вкладку).
function PLUGIN:PlayerSpawnSENT(client, class)
	if (class == "ix_npc" and !self:CanManage(client)) then
		return false
	end
end

-- Удаление NPC через Q-меню/undo тоже должно попасть в сохранение.
function PLUGIN:EntityRemoved(entity)
	if (entity:GetClass() == "ix_npc" and !ix.shuttingDown) then
		timer.Create("ixNPCSaveAfterRemove", 1, 1, function()
			self:SaveData()
		end)
	end
end
