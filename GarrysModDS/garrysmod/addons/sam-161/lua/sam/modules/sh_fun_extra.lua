--[[
	SAM Fun Extra v2
	Дополнительные шуточные команды для SAM Admin Mod (категория "Fun").

	Установка (любой из вариантов):
	  garrysmod/addons/sam_fun_extra/lua/sam/modules/sh_fun_extra.lua
	  garrysmod/addons/sam_fun_extra/lua/sam/commands/sh_fun_extra.lua
	После этого перезапусти сервер (или смени карту).

	Команды:
	  Взрывное:   rocket, explode, nuke, timebomb, barrel, smite, zap, punch, yeet
	  Движение:   gravity, speed, jumppower, bounce/unbounce, jetpack/unjetpack,
	              abduct, spin/unspin, turnaround, shuffle, swap
	  Тело:       bighead/unbighead, ragdoll/unragdoll, rainbow/unrainbow, paint,
	              trail/untrail, poison, dropweapon, forceact
	  Экран:      flash, blind/unblind, drunk/undrunk, bw/unbw, flip/unflip,
	              shake
	  Звук/чат:   psound, scream, forcesay, fakeleave
	  Мир:        dropprop, earthquake, worldgravity, slowmo, propchaos
	  Прочее:     cure (снимает все эффекты)
]]

local command = sam.command
command.set_category("Fun")

-- ============================================================
-- Состояния
-- ============================================================

local spinning   = {}
local bouncing   = {}
local jetpacking = {}
local rainbowing = {}
local bigheads   = {}
local ragdolled  = {}
local trails     = {}

local CLIENT_EFFECTS = {"drunk", "bw", "flip"}

if SERVER then
	util.AddNetworkString("SAMFun.FX")
	util.AddNetworkString("SAMFun.Sound")
end

-- ============================================================
-- Вспомогательные функции
-- ============================================================

local function Announce(msg, args)
	if sam.is_command_silent then return end
	sam.player.send_message(nil, msg, args)
end

local function Attacker(ply)
	return IsValid(ply) and ply or game.GetWorld()
end

local function TimerID(prefix, ent)
	return "SAMFun_" .. prefix .. "_" .. ent:EntIndex()
end

local function Boom(pos)
	local fx = EffectData()
	fx:SetOrigin(pos)
	fx:SetScale(1)
	fx:SetMagnitude(1)
	util.Effect("Explosion", fx, true, true)
	sound.Play("ambient/explosions/explode_4.wav", pos, 100, 100, 1)
end

-- Эффекты на экране клиента (код клиентской части внизу файла)
local function SetFX(target, name, enabled)
	net.Start("SAMFun.FX")
		net.WriteString(name)
		net.WriteBool(enabled)
	net.Send(target)

	target.sam_fun_fx = target.sam_fun_fx or {}
	target.sam_fun_fx[name] = enabled or nil
end

-- ---------- Голова ----------

local HEAD_BONES = {
	"ValveBiped.Bip01_Head1", "ValveBiped.Bip01_Head", "Bip01_Head", "Bip01 Head", "head", "Head",
}

local function FindHeadBone(ent)
	for _, name in ipairs(HEAD_BONES) do
		local bone = ent:LookupBone(name)
		if bone then return bone end
	end

	-- запасной вариант: любая кость, в названии которой есть "head"
	for i = 0, ent:GetBoneCount() - 1 do
		local name = ent:GetBoneName(i)
		if name and string.find(string.lower(name), "head", 1, true) then
			return i
		end
	end
end

local function SetHeadScale(target, scale)
	local bone = FindHeadBone(target)
	if not bone then return false end

	local vec = Vector(scale, scale, scale)
	if target:GetManipulateBoneScale(bone) ~= vec then
		target:ManipulateBoneScale(bone, vec)
	end
	return true
end

-- ---------- Следы ----------

local function RemoveTrail(target)
	local trail = trails[target]
	if IsValid(trail) then trail:Remove() end
	trails[target] = nil
end

-- ---------- Тряпичная кукла ----------

local function Ragdoll(target)
	if ragdolled[target] or not target:Alive() then return false end

	local data = {
		health = target:Health(),
		armor = target:Armor(),
		ang = target:EyeAngles(),
		pos = target:GetPos(),
		weapons = {},
	}

	local active = target:GetActiveWeapon()
	if IsValid(active) then data.active = active:GetClass() end

	for _, wep in ipairs(target:GetWeapons()) do
		data.weapons[#data.weapons + 1] = {
			class = wep:GetClass(),
			clip1 = wep:Clip1(),
			clip2 = wep:Clip2(),
		}
	end

	target:ExitVehicle()

	local rag = ents.Create("prop_ragdoll")
	if not IsValid(rag) then return false end

	rag:SetModel(target:GetModel())
	rag:SetSkin(target:GetSkin())
	rag:SetPos(target:GetPos())
	rag:SetAngles(target:GetAngles())
	rag:Spawn()
	rag:Activate()

	local vel = target:GetVelocity()
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(i)
		if IsValid(phys) then phys:SetVelocity(vel) end
	end

	target:StripWeapons()
	target:SetNoDraw(true)
	target:SetNotSolid(true)
	target:Spectate(OBS_MODE_CHASE)
	target:SpectateEntity(rag)

	ragdolled[target] = {rag = rag, data = data}
	return true
end

local function UnRagdoll(target)
	local info = ragdolled[target]
	if not info then return false end
	ragdolled[target] = nil

	local rag, data = info.rag, info.data
	local pos = IsValid(rag) and rag:GetPos() or data.pos

	target.sam_fun_noreset = true
	target:UnSpectate()
	target:Spawn()
	target.sam_fun_noreset = nil

	target:SetNoDraw(false)
	target:SetNotSolid(false)
	target:SetPos(pos + Vector(0, 0, 8))
	target:SetEyeAngles(data.ang)
	target:SetHealth(data.health)
	target:SetArmor(data.armor)

	target:StripWeapons()
	for _, w in ipairs(data.weapons) do
		local wep = target:Give(w.class, true)
		if IsValid(wep) then
			wep:SetClip1(w.clip1)
			wep:SetClip2(w.clip2)
		end
	end
	if data.active then target:SelectWeapon(data.active) end

	if IsValid(rag) then rag:Remove() end
	return true
