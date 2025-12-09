local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataController = require(ReplicatedStorage.Controllers.PlayerDataController)

local formatCurrency = require(ReplicatedStorage.Modules.Math.FormatCurrency)

local player = Players.LocalPlayer
local snowflakes = player.PlayerGui:WaitForChild("MainGui"):WaitForChild("Snowflakes"):WaitForChild("Amount")

local module = {}

function module.Start()
	snowflakes.Text = formatCurrency(PlayerDataController:Get({ "Snowflakes" }))

	PlayerDataController:GetValueChangedSignal({ "Snowflakes" }):Connect(function(newValue)
		snowflakes.Text = formatCurrency(newValue)
	end)
end

return module
