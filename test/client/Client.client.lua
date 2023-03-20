local Packages = game.ReplicatedStorage.Packages
local Network = require(Packages.Network):GetClient()
local Promise = Network.getPromise()

local Net = Network.new("Net")
local Signal = Net:GetSignal("Signal")
local Func = Net:GetFunction("Func")
local Queue = Net:GetSignal("Queue")

Signal:Connect(function(message: string)
    print("[NETWORKSIGNAL CLIENT] Server :", message)
end)

Func:SetCallback(function()
    return "NETWORKFUNCTION CLIENT RESPONSE"
end)

Signal:FireServer("Hi")
print(Func:InvokeServer())

task.wait(2.5)
print("fart")
Queue:Once(function(...)
    print(..., "ONCE")
    Queue:Connect(function(...)
        print(...)
    end)
end)

task.wait(0.5)
print("fart 2")
Queue:Once(function(...)
    print(..., "ONCE")
end)