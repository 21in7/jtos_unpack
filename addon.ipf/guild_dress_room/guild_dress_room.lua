-- guild_dress_room.lua
local json = require "json_imc"

-- sort type
local dress_room_sort_types = {
	none = 0,			
	name_asc = 1,		
	name_desc = 2,		
	level_asc = 3,		
	level_desc = 4
}
-- filter veiw types
local dress_room_view_types = {
	complete = 1,
	unregister = 2,
	incomplete = 3
}
-- filter options
local dress_room_filter_options = {
	show_complete = false,
	show_unregister = false,
	show_incomplete = false,
	show_previewable = false,
	sort_type = dress_room_sort_types.none
}
-- view count
local dress_room_view_count = {
	complete = 0,
	unregister = 0,
	incomplete = 0
}
-- option check list
local dress_room_option_checklist = {
	{ name = "matk_check", prop = "MATK_BM" },
	{ name = "patk_check", prop = "PATK_BM" },
	{ name = "str_check", prop = "STR_BM" },
	{ name = "int_check", prop = "INT_BM" },
	{ name = "con_check", prop = "CON_BM" },
	{ name = "dex_check", prop = "DEX_BM" },
	{ name = "mna_check", prop = "MNA_BM" },
	{ name = "crtatk_check", prop = "CRTATK_BM" },
	{ name = "crtmatk_check", prop = "CRTMATK_BM" },
	{ name = "def_check", prop = "DEF_BM" },
	{ name = "mdef_check", prop = "MDEF_BM" },
	{ name = "blk_check", prop = "BLK_BM" },
	{ name = "blk_break_check", prop = "BLK_BREAK_BM" },
	{ name = "crtdr_check", prop = "CRTDR_BM" },
	{ name = "crthr_check", prop = "CRTHR_BM" },
	{ name = "hr_check", prop = "HR_BM" },
	{ name = "dr_check", prop = "DR_BM" },
	{ name = "mhp_check", prop = "MHP_BM" },
	{ name = "msp_check", prop = "MSP_BM" }
}
-- selected options
local dress_room_selected_options = {}

function GUILD_DRESS_ROOM_ON_INIT(addon, frame)
	addon:RegisterMsg("GUILD_DRESS_ROOM_REGISTER_RESULT", "ON_GUILD_DRESS_ROOM_RESULT")
	addon:RegisterMsg("GUILD_DRESS_ROOM_ITEM_MAKE_RESULT", "ON_GUILD_DRESS_ROOM_RESULT")
end

-- function
---- enable check
local function is_enable_ui_check()
	if IsRaidField() == 1 or IsRaidMap() == 1 or IsPVPField() == 1 or IsPVPServer() == 1 or session.world.IsIntegrateServer() == true or session.colonywar.GetIsColonyWarMap() == true or session.world.IsDungeon() == true then
		ui.SysMsg(ScpArgMsg("CantUsePlace"))
		ui.CloseFrame("guild_dress_room")
		return false
	end
	return true
end

---- get grade
local function get_grade_by_tab_idx(idx)
	local grade = "All"
	if idx == 1 then
		grade = "S"
	elseif idx == 2 then
		grade = "A"
	elseif idx == 3 then
		grade = "B"
	end
	return grade
end

---- set color tone
local function set_icon_color_tone(icon, cur_lv, max_lv)
	local ratio = 0
	if cur_lv > 0 then
		ratio = 0.5 + (cur_lv / max_lv) * 0.5
	end

	if ratio > 1 then
		ratio = 1
	end

	local start_alpha = 136 
	local end_alpha = 255
	local cur_alpha = math.floor(start_alpha + (end_alpha - start_alpha) * ratio)
	
	local start_rgb = 0
	local end_rgb = 255
	local cur_rgb = math.floor(start_rgb + (end_rgb - start_rgb) * ratio)

	local color_tone = string.format("%02X%02X%02X%02X", cur_alpha, cur_rgb, cur_rgb, cur_rgb)
	icon:SetColorTone(color_tone)
end

-- sort function
local function sort_by_name_asc(a, b)
	local a_name = dic.getTranslatedStr(a.name)
	local b_name = dic.getTranslatedStr(b.name)
	return a_name < b_name
end

local function sort_by_name_desc(a, b)
	local a_name = dic.getTranslatedStr(a.name)
	local b_name = dic.getTranslatedStr(b.name)
	return a_name > b_name
end

local function sort_by_level_asc(a, b)
	if a.cur_level ~= b.cur_level then
		return a.cur_level < b.cur_level
	end
	local a_name = dic.getTranslatedStr(a.name)
	local b_name = dic.getTranslatedStr(b.name)
	return a_name < b_name
end

local function sort_by_level_desc(a, b)
	if a.cur_level ~= b.cur_level then
		return a.cur_level > b.cur_level
	end
	local a_name = dic.getTranslatedStr(a.name)
	local b_name = dic.getTranslatedStr(b.name)
	return a_name < b_name
end

