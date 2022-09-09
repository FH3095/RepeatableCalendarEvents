local log = FH3095Debug.log
local RCE = RepeatableCalendarEvents

local TYPE = {}
TYPE.FUNC = "func"
TYPE.EVENT = "event"

local WorkList = {
    work = RCE.classes.List(),
    eventOccured = false,
    current = nil,
    timer = nil,
}
RCE.work = WorkList

local unpack = unpack
local function pack(...)
    local result = { ... }
    result.n = select("#", ...)
    return result
end

function WorkList:add(arg1, arg2, arg3, ...)
    local wasEmpty = self.work:isEmpty() and self.current == nil
    if type(arg3) == "function" then
        if type(arg1) ~= "string" or type(arg2) ~= "number" then
            error("For functions, args must be string and number " .. type(arg1) .. " " .. type(arg2))
        end
        local functionParams = pack(...)
        local runFunction = function()
            arg3(unpack(functionParams, 1, functionParams.n))
        end
        log("WorkList:add", arg1, TYPE.FUNC)
        self.work:push({ type = TYPE.FUNC, name = arg1, delay = arg2, func = runFunction })
    else
        if type(arg1) ~= "string" or (type(arg2) ~= "number" and type(arg2) ~= "nil") or type(arg3) ~= "boolean" then
            error("For events, args must be string and (number or nil) and boolean " ..
                type(arg1) .. " " .. type(arg2) .. " " .. type(arg3))
        end
        if wasEmpty or ((not self.work:isEmpty()) and self.work:peekLast().type == TYPE.EVENT) then
            error("You cant chain event-work and event-work cant be first work " .. arg1)
        end
        if arg2 == nil or arg2 < 1 then
            arg2 = RCE.consts.WORK_EVENT_DEFAULT_WAIT_TIME
        end
        log("WorkList:add", arg1, TYPE.EVENT)
        self.work:push({ type = TYPE.EVENT, name = arg1, delay = arg2, forceWait = arg3 })
    end
    if wasEmpty then
        self:runNext()
    end
end

function WorkList:_checkEventOccured()
    if self.current ~= nil and self.current.type == TYPE.EVENT and not self.eventOccured then
        RCE.events:UnregisterEvent(self.current.name)
        RCE.core:printError("Event %s didn't occure.", self.current.name)
        self:clear()
    end
end

function WorkList:_eventFunc(event)
    log("WorkList:_eventFunc", event, self.current.forceWait)
    self.eventOccured = true
    RCE.events:UnregisterEvent(event)
    if (not self.current.forceWait) and self.timer and RCE.timers:TimeLeft(self.timer) > 0 then
        log("WorkList:_eventFunc", "Now run next")
        RCE.timers:CancelTimer(self.timer)
        RCE.timers:ScheduleTimer(self.runNext, 1, self)
    end
end

function WorkList:runNext()
    self:_checkEventOccured()
    if self.work:isEmpty() then
        self:clear()
        return
    end

    self.eventOccured = false
    self.forceWaitForTimer = true

    local next = self.work:pop()
    self.current = next
    if next.type == TYPE.FUNC then
        local delay = next.delay
        local next2 = (not self.work:isEmpty()) and self.work:peek() or nil
        log("WorkList:runNext", next.type, next.name, next2 and next2.type, next2 and next2.name)
        -- delay is < 0 if we should not automatically call runNext but wait for a call from elsewhere
        if delay >= 0 and next2 ~= nil and next2.type == TYPE.EVENT then
            RCE.events:RegisterEvent(next2.name, self._eventFunc, self)
            delay = delay + next2.delay
            self.current = next2
            self.work:pop()
        end
        if delay >= 0 then
            self.timer = RCE.timers:ScheduleTimer(self.runNext, delay, self)
        end
        next.func()
    elseif next.type == TYPE.EVENT then
        log("WorkList:runNext", next.type, next.name)
        RCE.events:RegisterEvent(next.name, self._eventFunc, self)
        self.timer = RCE.timers:ScheduleTimer(self.runNext, next.delay, self)
    else
        error("Unknown type " .. next.type)
    end
end

function WorkList:clear()
    log("WorkList:clear", self.current, self.work)
    self.eventOccured = false
    self.current = nil
    self.work:clear()
end
