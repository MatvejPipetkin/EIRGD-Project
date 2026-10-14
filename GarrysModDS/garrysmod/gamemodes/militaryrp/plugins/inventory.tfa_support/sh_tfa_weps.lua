


--═════════════════════════════════════════════════БЛИЖНИЙ═БОЙ══════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_asaw" ] = {
--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Циркулярная пила",
	Slot = "weapons4",

    inventoryType = "weapon_melee", 

	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_me_abrasivesaw.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 5,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 1,
		Ammo = "ar2",
		KickUp = 0.4,
		KickDown = 0.4,
		KickHorizontal = 0.35,
		Spread = .021,
		IronAccuracy = .01
	},
	
	--Sec == Secondary
	Sec = {
		Damage = 1
	}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_chainsaw" ] = {
--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Бензопила",
	Slot = "weapons4",

    inventoryType = "weapon_melee", 

	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_me_chainsaw.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 6,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 1,
		Ammo = "ar2",
		KickUp = 0.4,
		KickDown = 0.4,
		KickHorizontal = 0.35,
		Spread = .021,
		IronAccuracy = .01
	},
	
	--Sec == Secondary
	Sec = {
		Damage = 1
	}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_bcd" ] = {
--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Молоток",
	Slot = "weapons4",

    inventoryType = "weapon_melee", 

	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_tool_barricade.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 0.2,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 15,
		KickUp = 0.4,
		KickDown = 0.4,
		KickHorizontal = 0.35,
		Spread = .021,
		IronAccuracy = .01
	},
	
	--Sec == Secondary
	Sec = {
		Damage = 10
	}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_wrench" ] = {
--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Гаечный ключ",
	Slot = "weapons4",

    inventoryType = "weapon_melee", 

	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_me_wrench.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 0.8,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 15,
		KickUp = 0.4,
		KickDown = 0.4,
		KickHorizontal = 0.35,
		Spread = .021,
		IronAccuracy = .01
	},
	
	--Sec == Secondary
	Sec = {
		Damage = 10
	}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_bat" ] = {
--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Бейсбольная бита",
	Slot = "weapons4",

    inventoryType = "weapon_melee", 

	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_me_bat_metal.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 0.8,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 15,
		KickUp = 0.4,
		KickDown = 0.4,
		KickHorizontal = 0.35,
		Spread = .021,
		IronAccuracy = .01
	},
	
	--Sec == Secondary
	Sec = {
		Damage = 10,
		BashDamage = 1,
	}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_lpipe" ] = {
--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Труба",
	Slot = "weapons4",

    inventoryType = "weapon_melee", 

	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_me_pipe_lead.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 0.7,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 15,
		KickUp = 0.4,
		KickDown = 0.4,
		KickHorizontal = 0.35,
		Spread = .021,
		IronAccuracy = .01
	},
	
	--Sec == Secondary
	Sec = {
		Damage = 10
	}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_etool" ] = {
--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Сапёрная лопата",
	Slot = "weapons4",

    inventoryType = "weapon_melee", 

	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_me_etool.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 0.9,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 15,
		--KickUp = 0.4,
		--KickDown = 0.4,
		--KickHorizontal = 0.35,
		--Spread = .021,
		--IronAccuracy = .01
	},
	
	--Sec == Secondary
	Sec = {
		Damage = 10
	}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_spade" ] = {
--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Лопата",
	Slot = "weapons4",

    inventoryType = "weapon_melee", 

	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_me_spade.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 1.2,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 25,
		KickUp = 0.4,
		KickDown = 0.4,
		KickHorizontal = 0.35,
		Spread = .021,
		IronAccuracy = .01
	},
	
	--Sec == Secondary
	Sec = {
		Damage = 15
	}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_kknife" ] = {
--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Нож",
	Slot = "weapons4",

    inventoryType = "weapon_melee", 

	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_me_kitknife.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 0.3,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 15,
		--KickUp = 0.4,
		--KickDown = 0.4,
		--KickHorizontal = 0.35,
		--Spread = .021,
		--IronAccuracy = .01
	},
	
	--Sec == Secondary
	Sec = {
		Damage = 10
	}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_hatchet" ] = {
