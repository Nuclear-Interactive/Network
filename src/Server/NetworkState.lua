local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Util = script.Parent.Parent.Util
local Packages = script.Parent.Parent.Parent

local assert = require(Util.assert)

local FastSignal = require(Packages.FastSignal)
type FastSignal = FastSignal.Class
type FastConnection = FastSignal.ScriptConnection

local BasicState = require(Packages.BasicState)
type BasicState = typeof(BasicState.new())

local Janitor = require(Packages.Janitor)
type Janitor = typeof(Janitor.new())

local Promise = require(Packages.Promise)
type Promise = typeof(Promise.new())

local NetworkSignal = require(script.Parent.NetworkSignal)
local NetworkFunction = require(script.Parent.NetworkFunction)
type NetworkSignal = NetworkSignal.NetworkSignal
type NetworkFunction = NetworkFunction.NetworkFunction

type ReplicationType = "All" | {Player}
export type NetworkState = BasicState & {
    Name: string;
    Replication: ReplicationType;

    __state: BasicState;
    __janitor: Janitor;

    SetReplication: (self: NetworkState, replication: ReplicationType) -> ();
}

local NetworkState: NetworkState = setmetatable({}, BasicState)
NetworkState.__index = NetworkState

local function canReplicate(replicationType: ReplicationType, player: Player)
    if replicationType == "All" then
        return true
    end
    if table.find(replicationType, player) then
        return true
    end
    return false
end

function NetworkState:SetReplication(replication: ReplicationType)
    self.Replication = replication
end

function NetworkState:Destroy()
    self.__state:Destroy()
    self.__janitor:Destroy()
    table.clear(self)
    setmetatable(self, nil)
end

function NetworkState.new(name: string, replication: ReplicationType, initialState: {any}, network): NetworkState
    local state = BasicState.new(initialState)
    local self = setmetatable(state, NetworkState)

    self.Name = name
    self.Replication = replication

    self.__state = state
    self.__janitor = Janitor.new()
    self.__network = network
    
    local changedSignal: NetworkSignal = network:CreateSignal(name.."_".."Changed")
    local getFunction: NetworkFunction = network:CreateFunction(name.."_".."Get")
    self.__janitor:Add(changedSignal, "Destroy")
    self.__janitor:Add(getFunction, "Destroy")

    self.Changed:Connect(function(key)
        local value = self.__state:Get(key)
        local clients = self.Replication == "All" and Players:GetPlayers() or self.Replication
        changedSignal:FireClients(clients, key, value)
    end)

    getFunction:SetCallback(function(player)
        if not canReplicate(self.Replication, player) then
            warn(player.Name, player.UserId, "tried getting a state they are not allowed to access.")
            return
        end
        return self.__state:GetState()
    end)

    return self
end

return NetworkState