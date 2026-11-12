local PLUGIN = PLUGIN

-- общий стиль меню (тот же, что в cl_menu.lua / cl_inventory.lua / statusbars)
ix.menuStyle = ix.menuStyle or {accent = Color(90, 160, 235), projectName = "EIRGD"}

--[[
	НАСТРОЙКИ
]]
local CFG = {
	title = "ВЕС", -- заголовок панели
	headerH = 34, -- высота шапки (при высоте экрана 1080)
	rowH = 28, -- высота одной строки
	labelW = 110, -- ширина колонки с названием
	valueW = 110, -- ширина колонки со значением справа
	smooth = 8, -- скорость плавного изменения шкалы
	warnThreshold = 0.75 -- с этой доли лимита шкала становится жёлтой
}

local function S(value)
	return math.floor(value * ScrH() / 1080 + 0.5)
end

local function GetAccent()
	return ix.menuStyle.accent or ix.config.Get("color") or Color(90, 160, 235)
end

local COLOR_OK = Color(95, 200, 120)
local COLOR_WARN = Color(215, 165, 60)
local COLOR_BAD = Color(205, 85, 75)
local COLOR_SPEED = Color(90, 150, 225)
local COLOR_SHADOW = Color(0, 0, 0, 210)
local COLOR_TEXT = Color(255, 255, 255, 235)

local PANEL = {}

function PANEL:Init()
	self.headerH = S(CFG.headerH)
	self.rowH = S(CFG.rowH)
	self.weightValue = nil
	self.speedValue = nil
end

-- высота панели: шапка + две шкалы (вес и скорость)
function PANEL:GetDesiredHeight()
	return self.headerH + 2 * self.rowH + S(14)
end

