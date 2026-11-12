# Weight System (плагин веса для Helix)

Установка: папку `weight` положить в `plugins/` схемы (рядом со `statusbars`) и перезапустить сервер.

## Вес предмета (в файле предмета)

```lua
ITEM.name = "Консервы"
ITEM.weight = 0.4 -- кг за 1 штуку
```

Если у предмета есть количество (стак, патроны), вес = `ITEM.weight` × количество.

Дополнительно:

```lua
-- предмет сам считает полный вес
ITEM.weight = function(item) return 2 + item:GetData("fuel", 0) * 0.1 end

-- не умножать на количество
ITEM.weightIgnoreQuantity = true

-- вес конкретного экземпляра (перекрывает ITEM.weight)
item:SetData("weight", 3.5)
```

Предметы без `ITEM.weight` весят столько, сколько указано в настройке «Вес по умолчанию».
Сумки считаются вместе с содержимым.

## Настройки в игре

F1 → Config → «Система веса» (правка доступна администраторам):

| Настройка | Что делает |
|---|---|
| weightEnabled | включить/выключить систему |
| weightMax | базовый лимит веса, кг |
| weightAttribute / weightPerAttribute | атрибут (по умолчанию `str`) и сколько кг лимита даёт 1 очко |
| weightDefault | вес предметов без `ITEM.weight` |
| weightSlowPerKg | % замедления за каждый кг перегруза |
| weightMaxSlow | потолок замедления, % |

## Для разработчиков

- `client:GetCarryWeight()`, `client:GetMaxCarryWeight()`, `client:GetWeightSlow()`, `client:IsOverweight()`
- `ix.weight.GetItemWeight(item)`, `ix.weight.GetInventoryWeight(inventory)`
- хук `GetPlayerMaxWeight(client, maxWeight)` — вернуть число, чтобы поменять лимит (рюкзаки, перки и т.д.)
