-- contents_guild.lua
function CONTENTS_GUILD_ON_INIT(addon, frame)
end

function CONTENTS_GUILD_OPEN(frame)
	local guild_rank = GET_CHILD_RECURSIVELY(frame, "CONTENTS_GUILD_RANK")
	guild_rank:ShowWindow(1)

	local guild_info = GET_CHILD_RECURSIVELY(frame, "CONTENTS_GUILD_INFO")
	local guild_activity = GET_CHILD_RECURSIVELY(frame, "CONTENTS_GUILD_ACTIVITY")
	local guild_dress_room = GET_CHILD_RECURSIVELY(frame, "CONTENTS_GUILD_DRESS_ROOM")
	local is_check = UI_CHECK_GUILD_UI_OPEN()
	guild_info:ShowWindow(is_check)
	guild_activity:ShowWindow(is_check)
	guild_dress_room: ShowWindow(is_check)
end

function CONTENTS_GUILD_CLOSE(frame)
end

function CONTENTS_GUILD_LOSTFOCUS_SCP(frame, ctrl, argStr, argNum)
	local focusFrame = ui.GetFocusFrame();	
	if focusFrame ~= nil then
		local focusFrameName = focusFrame:GetName();		
		if focusFrameName == "apps" or focusFrameName == "sysmenu" then
			return;
		end
	end
	ui.CloseFrame("apps");
end