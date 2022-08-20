local RunService = game:GetService("RunService")
local Packages = game.ReplicatedFirst.Packages

local ALREADY_EXISTS_ERROR = "%s already exists inside this Network object."

local FastSignal = require(Packages.FastSignal)
type FastSignal = FastSignal.Class
type FastConnection = FastSignal.ScriptConnection

local Promise = require(Packages.Promise)
type Promise = typeof(Promise.new())

local NetworkSignal = require(script.NetworkSignal)
type NetworkSignal = NetworkSignal.NetworkSignal
local NetworkFunction = require(script.NetworkFunction)
type NetworkFunction = NetworkFunction.NetworkFunction

type NetworkVault = Folder & {
    Signals: Folder;
    Functions: Folder;
}

type NetworkSignalAddedServer = FastSignal & {
    Connect: (self: FastSignal, handler: (netSig: NetworkSignal.ServerClass) -> () ) -> FastConnection;
    Once: (self: FastSignal, handler: (netSig: NetworkSignal.ServerClass) -> () ) -> ();
    Wait: (self: FastSignal) -> NetworkSignal.ServerClass;
}

type NetworkFunctionAddedServer = FastSignal & {
    Connect: (self: FastSignal, handler: (netSig: NetworkFunction.ServerClass) -> () ) -> FastConnection;
    Once: (self: FastSignal, handler: (netSig: NetworkFunction.ServerClass) -> () ) -> ();
    Wait: (self: FastSignal) -> NetworkFunction.ServerClass;
}

export type NetworkServer = {
    Name: string;
    NetworkSignalAdded: NetworkSignalAddedServer;
    NetworkFunctionAdded: NetworkFunctionAddedServer;

    __vault: NetworkVault;
    __networkSignals: {NetworkSignal.ServerClass};
    __networkFunctions: {NetworkFunction.ServerClass};

    CreateSignal: (self: NetworkServer, name: string) -> NetworkSignal.ServerClass;
    GetSignal: (self: NetworkServer, name: string) -> NetworkSignal.ServerClass?;
    GetSignalWithRemote: (self: NetworkServer, remote: RemoteEvent) -> NetworkSignal.ServerClass?;
    WaitForSignal: (self: NetworkServer, name: string) -> NetworkSignal.ServerClass;
    WaitForSignalPromise: (self: NetworkServer, name: string) -> Promise;

    CreateFunction: (self: NetworkServer, name: string) -> NetworkFunction.ServerClass;
    GetFunction: (self: NetworkServer, name: string) -> NetworkFunction.ServerClass?;
    GetFunctionWithRemote: (self: NetworkServer, remote: RemoteFunction) -> NetworkFunction.ServerClass?;
    WaitForFunction: (self: NetworkServer, name: string) -> NetworkFunction.ServerClass;
    WaitForFunctionPromise: (self: NetworkServer, name: string) -> Promise;

    Destroy: (self: NetworkServer) -> ();
}

type NetworkSignalAddedClient = FastSignal & {
    Connect: (self: FastSignal, handler: (signal: NetworkSignal.ClientClass) -> () ) -> FastConnection;
    Once: (self: FastSignal, handler: (signal: NetworkSignal.ClientClass) -> () ) -> ();
    Wait: (self: FastSignal) -> NetworkSignal.ClientClass;
}

type NetworkFunctionAddedClient = FastSignal & {
    Connect: (self: FastSignal, handler: (signal: NetworkFunction.ClientClass) -> () ) -> FastConnection;
    Once: (self: FastSignal, handler: (signal: NetworkFunction.ClientClass) -> () ) -> ();
    Wait: (self: FastSignal) -> NetworkFunction.ClientClass;
}

export type NetworkClient = {
    Name: string;
    NetworkSignalAdded: NetworkSignalAddedClient;
    NetworkFunctionAdded: NetworkFunctionAddedClient;

    __vault: NetworkVault;
    __networkSignals: {NetworkSignal.ClientClass};
    __networkFunctions: {NetworkFunction.ClientClass};

    GetSignal: (self: NetworkClient, name: string) -> NetworkSignal.ClientClass?;
    GetSignalWithRemote: (self: NetworkClient, remote: RemoteEvent) -> NetworkSignal.ClientClass?;
    WaitForSignal: (self: NetworkClient, name: string) -> NetworkSignal.ClientClass;
    WaitForSignalPromise: (self: NetworkClient, name: string) -> Promise;

    GetFunction: (self: NetworkClient, name: string) -> NetworkFunction.ClientClass?;
    GetFunctionWithRemote: (self: NetworkClient, remote: RemoteFunction) -> NetworkFunction.ClientClass?;
    WaitForFunction: (self: NetworkClient, name: string) -> NetworkFunction.ClientClass;
    WaitForFunctionPromise: (self: NetworkClient, name: string) -> Promise;

    Destroy: (self: NetworkClient) -> ();
}

export type Network = NetworkServer & NetworkClient

local DefaultNetworkParent = game.ReplicatedStorage:FindFirstChild("Pipes")
if RunService:IsServer() then
    DefaultNetworkParent = Instance.new("Folder")
    DefaultNetworkParent.Name = "Pipes"
    DefaultNetworkParent.Parent = game.ReplicatedStorage
