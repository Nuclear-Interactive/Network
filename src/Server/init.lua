local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ALREADY_EXISTS_ERROR = "Network%s: %s already exists."
local RESERVED_NAMESPACE_ERROR = "Network%s: %s is a reserved namespace for internal use."
local RESERVED_NAMESPACES = {
    Signal = {StateAdded = {}};
    Function = {};
    State = {};
};

local Util = script.Parent.Util
local Packages = script.Parent.Parent

local assert = require(Util.assert)

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
    FunctionAdded: FastSignal;
    --StateAdded: FastSignal;

    __vault: NetworkVault;
    __registry: {
        Signal: {NetworkSignal};
        Function: {NetworkFunction};
        State: {NetworkState};
    };

    CreateSignal: (self: Network, name: string) -> NetworkSignal;
    CreateFunction: (self: Network, name: string) -> NetworkFunction;
    --CreateState: (self: Network, name: string, initialState: {any}) -> NetworkState;

    GetSignal: (self: Network, name: string) -> NetworkSignal?;
    GetFunction: (self: Network, name: string) -> NetworkFunction?;
    --GetState: (self: Network, name: string) -> NetworkState?;

    GetSignalWithRemote: (self: Network, remote: RemoteEvent) -> NetworkSignal?;
    GetFunctionWithRemote: (self: Network, remote: RemoteFunction) -> NetworkFunction?;

    Destroy: (self: Network) -> ();
}

assert(RunService:IsServer(), "This module is Server only!")

local DefaultNetworkParent = Instance.new("Folder")
DefaultNetworkParent.Name = "Pipes"
DefaultNetworkParent.Parent = game.ReplicatedStorage

local Network: Network = {}
Network.__index = Network

local function checkNamespace(network: Network, objectType: string, name: string)
    assert(network.__registry[objectType][name] == nil or RESERVED_NAMESPACES[objectType][name] == nil, RESERVED_NAMESPACE_ERROR, objectType, name)
    assert(network.__registry[objectType][name] == nil, ALREADY_EXISTS_ERROR, objectType, name)
end

local function createReservedObjects(network: Network)
    for namespace, args in pairs(RESERVED_NAMESPACES.Signal) do
        network:CreateSignal(namespace)
    end
    for namespace, args in pairs(RESERVED_NAMESPACES.Function) do
        network:CreateFunction(namespace)
    end
    for namespace, args in pairs(RESERVED_NAMESPACES.State) do
        network:CreateState(namespace, unpack(args))
    end
end

local function createNetworkVault(name: string, parent: Instance): NetworkVault
    local vault = Instance.new("Folder")
    vault.Name = name

    local signalVault = Instance.new("Folder")
    signalVault.Name = "Signals"
    signalVault.Parent = vault

    local functionVault = Instance.new("Folder")
    functionVault.Name = "Functions"
    functionVault.Parent = vault

    vault.Parent = parent
    return vault
end

local function registerSignal(self: Network, name: string, remote: RemoteEvent)
    local networkSignal = NetworkSignal.new(name, remote)
    self.__registry.Signal[name] = networkSignal
    self.SignalAdded:Fire(networkSignal)
    return networkSignal
end

local function registerFunction(self: Network, name: string, remote: RemoteFunction)
    local networkFunction = NetworkFunction.new(name, remote)
    self.__registry.Function[name] = networkFunction
    self.FunctionAdded:Fire(networkFunction)
    return networkFunction
end

-- CREATORS --

function Network:CreateSignal(name: string): NetworkSignal
    checkNamespace(self, "Signal", name)
    local remote = Instance.new("RemoteEvent")
    remote.Name = name
    remote.Parent = self.__vault.Signals
    return registerSignal(self, name, remote)
end

function Network:CreateFunction(name: string): NetworkFunction
    checkNamespace(self, "Function", name)
    local remote = Instance.new("RemoteFunction")
    remote.Name = name
    remote.Parent = self.__vault.Functions
    return registerFunction(self, name, remote)
end

--[[
function Network:CreateState(name: string): NetworkState
    checkNamespace(self, "State", name)
end
]]

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

function Network:GetFunction(name: string): NetworkFunction?
    return self.__registry.Function[name]
end

function Network:GetFunctionWithRemote(remote: RemoteFunction): NetworkFunction?
    for namespace, func in pairs(self.__registry.Function) do
        if func.__remote == remote then
            return func
        end
    end
end

--[[
function Network:GetState(name: string): NetworkState?
    return self.__registry.State[name]
end
]]

function Network:Destroy()
    self.__vault:Destroy()
end

function Network.new(name: string, parent: Instance?): Network
    parent = parent or DefaultNetworkParent
    assert(parent:FindFirstChild(name) == nil, ALREADY_EXISTS_ERROR, "", name)
    local self = setmetatable({
        Name = name;

        SignalAdded = FastSignal.new();
        FunctionAdded = FastSignal.new();
        StateAdded = FastSignal.new();

        __vault = createNetworkVault(name, parent);
        __registry = {
            Signal = {};
            Function = {};
            State = {};
        };
    }, Network)

    createReservedObjects(self)
    self.__vault.Destroying:Once(function()
        setmetatable(self, nil)
        table.clear(self)
    end)

    return self
end

return Network :: {
    new: (name: string, parent: Instance?) -> Network;
}