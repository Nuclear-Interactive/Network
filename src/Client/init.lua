local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DOES_NOT_EXIST_ERROR = "Network: %s.%s does not exist on the Server."

local Util = script.Parent.Util
local Packages = script.Parent.Parent

local assert = require(Util.assert)
local applyToChildren = require(Util.applyToChildren)

local FastSignal = require(Packages.FastSignal)
type FastSignal = FastSignal.Class
type FastConnection = FastSignal.ScriptConnection

local Promise = require(Packages.Promise)
type Promise = typeof(Promise.new())

local BasicState = require(Packages.BasicState)
type BasicState = typeof(BasicState.new())

local NetworkSignal = require(script.NetworkSignal)
local NetworkFunction = require(script.NetworkFunction)
local NetworkState = require(script.NetworkState)
export type NetworkSignal = NetworkSignal.NetworkSignal
export type NetworkFunction = NetworkFunction.NetworkFunction
export type NetworkState = NetworkState.NetworkState

type NetworkVault = Folder & {
    Signals: Folder;
    Functions: Folder;
}

export type Network = {
    Name: string;

    SignalAdded: FastSignal;
    --FunctionAdded: FastSignal;
    --StateAdded: FastSignal;

    __vault: NetworkVault;
    __registry: {
        Signal: {NetworkSignal};
        Function: {NetworkFunction};
        State: {NetworkState};
    };

    GetSignal: (self: Network, name: string) -> NetworkSignal?;
    --GetFunction: (self: Network, name: string) -> NetworkFunction?;
    --GetState: (self: Network, name: string) -> NetworkState?;

    GetSignalWithRemote: (self: Network, remote: RemoteEvent) -> NetworkSignal?;
    --GetFunctionWithRemote: (self: Network, remote: RemoteFunction) -> NetworkFunction?;

    Destroy: (self: Network) -> ();
}

local DefaultNetworkParent = game.ReplicatedStorage:WaitForChild("Pipes")

local Network: Network = {}
Network.__index = Network

local function registerSignal(self: Network, name: string, remote: RemoteEvent)
    local networkSignal = NetworkSignal.new(name, remote)
    self.__registry.Signal[name] = networkSignal
    self.SignalAdded:Fire(networkSignal)
    return networkSignal
end

-- GETTERS --

function Network:GetSignal(name: string): NetworkSignal?
    return self.__registry.Signal[name]
end

function Network:GetSignalWithRemote(remote: RemoteEvent): NetworkSignal?
    for namespace, signal in pairs(self.__registry.Signal) do
        if signal.__remote == remote then
            return signal
        end
    end
end

--[[
function Network:GetFunction(name: string): NetworkFunction?
    return self.__registry.Signal[name]
end

function Network:GetFunctionWithRemote(remote: RemoteFunction): NetworkFunction?
end

function Network:GetState(name: string): NetworkState?
    return self.__registry.Signal[name]
end
]]

function Network:Destroy()
    self.__vault:Destroy()
end

function Network.new(name: string, parent: Instance?): Network
    parent = parent or DefaultNetworkParent
    assert(parent:FindFirstChild(name), DOES_NOT_EXIST_ERROR, parent:GetFullName(), name);
    local self = setmetatable({
        Name = name;

        SignalAdded = FastSignal.new();
        FunctionAdded = FastSignal.new();
        StateAdded = FastSignal.new();

        __vault = parent:FindFirstChild(name);
        __registry = {
            Signal = {};
            Function = {};
            State = {};
        };
    }, Network)

    self.__vault.Destroying:Once(function()
        setmetatable(self, nil)
        table.clear(self)
    end)

    applyToChildren(self.__vault.Signals, function(remote: RemoteEvent)
        registerSignal(self, remote.Name, remote)
    end)

    return self
end

return Network :: {
    new: (name: string, parent: Instance?) -> Network;
}