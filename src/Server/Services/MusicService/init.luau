local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

local packets = require(ReplicatedStorage.Modules.Game.Packets)
local utils = require(script.Utils)

local MusicService = {}

function MusicService.Init(self: MusicService): ()
    self.MusicEnded = Signal.new()
    
    self.LobbyMusic = {
		Id = 1837101327,
		Duration = 203.5
	}
	self.StandoffMusic = {
		Id = 1836738307,
		Duration = 105.378
	}

    self:SetMusic(self.LobbyMusic)
end

function MusicService.Start(self: MusicService): ()
    self.MusicEnded:Connect(function()
        self:SetMusic(self.LobbyMusic)
    end)

    packets.GetCurrentMusic.OnServerInvoke = function()
        return self._currentMusic.Id, self._startTime
    end
end

function MusicService.SetMusic(self: MusicService, musicData: utils.MusicData)
    self._currentMusic = musicData
    self._startTime = tick()

    packets.UpdateMusic:Fire(musicData.Id)

    task.delay(musicData.Duration, self.MusicEnded.Fire, self.MusicEnded)
end

function MusicService.PlaySound(_: MusicService, soundId: number, player: Player?, pitch: boolean?): ()
	if player then
		packets.PlaySound:FireClient(player, soundId, pitch or false)
	else
		packets.PlaySound:Fire(soundId, pitch or false)
	end
end

function MusicService.PlaySoundAt(
	_: MusicService,
	soundId: number,
	instance: BasePart | Attachment,
	player: Player?,
	volume: number?
): ()
	if player then
		packets.PlaySoundAt:FireClient(player, soundId, instance, volume or 0.5)
	else
		packets.PlaySoundAt:Fire(soundId, instance, volume or 0.5)
	end
end

type MusicService = typeof(MusicService) & {
    LobbyMusic: utils.MusicData,
    StandoffMusic: utils.MusicData,
	MusicEnded: Signal.Signal<>,
	_currentMusic: utils.MusicData,
	_startTime: number,
}

return MusicService :: MusicService
