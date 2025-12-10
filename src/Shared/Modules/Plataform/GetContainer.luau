local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomTypes = require(ReplicatedStorage.Modules.Core.CustomTypes)

local function getContainer<T>(tbl: T, path: CustomTypes.Path): any
	local current: any = tbl

	for _, key in ipairs(path) do
		if type(current) ~= "table" then
			error(`Cannot index "{key}" because the parent is not a table.`)
		end

		current = current[key]

		if current == nil then
			error(`No index "{key}" in path "{table.concat(path, "/")}"`)
		end
	end

	return current
end

return getContainer
