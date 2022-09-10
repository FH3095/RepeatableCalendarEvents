local log = FH3095Debug.log
local RCE = RepeatableCalendarEvents

local EventWindow = {}
RCE.eventWindow = EventWindow

local function buildRaidOrDungeonDropdownList(cache)
	local ret = {}
	for i = 1, #cache do
		ret[i] = cache[i].expansionName .. " - " .. cache[i].title
	end

	return ret
end

local function builDifficultyDropdownList(cache, index)
	local ret = {}
	local difficulties = cache[index].difficulties

	for i = 1, #difficulties do
		ret[i] = difficulties[i].name
	end

	return ret
end

local function constructDefaultEvent()
	local today = date("*t")
	local ret = {
		name = "",
		enabled = true,
		title = "",
		desc = "",
		type = RCE.consts.EVENT_TYPES.RAID,
		raidOrDungeon = 1,
		difficulty = 1,
		hour = 0,
		minute = 0,
		day = today.day,
		month = today.month,
		year = today.year,
		repeatType = RCE.consts.REPEAT_TYPES.DAILY,
		repeatStep = 7,
		locked = false,
		guildEvent = false,
		autoInvite = "",
	}

	return ret
end

function EventWindow:open(eventId)
	local L = RCE.l
	local Const = RCE.consts
	local event = nil
	if eventId and RCE.db.profile.events[eventId] ~= nil then
		event = RCE.db.profile.events[eventId]
	else
		event = constructDefaultEvent()
	end
	log("OpenEventWindow", eventId, event)

	local frame = RCE.gui:Create("Window")
	frame:SetLayout("Flow")
	frame:EnableResize(true)
	frame:SetTitle(L.EventWindowName)
	frame:SetAutoAdjustHeight(true)
	frame:PauseLayout()

	local name = self:createElement(frame, "EditBox", "EventName", event.name)
	name:SetRelativeWidth(0.49)
	name:DisableButton(true)

	local enabled = self:createElement(frame, "CheckBox", "EventEnabled", event.enabled)
	enabled:SetRelativeWidth(0.49)

	local title = self:createElement(frame, "EditBox", "EventTitle", event.title)
	title:SetRelativeWidth(0.49)
	title:DisableButton(true)

	local type = self:createElement(frame, "Dropdown", "EventType")
	local types = {
		[Const.EVENT_TYPES.RAID] = L["EventTypeRaid"],
		[Const.EVENT_TYPES.DUNGEON] = L["EventTypeDungeon"],
		[Const.EVENT_TYPES.PVP] = L["EventTypePvP"],
		[Const.EVENT_TYPES.MEETING] = L["EventTypeMeeting"],
		[Const.EVENT_TYPES.OTHER] = L["EventTypeOther"],
	}
	type:SetList(types)
	type:SetRelativeWidth(0.49)
	type:SetValue(event.type)

	local raidOrDungeon = self:createElement(frame, "Dropdown", "EventRaidOrDungeon")
	raidOrDungeon:SetRelativeWidth(0.49)
	raidOrDungeon:SetValue(event.raidOrDungeon)

	local difficulty = self:createElement(frame, "Dropdown", "EventDifficulty")
	local difficulties = { "Normal", "Heroic", "Mythic" }
	difficulty:SetList(difficulties)
	difficulty:SetRelativeWidth(0.49)
	difficulty:SetValue(event.difficulty)

	local desc = self:createElement(frame, "MultiLineEditBox", "EventDesc", event.desc)
	desc:SetFullWidth(true)
	desc:DisableButton(true)

	local hour = self:createElement(frame, "Dropdown", "EventHour")
	local hours = {}
	for i = 0, 23 do
		hours[i] = format("%02u", i)
	end
	hour:SetList(hours)
	hour:SetRelativeWidth(0.19)
	hour:SetValue(event.hour)

	local minute = self:createElement(frame, "Dropdown", "EventMinute")
	local minutes = {}
	for i = 0, 55, 5 do
		minutes[i] = format("%02u", i)
	end
	minute:SetList(minutes)
	minute:SetRelativeWidth(0.19)
	minute:SetValue(event.minute)

	local day = self:createElement(frame, "EditBox", "EventDay", event.day)
	day:SetRelativeWidth(0.2)
	day:DisableButton(true)

	local month = self:createElement(frame, "EditBox", "EventMonth", event.month)
	month:SetRelativeWidth(0.2)
	month:DisableButton(true)

	local year = self:createElement(frame, "EditBox", "EventYear", event.year)
	year:SetRelativeWidth(0.2)
	year:DisableButton(true)

	local repeatType = self:createElement(frame, "Dropdown", "EventRepeatType")
	local repeatTypes = {
		[Const.REPEAT_TYPES.DAILY] = L.EventRepeatDaily,
		[Const.REPEAT_TYPES.MONTHLY] = L.EventRepeatMonthly,
		[Const.REPEAT_TYPES.YEARLY] = L.EventRepeatYearly,
	}
	repeatType:SetList(repeatTypes)
	repeatType:SetWidth(100)
	repeatType:SetValue(event.repeatType)

	local repeatStep = self:createElement(frame, "EditBox", "EventRepeatStep", event.repeatStep)
	repeatStep:SetWidth(100)
	repeatStep:DisableButton(true)

	local autoInvite = self:createElement(frame, "MultiLineEditBox", "EventAutoInvite", event.autoInvite)
	autoInvite:SetFullWidth(true)
	autoInvite:DisableButton(true)

	local locked = self:createElement(frame, "CheckBox", "EventLocked", event.locked)

	local guildEvent = self:createElement(frame, "CheckBox", "EventTypeGuild", event.guildEvent)

	local saveButton = self:createElement(frame, "Button", "SaveEventButton")
	saveButton:SetFullWidth(true)
	saveButton:SetCallback("OnClick", function()
		if self:save(frame, eventId) then
			frame:Release()
			RCE.eventsListWindow:open()
		end
	end)

	frame:ResumeLayout()
	frame:DoLayout()

	self:registerForChangeToCheckOtherFields(frame, type, "Dropdown")
	self:registerForChangeToCheckOtherFields(frame, raidOrDungeon, "Dropdown")
	self:checkFields(frame)
