ITEM.name = "Читаемый материал"
ITEM.description = "Печатный материал."
ITEM.category = "Литература"
ITEM.model = "models/props_lab/binderblue.mdl"
ITEM.width = 1
ITEM.height = 1

-- Время чтения в секундах (до учёта Эрудиции и readTimeScale).
ITEM.readTime = 8
-- Через сколько секунд материал снова даст опыт.
ITEM.cooldown = 1800
-- Сколько очков каждого атрибута даёт ПЕРВОЕ прочтение (до множителей).
-- Повторное чтение даёт долю от этого (конфиг rereadFactor).
ITEM.attributes = {}
-- Минимальные значения атрибутов, необходимые для чтения. Пример: {erudition = 5}
ITEM.requirements = {}
-- Текст, который увидит игрок после чтения (необязательно).
ITEM.content = nil

ITEM.functions.Read = {
	name = "Читать",
	tip = "Прочитать и получить опыт.",
	icon = "icon16/book_open.png",
	OnRun = function(item)
		ix.readables.StartReading(item.player, item)

		return false
	end,
	OnCanRun = function(item)
		return !IsValid(item.entity)
	end
}

ITEM.functions.View = {
	name = "Просмотреть",
	tip = "Открыть текст без получения опыта.",
	icon = "icon16/eye.png",
	OnRun = function(item)
		ix.readables.OpenContent(item.player, item)

		return false
	end,
	OnCanRun = function(item)
		return !IsValid(item.entity) and item.content != nil
	end
}

if (CLIENT) then
	function ITEM:PopulateTooltip(tooltip)
		local names = {}

		for key in SortedPairs(self.attributes or {}) do
			local attribute = ix.attributes.list[key]

			if (attribute) then
				names[#names + 1] = attribute.name
			end
		end

		if (#names > 0) then
			local row = tooltip:AddRow("readableAttributes")
			row:SetText("Развивает: " .. table.concat(names, ", "))
			row:SizeToContents()
		end

		local required = {}

		for key, value in SortedPairs(self.requirements or {}) do
			local attribute = ix.attributes.list[key]
			required[#required + 1] = (attribute and attribute.name or key) .. " " .. value
		end

		if (#required > 0) then
			local row = tooltip:AddRow("readableRequirements")
			row:SetText("Требуется: " .. table.concat(required, ", "))
			row:SizeToContents()
		end
	end
end
