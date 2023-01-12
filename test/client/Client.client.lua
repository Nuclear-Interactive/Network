local Packages = game.ReplicatedStorage.Packages
local Network = require(Packages.Network.Client)
local Promise = Network.getPromise()

local Net = Network.new("Net")
local Signal = Net:GetSignal("Signal")
local Func = Net:GetFunction("Func")

Signal:Connect(function(message: string)
    print("[NETWORKSIGNAL CLIENT] Server :", message)
end)

Func:SetCallback(function()
    return "NETWORKFUNCTION CLIENT RESPONSE"
end)

Signal:FireServer("Hi")
print(Func:InvokeServer())