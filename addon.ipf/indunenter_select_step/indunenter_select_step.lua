local INDUNENTER_SELECT_STEP_MIN = 1
local INDUNENTER_SELECT_STEP_PC_INFO_COUNT = 5

-- indunenter_select_step.lua
function INDUNENTER_SELECT_STEP_ON_INIT(addon, frame)
    addon:RegisterMsg("MOVE_ZONE", "INDUNENTER_SELECT_STEP_CLOSE")
    addon:RegisterMsg("CLOSE_UI", "INDUNENTER_SELECT_STEP_CLOSE")
    addon:RegisterMsg("ESCAPE_PRESSED", "INDUNENTER_SELECT_STEP_ON_ESCAPE_PRESSED")
    addon:RegisterMsg("PARTY_UPDATE", "INDUNENTER_SELECT_STEP_REFRESH_PARTY")
    addon:RegisterMsg("PARTY_INST_UPDATE", "INDUNENTER_SELECT_STEP_REFRESH_PARTY")
    addon:RegisterMsg("FAIL_START_PARTY_MATCHING", "INDUNENTER_SELECT_STEP_FAIL_START_PARTY_MATCHING")
    addon:RegisterMsg("FAIL_REGISTER_PARTY_MATCHING", "INDUNENTER_SELECT_STEP_FAIL_REGISTER_PARTY_MATCHING")
end

-- function
local function IsExistRewardItemInList(list, class_name)
    if list == nil or class_name == nil then
        return false
    end

    for i = 1, #list do
        if TryGetProp(list[i], "ClassName", "None") == class_name then
            return true
        end
    end
    return false
end

local function CheckAndFill_RewardBox(list, item_name)
    if list == nil or item_name == nil or item_name == "" or item_name == "None" then
        return
    end
    
    local item = GetClass("Item", item_name)
    if item == nil then
        return
    end

    local group_name = TryGetProp(item, "GroupName", "None")
    local class_type = TryGetProp(item, "ClassType", "None")

    if group_name == "Recipe" then
        local recipe_cls = GetClass("Recipe", item_name)
        if recipe_cls ~= nil then
            local target_item_name = TryGetProp(recipe_cls, "TargetItem", "None")
            local target_item_cls = GetClass("Item", target_item_name)
            if target_item_cls ~= nil then
                group_name = TryGetProp(target_item_cls, "GroupName", "None")
                class_type = TryGetProp(target_item_cls, "ClassType", "None")
            end
        end
    end

    if group_name == "Weapon" then
        if IsExistRewardItemInList(list.weapon_btn, item_name) == false and IsExistRewardItemInList(list.subweapon_btn, item_name) == false then
            list.weapon_btn[#list.weapon_btn + 1] = item
        end
    elseif group_name == "SubWeapon" then
        local target_list = class_type == "Armband" and list.acc_btn or list.subweapon_btn
        if IsExistRewardItemInList(target_list, item_name) == false then
            target_list[#target_list + 1] = item
        end
    elseif group_name == "Armor" then
        local target_list = list.armor_btn
        if class_type == "Neck" or class_type == "Ring" then
            target_list = list.acc_btn
        elseif class_type == "Shield" then
            target_list = list.subweapon_btn
        end

        if IsExistRewardItemInList(target_list, item_name) == false then
            target_list[#target_list + 1] = item
        end
    else
        if IsExistRewardItemInList(list.material_btn, item_name) == false then
            list.material_btn[#list.material_btn + 1] = item
        end
    end
end

local function GetCountObject(indun_cls)
    if indun_cls == nil then
        return nil
    end

    if TryGetProp(indun_cls, "UnitPerReset", "PC") == "ACCOUNT" then
        return GetMyAccountObj()
    end
    return GetMyEtcObject()
end

local function GetEnterContext(frame, check_multiple_item_lock)
    if frame == nil then
        return nil
    end

    local top_frame = frame:GetTopParentFrame()
    if top_frame == nil then
        return nil
    end

    local multiple_count = top_frame:GetUserIValue("multipleCount")
    local indun_type = top_frame:GetUserIValue("INDUN_TYPE")
    local indun_cls = GetClassByType("Indun", indun_type)
    if indun_cls == nil then
        return nil
    end

    local indun_min_pc_rank = TryGetProp(indun_cls, "PCRank")
    local total_job_count = session.GetPcTotalJobGrade()
    if indun_min_pc_rank ~= nil and indun_min_pc_rank > total_job_count then
        ui.SysMsg(ScpArgMsg("IndunEnterNeedPCRank", "NEED_RANK", indun_min_pc_rank))
        return nil
    end

    if check_multiple_item_lock == true and multiple_count > 0 then
        local multiple_item_list = GET_INDUN_MULTIPLE_ITEM_LIST()
        for i = 1, #multiple_item_list do
            local item_name = multiple_item_list[i]
            local inv_item = session.GetInvItemByName(item_name)
            if inv_item ~= nil and inv_item.isLockState then
                ui.SysMsg(ClMsg("MaterialItemIsLock"))
                return nil
            end
        end
    end
    return top_frame, indun_cls, indun_type, multiple_count
end

local function GetTicketRemainCount(indun_cls)
    if indun_cls == nil then
        return nil
    end

    if TryGetProp(indun_cls, "TicketingType", "None") ~= "Entrance_Ticket" then
        return nil
    end

    local check_count_name = TryGetProp(indun_cls, "CheckCountName", "None")
    if check_count_name == "None" then
        return nil
    end

    local count_object = GetCountObject(indun_cls)
    if count_object == nil then
        return 0
    end
    return TryGetProp(count_object, check_count_name, 0)
end

local function CheckAdmissionItem(frame, match_type)
    if frame == nil then
        return false
    end

    if match_type == nil then
        match_type = 1
    end

    local indun_cls = GetClassByType("Indun", frame:GetUserIValue("INDUN_TYPE"))
    if indun_cls == nil then
        return false
    end

    local ticket_remain_count = GetTicketRemainCount(indun_cls)
    if ticket_remain_count ~= nil and ticket_remain_count < 1 then
        ui.SysMsg(ScpArgMsg("RaidEntranceCountLimit", "Raid", TryGetProp(indun_cls, "Name", "None")))
        return false
    end

    local admission_item_name = TryGetProp(indun_cls, "AdmissionItemName", "None")
    if admission_item_name == "None" then
        return true
    end

    local pc = GetMyPCObject()
    local count_object = GetCountObject(indun_cls)
    if pc == nil or count_object == nil then
        return false
    end

    local token_count = 0
    if session.loginInfo.IsPremiumState(ITEM_TOKEN) == true then
        token_count = TryGetProp(indun_cls, "PlayPerReset_Token", 0)
    end

    local reset_type = TryGetProp(indun_cls, "PlayPerResetType", 0)
    local weekly_count = TryGetProp(indun_cls, "WeeklyEnterableCount", 0)
    local now_count = TryGetProp(count_object, "InDunCountType_"..tostring(reset_type), 0)
    if weekly_count ~= 0 then
        now_count = TryGetProp(count_object, "IndunWeeklyEnteredCount_"..tostring(reset_type), 0)
    end

    local admission_item_count = TryGetProp(indun_cls, "AdmissionItemCount", 0)
    local additional_item_count = TryGetProp(indun_cls, "AdmissionPlayAddItemCount", 0)
    local add_count = math.max(0, math.floor((now_count - weekly_count) * additional_item_count))
    local required_count = math.max(0, admission_item_count + add_count - token_count)

    if IsBuffApplied(pc, "Event_Steam_New_World_Buff") == "YES" and admission_item_name == "Dungeon_Key01_NoTrade" then
        required_count = 1
    elseif IsBuffApplied(pc, "Event_Unique_Raid_Bonus") == "YES" and admission_item_name == "Dungeon_Key01_NoTrade" then
        required_count = admission_item_count
    elseif IsBuffApplied(pc, "Event_Unique_Raid_Bonus_Limit") == "YES" and admission_item_name == "Dungeon_Key01_NoTrade" then
        local account_object = GetMyAccountObj()
        if account_object ~= nil and TryGetProp(account_object, "EVENT_UNIQUE_RAID_BONUS_LIMIT", 0) > 0 then
            required_count = admission_item_count
        end
    end

    local inv_count = GetInvItemCount(pc, admission_item_name)
    local inv_item = session.GetInvItemByName(admission_item_name)
    local dungeon_type = TryGetProp(indun_cls, "DungeonType", "None")
    if (dungeon_type == "Raid" or dungeon_type == "GTower") and now_count < weekly_count then
        return true
    end

    if dungeon_type == "Raid" or dungeon_type == "GTower" then
        local multiple_count = frame:GetUserIValue("multipleCount")
        local yes_script = string.format("INDUNENTER_SELECT_STEP_REQ_MOVE_TO_INDUN(%d,%d)", match_type, multiple_count)
        local item_cls = GetClass("Item", admission_item_name)
        local item_name = TryGetProp(item_cls, "Name", "None")
        if TryGetProp(indun_cls, "SubType", "None") ~= "Casual" then
            if inv_item == nil or inv_count < required_count then
                ui.MsgBox(ScpArgMsg("HaveNoAdmissionItem", "Name", item_name), yes_script, "None")
            elseif inv_item.isLockState == true then
                ui.MsgBox(ScpArgMsg("AdmissionItemIsLocked", "Name", item_name), yes_script, "None")
            else
                ui.MsgBox(ScpArgMsg("EnterWithAdmissionItem", "Name", item_name, "Count", required_count), yes_script, "None")    
            end
            return false
        end
    end

    if inv_count == nil or inv_count < required_count then
        ui.MsgBox_NonNested(ClMsg("CannotJoinIndunItemScarcity"))
        return false
    end

    if inv_item == nil or inv_item.isLockState == true then
        ui.MsgBox_NonNested(ClMsg("AdmissionItemLockMsg"))
        return false
    end
    return true
end

local function GetStepList(frame)
    if frame == nil then
        return
    end

    local indun_type = frame:GetUserIValue("INDUN_TYPE")
    return shared_indun_step.get_list(indun_type)
end

local function GetStepInfo(frame, step)
    if frame == nil then
        return
    end

    local indun_type = frame:GetUserIValue("INDUN_TYPE")
    return shared_indun_step.get_info(indun_type, step)
end

local function IsUnlockedStep(frame, step)
    if frame == nil then
        return false
    end

    local pc = GetMyPCObject()
    local indun_type = frame:GetUserIValue("INDUN_TYPE")
    if shared_indun_step.is_unlocked(pc, indun_type, step) == true then
        return true
    end
    return false
end

local function GetRequestStep(frame, join_method)
    if frame == nil then
        return nil
    end

    if join_method == 4 then
        return 0
    end

    local selected_step = frame:GetUserIValue("SELECTED_STEP")
    local step_info = GetStepInfo(frame, selected_step)
    if step_info == nil then
        return nil
    end

    if IsUnlockedStep(frame, selected_step) == false then
        ui.SysMsg(ScpArgMsg("IndunInfoSelectStepLock"))
        return nil
    end
    return selected_step
end

-- open & close
function INDUNENTER_SELECT_STEP_UI_RESET(frame)
    local top_frame = ui.GetFrame("indunenter_select_step")
    if top_frame == nil then
        return
    end

    local button_names = { 'weapon_btn', 'subweapon_btn', 'armor_btn', 'acc_btn', 'material_btn' }
    local image_names = { 'indun_weapon', 'indun_shield', 'indun_armour', 'indun_acc', 'indun_material' }
    for i = 1, #button_names do
        local button = GET_CHILD_RECURSIVELY(top_frame, button_names[i])
        if button ~= nil then
            button:SetImage(image_names[i])
            button:SetUserValue(button_names[i], 'NO')
        end
    end
    INDUNENTER_SELECT_STEP_REFRESH_ENTER_BUTTON_STATE(top_frame)
end

function INDUNENTER_SELECT_STEP_ON_ESCAPE_PRESSED(frame, msg, arg_str, arg_num)
    local top_frame = ui.GetFrame("indunenter_select_step")
    if top_frame == nil or top_frame:GetUserValue("INDUNENTER_SELECT_STEP_ACTIVE") ~= "YES" then
        return
    end

    if top_frame:GetUserValue("AUTOMATCH_MODE") == "YES" then
        return
    end
    INDUNENTER_SELECT_STEP_CLOSE(frame, msg, arg_str, arg_num)
end

function INDUNENTER_SELECT_STEP_CLOSEBUTTON_PRESSED(frame, ctrl)
    local top_frame = frame:GetTopParentFrame()
    if top_frame == nil then
        return
    end

    if top_frame:GetUserValue("FRAME_MODE") == "SMALL" and top_frame:GetUserValue("AUTOMATCH_MODE") == "YES" then
        packet.SendCancelIndunMatching()
        return
    end
    INDUNENTER_SELECT_STEP_CLOSE(frame)
end

function INDUNENTER_SELECT_STEP_CLOSE(frame, msg, arg_str, arg_num)
    local top_frame = ui.GetFrame("indunenter_select_step")
    if top_frame == nil
        or top_frame:GetUserValue("INDUNENTER_SELECT_STEP_ACTIVE") ~= "YES"
        or top_frame:GetUserValue("INDUNENTER_SELECT_STEP_CLOSING") == "YES" then
        return
    end

    top_frame:SetUserValue("INDUNENTER_SELECT_STEP_CLOSING", "YES")
    top_frame:SetUserValue("INDUNENTER_SELECT_STEP_ACTIVE", "NO")

    packet.SendCancelIndunMatching()
    packet.SendCancelIndunPartyMatching()

    INDUNENTER_SELECT_STEP_RESET_BIG_MODE(top_frame)

    ui.CloseFrame('toshero_info_monster')
    ui.CloseFrame("indunenter_select_step")
    CloseIndunEnterDialog()
end

-- set enter button
---- enable & show control
function INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, control_name, is_show, is_enable)
    local control = GET_CHILD_RECURSIVELY(frame, control_name)
    if control ~= nil then
        control:ShowWindow(is_show)
        control:SetEnable(is_enable)
    end
end

---- button richtext refresh : auto match, with match
function INDUNENTER_SELECT_STEP_REFRESH_ENTER_BUTTON_TEXT(frame)
    if frame == nil then
        return
    end

    local automatch_mode = frame:GetUserValue("AUTOMATCH_MODE")
    local withmatch_mode = frame:GetUserValue("WITHMATCH_MODE")
    INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "automatch_text", BoolToNumber(automatch_mode ~= "YES"), 1)
    INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "automatch_time", BoolToNumber(automatch_mode == "YES"), 1)
    INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "with_party_auto_text", BoolToNumber(withmatch_mode ~= "YES"), 1)
    INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "with_cur_member_text", BoolToNumber(withmatch_mode == "YES"), 1)
