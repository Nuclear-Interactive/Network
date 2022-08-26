local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Util = script.Parent.Parent.Util
local Packages = script.Parent.Parent.Parent

local assert = require(Util.assert)
local onSignalFirstConnected = require(Util.onSignalFirstConnected)

local FastSignal = require(Packages.FastSignal)
type FastSignal = FastSignal.Class
type FastConnection = FastSignal.ScriptConnection

local Promise = require(Packages.Promise)
type Promise = typeof(Promise.new())

export type NetworkSignal = {
    Name: string;

    __remote: RemoteEvent;
    __signal: FastSignal;

    Connect: (self: NetworkSignal, handler: (...any) -> ()) -> FastConnection;
    Once: (self: NetworkSignal, handler: (...any) -> ()) -> ();
    Wait: (self: NetworkSignal) -> ...any;

    FireServer: (self: NetworkSignal, ...any) -> ();

    Destroy: (self: NetworkSignal) -> ();
}

local NetworkSignal: NetworkSignal = {}
NetworkSignal.__index = NetworkSignal

function NetworkSignal:Connect(handler: (...any) -> (), direct: boolean?): FastConnection
    local signalToConnectTo = direct and self.__remote.OnClientEvent or self.__signal
    return signalToConnectTo:Connect(handler)
end

function NetworkSignal:Once(handler: (...any) -> (), direct: boolean?)
    local signalToConnectTo = direct and self.__remote.OnClientEvent or self.__signal
    return signalToConnectTo:Once(handler)
end

function NetworkSignal:Wait(direct: boolean?): ...any
    local signalToConnectTo = direct and self.__remote.OnClientEvent or self.__signal
    return signalToConnectTo:Wait()
end

function NetworkSignal:FireServer(...: any)
    self.__remote:FireServer(...)
end

function NetworkSignal:Destroy()
    self.__remote:Destroy()
end

function NetworkSignal.new(name: string, remote: RemoteEvent): NetworkSignal
    local self = setmetatable({
        Name = name;

        __remote = remote;
        __signal = FastSignal.new();
    }, NetworkSignal)

    onSignalFirstConnected(self.__signal, function()
        self.__remote.OnClientEvent:Connect(function(...)
            self.__signal:Fire(...)
        end)
    end)

    self.__remote.Destroying:Once(function()
        self.__signal:Destroy()
		table.clear(self)
		setmetatable(self, nil)
    end)

    return self
end

return NetworkSignal :: {
    new: (name: string, remote: RemoteEvent) -> NetworkSignal;
}