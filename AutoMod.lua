
local log = FH3095Debug.log
local RCE = RepeatableCalendarEvents

local AutoMod = {}
RCE.Class:createSingleton("autoMod", AutoMod, {queue = RCE.List.new(), currentEvent = nil, autoModChars = nil})

local function splitStringToArray(array)
	local ret = {}
	if array == nil then
		return ret
	end

	for m in array:gmatch("%S+") do
		if m:trim() ~= "" then
			tinsert(ret, m)
		end
	end

	return ret
end

function AutoMod:enqueueNextEvent()
	if self.queue:isEmpty() then
		RCE.console:Printf("%s: %s", RCE.consts.ADDON_NAME_COLORED, RCE.l.CalendarUpdateFinished)
		return
	end

	local nextEvent = self.queue:pop()
	RCE.core:setCalendarMonthToDate(nextEvent.year, nextEvent.month)
	log("CheckAutoMod: Enqueue Event", nextEvent.year, nextEvent.month, nextEvent.day, nextEvent.index)
	self.currentEvent = nextEvent
	RCE.workQueue:addTask(function() C_Calendar.OpenEvent(0, nextEvent.day, nextEvent.index) end, nil, 1)
	RCE.workQueue:addTask(function() self:parseEvent() end, "CALENDAR_OPEN_EVENT")
end

function AutoMod:parseEvent()
	-- CALENDAR_OPEN_EVENT sometimes fires twice, so check that currentEvent is set and reset after the check
	if self.currentEvent == nil then
		return
	end
	self.currentEvent = nil
	log("AutoMod.parseEvent")
	if C_Calendar.EventCanEdit() then
		local toCheckEvent = C_Calendar.GetEventInfo()
		log("AutoMod.parseEvent: Check event", toCheckEvent.title, toCheckEvent.time.monthDay, toCheckEvent.time.month, toCheckEvent.time.year, toCheckEvent.time.hour, toCheckEvent.time.minute)
		local numInvitees = C_Calendar.GetNumInvites()
		for inviteeIndex=1,numInvitees do
			local inviteInfo = C_Calendar.EventGetInvite(inviteeIndex)
			local charName = inviteInfo.name
			if charName ~= nil then
				if not charName:find("-", 1, true) then
					charName = charName .. "-" .. GetRealmName()
				end
				if (inviteInfo.modStatus == nil or inviteInfo.modStatus == "") and tContains(self.autoModChars, charName) then
					log("AutoMod.parseEvent: Set Mod", charName, inviteeIndex)
					C_Calendar.EventSetModerator(inviteeIndex)
				end
			end
		end
	end
	C_Calendar.CloseEvent()

	RCE.workQueue:addTask(function() self:enqueueNextEvent() end, nil, 1)
end

function AutoMod:execute()
	self.autoModChars = splitStringToArray(RCE.db.profile.autoModNames)
	log("CheckAutoMod", self.autoModChars)

	local dateTable = date("*t")

	for futureDays=1,RCE.db.profile.eventsInFuture do
		RCE.core:setCalendarMonthToDate(dateTable)
		local numEvents = C_Calendar.GetNumDayEvents(0, dateTable.day)
		for eventIndex=1,numEvents do
			local otherEvent = C_Calendar.GetDayEvent(0, dateTable.day, eventIndex)
			if otherEvent.modStatus == "CREATOR" and (otherEvent.calendarType == "GUILD_EVENT" or otherEvent.calendarType == "PLAYER") then
				local event = {day = dateTable.day, month = dateTable.month, year = dateTable.year, index = eventIndex}
				self.queue:push(event)
			end
		end
		dateTable.day = dateTable.day + 1
		dateTable = RCE.core:normalizeDateTable(dateTable)
	end

	self:enqueueNextEvent()
end
