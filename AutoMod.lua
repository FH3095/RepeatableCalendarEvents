local log = FH3095Debug.log
local RCE = RepeatableCalendarEvents

local AutoMod = {
	queue = RCE.classes.List(),
	currentEvent = nil,
}
RCE.autoMod = AutoMod

function AutoMod:enqueueNextEvent()
	if self.queue:isEmpty() then
		Calendar_Hide()
		RCE.console:Printf("%s: %s", RCE.consts.ADDON_NAME_COLORED, RCE.l.CalendarUpdateFinished)
		return
	end

	local nextEvent = self.queue:pop()
	RCE.core:setCalendarMonthToDate(nextEvent.year, nextEvent.month)
	log("CheckAutoMod: Enqueue Event", nextEvent.year, nextEvent.month, nextEvent.day, nextEvent.index)
	self.currentEvent = nextEvent
	RCE.work:add("Open Event", 0, function() C_Calendar.OpenEvent(0, nextEvent.day, nextEvent.index) end)
	RCE.work:add("CALENDAR_OPEN_EVENT", nil, false)
	RCE.work:add("Parse Event", 0, function() self:parseEvent() end)
end

function AutoMod:parseEvent()
	log("AutoMod.parseEvent")
	if C_Calendar.EventCanEdit() then
		local toCheckEvent = C_Calendar.GetEventInfo()
		log("AutoMod.parseEvent: Check event", toCheckEvent.title, toCheckEvent.time.monthDay, toCheckEvent.time.month,
			toCheckEvent.time.year, toCheckEvent.time.hour, toCheckEvent.time.minute)
		local numInvitees = C_Calendar.GetNumInvites()
		for inviteeIndex = 1, numInvitees do
			local inviteInfo = C_Calendar.EventGetInvite(inviteeIndex)
			local charName = inviteInfo.name
			if charName ~= nil then
				if not charName:find("-", 1, true) then
					charName = charName .. "-" .. GetRealmName()
				end
				if (inviteInfo.modStatus == nil or inviteInfo.modStatus == "") and tContains(self.autoModChars, charName) then
					RCE.work:add("Set Mod", 1, function(charName, inviteeIndex)
						log("AutoMod.parseEvent: Set Mod", charName, inviteeIndex)
						C_Calendar.EventSetModerator(inviteeIndex)
					end, charName, inviteeIndex)
				end
			end
		end
	end
	RCE.work:add("Close Event", 1, function() C_Calendar.CloseEvent() end)
	RCE.work:add("AutoMod check next", 1, function() self:enqueueNextEvent() end)
end

function AutoMod:execute()
	self.autoModChars = RCE.core:splitStringToArray(RCE.db.profile.autoModNames)
	log("CheckAutoMod", self.autoModChars)

	local dateTable = date("*t")

	for futureDays = 1, RCE.db.profile.eventsInFuture do
		RCE.core:setCalendarMonthToDate(dateTable)
		local numEvents = C_Calendar.GetNumDayEvents(0, dateTable.day)
		for eventIndex = 1, numEvents do
			local otherEvent = C_Calendar.GetDayEvent(0, dateTable.day, eventIndex)
			if otherEvent.modStatus == "CREATOR" and
				(otherEvent.calendarType == "GUILD_EVENT" or otherEvent.calendarType == "PLAYER") then
				local event = { day = dateTable.day, month = dateTable.month, year = dateTable.year, index = eventIndex }
				self.queue:push(event)
			end
		end
		dateTable.day = dateTable.day + 1
		dateTable = RCE.core:normalizeDateTable(dateTable)
	end

	RCE.work:add("AutoMod check next", 1, function() self:enqueueNextEvent() end)
end
