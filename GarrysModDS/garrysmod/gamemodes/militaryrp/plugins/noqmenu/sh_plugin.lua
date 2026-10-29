PLUGIN.name = "No Q Menu"
PLUGIN.author = "Shahanshsh"
PLUGIN.description = "Q-меню только для админов."

if (CLIENT) then
    function PLUGIN:SpawnMenuOpen()
        if (!LocalPlayer():IsAdmin()) then
            return false
        end
    end
end