end

-- ---------- Снять всё ----------

local function CureAll(target)
	spinning[target] = nil
	bouncing[target] = nil
	jetpacking[target] = nil
	rainbowing[target] = nil
	bigheads[target] = nil

	SetHeadScale(target, 1)
	target:SetGravity(1)
	target:SetDSP(0)
	target:ScreenFade(SCREENFADE.PURGE, Color(0, 0, 0, 0), 0, 0)
	target:Extinguish()
	RemoveTrail(target)

	timer.Remove(TimerID("Poison", target))
	timer.Remove(TimerID("Abduct", target))

	if target.sam_fun_speed then
		local orig = target.sam_fun_speed
		target:SetWalkSpeed(orig.walk)
		target:SetRunSpeed(orig.run)
		target:SetSlowWalkSpeed(orig.slow)
		target.sam_fun_speed = nil
	end

	if target.sam_fun_jump then
		target:SetJumpPower(target.sam_fun_jump)
		target.sam_fun_jump = nil
	end

	if target.sam_fun_colored then
		target:SetColor(Color(255, 255, 255, 255))
		target.sam_fun_colored = nil
	end

	if target.sam_fun_fx then
		for name in pairs(target.sam_fun_fx) do
			SetFX(target, name, false)
		end
		target.sam_fun_fx = nil
	end
end

-- Анимации для forceact
local ALLOWED_ACTS = {
	dance = true, muscle = true, laugh = true, zombie = true, robot = true,
	cheer = true, bow = true, wave = true, agree = true, disagree = true,
	salute = true, forward = true, group = true, halt = true, becon = true,
}

-- Предметы, которые падают на голову (dropprop)
local FALLING_PROPS = {
	"models/props_c17/oildrum001.mdl",
	"models/props_c17/furniturebathtub001a.mdl",
	"models/props_c17/furnituretoilet001a.mdl",
	"models/props_c17/furniturefridge001a.mdl",
	"models/props_c17/furniturestove001a.mdl",
	"models/props_interiors/furniture_couch02a.mdl",
	"models/props_wasteland/laundry_washer003.mdl",
	"models/props_junk/trashdumpster01a.mdl",
	"models/props_junk/wood_crate001a.mdl",
	"models/props_junk/watermelon01.mdl",
}

-- Крики для scream
local SCREAMS = {
	"vo/npc/male01/pain07.wav",
	"vo/npc/male01/pain08.wav",
	"vo/npc/male01/pain09.wav",
	"vo/npc/male01/no02.wav",
	"vo/npc/male01/help01.wav",
	"vo/npc/female01/pain07.wav",
	"vo/npc/female01/help01.wav",
	"ambient/creatures/town_child_scream1.wav",
}

-- Спавнит предмет над игроком и бросает вниз
local function DropThing(target, model, ignite)
	if not IsValid(target) or not target:Alive() then return end

	local pos = target:GetPos()
	local tr = util.TraceLine({
		start = pos + Vector(0, 0, 70),
		endpos = pos + Vector(0, 0, 600),
		filter = target,
	})
	local height = math.max(tr.Fraction * 530 - 30, 40)

	local prop = ents.Create("prop_physics")
	if not IsValid(prop) then return end

	prop:SetModel(model)
	prop:SetPos(pos + Vector(0, 0, 70 + height))
	prop:SetAngles(Angle(math.random(0, 360), math.random(0, 360), 0))
	prop:Spawn()

	local phys = prop:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
		phys:SetVelocity(Vector(0, 0, -1500))
	end

	if ignite then
		prop:Ignite(5)
		prop:Fire("Break", "", 1.5)
	end

	SafeRemoveEntityDelayed(prop, 12)
end

-- ============================================================
-- ВЗРЫВНОЕ
-- ============================================================

-- rocket - запускает игрока в небо, а потом взрывает
command.new("rocket")
	:SetPermission("rocket", "admin")
	:AddArg("player")
	:Help("Запускает игрока в небо, а потом взрывает")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			local target = targets[i]
			if target:Alive() then
				target:ExitVehicle()
				target:SetVelocity(Vector(0, 0, 1800))
				target:Ignite(3)
				target:EmitSound("weapons/rpg/rocketfire1.wav", 100)

				timer.Simple(1.5, function()
					if not IsValid(target) or not target:Alive() then return end
					Boom(target:GetPos())
					target:Extinguish()
					target:Kill()
				end)
			end
		end

		Announce("{A} запустил {T} в космос", {A = ply, T = targets})
	end)
:End()

-- explode - мгновенный взрыв
command.new("explode")
	:SetPermission("explode", "admin")
	:AddArg("player")
	:Help("Взрывает игрока")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			local target = targets[i]
			if target:Alive() then
				Boom(target:GetPos() + Vector(0, 0, 36))
				target:Kill()
			end
		end

		Announce("{A} взорвал {T}", {A = ply, T = targets})
	end)
:End()

-- nuke - отсчёт 3 секунды, потом большой бабах с уроном по площади
command.new("nuke")
	:SetPermission("nuke", "superadmin")
	:AddArg("player")
	:Help("Через 3 секунды сбрасывает ядерную бомбу на игрока")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			local target = targets[i]
			if target:Alive() then
				target:EmitSound("ambient/alarms/warningbell1.wav", 110)

				timer.Simple(3, function()
					if not IsValid(target) or not target:Alive() then return end
					local pos = target:GetPos()
					local attacker = Attacker(ply)

					Boom(pos)
					Boom(pos + Vector(0, 0, 80))
					util.BlastDamage(attacker, attacker, pos, 400, 300)

					if target:Alive() then
						target:Kill()
					end
				end)
			end
		end

		Announce("{A} сбросил ядерную бомбу на {T}", {A = ply, T = targets})
	end)
:End()

