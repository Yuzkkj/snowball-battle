local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Replica = require(ReplicatedStorage.Packages.Replica)

local module = {}

module.Template = {
	Snowflakes = 0,
	Wins = 0,
	Eliminations = 0,
	Settings = {
		SoundVolume = 0.5,
		MusicVolume = 0.5,
	},
	Gamepasses = {},
}

module.Token = Replica.Token("PlayerStore")

return module
