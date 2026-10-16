ITEM.name = "Рация"
ITEM.model = "models/props_lab/tpplug.mdl"
ITEM.description= "Переносное радио с двусторонней связью, которое позволяет общаться между двумя или более людьми на коротких расстояниях"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Инструменты"
ITEM.price = 275
ITEM.quantity = 1
ITEM.weight = 0.2
ITEM.bDropOnDeath = false

local function getText(togga)
	if (togga) then
		return "<color=39, 174, 96>" .. L"вкл" .. "</color>"
	else
		return "<color=192, 57, 43>" .. L"выкл" .. "</color>"
	end
end

function ITEM:GetDescription()	
	return ("переносное радио с двусторонней связью, которое позволяет общаться между двумя или более людьми на коротких расстояниях\nСтатус: " .. (self:GetData("power") and "Вкл" or "Выкл") .. '.\nЧастота: ' .. self:GetData("freq", "000.0") .. '.')
end


if (CLIENT) then
	function ITEM:PaintOver(item, w, h)
		if (item:GetData("power", false)) then
			surface.SetDrawColor(110, 255, 110, 100)
		else
			surface.SetDrawColor(255, 110, 110, 100)
		end

		surface.DrawRect(w - 14, h - 14, 8, 8)
	end

	local GLOW_MATERIAL = Material("sprites/glow04_noz.vmt")
	local COLOR_ACTIVE = Color(0, 255, 0)
	local COLOR_INACTIVE = Color(255, 0, 0)
	local ceil = math.ceil
	function ITEM:DrawEntity(entity, item)
		entity:DrawModel()
		local rt = RealTime()*100
		local position = entity:GetPos() + entity:GetForward() * 0 + entity:GetUp() * 2 + entity:GetRight() * 0

		if (entity:GetData("power", false) == true) then
			if (ceil(rt/14)%10 == 0) then
				render.SetMaterial(GLOW_MATERIAL)
				render.DrawSprite(position, rt % 14, rt % 14, entity:GetData("power", false) and COLOR_ACTIVE or COLOR_INACTIVE)
			end
		end
	end
end

// On player uneqipped the item, Removes a weapon from the player and keep the ammo in the item.
ITEM.functions.toggle = { -- sorry, for name order.
	name = "Вкл/Выкл",
	tip = "useTip",
	icon = "icon16/connect.png",
	OnRun = function(item)
		item:SetData("power", !item:GetData("power", false), nil, nil)
		if item:GetData("power") then
		    item.player:EmitSound("fosounds/fix/obj/obj_radioknobturn_on.mp3", 30)
	    else
		    item.player:EmitSound("fosounds/fix/obj/obj_radioknobturn_off.mp3", 30)
		end

		return false
	end,
	OnCanRun = function(item)
		if item:GetData("power") == true then return true end;
		if IsValid(item.entity) then return false end;
		local owner = item.player
		if !owner then return false end;
		local items = owner:GetCharacter()
		if !items then return false end;
		items = items:GetInventory():GetItemsByUniqueID('radio')
		
		for _, x in ipairs(items) do
			if x:GetData('power') && x.id ~= item.id then return false end;
		end;
		return true
	end;
}

ITEM.functions.use = { -- sorry, for name order.
	name = "Частота",
	tip = "useTip",
	icon = "icon16/wrench.png",
	OnRun = function(item)
		netstream.Start(item.player, "radioAdjust", item:GetData("freq", "000,0"), item.id)

		return false
	end,
	OnCanRun = function(item)
		if IsValid(item.entity) then return false end;
		local owner = item.player
		if !owner then return false end;
		local items = owner:GetCharacter()
		if !items then return false end;
		items = items:GetInventory():GetItemsByUniqueID('radio')
		
		for _, x in ipairs(items) do
			if x:GetData('power') && x.id ~= item.id then return false end;
		end;
		return true
	end;
}