-- timebomb - игрок превращается в бомбу с таймером
command.new("timebomb")
	:SetPermission("timebomb", "admin")
	:AddArg("player")
	:AddArg("number", {hint = "секунды", optional = true, default = 5, min = 2, max = 30, round = true})
	:Help("Делает игрока бомбой: пикает и взрывается через N секунд (бьёт и по соседям)")
	:OnExecute(function(ply, targets, seconds)
		for i = 1, #targets do
			local target = targets[i]
			if target:Alive() then
				local id = TimerID("Bomb", target)
				local left = seconds
				timer.Remove(id)

				target:ChatPrint("Ты бомба! Взрыв через " .. seconds .. " сек. Беги к людям!")

				timer.Create(id, 1, seconds, function()
					if not IsValid(target) or not target:Alive() then
						timer.Remove(id)
						return
					end

					left = left - 1
					if left > 0 then
						target:EmitSound("buttons/blip1.wav", 90, 100 + (seconds - left) * 8)
					else
						local pos = target:GetPos()
						local attacker = Attacker(ply)

						Boom(pos + Vector(0, 0, 36))
						util.BlastDamage(attacker, attacker, pos, 250, 150)

						if target:Alive() then
							target:Kill()
						end
					end
				end)
			end
		end

		Announce("{A} установил бомбу на {T} ({V} сек.)", {A = ply, T = targets, V = seconds})
	end)
:End()

-- barrel - взрывная бочка с неба
command.new("barrel")
	:SetPermission("barrel", "admin")
	:AddArg("player")
	:Help("Сбрасывает горящую взрывную бочку на игрока")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			DropThing(targets[i], "models/props_c17/oildrum001_explosive.mdl", true)
		end

		Announce("{A} сбросил взрывную бочку на {T}", {A = ply, T = targets})
	end)
:End()

-- smite - кара небесная
command.new("smite")
	:SetPermission("smite", "admin")
	:AddArg("player")
	:Help("Поражает игрока небесной карой (гром, вспышка, смерть)")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			local target = targets[i]
			if target:Alive() then
				local pos = target:GetPos()
				sound.Play("ambient/atmosphere/thunder" .. math.random(1, 4) .. ".wav", pos, 140, 100, 1)

				for _, p in ipairs(player.GetAll()) do
					p:ScreenFade(SCREENFADE.IN, Color(255, 255, 255, 140), 0.4, 0)
				end

				timer.Simple(0.3, function()
					if not IsValid(target) or not target:Alive() then return end
					Boom(target:GetPos())
					target:Kill()
				end)
			end
		end

		Announce("{A} поразил {T} небесной карой", {A = ply, T = targets})
	end)
:End()

-- zap - бьёт током
command.new("zap")
	:SetPermission("zap", "admin")
	:AddArg("player")
	:AddArg("number", {hint = "урон", optional = true, default = 20, min = 0, max = 100, round = true})
	:Help("Бьёт игрока молнией")
	:OnExecute(function(ply, targets, damage)
		for i = 1, #targets do
			local target = targets[i]
			if target:Alive() then
				local fx = EffectData()
				fx:SetOrigin(target:GetPos() + Vector(0, 0, 36))
				fx:SetMagnitude(3)
				fx:SetScale(2)
				fx:SetRadius(3)
				util.Effect("cball_explode", fx, true, true)

				target:EmitSound("ambient/energy/zap" .. math.random(1, 3) .. ".wav", 100)
				target:ScreenFade(SCREENFADE.IN, Color(120, 170, 255, 120), 0.5, 0)
				target:SetVelocity(VectorRand() * 250 + Vector(0, 0, 150))

				if damage > 0 then
					target:TakeDamage(damage, Attacker(ply), Attacker(ply))
				end
			end
		end

		Announce("{A} ударил {T} током", {A = ply, T = targets})
	end)
:End()

-- punch - удар кулаком
command.new("punch")
	:SetPermission("punch", "admin")
	:AddArg("player")
	:AddArg("number", {hint = "урон", optional = true, default = 10, min = 0, max = 100, round = true})
	:Help("Бьёт игрока кулаком в направлении вашего взгляда")
	:OnExecute(function(ply, targets, damage)
		for i = 1, #targets do
			local target = targets[i]
			if target:Alive() then
				local dir = (IsValid(ply) and ply ~= target) and ply:GetAimVector() or VectorRand()

				target:ExitVehicle()
				target:SetVelocity(dir * 700 + Vector(0, 0, 250))
				target:EmitSound("physics/body/body_medium_impact_hard" .. math.random(1, 6) .. ".wav", 100)
				target:ScreenFade(SCREENFADE.IN, Color(255, 0, 0, 100), 0.3, 0)
				util.ScreenShake(target:GetPos(), 8, 30, 0.6, 100)

				if damage > 0 then
					target:TakeDamage(damage, Attacker(ply), Attacker(ply))
				end
			end
		end

		Announce("{A} ударил {T} кулаком", {A = ply, T = targets})
	end)
:End()

-- yeet - отбрасывает игрока подальше от админа
command.new("yeet")
	:SetPermission("yeet", "admin")
	:AddArg("player")
	:AddArg("number", {hint = "сила", optional = true, default = 1500, min = 100, max = 10000, round = true})
	:Help("Отшвыривает игрока подальше от вас")
	:OnExecute(function(ply, targets, power)
		for i = 1, #targets do
			local target = targets[i]
			if target:Alive() then
				local dir = VectorRand()
				if IsValid(ply) and ply ~= target then
					dir = target:GetPos() - ply:GetPos()
				end
				dir.z = 0
				if dir:LengthSqr() < 1 then dir = VectorRand() dir.z = 0 end
				dir:Normalize()

				target:ExitVehicle()
				target:SetVelocity(dir * power + Vector(0, 0, power / 3))
			end
		end

		Announce("{A} зафутболил {T}", {A = ply, T = targets})
	end)
:End()

-- ============================================================
-- ДВИЖЕНИЕ
-- ============================================================

command.new("gravity")
	:SetPermission("gravity", "admin")
	:AddArg("player")
	:AddArg("number", {hint = "множитель (1 = обычная)", optional = true, default = 0.2, min = 0.05, max = 10})
	:Help("Меняет гравитацию игрока")
	:OnExecute(function(ply, targets, mult)
		for i = 1, #targets do
			targets[i]:SetGravity(mult)
		end

		Announce("{A} изменил гравитацию {T} (x{V})", {A = ply, T = targets, V = mult})
	end)
:End()

