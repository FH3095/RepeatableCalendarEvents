local log = FH3095Debug.log
local RCE = RepeatableCalendarEvents

local Settings = {}
RCE.settings = Settings

function Settings:createOptions()
	local optionsTable = {
		name = RCE.consts.ADDON_NAME,
		type = "group",
		args = {
			basic = {
				handler = self,
				name = "Basic",
				type = "group",
				set = "SetBasicOption",
				get = "GetBasicOption",
				args = {
					eventsInFuture = {
						type    = "range",
						name    = RCE.l.EventsInFutureName,
						desc    = RCE.l.EventsInFutureDesc,
						width   = "full",
						min     = 1,
						max     = 365,
						softMax = 32,
						step    = 1,
					},
					autoModNames = {
						type      = "input",
						name      = RCE.l.AutoModNamesName,
						desc      = RCE.l.AutoModNamesDesc,
						multiline = true,
						width     = "full",
					}
				}
			},
			profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(RCE.db),
		}
	}
	LibStub("AceConfig-3.0"):RegisterOptionsTable(RCE.consts.ADDON_NAME, optionsTable)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions(RCE.consts.ADDON_NAME)
end

function Settings:SetBasicOption(info, value)
	log("Set option", info[#info], value)
	RCE.db.profile[info[#info]] = value
end

function Settings:GetBasicOption(info)
	return RCE.db.profile[info[#info]]
end
