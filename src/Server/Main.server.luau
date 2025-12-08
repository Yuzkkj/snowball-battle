local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = require(ReplicatedStorage.Framework)

Framework:Start():andThen(function()
	print("Server load completed")
end)
