local Handler = {}

function Handler:GetServer()
    return require(script.Server)
end

function Handler:GetClient()
    return require(script.Client)
end

return Handler