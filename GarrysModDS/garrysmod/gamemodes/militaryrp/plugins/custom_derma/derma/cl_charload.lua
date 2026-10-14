local glowMat = Material("sprites/light_glow02_add")

--[[
	НАСТРОЙКИ МЕНЮ ЗАГРУЗКИ ПЕРСОНАЖА
	Три слота: слева колонка слотов, в центре модель выбранного персонажа в полный рост, справа его досье.
	Свободные слоты заблокированы, пока их не откроют (хук slotHook или unlockedSlots ниже).
	logos / factionColors — по имени глобальной константы фракции (как factionConst в cl_charcreate).
	Если логотипа нет — он просто не рисуется. Цвет по умолчанию берётся из faction.color.
]]
local CFG = {
	slots = 3, -- всего слотов
	unlockedSlots = 1, -- сколько слотов открыто, если хук slotHook ничего не вернул
	slotHook = "GetMaxPlayerCharacter", -- хук, возвращающий число доступных слотов: hook.Run(slotHook, LocalPlayer())
	autoSelect = false, -- сразу выбирать персонажа при открытии меню (false = пока не выберут, показывается пустое состояние)
	hideMenuHud = true, -- прятать HUD из cl_character на время работы меню (так же, как в cl_charcreate)

	modelFOV = 72, -- угол обзора превью-модели
	modelScale = 1, -- размер превью-модели (1 = полный рост)
	modelCenterY = 0.476, -- вертикальный центр превью-модели (доля высоты экрана)
	floorY = 0.79, -- высота «пола» под моделью (доля высоты экрана)
	modelFace = 0, -- подстройка разворота к камере в градусах
	modelTurnMax = 14, -- максимальный поворот модели за курсором (градусы)
	wipeFeet = 0.89, -- где в панели модели находятся ноги (доля высоты панели) — для эффекта проявления
	wipeHead = 0.13, -- где в панели модели находится макушка
	revealTime = 1.1, -- длительность проявления модели (сек.)
	dragSpeed = 0.6, -- скорость вращения модели при перетаскивании мышью
	dragReturn = 2.5, -- через сколько секунд после отпускания модель плавно возвращается в исходный поворот

	particles = 28, -- плывущие светлые точки (0 = выкл)
	gridAlpha = 1, -- прозрачность сетки (множитель, 0 = без сетки)
	descLines = 5, -- максимум строк описания персонажа в досье
	maxAttributes = 5, -- максимум характеристик в досье
	enterDelay = 0.8, -- пауза перед входом в игру после нажатия кнопки (сек.)

	idleColor = Color(90, 160, 235), -- акцент, пока персонаж не выбран
	lockedColor = Color(120, 132, 150), -- цвет заблокированных слотов
	dangerColor = Color(232, 68, 68), -- цвет удаления

	logos = {
		FACTION_FVUR = "fvur_logo.png",
		FACTION_EIR = "eir_logo.png"
	},

	factionColors = {
		FACTION_FVUR = Color(70, 140, 235),
		FACTION_EIR = Color(232, 68, 68)
	},

	heading = "ВЫБОР ПЕРСОНАЖА",
	subHeading = "ВЫБЕРИТЕ СЛОТ, ЧТОБЫ ОТКРЫТЬ ДОСЬЕ ПЕРСОНАЖА",
	archiveText = "АРХИВ ПЕРСОНАЖЕЙ",
	slotLabel = "СЛОТ",
	freeText = "СВОБОДНЫЙ СЛОТ",
	freeHint = "НАЖМИТЕ, ЧТОБЫ СОЗДАТЬ ПЕРСОНАЖА",
	lockedText = "СЛОТ ЗАБЛОКИРОВАН",
	lockedHint = "БУДЕТ ДОСТУПЕН ПОЗЖЕ",
	activeText = "В ИГРЕ",
	idleTitle = "ПЕРСОНАЖ НЕ ВЫБРАН",
	idleHint = "ВЫБЕРИТЕ СЛОТ СЛЕВА",
	noDataTitle = "ДОСЬЕ НЕДОСТУПНО",
	noDataHint = "ДАННЫЕ ПОЯВЯТСЯ ПОСЛЕ ВЫБОРА ПЕРСОНАЖА",
	dossierText = "ДОСЬЕ",
	factionLabel = "ФРАКЦИЯ",
	descLabel = "ОПИСАНИЕ",
	noDescText = "Описание отсутствует.",
	attrLabel = "ХАРАКТЕРИСТИКИ",
	summaryLabel = "ЗАПОЛНЕНИЕ СЛОТОВ",
	dragHint = "ПЕРЕТАЩИТЕ, ЧТОБЫ ПОВЕРНУТЬ",
	backText = "ВЕРНУТЬСЯ",
	enterText = "ВОЙТИ В ИГРУ",
	enteringText = "ВХОД...",
	deleteText = "УДАЛИТЬ",
	confirmTitle = "ПОДТВЕРДИТЕ УДАЛЕНИЕ",
	confirmText = "Персонаж будет удалён безвозвратно. Это действие нельзя отменить.",
	confirmYes = "ДА, УДАЛИТЬ",
	confirmNo = "ОТМЕНА",

	sounds = true,
	soundVolume = 0.55,
	soundSet = {
		hover = {"buttons/blip1.wav", 0.35, 115},
		click = {"buttons/button15.wav", 0.5, 100},
		deny = {"buttons/button10.wav", 0.5, 100},
		open = {"buttons/combine_button1.wav", 0.4, 105},
		tick = {"buttons/blip2.wav", 0.18, 130},
		boom = {"ambient/machines/thumper_hit.wav", 0.55, 100},
		confirm = {"buttons/combine_button7.wav", 0.45, 100}
	}
}

local function CreateFonts()
	local h = ScrH()

	local function Make(name, size, weight)
		surface.CreateFont(name, {font = "Roboto", size = math.floor(h * size), weight = weight, extended = true, antialias = true})
	end

	Make("ixLoadHuge", 0.05, 700)
	Make("ixLoadBig", 0.038, 700)
	Make("ixLoadName", 0.03, 700)
	Make("ixLoadNameS", 0.024, 700)
	Make("ixLoadSlot", 0.027, 700)
	Make("ixLoadMid", 0.024, 600)
	Make("ixLoadText", 0.0185, 500)
	Make("ixLoadSmall", 0.0155, 500)
	Make("ixLoadTiny", 0.012, 500)
	Make("ixLoadNum", 0.12, 800)
	Make("ixLoadBtn", 0.0225, 600)

	surface.CreateFont("ixLoadMono", {font = "Courier New", size = math.floor(h * 0.0135), weight = 500, extended = true, antialias = true})
end

CreateFonts()

local C = TEXT_ALIGN_CENTER
local LEFT = TEXT_ALIGN_LEFT
local RIGHT = TEXT_ALIGN_RIGHT
local TOP = TEXT_ALIGN_TOP

local function EaseOutCubic(x)
	return 1 - (1 - x) ^ 3
end

local function EaseOutExpo(x)
	return x >= 1 and 1 or 1 - 2 ^ (-10 * x)
end

local function Clamp01(x)
	return math.Clamp(x, 0, 1)
end

-- прогресс 0..1 для времени t, начинающегося в t0 и длящегося dur
local function Prog(t, t0, dur)
	return math.Clamp((t - t0) / dur, 0, 1)
end

local function Upper(text)
	return (string.utf8upper or string.upper)(text)
end

local function HexLine()
	local b = {}

	for i = 1, 8 do
		b[i] = math.random(0, 255)
	end

	return string.format("%04X  %02X %02X %02X %02X  %02X %02X %02X %02X", math.random(0, 0xFFFF), b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8])
end