command.new("speed")
	:SetPermission("speed", "admin")
	:AddArg("player")
	:AddArg("number", {hint = "множитель (1 = обычная)", optional = true, default = 3, min = 0.1, max = 10})
	:Help("Меняет скорость передвижения игрока")
	:OnExecute(function(ply, targets, mult)
		for i = 1, #targets do
			local target = targets[i]

			-- запоминаем оригинальные значения один раз
			if not target.sam_fun_speed then
				target.sam_fun_speed = {
					walk = target:GetWalkSpeed(),
					run = target:GetRunSpeed(),
					slow = target:GetSlowWalkSpeed(),
				}
			end

			local orig = target.sam_fun_speed
			target:SetWalkSpeed(orig.walk * mult)
			target:SetRunSpeed(orig.run * mult)
			target:SetSlowWalkSpeed(orig.slow * mult)
		end

		Announce("{A} изменил скорость {T} (x{V})", {A = ply, T = targets, V = mult})
	end)
:End()

command.new("jumppower")
	:SetPermission("jumppower", "admin")
	:AddArg("player")
	:AddArg("number", {hint = "множитель (1 = обычный)", optional = true, default = 3, min = 0.1, max = 10})
	:Help("Меняет силу прыжка игрока")
	:OnExecute(function(ply, targets, mult)
		for i = 1, #targets do
			local target = targets[i]

			if not target.sam_fun_jump then
				target.sam_fun_jump = target:GetJumpPower()
			end

			target:SetJumpPower(target.sam_fun_jump * mult)
		end

		Announce("{A} изменил силу прыжка {T} (x{V})", {A = ply, T = targets, V = mult})
	end)
:End()

-- bounce / unbounce - игрок постоянно подпрыгивает как мячик
command.new("bounce")
	:SetPermission("bounce", "admin")
	:AddArg("player")
	:AddArg("number", {hint = "сила прыжка", optional = true, default = 600, min = 200, max = 2000, round = true})
	:Help("Игрок постоянно подпрыгивает, как мячик")
	:OnExecute(function(ply, targets, power)
		for i = 1, #targets do
			bouncing[targets[i]] = power
		end

		Announce("{A} превратил {T} в мячик", {A = ply, T = targets})
	end)
:End()

command.new("unbounce")
	:SetPermission("unbounce", "admin")
	:AddArg("player", {optional = true})
	:Help("Останавливает подпрыгивание")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			bouncing[targets[i]] = nil
		end

		Announce("{A} остановил подпрыгивание {T}", {A = ply, T = targets})
	end)
:End()

-- jetpack / unjetpack - полёт по зажатому пробелу
command.new("jetpack")
	:SetPermission("jetpack", "admin")
	:AddArg("player")
	:Help("Даёт игроку джетпак: зажми пробел, чтобы лететь (без урона от падения)")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			jetpacking[targets[i]] = true
		end

		Announce("{A} выдал {T} джетпак (зажми пробел)", {A = ply, T = targets})
	end)
:End()

command.new("unjetpack")
	:SetPermission("unjetpack", "admin")
	:AddArg("player", {optional = true})
	:Help("Забирает джетпак")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			jetpacking[targets[i]] = nil
		end

		Announce("{A} забрал джетпак у {T}", {A = ply, T = targets})
	end)
:End()

-- abduct - инопланетяне поднимают игрока вверх, а потом роняют
command.new("abduct")
	:SetPermission("abduct", "admin")
	:AddArg("player")
	:AddArg("number", {hint = "секунды подъёма", optional = true, default = 3, min = 1, max = 10, round = true})
	:Help("Поднимает игрока лучом НЛО, а потом бросает вниз")
	:OnExecute(function(ply, targets, seconds)
		for i = 1, #targets do
			local target = targets[i]
			if target:Alive() then
				local id = TimerID("Abduct", target)
				timer.Remove(id)

				target:ExitVehicle()
				target:ScreenFade(SCREENFADE.IN, Color(150, 255, 200, 70), 0.5, seconds)

				timer.Create(id, 0.1, seconds * 10, function()
					if not IsValid(target) or not target:Alive() then
						timer.Remove(id)
						return
					end

					local v = target:GetVelocity()
					target:SetVelocity(Vector(-v.x * 0.5, -v.y * 0.5, 350 - v.z))
				end)
			end
		end

		Announce("{A} отправил {T} на встречу с НЛО", {A = ply, T = targets})
	end)
:End()

-- spin / unspin - игрока крутит вокруг оси
command.new("spin")
	:SetPermission("spin", "admin")
	:AddArg("player")
	:AddArg("number", {hint = "градусов в секунду", optional = true, default = 360, min = 30, max = 2000, round = true})
	:Help("Закручивает камеру игрока")
	:OnExecute(function(ply, targets, speed)
		for i = 1, #targets do
			spinning[targets[i]] = speed
		end

		Announce("{A} закрутил {T}", {A = ply, T = targets})
	end)
:End()

command.new("unspin")
	:SetPermission("unspin", "admin")
	:AddArg("player", {optional = true})
	:Help("Останавливает вращение")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			spinning[targets[i]] = nil
		end

		Announce("{A} остановил вращение {T}", {A = ply, T = targets})
	end)
:End()

-- turnaround - разворачивает на 180 градусов
command.new("turnaround")
	:SetPermission("turnaround", "admin")
	:AddArg("player")
	:Help("Резко разворачивает игрока на 180 градусов")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			local target = targets[i]
			local ang = target:EyeAngles()
			ang.y = ang.y + 180
			target:SetEyeAngles(ang)
		end

		Announce("{A} развернул {T}", {A = ply, T = targets})
	end)
:End()

