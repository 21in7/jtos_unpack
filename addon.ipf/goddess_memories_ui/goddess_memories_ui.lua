-- goddess_memories_ui.lua
function GODDESS_MEMORIES_UI_ON_INIT(addon, frame)
	addon:RegisterMsg("GODDESS_MEMORIES_RESONANCE_SKILL_UPDATE", "ON_GODDESS_MEMORIES_UI_RESONANCE_SKILL_UPDATE")
	addon:RegisterMsg("GODDESS_MEMORIES_RESONANCE_SKILL_REINFORCE_FAIL", "ON_GODDESS_MEMORIES_UI_RESONANCE_SKILL_REINFORCE_FAIL")
	addon:RegisterMsg("GODDESS_MEMORIES_RESONANCE_SKILL_REINFORCE_REJECT", "ON_GODDESS_MEMORIES_UI_RESONANCE_SKILL_REINFORCE_REJECT")
	addon:RegisterMsg("GODDESS_MEMORIES_RESONANCE_SKILL_REGISTER", "ON_GODDESS_MEMORIES_UI_RESONANCE_SKILL_REGISTER")
	addon:RegisterMsg("GODDESS_MEMORIES_RESONANCE_SKILL_UNREGISTER", "ON_GODDESS_MEMORIES_UI_RESONANCE_SKILL_UNREGISTER")
end

---- open & close
function ON_GODDESS_MEMORIES_UI_OPEN(frame)
	ui.OpenFrame("goddess_memories_ui")
	INIT_LIST_GODDESS_MEMORIES_UI()
	INIT_HELP_GUIDE_GODDESS_MEMORIES_UI(frame)
end

function ON_GODDESS_MEMORIES_UI_CLOSE(frame)
	ui.CloseFrame("goddess_memories_ui")
end

function UI_TOGGLE_GODDESS_MEMORIES_UI()
	if app.IsBarrackMode() == true then
		return
    end

    if session.world.IsIntegrateServer() == true then
        ui.SysMsg(ScpArgMsg("CantUseThisInIntegrateServer"))
        return
    end
	
	ui.ToggleFrame("goddess_memories_ui")
end

-- ** addon ** --
---- resonance skill update
function ON_GODDESS_MEMORIES_UI_RESONANCE_SKILL_UPDATE(frame, msg, arg_str, arg_num)
	if frame == nil then 
		return 
	end

    local is_unlock = frame:GetUserIValue("PENDING_RESONANCE_REINFORCE_IS_UNLOCK")
    if FINISH_RESONANCE_REINFORCE_REQUEST_GODDESS_MEMORIES_UI(frame, arg_num) == false then
        return
    end

    REFRESH_RESONANCE_SLOT_PROGRESS_GODDESS_MEMORIES_UI(frame, arg_num)
    PLAY_RESONANCE_REINFORCE_SUCCESS_EFFECT_GODDESS_MEMORIES_UI(frame, is_unlock)
    SHOW_RESONANCE_REINFORCE_RESULT_TEXT_GODDESS_MEMORIES_UI(frame, true)
end

---- play ui success effect
function PLAY_RESONANCE_REINFORCE_SUCCESS_EFFECT_GODDESS_MEMORIES_UI(frame, is_unlock)
	local target = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_arrow_pic")
	if target == nil or target:IsVisible() == 0 then
		target = GET_CHILD_RECURSIVELY(frame, "skill_mgr_pic")
	end

	if target == nil then
		return
	end

	local effect_name = frame:GetUserConfig("RESONANCE_REINFORCE_SUCCESS_EFFECT")
    local effect_scale = tonumber(frame:GetUserConfig("RESONANCE_REINFORCE_SUCCESS_SCALE"))

	if is_unlock == 1 then
        effect_name = frame:GetUserConfig("RESONANCE_UNLOCK_SUCCESS_EFFECT")
        effect_scale = tonumber(frame:GetUserConfig("RESONANCE_UNLOCK_SUCCESS_SCALE"))
    end

    target:StopUIEffect("RESONANCE_REINFORCE_SUCCESS_EFFECT", true, 0)
    target:PlayUIEffect(effect_name, effect_scale, "RESONANCE_REINFORCE_SUCCESS_EFFECT", true)
end

---- resonance skill reinforce fail
function ON_GODDESS_MEMORIES_UI_RESONANCE_SKILL_REINFORCE_FAIL(frame, msg, arg_str, arg_num)
	if frame == nil then 
		return 
	end

    if FINISH_RESONANCE_REINFORCE_REQUEST_GODDESS_MEMORIES_UI(frame, arg_num) == false then
        return
    end

    PLAY_RESONANCE_REINFORCE_FAIL_EFFECT_GODDESS_MEMORIES_UI(frame)
    SHOW_RESONANCE_REINFORCE_RESULT_TEXT_GODDESS_MEMORIES_UI(frame, false)
end

---- play ui fail effect
function PLAY_RESONANCE_REINFORCE_FAIL_EFFECT_GODDESS_MEMORIES_UI(frame)
	local target = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_arrow_pic")
    if target == nil or target:IsVisible() == 0 then
        target = GET_CHILD_RECURSIVELY(frame, "skill_mgr_pic")
    end

    if target == nil then
        return
    end

    local effect_name = frame:GetUserConfig("RESONANCE_REINFORCE_FAIL_EFFECT")
    local effect_scale = tonumber(frame:GetUserConfig("RESONANCE_REINFORCE_FAIL_SCALE"))
	local effect_duration = tonumber(frame:GetUserConfig("RESONANCE_REINFORCE_FAIL_DURATION"))

	target:StopUIEffect("RESONANCE_REINFORCE_FAIL_EFFECT", true, 0)
    target:PlayUIEffect(effect_name, effect_scale, "RESONANCE_REINFORCE_FAIL_EFFECT", true)
    ReserveScript("STOP_RESONANCE_REINFORCE_FAIL_EFFECT_GODDESS_MEMORIES_UI()", effect_duration)
end

---- play ui fail effect - stop
function STOP_RESONANCE_REINFORCE_FAIL_EFFECT_GODDESS_MEMORIES_UI()
    local frame = ui.GetFrame("goddess_memories_ui")
    if frame == nil or frame:IsVisible() == 0 then
        return
    end

    local target = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_arrow_pic")
    if target == nil then
        target = GET_CHILD_RECURSIVELY(frame, "skill_mgr_pic")
    end

    if target ~= nil then
        target:StopUIEffect("RESONANCE_REINFORCE_FAIL_EFFECT", true, 0.5)
    end
end

---- show result text
function SHOW_RESONANCE_REINFORCE_RESULT_TEXT_GODDESS_MEMORIES_UI(frame, is_success)
	if frame == nil then
		return
	end

	local success_skin = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_success_skin")
    local success_text = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_success_text")
    local fail_skin = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_fail_skin")
    local fail_text = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_faile_text")
	if success_skin == nil or success_text == nil or fail_skin == nil or fail_text == nil then
		return
	end

	if is_success == true then
		success_skin:ShowWindow(1)
		success_text:ShowWindow(1)
		fail_skin:ShowWindow(0)
		fail_text:ShowWindow(0)
	else
		success_skin:ShowWindow(0)
		success_text:ShowWindow(0)
		fail_skin:ShowWindow(1)
		fail_text:ShowWindow(1)
	end
	
	local duration = tonumber(frame:GetUserConfig("RESONANCE_REINFORCE_RESULT_TEXT_DURATION")) or 1
	ReserveScript("HIDE_RESONANCE_REINFORCE_RESULT_TEXT_GODDESS_MEMORIES_UI()", duration)
end

---- hide show result text
function HIDE_RESONANCE_REINFORCE_RESULT_TEXT_GODDESS_MEMORIES_UI()
	local frame = ui.GetFrame("goddess_memories_ui")
    if frame == nil or frame:IsVisible() == 0 then
        return
    end

	local success_skin = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_success_skin")
	if success_skin ~= nil then
		success_skin:ShowWindow(0)
	end
    local success_text = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_success_text")
    if success_text ~= nil then
		success_text:ShowWindow(0)
	end
	local fail_skin = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_fail_skin")
    if fail_skin ~= nil then
		fail_skin:ShowWindow(0)
	end
	local fail_text = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_faile_text")
	if fail_text ~= nil then
		fail_text:ShowWindow(0)
	end
end

---- reject reinforce
function ON_GODDESS_MEMORIES_UI_RESONANCE_SKILL_REINFORCE_REJECT(frame, msg, arg_str, arg_num)
	if frame == nil then
        return
    end

	local guid = tonumber(arg_num)
    if guid == nil or guid <= 0 then
        return
    end

    if FINISH_RESONANCE_REINFORCE_REQUEST_GODDESS_MEMORIES_UI(frame, guid) == false then
        return
    end
	REFRESH_RESONANCE_SLOT_PROGRESS_GODDESS_MEMORIES_UI(frame, guid)
end

-- ** init ** --
---- init list
function INIT_LIST_GODDESS_MEMORIES_UI()
	local frame = ui.GetFrame("goddess_memories_ui")
	if frame == nil then
		return
	end

	frame:SetUserValue("SORT_TYPE", shared_resonance.SORT_NONE)
	frame:SetUserValue("SELECT_GUID", "None")
	frame:SetUserValue("SELECT_SKILL_NAME", "None")

	local list_main_bg = GET_CHILD_RECURSIVELY(frame, "list_main_bg")
	if list_main_bg == nil then
		return
	end

	REMOVE_LIST_GODDESS_MEMORIES_UI(frame)
	CREATE_LIST_GODDESS_MEMORIES_UI(frame, list_main_bg)
	FIRST_SELECT_INIT_LIST_GODDESS_MEMORIES_UI(frame, list_main_bg)
	FIRST_SELECT_INIT_DETAIL_TAB_GODDESS_MEMORIES_UI(frame)
end

---- init list - first select
function FIRST_SELECT_INIT_LIST_GODDESS_MEMORIES_UI(frame, gbox)
	local ctrlset = GET_CHILD_RECURSIVELY(gbox, "RESONANCE_SLOT_1")
	if ctrlset ~= nil then
		local slot = GET_CHILD_RECURSIVELY(ctrlset, "slot")
		if slot ~= nil then
			local guid = tonumber(slot:GetUserValue("GUID"))
			frame:SetUserValue("SELECT_GUID", guid)
			MAKE_DETAIL_GODDESS_MEMORIES_UI(frame, guid, true)
		end
	end
end

---- init detail tab
function FIRST_SELECT_INIT_DETAIL_TAB_GODDESS_MEMORIES_UI(frame)
	local tab = GET_CHILD_RECURSIVELY(frame, "detail_tab")
	if tab == nil then
		return
	end
	AUTO_CAST(tab)
	tab:SelectTab(shared_resonance.TAB_SKILL_INFO)
	CHANGE_DETAIL_TAB_GODDESS_MEMORIES_UI(frame, shared_resonance.TAB_SKILL_INFO)
