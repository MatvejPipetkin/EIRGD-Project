-- bar manager
-- HUD-шкалы отключены: менеджер создаётся, но скрыт и ничего не рисует и не обновляет.
-- Классы панелей и методы оставлены, чтобы ix.bar.Add / ix.bar.Remove и ix.gui.bars
-- (в том числе вызовы из других плагинов) продолжали работать без ошибок.
local PANEL = {}

AccessorFunc(PANEL, "padding", "Padding", FORCE_NUMBER)

function PANEL:Init()
	self:SetSize(ScrW() * 0.35, ScrH())
	self:SetPos(4, 4)
	self:ParentToHUD()
	self:SetVisible(false)

	self.bars = {}
	self.padding = 2

	-- add bars that were registered before manager creation
	for _, v in ipairs(ix.bar.list) do
		v.panel = self:AddBar(v.index, v.color, v.priority)
	end
end

function PANEL:GetAll()
	return self.bars
end

function PANEL:Clear()
	for k, v in ipairs(self.bars) do
		v:Remove()

		table.remove(self.bars, k)
	end
end

function PANEL:AddBar(index, color, priority)
	local panel = self:Add("ixInfoBar")
	panel:SetSize(self:GetWide(), BAR_HEIGHT)
	panel:SetVisible(false)
	panel:SetID(index)
	panel:SetColor(color)
	panel:SetPriority(priority)

	self.bars[#self.bars + 1] = panel
	self:Sort()

	return panel
end

function PANEL:RemoveBar(panel)
	local toRemove

	for k, v in ipairs(self.bars) do
		if (v == panel) then
			toRemove = k
			break
		end
	end

	if (toRemove) then
		table.remove(self.bars, toRemove)

		-- Decrease index value for the next bars
		for i = toRemove, #self.bars do
			ix.bar.list[i].index = i
			self.bars[i]:SetID(i)
		end
	end

	panel:Remove()
	self:Sort()
end

-- sort bars by priority
function PANEL:Sort()
	table.sort(self.bars, function(a, b)
		return a:GetPriority() < b:GetPriority()
	end)
end

function PANEL:OnRemove()
	self:Clear()
end

vgui.Register("ixInfoBarManager", PANEL, "Panel")

PANEL = {}

AccessorFunc(PANEL, "index", "ID", FORCE_NUMBER)
AccessorFunc(PANEL, "color", "Color")
AccessorFunc(PANEL, "priority", "Priority", FORCE_NUMBER)
AccessorFunc(PANEL, "value", "Value", FORCE_NUMBER)
AccessorFunc(PANEL, "delta", "Delta", FORCE_NUMBER)
AccessorFunc(PANEL, "lifetime", "Lifetime", FORCE_NUMBER)

function PANEL:Init()
	self.value = 0
	self.delta = 0
	self.lifetime = 0
end

function PANEL:SetText(text)
end

vgui.Register("ixInfoBar", PANEL, "Panel")

if (IsValid(ix.gui.bars)) then
	ix.gui.bars:Remove()
	ix.gui.bars = vgui.Create("ixInfoBarManager")
end