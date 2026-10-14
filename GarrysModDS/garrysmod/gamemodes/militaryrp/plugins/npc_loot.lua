PLUGIN.name = "NPC Loot"

local items = {
	npc_antlionguard = {
        loot = {"xen_extract", "guardian_meat"},
        tools = {
            ["tfa_nmrih_machete"] = {name = "Мачете", time = 30},
        }
    },
    npc_antlion = {
        loot = {"xen_beetle_meat"},
        tools = {
            ["tfa_nmrih_machete"] = {name = "Мачете", time = 20},
            ["tfa_nmrih_hatchet"] = {name = "Топор", time = 30},
        }
    },
    npc_zombie_alien_grunt = {
        loot = {"xen_alien_meat", "xen_headcrab_carcass_o"},
        tools = {
            ["tfa_nmrih_machete"] = {name = "Мачете", time = 20},
            ["tfa_nmrih_hatchet"] = {name = "Топор", time = 30},
        }
    },
    npc_zombine = {
        loot = {"xen_rotten_flesh"},
        tools = {
            ["tfa_nmrih_machete"] = {name = "Мачете", time = 20},
            ["tfa_nmrih_hatchet"] = {name = "Топор", time = 30},
        }
    },
    npc_poisonzombie = {
        loot = {"xen_rotten_flesh"},
        tools = {
            ["tfa_nmrih_machete"] = {name = "Мачете", time = 20},
            ["tfa_nmrih_hatchet"] = {name = "Топор", time = 30},
        }
    },
    npc_fastzombie = {
        loot = {"xen_rotten_flesh"},
        tools = {
            ["tfa_nmrih_machete"] = {name = "Мачете", time = 10},
            ["tfa_nmrih_hatchet"] = {name = "Топор", time = 15},
            ["tfa_nmrih_cleaver"] = {name = "Тесак", time = 25},
        }
    },
    npc_zombie = {
        loot = {"xen_rotten_flesh"},
        tools = {
            ["tfa_nmrih_machete"] = {name = "Мачете", time = 10},
            ["tfa_nmrih_hatchet"] = {name = "Топор", time = 15},
            ["tfa_nmrih_cleaver"] = {name = "Тесак", time = 25},
        }
    },
    npc_headcrab_black = {
        loot = {"xen_headcrab_carcass_i"},
        tools = {
            ["tfa_nmrih_machete"] = {name = "Мачете", time = 10},
            ["tfa_nmrih_hatchet"] = {name = "Топор", time = 15},
            ["tfa_nmrih_cleaver"] = {name = "Тесак", time = 25},
        }
    },
    npc_headcrab_fast = {
        loot = {"xen_headcrab_carcass_b"},
        tools = {
            ["tfa_nmrih_machete"] = {name = "Мачете", time = 10},
            ["tfa_nmrih_hatchet"] = {name = "Топор", time = 15},
            ["tfa_nmrih_cleaver"] = {name = "Тесак", time = 25},
            ["tfa_nmrih_kknife"] = {name = "Нож", time = 30},
        }
    },
    npc_headcrab = {
        loot = {"xen_headcrab_carcass_o"},
        tools = {
            ["tfa_nmrih_machete"] = {name = "Мачете", time = 10},
            ["tfa_nmrih_hatchet"] = {name = "Топор", time = 15},
            ["tfa_nmrih_cleaver"] = {name = "Тесак", time = 25},
            ["tfa_nmrih_kknife"] = {name = "Нож", time = 30},
        }
    }
}

local lootProps = {}

local npcLootClasses = {}
for k, v in pairs(items) do
    npcLootClasses[k] = true
end

if CLIENT then
    hook.Add( "CreateClientsideRagdoll", "fade_out_corpses", function( entity, ragdoll )
        if items[entity:GetClass()] then
            ragdoll:Remove()
        end
    end)
