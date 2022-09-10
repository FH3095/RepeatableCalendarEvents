local log = FH3095Debug.log
local RCE = RepeatableCalendarEvents

local EventRepeater = {}
RCE.eventRepeater = EventRepeater

local function increaseDate(repeatType, repeatStep, dateTable)
	if repeatType == RCE.consts.REPEAT_TYPES.DAILY then
		dateTable.day = dateTable.day + repeatStep
	elseif repeatType == RCE.consts.REPEAT_TYPES.MONTHLY then
		dateTable.month = dateTable.month + repeatStep
	elseif repeatType == RCE.consts.REPEAT_TYPES.YEARLY then
		dateTable.year = dateTable.year + repeatStep
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
	for i = 1, numEvents do
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
	for key, event in pairs(RCE.db.profile.events) do
		if event.enabled then
			local dateTable = RCE.core:timeTableFromEvent(event)
			local eventTime = time(dateTable)
			log("RepeatEvent Check", event.name, date("%c", eventTime))

			while eventTime < currentTime do
				-- increase eventTime until it reaches today
				dateTable = increaseDate(event.repeatType, event.repeatStep, dateTable)
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

					local eventCreateFunc = function()
						local eventIndex
						RCE.work:add("CALENDAR_NEW_EVENT", nil, false)
						RCE.work:add("Find event", 0, function()
							eventIndex = searchForEvent(dateTable, event.title)
							if eventIndex < 0 then
								error("Cant find just created event " .. event.title .. " on " .. date("%c", eventTime))
							end
						end)

						local invitees = RCE.core:splitStringToArray(event.autoInvite)
						if table.getn(invitees) > 0 then
							RCE.work:add("Open event", 0,
								function() C_Calendar.CloseEvent(); C_Calendar.OpenEvent(0, dateTable.day, eventIndex) end)
							RCE.work:add("CALENDAR_OPEN_EVENT", nil, false)
							for _, invitee in pairs(invitees) do
								RCE.work:add("Invite " .. invitee, 0,
									function(invitee)
										log("RepeatEvent invite", invitee, event.title)
										C_Calendar.EventInvite(invitee)
									end, invitee)
								RCE.work:add("CALENDAR_UPDATE_INVITE_LIST", RCE.consts.INTERVAL_INVITE, true)
							end
							RCE.work:add("Close event", 0, function() C_Calendar.CloseEvent() end)
							RCE.work:add("CALENDAR_CLOSE_EVENT", nil, false)
						end
						RCE.work:add("Wait for repeat check", RCE.consts.INTERVAL_REPEAT_CHECK, function() end)
						RCE.work:add("Run repeat check", RCE.consts.WORK_CONTINUE_MANUALLY, function() RCE.eventRepeater:execute() end)
						RCE.work:runNext()
					end

					log("RepeatEvent Create", event.name, date("%c", eventTime), event)
					createWoWEvent(event)
					RCE.confirmWindow:open(eventCreateFunc)
					return
				end

				-- increase date for next check round
				dateTable = increaseDate(event.repeatType, event.repeatStep, dateTable)
				eventTime = time(dateTable)
			end
			-- Finally save the dateTable to the event, so that the next checks ignore already created events
			dateTableToEvent(dateTable, event)
			log("RepeatEvent NextDate", event.name, date("%c", eventTime))
		end
	end

	-- when we reach here, we are done. Close Calendar
	RCE.work:add("Close Calendar", 0, function() Calendar_Hide() end)
	RCE.work:runNext()
	RCE.core:scheduleAutoModCheck()
end
