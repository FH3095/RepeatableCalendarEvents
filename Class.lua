
local RCE = RepeatableCalendarEvents
local ClassHelper = {}
RCE.Class = ClassHelper

function ClassHelper:createClass(className, class, newFunction)
	RCE[className] = {}
	RCE[className].new = newFunction
	class.__index = class
	return RCE[className]
end

function ClassHelper:createSingleton(className, class, initData)
	RCE[className] = {}
	class.__index = class
	local instance = self:createObject(class, initData)
	RCE[className] = instance
	return instance
end

function ClassHelper:createObject(class, initData)
	if initData == nil then
		initData = {}
	end
	setmetatable(initData, class)
	return initData
end
