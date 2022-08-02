local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Packages = game.ReplicatedFirst.Packages

local FastSignal = require(Packages.FastSignal)
type FastSignal = FastSignal.Class
type FastConnection = FastSignal.ScriptConnection

local Promise = require(Packages.Promise)
type Promise = typeof(require(Promise.new()))

export type ServerMiddlewareFn = (player: Player, args: {any}) -> Promise
export type ServerMiddleware = {[number]: ServerMiddlewareFn};

export type ClientMiddlewareFn = (args: {any}) -> Promise
export type ClientMiddleware = {[number]: ClientMiddlewareFn};

type ServerCallback = (player: Player, any...) -> (...any)
export type NetworkFunctionServer = {
	Name: string;
    InboundMiddleware: ServerMiddleware;
	OutboundMiddleware: ServerMiddleware;

	__remote: RemoteFunction;
	__function: ServerCallback;

    CallbackSet: FastSignal & {
        Connect: (self: FastSignal, handler: (callback: ServerCallback) -> () ) -> FastConnection;
        Wait: (self: FastSignal) -> ServerCallback;
    };

    SetCallback: (self: NetworkFunctionServer, callback: ServerCallback) -> ();
    InvokeClient: (self: NetworkFunctionServer, player: Player, any...) -> (...any);
    InvokeClientPromise: (self: NetworkFunctionServer, player: Player, any...) -> Promise;

	Destroy: (self: NetworkFunctionServer) -> ();
}

type ClientCallback = (any...) -> (...any)
export type NetworkFunctionClient = {
	Name: string;
	InboundMiddleware: ClientMiddleware;
	OutboundMiddleware: ClientMiddleware;

	__remote: RemoteFunction;
	__function: ClientCallback;

    CallbackSet: FastSignal & {
        Connect: (self: FastSignal, handler: (callback: ClientCallback) -> () ) -> FastConnection;
        Wait: (self: FastSignal) -> ClientCallback;
    };

    SetCallback: (self: NetworkFunctionClient, callback: ClientCallback) -> ();
    InvokeServer: (self: NetworkFunctionClient, any...) -> (...any);
    InvokeServerPromise: (self: NetworkFunctionClient, any...) -> Promise;

	Destroy: (self: NetworkFunctionClient) -> ();
}

export type Middleware = ServerMiddleware & ClientMiddleware
export type ServerClass = NetworkFunctionServer
export type ClientClass = NetworkFunctionClient
export type NetworkFunction = NetworkFunctionServer & NetworkFunctionClient

local NetworkFunction: NetworkFunction = {}
NetworkFunction.__index = NetworkFunction

local unpack = table.unpack

local function clientOnly()
	assert(RunService:IsClient())
end

local function serverOnly()
	assert(RunService:IsServer())
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

local function invokeClient(self: NetworkFunctionServer, player, ...)
    local args = {...}
    return Promise.new(function(resolve, reject)
        if #self.InboundMiddleware > 0 or #self.OutboundMiddleware > 0 then
            local outSuccess, outArgs = applyMiddlewareServer(self.OutboundMiddleware, player, unpack(args)):await()
            if not outSuccess then reject(outArgs) return end
            local inSuccess, inArgs = applyMiddlewareServer(self.InboundMiddleware, player, self.__remote:InvokeClient(player, unpack(outArgs))):await()
            if not inSuccess then reject(inArgs) return end
            resolve(unpack(inArgs))
        else
            resolve(unpack(args))
        end
    end)
end

local function invokeServer(self: NetworkFunctionClient, ...)
    local args = {...}
    return Promise.new(function(resolve, reject)
        if #self.InboundMiddleware > 0 or #self.OutboundMiddleware > 0 then
            local outSuccess, outArgs = applyMiddlewareClient(self.OutboundMiddleware, unpack(args)):await()
            if not outSuccess then reject(outArgs) return end
            local inSuccess, inArgs = applyMiddlewareClient(self.InboundMiddleware, self.__remote:InvokeServer(unpack(outArgs))):await()
            if not inSuccess then reject(inArgs) return end
            resolve(unpack(inArgs))
        else
            resolve(self.__remote:InvokeServer(unpack(args)))
        end
    end)
end

local function onServerInvoke(self: NetworkFunctionServer, player: Player, ...)
    if #self.InboundMiddleware > 0 or #self.OutboundMiddleware > 0 then
        local inSuccess, inArgs = applyMiddlewareServer(self.InboundMiddleware, player, ...):await()
        if not inSuccess then return end
        local outSuccess, outArgs = applyMiddlewareServer(self.OutboundMiddleware, player, self.__function(player, unpack(inArgs))):await()
        if not outSuccess then return end
        return unpack(outArgs)
    else
        return self.__function(player, ...)
    end
end

local function onClientInvoke(self: NetworkFunctionClient, ...)
    if #self.InboundMiddleware > 0 or #self.OutboundMiddleware > 0 then
        local inSuccess, inArgs = applyMiddlewareClient(self.InboundMiddleware, ...):await()
        if not inSuccess then return end
        local outSuccess, outArgs = applyMiddlewareServer(self.OutboundMiddleware, self.__function(unpack(inArgs))):await()
        if not outSuccess then return end
        return unpack(outArgs)
    else
        return self.__function(...)
    end
end

-- SHARED --

function NetworkFunction.__function(...)
    return
end

function NetworkFunction:SetCallback(callback: ServerCallback | ClientCallback)
    self.__function = callback
    self.CallbackSet:Fire(callback)
end

function NetworkFunction:Destroy()
    self.__remote:Destroy()
end

-- SERVER --

function NetworkFunction:InvokeClient(player: Player, ...: any): (...any)
    serverOnly()
    local result = {invokeClient(self, ...):await()}
    return unpack(result, 2, #result)
end

function NetworkFunction:InvokeClientPromise(player: Player, ...: any): Promise
    serverOnly()
    return invokeClient(self, player, ...)
end

-- CLIENT --

function NetworkFunction:InvokeServer(...: any): (...any)
    clientOnly()
    local result = {invokeServer(self, ...):await()}
    return unpack(result, 2, #result)
end

function NetworkFunction:InvokeServerPromise(...: any): Promise
    clientOnly()
    return invokeServer(self, ...)
end

function NetworkFunction.new(name: string, remote: RemoteFunction,  inboundMiddleware: Middleware?, outboundMiddleware: Middleware?): NetworkFunction
    local self = setmetatable({
        Name = name;
        __remote = remote;
        CallbackSet = FastSignal.new();
        InboundMiddleware = inboundMiddleware or {};
		OutboundMiddleware = outboundMiddleware or {};
    }, NetworkFunction)

    self.__remote.Destroying:Once(function()
        self.__function = nil
        table.clear(self)
        setmetatable(self, nil)
    end)

    if RunService:IsServer() then
        self.CallbackSet:Once(function()
            self.__remote.OnServerInvoke = function(player, ...)
                return onServerInvoke(self, player, ...)
            end
        end)
    else
        self.CallbackSet:Once(function()
            self.__remote.OnClientInvoke = function(...)
                return onClientInvoke(self, ...)
            end
        end)
    end

    return self
end

return NetworkFunction