---- get item list
local function get_item_inv_list(type)
	local result = {}
	local inv_item_list = session.GetInvItemList()
	FOR_EACH_INVENTORY(inv_item_list, function(inv_item_list, inv_item, result)		
		if inv_item ~= nil then
			if inv_item.type == type and inv_item.isLockState == false then
				local item_obj = GetIES(inv_item:GetObject())
				if shared_guild_dress_room.is_valid_item(item_obj) == true then
					result[#result + 1] = inv_item
				end
			end
		end
	end, false, result);
	table.sort(result, SORT_PURE_INVITEMLIST);
	return result
end

-- search function
---- get search_text
local function get_search_text(frame)
	local search_edit = GET_CHILD_RECURSIVELY(frame, "search_edit", "ui::CEditBox")
	if search_edit == nil then
		return nil
	end

	local search_text = search_edit:GetText()
	if search_text ~= nil and string.len(search_text) > 0 then
		return string.lower(search_text)
	end

	return nil
end

---- check search filter
local function check_search_filter(info, search_text)
	if search_text == nil or string.len(search_text) <= 0 then
		return true
	end
	local name = dic.getTranslatedStr(info.name)
	if name ~= nil then
		name = string.lower(name)
		if string.find(name, search_text) ~= nil then
			return true
		end
	end

	return false
end

-- filter function
---- filter function - view type get
local function get_view_type(info)
	if info.cur_level >= info.max_level then
		return dress_room_view_types.complete
	elseif info.cur_level == 0 then
		return dress_room_view_types.unregister
	else
		return dress_room_view_types.incomplete
	end
end

---- filter function - view type check
local function check_view_filter(info)
	local view_type = get_view_type(info)
	if dress_room_filter_options.show_complete == false and dress_room_filter_options.show_unregister == false and dress_room_filter_options.show_incomplete == false then
		return true
	end

	if view_type == dress_room_view_types.complete and dress_room_filter_options.show_complete then
		return true
	end
	if view_type == dress_room_view_types.unregister and dress_room_filter_options.show_unregister then
		return true
	end
	if view_type == dress_room_view_types.incomplete and dress_room_filter_options.show_incomplete then
		return true
	end

	return false
end

---- filter function - option check
local function check_option_filter(info)
	if #dress_room_selected_options == 0 then
		return true
	end

	local cls = GetClassByType("guild_dress_room", info.type)
	if cls == nil then
		return false
	end

	local max_lv = info.max_level
	for lv = 1, max_lv do
		local prop_name = "Level_"..lv
		local option_str = TryGetProp(cls, prop_name, "None")
		if option_str ~= nil and option_str ~= "" and option_str ~= "None" then
			local option_list = StringSplit(option_str, ';')
			for _, selected_prop in ipairs(dress_room_selected_options) do
				for _, option_item in ipairs(option_list) do
					local option_data = StringSplit(option_item, '/')
					if #option_data > 0 and option_data[1] == selected_prop then
						return true
					end
				end
			end
		end
	end

	return false
end

---- filter function - previewable check
local function check_previewable_filter(info)
	if dress_room_filter_options.show_previewable == false then
		return true
	end

	local item_cls = GetClass("Item", info.class_name)
	if item_cls == nil then
		return false
	end
	
	local prop = geItemTable.GetProp(TryGetProp(item_cls, "ClassID", 0))
	if prop == nil then
		return false
	end

	local lv = GETMYPCLEVEL()
	local job = GETMYPCJOB()
	local gender = GETMYPCGENDER()
	local ret = prop:CheckEquip(lv, job, gender)
	if ret ~= "OK" then
		return false
	end
	return true
end

---- filter function - apply all filter
local function apply_filters(info_list, search_text)
	local filtered_list = {}
	dress_room_view_count.complete = 0
	dress_room_view_count.unregister = 0
	dress_room_view_count.incomplete = 0

	for i, info in ipairs(info_list) do
		local view_type = get_view_type(info)
		if view_type == dress_room_view_types.complete then
			dress_room_view_count.complete = dress_room_view_count.complete + 1
		elseif view_type == dress_room_view_types.unregister then
			dress_room_view_count.unregister = dress_room_view_count.unregister + 1
		else
			dress_room_view_count.incomplete = dress_room_view_count.incomplete + 1
		end

		if check_view_filter(info) and check_option_filter(info) and check_previewable_filter(info) and check_search_filter(info, search_text) then
			table.insert(filtered_list, info)
		end
	end

	if dress_room_filter_options.sort_type == dress_room_sort_types.name_asc then
		table.sort(filtered_list, sort_by_name_asc)
	elseif dress_room_filter_options.sort_type == dress_room_sort_types.name_desc then
		table.sort(filtered_list, sort_by_name_desc)
	elseif dress_room_filter_options.sort_type == dress_room_sort_types.level_asc then
		table.sort(filtered_list, sort_by_level_asc)
	elseif dress_room_filter_options.sort_type == dress_room_sort_types.level_desc then
		table.sort(filtered_list, sort_by_level_desc)
	end
	return filtered_list
end

function GUILD_DRESS_ROOM_OPEN()
	if is_enable_ui_check() == false then
		return
	end
	ui.OpenFrame("guild_dress_room")
	GUILD_DRESS_ROOM_BG_PIC_INIT()
	GUILD_DRESS_ROOM_COSTUME_TAB_INIT()
	GUILD_DRESS_ROOM_PREVIEW_INIT()
	GUILD_DRESS_ROOM_FILTER_INIT()
	GUILD_DRESS_ROOM_NOTICE_INIT()
	GUILD_DRESS_ROOM_RANK_INIT()
end

function GUILD_DRESS_ROOM_CLOSE()
	ui.CloseFrame("guild_dress_room")
	GUILD_DRESS_ROOM_PREVIEW_CLOSE()
	GUILD_DRESS_ROOM_DIGNITY_TOTAL_CLOSE()
	GUILD_DRESS_ROOM_POSE_SELECT_CLOSE()
	dress_room_selected_options = {}
end

function UI_TOGGLE_GUILD_DRESS_ROOM()
    if app.IsBarrackMode() == true then
		return
    end

    if session.world.IsIntegrateServer() == true then
        ui.SysMsg(ScpArgMsg("CantUseThisInIntegrateServer"))
        return
    end

    local guildinfo = session.GetGuildInfo();
    if guildinfo == nil then
        return
    end

	if is_enable_ui_check() == false then
		return
	end
	
	ui.ToggleFrame('guild_dress_room')
end

-- init
---- init - background
function GUILD_DRESS_ROOM_BG_PIC_INIT()
	local frame = ui.GetFrame("guild_dress_room")
	if frame == nil then
		return
	end

	local bg_pic = GET_CHILD_RECURSIVELY(frame, "bg_pic")
	if bg_pic ~= nil then
		local s_grade_img = frame:GetUserConfig("S_GRADE_BACKGROUND_IMAGE_NAME")
		bg_pic:SetImage(s_grade_img)
	end

	local pose_select_gb = GET_CHILD_RECURSIVELY(frame, "pose_select_gb")
	if pose_select_gb ~= nil then
		pose_select_gb:ShowWindow(0)
	end

	local dignity_total_gb = GET_CHILD_RECURSIVELY(frame, "dignity_total_gb")
	if dignity_total_gb ~= nil then
		dignity_total_gb:ShowWindow(0)
	end
end

---- init - tab
function GUILD_DRESS_ROOM_COSTUME_TAB_INIT()
	local frame = ui.GetFrame("guild_dress_room")
	if frame == nil then
		return
	end

	local tab = GET_CHILD_RECURSIVELY(frame, "grade_tab", "ui::CTabControl")
	if tab ~= nil then
		local idx = 0
		tab:SelectTab(idx)
		local grade = get_grade_by_tab_idx(idx)	
		GUILD_DRESS_ROOM_UPDATE_COSTUME_LIST(frame, grade)
		frame:SetUserValue("SELECT_GRADE", grade)
	end
end

---- init - preview
function GUILD_DRESS_ROOM_PREVIEW_INIT()
	local frame = ui.GetFrame("guild_dress_room")
	if frame == nil then
		return
	end

	local preview = GET_CHILD_RECURSIVELY(frame, "preview_main")
	if preview ~= nil then
		preview:SetRenderTargetSize(preview:GetWidth(), preview:GetHeight())
		preview:SetTargetActorByHandle(session.GetMyHandle())
	end
end

---- init - filter
function GUILD_DRESS_ROOM_FILTER_INIT()
	local frame = ui.GetFrame("guild_dress_room")
	if frame == nil then
		return
	end

	local filter_bg = GET_CHILD_RECURSIVELY(frame, "list_filter_bg")
	if filter_bg ~= nil then
		filter_bg:ShowWindow(0)
	end
	
	dress_room_filter_options.show_complete = false
	dress_room_filter_options.show_unregister = false
	dress_room_filter_options.show_incomplete = false
	dress_room_filter_options.show_previewable = false
	dress_room_filter_options.sort_type = dress_room_sort_types.none
	dress_room_selected_options = {}

	local name_asc_check = GET_CHILD_RECURSIVELY(frame, "name_asc_sort_check")
	if name_asc_check ~= nil then 
		name_asc_check:SetCheck(0) 
	end
	local name_desc_check = GET_CHILD_RECURSIVELY(frame, "name_desc_sort_check")
	if name_desc_check ~= nil then 
		name_desc_check:SetCheck(0) 
	end
	local level_asc_check = GET_CHILD_RECURSIVELY(frame, "level_asc_sort_check")
	if level_asc_check ~= nil then 
		level_asc_check:SetCheck(0) 
	end
	local level_desc_check = GET_CHILD_RECURSIVELY(frame, "level_desc_sort_check")
	if level_desc_check ~= nil then 
		level_desc_check:SetCheck(0) 
	end

	local complete_check = GET_CHILD_RECURSIVELY(frame, "complete_check")
	if complete_check ~= nil then 
		complete_check:SetCheck(0) 
	end
	local unregister_check = GET_CHILD_RECURSIVELY(frame, "unregister_check")
	if unregister_check ~= nil then 
		unregister_check:SetCheck(0) 
	end
	local incomplete_check = GET_CHILD_RECURSIVELY(frame, "incomplete_check")
	if incomplete_check ~= nil then 
		incomplete_check:SetCheck(0) 
	end
	local previewable_check = GET_CHILD_RECURSIVELY(frame, "previewable_check")
	if previewable_check ~= nil then
		previewable_check:SetCheck(0)
	end

	for i, info in ipairs(dress_room_option_checklist) do
		local check = GET_CHILD_RECURSIVELY(frame, info.name)
		if check ~= nil then
			check:SetCheck(0)
		end
	end
end

---- init - notice
function GUILD_DRESS_ROOM_NOTICE_INIT()
	local frame = ui.GetFrame("guild_dress_room")
	if frame == nil then
		return
	end

	local notice_text = GET_CHILD_RECURSIVELY(frame, "notice_text")
	if notice_text ~= nil then
		notice_text:SetTextByKey("text_1", ScpArgMsg("GuildDressRoomNoticeMsg1"))
		notice_text:SetTextByKey("text_2", ScpArgMsg("GuildDressRoomNoticeMsg2"))
	end
end

---- init - rank
function GUILD_DRESS_ROOM_RANK_INIT()
	GetGuildDressRoomRank("GUILD_DRESS_ROOM_RANK_CALLBACK")
end

-- callback
---- rank callback
function GUILD_DRESS_ROOM_RANK_CALLBACK(code, ret_json)
	if code == 200 then
		local ret = json.decode(ret_json)
		GUILD_DRESS_ROOM_MAKE_RANK_INFO(ret)
	end
end

---- rank info remove
function GUILD_DRESS_ROOM_REMOVE_RANK_INFO(frame)
	local gbox = GET_CHILD_RECURSIVELY(frame, "list_top_bg")
	if gbox ~= nil then
		DESTROY_CHILD_BYNAME(gbox, "DRESS_ROOM_RANK_INFO_")
	end
end

---- rank info make
function GUILD_DRESS_ROOM_MAKE_RANK_INFO(ret)
	local frame = ui.GetFrame("guild_dress_room")
	if frame ~= nil then
		local gbox = GET_CHILD_RECURSIVELY(frame, "list_top_bg")
		if gbox ~= nil then
			local rank_count = 3
			local width = ui.GetControlSetAttribute("guild_dress_room_rank_info_1", "width")
			local start_x = 100
			for i = 1, rank_count do
				local info = ret['list'][i]
				if info ~= nil then
					local x = start_x + (width * (i - 1))
					local ctrlset = gbox:CreateOrGetControlSet("guild_dress_room_rank_info_"..i, "DRESS_ROOM_RANK_INFO_"..i, x, 0)
					if ctrlset ~= nil then
						local rank_pic = GET_CHILD_RECURSIVELY(ctrlset, "rank")
						if rank_pic ~= nil then
							local image_name = "guild_dress_room_rank_"..i
							rank_pic:SetImage(image_name)
						end
						
						local team_name = info['team_name']
						if team_name ~= "" and team_name ~= "None" then
							local team_name_text = GET_CHILD_RECURSIVELY(ctrlset, "team_name")
							if team_name_text ~= nil then
								team_name_text:SetTextByKey("name", team_name)
							end
						end

						local donation_count = info['donation_count']
						if donation_count > 0 then
							local donation_count_text =  GET_CHILD_RECURSIVELY(ctrlset, "donation_count")
							if donation_count_text ~= nil then
								donation_count_text:SetTextByKey("count", donation_count)
							end
						end
					end
				end
			end
		end
	end
end

-- close
---- close - preview
function GUILD_DRESS_ROOM_PREVIEW_CLOSE()
	local frame = ui.GetFrame("guild_dress_room")
	if frame == nil then
		return
	end

	local preview = GET_CHILD_RECURSIVELY(frame, "preview_main")
	if preview ~= nil then
		preview:ClearPreviewActor()
	end

	GUILD_DRESS_ROOM_REMOVE_RANK_INFO(frame)
end

-- costume
---- costume - tab
function GUILD_DRESS_ROOM_COSTUME_TAB_CHANGE(frame, ctrl, arg_str, arg_num)
	if frame == nil then
		return
	end

	local top_frame = frame:GetTopParentFrame()
	if top_frame == nil then
		return
	end

	local tab = GET_CHILD_RECURSIVELY(top_frame, "grade_tab", "ui::CTabControl")
	if tab ~= nil then
		local idx = tab:GetSelectItemIndex()
		local grade = get_grade_by_tab_idx(idx)	
		GUILD_DRESS_ROOM_UPDATE_COSTUME_LIST(top_frame, grade)
		top_frame:SetUserValue("SELECT_GRADE", grade)
	end
end

---- costume - update list
function GUILD_DRESS_ROOM_UPDATE_COSTUME_LIST(frame, grade)
	local info_list = shared_guild_dress_room.get_guild_dress_room_info_list(nil, grade)
	if info_list == nil or #info_list <= 0 then
		return
	end	

	local search_text = get_search_text(frame)
	local filtered_list = apply_filters(info_list, search_text)

	GUILD_DRESS_ROOM_MAKE_COSTUME_SLOT(frame, filtered_list)
end

---- costume - scroll setting
function GUILD_DRESS_ROOM_COSTUME_GBOX_SCROLL_SETTING(gbox)
	local frame = gbox:GetTopParentFrame()
	if frame ~= nil then
		local scroll_bar_margin = tonumber(frame:GetUserConfig("SCROLL_BAR_MARGIN"))
		gbox:SetScrollBar(gbox:GetHeight())
		gbox:SetVisibleLineBottomMargin(scroll_bar_margin)
		gbox:SetScrollBarBottomMargin(scroll_bar_margin)
		gbox:InvalidateScrollBar()
		gbox:SetScrollPos(0)
	end
end

---- costume - make slot
function GUILD_DRESS_ROOM_MAKE_COSTUME_SLOT(frame, info_list)
	local gbox = GET_CHILD_RECURSIVELY(frame, "list_main_bg")
	if gbox == nil then
		return
	end
	DESTROY_CHILD_BYNAME(gbox, "DRESS_ROOM_SLOT_")
	GUILD_DRESS_ROOM_COSTUME_GBOX_SCROLL_SETTING(gbox)

	local max = #info_list
	local margin_x = tonumber(frame:GetUserConfig("DRAW_MARGIN_X"))
	local margin_y = tonumber(frame:GetUserConfig("DRAW_MARGIN_Y"))
	local space = tonumber(frame:GetUserConfig("DRAW_SPACE"))
	local limit_count = tonumber(frame:GetUserConfig("DRAW_LIMIT_COUNT"))
	local count = math.ceil(max / limit_count)

	local is_break = 0
	local gbox_width = gbox:GetWidth()
	local slot_width = ui.GetControlSetAttribute("guild_dress_room_slot", "width")
	local slot_height = ui.GetControlSetAttribute("guild_dress_room_slot", "height")
	local idx = 0
	for i = 1, count do
		for j = 1, limit_count do
			local info = info_list[idx + 1]
			if info ~= nil then
				if idx > max then
					is_break = 1
					break
				end

				local type = info.type
				local class_name = info.class_name
				local name = info.name
				local cur_lv = info.cur_level
				local max_lv = info.max_level
				local unlock_lv = info.unlock_level
				local grade = info.grade
				local item_cls = GetClass("Item", class_name)
				if item_cls == nil then
					is_break = 1
					break
				end

				local class_id = TryGetProp(item_cls, "ClassID", 0)
				local row = i
				local col = (j - 1) % limit_count
				local x = margin_x + col * (slot_width + space)
				local y = margin_y + (row - 1) * (slot_height + space)
				local ctrlset = gbox:CreateOrGetControlSet("guild_dress_room_slot", "DRESS_ROOM_SLOT_"..idx, x, y)
				if ctrlset ~= nil then
					ctrlset:SetUserValue("DRESS_DROP", class_name)
					ctrlset:SetUserValue("GRADE", grade)
					-- btn
					local btn = GET_CHILD_RECURSIVELY(ctrlset, "btn")
					if btn ~= nil then
						btn:ShowWindow(0)
						btn:SetTooltipOverlap(0)
						if session.GetInvItemCountByType(class_id) > 0 then
							btn:ShowWindow(1)
						end
					end
					local inventory_btn = GET_CHILD_RECURSIVELY(ctrlset, "inventory_btn")
					if inventory_btn ~= nil then
						inventory_btn:SetUserValue("TYPE", type)
						inventory_btn:ShowWindow(0)
					end
					-- pic
					local complete_pic = GET_CHILD_RECURSIVELY(ctrlset, "complete_pic")
					if complete_pic ~= nil then
						complete_pic:ShowWindow(0)
					end
					-- slot
					local slot = GET_CHILD_RECURSIVELY(ctrlset, "slot", "ui::CSlot")
					if slot ~= nil and btn ~= nil and inventory_btn ~= nil and complete_pic ~= nil then
						slot:SetUserValue("TYPE", type)
						slot:SetUserValue("ITEM_NAME", class_name)
						local icon = CreateIcon(slot)
						if icon ~= nil then
							local icon_name = GET_ITEM_ICON_IMAGE(item_cls, "Icon")
							if icon_name ~= "None" then
								icon:SetImage(icon_name)
								icon:SetTooltipOverlap(0)
								if cur_lv < max_lv then
									set_icon_color_tone(icon, cur_lv, max_lv)
									btn:ShowWindow(1)
									complete_pic:ShowWindow(0)
								else
									set_icon_color_tone(icon, cur_lv, max_lv)
									btn:ShowWindow(0)
									inventory_btn:ShowWindow(1)
									complete_pic:ShowWindow(1)
								end
								SET_ITEM_TOOLTIP_ALL_TYPE(icon, nil, class_name, "collection", class_id, class_id)
								SET_ITEM_TOOLTIP_ALL_TYPE(btn, nil, class_name, "collection", class_id, class_id)
							end
						end
					end
					-- garde
					local grade_pic = GET_CHILD_RECURSIVELY(ctrlset, "grade_pic")
					if grade_pic ~= nil then
						local suffix = string.lower(grade)
						local image_name = "guild_dress_room_rank_"..suffix
						grade_pic:SetImage(image_name)
					end
					-- name
					local name_text = GET_CHILD_RECURSIVELY(ctrlset, "name")
					if name_text ~= nil then
						if cur_lv >= max_lv then
							local complete_font = frame:GetUserConfig("COMPLETE_DECK_TITLE_FONT")
							name = complete_font..name
						end
						name_text:SetTextByKey("name", name)
					end
					-- level
					local level_text = GET_CHILD_RECURSIVELY(ctrlset, "level")
					if level_text ~= nil then
						level_text:SetTextByKey("level", cur_lv)
						level_text:SetTextByKey("max_level", max_lv)
					end
					-- desc
					local desc_text = GET_CHILD_RECURSIVELY(ctrlset, "desc")
					if desc_text ~= nil then
						local cls = GetClassByType("guild_dress_room", type)
						if cls ~= nil then
							local option_str = shared_guild_dress_room.get_item_option_list_from_cls_and_level(cls, cur_lv)
							local desc = ""
							if option_str ~= "None" then
								local desc_parts = {}
								local option_list = StringSplit(option_str, ';')
								for k = 1, #option_list do
									local option_data = StringSplit(option_list[k], '/')
									if #option_data > 0 then
										desc_parts[#desc_parts + 1] = "{nl}{@st42}- {#00ccff}" .. ClMsg(option_data[1]) .. " {#ffffff}+" .. option_data[2] .. "{/}"
									end
								end
								desc = table.concat(desc_parts)
							end
							desc_text:SetTextByKey("desc", desc)
						end
					end
					-- rental
					local rental_text = GET_CHILD_RECURSIVELY(ctrlset, "rental")
					if rental_text ~= nil then
						local rental_count = shared_guild_dress_room.get_guild_dress_room_rental_count(nil, type)
						rental_text:SetTextByKey("rental_count", rental_count)
					end
					idx = idx + 1
				end
			end
		end
		if is_break == 1 then
			break
		end
	end
	gbox:Invalidate()
end

---- costume - drop
function GUILD_DRESS_ROOM_DROP(parent, ctrl)
	local frame = parent:GetTopParentFrame()
	if frame == nil then
		return
	end

	local slot = GET_CHILD_RECURSIVELY(parent, "slot", "ui::CSlot")
	if slot == nil then
		return
	end

	local lift_icon = ui.GetLiftIcon():GetInfo()
	local ies_id = lift_icon:GetIESID()
	local item_type = lift_icon.type
	local inv_item = session.GetInvItemByGuid(ies_id)
	if inv_item == nil then
		return
	end

	local inv_item_obj = GetIES(inv_item:GetObject())
	if inv_item_obj == nil then
		return
	end

	local is_enable, msg = shared_guild_dress_room.is_valid_item(inv_item_obj)
	if is_enable == false then
		ui.SysMsg(ScpArgMsg(msg))
		return
	end

	local item_class_name = TryGetProp(inv_item_obj, "ClassName", "None")
	local slot_item_name = slot:GetUserValue("ITEM_NAME")
	if slot_item_name ~= item_class_name then
		ui.SysMsg(ScpArgMsg("InconsistentGuildDressRoomItem"))
		return
	end
	
	local slot_type = slot:GetUserValue("TYPE")
	frame:SetUserValue("DRESS_ROOM_ITEM_IES_ID", ies_id)
	frame:SetUserValue("DRESS_ROOM_ITEM_TYPE", slot_type)
	
	local item_name = TryGetProp(inv_item_obj, "Name", "None")
	local check_msg = ScpArgMsg("ReallyRegisterGuildDressRoomItem", "item", dic.getTranslatedStr(item_name))
	local check_yes_scp = "GUILD_DRESS_ROOM_REGISTER()"
	local check_msg_box = ui.MsgBox(check_msg, check_yes_scp, "None")
	SET_MODAL_MSGBOX(check_msg_box)
end

---- costume - take
function GUILD_DRESS_ROOM_TAKE(parent, ctrl)
	local frame = parent:GetTopParentFrame()
	if frame == nil then
		return
	end

	local slot = GET_CHILD_RECURSIVELY(parent, "slot", "ui::CSlot")
	if slot == nil then
		return
	end

	local icon = slot:GetIcon()
	if icon == nil then
		return
	end

	local item_type = icon:GetTooltipIESID()
	local item_cls = GetClassByType("Item", item_type)
	if item_cls == nil then
		return
	end

	local inv_item_list = get_item_inv_list(tonumber(item_type))
	if inv_item_list == nil or #inv_item_list <= 0 then
		ui.SysMsg(ScpArgMsg("DoNotExistItemGuildDressRoom"))
		return
	end

	local inv_item = inv_item_list[1]
	if inv_item == nil then
		return
	end

	local inv_item_obj = GetIES(inv_item:GetObject())
	if inv_item_obj == nil then
		return
	end

	local is_enable, msg = shared_guild_dress_room.is_valid_item(inv_item_obj)
	if is_enable == false then
		ui.SysMsg(ScpArgMsg(msg))
		return
	end

	local ies_id = inv_item:GetIESID()
	local slot_type = slot:GetUserValue("TYPE")
	frame:SetUserValue("DRESS_ROOM_ITEM_IES_ID", ies_id)
	frame:SetUserValue("DRESS_ROOM_ITEM_TYPE", slot_type)

	local item_name = TryGetProp(inv_item_obj, "Name", "None")
	local check_msg = ScpArgMsg("ReallyRegisterGuildDressRoomItem", "item", dic.getTranslatedStr(item_name))
	local check_yes_scp = "GUILD_DRESS_ROOM_REGISTER()"
	local check_msg_box = ui.MsgBox(check_msg, check_yes_scp, "None")
	SET_MODAL_MSGBOX(check_msg_box)
end

---- costume - register
function GUILD_DRESS_ROOM_REGISTER()
	local frame = ui.GetFrame("guild_dress_room")
	if frame == nil then
		return
	end

	local ies_id = frame:GetUserValue("DRESS_ROOM_ITEM_IES_ID")
	local type = frame:GetUserValue("DRESS_ROOM_ITEM_TYPE")
	local inv_item = session.GetInvItemByGuid(ies_id)
	if inv_item ~= nil then
		local inv_item_obj = GetIES(inv_item:GetObject())
		if inv_item_obj ~= nil then
			local class_name = TryGetProp(inv_item_obj, "ClassName", "None")
			frame:SetUserValue("LAST_REGISTER_CLASS_NAME", class_name)
		end
		pc.ReqExecuteTx_Item("LEVEL_UP_GUILD_DRESS_ROOM", ies_id, tonumber(type))
	end
end

---- costume - register result
function ON_GUILD_DRESS_ROOM_RESULT(frame, msg, arg_str, arg_num)
	frame = ui.GetFrame("guild_dress_room")
	if frame == nil then
		return
	end

	if msg == "GUILD_DRESS_ROOM_REGISTER_RESULT" then
		local class_name = frame:GetUserValue("LAST_REGISTER_CLASS_NAME")
		local type = tonumber(frame:GetUserValue("DRESS_ROOM_ITEM_TYPE"))
		local new_level = arg_num
		if class_name ~= nil and class_name ~= "" and class_name ~= "None" then
			GUILD_DRESS_ROOM_UPDATE_SINGLE_SLOT(frame, class_name, type, new_level, nil)
		else
			local grade = frame:GetUserValue("SELECT_GRADE")
			GUILD_DRESS_ROOM_UPDATE_COSTUME_LIST(frame, grade)
		end
	elseif msg == "GUILD_DRESS_ROOM_ITEM_MAKE_RESULT" then
		local arg_str_list = StringSplit(arg_str, "/")
		if #arg_str_list > 0 then
			local class_name = arg_str_list[1]
			local rental_count = tonumber(arg_str_list[2])
			local now_level = arg_num
			if class_name ~= nil and class_name ~= "" and class_name ~= "None" then
				GUILD_DRESS_ROOM_UPDATE_SINGLE_SLOT(frame, class_name, nil, now_level, rental_count)
			end
		end
	end

	frame:Invalidate()
end

---- costume - update single slot
function GUILD_DRESS_ROOM_UPDATE_SINGLE_SLOT(frame, class_name, type, new_level, rental_count)
	local gbox = GET_CHILD_RECURSIVELY(frame, "list_main_bg")
	if gbox == nil then
		return
	end

	local info_list = shared_guild_dress_room.get_guild_dress_room_info_list(nil, "All")
	local target_info = nil
	if info_list ~= nil then
		for _, info in ipairs(info_list) do
			if info.class_name == class_name then
				target_info = info
				break
			end
		end
	end

	if target_info == nil then
		return
	end

	if new_level ~= nil and new_level > 0 then
		target_info.cur_level = new_level
	else
		target_info.cur_level = target_info.cur_level + 1
		if target_info.cur_level > target_info.max_level then
			target_info.cur_level = target_info.max_level
		end
	end

	local child_count = gbox:GetChildCount()
	for i = 0, child_count - 1 do
		local child = gbox:GetChildByIndex(i)
		if child ~= nil then
			local child_name = child:GetName()
			if string.find(child_name, "DRESS_ROOM_SLOT_") then
				local slot_class_name = child:GetUserValue("DRESS_DROP")
				if slot_class_name == class_name then
					GUILD_DRESS_ROOM_UPDATE_SLOT_UI(frame, child, target_info, rental_count)
					break
				end
			end
		end
	end
end

---- costume - update slot ui
function GUILD_DRESS_ROOM_UPDATE_SLOT_UI(frame, ctrlset, info, rental_count)
	if ctrlset == nil or info == nil then
		return
	end

	local type = info.type
	local class_name = info.class_name
	local name = info.name
	local cur_lv = info.cur_level
	local max_lv = info.max_level
	local grade = info.grade
	local item_cls = GetClass("Item", class_name)
	if item_cls == nil then
		return
	end

	local class_id = TryGetProp(item_cls, "ClassID", 0)
	local btn = GET_CHILD_RECURSIVELY(ctrlset, "btn")
	if btn ~= nil then
		btn:ShowWindow(0)
		if cur_lv < max_lv and session.GetInvItemCountByType(class_id) > 0 then
			btn:ShowWindow(1)
		end
	end

	local inventory_btn = GET_CHILD_RECURSIVELY(ctrlset, "inventory_btn")
	if inventory_btn ~= nil then
		inventory_btn:SetUserValue("TYPE", type)
		inventory_btn:ShowWindow(0)
	end

	-- slot
	local slot = GET_CHILD_RECURSIVELY(ctrlset, "slot", "ui::CSlot")
	if slot ~= nil and btn ~= nil and inventory_btn ~= nil then
		local icon = slot:GetIcon()
		if icon ~= nil then
			if cur_lv < max_lv then
				set_icon_color_tone(icon, cur_lv, max_lv)
			else
				set_icon_color_tone(icon, cur_lv, max_lv)
				btn:ShowWindow(0)
				inventory_btn:ShowWindow(1)
			end
		end
		-- effect
		if rental_count == nil then
			if cur_lv >= max_lv then
				local effect_name = frame:GetUserConfig("EFFECT_COMPLETE")
				local effect_scale = tonumber(frame:GetUserConfig("EFFECT_COMPLETE_SCALE"))
				slot:PlayUIEffect(effect_name, effect_scale, 'GUILD_DRESS_ROOM_COMPLETE_EFFECT', true)
			else
				local effect_name = frame:GetUserConfig("EFFECT_LEVEL_UP")
				local effect_scale = tonumber(frame:GetUserConfig("EFFECT_LEVEL_UP_SCALE"))
				slot:PlayUIEffect(effect_name, effect_scale, 'GUILD_DRESS_ROOM_LEVELUP_EFFECT', true)
			end
		end
	end

	-- level
	local level_text = GET_CHILD_RECURSIVELY(ctrlset, "level")
	if level_text ~= nil then
		level_text:SetTextByKey("level", cur_lv)
		level_text:SetTextByKey("max_level", max_lv)
		level_text:Invalidate()
	end

	-- desc
	if desc_text ~= nil then
		local cls = GetClassByType("guild_dress_room", type)
		if cls ~= nil then
			local option_str = shared_guild_dress_room.get_item_option_list_from_cls_and_level(cls, cur_lv)
			local desc = ""
			if option_str ~= "None" then
				local desc_parts = {}
				local option_list = StringSplit(option_str, ';')
				for k = 1, #option_list do
					local option_data = StringSplit(option_list[k], '/')
					if #option_data > 0 then
						desc_parts[#desc_parts + 1] = "{nl}{@st42}- {#00ccff}" .. ClMsg(option_data[1]) .. " {#ffffff}+" .. option_data[2] .. "{/}"
					end
				end
				desc = table.concat(desc_parts)
			end
			desc_text:SetTextByKey("desc", desc)
			desc_text:Invalidate()
		end
	end

	-- rental
	local rental_text = GET_CHILD_RECURSIVELY(ctrlset, "rental")
	if rental_text ~= nil then
		local rental_count = shared_guild_dress_room.get_guild_dress_room_rental_count(nil, type)
		rental_text:SetTextByKey("rental_count", rental_count)
	end
	ctrlset:Invalidate()
end

---- costume - make item
function ON_GUILD_DRESS_ROOM_COSTUME_MAKE_ITEM(parent, ctrl)
	local ctrlset = parent
	if ctrlset == nil then
		return
	end

	local class_name = ctrlset:GetUserValue("DRESS_DROP")
	if class_name == nil or class_name == "None" then
		return
	end

	local item_cls = GetClass("Item", class_name)
	if item_cls == nil then
		return
	end

	local cls = GetClass("guild_dress_room", class_name)
	if cls == nil then
		return
	end

	local frame = parent:GetTopParentFrame()
	if frame ~= nil then
		local effect_name = frame:GetUserConfig("EFFECT_PREVIEW")
		local effect_scale = tonumber(frame:GetUserConfig("EFFECT_PREVIEW_SCALE"))
		ctrl:PlayUIEffect(effect_name, effect_scale, 'GUILD_DRESS_ROOM_PREVIEW_EFFECT', true)
	end
	
	local inv_item = session.GetInvItemByName(class_name)
	if inv_item ~= nil then
		addon.BroadMsg("NOTICE_Dm_!", ClMsg("Auto_iMi_aiTemeul_KaJiKo_issSeupNiDa"), 3)
		return
	end

	local equip_item = session.GetEquipItemBySpot(item.GetEquipSpotNum('OUTER'))
	if equip_item ~= nil then
		local equip_obj = GetIES(equip_item:GetObject())
		if equip_obj ~= nil then			
			if TryGetProp(equip_obj, 'ClassName', 'None') == class_name then
				addon.BroadMsg("NOTICE_Dm_!", ClMsg("Auto_iMi_aiTemeul_KaJiKo_issSeupNiDa"), 3)
				return
			end
		end
	end
	
	if session.GetWarehouseItemByType(TryGetProp(item_cls, "ClassID", 0)) ~= nil then
		addon.BroadMsg("NOTICE_Dm_!", ClMsg("Auto_iMi_aiTemeul_KaJiKo_issSeupNiDa"), 3)
		return
	end

	local slot_type = ctrl:GetUserValue("TYPE")
	pc.ReqExecuteTx_Item("MAKE_COSTUME_GUILD_DRESS_ROOM", slot_type)
end

----- costume - dignity total
function GUILD_DRESS_ROOM_OPEN_DIGNITY_TOTAL(parent, ctrl)
	local frame = parent:GetTopParentFrame()
	if frame ~= nil then
		local dignity_total_gb = GET_CHILD_RECURSIVELY(frame, "dignity_total_gb")
		local dignity_total_frame = ui.GetFrame("guild_dress_room_dignity_total")
		if dignity_total_gb ~= nil and dignity_total_frame ~= nil then
			if dignity_total_frame:IsVisible() == 0 then
				local dignity_data_str = shared_guild_dress_room.get_guild_dignity_total_str()
				local complet_list = shared_guild_dress_room.get_guild_dress_room_complete_count(nil, "All")
				GUILD_DRESS_ROOM_DIGNITY_TOTAL_OPEN(dignity_total_frame, dignity_data_str, complet_list["All"].complete_count)
				dignity_total_gb:ShowWindow(1)
			else
				GUILD_DRESS_ROOM_DIGNITY_TOTAL_CLOSE(dignity_total_frame)
				dignity_total_gb:ShowWindow(0)
			end
		end
	end
end

-- preview
---- preview - left rotate
function GUILD_DRESS_ROOM_PREVIEW_LEFT_ROTATE(parent, ctrl)
	local frame = parent:GetTopParentFrame()
	if frame ~= nil then
		local preview = GET_CHILD_RECURSIVELY(frame, "preview_main")
		if preview ~= nil then
			preview:RotateLeft()
		end
	end
end

---- preview - right rotate
function GUILD_DRESS_ROOM_PREVIEW_RIGHT_ROTATE(parent, ctrl)
	local frame = parent:GetTopParentFrame()
	if frame ~= nil then
		local preview = GET_CHILD_RECURSIVELY(frame, "preview_main")
		if preview ~= nil then
			preview:RotateRight()
		end
	end
end

---- preview - pose
function GUILD_DRESS_ROOM_PREVIEW_POSE(parent, ctrl)
	local frame = parent:GetTopParentFrame()
	if frame ~= nil then
		local pose_select_gb = GET_CHILD_RECURSIVELY(frame, "pose_select_gb")
		local pose_select_frame = ui.GetFrame("guild_dress_room_pose_select")
		if pose_select_gb ~= nil and pose_select_frame ~= nil and pose_select_frame:IsVisible() == 0 then
			ui.OpenFrame("guild_dress_room_pose_select")
			pose_select_gb:ShowWindow(1)
		else
			ui.CloseFrame("guild_dress_room_pose_select")
			pose_select_gb:ShowWindow(0)
		end
	end
end

---- preview - play pose
function GUILD_DRESS_ROOM_PREVIEW_PLAY_POSE(frame, ctrl, arg_str, arg_num)
	frame = ui.GetFrame("guild_dress_room")
	if frame == nil then
		return
	end

	local preview = GET_CHILD_RECURSIVELY(frame, "preview_main")
	if preview ~= nil then
		local cls = GetClassByType("Pose", arg_num)
		if cls ~= nil then
			local class_name = TryGetProp(cls, "ClassName", "None")
			preview:PlayPose(class_name)
		end
	end
end

---- preview - reset pos
function GUILD_DRESS_ROOM_PREVIEW_RESET_POSE(parent, btn)
	local frame = ui.GetFrame("guild_dress_room")
	if frame == nil then
		return
	end

	local preview = GET_CHILD_RECURSIVELY(frame, "preview_main")
	if preview ~= nil then
		preview:SetIdleAnimation(true)
	end
end

---- preview - costume preivew : bg img change
function GUILD_DRESS_ROOM_PREVIEW_COSTUME_BG_IMG_CHANGE(type)
	local frame = ui.GetFrame("guild_dress_room")
	if frame ~= nil then
		local item_cls = GetClassByType("Item", type)
		if item_cls ~= nil then
			local item_cls_name = TryGetProp(item_cls, "ClassName", "None")
			local dress_room_cls = GetClass("guild_dress_room", item_cls_name)
			if dress_room_cls ~= nil then
				local grade = TryGetProp(dress_room_cls, "Grade", "None")
				if grade ~= "None" then
					local bg_pic = GET_CHILD_RECURSIVELY(frame, "bg_pic")
					if bg_pic ~= nil then
						local prop_name = grade.."_GRADE_BACKGROUND_IMAGE_NAME"
						local img = frame:GetUserConfig(prop_name)
						bg_pic:SetImage(img)
					end
				end
			end
		end
	end
end

---- preivew - costume preview
function GUILD_DRESS_ROOM_PREVIEW_COSTUME(parent, btn)
	local ctrlset = parent
	if ctrlset == nil then
		return
	end

	local frame = ctrlset:GetTopParentFrame()
	if frame == nil then
		return
	end

	local class_name = ctrlset:GetUserValue("DRESS_DROP")
	if class_name == nil or class_name == "None" then
		return
	end

	local cls = GetClass("Item", class_name)
	if cls == nil then
		return
	end

	local preview = GET_CHILD_RECURSIVELY(frame, "preview_main")
	if preview ~= nil then
		local spot = item.GetEquipSpotNum('OUTER') 
		local class_id = TryGetProp(cls, "ClassID", 0)
		if spot ~= nil and class_id ~= 0 then
			preview:SetPreviewItem(spot, class_id)
		end
	
	end

	local effect_name = frame:GetUserConfig("EFFECT_PREVIEW")
	local effect_scale = tonumber(frame:GetUserConfig("EFFECT_PREVIEW_SCALE"))
	btn:PlayUIEffect(effect_name, effect_scale, 'GUILD_DRESS_ROOM_PREVIEW_EFFECT', true)
end

-- filter & sort
---- filter & sort - btn
function GUILD_DRESS_ROOM_SORT_FILTER_TOGGLE(parent, ctrl)
	local frame = parent:GetTopParentFrame()
	if frame == nil then
		return
	end

	local filter_bg = GET_CHILD_RECURSIVELY(frame, "list_filter_bg")
	if filter_bg ~= nil then
		if filter_bg:IsVisible() == 0 then
			filter_bg:ShowWindow(1)
		else
			filter_bg:ShowWindow(0)
		end
	end
end

---- sort
function GUILD_DRESS_ROOM_SORT_CHECK(parent, ctrl)
	local frame = parent:GetTopParentFrame()
	if frame == nil then
		return
	end
	
	local name_asc_check = GET_CHILD_RECURSIVELY(frame, "name_asc_sort_check")
	local name_desc_check = GET_CHILD_RECURSIVELY(frame, "name_desc_sort_check")
	local level_asc_check = GET_CHILD_RECURSIVELY(frame, "level_asc_sort_check")
	local level_desc_check = GET_CHILD_RECURSIVELY(frame, "level_desc_sort_check")

	local ctrl_name = ctrl:GetName()
	if ctrl_name ~= "name_asc_sort_check" then 
		name_asc_check:SetCheck(0) 
	end
	if ctrl_name ~= "name_desc_sort_check" then 
		name_desc_check:SetCheck(0) 
	end
	if ctrl_name ~= "level_asc_sort_check" then 
		level_asc_check:SetCheck(0) 
	end
	if ctrl_name ~= "level_desc_sort_check" then 
		level_desc_check:SetCheck(0) 
	end
	
	local is_checked = ctrl:IsChecked()
	if is_checked == 1 then
		if ctrl_name == "name_asc_sort_check" then
			dress_room_filter_options.sort_type = dress_room_sort_types.name_asc
		elseif ctrl_name == "name_desc_sort_check" then
			dress_room_filter_options.sort_type = dress_room_sort_types.name_desc
		elseif ctrl_name == "level_asc_sort_check" then
			dress_room_filter_options.sort_type = dress_room_sort_types.level_asc
		elseif ctrl_name == "level_desc_sort_check" then
			dress_room_filter_options.sort_type = dress_room_sort_types.level_desc
		end
	else
		dress_room_filter_options.sort_type = dress_room_sort_types.none
	end

	local grade = frame:GetUserValue("SELECT_GRADE")
	GUILD_DRESS_ROOM_UPDATE_COSTUME_LIST(frame, grade)
end

---- filter - complete
function GUILD_DRESS_ROOM_FILTER_COMPLETE_CHECK(parent, ctrl)
	local frame = parent:GetTopParentFrame()
	if frame == nil then
		return
	end

	local complete_check = GET_CHILD_RECURSIVELY(frame, "complete_check")
	local unregister_check = GET_CHILD_RECURSIVELY(frame, "unregister_check")
	local incomplete_check = GET_CHILD_RECURSIVELY(frame, "incomplete_check")
	local previewable_check = GET_CHILD_RECURSIVELY(frame, "previewable_check")

	dress_room_filter_options.show_complete = complete_check:IsChecked() == 1
	dress_room_filter_options.show_unregister = unregister_check:IsChecked() == 1
	dress_room_filter_options.show_incomplete = incomplete_check:IsChecked() == 1
	dress_room_filter_options.show_previewable = previewable_check:IsChecked() == 1

	local grade = frame:GetUserValue("SELECT_GRADE")
	GUILD_DRESS_ROOM_UPDATE_COSTUME_LIST(frame, grade)
end

---- filter - option
function GUILD_DRESS_ROOM_FILTER_OPTION_CHECK(parent, ctrl)
	local frame = parent:GetTopParentFrame()
	if frame == nil then
		return
	end

	dress_room_selected_options = {}
	for i, info in ipairs(dress_room_option_checklist) do
		local check = GET_CHILD_RECURSIVELY(frame, info.name)
		if check ~= nil and check:IsChecked() == 1 then
			table.insert(dress_room_selected_options, info.prop)
		end
	end

	local grade = frame:GetUserValue("SELECT_GRADE")
	GUILD_DRESS_ROOM_UPDATE_COSTUME_LIST(frame, grade)
end

---- filter - all select
function GUILD_DRESS_ROOM_FILTER_ALL_SELECT_BTN(parent, btn)
	local frame = parent:GetTopParentFrame()
	if frame == nil then
		return
	end

	local complete_check = GET_CHILD_RECURSIVELY(frame, "complete_check")
	local unregister_check = GET_CHILD_RECURSIVELY(frame, "unregister_check")
	local incomplete_check = GET_CHILD_RECURSIVELY(frame, "incomplete_check")
	local previewable_check = GET_CHILD_RECURSIVELY(frame, "previewable_check")
	complete_check:SetCheck(1)
	unregister_check:SetCheck(1)
	incomplete_check:SetCheck(1)
	previewable_check:SetCheck(1)

	dress_room_filter_options.show_complete = true
	dress_room_filter_options.show_unregister = true
	dress_room_filter_options.show_incomplete = true
	dress_room_filter_options.show_previewable = true

	local grade = frame:GetUserValue("SELECT_GRADE")
	GUILD_DRESS_ROOM_UPDATE_COSTUME_LIST(frame, grade)
end

---- filter - all deselect
function GUILD_DRESS_ROOM_FILTER_ALL_DESELECT_BTN(parent, btn)
	local frame = parent:GetTopParentFrame()
	if frame == nil then
		return
	end

	local complete_check = GET_CHILD_RECURSIVELY(frame, "complete_check")
	local unregister_check = GET_CHILD_RECURSIVELY(frame, "unregister_check")
	local incomplete_check = GET_CHILD_RECURSIVELY(frame, "incomplete_check")
	local previewable_check = GET_CHILD_RECURSIVELY(frame, "previewable_check")
	complete_check:SetCheck(0)
	unregister_check:SetCheck(0)
	incomplete_check:SetCheck(0)
	previewable_check:SetCheck(0)

	dress_room_filter_options.show_complete = false
	dress_room_filter_options.show_unregister = false
	dress_room_filter_options.show_incomplete = false
	dress_room_filter_options.show_previewable = false

	local grade = frame:GetUserValue("SELECT_GRADE")
	GUILD_DRESS_ROOM_UPDATE_COSTUME_LIST(frame, grade)
end

---- filter option - all select
function GUILD_DRESS_ROOM_FILTER_OPTION_ALL_SELECT_BTN(parent, btn)
	local frame = parent:GetTopParentFrame()
	if frame == nil then
		return
	end

	for i, info in ipairs(dress_room_option_checklist) do
		local check = GET_CHILD_RECURSIVELY(frame, info.name)
		if check ~= nil then
			check:SetCheck(1)
		end
	end

	local grade = frame:GetUserValue("SELECT_GRADE")
	GUILD_DRESS_ROOM_UPDATE_COSTUME_LIST(frame, grade)
end

---- filter - all deselect
function GUILD_DRESS_ROOM_FILTER_OPTION_ALL_DESELECT_BTN(parent, btn)
	local frame = parent:GetTopParentFrame()
	if frame == nil then
		return
	end

	for i, info in ipairs(dress_room_option_checklist) do
		local check = GET_CHILD_RECURSIVELY(frame, info.name)
		if check ~= nil then
			check:SetCheck(0)
		end
	end

	local grade = frame:GetUserValue("SELECT_GRADE")
	GUILD_DRESS_ROOM_UPDATE_COSTUME_LIST(frame, grade)
end

-- search
---- search - enter & btn
function GUILD_DRESS_ROOM_SEARCH(parent, ctrl)
	local frame = parent:GetTopParentFrame()
	if frame == nil then
		return
	end

	local grade = frame:GetUserValue("SELECT_GRADE")
	GUILD_DRESS_ROOM_UPDATE_COSTUME_LIST(frame, grade)
end