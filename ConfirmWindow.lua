
local log = FH3095Debug.log
local RCE = RepeatableCalendarEvents

local ConfirmWindow = {}
RCE.Class:createSingleton("confirmWindow", ConfirmWindow, {})

function ConfirmWindow:open(beforeAddFunc)
	local frame = RCE.gui:Create("Window")
	--frame:SetCallback("OnClose",function(widget) C_Calendar.AddEvent(); RCE.core:scheduleRepeatCheck(); frame:Release() end)
	frame:SetCallback("OnClose",function(widget) RCE.core:scheduleRepeatCheck() end)
	frame:SetLayout("Fill")
	frame:EnableResize(false)
	frame:SetTitle(RCE.l.ConfirmWindowName)
	frame:SetWidth(250)
	frame:SetHeight(75)

	local button = RCE.gui:Create("Button")
	button:SetText(RCE.l.ConfirmButton)
	button:SetCallback("OnClick", function()
		beforeAddFunc()
		C_Calendar.AddEvent()
		frame:Release()
	end)
	frame:AddChild(button)

	PlaySound(SOUNDKIT.READY_CHECK)
end