-- shuffle - перемешивает позиции нескольких игроков
command.new("shuffle")
	:SetPermission("shuffle", "admin")
	:AddArg("player")
	:Help("Перемешивает игроков между собой (используй с несколькими целями, например *)")
	:OnExecute(function(ply, targets)
		local alive = {}
		for i = 1, #targets do
			if targets[i]:Alive() then
				alive[#alive + 1] = targets[i]
			end
		end

		local n = #alive
		if n < 2 then
			if IsValid(ply) then
				ply:sam_send_message("Нужно минимум 2 живых игрока.")
			end
			return
		end

		local positions = {}
		for i = 1, n do
			positions[i] = alive[i]:GetPos()
		end

		local shift = math.random(1, n - 1)
		for i = 1, n do
			local target = alive[i]
			target:ExitVehicle()
			target:SetPos(positions[((i - 1 + shift) % n) + 1])
			target:SetLocalVelocity(Vector(0, 0, 0))
		end

		Announce("{A} перемешал игроков: {T}", {A = ply, T = alive})
	end)
:End()

-- swap - меняет двух игроков местами
command.new("swap")
	:SetPermission("swap", "admin")
	:AddArg("player", {single_target = true})
	:AddArg("player", {single_target = true})
	:Help("Меняет двух игроков местами")
	:OnExecute(function(ply, targets1, targets2)
		local a, b = targets1[1], targets2[1]
		if not IsValid(a) or not IsValid(b) or a == b then return end

		a:ExitVehicle()
		b:ExitVehicle()

		local posA, angA = a:GetPos(), a:EyeAngles()
		local posB, angB = b:GetPos(), b:EyeAngles()

		a:SetPos(posB)
		a:SetEyeAngles(angB)
		a:SetLocalVelocity(Vector(0, 0, 0))

		b:SetPos(posA)
		b:SetEyeAngles(angA)
		b:SetLocalVelocity(Vector(0, 0, 0))

		Announce("{A} поменял местами {T} и {V}", {A = ply, T = targets1, V = b:Nick()})
	end)
:End()

-- ============================================================
-- ТЕЛО
-- ============================================================

-- bighead / unbighead
command.new("bighead")
	:SetPermission("bighead", "admin")
	:AddArg("player")
	:AddArg("number", {hint = "размер", optional = true, default = 3, min = 0.1, max = 10})
	:Help("Меняет размер головы игрока")
	:OnExecute(function(ply, targets, scale)
		local failed = {}

		for i = 1, #targets do
			local target = targets[i]
			if SetHeadScale(target, scale) then
				-- запоминаем: размер будет подтверждаться каждые полсекунды,
				-- чтобы его не сбрасывала смена модели или другие аддоны
				bigheads[target] = scale
			else
				failed[#failed + 1] = target:Nick()
			end
		end

		if #failed > 0 and IsValid(ply) then
			ply:sam_send_message("У модели нет кости головы: " .. table.concat(failed, ", "))
		end

		Announce("{A} изменил размер головы {T} (x{V})", {A = ply, T = targets, V = scale})
	end)
:End()

command.new("unbighead")
	:SetPermission("unbighead", "admin")
	:AddArg("player", {optional = true})
	:Help("Возвращает нормальный размер головы")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			bigheads[targets[i]] = nil
			SetHeadScale(targets[i], 1)
		end

		Announce("{A} вернул нормальную голову {T}", {A = ply, T = targets})
	end)
:End()

-- ragdoll / unragdoll
command.new("ragdoll")
	:SetPermission("ragdoll", "admin")
	:AddArg("player")
	:Help("Превращает игрока в тряпичную куклу")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			Ragdoll(targets[i])
		end

		Announce("{A} превратил {T} в тряпичную куклу", {A = ply, T = targets})
	end)
:End()

command.new("unragdoll")
	:SetPermission("unragdoll", "admin")
	:AddArg("player", {optional = true})
	:Help("Возвращает игрока из тряпичной куклы")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			UnRagdoll(targets[i])
		end

		Announce("{A} вернул {T} в нормальное состояние", {A = ply, T = targets})
	end)
:End()

-- rainbow / unrainbow - переливающийся цвет
command.new("rainbow")
	:SetPermission("rainbow", "admin")
	:AddArg("player")
	:Help("Игрок переливается всеми цветами радуги")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			rainbowing[targets[i]] = true
			targets[i].sam_fun_colored = true
		end

		Announce("{A} раскрасил {T} в цвета радуги", {A = ply, T = targets})
	end)
:End()

command.new("unrainbow")
	:SetPermission("unrainbow", "admin")
	:AddArg("player", {optional = true})
	:Help("Убирает радугу")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			rainbowing[targets[i]] = nil
			targets[i]:SetColor(Color(255, 255, 255, 255))
			targets[i].sam_fun_colored = nil
		end

		Announce("{A} убрал радугу у {T}", {A = ply, T = targets})
	end)
:End()

-- paint - красит игрока в любой цвет
command.new("paint")
	:SetPermission("paint", "admin")
	:AddArg("player")
	:AddArg("number", {hint = "R", optional = true, default = 255, min = 0, max = 255, round = true})
	:AddArg("number", {hint = "G", optional = true, default = 0, min = 0, max = 255, round = true})
	:AddArg("number", {hint = "B", optional = true, default = 0, min = 0, max = 255, round = true})
	:Help("Красит игрока в цвет R G B (255 255 255 = обычный)")
	:OnExecute(function(ply, targets, r, g, b)
		for i = 1, #targets do
			rainbowing[targets[i]] = nil
			targets[i]:SetColor(Color(r, g, b, 255))
			targets[i].sam_fun_colored = true
		end

		Announce("{A} перекрасил {T} в цвет {V}", {A = ply, T = targets, V = r .. " " .. g .. " " .. b})
	end)
:End()

-- trail / untrail - светящийся шлейф за игроком
command.new("trail")
	:SetPermission("trail", "admin")
	:AddArg("player")
	:Help("Прикрепляет к игроку яркий шлейф")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			local target = targets[i]
			RemoveTrail(target)

			local color = HSVToColor(math.random(0, 360), 1, 1)
			trails[target] = util.SpriteTrail(target, 0, color, false, 20, 1, 3, 1 / 21 * 0.5, "trails/laser.vmt")
		end

		Announce("{A} прикрепил шлейф к {T}", {A = ply, T = targets})
	end)
:End()

command.new("untrail")
	:SetPermission("untrail", "admin")
	:AddArg("player", {optional = true})
	:Help("Убирает шлейф")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			RemoveTrail(targets[i])
		end

		Announce("{A} убрал шлейф у {T}", {A = ply, T = targets})
	end)
:End()

