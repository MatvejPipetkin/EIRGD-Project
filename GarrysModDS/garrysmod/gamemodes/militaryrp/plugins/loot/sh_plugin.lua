

local PLUGIN = PLUGIN

PLUGIN.name = "Box"
PLUGIN.author = ""
PLUGIN.description = "-"

ix.command.Add("AddLootingEntity", {
    description = "Добавить Entity которые можно обыскивать",
    superAdminOnly = true,
    OnRun = function(self, client)
    	PLUGIN:CreateLootingEntity(client)
    end
})

ix.command.Add("EditLootingEntity", {
    description = "Добавить Entity которые можно обыскивать",
    superAdminOnly = true,
    OnRun = function(self, client)
        PLUGIN:EditLootingEntity(client)
    end
})

ix.command.Add("RemoveLootingEntity", {
    description = "Удалить Entity которые можно обыскивать",
    superAdminOnly = true,
    OnRun = function(self, client)
    	PLUGIN:RemoveLootingEntity(client)
    end
})

ix.util.Include("cl_plugin.lua")
ix.util.Include("sv_plugin.lua")
ix.util.Include("sv_hooks.lua")