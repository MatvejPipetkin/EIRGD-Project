

local PLUGIN = PLUGIN

netstream.Hook("OpenEditLootingEntity", function(data, entity)
	if LocalPlayer():IsAdmin() or LocalPlayer():IsSuperAdmin() then
		if IsValid(LootingEntity_Menu) then
			LootingEntity_Menu:Remove()
		end

		if not IsValid(LootingEntity_Menu) then
			local main = vgui.Create("EditLootingEntity")
			main:GetInfo(data, entity)
		end
	end
end)

local PANEL = {}

function PANEL:Init()
	self:SetSize(800, ScrH()/ 1.1)
	self:MakePopup()
	self:Center()
	self:SetDraggable()
	LootingEntity_Menu = self
	self:SetTitle("Изменение Looting Entity")

	self.editnameText = self:Add("DLabel")
	self.editnameText:SetText( "Название Entity" )
	self.editnameText:Dock(TOP)
	self.editname = self:Add("DTextEntry")
	self.editname:Dock(TOP)
	self.editname:SetFont("ixChatFont")
	self.editname.Paint = function(_,w,h)
		derma.SkinFunc("PaintChatboxEntry", _, w, h)
	end

	self.editdescText = self:Add("DLabel")
	self.editdescText:SetText( "Описание Entity" )
	self.editdescText:Dock(TOP)
	self.editdesc = self:Add("DTextEntry")
	self.editdesc:Dock(TOP)
	self.editdesc:SetFont("ixChatFont")
	self.editdesc.Paint = function(_,w,h)
		derma.SkinFunc("PaintChatboxEntry", _, w, h)
	end

	self.editmodelText = self:Add("DLabel")
	self.editmodelText:SetText( "Модель Entity" )
	self.editmodelText:Dock(TOP)
	self.editmodel = self:Add("DTextEntry")
	self.editmodel:Dock(TOP)
	self.editmodel:SetFont("ixChatFont")
	self.editmodel.Paint = function(_,w,h)
		derma.SkinFunc("PaintChatboxEntry", _, w, h)
	end

	self.loottextText = self:Add("DLabel")
	self.loottextText:SetText( "Текст при использовании" )
	self.loottextText:Dock(TOP)
	self.loottext = self:Add("DTextEntry")
	self.loottext:Dock(TOP)
	self.loottext:SetFont("ixChatFont")
	self.loottext.Paint = function(_,w,h)
		derma.SkinFunc("PaintChatboxEntry", _, w, h)
	end

	self.resp = self:Add("DCheckBoxLabel")
	self.resp:SetText("Удалять после использования?")
	self.resp:Dock(TOP)
	self.resp.OnChange = function(_, value)
		self.data.respawn = value
	end

	self.duck = self:Add("DCheckBoxLabel")
	self.duck:SetText("Собирать можно только сидя?")
	self.duck:Dock(TOP)
	self.duck.OnChange = function(_, value)
		self.data.squat = value
	end

	self.show = self:Add("DCheckBoxLabel")
	self.show:SetText("Писать название и описание при наводке?")
	self.show:Dock(TOP)
	self.show.OnChange = function(_, value)
		self.data.showtext = value
	end

	self.openinv = self:Add("DCheckBoxLabel")
	self.openinv:SetText("Открывать инвентарь после успешного собирания?")
	self.openinv:Dock(TOP)
	self.openinv.OnChange = function(_, value)
		self.data.openinventory = value
	end


	self.edittimeText = self:Add("DLabel")
	self.edittimeText:SetText( "Сколько времени собирается мусор? (в секундах)" )
	self.edittimeText:Dock(TOP)
	self.edittime = self:Add("DTextEntry")
	self.edittime:Dock(TOP)
	self.edittime:SetFont("ixChatFont")
	self.edittime.Paint = function(_,w,h)
		derma.SkinFunc("PaintChatboxEntry", _, w, h)
	end

	self.resptimeText = self:Add("DLabel")
	self.resptimeText:SetText( "Через сколько времени мусор можно собрать еще раз ИЛИ мусор заспавнится еще раз? (в секундах) " )
	self.resptimeText:Dock(TOP)
	self.resptime = self:Add("DTextEntry")
	self.resptime:Dock(TOP)
	self.resptime:SetFont("ixChatFont")
	self.resptime.Paint = function(_,w,h)
		derma.SkinFunc("PaintChatboxEntry", _, w, h)
	end

	self.dropText = self:Add("DLabel")
	self.dropText:SetText( "Максимально предметов выпадает?" )
	self.dropText:Dock(TOP)
	self.drop = self:Add("DTextEntry")
	self.drop:Dock(TOP)
	self.drop:SetFont("ixChatFont")
	self.drop.Paint = function(_,w,h)
		derma.SkinFunc("PaintChatboxEntry", _, w, h)
	end

	self.startclearText = self:Add("DLabel")
	self.startclearText:SetText( "Звук при начинании уборки" )
	self.startclearText:Dock(TOP)
	self.startclear = self:Add("DTextEntry")
	self.startclear:Dock(TOP)
	self.startclear:SetFont("ixChatFont")
	self.startclear.Paint = function(_,w,h)
		derma.SkinFunc("PaintChatboxEntry", _, w, h)
	end

	self.endclearText = self:Add("DLabel")
	self.endclearText:SetText( "Звук при окончании уборки" )
	self.endclearText:Dock(TOP)
	self.endclear = self:Add("DTextEntry")
	self.endclear:Dock(TOP)
	self.endclear:SetFont("ixChatFont")
	self.endclear.Paint = function(_,w,h)
		derma.SkinFunc("PaintChatboxEntry", _, w, h)
	end

	self.chanceText = self:Add("DLabel")
	self.chanceText:SetText( "Шанс выпадения предмета(ов) (нельзя больше 100 и меньше 0)" )
	self.chanceText:Dock(TOP)
	self.chance = self:Add("DTextEntry")
	self.chance:Dock(TOP)
	self.chance:SetFont("ixChatFont")
	self.chance.Paint = function(_,w,h)
		derma.SkinFunc("PaintChatboxEntry", _, w, h)
	end

	self.itemslist = self:Add("DPanel")
	self.itemslist:Dock(FILL)
	self.itemslist:DockMargin(5, 10, 10, 5)

	self.itemslist2 = self.itemslist:Add("DPanelList")
	self.itemslist2:Dock(FILL)
	self.itemslist2:EnableVerticalScrollbar()

	self.save = self:Add("DButton")
	self.save:SetText("Сохранить")
	self.save:Dock(BOTTOM)
	self.save.DoClick = function()
		local name = self.editname:GetValue()
		local desc = self.editdesc:GetValue()
		local model = self.editmodel:GetValue()
		local text_on_use = self.loottext:GetValue()

		local chance = self.chance:GetValue()
		local time = self.edittime:GetValue()
		local resptime = self.resptime:GetValue()
		local dropMax = self.drop:GetValue()
		local soundStart = self.startclear:GetValue()
		local soundEnd = self.endclear:GetValue()

		self.data.name = tostring(name)
		self.data.desc = tostring(desc)
		self.data.model = tostring(model)
		self.data.loot_text = tostring(text_on_use)

		self.data.chance = tonumber(chance)
		self.data.pick = tonumber(time)
		self.data.time = tonumber(resptime)
		self.data.max_drop = tonumber(dropMax)
		self.data.soundstart = tostring(soundStart)
		self.data.soundend = tostring(soundEnd)

		netstream.Start("EditLootingSysten", self.entity, self.data)
		self:Close()
	end

	self.additem = self:Add("DButton")
	self.additem:SetText("Добавить новый предмет выпадения")
	self.additem:Dock(BOTTOM)
	self.additem.DoClick = function()
		Derma_StringRequest(
			"Добавить предмет", 
			"Напишите UniqueID предмета которого вы хотите добавить в таблицу",
			"",
			function(text) 
				local item = ix.item.Get(text)
				local v = item.uniqueID
				if item and not IsValid(self.items[v]) then
					self.items[v] = self.itemslist:Add("DCheckBoxLabel")
					self.items[v]:SetText(""..v.." /  "..item.name.."")
					self.items[v]:Toggle()
					self.items[v].key = k
					self.items[v].OnChange = function(_, value)
						if not value then
							self.items[v]:Remove()
							table.remove(self.data.items, self.items[v].key)
						end
					end

					self.itemslist2:AddItem(self.items[v])
					table.insert(self.data.items, v)
				else
					LocalPlayer():Notify("Предмета с UniqueID "..text.." не существует или в таблице уже есть этот предет!")
				end
			end
		)
	end