end

function EventWindow:createElement(frame, type, name, value)
	local checkValue = function()
		if value == nil then
			error("Value for element " .. name .. " of type " .. type .. " must not be nil")
		end
	end

	local element = RCE.gui:Create(type)
	if element.SetLabel ~= nil then
		element:SetLabel(RCE.l[name])
	elseif type == "Button" then
		element:SetText(RCE.l[name])
	else
		error("Unknown SetLabel method for window element " .. name .. " of type " .. type)
	end

	if type == "EditBox" or type == "MultiLineEditBox" then
		checkValue()
		element:SetText(value)
	elseif type == "CheckBox" or type == "Slider" then
		checkValue()
		element:SetValue(value)
	elseif type == "Button" or type == "Dropdown" then
		-- Do nothing for buttons and cant set for dropdowns before options are set
	else
		error("Cant handle value for element " .. name .. " of type " .. type)
	end

	frame:AddChild(element)

	local childs = frame:GetUserData("Childs")
	if childs == nil then
		frame:SetUserData("Childs", {})
		childs = frame:GetUserData("Childs")
	end
	childs[name] = element

	return element
end

function EventWindow:checkFields(frame)
	local childs = frame:GetUserData("Childs")
	if childs.EventType:GetValue() == RCE.consts.EVENT_TYPES.RAID or
		childs.EventType:GetValue() == RCE.consts.EVENT_TYPES.DUNGEON then
		childs.EventRaidOrDungeon:SetDisabled(false)
		childs.EventDifficulty:SetDisabled(false)

		local cache = RCE.core:getCacheForEventType(childs.EventType:GetValue())
		local oldValue = childs.EventRaidOrDungeon:GetValue()
		childs.EventRaidOrDungeon:SetList(buildRaidOrDungeonDropdownList(cache))
		childs.EventRaidOrDungeon:SetValue(oldValue)
		oldValue = childs.EventDifficulty:GetValue()
		childs.EventDifficulty:SetList(builDifficultyDropdownList(cache, childs.EventRaidOrDungeon:GetValue()))
		childs.EventDifficulty:SetValue(oldValue)
	else
		childs.EventRaidOrDungeon:SetDisabled(true)
		childs.EventDifficulty:SetDisabled(true)
	end

	if IsInGuild() then
		childs.EventTypeGuild:SetDisabled(false)
	else
		childs.EventTypeGuild:SetDisabled(true)
	end

	frame:DoLayout()
end

function EventWindow:registerForChangeToCheckOtherFields(frame, element, type)
	local callCheckFunction = function()
		self:checkFields(frame)
	end

	if type == "CheckBox" or type == "Dropdown" then
		element:SetCallback("OnValueChanged", callCheckFunction)
	else
		error("Unknown type to check for changes: " .. type)
	end
end

function EventWindow:save(frame, eventId)
	log("EvtWndSave", eventId)
	local childs = frame:GetUserData("Childs")
	local event = {}

	event.name = childs.EventName:GetText()
	event.enabled = childs.EventEnabled:GetValue() and true or false
	event.title = childs.EventTitle:GetText()
	event.desc = childs.EventDesc:GetText()
	event.type = childs.EventType:GetValue()
	event.raidOrDungeon = childs.EventRaidOrDungeon:GetValue()
	event.difficulty = childs.EventDifficulty:GetValue()
	event.hour = tonumber(childs.EventHour:GetValue())
	event.minute = tonumber(childs.EventMinute:GetValue())
	event.day = tonumber(childs.EventDay:GetText())
	event.month = tonumber(childs.EventMonth:GetText())
	event.year = tonumber(childs.EventYear:GetText())
	event.repeatType = tonumber(childs.EventRepeatType:GetValue())
	event.repeatStep = tonumber(childs.EventRepeatStep:GetText())
	event.locked = childs.EventLocked:GetValue() and true or false
	event.autoInvite = childs.EventAutoInvite:GetText()
	event.guildEvent = childs.EventTypeGuild:GetValue() and true or false

	if not RCE.core:validateEvent(event) then
		return false
	end

	log("EvtWndSave Saving: ", eventId, event)
	if eventId and RCE.db.profile.events[eventId] ~= nil then
		RCE.db.profile.events[eventId] = event
	else
		tinsert(RCE.db.profile.events, event)
	end

	local sortFunc = function(evt1, evt2)
		if evt1 == nil then
			return false
		elseif evt2 == nil then
			return true
		else
			return strcmputf8i(tostring(evt1.name), tostring(evt2.name)) < 0
		end
	end
	sort(RCE.db.profile.events, sortFunc)
	return true
end