end

---- init footer - guide
function SET_GODDESS_MEMORIES_UI_SMALL_TEXT_TOOLTIP(ctrl, text)
	if ctrl == nil then
		return
	end

	ctrl:SetTextTooltip("{@st59s}"..text.."{/}")
end

function SET_GODDESS_MEMORIES_UI_SLIDESHOW_BY_WIDTH(text_ctrl)
	if text_ctrl == nil then
		return
	end

	text_ctrl:Invalidate()
	if text_ctrl:GetTextWidth() > text_ctrl:GetWidth() then
		text_ctrl:SetCompareTextWidthBySlideShow(true)
		text_ctrl:EnableSlideShow(1)
	else
		text_ctrl:EnableSlideShow(0)
		text_ctrl:SetCompareTextWidthBySlideShow(false)
	end
end

function INIT_HELP_GUIDE_GODDESS_MEMORIES_UI(frame)
	if frame == nil then 
		return 
	end

	local title = GET_CHILD_RECURSIVELY(frame, "title")
	if title ~= nil then
		title:SetText("{@st43}"..ScpArgMsg("GoddessMemories_Title").."{/}")
	end

	local filter_name_btn = GET_CHILD_RECURSIVELY(frame, "filter_name_btn")
	if filter_name_btn ~= nil then
		filter_name_btn:SetText("{@st59}"..ScpArgMsg("GoddessMemories_SortByName").."{/}")
	end
	local filter_level_btn = GET_CHILD_RECURSIVELY(frame, "filter_level_btn")
	if filter_level_btn ~= nil then
		filter_level_btn:SetText("{@st59}"..ScpArgMsg("GoddessMemories_SortByLevel").."{/}")
	end
	local filter_resonance_btn = GET_CHILD_RECURSIVELY(frame, "filter_resonance_btn")
	if filter_resonance_btn ~= nil then
		filter_resonance_btn:SetText("{@st59}"..ScpArgMsg("GoddessMemories_SortByResonance").."{/}")
	end

	local detail_tab = GET_CHILD_RECURSIVELY(frame, "detail_tab")
	if detail_tab ~= nil then
		AUTO_CAST(detail_tab)
		detail_tab:ChangeCaption(shared_resonance.TAB_SKILL_INFO, "{@st66b}{s20}"..ScpArgMsg("GoddessMemories_SkillManagement").."{/}", false)
		detail_tab:ChangeCaption(shared_resonance.TAB_SKILL_REG, "{@st66b}{s20}"..ScpArgMsg("GoddessMemories_SkillRegister").."{/}", false)
	end

	local current_effect_title = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_desc_title_text")
	if current_effect_title ~= nil then
		current_effect_title:SetTextByKey("title", ScpArgMsg("GoddessMemories_CurrentEffect"))
	end
	local after_enhance_effect_title = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_next_desc_title_text")
	if after_enhance_effect_title ~= nil then
		after_enhance_effect_title:SetTextByKey("title", ScpArgMsg("GoddessMemories_AfterEnhanceEffect"))
	end
	local resonance_skill_slot_title = GET_CHILD_RECURSIVELY(frame, "detail_skill_reg_slot_bg_title_text")
	if resonance_skill_slot_title ~= nil then
		resonance_skill_slot_title:SetTextByKey("title", ScpArgMsg("GoddessMemories_ResonanceSkillSlot"))
	end

    local question = GET_CHILD_RECURSIVELY(frame, "question")
    if question ~= nil then
        question:SetTextTooltip(ScpArgMsg("GoddessMemories_QuestionGuide"))
    end

	SET_GODDESS_MEMORIES_UI_SMALL_TEXT_TOOLTIP(GET_CHILD_RECURSIVELY(frame, "close"), ScpArgMsg("GoddessMemories_CloseTooltip"))
	SET_GODDESS_MEMORIES_UI_SMALL_TEXT_TOOLTIP(GET_CHILD_RECURSIVELY(frame, "filter_name_btn"), ScpArgMsg("GoddessMemories_SortByName"))
	SET_GODDESS_MEMORIES_UI_SMALL_TEXT_TOOLTIP(GET_CHILD_RECURSIVELY(frame, "filter_level_btn"), ScpArgMsg("GoddessMemories_SortByLevel"))
	SET_GODDESS_MEMORIES_UI_SMALL_TEXT_TOOLTIP(GET_CHILD_RECURSIVELY(frame, "filter_resonance_btn"), ScpArgMsg("GoddessMemories_SortByResonance"))
	SET_GODDESS_MEMORIES_UI_SMALL_TEXT_TOOLTIP(GET_CHILD_RECURSIVELY(frame, "detail_tab_1"), ScpArgMsg("GoddessMemories_SkillManagement"))
	SET_GODDESS_MEMORIES_UI_SMALL_TEXT_TOOLTIP(GET_CHILD_RECURSIVELY(frame, "detail_tab_2"), ScpArgMsg("GoddessMemories_SkillRegister"))
	SET_GODDESS_MEMORIES_UI_SMALL_TEXT_TOOLTIP(GET_CHILD_RECURSIVELY(frame, "skill_mtrl_slot_btn"), ScpArgMsg("GoddessMemories_AddMaterialTooltip"))

    local footer_text = GET_CHILD_RECURSIVELY(frame, "footer_guide_text")
    if footer_text ~= nil then
		local guide_msg = ScpArgMsg("SancuartyResonance_SkillRegister_QuickslotGuide")
        footer_text:SetTextByKey("desc", tooltip_resonance.skill_factor_emphasis_start..guide_msg..tooltip_resonance.skill_factor_emphasis_end)
		SET_GODDESS_MEMORIES_UI_SMALL_TEXT_TOOLTIP(footer_text, guide_msg)
		SET_GODDESS_MEMORIES_UI_SLIDESHOW_BY_WIDTH(footer_text)
    end
end

-- ** list ** --
---- remove list
function REMOVE_LIST_GODDESS_MEMORIES_UI(frame)
	local gbox= GET_CHILD_RECURSIVELY(frame, "list_main_bg")
	if gbox == nil then
		return
	end
	DESTROY_CHILD_BYNAME(gbox, "RESONANCE_SLOT_")
end