end

local Network: Network = {}
Network.__index = Network

local function createSignal(self: Network, name: string, remote: RemoteEvent, inboundMiddleware: NetworkSignal.Middleware, outboundMiddleware: NetworkSignal.Middleware): NetworkSignal
    local netSig = NetworkSignal.new(name, remote, inboundMiddleware, outboundMiddleware)
    self.__networkSignals[name] = netSig
    self.NetworkSignalAdded:Fire(netSig)
    return netSig
end

local function createFunction(self: Network, name: string, remote: RemoteEvent): NetworkFunction
    local netFunc = NetworkFunction.new(name, remote)
    self.__networkFunctions[name] = netFunc
    self.NetworkFunctionAdded:Fire(netFunc)
    return netFunc
end

local function createNetworkVault(name: string, parent: Instance): NetworkVault
    local vault = Instance.new("Folder")
    vault.Name = name
    vault.Parent = parent

    local signalVault = Instance.new("Folder")
    signalVault.Name = "Signals"
    signalVault.Parent = vault

    local functionVault = Instance.new("Folder")
    functionVault.Name = "Functions"
    functionVault.Parent = vault

    return vault
end

-- SHARED --

function Network:Destroy()
    self.__vault:Destroy()
end

function Network:GetSignal(name: string): NetworkSignal?
    return self.__networkSignals[name]
end

function Network:GetSignalWithRemote(remote: RemoteEvent): NetworkSignal?
    for _, networkSignal in pairs(self.__networkSignals) do
        if networkSignal.__remote == remote then
            return networkSignal
        end
    end
    return nil
end

function Network:WaitForSignal(name: string): NetworkSignal
    local netSig = self:GetSignal(name)
    if not netSig or netSig.Name ~= name then
        repeat
            netSig = self.NetworkSignalAdded:Wait()
        until netSig.Name == name
    end
    return netSig
end

function Network:WaitForSignalPromise(name: string): Promise
    return Promise.new(function(resolve, reject, onCancel)
        resolve(self:WaitForSignal(name))
    end)
end

function Network:GetFunction(name: string): NetworkFunction?
    return self.__networkFunctions[name]
end

function Network:GetFunctionWithRemote(remote: RemoteFunction): NetworkFunction?
    for _, netFunc in pairs(self.__networkFunctions) do
        if netFunc.__remote == remote then
            return netFunc
        end
    end
    return nil
end

function Network:WaitForFunction(name: string): NetworkFunction
    local netFunc = self:GetFunction(name)
    if not netFunc or netFunc.Name ~= name then
        repeat
            netFunc = self.NetworkFunctionAdded:Wait()
        until netFunc.Name == name
    end
    return netFunc
end

function Network:WaitForFunctionPromise(name: string): Promise
    return Promise.new(function(resolve, reject, onCancel)
        resolve(self:WaitForFunction(name))
    end)
end

-- SERVER --

function Network:CreateSignal(name: string): NetworkSignal
    assert(self.__networkSignals[name] == nil, string.format(ALREADY_EXISTS_ERROR, name))
    local remote = Instance.new("RemoteEvent")
    remote.Name = name
    remote.Parent = self.__vault.Signals
    return createSignal(self, name, remote)
end

function Network:CreateFunction(name: string): NetworkFunction
    assert(self.__networkFunctions[name] == nil, string.format(ALREADY_EXISTS_ERROR, name))
    local remote = Instance.new("RemoteFunction")
    remote.Name = name
    remote.Parent = self.__vault.Functions
    return createFunction(self, name, remote)
end

-- CLIENT --

function Network.new(name: string, parent: Instance?): Network
    parent = parent or DefaultNetworkParent
    local self = setmetatable({
        Name = name;
        __networkSignals = {};
        __networkFunctions = {};
        __vault = parent:FindFirstChild(name);

        NetworkSignalAdded = FastSignal.new();
        NetworkFunctionAdded = FastSignal.new();
    }, Network)

    if RunService:IsServer() then
        self.__vault = createNetworkVault(name, parent)
    elseif RunService:IsClient() then
        if not self.__vault then
            self:Destroy()
            error(string.format("Network %s does not exist on the Server.", name))
        end
        self.__vault.Signals.ChildAdded:Connect(function(remote)
            createSignal(self, remote.Name, remote)
        end)
        for _, remote in pairs(self.__vault.Signals:GetChildren()) do
            createSignal(self, remote.Name, remote)
        end

        self.__vault.Functions.ChildAdded:Connect(function(remote)
            createFunction(self, remote.Name, remote)
        end)
        for _, remote in pairs(self.__vault.Functions:GetChildren()) do
            createFunction(self, remote.Name, remote)
        end
    end

    self.__vault.Destroying:Once(function()
        self.NetworkSignalAdded:Destroy()
        self.NetworkFunctionAdded:Destroy()
        setmetatable(self, nil)
        table.clear(self)
    end)

    return self
end

return Network :: {
    new: (name: string, parent: Instance) -> Network;
}