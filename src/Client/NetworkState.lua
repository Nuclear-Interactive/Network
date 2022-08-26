export type NetworkState = {}

local NetworkState: NetworkState = {}
NetworkState.__index = NetworkState

function NetworkState.new(): NetworkState
    local self = setmetatable({}, NetworkState)
    return NetworkState
end

return NetworkState