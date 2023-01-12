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
    Middleware: {
        Inbound: {(args: {any}) -> Promise};
        Outbound: {(args: {any}) -> Promise};
    };

	__remote: RemoteFunction;
	__function: Callback;

    SetCallback: (self: NetworkFunction, callback: Callback) -> ();
    InvokeServer: (self: NetworkFunction, any...) -> (...any);

	Destroy: (self: NetworkFunction) -> ();
}

local NetworkFunction: NetworkFunction = {}
NetworkFunction.__index = NetworkFunction

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

local function invokeServer(self: NetworkFunction, ...)
    local args = {...}
    return Promise.new(function(resolve, reject)
        if #self.Middleware.Inbound > 0 or #self.Middleware.Outbound > 0 then
            local outSuccess, outArgs = applyMiddleware(self.Middleware.Outbound, unpack(args)):await()
            if not outSuccess then reject(outArgs) return end
            local inSuccess, inArgs = applyMiddleware(self.Middleware.Inbound, self.__remote:InvokeServer(unpack(outArgs))):await()
            if not inSuccess then reject(inArgs) return end
            resolve(unpack(inArgs))
        else
            resolve(self.__remote:InvokeServer(unpack(args)))
        end
    end)
end

local function onClientInvoke(self: NetworkFunction, ...)
    if #self.Middleware.Inbound > 0 or #self.Middleware.Outbound > 0 then
        local inSuccess, inArgs = applyMiddleware(self.Middleware.Inbound, ...):await()
        if not inSuccess then return end
        local outSuccess, outArgs = applyMiddleware(self.Middleware.Outbound, self.__function(unpack(inArgs))):await()
        if not outSuccess then return end
        return unpack(outArgs)
    else
        return self.__function(...)
    end
end

function NetworkFunction.__function(player: Player)
    return
end

function NetworkFunction:SetCallback(callback: Callback)
    self.__function = callback
    self.CallbackSet:Fire(callback)
end

function NetworkFunction:InvokeServer(...: any)
    local result = {invokeServer(self, ...):await()}
    return unpack(result, 2, #result)
end

function NetworkFunction:Destroy()
    self.__remote:Destroy()
end

function NetworkFunction.new(name: string, remote: RemoteFunction): NetworkFunction
    local self = setmetatable({
        Name = name;
        CallbackSet = FastSignal.new();
        Middleware = {
            Inbound = {};
            Outbound = {};
        };

        __remote = remote;
    }, NetworkFunction)

    self.__remote.Destroying:Once(function()
        self.CallbackSet:Destroy()
        table.clear(self)
        setmetatable(self, nil)
    end)

    self.CallbackSet:Once(function()
        self.__remote.OnClientInvoke = function(...)
            return onClientInvoke(self, ...)
        end
    end)

    return self
end

return NetworkFunction