local MAX_TRIES = 7
local WAIT_TIME = 10

-- Attempts to run a function multiple times until it succeeds.
local function try(func, ...): (boolean, any?)
	local sucess, result
	for _ = 1, MAX_TRIES do
		local r = { pcall(func, ...) }

		sucess = r[1]

		if sucess then
			table.remove(r, 1)
			result = r
			break
		end

		task.wait(WAIT_TIME)
	end

	return sucess, table.unpack(result or {})
end

return try
