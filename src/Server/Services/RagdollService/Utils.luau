export type CharacterRagdollData = {
	StartTime: number,
	Joints: { Attachment | BallSocketConstraint },
	UnragdollThread: thread?
}

local module = {}

module.RagdollData = {
	Head = {
		CFrame = {CFrame.new(0, 1, 0, 0, -1, 0, 1, 0, -0, 0, 0, 1), CFrame.new(0, -0.5, 0, 0, -1, 0, 1, 0, -0, 0, 0, 1)}
	},
	HumanoidRootPart = {
		CFrame = {CFrame.new(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), CFrame.new(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)}
	},
	["Right Arm"] = {
		CFrame = {CFrame.new(1.3, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), CFrame.new(-0.2, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)}
	},
	["Left Arm"] = {
		CFrame = {CFrame.new(-1.3, 0.75, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1), CFrame.new(0.2, 0.75, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1)}
	},
	["Right Leg"] = {
		CFrame = {CFrame.new(0.5, -1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1), CFrame.new(0, 1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1)}
	},
	["Left Leg"] = {
		CFrame = {CFrame.new(-0.5, -1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1), CFrame.new(0, 1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1)}
	}
}

module.setupHumanoid = function(humanoid: Humanoid): ()
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
end

module.buildCollisionParts = function(character: Model): ()
	for _, v in next, character:GetChildren() do
		if v:IsA("BasePart") then
			if v.Name == "HumanoidRootPart" then
				continue
			end

			local clonedPart = v:Clone()
			clonedPart.CanCollide = false
			clonedPart.Massless = true
			clonedPart.Size = Vector3.one
			clonedPart.Name = "Collide"
			clonedPart.Transparency = 1
			clonedPart:ClearAllChildren()
			clonedPart.Parent = v

			local weld = Instance.new("Weld")
			weld.Part0 = v
			weld.Part1 = clonedPart
            weld.Parent = clonedPart
		end
	end
end

module.toggleMotor6D = function(character: Model, state: boolean): ()
	for _, v in next, character:GetDescendants() do
		if v.Name == "Handle" or v.Name == "RootJoint" or v.Name == "Neck" then
			continue
		end

		if v:IsA("Motor6D") then
			v.Enabled = state
		end

		if v:IsA("BasePart") then
			v.CollisionGroup = if state then "Character" else "Ragdoll"
		end
	end
end

module.buildJoints = function(character: Model, characterRagdollData: CharacterRagdollData): ()
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		error("[S]: HumanoidRootPart not found.")
	end

	characterRagdollData.Joints = {}

	for _, v in next, character:GetChildren() do
		if not v:IsA("BasePart") or v:FindFirstAncestorOfClass("Accessory") or v.Name == "Handle" or v == humanoidRootPart then
			continue
		end

		if not module.RagdollData[v.Name] then
			continue
		end

		local a0 = Instance.new("Attachment")
		local a1 = Instance.new("Attachment")
		local joint = Instance.new("BallSocketConstraint")

		table.insert(characterRagdollData.Joints, a0)
		table.insert(characterRagdollData.Joints, a1)
		table.insert(characterRagdollData.Joints, joint)

		a0.Name = "RAGDOLL_ATTACHMENT"
		a0.Parent = v
		a0.CFrame = module.RagdollData[v.Name].CFrame[2]

		a1.Name = "RAGDOLL_ATTACHMENT"
		a1.Parent = humanoidRootPart
		a1.CFrame = module.RagdollData[v.Name].CFrame[1]

		joint.Name = "RAGDOLL_CONSTRAINT"
		joint.Parent = v
		joint.Attachment0 = a0
		joint.Attachment1 = a1

		v.Massless = true
	end
end

module.destroyJoints = function(character: Model, characterRagdollData: CharacterRagdollData): ()
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: Part
	if humanoidRootPart then
		humanoidRootPart.Massless = false
	end

	for _, joint in next, characterRagdollData.Joints do
		joint:Destroy()
	end

	for _, v in next, character:GetChildren() do
		if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
			v.Massless = false
		end
	end
end

module.toggleCollisionParts = function(character: Model, state: boolean): ()
	for _, v in next, character:GetChildren() do
		if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
			local collisionPart = v:FindFirstChild("Collide") :: Part
			if collisionPart then
				v.CanCollide = not state
				collisionPart.CanCollide = state
			end
		end
	end
end

return module
