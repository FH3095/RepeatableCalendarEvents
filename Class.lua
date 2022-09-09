local RCE = RepeatableCalendarEvents

local ClassHelper = {}
local classRegistry = {}
RCE.Class = ClassHelper
RCE.classes = classRegistry

function ClassHelper:createClass(className, newFunction)
	classRegistry[className] = newFunction
end

function ClassHelper:createObject(class, initData)
	if class == nil then
		error("Missing class")
	end
	if initData == nil then
		initData = {}
	end
	setmetatable(initData, { __index = class })
	return initData
end
