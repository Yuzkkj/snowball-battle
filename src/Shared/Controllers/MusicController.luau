local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataController = require(script.Parent.PlayerDataController)
local packets = require(ReplicatedStorage.Modules.Game.Packets)

local MusicController = {}

function MusicController.Init(self: MusicController): ()
	self._soundsFolder = Instance.new("Folder")
	self._soundsFolder.Name = "Sounds"
	self._soundsFolder.Parent = workspace

	self._music = Instance.new("Sound")
	self._music.Name = "BackgroundMusic"
	self._music.Parent = workspace
end

function MusicController.Start(self: MusicController): ()
	self._music.Volume = PlayerDataController:Get({ "Settings", "MusicVolume" })
	PlayerDataController:GetValueChangedSignal({ "Settings", "MusicVolume" }):Connect(function(newValue)
		self._music.Volume = newValue
	end)

	local musicId, startTime = packets.GetCurrentMusic:Fire()

	self._music.TimePosition = tick() - startTime

	self:PlayMusic(musicId)

	packets.UpdateMusic.OnClientEvent:Connect(function(musicId)
		self:PlayMusic(musicId)
	end)

	packets.PlaySound.OnClientEvent:Connect(function(soundId, pitch)
		self:PlaySound(soundId, pitch)
	end)

	packets.PlaySoundAt.OnClientEvent:Connect(function(soundId, at, volume)
		self:PlaySoundAt(soundId, at, volume)
	end)
end

function MusicController.PlayMusic(self: MusicController, musicId: number): ()
	if self._music.Playing then
		self._music:Stop()
		self._music.SoundId = "rbxassetid://" .. musicId
		self._music:Play()
	else
		self._music.SoundId = "rbxassetid://" .. musicId
		self._music:Play()
	end
end

function MusicController.PlaySound(self: MusicController, soundId: number, pitch: boolean?): ()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. soundId
	sound.Volume = PlayerDataController:Get({ "Settings", "SoundVolume" })
	sound.Parent = self._soundsFolder

	if pitch then
		local pitchEffect = Instance.new("PitchShiftSoundEffect")
		pitchEffect.Octave = math.random(90, 110) / 100
		pitchEffect.Parent = sound
	end

	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

function MusicController.PlaySoundAt(
	_: MusicController,
	soundId: number,
	instance: BasePart | Attachment,
	volume: number?
): ()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. soundId
	sound.Volume = volume or 0.5
	sound.Parent = instance

	sound:Play()
	sound.Ended:Connect(function()
		Debris:AddItem(sound)
	end)
end

type MusicController = typeof(MusicController) & {
	_music: Sound,
	_soundsFolder: Folder,
}

return MusicController :: MusicController
