
local log = FH3095Debug.log
local RCE = RepeatableCalendarEvents

local WQ = {}
RCE.Class:createSingleton("workQueue", WQ, {runningTimer = nil, queue = RCE.List.new()})

function WQ:prepareNextTask()
	local elem = self.queue:peek()
	if elem.event then
		RCE.events:RegisterEvent(elem.event, function()
			log("WorkQueue:RegisterForEvent", elem.event)
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
	if self.queue:isEmpty() then
		return -- ClearTasks was called between prepareNextTask and runTask
	end

	local elem = self.queue:pop()
	log("WorkQueue:runTask", elem.event, elem.delay)
	elem.func()

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
