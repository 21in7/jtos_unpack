-- contents_guild.lua
function CONTENTS_SKILLS_ON_INIT(addon, frame)
end

function CONTENTS_SKILLS_OPEN(frame)
	if frame == nil then
		return
	end

	local skill_ability = GET_CHILD_RECURSIVELY(frame, "CONTENTS_SKILL_ABILITY")
	skill_ability:ShowWindow(1)

	local goddess_memories = GET_CHILD_RECURSIVELY(frame, "CONTENTS_GODDESS_MEMORIES")
	goddess_memories:ShowWindow(1)
end

function CONTENTS_SKILLS_CLOSE(frame)
end

function CONTENTS_SKILLS_LOSTFOCUS_SCP(frame, ctrl, argStr, argNum)
	local focusFrame = ui.GetFocusFrame()
	if focusFrame ~= nil then
		local focusFrameName = focusFrame:GetName()
		if focusFrameName == "apps" or focusFrameName == "sysmenu" then
			return
		end
	end
	ui.CloseFrame("apps")
end