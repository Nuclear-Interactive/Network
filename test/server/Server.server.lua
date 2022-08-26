local Packages = game.ReplicatedStorage.Packages
local Network = require(Packages.Network.Server)

local Net = Network.new("Net")
local Signal = Net:CreateSignal("Signal")

Signal:Connect(function(player, message: string)
    print(player.DisplayName, ":", message)
end)