-- poison - яд: тихий урон, но не убивает
command.new("poison")
	:SetPermission("poison", "admin")
	:AddArg("player")
	:AddArg("number", {hint = "секунды", optional = true, default = 10, min = 1, max = 60, round = true})
	:Help("Отравляет игрока: 3 урона в секунду, но яд не убивает")
	:OnExecute(function(ply, targets, seconds)
		for i = 1, #targets do
			local target = targets[i]
			if target:Alive() then
				local id = TimerID("Poison", target)
				timer.Remove(id)

				target:ScreenFade(SCREENFADE.IN, Color(60, 200, 60, 80), 0.5, seconds)

				timer.Create(id, 1, seconds, function()
					if not IsValid(target) or not target:Alive() then
						timer.Remove(id)
						return
					end

					if target:Health() > 5 then
						target:TakeDamage(3, game.GetWorld(), game.GetWorld())
						target:EmitSound("player/pl_pain" .. math.random(5, 7) .. ".wav", 70)
					end
				end)
			end
		end

		Announce("{A} отравил {T} на {V} сек.", {A = ply, T = targets, V = seconds})
	end)
:End()

-- dropweapon - заставляет выронить оружие
command.new("dropweapon")
	:SetPermission("dropweapon", "admin")
	:AddArg("player")
	:Help("Игрок роняет оружие из рук")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			local target = targets[i]
			local wep = target:GetActiveWeapon()
			if target:Alive() and IsValid(wep) then
				target:DropWeapon(wep)
			end
		end

		Announce("{A} заставил {T} выронить оружие", {A = ply, T = targets})
	end)
:End()

-- forceact - заставляет игрока станцевать / помахать и т.д.
command.new("forceact")
	:SetPermission("forceact", "admin")
	:AddArg("player")
	:AddArg("text", {hint = "dance, muscle, laugh, zombie, robot, cheer, bow, wave, agree, disagree, salute, forward, group, halt, becon", optional = true, default = "dance"})
	:Help("Заставляет игрока выполнить анимацию (dance, wave, laugh...)")
	:OnExecute(function(ply, targets, act)
		act = string.lower(string.Trim(act or "dance"))
		if not ALLOWED_ACTS[act] then act = "dance" end

		for i = 1, #targets do
			local target = targets[i]
			if target:Alive() then
				target:ConCommand("act " .. act)
			end
		end

		Announce("{A} заставил {T} выполнить действие: {V}", {A = ply, T = targets, V = act})
	end)
:End()

-- ============================================================
-- ЭКРАН
-- ============================================================

command.new("flash")
	:SetPermission("flash", "admin")
	:AddArg("player")
	:Help("Светошумовая граната: белый экран и звон в ушах")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			local target = targets[i]
			if target:Alive() then
				target:ScreenFade(SCREENFADE.IN, Color(255, 255, 255, 255), 4, 1)
				target:SetDSP(35)

				timer.Simple(5, function()
					if IsValid(target) then
						target:SetDSP(0)
					end
				end)
			end
		end

		Announce("{A} бросил светошумовую гранату в {T}", {A = ply, T = targets})
	end)
:End()

command.new("blind")
	:SetPermission("blind", "admin")
	:AddArg("player")
	:Help("Делает экран игрока чёрным")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			targets[i]:ScreenFade(SCREENFADE.STAYOUT, Color(0, 0, 0, 255), 0, 0)
		end

		Announce("{A} лишил зрения {T}", {A = ply, T = targets})
	end)
:End()

command.new("unblind")
	:SetPermission("unblind", "admin")
	:AddArg("player", {optional = true})
	:Help("Возвращает игроку зрение")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			targets[i]:ScreenFade(SCREENFADE.PURGE, Color(0, 0, 0, 0), 0, 0)
		end

		Announce("{A} вернул зрение {T}", {A = ply, T = targets})
	end)
:End()

-- drunk / undrunk
command.new("drunk")
	:SetPermission("drunk", "admin")
	:AddArg("player")
	:Help("Пьяный экран: размытие и покачивание камеры")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			SetFX(targets[i], "drunk", true)
		end

		Announce("{A} напоил {T}", {A = ply, T = targets})
	end)
:End()

command.new("undrunk")
	:SetPermission("undrunk", "admin")
	:AddArg("player", {optional = true})
	:Help("Протрезвляет игрока")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			SetFX(targets[i], "drunk", false)
		end

		Announce("{A} протрезвил {T}", {A = ply, T = targets})
	end)
:End()

-- bw / unbw - чёрно-белый мир
command.new("bw")
	:SetPermission("bw", "admin")
	:AddArg("player")
	:Help("Делает мир игрока чёрно-белым")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			SetFX(targets[i], "bw", true)
		end

		Announce("{A} сделал мир {T} чёрно-белым", {A = ply, T = targets})
	end)
:End()

command.new("unbw")
	:SetPermission("unbw", "admin")
	:AddArg("player", {optional = true})
	:Help("Возвращает цвета")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			SetFX(targets[i], "bw", false)
		end

		Announce("{A} вернул цвета {T}", {A = ply, T = targets})
	end)
:End()

-- flip / unflip - перевёрнутая камера
command.new("flip")
	:SetPermission("flip", "admin")
	:AddArg("player")
	:Help("Переворачивает камеру игрока вверх ногами")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			SetFX(targets[i], "flip", true)
		end

		Announce("{A} перевернул мир {T}", {A = ply, T = targets})
	end)
:End()

command.new("unflip")
	:SetPermission("unflip", "admin")
	:AddArg("player", {optional = true})
	:Help("Возвращает камеру в нормальное положение")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			SetFX(targets[i], "flip", false)
		end

		Announce("{A} вернул мир {T} в нормальное положение", {A = ply, T = targets})
	end)
:End()

-- shake - тряска экрана
command.new("shake")
	:SetPermission("shake", "admin")
	:AddArg("player")
	:AddArg("number", {hint = "секунды", optional = true, default = 5, min = 1, max = 30})
	:Help("Трясёт экран игрока")
	:OnExecute(function(ply, targets, seconds)
		for i = 1, #targets do
			local target = targets[i]
			util.ScreenShake(target:GetPos(), 15, 40, seconds, 60)
		end

		Announce("{A} потряс {T}", {A = ply, T = targets})
	end)
