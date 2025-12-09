local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Replica = require(ReplicatedStorage.Packages.Replica)

local module = {}

module.Template = {
	Snowflakes = 0,
	Wins = 0,
	Eliminations = 0,
}

module.Token = Replica.Token("PlayerStore")

return module
