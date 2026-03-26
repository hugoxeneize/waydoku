-- ╔═══════════════════════════════╗
-- ║      waydoku - init.lua       ║
-- ╚═══════════════════════════════╝
-- Press F8 to toggle. move with your minecraft keys, 1-9 place, 0 erase, r new game.

-- ─── CONFIG ───────────────────────────────────────────────────────────────────
local cfg = {
	x = 50,
	y = 50,
	size = 3,
	start_key = "F8",
	difficulty = "medium", -- "easy", "medium", "hard"

	-- path to your minecraft options.txt
	-- set to nil to use default wasd + 1-9
	options_txt = nil,
}

local waywall = require("waywall")
local h = require("waydoku.helpers")
local M = {}

local COL = {
	given = "#e0e0f0",
	user = "#00ffc8",
	error = "#ff3c6e",
	cursor = "#ffe74c",
	grid = "#555577",
	title = "#00ffc8",
	status = "#888899",
	dead = "#ff3c6e",
}

local CLUES = { easy = 38, medium = 30, hard = 23 }

local sudoku_on = false
local puzzle = nil
local solution = nil
local user_grid = nil
local given = nil
local cursor_r = 1
local cursor_c = 1
local mistakes = 0
local game_over = false

local cell_handles = {}
local sep_handles = {}
local title_handle = nil
local status_handle = nil