else
    hook.Add("OnNPCKilled", "npcloot.OnKilledNPC", function(entity, attacker)
        if not IsValid(entity) then return end
        
        local class = entity:GetClass()
        local chance = math.random(100)
        -- if chance >= 20 then return end

        local npcData = items[class]
        if npcData then
            local RandomItem = table.Random(npcData.loot)
            if RandomItem then
                -- Capture entity data before timer to avoid NULL entity issues
                local entityModel = entity:GetModel()
                local entityPos = entity:GetPos()
                local entityAngles = entity:GetAngles()
                local entitySkin = entity:GetSkin()
                
                timer.Simple(0, function()
                    local rag = ents.Create("prop_ragdoll")
                    rag:SetModel(entityModel)
                    rag:SetPos(entityPos)
                    rag:SetAngles(entityAngles)
                    rag:Spawn()
                    rag:Activate()
                    rag:SetMoveType(MOVETYPE_NONE)
                    rag:SetSkin(entitySkin)
                    rag.LootItem = RandomItem
                    rag.Looted = false
                    rag.LootTools = npcData.tools
                    rag.LootClass = class

                    timer.Simple(60, function()
                        if IsValid(rag) then
                            rag:Remove()
                        end
                    end)
                end)
            end
        end
    end)

    hook.Add("PlayerUse", "npcloot.PlayerUseLootProp", function(ply, ent)
        if not IsValid(ent) then return end
        if ent.UseLoot then return end
        if not ent.LootItem then return end
        if ent.Looted then return end
        local char = ply:GetCharacter()
        if not char then return end
        if not ix.item.Get(ent.LootItem) then return end

        ply._lastLootTry = ply._lastLootTry or 0
        if CurTime() - ply._lastLootTry < 0.5 then
            return
        end
        ply._lastLootTry = CurTime()

        local tools = ent.LootTools or ent.LootClass and items[ent.LootClass] and items[ent.LootClass].tools or {}
        local foundTool, foundData
        local toolNames = {}
        for tool, data in pairs(tools) do
            toolNames[#toolNames+1] = data.name or tool
            if ply:HasWeapon(tool) then
                foundTool = tool
                foundData = data
                break
            end
        end
        if not foundTool then
            ply:Notify("Для разделки требуется: " .. table.concat(toolNames, ", "))
            return
        end

        ent.UseLoot = true
        local time = foundData and foundData.time or 1
        ply:SetAction("Разделка тела...", time)
        ply:DoStaredAction(ent, function()
            if not IsValid(ent) or ent.Looted then return end
            ent.Looted = true
            local inv = char:GetInventory()
            if inv then
                inv:Add(ent.LootItem)
            end
            ent:EmitSound("vj_gib/bones_snapping1.wav", 75, 90, 0.35)
            ply:Notify("Вы разделали тело и получили " .. ix.item.Get(ent.LootItem).name)
            timer.Simple(0, function()
                if IsValid(ent) then
                    ent:Remove()
                end
            end)
        end, time, function()
            if IsValid(ply) then
                ply:SetAction()
            end
            ent.UseLoot = false
        end)
        return
    end)

    local nextCleanup = CurTime() + 3600 -- 30 минут до первой чистки
    local warned = false

    hook.Add("Think", "ix_item_autocleanup", function()
        if not nextCleanup then
            nextCleanup = CurTime() + 3600
            warned = false
        end
        local timeLeft = nextCleanup - CurTime()
        if timeLeft <= 300 and not warned then -- 5 минут до чистки
            for _, ply in ipairs(player.GetAll()) do
                if ply.Notify then
                    ply:Notify("Внимание! Очистка мусора на карте через 5 минут.")
                end
            end
            warned = true
        end
        if CurTime() >= nextCleanup then
            for _, ent in ipairs(ents.FindByClass("ix_item")) do
                local itemTable = ent:GetItemTable()
                if itemTable and itemTable.NoRemove then continue end

                if IsValid(ent) then
                    ent:Remove()
                end
            end
            nextCleanup = CurTime() + 3600
            warned = false
        end
    end)
end