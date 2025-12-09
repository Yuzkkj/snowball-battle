local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomTypes = require(ReplicatedStorage.Modules.Core.CustomTypes)

local function getContainer<T>(tbl: T, path: CustomTypes.Path): T | { any }
	local container = tbl
	for _, arg in pairs(path) do
		if not container[arg] then
			error(`No index "{arg}" in: `, container)
		end

		if type(container[arg]) ~= "table" then
			break
		end

		container = container[arg]
	end

	return container
end

return getContainer
