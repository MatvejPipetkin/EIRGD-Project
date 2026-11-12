local PAPER = Color(226, 219, 196)
local PAPER_EDGE = Color(120, 105, 80)
local INK = Color(38, 34, 28)

-- Окно с текстом прочитанного материала.
net.Receive("ixReadableOpen", function()
	local title = net.ReadString()
	local content = net.ReadString()

	if (IsValid(ix.gui.readable)) then
		ix.gui.readable:Remove()
	end

	local frame = vgui.Create("DFrame")
	frame:SetSize(math.min(ScrW() - 80, 720), math.min(ScrH() - 80, 760))
	frame:Center()
	frame:SetTitle("")
	frame:SetDraggable(true)
	frame:SetSizable(false)
	frame:ShowCloseButton(true)
	frame.btnMinim:Hide()
	frame.btnMaxim:Hide()
	frame:MakePopup()

	frame.Paint = function(this, w, h)
		surface.SetDrawColor(PAPER_EDGE)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(PAPER)
		surface.DrawRect(3, 3, w - 6, h - 6)

		draw.SimpleText(title, "ixMediumFont", w * 0.5, 14, INK, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(PAPER_EDGE)
		surface.DrawRect(24, 42, w - 48, 1)
	end

	local scroll = frame:Add("DScrollPanel")
	scroll:Dock(FILL)
	scroll:DockMargin(18, 28, 18, 14)

	local label = scroll:Add("DLabel")
	label:Dock(TOP)
	label:DockMargin(0, 0, 16, 0)
	label:SetFont("ixMediumFont")
	label:SetTextColor(INK)
	label:SetWrap(true)
	label:SetAutoStretchVertical(true)
	label:SetText(content)
	label:SetWide(frame:GetWide() - 70)
	label:SizeToContentsY()

	ix.gui.readable = frame
end)
