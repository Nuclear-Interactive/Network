local Packages = game.ReplicatedStorage.Packages
local Network = require(Packages.Network.Client)

local Net = Network.new("Net")
local Signal = Net:GetSignal("Signal")
local Func = Net:GetFunction("Func")

Signal:Connect(function(message: string)
    print("Server :", message)
end)

Func:SetCallback(function()
    return "HELLO TOO BRO!"
end)

Signal:FireServer("Hi")
print(Func:InvokeServer())