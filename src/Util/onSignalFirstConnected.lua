local Packages = script.Parent.Parent.Parent

local FastSignal = require(Packages.FastSignal)
type FastSignal = FastSignal.Class
type FastConnection = FastSignal.ScriptConnection

local function onSignalFirstConnected<A...>(signal: FastSignal, fn: (A...) -> (), ...: A...)
    local connectFn = signal.Connect
    signal.Connect = function(...)
        signal.Connect = nil
        task.spawn(fn)
        return connectFn(...)
    end
end

return onSignalFirstConnected