end

---- button richtext refresh : reenter, understaff
function INDUNENTER_SELECT_STEP_REFRESH_REENTER_UNDERSTAFF_BUTTON(frame, enable_reenter)
    if frame == nil then
        return
    end

    if enable_reenter == nil then
        enable_reenter = frame:GetUserIValue("ENABLE_REENTER")
    end

    if enable_reenter == 1 then
        INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "reenter_btn", 1, 1)
        INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "understaff_enter_allow_btn", 0, 0)
    else
        INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "reenter_btn", 0, 0)
        INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "understaff_enter_allow_btn", 1, 0)
    end
end

---- auto match button refresh
function INDUNENTER_SELECT_STEP_REFRESH_AUTOMATCH_MODE(is_start)
    local frame = ui.GetFrame("indunenter_select_step")
    if frame == nil then
        return
    end

    if is_start == 1 then
        frame:SetUserValue("AUTOMATCH_MODE", "YES")
        frame:SetUserValue("WITHMATCH_MODE", "NO")
    else
        frame:SetUserValue("AUTOMATCH_MODE", "NO")
    end
    INDUNENTER_SELECT_STEP_REFRESH_ENTER_BUTTON_STATE(frame)
end

---- party match button refresh
function INDUNENTER_SELECT_STEP_REFRESH_PARTYMATCH_MODE(is_start)
    local frame = ui.GetFrame("indunenter_select_step")
    if frame == nil then
        return
    end

    if is_start == 1 then
        frame:SetUserValue("WITHMATCH_MODE", "YES")
        frame:SetUserValue("AUTOMATCH_MODE", "NO")
    else
        frame:SetUserValue("WITHMATCH_MODE", "NO")
    end
    INDUNENTER_SELECT_STEP_REFRESH_ENTER_BUTTON_STATE(frame)
end

---- reenter or understaff button state refresh
function INDUNENTER_SELECT_STEP_REFRESH_STATE_REENTER_UNDERSTAFF_BUTTON(is_enable_reenter)
    local frame = ui.GetFrame("indunenter_select_step")
    if frame == nil then
        return
    end
    frame:SetUserValue("ENABLE_REENTER", is_enable_reenter)
    INDUNENTER_SELECT_STEP_REFRESH_ENTER_BUTTON_STATE(frame)
end

---- total button state
function INDUNENTER_SELECT_STEP_REFRESH_ENTER_BUTTON_STATE(frame)
    if frame == nil then
        return
    end

    local enable_enter_right = frame:GetUserIValue("ENABLE_ENTERRIGHT")
    local enable_auto_match = frame:GetUserIValue("ENABLE_AUTOMATCH")
    local enable_party_match = frame:GetUserIValue("ENABLE_PARTYMATCH")
    local enable_reenter = frame:GetUserIValue("ENABLE_REENTER")
    local party_match_pending = frame:GetUserValue("PARTYMATCH_REQUEST_PENDING") == "YES"

    local automatch_mode = frame:GetUserValue("AUTOMATCH_MODE")
    local withmatch_mode = frame:GetUserValue("WITHMATCH_MODE")

    local enter_enable = enable_enter_right
    local automatch_enable = enable_auto_match
    local party_match_enable = enable_party_match
    local show_reenter = enable_reenter

    if automatch_mode == "YES" then
        enter_enable = 0
        automatch_enable = enable_auto_match
        party_match_enable = 0
        show_reenter = 0
    end

    if withmatch_mode == "YES" then
        enter_enable = 0
        automatch_enable = 0
        party_match_enable = enable_party_match
        show_reenter = 0
    end

    if party_match_pending == true then
        enter_enable = 0
        automatch_enable = 0
        party_match_enable = 0
        show_reenter = 0
    end

    INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "enter_right_btn", 1, enter_enable)
    INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "automatch_btn", 1, automatch_enable)
    INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "with_btn", 1, party_match_enable)
    INDUNENTER_SELECT_STEP_REFRESH_REENTER_UNDERSTAFF_BUTTON(frame, show_reenter)
    INDUNENTER_SELECT_STEP_REFRESH_ENTER_BUTTON_TEXT(frame)

    local show_small_btn = BoolToNumber(enable_auto_match == 1)
    INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "small_btn", show_small_btn, automatch_enable)
    
    local frame_mode = frame:GetUserValue("FRAME_MODE")
    if frame_mode == "SMALL" then
        INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "main_gb", 0, 0)
        INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "main_small_gb", 1, 1)
    else
        INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "main_gb", 1, 1)
        INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "main_small_gb", 0, 0)
    end
end

-- on button
---- on automatch button 
function ON_INDUNENTER_SELECT_STEP_AUTOMATCH(frame, ctrl)
    if frame == nil then
        return
    end

    local top_frame, indun_cls, indun_type, multiple_count = GetEnterContext(frame, true)
    if top_frame == nil then
        return
    end

     if top_frame:GetUserValue("AUTOMATCH_MODE") == "NO" then
        if CheckAdmissionItem(top_frame, 2) == false then
            return
        end
        INDUNENTER_SELECT_STEP_REQ_MOVE_TO_INDUN(2, multiple_count)
    else
        packet.SendCancelIndunMatching()
    end
end

---- on partymatch button
function ON_INDUNENTER_SELECT_STEP_PARTYMATCH(frame, ctrl)
    if frame == nil then
        return
    end

    local top_frame, indun_cls, indun_type, multiple_count = GetEnterContext(frame, true)
    if top_frame == nil then
        return
    end

    if top_frame:GetUserValue("PARTYMATCH_REQUEST_PENDING") == "YES" then
        return
    end

    if session.party.GetPartyInfo(PARTY_NORMAL) == nil then
        ui.SysMsg(ClMsg("HadNotMyParty"))
        return
    end

    if CheckAdmissionItem(top_frame) == false then
        return
    end

    top_frame:SetUserValue("PARTYMATCH_REQUEST_PENDING", "YES")
    INDUNENTER_SELECT_STEP_REFRESH_ENTER_BUTTON_STATE(top_frame)

    if top_frame:GetUserValue("WITHMATCH_MODE") == "NO" then
        INDUNENTER_SELECT_STEP_REQ_MOVE_TO_INDUN(3, multiple_count)
    else
        ReqRegisterToIndun(top_frame:GetUserIValue("INDUN_TYPE"))
    end
end

---- on enter right button
function ON_INDUNENTER_SELECT_STEP_ENTERRIGHT(frame, ctrl)
    if frame == nil then
        return
    end

    local top_frame, indun_cls, indun_type, multiple_count = GetEnterContext(frame, true)
    if top_frame == nil then
        return
    end

    if CheckAdmissionItem(top_frame, 1) == false then
        return
    end

    local player_count = TryGetProp(indun_cls, "PlayerCnt", 1)
    local party = session.party.GetPartyMemberList(PARTY_NORMAL)
    if party:Count() > player_count then
        ui.SysMsg(ClMsg("OverIndunMaxPC"))
        return
    end

    local yes_script = string.format("INDUNENTER_SELECT_STEP_REQ_MOVE_TO_INDUN(%d,%d)", 1, multiple_count)
    ui.MsgBox(ScpArgMsg("EnterRightNow"), yes_script, "None")
