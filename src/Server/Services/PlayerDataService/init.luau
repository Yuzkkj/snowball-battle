local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerDataService = {}

-- Requires (Adjust paths as needed for your game structure)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local Replica = require(ReplicatedStorage.Packages.Replica)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Signal = require(ReplicatedStorage.Packages.Signal)
local utils = require(script.Utils) -- Assuming utils contains your data Template and Token

local DATA_STORE_KEY = (RunService:IsStudio() and "PlayerStore_Test") or "PlayerStore"
local playerStore = ProfileStore.New(DATA_STORE_KEY, utils.Template)

-- === Type Definitions ===

type Profile = typeof(playerStore:StartSessionAsync())
type ProfileData = typeof(playerStore:StartSessionAsync().Data)
type Replica = typeof(Replica.New())
type Promise = typeof(Promise.new())

-- Recursive types for the signal caches
-- These allow keys to map to either a Signal or another table of the same type.
type ValueChangedSignalContainer = { [any]: Signal.Signal<any, any> | ValueChangedSignalContainer }
type ValueInsertedSignalContainer = { [any]: Signal.Signal<any, any?> | ValueInsertedSignalContainer }
type ValueRemovedSignalContainer = { [any]: Signal.Signal<any, any> | ValueRemovedSignalContainer }

type PlayerDataService = typeof(PlayerDataService) & {
    _profiles: { [Player]: Profile },
    _replicas: { [Player]: Replica },
    _valueChangedSignals: { [Player]: ValueChangedSignalContainer },
    _valueInsertedSignals: { [Player]: ValueInsertedSignalContainer },
    _valueRemovedSignals: { [Player]: ValueRemovedSignalContainer }
}

-- === Internal Utility Functions ===

