local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

local Replica = require(ReplicatedStorage.Packages.Replica)
local Signal = require(ReplicatedStorage.Packages.Signal)

local CustomTypes = require(ReplicatedStorage.Modules.Core.CustomTypes)
local getContainer = require(ReplicatedStorage.Modules.Plataform.GetContainer)

local utils = require(script.Utils)

local DATA_STORE_KEY = (RunService:IsStudio() and "PlayerStore_Test") or "PlayerStore"

local playerStore = ProfileStore.New(DATA_STORE_KEY, utils.Template)

local PlayerDataService = {}

-- create the cached tables
function PlayerDataService.Init(self: PlayerDataService): ()
	self._profiles = {}
	self._replicas = {}
	self._valueChangedSignals = {}
	self._valueInsertedSignals = {}
	self._valueRemovedSignals = {}
end

-- handles player events
function PlayerDataService.Start(self: PlayerDataService): ()
	local function onPlayerAdded(player: Player)
		self._valueChangedSignals[player] = {}
		self._valueInsertedSignals[player] = {}
		self._valueRemovedSignals[player] = {}

		local playerProfile = playerStore:StartSessionAsync(tostring(player.UserId), {
			Cancel = function()
				return player.Parent ~= Players
			end,
		})

		if not playerProfile then
			player:Kick("Profile load failed. Please rejoin")
		end

		playerProfile:AddUserId(player.UserId)
		playerProfile:Reconcile()

		playerProfile.OnSessionEnd:Connect(function()
			self:_RemoveData(player)
		end)

		if player.Parent ~= Players then
			playerProfile:EndSession()
		end

		self._profiles[player] = playerProfile

		local playerReplica = Replica.New({
			Token = utils.Token,
			Data = playerProfile.Data,
			Tags = { Player = player },
		})

		playerReplica:Replicate()

		self._replicas[player] = playerReplica

		player:SetAttribute("DataLoaded", true)
	end

	for _, player in pairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)

	if not RunService:IsStudio() then
		game:BindToClose(function()
			for _, player in pairs(Players:GetPlayers()) do
				player:Kick()
			end
		end)
	end
end

function PlayerDataService._RemoveData(self: PlayerDataService, player: Player): ()
	self._profiles[player] = nil

	local playerReplica = self._replicas[player]
	if playerReplica then
		playerReplica:Destroy()
		self._replicas[player] = nil
	end

	self._valueChangedSignals[player] = nil
	self._valueInsertedSignals[player] = nil
	self._valueRemovedSignals[player] = nil

	player:Kick("Profile session ended. Please rejoin")
end

function PlayerDataService.WipeData(self: PlayerDataService, player: Player): ()
	local playerProfile = self._profiles[player]
	playerProfile.Data = utils.Template

	self:_RemoveData(player)
end

function PlayerDataService.GetProfile(self: PlayerDataService, player: Player): typeof(playerStore:StartSessionAsync())
	local playerProfile = self._profiles[player]
	if not playerProfile then
		error(`No profile found for player @{player.Name}`)
	end

	return playerProfile
end

function PlayerDataService.Get(self: PlayerDataService, player: Player, path: CustomTypes.Path): any
	return getContainer(self:GetProfile(player).Data, path)
end

function PlayerDataService.Set(self: PlayerDataService, player: Player, path: CustomTypes.Path, value: any): ()
	local concatedPath = table.concat(path, "/")

	local oldValue = self:Get(player, path)
	if not oldValue then
		error(`No value found in path "{concatedPath}"`)
	end

	local playerProfile = self:GetProfile(player)

	local length = #path
	local last = path[length]

	local container = getContainer(playerProfile.Data, path)
	if not container[last] then
		error(`No index "{last}" in path "{concatedPath}"`)
	end

	local playerReplica = self._replicas[player]

	container[last] = value
	playerReplica:Set(path, value)

	local valueChangedSignal = self._valueChangedSignals[player][concatedPath]
	if valueChangedSignal then
		valueChangedSignal:Fire(value, oldValue)
	end
