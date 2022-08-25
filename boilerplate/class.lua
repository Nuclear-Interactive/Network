export type Class = {}

local Class: Class = {}
Class.__index = Class

function Class.new(): Class
    local self = setmetatable({}, Class)
    return Class
end

return Class