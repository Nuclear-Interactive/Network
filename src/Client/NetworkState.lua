local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Util = script.Parent.Parent.Util
local Packages = script.Parent.Parent.Parent

local assert = require(Util.assert)

local RESTRICTED_BASICSTATE_METHODS = {
    ["Set"] = true;
    ["SetState"] = true;
    ["Reset"] = true;
    ["Delete"] = true;
    ["Toggle"] = true;
    ["Increment"] = true;
    ["Decrement"] = true;
    ["RawSet"] = true;
}

local FastSignal = require(Packages.FastSignal)
type FastSignal = FastSignal.Class
type FastConnection = FastSignal.ScriptConnection

local BasicState = require(Packages.BasicState)
type BasicState = typeof(BasicState.new())

local Janitor = require(Packages.Janitor)
type Janitor = typeof(Janitor.new())

local Promise = require(Packages.Promise)
type Promise = typeof(Promise.new())

local NetworkSignal = require(script.Parent.NetworkSignal)
local NetworkFunction = require(script.Parent.NetworkFunction)
type NetworkSignal = NetworkSignal.NetworkSignal
type NetworkFunction = NetworkFunction.NetworkFunction

type ReplicationType = "All" | {Player}
export type NetworkState = {
    Name: string;
    Replication: ReplicationType;

    __state: BasicState;
    __janitor: Janitor;

    Changed: RBXScriptSignal;

    Get: (self: NetworkState, DefaultValue: any) -> any;
    GetState: (self: NetworkState) -> {[string]: any};
    GetChangedSignal: (self: NetworkState, Key: any) -> RBXScriptSignal;
    Destroy: (self: NetworkState) -> ();
    Roact: (self: NetworkState) -> ();
}

local NetworkState: NetworkState = setmetatable({}, BasicState)
NetworkState.__index = NetworkState

local function restrictMethod(object: {any}, name: string, errorMessage: string, ...: string)
    local originalMethod = object[name]
    local message = string.format(errorMessage, ...)
    local function newMethod()
        return error(message)
    end
    object[name] = newMethod()
    return originalMethod
end

function NetworkState:Destroy()
    self.__state:Destroy()
    self.__janitor:Destroy()
    table.clear(self)
    setmetatable(self, nil)
end

function NetworkState.new(name: string, replication: ReplicationType, network): NetworkState
    local changedSignal: NetworkSignal = network:GetSignal(name.."_".."Changed")
    local getFunction: NetworkFunction = network:GetFunction(name.."_".."Get")

    local state = BasicState.new(getFunction:InvokeServer())
    local self = setmetatable(state, NetworkState)

    self.Name = name
    self.Replication = replication

    self.__state = state
    self.__janitor = Janitor.new()
    self.__network = network

    self.__janitor:Add(changedSignal, "Destroy")
    self.__janitor:Add(getFunction, "Destroy")

    for methodName in pairs(RESTRICTED_BASICSTATE_METHODS) do
        restrictMethod(self, methodName, "Method %s is not allowed on the Client.", methodName)
    end

    changedSignal:Connect(function(key, value)
        self.__state:Set(key, value)
    end)

    return self
end

return NetworkState