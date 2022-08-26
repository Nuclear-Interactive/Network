local Packages = game.ReplicatedStorage.Packages
local Network = require(Packages.Network.Client)

local Net = Network.new("Net")
local Signal = Net:GetSignal("Signal")

Signal:FireServer("Hi")