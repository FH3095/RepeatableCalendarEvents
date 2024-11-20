FH3095Debug = {
	logFrame = nil,
}


local objToStringHelper = nil

local function objToString(obj)
	if type(obj) == "table" then
		local s = "{ "
		for k, v in pairs(obj) do
			if type(k) == "table" then
				k = '"TableAsKey"'
			elseif type(k) ~= "number" then
				k = '"' .. k .. '"'
			end

			if not objToStringHelper[v] then
				if type(v) == "table" then
					objToStringHelper[v] = true
				end
				s = s .. "[" .. k .. "] = " .. objToString(v) .. ','
			end
		end
		return s .. "} "
	else
		return tostring(obj)
	end
end

function FH3095Debug.log(str, ...)
	if FH3095Debug.logFrame == nil then
		return
	end

	objToStringHelper = {}
	str = str .. ": "
	for i = 1, select('#', ...) do
		local val = select(i, ...)
		str = str .. objToString(val) .. " ; "
	end

	for i = 1, #str, 4000 do
		FH3095Debug.logFrame:AddMessage(str:sub(i, i + 4000 - 1))
	end
end

function FH3095Debug.onEnable()
	for i = 1, NUM_CHAT_WINDOWS do
		local frameName = GetChatWindowInfo(i)
		if frameName == "Debug" then
			FH3095Debug.logFrame = _G["ChatFrame" .. i]
			return
		end
	end
end

function FH3095Debug.isEnabled()
	return FH3095Debug.logFrame ~= nil
end