end

---- on reenter
function ON_INDUNENTER_SELECT_STEP_REENTER(frame, ctrl)
    if frame == nil then
        return
    end

    local top_frame, indun_cls, indun_type, multiple_count = GetEnterContext(frame, false)
    if top_frame == nil then
        return
    end

    if top_frame:GetUserIValue("ENABLE_REENTER") ~= 1 then
        return
    end

    if multiple_count > 0 then
        local yes_script = string.format("INDUNENTER_SELECT_STEP_REQ_MOVE_TO_INDUN(%d,%d)", 4, multiple_count)
        ui.MsgBox(ClMsg("ReenterMultipleNotAllowed"), yes_script, "None")
        return
    end
    INDUNENTER_SELECT_STEP_REQ_MOVE_TO_INDUN(4, multiple_count)
end

---- on understaff enter : myinfo
function INDUNENTER_SELECT_STEP_UNDERSTAFF_SET_MY_INFO(frame, understaff)
    if frame == nil then
        return
    end

    local pc = GetMyPCObject()
    local etc_object = GetMyEtcObject()
    local my_session = session.GetMySession()
    if pc == nil or etc_object == nil or my_session == nil then
        return
    end

    local aid = session.loginInfo.GetAID()
    local cid = my_session:GetCID()
    local level = TryGetProp(pc, "Lv", 0)
    local job_id = TryGetProp(etc_object, "RepresentationClassID", 0)
    frame:SetUserValue("MEMBER_INFO", aid.."/"..tostring(job_id).."/"..tostring(level).."/"..cid.."/"..understaff)
end

---- on understaff enter : check party auto match, member info flag
function INDUNENTER_SELECT_STEP_CHECK_UNDERSTAFF_MODE_WITH_PARTY(frame)
    if frame == nil then
        return false
    end

    local with_match_mode = frame:GetUserValue("WITHMATCH_MODE")
    if with_match_mode ~= "YES" then
        return false
    end

    local member_info = frame:GetUserValue("MEMBER_INFO")
    local member_info_table = StringSplit(member_info, "/")
    if #member_info_table < INDUNENTER_SELECT_STEP_PC_INFO_COUNT then
        return false
    end

    if member_info_table[INDUNENTER_SELECT_STEP_PC_INFO_COUNT] ~= "YES" then
        return false
    end
    return true
end

---- on understaff enter : enable setting
function INDUNENTER_SELECT_STEP_UNDERSTAFF_BTN_ENABLE(frame, enable)
    if frame == nil then
        return
    end

    local understaff_btn = GET_CHILD_RECURSIVELY(frame, "understaff_enter_allow_btn")
    local small_understaff_btn = GET_CHILD_RECURSIVELY(frame, "small_understaff_enter_allow_btn")

    local indun_cls = GetClassByType("Indun", frame:GetUserIValue("INDUN_TYPE"))
    if indun_cls ~= nil and TryGetProp(indun_cls, "EnableUnderStaffEnter", "YES") == "NO" then
        enable = 0
    end

    if understaff_btn ~= nil then
        understaff_btn:SetEnable(enable)
        if enable == 1 then
            understaff_btn:ShowWindow(1)
        end
    end

    if small_understaff_btn ~= nil then
        small_understaff_btn:SetEnable(enable)
    end

    local reenter_btn = GET_CHILD_RECURSIVELY(frame, "reenter_btn")
    if understaff_btn ~= nil and understaff_btn:IsVisible() == 1 and reenter_btn ~= nil then
        reenter_btn:ShowWindow(0)
    end
end

---- on understaff enter
function ON_INDUNENTER_SELECT_STEP_REQ_UNDERSTAFF_ENTER_ALLOW(parent, ctrl)
    if parent == nil then
        return
    end

    local top_frame = parent:GetTopParentFrame()
    if top_frame == nil then
        return
    end

    local use_count = tonumber(top_frame:GetUserValue("multipleCount")) or 0
    if use_count > 0 then
        local multiple_item_list = GET_INDUN_MULTIPLE_ITEM_LIST()
        for i = 1, #multiple_item_list do
            local item_name = multiple_item_list[i]
            local inv_item = session.GetInvItemByName(item_name)
            if inv_item ~= nil and inv_item.isLockState then
                ui.SysMsg(ClMsg("MaterialItemIsLock"))
                return
            end
        end
    end

    local automatch_mode = top_frame:GetUserValue("AUTOMATCH_MODE")
    local with_match_mode = top_frame:GetUserValue("WITHMATCH_MODE")
    if automatch_mode ~= "YES" and with_match_mode == "NO" then
        ui.SysMsg(ScpArgMsg("EnableWhenAutoMatching"))
        return
    end

    local indun_type = top_frame:GetUserIValue("INDUN_TYPE")
    local indun_cls = GetClassByType("Indun", indun_type)
    if indun_cls == nil then
        return
    end

    local min_member = TryGetProp(indun_cls, "UnderstaffEnterAllowMinMember")
    if min_member == nil then
        return
    end

    local yes_script = "EXEC_INDUNENTER_SELECT_STEP_REQ_UNDERSTAFF_ENTER_ALLOW()"
    local client_msg = ScpArgMsg("ReallyAllowUnderstaffMatchingWith{MIN_MEMBER}?", "MIN_MEMBER", min_member)
    if INDUNENTER_SELECT_STEP_CHECK_UNDERSTAFF_MODE_WITH_PARTY(top_frame) == true then
        client_msg = ClMsg("CancelUnderstaffMatching")
    end

    if with_match_mode == "YES" then
        yes_script = "ReqUnderstaffEnterAllowModeWithParty("..indun_type..")"
    end
    ui.MsgBox(client_msg, yes_script, "None")
end

---- on understaff enter : exec
function EXEC_INDUNENTER_SELECT_STEP_REQ_UNDERSTAFF_ENTER_ALLOW()
    local frame = ui.GetFrame("indunenter_select_step")
    if frame == nil then
        return
    end
    ReqUnderstaffEnterAllowMode()
    INDUNENTER_SELECT_STEP_UNDERSTAFF_SET_MY_INFO(frame, "YES")
    INDUNENTER_SELECT_STEP_UNDERSTAFF_BTN_ENABLE(frame, 0)
end

---- on mon right btn
function ON_INDUNENTER_SELECT_STEP_MON_CLICK_RIGHT(parent, ctrl)
    local frame = parent:GetTopParentFrame()
    if frame == nil then
        return
    end

    local monster_count = frame:GetUserIValue("MON_SLOT_CNT")
    if monster_count < 6 then
        return
    end

    local monster_slotset = GET_CHILD_RECURSIVELY(frame, "monster_slotset")
    local left_btn = GET_CHILD_RECURSIVELY(frame, "left_btn")
    if monster_slotset == nil or left_btn == nil then
        return  
    end

    local current_slot = monster_slotset:GetUserIValue("CURRENT_SLOT")
    if current_slot + 4 >= monster_count then
        return
    end

    UI_PLAYFORCE(monster_slotset, "slotsetLeftMove_1")
    monster_slotset:SetUserValue("CURRENT_SLOT", current_slot + 1)
    ctrl:SetEnable(BoolToNumber(current_slot + 5 < monster_count))
    left_btn:SetEnable(1)
end

---- on mon left btn
function ON_INDUNENTER_SELECT_STEP_MON_CLICK_LEFT(parent, ctrl)
    local frame = parent:GetTopParentFrame()
    if frame == nil then
        return
    end

    local monster_count = frame:GetUserIValue("MON_SLOT_CNT")
    if monster_count < 6 then
        return
    end

    local monster_slotset = GET_CHILD_RECURSIVELY(frame, "monster_slotset")
    local right_btn = GET_CHILD_RECURSIVELY(frame, "right_btn")
    if monster_slotset == nil or right_btn == nil then
        return
    end

    local current_slot = monster_slotset:GetUserIValue("CURRENT_SLOT")
    if current_slot <= 1 then
        return
    end

    UI_PLAYFORCE(monster_slotset, "slotsetRightMove_1")
    monster_slotset:SetUserValue("CURRENT_SLOT", current_slot - 1)
    ctrl:SetEnable(BoolToNumber(current_slot - 1 > 1))
    right_btn:SetEnable(1)
end

-- show indunenter ui
function SHOW_INDUNENTER_SELECT_STEP_DIALOG(indun_type, is_already_playing, enable_auto_match, enable_enter_right, enable_party_match)
    local frame = ui.GetFrame("indunenter_select_step")
    if frame == nil or frame:IsVisible() == 1 then
        return
    end

    local pc = GetMyPCObject()
    local etc_object = GetMyEtcObject()
    local indun_cls = GetClassByType("Indun", indun_type)
    if pc == nil or etc_object == nil or indun_cls == nil then
        return
    end

    if string.find(TryGetProp(indun_cls, "DungeonType", "None"), "TOSHero") == 1 then
        indun_type = 652
    end

    if enable_enter_right == nil then
        enable_enter_right = 1
    end

    frame:SetUserValue("INDUN_TYPE", indun_type)
    frame:SetUserValue("INDUN_NAME", TryGetProp(indun_cls, "Name", ""))
    frame:SetUserValue("AUTOMATCH_MODE", "NO")
    frame:SetUserValue("WITHMATCH_MODE", "NO")
    frame:SetUserValue("PARTYMATCH_REQUEST_PENDING", "NO")
    frame:SetUserValue("UI_PC_COUNT", 0)
    frame:SetUserValue("UI_UNDERSTAFF_COUNT", 0)
    frame:SetUserValue("multipleCount", 0)
    frame:SetUserValue("ENABLE_ENTERRIGHT", enable_enter_right)
    frame:SetUserValue("ENABLE_AUTOMATCH", enable_auto_match or 0)
    frame:SetUserValue("ENABLE_PARTYMATCH", enable_party_match or 0)
    frame:SetUserValue("ENABLE_REENTER", is_already_playing or 0)
    frame:SetUserValue("INDUNENTER_SELECT_STEP_ACTIVE", "YES")
    frame:SetUserValue("INDUNENTER_SELECT_STEP_CLOSING", "NO")

    INDUNENTER_SELECT_STEP_UNDERSTAFF_SET_MY_INFO(frame, "NO")

    INDUNENTER_SELECT_STEP_RESET_BIG_MODE(frame)
    INDUNENTER_SELECT_STEP_MAKE_HEADER(frame)
    INDUNENTER_SELECT_STEP_MAKE_PICTURE(frame, indun_cls)
    INDUNENTER_SELECT_STEP_MAKE_ALERT(frame, indun_cls)
    INDUNENTER_SELECT_STEP_MAKE_COUNT_BOX(frame, indun_cls)
    INDUNENTER_SELECT_STEP_MAKE_LEVEL_BOX(frame, indun_cls)
    INDUNENTER_SELECT_STEP_MAKE_MONLIST(frame, indun_cls)
    INDUNENTER_SELECT_STEP_SET_ADMISSION_ITEM_TEXT(frame, indun_cls, pc, etc_object)
    INDUNENTER_SELECT_STEP_INIT_STEP_UI(frame)
    INDUNENTER_SELECT_STEP_REFRESH_PARTY(frame)
    INDUNENTER_SELECT_STEP_REFRESH_ENTER_BUTTON_STATE(frame)

    local main_gb = GET_CHILD_RECURSIVELY(frame, "main_gb")
    frame:ShowWindow(1)
    main_gb:ShowWindow(1)
