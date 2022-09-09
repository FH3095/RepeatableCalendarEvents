local log = FH3095Debug.log
local RCE = RepeatableCalendarEvents

local ConfirmWindow = {
	confirmed = false,
}
RCE.confirmWindow = ConfirmWindow

function ConfirmWindow:open(beforeAddFunc)
	local frame = RCE.gui:Create("Window")
	frame:SetCallback("OnClose", function()
		if not self.confirmed then
			RCE.work:clear()
		end
	end)
	frame:SetLayout("Fill")
	frame:EnableResize(false)
	frame:SetTitle(RCE.l.ConfirmWindowName)
	frame:SetWidth(250)
	frame:SetHeight(75)

	local button = RCE.gui:Create("Button")
	button:SetText(RCE.l.ConfirmButton)
	button:SetCallback("OnClick", function()
		self.confirmed = true
		beforeAddFunc()
		log("ConfirmWindow", "CreateEventClicked")
		C_Calendar.AddEvent()
		frame:Release()
	end)
	frame:AddChild(button)

	PlaySound(SOUNDKIT.READY_CHECK)
end
