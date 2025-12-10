local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local packets = require(ReplicatedStorage.Modules.Game.Packets)
local utils = require(script.Utils)

local RagdollService = {}

function RagdollService.Init(self: RagdollService): ()
	self._characterRagdollDatas = {}
	self._getUpTicks = {}
end

function RagdollService.Start(self: RagdollService): ()
	local function SetupCharacter(character: Model): ()
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
		if humanoid then
			utils.setupHumanoid(humanoid)
			utils.buildCollisionParts(character)

			humanoid.Died:Connect(function()
				local characterRagdollData = self:GetRagdollData(character)
				if characterRagdollData then
					if characterRagdollData.UnragdollThread then
						task.cancel(characterRagdollData.UnragdollThread)
					end

				else
					self:Ragdoll(character)
				end
			end)
		end

		character.Destroying:Connect(function()
			if self._characterRagdollDatas[character] then
				self._characterRagdollDatas[character] = nil
			end
		end)
	end

	-- Handle existing Players
	for _, player in pairs(Players:GetPlayers()) do
		if player.Character then
			CollectionService:AddTag(player.Character, "Ragdoll")
		end
	end

	-- Handle existing tagged characters
	for _, character in next, CollectionService:GetTagged("Ragdoll") do
		SetupCharacter(character)
	end

	-- Handle new Players
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			CollectionService:AddTag(character, "Ragdoll")
		end)

		-- Handle if player already has character
		if player.Character then
			CollectionService:AddTag(player.Character, "Ragdoll")
		end
	end)

	-- Handle new tagged characters
	CollectionService:GetInstanceAddedSignal("Ragdoll"):Connect(function(character: Model)
		SetupCharacter(character)
	end)
end

function RagdollService.Impulse(self: RagdollService, character: Model, direction: Vector3, force: number): ()
	local ragdollDuration = 0.0375 * force -- Considerando tempo base de 1.5s para 40 de força
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return
	end

	local lastGetUpTick = self._getUpTicks[character] or 0
	local currentTick = tick()

	if currentTick - lastGetUpTick <= 0.5 then
		return
	end

	if not self:GetRagdollData(character) then
		self:Ragdoll(character, ragdollDuration)
	end

	local player = Players:GetPlayerFromCharacter(character)
	if player then
		packets.Impulse:FireClient(player, direction, force)
	else
		local LinearVelocity = Instance.new("LinearVelocity")
		LinearVelocity.Name = "ImpulseVelocity"
		LinearVelocity.MaxForce = math.huge
		LinearVelocity.Attachment0 = humanoidRootPart:FindFirstChild("RootAttachment") :: Attachment
		LinearVelocity.VectorVelocity = direction * force
		LinearVelocity.Parent = humanoidRootPart

		Debris:AddItem(LinearVelocity, 0.1)
	end
end

function RagdollService.Ragdoll(self: RagdollService, character: Model, duration: number?): boolean
	if self:GetRagdollData(character) then
		return false
	end

	local player = Players:GetPlayerFromCharacter(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: Part

	if not humanoidRootPart or not humanoid then
		return false
	end

	local characterRagdollData = {
		StartTime = tick()
	} :: utils.CharacterRagdollData

	utils.toggleMotor6D(character, false)
	utils.buildJoints(character, characterRagdollData)
	utils.toggleCollisionParts(character, true)

	if player then
		packets.Ragdoll:FireClient(player, true)
	else
		humanoidRootPart:SetNetworkOwner(nil)
		humanoid.AutoRotate = false
		humanoid.PlatformStand = true
	end

	if duration then
		characterRagdollData.UnragdollThread = task.delay(duration, function()
			self:Unragdoll(character)
		end)
	end

	self._characterRagdollDatas[character] = characterRagdollData

	return true
end

function RagdollService.Unragdoll(self: RagdollService, character: Model): boolean
	local characterRagdollData = self:GetRagdollData(character)
	if not characterRagdollData then
		return false
	end

	local player = Players:GetPlayerFromCharacter(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: Part

	if not humanoidRootPart or not humanoid then
		self._characterRagdollDatas[character] = nil

		return false
	end

	if player then
		humanoidRootPart:SetNetworkOwner(player)
		packets.Ragdoll:FireClient(player, false)
	else
		humanoidRootPart:SetNetworkOwner(nil)
		if humanoid:GetState() == Enum.HumanoidStateType.Dead then
			return false
		end

		humanoid.PlatformStand = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		humanoid.AutoRotate = true
	end

	utils.destroyJoints(character, characterRagdollData)
	utils.toggleMotor6D(character, true)
	utils.toggleCollisionParts(character, false)

	self._characterRagdollDatas[character] = nil

	self._getUpTicks[character] = tick()

	return true
end

function RagdollService.GetRagdollData(self: RagdollService, character: Model): utils.CharacterRagdollData?
	return self._characterRagdollDatas[character]
end

type RagdollService = typeof(RagdollService) & {
	_characterRagdollDatas: { [Model]: utils.CharacterRagdollData },
	_getUpTicks: { [Model]: number }
}

return RagdollService :: RagdollService
