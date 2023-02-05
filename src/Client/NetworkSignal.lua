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
    Middleware: {
        Inbound: {(args: {any}) -> Promise};
        Outbound: {(args: {any}) -> Promise};
    };

    __remote: RemoteEvent;
    __signal: FastSignal;

    Connect: (self: NetworkSignal, handler: (...any) -> ()) -> FastConnection;
    Once: (self: NetworkSignal, handler: (...any) -> ()) -> ();
    Wait: (self: NetworkSignal) -> ...any;
    WaitPromise: (self: NetworkSignal) -> Promise;

    FireServer: (self: NetworkSignal, ...any) -> ();

    Destroy: (self: NetworkSignal) -> ();
}

local NetworkSignal: NetworkSignal = {}
NetworkSignal.__index = NetworkSignal

local function applyMiddleware(middleware, ...)
	local args = {...}
	return Promise.new(function(resolve, reject)
		if #middleware > 0 then
			local shouldContinue = true
			for _, middlewareFn in pairs(middleware) do
				local success = false
				success, shouldContinue, args = middlewareFn(args):await()
				if not success then
					reject(args)
				end
				if not shouldContinue then
					break
				end
			end
			resolve(args)
		else
			resolve(args)
		end
	end)
end

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

function NetworkSignal:WaitPromise(direct: boolean?)
    return Promise.new(function(resolve)
        resolve(self:Wait(direct))
    end)
end

function NetworkSignal:FireServer(...: any)
    applyMiddleware(self.Middleware.Outbound, ...):andThen(function(args)
        self.__remote:FireServer(unpack(args))
    end)
end

function NetworkSignal:Destroy()
    self.__remote:Destroy()
end

function NetworkSignal.new(name: string, remote: RemoteEvent): NetworkSignal
    local self = setmetatable({
        Name = name;
        Middleware = {
            Inbound = {};
            Outbound = {};
        };

        __remote = remote;
        __signal = FastSignal.new();
    }, NetworkSignal)

    onSignalFirstConnected(self.__signal, function()
        self.__remote.OnClientEvent:Connect(function(...)
            applyMiddleware(self.Middleware.Inbound, ...):andThen(function(args)
                self.__signal:Fire(unpack(args))
            end)
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