end

-- make
---- make - header
function INDUNENTER_SELECT_STEP_MAKE_HEADER(frame)
    local indun_name_value = frame:GetUserValue("INDUN_NAME")
    if indun_name_value == nil or indun_name_value == "" or indun_name_value == "None" then
        return
    end

    local indun_name = GET_CHILD_RECURSIVELY(frame, "indun_name_text")
    if indun_name ~= nil then
        indun_name:SetText(indun_name_value)
    end

    local small_title = GET_CHILD_RECURSIVELY(frame, "small_indun_name_text")
    if small_title ~= nil then
        small_title:SetText(indun_name_value)
    end
end

---- mkae - indun pic
function INDUNENTER_SELECT_STEP_MAKE_PICTURE(frame, indun_cls)
    if frame == nil or indun_cls == nil then
        return
    end

    local indun_pic = GET_CHILD_RECURSIVELY(frame, "indun_pic")
    local map_image = TryGetProp(indun_cls, "MapImage", "None")
    if indun_pic ~= nil and map_image ~= "None" then
        indun_pic:SetImage(map_image)
    end
end

---- make - alert
function INDUNENTER_SELECT_STEP_MAKE_ALERT(frame, indun_cls)
    if frame == nil or indun_cls == nil then
        return
    end

    INDUNENTER_SELECT_STEP_MAKE_SKILL_ALERT(frame, indun_cls)
    INDUNENTER_SELECT_STEP_MAKE_ITEM_ALERT(frame, indun_cls)
    INDUNENTER_SELECT_STEP_MAKE_DUNGEON_ALERT(frame, indun_cls)

    local restrict_gb = GET_CHILD_RECURSIVELY(frame, "restrict_gb")
    if restrict_gb ~= nil then
        GBOX_AUTO_ALIGN(restrict_gb, 2, 2, 0, true, true, true)
    end
end

---- make - alert : skill
function INDUNENTER_SELECT_STEP_MAKE_SKILL_ALERT(frame, indun_cls)
    local restrict_skill_gb = GET_CHILD_RECURSIVELY(frame, "restrict_skill_gb")
    if restrict_skill_gb == nil then
        return
    end
    restrict_skill_gb:ShowWindow(0)

    local map_name = TryGetProp(indun_cls, "MapName", "None")
    if map_name == "None" then
        map_name = TryGetProp(indun_cls, "StartMap", "None")
    end

    local map_cls = GetClass("Map", map_name)
    local map_keyword = TryGetProp(map_cls, "Keyword", "None")
    if map_keyword == "None" or string.find(map_keyword, "IsRaidField") == nil then
        return
    end

    local dungeon_type = TryGetProp(indun_cls, "DungeonType", "None")
    local is_legend_raid = dungeon_type == "Raid" or dungeon_type == "GTower" or string.find(dungeon_type, "MythicDungeon") == 1

    restrict_skill_gb:ShowWindow(1)
    restrict_skill_gb:SetTooltipOverlap(1)
    restrict_skill_gb:SetPosTooltip(frame:GetUserConfig("TOOLTIP_POSX"), frame:GetUserConfig("TOOLTIP_POSY"))
    restrict_skill_gb:SetTooltipType("skillRestrictList")
    restrict_skill_gb:SetTooltipArg("IsRaidField", BoolToNumber(is_legend_raid))
end

---- make - alert : item
function INDUNENTER_SELECT_STEP_MAKE_ITEM_ALERT(frame, indun_cls)
     local restrict_item_gb = GET_CHILD_RECURSIVELY(frame, "restrict_item_gb")
    if restrict_item_gb == nil then
        return
    end
    restrict_item_gb:ShowWindow(0)

    local class_name = TryGetProp(indun_cls, "ClassName", "None")
    if GetClassByStrProp("ItemRestrict", "Category", class_name) == nil then
        return
    end

    restrict_item_gb:ShowWindow(1)
    restrict_item_gb:SetTooltipOverlap(1)
    restrict_item_gb:SetPosTooltip(frame:GetUserConfig("TOOLTIP_POSX"), frame:GetUserConfig("TOOLTIP_POSY"))
    restrict_item_gb:SetTooltipType("itemRestrictList")
    restrict_item_gb:SetTooltipArg(class_name)
end

---- make - alert : dungeon
function INDUNENTER_SELECT_STEP_MAKE_DUNGEON_ALERT(frame, indun_cls)
    local restrict_dungeon_gb = GET_CHILD_RECURSIVELY(frame, "restrict_dungeon_gb")
    if restrict_dungeon_gb == nil then
        return
    end
    restrict_dungeon_gb:ShowWindow(0)

    local class_name = TryGetProp(indun_cls, "ClassName", "None")
    if GetClassByStrProp("dungeon_restrict", "Category", class_name) == nil then
        return
    end

    restrict_dungeon_gb:ShowWindow(1)
    restrict_dungeon_gb:SetTooltipOverlap(1)
    restrict_dungeon_gb:SetPosTooltip(frame:GetUserConfig("TOOLTIP_POSX"), frame:GetUserConfig("TOOLTIP_POSY"))
    restrict_dungeon_gb:SetTooltipType("dungeonRestrictList")
    restrict_dungeon_gb:SetTooltipArg(class_name)
end

---- make - count
function INDUNENTER_SELECT_STEP_MAKE_COUNT_BOX(frame, indun_cls)
    if frame == nil or indun_cls == nil then
        return
    end

    local count_text = GET_CHILD_RECURSIVELY(frame, "count_text")
    local count_data_text = GET_CHILD_RECURSIVELY(frame, "count_data_text")
    local count_data2_text = GET_CHILD_RECURSIVELY(frame, "count_data2_text")
    local count_item_data_text = GET_CHILD_RECURSIVELY(frame, "count_item_data_text")
    local count_cycle_pic = GET_CHILD_RECURSIVELY(frame, "count_cycle_pic")
    if count_text == nil or count_data_text == nil or count_data2_text == nil or count_item_data_text == nil or count_cycle_pic == nil then
        return
    end

    count_data_text:ShowWindow(0)
    count_data2_text:ShowWindow(0)
    count_item_data_text:ShowWindow(0)
    count_cycle_pic:ShowWindow(0)

    local count_object = GetCountObject(indun_cls)
    if count_object == nil then
        return
    end

    local ticket_remain_count = GetTicketRemainCount(indun_cls)
    if ticket_remain_count ~= nil then
        count_data2_text:SetTextByKey("now", ticket_remain_count)
        count_data_text:ShowWindow(0)
        count_data2_text:ShowWindow(1)
        count_item_data_text:ShowWindow(0)
        return
    end

    local admission_item_name = TryGetProp(indun_cls, "AdmissionItemName", "None")
    if admission_item_name ~= "None" then
        local pc = GetMyPCObject()
        local item_cls = GetClass("Item", admission_item_name)
        if pc ~= nil and item_cls ~= nil then
            local item_icon = TryGetProp(item_cls, "Icon", "None")
            local item_count = GetInvItemCount(pc, admission_item_name)
            count_text:SetText(ScpArgMsg("IndunAdmissionItemPossession"))
            count_item_data_text:SetTextByKey("ivnadmissionitem", string.format("{img %s 30 30} %d", item_icon, item_count))
            count_item_data_text:ShowWindow(1)
            return
        end
    end

    local reset_type = TryGetProp(indun_cls, "PlayPerResetType", 0)
    local weekly_count = TryGetProp(indun_cls, "WeeklyEnterableCount", 0)
    local now_count = TryGetProp(count_object, "InDunCountType_"..tostring(reset_type), 0)
    local max_count = TryGetProp(indun_cls, "PlayPerReset", 0)
    if weekly_count ~= 0 then
        now_count = TryGetProp(count_object, "IndunWeeklyEnteredCount_"..tostring(reset_type), 0)
        max_count = weekly_count
    end

    if session.loginInfo.IsPremiumState(ITEM_TOKEN) == true then
        max_count = max_count + TryGetProp(indun_cls, "PlayPerReset_Token", 0)
    end

    local max_text = max_count
    if TryGetProp(indun_cls, "EnableInfiniteEnter", "NO") == "YES" then
        max_text = "{img infinity_text 20 10}"
    end
    count_data_text:SetTextByKey("now", now_count)
    count_data_text:SetTextByKey("max", max_text)
    count_data_text:ShowWindow(1)
end

---- make - level
function INDUNENTER_SELECT_STEP_MAKE_LEVEL_BOX(frame, indun_cls)
    if frame == nil or indun_cls == nil then
        return
    end

    local level_data_text = GET_CHILD_RECURSIVELY(frame, "level_data_text")
    if level_data_text ~= nil then
        level_data_text:SetText(tostring(TryGetProp(indun_cls, "Level", 0)))
    end
end

