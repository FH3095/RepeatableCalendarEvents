
local log = FH3095Debug.log
local RCE = RepeatableCalendarEvents

local EventRepeater = {}
RCE.Class:createSingleton("eventRepeater", EventRepeater, {workQueue = RCE.WorkQueue.new()})

local function increaseDate(repeatType, dateTable)
	if repeatType == RCE.consts.REPEAT_TYPES.WEEKLY then
		dateTable.day = dateTable.day + 7
	elseif repeatType == RCE.consts.REPEAT_TYPES.MONTHLY then
		dateTable.month = dateTable.month + 1
	elseif repeatType == RCE.consts.REPEAT_TYPES.YEARLY then
		dateTable.year = dateTable.year + 1
	else
		error("Unknown repeattype " .. repeatType)
	end
	
	return RCE.core:normalizeDateTable(dateTable)
end

local function dateTableToEvent(dateTable, event)
	dateTable = date("*t", time(dateTable))
	event.year = dateTable.year
	event.month = dateTable.month
	event.day = dateTable.day
	event.hour = dateTable.hour
	event.minute = dateTable.min
end

local function createWoWEvent(event)
	if event.guildEvent and IsInGuild() then
		C_Calendar.CreateGuildSignUpEvent()
	else
		C_Calendar.CreatePlayerEvent()
	end
	C_Calendar.EventSetTitle(event.title)
	C_Calendar.EventSetDescription(event.desc)
	C_Calendar.EventSetType(event.type)
	C_Calendar.EventSetTime(event.hour, event.minute)
	C_Calendar.EventSetDate(event.month, event.day, event.year)
	if event.locked then
		C_Calendar.EventSetLocked()
	end
	if not event.guildEvent and event.customGuildInvite and IsInGuild() then
		C_Calendar.MassInviteGuild(event.guildInvMinLevel, event.guildInvMaxLevel, event.guildInvRank)
	end

	local cache = RCE.core:getCacheForEventType(event.type)
	if cache ~= nil then
		local textureId = cache[event.raidOrDungeon].difficulties[event.difficulty].index
		C_Calendar.EventSetTextureID(textureId)
	end
end

local function searchForEvent(dateTable, eventTitle)
	log("Search for event", eventTitle, dateTable)
	RCE.core:setCalendarMonthToDate(dateTable)

	local numEvents = C_Calendar.GetNumDayEvents(0, dateTable.day)
	for i=1,numEvents do
		local otherEvent = C_Calendar.GetDayEvent(0, dateTable.day, i)
		if (otherEvent.calendarType == "GUILD_EVENT" or otherEvent.calendarType == "PLAYER") and otherEvent.title == eventTitle then
			return i
		end
	end
	return -1
end

function EventRepeater:execute()
	log("EventRepeater:execute")

	local currentTime = time()
	local maxCreateTime = time() + RCE.db.profile.eventsInFuture * 86400
	for key,event in pairs(RCE.db.profile.events) do
		local dateTable = RCE.core:timeTableFromEvent(event)
		local eventTime = time(dateTable)
		log("RepeatEvent Check", event.name, date("%c", eventTime))

		while eventTime < currentTime do
			-- increase eventTime until it reaches today
			dateTable = increaseDate(event.repeatType, dateTable)
			eventTime = time(dateTable)
			log("EventRepeater added to", date("%c", eventTime))
		end

		while eventTime < maxCreateTime do
			log("RepeatEvent CheckFor", event.name, date("%c", eventTime))
			local eventIndex = searchForEvent(dateTable, event.title)

			if eventIndex >= 0 then
				log("RepeatEvent Found", event.name, date("%c", eventTime))
			else
				-- Create event if not found
				-- First write date from DateTable to the event
				dateTableToEvent(dateTable, event)

				local beforeAddNewEventFunc = function()
					local afterNewEventCreatedFunc = function()
						local eventIndex = searchForEvent(dateTable, event.title)
						if eventIndex < 0 then
							error("Cant find just created event " .. event.title .. " on " .. date("%c", eventTime))
						end

						local invitees = RCE.core:splitStringToArray(event.autoInvite)
						if table.getn(invitees) > 0 then
							log("RepeatEvent AutoInvite", event.name, date("%c", eventTime), invitees)
							local waitForEvent = "CALENDAR_OPEN_EVENT"
							self.workQueue:addTask(function() C_Calendar.CloseEvent(); C_Calendar.OpenEvent(0, dateTable.day, eventIndex) end, nil, 1)
							for _,v in pairs(invitees) do
								self.workQueue:addTask(function() log("RepeatEvent invite", v, event); C_Calendar.EventInvite(v) end, waitForEvent, RCE.consts.INVITE_INTERVAL)
								waitForEvent = nil
							end
							self.workQueue:addTask(function() C_Calendar.CloseEvent() end, nil, RCE.consts.INVITE_INTERVAL)
						end

						self.workQueue:addTask(function() RCE.eventRepeater:execute() end, nil, RCE.consts.REPEAT_CHECK_INTERVAL)
					end

					self.workQueue:addTask(function() afterNewEventCreatedFunc() end, "CALENDAR_NEW_EVENT", 1)
				end

				log("RepeatEvent Create", event.name, date("%c", eventTime), event)
				createWoWEvent(event)
				RCE.confirmWindow:open(beforeAddNewEventFunc)
				return
			end

			-- increase date for next check round
			dateTable = increaseDate(event.repeatType, dateTable)
			eventTime = time(dateTable)
		end
		-- Finally save the dateTable to the event, so that the next checks ignore already created events
		dateTableToEvent(dateTable, event)
		log("RepeatEvent NextDate", event.name, date("%c", eventTime))
	end

	RCE.core:scheduleAutoModCheck()
end