end

function PANEL:GetInfo(data, entity)
	self.items = {}
	self.entity = entity
	self.data = data or {}

	local d = self.data

	-- значения по умолчанию, чтобы избежать ошибок при nil
	d.name = d.name or ""
	d.desc = d.desc or ""
	d.loot_text = d.loot_text or ""
	d.model = d.model or ""
	d.chance = tonumber(d.chance) or 100
	d.pick = tonumber(d.pick) or 0
	d.time = tonumber(d.time) or 0
	d.max_drop = tonumber(d.max_drop) or 1
	d.soundstart = d.soundstart or ""
	d.soundend = d.soundend or ""
	d.items = istable(d.items) and d.items or {}
	d.squat = d.squat or false
	d.respawn = d.respawn or false
	d.showtext = d.showtext or false
	d.openinventory = d.openinventory or false

	self.editname:SetValue(d.name)
	self.editdesc:SetValue(d.desc)
	self.loottext:SetValue(d.loot_text)
	self.editmodel:SetValue(d.model)
	self.chance:SetValue(d.chance)

	self.edittime:SetValue(d.pick)
	self.resptime:SetValue(d.time)
	self.drop:SetValue(d.max_drop)

	self.startclear:SetValue(d.soundstart)
	self.endclear:SetValue(d.soundend)

	for k, v in pairs(d.items) do
		local item = ix.item.Get(v)
		local name = item and item.name or "UNKNOWN"
		self.items[v] = self.itemslist:Add("DCheckBoxLabel")
		self.items[v]:SetText(""..v.." /  "..name.."")
		self.items[v]:Toggle()
		self.items[v].key = k
		self.items[v].OnChange = function(_, value)
			if not value then
				self.items[v]:Remove()
				table.remove(self.data.items, self.items[v].key)
			end
		end

		self.itemslist2:AddItem(self.items[v])
	end

	if d.squat then self.duck:Toggle() end
	if d.respawn then self.resp:Toggle() end
	if d.showtext then self.show:Toggle() end
	if d.openinventory then self.openinv:Toggle() end
end

vgui.Register("EditLootingEntity", PANEL, "DFrame")