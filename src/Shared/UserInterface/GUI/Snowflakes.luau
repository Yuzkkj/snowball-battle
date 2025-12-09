local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataController = require(ReplicatedStorage.Controllers.PlayerDataController)

local player = Players.LocalPlayer
local snowflakes = player.PlayerGui:WaitForChild("MainGui"):WaitForChild("Snowflakes"):WaitForChild("Amount")

local module = {}

function module.Start()
    snowflakes.Text = PlayerDataController:Get({"Snowflakes"})
end

return module