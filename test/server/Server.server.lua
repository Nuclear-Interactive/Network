local Players = game:GetService("Players")

local Packages = game.ReplicatedStorage.Packages
local Network = require(Packages.Network):GetServer()
local Promise = Network.getPromise()

local Net = Network.new("Net")
local Signal = Net:CreateSignal("Signal")
local Func = Net:CreateFunction("Func")
local Queue = Net:CreateSignal("Queue")

Signal:Connect(function(player, message: string)
    print("[NETWORKSIGNAL SERVER]", player.DisplayName, ":", message)
end)

Func:SetCallback(function(player)
    return "NETWORKFUNCTION SERVER RESPONSE"
end)

Players.PlayerAdded:Connect(function(player)
    Signal:FireClient(player, "Hello")
    Func:InvokeClientPromise(player):andThen(function(...)
        print(...)
    end)

    for i = 1, 10 do
        Queue:FireClient(player, i)
    end
    task.wait(10)
    print("fart 2")
    Queue:FireClient(player, 11)
end)