---- make - mon
function INDUNENTER_SELECT_STEP_MAKE_MONLIST(frame, indun_cls)
    if frame == nil or indun_cls == nil then
        return
    end

    local monster_slotset = GET_CHILD_RECURSIVELY(frame, "monster_slotset")
    local right_btn = GET_CHILD_RECURSIVELY(frame, "right_btn")
    local left_btn = GET_CHILD_RECURSIVELY(frame, "left_btn")
    if monster_slotset == nil or right_btn == nil or left_btn == nil then
        return
    end
    monster_slotset:ClearIconAll()
    monster_slotset:SetUserValue("CURRENT_SLOT", 1)
    monster_slotset:SetOffset(monster_slotset:GetOriginalX(), monster_slotset:GetY())

    local boss_list = TryGetProp(indun_cls, "BossList", "None")
    if boss_list == "None" then
        frame:SetUserValue("MON_SLOT_CNT", 0)
        right_btn:SetEnable(0)
        left_btn:SetEnable(0)
        return
    end

    local boss_table = StringSplit(boss_list, '/')
    frame:SetUserValue("MON_SLOT_CNT", #boss_table)
    for i = 1, #boss_table do
        local slot = monster_slotset:GetSlotByIndex(i - 1)
        if slot ~= nil then
            local icon = CreateIcon(slot)
            if boss_table[i] == "Random" then
                icon:SetImage(frame:GetUserConfig("RANDOM_ICON"))
            else
                local monster_cls = GetClass("Monster", boss_table[i])
                if monster_cls ~= nil then
                    icon:SetImage(GET_MON_ILLUST(monster_cls))
                    icon:SetTooltipType("mon_simple")
                    icon:SetTooltipArg(boss_table[i])
                    icon:SetTooltipOverlap(1)
                end
            end
        end
    end
    right_btn:SetEnable(BoolToNumber(#boss_table > 5))
    left_btn:SetEnable(0)
end

---- make - enter right btn
function INDUNENTER_SELECT_STEP_SET_ADMISSION_ITEM_TEXT(frame, indun_cls, pc, etc_object)
    local enter_button = GET_CHILD_RECURSIVELY(frame, 'enter_right_btn')
    if enter_button == nil then
        return
    end

    local admission_item_name = TryGetProp(indun_cls, 'AdmissionItemName', 'None')
    if admission_item_name == 'None' then
        enter_button:SetTextByKey('image', '')
        return
    end

    local admission_item_count = TryGetProp(indun_cls, 'AdmissionItemCount', 0)
    local admission_play_add_item_count = TryGetProp(indun_cls, 'AdmissionPlayAddItemCount', 0)
    local admission_item_cls = GetClass('Item', admission_item_name)
    local admission_item_image = TryGetProp(admission_item_cls, 'Icon', 'None')
    local token_count = 0
    if session.loginInfo.IsPremiumState(ITEM_TOKEN) == true then
        token_count = TryGetProp(indun_cls, 'PlayPerReset_Token', 0)
    end

    if indun_cls.UnitPerReset == 'ACCOUNT' then
        etc_object = GetMyAccountObj()
    end
    if etc_object == nil then
        return
    end

    local reset_type = TryGetProp(indun_cls, 'PlayPerResetType', 0)
    local now_count = TryGetProp(etc_object, 'InDunCountType_' .. tostring(reset_type), 0)
    local add_count = math.floor(now_count * admission_play_add_item_count)
    local weekly_count = TryGetProp(indun_cls, 'WeeklyEnterableCount', 0)
    if weekly_count ~= 0 then
        now_count = TryGetProp(etc_object, 'IndunWeeklyEnteredCount_' .. tostring(reset_type), 0)
        add_count = math.max(0, math.floor((now_count - weekly_count) * admission_play_add_item_count))
    end

    local required_count = admission_item_count + add_count - token_count
    if IsBuffApplied(pc, 'Event_Steam_New_World_Buff') == 'YES' and admission_item_name == 'Dungeon_Key01_NoTrade' then
        required_count = 1
    elseif IsBuffApplied(pc, 'Event_Unique_Raid_Bonus') == 'YES' and admission_item_name == 'Dungeon_Key01_NoTrade' then
        required_count = admission_item_count
    elseif IsBuffApplied(pc, 'Event_Unique_Raid_Bonus_Limit') == 'YES' and admission_item_name == 'Dungeon_Key01_NoTrade' then
        local account_object = GetMyAccountObj()
        if TryGetProp(account_object, 'EVENT_UNIQUE_RAID_BONUS_LIMIT', 0) > 0 then
            required_count = admission_item_count
        end
    end

    if (indun_cls.DungeonType == 'Raid' or indun_cls.DungeonType == 'GTower') and now_count < weekly_count then
        enter_button:SetTextByKey('image', '')
    else
        enter_button:SetTextByKey('image', '  {img ' .. admission_item_image .. ' 24 24} - ' .. required_count)
    end
end

---- make - step init
function INDUNENTER_SELECT_STEP_INIT_STEP_UI(frame)
    local pc = GetMyPCObject()
    local indun_type = frame:GetUserIValue("INDUN_TYPE")
    local selected_step = shared_indun_step.get_first_unlocked_step(pc, indun_type)
    frame:SetUserValue("SELECTED_STEP", selected_step)
    INDUNENTER_SELECT_STEP_MAKE_STEP_CTRLSET(frame)
    INDUNENTER_SELECT_STEP_REFRESH_STEP_BUTTONS(frame)
    INDUNENTER_SELECT_STEP_REFRESH_STEP_INFO(frame)
end

---- make - step contrlset
function INDUNENTER_SELECT_STEP_MAKE_STEP_CTRLSET(frame)
    local step_gb = GET_CHILD_RECURSIVELY(frame, "step_gb")
    if step_gb == nil then
        return
    end
    DESTROY_CHILD_BYNAME(step_gb, "STEP_")

    local width = ui.GetControlSetAttribute("indunenter_select_step_btn", "width")
    local start_x = 5
    local space_x = 3
    local step_list = GetStepList(frame)
    for i = 1, #step_list do
        local info = step_list[i]
        if info ~= nil then
            local x = start_x + ((i - 1) * (width + space_x))
            local ctrlset = step_gb:CreateOrGetControlSet("indunenter_select_step_btn", "STEP_"..info.step, x, 0)
            if ctrlset ~= nil then
                ctrlset:SetUserValue("STEP", info.step)
                local btn = GET_CHILD_RECURSIVELY(ctrlset, "step_btn")
                if btn ~= nil then
                    btn:SetEventScript(ui.LBUTTONUP, "INDUNENTER_SELECT_STEP_SELECT")
                    btn:SetEventScriptArgNumber(ui.LBUTTONUP, info.step)
                    btn:SetEnable(1)
                end
            end
        end
    end
end

---- make - step refresh
function INDUNENTER_SELECT_STEP_REFRESH_PARTY(frame, msg, arg_str, arg_num)
    if frame == nil or frame:GetName() ~= "indunenter_select_step" then
        frame = ui.GetFrame("indunenter_select_step")
    end

    if frame:GetUserValue("AUTOMATCH_MODE") == "YES" or frame:GetUserValue("WITHMATCH_MODE") == "YES" or frame:GetUserValue("PARTYMATCH_REQUEST_PENDING") == "YES" then
        return
    end

    local member_box = GET_CHILD_RECURSIVELY(frame, "member_box")
    local party_line = GET_CHILD_RECURSIVELY(frame, "party_line")
    local member_count_text = GET_CHILD_RECURSIVELY(frame, "member_cnt_text")
    local member_count_box = GET_CHILD_RECURSIVELY(frame, "member_cnt_box")
    local party_ask_text = GET_CHILD_RECURSIVELY(frame, "party_ask_text")
    local party_list = session.party.GetPartyMemberList(PARTY_NORMAL)
    local party_count = party_list:Count()
    local display_count = math.max(1, party_count)
    local indun_cls = GetClassByType('Indun', frame:GetUserIValue("INDUN_TYPE"))
    if indun_cls == nil then
        return
    end
    DESTROY_CHILD_BYNAME(member_box, 'MEMBER_')
    
    local space_x = 15
    local start_y = 10
    local offset_x = 47
    local max_count = TryGetProp(indun_cls, 'PlayerCnt', 5)
    for i = 1, max_count do
        local x = space_x * i + offset_x * (i - 1)
        local y = start_y
        local member_control = member_box:CreateOrGetControlSet("indunMember", "MEMBER_"..i, x, y)
        local leader_image = member_control:GetChild("leader_img")
        local level_text = member_control:GetChild("level_text")
        local job_icon = GET_CHILD_RECURSIVELY(member_control, "jobportrait")
        local matched_icon = GET_CHILD_RECURSIVELY(member_control, "matchedIcon")
        local understaff_image = member_control:GetChild("understaffAllowImg")

        member_control:ShowWindow(1)
        leader_image:ShowWindow(0)
        level_text:ShowWindow(0)
        matched_icon:ShowWindow(0)
        understaff_image:ShowWindow(0)
        job_icon:ShowWindow(1)
        job_icon:SetImage(frame:GetUserConfig("NO_MATCH_SKIN"))

        if party_count > 0 and i <= party_count then
            local member_info = party_list:Element(i - 1)
            local icon_info = member_info:GetIconInfo()
            local job_id = icon_info.repre_job
            if job_id == nil or job_id == 0 then
                job_id = icon_info.job
            end
            local job_cls = GetClassByType("Job", job_id)
            if job_cls ~= nil then
                job_icon:SetImage(job_cls.Icon)
            end
            level_text:SetText(member_info:GetLevel())
            level_text:ShowWindow(1)

            local party_info = session.party.GetPartyInfo(PARTY_NORMAL)
            if party_info ~= nil and party_info.info:GetLeaderAID() == member_info:GetAID() then
                leader_image:ShowWindow(1)
            end
        elseif party_count == 0 and i == 1 then
            local pc = GetMyPCObject()
            local etc_object = GetMyEtcObject()
            local job_id = TryGetProp(etc_object, "RepresentationClassID", 0)
            local job_cls = GetClassByType("Job", job_id)
            if job_cls ~= nil then
                job_icon:SetImage(job_cls.Icon)
            end
            level_text:SetText(TryGetProp(pc, "Lv", 0))
            level_text:ShowWindow(1)
            leader_image:ShowWindow(1)
        end
    end
    party_line:ShowWindow(BoolToNumber(display_count > 1))

    if display_count > 1 then
        party_line:Resize(58 * (display_count - 1), 15)
    end

    member_count_text:SetTextByKey('cnt', display_count .. ClMsg("PersonCountUnit"))
    party_ask_text:ShowWindow(0)
    member_count_box:ShowWindow(1)
end

---- make - dropbox
function INDUNENTER_SELECT_STEP_MAKE_DROPBOX(parent, control)
    local frame = ui.GetFrame("indunenter_select_step")
    local reward_box = GET_CHILD_RECURSIVELY(frame, 'reward_gb')
    local control_name = control:GetName()
    local button_names = { 'weapon_btn', 'subweapon_btn', 'armor_btn', 'acc_btn', 'material_btn' }
    local image_names = { 'indun_weapon', 'indun_shield', 'indun_armour', 'indun_acc', 'indun_material' }

    for i = 1, #button_names do
        local button = GET_CHILD_RECURSIVELY(reward_box, button_names[i])
        if control_name == button_names[i] then
            local is_open = control:GetUserValue(control_name) == 'YES'
            control:SetImage(image_names[i] .. (is_open and '' or '_clicked'))
            control:SetUserValue(control_name, is_open and 'NO' or 'YES')
        else
            button:SetImage(image_names[i])
            button:SetUserValue(button_names[i], 'NO')
        end
    end

    if control:GetUserValue(control_name) == 'YES' then
        INDUNENTER_SELECT_STEP_DROPBOX_ITEM_LIST(parent, control)
    end
end

---- make - dropbox item list
function INDUNENTER_SELECT_STEP_DROPBOX_ITEM_LIST(parent, control)
    local frame = ui.GetFrame("indunenter_select_step")
    local indun_cls = GetClassByType('Indun', frame:GetUserIValue('INDUN_TYPE'))
    local control_name = control:GetName()
    local reward_item_list = {
        weapon_btn = {},
        subweapon_btn = {},
        armor_btn = {},
        acc_btn = {},
        material_btn = {}
    }
    local group_list = SCR_STRING_CUT(TryGetProp(indun_cls, 'Reward_Item', 'None'), '/')
    local all_reward_list, all_reward_count = GetClassList('reward_indun')

    if group_list ~= nil then
        for i = 1, #group_list do
            local item_name = SCR_STRING_CUT(group_list[i], ';')[1]
            local item_cls = GetClass('Item', item_name)
            if TryGetProp(item_cls, 'GroupName', 'None') == 'Cube' then
                local item_group = TryGetProp(item_cls, 'StringArg', 'None')
                for j = 0, all_reward_count - 1 do
                    local reward_cls = GetClassByIndexFromList(all_reward_list, j)
                    if reward_cls ~= nil and TryGetProp(reward_cls, 'Group', 'None') == item_group then
                        CheckAndFill_RewardBox(reward_item_list, reward_cls.ItemName)
                    end
                end
            else
                CheckAndFill_RewardBox(reward_item_list, item_name)
            end
        end
    end

    local item_count = #reward_item_list[control_name]
    if item_count == 0 then
        ui.MakeDropListFrame(control, 0, 0, 300, 600, 1, ui.LEFT, 'INDUNENTER_SELECT_STEP_DROPBOX_AFTER_BTN_DOWN', nil, nil)
        ui.AddDropListItem(ClMsg('IndunRewardItem_Empty'))
        return
    end

    ui.MakeDropListFrame(control, 0, 0, 300, 600, math.min(item_count, 10), ui.LEFT,
        'INDUNENTER_SELECT_STEP_DROPBOX_TOOLTIP_VIEW',
        'INDUNENTER_SELECT_STEP_DROPBOX_MOUSE_OVER',
        'INDUNENTER_SELECT_STEP_DROPBOX_MOUSE_OUT')
    for i = 1, item_count do
        local reward_item = reward_item_list[control_name][i]
        ui.AddDropListItem(reward_item.Name, nil, reward_item.ClassName)
    end

    local item_frame = ui.GetFrame('wholeitem_link') or ui.GetNewToolTip('wholeitem_link', 'wholeitem_link')
    item_frame:SetUserValue('MouseClickedCheck', 'NO')
end

---- make - dropbox after btn down
function INDUNENTER_SELECT_STEP_DROPBOX_AFTER_BTN_DOWN(index, class_name)
    local frame = ui.GetFrame("indunenter_select_step")
    local button_names = { 'weapon_btn', 'subweapon_btn', 'armor_btn', 'acc_btn', 'material_btn' }
    local image_names = { 'indun_weapon', 'indun_shield', 'indun_armour', 'indun_acc', 'indun_material' }
    for i = 1, #button_names do
        local button = GET_CHILD_RECURSIVELY(frame, button_names[i])
        button:SetImage(image_names[i])
        button:SetUserValue(button_names[i], 'NO')
    end
end

---- make - dropbox mouse over
function INDUNENTER_SELECT_STEP_DROPBOX_MOUSE_OVER(index, class_name)
    INDUNENTER_SELECT_STEP_SHOW_ITEM_TOOLTIP(index, class_name, false)
end

---- make - dropbox tooltip view
function INDUNENTER_SELECT_STEP_DROPBOX_TOOLTIP_VIEW(index, class_name)
    INDUNENTER_SELECT_STEP_SHOW_ITEM_TOOLTIP(index, class_name, true)
end

---- make - dropbox item tooltip
function INDUNENTER_SELECT_STEP_SHOW_ITEM_TOOLTIP(index, class_name, keep_visible)
    local frame = ui.GetFrame("indunenter_select_step")
    local item_frame = ui.GetFrame('wholeitem_link') or ui.GetNewToolTip('wholeitem_link', 'wholeitem_link')
    local item_object = CreateIES('Item', class_name)
    if item_object == nil then
        return
    end

    tolua.cast(item_frame, 'ui::CTooltipFrame')
    item_frame:SetTooltipType('wholeitem')
    item_frame:SetToolTipObject(tolua.cast(item_object, 'size_t'))
    item_frame:RefreshTooltip()
    item_frame:SetOffset(frame:GetX() + frame:GetWidth(), frame:GetY())
    item_frame:ShowWindow(1)
    item_frame:SetUserValue('MouseClickedCheck', keep_visible and 'YES' or 'NO')
    INDUNENTER_SELECT_STEP_DROPBOX_AFTER_BTN_DOWN(index, class_name)
end

---- make - dropbox mouse out
function INDUNENTER_SELECT_STEP_DROPBOX_MOUSE_OUT()
    local item_frame = ui.GetFrame('wholeitem_link') or ui.GetNewToolTip('wholeitem_link', 'wholeitem_link')
    if item_frame:GetUserValue('MouseClickedCheck') ~= 'YES' then
        item_frame:ShowWindow(0)
    else
        item_frame:SetUserValue('MouseClickedCheck', 'NO')
    end
end

---- make - smallmode pc
function INDUNENTER_SELECT_STEP_MAKE_SMALLMODE_PC(frame, pc_count, understaff_count)
    if frame == nil then
        return
    end

    local match_pc_gb = GET_CHILD_RECURSIVELY(frame, "match_pc_gb")
    local indun_cls = GetClassByType("Indun", frame:GetUserIValue("INDUN_TYPE"))
    if match_pc_gb == nil or indun_cls == nil then
        return
    end
    match_pc_gb:RemoveAllChild()

    local max_count = TryGetProp(indun_cls, "PlayerCnt", 0)
    local waiting_count = math.max(0, max_count - pc_count)
    local image = frame:GetUserConfig("YES_MATCH_SKIN")
    local index = 0
    for i = 1, pc_count do
        local ctrlset = match_pc_gb:CreateOrGetControlSet("smallIndunMember", "MAN_PICTURE_"..index, 0, 0)
        if ctrlset ~= nil then
            local picture = ctrlset:GetChild("pcImg")
            if picture ~= nil then
                AUTO_CAST(picture)
                picture:SetEnableStretch(1)
                picture:SetImage(image)
            end
    
            local understaff_picture = ctrlset:GetChild("understaffAllowImg")
            if understaff_picture ~= nil then
                understaff_picture:ShowWindow(BoolToNumber(i <= understaff_count))
            end
            index = index + 1
        end
    end

    for i = 1, waiting_count do
        local ctrlset = match_pc_gb:CreateOrGetControlSet("smallIndunMember", "MAN_PICTURE_"..index, 0, 0)
        if ctrlset ~= nil then
            local picture = ctrlset:GetChild("pcImg")
            if picture ~= nil then
                AUTO_CAST(picture)
                picture:SetEnableStretch(1)
                picture:SetImage(image)
                picture:SetColorTone("FF222222")
            end

            local understaff_picture = ctrlset:GetChild("understaffAllowImg")
            if understaff_picture ~= nil then
                understaff_picture:ShowWindow(0)
            end
            index = index + 1
        end
    end
    GBOX_AUTO_ALIGN_HORZ(match_pc_gb, 0, 0, 0, true, true)
end

-- callback
---- callback - pc count
function INDUNENTER_SELECT_STEP_UPDATE_PC_COUNT(frame, msg, info_str, pc_count, understaff_count)
    if frame == nil then
        frame = ui.GetFrame("indunenter_select_step")
    end

    if info_str == nil then
        info_str = "None"
    end
    
    local member_info = frame:GetUserValue("MEMBER_INFO")
    if info_str ~= 'None' then
        member_info = info_str
        frame:SetUserValue("MEMBER_INFO", member_info)
    end

    local current_pc_count = tonumber(pc_count) or 0
    local current_understaff_count = tonumber(understaff_count) or 0
    local member_table = StringSplit(member_info, "/")
    INDUNENTER_SELECT_STEP_MAKE_PARTY_CTRLSET(frame, current_pc_count, member_table, current_understaff_count)
    INDUNENTER_SELECT_STEP_MAKE_SMALLMODE_PC(frame, current_pc_count, current_understaff_count)
    INDUNENTER_SELECT_STEP_SET_MEMBER_COUNT_BOX(frame)
end

---- callback - pc count : make party ctrlset
function INDUNENTER_SELECT_STEP_MAKE_PARTY_CTRLSET(frame, pc_count, member_table, understaff_count)
    local member_box = GET_CHILD_RECURSIVELY(frame, "member_box")
    local party_line = GET_CHILD_RECURSIVELY(frame, "party_line")
    local member_count_text = GET_CHILD_RECURSIVELY(frame, "member_cnt_text")
    if member_box == nil or party_line == nil or member_count_text == nil then
        return
    end
    
    local indun_cls = GetClassByType("Indun", frame:GetUserIValue("INDUN_TYPE"))
    if indun_cls == nil then
        return
    end

    local max_count = TryGetProp(indun_cls, "PlayerCnt", 5)
    local member_count = math.floor(#member_table / INDUNENTER_SELECT_STEP_PC_INFO_COUNT)
    if pc_count < 1 then
        member_count = 0
    end

    local previous_pc_count = frame:GetUserIValue("UI_PC_COUNT")
    frame:SetUserValue("UI_PC_COUNT", pc_count)
    if previous_pc_count < pc_count then
        imcSound.PlaySoundEvent(frame:GetUserConfig("MEMBER_FINDED_SOUND"))
    end

    local previous_understaff_count = frame:GetUserIValue("UI_UNDERSTAFF_COUNT")
    frame:SetUserValue("UI_UNDERSTAFF_COUNT", understaff_count)
    if previous_understaff_count < understaff_count then
        imcSound.PlaySoundEvent(frame:GetUserConfig("UNDERSTAFF_CHECK_SOUND"))
    end

    party_line:ShowWindow(BoolToNumber(member_count > 1))
    if member_count > 1 then
        party_line:Resize(58 * (member_count - 1), 15)
    end
    DESTROY_CHILD_BYNAME(member_box, "MEMBER_")

    local understaff_show_count = 0
    for i = 1, max_count do
        local member_ctrl = member_box:CreateOrGetControlSet("indunMember", "MEMBER_"..i, 10 * i + 47 * (i - 1), 0)
        if member_ctrl ~= nil then
            member_ctrl:ShowWindow(1)

            local leader_image = member_ctrl:GetChild("leader_img")
            leader_image:ShowWindow(0)
            
            local level_text = member_ctrl:GetChild("level_text")
            level_text:ShowWindow(0)
            
            local job_icon = GET_CHILD_RECURSIVELY(member_ctrl, "jobportrait")
            job_icon:SetImage(frame:GetUserConfig("NO_MATCH_SKIN"))
            
            local matched_icon = GET_CHILD_RECURSIVELY(member_ctrl, "matchedIcon")
            matched_icon:ShowWindow(0)
            
            local understaff_image = member_ctrl:GetChild("understaffAllowImg")
            understaff_image:ShowWindow(0)
    
            if i <= pc_count then
                local base_index = (i - 1) * INDUNENTER_SELECT_STEP_PC_INFO_COUNT
                if base_index + INDUNENTER_SELECT_STEP_PC_INFO_COUNT <= #member_table then
                    local aid = member_table[base_index + 1]
                    local job_id = tonumber(member_table[base_index + 2])
                    local level = member_table[base_index + 3]
                    local cid = member_table[base_index + 4]
                    local understaff = member_table[base_index + 5]
                    local party_info = session.party.GetPartyInfo(PARTY_NORMAL)
                    if party_info ~= nil and party_info.info:GetLeaderAID() == aid then
                        leader_image:ShowWindow(1)
                    end

                    local job_cls = GetClassByType("Job", job_id)
                    if job_cls ~= nil then
                        job_icon:SetImage(job_cls.Icon)
                        PARTY_JOB_TOOLTIP_BY_CID(cid, job_icon, job_cls)
                    end

                    level_text:SetText(level)
                    level_text:ShowWindow(1)

                    if understaff == "YES" then
                        understaff_image:ShowWindow(1)
                        understaff_show_count = understaff_show_count + 1
                    end
                else
                    job_icon:ShowWindow(0)
                    matched_icon:ShowWindow(1)
                    if understaff_show_count < understaff_count then
                        understaff_image:ShowWindow(1)
                        understaff_show_count = understaff_show_count + 1
                    end
                end
            end
        end
    end
    member_count_text:SetTextByKey("cnt", pc_count..ClMsg("PersonCountUnit"))
end

-- automatch
---- automatch party set count
function INDUNENTER_SELECT_STEP_AUTOMATCH_PARTY_SET_COUNT(member_count, member_info, understaff_count)
    local frame = ui.GetFrame("indunenter_select_step")
    if frame ~= nil then
        INDUNENTER_SELECT_STEP_UPDATE_PC_COUNT(frame, nil, member_info, member_count, understaff_count)
    end
end

---- automatch finded
function INDUNENTER_SELECT_STEP_AUTOMATCH_FINDED()
    local frame = ui.GetFrame("indunenter_select_step")
    if frame == nil or frame:IsVisible() ~= 1 then
        return
    end

    if frame:GetUserValue("AUTOMATCH_MODE") ~= "YES" then
        return
    end
    frame:SetUserValue("AUTOMATCH_FIND", "YES")

    local cancel_btn = GET_CHILD_RECURSIVELY(frame, "cancel_auto_match")
    local automatch_text = GET_CHILD_RECURSIVELY(frame, "automatch_text")
    local automatch_time = GET_CHILD_RECURSIVELY(frame, "automatch_time")
    local indun_name_text = GET_CHILD_RECURSIVELY(frame, "indun_name_text")
    if cancel_btn ~= nil then
        cancel_btn:SetEnable(0)
    end

    if indun_name_text ~= nil then
        indun_name_text:SetText(ClMsg("AutoMatchComplete"))
    end

    if automatch_text ~= nil then
        automatch_text:SetText(ClMsg("PILGRIM41_1_SQ07_WATER"))
        automatch_text:ShowWindow(1)
    end

    if automatch_time ~= nil then
        automatch_time:ShowWindow(0)
    end

    INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "enter_right_btn", 1, 0)
    INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "automatch_btn", 1, 0)
    INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "with_btn", 1, 0)
    INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "reenter_btn", 0, 0)
    INDUNENTER_SELECT_STEP_SET_CONTROL_STATE(frame, "understaff_enter_allow_btn", 1, 0)
    INDUNENTER_SELECT_STEP_MAKE_SMALLMODE(frame, true)
    INDUNENTER_SELECT_STEP_AUTOMATCH_FIND_TIMER_START(frame)
    imcSound.PlaySoundEvent(frame:GetUserConfig("MATCH_FINDED_SOUND"))
    app.SetWindowTopMost()
