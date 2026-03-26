local M = {}

-- ─── SUDOKU ENGINE ────────────────────────────────────────────────────────────

function M.is_valid(grid, row, col, num)
	-- check row
	for c = 1, 9 do
		if grid[row][c] == num then
			return false
		end
	end
	-- check column
	for r = 1, 9 do
		if grid[r][col] == num then
			return false
		end
	end
	-- check 3x3 box
	local box_row = math.floor((row - 1) / 3) * 3
	local box_col = math.floor((col - 1) / 3) * 3
	for r = box_row + 1, box_row + 3 do
		for c = box_col + 1, box_col + 3 do
			if grid[r][c] == num then
				return false
			end
		end
	end
	return true
end

function M.solve(grid)
	for row = 1, 9 do
		for col = 1, 9 do
			if grid[row][col] == 0 then
				for num = 1, 9 do
					if M.is_valid(grid, row, col, num) then
						grid[row][col] = num
						if M.solve(grid) then
							return true
						end
						grid[row][col] = 0
					end
				end
				return false
			end
		end
	end
	return true
end

function M.count_solutions(grid, limit)
	local count = 0
	local function bt()
		if count >= limit then
			return
		end
		for row = 1, 9 do
			for col = 1, 9 do
				if grid[row][col] == 0 then
					for num = 1, 9 do
						if M.is_valid(grid, row, col, num) then
							grid[row][col] = num
							bt()
							grid[row][col] = 0
						end
					end
					return
				end
			end
		end
		count = count + 1
	end
	bt()
	return count
end

function M.shuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

function M.deep_copy(grid)
	local copy = {}
	for r = 1, 9 do
		copy[r] = {}
		for c = 1, 9 do
			copy[r][c] = grid[r][c]
		end
	end
	return copy
end

function M.generate_puzzle(clues)
	-- fill diagonal 3x3 boxes first
	local solution = {}
	for r = 1, 9 do
		solution[r] = {}
		for c = 1, 9 do
			solution[r][c] = 0
		end
	end

	for b = 0, 2 do
		local nums = M.shuffle({ 1, 2, 3, 4, 5, 6, 7, 8, 9 })
		local i = 1
		for r = b * 3 + 1, b * 3 + 3 do
			for c = b * 3 + 1, b * 3 + 3 do
				solution[r][c] = nums[i]
				i = i + 1
			end
		end
	end
	M.solve(solution)

	-- remove numbers while keeping unique solution
	local puzzle = M.deep_copy(solution)
	local positions = {}
	for i = 1, 81 do
		positions[i] = i
	end
	M.shuffle(positions)

	local removed = 0
	for _, pos in ipairs(positions) do
		if removed >= 81 - clues then
			break
		end
		local r = math.floor((pos - 1) / 9) + 1
		local c = ((pos - 1) % 9) + 1
		local backup = puzzle[r][c]
		puzzle[r][c] = 0
		local copy = M.deep_copy(puzzle)
		if M.count_solutions(copy, 2) == 1 then
			removed = removed + 1
		else
			puzzle[r][c] = backup
		end
	end

	return puzzle, solution
end

return M
