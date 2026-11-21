ix.tablet = ix.tablet or {}
ix.tablet.state = ix.tablet.state or nil

function ix.tablet.Send(action, data)
	net.Start("ixTablet.Request")
		net.WriteString(action)
		net.WriteTable(data or {})
	net.SendToServer()
end

net.Receive("ixTablet.Open", function()
	local hasAccount = net.ReadBool()
	local info = net.ReadTable()

	if (IsValid(ix.tablet.panel)) then
		ix.tablet.panel:Remove()
	end

	ix.tablet.state = nil

	local panel

	if (vgui.GetControlTable("ixMilTablet")) then
		panel = vgui.Create("ixMilTablet")
	end

	-- Панель не создалась: значит, derma/cl_tablet.lua не загрузился. Объясняем причину вместо падения.
	if (!IsValid(panel)) then
		local reason = !ix.tablet.ui
			and "не загружена библиотека cl_tabletui.lua (файл должен лежать в plugins/tablet/libs/cl_tabletui.lua)"
			or "панель ixMilTablet не зарегистрирована - найдите в консоли первую ошибку про derma/cl_tablet.lua"

		MsgC(Color(255, 90, 90), "[Планшет] ", color_white, reason, "\n")
		chat.AddText(Color(255, 90, 90), "[Планшет] ", color_white, "Интерфейс не загрузился, подробности в консоли.")

		return
	end

	panel.hasAccount = hasAccount
	panel.regLogin = info and info.login
	panel:ShowLogin()

	ix.tablet.panel = panel
end)

net.Receive("ixTablet.Response", function()
	local action = net.ReadString()
	local data = net.ReadTable()

	if (IsValid(ix.tablet.panel)) then
		ix.tablet.panel:OnResponse(action, data)
	end
end)

-- Открытие планшета по клавише (ix.tablet.key, по умолчанию M).
hook.Add("PlayerButtonDown", "ixTabletBind", function(client, button)
	if (!IsFirstTimePredicted()) then return end
	if (button != ix.tablet.key) then return end
	if (IsValid(ix.tablet.panel)) then return end

	-- Не реагируем, если открыто меню, чат или другое окно с курсором (набор текста).
	if (gui.IsGameUIVisible() or vgui.CursorVisible()) then return end
	if (!client:GetCharacter()) then return end

	if ((ix.tablet.nextBind or 0) > CurTime()) then return end
	ix.tablet.nextBind = CurTime() + 1

	net.Start("ixTablet.Bind")
	net.SendToServer()
end)