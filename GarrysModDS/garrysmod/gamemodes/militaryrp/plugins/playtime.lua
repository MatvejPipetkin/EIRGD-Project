local PLUGIN = PLUGIN
PLUGIN.name = "Playtime Tracker"
PLUGIN.author = "YourName"
PLUGIN.description = "Displays playtime of players in a separate menu."

if (SERVER) then
    util.AddNetworkString("ixRequestPlaytime")
    util.AddNetworkString("ixSendPlaytime")
    util.AddNetworkString("ixRequestAllPlaytimes")
    util.AddNetworkString("ixSendAllPlaytimes")

    -- Function to track player join time
    function PLUGIN:PlayerInitialSpawn(client)
        client.ixJoinTime = RealTime()
    end

    -- Handle playtime request
    net.Receive("ixRequestPlaytime", function(len, client)
        local joinTime = client.ixJoinTime or RealTime()
        local totalTime = (client:GetPData("ixTotalPlaytime", 0) or 0) + (RealTime() - joinTime)

        net.Start("ixSendPlaytime")
        net.WriteFloat(totalTime)
        net.Send(client)
    end)

    -- Handle all playtimes request (for admins)
    net.Receive("ixRequestAllPlaytimes", function(len, client)
        if not client:IsSuperAdmin() then return end

        local playtimeData = {}
        for _, ply in ipairs(player.GetAll()) do
            local joinTime = ply.ixJoinTime or RealTime()
            local totalTime = (ply:GetPData("ixTotalPlaytime", 0) or 0) + (RealTime() - joinTime)
            table.insert(playtimeData, {name = ply:Nick(), time = totalTime})
        end

        net.Start("ixSendAllPlaytimes")
        net.WriteTable(playtimeData)
        net.Send(client)
    end)

    -- Save playtime when player disconnects
    function PLUGIN:PlayerDisconnected(client)
        local joinTime = client.ixJoinTime or RealTime()
        local totalTime = (client:GetPData("ixTotalPlaytime", 0) or 0) + (RealTime() - joinTime)
        client:SetPData("ixTotalPlaytime", totalTime)
    end
end

if (CLIENT) then
    -- Open individual playtime menu function
    function PLUGIN:OpenPlaytimeMenu()
        net.Start("ixRequestPlaytime")
        net.SendToServer()

        net.Receive("ixSendPlaytime", function()
            local totalTime = net.ReadFloat()
            local hours = math.floor(totalTime / 3600)
            local minutes = math.floor((totalTime % 3600) / 60)

            local frame = vgui.Create("DFrame")
            frame:SetTitle("Your Playtime")
            frame:SetSize(300, 100)
            frame:Center()
            frame:MakePopup()

            local label = vgui.Create("DLabel", frame)
            label:SetText("Total Playtime: " .. hours .. " hours, " .. minutes .. " minutes")
            label:Dock(FILL)
            label:SetContentAlignment(5)
        end)
    end

    -- Open admin playtime menu function
    function PLUGIN:OpenAdminPlaytimeMenu()
        net.Start("ixRequestAllPlaytimes")
        net.SendToServer()

        net.Receive("ixSendAllPlaytimes", function()
            local playtimeData = net.ReadTable()

            local frame = vgui.Create("DFrame")
            frame:SetTitle("Player Playtimes")
            frame:SetSize(400, 600)
            frame:Center()
            frame:MakePopup()

            local scrollPanel = vgui.Create("DScrollPanel", frame)
            scrollPanel:Dock(FILL)

            for _, data in ipairs(playtimeData) do
                local hours = math.floor(data.time / 3600)
                local minutes = math.floor((data.time % 3600) / 60)

                local label = scrollPanel:Add("DLabel")
                label:SetText(data.name .. " - " .. hours .. " hours, " .. minutes .. " minutes")
                label:Dock(TOP)
                label:DockMargin(5, 5, 5, 0)
                label:SetWrap(true)
            end
        end)
    end

    -- Add console command for individual playtime
    concommand.Add("ix_playtime", function(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        PLUGIN:OpenPlaytimeMenu()
    end)

    -- Add console command for admin playtime menu
    concommand.Add("ix_playtime_admin", function(ply)
        if not ply:IsSuperAdmin() then return end
        PLUGIN:OpenAdminPlaytimeMenu()
    end)
end
