local PLUGIN = PLUGIN
local UI = PLUGIN.ui
local C = UI.col

local function Noop() end

local PRESET_MODELS = {
	{"Мосман", "models/mossman.mdl"}, {"Аликс", "models/alyx.mdl"}, {"Барни", "models/barney.mdl"},
	{"Илай", "models/eli.mdl"}, {"Кляйнер", "models/kleiner.mdl"}, {"Брин", "models/breen.mdl"},
	{"Джи-мен", "models/gman.mdl"}, {"Монах", "models/monk.mdl"}, {"Одесса", "models/odessa.mdl"},
	{"Гражданский (м)", "models/Humans/Group01/male_07.mdl"}, {"Гражданская (ж)", "models/Humans/Group01/female_02.mdl"},
	{"Повстанец (м)", "models/Humans/Group03/male_02.mdl"}, {"Медик (ж)", "models/Humans/Group03m/female_01.mdl"},
	{"Полицейский", "models/police.mdl"}, {"Солдат Альянса", "models/combine_soldier.mdl"}
}

local PRESET_COLORS = {"#5AA0EB", "#E8573D", "#D94F8B", "#9B6BE8", "#3FB8C9", "#5CC76B", "#F0B030", "#C9C93F"}

local ACTION_TYPES = {
	{"Выдать деньги", "giveMoney"}, {"Забрать деньги", "takeMoney"},
	{"Выдать предмет", "giveItem"}, {"Забрать предмет", "takeItem"},
	{"Взять задание", "startQuest"}, {"Сдать задание", "completeQuest"},
	{"Открыть магазин", "openShop"}
}

local QSTATES = {
	{"доступно (не взято)", "none"}, {"выполняется", "active"},
	{"готово к сдаче", "ready"}, {"завершено", "done"}
}

local KILL_PRESETS = {
	{"Зомби", "npc_zombie"}, {"Хедкраб", "npc_headcrab"}, {"Солдат Альянса", "npc_combine_s"},
	{"Метрокоп", "npc_metropolice"}, {"Муравьиный лев", "npc_antlion"}, {"Игрок", "player"}
}

-- ============================================================
-- Вспомогательное
-- ============================================================

