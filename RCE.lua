
local ADDON_NAME = "RepeatableCalendarEvents"
local VERSION = "@project-version@"
local log = FH3095Debug.log
local RCE = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME)
RepeatableCalendarEvents = RCE


RCE.consts = {}

RCE.consts.ADDON_NAME = ADDON_NAME
RCE.consts.VERSION = VERSION
RCE.consts.CHAR_MAX_LEVEL = 120
RCE.consts.COLORS = {
	HIGHLIGHT = "|cFF00FFFF",
}
RCE.consts.EVENT_TYPES = {
	RAID = Enum.CalendarEventType.Raid,
	DUNGEON = Enum.CalendarEventType.Dungeon,
	PVP = Enum.CalendarEventType.Pvp,
	MEETING = Enum.CalendarEventType.Meeting,
	OTHER = Enum.CalendarEventType.Other,
}
RCE.consts.REPEAT_TYPES = {
	WEEKLY = 1,
	MONTHLY = 2,
	YEARLY = 3,
}
RCE.consts.WAIT_FOR_PLAYER_ALIVE = 60
RCE.consts.REPEAT_CHECK_INTERVAL = 11
RCE.consts.ADDON_NAME_COLORED = RCE.consts.COLORS.HIGHLIGHT .. RCE.consts.ADDON_NAME .. "|r"

function RCE:OnEnable()
	FH3095Debug.onEnable()
end

function RCE:OnInitialize()
	--FH3095Debug.onInit()
	log("RCE:OnInitialize")
	self.l = LibStub("AceLocale-3.0"):GetLocale("RepeatableCalendarEvents", false)
	self.gui = LibStub("AceGUI-3.0")
	self.timers = {}
	LibStub("AceTimer-3.0"):Embed(self.timers)
	self.events = {}
	LibStub("AceEvent-3.0"):Embed(self.events) -- Have to embed, UnregisterEvent doesnt work otherwise

	local defaultDb = { profile = { events = {}, eventsInFuture = 15, }}
	self.db = LibStub("AceDB-3.0"):New(self.consts.ADDON_NAME .. "DB", defaultDb)
	self.settings:createOptions()

	-- On login, ask for calendar at PlayerAlive
	local waitExpireTimer = self.timers:ScheduleTimer(function()
		log("Wait for PLAYER_ALIVE expired, unregister events")
		self.workQueue:clearTasks()
	end, self.consts.WAIT_FOR_PLAYER_ALIVE)
	self.workQueue:addTask(function() self.timers:CancelTimer(waitExpireTimer) C_Calendar.OpenCalendar() end, "PLAYER_ALIVE")
	self.workQueue:addTask(function() self.timers:CancelTimer(waitExpireTimer) self.core:scheduleRepeatCheck() end, "CALENDAR_UPDATE_EVENT_LIST")


	self.console = LibStub("AceConsole-3.0")
	local consoleCommandFunc = function(msg, editbox)
		self.core:consoleParseCommand(msg, editbox)
	end
	self.console:RegisterChatCommand("RCE", consoleCommandFunc, true)
	self.console:RegisterChatCommand("RepeatableCalendarEvents", consoleCommandFunc, true)
end
