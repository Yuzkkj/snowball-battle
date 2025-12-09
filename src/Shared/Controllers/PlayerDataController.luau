local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Replica = require(ReplicatedStorage.Packages.Replica)
local Signal = require(ReplicatedStorage.Packages.Signal)

local CustomTypes = require(ReplicatedStorage.Modules.Core.CustomTypes)
local getContainer = require(ReplicatedStorage.Modules.Plataform.GetContainer)

local localPlayer = Players.LocalPlayer

local PlayerDataController = {}

function PlayerDataController.Init(self: PlayerDataController): ()
	self._replicas = {}
	self._valueChangedSignals = {}
	self._valueInsertedSignals = {}
	self._valueRemovedSignals = {}
	self._valueChangedSignalAdded = Signal.new()

	Replica.OnNew("PlayerStore", function(replica)
		local player = replica.Tags.Player
		self._replicas[player] = replica

		if player ~= localPlayer then
			return
		end

		for concatedPath, valueChangedSignal in pairs(self._valueChangedSignals) do
			local path = string.split(concatedPath, "/")
			replica:OnSet(path, function(newValue, oldValue)
				valueChangedSignal:Fire(newValue, oldValue)
			end)
		end

		self._valueChangedSignalAdded:Connect(function(path, valueChangedSignal)
			replica:OnSet(path, function(newValue, oldValue)
				valueChangedSignal:Fire(newValue, oldValue)
			end)
		end)

		replica:OnChange(function(action, path, value, index)
			for concatedPath, valueInsertedSignal in pairs(self._valueInsertedSignals) do
				if table.concat(path, "/") ~= concatedPath then
					continue
				end

				if action == "TableInsert" then
					valueInsertedSignal:Fire(value, index or nil)
				end
			end

			for concatedPath, valueInsertedSignal in pairs(self._valueRemovedSignals) do
				if table.concat(path, "/") ~= concatedPath then
					continue
				end

				if action == "TableRemove" then
					valueInsertedSignal:Fire(value, index)
				end
			end
		end)
	end)
end

function PlayerDataController.Start(self: PlayerDataController): ()
	Players.PlayerRemoving:Connect(function(player)
		local playerReplica = self._replicas[player]
		if playerReplica then
			self._replicas[player] = nil
		end
	end)

	Replica.RequestData()
end

function PlayerDataController.WaitForReplica(self: PlayerDataController, timeOut: number?, player: Player?): typeof(Replica.New())
	local replica = nil
	local elapsed = 0
	local infinityYield = false

	timeOut = timeOut or 10

	repeat
		replica = self._replicas[player or localPlayer]
		if replica then
			break
		end

		elapsed += task.wait(1)
		if elapsed >= timeOut and not infinityYield and not replica then
			warn("Infinity yield possible on WaitForReplica for player: ", player)
			infinityYield = true
		end
	until replica

	return replica
end

function PlayerDataController.Get(self: PlayerDataController, path: CustomTypes.Path, player: Player?): any
	local replica = self:WaitForReplica(10, player)

	local length = #path
	local last = path[length]
	local value

	local container = getContainer(replica.Data, path)
	value = container[last]

	if not value then
		error(`No index "{last}" in path "{table.concat(path, "/")}"`)
	end

	return value
end

function PlayerDataController.GetValueChangedSignal(
	self: PlayerDataController,
	path: CustomTypes.Path
): Signal.Signal<any, any>
	local concatedPath = table.concat(path, "/")
	local valueChangedSignal = self._valueChangedSignals[concatedPath]
	if valueChangedSignal then
		return valueChangedSignal
	else
		valueChangedSignal = Signal.new()

		self._valueChangedSignals[concatedPath] = valueChangedSignal
		self._valueChangedSignalAdded:Fire(path, valueChangedSignal)

		return valueChangedSignal
	end
end

function PlayerDataController.GetValueInsertedSignal(
	self: PlayerDataController,
	path: CustomTypes.Path
): Signal.Signal<any, any?>
	local concatedPath = table.concat(path, "/")
	local valueInsertedSignal = self._valueInsertedSignals[concatedPath]
	if valueInsertedSignal then
		return valueInsertedSignal
	else
		valueInsertedSignal = Signal.new()

		self._valueInsertedSignals[concatedPath] = valueInsertedSignal

		return valueInsertedSignal
	end
end

function PlayerDataController.GetValueRemovedSignal(
	self: PlayerDataController,
	path: CustomTypes.Path
): Signal.Signal<any, any>
	local concatedPath = table.concat(path, "/")
	local valueRemovedSignal = self._valueRemovedSignals[concatedPath]
	if valueRemovedSignal then
		return valueRemovedSignal
	else
		valueRemovedSignal = Signal.new()

		self._valueRemovedSignals[concatedPath] = valueRemovedSignal

		return valueRemovedSignal
	end
end

type PlayerDataController = typeof(PlayerDataController) & {
	_replicas: { [Player]: typeof(Replica.New()) },
	_valueChangedSignals: { [string]: Signal.Signal<any, any> },
	_valueInsertedSignals: { [string]: Signal.Signal<any, any?> },
	_valueRemovedSignals: { [string]: Signal.Signal<any, any> },
	_valueChangedSignalAdded: Signal.Signal<CustomTypes.Path, Signal.Signal<any, any>>,
}

return PlayerDataController :: PlayerDataController
