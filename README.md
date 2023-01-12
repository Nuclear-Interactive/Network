# Network
  - [Changelog](CHANGELOG.md)
  - [Features](#features)
  - [Installation](#installation)
  - [Example Usage](#example-usage)
  - [Prior Art](#prior-art)

## About
A Roblox networking library with a goal of making networking easier on VS Code while having a familiar API. <br/>

## Features
- Similar API to default Roblox Remotes
- Middlewares for Serialization and Deserialization operations
- Promise alternative to yielding methods eg. `:Wait()` to `:WaitPromise()` (Not yet implemented)

## Installation
### Via Wally
```toml
Network = "synthranger/network@1.2.0"
```

## Example Usage
Network has a familiar API similar to the default Roblox Remotes so users will have the least amount of issues transitioning to this library.

#### Importing
Keep in mind the client and the server has completely different modules so you have to specify it while requiring each module.

*Assuming Packages variable is already defined*
```lua
-- SERVER
local Network = require(Packages.Network.Server)
```
```lua
-- CLIENT
local Network = require(Packages.Network.Client)
```

#### Class Creation
The Server is the only one who is authorized to create classes, the Client's job is only to have a copy of the Server's classes on their end.
```lua
-- SERVER
local Net = Network.new("Net")
local Signal = Net:CreateSignal("Signal")
local Function = Net:CreateFunction("Function")
```
The Client's Network constructor only creates a copy of the Network on their end and does not actually create a new Network class. Trying to construct a Network on the Client that does not exist on the Server will error.
```lua
-- CLIENT
local Net = Network.new("Net")
local Signal = Net:GetSignal("Signal")
local Function = Net:GetSignal("Function")
```

#### Network Usage
```lua
-- SERVER or CLIENT
-- Incase you forgot who Signal is
Net:GetSignal("Signal")
-- Returns a NetworkSignal if it is attached to one
Net:GetSignalWithRemote(Signal.__remote)
-- Equivalent for NetworkFunctions
Net:GetFunction("Function")
Net:GetFunctionWithRemote(Function.__remote)
```

#### NetworkSignal Usage
```lua
-- SERVER
-- NetworkSignals act like RBXScriptSignals
Signal:Connect(function(player)
    print(player.Name.." has fired this signal!")
end)
-- Similar API with RemoteEvents
Signal:FireClient(somePlayer)
Signal:FireAllClients("Hi clients!")
Signal:WaitPromise() -- Promise alternative to :Wait()

-- Utility methods for less boilerplate
Signal:FireClients({somePlayer, otherPlayer})
Signal:FireAllClientsExcept({otherPlayer})
Signal:FireAllClientsFilter(function(player)
    return player ~= otherPlayer
end)
```
```lua
-- CLIENT
Signal:FireServer("What's popping Server!")
```

#### NetworkFunction Usage
```lua
-- SERVER
-- Slight difference in API
Function:SetCallback(function(player)
    return "Hi "..player.Name..", this is a message returned by the server."
end)
-- Promise alternative for :InvokeClient(player)
Function:InvokeClientPromise(somePlayer):andThen(function(message)
    print(message)
end)
```
```lua
-- CLIENT
Function:SetCallback(function()
    return "Hi "..player.Name..", this is a message returned by the client."
end)
```

#### Middlewares
Since middlewares use promises, Network has a helper function to get the Promise library so you don't have to import it yourself.
```lua
local Network = require(Packages.Network.Server)
local Promise = Network.getPromise()
```

#### NetworkSignal Middlewares
Example of serialization and deserialization using middlewares with NetworkSignals.
```lua
-- SERVER
local function serialize(args)
    -- some serialization algorithm
    return serializedArgs
end

Signal.OutboundMiddleware[1] = function(player, args)
    return Promise.new(function(resolve, reject)
        if player == somePlayer then
            -- resolve(shouldContinue: boolean, args: {any})
            resolve(
                true, -- Set first argument to true to continue transforming args with next middleware
                {serialize(args)} -- The args, serialize(args) is now the first argument
            )
        else
            -- Reject to drop, will not fire connections
            reject()
        end
    end)
end
```
```lua
local function deserialize(args)
    -- some deserialization algorithm
    return deserializedArgs
end

-- CLIENT
Signal.InboundMiddleware[1] = function(args)
    return Promise.new(function(resolve, reject)
        resolve(
            true, 
            {deserialize(args[1])} -- since the serialized data is the 1st argument, we index it and deserialize it
        )
    end)
end
```

#### NetworkFunction Middlewares
Example of serialization and deserialization using middlewares with NetworkFunctions.
```lua
-- SERVER
Function.OutboundMiddleware[1] = function(player, args)
    -- reject will cause return arguments to be nil 
    -- so it doesn't get used as much in here
    return Promise.new(function(resolve)
        resolve(true, {"I replaced an argument", "I replaced another argument"})
    end)
end
```
```lua
-- CLIENT
Function.InboundMiddleware[1] = function(args)
    return Promise.new(function(resolve)
        resolve(true, {"This replaced the first argument", "Another replacement argument"})
    end)
end
```

## Prior Art
- sleitnick's [Comm](https://sleitnick.github.io/RbxUtil/api/Comm/).