:End()

-- ============================================================
-- ЗВУК И ЧАТ
-- ============================================================

-- psound - играет звук только у выбранного игрока
command.new("psound")
	:SetPermission("psound", "admin")
	:AddArg("player")
	:AddArg("text", {hint = "путь, например vo/npc/male01/hacks01.wav"})
	:Help("Проигрывает звук только у выбранного игрока")
	:OnExecute(function(ply, targets, path)
		path = string.Trim(path or "")

		local valid = path ~= ""
			and string.match(path, "^[%w_%-%./]+$")
			and not string.find(path, "..", 1, true)
			and (string.EndsWith(path, ".wav") or string.EndsWith(path, ".mp3") or string.EndsWith(path, ".ogg"))

		if not valid then
			if IsValid(ply) then
				ply:sam_send_message("Неверный путь к звуку. Пример: vo/npc/male01/hacks01.wav")
			end
			return
		end

		for i = 1, #targets do
			net.Start("SAMFun.Sound")
				net.WriteString(path)
			net.Send(targets[i])
		end

		Announce("{A} включил звук для {T}", {A = ply, T = targets})
	end)
:End()

-- scream - случайный крик
command.new("scream")
	:SetPermission("scream", "admin")
	:AddArg("player")
	:Help("Заставляет игрока издать случайный крик")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			local target = targets[i]
			if target:Alive() then
				target:EmitSound(SCREAMS[math.random(#SCREAMS)], 100)
			end
		end

		Announce("{A} напугал {T}", {A = ply, T = targets})
	end)
:End()

-- forcesay - заставляет игрока написать сообщение в чат
-- Сообщения, начинающиеся с ! / или ., блокируются, чтобы нельзя было
-- выполнять чат-команды от имени другого игрока.
command.new("forcesay")
	:SetPermission("forcesay", "superadmin")
	:AddArg("player")
	:AddArg("text", {hint = "сообщение"})
	:Help("Заставляет игрока написать сообщение в чат")
	:OnExecute(function(ply, targets, text)
		text = string.Trim(text or "")
		if text == "" then return end

		local first = string.sub(text, 1, 1)
		if first == "!" or first == "/" or first == "." then
			if IsValid(ply) then
				ply:sam_send_message("Нельзя заставить игрока выполнять чат-команды.")
			end
			return
		end

		for i = 1, #targets do
			local target = targets[i]
			if target:Alive() then
				target:Say(text)
			end
		end

		Announce("{A} заставил {T} кое-что сказать", {A = ply, T = targets})
	end)
:End()

-- fakeleave - фальшивое сообщение о выходе (без объявления админа!)
command.new("fakeleave")
	:SetPermission("fakeleave", "admin")
	:AddArg("player", {single_target = true})
	:Help("Пишет в чат, что игрок вышел с сервера (розыгрыш, остаётся тайной)")
	:OnExecute(function(ply, targets)
		local target = targets[1]
		if not IsValid(target) then return end

		PrintMessage(HUD_PRINTTALK, target:Nick() .. " покинул сервер (Disconnect by user.)")
	end)
:End()

-- ============================================================
-- МИР
-- ============================================================

-- dropprop - на голову падают тяжёлые предметы
command.new("dropprop")
	:SetPermission("dropprop", "admin")
	:AddArg("player")
	:AddArg("number", {hint = "сколько предметов", optional = true, default = 1, min = 1, max = 10, round = true})
	:Help("Роняет на игрока тяжёлые предметы (ванна, холодильник, арбуз...)")
	:OnExecute(function(ply, targets, count)
		for i = 1, #targets do
			local target = targets[i]
			for n = 1, count do
				timer.Simple((n - 1) * 0.4, function()
					DropThing(target, FALLING_PROPS[math.random(#FALLING_PROPS)], false)
				end)
			end
		end

		Announce("{A} уронил на {T} что-то тяжёлое", {A = ply, T = targets})
	end)
:End()

-- earthquake - землетрясение
command.new("earthquake")
	:SetPermission("earthquake", "admin")
	:AddArg("number", {hint = "секунды", optional = true, default = 8, min = 1, max = 30})
	:Help("Землетрясение: трясёт экраны всех игроков")
	:OnExecute(function(ply, seconds)
		util.ScreenShake(Vector(0, 0, 0), 12, 40, seconds, 32768)

		for _, p in ipairs(player.GetAll()) do
			p:EmitSound("ambient/explosions/explode_9.wav", 80)
		end

		Announce("{A} устроил землетрясение", {A = ply})
	end)
:End()

-- worldgravity - гравитация во всём мире
command.new("worldgravity")
	:SetPermission("worldgravity", "superadmin")
	:AddArg("number", {hint = "значение (обычно 600)", optional = true, default = 200, min = 50, max = 3000, round = true})
	:Help("Меняет гравитацию на всём сервере (обычная = 600)")
	:OnExecute(function(ply, value)
		RunConsoleCommand("sv_gravity", tostring(value))

		Announce("{A} изменил гравитацию мира: {V}", {A = ply, V = value})
	end)
:End()

-- slowmo - замедление времени
command.new("slowmo")
	:SetPermission("slowmo", "superadmin")
	:AddArg("number", {hint = "скорость (1 = обычная)", optional = true, default = 0.3, min = 0.1, max = 3})
	:Help("Меняет скорость течения времени на сервере (1 = обычная)")
	:OnExecute(function(ply, mult)
		game.SetTimeScale(mult)

		Announce("{A} изменил скорость времени: x{V}", {A = ply, V = mult})
	end)
:End()

-- propchaos - все проп-объекты подлетают
command.new("propchaos")
	:SetPermission("propchaos", "superadmin")
	:Help("Подбрасывает и раскручивает все незамороженные пропы на карте")
	:OnExecute(function(ply)
		local count = 0

		for _, ent in ipairs(ents.FindByClass("prop_physics")) do
			local phys = ent:GetPhysicsObject()
			if IsValid(phys) and phys:IsMotionEnabled() then
				phys:Wake()
				phys:SetVelocity(VectorRand() * 400 + Vector(0, 0, 600))
				phys:AddAngleVelocity(VectorRand() * 300)
				count = count + 1
			end
		end

		Announce("{A} устроил хаос среди пропов ({V} шт.)", {A = ply, V = count})
	end)
:End()

-- ============================================================
-- ПРОЧЕЕ
-- ============================================================

command.new("cure")
	:SetPermission("cure", "admin")
	:AddArg("player", {optional = true})
	:Help("Снимает с игрока все шуточные эффекты")
	:OnExecute(function(ply, targets)
		for i = 1, #targets do
			UnRagdoll(targets[i])
			CureAll(targets[i])
		end

		Announce("{A} вылечил {T} от всех эффектов", {A = ply, T = targets})
	end)
:End()

-- ============================================================
-- Серверные хуки
-- ============================================================
if SERVER then
	local next_head = 0

	hook.Add("Tick", "SAMFun.Tick", function()
		local step = engine.TickInterval()
		local now = CurTime()

		for target, speed in pairs(spinning) do
			if not IsValid(target) then
				spinning[target] = nil
			elseif target:Alive() then
				local ang = target:EyeAngles()
				ang.y = ang.y + speed * step
				target:SetEyeAngles(ang)
			end
		end

		for target, power in pairs(bouncing) do
			if not IsValid(target) then
				bouncing[target] = nil
			elseif target:Alive() and target:OnGround() and (target.sam_fun_bounce_next or 0) <= now then
				target.sam_fun_bounce_next = now + 0.25
				target:SetVelocity(Vector(0, 0, power))
			end
		end

		for target in pairs(jetpacking) do
			if not IsValid(target) then
				jetpacking[target] = nil
			elseif target:Alive() and target:KeyDown(IN_JUMP) and not target:InVehicle() then
				if target:GetVelocity().z < 500 then
					target:SetVelocity(Vector(0, 0, 45))
				end
			end
		end

		if next(rainbowing) then
			local color = HSVToColor((now * 120) % 360, 1, 1)
			for target in pairs(rainbowing) do
				if IsValid(target) then
					target:SetColor(color)
				else
					rainbowing[target] = nil
				end
			end
		end

		-- подтверждаем размер головы (на случай смены модели и т.п.)
		if now >= next_head then
			next_head = now + 0.5
			for target, scale in pairs(bigheads) do
				if IsValid(target) then
					SetHeadScale(target, scale)
				else
					bigheads[target] = nil
				end
			end
		end
	end)

	-- Игрок с джетпаком не получает урон от падения
	hook.Add("EntityTakeDamage", "SAMFun.JetpackFall", function(ent, dmg)
		if ent:IsPlayer() and jetpacking[ent] and dmg:IsFallDamage() then
			return true
		end
	end)

	-- После респавна все эффекты снимаются
	hook.Add("PlayerSpawn", "SAMFun.Reset", function(target)
		if target.sam_fun_noreset then return end
		CureAll(target)
	end)

	-- Если игрока-куклу убили другим способом
	hook.Add("PlayerDeath", "SAMFun.RagdollDeath", function(victim)
		local info = ragdolled[victim]
		if not info then return end

		ragdolled[victim] = nil
		if IsValid(info.rag) then info.rag:Remove() end
		victim:SetNoDraw(false)
		victim:SetNotSolid(false)
	end)

	hook.Add("PlayerDisconnected", "SAMFun.Cleanup", function(target)
		local info = ragdolled[target]
		if info and IsValid(info.rag) then info.rag:Remove() end

		ragdolled[target] = nil
		spinning[target] = nil
		bouncing[target] = nil
		jetpacking[target] = nil
		rainbowing[target] = nil
		bigheads[target] = nil
		RemoveTrail(target)

		timer.Remove(TimerID("Poison", target))
		timer.Remove(TimerID("Abduct", target))
		timer.Remove(TimerID("Bomb", target))
	end)
end

-- ============================================================
-- Клиентская часть (эффекты экрана и звук)
-- ============================================================
if CLIENT then
	local effects = {}

	effects.drunk = {
		on = function()
			hook.Add("RenderScreenspaceEffects", "SAMFun.Drunk", function()
				DrawMotionBlur(0.08, 0.85, 0.01)
			end)

			hook.Add("CalcView", "SAMFun.Drunk", function(_, pos, ang, fov)
				local t = CurTime()
				return {
					origin = pos,
					angles = Angle(
						ang.p + math.sin(t * 1.3) * 3,
						ang.y + math.cos(t * 0.9) * 5,
						math.sin(t * 0.7) * 10
					),
					fov = fov + math.sin(t * 1.1) * 6,
				}
			end)
		end,
		off = function()
			hook.Remove("RenderScreenspaceEffects", "SAMFun.Drunk")
			hook.Remove("CalcView", "SAMFun.Drunk")
		end,
	}

	effects.bw = {
		on = function()
			hook.Add("RenderScreenspaceEffects", "SAMFun.BW", function()
				DrawColorModify({
					["$pp_colour_addr"] = 0,
					["$pp_colour_addg"] = 0,
					["$pp_colour_addb"] = 0,
					["$pp_colour_brightness"] = 0,
					["$pp_colour_contrast"] = 1,
					["$pp_colour_colour"] = 0,
					["$pp_colour_mulr"] = 0,
					["$pp_colour_mulg"] = 0,
					["$pp_colour_mulb"] = 0,
				})
			end)
		end,
		off = function()
			hook.Remove("RenderScreenspaceEffects", "SAMFun.BW")
		end,
	}

	effects.flip = {
		on = function()
			hook.Add("CalcView", "SAMFun.Flip", function(_, pos, ang, fov)
				return {
					origin = pos,
					angles = Angle(ang.p, ang.y, 180),
					fov = fov,
				}
			end)
		end,
		off = function()
			hook.Remove("CalcView", "SAMFun.Flip")
		end,
	}

	net.Receive("SAMFun.FX", function()
		local name = net.ReadString()
		local state = net.ReadBool()

		local fx = effects[name]
		if not fx then return end

		fx.off()
		if state then fx.on() end
	end)

	net.Receive("SAMFun.Sound", function()
		local path = net.ReadString()
		if path ~= "" then
			surface.PlaySound(path)
		end
	end)
end