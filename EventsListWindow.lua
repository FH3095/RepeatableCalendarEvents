
local log = FH3095Debug.log
local RCE = RepeatableCalendarEvents

local EventListWindow = {}
RCE.Class:createSingleton("eventsListWindow", EventListWindow, {})


function EventListWindow:open()
	log("openEventsListWindow")
	local L = RCE.l

	local frame = RCE.gui:Create("Window")
	--frame:SetCallback("OnClose",function(widget) frame:Release() end)
	frame:SetLayout("Fill")
	frame:EnableResize(true)
	frame:SetTitle(L.EventListWindowName)

	local scroll = RCE.gui:Create("ScrollFrame")
	scroll:SetLayout("Flow")
	frame:AddChild(scroll)
	scroll:PauseLayout()


	local events = RCE.db.profile.events;
	for key,event in pairs(events) do
		local editButton = RCE.gui:Create("Button")
		editButton:SetText(event.name)
		editButton:SetRelativeWidth(0.8)
		editButton:SetCallback("OnClick", function() RCE.eventWindow:open(key); frame:Release() end)
		scroll:AddChild(editButton)
		local deleteButton = RCE.gui:Create("Button")
		deleteButton:SetRelativeWidth(0.199)
		deleteButton:SetText(L.DeleteButtonText)
		deleteButton:SetCallback("OnClick", function() RCE.db.profile.events[key] = nil; frame:Release(); self:open() end)
		scroll:AddChild(deleteButton)
	end

	local newButton = RCE.gui:Create("Button")
	newButton:SetText(L.NewEventButton)
	newButton:SetFullWidth(true)
	newButton:SetCallback("OnClick", function() RCE.eventWindow:open(nil); frame:Release() end)
	scroll:AddChild(newButton)

	scroll:ResumeLayout()
	scroll:DoLayout()
end
