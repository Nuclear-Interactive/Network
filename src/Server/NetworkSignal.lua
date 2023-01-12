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
        Inbound: {(player: Player, args: {any}) -> Promise};
        Outbound: {(player: Player, args: {any}) -> Promise};
    };

    __remote: RemoteEvent;
    __signal: FastSignal;

    Connect: (self: NetworkSignal, handler: (player: Player, ...any) -> ()) -> FastConnection;
    Once: (self: NetworkSignal, handler: (player: Player, ...any) -> ()) -> ();
    Wait: (self: NetworkSignal) -> ...any;

	FireClient: (self: NetworkSignal, client: Player, any...) -> ();
	FireClients: (self: NetworkSignal, clients: {Player}, any...) -> ();
	FireAllClients: (self: NetworkSignal, any...) -> ();
	FireAllExcept: (self: NetworkSignal, excludedClients: {Player}, any...) -> ();
	FireAllFilter: <A...>(self: NetworkSignal, predicate: (client: Player, A...) -> (boolean), A...) -> ();

    Destroy: (self: NetworkSignal) -> ();
}

local NetworkSignal: NetworkSignal = {}
NetworkSignal.__index = NetworkSignal

local function applyMiddleware(middleware, player, ...)
	local args = {...}
	return Promise.new(function(resolve, reject)
		if #middleware > 0 then
			local shouldContinue = true
			for _, middlewareFn in pairs(middleware) do
				local success = false
				success, shouldContinue, args = middlewareFn(player, args):await()
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

local function fireClient(self: NetworkSignal, client: Player, ...: any)
    applyMiddleware(self.Middleware.Outbound, client, ...):andThen(function(args)
        self.__remote:FireClient(client, unpack(args))
    end)
end

function NetworkSignal:Connect(handler: (...any) -> (), direct: boolean?): FastConnection
    local signalToConnectTo = direct and self.__remote.OnServerEvent or self.__signal
    return signalToConnectTo:Connect(handler)
end

function NetworkSignal:Once(handler: (...any) -> (), direct: boolean?)
    local signalToConnectTo = direct and self.__remote.OnServerEvent or self.__signal
    return signalToConnectTo:Once(handler)
end

function NetworkSignal:Wait(direct: boolean?): ...any
    local signalToConnectTo = direct and self.__remote.OnServerEvent or self.__signal
    return signalToConnectTo:Wait()
end

function NetworkSignal:FireClient(client: Player, ...: any)
    fireClient(self, client, ...)
end

function NetworkSignal:FireClients(clients: {Player}, ...: any)
    for _, client in pairs(clients) do
        fireClient(self, client, ...)
    end
end

function NetworkSignal:FireAllClients(...: any)
    for _, client in pairs(Players:GetPlayers()) do
        fireClient(self, client, ...)
    end
end

function NetworkSignal:FireAllExcept(excludedClients: {Player}, ...: any)
    for _, client in pairs(Players:GetPlayers()) do
        if not table.find(excludedClients, client) then
            fireClient(self, client, ...)
        end
    end
end

function NetworkSignal:FireAllFilter(predicate, ...: any)
    for _, client in pairs(Players:GetPlayers()) do
        if predicate(client) then 
            fireClient(self, client, ...) 
        end
    end
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
        self.__remote.OnServerEvent:Connect(function(player, ...)
            applyMiddleware(self.Middleware.Inbound, player, ...):andThen(function(args)
                self.__signal:Fire(player, unpack(args))
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