end

---- automatch find - timer start
function INDUNENTER_SELECT_STEP_AUTOMATCH_FIND_TIMER_START(frame)
    local gauge = GET_CHILD_RECURSIVELY(frame, "match_success_gauge")
    if gauge == nil then
        return
    end
    gauge:SetPoint(5, 5)
    frame:SetUserValue("FIND_START_TIME", os.time())
    frame:RunUpdateScript("INDUNENTER_SELECT_STEP_AUTOMATCH_FIND_TIME_UPDATE", 0.1)
    INDUNENTER_SELECT_STEP_AUTOMATCH_FIND_TIME_UPDATE(frame)
end

---- automatch find - timer update
function INDUNENTER_SELECT_STEP_AUTOMATCH_FIND_TIME_UPDATE(frame)
    local elapsed_sec = os.time() - frame:GetUserIValue("FIND_START_TIME")
    local gauge = GET_CHILD_RECURSIVELY(frame, "match_success_gauge")
    if gauge == nil then
        return 0
    end
    gauge:SetPointWithTime(0, math.max(0, 5 - elapsed_sec))
    if elapsed_sec >= 5 then
        return 0
    end
    return 1
end

---- automatch set member count
function INDUNENTER_SELECT_STEP_SET_MEMBER_COUNT_BOX(frame)
    if frame == nil then
        return
    end

    local member_count_box = GET_CHILD_RECURSIVELY(frame, "member_cnt_box")
    local member_count_text = GET_CHILD_RECURSIVELY(frame, "member_cnt_text")
    local party_ask_text = GET_CHILD_RECURSIVELY(frame, "party_ask_text")
    if member_count_box == nil or member_count_text == nil or party_ask_text == nil then
        return
    end

    if frame:GetUserValue("WITHMATCH_MODE") == "YES" then
        member_count_text:ShowWindow(0)
        party_ask_text:ShowWindow(1)
        member_count_box:ShowWindow(1)
    elseif frame:GetUserValue("AUTOMATCH_MODE") == "YES" then
        member_count_text:ShowWindow(1)
        party_ask_text:ShowWindow(0)
        member_count_box:ShowWindow(1)
    else
        member_count_box:ShowWindow(0)
    end
