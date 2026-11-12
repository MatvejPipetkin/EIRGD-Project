local config = ix.medical.config

local smooth = {blur = 0, vignette = 0, r = 0, g = 0, b = 0, a = 0}

-- суммарные эффекты всех текущих состояний
local function Collect()
	local med = LocalPlayer():GetLocalVar("med")
	local blur, vignette, r, g, b, a = 0, 0, 0, 0, 0, 0

	if (med) then
		for _, cond in pairs(med.cond) do
			local fx = config.conditions[cond.id] and config.conditions[cond.id].fx

			if (fx) then
				blur = blur + (fx.blur or 0)
				vignette = math.max(vignette, fx.vignette or 0)

				if (fx.tint) then
					r = r + fx.tint[1] * fx.tint[4]
					g = g + fx.tint[2] * fx.tint[4]
					b = b + fx.tint[3] * fx.tint[4]
					a = a + fx.tint[4]
				end
			end
		end
	end

	if (a > 0) then
		r, g, b = r / a, g / a, b / a
	end

	return math.min(blur, 0.8), vignette, r, g, b, math.min(a, 0.4)
end

hook.Add("RenderScreenspaceEffects", "ixMedicalFX", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive()) then
		return
	end

	local blur, vignette, r, g, b, a = Collect()
	local fade = math.min(FrameTime() * 2, 1)

	-- плавные переходы при получении/снятии состояния
	smooth.blur = Lerp(fade, smooth.blur, blur)
	smooth.vignette = Lerp(fade, smooth.vignette, vignette)
	smooth.r = Lerp(fade, smooth.r, r)
	smooth.g = Lerp(fade, smooth.g, g)
	smooth.b = Lerp(fade, smooth.b, b)
	smooth.a = Lerp(fade, smooth.a, a)

	if (smooth.blur > 0.02) then
		-- сотрясение и контузия: «плывущее» зрение
		local wobble = 0.5 + 0.5 * math.sin(CurTime() * 1.3)

		DrawMotionBlur(0.12, math.min(smooth.blur * (0.6 + 0.4 * wobble), 0.85), 0.03)
	end

	if (smooth.a > 0.01) then
		DrawColorModify({
			["$pp_colour_addr"] = smooth.r / 255 * smooth.a * 0.35,
			["$pp_colour_addg"] = smooth.g / 255 * smooth.a * 0.35,
			["$pp_colour_addb"] = smooth.b / 255 * smooth.a * 0.35,
			["$pp_colour_brightness"] = 0,
			["$pp_colour_contrast"] = 1,
			["$pp_colour_colour"] = 1 - smooth.a * 0.8,
			["$pp_colour_mulr"] = 0,
			["$pp_colour_mulg"] = 0,
			["$pp_colour_mulb"] = 0
		})
	end
end)

-- красная пульсирующая виньетка при кровотечении
hook.Add("HUDPaint", "ixMedicalVignette", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or smooth.vignette < 0.02) then
		return
	end

	local width, height = ScrW(), ScrH()
	local pulse = 0.65 + 0.35 * math.sin(CurTime() * (2 + smooth.vignette * 3))
	local strength = 255 * smooth.vignette * pulse
	local steps = 24
	local band = math.floor(height * 0.22 / steps)
	local side = math.floor(width * 0.14 / steps)

	draw.NoTexture()

	-- рамка из полос с убывающей прозрачностью (без внешних материалов)
	for i = 0, steps - 1 do
		local alpha = strength * (1 - i / steps) ^ 2

		surface.SetDrawColor(190, 15, 15, alpha)
		surface.DrawRect(0, i * band, width, band)
		surface.DrawRect(0, height - (i + 1) * band, width, band)
		surface.DrawRect(i * side, 0, side, height)
		surface.DrawRect(width - (i + 1) * side, 0, side, height)
	end
end)
