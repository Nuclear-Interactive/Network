local function applyToChildren(parent: Instance, handler: (child: Instance) -> ()): RBXScriptConnection
    local connection = parent.ChildAdded:Connect(handler)
    for _, child in pairs(parent:GetChildren()) do
        task.spawn(handler, child)
    end
    return connection
end

return applyToChildren