local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Util = script.Parent.Parent.Util
local Packages = script.Parent.Parent.Parent

local assert = require(Util.assert)

local FastSignal = require(Packages.FastSignal)
type FastSignal = FastSignal.Class
type FastConnection = FastSignal.ScriptConnection

local Promise = require(Packages.Promise)
type Promise = typeof(Promise.new())

export type NetworkSignal = {
    Name: string;

    __remote: RemoteEvent;
    __signal: FastSignal;

    Connect: () -> ();
    Once: () -> ();
    Wait: () -> ();

    FireClient: () -> ();
    FireAllClients: () -> ();

    Destroy: (self: NetworkSignal) -> ();
}

local NetworkSignal: NetworkSignal = {}
NetworkSignal.__index = NetworkSignal

function NetworkSignal.new(name: string, remote: RemoteEvent): NetworkSignal
    local self = setmetatable({}, NetworkSignal)
    return NetworkSignal
end

return NetworkSignal