local PLUGIN = PLUGIN or ix.plugin.Get("roleplay.fake_recognize")

CHAT_RECOGNIZED = CHAT_RECOGNIZED or {}
CHAT_RECOGNIZED["ic"] = true
CHAT_RECOGNIZED["y"] = true
CHAT_RECOGNIZED["w"] = true
CHAT_RECOGNIZED["me"] = true
CHAT_RECOGNIZED["looc"] = true

function PLUGIN:IsRecognizedChatType(chatType)
	if (CHAT_RECOGNIZED[chatType]) then
		return true
	end
end

function PLUGIN:GetCharacterDescription(client)
	if (client:GetCharacter() and client != LocalPlayer() and LocalPlayer():GetCharacter() and
		!LocalPlayer():GetCharacter():DoesRecognize(client:GetCharacter()) and !hook.Run("IsPlayerRecognized", client)) then
		return L"noRecog"
	end
end

function PLUGIN:ShouldAllowScoreboardOverride(client)
	if (ix.config.Get("scoreboardRecognition")) then
		return true
	end
end

function PLUGIN:GetCharacterName(client, chatType)
	if (client != LocalPlayer()) then
		local character = client:GetCharacter()
		if not character then return end
		local ourCharacter = LocalPlayer():GetCharacter()
		if (ourCharacter and character and !ourCharacter:DoesRecognize(character) and !hook.Run("IsPlayerRecognized", client)) then
			if (chatType and hook.Run("IsRecognizedChatType", chatType)) then
				local description = character:GetDescription()
				if (#description > 40) then
					description = description:utf8sub(1, 37).."..."
				end
				return "["..description.."]"
			elseif (!chatType) then
				return L"unknown"
			end
		end
	end
end

local function Recognize(level,name)
	net.Start("ixRecognize")
		net.WriteUInt(level, 2)
		net.WriteString(name)
	net.SendToServer()
end

net.Receive("ixRecognizeMenu", function(length)
	vgui.Create("fkname_recognitionmenu")
end)

net.Receive("ixRecognizeDone", function(length)
	hook.Run("CharacterRecognized")
end)

function PLUGIN:CharacterRecognized(client, recogCharID)
	surface.PlaySound("buttons/button17.wav")
end


--------------------------------------------------------------------------------
-- ВИЗУАЛ: минималистичный синий стиль
--------------------------------------------------------------------------------

local C = {
	bg      = Color(7, 14, 28, 235),
	header  = Color(10, 24, 48, 235),
	btn     = Color(12, 26, 50),
	line    = Color(52, 120, 210),
	lineDim = Color(30, 64, 112),
	accent  = Color(72, 160, 255),
	hi      = Color(215, 235, 255),
	text    = Color(160, 195, 235),
	textDim = Color(98, 130, 172),
}

local MENU_W, MENU_H = 620, 444

surface.CreateFont("f3.btn", {
	font = "Nagonia",
	extended = true,
	size = 24,
	weight = 500,
	blursize = 0,
	scanlines = 0,
	antialias = true,
})

surface.CreateFont("f3.title", {
	font = "Nagonia",
	extended = true,
	size = 26,
	weight = 600,
	antialias = true,
})

surface.CreateFont("f3.name", {
	font = "Nagonia",
	extended = true,
	size = 28,
	weight = 600,
	antialias = true,
})

surface.CreateFont("f3.small", {
	font = "Nagonia",
	extended = true,
	size = 16,
	weight = 500,
	antialias = true,
})

local function LerpColor(t, a, b)
	return Color(Lerp(t, a.r, b.r), Lerp(t, a.g, b.g), Lerp(t, a.b, b.b), Lerp(t, a.a, b.a))
end

-- Обрезка текста по ширине (шрифт должен быть установлен заранее)
local function FitText(text, maxW)
	if (surface.GetTextSize(text) <= maxW) then
		return text
	end

	local n = utf8.len(text) or #text

	while (n > 1) do
		n = n - 1

		local cut = text:utf8sub(1, n).."..."

		if (surface.GetTextSize(cut) <= maxW) then
			return cut
		end
	end

	return text
end

local function DrawLabel(text, x, y)
	surface.SetFont("f3.small")
	surface.SetTextColor(C.textDim)
	surface.SetTextPos(x, y)
	surface.DrawText(text)
end


--------------------------------------------------------------------------------
-- Кнопка
--------------------------------------------------------------------------------
local PANEL = {}

function PANEL:Init()
	self.BaseClass.SetText(self, "")

	self:SetSize(32, 40)

	self:SetTextColor(C.text)
	self:SetFont("f3.btn")
	self:SetTextInset(32 + 13, 0)
	self:SetContentAlignment(4)

	self.text = ""
	self.icon = 0
	self.hover = 0
end
function PANEL:SetText(value)
	self.text = value
end

function PANEL:Paint(w, h)
	local disabled = self:GetDisabled()
	local target = (self:IsHovered() and !disabled) and 1 or 0

	self.hover = Lerp(math.min(FrameTime() * 12, 1), self.hover or 0, target)

	-- IsPicked задаётся снаружи (не путать со встроенным Panel:IsSelected)
	local picked = (self.IsPicked and self.IsPicked()) and 1 or 0
	local f = math.max(self.hover, picked * 0.6)
	local a = disabled and 0.35 or 1

	-- фон
	surface.SetDrawColor(C.btn.r, C.btn.g, C.btn.b, 150 * a)
	surface.DrawRect(0, 0, w, h)

	-- мягкая подсветка при наведении / выборе
	surface.SetDrawColor(C.accent.r, C.accent.g, C.accent.b, 38 * f * a)
	surface.DrawRect(0, 0, w, h)

	-- тонкая рамка
	local bc = LerpColor(f, C.lineDim, C.line)
	surface.SetDrawColor(bc.r, bc.g, bc.b, 255 * a)
	surface.DrawOutlinedRect(0, 0, w, h, 1)

	-- полоска слева (появляется при наведении)
	surface.SetDrawColor(C.accent.r, C.accent.g, C.accent.b, 255 * f * a)
	surface.DrawRect(0, 0, 3, h)

	-- текст
	local tx = 14 + 3 * f

	surface.SetFont("f3.btn")
	local txt = FitText(self.text or "", w - tx - 12)
	local _, th = surface.GetTextSize(txt)

	local col = LerpColor(f, C.text, C.hi)
	surface.SetTextColor(col.r, col.g, col.b, 255 * (disabled and 0.45 or 1))
	surface.SetTextPos(tx, h / 2 - th / 2)
	surface.DrawText(txt)
end
vgui.Register("f3.btn", PANEL, "DButton")



--------------------------------------------------------------------------------
-- Меню
--------------------------------------------------------------------------------
local PANEL = {}
local Buttons = {}
timer.Simple(0.1,function()
	Buttons = 	{
	[0] = L"rgnLookingAt",
	[1] = L"rgnWhisper",
	[2] = L"rgnTalk",
	[3] = L"rgnYell",
	}
end)

local VariantsSetsName = {
	["Новое имя"] = function(panel)
		Derma_StringRequest("Добавление нового имени для представлений","Введите новое имя","Андрей",function(text)
				fkname_RECOGNIZE_SELECTEDNAME = text
				netstream.Start("fkname_ActionName",{text})
				timer.Simple(0.1,function()
					if IsValid(panel) then
						panel:GetParent():LoadNames()
					end
				end)
			end,nil,"Добавить","Отказаться")
	 end,
	["Настоящее имя"] = function() fkname_RECOGNIZE_SELECTEDNAME = LocalPlayer():Name() end,
}


fkname_RECOGNIZE_SELECTEDNAME = nil;
fkname_RECOGNIZE_MENU = nil
function PANEL:Init()
    if IsValid(fkname_RECOGNIZE_MENU) then
        self:Remove()
        return
    end
    fkname_RECOGNIZE_MENU = self
    local data = LocalPlayer():GetCharacter():GetData("fkname_UsedNames",{})
    fkname_RECOGNIZE_SELECTEDNAME = (LocalPlayer():Name() == fkname_RECOGNIZE_SELECTEDNAME or data[fkname_RECOGNIZE_SELECTEDNAME]) and fkname_RECOGNIZE_SELECTEDNAME or nil 

	self:SetSize(MENU_W, MENU_H)
	self:SetPos(ScrW() / 2 - MENU_W / 2, ScrH() / 2 - MENU_H / 2)
	self:SetAlpha(0)
	self:AlphaTo(255,0.3)
	self:MakePopup()

	self.Paint = function(this,w,h)
		ix.util.DrawBlur(this, 6)

		-- основа
		surface.SetDrawColor(C.bg)
		surface.DrawRect(0, 0, w, h)

		-- шапка
		surface.SetDrawColor(C.header)
		surface.DrawRect(0, 0, w, 48)
		surface.SetDrawColor(C.lineDim)
		surface.DrawRect(0, 47, w, 1)
		surface.SetDrawColor(C.accent)
		surface.DrawRect(0, 46, 64, 2)

		-- заголовок
		surface.SetFont("f3.title")
		local title = "ПРЕДСТАВЛЕНИЕ"
		local _, th = surface.GetTextSize(title)
		surface.SetTextColor(C.hi)
		surface.SetTextPos(20, 24 - th / 2)
		surface.DrawText(title)

		-- подзаголовок
		local sub = "выберите имя и громкость"
		surface.SetFont("f3.small")
		local sw, sh = surface.GetTextSize(sub)
		surface.SetTextColor(C.textDim)
		surface.SetTextPos(w - 56 - sw, 24 - sh / 2)
		surface.DrawText(sub)

		-- рамка
		surface.SetDrawColor(C.lineDim)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end


	local CloseButton = self:Add("f3.btn")
	CloseButton:SetPos(MENU_W - 40, 10)
	CloseButton:SetSize(28,28)
	CloseButton:SetText("")
	CloseButton.DoClick = function()
		self:AlphaTo(0,0.3,0,function()
			self:Remove()
		end)
	end
	CloseButton.Paint = function(btn, w, h)
		btn.hv = Lerp(math.min(FrameTime() * 12, 1), btn.hv or 0, btn:IsHovered() and 1 or 0)

		surface.SetDrawColor(C.accent.r, C.accent.g, C.accent.b, 40 * btn.hv)
		surface.DrawRect(0, 0, w, h)

		local xc = LerpColor(btn.hv, C.textDim, C.hi)
		surface.SetDrawColor(xc)
		surface.DrawLine(9, 9, w - 9, h - 9)
		surface.DrawLine(w - 9, 9, 9, h - 9)
	end

	self.list = self:Add("DPanelList")
	self.list:SetPos(16, 82)
	self.list:SetSize(340, 168)
	self.list:EnableVerticalScrollbar()
	self.list:SetPadding(4)
    self.list:SetSpacing(4)
	self.list.Paint = function(_, w, h)
		surface.SetDrawColor(3, 9, 20, 150)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(C.lineDim)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end
	self.list.PaintOver = function(lst, w, h)
		if (#lst:GetItems() == 0) then
			local text = "нет сохранённых имён"
			surface.SetFont("f3.small")
			local tw, th = surface.GetTextSize(text)
			surface.SetTextColor(C.textDim)
			surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
			surface.DrawText(text)
		end
	end

	local vbar = self.list.VBar
	if (IsValid(vbar)) then
		vbar:SetWide(4)
		vbar.Paint = function() end
		vbar.btnUp.Paint = function() end
		vbar.btnDown.Paint = function() end
		vbar.btnGrip.Paint = function(_, w, h)
			surface.SetDrawColor(C.accent.r, C.accent.g, C.accent.b, 150)
			surface.DrawRect(0, 0, w, h)
		end
	end

	self:LoadNames()
	self.PaintOver = function(this,w,h)
		DrawLabel("Сохранённые имена", 16, 60)
		DrawLabel("Представляетесь как:", 376, 60)
		DrawLabel("Действие", 16, 268)

		-- карточка выбранного имени
		local cx, cy, cw, ch = 376, 82, 228, 80

		surface.SetDrawColor(3, 9, 20, 150)
		surface.DrawRect(cx, cy, cw, ch)
		surface.SetDrawColor(C.lineDim)
		surface.DrawOutlinedRect(cx, cy, cw, ch, 1)

		local name = fkname_RECOGNIZE_SELECTEDNAME

		if (name) then
			surface.SetDrawColor(C.accent)
			surface.DrawRect(cx, cy, 3, ch)

			surface.SetFont("f3.name")
			local txt = FitText(name, cw - 28)
			local tw, th = surface.GetTextSize(txt)
			surface.SetTextColor(C.hi)
			surface.SetTextPos(cx + cw / 2 - tw / 2, cy + ch / 2 - th / 2)
			surface.DrawText(txt)
		else
			local txt = "не выбрано"
			surface.SetFont("f3.btn")
			local tw, th = surface.GetTextSize(txt)
			surface.SetTextColor(C.textDim)
			surface.SetTextPos(cx + cw / 2 - tw / 2, cy + ch / 2 - th / 2)
			surface.DrawText(txt)
		end
	end

	local xpos = 178

	for k,v in pairs(VariantsSetsName)do
		local SetName = self:Add("f3.btn")
		SetName:SetPos(376,xpos)
		SetName:SetSize(228,32)
		SetName:SetText(k)
		SetName.DoClick = v
		xpos = xpos + 40
	end
	self.buttons = {}
	xpos = 294
	for k = 0, 3 do
		local v = Buttons[k]
		if (v) then
			self.buttons[k] = self:Add("f3.btn")
			self.buttons[k]:SetSize(MENU_W - 32,30)
			self.buttons[k]:SetPos(16,xpos)
			self.buttons[k]:SetText(v)
			self.buttons[k].DoClick = function(this)
				self:Remove()
				Recognize(k,fkname_RECOGNIZE_SELECTEDNAME)
			end
			self.buttons[k]:SetDisabled(!fkname_RECOGNIZE_SELECTEDNAME)
			xpos = xpos + 34
		end
	end
end

-- Кнопки действий активны только когда выбрано имя
function PANEL:Think()
	local noName = !fkname_RECOGNIZE_SELECTEDNAME

	for _, btn in pairs(self.buttons or {}) do
		if (btn:GetDisabled() != noName) then
			btn:SetDisabled(noName)
		end
	end
end

function PANEL:LoadNames()
	for k,v in pairs(self.buttons or {})do
		v:SetDisabled(!fkname_RECOGNIZE_SELECTEDNAME)
	end
	for k,v in pairs(self.list:GetItems())do
		v:Remove()
	end
	local Names = LocalPlayer():GetCharacter():GetData("fkname_UsedNames",{})
	for k,v in pairs(Names) do
		local button = self.list:Add("f3.btn")
		button:SetSize(320,30)
		button:SetText(k)
		button.Text = k
		button.IsPicked = function() return fkname_RECOGNIZE_SELECTEDNAME == k end
		button.DoClick = function(this)
			Derma_Query("Представляться под именем "..k.."?","Выберите операцию","Выбрать",function() fkname_RECOGNIZE_SELECTEDNAME = k end,"Удалить",
            function() 
                netstream.Start("fkname_ActionName",{k,true})
                timer.Simple(0.1,function()
					self:LoadNames()
				end)
            end,"Отменить")
		end
		self.list:AddItem(button)
	end
end


vgui.Register("fkname_recognitionmenu",PANEL,"DPanel")