-- одна строка со шкалой
function PANEL:DrawRow(index, label, fraction, color, text, pulse, width)
	local midY = self.headerH + S(8) + (index - 1) * self.rowH + math.floor(self.rowH * 0.5) - S(4)
	local barX = S(12) + S(CFG.labelW)
	local barW = width - barX - S(12) - S(CFG.valueW)
	local barH = S(12)
	local barY = midY - math.floor(barH * 0.5)
	local alpha = 220

	if (pulse) then
		alpha = 150 + math.abs(math.sin(CurTime() * 4)) * 105
	end

	-- название
	draw.SimpleText(label, "ixMenuTinyFont", S(12) + 1, midY + 1, COLOR_SHADOW, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(label, "ixMenuTinyFont", S(12), midY, Color(color.r, color.g, color.b, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	-- подложка и заливка
	surface.SetDrawColor(22, 27, 34, 235)
	surface.DrawRect(barX, barY, barW, barH)

	local fillW = math.floor((barW - 2) * fraction)

	if (fillW > 0) then
		surface.SetDrawColor(color.r, color.g, color.b, alpha)
		surface.DrawRect(barX + 1, barY + 1, fillW, barH - 2)

		-- блик сверху
		surface.SetDrawColor(255, 255, 255, 28)
		surface.DrawRect(barX + 1, barY + 1, fillW, math.max(math.floor((barH - 2) * 0.4), 1))
	end

	-- деления каждые 10%
	surface.SetDrawColor(0, 0, 0, 110)

	for i = 1, 9 do
		surface.DrawRect(barX + math.floor(barW * i / 10), barY + 1, 1, barH - 2)
	end

	-- рамка
	surface.SetDrawColor(color.r, color.g, color.b, 90)
	surface.DrawOutlinedRect(barX, barY, barW, barH, 1)

	-- значение
	local valueX = width - S(12)

	draw.SimpleText(text, "ixMenuTinyFont", valueX + 1, midY + 1, COLOR_SHADOW, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	draw.SimpleText(text, "ixMenuTinyFont", valueX, midY, COLOR_TEXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

function PANEL:Paint(width, height)
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local accent = GetAccent()
	local headerH = self.headerH
	local centerY = math.floor(headerH * 0.5)

	local weight = client:GetCarryWeight()
	local maxWeight = client:GetMaxCarryWeight()
	local slow = client:GetWeightSlow()
	local over = weight - maxWeight
	local overweight = over > 0

	-- доля заполнения шкалы веса
	local ratio

	if (maxWeight > 0) then
		ratio = weight / maxWeight
	else
		ratio = weight > 0 and 1 or 0
	end

	local weightFraction = math.Clamp(ratio, 0, 1)
	local speedFraction = math.Clamp(1 - slow / 100, 0, 1)

	-- плавное изменение
	local step = math.min(FrameTime() * CFG.smooth, 1)

	self.weightValue = self.weightValue and Lerp(step, self.weightValue, weightFraction) or weightFraction
	self.speedValue = self.speedValue and Lerp(step, self.speedValue, speedFraction) or speedFraction

	local weightColor = COLOR_OK

	if (overweight) then
		weightColor = COLOR_BAD
	elseif (ratio >= CFG.warnThreshold) then
		weightColor = COLOR_WARN
	end

	draw.NoTexture()

	-- фон
	surface.SetDrawColor(8, 11, 16, 215)
	surface.DrawRect(0, 0, width, height)

	-- шапка
	surface.SetDrawColor(0, 0, 0, 90)
	surface.DrawRect(0, 0, width, headerH)

	for i = 1, 6 do
		surface.SetDrawColor(accent.r, accent.g, accent.b, 16 * (1 - i / 6) ^ 2)
		surface.DrawRect(1, headerH + i - 1, width - 2, 1)
	end

	surface.SetDrawColor(accent.r, accent.g, accent.b, 60)
	surface.DrawRect(0, headerH - 1, width, 1)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 230)
	surface.DrawRect(S(8), headerH - 2, S(40), 3)
	surface.DrawRect(S(8), centerY - S(7), 2, S(14))

	draw.SimpleText(CFG.title, "ixMenuTabFontSmall", S(20), centerY, Color(255, 255, 255, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	-- статус справа в шапке
	if (overweight) then
		local alpha = 170 + math.abs(math.sin(CurTime() * 4)) * 85

		draw.SimpleText("ПЕРЕГРУЗ  +" .. ix.weight.Format(over) .. " КГ", "ixMenuTinyFont", width - S(10), centerY,
			Color(COLOR_BAD.r, COLOR_BAD.g, COLOR_BAD.b, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	else
		draw.SimpleText("НОРМА", "ixMenuTinyFont", width - S(10), centerY,
			Color(accent.r, accent.g, accent.b, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	-- шкалы
	self:DrawRow(1, "ВЕС", self.weightValue, weightColor,
		ix.weight.Format(weight) .. " / " .. ix.weight.Format(maxWeight) .. " кг", overweight, width)

	local speedColor = COLOR_SPEED
	local speedText = "100%"

	if (slow > 0) then
		speedColor = COLOR_BAD
		speedText = math.Round(100 - slow) .. "%  (-" .. math.Round(slow) .. "%)"
	end

	self:DrawRow(2, "СКОРОСТЬ", self.speedValue, speedColor, speedText, slow > 0, width)

	-- внешняя рамка
	surface.SetDrawColor(accent.r, accent.g, accent.b, 45)
	surface.DrawOutlinedRect(0, 0, width, height, 1)

	-- яркие уголки
	local corner = S(10)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 230)
	surface.DrawRect(0, 0, corner, 1)
	surface.DrawRect(0, 0, 1, corner)
	surface.DrawRect(width - corner, 0, corner, 1)
	surface.DrawRect(width - 1, 0, 1, corner)
	surface.DrawRect(0, height - 1, corner, 1)
	surface.DrawRect(0, height - corner, 1, corner)
	surface.DrawRect(width - corner, height - 1, corner, 1)
	surface.DrawRect(width - 1, height - corner, 1, corner)
end

vgui.Register("ixWeightBar", PANEL, "EditablePanel")

-- вызывается из cl_inventory.lua сразу после создания основной сетки инвентаря
-- (панель статус-баров добавляется тем же хуком и окажется выше)
function PLUGIN:CreateInventoryFooter(canvas, inventoryPanel)
	if (!IsValid(canvas) or !IsValid(inventoryPanel) or !ix.config.Get("weightEnabled", true)) then
		return
	end

	local panel = canvas:Add("ixWeightBar")
	panel:SetSize(inventoryPanel:GetWide(), panel:GetDesiredHeight())

	ix.gui.weightBar = panel

	-- поднимаем всё окно (сетка + вес + состояние) выше на weightWindowOffset пикселей
	-- (значение для экрана 1080p, масштабируется). Если другой код переставит окно,
	-- смещение применяется заново относительно новой позиции.
	local offset = S(ix.config.Get("weightWindowOffset", 40))

	if (offset != 0) then
		canvas.weightLastY = nil

		local oldThink = canvas.Think

		canvas.Think = function(this)
			if (oldThink) then
				oldThink(this)
			end

			local x, y = this:GetPos()

			if (y != this.weightLastY) then
				this.weightLastY = y - offset
				this:SetPos(x, this.weightLastY)
			end
		end
	end
end

-- строка с весом в подсказке предмета
function PLUGIN:PopulateItemTooltip(tooltip, item)
	if (!ix.config.Get("weightEnabled", true) or !item or !tooltip.AddRow) then
		return
	end

	local total, amount = ix.weight.GetItemWeight(item)
	local text = "Вес: " .. ix.weight.Format(total) .. " кг"

	if (amount > 1) then
		text = "Вес: " .. ix.weight.Format(total / amount) .. " кг × " .. math.floor(amount) .. " = " .. ix.weight.Format(total) .. " кг"
	end

	local row = tooltip:AddRow("weight")
	row:SetText(text)
	row:SetFont("ixSmallFont")
	row:SetBackgroundColor(Color(60, 70, 85, 200))
	row:SizeToContents()
end
