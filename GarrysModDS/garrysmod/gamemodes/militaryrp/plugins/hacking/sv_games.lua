-- Мини-игры взлома. Головоломку ГЕНЕРИРУЕТ и ПРОВЕРЯЕТ сервер; клиент только показывает её
-- и присылает ответ, поэтому «я выиграл» подделать нельзя.
--
-- Интерфейс игры:
--   Generate(level)  -> public, secret
--       public  - то, что уходит клиенту (обязательно содержит time - лимит времени в секундах);
--       secret  - то, что остаётся на сервере для проверки.
--   Handle(secret, action, data, elapsed) -> status, reply
--       status: "win" | "fail" | "continue"; reply - таблица, которую увидит клиент (необязательно).

ix.hack = ix.hack or {}

local HACK = ix.hack
local games = {}

HACK.games = games

local function pick(list)
	return list[math.random(#list)]
end

local function shuffle(list)
	for i = #list, 2, -1 do
		local j = math.random(i)

		list[i], list[j] = list[j], list[i]
	end

	return list
end

local function isInt(n, min, max)
	return type(n) == "number" and n % 1 == 0 and n >= min and n <= max
end

-- Игры: подбор пароля в дампе памяти, шифр-диск, настройка сигнала, маршрут через сеть, взлом замка.
-- Каждая получает уровень 1..4 (чем выше, тем сложнее). Handle возвращает "win", "fail" или
-- "continue" (с ответом клиенту вторым значением - для игр с несколькими попытками).

local WORDS = {
	[5] = {"PROXY", "TOKEN", "CRYPT", "RELAY", "VAULT", "FLASH", "PATCH", "BLOCK", "SHELL", "ADMIN", "CACHE", "LOGIN",
		"PORTS", "QUERY", "STACK", "MACRO", "ROUTE", "DRIVE", "AUDIO", "FIBER", "CABLE", "NODES", "INPUT", "PIXEL", "TRACE"},
	[6] = {"KERNEL", "ROUTER", "BUFFER", "SOCKET", "DAEMON", "BACKUP", "ACCESS", "SYSTEM", "SERVER", "SIGNAL", "BEACON",
		"TUNNEL", "SCRIPT", "MODULE", "BRIDGE", "CIPHER", "BINARY", "DOMAIN", "FILTER", "PACKET", "SECTOR", "CLIENT",
		"STREAM", "MATRIX"},
	[7] = {"NETWORK", "GATEWAY", "PAYLOAD", "COMPILE", "PROCESS", "MONITOR", "CONSOLE", "DECRYPT", "ENCRYPT"}
}

-- -------------------------------------------------------------------------------------
-- 1. Подбор пароля: в «дампе памяти» спрятаны слова-кандидаты, одно из них - пароль.
--    Выбираете слово - узел сообщает, сколько букв стоит на своих местах.
-- -------------------------------------------------------------------------------------

local function Likeness(a, b)
	local n = 0

	for i = 1, #a do
		if (string.sub(a, i, i) == string.sub(b, i, i)) then n = n + 1 end
	end

	return n
end

games.crack = {
	name = "ПОДБОР ПАРОЛЯ",

	Generate = function(level)
		local len = ({5, 5, 6, 6})[level]
		local count = ({6, 8, 9, 11})[level]
		local attempts = ({5, 5, 4, 4})[level]
		local pool = {}

		for _, w in ipairs(WORDS[len]) do pool[#pool + 1] = w end

		shuffle(pool)

		local password = pool[1]
		local rest = {}

		for i = 2, #pool do
			rest[#rest + 1] = {word = pool[i], like = Likeness(pool[i], password)}
		end

		-- Пара слов, похожих на пароль, чтобы подсказки имели смысл; остальные - случайные.
		table.sort(rest, function(x, y) return x.like > y.like end)

		local words = {password}
		local near = math.min(2, count - 1)

		for i = 1, near do words[#words + 1] = rest[i].word end

		local others = {}

		for i = near + 1, #rest do others[#others + 1] = rest[i].word end

		shuffle(others)

		for i = 1, count - 1 - near do words[#words + 1] = others[i] end

		shuffle(words)

		local set = {}

		for _, w in ipairs(words) do set[w] = true end

		return
			{words = words, len = len, attempts = attempts, seed = math.random(1, 1000000), time = 120},
			{password = password, set = set, attempts = attempts, used = 0, tried = {}}
	end,

	Handle = function(secret, action, data)
		if (action ~= "submit" or type(data.word) ~= "string" or not secret.set[data.word]) then
			return "fail"
		end

		local word = data.word

		if (secret.tried[word]) then return "continue" end

		secret.tried[word] = true
		secret.used = secret.used + 1

		local reply = {word = word, like = Likeness(word, secret.password), used = secret.used}

		if (word == secret.password) then return "win", reply end

		if (secret.used >= secret.attempts) then return "fail", reply end

		return "continue", reply
	end
}

-- -------------------------------------------------------------------------------------
-- 2. Дешифровка: сообщение зашифровано сдвигом по алфавиту. Известна одна пара «шифр -> буква»;
--    по ней выставляется шифр-диск, дальше сообщение читается и вводится.
-- -------------------------------------------------------------------------------------

games.cipher = {
	name = "ДЕШИФРОВКА",

	Generate = function(level)
		local len = ({5, 5, 6, 7})[level]
		local word = pick(WORDS[len])
		local shift = math.random(3, 23)
		local letters = {}

		for i = 1, #word do
			letters[i] = string.char((string.byte(word, i) - 65 + shift) % 26 + 65)
		end

		local hintPlain, hintCipher

		if (level <= 2) then
			-- Подсказка - первая буква самого сообщения.
			hintPlain = string.sub(word, 1, 1)
		else
			-- Подсказка - случайная буква алфавита: диск придётся выставлять «вслепую».
			hintPlain = string.char(math.random(0, 25) + 65)
		end

		hintCipher = string.char((string.byte(hintPlain) - 65 + shift) % 26 + 65)

		return
			{cipher = table.concat(letters), len = len, hintCipher = hintCipher, hintPlain = hintPlain, tries = 3, time = 120},
			{word = word, tries = 3, used = 0}
	end,

	Handle = function(secret, action, data, elapsed)
		if (action ~= "submit" or type(data.guess) ~= "string") then
			return "fail"
		end

		if (elapsed < #secret.word * 0.3) then return "fail" end

		if (data.guess == secret.word) then return "win" end

		secret.used = secret.used + 1

		if (secret.used >= secret.tries) then return "fail" end

		return "continue", {wrong = true, left = secret.tries - secret.used}
	end
}

-- -------------------------------------------------------------------------------------
-- 3. Настройка сигнала: подогнать частоту, амплитуду (и фазу) под эталонную волну
--    на осциллографе и удержать совпадение.
-- -------------------------------------------------------------------------------------

local function PhaseDiff(a, b)
	local d = math.abs(a - b) % (math.pi * 2)

	return math.min(d, math.pi * 2 - d)
end

local function IsNum(v)
	return type(v) == "number" and v == v and v > -1e6 and v < 1e6
end

games.tune = {
	name = "НАСТРОЙКА СИГНАЛА",

	Generate = function(level)
		local useP = level >= 3
		local p = {
			f = math.random(6, 22) * 0.25,
			a = math.random(4, 10) * 0.1,
			p = useP and (math.random(0, 15) * math.pi / 8) or 0,
			useP = useP,
			tolF = ({0.14, 0.11, 0.1, 0.08})[level],
			tolA = ({0.12, 0.1, 0.09, 0.07})[level],
			tolP = ({0.45, 0.4, 0.35, 0.28})[level],
			fmin = 1, fmax = 6, hold = 1.0,
			time = 120
		}

		return p, {f = p.f, a = p.a, p = p.p, useP = useP, tolF = p.tolF, tolA = p.tolA, tolP = p.tolP}
	end,

	Handle = function(secret, action, data, elapsed)
		if (action ~= "submit" or not IsNum(data.f) or not IsNum(data.a) or not IsNum(data.p)) then
			return "fail"
		end

		if (elapsed < 2) then return "fail" end

		-- На допуск сервера небольшой запас: клиент уже проверил точное попадание.
		if (math.abs(data.f - secret.f) > secret.tolF * 1.25) then return "fail" end

		if (math.abs(data.a - secret.a) > secret.tolA * 1.25) then return "fail" end

		if (secret.useP and PhaseDiff(data.p, secret.p) > secret.tolP * 1.25) then return "fail" end

		return "win"
	end
}

-- -------------------------------------------------------------------------------------
-- 4. Маршрут: провести пакет от входа до цели по сети, обходя «ледяные» узлы защиты
--    и заходя в ключевые узлы. Маршрут, гарантирующий решение, строит сервер.
-- -------------------------------------------------------------------------------------

local DIRS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}

-- Случайный самонепересекающийся путь от s до g длиной minLen..maxLen (перебор с возвратами).
local function GenPath(rows, cols, s, g, minLen, maxLen)
	local budget = 4000
	local visited, path = {}, {}

	local function key(r, c) return (r - 1) * cols + c end

	local function dfs(r, c)
		budget = budget - 1

		if (budget <= 0) then return false end

		path[#path + 1] = {r, c}
		visited[key(r, c)] = true

		if (r == g[1] and c == g[2]) then
			if (#path >= minLen) then return true end
		elseif (#path < maxLen) then
			local order = {1, 2, 3, 4}

			shuffle(order)

			for _, di in ipairs(order) do
				local nr, nc = r + DIRS[di][1], c + DIRS[di][2]

				if (nr >= 1 and nr <= rows and nc >= 1 and nc <= cols and not visited[key(nr, nc)]) then
					if (dfs(nr, nc)) then return true end
				end
			end
		end

		path[#path] = nil
		visited[key(r, c)] = nil

		return false
	end

	if (dfs(s[1], s[2])) then return path end
end

games.route = {
	name = "МАРШРУТ",

	Generate = function(level)
		local rows = ({4, 5, 5, 6})[level]
		local cols = ({6, 7, 8, 9})[level]
		local density = ({0.35, 0.4, 0.45, 0.5})[level]
		local nChecks = ({0, 1, 2, 3})[level]
		local start = {math.random(1, rows), 1}
		local goal = {math.random(1, rows), cols}
		local path

		for _ = 1, 40 do
			path = GenPath(rows, cols, start, goal, cols + rows - 1, cols * rows - 2)

			if (path) then break end
		end

		if (not path) then
			-- Запасной вариант: прямая дорожка вдоль строк.
			path = {}

			local r = start[1]

			for c = 1, cols do path[#path + 1] = {r, c} end

			while (r ~= goal[1]) do
				r = r + (goal[1] > r and 1 or -1)
				path[#path + 1] = {r, cols}
			end

			nChecks = 0
		end

		local onPath = {}

		for _, cell in ipairs(path) do onPath[(cell[1] - 1) * cols + cell[2]] = true end

		local checks = {}
		local idxs = {}

		for i = 2, #path - 1 do idxs[#idxs + 1] = i end

		shuffle(idxs)

		for i = 1, math.min(nChecks, #idxs) do
			checks[#checks + 1] = {path[idxs[i]][1], path[idxs[i]][2]}
		end

		local walls = {}

		for r = 1, rows do
			walls[r] = {}

			for c = 1, cols do
				walls[r][c] = (not onPath[(r - 1) * cols + c] and math.random() < density) and 1 or 0
			end
		end

		local pub = {rows = rows, cols = cols, start = start, goal = goal, walls = walls, checks = checks, time = 120}

		return pub, {rows = rows, cols = cols, start = start, goal = goal, walls = walls, checks = checks}
	end,

	Handle = function(secret, action, data, elapsed)
		local path = data.path

		if (action ~= "submit" or type(path) ~= "table") then return "fail" end

		local rows, cols = secret.rows, secret.cols
		local n = #path

		if (n < 2 or n > rows * cols) then return "fail" end

		if (elapsed < n * 0.08) then return "fail" end

		local isCheck = {}

		for _, ck in ipairs(secret.checks) do isCheck[(ck[1] - 1) * cols + ck[2]] = true end

		local seen, got, prev = {}, 0, nil

		for i = 1, n do
			local cell = path[i]

			if (type(cell) ~= "table" or not isInt(cell[1], 1, rows) or not isInt(cell[2], 1, cols)) then
				return "fail"
			end

			local r, c = cell[1], cell[2]
			local key = (r - 1) * cols + c

			if (secret.walls[r][c] == 1 or seen[key]) then return "fail" end

			if (i == 1) then
				if (r ~= secret.start[1] or c ~= secret.start[2]) then return "fail" end
			elseif (math.abs(r - prev[1]) + math.abs(c - prev[2]) ~= 1) then
				return "fail"
			end

			seen[key] = true

			if (isCheck[key]) then got = got + 1 end

			prev = {r, c}
		end

		if (prev[1] ~= secret.goal[1] or prev[2] ~= secret.goal[2]) then return "fail" end

		return got == #secret.checks and "win" or "fail"
	end
}

-- -------------------------------------------------------------------------------------
-- 5. Взлом замка: стрелка бежит по кругу, нужно нажать, когда она в светящемся секторе.
--    Каждый успешный «штифт» ускоряет стрелку. Положение стрелки считается от времени,
--    поэтому сервер может проверить моменты нажатий.
-- -------------------------------------------------------------------------------------

games.lock = {
	name = "ВЗЛОМ ЗАМКА",

	Generate = function(level)
		local count = ({2, 3, 3, 4})[level]
		local base = ({100, 115, 130, 145})[level]
		local width = ({70, 60, 54, 48})[level]
		local misses = ({4, 3, 3, 3})[level]
		local rounds = {}

		for i = 1, count do
			local dir = (math.random() < 0.5) and 1 or -1
			local phase = math.random(0, 359)
			local ahead = math.random(100, 250)

			rounds[i] = {
				phase = phase,
				speed = math.floor(base * (1 + 0.08 * (i - 1))),
				dir = dir,
				center = (phase + dir * ahead) % 360,
				width = width
			}
		end

		return {rounds = rounds, misses = misses, time = 90}, {rounds = rounds}
	end,

	Handle = function(secret, action, data, elapsed)
		if (action ~= "submit") then return "fail" end

		if (data.fail) then return "fail" end

		local hits = data.hits

		if (type(hits) ~= "table" or #hits ~= #secret.rounds) then return "fail" end

		local total = 0

		for i, rd in ipairs(secret.rounds) do
			local t = hits[i]

			if (not IsNum(t) or t < 0.25 or t > 80) then return "fail" end

			total = total + t

			local ang = (rd.phase + rd.dir * rd.speed * t) % 360
			local diff = math.abs(((ang - rd.center + 540) % 360) - 180)

			-- Небольшой запас сверх размера сектора на разброс округления и задержки.
			if (diff > rd.width / 2 + 5) then return "fail" end
		end

		-- Нельзя «прокрутить» больше времени, чем реально прошло.
		if (total > elapsed + 1.5) then return "fail" end

		return "win"
	end
}

-- Порядок, в котором игры раздаются по этапам (без повторов, пока хватает).
HACK.gameIDs = {"crack", "cipher", "tune", "route", "lock"}

function HACK.PlanStages(diff)
	local levels = HACK.plans[diff] or HACK.plans[1]
	local bag, plan = {}, {}

	for i, level in ipairs(levels) do
		if (#bag == 0) then
			for _, id in ipairs(HACK.gameIDs) do bag[#bag + 1] = id end

			shuffle(bag)
		end

		plan[i] = {game = table.remove(bag), level = level}
	end

	return plan
end