---- create list
function CREATE_LIST_GODDESS_MEMORIES_UI(frame, gbox)
	if frame == nil or gbox == nil then 
		return
	end

	local list, cnt = GetClassList("Indun")
	if list == nil or cnt <= 0 then
		return
	end

	local sort_type = frame:GetUserValue("SORT_TYPE")
	if sort_type == nil or sort_type == "None" then
		sort_type = shared_resonance.SORT_NONE
	end

	local ret_list = shared_resonance.get_list(list, cnt, sort_type)
	if ret_list == nil or #ret_list <= 0 then
		return
	end

	local margin_x = tonumber(frame:GetUserConfig("DRAW_MARGIN_X"))
	local margin_y = tonumber(frame:GetUserConfig("DRAW_MARGIN_Y"))
	local space = tonumber(frame:GetUserConfig("DRAW_SPACE"))
	local limit_count = tonumber(frame:GetUserConfig("DRAW_LIMIT_COUNT"))
	local count = math.ceil(#ret_list / limit_count)
	local witdh = gbox:GetWidth()
    local slot_width = ui.GetControlSetAttribute("goddess_memories_resonance_slot", "width")
    local slot_height = ui.GetControlSetAttribute("goddess_memories_resonance_slot", "height")
	for i = 1, #ret_list do
        local value = ret_list[i]
        if value == nil then
            break
        end

		local boss_info = shared_resonance.get_boss_info(value)
		if boss_info == nil then
			break
		end

        local math_idx = i - 1
        local col = math_idx % limit_count
        local row = math.floor(math_idx / limit_count)
		local x = margin_x + col * (slot_width + space)
        local y = margin_y + row * (slot_height + space)
        local ctrlset = gbox:CreateOrGetControlSet("goddess_memories_resonance_slot", "RESONANCE_SLOT_"..i, x, y)
        if ctrlset ~= nil then
            local slot = GET_CHILD_RECURSIVELY(ctrlset, "slot", "ui::CSlot")
            if slot ~= nil then
                local icon = CreateIcon(slot)
                if icon ~= nil then
                    icon:SetImage(boss_info.icon)
                    icon:SetTooltipOverlap(0)
                end
				local guid = TryGetProp(value, "ClassID", 0)
				slot:SetUserValue("GUID", guid)
            end

			local attribute_pic = GET_CHILD_RECURSIVELY(ctrlset, "attribute")
			if attribute_pic ~= nil then
				if boss_info.is_next_boss == true then
					local attribute_slot = GET_CHILD_RECURSIVELY(ctrlset, "attribute_slot")
					if attribute_slot ~= nil then
						attribute_slot:ShowWindow(0)
					end
					attribute_pic:ShowWindow(0)
				else
					local attribute_icon = "attri_"..boss_info.attribute
					attribute_pic:SetImage(attribute_icon)
					attribute_pic:ShowWindow(1)
				end
			end

			local name_text = GET_CHILD_RECURSIVELY(ctrlset, "name")
			if name_text ~= nil then
				if boss_info.is_next_boss == true then
					local name_bg = GET_CHILD_RECURSIVELY(ctrlset, "name_bg")
					if name_bg ~= nil then
						name_bg:SetImage("bgm_simple_bg")
					end
					name_text:SetTextByKey("name", ScpArgMsg(boss_info.name))
				else
					name_text:SetTextByKey("name", boss_info.name)
				end
			end
			SET_RESONANCE_SLOT_PROGRESS_GODDESS_MEMORIES_UI(ctrlset, TryGetProp(value, "ClassID", 0))
        end
    end
end

function SET_RESONANCE_SLOT_PROGRESS_GODDESS_MEMORIES_UI(ctrlset, guid)
	if ctrlset == nil or guid == nil or guid == 0 then
		return
	end

	local gauge = GET_CHILD_RECURSIVELY(ctrlset, "progress_gauge", "ui::CGauge")
	if gauge == nil then
		return
	end

	local cur_point, max_point = shared_resonance.get_skill_progress(guid)
	cur_point = tonumber(cur_point) or 0
	max_point = tonumber(max_point) or 0
	cur_point = math.max(0, cur_point)
	max_point = math.max(0, max_point)

	if max_point <= 0 then
		gauge:SetPoint(0, 1)
		gauge:SetTextStat(0, "")
		gauge:ShowWindow(0)
		return
	end

	if cur_point > max_point then
		cur_point = max_point
	end

	gauge:ShowWindow(1)
	gauge:SetPoint(cur_point, max_point)
	gauge:SetTextStat(0, string.format("{s15}%d/%d{/}", cur_point, max_point))
end

function REFRESH_RESONANCE_SLOT_PROGRESS_GODDESS_MEMORIES_UI(frame, guid)
	if frame == nil or guid == nil or guid == 0 then
		return
	end

	local gbox = GET_CHILD_RECURSIVELY(frame, "list_main_bg")
	if gbox == nil then
		return
	end

	local child_count = gbox:GetChildCount()
	for i = 0, child_count - 1 do
		local ctrlset = gbox:GetChildByIndex(i)
		if ctrlset ~= nil and string.find(ctrlset:GetName(), "RESONANCE_SLOT_", 1, true) ~= nil then
			local slot = GET_CHILD_RECURSIVELY(ctrlset, "slot")
			if slot ~= nil and tonumber(slot:GetUserValue("GUID")) == tonumber(guid) then
				SET_RESONANCE_SLOT_PROGRESS_GODDESS_MEMORIES_UI(ctrlset, tonumber(guid))
				return
			end
		end
	end
end

---- list - ctrlset click
function LBTN_RESONANCE_SLOT_GODDESS_MEMORIES_UI(parent, slot)
	if parent == nil or slot == nil then
		return
	end

	local frame = ui.GetFrame("goddess_memories_ui")
	if frame == nil then
		return
	end

	local guid = tonumber(slot:GetUserValue("GUID"))
	SELECT_RESONANCE_BOSS_GODDESS_MEMORIES_UI(frame, guid)
end

---- list - sort btn
function LBTN_SORT_GODDESS_MEMORIES_UI(parent, btn, arg_str, arg_num)
	local frame = ui.GetFrame("goddess_memories_ui")
	if frame == nil then
		return
	end

	if arg_num == nil or arg_num == 0 or arg_num == -1 then
		arg_num = shared_resonance.SORT_NONE
	end
	frame:SetUserValue("SORT_TYPE", arg_num)
	
	local list_main_bg = GET_CHILD_RECURSIVELY(frame, "list_main_bg")
	if list_main_bg ~= nil then
		REMOVE_LIST_GODDESS_MEMORIES_UI(frame)
		CREATE_LIST_GODDESS_MEMORIES_UI(frame, list_main_bg)

		local selected_guid = frame:GetUserValue("SELECT_GUID")
		if selected_guid ~= nil and selected_guid ~= "None" then
			SELECT_RESONANCE_BOSS_GODDESS_MEMORIES_UI(frame, tonumber(selected_guid))
		else
			FIRST_SELECT_INIT_LIST_GODDESS_MEMORIES_UI(frame, list_main_bg)
		end
	end
	frame:Invalidate()
end

-- ** Tab ** --
---- tab - get select index
function GET_DETAIL_TAB_INDEX_GODDESS_MEMORIES_UI(frame)
	local tab = GET_CHILD_RECURSIVELY(frame, "detail_tab")
	if tab == nil then
		return shared_resonance.TAB_SKILL_INFO
	end
	AUTO_CAST(tab)
	return tab:GetSelectItemIndex()
end

---- tab - show detail contents
function SHOW_DETAIL_TAB_CONTENT_GODDESS_MEMORIES_UI(frame, index)
	local info_bg = GET_CHILD_RECURSIVELY(frame, "detail_skill_info_bg")
	if info_bg ~= nil then
		info_bg:ShowWindow(index == shared_resonance.TAB_SKILL_INFO and 1 or 0)
	end

	local reg_bg = GET_CHILD_RECURSIVELY(frame, "detail_skill_reg_bg")
	if reg_bg ~= nil then
		reg_bg:ShowWindow(index == shared_resonance.TAB_SKILL_REG and 1 or 0)
	end
end

---- tab - refresh skill info bg
function REFRESH_DETAIL_SKILL_INFO_TAB_GODDESS_MEMORIES_UI(frame)
	local guid = frame:GetUserValue("SELECT_GUID")
	if guid == nil or guid == "None" then
		return
	end
	MAKE_DETAIL_GODDESS_MEMORIES_UI(frame, tonumber(guid), true)
end

---- tab - refresh skill reg bg
function REFRESH_DETAIL_SKILL_REG_TAB_GODDESS_MEMORIES_UI(frame)
	-- common
	CLEAR_SKILL_SELECTED_REG_GODDESS_MEMORIES_UI(frame)
	-- select
	REMOVE_SKILL_SELECT_GODDESS_MEMORIES_UI(frame)
	MAKE_SKILL_SELECT_GODDESS_MEMORIES_UI(frame)
	-- register
	REMOVE_SKILL_REG_GODDESS_MEMORIES_UI(frame)
	MAKE_SKILL_REG_GODDESS_MEMORIES_UI(frame)
end

---- tab - change detail
function CHANGE_DETAIL_TAB_GODDESS_MEMORIES_UI(frame, index)
	SHOW_DETAIL_TAB_CONTENT_GODDESS_MEMORIES_UI(frame, index)
	
	if index == shared_resonance.TAB_SKILL_INFO then
		local guid = frame:GetUserValue("SELECT_GUID")
		REFRESH_DETAIL_SKILL_INFO_TAB_GODDESS_MEMORIES_UI(frame)
	elseif index == shared_resonance.TAB_SKILL_REG then
		REFRESH_DETAIL_SKILL_REG_TAB_GODDESS_MEMORIES_UI(frame)
	end
	frame:Invalidate()
end

---- tab - select resonance boss
function SELECT_RESONANCE_BOSS_GODDESS_MEMORIES_UI(frame, guid)
	if guid == nil then
		return
	end
	frame:SetUserValue("SELECT_GUID", guid)

	local index = GET_DETAIL_TAB_INDEX_GODDESS_MEMORIES_UI(frame)
	if index == shared_resonance.TAB_SKILL_INFO then
		REFRESH_DETAIL_SKILL_INFO_TAB_GODDESS_MEMORIES_UI(frame)
	elseif index == shared_resonance.TAB_SKILL_REG then
		REFRESH_DETAIL_SKILL_REG_TAB_GODDESS_MEMORIES_UI(frame)
	end
	SHOW_DETAIL_TAB_CONTENT_GODDESS_MEMORIES_UI(frame, index)
	frame:Invalidate()
end

---- tab - lbtn down
function LBTN_TAB_DETAIL_GODDESS_MEMORIES_UI(parent, ctrl)
	local frame = parent:GetTopParentFrame()
	if frame == nil then
		return
	end
	
	local index = GET_DETAIL_TAB_INDEX_GODDESS_MEMORIES_UI(frame)
	CHANGE_DETAIL_TAB_GODDESS_MEMORIES_UI(frame, index)
end

-- ** Detail ** -- 
---- reinforce unlock
function FINISH_RESONANCE_REINFORCE_REQUEST_GODDESS_MEMORIES_UI(frame, guid)
	if frame == nil or guid == nil or guid <= 0 then
        return false
    end

    local pending_guid = frame:GetUserIValue("PENDING_RESONANCE_REINFORCE_GUID")
    if pending_guid ~= guid then
        return false
    end

    SET_RESONANCE_REINFORCE_REQUESTING_GODDESS_MEMORIES_UI(frame, false)
    frame:SetUserValue("PENDING_RESONANCE_REINFORCE_GUID", "None")
    frame:SetUserValue("PENDING_RESONANCE_REINFORCE_IS_UNLOCK", 0)

    MAKE_DETAIL_GODDESS_MEMORIES_UI(frame, guid, true)
    frame:Invalidate()
    return true
end

---- Make Detail
function MAKE_DETAIL_GODDESS_MEMORIES_UI(frame, guid, is_init)
	if is_init == nil then
		is_init = false
	end

	local gbox = GET_CHILD_RECURSIVELY(frame, "detail_skill_info_title_bg")
	if gbox == nil then
		return
	end

	REMOVE_SKILL_NAME_TAB_GODDESS_MEMORIES_UI(gbox)
	MAKE_SKILL_NAME_TAB_GODDESS_MEMORIES_UI(frame, gbox, guid)
	
	if is_init == true then
		local selected_skill_name = frame:GetUserValue("SELECT_SKILL_NAME")
		local parent = nil
		if selected_skill_name ~= nil and selected_skill_name ~= "None" then
			for i = 0, gbox:GetChildCount() - 1 do
				local child = gbox:GetChildByIndex(i)
				if child ~= nil then
					local tab = GET_CHILD_RECURSIVELY(child, "tab")
					if tab ~= nil and tab:GetUserValue("SKILL_NAME") == selected_skill_name then
						parent = child
						break
					end
				end
			end
		end

		if parent == nil then
			parent = GET_CHILD_RECURSIVELY(gbox, "RESONANCE_SKILL_NAME_TAB_1")
		end
		if parent ~= nil then
			local tab = GET_CHILD_RECURSIVELY(parent, "tab")
			if tab ~= nil then
				LBTN_SKILL_NAME_TAB_GODDESS_MEMORIES_UI(parent, tab)
			end
		end
	end
end

---- RemoveDetail - skill name tab
function REMOVE_SKILL_NAME_TAB_GODDESS_MEMORIES_UI(gbox)
	DESTROY_CHILD_BYNAME(gbox, "RESONANCE_SKILL_NAME_TAB_")
end

---- Make Detail - skill name tab
function MAKE_SKILL_NAME_TAB_GODDESS_MEMORIES_UI(frame, gbox, guid)
	local list = shared_resonance.get_skill_info_list(guid)
	if list == nil then
		return
	end

	local start_x = 10
	local end_x = 10
	local gap = 4
	local count = #list
	local width = math.floor((gbox:GetWidth() - start_x - end_x - (gap * (count-1))) / count)
	for i = 1, count do
		local info = list[i]
		if info ~= nil then
			local x = start_x + ((width + gap) * (i - 1))
			local ctrlset = gbox:CreateOrGetControlSet("goddess_memoires_resonance_skill_tab", "RESONANCE_SKILL_NAME_TAB_"..i, x, 10)
			if ctrlset ~= nil then
				ctrlset:Resize(width, ctrlset:GetHeight())
				local skill_cls = GetClass("Skill", info.skill_name)
				if skill_cls ~= nil then
					local name = TryGetProp(skill_cls, "Name", "None")
					local tab = GET_CHILD_RECURSIVELY(ctrlset, "tab")
					if tab ~= nil then
						tab:Resize(width, tab:GetHeight())
						tab:SetTextByKey("name", name)
						tab:SetUserValue("ID", info.id)
						tab:SetUserValue("GUID", guid)
						tab:SetUserValue("SKILL_NAME", info.skill_name)
						tab:SetUserValue("IDX", i)
					end
				end
			end
		end
	end
end

---- Make Detail - skill name tab Lbtn
function LBTN_SKILL_NAME_TAB_GODDESS_MEMORIES_UI(parent, btn)
	if parent == nil or btn == nil then
		return
	end

	local frame = parent:GetTopParentFrame()
	if frame ~= nil then
		local id = tonumber(btn:GetUserValue("ID"))
		local guid = tonumber(btn:GetUserValue("GUID"))
		local skill_name = btn:GetUserValue("SKILL_NAME")
		if skill_name ~= nil and skill_name ~= "None" then
			frame:SetUserValue("SELECT_SKILL_NAME", skill_name)
		end
		MAKE_SKILL_INFO_GODDESS_MEMORIES_UI(frame, id)
		MAKE_SKILL_MGR_GODDESS_MEMORIES_UI(frame, id, guid)

		REMOVE_SKILL_SELECT_GODDESS_MEMORIES_UI(frame)
		MAKE_SKILL_SELECT_GODDESS_MEMORIES_UI(frame)

		REMOVE_SKILL_REG_GODDESS_MEMORIES_UI(frame)
		MAKE_SKILL_REG_GODDESS_MEMORIES_UI(frame)
	end
end

---- Make Detail - skill info
function MAKE_SKILL_INFO_GODDESS_MEMORIES_UI(frame, id)
	local info = shared_resonance.get_skill_info(id)
	if info == nil then
		return
	end

	local gbox = GET_CHILD_RECURSIVELY(frame, "detail_skill_info_bg")
	if gbox == nil then
		return
	end

	local skill_cls = GetClass("Skill", info.skill_name)
	if skill_cls ~= nil then
		local cur_level = shared_resonance.get_skill_level(info.skill_name)
		local is_unlock = cur_level > 0

		local slot = GET_CHILD_RECURSIVELY(gbox, "skill_info_slot")
		if slot ~= nil then
			slot:ClearIcon()
			slot:EnableDrag(0)
			slot:EnableDrop(0)
		end

		local pic = GET_CHILD_RECURSIVELY(gbox, "skill_info_pic")
		if pic ~= nil then
			pic:SetImage(info.icon_name)
			local color_tone = frame:GetUserConfig("ENABLE_COLOR")
			local tooltip = ""
			if is_unlock == false then 
				color_tone = frame:GetUserConfig("DISABLE_COLOR")
			else
				tooltip = tooltip_resonance.get_skill_raid_effect_tooltip(info.skill_name, cur_level)
			end
			pic:SetColorTone(color_tone)
			pic:SetTextTooltip(tooltip)
		end

		local pic_lock = GET_CHILD_RECURSIVELY(gbox, "skill_info_pic_lock")
		if pic_lock ~= nil then
			if is_unlock == false then
				local category, difficulty = shared_resonance.get_skill_unlock_route(info.skill_name)
				local tooltip = tooltip_resonance.get_locked_skill_tooltip(category, difficulty)
				pic_lock:SetTextTooltip(tooltip)
				pic_lock:ShowWindow(1)
			else
				pic_lock:SetTextTooltip("")
				pic_lock:ShowWindow(0)
			end
		end
	
		local skill_name_text = GET_CHILD_RECURSIVELY(gbox, "skill_name_text")
		if skill_name_text ~= nil then
			local skill_name = TryGetProp(skill_cls, "Name", "None")
			skill_name_text:SetTextByKey("name", skill_name)
		end

		local skill_desc_top_text = GET_CHILD_RECURSIVELY(frame, "skill_desc_top_text")
		local skill_cooldown_text = GET_CHILD_RECURSIVELY(frame, "skill_cooldown_text")
		local skill_desc_main_text = GET_CHILD_RECURSIVELY(gbox, "skill_desc_main_text")
		local skill_desc_detail_text = GET_CHILD_RECURSIVELY(gbox, "skill_desc_detail_text")
		if is_unlock == true then
			if skill_desc_top_text ~= nil then
				local desc = tooltip_resonance.get_skill_top_desc(info.skill_name)
				skill_desc_top_text:SetTextByKey("desc", desc)
			end
			
			if skill_cooldown_text ~= nil then
				local cooldown = shared_resonance.get_skill_cooldown(info.skill_name)
				local cooldown_text = tooltip_resonance.format_cooldown_time(cooldown)
				skill_cooldown_text:ShowWindow(1)
				skill_cooldown_text:SetTextByKey("text", ScpArgMsg("SancuartyResonance_SkillCooldown", "TIME", cooldown_text))
			end
	
			if skill_desc_main_text ~= nil then
				local desc = tooltip_resonance.get_skill_main_desc(info.skill_name)
				skill_desc_main_text:SetTextByKey("desc", desc)
			end
	
			if skill_desc_detail_text ~= nil then
				local desc = tooltip_resonance.get_skill_detail_desc(info.skill_name)
				skill_desc_detail_text:SetTextByKey("desc", desc)
			end
		else
			if skill_desc_top_text ~= nil then
				skill_desc_top_text:SetTextByKey("desc", "")
			end

			if skill_cooldown_text ~= nil then
				skill_cooldown_text:ShowWindow(0)
				skill_cooldown_text:SetTextByKey("text", "")
			end
	
			if skill_desc_main_text ~= nil then
				skill_desc_main_text:SetTextByKey("desc", ScpArgMsg("SkillUnlockNeed"))
			end
	
			if skill_desc_detail_text ~= nil then
				skill_desc_detail_text:SetTextByKey("desc", "")
			end
		end
		
		local has_video = info.video_name ~= nil and info.video_name ~= "None"
		local skill_video = GET_CHILD_RECURSIVELY(gbox, "skill_video")
		if skill_video ~= nil then
			skill_video:Stop()
			skill_video:UseGPU(true)
			skill_video:SetUserValue("VIDEO_STATE", "STOP")
			if is_unlock == true and has_video == true then
				skill_video:SetUserValue("VIDEO_NAME", info.video_name)
				skill_video:SetVideoName(info.video_name)
			else
				skill_video:SetUserValue("VIDEO_NAME", "None")
				skill_video:SetVideoName("None")
			end
		end

		local skill_video_overlay = GET_CHILD_RECURSIVELY(gbox, "skill_video_overlay")
		if skill_video_overlay ~= nil then
			if info.video_overlay_name ~= nil and info.video_overlay_name ~= "None" then
				skill_video_overlay:SetImage(info.video_overlay_name)
				skill_video_overlay:ShowWindow(1)
			else
				skill_video_overlay:ShowWindow(0)
			end
		end

		local skill_video_hit_area = GET_CHILD_RECURSIVELY(gbox, "skill_video_hit_area")
		local skill_video_play_btn = GET_CHILD_RECURSIVELY(gbox, "skill_video_play_btn")
		if skill_video_play_btn ~= nil then
			if has_video == false then
				skill_video_play_btn:ShowWindow(0)
				if skill_video_hit_area ~= nil then
					skill_video_hit_area:EnableHitTest(0)
				end
			elseif is_unlock == true then
				skill_video_play_btn:SetImage(frame:GetUserConfig("VIDEO_BTN_PLAY_IMAGE"))
				skill_video_play_btn:ShowWindow(1)
				if skill_video_hit_area ~= nil then
					skill_video_hit_area:EnableHitTest(1)
				end
			else
				skill_video_play_btn:SetImage(frame:GetUserConfig("VIDEO_BTN_LOCK_IMAGE"))
				skill_video_play_btn:ShowWindow(1)
				if skill_video_hit_area ~= nil then
					skill_video_hit_area:EnableHitTest(0)
				end
			end
		end
	end
end

---- toggle video
function TOGGLE_SKILL_VIDEO_GODDESS_MEMORIES_UI(parent, ctrl)
	local frame = ui.GetFrame("goddess_memories_ui")
    if frame == nil then
        return
    end

	local gbox = GET_CHILD_RECURSIVELY(frame, "detail_skill_info_bg")
    if gbox == nil then
        return
    end

    local skill_video = GET_CHILD_RECURSIVELY(gbox, "skill_video")
    local skill_video_overlay = GET_CHILD_RECURSIVELY(gbox, "skill_video_overlay")
	local skill_video_play_btn = GET_CHILD_RECURSIVELY(gbox, "skill_video_play_btn")
    if skill_video == nil or skill_video_overlay == nil or skill_video_play_btn == nil then
        return
    end

    local video_name = skill_video:GetUserValue("VIDEO_NAME")
    if video_name == nil or video_name == "None" then
        return
    end

	local state = skill_video:GetUserValue("VIDEO_STATE")
    if state == "PLAY" then
        skill_video:Pause()
		skill_video:SetUserValue("VIDEO_STATE", "PAUSE")
		skill_video_play_btn:SetImage(frame:GetUserConfig("VIDEO_BTN_PLAY_IMAGE"))
		skill_video_play_btn:ShowWindow(1)
        return
    end

    if skill_video_overlay ~= nil then
        skill_video_overlay:ShowWindow(0)
    end
	skill_video:Play()
	skill_video:SetUserValue("VIDEO_STATE", "PLAY")
	skill_video_play_btn:SetImage(frame:GetUserConfig("VIDEO_BTN_PAUSE_IMAGE"))
	skill_video_play_btn:ShowWindow(1)
end

---- mouse over
function SHOW_SKILL_VIDEO_CTRL_GODDESS_MEMORIES_UI(parent, ctrl)
	local frame = ui.GetFrame("goddess_memories_ui")
    if frame == nil then
        return
    end

    local gbox = GET_CHILD_RECURSIVELY(frame, "detail_skill_info_bg")
    if gbox == nil then
        return
    end

    local skill_video = GET_CHILD_RECURSIVELY(gbox, "skill_video")
    local skill_video_play_btn = GET_CHILD_RECURSIVELY(gbox, "skill_video_play_btn")
    if skill_video == nil or skill_video_play_btn == nil then
        return
    end

    local state = skill_video:GetUserValue("VIDEO_STATE")
    if state == "PLAY" then
        skill_video_play_btn:SetImage(frame:GetUserConfig("VIDEO_BTN_PAUSE_IMAGE"))
        skill_video_play_btn:ShowWindow(1)
    end
end

---- mouse out
function HIDE_SKILL_VIDEO_CTRL_GODDESS_MEMORIES_UI(parent, ctrl)
    local frame = ui.GetFrame("goddess_memories_ui")
    if frame == nil then
        return
    end

    local gbox = GET_CHILD_RECURSIVELY(frame, "detail_skill_info_bg")
    if gbox == nil then
        return
    end

    local skill_video = GET_CHILD_RECURSIVELY(gbox, "skill_video")
    local skill_video_play_btn = GET_CHILD_RECURSIVELY(gbox, "skill_video_play_btn")
    if skill_video == nil or skill_video_play_btn == nil then
        return
    end

    local state = skill_video:GetUserValue("VIDEO_STATE")
    if state == "PLAY" then
        skill_video_play_btn:ShowWindow(0)
    end
end

---- Make Detail - skill mgr
function MAKE_SKILL_MGR_GODDESS_MEMORIES_UI(frame, id, guid)
	local skill_info = shared_resonance.get_skill_info(id)
	if skill_info == nil then
		return
	end

	local reinforce_info = shared_resonance.get_skill_reinforce_info(skill_info.skill_name)
	if reinforce_info == nil then
		return
	end

	local is_unlock = true
	local cur_level, next_level = shared_resonance.get_skill_level(skill_info.skill_name)
	if cur_level == nil then
		cur_level = 0
	end

	if next_level == nil or next_level <= 0 then
		next_level = cur_level + 1
	end
	
	if cur_level == 0 and next_level == 1 then
		is_unlock = false
	end

	local is_max_level = false
	if cur_level >= skill_info.max_level then
		is_max_level = true
	end

	local mtrl_slot = GET_CHILD_RECURSIVELY(frame, "skill_mtrl_slot")
	local cur_level_text = GET_CHILD_RECURSIVELY(frame, "skill_cur_level_text")
	local next_level_text = GET_CHILD_RECURSIVELY(frame, "skill_next_level_text")
	local max_level_text = GET_CHILD_RECURSIVELY(frame, "skill_max_level_text")
	local reinroce_arrow_pic = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_arrow_pic")
	if cur_level_text ~= nil and next_level_text ~= nil then
		if is_max_level == true then
			cur_level_text:ShowWindow(0)
			next_level_text:ShowWindow(0)
			reinroce_arrow_pic:ShowWindow(0)
			max_level_text:ShowWindow(1)
		else
			cur_level_text:ShowWindow(1)
			next_level_text:ShowWindow(1)
			reinroce_arrow_pic:ShowWindow(1)
			max_level_text:ShowWindow(0)

			if is_unlock == false then
				cur_level = 0
				next_level = cur_level + 1
			else
				if next_level > skill_info.max_level then
					next_level = skill_info.max_level
				end
			end
			cur_level_text:SetTextByKey("level", cur_level)
			next_level_text:SetTextByKey("level", next_level)
		end
	end	

	if next_level > 0 then
		local cur_reinforce_data = reinforce_info[cur_level + 1]
		local next_reinforce_data = reinforce_info[next_level + 1]
		if cur_reinforce_data == nil or (is_max_level == false and next_reinforce_data == nil) then
			if mtrl_slot ~= nil then
				mtrl_slot:ClearIcon()
			end

			local reinforce_btn = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_btn")
			if reinforce_btn ~= nil then
				local disable_color = frame:GetUserConfig("DISABLE_COLOR")
				reinforce_btn:SetColorTone(disable_color)
				reinforce_btn:SetEnable(0)
			end
			return
		end

		local reinforce_pic = GET_CHILD_RECURSIVELY(frame, "skill_mgr_pic")
		local reinforce_next_pic = GET_CHILD_RECURSIVELY(frame, "skill_mgr_next_pic")
		if reinforce_pic ~= nil and reinforce_next_pic ~= nil then
			if is_max_level == true then
				local cur_image = tooltip_resonance.get_reinforce_slot_image(cur_level)
				reinforce_next_pic:SetImage(cur_image)

				local arrow_margin = reinroce_arrow_pic:GetMargin()
				local next_pic_x = arrow_margin.left + ((reinroce_arrow_pic:GetWidth() - reinforce_next_pic:GetWidth()) / 2)
				local next_pic_y = arrow_margin.top + ((reinroce_arrow_pic:GetHeight() - reinforce_next_pic:GetHeight()) / 2)
				reinforce_next_pic:SetMargin(next_pic_x, next_pic_y, 0, 0)
				reinforce_next_pic:ShowWindow(1)

				reinforce_pic:ShowWindow(0)
				reinroce_arrow_pic:ShowWindow(0)
				max_level_text:ShowWindow(1)
				next_level_text:ShowWindow(0)
			else
				local cur_image = tooltip_resonance.get_reinforce_slot_image(cur_level)
				reinforce_pic:SetImage(cur_image)
				reinforce_pic:ShowWindow(1)
				reinroce_arrow_pic:ShowWindow(1)
				
				local next_image = tooltip_resonance.get_reinforce_slot_image(next_level)
				reinforce_next_pic:SetImage(next_image)
				reinforce_next_pic:ShowWindow(1)
				reinforce_next_pic:SetMargin(reinforce_next_pic:GetOriginalX(), reinforce_next_pic:GetOriginalY(), 0, 0)

				max_level_text:ShowWindow(0)
				next_level_text:ShowWindow(1)
			end
		end

		local reinforce_rate_text = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_rate_text")
		local reinforce_max_rate_text = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_max_rate_text")
		local reinforce_rate_btn = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_rate_btn")
		if reinforce_rate_text ~= nil then
			if is_max_level == true then
				reinforce_rate_text:ShowWindow(0)
				reinforce_max_rate_text:ShowWindow(1)
				local max_level_msg = ScpArgMsg("GoddessMemories_MaxLevel")
				reinforce_max_rate_text:SetTextByKey("text", max_level_msg)
				SET_GODDESS_MEMORIES_UI_SMALL_TEXT_TOOLTIP(reinforce_rate_btn, max_level_msg)
			else
				reinforce_rate_text:ShowWindow(1)
				reinforce_max_rate_text:ShowWindow(0)

				local rate = next_reinforce_data.rate * 100
				local rate_msg = ScpArgMsg("GoddessMemories_EnhanceRate", "RATE", rate)
				reinforce_rate_text:SetTextByKey("text", rate_msg)
				SET_GODDESS_MEMORIES_UI_SMALL_TEXT_TOOLTIP(reinforce_rate_btn, rate_msg)
			end
		end

		SET_SKILL_MGR_REINFORCE_DESC_LAYOUT_GODDESS_MEMORIES_UI(frame, is_max_level)
		local skill_reinforce_desc_list_bg = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_desc_list_bg")
		if skill_reinforce_desc_list_bg ~= nil then
			MAKE_SKILL_MGR_REINFORCE_DESC_GODDESS_MEMORIES_UI(skill_reinforce_desc_list_bg, skill_info.skill_name, cur_level, cur_reinforce_data.desc_value, "CaptionRatio", cur_reinforce_data.cooldown_value, false)
		end

		local skill_reinforce_next_desc_list_bg = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_next_desc_list_bg")
		if is_max_level == false and skill_reinforce_next_desc_list_bg ~= nil and next_reinforce_data ~= nil then
			MAKE_SKILL_MGR_REINFORCE_DESC_GODDESS_MEMORIES_UI(skill_reinforce_next_desc_list_bg, skill_info.skill_name, next_level, next_reinforce_data.desc_value, "CaptionRatio", next_reinforce_data.cooldown_value, true)
		end

		if is_max_level == false then
			local mtrl_name = next_reinforce_data.item_name
			local mtrl_cls = GetClass("Item", mtrl_name)
			if mtrl_cls ~= nil then
				local mtrl_cls_id = TryGetProp(mtrl_cls, "ClassID", 0)
				local mtrl_name_text = GET_CHILD_RECURSIVELY(frame, "skill_mtrl_text")
				local mtrl_need_count_text = GET_CHILD_RECURSIVELY(frame, "skill_mtrl_slot_need_count_text")
				if mtrl_slot ~= nil and mtrl_name_text ~= nil and mtrl_need_count_text ~= nil then
					mtrl_slot:ClearIcon()
					mtrl_slot:EnableDrag(0)
					mtrl_slot:EnableDrop(1)
					mtrl_slot:EnablePop(0)
					mtrl_slot:SetOverSound("button_cursor_over_2")
					mtrl_slot:SetClickSound("button_click")
					mtrl_slot:SetEventScriptArgNumber(ui.DROP, mtrl_cls_id)
					mtrl_slot:SetEventScriptArgString(ui.DROP, tostring(next_reinforce_data.item_count))
					mtrl_slot:SetUserValue("ITEM_NAME", mtrl_name)
					mtrl_slot:SetUserValue("ITEM_CLS_ID", mtrl_cls_id)
					mtrl_slot:SetUserValue("NEED_COUNT", next_reinforce_data.item_count)
					mtrl_slot:SetUserValue("ITEM_GUID", "None")
					mtrl_slot:SetEventScript(ui.RBUTTONUP, "CANCEL_REINFORCE_RESONANCE_SKILL_MTRL_REG_GODDESS_MEMORIES_UI")
			
					local name = TryGetProp(mtrl_cls, "Name", "None")
					mtrl_name_text:SetTextByKey("name", name)
					mtrl_need_count_text:SetTextByKey("count", next_reinforce_data.item_count)

					local mtrl_slot_btn = GET_CHILD_RECURSIVELY(mtrl_slot, "skill_mtrl_slot_btn")
					if mtrl_slot_btn ~= nil then
						mtrl_slot_btn:ShowWindow(1)
					end
				end
				
				local mtrl_cur_count_text = GET_CHILD_RECURSIVELY(frame, "skill_mtrl_cur_count_text")
				if mtrl_cur_count_text ~= nil then
					local count = session.GetInvItemCountByType(mtrl_cls_id)
					mtrl_cur_count_text:SetTextByKey("text", ScpArgMsg("GoddessMemories_CurrentMaterialCount", "COUNT", count))
				end
			end
		else
			if mtrl_slot ~= nil then
				mtrl_slot:ClearIcon()
				mtrl_slot:EnableDrag(0)
				mtrl_slot:EnableDrop(0)
				mtrl_slot:EnablePop(0)

				local mtrl_slot_btn = GET_CHILD_RECURSIVELY(mtrl_slot, "skill_mtrl_slot_btn")
				if mtrl_slot_btn ~= nil then
					mtrl_slot_btn:ShowWindow(0)
				end
			end
		end
		
		local reinforce_btn = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_btn")
		if reinforce_btn ~= nil then
			local is_requesting = frame:GetUserIValue("IS_RESONANCE_REINFORCE_REQUESTING") == 1
			if is_max_level == true or is_requesting == true then
				local disable_color = frame:GetUserConfig("DISABLE_COLOR")
				reinforce_btn:SetColorTone(disable_color)
				reinforce_btn:SetEnable(0)
				reinforce_btn:EnableHitTest(0)
			else
				local style_start = frame:GetUserConfig("EXEC_BTN_STYLE_START")
				local style_end = frame:GetUserConfig("EXEC_BTN_STYLE_END")
				local cl_msg = ScpArgMsg("EnhanceSkill")
				if is_unlock == false then
					cl_msg = ScpArgMsg("SkillUnlock")
				end
				local caption = style_start..cl_msg..style_end
				reinforce_btn:SetText(caption)
				SET_GODDESS_MEMORIES_UI_SMALL_TEXT_TOOLTIP(reinforce_btn, cl_msg)
				reinforce_btn:SetColorTone("FFFFFFFF")
				reinforce_btn:SetEnable(1)
				reinforce_btn:EnableHitTest(1)
				reinforce_btn:SetUserValue("ARG_1", skill_info.id)
				reinforce_btn:SetUserValue("ARG_2", next_level)
				reinforce_btn:SetUserValue("ARG_3", guid)
			end
		end
	end
end

---- Make Detail - skill mgr reinforce desc layout
function SET_SKILL_MGR_REINFORCE_DESC_LAYOUT_GODDESS_MEMORIES_UI(frame, is_max_level)
	local mgr_bg = GET_CHILD_RECURSIVELY(frame, "detail_skill_mgr_bg")
	local bg = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_bg")
	local reinforce_info_bg = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_info_bg")
	local desc_bg = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_desc_bg")
	local next_desc_bg = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_next_desc_bg")
	if mgr_bg == nil or bg == nil or reinforce_info_bg == nil or desc_bg == nil or next_desc_bg == nil then
		return	
	end

	if is_max_level == true then
		local bg_x = math.floor((mgr_bg:GetWidth() - bg:GetWidth()) / 2)
		bg:SetMargin(bg_x, bg:GetOriginalY(), 0, 0)
		reinforce_info_bg:ShowWindow(0)

		local offset_x = 5
		local x = math.floor((bg:GetWidth() - desc_bg:GetWidth()) / 2) + offset_x
		desc_bg:SetMargin(x, desc_bg:GetOriginalY(), 0, 0)
		desc_bg:ShowWindow(1)
		next_desc_bg:ShowWindow(0)
		local next_desc_list_bg = GET_CHILD_RECURSIVELY(next_desc_bg, "skill_reinforce_next_desc_list_bg")
		if next_desc_list_bg ~= nil then
			DESTROY_CHILD_BYNAME(next_desc_list_bg, "RESONANCE_SKILL_DESC_")
		end
	else
		bg:SetMargin(bg:GetOriginalX(), bg:GetOriginalY(), 0, 0)
		reinforce_info_bg:ShowWindow(1)

		desc_bg:SetMargin(desc_bg:GetOriginalX(), desc_bg:GetOriginalY(), 0, 0)
		desc_bg:ShowWindow(1)
		next_desc_bg:SetMargin(next_desc_bg:GetOriginalX(), next_desc_bg:GetOriginalY(), 0, 0)
		next_desc_bg:ShowWindow(1)
	end
end

---- Make Detail - skill mgr reinforce desc
function MAKE_SKILL_MGR_REINFORCE_DESC_GODDESS_MEMORIES_UI(gbox, skill_name, level, desc_value, desc_prop_name, cooldown_value, is_emphasis)
	if gbox == nil then
		return
	end
	DESTROY_CHILD_BYNAME(gbox, "RESONANCE_SKILL_DESC_")
	
	local desc_list = tooltip_resonance.get_skill_reinforce_desc_list(skill_name, level, desc_value, desc_prop_name, is_emphasis, cooldown_value)
	if desc_list == nil or #desc_list <= 0 then
		return
	end

	local ctrlset_name = "goddess_memoires_resonance_skill_reinforce_desc"
	local height = ui.GetControlSetAttribute(ctrlset_name, "height")
	local start_x = 2
	local start_y = 0
	for i = 1, #desc_list do
		local x = start_x
		local y = start_y + ((i - 1) * height)
		local ctrlset = gbox:CreateOrGetControlSet(ctrlset_name, "RESONANCE_SKILL_DESC_"..i, x, y)
		if ctrlset ~= nil then
			local info = desc_list[i]
			local desc_text = GET_CHILD_RECURSIVELY(ctrlset, "desc")
			if desc_text ~= nil then
				local desc = info.text
				if info.is_raid_effect == true then
    				if info.emphasis == true then
						desc = tooltip_resonance.raid_effect_changed_emphasis_start..desc..tooltip_resonance.raid_effect_changed_emphasis_end
					else
						desc = tooltip_resonance.raid_effect_emphasis_start..desc..tooltip_resonance.raid_effect_emphasis_end
					end
				elseif info.emphasis == true then
					desc = tooltip_resonance.reinforce_emphasis_start..desc..tooltip_resonance.reinforce_emphasis_end
				end
				desc_text:SetTextByKey("desc", desc)
			end
		end
	end
end

function GET_REINFORCE_RESONANCE_SKILL_MTRL_SLOT_GODDESS_MEMORIES_UI(ctrl)
	if ctrl == nil then
		return nil
	end

	if ctrl:GetName() == "skill_mtrl_slot" then
		return tolua.cast(ctrl, "ui::CSlot")
	end

	local parent = ctrl:GetParent()
	if parent ~= nil and parent:GetName() == "skill_mtrl_slot" then
		return tolua.cast(parent, "ui::CSlot")
	end

	local frame = ctrl:GetTopParentFrame()
	if frame == nil then
		frame = ui.GetFrame("goddess_memories_ui")
	end

	if frame == nil then
		return nil
	end

	return GET_CHILD_RECURSIVELY(frame, "skill_mtrl_slot", "ui::CSlot")
end

function CLEAR_REINFORCE_RESONANCE_SKILL_MTRL_SLOT_GODDESS_MEMORIES_UI(mtrl_slot)
	if mtrl_slot == nil then
		return
	end

	mtrl_slot:ClearIcon()
	mtrl_slot:SetUserValue("ITEM_GUID", "None")

	local mtrl_slot_btn = GET_CHILD_RECURSIVELY(mtrl_slot, "skill_mtrl_slot_btn")
	if mtrl_slot_btn ~= nil then
		mtrl_slot_btn:ShowWindow(1)
	end
end

function REG_REINFORCE_RESONANCE_SKILL_MTRL_SLOT_GODDESS_MEMORIES_UI(mtrl_slot, inv_item)
	if mtrl_slot == nil or inv_item == nil then
		return false
	end

	local item_obj = GetIES(inv_item:GetObject())
	if item_obj == nil then
		return false
	end

	local need_item_name = mtrl_slot:GetUserValue("ITEM_NAME")
	if need_item_name == nil or need_item_name == "None" or item_obj.ClassName ~= need_item_name then
		ui.SysMsg(ScpArgMsg("NotEnoughTarget"))
		return false
	end

	if inv_item.isLockState == true then
		ui.SysMsg(ScpArgMsg("MaterialItemIsLock"))
		return false
	end

	local need_count = mtrl_slot:GetUserIValue("NEED_COUNT")
	local item_cls_id = mtrl_slot:GetUserIValue("ITEM_CLS_ID")
	local cur_count = session.GetInvItemCountByType(item_cls_id)
	if cur_count < need_count then
		ui.SysMsg(ScpArgMsg("NotEnoughRecipe"))
		return false
	end

	CLEAR_REINFORCE_RESONANCE_SKILL_MTRL_SLOT_GODDESS_MEMORIES_UI(mtrl_slot)
	SET_SLOT_ITEM(mtrl_slot, inv_item)
	mtrl_slot:SetUserValue("ITEM_GUID", inv_item:GetIESID())
	mtrl_slot:SetEventScript(ui.RBUTTONUP, "CANCEL_REINFORCE_RESONANCE_SKILL_MTRL_REG_GODDESS_MEMORIES_UI")

	local mtrl_slot_btn = GET_CHILD_RECURSIVELY(mtrl_slot, "skill_mtrl_slot_btn")
	if mtrl_slot_btn ~= nil then
		mtrl_slot_btn:ShowWindow(0)
	end

	return true
end

---- Skill Mgr - button Clicked MtrlSlot
function LBTN_REINFORCE_RESONANCE_SKILL_MTRL_REG_GODDESS_MEMORIES_UI(parent, btn)
	local mtrl_slot = GET_REINFORCE_RESONANCE_SKILL_MTRL_SLOT_GODDESS_MEMORIES_UI(parent)
	if mtrl_slot == nil then
		return
	end

	local item_name = mtrl_slot:GetUserValue("ITEM_NAME")
	local inv_item = session.GetInvItemByName(item_name)
	if inv_item == nil then
		ui.SysMsg(ScpArgMsg("NotEnoughRecipe"))
		return
	end

	REG_REINFORCE_RESONANCE_SKILL_MTRL_SLOT_GODDESS_MEMORIES_UI(mtrl_slot, inv_item)
end

---- Skill Mgr - OnDrop MtrlSlot
function DROP_REINFORCE_RESONANCE_SKILL_MTRL_REG_GODDESS_MEMORIES_UI(parent, ctrl, arg_str, arg_num)
	if ui.CheckHoldedUI() == true then
		return
	end

	local lift_icon = ui.GetLiftIcon()
	if lift_icon == nil then
		return
	end

	local from_frame = lift_icon:GetTopParentFrame()
	if from_frame == nil or from_frame:GetName() ~= "inventory" then
		return
	end

	local icon_info = lift_icon:GetInfo()
	if icon_info == nil then
		return
	end

	local inv_item = session.GetInvItemByGuid(icon_info:GetIESID())
	if inv_item == nil then
		return
	end

	local mtrl_slot = GET_REINFORCE_RESONANCE_SKILL_MTRL_SLOT_GODDESS_MEMORIES_UI(ctrl)
	REG_REINFORCE_RESONANCE_SKILL_MTRL_SLOT_GODDESS_MEMORIES_UI(mtrl_slot, inv_item)
end

---- Skill Mgr - Cancel MtrlSlot
function CANCEL_REINFORCE_RESONANCE_SKILL_MTRL_REG_GODDESS_MEMORIES_UI(parent, ctrl, arg_str, arg_num)
	local mtrl_slot = GET_REINFORCE_RESONANCE_SKILL_MTRL_SLOT_GODDESS_MEMORIES_UI(ctrl)
	if mtrl_slot == nil then
		mtrl_slot = GET_REINFORCE_RESONANCE_SKILL_MTRL_SLOT_GODDESS_MEMORIES_UI(parent)
	end
	CLEAR_REINFORCE_RESONANCE_SKILL_MTRL_SLOT_GODDESS_MEMORIES_UI(mtrl_slot)
end

---- Skill Mgr - reinforce requesting
function SET_RESONANCE_REINFORCE_REQUESTING_GODDESS_MEMORIES_UI(frame, is_requesting)
    if frame == nil then 
		return 
	end
    frame:SetUserValue("IS_RESONANCE_REINFORCE_REQUESTING", is_requesting == true and 1 or 0)

    if is_requesting == false then 
		return 
	end

    local reinforce_btn = GET_CHILD_RECURSIVELY(frame, "skill_reinforce_btn")
    if reinforce_btn ~= nil then
        reinforce_btn:SetEnable(0)
        reinforce_btn:EnableHitTest(0)
        reinforce_btn:SetColorTone(frame:GetUserConfig("DISABLE_COLOR"))
    end
end

---- Skill_Mgr - button Clicked
function LBTN_REINFORCE_RESONANCE_SKILL_BTN_GODDESS_MEMORIES_UI(parent, btn)
	if parent == nil or btn == nil then
		return
	end

	if shared_resonance.is_skillmgr_enable_check() == false then
		return
	end

	local id = btn:GetUserIValue("ARG_1")
	local next_level = btn:GetUserIValue("ARG_2")
	local guid = btn:GetUserIValue("ARG_3")
	if id <= 0 or next_level <= 0 or guid <= 0 then
		return
	end

	local frame = btn:GetTopParentFrame()
	if frame == nil then
		return
	end

	if frame:GetUserIValue("IS_RESONANCE_REINFORCE_REQUESTING") == 1 then
		return
	end

	local mtrl_slot = GET_CHILD_RECURSIVELY(frame, "skill_mtrl_slot")
	if mtrl_slot == nil or mtrl_slot:GetUserValue("ITEM_GUID") == "None" then
		ui.SysMsg(ScpArgMsg("REQUEST_TAKE_ITEM"))
		return
	end

	local is_unlock = next_level == 1
	frame:SetUserValue("PENDING_RESONANCE_REINFORCE_GUID", guid)
	frame:SetUserValue("PENDING_RESONANCE_REINFORCE_IS_UNLOCK", is_unlock == true and 1 or 0)
	SET_RESONANCE_REINFORCE_REQUESTING_GODDESS_MEMORIES_UI(frame, true)

	control.CustomCommand("REQ_RESONANCE_SKILL_REINFORCE", id, next_level, guid)
end

-- ** select & reg ** --
---- skill select - remove
function REMOVE_SKILL_SELECT_GODDESS_MEMORIES_UI(frame)
	local gbox = GET_CHILD_RECURSIVELY(frame, "detail_skill_select_bg")
	if gbox == nil then
		return
	end
	DESTROY_CHILD_BYNAME(gbox, "RESONANCE_SKILL_SELECT_SLOT_")
end

---- skill select - make select list
function MAKE_SKILL_SELECT_GODDESS_MEMORIES_UI(frame)
	local gbox = GET_CHILD_RECURSIVELY(frame, "detail_skill_select_bg")
	if gbox == nil then
		return
	end

	local select_info = shared_resonance.get_skill_select_info()
	if select_info ~= nil and #select_info > 0 then
		local col_count = 3
		local start_x, start_y = 35, 0
		local space_x, space_y = 15, 0
		local slot_width = ui.GetControlSetAttribute("goddess_memoires_resonance_skill_select_slot", "width")
		local slot_height = ui.GetControlSetAttribute("goddess_memoires_resonance_skill_select_slot", "height")
		for i = 1, #select_info do
			local col = (i - 1) % col_count
			local row = math.floor((i - 1) / col_count)
			local x = start_x + (col * (slot_width + space_x))
			local y = start_y + (row * (slot_height + space_y))
			local ctrlset = gbox:CreateOrGetControlSet("goddess_memoires_resonance_skill_select_slot", "RESONANCE_SKILL_SELECT_SLOT_"..i, x, y)
			if ctrlset ~= nil then
				MAKE_SKILL_SELECT_CTRLSET_GODDESS_MEMORIES_UI(ctrlset, select_info[i], i)
			end
		end
	end
	gbox:Invalidate()
	frame:Invalidate()
end

---- skill select - make select ctrlset
function MAKE_SKILL_SELECT_CTRLSET_GODDESS_MEMORIES_UI(ctrlset, info, index)
	if ctrlset == nil or info == nil then
		return
	end
	ctrlset:SetUserValue("IDX", index)
	ctrlset:SetUserValue("SKILL_NAME", info.cls_name)
	ctrlset:SetUserValue("ENABLE", info.enable)
	ctrlset:SetUserValue("SELECTED", 0)
	SET_SKILL_SELECTED_MARK_GODDESS_MEMORIES_UI(ctrlset, false)

	local slot = GET_CHILD_RECURSIVELY(ctrlset, "slot")
	if slot ~= nil then
		AUTO_CAST(slot)
		slot:SetEnable(info.enable)
		slot:EnableDrag(info.enable)
		slot:EnableDrop(0)
		SET_SLOT_IMG(slot, info.icon)
	end
	
	local text = GET_CHILD_RECURSIVELY(ctrlset, "name")
	if text ~= nil then
		text:SetTextByKey("name", info.name)
	end
end

---- skill select : mark
function SET_SKILL_SELECTED_MARK_GODDESS_MEMORIES_UI(ctrlset, is_selected)
	local select_bg = GET_CHILD_RECURSIVELY(ctrlset, "select_bg")
	if select_bg ~= nil then
		select_bg:ShowWindow(is_selected == true and 1 or 0)
	end
end

---- skill select : clear
function CLEAR_SKILL_SELECTED_REG_GODDESS_MEMORIES_UI(frame)
	local ctrl_name = frame:GetUserValue("SELECT_REG_SKILL_CTRL_NAME")
	if ctrl_name ~= nil and ctrl_name ~= "None" then
		local ctrlset = GET_CHILD_RECURSIVELY(frame, ctrl_name)
		if ctrlset ~= nil then
			ctrlset:SetUserValue("SELECTED", 0)
			SET_SKILL_SELECTED_MARK_GODDESS_MEMORIES_UI(ctrlset, false)
		end
	end
	frame:SetUserValue("SELECT_REG_SKILL_NAME", "None")
	frame:SetUserValue("SELECT_REG_SKILL_CTRL_NAME", "None")
end

---- skill select - lbtn
function LBTN_SKILL_SELECTED_GODDESS_MEMORIES_UI(parent, slot)
	if parent == nil then
		return
	end

	local frame = parent:GetTopParentFrame()
	local ctrlset = parent:GetParent()
	if frame == nil or ctrlset == nil then
		return
	end

	if ctrlset:GetUserIValue("ENABLE") ~= 1 then
		return
	end

	local skill_name = ctrlset:GetUserValue("SKILL_NAME")
	if skill_name == nil or skill_name == "None" then
		return
	end
	CLEAR_SKILL_SELECTED_REG_GODDESS_MEMORIES_UI(frame)

	ctrlset:SetUserValue("SELECTED", 1)
	frame:SetUserValue("SELECT_REG_SKILL_NAME", skill_name)
	frame:SetUserValue("SELECT_REG_SKILL_CTRL_NAME", ctrlset:GetName())
	SET_SKILL_SELECTED_MARK_GODDESS_MEMORIES_UI(ctrlset, true)
end

---- skill select - lift
function LIFT_SKILL_SELECT_GODDESS_MEMORIES_UI(parent, ctrl)
	if parent == nil then
		return
	end

	local frame = parent:GetTopParentFrame()
	local ctrlset = parent:GetParent()
	if frame == nil or ctrlset == nil then
		return
	end

	if ctrlset:GetUserIValue("ENABLE") ~= 1 then
		return
	end

	local skill_name = ctrlset:GetUserValue("SKILL_NAME")
	if skill_name == nil or skill_name == "None" then
		return
	end
	CLEAR_SKILL_SELECTED_REG_GODDESS_MEMORIES_UI(frame)

	ctrlset:SetUserValue("SELECTED", 1)
	frame:SetUserValue("SELECT_REG_SKILL_NAME", skill_name)
	frame:SetUserValue("SELECT_REG_SKILL_CTRL_NAME", ctrlset:GetName())
	SET_SKILL_SELECTED_MARK_GODDESS_MEMORIES_UI(ctrlset, true)
end

---- skill select - drop to reg slot
function DROP_SELECTED_SKILL_TO_REG_SLOT_GODDESS_MEMORIES_UI(parent, ctrl, arg_str, arg_num)
	local frame = ui.GetFrame("goddess_memories_ui")
	if frame == nil or parent == nil then
		return
	end

	local slot_index = parent:GetUserIValue("IDX")
	EXEC_SKILL_SELECTED_TO_REG_GODDESS_MEMORIES_UI(frame, slot_index)
end

function CHECK_RESONANCE_SKILL_SLOT_CHANGE_COOLDOWN_GODDESS_MEMORIES_UI()
	if shared_resonance.is_skill_slot_change_blocked_by_cooldown() == true then
		ui.SysMsg(ScpArgMsg("SancuartyResonance_SkillRegister_CooldownLock"))
		return false
	end
	return true
end

---- skill select - exec reg
function EXEC_SKILL_SELECTED_TO_REG_GODDESS_MEMORIES_UI(frame, slot_index)
	if frame == nil then
		return
	end

	if shared_resonance.is_skillmgr_enable_check() == false then
		return
	end

	if CHECK_RESONANCE_SKILL_SLOT_CHANGE_COOLDOWN_GODDESS_MEMORIES_UI() == false then
		return
	end

	local skill_name = frame:GetUserValue("SELECT_REG_SKILL_NAME")
	if skill_name == nil or skill_name == "None" then
		ui.SysMsg(ScpArgMsg("SancuartyResonance_SkillSelectNeed"))
		return
	end

	if slot_index == nil or slot_index <= 0 then
		return
	end

	local gbox = GET_CHILD_RECURSIVELY(frame, "detail_skill_reg_slot_bg")
	if gbox == nil then
		return
	end

	local ctrlset = GET_CHILD_RECURSIVELY(gbox, "RESONANCE_SKILL_REG_SLOT_"..slot_index)
	if ctrlset == nil then
		return
	end

	local reg_skill_name = ctrlset:GetUserValue("SKILL_NAME")
	if reg_skill_name ~= nil and reg_skill_name ~= "None" then
		ui.SysMsg(ScpArgMsg("SancuartyResonance_SkillRegister_Duplicate_Skill"))
		return
	end

	EXEC_RESONANCE_REG_SLOT_GODDESS_MEMORIES_UI(slot_index, skill_name)
end

---- skill reg - remove
function REMOVE_SKILL_REG_GODDESS_MEMORIES_UI(frame)
	local gbox = GET_CHILD_RECURSIVELY(frame, "detail_skill_reg_slot_bg")
	if gbox == nil then
		return
	end
	DESTROY_CHILD_BYNAME(gbox, "RESONANCE_SKILL_REG_SLOT_")
end

---- skill reg - make reg
function MAKE_SKILL_REG_GODDESS_MEMORIES_UI(frame)
	local gbox = GET_CHILD_RECURSIVELY(frame, "detail_skill_reg_slot_bg")
	if gbox == nil then
		return
	end
	
	local slot_count = 0
	local slot_cls = GetClass("SharedConst", "RESONANCE_SKILL_SLOT_CNT")
	if slot_cls ~= nil then
		slot_count = slot_cls.Value
	end

	local reg_info = shared_resonance.get_skill_register_info()
	local gbox_width = gbox:GetWidth()
	local slot_width = ui.GetControlSetAttribute("goddess_memoires_resonance_skill_reg_slot", "width")
	local slot_gap = tonumber(frame:GetUserConfig("REG_SLOT_GAP"))
	local total_width = (slot_count * slot_width) + ((slot_count - 1) * slot_gap)
	local start_x = (gbox_width - total_width) / 2
	local start_y = tonumber(frame:GetUserConfig("REG_SLOT_START_Y"))
	for i = 1, slot_count do
		local x = start_x + ((i - 1) * (slot_width + slot_gap))
		local y = start_y
		local ctrlset = gbox:CreateOrGetControlSet("goddess_memoires_resonance_skill_reg_slot", "RESONANCE_SKILL_REG_SLOT_"..i, x, y)
		if ctrlset ~= nil then
			MAKE_SKILL_CTRLSET_REG_GODDESS_MEMORIES_UI(ctrlset, reg_info, i)
		end
	end
end

---- skill reg - make reg ctrlset
function MAKE_SKILL_CTRLSET_REG_GODDESS_MEMORIES_UI(ctrlset, reg_info, slot_index)
	if ctrlset == nil then
		return
	end

	local slot = GET_CHILD_RECURSIVELY(ctrlset, "drag_slot")
	if slot == nil then
		return
	end
	AUTO_CAST(slot)
	slot:EnableDrag(0)
	slot:EnableDrop(1)
	slot:EnablePop(0)
	slot:SetEventScript(ui.DROP, "DROP_SELECTED_SKILL_TO_REG_SLOT_GODDESS_MEMORIES_UI")
	MAKE_SKILL_NAME_SLOT_REG_GODDESS_MEMORIES_UI(ctrlset, slot_index, "None")

	if reg_info ~= nil then
		local info = reg_info[slot_index]
		if info ~= nil then
			local prop_name = info.prop_name
			local skill_name = info.reg_skill_name
			local skill_lv = info.reg_skill_lv
			if prop_name ~= "None" and skill_name ~= "None" and skill_lv > 0 then
				MAKE_SKILL_SLOT_REG_GODDESS_MEMORIES_UI(slot, skill_name)
				MAKE_SKILL_NAME_SLOT_REG_GODDESS_MEMORIES_UI(ctrlset, slot_index, skill_name)
				ctrlset:SetUserValue("SKILL_NAME", skill_name)
				ctrlset:SetUserValue("SKILL_LV", skill_lv)
				ctrlset:SetUserValue("PROP_NAME", prop_name)
			end
		end
		ctrlset:SetUserValue("IDX", slot_index)
	end
end

---- skill reg - make reg slot
function MAKE_SKILL_SLOT_REG_GODDESS_MEMORIES_UI(slot, skill_name)
	if slot ~= nil then
		local skill_cls = GetClass("Skill", skill_name)
		if skill_cls ~= nil then
			local skill_id = TryGetProp(skill_cls, "ClassID", 0)
			local icon = CreateIcon(slot)
			if icon ~= nil then
				local icon_name = shared_resonance.get_skill_slot_icon(skill_name)
				icon:SetTooltipType("skill")
				icon:SetTooltipStrArg(skill_name)
				icon:SetTooltipNumArg(skill_id)
				icon:SetTooltipIESID("0")
				icon:SetTooltipOverlap(1)
				icon:Set(icon_name, "Skill", skill_id, 1)
				icon:SetDropFinallyScp("DROP_RESONANCE_REG_SLOT_GODDESS_MEMORIES_UI")
			end
			slot:EnableDrag(1)
			slot:EnableDrop(1)
			slot:EnablePop(1)
			slot:SetEventScript(ui.DROP, "DROP_SELECTED_SKILL_TO_REG_SLOT_GODDESS_MEMORIES_UI")
		end
	end
end

---- skill reg - make rag slot name
function MAKE_SKILL_NAME_SLOT_REG_GODDESS_MEMORIES_UI(ctrlset, slot_index, skill_name)
	if ctrlset == nil then
		return
	end

	local text = GET_CHILD_RECURSIVELY(ctrlset, "name")
	if text == nil then
		return
	end

	local name = ScpArgMsg("SancuartyResonance_SkillRegister_SlotName")..slot_index
	if skill_name ~= nil and skill_name ~= "None" then
		local skill_cls = GetClass("Skill", skill_name)
		if skill_cls ~= nil then
			name = tooltip_resonance.reinforce_emphasis_start..TryGetProp(skill_cls, "Name", name)..tooltip_resonance.reinforce_emphasis_end
		end
	end
	text:SetTextByKey("name", name)
end

---- reg slot - ctrlset click : RBtn
function RBTN_RESONANCE_REG_SLOT_GODDESS_MEMORIES_UI(ctrlset)
	if shared_resonance.is_skillmgr_enable_check() == false then
		return
	end

	if ctrlset == nil then
		return
	end

	local skill_name = ctrlset:GetUserValue("SKILL_NAME")
	if skill_name == nil or skill_name == "None" then
		return
	end

	if CHECK_RESONANCE_SKILL_SLOT_CHANGE_COOLDOWN_GODDESS_MEMORIES_UI() == false then
		return
	end

	local idx = ctrlset:GetUserIValue("IDX")
	local prop_name = ctrlset:GetUserValue("PROP_NAME")
	resonance.RequestResonanceSkillUnRegister(idx, prop_name)
end

---- reg slot - unregister result
function ON_GODDESS_MEMORIES_UI_RESONANCE_SKILL_UNREGISTER(frame, msg, arg_str, arg_num)
	if frame == nil then
		return
	end

	local gbox = GET_CHILD_RECURSIVELY(frame, "detail_skill_reg_slot_bg")
	if gbox == nil then
		return
	end

	local idx = arg_num
	local ctrlset = nil
	for i = 0, gbox:GetChildCount() - 1 do
		local child = gbox:GetChildByIndex(i)
		if child ~= nil and child:GetUserIValue("IDX") == idx then
			ctrlset = child
			break
		end
	end

	if ctrlset ~= nil then
		local slot = GET_CHILD_RECURSIVELY(ctrlset, "drag_slot")
		if slot ~= nil then
			slot:ClearIcon()
			slot:EnableDrag(0)
			slot:EnableDrop(1)
			slot:EnablePop(0)
			slot:SetEventScript(ui.DROP, "DROP_SELECTED_SKILL_TO_REG_SLOT_GODDESS_MEMORIES_UI")
		end
		
		local skill_name = ctrlset:GetUserValue("SKILL_NAME")
		if skill_name ~= nil and skill_name ~= "None" then
			local cls = GetClass("Skill", skill_name)
			if cls ~= nil then
				local id = TryGetProp(cls, "ClassID", 0)
				if id > 0 then
					DELETE_SKILLICON_QUICKSLOTBAR(nil, "None", tostring(id), 0)
				end
			end
		end
		
		local reg_info = shared_resonance.get_skill_register_info()
		if reg_info ~= nil and reg_info[idx] ~= nil then
			ctrlset:SetUserValue("PROP_NAME", reg_info[idx].prop_name)
		else
			ctrlset:SetUserValue("PROP_NAME", "None")
		end
		ctrlset:SetUserValue("SKILL_NAME", "None")
		ctrlset:SetUserValue("SKILL_LV", 0)
		MAKE_SKILL_NAME_SLOT_REG_GODDESS_MEMORIES_UI(ctrlset, idx, "None")
		CLEAR_SKILL_SELECTED_REG_GODDESS_MEMORIES_UI(frame)
	end
end

---- reg slot - lift
function LIFT_RESONANCE_REG_SLOT_GODDESS_MEMORIES_UI(parent, ctrl)
	local frame = ctrl:GetTopParentFrame()
    if frame == nil then
        return
    end

    local layer = tonumber(frame:GetUserConfig("LAYER_LEVEL_DRAG_ON"))
    if layer ~= nil then
        frame:SetLayerLevel(layer)
    end
end

---- reg slot - drop
function DROP_RESONANCE_REG_SLOT_GODDESS_MEMORIES_UI(frame, object, arg_str, arg_num)
	if object == nil then
        return
    end

    AUTO_CAST(object)

    local from_frame = object:GetTopParentFrame()
    if from_frame == nil then
        from_frame = ui.GetFrame("goddess_memories_ui")
    end

    if from_frame == nil then
        return
    end

    local layer = tonumber(from_frame:GetUserConfig("LAYER_LEVEL_DRAG_OFF"))
    if layer ~= nil then
        from_frame:SetLayerLevel(layer)
    end
end

---- reg slot - exec
function EXEC_RESONANCE_REG_SLOT_GODDESS_MEMORIES_UI(idx, skill_name)
	local frame = ui.GetFrame("goddess_memories_ui")
	if frame == nil then
		return
	end

	if idx == nil or idx == 0 or skill_name == nil or skill_name == "None" then
		return
	end

	if CHECK_RESONANCE_SKILL_SLOT_CHANGE_COOLDOWN_GODDESS_MEMORIES_UI() == false then
		return
	end

	local reg_info = shared_resonance.get_skill_register_info()
	if reg_info ~= nil then
		local info = reg_info[idx]
		if info ~= nil then
			local skill_lv = shared_resonance.get_skill_level(skill_name)
			resonance.RequestResonanceSkillRegister(idx, info.prop_name, skill_name, skill_lv)
		end
	end
end

---- reg slot - register result
function ON_GODDESS_MEMORIES_UI_RESONANCE_SKILL_REGISTER(frame, msg, arg_str, arg_num)
	if frame == nil then
		return
	end

	local gbox = GET_CHILD_RECURSIVELY(frame, "detail_skill_reg_slot_bg")
	if gbox == nil then
		return
	end

	local idx = arg_num
	local prop_name = "None"
	local skill_name = "None"
	local skill_lv = 0
	local arg_str_list = StringSplit(arg_str, '/')
	if #arg_str_list > 0 then
		prop_name = arg_str_list[1]
		skill_name = arg_str_list[2]
		skill_lv = tonumber(arg_str_list[3])
	end

	local ctrlset = nil
	for i = 0, gbox:GetChildCount() - 1 do
		local child = gbox:GetChildByIndex(i)
		if child ~= nil and child:GetUserIValue("IDX") == idx then
			ctrlset = child
			break
		end
	end

	if ctrlset ~= nil then
		local slot = GET_CHILD_RECURSIVELY(ctrlset, "drag_slot")
		if slot ~= nil then
			slot:ClearIcon()
			MAKE_SKILL_SLOT_REG_GODDESS_MEMORIES_UI(slot, skill_name)
		end
		ctrlset:SetUserValue("SKILL_NAME", skill_name)
		ctrlset:SetUserValue("SKILL_LV", skill_lv)
		ctrlset:SetUserValue("PROP_NAME", prop_name)
		MAKE_SKILL_NAME_SLOT_REG_GODDESS_MEMORIES_UI(ctrlset, idx, skill_name)

		local skill_cls = GetClass("Skill", skill_name)
		if skill_cls ~= nil then
			local skill_id = TryGetProp(skill_cls, "ClassID", 0)
			if skill_id > 0 then
				local quickslot_frame = ui.GetFrame("quickslotnexpbar")
				QUICKSLOT_REGISTER_Skill(quickslot_frame, "REGISTER_QUICK_SKILL", skill_id, -1)
			end
		end
	end
	CLEAR_SKILL_SELECTED_REG_GODDESS_MEMORIES_UI(frame)
end