--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Топор",
	Slot = "weapons4",

    inventoryType = "weapon_melee", 

	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_me_hatchet.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 0.8,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 20,
		--KickUp = 0.4,
		--KickDown = 0.4,
		--KickHorizontal = 0.35,
		--Spread = .021,
		--IronAccuracy = .01
	},
	
	--Sec == Secondary
	Sec = {
		Damage = 10
	}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_cleaver" ] = {
--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Тесак",
	Slot = "weapons4",

    inventoryType = "weapon_melee", 

	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_me_cleaver.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 0.6,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 20,
		--KickUp = 0.4,
		--KickDown = 0.4,
		--KickHorizontal = 0.35,
		--Spread = .021,
		--IronAccuracy = .01
	},
	
	--Sec == Secondary
	Sec = {
		Damage = 10
	}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_fubar" ] = {
--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Разводной Ключ",
	Slot = "weapons4",

    inventoryType = "weapon_melee", 

	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_me_fubar.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 3,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 25,
		--KickUp = 0.4,
		--KickDown = 0.4,
		--KickHorizontal = 0.35,
		--Spread = .021,
		--IronAccuracy = .01
	},
	
	--Sec == Secondary
	Sec = {
		Damage = 10
	}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_sledge" ] = {
--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Кувалда",
	Slot = "weapons4",

    inventoryType = "weapon_melee", 

	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_me_sledge.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 3,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 25,
		--KickUp = 0.4,
		--KickDown = 0.4,
		--KickHorizontal = 0.35,
		--Spread = .021,
		--IronAccuracy = .01
	},
	
	--Sec == Secondary
	Sec = {
		Damage = 10
	}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_crowbar" ] = {
--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Монтировка",
	Slot = "weapons4",

    inventoryType = "weapon_melee", 

	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_me_crowbar.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 2,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 25,
		--KickUp = 0.4,
		--KickDown = 0.4,
		--KickHorizontal = 0.35,
		--Spread = .021,
		--IronAccuracy = .01
	},
	
	--Sec == Secondary
	Sec = {
		Damage = 10
	}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_machete" ] = {
--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Мачете",
	Slot = "weapons4",

    inventoryType = "weapon_melee", 

	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_me_machete.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 0.7,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 25,
		--KickUp = 0.4,
		--KickDown = 0.4,
		--KickHorizontal = 0.35,
		--Spread = .021,
		--IronAccuracy = .01
	},
	
	--Sec == Secondary
	Sec = {
		Damage = 10
	}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_pickaxe" ] = {
--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Кирка",
	Slot = "weapons4",

    inventoryType = "weapon_melee", 
	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_me_pickaxe.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 3,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 25,
		--KickUp = 0.4,
		--KickDown = 0.4,
		--KickHorizontal = 0.35,
		---Spread = .021,
		---IronAccuracy = .01
	},
	
	--Sec == Secondary
	Sec = {
		Damage = 10
	}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_fireaxe" ] = {
--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Пожарный топор",
	Slot = "weapons4",

    inventoryType = "weapon_melee", 

	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_me_axe_fire.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 3,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 25,
		--KickUp = 0.4,
		--KickDown = 0.4,
		--KickHorizontal = 0.35,
		--Spread = .021,
		--IronAccuracy = .01
	},
	
	--Sec == Secondary
	Sec = {
		Damage = 10
	}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_mw2019_katana" ] = {
--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Катана",
	Slot = "weapons4",

    inventoryType = "weapon_melee", 
	exRender = false,
	Model = "models/weapons/tfa_l4d_mw2019/melee/w_katana.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 3,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 40,
		--KickUp = 0.4,
		--KickDown = 0.4,
		--KickHorizontal = 0.35,
		---Spread = .021,
		---IronAccuracy = .01
	},
	
	--Sec == Secondary
	Sec = {
		Damage = 40
	}
}