end

function PlayerDataService.GetValueChangedSignal(
	self: PlayerDataService,
	player: Player,
	path: CustomTypes.Path
): Signal.Signal<any, any>
	local concatedPath = table.concat(path, "/")

	local valueChangedSignal = self._valueChangedSignals[player][concatedPath]
	if valueChangedSignal then
		return valueChangedSignal
	else
		valueChangedSignal = Signal.new()

		self._valueChangedSignals[player][concatedPath] = valueChangedSignal

		return valueChangedSignal
	end
end

function PlayerDataService.Insert(
	self: PlayerDataService,
	player: Player,
	path: CustomTypes.Path,
	value: any,
	index: string | number?
): ()
	local playerProfile = self:GetProfile(player)

	local container = getContainer(playerProfile.Data, path)

	local playerReplica = self._replicas[player]

	if index then
		container[index] = value
	else
		table.insert(container, value)
	end

	playerReplica:TableInsert(path, value, index or nil)

	local concatedPath = table.concat(path, "/")
	local valueInsertedSignal = self._valueInsertedSignals[player][concatedPath]
	if valueInsertedSignal then
		valueInsertedSignal:Fire(value, index or nil)
	end
end

function PlayerDataService.GetValueInsertedSignal(
	self: PlayerDataService,
	player: Player,
	path: CustomTypes.Path
): Signal.Signal<any, any?>
	local concatedPath = table.concat(path, "/")
	local valueInsertedSignal = self._valueInsertedSignals[player][concatedPath]
	if valueInsertedSignal then
		return valueInsertedSignal
	else
		valueInsertedSignal = Signal.new()

		self._valueInsertedSignals[player][concatedPath] = valueInsertedSignal

		return valueInsertedSignal
	end
end

function PlayerDataService.Remove(self: PlayerDataService, player: Player, path: CustomTypes.Path, index: string): ()
	local playerProfile = self:GetProfile(player)

	local container = getContainer(playerProfile.Data, path)

	local concatedPath = table.concat(path, "/")

	local valueRemoved = container[index]
	if not valueRemoved then
		error(`No index "{index}" at path "{concatedPath}"`)
	end

	local playerReplica = self._replicas[player]

	container[index] = nil
	playerReplica:TableRemove(path, index)

	local valueRemovedSignal = self._valueRemovedSignals[player][concatedPath]
	if valueRemovedSignal then
		valueRemovedSignal:Fire(valueRemoved, index)
	end
end

function PlayerDataService.GetValueRemovedSignal(
	self: PlayerDataService,
	player: Player,
	path: CustomTypes.Path
): Signal.Signal<any, any>
	local concatedPath = table.concat(path, "/")
	local valueRemovedSignal = self._valueRemovedSignals[player][concatedPath]
	if valueRemovedSignal then
		return valueRemovedSignal
	else
		valueRemovedSignal = Signal.new()

		self._valueRemovedSignals[player][concatedPath] = valueRemovedSignal

		return valueRemovedSignal
	end
end

function PlayerDataService.Increment(
	self: PlayerDataService,
	player: Player,
	path: CustomTypes.Path,
	increment: number
): ()
	local oldValue = self:Get(player, path)
	local newValue = oldValue + increment

	self:Set(player, path, newValue)
end

type PlayerDataService = typeof(PlayerDataService) & {
	_profiles: { [Player]: typeof(playerStore:StartSessionAsync()) },
	_replicas: { [Player]: typeof(Replica.New()) },
	_valueChangedSignals: { [Player]: { [string]: Signal.Signal<any, any> } },
	_valueInsertedSignals: { [Player]: { [string]: Signal.Signal<any, any?> } },
	_valueRemovedSignals: { [Player]: { [string]: Signal.Signal<any, any> } },
}

return PlayerDataService
