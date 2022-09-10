-- TODO:
-- - AutoMod für Events
-- - Custom-Einlade-Listen für Events (Gilde und nicht-Gilde)

local log = FH3095Debug.log
local RCE = RepeatableCalendarEvents

local Core = {}
RCE.core = Core

local function buildCache(textureInfos)
	local sortDifficulties = function(a, b)
		return a.difficulty < b.difficulty
	end
	local sortEntries = function(a, b)
		if a.expansion ~= b.expansion then
			return a.expansion > b.expansion
		end
		return a.texture > b.texture
	end
	local result = {}

	local index = 0
	for _, entry in pairs(textureInfos) do
		index = index + 1
		local title = entry.title
		local texture = entry.iconTexture
		local expansion = entry.expansionLevel
		local difficultyId = entry.difficultyId
		local mapId = entry.mapId
		local isLFR = entry.isLfr

		local difficultyName, _, _, _, isHeroic, isMythic = GetDifficultyInfo(difficultyId)
		if result[mapId] == nil or
			(result[mapId].isLFR and not isLFR) or
			((result[mapId].isHeroic or result[mapId].isMythic) and not (isHeroic or isMythic)) then
			local difficulties = {}
			if result[mapId] ~= nil then
				difficulties = result[mapId].difficulties
			end
			difficulties[difficultyId] = { difficulty = difficultyId, name = difficultyName, index = index }

			result[mapId] = {
				title = title,
				expansion = expansion,
				expansionName = _G["EXPANSION_NAME" .. expansion],
				isLFR = isLFR,
				isHeroic = isHeroic,
				isMythic = isMythic,
				texture = texture,
				difficulties = difficulties,
			}
		else
			result[mapId].difficulties[difficultyId] = { difficulty = difficultyId, name = difficultyName, index = index }
			if result[mapId].texture == nil and texture ~= nil then
				result[mapId].texture = texture
			end
		end
	end

	local sortedResult = {}
	-- By purpose we drop the mapid-information and difficulty-id-key here. We dont need them any longer and they prevent sorting
	for _, v in pairs(result) do
		local difficulties = v.difficulties
		v.difficulties = {}
		for _, v2 in pairs(difficulties) do
			tinsert(v.difficulties, v2)
		end
		sort(v.difficulties, sortDifficulties)
		tinsert(sortedResult, v)
	end
	sort(sortedResult, sortEntries)
	return sortedResult
end

function Core:buildCaches()
	if self.raidCache == nil then
		self.raidCache = buildCache(C_Calendar.EventGetTextures(RCE.consts.EVENT_TYPES.RAID))
	end
	if self.dungeonCache == nil then
		self.dungeonCache = buildCache(C_Calendar.EventGetTextures(RCE.consts.EVENT_TYPES.DUNGEON))
	end
end

function Core:consoleParseCommand(msg, editbox)
	log("ConsoleParseCommand", msg)
	local cmd, nextpos = RCE.console:GetArgs(msg)

	if cmd ~= nil then
		if cmd == "check" then
			self:scheduleRepeatCheck()
		elseif cmd == "new" then
			RCE.eventWindow:open()
		else
			RCE.eventsListWindow:open()
		end
	else
		RCE.eventsListWindow:open()
	end
end

function Core:printError(str, ...)
	str = RCE.consts.ADDON_NAME_COLORED .. " |cFFFF0000Error:|r " .. str
	print(str:format(...))
end

function Core:getCacheForEventType(eventType)
	self:buildCaches()
	if RCE.consts.EVENT_TYPES.RAID == eventType then
		return self.raidCache
	elseif RCE.consts.EVENT_TYPES.DUNGEON == eventType then
		return self.dungeonCache
	else
		return nil
	end
end

function Core:timeTableFromEvent(event)
	local dateTable = {
		year = event.year,
		month = event.month,
		day = event.day,
		hour = event.hour,
		min = event.minute,
	}
	return dateTable
end

function Core:timeFromEvent(event, errorIfInvalid)
	local dateTable = self:timeTableFromEvent(event)
	local status, eventTime = xpcall(function() return time(dateTable) end, function() end)
	if not status then
		if errorIfInvalid then
			error("Date/Time for event " .. event.name .. " is invalid! Delete this event.")
		else
			return nil
		end
	end

	return tonumber(eventTime)
end

function Core:validateEvent(event)
	log("ValidateEvent", event)
	local empty = function(param)
		if param == nil or strtrim(param) == "" then
			return true
		else
			return false
		end
	end
	local L = RCE.l

	if empty(event.name) then
		self:printError(L.ErrorNameEmpty)
		return false
	end
	if empty(event.title) then
		self:printError(L.ErrorTitleEmpty)
		return false
	end
	if (event.type == RCE.consts.EVENT_TYPES.RAID or event.type == RCE.consts.EVENT_TYPES.DUNGEON) then
		local cache = self:getCacheForEventType(event.type)
		if cache == nil then
			error("No cache for " .. event.type .. "???")
		end
		if empty(event.raidOrDungeon) or event.raidOrDungeon <= 0 or event.raidOrDungeon > #cache then
			self:printError(L.ErrorNoRaidOrDungeonChoosen)
			return false
		end
		if empty(event.difficulty) or event.difficulty <= 0 or event.difficulty > #cache[event.raidOrDungeon].difficulties then
			self:printError(L.ErrorNoDifficultyChoosen)
			return false
		end
	end

	local currentTime = time()
	local eventTime = self:timeFromEvent(event, false)
	if not eventTime then
		self:printError(L.ErrorEventInvalidDate)
		return false
	end
	log("ValidateEvent Times: ", date(L.DateFormat, eventTime), date(L.DateFormat, currentTime))
	if currentTime >= eventTime then
		self:printError(L.ErrorEventIsInPast)
		return false
	end
	return true
end

function Core:scheduleRepeatCheck()
	log("ScheduleRepeatCheck")
	-- We have to use Calendar_Show() which shows the calendar ui. Without the ui, we cant open an event to invite people
	RCE.work:add("Open Calendar", 1,
		function()
			if not Calendar_Show then
				Calendar_LoadUI()
			end
			Calendar_Show()
		end)
	RCE.work:add("Run first repeat check", RCE.consts.WORK_CONTINUE_MANUALLY, function() RCE.eventRepeater:execute() end)
end

function Core:scheduleAutoModCheck()
	if self.autoModCheckTimer ~= nil and RCE.timers:TimeLeft(self.autoModCheckTimer) > 0 then
		return
	end

	self.autoModCheckTimer = RCE.timers:ScheduleTimer(function() RCE.autoMod:execute() end, 10)
end

function Core:setCalendarMonthToDate(yearOrDateTable, month)
	local year = yearOrDateTable
	if month == nil then
		year = yearOrDateTable.year
		month = yearOrDateTable.month
	else
		year = yearOrDateTable
	end
	C_Calendar.SetAbsMonth(month, year)
	-- assert that CalendarSetMonth worked
	local monthInfo = C_Calendar.GetMonthInfo(0)
	assert(monthInfo.month == month, "Month mismatch " .. monthInfo.month .. " <> " .. month)
	assert(monthInfo.year == year, "Year mismatch " .. monthInfo.year .. " <> " .. year)
end

function Core:normalizeDateTable(dateTable)
	dateTable = date("*t", time(dateTable))
	local ret = {}
	ret.year = dateTable.year
	ret.month = dateTable.month
	ret.day = dateTable.day
	ret.hour = dateTable.hour
	ret.min = dateTable.min

	return ret
end

function Core:splitStringToArray(array)
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
