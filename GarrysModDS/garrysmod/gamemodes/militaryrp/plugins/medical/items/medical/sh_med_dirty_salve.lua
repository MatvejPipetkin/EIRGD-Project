local med = ix.medical.config.meds.dirty_salve

ITEM.name = med.name
ITEM.description = med.desc
ITEM.model = med.model
ITEM.width = med.width or 1
ITEM.height = med.height or 1
ITEM.medical = "dirty_salve"
ITEM.invColor = Color(140, 110, 70) -- «грязные» медикаменты выделены коричневой подложкой
-- все параметры (цель, эффект, использования) — в libs/sh_medical_config.lua: ix.medical.config.meds.dirty_salve
