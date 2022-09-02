local Players = game:GetService("Players")

local Util = script.Parent.Parent.Util
local Packages = script.Parent.Parent.Parent

local assert = require(Util.assert)

local FastSignal = require(Packages.FastSignal)
type FastSignal = FastSignal.Class
type FastConnection = FastSignal.ScriptConnection

local Promise = require(Packages.Promise)
type Promise = typeof(Promise.new())

type Callback = (any...) -> (...any)
export type NetworkFunction = {
	Name: string;
    CallbackSet: FastSignal;

	__remote: RemoteFunction;
	__function: Callback;

    SetCallback: (self: NetworkFunction, callback: Callback) -> ();
    InvokeServer: (self: NetworkFunction, any...) -> (...any);

	Destroy: (self: NetworkFunction) -> ();
}

local NetworkFunction: NetworkFunction = {}
NetworkFunction.__index = NetworkFunction

function NetworkFunction.__onClientInvoke()
    
end

function NetworkFunction.__function(player: Player)
    return
end

function NetworkFunction:SetCallback(callback: Callback)
    self.__function = callback
    self.CallbackSet:Fire(callback)
end

function NetworkFunction:InvokeServer(...: any)
    return self.__remote:InvokeServer(...)
end

function NetworkFunction:Destroy()
    self.__remote:Destroy()
end

function NetworkFunction.new(name: string, remote: RemoteFunction): NetworkFunction
    local self = setmetatable({
        Name = name;
        CallbackSet = FastSignal.new();

        __remote = remote;
    }, NetworkFunction)

    self.__remote.Destroying:Once(function()
        self.CallbackSet:Destroy()
        table.clear(self)
        setmetatable(self, nil)
    end)

    self.CallbackSet:Once(function()
        self.__remote.OnClientInvoke = function(player: Player, ...)
            return self.__function(player, ...)
        end
    end)

    return self
end

return NetworkFunction