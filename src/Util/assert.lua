local function assert<A>(value: A, errorMessage: string, ...: string): A?
	if value then return value end
	if errorMessage then
		return error(string.format(errorMessage, ...))
	else
		return error("assertion failed!")
	end
end

return assert