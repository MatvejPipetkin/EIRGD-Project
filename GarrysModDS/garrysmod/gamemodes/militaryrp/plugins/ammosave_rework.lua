
local PLUGIN = PLUGIN

PLUGIN.name = "Ammo Saver"
PLUGIN.author = "Black Tea"
PLUGIN.description = "Saves the ammo of a character."
PLUGIN.ammoList = {}

ix.ammo = ix.ammo or {}

function ix.ammo.Register(name)
	name = name:lower()

	if (!table.HasValue(PLUGIN.ammoList, name)) then
		PLUGIN.ammoList[#PLUGIN.ammoList + 1] = name
	end
end

-- Register Default HL2 Ammunition.
ix.ammo.Register("ar2")
ix.ammo.Register("pistol")
ix.ammo.Register("357")
ix.ammo.Register("smg1")
ix.ammo.Register("xbowbolt")
ix.ammo.Register("buckshot")
ix.ammo.Register("rpg_round")
ix.ammo.Register("smg1_grenade")
ix.ammo.Register("grenade")
ix.ammo.Register("ar2altfire")
ix.ammo.Register("slam")

-- Register Cut HL2 Ammunition.
ix.ammo.Register("alyxgun")
ix.ammo.Register("sniperround")
ix.ammo.Register("sniperpenetratedround")
ix.ammo.Register("thumper")
ix.ammo.Register("gravity")
ix.ammo.Register("battery")
ix.ammo.Register("gaussenergy")
ix.ammo.Register("combinecannon")
ix.ammo.Register("airboatgun")
ix.ammo.Register("striderminigun")
ix.ammo.Register("helicoptergun")

-- Register Custom Ammunition Types
ix.ammo.Register("ammo_9x18_fmj")
ix.ammo.Register("ammo_9x18_pmm")
ix.ammo.Register("ammo_9x18_ap")
ix.ammo.Register("ammo_9x19_fmj")
ix.ammo.Register("ammo_9x19_pbp")
ix.ammo.Register("ammo_9x19_ap")
ix.ammo.Register("ammo_57x28_ss190")
ix.ammo.Register("ammo_57x28_ss195")
ix.ammo.Register("ammo_762x25_p")
ix.ammo.Register("ammo_762x25_ps")
ix.ammo.Register("ammo_1143x23_fmj")
ix.ammo.Register("ammo_1143x23_hydro")
ix.ammo.Register("ammo_545x39_fmj")
ix.ammo.Register("ammo_545x39_ep")
ix.ammo.Register("ammo_545x39_ap")
ix.ammo.Register("ammo_556x45_fmj")
ix.ammo.Register("ammo_556x45_ss190")
ix.ammo.Register("ammo_556x45_ap")
ix.ammo.Register("ammo_9x39_pab9")
ix.ammo.Register("ammo_9x39_ap")
ix.ammo.Register("ammo_12x70_buck")
ix.ammo.Register("ammo_12x76_zhekan")
ix.ammo.Register("ammo_12x76_bull")
ix.ammo.Register("ammo_12x76_dart")
ix.ammo.Register("ammo_762x39_fmj")
ix.ammo.Register("ammo_762x39_ap")
ix.ammo.Register("ammo_792x33_fmj")
ix.ammo.Register("ammo_792x33_ap")
ix.ammo.Register("ammo_762x51_fmj")
ix.ammo.Register("ammo_762x51_ap")
ix.ammo.Register("ammo_pkm_100")
ix.ammo.Register("ammo_762x54_7h1")
ix.ammo.Register("ammo_762x54_ap")
ix.ammo.Register("ammo_762x54_7h14")
ix.ammo.Register("ammo_46x30_fmj")
ix.ammo.Register("ammo_127x55_fmj")
ix.ammo.Register("ammo_127x55_ap")
ix.ammo.Register("ammo_magnum_300")
ix.ammo.Register("ammo_357_hp_mag")
ix.ammo.Register("ammo_50_bmg")
ix.ammo.Register("ammo_vog-25")
ix.ammo.Register("ammo_m209")
ix.ammo.Register("ammo_og-7b")
ix.ammo.Register("ammo_gauss")
ix.ammo.Register("ammo_gauss_cardan")

-- Called right before the character has its information save.
function PLUGIN:CharacterPreSave(character)
	-- Get the player from the character.
	local client = character:GetPlayer()

	-- Check to see if we can get the player's ammo.
	if (IsValid(client)) then
		local ammoTable = {}

		-- Save reserve ammo (патроны в резерве)
		for _, v in ipairs(self.ammoList) do
			local ammo = client:GetAmmoCount(v)

			if (ammo > 0) then
				ammoTable[v] = ammo
			end
		end

		-- Save clip ammo (патроны в магазинах оружия)
		local clipAmmoTable = {}
		for _, weapon in pairs(client:GetWeapons()) do
			if (IsValid(weapon) and weapon.ixItem) then
				local clip1 = weapon:Clip1()
				local clip2 = weapon:Clip2()
				
				-- Проверяем, что патроны действительно есть
				if (clip1 > 0 or clip2 > 0) then
					clipAmmoTable[weapon:GetClass()] = {
						clip1 = clip1,
						clip2 = clip2,
						itemID = weapon.ixItem.id -- Сохраняем ID предмета для точного восстановления
					}
				end
			end
		end

		character:SetData("ammo", ammoTable)
		character:SetData("clip_ammo", clipAmmoTable)
	end
end

-- Called after the player's loadout has been set.
function PLUGIN:PlayerLoadedCharacter(client)
	-- Первая попытка восстановления через 3.5 секунды
	timer.Simple(3.5, function()
		if (!IsValid(client)) then
			return
		end

		-- Get the saved ammo table from the character data.
		local character = client:GetCharacter()

		if (!character) then
			return
		end

		local ammoTable = character:GetData("ammo")
		local clipAmmoTable = character:GetData("clip_ammo")

		-- Restore reserve ammo (патроны в резерве)
		if (ammoTable) then
			for k, v in pairs(ammoTable) do
				client:SetAmmo(v, tostring(k))
			end
		end

		-- Restore clip ammo (патроны в магазинах оружия)
		if (clipAmmoTable) then
			for weaponClass, clipData in pairs(clipAmmoTable) do
				local weapon = client:GetWeapon(weaponClass)
				
				if (IsValid(weapon) and weapon.ixItem) then
					-- Проверяем, что это тот же предмет (по ID)
					if (clipData.itemID and weapon.ixItem.id == clipData.itemID) then
						if (clipData.clip1 and clipData.clip1 > 0) then
							weapon:SetClip1(clipData.clip1)
						end
						
						if (clipData.clip2 and clipData.clip2 > 0) then
							weapon:SetClip2(clipData.clip2)
						end
						
						-- Для TFA оружия обновляем данные предмета
						if (weapon.ixItem.SetData) then
							weapon.ixItem:SetData("ammo", clipData.clip1 or 0)
						end
					end
				end
			end
		end
	end)
	
	-- Вторая попытка восстановления через 6 секунд для TFA оружия
	timer.Simple(6, function()
		if (!IsValid(client)) then
			return
		end

		local character = client:GetCharacter()
		if (!character) then
			return
		end

		local clipAmmoTable = character:GetData("clip_ammo")
		
		-- Дополнительная попытка восстановления патронов в магазинах
		if (clipAmmoTable) then
			for weaponClass, clipData in pairs(clipAmmoTable) do
				local weapon = client:GetWeapon(weaponClass)
				
				if (IsValid(weapon) and weapon.ixItem) then
					-- Проверяем, что это тот же предмет (по ID)
					if (clipData.itemID and weapon.ixItem.id == clipData.itemID) then
						if (clipData.clip1 and clipData.clip1 > 0) then
							weapon:SetClip1(clipData.clip1)
						end
						
						if (clipData.clip2 and clipData.clip2 > 0) then
							weapon:SetClip2(clipData.clip2)
						end
						
						-- Для TFA оружия обновляем данные предмета
						if (weapon.ixItem.SetData) then
							weapon.ixItem:SetData("ammo", clipData.clip1 or 0)
						end
					end
				end
			end
		end
	end)
end

-- Сохраняем патроны при смерти игрока
hook.Add("PlayerDeath", "AmmoSaveOnDeath", function(client)
	if (IsValid(client) and client:GetCharacter()) then
		local character = client:GetCharacter()
		local ammoTable = {}
		local clipAmmoTable = {}

		-- Сохраняем резервные патроны
		for _, v in ipairs(PLUGIN.ammoList) do
			local ammo = client:GetAmmoCount(v)
			if (ammo > 0) then
				ammoTable[v] = ammo
			end
		end

		-- Сохраняем патроны в магазинах
		for _, weapon in pairs(client:GetWeapons()) do
			if (IsValid(weapon) and weapon.ixItem) then
				local clip1 = weapon:Clip1()
				local clip2 = weapon:Clip2()
				
				if (clip1 > 0 or clip2 > 0) then
					clipAmmoTable[weapon:GetClass()] = {
						clip1 = clip1,
						clip2 = clip2,
						itemID = weapon.ixItem.id
					}
				end
			end
		end

		character:SetData("ammo", ammoTable)
		character:SetData("clip_ammo", clipAmmoTable)
	end
end)

-- Сохраняем патроны при отключении игрока
hook.Add("PlayerDisconnected", "AmmoSaveOnDisconnect", function(client)
	if (IsValid(client) and client:GetCharacter()) then
		local character = client:GetCharacter()
		local ammoTable = {}
		local clipAmmoTable = {}

		-- Сохраняем резервные патроны
		for _, v in ipairs(PLUGIN.ammoList) do
			local ammo = client:GetAmmoCount(v)
			if (ammo > 0) then
				ammoTable[v] = ammo
			end
		end

		-- Сохраняем патроны в магазинах
		for _, weapon in pairs(client:GetWeapons()) do
			if (IsValid(weapon) and weapon.ixItem) then
				local clip1 = weapon:Clip1()
				local clip2 = weapon:Clip2()
				
				if (clip1 > 0 or clip2 > 0) then
					clipAmmoTable[weapon:GetClass()] = {
						clip1 = clip1,
						clip2 = clip2,
						itemID = weapon.ixItem.id
					}
				end
			end
		end

		character:SetData("ammo", ammoTable)
		character:SetData("clip_ammo", clipAmmoTable)
		
		-- Принудительно сохраняем персонажа
		character:Save()
	end
end)

-- Функция для очистки старых данных патронов
local function CleanupOldAmmoData(character)
	if not character then return end
	
	local clipAmmoTable = character:GetData("clip_ammo")
	if not clipAmmoTable then return end
	
	local client = character:GetPlayer()
	if not IsValid(client) then return end
	
	local cleanedTable = {}
	
	-- Проверяем, какие оружия у игрока есть сейчас
	for weaponClass, clipData in pairs(clipAmmoTable) do
		local weapon = client:GetWeapon(weaponClass)
		
		-- Сохраняем данные только для оружия, которое у игрока есть
		if (IsValid(weapon) and weapon.ixItem) then
			cleanedTable[weaponClass] = clipData
		end
	end
	
	character:SetData("clip_ammo", cleanedTable)
end

-- Очищаем старые данные при загрузке персонажа
hook.Add("PlayerLoadedCharacter", "AmmoSaveCleanup", function(client)
	timer.Simple(5, function()
		if (IsValid(client) and client:GetCharacter()) then
			CleanupOldAmmoData(client:GetCharacter())
		end
	end)
end)
