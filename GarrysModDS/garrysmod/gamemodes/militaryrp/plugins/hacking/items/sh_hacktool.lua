ITEM.name = "Хакерский терминал"
ITEM.description = "Портативный взломщик сетей. Подключается к серверным узлам и вскрывает их защиту. "
	.. "Работать с ним умеют только специалисты."
ITEM.model = "models/props_lab/reciever01b.mdl" -- замените на нужную модель
ITEM.width = 2
ITEM.height = 1
ITEM.category = "Инструменты"
ITEM.noBusiness = true
ITEM.bDropOnDeath = true

function ITEM:GetDescription()
	local left = ix.hack.GetCooldownLeft()
	local status

	if (left > 0) then
		status = "Перезарядка: " .. ix.hack.FormatTime(left) .. "."
	else
		status = "Готов к взлому."
	end

	local text = self.description .. "\n\n" .. status

	local dossier = self:GetData("dossier")

	if (dossier) then
		text = text .. "\nВ памяти досье: " .. tostring(dossier.faction) .. " (" .. os.date("%d.%m %H:%M", dossier.time or 0) .. ")."
	end

	return text
end

-- Устройство работает только у разрешённых классов и только в инвентаре.
local function CanRun(item)
	if (IsValid(item.entity)) then return false end

	local owner = item.player

	if (not IsValid(owner)) then return false end

	return ix.hack.CanUse(owner)
end

ITEM.functions.Hack = {
	name = "Подключиться к узлу",
	icon = "icon16/lock_break.png",
	OnRun = function(item)
		local client = item.player

		if (SERVER and IsValid(client)) then
			local node = ix.hack.AimedNode(client)

			if (not IsValid(node)) then
				ix.hack.Tell(client, "Рядом нет узла. Подойдите к серверу и наведите на него прицел.", "warn")
			else
				ix.hack.TryStart(client, node, item)
			end
		end

		return false
	end,
	OnCanRun = CanRun
}

ITEM.functions.Scan = {
	name = "Сканировать сеть",
	icon = "icon16/transmit.png",
	OnRun = function(item)
		if (SERVER and IsValid(item.player)) then
			ix.hack.Scan(item.player)
		end

		return false
	end,
	OnCanRun = CanRun
}

ITEM.functions.Dossier = {
	name = "Открыть досье",
	icon = "icon16/page_white_text.png",
	-- Клиентская часть пункта меню (как у сумок в Helix): открываем окно и ничего не шлём серверу.
	OnClick = function(item)
		local dossier = item:GetData("dossier")

		if (dossier) then
			ix.hack.OpenDossier(dossier)
		end

		return false
	end,
	OnRun = function(item)
		return false
	end,
	OnCanRun = function(item)
		return CanRun(item) and item:GetData("dossier") ~= nil
	end
}