-- эффект «печатной машинки» с учётом UTF-8
local function TypeText(text, p)
	local len = utf8.len(text) or #text
	local n = math.floor(len * math.Clamp(p, 0, 1))

	if (n >= len) then
		return text
	end

	return text:sub(1, (utf8.offset(text, n + 1) or (#text + 1)) - 1)
end

-- укорачивает строку до maxW пикселей, добавляя «...» (результат кэшируется)
local ellipsisCache = {}

local function Ellipsize(text, font, maxW)
	local key = font .. "|" .. math.floor(maxW) .. "|" .. text

	if (ellipsisCache[key]) then
		return ellipsisCache[key]
	end

	surface.SetFont(font)

	local result = text

	if (surface.GetTextSize(text) > maxW) then
		local len = utf8.len(text) or #text

		result = "..."

		for n = len - 1, 1, -1 do
			local cut = text:sub(1, (utf8.offset(text, n + 1) or (#text + 1)) - 1) .. "..."

			if (surface.GetTextSize(cut) <= maxW) then
				result = cut

				break
			end
		end
	end

	ellipsisCache[key] = result

	return result
end

-- перенос по словам с учётом абзацев; maxLines обрезает хвост многоточием
local function WrapLines(text, font, maxW, maxLines)
	local lines = {}

	surface.SetFont(font)

	for para in string.gmatch(text .. "\n", "(.-)\n") do
		local cur = ""

		for word in string.gmatch(para, "%S+") do
			local try = (cur == "") and word or (cur .. " " .. word)

			if (cur != "" and surface.GetTextSize(try) > maxW) then
				lines[#lines + 1] = cur
				cur = word
			else
				cur = try
			end
		end

		lines[#lines + 1] = cur
	end

	while (#lines > 1 and lines[#lines] == "") do
		lines[#lines] = nil
	end

	if (maxLines and #lines > maxLines) then
		local last = lines[maxLines]

		for i = #lines, maxLines + 1, -1 do
			lines[i] = nil
		end

		lines[maxLines] = Ellipsize(last .. "...", font, maxW)
	end

	return lines
end

-- подбирает самый крупный шрифт, в который название влезает в одну строку; иначе переносит по словам (до двух строк)
-- возвращает: шрифт, список строк, ширину самой длинной строки, высоту строки
local NAME_FONTS = {"ixLoadHuge", "ixLoadBig", "ixLoadName", "ixLoadNameS"}

local function FitName(text, maxW)
	for _, font in ipairs(NAME_FONTS) do
		surface.SetFont(font)

		local tw, th = surface.GetTextSize(text)

		if (tw <= maxW) then
			return font, {text}, tw, th
		end
	end

	local font = NAME_FONTS[#NAME_FONTS]
	local lines = WrapLines(text, font, maxW, 2)
	local tw, th = 0, select(2, surface.GetTextSize(text))

	for _, line in ipairs(lines) do
		tw = math.max(tw, (surface.GetTextSize(line)))
	end

	return font, lines, tw, th
end

-- печатает строки по символам: p (0..1) — общий прогресс по всем строкам, cursor — мигающий «_» на конце
local function DrawTyped(lines, font, x, y, step, col, p, cursor)
	local counts, total = {}, 0

	for i, line in ipairs(lines) do
		counts[i] = utf8.len(line) or #line
		total = total + counts[i]
	end

	local n = math.floor(total * math.Clamp(p, 0, 1))

	for i, line in ipairs(lines) do
		if (n <= 0) then
			break
		end

		local part = line

		if (n < counts[i]) then
			part = line:sub(1, (utf8.offset(line, n + 1) or (#line + 1)) - 1)

			if (cursor) then
				part = part .. "_"
			end
		end

		draw.SimpleText(part, font, x, y + (i - 1) * step, col, LEFT, TOP)

		n = n - counts[i]
	end
end

--[[
	СГЛАЖЕННАЯ ОТРИСОВКА (как в cl_character): ядро линии + два полупрозрачных края
]]
local FEATHER = {{0, 0.6, 0.45}, {0.6, 1.3, 0.14}}
local quad = {{x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}}

local function SetQuad(x1, y1, x2, y2, x3, y3, x4, y4)
	local q = quad

	q[1].x, q[1].y = x1, y1
	q[2].x, q[2].y = x2, y2
	q[3].x, q[3].y = x3, y3
	q[4].x, q[4].y = x4, y4

	surface.DrawPoly(q)
end

local function LineBand(x1, y1, x2, y2, nx, ny, o1, o2)
	SetQuad(x1 + nx * o1, y1 + ny * o1, x2 + nx * o1, y2 + ny * o1, x2 + nx * o2, y2 + ny * o2, x1 + nx * o2, y1 + ny * o2)
end

local function SmoothLine(x1, y1, x2, y2, thick, r, g, b, a)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)

	if (len < 0.001 or a <= 0) then
		return
	end

	local nx, ny = -dy / len, dx / len
	local half = thick * 0.5

	draw.NoTexture()
	surface.SetDrawColor(r, g, b, a)
	LineBand(x1, y1, x2, y2, nx, ny, -half, half)

	for _, f in ipairs(FEATHER) do
		surface.SetDrawColor(r, g, b, a * f[3])
		LineBand(x1, y1, x2, y2, nx, ny, half + f[1], half + f[2])
		LineBand(x1, y1, x2, y2, nx, ny, -half - f[2], -half - f[1])
	end
end

-- sq — сжатие по вертикали (1 = круг, <1 = эллипс)
local function RingBand(cx, cy, rIn, rOut, a0, step, seg, sq)
	if (rOut <= 0) then
		return
	end

	rIn = math.max(rIn, 0)
	sq = sq or 1

	local c0, s0 = math.cos(a0), math.sin(a0)

	for i = 1, seg do
		local a = a0 + step * i
		local c1, s1 = math.cos(a), math.sin(a)

		SetQuad(
			cx + c0 * rOut, cy + s0 * rOut * sq,
			cx + c1 * rOut, cy + s1 * rOut * sq,
			cx + c1 * rIn, cy + s1 * rIn * sq,
			cx + c0 * rIn, cy + s0 * rIn * sq
		)

		c0, s0 = c1, s1
	end
end

local function SmoothArc(cx, cy, r, deg0, deg1, thick, seg, cr, cg, cb, ca, sq)
	if (ca <= 0 or deg1 <= deg0) then
		return
	end

	local a0 = math.rad(deg0)
	local step = math.rad(deg1 - deg0) / seg
	local half = thick * 0.5

	draw.NoTexture()
	surface.SetDrawColor(cr, cg, cb, ca)
	RingBand(cx, cy, r - half, r + half, a0, step, seg, sq)

	for _, f in ipairs(FEATHER) do
		surface.SetDrawColor(cr, cg, cb, ca * f[3])
		RingBand(cx, cy, r + half + f[1], r + half + f[2], a0, step, seg, sq)
		RingBand(cx, cy, r - half - f[2], r - half - f[1], a0, step, seg, sq)
	end
end

local function DrawBrackets(x, y, w, h, len, r, g, b, a)
	surface.SetDrawColor(r, g, b, a)

	surface.DrawRect(x, y, len, 2)
	surface.DrawRect(x, y, 2, len)
	surface.DrawRect(x + w - len, y, len, 2)
	surface.DrawRect(x + w - 2, y, 2, len)
	surface.DrawRect(x, y + h - 2, len, 2)
	surface.DrawRect(x, y + h - len, 2, len)
	surface.DrawRect(x + w - len, y + h - 2, len, 2)
	surface.DrawRect(x + w - 2, y + h - len, 2, len)
end

-- замок: s — ширина корпуса, rattle — подъём дужки (дрожание)
local function DrawLock(cx, cy, s, r, g, b, a, rattle)
	local bw, bh = math.floor(s), math.floor(s * 0.78)
	local bx, by = math.floor(cx - bw * 0.5), math.floor(cy - bh * 0.1)
	local sr = math.floor(bw * 0.3)
	local lift = math.floor(rattle or 0)
	local arcY = by - math.floor(bh * 0.15) - lift

	draw.NoTexture()

	-- дужка
	SmoothArc(cx, arcY, sr, 180, 360, 3, 18, r, g, b, a)
	surface.SetDrawColor(r, g, b, a)
	surface.DrawRect(cx - sr - 1, arcY, 3, by - arcY + 2)
	surface.DrawRect(cx + sr - 1, arcY, 3, by - arcY + 2)

	-- корпус
	surface.SetDrawColor(r, g, b, a * 0.22)
	surface.DrawRect(bx, by, bw, bh)
	surface.SetDrawColor(r, g, b, a)
	surface.DrawOutlinedRect(bx, by, bw, bh, 2)

	-- замочная скважина
	local kr = math.max(math.floor(bw * 0.09), 2)

	SmoothArc(cx, by + bh * 0.4, kr * 0.5, 0, 360, kr, 16, 255, 255, 255, a)
	surface.SetDrawColor(255, 255, 255, a)
	surface.DrawRect(cx - 1, math.floor(by + bh * 0.45), 2, math.floor(bh * 0.28))
end

-- материалы логотипов фракций (ищутся один раз; если файла нет — логотип не рисуется)
local matCache = {}

local function LoadMaterial(path)
	if (!path or path == "") then
		return false
	end

	if (matCache[path] == nil) then
		matCache[path] = false

		local mat = Material(path, "smooth mips")

		if (mat and !mat:IsError()) then
			matCache[path] = mat
		end
	end

	return matCache[path]
end

local styleCache = {}

-- цвет и логотип фракции по её индексу
local function FactionStyle(index)
	if (styleCache[index]) then
		return styleCache[index]
	end

	local faction = ix.faction.indices[index]
	local color = (faction and IsColor(faction.color)) and faction.color or CFG.idleColor
	local logo = false

	for const, col in pairs(CFG.factionColors) do
		if (_G[const] == index) then
			color = col

			break
		end
	end

	for const, path in pairs(CFG.logos) do
		if (_G[const] == index) then
			logo = LoadMaterial(path)

			break
		end
	end

	local style = {color = color, logo = logo}

	if (faction) then
		styleCache[index] = style
	end

	return style
end

-- рисует логотип по центру (cx, cy) высотой h, не шире maxW; возвращает итоговую ширину
local function DrawLogo(mat, cx, cy, h, c, a, glow, maxW)
	local w = h * mat:Width() / math.max(mat:Height(), 1)

	if (maxW and w > maxW) then
		h = h * maxW / w
		w = maxW
	end

	if (glow and glow > 0) then
		local gs = h * 2.4

		surface.SetMaterial(glowMat)
		surface.SetDrawColor(c.r, c.g, c.b, glow)
		surface.DrawTexturedRect(cx - gs * 0.5, cy - gs * 0.5, gs, gs)
	end

	render.PushFilterMag(TEXFILTER.ANISOTROPIC)
	render.PushFilterMin(TEXFILTER.ANISOTROPIC)
		surface.SetMaterial(mat)
		surface.SetDrawColor(255, 255, 255, a)
		surface.DrawTexturedRect(math.Round(cx - w * 0.5), math.Round(cy - h * 0.5), math.Round(w), math.Round(h))
	render.PopFilterMin()
	render.PopFilterMag()

	draw.NoTexture()

	return w
end

local lastPlayed = {}

local function PlayUI(key, pitchMul, volMul)
	local def = CFG.soundSet[key]

	if (!CFG.sounds or !def) then
		return
	end

	local now = RealTime()

	-- защита от «залпа» одинаковых звуков в один кадр
	if (lastPlayed[key] and now - lastPlayed[key] < 0.05) then
		return
	end

	lastPlayed[key] = now

	local vol = math.Clamp(def[2] * (volMul or 1) * CFG.soundVolume, 0, 1)
	local pitch = math.Clamp(def[3] * (pitchMul or 1), 40, 255)
	local ply = LocalPlayer()

	if (IsValid(ply)) then
		ply:EmitSound(def[1], 75, pitch, vol, CHAN_AUTO)
	else
		surface.PlaySound(def[1])
	end
end

-- угол, при котором модель смотрит прямо на камеру превью (см. cl_charcreate)
local function FaceYaw(panel, entity)
	local cam = panel.GetCamPos and panel:GetCamPos()

	if (cam) then
		local dir = cam - entity:GetPos()

		if (math.abs(dir.x) + math.abs(dir.y) > 0.01) then
			return math.deg(math.atan2(dir.y, dir.x)) + CFG.modelFace
		end
	end

	return 45 + CFG.modelFace
end

local function IsCurrentCharacter(character)
	local ply = LocalPlayer()

	return IsValid(ply) and ply.GetCharacter and ply:GetCharacter() == character
end

local function FormatTime(ts)
	if (isnumber(ts) and ts > 86400) then
		return os.date("%d.%m.%Y", ts)
	end
end

local function MoneyText(character)
	local money = character.GetMoney and character:GetMoney()

	if (!money) then
		return nil
	end

	if (ix.currency and ix.currency.Get) then
		return tostring(ix.currency.Get(money))
	end

	return tostring(money)
end

--[[
	КНОПКА В СТИЛЕ МЕНЮ ИЗ cl_character
]]
DEFINE_BASECLASS("DButton")
local BUTTON = {}

function BUTTON:Init()
	self.hoverFrac = 0
	self.pressFrac = 0
	self.label = ""
	self.pulse = false
	self.accentFn = function() return CFG.idleColor end

	self:SetText("")
end

function BUTTON:SetLabel(text)
	self.label = text
end

function BUTTON:SetAccentFunc(fn)
	self.accentFn = fn
end

-- подсвечивать кнопку «дыханием» (главное действие)
function BUTTON:SetPulse(state)
	self.pulse = state
end

function BUTTON:OnCursorEntered()
	self.shineStart = RealTime()

	if (!self:GetDisabled()) then
		PlayUI("hover", math.Rand(0.96, 1.06))
	end
end

function BUTTON:OnCursorExited()
end

function BUTTON:OnMousePressed(code)
	if (code == MOUSE_LEFT) then
		if (self:GetDisabled()) then
			PlayUI("deny")
		else
			PlayUI("click")
			self.pressFrac = 1
		end
	end

	return BaseClass.OnMousePressed(self, code)
end

function BUTTON:Paint(w, h)
	local disabled = self:GetDisabled()
	local target = (!disabled and self:IsHovered()) and 1 or 0
	local accent = self.accentFn()
	local k = disabled and 0.3 or 1
	local now = RealTime()
	local dt = RealFrameTime()

	self.hoverFrac = Lerp(math.min(dt * 14, 1), self.hoverFrac, target)
	self.pressFrac = Lerp(math.min(dt * 7, 1), self.pressFrac, 0)

	local f = self.hoverFrac
	local ef = EaseOutCubic(f)
	local pf = self.pressFrac
	local y, bh = 3, h - 6
	local glow = (self.pulse and !disabled) and (0.5 + 0.5 * math.sin(now * 2.4)) or 0

	draw.NoTexture()

	surface.SetDrawColor(accent.r, accent.g, accent.b, (16 + 34 * f + 18 * glow) * k)
	surface.DrawRect(0, y, w, bh)

	-- заливка, выезжающая слева при наведении
	if (ef > 0.01) then
		surface.SetDrawColor(accent.r, accent.g, accent.b, 40 * ef * k)
		surface.DrawRect(0, y, math.floor(w * ef), bh)
	end

	-- одиночный блик
	if (f > 0.05 and !disabled) then
		local st = (now - (self.shineStart or now)) * 1.7

		if (st < 1) then
			local sx = math.floor(-40 + (w + 80) * EaseOutCubic(st))

			for i = 0, 7 do
				local x = sx + i * 5

				if (x >= 0 and x < w) then
					surface.SetDrawColor(255, 255, 255, 38 * math.sin((i + 0.5) / 8 * math.pi) * f)
					surface.DrawRect(x, y, 5, bh)
				end
			end
		end
	end

	-- рамка с лёгким «дыханием»
	local breathe = 0.5 + 0.5 * math.sin(now * 1.6 + h)

	surface.SetDrawColor(accent.r, accent.g, accent.b, (104 + 8 * breathe + 108 * f + 40 * glow) * k)
	surface.DrawOutlinedRect(0, y, w, bh, 1)

	-- маркер слева
	surface.SetDrawColor(255, 255, 255, (70 + 185 * f) * k)
	surface.DrawRect(0, y, 4 + math.floor(3 * ef), bh)

	-- скобки справа при наведении
	if (ef > 0.02 and w > 24) then
		local bl = math.floor(10 * ef)

		surface.SetDrawColor(255, 255, 255, 200 * ef * k)
		surface.DrawRect(w - bl - 1, y, bl, 2)
		surface.DrawRect(w - 2, y, 2, bl)
		surface.DrawRect(w - bl - 1, y + bh - 2, bl, 2)
		surface.DrawRect(w - 2, y + bh - bl, 2, bl)
	end

	-- вспышка при нажатии
	if (pf > 0.01) then
		surface.SetDrawColor(255, 255, 255, 70 * pf * k)
		surface.DrawRect(0, y, w, bh)
	end

	local text = self.label
	local font = "ixLoadBtn"
	local tx = w * 0.5
	local ty = h * 0.5 + pf

	surface.SetFont(font)

	local tw = surface.GetTextSize(text)

	draw.SimpleText(text, font, tx + 1, ty + 1, Color(0, 0, 0, 150 * k), C, C)
	draw.SimpleText(text, font, tx, ty, Color(255, 255, 255, (200 + 55 * f) * k), C, C)

	-- шевроны по бокам текста при наведении
	if (ef > 0.02) then
		local off = 26 - 10 * ef
		local lx, rxx = tx - tw * 0.5 - off, tx + tw * 0.5 + off

		SmoothLine(lx, ty - 5, lx + 5, ty, 1.5, 255, 255, 255, 230 * ef * k)
		SmoothLine(lx + 5, ty, lx, ty + 5, 1.5, 255, 255, 255, 230 * ef * k)
		SmoothLine(rxx, ty - 5, rxx - 5, ty, 1.5, 255, 255, 255, 230 * ef * k)
		SmoothLine(rxx - 5, ty, rxx, ty + 5, 1.5, 255, 255, 255, 230 * ef * k)
	end

	return true
end

vgui.Register("ixCharLoadButton", BUTTON, "DButton")

--[[
	ЭКРАН ЗАГРУЗКИ ПЕРСОНАЖА
	Слева три слота (свободные заблокированы), в центре модель выбранного персонажа в полный рост
	(проявляется снизу вверх, вращается мышью), справа анимированное досье.
]]
local SCREEN = {}

function SCREEN:Init()
	self.slots = {}
	self.slotAnim = {}
	self.sel = 0
	self.selChar = nil
	self.info = nil
	self.selAt = -10
	self.hoverSlot = 0
	self.shownAt = RealTime()
	self.confirm = false
	self.confirmAt = 0
	self.entering = nil
	self.enterDone = false
	self.dragging = false
	self.dragX = 0
	self.lastDrag = 0
	self.userYaw = 0
	self.modelYaw = 0
	self.revealV = 0
	self.revealE = 0
	self.modelChar = nil
	self.sparks = {}
	self.particles = {}
	self.hexLines = {}
	self.nextHex = 0
	self.curAccent = Color(CFG.idleColor.r, CFG.idleColor.g, CFG.idleColor.b)
	self.accentTarget = CFG.idleColor

	for i = 1, 14 do
		self.hexLines[i] = HexLine()
	end

	for n = 1, CFG.particles do
		self.particles[n] = {
			fx = math.Rand(0.02, 0.98),
			y = math.Rand(0, ScrH()),
			speed = math.Rand(8, 26),
			size = math.Rand(6, 16),
			phase = math.Rand(0, math.pi * 2),
			a = math.Rand(25, 70)
		}
	end

	self:SetMouseInputEnabled(true)

	local screen = self

	-- модель выбранного персонажа
	local mp = self:Add("ixModelPanel")
	mp:SetFOV(CFG.modelFOV)
	mp.PaintModel = mp.Paint
	mp:SetMouseInputEnabled(false)
	mp:SetVisible(false)
	mp.reveal = 0

	local basePaint = mp.Paint

	-- проявление снизу вверх: модель рисуется только ниже «линии сканирования»
	mp.Paint = function(this, pw, ph)
		local e = this.reveal or 0

		if (e <= 0.001 or !IsValid(this.Entity)) then
			return
		end

		if (e >= 0.999) then
			return basePaint(this, pw, ph)
		end

		local px, py = this:LocalToScreen(0, 0)
		local frac = CFG.wipeFeet - (CFG.wipeFeet - CFG.wipeHead) * e

		render.SetScissorRect(px, py + ph * frac, px + pw, py + ph, true)
			basePaint(this, pw, ph)
		render.SetScissorRect(0, 0, 0, 0, false)
	end

	mp.LayoutEntity = function(this, entity)
		this:RunAnimation()

		if (IsValid(entity)) then
			entity:SetAngles(Angle(0, FaceYaw(this, entity) + screen.modelYaw, 0))
		end
	end

	self.model = mp

	local accentFn = function() return screen.curAccent end
	local dangerFn = function() return CFG.dangerColor end

	local function MakeButton(parent, label, fn)
		local button = parent:Add("ixCharLoadButton")

		button:SetLabel(label)
		button:SetAccentFunc(fn)

		return button
	end

	self.btnBack = MakeButton(self, CFG.backText, accentFn)
	self.btnBack.DoClick = function(this)
		if (this:GetDisabled() or screen.confirm or screen.entering) then
			return
		end

		screen:OnBack()
	end

	self.btnDelete = MakeButton(self, CFG.deleteText, dangerFn)
	self.btnDelete.DoClick = function(this)
		if (this:GetDisabled()) then
			return
		end

		screen:OpenConfirm()
	end

	self.btnEnter = MakeButton(self, CFG.enterText, accentFn)
	self.btnEnter:SetPulse(true)
	self.btnEnter.DoClick = function(this)
		if (this:GetDisabled()) then
			return
		end

		screen:BeginEnter()
	end

	-- окно подтверждения удаления: отдельная панель поверх всего
	local conf = self:Add("Panel")
	conf:SetVisible(false)
	conf.Paint = function(this, pw, ph)
		screen:PaintConfirm(pw, ph)
	end
	conf.OnMousePressed = function() end

	self.confirmPanel = conf

	self.btnYes = MakeButton(conf, CFG.confirmYes, dangerFn)
	self.btnYes.DoClick = function(this)
		screen:CloseConfirm(true)
	end

	self.btnNo = MakeButton(conf, CFG.confirmNo, accentFn)
	self.btnNo.DoClick = function(this)
		screen:CloseConfirm(false)
	end
end

-- ===== обратные вызовы (переопределяются панелью) =====
function SCREEN:OnSelect(character)
end

function SCREEN:OnBack()
end

function SCREEN:OnCreate()
end

function SCREEN:OnEnter(character)
end

function SCREEN:OnDelete(character)
end

function SCREEN:GetSelectedCharacter()
	return self.selChar
end

function SCREEN:IsBusy()
	return self.entering != nil
end

-- расстановка элементов
function SCREEN:PerformLayout(w, h)
	local L = {w = w, h = h}

	L.headY = math.floor(h * 0.07)
	L.top = math.floor(h * 0.155)
	L.bottom = math.floor(h * 0.935)

	-- колонка слотов
	L.sx = math.floor(w * 0.035)
	L.sw = math.floor(w * 0.265)
	L.cardX = L.sx + 14
	L.cardW = L.sw - 28
	L.slotGap = math.floor(h * 0.022)

	local n = math.max(#self.slots, CFG.slots)

	L.slotH = math.floor(math.min(h * 0.2, (h * 0.7 - L.slotGap * (n - 1)) / n))
	L.slotTop = L.top + math.floor(h * 0.022)

	-- центральная колонка
	L.cx = math.floor(w * 0.49)
	L.cw = math.floor(w * 0.35)

	-- колонка досье
	L.ix = math.floor(w * 0.68)
	L.iw = math.floor(w * 0.285)

	L.btnH = math.floor(h * 0.056)
	L.btnY = L.bottom - L.btnH - 18

	-- модель (пропорции и FOV подобраны как на экране выбора стороны)
	L.mw = math.floor(h * 0.78 * CFG.modelScale)
	L.mh = math.floor(h * 0.88 * CFG.modelScale)
	L.mx = L.cx - math.floor(L.mw * 0.5)
	L.my = math.floor(h * CFG.modelCenterY - L.mh * 0.5)
	L.floorY = math.floor(h * CFG.floorY)
	L.ringR = math.floor(math.min(L.cw * 0.4, h * 0.3))

	local function FontHeight(font)
		surface.SetFont(font)

		local _, th = surface.GetTextSize("Ag")

		return th
	end

	L.hTiny = FontHeight("ixLoadTiny")
	L.hSmall = FontHeight("ixLoadSmall")
	L.hText = FontHeight("ixLoadText")
	L.hMid = FontHeight("ixLoadMid")

	-- окно подтверждения
	L.cardWc = math.floor(w * 0.34)
	L.cardHc = math.floor(h * 0.27)
	L.confX = math.floor((w - L.cardWc) * 0.5)
	L.confY = math.floor((h - L.cardHc) * 0.5)

	self.L = L

	if (IsValid(self.model)) then
		self.model:SetSize(L.mw, L.mh)
		self.model:SetPos(L.mx, L.my)
	end

	self.btnBack:SetSize(math.floor(w * 0.12), L.btnH)
	self.btnBack:SetPos(40, 40)

	local delW = math.floor(L.iw * 0.36)

	self.btnDelete:SetSize(delW, L.btnH)
	self.btnDelete:SetPos(L.ix, L.btnY)
	self.btnEnter:SetSize(L.iw - delW - 12, L.btnH)
	self.btnEnter:SetPos(L.ix + delW + 12, L.btnY)

	self.confirmPanel:SetSize(w, h)
	self.confirmPanel:SetPos(0, 0)

	local bw = math.floor((L.cardWc - 72) * 0.5)
	local by = L.confY + L.cardHc - L.btnH - 24

	self.btnYes:SetSize(bw, L.btnH)
	self.btnYes:SetPos(L.confX + 24, by)
	self.btnNo:SetSize(bw, L.btnH)
	self.btnNo:SetPos(L.confX + L.cardWc - 24 - bw, by)
end

-- сброс при каждом открытии меню
function SCREEN:Reset()
	if (self.dragging) then
		self:MouseCapture(false)
	end

	self.shownAt = RealTime()
	self.confirm = false
	self.entering = nil
	self.enterDone = false
	self.dragging = false
	self.sel = 0
	self.selChar = nil
	self.info = nil
	self.userYaw = 0
	self.modelYaw = 0
	self.modelChar = nil
	self.revealV = 0
	self.revealE = 0
	self.sparks = {}

	self.confirmPanel:SetVisible(false)
	self.model.reveal = 0
	self.model:SetVisible(false)

	self:SetMouseInputEnabled(true)
end

-- list[i] = {character = персонаж или nil, locked = true/false}
function SCREEN:SetSlots(list)
	local prev = self.selChar
	local want

	self.slots = list
	self.slotAnim = {}

	for i = 1, #list do
		self.slotAnim[i] = {hover = 0, sel = 0, shake = -10}

		if (prev and list[i].character == prev) then
			want = i
		end
	end

	if (want) then
		-- тот же персонаж остался в списке — выбор не сбрасываем
		self.sel = want
		self.slotAnim[want].sel = 1
	else
		self.sel = 0
		self.selChar = nil
		self.info = nil

		if (CFG.autoSelect) then
			local pick

			for i, slot in ipairs(list) do
				if (slot.character) then
					pick = pick or i

					if (IsCurrentCharacter(slot.character)) then
						pick = i

						break
					end
				end
			end

			if (pick) then
				self:Select(pick)
			end
		end
	end

	self:InvalidateLayout()
end

function SCREEN:SlotRect(i)
	local L = self.L

	return L.cardX, L.slotTop + (i - 1) * (L.slotH + L.slotGap), L.cardW, L.slotH
end

function SCREEN:SlotAt(mx, my)
	if (!self.L) then
		return 0
	end

	for i = 1, #self.slots do
		local x, y, w, h = self:SlotRect(i)

		if (mx >= x and mx <= x + w and my >= y and my <= y + h) then
			return i
		end
	end

	return 0
end

function SCREEN:InModelArea(mx, my)
	local L = self.L

	return mx >= L.cx - L.cw * 0.5 and mx <= L.cx + L.cw * 0.5 and my >= L.top and my <= L.bottom
end

-- собирает данные для досье
function SCREEN:BuildInfo(character)
	local factionIndex = character:GetFaction()
	local faction = ix.faction.indices[factionIndex]
	local style = FactionStyle(factionIndex)

	local info = {
		char = character,
		name = Upper(tostring(character:GetName() or "")),
		faction = faction and Upper(L(faction.name)) or "НЕИЗВЕСТНО",
		color = style.color,
		logo = style.logo,
		desc = tostring(character:GetDescription() or ""),
		id = character:GetID(),
		money = MoneyText(character),
		created = character.GetCreateTime and FormatTime(character:GetCreateTime()) or nil,
		lastJoin = character.GetLastJoinTime and FormatTime(character:GetLastJoinTime()) or nil,
		attrs = {}
	}

	if (ix.attributes and istable(ix.attributes.list)) then
		local maxValue = ix.config.Get("maxAttributes", 30)

		for key, attr in SortedPairs(ix.attributes.list) do
			if (#info.attrs >= CFG.maxAttributes) then
				break
			end

			local value = character.GetAttribute and character:GetAttribute(key, 0) or 0

			info.attrs[#info.attrs + 1] = {
				name = Upper(L(attr.name or key)),
				value = value,
				max = attr.maxValue or maxValue
			}
		end
	end

	return info
end

function SCREEN:SpawnSparks()
	local L = self.L

	if (!L) then
		return
	end

	for _ = 1, 18 do
		if (#self.sparks >= 80) then
			break
		end

		self.sparks[#self.sparks + 1] = {
			x = L.cx + math.Rand(-1, 1) * L.ringR * 0.8,
			y = L.floorY + math.Rand(-6, 10),
			vx = math.Rand(-20, 20),
			vy = -math.Rand(80, 260),
			life = 0,
			max = math.Rand(0.7, 1.6),
			size = math.Rand(2, 5)
		}
	end
end

function SCREEN:Select(i)
	local slot = self.slots[i]

	if (!slot or !slot.character or self.sel == i) then
		return
	end

	self.sel = i
	self.selChar = slot.character
	self.selAt = RealTime()
	self.info = self:BuildInfo(slot.character)

	self:SpawnSparks()

	PlayUI("confirm", 1.05)
	PlayUI("tick", 0.9)

	self:OnSelect(slot.character)
end

function SCREEN:ClickSlot(i)
	local slot = self.slots[i]
	local anim = self.slotAnim[i]

	if (!slot) then
		return
	end

	if (slot.locked) then
		PlayUI("deny")
		anim.shake = RealTime()

		return
	end

	PlayUI("click")

	if (!slot.character) then
		self:OnCreate()

		return
	end

	self:Select(i)
end

-- подгружает модель персонажа в панель превью
function SCREEN:ApplyModel(character)
	local mp = self.model

	if (!character) then
		mp:SetVisible(false)

		return
	end

	mp:SetModel(character:GetModel(), character:GetData("skin", 0))
	mp:SetFOV(CFG.modelFOV)

	local entity = mp.Entity

	if (IsValid(entity)) then
		for i = 0, (entity:GetNumBodyGroups() - 1) do
			entity:SetBodygroup(i, 0)
		end

		local groups = character:GetData("groups", nil)

		if (istable(groups)) then
			for k, v in pairs(groups) do
				entity:SetBodygroup(k, v)
			end
		end
	end

	mp.reveal = 0
	mp:SetVisible(true)
end

function SCREEN:BeginEnter()
	if (!self.selChar or self.entering or self.confirm) then
		return
	end

	self.entering = RealTime()
	self.enterDone = false

	PlayUI("confirm")
	PlayUI("boom", 1.1)
end

function SCREEN:OpenConfirm()
	if (!self.selChar or self.entering or self.confirm) then
		return
	end

	self.confirm = true
	self.confirmAt = RealTime()
	self.confirmLines = WrapLines(CFG.confirmText, "ixLoadText", self.L.cardWc - 64, 3)

	self.confirmPanel:SetVisible(true)
	self.confirmPanel:MoveToFront()
	self.btnYes:SetAlpha(0)
	self.btnNo:SetAlpha(0)

	PlayUI("open")
end

function SCREEN:CloseConfirm(bYes)
	self.confirm = false
	self.confirmPanel:SetVisible(false)

	if (bYes and self.selChar) then
		PlayUI("boom", 0.8)
		self:OnDelete(self.selChar)
	else
		PlayUI("click", 0.9)
	end
end

function SCREEN:OnMousePressed(code)
	if (code != MOUSE_LEFT or self.confirm or self.entering) then
		return
	end

	local mx, my = self:CursorPos()
	local slot = self:SlotAt(mx, my)

	if (slot != 0) then
		self:ClickSlot(slot)

		return
	end

	if (self.selChar and self.L and self:InModelArea(mx, my)) then
		self.dragging = true
		self.dragX = mx
		self.lastDrag = RealTime()

		self:MouseCapture(true)
	end
end

function SCREEN:OnMouseReleased(code)
	if (self.dragging) then
		self.dragging = false
		self.userYaw = math.NormalizeAngle(self.userYaw)
		self.lastDrag = RealTime()

		self:MouseCapture(false)
	end
end

function SCREEN:Think()
	local L = self.L

	if (!L) then
		return
	end

	local now = RealTime()
	local dt = math.min(RealFrameTime(), 0.05)
	local mx, my = self:CursorPos()
	local hovered = self:IsHovered() and !self.entering
	local hs = hovered and self:SlotAt(mx, my) or 0

	if (hs != self.hoverSlot) then
		self.hoverSlot = hs

		if (hs != 0) then
			PlayUI("hover", self.slots[hs].locked and 0.75 or 1)
		end
	end

	if (hs != 0) then
		self:SetCursor("hand")
	elseif (hovered and self.selChar and self:InModelArea(mx, my)) then
		self:SetCursor("sizewe")
	else
		self:SetCursor("arrow")
	end

	for i, anim in ipairs(self.slotAnim) do
		anim.hover = Lerp(math.min(dt * 10, 1), anim.hover, (hs == i) and 1 or 0)
		anim.sel = Lerp(math.min(dt * 8, 1), anim.sel, (self.sel == i) and 1 or 0)
	end

	-- акцент плавно меняется под фракцию выбранного персонажа
	self.accentTarget = self.info and self.info.color or CFG.idleColor

	local t, c = self.accentTarget, self.curAccent
	local k = math.min(RealFrameTime() * 6, 1)

	c.r = Lerp(k, c.r, t.r)
	c.g = Lerp(k, c.g, t.g)
	c.b = Lerp(k, c.b, t.b)

	-- смена модели: старая «гаснет» за долю секунды, затем проявляется новая
	local mp = self.model

	if (self.modelChar != self.selChar) then
		if (self.modelChar and self.revealV > 0.02) then
			self.revealV = math.max(self.revealV - dt * 5, 0)
		else
			self.modelChar = self.selChar
			self.revealV = 0
			self:ApplyModel(self.modelChar)
		end
	elseif (self.modelChar) then
		self.revealV = math.min(self.revealV + dt / CFG.revealTime, 1)
	end

	self.revealE = self.modelChar and EaseOutCubic(self.revealV) or 0
	mp.reveal = self.revealE
	mp.brightness = (now - self.selAt < 0.7) and (0.7 + 0.5 * math.random()) or 1

	-- вращение модели: перетаскивание мышью, затем плавный возврат; без перетаскивания — лёгкий поворот за курсором
	if (self.dragging) then
		if (!input.IsMouseDown(MOUSE_LEFT)) then
			self:OnMouseReleased(MOUSE_LEFT)
		else
			self.userYaw = self.userYaw + (mx - self.dragX) * CFG.dragSpeed
			self.dragX = mx
			self.lastDrag = now
		end
	elseif (now - self.lastDrag > CFG.dragReturn) then
		self.userYaw = Lerp(math.min(dt * 1.5, 1), self.userYaw, 0)
	end

	local follow = 0

	if (hovered and !self.dragging and self.selChar) then
		follow = math.Clamp((mx - L.cx) / (L.w * 0.35), -1, 1) * CFG.modelTurnMax * 0.6
	end

	local want = self.userYaw + follow + math.sin(now * 0.8) * 2.5

	self.modelYaw = Lerp(math.min(dt * (self.dragging and 16 or 5), 1), self.modelYaw, want)

	-- кнопки
	local busy = self.confirm or self.entering != nil
	local ra = EaseOutCubic(Prog(now - self.shownAt, 0.5, 0.5))

	self.btnBack:SetDisabled(busy)
	self.btnEnter:SetDisabled(busy or !self.selChar)
	self.btnDelete:SetDisabled(busy or !self.selChar)
	self.btnEnter:SetLabel(self.entering and CFG.enteringText or CFG.enterText)

	self.btnBack:SetAlpha(255 * ra)
	self.btnEnter:SetAlpha(255 * ra)
	self.btnDelete:SetAlpha(255 * ra)

	if (self.confirm) then
		local ba = Clamp01((EaseOutCubic(Prog(now - self.confirmAt, 0, 0.3)) - 0.5) / 0.5)

		self.btnYes:SetAlpha(255 * ba)
		self.btnNo:SetAlpha(255 * ba)
	end

	-- вход в игру после короткой паузы
	if (self.entering and !self.enterDone and now - self.entering >= CFG.enterDelay) then
		self.enterDone = true
		self:OnEnter(self.selChar)
	end
end

--[[
	ОТРИСОВКА
]]
function SCREEN:DrawSlot(i, now)
	local slot, anim = self.slots[i], self.slotAnim[i]
	local bx, by, bw, bh = self:SlotRect(i)
	local p = EaseOutCubic(Prog(now - self.shownAt, 0.2 + (i - 1) * 0.12, 0.55))

	if (p <= 0) then
		return
	end

	local hv, sl = EaseOutCubic(anim.hover), EaseOutCubic(anim.sel)
	local act = math.max(hv, sl)
	local locked, character = slot.locked, slot.character
	local c

	if (character) then
		c = FactionStyle(character:GetFaction()).color
	elseif (locked) then
		c = CFG.lockedColor
	else
		c = self.curAccent
	end

	local x = bx + math.floor(-60 * (1 - p) + 12 * sl)
	local k = p
	local dim = locked and 0.6 or 1
	local breathe = 0.5 + 0.5 * math.sin(now * 1.6 + i)
	local tx = x + 24

	draw.NoTexture()

	-- подложка и заливка выбранного слота
	surface.SetDrawColor(c.r, c.g, c.b, (16 + 30 * hv + 34 * sl) * k * dim)
	surface.DrawRect(x, by, bw, bh)

	if (sl > 0.01) then
		surface.SetDrawColor(c.r, c.g, c.b, 46 * sl * k)
		surface.DrawRect(x, by, math.floor(bw * sl), bh)
	end

	-- штриховка заблокированного слота
	if (locked) then
		local sx, sy = self:LocalToScreen(x, by)

		render.SetScissorRect(sx, sy, sx + bw, sy + bh, true)
			surface.SetDrawColor(c.r, c.g, c.b, 14 * k)

			for gx = -bh, bw, 14 do
				surface.DrawLine(x + gx, by + bh, x + gx + bh, by)
			end
		render.SetScissorRect(0, 0, 0, 0, false)
	end

	-- рамка и маркер слева
	surface.SetDrawColor(c.r, c.g, c.b, (92 + 8 * breathe + 118 * act) * k * dim)
	surface.DrawOutlinedRect(x, by, bw, bh, 1)
	surface.SetDrawColor(255, 255, 255, (70 + 185 * act) * k * dim)
	surface.DrawRect(x, by, 4 + math.floor(3 * sl), bh)

	if (character) then
		local rightSpace = math.floor(bh * 0.85)
		local style = FactionStyle(character:GetFaction())
		local faction = ix.faction.indices[character:GetFaction()]

		-- номер слота водяным знаком (если нет логотипа)
		if (style.logo) then
			DrawLogo(style.logo, x + bw - math.floor(bh * 0.5) - 8, by + bh * 0.5, bh * 0.42, c, (200 + 55 * act) * k, (20 + 50 * act) * k, bh * 0.7)
		else
			draw.SimpleText(string.format("%02d", i), "ixLoadNum", x + bw - 14, by + bh * 0.5, Color(c.r, c.g, c.b, (14 + 22 * act) * k), RIGHT, C)
		end

		draw.SimpleText(CFG.slotLabel .. " " .. string.format("%02d", i), "ixLoadSmall", tx, by + bh * 0.13, Color(c.r, c.g, c.b, (170 + 60 * act) * k), LEFT, TOP)

		if (IsCurrentCharacter(character)) then
			draw.SimpleText(CFG.activeText, "ixLoadTiny", x + bw - 14, by + bh * 0.13 + 2, Color(255, 255, 255, 150 * k), RIGHT, TOP)
		end

		local name = Ellipsize(Upper(tostring(character:GetName() or "")), "ixLoadSlot", bw - 48 - rightSpace)

		draw.SimpleText(name, "ixLoadSlot", tx + 2, by + bh * 0.33 + 2, Color(0, 0, 0, 160 * k), LEFT, TOP)
		draw.SimpleText(name, "ixLoadSlot", tx, by + bh * 0.33, Color(255, 255, 255, (200 + 55 * act) * k), LEFT, TOP)

		draw.SimpleText(Ellipsize(faction and Upper(L(faction.name)) or "", "ixLoadSmall", bw - 48 - rightSpace), "ixLoadSmall", tx, by + bh * 0.62, Color(c.r, c.g, c.b, 210 * k), LEFT, TOP)
		draw.SimpleText(string.format("#%06d", character:GetID()), "ixLoadTiny", tx, by + bh - self.L.hTiny - 14, Color(255, 255, 255, 90 * k), LEFT, TOP)
	elseif (locked) then
		-- замок: при наведении дужка подрагивает, при клике слот «трясётся»
		local ts = now - anim.shake
		local shake = (ts >= 0 and ts < 0.45) and math.sin(ts * 70) * 5 * (1 - ts / 0.45) or 0
		local flash = (ts >= 0 and ts < 0.45) and (1 - ts / 0.45) or 0
		local rattle = hv * math.abs(math.sin(now * 14)) * 3
		local lx = x + 24 + math.floor(bh * 0.22) + shake
		local ly = by + bh * 0.5
		local lc = flash > 0 and CFG.dangerColor or c

		DrawLock(lx, ly, bh * 0.26, lc.r, lc.g, lc.b, (170 + 60 * flash) * k, rattle)

		local textX = x + 24 + math.floor(bh * 0.5) + 14

		draw.SimpleText(CFG.slotLabel .. " " .. string.format("%02d", i), "ixLoadSmall", textX, by + bh * 0.13, Color(c.r, c.g, c.b, 170 * k), LEFT, TOP)
		draw.SimpleText(CFG.lockedText, "ixLoadSmall", textX, by + bh * 0.42, Color(255, 255, 255, (150 + 60 * flash) * k), LEFT, TOP)
		draw.SimpleText(CFG.lockedHint, "ixLoadTiny", textX, by + bh * 0.42 + self.L.hSmall + 6, Color(c.r, c.g, c.b, 150 * k), LEFT, TOP)
	else
		-- свободный слот: плюс и подсказка
		local px, py = x + 24 + math.floor(bh * 0.22), by + bh * 0.5
		local ps = math.floor(bh * 0.12) + math.floor(3 * hv)

		SmoothLine(px - ps, py, px + ps, py, 2, c.r, c.g, c.b, (170 + 70 * hv) * k)
		SmoothLine(px, py - ps, px, py + ps, 2, c.r, c.g, c.b, (170 + 70 * hv) * k)
		SmoothArc(px, py, math.floor(bh * 0.2), 0, 360, 1, 40, c.r, c.g, c.b, (60 + 100 * hv) * k)

		local textX = x + 24 + math.floor(bh * 0.5) + 14

		draw.SimpleText(CFG.slotLabel .. " " .. string.format("%02d", i), "ixLoadSmall", textX, by + bh * 0.13, Color(c.r, c.g, c.b, 170 * k), LEFT, TOP)
		draw.SimpleText(CFG.freeText, "ixLoadSmall", textX, by + bh * 0.42, Color(255, 255, 255, (170 + 60 * hv) * k), LEFT, TOP)
		draw.SimpleText(Ellipsize(CFG.freeHint, "ixLoadTiny", bw - (textX - x) - 14), "ixLoadTiny", textX, by + bh * 0.42 + self.L.hSmall + 6, Color(c.r, c.g, c.b, 150 * k), LEFT, TOP)
	end

	-- скобки вокруг выбранного/наведённого слота
	if (act > 0.02 and !locked) then
		surface.SetDrawColor(255, 255, 255, 255 * act * k)
		DrawBrackets(x - 4, by - 4, bw + 8, bh + 8, math.floor(10 + 8 * sl), 255, 255, 255, 230 * act * k)
	end
end

-- сводка по слотам под колонкой: сегментная шкала и счётчики
function SCREEN:DrawSummary(now)
	local L, c = self.L, self.curAccent
	local n = #self.slots
	local used, locked = 0, 0

	for _, slot in ipairs(self.slots) do
		if (slot.character) then
			used = used + 1
		elseif (slot.locked) then
			locked = locked + 1
		end
	end

	local free = n - used - locked
	local p = EaseOutCubic(Prog(now - self.shownAt, 0.7, 0.5))
	local y = L.slotTop + n * L.slotH + (n - 1) * L.slotGap + 26
	local x = L.cardX
	local w = L.cardW

	draw.SimpleText(CFG.summaryLabel, "ixLoadSmall", x, y, Color(c.r, c.g, c.b, 170 * p), LEFT, TOP)

	y = y + L.hSmall + 10

	local gap = 8
	local segW = math.floor((w - gap * (n - 1)) / math.max(n, 1))

	draw.NoTexture()

	for i, slot in ipairs(self.slots) do
		local sx = x + (i - 1) * (segW + gap)
		local sp = EaseOutCubic(Prog(now - self.shownAt, 0.75 + (i - 1) * 0.1, 0.4))
		local fillW = math.floor(segW * sp)

		if (slot.character) then
			local col = FactionStyle(slot.character:GetFaction()).color

			surface.SetDrawColor(col.r, col.g, col.b, 210 * p)
			surface.DrawRect(sx, y, fillW, 8)
			surface.SetDrawColor(255, 255, 255, 120 * p)
			surface.DrawOutlinedRect(sx, y, segW, 8, 1)
		elseif (slot.locked) then
			surface.SetDrawColor(CFG.lockedColor.r, CFG.lockedColor.g, CFG.lockedColor.b, 40 * sp * p)
			surface.DrawRect(sx, y, segW, 8)
			surface.SetDrawColor(CFG.lockedColor.r, CFG.lockedColor.g, CFG.lockedColor.b, 90 * p)
			surface.DrawOutlinedRect(sx, y, segW, 8, 1)
		else
			surface.SetDrawColor(c.r, c.g, c.b, 30 * sp * p)
			surface.DrawRect(sx, y, segW, 8)
			surface.SetDrawColor(c.r, c.g, c.b, 140 * p)
			surface.DrawOutlinedRect(sx, y, segW, 8, 1)
		end
	end

	y = y + 8 + 12

	draw.SimpleText("ЗАНЯТО: " .. used .. "   //   СВОБОДНО: " .. free .. "   //   ЗАБЛОКИРОВАНО: " .. locked, "ixLoadTiny", x, y, Color(255, 255, 255, 130 * p), LEFT, TOP)
end

-- центральная колонка: «пол», кольца, свет, ударные волны при выборе
function SCREEN:DrawFloor(now)
	local L, c = self.L, self.curAccent
	local sel = self.revealE
	local fy, cx = L.floorY, L.cx
	local rx = L.ringR * (1 + 0.06 * sel)

	draw.NoTexture()

	-- свечение на полу и световой столб над ним
	local gs = rx * 2.6

	surface.SetMaterial(glowMat)
	surface.SetDrawColor(c.r, c.g, c.b, 30 + 60 * sel)
	surface.DrawTexturedRect(cx - gs * 0.5, fy - gs * 0.16, gs, gs * 0.32)

	if (sel > 0.01) then
		local gh = fy - L.h * 0.17

		surface.SetDrawColor(c.r, c.g, c.b, 16 * sel)
		surface.DrawTexturedRect(cx - rx * 0.55, fy - gh, rx * 1.1, gh)
	end

	draw.NoTexture()

	SmoothArc(cx, fy, rx, 0, 360, 2, 90, c.r, c.g, c.b, 70 + 120 * sel, 0.2)
	SmoothArc(cx, fy, rx * 0.72, 0, 360, 1, 72, 255, 255, 255, 25 + 60 * sel, 0.2)

	for k = 0, 5 do
		local s = now * (30 + 40 * sel) + k * 60

		SmoothArc(cx, fy, rx * 1.12, s, s + 22, 3, 10, 255, 255, 255, 40 + 140 * sel, 0.2)
	end

	-- ударные кольца в момент выбора
	local t = now - self.selAt

	if (self.selChar) then
		for r = 0, 1 do
			local p = (t - r * 0.15) / 1.1

			if (p > 0 and p < 1) then
				SmoothArc(cx, fy, rx * (0.35 + EaseOutExpo(p) * 1.3), 0, 360, 2 + (1 - p) * 4, 120, c.r, c.g, c.b, 220 * (1 - p) ^ 2, 0.2)
			end
		end
	end
end

-- пустое состояние центра: прицел с вопросом
function SCREEN:DrawCenterIdle(now, a)
	local L, c = self.L, self.curAccent
	local cx, cy = L.cx, math.floor(L.h * 0.46)
	local r = math.floor(L.h * 0.11)
	local p = Prog(now - self.shownAt, 0.4, 0.8) * a
	local pulse = 0.5 + 0.5 * math.sin(now * 2)

	if (p <= 0) then
		return
	end

	draw.NoTexture()

	SmoothArc(cx, cy, r, 0, 360, 1, 72, c.r, c.g, c.b, 90 * p)

	for k = 0, 3 do
		local s = now * 25 + k * 90

		SmoothArc(cx, cy, r + 10, s, s + 40, 2, 10, 255, 255, 255, 150 * p)
	end

	for k = 0, 5 do
		local s = -now * 18 + k * 60

		SmoothArc(cx, cy, r - 12, s, s + 20, 1, 6, c.r, c.g, c.b, 120 * p)
	end

	surface.SetDrawColor(c.r, c.g, c.b, 110 * p)
	surface.DrawRect(cx - r - 28, cy, 18, 1)
	surface.DrawRect(cx + r + 10, cy, 18, 1)
	surface.DrawRect(cx, cy - r - 28, 1, 18)
	surface.DrawRect(cx, cy + r + 10, 1, 18)

	draw.SimpleText("?", "ixLoadHuge", cx, cy, Color(255, 255, 255, (150 + 90 * pulse) * p), C, C)
	draw.SimpleText(CFG.idleTitle, "ixLoadMid", cx, cy + r + 46, Color(255, 255, 255, 230 * p), C, C)
	draw.SimpleText(CFG.idleHint, "ixLoadSmall", cx, cy + r + 46 + L.hMid, Color(c.r, c.g, c.b, (140 + 60 * pulse) * p), C, C)
end

-- досье выбранного персонажа
function SCREEN:DrawInfo(now)
	local L, info = self.L, self.info
	local c = info.color
	local t = now - self.selAt
	local x = L.ix + 22
	local w = L.iw - 44
	local y = L.top + 22
	local hS, hX = L.hSmall, L.hText

	draw.NoTexture()

	-- шапка: метка и индикатор
	local pTag = Prog(t, 0, 0.25)
	local pulse = 0.5 + 0.5 * math.sin(now * 3.2)

	draw.SimpleText(CFG.dossierText .. "  //  " .. CFG.slotLabel .. " " .. string.format("%02d", self.sel), "ixLoadSmall", x, y, Color(c.r, c.g, c.b, 200 * pTag), LEFT, TOP)

	surface.SetDrawColor(255, 255, 255, (120 + 110 * pulse) * pTag)
	surface.DrawRect(x + w - 7, y + 4, 7, 7)

	if (IsCurrentCharacter(info.char)) then
		draw.SimpleText(CFG.activeText, "ixLoadTiny", x + w - 18, y + 3, Color(255, 255, 255, 170 * pTag), RIGHT, TOP)
	end

	y = y + hS + 16

	-- имя с «глитчем» при появлении
	local font, lines, tw, th = FitName(info.name, w)
	local step = math.floor(th * 0.95)
	local pName = Prog(t, 0.08, 0.5)
	local gl = Clamp01(1 - (t - 0.05) / 0.3)

	if (gl > 0.02 and pName > 0) then
		local off = 3 + gl * 6

		DrawTyped(lines, font, x - off, y, step, Color(255, 50, 70, 110 * gl), pName)
		DrawTyped(lines, font, x + off, y, step, Color(50, 220, 255, 110 * gl), pName)
	end

	DrawTyped(lines, font, x + 2, y + 2, step, Color(0, 0, 0, 160), pName)
	DrawTyped(lines, font, x, y, step, Color(255, 255, 255, 255), pName, true)

	y = y + #lines * step + 6

	-- подчёркивание
	local lw = math.floor(w * EaseOutCubic(Prog(t, 0.25, 0.5)))

	draw.NoTexture()
	surface.SetDrawColor(c.r, c.g, c.b, 30)
	surface.DrawRect(x, y, w, 1)
	surface.SetDrawColor(c.r, c.g, c.b, 220)
	surface.DrawRect(x, y, lw, 2)
	surface.SetDrawColor(255, 255, 255, 220)
	surface.DrawRect(x - 1, y - 1, 4, 4)

	if (lw > 8) then
		surface.DrawRect(x + lw - 3, y - 1, 4, 4)
	end

	y = y + 18

	-- фракция
	local pF = EaseOutCubic(Prog(t, 0.35, 0.45))
	local rowH = math.floor(L.h * 0.05)
	local lx = x

	if (info.logo) then
		local logoW = math.min(rowH * info.logo:Width() / math.max(info.logo:Height(), 1), rowH * 1.6)

		DrawLogo(info.logo, x + logoW * 0.5 - 20 * (1 - pF), y + rowH * 0.5, rowH, c, 235 * pF, 40 * pF, rowH * 1.6)

		lx = x + logoW + 14
	end

	draw.SimpleText(CFG.factionLabel, "ixLoadSmall", lx - 20 * (1 - pF), y + 2, Color(c.r, c.g, c.b, 170 * pF), LEFT, TOP)
	draw.SimpleText(Ellipsize(info.faction, "ixLoadMid", x + w - lx), "ixLoadMid", lx - 20 * (1 - pF), y + hS + 4, Color(255, 255, 255, 240 * pF), LEFT, TOP)

	y = y + rowH + 14

	-- разделитель
	local pSep = Prog(t, 0.45, 0.4)

	surface.SetDrawColor(c.r, c.g, c.b, 60)
	surface.DrawRect(x, y, math.floor(w * EaseOutCubic(pSep)), 1)

	y = y + 12

	-- описание (печатается)
	local pL = Prog(t, 0.5, 0.3)

	draw.SimpleText(CFG.descLabel, "ixLoadSmall", x, y, Color(c.r, c.g, c.b, 170 * pL), LEFT, TOP)

	y = y + hS + 8

	if (info.descW != w) then
		local text = (info.desc:Trim() == "") and CFG.noDescText or info.desc

		info.descW = w
		info.descLines = WrapLines(text, "ixLoadText", w, CFG.descLines)
		info.descChars = 0

		for _, line in ipairs(info.descLines) do
			info.descChars = info.descChars + (utf8.len(line) or #line)
		end
	end

	local lineH = math.floor(hX * 1.25)
	local dur = math.Clamp(info.descChars * 0.012, 0.3, 1.4)

	DrawTyped(info.descLines, "ixLoadText", x, y, lineH, Color(255, 255, 255, 200), Prog(t, 0.6, dur), true)

	y = y + #info.descLines * lineH + 10

	draw.NoTexture()
	surface.SetDrawColor(c.r, c.g, c.b, 60)
	surface.DrawRect(x, y, math.floor(w * EaseOutCubic(Prog(t, 0.6 + dur * 0.5, 0.4))), 1)

	y = y + 12

	-- данные 2x2
	local cells = {
		{"ИДЕНТИФИКАТОР", string.format("#%06d", info.id)},
		{"СРЕДСТВА", info.money or "-"}
	}

	if (info.created) then
		cells[#cells + 1] = {"СОЗДАН", info.created}
	end

	if (info.lastJoin) then
		cells[#cells + 1] = {"ПОСЛЕДНИЙ ВХОД", info.lastJoin}
	end

	if (#cells < 4) then
		cells[#cells + 1] = {"СТАТУС", IsCurrentCharacter(info.char) and "В ИГРЕ" or "В АРХИВЕ"}
	end

	if (#cells < 4) then
		cells[#cells + 1] = {"ДОПУСК", "ПОДТВЕРЖДЁН"}
	end

	local cellW = math.floor(w * 0.5)
	local cellH = hS + L.hMid + 14

	for i, cell in ipairs(cells) do
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		local p = EaseOutCubic(Prog(t, 0.75 + (i - 1) * 0.07, 0.35))
		local cx = x + col * cellW
		local cy = y + row * cellH + 6 * (1 - p)

		draw.SimpleText(cell[1], "ixLoadSmall", cx, cy, Color(c.r, c.g, c.b, 150 * p), LEFT, TOP)
		draw.SimpleText(Ellipsize(cell[2], "ixLoadMid", cellW - 12), "ixLoadMid", cx, cy + hS + 2, Color(255, 255, 255, 235 * p), LEFT, TOP)
	end

	y = y + 2 * cellH

	-- характеристики: полосы заполняются по очереди
	if (#info.attrs > 0) then
		draw.NoTexture()
		surface.SetDrawColor(c.r, c.g, c.b, 60)
		surface.DrawRect(x, y, math.floor(w * EaseOutCubic(Prog(t, 0.85, 0.4))), 1)

		y = y + 12

		draw.SimpleText(CFG.attrLabel, "ixLoadSmall", x, y, Color(c.r, c.g, c.b, 170 * Prog(t, 0.9, 0.3)), LEFT, TOP)

		y = y + hS + 10

		local rowStep = hS + 16
		local limit = L.btnY - 16
		local count = math.min(#info.attrs, math.floor((limit - y) / rowStep))

		for i = 1, count do
			local attr = info.attrs[i]
			local p = Prog(t, 0.95 + (i - 1) * 0.08, 0.6)
			local e = EaseOutCubic(p)
			local frac = Clamp01(attr.value / math.max(attr.max, 1))
			local ry = y + (i - 1) * rowStep

			draw.SimpleText(Ellipsize(attr.name, "ixLoadSmall", w - 90), "ixLoadSmall", x, ry, Color(255, 255, 255, 190 * e), LEFT, TOP)
			draw.SimpleText(tostring(math.floor(attr.value * e + 0.5)), "ixLoadMono", x + w, ry + 2, Color(255, 255, 255, 220 * e), RIGHT, TOP)

			local by = ry + hS + 4

			draw.NoTexture()
			surface.SetDrawColor(c.r, c.g, c.b, 40 * e)
			surface.DrawRect(x, by, w, 4)
			surface.SetDrawColor(255, 255, 255, 235 * e)

			local fw = math.floor(w * frac * e)

			surface.DrawRect(x, by, fw, 4)

			-- сегментные деления
			surface.SetDrawColor(7, 10, 15, 200 * e)

			for s = 1, 9 do
				surface.DrawRect(x + math.floor(w * s / 10), by, 1, 4)
			end

			-- светящаяся головка полосы
			if (fw > 2 and p < 1) then
				surface.SetMaterial(glowMat)
				surface.SetDrawColor(c.r, c.g, c.b, 150 * (1 - p))
				surface.DrawTexturedRect(x + fw - 16, by + 2 - 16, 32, 32)
				draw.NoTexture()
			end
		end
	end
end

-- пустое досье: «скелет» с бегущим бликом и поток hex-данных
function SCREEN:DrawInfoIdle(now)
	local L, c = self.L, self.curAccent
	local x = L.ix + 22
	local w = L.iw - 44
	local y = L.top + 22
	local p = Prog(now - self.shownAt, 0.5, 0.6)
	local hS = L.hSmall

	draw.NoTexture()

	draw.SimpleText(CFG.dossierText .. "  //  ОЖИДАНИЕ", "ixLoadSmall", x, y, Color(c.r, c.g, c.b, 170 * p), LEFT, TOP)

	surface.SetDrawColor(255, 255, 255, (120 + 110 * (0.5 + 0.5 * math.sin(now * 3.2))) * p)
	surface.DrawRect(x + w - 7, y + 4, 7, 7)

	y = y + hS + 16

	draw.SimpleText(TypeText(CFG.noDataTitle, (p - 0.1) / 0.6), "ixLoadBig", x, y, Color(255, 255, 255, 200 * p), LEFT, TOP)

	surface.SetFont("ixLoadBig")

	local _, th = surface.GetTextSize("A")

	y = y + th + 6

	draw.NoTexture()
	surface.SetDrawColor(c.r, c.g, c.b, 150 * p)
	surface.DrawRect(x, y, math.floor(w * 0.35 * p), 2)

	y = y + 14

	draw.SimpleText(CFG.noDataHint, "ixLoadTiny", x, y, Color(255, 255, 255, 120 * p), LEFT, TOP)

	y = y + L.hTiny + 28

	-- скелет досье
	local bars = {
		{0.55, 22}, {0.9, 12}, {0.8, 12}, {0.86, 12}, {0.6, 12}, {0.45, 12},
		{0.4, 30}, {0.4, 30}, {0.4, 30}, {0.4, 30}
	}
	local by = y

	for i, bar in ipairs(bars) do
		local bw = math.floor(w * bar[1])
		local bh = bar[2]
		local bx = x

		-- второй столбец ячеек данных
		if (i >= 8 and i % 2 == 1) then
			bx = x + math.floor(w * 0.5)
			by = by - (bh + 12)
		end

		draw.NoTexture()
		surface.SetDrawColor(c.r, c.g, c.b, 12 * p)
		surface.DrawRect(bx, by, bw, bh)
		surface.SetDrawColor(c.r, c.g, c.b, 36 * p)
		surface.DrawOutlinedRect(bx, by, bw, bh, 1)

		-- бегущий блик
		local hx = bx + (((now * 0.5 + i * 0.12) % 1.8) - 0.4) * bw

		for k = 0, 5 do
			local rx = math.floor(hx + k * 6)

			if (rx >= bx and rx + 6 <= bx + bw) then
				surface.SetDrawColor(255, 255, 255, 16 * math.sin((k + 0.5) / 6 * math.pi) * p)
				surface.DrawRect(rx, by, 6, bh)
			end
		end

		by = by + bh + 12
	end

	-- поток hex-данных внизу колонки
	if (now >= self.nextHex) then
		self.nextHex = now + 0.11

		table.remove(self.hexLines, 1)
		self.hexLines[#self.hexLines + 1] = HexLine()
	end

	local n = 5
	local lh = math.floor(L.h * 0.017)
	local hy = L.btnY - 24 - n * lh

	if (hy > by + 10) then
		for i = 1, n do
			local line = self.hexLines[#self.hexLines - n + i]
			local f = i / n

			draw.SimpleText(line, "ixLoadMono", x, hy + (i - 1) * lh, Color(c.r, c.g, c.b, (25 + 95 * f * f) * p), LEFT, TOP)
		end
	end
end

-- светящаяся линия проявления и эллипс на уровне сканирования
function SCREEN:DrawWipe(now)
	local mp = self.model
	local e = mp.reveal or 0

	if (e <= 0.001 or e >= 0.999 or !IsValid(mp.Entity)) then
		return
	end

	local L, c = self.L, self.curAccent
	local frac = CFG.wipeFeet - (CFG.wipeFeet - CFG.wipeHead) * e
	local y = math.floor(L.my + L.mh * frac)
	local bw = L.ringR * 2
	local a = 0.4 + 0.6 * (1 - e)

	draw.NoTexture()

	surface.SetMaterial(glowMat)
	surface.SetDrawColor(c.r, c.g, c.b, 150 * a)
	surface.DrawTexturedRect(L.cx - bw * 0.5, y - 22, bw, 44)

	draw.NoTexture()

	SmoothLine(L.cx - bw * 0.5, y, L.cx + bw * 0.5, y, 2, 255, 255, 255, 230 * a)
	SmoothArc(L.cx, y, bw * 0.34, 0, 360, 1.5, 48, c.r, c.g, c.b, 200 * a, 0.18)
end

function SCREEN:DrawHeading(w, h, now)
	local p = (now - self.shownAt - 0.15) / 0.9
	local cx = math.floor(w * 0.5)
	local y = self.L.headY
	local c = self.curAccent
	local text = TypeText(CFG.heading, p)

	surface.SetFont("ixLoadMid")

	local tw = surface.GetTextSize(CFG.heading)
	local lineLen = math.floor(w * 0.1)
	local la = Clamp01(p)

	draw.NoTexture()
	surface.SetDrawColor(c.r, c.g, c.b, 150 * la)
	surface.DrawRect(cx - math.floor(tw * 0.5) - 26 - lineLen, y, lineLen, 2)
	surface.DrawRect(cx + math.floor(tw * 0.5) + 26, y, lineLen, 2)

	surface.SetDrawColor(255, 255, 255, (120 + 110 * (0.5 + 0.5 * math.sin(now * 3.2))) * la)
	surface.DrawRect(cx - math.floor(tw * 0.5) - 20, y - 3, 7, 7)
	surface.DrawRect(cx + math.floor(tw * 0.5) + 13, y - 3, 7, 7)

	draw.SimpleText(text, "ixLoadMid", cx, y, Color(255, 255, 255, 235), C, C)
	draw.SimpleText(TypeText(CFG.subHeading, (p - 0.25) / 0.75), "ixLoadSmall", cx, y + 28, Color(255, 255, 255, 130), C, C)
end

-- надпись в правом верхнем углу (как «СТОРОНА // ...» в cl_charcreate)
function SCREEN:DrawTopRight(w, h, now)
	local c = self.curAccent
	local m = 28
	local used = 0

	for _, slot in ipairs(self.slots) do
		if (slot.character) then
			used = used + 1
		end
	end

	local text = CFG.archiveText .. "  //  " .. used .. " / " .. #self.slots

	surface.SetFont("ixLoadSmall")

	local tw = surface.GetTextSize(text)
	local x = w - m - 12 - tw
	local logo = self.info and self.info.logo

	if (logo) then
		local lh = 34
		local lw = lh * logo:Width() / math.max(logo:Height(), 1)

		DrawLogo(logo, x - 34 - lw * 0.5, m + 18, lh, c, 230)
	end

	draw.NoTexture()
	surface.SetDrawColor(255, 255, 255, 120 + 110 * (0.5 + 0.5 * math.sin(now * 3.2)))
	surface.DrawRect(x - 16, m + 14, 7, 7)
	surface.SetDrawColor(c.r, c.g, c.b, 90)
	surface.DrawRect(x - 16, m + 34, tw + 16, 1)

	draw.SimpleText(text, "ixLoadSmall", x, m + 8, Color(255, 255, 255, 170), LEFT, TOP)
end

function SCREEN:Paint(w, h)
	local L = self.L
	local now = RealTime()
	local dt = math.min(RealFrameTime(), 0.05)

	surface.SetDrawColor(7, 10, 15, 255)
	surface.DrawRect(0, 0, w, h)

	if (!L) then
		return
	end

	local c = self.curAccent
	local sel = self.revealE

	draw.NoTexture()

	-- свечение за моделью
	local gs = h * 1.25

	surface.SetMaterial(glowMat)
	surface.SetDrawColor(c.r, c.g, c.b, 26 + 46 * sel)
	surface.DrawTexturedRect(L.cx - gs * 0.5, h * CFG.modelCenterY - gs * 0.5, gs, gs)
	draw.NoTexture()

	-- тактическая сетка
	local step = math.max(math.floor(h / 12), 48)
	local ga = CFG.gridAlpha * (1 + 0.6 * sel)

	for gx = 0, w, step do
		local major = (gx / step) % 4 == 0

		surface.SetDrawColor(c.r, c.g, c.b, (major and 8 or 3.5) * ga)
		surface.DrawRect(gx, 0, 1, h)
	end

	for gy = 0, h, step do
		local major = (gy / step) % 4 == 0

		surface.SetDrawColor(c.r, c.g, c.b, (major and 8 or 3.5) * ga)
		surface.DrawRect(0, gy, w, 1)
	end

	-- подложки колонок слотов и досье
	surface.SetDrawColor(0, 0, 0, 70)
	surface.DrawRect(L.sx, L.top, L.sw, L.bottom - L.top)
	surface.DrawRect(L.ix, L.top, L.iw, L.bottom - L.top)

	-- плывущие светлые точки
	if (#self.particles > 0) then
		surface.SetMaterial(glowMat)

		for _, p in ipairs(self.particles) do
			p.y = p.y - p.speed * dt * (1 + sel * 1.2)

			if (p.y < -20) then
				p.y = h + 20
			end

			local px = p.fx * w + math.sin(now * 0.4 + p.phase) * 14
			local tw = 0.6 + 0.4 * math.sin(now * 1.1 + p.phase * 3)

			surface.SetDrawColor(c.r, c.g, c.b, p.a * tw * (0.6 + 0.6 * sel))
			surface.DrawTexturedRect(px - p.size * 0.5, p.y - p.size * 0.5, p.size, p.size)
		end

		draw.NoTexture()
	end

	-- искры при выборе персонажа
	if (#self.sparks > 0) then
		surface.SetMaterial(glowMat)

		for i = #self.sparks, 1, -1 do
			local s = self.sparks[i]

			s.life = s.life + dt

			if (s.life >= s.max) then
				table.remove(self.sparks, i)
			else
				s.x = s.x + s.vx * dt
				s.y = s.y + s.vy * dt
				s.vy = s.vy * (1 - dt * 0.8)

				local f = 1 - s.life / s.max

				surface.SetDrawColor(c.r, c.g, c.b, 230 * f)
				surface.DrawTexturedRect(s.x - s.size * 2, s.y - s.size * 2, s.size * 4, s.size * 4)
			end
		end

		draw.NoTexture()
	end

	-- медленный луч, пересекающий центральную колонку
	local bx0 = L.cx - L.cw * 0.5
	local beamX = bx0 + ((now * 0.12) % 1) * L.cw

	for j = 0, 9 do
		surface.SetDrawColor(c.r, c.g, c.b, 12 * (1 - j / 10))
		surface.DrawRect(beamX - j * 4, L.top, 4, L.bottom - L.top)
	end

	surface.SetDrawColor(c.r, c.g, c.b, 40)
	surface.DrawRect(beamX, L.top, 1, L.bottom - L.top)

	-- «пол» и кольца
	self:DrawFloor(now)

	if (!self.modelChar or self.revealE < 0.34) then
		self:DrawCenterIdle(now, self.modelChar and (1 - self.revealE * 3) or 1)
	end

	-- угловые скобки и верхняя линия (как в cl_charcreate)
	local m, l = 28, 42

	draw.NoTexture()
	surface.SetDrawColor(c.r, c.g, c.b, 200)
	surface.DrawRect(m, m, l, 2)
	surface.DrawRect(m, m, 2, l)
	surface.DrawRect(w - m - l, m, l, 2)
	surface.DrawRect(w - m - 2, m, 2, l)
	surface.DrawRect(m, h - m - 2, l, 2)
	surface.DrawRect(m, h - m - l, 2, l)
	surface.DrawRect(w - m - l, h - m - 2, l, 2)
	surface.DrawRect(w - m - 2, h - m - l, 2, l)

	surface.SetDrawColor(c.r, c.g, c.b, 60)
	surface.DrawRect(m + l + 8, m, w - (m + l + 8) * 2, 1)

	-- слоты и сводка
	for i = 1, #self.slots do
		self:DrawSlot(i, now)
	end

	self:DrawSummary(now)
end

function SCREEN:PaintOver(w, h)
	local L = self.L

	if (!L) then
		return
	end

	local now = RealTime()
	local c = self.curAccent
	local sel = self.revealE

	self:DrawWipe(now)

	-- рамки колонок
	local ap = EaseOutCubic(Prog(now - self.shownAt, 0.15, 0.6))
	local breathe = 0.5 + 0.5 * math.sin(now * 1.4)
	local fa = (110 + 20 * breathe + 60 * sel) * ap
	local len = math.floor(18 + 10 * ap)

	draw.NoTexture()
	DrawBrackets(L.sx, L.top, L.sw, L.bottom - L.top, len, c.r, c.g, c.b, fa)
	DrawBrackets(L.cx - math.floor(L.cw * 0.5), L.top, L.cw, L.bottom - L.top, len, c.r, c.g, c.b, fa)
	DrawBrackets(L.ix, L.top, L.iw, L.bottom - L.top, len, c.r, c.g, c.b, fa)

	-- подсказка про вращение модели
	if (self.selChar and sel > 0.95) then
		local hy = L.floorY + math.floor(L.ringR * 0.2 * 1.2) + 26
		local pulse = 0.5 + 0.5 * math.sin(now * 2)
		local a = 90 + 50 * pulse

		surface.SetFont("ixLoadTiny")

		local tw = surface.GetTextSize(CFG.dragHint)

		draw.SimpleText(CFG.dragHint, "ixLoadTiny", L.cx, hy, Color(255, 255, 255, a), C, C)

		local lx, rx = L.cx - tw * 0.5 - 18, L.cx + tw * 0.5 + 18

		SmoothLine(lx, hy - 5, lx - 5, hy, 1.5, 255, 255, 255, a)
		SmoothLine(lx - 5, hy, lx, hy + 5, 1.5, 255, 255, 255, a)
		SmoothLine(rx, hy - 5, rx + 5, hy, 1.5, 255, 255, 255, a)
		SmoothLine(rx + 5, hy, rx, hy + 5, 1.5, 255, 255, 255, a)
	end

	-- досье
	if (self.info) then
		self:DrawInfo(now)
	else
		self:DrawInfoIdle(now)
	end

	self:DrawHeading(w, h, now)
	self:DrawTopRight(w, h, now)

	-- вход в игру: вспышка, ударные кольца и уход в тёмный фон
	if (self.entering) then
		local t = now - self.entering
		local flash = (1 - Clamp01(t / 0.5)) ^ 2

		draw.NoTexture()

		if (flash > 0) then
			surface.SetDrawColor(255, 255, 255, 90 * flash)
			surface.DrawRect(0, 0, w, h)
		end

		for r = 0, 1 do
			local p = (t - r * 0.15) / 1.1

			if (p > 0 and p < 1) then
				SmoothArc(L.cx, h * 0.5, h * 0.12 + EaseOutExpo(p) * h * 0.75, 0, 360, 2 + (1 - p) * 5, 140, c.r, c.g, c.b, 220 * (1 - p) ^ 2)
			end
		end

		local fo = Clamp01((t - CFG.enterDelay * 0.45) / 0.4)

		if (fo > 0) then
			surface.SetDrawColor(7, 10, 15, 255 * fo)
			surface.DrawRect(0, 0, w, h)
		end
	end

	-- плавное появление из чёрного при открытии
	local fb = 1 - Clamp01((now - self.shownAt) / 0.45)

	if (fb > 0) then
		draw.NoTexture()
		surface.SetDrawColor(0, 0, 0, 255 * fb ^ 1.5)
		surface.DrawRect(0, 0, w, h)
	end
end

-- окно подтверждения удаления (рисуется панелью confirmPanel под кнопками «да/нет»)
function SCREEN:PaintConfirm(w, h)
	local L = self.L
	local now = RealTime()
	local p = Prog(now - self.confirmAt, 0, 0.3)
	local e = EaseOutCubic(p)
	local red = CFG.dangerColor
	local x, y, cw, ch = L.confX, L.confY, L.cardWc, L.cardHc
	local pulse = 0.5 + 0.5 * math.sin(now * 4)

	draw.NoTexture()

	surface.SetDrawColor(0, 0, 0, 200 * e)
	surface.DrawRect(0, 0, w, h)

	-- карточка раскрывается от центра по вертикали
	local rh = math.floor(ch * e)
	local ry = y + math.floor((ch - rh) * 0.5)

	surface.SetDrawColor(9, 12, 18, 245 * e)
	surface.DrawRect(x, ry, cw, rh)
	surface.SetDrawColor(red.r, red.g, red.b, (18 + 10 * pulse) * e)
	surface.DrawRect(x, ry, cw, rh)

	if (p < 0.55) then
		return
	end

	local k = Clamp01((p - 0.55) / 0.45)

	-- бегущие предупреждающие полосы сверху
	local bar = 10
	local sx, sy = self:LocalToScreen(x, y)

	render.SetScissorRect(sx, sy, sx + cw, sy + bar, true)
		surface.SetDrawColor(red.r, red.g, red.b, 200 * k)

		local off = (now * 30) % 24

		for gx = -bar - 24, cw, 24 do
			SetQuad(x + gx + off, y + bar, x + gx + off + 12, y + bar, x + gx + off + 12 + bar, y, x + gx + off + bar, y)
		end
	render.SetScissorRect(0, 0, 0, 0, false)

	draw.NoTexture()
	surface.SetDrawColor(red.r, red.g, red.b, 200 * k)
	surface.DrawOutlinedRect(x, y, cw, ch, 1)
	DrawBrackets(x - 5, y - 5, cw + 10, ch + 10, 22, red.r, red.g, red.b, 230 * k)

	local cx = x + math.floor(cw * 0.5)
	local ty = y + bar + 22

	draw.SimpleText(CFG.confirmTitle, "ixLoadBig", cx + 2, ty + 2, Color(0, 0, 0, 160 * k), C, TOP)
	draw.SimpleText(CFG.confirmTitle, "ixLoadBig", cx, ty, Color(red.r, red.g, red.b, 255 * k), C, TOP)

	surface.SetFont("ixLoadBig")

	local _, th = surface.GetTextSize("A")

	ty = ty + th + 8

	if (self.info) then
		draw.SimpleText(Ellipsize(self.info.name, "ixLoadMid", cw - 64), "ixLoadMid", cx, ty, Color(255, 255, 255, 240 * k), C, TOP)
	end

	ty = ty + L.hMid + 12

	for i, line in ipairs(self.confirmLines or {}) do
		draw.SimpleText(line, "ixLoadText", cx, ty + (i - 1) * math.floor(L.hText * 1.25), Color(255, 255, 255, 170 * k), C, TOP)
	end
end

vgui.Register("ixCharLoadScreen", SCREEN, "EditablePanel")

--[[
	ПАНЕЛЬ ЗАГРУЗКИ ПЕРСОНАЖА (ixCharMenuLoad)
	Оболочка вокруг экрана выше: связывает его с меню cl_character, сетью Helix и списком персонажей.
]]
DEFINE_BASECLASS("ixCharMenuPanel")
local PANEL = {}

AccessorFunc(PANEL, "animationTime", "AnimationTime", FORCE_NUMBER)

function PANEL:Init()
	local parent = self:GetParent()

	self.animationTime = 1

	-- служебная подпанель (нужна базовому классу); весь интерфейс лежит поверх неё и растянут на весь экран
	self.panel = self:AddSubpanel("main")
	self.panel:SetTitle(nil)
	self.panel:SetMouseInputEnabled(false)

	self.screen = self:Add("ixCharLoadScreen")
	self.screen:SetPos(0, 0)
	self.screen:SetSize(parent:GetWide(), parent:GetTall())
	self.screen:InvalidateLayout(true)

	self.screen.OnSelect = function(this, character)
		self.character = character
	end

	self.screen.OnBack = function()
		self:SlideDown()
		parent.mainPanel:Undim()
	end

	-- свободный открытый слот ведёт на создание персонажа
	self.screen.OnCreate = function()
		if (#ix.characters >= self:GetUnlockedSlots()) then
			parent:ShowNotice(3, L("maxCharacters"))

			return
		end

		self:SlideDown()

		parent.newCharacterPanel:SetActiveSubpanel("faction", 0)
		parent.newCharacterPanel:SlideUp()
	end

	self.screen.OnEnter = function(this, character)
		self.character = character

		self:SlideDown(self.animationTime, function()
			net.Start("ixCharacterChoose")
				net.WriteUInt(character:GetID(), 32)
			net.SendToServer()
		end, true)
	end

	self.screen.OnDelete = function(this, character)
		local id = character:GetID()

		parent:ShowNotice(1, L("deleteComplete", character:GetName()))
		self:Populate(id)

		net.Start("ixCharacterDelete")
			net.WriteUInt(id, 32)
		net.SendToServer()
	end

	self:SetActiveSubpanel("main", 0)
	self.screen:MoveToFront()
end

-- сколько слотов открыто: хук слота, иначе CFG.unlockedSlots
function PANEL:GetUnlockedSlots()
	local count = hook.Run(CFG.slotHook, LocalPlayer())

	if (!isnumber(count)) then
		count = CFG.unlockedSlots
	end

	return math.max(math.floor(count), 0)
end

function PANEL:OnCharacterDeleted(character)
	if (self.bActive and #ix.characters == 0) then
		self:SlideDown()
	end
end

-- ignoreID — персонаж, который только что удалили (с сервера список ещё не обновился)
function PANEL:Populate(ignoreID)
	local list = {}

	for i = 1, #ix.characters do
		local character = ix.char.loaded[ix.characters[i]]

		if (character and character:GetID() != ignoreID) then
			list[#list + 1] = character
		end
	end

	local total = math.max(CFG.slots, #list)
	local unlocked = self:GetUnlockedSlots()
	local slots = {}

	for i = 1, total do
		local character = list[i]

		slots[i] = {character = character, locked = (!character and i > unlocked)}
	end

	self.screen:SetSlots(slots)
	self.character = self.screen:GetSelectedCharacter()
end

function PANEL:OnSlideUp()
	local menu = self:GetParent()

	self.bActive = true

	-- HUD из cl_character на время работы меню прячется (см. HookMenuDraw в cl_charcreate)
	if (IsValid(menu)) then
		menu.ixHideHud = CFG.hideMenuHud
	end

	self.screen:Reset()
	self:Populate()
	self.screen:MoveToFront()
end

function PANEL:OnSlideDown()
	local menu = self:GetParent()

	self.bActive = false

	if (IsValid(menu)) then
		menu.ixHideHud = false
	end
end

function PANEL:Paint(width, height)
	surface.SetDrawColor(7, 10, 15, 255)
	surface.DrawRect(0, 0, width, height)

	BaseClass.Paint(self, width, height)
end

vgui.Register("ixCharMenuLoad", PANEL, "ixCharMenuPanel")