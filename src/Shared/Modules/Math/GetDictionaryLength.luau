-- Returns the length of the given dictionary
local function getDictionaryLength(dict: { [any]: any }): number
	local counter = 0

	for _, _ in pairs(dict) do
		counter += 1
	end

	return counter
end

return getDictionaryLength
