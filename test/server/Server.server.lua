local Players = game:GetService("Players")

local Packages = game.ReplicatedStorage.Packages
local Network = require(Packages.Network.Server)

local Net = Network.new("Net")
local Signal = Net:CreateSignal("Signal")
local Func = Net:CreateFunction("Func")

Signal:Connect(function(player, message: string)
    print(player.DisplayName, ":", message)
end)

Func:SetCallback(function(player)
    return "HI BRO!"
end)

Players.PlayerAdded:Connect(function(player)
    Signal:FireClient(player, "Hello")
    print(Func:InvokeClient(player))
end)