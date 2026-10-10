-- guild_dress_room_pose_select.lua
function GUILD_DRESS_ROOM_POSE_SELECT_ON_INIT(addon, frame)
end

function GUILD_DRESS_ROOM_POSE_SELECT_OPEN(frame)
	GUILD_DRESS_ROOM_POSE_SELECT_POSE_MAKE_LIST(frame)
	frame:ShowWindow(1)
end

function GUILD_DRESS_ROOM_POSE_SELECT_CLOSE(frame)
	frame = ui.GetFrame("guild_dress_room_pose_select")
	if frame ~= nil then
		GUILD_DRESS_ROOM_POSE_SELECT_POSE_REMOVE_LIST(frame)
		frame:ShowWindow(0)

		local parent_frame = ui.GetFrame("guild_dress_room")
		if parent_frame ~= nil then
			local pose_select_gb = GET_CHILD_RECURSIVELY(parent_frame, "pose_select_gb")
			if pose_select_gb ~= nil then
				pose_select_gb:ShowWindow(0)
			end
		end
	end
end

function GUILD_DRESS_ROOM_POSE_SELECT_POSE_MAKE_LIST(frame)
	if frame == nil then
		return
	end

	local main_bg = GET_CHILD_RECURSIVELY(frame, "main_bg")
	if main_bg == nil then
		return
	end
	
	local basic_list = {}
	local list, cnt = GetClassList("Pose")
	if list ~= nil and cnt > 0 then
		for i = 0, cnt - 1 do
			local cls = GetClassByIndexFromList(list, i)
			if cls ~= nil and TryGetProp(cls, "PoseType", "None") == "Basic" then
				basic_list[#basic_list + 1] = cls				
			end
		end
	end
	
	if #basic_list > 0 then
		local ctrlset_width = ui.GetControlSetAttribute("pose_icon", "width")
		local ctrlset_height = ui.GetControlSetAttribute("pose_icon", "height")
		local count = 4
		local space_x, space_y = 0, 0
		local start_x, start_y = 30, 0
		for i = 1, #basic_list do
			local cls = basic_list[i]
			if cls ~= nil then
				local class_id = TryGetProp(cls, "ClassID", 0)
				local class_name = TryGetProp(cls, "ClassName", "None")
				local name = TryGetProp(cls, "Name", "None")
				local col = (i - 1) % count
				local row = math.floor((i - 1) / count)
				local x = start_x + (col * (ctrlset_width + space_x))
				local y = start_y + (row * (ctrlset_height + space_y))
				local ctrlset = main_bg:CreateOrGetControlSet("pose_icon", class_name, x, y)
				if ctrlset ~= nil then
					local slot = GET_CHILD_RECURSIVELY(ctrlset, "pose_slot", "ui::CSlot")
					if slot ~= nil then
						slot:EnableDrop(0)
						slot:EnableDrag(0)
						if i == 1 then
							slot:SetEventScript(ui.LBUTTONDOWN, "GUILD_DRESS_ROOM_PREVIEW_RESET_POSE")
							local icon_name = "icon_gesture_reset"
							SET_SLOT_IMG(slot, icon_name)

						else
							slot:SetEventScript(ui.LBUTTONDOWN, "GUILD_DRESS_ROOM_PREVIEW_PLAY_POSE")
							if IS_MACRO_UNVISIBLE_WEAPON_POSE(class_name) == true then
								slot:SetEventScriptArgString(ui.LBUTTONDOWN, "UnVisibleWeapon")
							end
							slot:SetEventScriptArgNumber(ui.LBUTTONDOWN, class_id)
				
							local icon_name = TryGetProp(cls, "Icon", "None")
							if icon_name ~= nil and icon_name ~= "None" then
								SET_SLOT_IMG(slot, TryGetProp(cls, "Icon", "None"))
							end
				
							local icon = slot:GetIcon()
							if icon ~= nil then
								icon:SetUserValue("POSEID", class_id)
							end
							slot:SetTextByKey("posename", name)
						end
					end
					
					local text = GET_CHILD_RECURSIVELY(ctrlset, "pose_name", "ui::CRichText")
					if text ~= nil then
						if i == 1 then
							text:SetTextByKey("posename", ScpArgMsg("Reset"))
						else
							text:SetTextByKey("posename", name)
						end
					end
				end
			end
		end
	end
	main_bg:Invalidate()
	frame:Invalidate()
end

function GUILD_DRESS_ROOM_POSE_SELECT_POSE_REMOVE_LIST(frame)
	if frame == nil then
		return
	end

	local main_bg = GET_CHILD_RECURSIVELY(frame, "main_bg")
	if main_bg == nil then
		return
	end

	main_bg:RemoveAllChild()
	main_bg:Invalidate()
	frame:Invalidate()
end