end

---- automatch callback
function INDUNENTER_SELECT_STEP_AUTOMATCH_TYPE(indun_type, need_understaff_allow)
    local frame = ui.GetFrame("indunenter_select_step")
    if frame == nil or frame:IsVisible() ~= 1 then
        return
    end
    need_understaff_allow = tonumber(need_understaff_allow) or 1

    if indun_type == 0 then
        frame:SetUserValue("AUTOMATCH_FIND", "NO")
        INDUNENTER_SELECT_STEP_REFRESH_AUTOMATCH_MODE(0)
        INDUNENTER_SELECT_STEP_UPDATE_PC_COUNT(frame, nil, "None", 0, 0)
        INDUNENTER_SELECT_STEP_UNDERSTAFF_BTN_ENABLE(frame, 0)

        local cancel_btn = GET_CHILD_RECURSIVELY(frame, "cancel_auto_match")
        if cancel_btn ~= nil then
            cancel_btn:SetEnable(1)
        end

        if frame:GetUserValue("FRAME_MODE") == "SMALL" then
            INDUNENTER_SELECT_STEP_RESET_BIG_MODE(frame)
        end
    elseif frame:GetUserValue("AUTOMATCH_MODE") ~= "YES" then
        local indun_cls = GetClassByType("Indun", indun_type)
        if indun_cls ~= nil
            and TryGetProp(indun_cls, "EnableUnderStaffEnter", "None") ~= "YES" then
            need_understaff_allow = 0
        end

        INDUNENTER_SELECT_STEP_REFRESH_AUTOMATCH_MODE(1)
        INDUNENTER_SELECT_STEP_UNDERSTAFF_BTN_ENABLE(frame, need_understaff_allow)
        INDUNENTER_SELECT_STEP_MAKE_SMALLMODE(frame, false)
        INDUNENTER_SELECT_STEP_MAKE_SMALLMODE_PC(frame, 1, 0)
        INDUNENTER_SELECT_STEP_AUTOMATCH_TIMER_START(frame)

        local cancel_btn = GET_CHILD_RECURSIVELY(frame, "cancel_auto_match")
        if cancel_btn ~= nil then
            cancel_btn:SetEnable(1)
        end
    end
    INDUNENTER_SELECT_STEP_SET_MEMBER_COUNT_BOX(frame)
end

---- automatch party callback
function INDUNENTER_SELECT_STEP_AUTOMATCH_PARTY(num_waiting, level, limit, indun_level, indun_name)
    local frame = ui.GetFrame("indunenter_select_step")
    if frame == nil or frame:IsVisible() ~= 1 then
        return
    end
    frame:SetUserValue("PARTYMATCH_REQUEST_PENDING", "NO")

    local with_btn = GET_CHILD_RECURSIVELY(frame, "with_btn")
    local party_ask_text = GET_CHILD_RECURSIVELY(frame, "party_ask_text")
    if num_waiting == 0 then
        INDUNENTER_SELECT_STEP_REFRESH_PARTYMATCH_MODE(0)
        INDUNENTER_SELECT_STEP_UNDERSTAFF_BTN_ENABLE(frame, 0)

        if with_btn ~= nil then
            with_btn:SetTextTooltip(ClMsg("PartyMatchInfo_Req"))
        end
    else
        local lower_bound = math.max(indun_level, level - limit)
        local upper_bound = math.min(PC_MAX_LEVEL, level + limit)
        if party_ask_text ~= nil then
            local text = ScpArgMsg("MatchWithParty").."(Lv."..tostring(lower_bound).."~"..tostring(upper_bound)..")"
            party_ask_text:SetTextByKey("value", text)
        end

        INDUNENTER_SELECT_STEP_REFRESH_PARTYMATCH_MODE(1)
        INDUNENTER_SELECT_STEP_UNDERSTAFF_BTN_ENABLE(frame, 1)

        if with_btn ~= nil then
            with_btn:SetTextTooltip(ClMsg("PartyMatchInfo_Go"))
        end
    end
    INDUNENTER_SELECT_STEP_SET_MEMBER_COUNT_BOX(frame)
end

---- automatch party fail start
function INDUNENTER_SELECT_STEP_FAIL_START_PARTY_MATCHING(frame, msg, arg_str, arg_num)
    local top_frame = ui.GetFrame("indunenter_select_step")
    if top_frame == nil then
        return
    end
    top_frame:SetUserValue("PARTYMATCH_REQUEST_PENDING", "NO")

    local with_btn = GET_CHILD_RECURSIVELY(top_frame, "with_btn")
    if with_btn ~= nil then
        with_btn:SetTextTooltip(ClMsg("PartyMatchInfo_Req"))
    end
    INDUNENTER_SELECT_STEP_REFRESH_ENTER_BUTTON_STATE(top_frame)
