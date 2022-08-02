local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Packages = game.ReplicatedFirst.Packages

local FastSignal = require(Packages.FastSignal)
type FastSignal = FastSignal.Class
type FastConnection = FastSignal.ScriptConnection

local Promise = require(Packages.Promise)
type Promise = typeof(Promise.new())

export type ServerMiddlewareFn = (player: Player, args: {any}) -> Promise
export type ServerMiddleware = {[number]: ServerMiddlewareFn};

export type ClientMiddlewareFn = (args: {any}) -> Promise
export type ClientMiddleware = {[number]: ClientMiddlewareFn};

export type NetworkSignalServer = {
	Name: string;
	InboundMiddleware: ServerMiddleware;
	OutboundMiddleware: ServerMiddleware;

	__remote: RemoteEvent;
	__signal: FastSignal;

	Connect: (self: NetworkSignalServer, handler: (player: Player, any...) -> ()) -> FastConnection;
	Once: (self: NetworkSignalServer, handler: (player: Player, any...) -> ()) -> FastConnection;
	Wait: (self: NetworkSignalServer) -> (...any);
	WaitPromise: (self: NetworkSignalServer) -> Promise;
	Destroy: (self: NetworkSignalServer) -> ();

	FireClient: (self: NetworkSignalServer, player: Player, any...) -> ();
	FireClients: (self: NetworkSignalServer, players: {Player}, any...) -> ();
	FireAllClients: (self: NetworkSignalServer, any...) -> ();
	FireAllClientsExcept: (self: NetworkSignalServer, excluded: {Player}, any...) -> ();
	FireAllClientsFilter: <A>(self: NetworkSignalServer, predicate: (player: Player, A...) -> (boolean), A...) -> ();
}

export type NetworkSignalClient = {
	Name: string;
	InboundMiddleware: ClientMiddleware;
	OutboundMiddleware: ClientMiddleware;

	__remote: RemoteEvent;
	__signal: FastSignal;

	Connect: (self: NetworkSignalClient, handler: (any...) -> ()) -> FastConnection;
	Once: (self: NetworkSignalClient, handler: (any...) -> ()) -> FastConnection;
	Wait: (self: NetworkSignalClient) -> (...any);
	WaitPromise: (self: NetworkSignalClient) -> Promise;
	Destroy: (self: NetworkSignalClient) -> ();

	FireServer: (self: NetworkSignalClient, any...) -> ();
}

export type Middleware = ServerMiddleware & ClientMiddleware
export type ServerClass = NetworkSignalServer
export type ClientClass = NetworkSignalClient
export type NetworkSignal = NetworkSignalServer & NetworkSignalClient

local NetworkSignal: NetworkSignal = {}
NetworkSignal.__index = NetworkSignal

local function clientOnly()
	assert(RunService:IsClient())
end

local function serverOnly()
	assert(RunService:IsServer())
end

local function wrapSignalConnectFn(signal: FastSignal)
	signal.Connected = FastSignal.new()
	local connectFn = signal.Connect
	function signal:Connect(...)
		local connection = connectFn(self, ...)
		signal.Connected:Fire(connection)
		return connection
	end
end

local function applyMiddlewareServer<A>(middleware: ServerMiddleware, player: Player, ...: A)
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

local function applyMiddlewareClient<A>(middleware: ClientMiddleware, ...: A)
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

-- SHARED --

function NetworkSignal:Destroy()
	self.__remote:Destroy()
end

function NetworkSignal:Connect(handLer: () -> ())
	return self.__signal:Connect(handLer)
end

function NetworkSignal:Once(handLer: () -> ())
	return self.__signal:Once(handLer)
end

function NetworkSignal:Wait()
	return self.__signal:Wait()
end

function NetworkSignal:WaitPromise()
	return Promise.new(function(resolve, reject)
		resolve(self.__signal:Wait())
	end)
end

-- SERVER --

local function fireClient(self: NetworkSignal, player, ...: any)
	applyMiddlewareServer(self.OutboundMiddleware, player, ...):andThen(function(args)
		self.__remote:FireClient(player, unpack(args))
	end)
end

function NetworkSignal:FireClient(player: Player, ...: any)
	serverOnly()
	fireClient(self, player, ...)
end

function NetworkSignal:FireClients(players: {Player}, ...: any)
	serverOnly()
	for _, player in pairs(players) do
		fireClient(self, player, ...)
	end
end

function NetworkSignal:FireAllClients(...: any)
	serverOnly()
	for _, player in pairs(Players:GetPlayers()) do
		fireClient(self, player, ...)
	end
end

function NetworkSignal:FireAllClientsExcept(excluded: {Player}, ...: any)
	serverOnly()
	for _, player in pairs(Players:GetPlayers()) do
		if not table.find(excluded, player) then
			fireClient(self, player, ...)
		end
	end
end

function NetworkSignal:FireAllClientsFilter(predicate: (player: Player, ...any) -> (boolean), ...: any)
	serverOnly()
	for _, player in pairs(Players:GetPlayers()) do
		if predicate(player, ...) then
			fireClient(self, player, ...)
		end
	end
end

-- CLIENT --

function NetworkSignal:FireServer(...: any)
	clientOnly()
	applyMiddlewareClient(self.OutboundMiddleware, ...):andThen(function(args)
		self.__remote:FireServer(unpack(args))
	end)
end

function NetworkSignal.new(name: string, remote: RemoteEvent, inboundMiddleware: Middleware?, outboundMiddleware: Middleware?): NetworkSignal
	local self = setmetatable({
		Name = name;
		__remote = remote;
		__signal = FastSignal.new();
		InboundMiddleware = inboundMiddleware or {};
		OutboundMiddleware = outboundMiddleware or {};
	}, NetworkSignal)

	self.__remote.Destroying:Once(function()
		self.__signal:Destroy()
		table.clear(self)
		setmetatable(self, nil)
	end)

	wrapSignalConnectFn(self.__signal) --GENIUS OF UNIMAGINABLE LEVELS
	if RunService:IsServer() then
        self.__signal.Connected:Once(function()
			self.__remote.OnServerEvent:Connect(function(player, ...)
				applyMiddlewareServer(self.InboundMiddleware, player, ...):andThen(function(args)
					self.__signal:Fire(player, unpack(args))
				end)
			end)
		end)
	elseif RunService:IsClient() then
		self.__signal.Connected:Once(function()
			self.__remote.OnClientEvent:Connect(function(...)
				applyMiddlewareClient(self.InboundMiddleware, ...):andThen(function(args)
					self.__signal:Fire(unpack(args))
				end)
			end)
		end)
	end

	return self
end

return NetworkSignal