local function SortedKeys(t)
	local k = {}

	for id in pairs(t) do k[#k + 1] = tostring(id) end

	table.sort(k)

	return k
end

local function QuestOptions(work, withNone)
	local o = {}

	if (withNone) then o[#o + 1] = {"— не важно —", ""} end

	for _, q in ipairs(work.quests) do
		o[#o + 1] = {q.name .. "  (" .. q.id .. ")", q.id}
	end

	return o
end

local function NodeOptions(work)
	local o = {{"[ закрыть диалог ]", ""}}

	for _, id in ipairs(SortedKeys(work.dialogue.nodes)) do
		o[#o + 1] = {"> " .. id, id}
	end

	return o
end

local function Normalize(w)
	w.name = w.name or "NPC"
	w.desc = w.desc or ""
	w.model = w.model or "models/mossman.mdl"
	w.skin = tonumber(w.skin) or 0
	w.color = w.color or "#5AA0EB"
	w.noBubble = w.noBubble == true

	w.dialogue = istable(w.dialogue) and w.dialogue or {}
	w.dialogue.start = tostring(w.dialogue.start or "start")

	local nodes = {}

	for id, n in pairs(istable(w.dialogue.nodes) and w.dialogue.nodes or {}) do
		n.text = n.text or ""
		n.options = istable(n.options) and n.options or {}

		for _, o in ipairs(n.options) do
			o.text = o.text or ""
			o.actions = istable(o.actions) and o.actions or {}
		end

		nodes[tostring(id)] = n
	end

	w.dialogue.nodes = nodes

	w.quests = istable(w.quests) and w.quests or {}

	for _, q in ipairs(w.quests) do
		q.name = q.name or q.id
		q.desc = q.desc or ""
		q.objectives = istable(q.objectives) and q.objectives or {}
		q.rewards = istable(q.rewards) and q.rewards or {}
		q.rewards.money = tonumber(q.rewards.money) or 0
		q.rewards.items = istable(q.rewards.items) and q.rewards.items or {}
		q.cooldown = tonumber(q.cooldown) or 0
	end

	w.shop = istable(w.shop) and w.shop or {}
	w.shop.items = istable(w.shop.items) and w.shop.items or {}

	for _, it in ipairs(w.shop.items) do
		it.buy = tonumber(it.buy) or -1
		it.sell = tonumber(it.sell) or -1
		it.stock = tonumber(it.stock) or -1
		it.max = tonumber(it.max) or it.stock
	end
end

local function SetIdle(e)
	for k, v in ipairs(e:GetSequenceList()) do
		if (v:lower():find("idle") and v != "idlenoise") then
			return e:ResetSequence(k)
		end
	end
end

local function ItemButton(parent, uid, onPick)
	local b

	b = UI.Button(parent, UI.ItemName(uid), function()
		UI.ItemPicker(function(id)
			b.label = UI.ItemName(id)
			onPick(id)
		end)
	end)

	return b
end

local function CondCount(c)
	if (!c) then return 0 end

	local n = 0

	if (c.faction and c.faction != "") then n = n + 1 end
	if (c.quest and c.quest != "") then n = n + 1 end
	if (c.item and c.item != "") then n = n + 1 end
	if ((tonumber(c.money) or 0) > 0) then n = n + 1 end

	return n
end

-- ============================================================
-- Окно условий
-- ============================================================

local function EditCond(work, opt, done)
	local c = table.Copy(opt.cond or {})
	local ov, box = UI.Modal("Условия показа варианта", 620, 560)

	UI.Hint(box, "Игрок увидит этот вариант, только если подходит под ВСЕ заполненные условия. Пустые поля игнорируются.")

	-- фракция
	local facE = UI.Field(box, "Фракции (uniqueID через запятую, пусто = любая)", c.faction or "", "например: citizen,vort", function(v) c.faction = v end)

	local facOpts = {}

	for _, f in ipairs(ix.faction.indices) do
		facOpts[#facOpts + 1] = {L(f.name), f.uniqueID}
	end

	local fc = UI.Combo(box, facOpts, nil, function(id)
		local cur = facE:GetText()

		facE:SetText(cur == "" and id or (cur .. "," .. id))
		c.faction = facE:GetText()
	end, "+ добавить фракцию из списка…")
	fc:Dock(TOP)
	fc:SetTall(30)
	fc:DockMargin(0, 4, 0, 0)

	-- задание
	local l = UI.Label(box, "Состояние задания", "ixNPC.EdSmall", C.dim)
	l:DockMargin(0, 10, 0, 3)

	local qr = UI.Row(box, 32)

	local sc = UI.Combo(qr, QSTATES, c.state or "active", function(v) c.state = v end)
	sc:Dock(RIGHT)
	sc:SetWide(210)
	sc:DockMargin(8, 0, 0, 0)

	local qc = UI.Combo(qr, QuestOptions(work, true), c.quest or "", function(v) c.quest = v end)
	qc:Dock(FILL)

	-- предмет
	l = UI.Label(box, "Нужен предмет в инвентаре", "ixNPC.EdSmall", C.dim)
	l:DockMargin(0, 10, 0, 3)

	local ir = UI.Row(box, 32)

	local amt = UI.NumEntry(ir, c.amount or 1, "кол-во", function(v) c.amount = tonumber(v) or 1 end)
	amt:Dock(RIGHT)
	amt:SetWide(80)
	amt:DockMargin(8, 0, 0, 0)

	local clear = UI.IconButton(ir, "icon16/cross.png", nil, "danger")
	clear:Dock(RIGHT)
	clear:DockMargin(8, 0, 0, 0)

	local ib = ItemButton(ir, c.item or "", function(id) c.item = id end)
	ib:Dock(FILL)

	clear.DoClick = function()
		c.item = ""
		ib.label = UI.ItemName("")
	end

	-- деньги
	UI.Field(box, "Минимум денег у игрока", c.money or 0, "0 = не проверять", function(v) c.money = tonumber(v) or 0 end)

	local footer = UI.Row(box, 40)
	footer:Dock(BOTTOM)

	local ok = UI.Button(footer, "Готово", function()
		local out = {}

		if (c.faction and c.faction != "") then out.faction = c.faction end

		if (c.quest and c.quest != "") then
			out.quest = c.quest
			out.state = c.state or "active"
		end

		if (c.item and c.item != "") then
			out.item = c.item
			out.amount = math.max(1, tonumber(c.amount) or 1)
		end

		if ((tonumber(c.money) or 0) > 0) then out.money = tonumber(c.money) end

		opt.cond = table.Count(out) > 0 and out or nil

		ov:Remove()
		done()
	end, "accent")
	ok:Dock(RIGHT)
	ok:SetWide(160)

	local reset = UI.Button(footer, "Сбросить всё", function()
		opt.cond = nil

		ov:Remove()
		done()
	end, "danger")
	reset:Dock(LEFT)
	reset:SetWide(160)
end

-- ============================================================
-- Окно действий
-- ============================================================

local function EditActions(work, opt, done)
	local acts = table.Copy(opt.actions or {})
	local ov, box = UI.Modal("Действия при выборе варианта", 760, 580)

	UI.Hint(box, "Выполняются сверху вниз в момент, когда игрок выбирает этот вариант.")

	local footer = UI.Row(box, 40)
	footer:Dock(BOTTOM)

	local scroll = UI.Scroll(box)
	scroll:Dock(FILL)

	local list = scroll:GetCanvas()
	local Rebuild

	local function Row(i, a)
		local card = UI.Card(list, 54)

		local del = UI.IconButton(card, "icon16/cross.png", function()
			table.remove(acts, i)
			Rebuild()
		end, "danger")
		del:Dock(RIGHT)
		del:DockMargin(8, 0, 0, 0)

		local tc = UI.Combo(card, ACTION_TYPES, a.type, function(v)
			a.type = v
			timer.Simple(0, Rebuild)
		end)
		tc:Dock(LEFT)
		tc:SetWide(190)
		tc:DockMargin(0, 0, 8, 0)

		local t = a.type

		if (t == "giveMoney" or t == "takeMoney") then
			local e = UI.NumEntry(card, a.value or 0, "сумма", function(v) a.value = tonumber(v) or 0 end)
			e:Dock(LEFT)
			e:SetWide(150)
		elseif (t == "giveItem" or t == "takeItem") then
			local amt = UI.NumEntry(card, a.amount or 1, "кол-во", function(v) a.amount = tonumber(v) or 1 end)
			amt:Dock(RIGHT)
			amt:SetWide(80)
			amt:DockMargin(8, 0, 0, 0)

			local ib = ItemButton(card, a.item or "", function(id) a.item = id end)
			ib:Dock(FILL)
		elseif (t == "startQuest" or t == "completeQuest") then
			local qc = UI.Combo(card, QuestOptions(work, false), a.quest or "", function(v) a.quest = v end, "— выберите задание —")
			qc:Dock(FILL)
		else
			local l = vgui.Create("DLabel", card)
			l:SetFont("ixNPC.Ed")
			l:SetTextColor(C.dim)
			l:SetText("Откроет окно торговли с этим NPC")
			l:Dock(FILL)
		end
	end

	Rebuild = function()
		if (!IsValid(list)) then return end

		list:Clear()

		for i, a in ipairs(acts) do Row(i, a) end

		if (#acts == 0) then
			local l = UI.Label(list, "Действий нет. Нажмите «Добавить действие».", "ixNPC.Ed", C.dim)
			l:DockMargin(4, 10, 0, 0)
		end
	end

	Rebuild()

	local add = UI.Button(footer, "+ Добавить действие", function()
		if (#acts >= 10) then return end

		acts[#acts + 1] = {type = "giveMoney", value = 100, amount = 1, item = "", quest = ""}
		Rebuild()
	end)
	add:Dock(LEFT)
	add:SetWide(210)

	local ok = UI.Button(footer, "Готово", function()
		opt.actions = acts

		ov:Remove()
		done()
	end, "accent")
	ok:Dock(RIGHT)
	ok:SetWide(160)
end

-- ============================================================
-- Главное окно редактора
-- ============================================================

net.Receive("ixNPCEditOpen", function()
	local ent = net.ReadEntity()
	local len = net.ReadUInt(16)
	local json = util.Decompress(net.ReadData(len))
	local def = json and util.JSONToTable(json)

	if (IsValid(ent) and def) then PLUGIN:OpenEditor(ent, def) end
end)

function PLUGIN:OpenEditor(ent, def)
	if (IsValid(self.editor)) then self.editor:Remove() end

	local work = table.Copy(def)
	Normalize(work)
	UI.SetAccent(UI.HexToColor(work.color))

	local sel = {node = work.dialogue.start, quest = work.quests[1] and work.quests[1].id}
	local P, B = {}, {}
	local cur = "general"
	local frame, status

	local function Rebuild(id)
		if (IsValid(P[id])) then B[id](P[id]) end
	end

	local function Status(text, good)
		status = {text = text, good = good}
	end

	-- ---------- каркас ----------
	local W, H = math.min(ScrW() - 40, 1240), math.min(ScrH() - 40, 790)

	frame = vgui.Create("EditablePanel")
	frame:SetSize(W, H)
	frame:Center()
	frame:MakePopup()
	frame.fade = 0
	self.editor = frame

	frame.Paint = function(s, w, h)
		s.fade = Lerp(FrameTime() * 10, s.fade, 1)
		surface.SetAlphaMultiplier(s.fade)
		draw.RoundedBox(10, 0, 0, w, h, C.bg)
	end

	frame.PaintOver = function() surface.SetAlphaMultiplier(1) end

	-- шапка
	local header = vgui.Create("DPanel", frame)
	header:Dock(TOP)
	header:SetTall(64)

	header.Paint = function(s, w, h)
		draw.RoundedBoxEx(10, 0, 0, w, h, C.panel, true, true, false, false)
		surface.SetDrawColor(UI.Accent())
		surface.DrawRect(0, h - 2, w, 2)
		draw.SimpleText("РЕДАКТОР NPC", "ixNPC.EdSmall", 24, 12, C.dim)
		draw.SimpleText(work.name != "" and work.name or "Без имени", "ixNPC.EdTitle", 24, 28, C.text)
	end

	header.OnMousePressed = function(s)
		local fx, fy = frame:GetPos()

		s.drag = {gui.MouseX() - fx, gui.MouseY() - fy}
		s:MouseCapture(true)
	end

	header.OnMouseReleased = function(s)
		s.drag = nil
		s:MouseCapture(false)
	end

	header.Think = function(s)
		if (s.drag) then frame:SetPos(gui.MouseX() - s.drag[1], gui.MouseY() - s.drag[2]) end
	end

	local closeBtn = UI.Button(header, "X", function() frame:Remove() end, "danger")
	closeBtn:SetSize(40, 32)
	closeBtn:SetPos(W - 56, 16)

	-- подвал
	local footer = vgui.Create("DPanel", frame)
	footer:Dock(BOTTOM)
	footer:SetTall(64)
	footer:DockPadding(16, 12, 16, 12)

	footer.Paint = function(s, w, h)
		draw.RoundedBoxEx(10, 0, 0, w, h, C.panel, false, false, true, true)

		if (status) then
			draw.SimpleText(status.text, "ixNPC.Ed", 16 + 3 * 120 + 24, h / 2, status.good and C.good or C.bad, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	-- сайдбар
	local side = vgui.Create("DPanel", frame)
	side:Dock(LEFT)
	side:SetWide(210)
	side:DockPadding(10, 14, 10, 10)
	side.Paint = function(s, w, h)
		surface.SetDrawColor(0, 0, 0, 70)
		surface.DrawRect(0, 0, w, h)
	end

	local content = vgui.Create("DPanel", frame)
	content:Dock(FILL)
	content.Paint = Noop

	local TABS = {
		{"general", "Основное", "icon16/user_edit.png", function() return "" end},
		{"dialogue", "Диалоги", "icon16/comments.png", function() return table.Count(work.dialogue.nodes) end},
		{"quests", "Задания", "icon16/book_open.png", function() return #work.quests end},
		{"shop", "Магазин", "icon16/cart.png", function() return #work.shop.items end}
	}

	local function ShowPage(id)
		cur = id

		for k, p in pairs(P) do p:SetVisible(k == id) end

		Rebuild(id)
	end

	for _, t in ipairs(TABS) do
		local b = vgui.Create("DButton", side)
		b:SetText("")
		b:Dock(TOP)
		b:SetTall(48)
		b:DockMargin(0, 0, 0, 6)
		b.hov = 0

		b.Paint = function(s, w, h)
			local active = cur == t[1]
			local a = UI.Accent()

			s.hov = Lerp(FrameTime() * 12, s.hov, (active or s:IsHovered()) and 1 or 0)

			draw.RoundedBox(6, 0, 0, w, h, Color(a.r * 0.3 * s.hov + C.panel.r * (1 - s.hov), a.g * 0.3 * s.hov + C.panel.g * (1 - s.hov), a.b * 0.3 * s.hov + C.panel.b * (1 - s.hov)))

			if (active) then
				surface.SetDrawColor(a)
				surface.DrawRect(0, 8, 3, h - 16)
			end

			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(UI.Mat(t[3]))
			surface.DrawTexturedRect(16, h / 2 - 8, 16, 16)

			draw.SimpleText(t[2], "ixNPC.EdBold", 44, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local n = t[4]()

			if (n != "") then
				draw.SimpleText(n, "ixNPC.Ed", w - 14, h / 2, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			end
		end

		b.DoClick = function()
			surface.PlaySound("ui/buttonclickrelease.wav")
			ShowPage(t[1])
		end

		P[t[1]] = vgui.Create("DPanel", content)
		P[t[1]]:Dock(FILL)
		P[t[1]].Paint = Noop
		P[t[1]]:SetVisible(false)
	end

	-- ============================================================
	-- Страница: Основное
	-- ============================================================

	B.general = function(page)
		page:Clear()

		local right = vgui.Create("DPanel", page)
		right:Dock(RIGHT)
		right:SetWide(380)
		right:DockMargin(0, 16, 16, 16)
		right:DockPadding(8, 8, 8, 8)
		right.Paint = function(s, w, h) draw.RoundedBox(8, 0, 0, w, h, C.panel) end

		local prev = vgui.Create("DModelPanel", right)
		prev:Dock(FILL)

		local basePaint = prev.Paint

		prev.Paint = function(s, w, h)
			local a = UI.Accent()

			draw.RoundedBox(6, 0, 0, w, h, Color(10, 10, 14))
			surface.SetDrawColor(a.r, a.g, a.b, 28)
			surface.DrawRect(0, h * 0.55, w, h * 0.45)
			basePaint(s, w, h)
		end

		prev.LayoutEntity = function(s, e)
			e:SetAngles(Angle(0, (RealTime() * 30) % 360, 0))
			e:SetSkin(work.skin or 0)
			s:RunAnimation()
		end

		local skinLbl

		local function SkinMax()
			return IsValid(prev.Entity) and math.max(0, prev.Entity:SkinCount() - 1) or 0
		end

		local function UpdateSkinLabel()
			if (IsValid(skinLbl)) then
				skinLbl:SetText("Скин " .. (work.skin or 0) .. " из " .. SkinMax())
			end
		end

		local function ApplyModel()
			if (util.IsValidModel(work.model)) then
				prev:SetModel(work.model)

				local e = prev.Entity

				if (IsValid(e)) then
					SetIdle(e)

					local mn, mx = e:GetRenderBounds()
					local size = math.max(mx.z - mn.z, mx.x - mn.x, mx.y - mn.y)

					prev:SetFOV(40)
					prev:SetCamPos(Vector(size * 1.5, 0, (mn.z + mx.z) / 2 + size * 0.05))
					prev:SetLookAt((mn + mx) / 2)
				end

				work.skin = math.min(work.skin or 0, SkinMax())
			end

			UpdateSkinLabel()
		end

		local left = vgui.Create("DPanel", page)
		left:Dock(FILL)
		left.Paint = Noop

		local scroll = UI.Scroll(left)
		scroll:Dock(FILL)

		local body = scroll:GetCanvas()
		body:DockPadding(22, 6, 22, 24)

		UI.Section(body, "Имя и описание")
		UI.Field(body, "Имя NPC", work.name, "Например: Старый Сталкер", function(v) work.name = v end)
		UI.Field(body, "Описание (видно при наведении)", work.desc, "Торговец", function(v) work.desc = v end)

		UI.Section(body, "Внешность")

		local ml = UI.Label(body, "Модель", "ixNPC.EdSmall", C.dim)
		ml:DockMargin(0, 4, 0, 3)

		local row = UI.Row(body, 32)
		local modelE

		local presets = UI.Combo(row, PRESET_MODELS, nil, function(v)
			work.model = v
			modelE:SetText(v)
			ApplyModel()
		end, "Пресеты…")
		presets:Dock(RIGHT)
		presets:SetWide(190)
		presets:DockMargin(8, 0, 0, 0)

		modelE = UI.Entry(row, work.model, "models/…/…mdl", function(v)
			work.model = v
			ApplyModel()
		end)
		modelE:Dock(FILL)

		local sr = UI.Row(body, 32)
		sr:DockMargin(0, 8, 0, 0)

		local plus = UI.Button(sr, "+", function()
			work.skin = math.min(SkinMax(), (work.skin or 0) + 1)
			UpdateSkinLabel()
		end)
		plus:Dock(RIGHT)
		plus:SetWide(40)

		local minus = UI.Button(sr, "-", function()
			work.skin = math.max(0, (work.skin or 0) - 1)
			UpdateSkinLabel()
		end)
		minus:Dock(LEFT)
		minus:SetWide(40)

		skinLbl = vgui.Create("DLabel", sr)
		skinLbl:SetFont("ixNPC.Ed")
		skinLbl:SetTextColor(C.text)
		skinLbl:SetContentAlignment(5)
		skinLbl:Dock(FILL)

		UI.Section(body, "Цвет диалога")
		UI.Hint(body, "Этот цвет используется в окне диалога и подсвечивает редактор.")

		local mixer = vgui.Create("DColorMixer", body)
		mixer:Dock(TOP)
		mixer:SetTall(130)
		mixer:SetPalette(false)
		mixer:SetAlphaBar(false)
		mixer:SetWangs(true)
		mixer:SetColor(UI.HexToColor(work.color))

		mixer.ValueChanged = function(_, col)
			work.color = UI.ColorToHex(col)
			UI.SetAccent(col)
		end

		local sw = UI.Row(body, 30)
		sw:DockMargin(0, 8, 0, 0)

		for _, hex in ipairs(PRESET_COLORS) do
			local b = vgui.Create("DButton", sw)
			b:SetText("")
			b:Dock(LEFT)
			b:SetWide(34)
			b:DockMargin(0, 0, 6, 0)

			b.Paint = function(s, w, h)
				local col = UI.HexToColor(hex)

				draw.RoundedBox(6, 0, 0, w, h, col)

				if (work.color == hex) then
					surface.SetDrawColor(255, 255, 255)
					surface.DrawOutlinedRect(0, 0, w, h, 2)
				end
			end

			b.DoClick = function()
				work.color = hex
				mixer:SetColor(UI.HexToColor(hex))
				UI.SetAccent(UI.HexToColor(hex))
			end
		end

		UI.Section(body, "Прочее")

		local tg = UI.Toggle(body, "Скрыть значок диалога над головой", work.noBubble, function(v) work.noBubble = v end)
		tg:Dock(TOP)
		tg:SetTall(30)

		ApplyModel()
	end

	-- ============================================================
	-- Страница: Диалоги
	-- ============================================================

	B.dialogue = function(page)
		page:Clear()

		local nodes = work.dialogue.nodes

		if (!nodes[sel.node]) then
			sel.node = nodes[work.dialogue.start] and work.dialogue.start or SortedKeys(nodes)[1]
		end

		local self2 = B.dialogue

		-- левая колонка
		local left = vgui.Create("DPanel", page)
		left:Dock(LEFT)
		left:SetWide(250)
		left:DockPadding(12, 12, 8, 12)
		left.Paint = function(s, w, h)
			surface.SetDrawColor(0, 0, 0, 45)
			surface.DrawRect(0, 0, w, h)
		end

		local hl = UI.Label(left, "Узлы диалога", "ixNPC.EdBold", C.text)
		hl:DockMargin(0, 0, 0, 8)

		local add = UI.Button(left, "+ Новый узел", function()
			Derma_StringRequest("Новый узел", "ID узла (латиницей, без пробелов):", "node" .. (table.Count(nodes) + 1), function(id)
				id = string.Trim(id)

				if (id == "" or nodes[id]) then return end

				nodes[id] = {text = "Текст реплики NPC…", options = {}}
				sel.node = id
				Rebuild("dialogue")
			end)
		end, "accent")
		add:Dock(BOTTOM)
		add:SetTall(38)

		local lscroll = UI.Scroll(left)
		lscroll:Dock(FILL)

		for _, id in ipairs(SortedKeys(nodes)) do
			local n = nodes[id]
			local b = vgui.Create("DButton", lscroll:GetCanvas())

			b:SetText("")
			b:Dock(TOP)
			b:SetTall(54)
			b:DockMargin(0, 0, 4, 4)

			b.Paint = function(s, w, h)
				local active = sel.node == id
				local a = UI.Accent()

				draw.RoundedBox(6, 0, 0, w, h, active and Color(a.r * 0.3 + 18, a.g * 0.3 + 18, a.b * 0.3 + 18) or (s:IsHovered() and C.panel2 or C.panel))

				if (active) then
					surface.SetDrawColor(a)
					surface.DrawRect(0, 8, 3, h - 16)
				end

				local tx = 14

				if (work.dialogue.start == id) then
					surface.SetDrawColor(255, 255, 255)
					surface.SetMaterial(UI.Mat("icon16/star.png"))
					surface.DrawTexturedRect(12, 9, 16, 16)
					tx = 34
				end

				draw.SimpleText(id, "ixNPC.EdBold", tx, 8, C.text)

				local snippet = UI.UTF8Sub(n.text, 26)

				if ((UI.UTF8Len(n.text) or 0) > 26) then snippet = snippet .. "…" end

				draw.SimpleText(snippet, "ixNPC.EdSmall", 14, 32, C.dim)
				draw.SimpleText(#n.options, "ixNPC.EdSmall", w - 10, 10, C.dim, TEXT_ALIGN_RIGHT)
			end

			b.DoClick = function()
				sel.node = id
				Rebuild("dialogue")
			end
		end

		-- правая колонка
		local node = nodes[sel.node]

		if (!node) then
			local l = UI.Label(page, "Нет узлов. Создайте первый кнопкой слева.", "ixNPC.Ed", C.dim)
			l:DockMargin(30, 30, 0, 0)

			return
		end

		local rscroll = UI.Scroll(page)
		rscroll:Dock(FILL)

		local body = rscroll:GetCanvas()
		body:DockPadding(22, 12, 22, 24)

		-- панель действий над узлом
		local bar = UI.Row(body, 36)

		local isStart = work.dialogue.start == sel.node

		local del = UI.Button(bar, "Удалить", function()
			Derma_Query("Удалить узел «" .. sel.node .. "»?", "Подтверждение", "Да", function()
				nodes[sel.node] = nil

				for _, n in pairs(nodes) do
					for _, o in ipairs(n.options) do
						if (o.next == sel.node) then o.next = nil end
					end
				end

				sel.node = nil
				Rebuild("dialogue")
			end, "Нет")
		end, "danger")
		del:Dock(RIGHT)
		del:SetWide(100)
		del:DockMargin(8, 0, 0, 0)
		del:SetEnabled(!isStart)

		local ren = UI.Button(bar, "Переименовать", function()
			local old = sel.node

			Derma_StringRequest("Переименовать узел", "Новый ID узла:", old, function(new)
				new = string.Trim(new)

				if (new == "" or new == old or nodes[new]) then return end

				nodes[new] = nodes[old]
				nodes[old] = nil

				if (work.dialogue.start == old) then work.dialogue.start = new end

				for _, n in pairs(nodes) do
					for _, o in ipairs(n.options) do
						if (o.next == old) then o.next = new end
					end
				end

				sel.node = new
				Rebuild("dialogue")
			end)
		end)
		ren:Dock(RIGHT)
		ren:SetWide(140)
		ren:DockMargin(8, 0, 0, 0)

		local st = UI.Button(bar, isStart and "Стартовый узел" or "Сделать стартовым", function()
			work.dialogue.start = sel.node
			Rebuild("dialogue")
		end, isStart and "accent" or nil)
		st:Dock(RIGHT)
		st:SetWide(180)
		st:DockMargin(8, 0, 0, 0)

		local ttl = vgui.Create("DLabel", bar)
		ttl:SetFont("ixNPC.EdTitle")
		ttl:SetTextColor(C.text)
		ttl:SetText("Узел: " .. sel.node)
		ttl:Dock(FILL)

		UI.Section(body, "Реплика NPC")
		UI.Hint(body, "Можно использовать: {player} — имя персонажа, {money} — его деньги, {npc} — имя NPC.")

		local te = UI.Entry(body, node.text, "Что говорит NPC…", function(v) node.text = v end, true)
		te:Dock(TOP)
		te:SetTall(110)

		UI.Section(body, "Варианты ответа игрока (" .. #node.options .. " / 12)")

		for i, opt in ipairs(node.options) do
			local card = UI.Card(body, 124)
			card.stripe = UI.TAGS[UI.OptionTag(opt)][2]

			-- строка 1: текст + управление
			local r1 = UI.Row(card, 32)

			local x = UI.IconButton(r1, "icon16/cross.png", function()
				table.remove(node.options, i)
				Rebuild("dialogue")
			end, "danger")
			x:Dock(RIGHT)
			x:DockMargin(6, 0, 0, 0)

			local dn = UI.IconButton(r1, "icon16/arrow_down.png", function()
				if (i < #node.options) then
					node.options[i], node.options[i + 1] = node.options[i + 1], node.options[i]
					Rebuild("dialogue")
				end
			end)
			dn:Dock(RIGHT)
			dn:DockMargin(6, 0, 0, 0)

			local up = UI.IconButton(r1, "icon16/arrow_up.png", function()
				if (i > 1) then
					node.options[i], node.options[i - 1] = node.options[i - 1], node.options[i]
					Rebuild("dialogue")
				end
			end)
			up:Dock(RIGHT)
			up:DockMargin(6, 0, 0, 0)

			local num = vgui.Create("DLabel", r1)
			num:SetFont("ixNPC.EdBold")
			num:SetTextColor(C.dim)
			num:SetText(i .. ".")
			num:SetContentAlignment(5)
			num:Dock(LEFT)
			num:SetWide(28)

			local oe = UI.Entry(r1, opt.text, "Текст кнопки…", function(v) opt.text = v end)
			oe:Dock(FILL)

			-- строка 2: переход
			local r2 = UI.Row(card, 32)
			r2:DockMargin(0, 4, 0, 0)

			local lbl = vgui.Create("DLabel", r2)
			lbl:SetFont("ixNPC.EdSmall")
			lbl:SetTextColor(C.dim)
			lbl:SetText("Ведёт к:")
			lbl:Dock(LEFT)
			lbl:SetWide(62)

			local nc = UI.Combo(r2, NodeOptions(work), opt.next or "", function(v)
				opt.next = (v != "") and v or nil
				timer.Simple(0, function() Rebuild("dialogue") end)
			end)
			nc:Dock(LEFT)
			nc:SetWide(230)

			local cn = CondCount(opt.cond)
			local an = #opt.actions

			local ab = UI.Button(r2, "Действия: " .. an, function()
				EditActions(work, opt, function() Rebuild("dialogue") end)
			end, an > 0 and "accent" or nil)
			ab:Dock(RIGHT)
			ab:SetWide(150)
			ab:DockMargin(8, 0, 0, 0)

			local cb = UI.Button(r2, "Условия: " .. cn, function()
				EditCond(work, opt, function() Rebuild("dialogue") end)
			end, cn > 0 and "accent" or nil)
			cb:Dock(RIGHT)
			cb:SetWide(150)
		end

		if (#node.options < 12) then
			local addOpt = UI.Button(body, "+ Добавить вариант ответа", function()
				node.options[#node.options + 1] = {text = "Новый вариант", actions = {}}
				Rebuild("dialogue")
			end)
			addOpt:Dock(TOP)
			addOpt:SetTall(38)
		end
	end

	-- ============================================================
	-- Страница: Задания
	-- ============================================================

	local function RenameQuest(old, new)
		for _, n in pairs(work.dialogue.nodes) do
			for _, o in ipairs(n.options) do
				if (o.cond and o.cond.quest == old) then o.cond.quest = new end

				for _, a in ipairs(o.actions) do
					if (a.quest == old) then a.quest = new end
				end
			end
		end
	end

	local function FindQuest(id)
		for i, q in ipairs(work.quests) do
			if (q.id == id) then return q, i end
		end
	end

	B.quests = function(page)
		page:Clear()

		if (!FindQuest(sel.quest)) then sel.quest = work.quests[1] and work.quests[1].id end

		local left = vgui.Create("DPanel", page)
		left:Dock(LEFT)
		left:SetWide(250)
		left:DockPadding(12, 12, 8, 12)
		left.Paint = function(s, w, h)
			surface.SetDrawColor(0, 0, 0, 45)
			surface.DrawRect(0, 0, w, h)
		end

		local hl = UI.Label(left, "Задания", "ixNPC.EdBold", C.text)
		hl:DockMargin(0, 0, 0, 8)

		local add = UI.Button(left, "+ Новое задание", function()
			local n = #work.quests + 1
			local id = "quest_" .. n

			while (FindQuest(id)) do
				n = n + 1
				id = "quest_" .. n
			end

			work.quests[#work.quests + 1] = {
				id = id, name = "Новое задание", desc = "",
				objectives = {{type = "kill", class = "npc_zombie", amount = 3}},
				rewards = {money = 50, items = {}}, repeatable = false, cooldown = 0
			}

			sel.quest = id
			Rebuild("quests")
		end, "accent")
		add:Dock(BOTTOM)
		add:SetTall(38)

		local lscroll = UI.Scroll(left)
		lscroll:Dock(FILL)

		for _, q in ipairs(work.quests) do
			local b = vgui.Create("DButton", lscroll:GetCanvas())

			b:SetText("")
			b:Dock(TOP)
			b:SetTall(54)
			b:DockMargin(0, 0, 4, 4)

			b.Paint = function(s, w, h)
				local active = sel.quest == q.id
				local a = UI.Accent()

				draw.RoundedBox(6, 0, 0, w, h, active and Color(a.r * 0.3 + 18, a.g * 0.3 + 18, a.b * 0.3 + 18) or (s:IsHovered() and C.panel2 or C.panel))

				if (active) then
					surface.SetDrawColor(a)
					surface.DrawRect(0, 8, 3, h - 16)
				end

				draw.SimpleText(UI.UTF8Sub(q.name, 22), "ixNPC.EdBold", 14, 8, C.text)
				draw.SimpleText(q.id, "ixNPC.EdSmall", 14, 32, C.dim)
			end

			b.DoClick = function()
				sel.quest = q.id
				Rebuild("quests")
			end
		end

		local q = FindQuest(sel.quest)

		if (!q) then
			local l = UI.Label(page, "Заданий пока нет. Создайте первое кнопкой слева.", "ixNPC.Ed", C.dim)
			l:DockMargin(30, 30, 0, 0)

			return
		end

		local rscroll = UI.Scroll(page)
		rscroll:Dock(FILL)

		local body = rscroll:GetCanvas()
		body:DockPadding(22, 6, 22, 24)

		UI.Section(body, "Описание")

		local idE = UI.Field(body, "ID задания (уникальный, используется в диалогах)", q.id, "quest_1")

		idE.OnLoseFocus = function(s)
			local new = string.Trim(s:GetText())

			if (new == "" or new == q.id or FindQuest(new)) then
				s:SetText(q.id)
				return
			end

			RenameQuest(q.id, new)
			q.id = new
			sel.quest = new
			Rebuild("quests")
		end

		UI.Field(body, "Название", q.name, "Название задания", function(v) q.name = v end)
		UI.Field(body, "Описание", q.desc, "Что нужно сделать…", function(v) q.desc = v end, true, 70)

		-- цели
		UI.Section(body, "Цели (" .. #q.objectives .. " / 8)")

		for i, o in ipairs(q.objectives) do
			local card = UI.Card(body, 100)

			local r1 = UI.Row(card, 32)

			local x = UI.IconButton(r1, "icon16/cross.png", function()
				table.remove(q.objectives, i)
				Rebuild("quests")
			end, "danger")
			x:Dock(RIGHT)
			x:DockMargin(6, 0, 0, 0)

			local tc = UI.Combo(r1, {{"Принести предмет", "item"}, {"Убить", "kill"}}, o.type, function(v)
				o.type = v

				if (v == "item") then o.item = o.item or "" else o.class = o.class or "npc_zombie" end

				timer.Simple(0, function() Rebuild("quests") end)
			end)
			tc:Dock(LEFT)
			tc:SetWide(170)
			tc:DockMargin(0, 0, 8, 0)

			local amt = UI.NumEntry(r1, o.amount or 1, "кол-во", function(v) o.amount = tonumber(v) or 1 end)
			amt:Dock(RIGHT)
			amt:SetWide(80)

			if (o.type == "item") then
				local ib = ItemButton(r1, o.item or "", function(id) o.item = id end)
				ib:Dock(FILL)
				ib:DockMargin(0, 0, 8, 0)
			else
				local pc = UI.Combo(r1, KILL_PRESETS, nil, nil, "Пресеты…")
				pc:Dock(RIGHT)
				pc:SetWide(150)
				pc:DockMargin(8, 0, 8, 0)

				local ce = UI.Entry(r1, o.class or "", "класс NPC, например npc_zombie", function(v) o.class = v end)
				ce:Dock(FILL)

				pc.OnSelect = function(_, _, _, data)
					o.class = data
					ce:SetText(data)
				end
			end

			local r2 = UI.Row(card, 32)
			r2:DockMargin(0, 6, 0, 0)

			if (o.type == "item") then
				local tg = UI.Toggle(r2, "Забрать предметы при сдаче", o.consume == true, function(v) o.consume = v end)
				tg:Dock(LEFT)
				tg:SetWide(280)
			end

			local te = UI.Entry(r2, o.text or "", "Своя подпись цели (необязательно)", function(v) o.text = v end)
			te:Dock(FILL)
		end

		if (#q.objectives < 8) then
			local addO = UI.Button(body, "+ Добавить цель", function()
				q.objectives[#q.objectives + 1] = {type = "kill", class = "npc_zombie", amount = 1}
				Rebuild("quests")
			end)
			addO:Dock(TOP)
			addO:SetTall(36)
		end

		-- награда
		UI.Section(body, "Награда")
		UI.Field(body, "Деньги", q.rewards.money, "0", function(v) q.rewards.money = tonumber(v) or 0 end)

		local rl = UI.Label(body, "Предметы-награды", "ixNPC.EdSmall", C.dim)
		rl:DockMargin(0, 10, 0, 4)

		for i, it in ipairs(q.rewards.items) do
			local row = UI.Row(body, 34)

			local x = UI.IconButton(row, "icon16/cross.png", function()
				table.remove(q.rewards.items, i)
				Rebuild("quests")
			end, "danger")
			x:Dock(RIGHT)
			x:DockMargin(6, 0, 0, 0)

			local amt = UI.NumEntry(row, it.amount or 1, "кол-во", function(v) it.amount = tonumber(v) or 1 end)
			amt:Dock(RIGHT)
			amt:SetWide(80)
			amt:DockMargin(6, 0, 0, 0)

			local ib = ItemButton(row, it.item or "", function(id) it.item = id end)
			ib:Dock(FILL)
		end

		local addR = UI.Button(body, "+ Добавить предмет в награду", function()
			UI.ItemPicker(function(id)
				q.rewards.items[#q.rewards.items + 1] = {item = id, amount = 1}
				Rebuild("quests")
			end)
		end)
		addR:Dock(TOP)
		addR:SetTall(36)

		-- повтор
		UI.Section(body, "Повторное выполнение")

		local tg = UI.Toggle(body, "Задание можно брать повторно", q.repeatable == true, function(v)
			q.repeatable = v
			Rebuild("quests")
		end)
		tg:Dock(TOP)
		tg:SetTall(30)

		if (q.repeatable) then
			UI.Field(body, "Пауза перед повтором (минуты)", math.floor((q.cooldown or 0) / 60), "0", function(v)
				q.cooldown = math.max(0, (tonumber(v) or 0) * 60)
			end)
		end

		local delQ = UI.Button(body, "Удалить задание", function()
			Derma_Query("Удалить задание «" .. q.name .. "»?", "Подтверждение", "Да", function()
				local _, idx = FindQuest(q.id)

				table.remove(work.quests, idx)
				sel.quest = nil
				Rebuild("quests")
			end, "Нет")
		end, "danger")
		delQ:Dock(TOP)
		delQ:SetTall(36)
		delQ:DockMargin(0, 24, 0, 0)
	end

	-- ============================================================
	-- Страница: Магазин
	-- ============================================================

	B.shop = function(page)
		page:Clear()

		local items = work.shop.items

		local top = vgui.Create("DPanel", page)
		top:Dock(TOP)
		top:SetTall(86)
		top:DockPadding(22, 14, 22, 0)
		top.Paint = Noop

		local t = UI.Label(top, "Ассортимент магазина (" .. #items .. " / 100)", "ixNPC.EdTitle", C.text)
		t:SetTall(32)

		UI.Hint(top, "Цена покупки — сколько платит игрок. Цена продажи — сколько получит игрок, сдавая предмет NPC. Пустое поле = недоступно; пустой остаток = бесконечно.")

		local add = UI.Button(page, "+ Добавить предмет", function()
			if (#items >= 100) then return end

			UI.ItemPicker(function(id)
				local price = ix.item.list[id] and ix.item.list[id].price or 10

				items[#items + 1] = {item = id, buy = price, sell = math.floor(price / 2), stock = -1, max = -1}
				Rebuild("shop")
			end)
		end, "accent")
		add:Dock(BOTTOM)
		add:SetTall(40)
		add:DockMargin(22, 8, 22, 14)

		local scroll = UI.Scroll(page)
		scroll:Dock(FILL)

		local body = scroll:GetCanvas()
		body:DockPadding(22, 0, 22, 8)

		-- заголовки колонок
		local hr = UI.Row(body, 22)

		local function Head(text, wide, dock)
			local l = vgui.Create("DLabel", hr)
			l:SetFont("ixNPC.EdSmall")
			l:SetTextColor(C.dim)
			l:SetText(text)
			l:Dock(dock or RIGHT)

			if (wide) then l:SetWide(wide) end

			l:SetContentAlignment(5)
		end

		Head("", 34 + 8)
		Head("Остаток", 90)
		Head("Продажа", 110)
		Head("Покупка", 110)
		Head("Товар", nil, FILL)

		for i, it in ipairs(items) do
			local card = UI.Card(body, 56)
			local row = UI.Row(card, 36)
			row:DockMargin(0, 0, 0, 0)

			local x = UI.IconButton(row, "icon16/cross.png", function()
				table.remove(items, i)
				Rebuild("shop")
			end, "danger")
			x:Dock(RIGHT)
			x:DockMargin(8, 0, 0, 0)

			local stock = UI.NumEntry(row, it.stock >= 0 and it.stock or "", "∞", function(v)
				local n = tonumber(v)

				it.stock = n and math.max(0, math.floor(n)) or -1
				it.max = it.stock
			end)
			stock:Dock(RIGHT)
			stock:SetWide(82)
			stock:DockMargin(8, 0, 0, 0)

			local sell = UI.NumEntry(row, it.sell >= 0 and it.sell or "", "—", function(v)
				local n = tonumber(v)
				it.sell = n and math.max(0, math.floor(n)) or -1
			end)
			sell:Dock(RIGHT)
			sell:SetWide(102)
			sell:DockMargin(8, 0, 0, 0)

			local buy = UI.NumEntry(row, it.buy >= 0 and it.buy or "", "—", function(v)
				local n = tonumber(v)
				it.buy = n and math.max(0, math.floor(n)) or -1
			end)
			buy:Dock(RIGHT)
			buy:SetWide(102)
			buy:DockMargin(8, 0, 0, 0)

			local ib = ItemButton(row, it.item, function(id) it.item = id end)
			ib:Dock(FILL)
		end

		if (#items == 0) then
			local l = UI.Label(body, "Магазин пуст. Добавьте первый предмет кнопкой внизу.", "ixNPC.Ed", C.dim)
			l:DockMargin(4, 14, 0, 0)
		end
	end

	-- ============================================================
	-- Подвал: кнопки
	-- ============================================================

	local function Save()
		if (!work.dialogue.nodes[work.dialogue.start]) then
			Status("Не задан стартовый узел диалога — выберите его на вкладке «Диалоги».", false)
			return
		end

		local data = util.Compress(util.TableToJSON(work))

		if (#data > 60000) then
			Status("Слишком большой конфиг — уменьшите число узлов или заданий.", false)
			return
		end

		net.Start("ixNPCEditSave")
			net.WriteEntity(ent)
			net.WriteUInt(#data, 16)
			net.WriteData(data, #data)
		net.SendToServer()

		frame:Remove()
	end

	local save = UI.Button(footer, "Сохранить и применить", Save, "accent")
	save:Dock(RIGHT)
	save:SetWide(230)

	local cancel = UI.Button(footer, "Отмена", function() frame:Remove() end)
	cancel:Dock(RIGHT)
	cancel:SetWide(110)
	cancel:DockMargin(0, 0, 10, 0)

	local pv = UI.Button(footer, "Предпросмотр", function()
		if (!work.dialogue.nodes[work.dialogue.start]) then
			Status("Нет стартового узла — нечего показывать.", false)
			return
		end

		PLUGIN:PreviewDialogue(work, cur == "dialogue" and sel.node or nil)
	end)
	pv:Dock(LEFT)
	pv:SetWide(120)

	local ex = UI.Button(footer, "Экспорт", function()
		SetClipboardText(util.TableToJSON(work, true))
		Status("Конфиг скопирован в буфер обмена (JSON).", true)
	end)
	ex:Dock(LEFT)
	ex:SetWide(110)
	ex:DockMargin(8, 0, 0, 0)

	local im = UI.Button(footer, "Импорт", function()
		local ov, box = UI.Modal("Импорт конфига", 700, 520)

		UI.Hint(box, "Вставьте сюда JSON, ранее скопированный кнопкой «Экспорт» (Ctrl+V). Текущий конфиг будет заменён.")

		local e = UI.Entry(box, "", "{ … }", nil, true)
		e:Dock(FILL)
		e:DockMargin(0, 0, 0, 10)

		local ok = UI.Button(box, "Применить", function()
			local tbl = util.JSONToTable(e:GetText())

			if (!istable(tbl)) then
				Status("Не удалось прочитать JSON.", false)
				ov:Remove()
				return
			end

			for k in pairs(work) do work[k] = nil end
			for k, v in pairs(tbl) do work[k] = v end

			Normalize(work)
			UI.SetAccent(UI.HexToColor(work.color))
			sel.node = work.dialogue.start
			sel.quest = work.quests[1] and work.quests[1].id

			ov:Remove()
			Status("Конфиг импортирован.", true)
			ShowPage(cur)
		end, "accent")
		ok:Dock(BOTTOM)
		ok:SetTall(38)
	end)
	im:Dock(LEFT)
	im:SetWide(110)
	im:DockMargin(8, 0, 0, 0)

	ShowPage("general")
end
