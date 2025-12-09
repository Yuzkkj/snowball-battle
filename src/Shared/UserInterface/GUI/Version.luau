local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local gameInfo = MarketplaceService:GetProductInfoAsync(game.PlaceId)

local player = Players.LocalPlayer
local versionText = player.PlayerGui:WaitForChild("MainGui"):WaitForChild("Version")

local module = {}

function module.Start()
	versionText.Text = `{gameInfo.Name} • v{game.PlaceVersion}`

	task.spawn(function()
		while true do
			local newVersion = MarketplaceService:GetProductInfoAsync(game.PlaceId).Updated
			if newVersion ~= gameInfo.Updated then
				versionText.TextColor3 = Color3.fromRGB(255, 0, 0)
			end
			task.wait(5)
		end
	end)
end

return module