--═════════════════════════════════════════════════ПИСТОЛЕТЫ════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_st_samopal" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Туз",
	Slot = "weapons3",

    inventoryType = "weapon_secondary", 
	exRender = false,
	Model = "models/weapons/comrade/w_samopal.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 0.8,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 10,
		Ammo = "pistol",
		--RPM = 200, -- СКОРОСТЬ СТРЕЛЬБЫ
		DamageType = DMG_BULLET,
		--KickUp = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.35, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--
PLUGIN.GunData[ "tfa_nam_nambu_type_14_remake" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Намбу Тип 14",
	Slot = "weapons3",

    inventoryType = "weapon_secondary", 
	exRender = false,
	Model = "models/com/knechtruprecht/nambu type 14.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 0.8,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 14,
		Ammo = "pistol",
		RPM = 200, -- СКОРОСТЬ СТРЕЛЬБЫ
		DamageType = DMG_BULLET,
		--KickUp = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.35, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_pm" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Макаров",
	Slot = "weapons3",

    inventoryType = "weapon_secondary", 
	exRender = false,
	Model = "models/weapons/tfa_ins2/w_pm.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 0.8,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 16,
		Ammo = "pistol",
		RPM = 300, -- СКОРОСТЬ СТРЕЛЬБЫ
		DamageType = DMG_BULLET,
		--KickUp = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.35, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_walther_p99" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "P99",
	Slot = "weapons3",

    inventoryType = "weapon_secondary", 
	exRender = false,
	Model = "models/weapons/w_ins2_pist_p99.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 0.8,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 13,
		Ammo = "pistol",
		--RPM = 300, -- СКОРОСТЬ СТРЕЛЬБЫ
		DamageType = DMG_BULLET,
		--KickUp = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.35, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_glock_19" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Глок-19",
	Slot = "weapons3",

    inventoryType = "weapon_secondary", 
	exRender = false,
	Model = "models/weapons/tfa_ins2/w_glock_p80.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 0.9,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 18,
		Ammo = "pistol",
		DamageType = DMG_BULLET,
		--RPM = 600, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.35, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--
PLUGIN.GunData[ "tfa_ins2_usp_match" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "USP",
	Slot = "weapons3",

    inventoryType = "weapon_secondary", 
	exRender = false,
	Model = "models/weapons/tfa_ins2/w_usp_match.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 0.9,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 21,
		Ammo = "pistol",
		DamageType = DMG_BULLET,
		RPM = 300, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.35, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_m9" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Беретта-M9",
	Slot = "weapons3",

    inventoryType = "weapon_secondary", 
	exRender = false,
	Model = "models/weapons/tfa_ins2/w_m9.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 0.8,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 21,
		Ammo = "pistol",
		--RPM = 200, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.35, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--
PLUGIN.GunData[ "tfa_ww1_steyr1907" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Рот-Штейр",
	Slot = "weapons3",

    inventoryType = "weapon_secondary", 
	exRender = false,
	Model = "models/weapons/w_steyr_1907.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 0.8,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 26,
		Ammo = "357",
		--RPM = 200, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.35, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_verdun_reichsrevolver" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Револьвер M1879",
	Slot = "weapons3",

    inventoryType = "weapon_secondary", 
	exRender = false,
	Model = "models/weapons/w_reichsrevolver_verdun2.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 1,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 50,
		Ammo = "357",
		DamageType = DMG_BULLET,
		--RPM = 200, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.35, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}


--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_thanez_cobra" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Револьвер Магнум",
	Slot = "weapons3",

    inventoryType = "weapon_secondary", 
	exRender = false,
	Model = "models/weapons/tfa_ins2/w_thanez_cobra.mdl",
	Width = 2, -- ШИРИНА
	Height = 1, -- ВЫСОТА
	Weight = 1,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 65,
		Ammo = "357",
		DamageType = DMG_BULLET,
		RPM = 200, -- СКОРОСТЬ СТРЕЛЬБЫ
		KickUp = 1.0, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.35, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--═══════════════════════════════════════════════ПИСТОЛЕТЫ═ПУЛЕМЕТЫ═════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_borz_9smg" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Кустартый GZ4",
	Slot = "weapons2",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/w_dm_borz9.mdl",
	Width = 2, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 0.8,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 14,
		Ammo = "pistol",
		DamageType = DMG_BULLET,
		RPM = 700, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.35, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_wpn_steyrmp40" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "MP-40",
	Slot = "weapons2",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/tfa_ins2_wpns/steyrmp40/w_mp40.mdl",
	Width = 3, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 0.8,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 18,
		Ammo = "pistol",
		DamageType = DMG_BULLET,
		--RPM = 400, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.35, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nam_ppsh41" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Ппш-41",
	Slot = "weapons2",
    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/w_ppsh.mdl",
	Width = 3, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 3.2,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 19,
		Ammo = "pistol",
		--RPM = 600, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.35, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_sterling" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Стерлинг",
	Slot = "weapons2",
    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/tfa_ins2/w_sterling.mdl",
	Width = 3, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 3.2,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 20,
		Ammo = "pistol",
		--RPM = 600, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.35, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_wpn_hkmp5kpdw" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "MP5K",
	Slot = "weapons2",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/tfa_ins2_wpns/hkmp5kpdw/w_mp5k.mdl",
	Width = 2, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 2,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 19,
		Ammo = "pistol",
		DamgeType = DMG_BULLET,
		DamageTypeHandled = false,
		RPM = 650, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.35, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_spectre" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Спектор",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/tfa_ins2/w_spectre.mdl",
	Width = 3, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 2.4,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 21,
		Ammo = "pistol",
		DamageTypeHandled = true,
		DamageType = DMG_BULLET,
		--RPM = 550, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.35, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_krissv" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Крисс Вектор",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/tfa_ins2/w_krissv.mdl",
	Width = 3, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 2.4,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 24,
		Ammo = "pistol",
		DamageTypeHandled = true,
		DamageType = DMG_BULLET,
		RPM = 550, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.35, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_sr2m_veresk" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Вереск",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/w_ins2_sr2m_veresk.mdl",
	Width = 3, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 2.4,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 25,
		Ammo = "pistol",
		DamageTypeHandled = true,
		DamageType = DMG_BULLET,
		RPM = 600, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.4, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.35, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--═════════════════════════════════════════════════ДРОБОВИКИ════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_st_shotga" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Выблядок",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/comrade/w_shotga.mdl",
	Width = 3, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 7,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 5,
		Ammo = "buckshot",
		DamageType = DMG_BULLET,
		--RPM = 100, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.04, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.5, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.5, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .070, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .070 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_l4d2_1887" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Винчестер-1887",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/tfa_l4d2/w_1887.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 5,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 6,
		Ammo = "buckshot",
		DamageType = DMG_BULLET,
		--RPM = 100, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.04, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.5, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.5, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .070, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .070 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_doublebarrel" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Двустволка",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/w_doublebarrel_new.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 4.4,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 7,
		Ammo = "buckshot",
		DamageType = DMG_BULLET,
		--RPM = 100, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.8, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.5, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.5, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .070, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .070 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_sv10" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Охотничья беретта V10",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_fa_sv10.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 4.4,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 7,
		Ammo = "buckshot",
		DamageType = DMG_BULLET,
		--RPM = 100, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.04, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.5, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.5, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .070, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .070 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_500a" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Моссберг-500",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_fa_500a.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 6,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 8,
		Ammo = "buckshot",
		DamageType = DMG_BULLET,
		--RPM = 100, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.04, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.5, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.5, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .070, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .070 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nam_stevens620" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Стивенс-620",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/w_nam_stevens620.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 4.4,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 8,
		Ammo = "buckshot",
		DamageType = DMG_BULLET,
		--RPM = 100, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.04, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.5, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.5, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .070, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .070 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_aa12" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "АА-12",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/tfa_ins2/w_aa12.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 7,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 6,
		Ammo = "buckshot",
		DamageType = DMG_BULLET,
		--RPM = 100, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.04, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.5, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.5, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .070, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .070 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_870" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Ремингтон-870",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_fa_870.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 6,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 9,
		Ammo = "buckshot",
		DamageType = DMG_BULLET,
		--RPM = 100, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.04, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.5, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.5, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .070, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .070 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_spas12" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Spas-12",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/tfa_ins2/w_spas12_bri.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 6,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 10,
		Ammo = "buckshot",
		DamageType = DMG_BULLET,
		RPM = 100, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.04, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.5, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.5, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .070, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .070 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--═════════════════════════════════════════════════════АВТОМАТЫ═════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_fml_lefrench_mas38" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Mac-38",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/w_ww2_mas38.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 3.6,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 10,
		Ammo = "pistol",
		--RPM = 650, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.6, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_akm_bw" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Акм",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/tfa_ins2/w_akm_bw.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 3.6,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 15,
		Ammo = "smg1",
		RPM = 650, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.6, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_wpn_ak9" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "AК-9",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/tfa_ins2_wpns/ak9/w_aks74u.mdl",
	Width = 4, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 3.6,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 17,
		Ammo = "smg1",
		--RPM = 650, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.6, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_wpn_hkg36compact" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "G36C",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/tfa_ins2_wpns/hkg36compact/w_g36c.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 5,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 19,
		Ammo = "smg1",
		DamageType = DMG_BULLET,
		--RPM = 600, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.6, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_rtbr_smg1" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "MP7A1",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/smg1/w_smg1.mdl",
	Width = 4, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 5,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 22,
		Ammo = "smg1",
		--RPM = 600, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.6, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}


--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_wpn_mk18cqbr" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Мк-18",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/tfa_ins2_wpns/mk18cqbr/w_mk18.mdl",
	Width = 4, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 5.6,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 25,
		Ammo = "smg1",
		RPM = 650, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.6, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_l85a2" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Ил-86",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/tfa_ins2/w_l85a2.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 5.6,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 27,
		Ammo = "smg1",
		RPM = 650, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.6, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_inss_asval" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Ас-Вал",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/w-asval.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 4.6,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 30,
		Ammo = "smg1",
		RPM = 650, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.6, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_scar_h_ssr" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "FN-SCAR",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/w_ins2_fn_scar_h_ssr.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 6,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 31,
		Ammo = "smg1",
		--RPM = 600, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.6, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--
PLUGIN.GunData[ "tfa_rtbr_oicw" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "OICW-27",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/oicw/w_oicw.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 6,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 34,
		Ammo = "smg1",
		RPM = 600, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.6, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_hl2_oicw" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "OICW-29",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/schwarzkruppzo/w_oicw.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 6,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 34,
		Ammo = "smg1",
		RPM = 500, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.6, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.6, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--═════════════════════════════════════════════════════════ПУЛЕМЕТЫ═════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ww1_smg0818" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Кастрат",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/ww1pack/w_smg0818.mdl",
	Width = 3, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 7,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 10,
		Ammo = "pistol",
		--RPM = 300, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.7, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ww2_type11" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Ручной пулемет Тип-11",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/w_ww2_type11.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 7,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 24,
		Ammo = "smg1",
		RPM = 300, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.7, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_verdun_madsen" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Мадсен",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/w_verdun_madsen.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 7,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 24,
		Ammo = "smg1",
		RPM = 300, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.7, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "blast_tfa_brenmk3" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Ручной пулемет Брен",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/w_mach_brenmk3.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 7,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 26,
		Ammo = "smg1",
		--RPM = 300, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.7, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_wpn_kacstoner" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Стоунер LMG-A1",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/tfa_ins2_wpns/kacstoner/w_m249.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 7,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 30,
		Ammo = "smg1",
		--RPM = 800, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.7, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_rtbr_hmg" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "GR-9",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/hmg/w_gr9.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 7,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 35,
		Ammo = "smg1",
		RPM = 800, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.7, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--═════════════════════════════════════════════════════ВИНТОВКИ════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_rug1022_25" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Ругер 10/22",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_fa_ruger1022_25mag.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 4.1,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 15,
		Ammo = "pistol",
		--RPM = 200, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.7, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_1892" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Винчестер-1892",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_fa_win1892.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 3.8,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 30,
		Ammo = "357",
		--RPM = 200, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.7, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_preww1_trapdoor1873" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Спрингфилд 1873",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/w_preww1_trapdoor1873.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 4.7,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 50,
		Ammo = "sniperpenetratedround",
		--RPM = 100, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.7, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ww1_gras1874" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Винтовка Гра-1874",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/w_gras1874.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 4.7,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 55,
		Ammo = "sniperpenetratedround",
		--RPM = 100, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.7, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_wpn_mosinnagant" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Винтовка Мосина",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/w_ins2_mosin_nagant.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 4.6,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 60,
		Ammo = "sniperpenetratedround",
		--RPM = 100, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.7, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_nmrih_sako" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Сако-85",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/tfa_nmrih/w_fa_sako85.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 5,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 65,
		Ammo = "sniperpenetratedround",
		--RPM = 100, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.7, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_warface_awm" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "AWM",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/w_ins2_warface_awm.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 4.1,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 90,
		Ammo = "sniperpenetratedround",
		--RPM = 100, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.7, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_barrett_m98_bravo" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Беретта M98B",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/w_ins2_warface_barret_m98b.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 4.1,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 125,
		Ammo = "sniperpenetratedround",
		--RPM = 100, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.7, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_rtbr_sniperrifle" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "LAR",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/sniper/w_sniper.mdl",
	Width = 5, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 10,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 150,
		Ammo = "sniperpenetratedround",
		RPM = 100, -- СКОРОСТЬ СТРЕЛЬБЫ
		KickUp = 3.1, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.7, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--═══════════════════════════════════════════════════ОСОБОЕ═══════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_bocw_nailgun" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Гвоздобой",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/nail_gun/w_smg1.mdl",
	Width = 2, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 5,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 10,
		Ammo = "XBowBolt",
		--RPM = 100, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.7, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_rtbr_crossbow" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Дрын",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/crossbow/w_crossbow.mdl",
	Width = 6, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 8,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 60,
		Ammo = "XBowBolt",
		RPM = 100, -- СКОРОСТЬ СТРЕЛЬБЫ
		--KickUp = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		--KickDown = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		--KickHorizontal = 0.7, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		--Spread = .021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		--IronAccuracy = .01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_ins2_panzerfaust3" ] = {
	--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "Гранатомет",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 
	exRender = false,
	Model = "models/weapons/w_panzerfaust3_sandstorm.mdl",
	Width = 6, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 13,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		 Damage = 200,
		 Ammo = "rpg_round",
		 RPM = 10, -- СКОРОСТЬ СТРЕЛЬБЫ
		 KickUp = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВВЕРХ
		 KickDown = 0.7, -- ЭТО МАКСИМАЛЬНАЯ ОТДАЧА ВНИЗ
		 KickHorizontal = 0.7, -- ЭТО МАКСИМАЛЬНАЯ БОКОВАЯ ОТДАЧА 
		 Spread = 0.021, -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ БЕДРА. (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
		 IronAccuracy = 0.01 -- ЭТО ТОЧНОСТЬ СТРЕЛЬБЫ ОТ ПРИЦЕЛА (1 - УЖАСТНО, 0,0001 - БЛИЖЕ К ИДЕАЛЬНОЙ)
	},
	
	--Sec == Secondary
	Sec = {}
}

--══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════--

PLUGIN.GunData[ "tfa_misc_smg2" ] = {
--Weapon can be Blacklisted and item will be not auto-generated
	BlackList = false,
	Name = "ИМП-2",
	Slot = "weapons1",

    inventoryType = "weapon_primary", 

	exRender = false,
	Model = "models/weapons/tfa_misc/w_combine_smg.mdl",
	Width = 3, -- ШИРИНА
	Height = 2, -- ВЫСОТА
	Weight = 5,
	Price = 2000,

	--Weapon Parameters
	--Prim == Primary
	Prim = {
		Damage = 27,
		Ammo = "ar2",
		KickUp = 0.4,
		KickDown = 0.4,
		KickHorizontal = 0.35,
		Spread = 0.021,
		IronAccuracy = 0.01
	},
	
	--Sec == Secondary
	Sec = {}
}