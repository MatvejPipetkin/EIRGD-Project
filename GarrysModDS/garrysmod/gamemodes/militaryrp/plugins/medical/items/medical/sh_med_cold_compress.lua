local med = ix.medical.config.meds.cold_compress

ITEM.name = med.name
ITEM.description = med.desc
ITEM.model = med.model
ITEM.width = med.width or 1
ITEM.height = med.height or 1
ITEM.medical = "cold_compress"
-- все параметры (цель, эффект, использования) — в libs/sh_medical_config.lua: ix.medical.config.meds.cold_compress
