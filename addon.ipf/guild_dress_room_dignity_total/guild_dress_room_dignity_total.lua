-- guild_dress_room_dignity_total.lua
function GUILD_DRESS_ROOM_DIGNITY_TOTAL_OPEN(frame, dignity_data_str, complete_count)		
	if frame ~= nil then
		frame:ShowWindow(1)
		GUILD_DRESS_ROOM_DIGNITY_TOTAL_REMOVE_LIST(frame)
		GUILD_DRESS_ROOM_DIGNITY_TOTAL_SET_LIST(frame, dignity_data_str, complete_count)
	end
end

function GUILD_DRESS_ROOM_DIGNITY_TOTAL_CLOSE(frame)
	if frame ~= nil then
		GUILD_DRESS_ROOM_DIGNITY_TOTAL_REMOVE_LIST(frame)
		frame:ShowWindow(0)
		local parent_frame = ui.GetFrame("guild_dress_room")
		if parent_frame ~= nil then
			local dignity_total_gb = GET_CHILD_RECURSIVELY(parent_frame, "dignity_total_gb")
			if dignity_total_gb ~= nil then
				dignity_total_gb:ShowWindow(0)
			end
		end
	end
end

function GUILD_DRESS_ROOM_DIGNITY_TOTAL_REMOVE_LIST(frame)
	local bg = GET_CHILD_RECURSIVELY(frame, "bg")
	if bg ~= nil then
		DESTROY_CHILD_BYNAME(bg, "DIGNITY_INFO_")
	end
end

function GUILD_DRESS_ROOM_DIGNITY_TOTAL_SET_LIST(frame, dignity_list_str, complete_count)
	if frame == nil then
		return
	end

	local complete_count_text = GET_CHILD(frame, "complete_count_text", "ui::CRichText");
	if complete_count_text == nil then
		return 
	end

	if dignity_list_str == "" then
		all_stauts_list_text:SetTextByKey("value", ScpArgMsg("GuildDressRoomDignityNotExist"))
		return
	end
	
	local dignity_list = StringSplit(dignity_list_str, ';')
	if #dignity_list <= 0 then
		return
	end	
	
	local bg = GET_CHILD_RECURSIVELY(frame, "bg")
	if bg ~= nil then
		local start_x = 5
		local idx = 0
		local height = ui.GetControlSetAttribute("guild_dress_room_dignity_info", "height")
		for i = 1, #dignity_list do
			local dingity_str = dignity_list[i]
			local dingity_elem = StringSplit(dingity_str, '/')
			if #dingity_elem > 0 then
				-- text_list = text_list.."{@st42}- {#00ccff}".."["..ScpArgMsg(name).."]{/}".." {#ffffff}+"..tostring(value).."{/}"
				local name = dingity_elem[1]
				local value = dingity_elem[2]
				local x = start_x
				local y = height * idx
				local ctrlset = bg:CreateOrGetControlSet("guild_dress_room_dignity_info", "DIGNITY_INFO_"..idx, x, y)
				if ctrlset ~= nil then
					if idx % 2 == 0 then
						local bg_pic = GET_CHILD_RECURSIVELY(ctrlset, "bg")
						if bg_pic ~= nil then
							bg_pic:SetImage("")
						end
					end

					local name_text = GET_CHILD_RECURSIVELY(ctrlset, "name")
					if name_text ~= nil then
						name_text:SetTextByKey("name", ScpArgMsg(name))
					end

					local value_text = GET_CHILD_RECURSIVELY(ctrlset, "value")
					if value_text ~= nil then
						local ret_value = "+"..tostring(value)
						value_text:SetTextByKey("value", ret_value)
					end

					idx = idx + 1
				end
			end
		end
	end
	complete_count_text:SetTextByKey("value", complete_count);
end