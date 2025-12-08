local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Replica = require(ReplicatedStorage.Packages.Replica)
local module = {}

module.Token = Replica.Token("PlayerData")

module.Template = {
    Snowflakes = 0,
    Eliminations = 0,
    Wins = 0,

}

return module