-- Utility to navigate a table using an array of keys (the path).
-- Returns the parent table containing the target, and the target key.
-- `createMissing`: If true, creates intermediate tables if they are missing.
local function _navigatePath(
    baseTable: { [any]: any }, 
    path: { any }, 
    createMissing: boolean?
): ({ [any]: any }?, any?)
    
    local currentTable = baseTable
    local lastKey = nil
    
    if #path == 0 then return nil, nil end

    -- Iterate up to the second-to-last element of the path
    for i = 1, #path - 1 do
        local key = path[i]
        
        if typeof(currentTable[key]) == "table" then
            currentTable = currentTable[key]
        elseif createMissing then
            -- Create a new table if it's missing (Write/Create Mode)
            currentTable[key] = {}
            currentTable = currentTable[key]
        else
            -- Path segment is missing or not a table (Read Mode)
            return nil, nil
        end
    end
    
    -- The table that contains the target value/signal
    local parentTable = currentTable
    -- The last key to access the target value/signal
    lastKey = path[#path]

    return parentTable, lastKey
end

-- Utility to navigate/create the nested tables ONLY within the signal cache.
-- It ensures that any value encountered on the path that is not a table
-- (and is not the final signal) is replaced by a new table.
local function _getSignalContainer(
    signalCache: { [any]: any }, -- Looser type for internal flexibility
    path: { any }
): ({ [any]: any }?, any?)

    local currentTable = signalCache
    local lastKey = nil
    
    if #path == 0 then return nil, nil end

    -- Iterate up to the second-to-last element of the path, creating nested tables.
    for i = 1, #path - 1 do
        local key = path[i]
        
        -- If the key doesn't exist OR it's not a table (it could be an intermediate signal
        -- from a previous, shorter path), create/replace it with a new table.
        if typeof(currentTable[key]) ~= "table" then
            currentTable[key] = {}
        end
        
        currentTable = currentTable[key]
    end
    
    local parentTable = currentTable
    lastKey = path[#path]

    return parentTable, lastKey
end

-- Utility to safely retrieve a signal ONLY if it already exists, without creation.
local function _getSignalIfPresent(
    signalCache: { [any]: any }, 
    path: { any }
): Signal.Signal<any, any>? -- Use the most restrictive Signal type for consistency
    
    -- Use the read-only helper to find the signal's location
    local parentTable, lastKey = _navigatePath(signalCache, path, false) 
    
    if not parentTable or not lastKey then
        return nil -- Path does not exist in the signal cache
    end
    
    local signal = parentTable[lastKey]

    -- Check if the value found is actually a Signal (Duck Typing)
    if typeof(signal) == "table" and (signal :: any).Connect and (signal :: any).Fire then
        return signal :: Signal.Signal<any, any>
    end
    
    return nil
end

-- === Service Methods ===

function PlayerDataService.Init(self: PlayerDataService): ()
    self._profiles = {}
    self._replicas = {}
    self._valueChangedSignals = {}
    self._valueInsertedSignals = {}
    self._valueRemovedSignals = {}
end

function PlayerDataService.Start(self: PlayerDataService): ()
    local function onPlayerAdded(player: Player)
        local profile = playerStore:StartSessionAsync(`{player.UserId}`, {
            Cancel = function()
                return player.Parent ~= Players
            end
        })

        if not profile then
            player:Kick("Profile load fail - Please rejoin")
        end

        profile:AddUserId(player.UserId)
        profile:Reconcile()

        profile.OnSessionEnd:Connect(function()
            self:RemoveData(player)
        end)

        if player.Parent ~= Players then
            profile:EndSession()
            return
        end

        self._profiles[player] = profile
        print(`@{player.Name} profile loaded`)

        local replica = Replica.New({
            Token = utils.Token,
            Tags = { Player = player },
            Data = profile.Data
        })

        replica:Replicate()

        player:SetAttribute("DataLoaded")

        self._replicas[player] = replica
    end

    for _, player in pairs(Players:GetPlayers()) do
        task.spawn(onPlayerAdded, player)
    end

    Players.PlayerAdded:Connect(onPlayerAdded)

    Players.PlayerRemoving:Connect(function(player)
        local profile = self._profiles[player]
        if profile then
            profile:EndSession()
        end
    end)

    if not RunService:IsStudio() then
        game:BindToClose(function()
            for _, player in pairs(Players:GetPlayers()) do
                local profile = self._profiles[player]
                if profile then
                    profile:EndSession()
                end
            end
        end)
    end
end

function PlayerDataService.GetData(self: PlayerDataService, player: Player): ProfileData?
    local profile = self._profiles[player]
    return profile and profile.Data
end

function PlayerDataService.WaitForReplica(self: PlayerDataService, player, timeOut: number?): Replica?
    local playerReplica = nil
    local elapsed = 0
    local infinityYield = false
    timeOut = timeOut or 10

    repeat
        if self._replicas[player] then
            playerReplica = self._replicas[player]
            break
        end

        elapsed += task.wait(1)
        if elapsed >= timeOut and not infinityYield and not playerReplica then
            warn(`Infinity yield possible on WaitForReplica for player: {player.Name}`)
            infinityYield = true
        end
    until playerReplica

    return playerReplica
end

function PlayerDataService.GetReplica(self: PlayerDataService, player): Replica?
    return self._replicas[player]
end

function PlayerDataService.RemoveData(self: PlayerDataService, player: Player): ()
    -- Remove data from cache (ProfileStore will handle actual saving/ending session)
    self._profiles[player] = nil
    self._replicas[player] = nil
    
    -- Clear signal caches
    self._valueChangedSignals[player] = nil
    self._valueInsertedSignals[player] = nil
    self._valueRemovedSignals[player] = nil

    if player.Parent == Players then
        player:Kick(`Profile session end - Please rejoin`)
    end
end

function PlayerDataService.ResetData(self: PlayerDataService, player: Player): ()
    local playerProfile = self._profiles[player]
    if not playerProfile then
        return
    end

    -- Setting Data to template automatically marks it as changed
    playerProfile.Data = utils.Template

    -- Ending session to save the reset data and force a reload on rejoin
    playerProfile:EndSession()
end

function PlayerDataService.Get(self: PlayerDataService, player: Player, path: { any }): any
    local profile = self._profiles[player]
    if not profile then
        warn(`[PlayerDataService] Attempted to get data for unloaded player: {player.Name}`)
        return nil
    end

    -- Use read mode (false) for navigation
    local parentTable, lastKey = _navigatePath(profile.Data, path, false)

    if not parentTable or not lastKey then
        return nil
    end

    return parentTable[lastKey]
end

function PlayerDataService.Set(self: PlayerDataService, player: Player, path: { any }, newValue: any): ()
    local profile = self._profiles[player]
    if not profile then
        warn(`[PlayerDataService] Attempted to set data for unloaded player: {player.Name}`)
        return
    end

    -- Navigate/Create the path structure in the actual data (Write Mode)
    local parentTable, lastKey = _navigatePath(profile.Data, path, true)
    
    if not parentTable or not lastKey then return end

    local oldValue = parentTable[lastKey]
    
    -- Only update if the value actually changes
    if oldValue == newValue then return end

    parentTable[lastKey] = newValue

    -- 🔴 Fire ValueChanged Signal ONLY IF IT EXISTS
    local rootSignals = self._valueChangedSignals[player]
    if rootSignals then
        -- Use the read-only getter to see if a signal exists for this path
        local changedSignal = _getSignalIfPresent(rootSignals, path)
        if changedSignal then
            changedSignal:Fire(newValue, oldValue)
        end
    end
end

function PlayerDataService.GetValueChangedSignal(self: PlayerDataService, player: Player, path: { any }): Signal.Signal<any, any>
    -- 1. Ensure the player's root signal container exists
    local rootSignals = self._valueChangedSignals[player]
    if not rootSignals then
        rootSignals = {}
        self._valueChangedSignals[player] = rootSignals
    end

    -- 2. Navigate/Create the path structure in the signal cache
    local parentTable, lastKey = _getSignalContainer(rootSignals, path)
    
    if not parentTable or not lastKey then
        error("Cannot get signal for empty path")
    end
    
    local signal = parentTable[lastKey]

    -- 3. Check if the object at the final key is already a Signal
    -- Using the 'Connect' property as a reliable duck-typing check for the Signal class
    if typeof(signal) == "table" and (signal :: any).Connect then
        -- Signal already exists, return the existing one.
        return signal :: Signal.Signal<any, any>
    else
        -- Signal does not exist (or the key was nil/non-signal). Create a new one.
        local newSignal = Signal.new()
        parentTable[lastKey] = newSignal
        return newSignal :: Signal.Signal<any, any>
    end
end

function PlayerDataService.Insert(self: PlayerDataService, player: Player, path: { any }, value: any, index: any?): ()
    local profile = self._profiles[player]
    if not profile then
        warn(`[PlayerDataService] Attempted to insert data for unloaded player: {player.Name}`)
        return
    end

    -- Navigate to the parent table of the array/list where we want to insert (Write Mode)
    local parentTable, lastKey = _navigatePath(profile.Data, path, true)
    
    if not parentTable or not lastKey then return end

    local targetTable = parentTable[lastKey]

    -- Check if the target is a table, and if it's currently nil, initialize it as a list
    if targetTable == nil then
        targetTable = {}
        parentTable[lastKey] = targetTable
    elseif typeof(targetTable) ~= "table" then
        warn(`[PlayerDataService] Insert target at path {table.concat(path, ".")} is not a table.`)
        return
    end

    -- Perform the insertion
    if index then
        table.insert(targetTable, index, value)
    else
        table.insert(targetTable, value)
    end

    -- 🔴 Fire ValueInserted Signal ONLY IF IT EXISTS
    local rootSignals = self._valueInsertedSignals[player]
    if rootSignals then
        -- We check the inserted signal cache for existence
        local insertedSignal = _getSignalIfPresent(rootSignals, path)
        if insertedSignal then
            insertedSignal:Fire(value, index)
        end
    end
end

function PlayerDataService.Remove(self: PlayerDataService, player: Player, path: { any }, index: any): ()
    local profile = self._profiles[player]
    if not profile then
        warn(`[PlayerDataService] Attempted to remove data for unloaded player: {player.Name}`)
        return
    end

    -- Navigate to the parent table of the array/list we want to modify (Read Mode - don't create)
    local parentTable, lastKey = _navigatePath(profile.Data, path, false)
    
    if not parentTable or not lastKey then return end

    local targetTable = parentTable[lastKey]

    if typeof(targetTable) ~= "table" then
        warn(`[PlayerDataService] Remove target at path {table.concat(path, ".")} is not a table.`)
        return
    end

    local removedValue = nil
    
    -- Perform the removal (works for both sequential tables and dictionary tables)
    if typeof(index) == "number" then
        removedValue = table.remove(targetTable, index)
    elseif targetTable[index] ~= nil then
        removedValue = targetTable[index]
        targetTable[index] = nil -- Dictionary removal
    else
        return -- Index/key does not exist
    end

    -- 🔴 Fire ValueRemoved Signal ONLY IF IT EXISTS
    local rootSignals = self._valueRemovedSignals[player]
    if rootSignals and removedValue then
        -- We check the removed signal cache for existence
        local removedSignal = _getSignalIfPresent(rootSignals, path)
        if removedSignal then
            removedSignal:Fire(removedValue, index)
        end
    end
end

function PlayerDataService.GetValueInsertedSignal(self: PlayerDataService, player: Player, path: { any }): Signal.Signal<any, any?>
    local rootSignals = self._valueInsertedSignals[player]
    if not rootSignals then
        rootSignals = {}
        self._valueInsertedSignals[player] = rootSignals
    end

    -- Navigate/Create the path structure in the signal cache
    local parentTable, lastKey = _getSignalContainer(rootSignals, path)
    
    if not parentTable or not lastKey then
        error("Cannot get inserted signal for empty path")
    end
    
    local signal = parentTable[lastKey]

    if typeof(signal) == "table" and (signal :: any).Connect then
        return signal :: Signal.Signal<any, any?>
    else
        local newSignal = Signal.new()
        parentTable[lastKey] = newSignal
        return newSignal :: Signal.Signal<any, any?>
    end
end

function PlayerDataService.GetValueRemovedSignal(self: PlayerDataService, player: Player, path: { any }): Signal.Signal<any, any>
    local rootSignals = self._valueRemovedSignals[player]
    if not rootSignals then
        rootSignals = {}
        self._valueRemovedSignals[player] = rootSignals
    end

    -- Navigate/Create the path structure in the signal cache
    local parentTable, lastKey = _getSignalContainer(rootSignals, path)
    
    if not parentTable or not lastKey then
        error("Cannot get removed signal for empty path")
    end
    
    local signal = parentTable[lastKey]

    if typeof(signal) == "table" and (signal :: any).Connect then
        return signal :: Signal.Signal<any, any>
    else
        local newSignal = Signal.new()
        parentTable[lastKey] = newSignal
        return newSignal :: Signal.Signal<any, any>
    end
end

function PlayerDataService.Increment(self: PlayerDataService, player: Player, path: { any }, increment: number): ()
    local currentValue = self:Get(player, path)

    if typeof(currentValue) == "number" then
        local newValue = currentValue + increment
        -- Use PlayerDataService.Set to handle data update, profile marking, and ValueChanged Signal firing.
        self:Set(player, path, newValue)
    else
        warn(`[PlayerDataService] Attempted to increment non-number value at path {table.concat(path, ".")} for player: {player.Name}`)
    end
end

return PlayerDataService