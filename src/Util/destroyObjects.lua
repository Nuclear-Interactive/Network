local function destroyObjects<k,v>(self: {[k]: v}, onDestroy: (key: k) -> (...any))
    for key, object in pairs(self) do
        if typeof(object) == "table" and typeof(object.Destroy) == "function" then
            object:Destroy()
            if onDestroy then onDestroy(key) end
        end
    end
end

return destroyObjects