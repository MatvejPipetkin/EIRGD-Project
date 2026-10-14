PLUGIN.name = "Crafting"
PLUGIN.author = "CHATGPT"
PLUGIN.desc = "Night vision for admins."

if (CLIENT) then
    -- Добавляем опцию для ночного видения
    ix.option.Add("Night vision", ix.type.bool, false, {
        category = "observer",
        hidden = function()
            return not CAMI.PlayerHasAccess(LocalPlayer(), "Helix - Observer", nil)
        end
    })
    
   
    ix.option.Add("Night_vision_r", ix.type.number, 2000, {
        category = "observer",
        min = 2000,
        max = 10000,
        hidden = function()
            return not CAMI.PlayerHasAccess(LocalPlayer(), "Helix - Observer", nil)
        end
    })

    -- Включаем ночное видение в режиме NOCLIP
    function PLUGIN:Think()
        local client = LocalPlayer()
        if CAMI.PlayerHasAccess(LocalPlayer(), "Helix - Observer", nil) and ix.option.Get("Night vision", true) and client:GetMoveType() == MOVETYPE_NOCLIP then
            local dlight = DynamicLight(client:EntIndex())
            if dlight then
                dlight.pos = client:GetShootPos()
                dlight.r = 255
                dlight.g = 255
                dlight.b = 255
                dlight.brightness = 2
                dlight.decay = 100
                dlight.size = ix.option.Get("Night_vision_r", 500)
                dlight.dietime = CurTime() + 1
            end
        end
    end
end
