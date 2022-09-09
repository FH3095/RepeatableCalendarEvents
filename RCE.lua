local ADDON_NAME = "RepeatableCalendarEvents"
local VERSION = "@project-version@"
local log = FH3095Debug.log
local RCE = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME)
RepeatableCalendarEvents = RCE


RCE.consts = {}

RCE.consts.ADDON_NAME = ADDON_NAME
RCE.consts.VERSION = VERSION
RCE.consts.COLORS = {
	HIGHLIGHT = "|cFF00FFFF",
}
RCE.consts.EVENT_TYPES = {
	RAID = Enum.CalendarEventType.Raid,
	DUNGEON = Enum.CalendarEventType.Dungeon,
	PVP = Enum.CalendarEventType.PvP,
	MEETING = Enum.CalendarEventType.Meeting,
	OTHER = Enum.CalendarEventType.Other,
}
RCE.consts.REPEAT_TYPES = {
	DAILY = 1,
	MONTHLY = 2,
	YEARLY = 3,
}
RCE.consts.WAIT_FOR_LOGIN_EVENT = 45
RCE.consts.INTERVAL_REPEAT_CHECK = 11
RCE.consts.INTERVAL_INVITE = 8
RCE.consts.ADDON_NAME_COLORED = RCE.consts.COLORS.HIGHLIGHT .. RCE.consts.ADDON_NAME .. "|r"
RCE.consts.WORK_EVENT_DEFAULT_WAIT_TIME = 60
RCE.consts.WORK_CONTINUE_MANUALLY = -1

function RCE:OnInitialize()
	--FH3095Debug.onInit()
	log("RCE:OnInitialize")

	self.l = LibStub("AceLocale-3.0"):GetLocale("RepeatableCalendarEvents", false)
	self.gui = LibStub("AceGUI-3.0")
	self.timers = {}
	LibStub("AceTimer-3.0"):Embed(self.timers)
	self.events = {}
	LibStub("AceEvent-3.0"):Embed(self.events) -- Have to embed, UnregisterEvent doesnt work otherwise

	local defaultDb = { profile = { events = {}, eventsInFuture = 15, } }
	self.db = LibStub("AceDB-3.0"):New(self.consts.ADDON_NAME .. "DB", defaultDb)
	self.settings:createOptions()


	self.console = LibStub("AceConsole-3.0")
end

local function registerEventPrint()
	local events = {
		"CALENDAR_ACTION_PENDING",
		"CALENDAR_CLOSE_EVENT",
		"CALENDAR_EVENT_ALARM",
		"CALENDAR_NEW_EVENT",
		"CALENDAR_OPEN_EVENT",
		"CALENDAR_UPDATE_ERROR",
		"CALENDAR_UPDATE_ERROR_WITH_COUNT",
		"CALENDAR_UPDATE_ERROR_WITH_PLAYER_NAME",
		"CALENDAR_UPDATE_EVENT",
		"CALENDAR_UPDATE_EVENT_LIST",
		"CALENDAR_UPDATE_GUILD_EVENTS",
		"CALENDAR_UPDATE_INVITE_LIST",
		"CALENDAR_UPDATE_PENDING_INVITES",
	}
	local aceEvent2 = {}
	LibStub("AceEvent-3.0"):Embed(aceEvent2)
	local eventPrintFunction = function(event, ...)
		FH3095Debug.log("CalEvt " .. event, ...)
	end
	for _, event in ipairs(events) do
		aceEvent2:RegisterEvent(event, eventPrintFunction)
	end
end

-- Enable is called after initialize
function RCE:OnEnable()
	FH3095Debug.onEnable()
	log("RCE:OnEnable")

	if FH3095Debug.isEnabled() then
		registerEventPrint()
	end

	-- On login, ask for calendar at PlayerAlive
	local loginEvent = "PLAYER_ALIVE"
	local cancelOnPlayerAlive = function()
		log("Cancel " .. loginEvent .. " listener")
		self.events:UnregisterEvent(loginEvent)
	end
	local timer = self.timers:ScheduleTimer(cancelOnPlayerAlive, self.consts.WAIT_FOR_LOGIN_EVENT)
	local onPlayerAlive = function()
		log(loginEvent .. " occured")
		self.events:UnregisterEvent(loginEvent)
		self.timers:CancelTimer(timer)
		self.core:scheduleRepeatCheck()
	end
	self.events:RegisterEvent(loginEvent, onPlayerAlive)

	local consoleCommandFunc = function(msg, editbox)
		self.core:consoleParseCommand(msg, editbox)
	end
	self.console:RegisterChatCommand("RCE", consoleCommandFunc, true)
	self.console:RegisterChatCommand("RepeatableCalendarEvents", consoleCommandFunc, true)
end
