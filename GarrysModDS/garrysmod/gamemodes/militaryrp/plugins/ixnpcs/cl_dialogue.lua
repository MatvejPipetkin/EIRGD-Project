local PLUGIN = PLUGIN
local UI = PLUGIN.ui
local S = UI.S

CreateClientConVar("ix_npc_camera", "1", true, false, "Кинематографичная камера во время диалога с NPC (1/0)")

-- ============================================================
-- Вариант ответа
-- ============================================================

local OPT = {}

function OPT:Init()
	self:SetText("")
	self.hov = 0
end

function OPT:Setup(index, text, tag, width, delay, accent, onChoose)
	self.index = index
	self.tag = UI.TAGS[tag] and tag or "talk"
	self.delay = delay
	self.accent = accent
	self.onChoose = onChoose
	self.birth = CurTime()
	self.lines = UI.Wrap(text, "ixNPC.Opt", width - S(56) - S(48))

	surface.SetFont("ixNPC.Opt")
	local _, lh = surface.GetTextSize("A")

	self.lh = lh
	self:SetTall(math.max(S(52), #self.lines * lh + S(22)))
end

function OPT:Shown()
	return math.Clamp((CurTime() - self.birth - self.delay) * 4, 0, 1)
end

function OPT:OnCursorEntered()
	if (self:Shown() > 0.6) then
		surface.PlaySound("ui/buttonrollover.wav")
	end
end

function OPT:DoClick()
	if (self:Shown() < 0.6) then return end

	surface.PlaySound("ui/buttonclickrelease.wav")
	self.onChoose(self.index)
end

function OPT:Paint(w, h)
	local show = self:Shown()

	if (show <= 0) then return end

	self.hov = Lerp(FrameTime() * 14, self.hov, self:IsHovered() and 1 or 0)

	local a = self.accent or UI.col.accent
	local hov = self.hov
	local shift = (1 - show) * S(60) + hov * S(8)
	local tag = UI.TAGS[self.tag]

	surface.SetAlphaMultiplier(show * (UI.dlgFade or 1))

	-- фон
	surface.SetDrawColor(8, 8, 12, 165 + 50 * hov)
	surface.DrawRect(shift, 0, w - shift, h)

	surface.SetDrawColor(a.r, a.g, a.b, 45 * hov)
	surface.DrawRect(shift, 0, w - shift, h)

	-- акцентная полоса слева
	surface.SetDrawColor(a.r, a.g, a.b, 255)
	surface.DrawRect(shift, 0, S(3) + S(5) * hov, h)

	-- номер
	local bs = S(30)
	local bx, by = shift + S(18), h / 2 - bs / 2

	if (hov > 0.5) then
		draw.RoundedBox(4, bx, by, bs, bs, a)
		draw.SimpleText(self.index, "ixNPC.Num", bx + bs / 2, by + bs / 2, Color(15, 15, 18), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	else
		draw.RoundedBox(4, bx, by, bs, bs, Color(255, 255, 255, 22))
		draw.SimpleText(self.index, "ixNPC.Num", bx + bs / 2, by + bs / 2, Color(255, 255, 255, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	-- текст
	local tx = shift + S(18) + bs + S(14)
	local ty = h / 2 - (#self.lines * self.lh) / 2

	for i, line in ipairs(self.lines) do
		draw.SimpleText(line, "ixNPC.Opt", tx, ty + (i - 1) * self.lh, Color(255, 255, 255, 215 + 40 * hov))
	end

	-- иконка тега
	surface.SetDrawColor(tag[2].r, tag[2].g, tag[2].b, 140 + 115 * hov)
	surface.SetMaterial(UI.Mat(tag[1]))
	surface.DrawTexturedRect(w - S(36), h / 2 - 8, 16, 16)

	surface.SetAlphaMultiplier(1)
end

vgui.Register("ixNPCOption", OPT, "DButton")

-- ============================================================
-- Окно диалога
-- ============================================================

local DLG = {}

function DLG:Init()
	local sw, sh = ScrW(), ScrH()

	self:SetSize(sw, sh)
	self:SetPos(0, 0)
	self:MakePopup()

	self.fade = 0
	self.born = CurTime()
	self.buttons = {}
	self.lines = {}
	self.opts = {}
	self.total = 0
	self.panelH = S(400)
	self.padX = math.max(S(70), sw * 0.07)
	self.optW = math.min(sw * 0.36, S(660))
	self.optX = sw - self.padX - self.optW
	self.textW = self.optX - self.padX - S(70)

	self.scroll = vgui.Create("DScrollPanel", self)
	self.scroll:SetPos(self.optX, sh - self.panelH + S(34))
	self.scroll:SetSize(self.optW, self.panelH - S(96))

	local vbar = self.scroll:GetVBar()
	vbar:SetWide(4)
	vbar:SetHideButtons(true)
	vbar.Paint = function() end
	vbar.btnGrip.Paint = function(s, w, h) draw.RoundedBox(2, 0, 0, w, h, Color(255, 255, 255, 90)) end

	local close = vgui.Create("DButton", self)
	close:SetText("")
	close:SetSize(S(40), S(40))
	close:SetPos(sw - S(40) - S(24), S(15))

	close.Paint = function(s, w, h)
		local c = s:IsHovered() and color_white or Color(255, 255, 255, 120)

		surface.SetDrawColor(c)
		surface.DrawLine(w * 0.3, h * 0.3, w * 0.7, h * 0.7)
		surface.DrawLine(w * 0.3, h * 0.31, w * 0.7, h * 0.71)
		surface.DrawLine(w * 0.7, h * 0.3, w * 0.3, h * 0.7)
		surface.DrawLine(w * 0.7, h * 0.31, w * 0.3, h * 0.71)
	end

	close.DoClick = function() self:Close() end
end

function DLG:SetNode(name, desc, color, text, opts)
	self.npcName = name
	self.desc = desc or ""
	self.accent = color
	UI.dlgAccent = color

	self.lines = UI.Wrap(text, "ixNPC.Text", self.textW)
	self.total = 0

	for _, l in ipairs(self.lines) do
		self.total = self.total + (UI.UTF8Len(l) or #l)
	end

	self.start = CurTime() + 0.25
	self.opts = opts
	self.built = false
	self.buttons = {}
	self.scroll:GetCanvas():Clear()
	self.scroll:GetVBar():SetScroll(0)
end

function DLG:BuildOptions()
	self.built = true

	local canvas = self.scroll:GetCanvas()
	local opts = self.opts

	if (#opts == 0) then
		opts = {{text = "Закончить разговор", tag = "leave", close = true}}
	end

	local w = self.optW - S(8)

	for i, o in ipairs(opts) do
		local b = vgui.Create("ixNPCOption", canvas)
		b:Dock(TOP)
		b:DockMargin(0, 0, 0, S(6))
		b:Setup(i, o.text, o.tag, w, (i - 1) * 0.07, self.accent, function(idx)
			if (o.close) then
				self:Close()
			else
				self.onChoose(idx)
			end
		end)

		self.buttons[i] = b
	end
end

function DLG:Skip()
	self.start = CurTime() - 999
end

function DLG:Think()
	self.fade = Lerp(FrameTime() * 8, self.fade, self.closing and 0 or 1)
	UI.dlgFade = self.fade

	if (self.closing) then
		if (self.fade < 0.03) then self:Remove() end

		return
	end

	if (!self.preview and (!IsValid(self.npc) or LocalPlayer():GetPos():DistToSqr(self.npc:GetPos()) > 320 * 320)) then
		self:Close()
		return
	end

	if (!self.built and (CurTime() - self.start) * 70 >= self.total) then
		self:BuildOptions()
	end
end

function DLG:Paint(w, h)
	local f = self.fade
	local a = self.accent or UI.col.accent

	surface.SetAlphaMultiplier(f)

	-- общее затемнение
	surface.SetDrawColor(0, 0, 0, 70)
	surface.DrawRect(0, 0, w, h)

	-- нижний градиент
	local gh = self.panelH + S(150)
	local steps = 40
	local sh = math.ceil(gh / steps)

	for i = 0, steps - 1 do
		local t = (i + 1) / steps

		surface.SetDrawColor(5, 5, 9, 240 * t * t)
		surface.DrawRect(0, h - gh + i * sh, w, sh + 1)
	end

	-- верхняя «киношная» полоса
	local bar = S(70)
	local ease = math.min(1, (CurTime() - self.born) * 2)

	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(0, 0, w, bar)
	surface.SetDrawColor(a.r, a.g, a.b, 255)
	surface.DrawRect(0, bar, w * ease, 2)

	draw.SimpleText("РАЗГОВОР", "ixNPC.Hint", self.padX, bar / 2, Color(a.r, a.g, a.b, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	-- табличка с именем
	local x = self.padX
	local y0 = h - self.panelH + S(34)

	draw.SimpleText(self.npcName or "", "ixNPC.Name", x + 2, y0 + 2, Color(0, 0, 0, 200))
	draw.SimpleText(self.npcName or "", "ixNPC.Name", x, y0, color_white)

	local lw = math.min(1, (CurTime() - self.born) * 2.5) * S(240)

	surface.SetDrawColor(a.r, a.g, a.b, 255)
	surface.DrawRect(x, y0 + S(60), lw, 3)

	if (self.desc != "") then
		draw.SimpleText(self.desc, "ixNPC.Desc", x, y0 + S(70), Color(255, 255, 255, 120))
	end

	-- текст с эффектом печати
	surface.SetFont("ixNPC.Text")

	local _, lh = surface.GetTextSize("A")
	local ty = y0 + S(118)
	local left = math.max(0, math.floor((CurTime() - self.start) * 70))

	surface.SetDrawColor(a.r, a.g, a.b, 140)
	surface.DrawRect(x - S(22), ty + 4, 3, math.max(0, #self.lines * lh - 8))

	for i, line in ipairs(self.lines) do
		if (left <= 0) then break end

		local n = UI.UTF8Len(line) or #line
		local part = (left < n) and UI.UTF8Sub(line, left) or line
		local ly = ty + (i - 1) * lh

		draw.SimpleText(part, "ixNPC.Text", x + 2, ly + 2, Color(0, 0, 0, 190))
		draw.SimpleText(part, "ixNPC.Text", x, ly, Color(245, 245, 250))

		left = left - n
	end

	draw.SimpleText("[1–9] выбрать    [ПРОБЕЛ] пропустить печать    [ESC] закончить разговор", "ixNPC.Hint", w / 2, h - S(22), Color(255, 255, 255, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	surface.SetAlphaMultiplier(1)
end

function DLG:OnKeyCodePressed(key)
	if (key >= KEY_1 and key <= KEY_9) then
		local b = self.buttons[key - KEY_0]

		if (self.built and IsValid(b)) then b:DoClick() end
	elseif (key == KEY_SPACE or key == KEY_ENTER) then
		self:Skip()
	end
end

function DLG:OnMousePressed()
	self:Skip()
end

function DLG:Close(silent)
	if (self.closing) then return end

	self.closing = true

	if (!self.preview and !silent) then
		net.Start("ixNPCClose")
		net.SendToServer()
	end
end

vgui.Register("ixNPCDialogue", DLG, "EditablePanel")

-- Esc закрывает диалог, а не открывает меню паузы
hook.Add("OnPauseMenuShow", "ixNPCDialogue", function()
	local d = PLUGIN.dialogue

	if (IsValid(d) and !d.closing) then
		d:Close()

		return false
	end
end)

-- ============================================================
-- API
-- ============================================================

function PLUGIN:ShowDialogue(ent, name, desc, color, text, opts, preview, onChoose)
	if (IsValid(self.shop)) then
		self.shop.silent = true
		self.shop:Remove()
	end

	local dlg = self.dialogue

	if (IsValid(dlg) and dlg.closing) then
		dlg:Remove()
		dlg = nil
	end

	if (!IsValid(dlg)) then
		dlg = vgui.Create("ixNPCDialogue")
		self.dialogue = dlg
	end

	dlg.npc = ent
	dlg.preview = preview
	dlg.onChoose = onChoose or function(idx)
		net.Start("ixNPCChoose")
			net.WriteUInt(idx, 5)
		net.SendToServer()
	end

	if (IsValid(ent)) then self.lastNPC = ent end

	dlg:SetNode(name, desc, color, text, opts)
end

-- Предпросмотр диалога из редактора (без сервера, условия и действия игнорируются)
function PLUGIN:PreviewDialogue(def, startNode)
	local nodes = def.dialogue.nodes
	local color = UI.HexToColor(def.color)
	local char = LocalPlayer():GetCharacter()

	local function Fmt(t)
		t = string.Replace(t or "", "{player}", char and char:GetName() or LocalPlayer():Name())
		t = string.Replace(t, "{money}", ix.currency.Get(char and char:GetMoney() or 0))

		return string.Replace(t, "{npc}", def.name or "")
	end

	local function Show(id)
		local node = nodes[id]

		if (!node) then
			if (IsValid(self.dialogue)) then self.dialogue:Close(true) end

			return
		end

		local opts = {}

		for _, o in ipairs(node.options or {}) do
			opts[#opts + 1] = {text = Fmt(o.text), tag = UI.OptionTag(o)}
		end

		self:ShowDialogue(nil, def.name, def.desc, color, Fmt(node.text), opts, true, function(i)
			local o = node.options[i]

			if (o and o.next and o.next != "" and nodes[o.next]) then
				Show(o.next)
			else
				self.dialogue:Close(true)
			end
		end)
	end

	Show(startNode or def.dialogue.start)
end

-- ============================================================
-- Кинематографичная камера
-- ============================================================

local camT = 0

local function HeadPos(npc)
	local bone = npc:LookupBone("ValveBiped.Bip01_Head1")

	if (bone) then
		local p = npc:GetBonePosition(bone)

		if (p) then return p end
	end

	return npc:GetPos() + Vector(0, 0, 64)
end

hook.Add("CalcView", "ixNPCCamera", function(client, origin, angles, fov)
	local dlg = PLUGIN.dialogue
	local npc = PLUGIN.lastNPC

	local active = GetConVar("ix_npc_camera"):GetBool() and IsValid(npc)
		and IsValid(dlg) and !dlg.closing and !dlg.preview

	camT = Lerp(FrameTime() * (active and 2.5 or 4), camT, active and 1 or 0)

	if (camT < 0.005 or !IsValid(npc)) then return end

	local head = HeadPos(npc)
	local toPlayer = origin - head
	toPlayer.z = 0

	if (toPlayer:LengthSqr() < 1) then toPlayer = -npc:GetForward() end

	toPlayer:Normalize()

	local right = toPlayer:Angle():Right()
	local wanted = head + toPlayer * 58 + right * 15 + Vector(0, 0, 2)

	local tr = util.TraceHull({
		start = head, endpos = wanted,
		mins = Vector(-5, -5, -5), maxs = Vector(5, 5, 5),
		filter = {npc, client}, mask = MASK_SOLID_BRUSHONLY
	})

	wanted = tr.HitPos

	local look = (head - Vector(0, 0, 3) - wanted):Angle()

	return {
		origin = LerpVector(camT, origin, wanted),
		angles = LerpAngle(camT, angles, look),
		fov = Lerp(camT, fov, 42),
		drawviewer = false
	}
end)

hook.Add("PreDrawViewModel", "ixNPCCamera", function()
	if (camT > 0.2) then return true end
end)

hook.Add("RenderScreenspaceEffects", "ixNPCCamera", function()
	if (camT < 0.01) then return end

	DrawColorModify({
		["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = -0.04 * camT,
		["$pp_colour_contrast"] = 1 + 0.14 * camT,
		["$pp_colour_colour"] = 1 - 0.18 * camT,
		["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0
	})
end)
