
local log = FH3095Debug.log
local RCE = RepeatableCalendarEvents

local WQ = {}
local function newWorkQueue()
	return RCE.Class:createObject(WQ, {runningTimer = nil, queue = RCE.List.new()})
end
RCE.Class:createClass("WorkQueue", WQ, newWorkQueue)

function WQ:prepareNextTask()
	local elem = self.queue:peek()
	if elem.event then
		log("WorkQueue:RegisterForEvent", elem.event, elem.delay)
		RCE.events:RegisterEvent(elem.event, function()
			log("WorkQueue:EventFired", elem.event, elem.delay)
			RCE.events:UnregisterEvent(elem.event)
			self.runningTimer = RCE.timers:ScheduleTimer(function() self:runTask() end, elem.delay)
		end)
	else
		self.runningTimer = RCE.timers:ScheduleTimer(function() self:runTask() end, elem.delay)
	end
end

function WQ:addTask(funcToCall, waitForEvent, delay)
	if delay == nil then
		delay = 0.1
	end
	local queueWasEmpty = self.queue:isEmpty()
	local elem = {func = funcToCall, event = waitForEvent, delay = delay}
	log("WorkQueue:addTask", elem.event, elem.delay, queueWasEmpty)
	self.queue:push(elem)

	if queueWasEmpty then
		self:prepareNextTask()
	end
end

function WQ:runTask()
	local elem = self.queue:peek()
	log("WorkQueue:runTask", elem.event, elem.delay)
	elem.func()
	self.queue:pop() -- if elem.func() adds elements to the queue, we have to behave as if the queue is not empty. So remove queue element AFTER elem.func()

	if not self.queue:isEmpty() then
		self:prepareNextTask()
	else
		self.runningTimer = nil
	end
end

function WQ:clearTasks()
	if self.queue:isEmpty() then
		return -- Nothing to do
	end
	local elem = self.queue:pop()
	log("WorkQueue:clearTasks", elem.event, self.runningTimer, RCE.timers:TimeLeft(self.runningTimer))

	if self.runningTimer then
		RCE.timers:CancelTimer(self.runningTimer)
	end

	if elem.event then
		RCE.events:UnregisterEvent(elem.event)
	end

	self.queue:clear()
end