end

---- automatch party fail register
function INDUNENTER_SELECT_STEP_FAIL_REGISTER_PARTY_MATCHING(frame, msg, arg_str, arg_num)
    local top_frame = ui.GetFrame("indunenter_select_step")
    if top_frame == nil then
        return
    end
    top_frame:SetUserValue("PARTYMATCH_REQUEST_PENDING", "NO")

    local with_btn = GET_CHILD_RECURSIVELY(top_frame, "with_btn")
    if with_btn ~= nil then
        with_btn:SetTextTooltip(ClMsg("PartyMatchInfo_Go"))
    end
    INDUNENTER_SELECT_STEP_REFRESH_ENTER_BUTTON_STATE(top_frame)
end

-- small mode
---- small mode - make
function INDUNENTER_SELECT_STEP_MAKE_SMALLMODE(frame, is_success)
    if frame == nil then
        return
    end

    local auto_match_gb = GET_CHILD_RECURSIVELY(frame, "auto_match_gb")
    local match_success_gb = GET_CHILD_RECURSIVELY(frame, "match_success_gb")
    if auto_match_gb == nil or match_success_gb == nil then
        return
    end
    auto_match_gb:ShowWindow(BoolToNumber(is_success ~= true))
    match_success_gb:ShowWindow(BoolToNumber(is_success == true))
end

---- small mode - automatch time start
function INDUNENTER_SELECT_STEP_AUTOMATCH_TIMER_START(frame)
    if frame == nil then
        return
    end
    frame:SetUserValue("AUTOMATCH_FIND", "NO")
    frame:SetUserValue("START_TIME", os.time())

    local automatch_time = GET_CHILD_RECURSIVELY(frame, "automatch_time")
    if automatch_time ~= nil then
        automatch_time:ShowWindow(1)
    end
    frame:RunUpdateScript("INDUNENTER_SELECT_STEP_AUTOMATCH_TIME_UPDATE", 0.5)
    INDUNENTER_SELECT_STEP_AUTOMATCH_TIME_UPDATE(frame)
end

---- small mode - automatch time update
function INDUNENTER_SELECT_STEP_AUTOMATCH_TIME_UPDATE(frame)
    if frame == nil then
        return 0
    end

    local elapsed_sec = os.time() - frame:GetUserIValue("START_TIME")
    local text = string.format("%02d:%02d", math.floor(elapsed_sec / 60), elapsed_sec % 60)
    local automatch_time = GET_CHILD_RECURSIVELY(frame, "automatch_time")
    local match_time = GET_CHILD_RECURSIVELY(frame, "match_time")
    if automatch_time ~= nil then
        automatch_time:SetText(text)
    end

    if match_time ~= nil then
        match_time:SetText(text)
    end

    if frame:GetUserValue("AUTOMATCH_MODE") == "NO" or frame:GetUserValue("AUTOMATCH_FIND") == "YES" then
        if automatch_time ~= nil then
            automatch_time:ShowWindow(0)
        end
        return 0
    end
    return 1
end

---- on small mode
function ON_INDUNENTER_SELECT_STEP_SMALL(frame, ctrl, force_small)
    if frame == nil then
        return
    end

    local top_frame = frame:GetTopParentFrame()
    if top_frame == nil then
        return
    end

    local main_gb = GET_CHILD_RECURSIVELY(top_frame, "main_gb")
    local main_small_gb = GET_CHILD_RECURSIVELY(top_frame, "main_small_gb")
    local header_gb = GET_CHILD_RECURSIVELY(top_frame, "header_gb")
    local small_header_gb = GET_CHILD_RECURSIVELY(top_frame, "small_header_gb")
    if main_gb == nil or main_small_gb == nil or header_gb == nil or small_header_gb == nil then
        return
    end

    if force_small == true and top_frame:GetUserValue("FRAME_MODE") == "SMALL" then
        return
    end

    if top_frame:GetUserValue("FRAME_MODE") == "BIG" then
        if top_frame:GetUserValue("AUTOMATCH_MODE") == "NO" then
            ui.SysMsg(ScpArgMsg("EnableWhenAutoMatching"))
            return
        end
        main_gb:ShowWindow(0)
        main_gb:SetEnable(0)
        main_small_gb:ShowWindow(1)
        main_small_gb:SetEnable(1)

        header_gb:ShowWindow(0)
        small_header_gb:ShowWindow(1)
        small_header_gb:SetEnable(1)

        top_frame:SetUserValue("FRAME_MODE", "SMALL")
        top_frame:Resize(main_small_gb:GetWidth(), main_small_gb:GetHeight())
    else
        main_gb:ShowWindow(1)
        main_gb:SetEnable(1)
        main_small_gb:ShowWindow(0)
        main_small_gb:SetEnable(0)

        header_gb:ShowWindow(1)
        header_gb:SetEnable(1)
        
        top_frame:SetUserValue("FRAME_MODE", "BIG")
        top_frame:Resize(main_gb:GetWidth(), main_gb:GetHeight())
    end
end

---- on automatch cancel - small mode
function ON_INDUNENTER_SELECT_STEP_SMALL_AUTOMATCH_CANCEL(frame, ctrl)
    local top_frame = ui.GetFrame("indunenter_select_step")
    if top_frame == nil then
        return
    end

     if top_frame:GetUserValue("AUTOMATCH_MODE") ~= "YES" then
        return
    end
    packet.SendCancelIndunMatching()
end

---- return big mode
function INDUNENTER_SELECT_STEP_RESET_BIG_MODE(frame)
    if frame == nil then
        return
    end

    local main_gb = GET_CHILD_RECURSIVELY(frame, "main_gb")
    local main_small_gb = GET_CHILD_RECURSIVELY(frame, "main_small_gb")
    local header_gb = GET_CHILD_RECURSIVELY(frame, "header_gb")
    local small_header_gb = GET_CHILD_RECURSIVELY(frame, "small_header_gb")

    frame:SetUserValue("FRAME_MODE", "BIG")
    frame:SetUserValue("AUTOMATCH_FIND", "NO")

    if main_gb ~= nil then
        main_gb:ShowWindow(1)
        main_gb:SetEnable(1)
        frame:Resize(main_gb:GetWidth(), main_gb:GetHeight())
    end

    if main_small_gb ~= nil then
        main_small_gb:ShowWindow(0)
        main_small_gb:SetEnable(0)
    end

    if header_gb ~= nil then
        header_gb:ShowWindow(1)
        header_gb:SetEnable(1)
    end

    if small_header_gb ~= nil then
        small_header_gb:ShowWindow(0)
        small_header_gb:SetEnable(0)
    end
    INDUNENTER_SELECT_STEP_MAKE_SMALLMODE(frame, false)

    local cancel_btn = GET_CHILD_RECURSIVELY(frame, "cancel_auto_match")
    if cancel_btn ~= nil then
        cancel_btn:SetEnable(1)
    end
end

-- step select
---- on step select
function INDUNENTER_SELECT_STEP_SELECT(parent, ctrl, arg_str, arg_num)
    if parent == nil then
        return
    end

    local frame = parent:GetTopParentFrame()
    if frame == nil then
        return
    end

    local selected_step = tonumber(arg_num)
    if selected_step == nil then
        return
    end

    local step_info = GetStepInfo(frame, selected_step)
    if step_info == nil then
        return
    end

    if IsUnlockedStep(frame, selected_step) == false then
        ui.SysMsg(ScpArgMsg("IndunInfoSelectStepLock"))
        return
    end
    frame:SetUserValue("SELECTED_STEP", selected_step)
    INDUNENTER_SELECT_STEP_REFRESH_STEP_BUTTONS(frame)
    INDUNENTER_SELECT_STEP_REFRESH_STEP_INFO(frame)
end

---- on step select - update btn
function INDUNENTER_SELECT_STEP_REFRESH_STEP_BUTTONS(frame)
    if frame == nil then
        return
    end

    local selected_step = frame:GetUserIValue("SELECTED_STEP")
    local step_list = GetStepList(frame)
    for i = 1, #step_list do
        local info = step_list[i]
        if info ~= nil then
            local ctrlset = GET_CHILD_RECURSIVELY(frame, "STEP_"..tostring(info.step))
            if ctrlset ~= nil then
                local is_unlocked = IsUnlockedStep(frame, info.step)
                local btn = GET_CHILD_RECURSIVELY(ctrlset, "step_btn")
                if btn ~= nil then
                    local skin_name = shared_indun_step.get_step_btn_skin(is_unlocked, info.step, selected_step)
                    local text = shared_indun_step.get_step_btn_text(is_unlocked, info.step, selected_step)
                    if skin_name ~= "" and text ~= "" then
                        btn:SetSkinName(skin_name)
                        btn:SetText(text)
                    end
                    btn:SetEnable(1)
                end

                local lock = GET_CHILD_RECURSIVELY(ctrlset, "step_lock")
                if lock ~= nil then
                    lock:ShowWindow(BoolToNumber(is_unlocked == false))
                end
            end
        end
    end
end

----- on step select - update step info
function INDUNENTER_SELECT_STEP_REFRESH_STEP_INFO(frame)
    if frame == nil then
        return
    end

    local step_gb = GET_CHILD_RECURSIVELY(frame, "step_info_gb")
    local selected_step = frame:GetUserIValue("SELECTED_STEP")
    local step_info = GetStepInfo(frame, selected_step)
    if step_gb ~= nil then
        if step_info == nil then
            step_gb:ShowWindow(0)
            return
        else
            step_gb:ShowWindow(1)
        end
    end
    
    local selected_step_text = GET_CHILD_RECURSIVELY(frame, "step_selected_text")
    if selected_step_text ~= nil then
        selected_step_text:SetTextByKey("step", step_info.step)
    end
    
    local gear_score = GET_COMMAED_STRING(tostring(step_info.gear_score))
    local gear_score_text = GET_CHILD_RECURSIVELY(frame, "gear_score_text")
    if gear_score_text ~= nil then
        gear_score_text:SetTextByKey("gearscore", gear_score)
    end

    local reward_bonus_text = GET_CHILD_RECURSIVELY(frame, "reward_bonus_text")
    if reward_bonus_text ~= nil then
        reward_bonus_text:SetTextByKey("ratio", step_info.reward_bonus)
    end
end

----- on step select - req move to indun selectstep
function INDUNENTER_SELECT_STEP_REQ_MOVE_TO_INDUN(join_method, multiple_count)
    local frame = ui.GetFrame("indunenter_select_step")
    if frame == nil then
        return
    end
    
    local selected_step = GetRequestStep(frame, join_method)
    if selected_step == nil then
        return
    end
    ReqMoveToIndunSelectStep(join_method, multiple_count, selected_step)
end