-- ─── OPTIONS.TXT READER ───────────────────────────────────────────────────────
-- default keys (used if options_txt is nil or file can't be read)
local KEYS = {
	up = "w",
	down = "s",
	left = "a",
	right = "d",
	hotbar = { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
	reset = "r",
	reset_options = { "r", "n", "p", "m" },
}

local function read_options_txt(path)
	local file = io.open(path, "r")
	if not file then
		print("[waydoku] could not open options.txt at: " .. path .. " — using default wasd")
		return
	end

	local function parse_key(val)
		local key = val:match("key%.keyboard%.(.+)")
		if not key then
			return nil
		end
		-- handle some special cases
		local special = {
			["left.shift"] = "Shift",
			["right.shift"] = "Shift",
			["left.control"] = "Control",
			["right.control"] = "Control",
			["space"] = "space",
			["left"] = "Left",
			["right"] = "Right",
			["up"] = "Up",
			["down"] = "Down",
		}
		return (special[key] or key):lower()
	end

	for line in file:lines() do
		local mc_action, mc_key = line:match("^key_key%.([^:]+):(.+)$")
		if mc_action and mc_key then
			local parsed = parse_key(mc_key)
			if parsed then
				if mc_action == "forward" then
					KEYS.up = parsed
				elseif mc_action == "back" then
					KEYS.down = parsed
				elseif mc_action == "left" then
					KEYS.left = parsed
				elseif mc_action == "right" then
					KEYS.right = parsed
				else
					local slot = mc_action:match("^hotbar%.(%d)$")
					if slot then
						KEYS.hotbar[tonumber(slot)] = parsed
					end
				end
			end
		end
	end
	file:close()
	print("[waydoku] loaded keys from options.txt")
	print("[waydoku] move: " .. KEYS.up .. "/" .. KEYS.left .. "/" .. KEYS.down .. "/" .. KEYS.right)
	print("[waydoku] hotbar: " .. table.concat(KEYS.hotbar, " "))
end

-- ─── GRID LAYOUT ──────────────────────────────────────────────────────────────
local function cell_xy(r, c)
	local cw = cfg.size * 12
	local ch = cfg.size * 14
	local bx = cfg.size * 6
	local by = cfg.size * 4
	local x = cfg.x + (c - 1) * cw + math.floor((c - 1) / 3) * bx
	local y = cfg.y + (r - 1) * ch + math.floor((r - 1) / 3) * by
	return x, y
end

-- ─── RENDERING ────────────────────────────────────────────────────────────────

local function close_all()
	for r = 1, 9 do
		if cell_handles[r] then
			for c = 1, 9 do
				if cell_handles[r][c] then
					cell_handles[r][c]:close()
					cell_handles[r][c] = nil
				end
			end
		end
	end
	for _, handle in ipairs(sep_handles) do
		if handle then
			handle:close()
		end
	end
	sep_handles = {}
	if title_handle then
		title_handle:close()
		title_handle = nil
	end
	if status_handle then
		status_handle:close()
		status_handle = nil
	end
end

local function render_separators()
	for _, col in ipairs({ 3, 6 }) do
		local x1, _ = cell_xy(1, col)
		local x2, _ = cell_xy(1, col + 1)
		local sx = x1 + math.floor((x2 - x1) / 2)
		for row = 1, 9 do
			local _, sy = cell_xy(row, 1)
			table.insert(
				sep_handles,
				waywall.text("|", {
					x = sx,
					y = sy,
					size = cfg.size,
					color = "#888899",
				})
			)
		end
	end
	for _, row in ipairs({ 3, 6 }) do
		local _, y1 = cell_xy(row, 1)
		local _, y2 = cell_xy(row + 1, 1)
		local sy = y1 + math.floor((y2 - y1) / 2)
		local sep = "- - + - -+ - -"
		table.insert(
			sep_handles,
			waywall.text(sep, {
				x = cfg.x,
				y = sy,
				size = cfg.size,
				color = "#888899",
			})
		)
	end
end

local function render_cells()
	for r = 1, 9 do
		cell_handles[r] = cell_handles[r] or {}
		for c = 1, 9 do
			if cell_handles[r][c] then
				cell_handles[r][c]:close()
				cell_handles[r][c] = nil
			end
			local val = user_grid[r][c]
			local is_cur = (r == cursor_r and c == cursor_c)
			local txt = (is_cur and val == 0) and ">" or (val == 0 and "." or tostring(val))

			local color
			if game_over then
				color = given[r][c] and COL.given or COL.dead
			elseif is_cur then
				color = COL.cursor
			elseif given[r][c] then
				color = COL.given
			elseif val ~= 0 and val ~= solution[r][c] then
				color = COL.error
			elseif val ~= 0 then
				color = COL.user
			else
				color = COL.grid
			end

			local x, y = cell_xy(r, c)
			cell_handles[r][c] = waywall.text(txt, { x = x, y = y, size = cfg.size, color = color })
		end
	end
end

local function render_title()
	if title_handle then
		title_handle:close()
		title_handle = nil
	end
	local mistake_str = "  mistakes: " .. mistakes .. "/3"
	title_handle = waywall.text(
		"WAYDOKU [" .. cfg.difficulty:upper() .. "]" .. mistake_str,
		{ x = cfg.x, y = cfg.y - cfg.size * 18, size = cfg.size, color = COL.title }
	)
end

local function render_status(msg)
	if status_handle then
		status_handle:close()
		status_handle = nil
	end
	local _, last_y = cell_xy(9, 1)
	status_handle = waywall.text(msg, {
		x = cfg.x,
		y = last_y + cfg.size * 20,
		size = math.max(1, cfg.size - 1),
		color = COL.status,
	})
end

local function full_render()
	close_all()
	render_title()
	render_separators()
	render_cells()
	local move_hint = KEYS.up .. KEYS.left .. KEYS.down .. KEYS.right
	render_status(move_hint .. ":move  hotbar:place  0:erase  r:new  " .. cfg.start_key .. ":quit")
end

-- ─── GAME LOGIC ───────────────────────────────────────────────────────────────

local function check_win()
	for r = 1, 9 do
		for c = 1, 9 do
			if user_grid[r][c] ~= solution[r][c] then
				return false
			end
		end
	end
	return true
end

local function new_game()
	cursor_r, cursor_c = 1, 1
	mistakes = 0
	game_over = false
	puzzle, solution = h.generate_puzzle(CLUES[cfg.difficulty] or 30)
	user_grid = h.deep_copy(puzzle)
	given = {}
	for r = 1, 9 do
		given[r] = {}
		for c = 1, 9 do
			given[r][c] = puzzle[r][c] ~= 0
		end
	end
	full_render()
end

local function update(key)
	if game_over then
		if key == "r" then
			new_game()
		end
		return
	end

	if key == KEYS.left then
		cursor_c = math.max(1, cursor_c - 1)
	elseif key == KEYS.right then
		cursor_c = math.min(9, cursor_c + 1)
	elseif key == KEYS.up then
		cursor_r = math.max(1, cursor_r - 1)
	elseif key == KEYS.down then
		cursor_r = math.min(9, cursor_r + 1)
	elseif key == "0" or key == "backspace" then
		if not given[cursor_r][cursor_c] then
			user_grid[cursor_r][cursor_c] = 0
		end
	elseif key == KEYS.reset then
		new_game()
		return
	else
		-- check if key matches a hotbar slot
		local num = nil
		for i, hk in ipairs(KEYS.hotbar) do
			if key == hk then
				num = i
				break
			end
		end
		if num and num >= 1 and num <= 9 then
			if not given[cursor_r][cursor_c] then
				local prev = user_grid[cursor_r][cursor_c]
				user_grid[cursor_r][cursor_c] = num
				if num ~= solution[cursor_r][cursor_c] then
					if prev == 0 or prev == solution[cursor_r][cursor_c] then
						mistakes = mistakes + 1
						render_title()
					end
					if mistakes >= 3 then
						game_over = true
						render_cells()
						render_status("GAME OVER! press r to try again")
						render_title()
						return
					end
				end
				if check_win() then
					render_cells()
					render_status("YOU WIN!! press r for a new game :)")
					render_title()
					return
				end
			end
		end
	end
	render_cells()
end

-- ─── KEY CAPTURE ──────────────────────────────────────────────────────────────

local function build_capture_list()
	local keys = {
		KEYS.up,
		KEYS.down,
		KEYS.left,
		KEYS.right,
		"0",
		"r",
		"Return",
		"Backspace",
	}
	for _, hk in ipairs(KEYS.hotbar) do
		table.insert(keys, hk)
	end
	return keys
end

local function normalize(key)
	return key:gsub("^%*%-", ""):lower()
end

local function setup_keys(config)
	local keys_to_capture = build_capture_list()
	local saved = {}

	for key, func in pairs(config.actions) do
		local norm = normalize(key)
		local is_capture = false
		for _, k in ipairs(keys_to_capture) do
			if norm == k:lower() then
				is_capture = true
				break
			end
		end
		if is_capture then
			config.actions[key] = function()
				if sudoku_on then
					return update(norm)
				else
					return func()
				end
			end
			saved[norm] = true
		else
			config.actions[key] = function()
				if sudoku_on then
					return false
				else
					return func()
				end
			end
		end
	end
	for _, k in ipairs(keys_to_capture) do
		local norm = k:lower()
		if not saved[norm] then
			config.actions["*-" .. k] = function()
				if sudoku_on then
					return update(norm)
				end
				return false
			end
		end
	end
end

local function toggle()
	if not sudoku_on then
		sudoku_on = true
		if not puzzle then
			new_game()
		else
			full_render()
		end
	else
		sudoku_on = false
		close_all()
	end
end

M.setup = function(config)
	math.randomseed(os.time())
	for i = 1, 3 do
		math.random()
	end

	if cfg.options_txt then
		read_options_txt(cfg.options_txt)
	end

	for _, possible_key in ipairs(KEYS.reset_options) do
		local is_conflict = false
		for _, hk in ipairs(KEYS.hotbar) do
			if possible_key == hk:lower() then
				is_conflict = true
				break
			end
		end

		if not is_conflict then
			KEYS.reset = possible_key
			print("[waydoku] reset key set to: " .. KEYS.reset)
			break
		end
	end

	sudoku_on = false
	setup_keys(config)
	config.actions[cfg.start_key] = function()
		toggle()
	end
end

return M
