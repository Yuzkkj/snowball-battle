local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local try = require(ReplicatedStorage.Modules.Plataform.Try)

-- Player Name Chat Colors
local nameColors = {
	Color3.new(253 / 255, 41 / 255, 67 / 255), -- BrickColor.new("Bright red").Color,
	Color3.new(1 / 255, 162 / 255, 255 / 255), -- BrickColor.new("Bright blue").Color,
	Color3.new(2 / 255, 184 / 255, 87 / 255), -- BrickColor.new("Earth green").Color,
	BrickColor.new("Bright violet").Color,
	BrickColor.new("Bright orange").Color,
	BrickColor.new("Bright yellow").Color,
	BrickColor.new("Light reddish violet").Color,
	BrickColor.new("Brick yellow").Color,
}

local module = {}

function module.getDisplayNameAsync(userId: number): string
	local success, result = try(function()
		return UserService:GetUserInfosByUserIdsAsync({ userId })
	end)

	if not success then
		warn(`[C]: Failed to get display name for id: {userId}`)
		return "Unknown"
	end

	result = table.remove(result, 1)

	local displayName = result.DisplayName

	if result.HasVerifiedBadge then
		displayName ..= ""
	end

	return displayName
end

function module.getUsernameColor(Username: string): Color3
	local Value = 0
	local NumName = #Username
	for index = 1, NumName do
		local CValue = string.byte(string.sub(Username, index, index))
		local ReverseIndex = NumName - index + 1
		if NumName % 2 == 1 then
			ReverseIndex = ReverseIndex - 1
		end
		if ReverseIndex % 4 >= 2 then
			CValue = -CValue
		end
		Value = Value + CValue
	end
	return nameColors[(Value % #nameColors) + 1]
end

return module
