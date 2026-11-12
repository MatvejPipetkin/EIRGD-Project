PLUGIN.name = "Weight System"
PLUGIN.author = "EIRGD"
PLUGIN.description = "Система веса: вес предметов, лимит переноски, замедление при перегрузе и панель под сеткой инвентаря."

ix.weight = ix.weight or {}

ix.util.Include("sh_weight.lua")
ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
