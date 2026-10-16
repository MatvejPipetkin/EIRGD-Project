local PLUGIN = PLUGIN

-- общий стиль меню (тот же, что в cl_menu.lua / cl_inventory.lua)
ix.menuStyle = ix.menuStyle or {accent = Color(90, 160, 235), projectName = "EIRGD"}

--[[
	НАСТРОЙКИ
]]
local CFG = {
	title = "СОСТОЯНИЕ", -- заголовок панели
	headerH = 34, -- высота шапки (при высоте экрана 1080)
	rowH = 28, -- высота одной строки
	labelW = 110, -- ширина колонки с названием
	valueW = 80, -- ширина колонки со значением справа
	smooth = 8, -- скорость плавного изменения шкалы
	lowThreshold = 0.25 -- ниже этой доли шкала начинает пульсировать
}

local function S(value)
	return math.floor(value * ScrH() / 1080 + 0.5)
end

local function GetAccent()
	return ix.menuStyle.accent or ix.config.Get("color") or Color(90, 160, 235)
end

--[[
	ШКАЛЫ
	get(client) -> доля 0..1, текст справа
	available() -> false, если шкала не поддерживается (например, плагин голода не загружен)
]]
local BARS = {
	{
		id = "health",
		label = "ЗДОРОВЬЕ",
		color = Color(205, 85, 75),
		get = function(client)
			local maxHealth = math.max(client:GetMaxHealth(), 1)
			local health = math.Clamp(client:Health(), 0, maxHealth)

			return health / maxHealth, health .. " / " .. maxHealth
		end
	},
	{
		id = "armor",
		label = "БРОНЯ",
		color = Color(90, 150, 225),
		get = function(client)
			local maxArmor = math.max(client.GetMaxArmor and client:GetMaxArmor() or 100, 1)
			local armor = math.Clamp(client:Armor(), 0, maxArmor)

			return armor / maxArmor, armor .. " / " .. maxArmor
		end
	},
	{
		id = "hunger",
		label = "ГОЛОД",
		color = Color(0, 153, 51),
		available = function()
			return isfunction(FindMetaTable("Player").GetHungerPercent)
		end,
		get = function(client)
			local fraction = 1 - client:GetHungerPercent()

			return fraction, math.Round(fraction * 100) .. "%"
		end
	},
	{
		id = "thirst",
		label = "ЖАЖДА",
		color = Color(0, 200, 255),
		available = function()
			return isfunction(FindMetaTable("Player").GetThirstPercent)
		end,
		get = function(client)
			local fraction = 1 - client:GetThirstPercent()

			return fraction, math.Round(fraction * 100) .. "%"
		end
	}
}

local COLOR_SHADOW = Color(0, 0, 0, 210)
local COLOR_TEXT = Color(255, 255, 255, 235)

local PANEL = {}

function PANEL:Init()
	self.headerH = S(CFG.headerH)
	self.rowH = S(CFG.rowH)
	self.rows = {}

	for _, bar in ipairs(BARS) do
		if (!bar.available or bar.available()) then
			self.rows[#self.rows + 1] = {bar = bar, value = nil}
		end
	end
end

-- высота панели под текущий набор шкал
function PANEL:GetDesiredHeight()
	return self.headerH + #self.rows * self.rowH + S(14)
end

function PANEL:Paint(width, height)
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local accent = GetAccent()
	local headerH = self.headerH
	local centerY = math.floor(headerH * 0.5)

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

	-- шкалы
	local barX = S(12) + S(CFG.labelW)
	local barW = width - barX - S(12) - S(CFG.valueW)
	local barH = S(12)
	local frameTime = FrameTime()

	for index, row in ipairs(self.rows) do
		local bar = row.bar
		local fraction, text = bar.get(client)

		fraction = math.Clamp(fraction or 0, 0, 1)

		-- плавное изменение
		row.value = row.value and Lerp(math.min(frameTime * CFG.smooth, 1), row.value, fraction) or fraction

		local rowY = headerH + S(8) + (index - 1) * self.rowH
		local midY = rowY + math.floor(self.rowH * 0.5) - S(4)
		local color = bar.color
		local alpha = 220

		-- пульсация при низком значении
		if (fraction <= CFG.lowThreshold) then
			alpha = 150 + math.abs(math.sin(CurTime() * 4)) * 105
		end

		-- название
		draw.SimpleText(bar.label, "ixMenuTinyFont", S(12) + 1, midY + 1, COLOR_SHADOW, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(bar.label, "ixMenuTinyFont", S(12), midY, Color(color.r, color.g, color.b, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		-- подложка и заливка
		local barY = midY - math.floor(barH * 0.5)

		surface.SetDrawColor(22, 27, 34, 235)
		surface.DrawRect(barX, barY, barW, barH)

		local fillW = math.floor((barW - 2) * row.value)

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

		draw.SimpleText(text or "", "ixMenuTinyFont", valueX + 1, midY + 1, COLOR_SHADOW, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		draw.SimpleText(text or "", "ixMenuTinyFont", valueX, midY, COLOR_TEXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

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

vgui.Register("ixStatusBars", PANEL, "EditablePanel")

-- вызывается из cl_inventory.lua сразу после создания основной сетки инвентаря
function PLUGIN:CreateInventoryFooter(canvas, inventoryPanel)
	if (!IsValid(canvas) or !IsValid(inventoryPanel)) then
		return
	end

	local panel = canvas:Add("ixStatusBars")
	panel:SetSize(inventoryPanel:GetWide(), panel:GetDesiredHeight())

	ix.gui.statusBars = panel
end
