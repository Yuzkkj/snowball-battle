local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local packets = require(ReplicatedStorage.Modules.Game.Packets)

local player = Players.LocalPlayer

local module = {}

function module.Start()
    packets.Ragdoll.OnClientEvent:Connect(function(state)
		local character = player.Character
		local humanoid: Humanoid = character:WaitForChild("Humanoid")

		if state then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
			humanoid.AutoRotate = false
			humanoid.PlatformStand = true
		else
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			humanoid.PlatformStand = false
			humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			humanoid.AutoRotate = true
		end
	end)
	
	packets.Impulse.OnClientEvent:Connect(function(direction, force)
		local character = player.Character
		if not character then
			return
		end

		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

		local LinearVelocity = Instance.new("LinearVelocity")
		LinearVelocity.Name = "ImpulseVelocity"
		LinearVelocity.MaxForce = math.huge
		LinearVelocity.Attachment0 = humanoidRootPart.RootAttachment
		LinearVelocity.VectorVelocity = direction * force
		LinearVelocity.Parent = humanoidRootPart

		Debris:AddItem(LinearVelocity, 0.1)
	end)
end

return module