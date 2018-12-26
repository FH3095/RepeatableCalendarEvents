
local log = FH3095Debug.log
local RCE = RepeatableCalendarEvents

local EventRepeater = {}
RCE.Class:createSingleton("eventRepeater", EventRepeater, {})

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
			increaseDate(event.repeatType, dateTable)
			eventTime = time(dateTable)
			log("EventRepeater added to", date("%c", eventTime))
		end

		while eventTime < maxCreateTime do
			log("RepeatEvent CheckFor", event.name, date("%c", eventTime))
			dateTable = RCE.core:normalizeDateTable(dateTable)
			RCE.core:setCalendarMonthToDate(dateTable)

			-- Loop through events of that day to see if event already exists
			local numEvents = C_Calendar.GetNumDayEvents(0, dateTable.day)
			local foundEvent = false
			for i=1,numEvents do
				local otherEvent = C_Calendar.GetDayEvent(0, dateTable.day, i)
				if (otherEvent.calendarType == "GUILD_EVENT" or otherEvent.calendarType == "PLAYER") and otherEvent.title == event.title then
					log("RepeatEvent Found", event.name, date("%c", eventTime))
					foundEvent = true
					break
				end
			end

			-- Create event if not found
			if not foundEvent then
				-- First write date from DateTable to the event
				dateTableToEvent(dateTable, event)
				log("RepeatEvent Create", event.name, date("%c", eventTime), event)
				createWoWEvent(event)
				RCE.confirmWindow:open()
				return
			end

			-- increase date for next check round
			increaseDate(event.repeatType, dateTable)
			eventTime = time(dateTable)
		end
		-- Finally save the dateTable to the event, so that the next checks ignore already created events
		dateTableToEvent(dateTable, event)
		log("RepeatEvent NextDate", event.name, date("%c", eventTime))
	end

	RCE.core:scheduleAutoModCheck()
end
