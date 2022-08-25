export type NetworkFunction = {}

local NetworkFunction: NetworkFunction = {}
NetworkFunction.__index = NetworkFunction

function NetworkFunction.new(): NetworkFunction
    local self = setmetatable({}, NetworkFunction)
    return NetworkFunction
end

return NetworkFunction