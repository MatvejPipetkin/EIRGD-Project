PLUGIN.name = "C Menu"
PLUGIN.author = "Shahanshsh"
PLUGIN.description = "Меню на C: онлайн, вызов админа, правила, Discord, деньги, описание, NLR."

local PLUGIN = PLUGIN

-- ===== НАСТРОЙКИ =====
PLUGIN.discordURL = ""      
PLUGIN.nlrTime = 120
PLUGIN.rules = "V RAZRABOTKE"    
               
-- ======================

ix.command.Add("CallAdmin", {
    description = "Вызвать администратора. /CallAdmin причина",
    arguments = ix.type.text,
    OnRun = function(self, client, text)
        if ((client.ixNextAdminCall or 0) > CurTime()) then
            return "Подождите немного перед повторным вызовом."
        end

        client.ixNextAdminCall = CurTime() + 30

        local sent = 0
        local message = "[Вызов админа] " .. client:Name() .. " (" .. client:SteamName() .. "): " .. text

        for _, ply in ipairs(player.GetAll()) do
            if (ply:IsAdmin()) then
                ply:Notify(message)
                ply:ChatPrint(message)
                sent = sent + 1
            end
        end

        if (sent == 0) then
            return "Сейчас нет администраторов онлайн."
        end

        client:Notify("Администраторы уведомлены.")
    end
})

if (SERVER) then
    function PLUGIN:PlayerDeath(client)
        client:SetNetVar("ixNLR", CurTime() + self.nlrTime)
    end
end

if (CLIENT) then
    local function S(n)
        return math.Round(n * ScrH() / 1080)
    end

    surface.CreateFont("ixCMenu", {font = "Roboto", size = 18, weight = 500, extended = true})

    local function Ask(title, text, command)
        Derma_StringRequest(title, text, "", function(value)
            if (value and value != "") then
                ix.command.Send(command, value)
            end
        end)
    end

    local function OpenRules()
        local frame = vgui.Create("DFrame")
        frame:SetSize(S(620), S(480))
        frame:Center()
        frame:SetTitle("Правила сервера")
        frame:MakePopup()
        frame.Paint = function(_, w, h)
            draw.RoundedBox(0, 0, 0, w, h, Color(25, 25, 25, 245))
        end

        local scroll = frame:Add("DScrollPanel")
        scroll:Dock(FILL)

        local label = scroll:Add("DLabel")
        label:Dock(TOP)
        label:DockMargin(S(8), S(8), S(8), S(8))
        label:SetFont("ixCMenu")
        label:SetTextColor(color_white)
        label:SetWrap(true)
        label:SetAutoStretchVertical(true)
        label:SetText(table.concat(PLUGIN.rules, "\n\n"))
    end

    local function AddRow(panel, icon, text, onClick)
        local row = panel:Add("DButton")
        row:Dock(TOP)
        row:SetTall(S(30))
        row:SetText("")

        local material = Material(icon)

        row.Paint = function(self, w, h)
            if (onClick and self:IsHovered()) then
                surface.SetDrawColor(60, 60, 60, 230)
                surface.DrawRect(0, 0, w, h)
            end

            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(material)
            surface.DrawTexturedRect(S(8), h / 2 - 8, 16, 16)

            local label = isfunction(text) and text() or text

            draw.SimpleText(label, "ixCMenu", S(34), h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        row.DoClick = function()
            if (onClick) then
                onClick()
            end
        end

        return row
    end

    function PLUGIN:OnContextMenuOpen()
        if (IsValid(self.cPanel)) then
            self.cPanel:Remove()
        end

        local parent = IsValid(g_ContextMenu) and g_ContextMenu or nil
        local panel = vgui.Create("DPanel", parent)

        if (!parent) then
            panel:MakePopup()
            panel:SetKeyboardInputEnabled(false)
        end

        panel:DockPadding(0, S(4), 0, S(4))
        panel.Paint = function(_, w, h)
            surface.SetDrawColor(15, 15, 15, 215)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(95, 95, 95, 255)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        AddRow(panel, "icon16/user.png", function()
            return "Онлайн: " .. #player.GetAll() .. " чел."
        end)

        AddRow(panel, "icon16/bell.png", "Вызвать администратора", function()
            Ask("Вызов администратора", "Опишите, что случилось:", "CallAdmin")
        end)

        AddRow(panel, "icon16/book.png", "Правила сервера", OpenRules)

        AddRow(panel, "icon16/group.png", "Дискорд сервера", function()
            if (PLUGIN.discordURL != "") then
                gui.OpenURL(PLUGIN.discordURL)
            else
                ix.util.Notify("Ссылка на Discord пока не задана.")
            end
        end)

        AddRow(panel, "icon16/flag_red.png", "Точки захвата", function()
            ix.util.Notify("Точки захвата пока в разработке.")
        end)

        AddRow(panel, "icon16/calendar.png", "Ивенты", function()
            ix.util.Notify("Ивенты пока в разработке.")
        end)

        AddRow(panel, "icon16/money_add.png", "Передать деньги тому, на кого вы смотрите", function()
            Ask("Передать деньги", "Сколько передать?", "GiveMoney")
        end)

        AddRow(panel, "icon16/money_delete.png", "Выбросить деньги", function()
            Ask("Выбросить деньги", "Сколько выбросить?", "DropMoney")
        end)

        AddRow(panel, "icon16/user_edit.png", "Изменить описание персонажа", function()
            ix.command.Send("CharDesc")
        end)

        AddRow(panel, "icon16/page_white_text.png", "Изменить документы", function()
            ix.util.Notify("Документы пока в разработке.")
        end)

        AddRow(panel, "icon16/clock.png", function()
            local left = LocalPlayer():GetNetVar("ixNLR", 0) - CurTime()

            if (left > 0) then
                return string.format("NLR: Да (%d:%02d)", math.floor(left / 60), math.floor(left % 60))
            end

            return "NLR: Нет"
        end)

        local w = S(360)
        local h = S(30) * 11 + S(8)

        panel:SetSize(w, h)
        panel:SetPos(S(24), ScrH() - h - S(180))

                self.cPanel = panel
        self.hiddenChildren = {}

        if (!LocalPlayer():IsAdmin() and IsValid(g_ContextMenu)) then
            for _, child in ipairs(g_ContextMenu:GetChildren()) do
                if (child != panel and child:IsVisible()) then
                    child:SetVisible(false)
                    self.hiddenChildren[#self.hiddenChildren + 1] = child
                end
            end
        end
    end

    function PLUGIN:OnContextMenuClose()
        if (IsValid(self.cPanel)) then
            self.cPanel:Remove()
        end
    end
end