Cupole_List = {}

local filter_type = "";
local filterconst = {
    ["UR"] = 3,
    ["SR"] = 2,
    ["R"]= 1
}
local stat_sort_value={
    ["PATK_BM"] = 1,
    ["MATK_BM"] = 2,
    ["DEF_BM"] = 3,
    ["MDEF_BM"] = 4,
    ["CRTDR_BM"] = 5,
    ["CRTHR_BM"] = 6,
    ["MiddleSize_Atk_BM"] = 7,
    ["MiddleSize_Def_BM"] = 8
}

local CUPOLE_PRESET_MAX_COUNT = 5;
local CUPOLE_PRESET_PROP_PREFIX = "CupolePreset";

------------------------------------get function
function GET_CUPOLE_INDEX(ownerHandle, ui_model, isMainCharacter)
    local val = GetCupoleRTTOffsetIndex(ownerHandle, ui_model)
    if val < 0 then
        REMOVE_ALL_CUPOLE_UIMODEL()
        ownerHandle, ui_model = CREATE_CUPOLE_UIMODEL(index, isMainCharacter)
        val = GetCupoleRTTOffsetIndex(ownerHandle, ui_model)     
    end
    return val;
end

function GET_KUPOLE_INDEX_BY_CLASSNAME(className)
    local cupole_list, cnt = GetClassList("cupole_list");
    local cls = GetClassByNameFromList(cupole_list, className)
    local id = TryGetProp(cls,"ClassID", 0)
    return id - 1;
end

function GET_KUPOLE_CLS_BY_CLASSNAME(className)
    local cupole_list, cnt = GetClassList("cupole_list");
    local cls = GetClassByNameFromList(cupole_list, className)
    return cls;
end


---Get current Select Cupole Index
function GET_GLOBAL_SELECT_CUPOLE(mainFrame)
    if mainFrame == nil then
        mainFrame = ui.GetFrame("cupole_item")
    end
    mainFrame = ui.GetFrame("cupole_item")
    local selc_cupole = mainFrame:GetUserIValue("Global_Select_Cupole");
    return selc_cupole;
end

---Get current Select Cupole Index
function GET_GLOBAL_SELECT_CUPOLE_ACCOUNTPROP(mainFrame)
    local cupole_index = GET_GLOBAL_SELECT_CUPOLE(mainFrame);
    local cupole_cls = GET_CUPOLE_CLASS_BY_INDEX(cupole_index)
    if cupole_cls == nil then
        return "None";
    end
    local AccProp = TryGetProp(cupole_cls, "AccountProperty" , "None")
    return AccProp;
end

--get cupole current rank
function GET_CUPOLE_RANK(pc, index)
    local pc = GetMyPCObject();
    if pc == nil then
        return 0;
    end
    local acc = GetMyAccountObj(pc);
    if acc == nil then
        return 0;
    end
    local cls = GET_CUPOLE_CLASS_BY_INDEX(index)
    local AccProp = TryGetProp(cls, "AccountProperty" , "None")
    local rank = TryGetProp(acc, AccProp, 0)
    return rank;
end

--- 현재 장착한 큐폴의 값들을 가져온다.
function GET_EQUIP_CUPOLE_LIST()
    local etc = GetMyEtcObject();
    local equipstr = TryGetProp(etc, 'Cupole_Equip', "0;0;0");
    local equip_list = StringSplit(equipstr, ';')

    for k,v in pairs(equip_list) do
        if v == nil or v == "nil" then
            equip_list[k] = -1
        end
    end

    local slot_list = {equip_list[1],equip_list[2],equip_list[3]};
    return slot_list;
end

---정렬 된 큐폴 리스트에서 큐폴 오브젝트의 클래스를 받아오는 함수. 
function GET_SELECT_CUPOLE_CLS(index)
    local table = Cupole_List[index + 1];
    if table == nil then
        return nil;
    end
    local cls = table[3]
    return cls;
end

--큐폴 리스트를 옵션에 따라 sort한다.
function GET_CUPOLE_SORT_TYPE_FUNCTION(option)
    local Cupole_Filter = ui.GetFrame("cupole_filter");
    local Owing = Cupole_Filter:GetUserIValue("Owing");
    
    local cupole_list, cnt = GetClassList("cupole_list");
    if option == "Friendly" then
        Cupole_List = SortTableByLevel(cupole_list, cnt, Owing)
    elseif option == "Grade" then
        Cupole_List = SortTableByPropertyName(cupole_list, cnt, "Grade", Owing)
    else
        Cupole_List = SortTableByPropertyName(cupole_list, cnt, "Grade", Owing)
    end
    return Cupole_List;
end

---index로 큐폴 값을 가져오는 함수.
function GET_CUPOLE_BY_INDEX_IN_CLASSLIST(cupole_index)
    if cupole_index == nil or cupole_index == "None" or cupole_index == "nil" then
        return nil;
    end
    index = tonumber(cupole_index);
    local cupole_list, cnt = GetClassList("cupole_list");
    if index > tonumber(cnt) then
        return nil;
    end
    local cls = GetClassByIndexFromList(cupole_list,index);
    
    return cls
end

---index로 해당 큐폴의 이름을 가져오는 함수.
function GET_CUPOLE_NAME_BY_INDEX(index)
    local cupole_info = GET_CUPOLE_BY_INDEX_IN_CLASSLIST(index);
    if cupole_info == nil then
        return;
    end

    local ClsName = TryGetProp(cupole_info,"ClassName","None");

    return ClsName;
end

---index로 원하는 큐폴의 설정 가져오기
function GET_CUPOLE_PROP_BY_INDEX(index, Prop)
    local cupole_info = GET_CUPOLE_BY_INDEX_IN_CLASSLIST(index);
    if cupole_info == nil then
        return;
    end

    local Value = TryGetProp(cupole_info, Prop);
    return Value;
end

function GET_CUPOLE_CLS_BY_TYPE(id)
    local cls = GetClassByType("cupole_list", id);
    return cls;
end
----좀 더 유틸리티에 관련 됨

--큐폴의 스탯 텍스트를 설정함.
function GET_CUPOLE_STAT_TEXT(Stat, UpgradeValue)
    if Stat == nil or UpgradeValue == nil then
        return "";
    end

    local StatText = ClMsg(Stat)
    local StatInfoStr = string.format("%s + {#ffcc33}%d{/}", StatText, UpgradeValue)    

    return StatInfoStr;
end

---오픈시에 초기에 출현할 큐폴의 index정보를 가져온다.
function GET_CHOOSE_INIT_CUPOLE(equip_cupole_list) 
    local state = "left"
    for k,v in pairs(equip_cupole_list) do
        if tonumber(v) ~= -1 and v ~= nil and v ~= "nil" then
            return state, v, k;
        end
    end
    state = "right"
    local index = SEARCH_EQUIP_CUPOLE_INDEX(1) - 1;
    return state, index, 0;
end
----정렬된 (우측 슬롯셋) 리스트에서 index로 원하는 큐폴 가져오는 것.
function SEARCH_EQUIP_CUPOLE_INDEX(index)
    GET_CUPOLE_SORT_TYPE_FUNCTION(filter_type)
    local clsId = TryGetProp(Cupole_List[index][3], "ClassID", -1);
    return clsId;
end

------------------sort 관련 함수
function SortTableByPropertyName(classlist, count, propName, Owing)
    local pc = GetMyPCObject();
    if pc == nil then
        return 0;
    end
    local acc = GetMyAccountObj(pc);
    if acc == nil then
        return 0;
    end

    local clsList = {};
    for i = 0, count - 1 do
        local cls = GetClassByIndexFromList(classlist, i);
        local favorite = BoolToNumber(IsFavoriteCupole(i));
        local SortName = nil;
        if propName ~= nil then
            SortName = TryGetProp(cls, propName, "None");    
        end
        if cls ~= nil then
            local Use = TryGetProp(cls, "Use", "false");   
            if Use == "true" then
                if SortName ~= nil or SortName ~= "None" then
                    if Owing == 1 then
                        local accprop = TryGetProp(cls, "AccountProperty", 0);   
                        local CupoleExpProp = TryGetProp(acc, accprop, 0);
                        if CupoleExpProp > 0 then
                            table.insert(clsList,{favorite, SortName, cls});
                        end
                    else
                        table.insert(clsList,{favorite, SortName, cls});
                    end
                end
            end
        end
    end
    --befor sort
    table.sort(clsList, CupoleTableSort);

    return clsList;
end

function SortTableByLevel(classlist, count, Owing)
    local pc = GetMyPCObject();
    if pc == nil then
        return 0;
    end
    local acc = GetMyAccountObj(pc);
    if acc == nil then
        return 0;
    end

    local clsList = {};
    for i = 0, count - 1 do
        local cls = GetClassByIndexFromList(classlist, i);
        local favorite = BoolToNumber(IsFavoriteCupole(i));

        if cls ~= nil then
            local accprop = TryGetProp(cls, "AccountProperty", 0);   
            local CupoleExpProp = TryGetProp(acc, accprop, 0);    
            local Use = TryGetProp(cls, "Use", "false");   
            if Use == "true" then
                if SortName ~= nil or SortName ~= "None" then
                    if Owing == 1 then
                        if CupoleExpProp > 0 then
                            table.insert(clsList,{favorite, CupoleExpProp, cls});
                    end
                    else
                        table.insert(clsList,{favorite, CupoleExpProp, cls});
                    end
                end
            end
        end
    end
    --befor sort
    table.sort(clsList, CupoleTableSort);

    return clsList;
end

function CupoleTableSort(left, right)
    if left[1] ~= right[1] then
        return left[1] >= right[1]
    end

    local leftcls = left[3];
    local rightcls = right[3];
    local leftGrade = TryGetProp(leftcls, "Grade", "R");
    local rightGrade = TryGetProp(rightcls, "Grade", "R");
    local leftGradeValue = filterconst[leftGrade]
    local rightGradeValue = filterconst[rightGrade]

    if leftGradeValue == rightGradeValue then
        return left[2] > right[2];
    end
    return leftGradeValue > rightGradeValue    
end
-------------------------------------------


-------------------------------------------set

----좌측의 팀편성 큐폴 슬롯을 만드는 함수
function SET_CUPOLE_SLOTS(frame)
    local bg = GET_CHILD_RECURSIVELY_NAME(frame,"managerTab/manageBG/bg")
    if bg == nil then
        return;
    end

    GET_CUPOLE_SORT_TYPE_FUNCTION(filter_type)

    local equip_cupole_list = GET_EQUIP_CUPOLE_LIST()

    if equip_cupole_list == nil then
        return;
    end

    local SlotBG = GET_CHILD(bg, "SlotBG")
    local gb_slot = GET_CHILD(SlotBG, "gb_slot")
    

    local cupole_slot_box = gb_slot:CreateOrGetControlSet('cupole_slot', "Main_Cupole_Slot_0", 0, 16);
    cupole_slot_box:SetGravity(ui.CENTER_HORZ, ui.CENTER_VERT)
    local slot_gb = cupole_slot_box:GetChild("gb")
    slot_gb:SetEventScript(ui.LBUTTONUP,"CUPOLE_SLOT_SELECT_BTN")
    cupole_slot_box:SetUserValue("SlotIndex",0);
    cupole_slot_box:SetUserValue("SEL_CUPOLE_INDEX", -1)
    slot_gb:SetEventScript(ui.RBUTTONUP,"RBTN_CUPOLE_ITEM_PROGRESS")
    slot_gb:SetEventScriptArgString(ui.RBUTTONUP,"Main_Cupole_Slot_0")

    -- SUMMON_SELECT_LEFT_CUPOLE_SLOT(cupole_slot_box, tonumber(equip_cupole_list[1]))
    SET_SLOT_CUPOLE_INFO(cupole_slot_box, tonumber(equip_cupole_list[1]))

    local MiniCnt = 2;
    local ctrler = 1;
    local defx = 12;
    local X = 94;
    local Y = 15;
    local cnt = 1;
    for i = 1, MiniCnt do 
        local mini_cupole_slot_box = gb_slot:CreateOrGetControlSet('cupole_mini_slot', "Main_Cupole_Slot_"..i, X * ctrler * cnt + defx * ctrler, Y);
        mini_cupole_slot_box:SetGravity(ui.CENTER_HORZ, ui.CENTER_VERT)
        mini_cupole_slot_box:SetUserValue("SEL_CUPOLE_INDEX", -1)
        if i % 2 == 0 then
            cnt = cnt + 1;
        end
        ctrler = ctrler * -1;
        local gb = mini_cupole_slot_box:GetChild("gb")
        gb:SetEventScript(ui.LBUTTONUP,"CUPOLE_SLOT_SELECT_BTN")
        mini_cupole_slot_box:SetUserValue("SlotIndex", i);
        gb:SetEventScript(ui.RBUTTONUP,"RBTN_CUPOLE_ITEM_PROGRESS")
        gb:SetEventScriptArgString(ui.RBUTTONUP, "Main_Cupole_Slot_"..i)
        -- SUMMON_SELECT_LEFT_CUPOLE_SLOT(mini_cupole_slot_box, tonumber(equip_cupole_list[i + 1]))
        SET_SLOT_CUPOLE_INFO(mini_cupole_slot_box, tonumber(equip_cupole_list[i + 1]))

    end
end

---선택된 큐폴의 정보를 좌측 정보 세팅에 설정하고, uimodel을 그린다.
function SET_SELECT_CUPOLE_INFO_WITH_MODEL(frame, cupole_index)
    local selc_cupole = GET_GLOBAL_SELECT_CUPOLE(frame);
    if cupole_index == -1 then
        return;
    end
    -- The control owns replacement/loading; the latest selection must win.
    frame:StopUpdateScript("CUPOLE_UIMODEL_DELAY_CREATE_IN_MAINCHARACTER")
    frame:SetUserValue("Select_Cupole_Index", cupole_index)
    SET_SELECT_CUPOLE_INFORMATION(frame,cupole_index);
    KUPOLE_UIMODEL_IN_MAINCHARACTER(cupole_index)
    SET_SELECT_CUPOLE_NAME(frame, cupole_index)
    frame:SetUserValue("Global_Select_Cupole", cupole_index);
    SET_BACKGROUND_IMAGE_BY_SELECT_TAB(frame, 0)
    CHECK_ILLUSTRATION_MODE(frame)
end

function CUPOLE_UIMODEL_DELAY_CREATE_IN_MAINCHARACTER(frame, delay)
    frame = frame:GetTopParentFrame()
    if frame:IsVisible() == 0 then return 0 end
    local index = frame:GetUserIValue("Select_Cupole_Index");
    local parent = frame:GetTopParentFrame();
    SET_SELECT_CUPOLE_NAME(parent, index)
    KUPOLE_UIMODEL_IN_MAINCHARACTER(index)
end

function SET_SELECT_CUPOLE_NAME(frame, index)
    local CupoleName = GET_CHILD_RECURSIVELY_NAME(frame,"managerTab/manageBG/Name_Pic/CupoleName")
    
    local cls = GET_CUPOLE_BY_INDEX_IN_CLASSLIST(index)
    local Name = TryGetProp(cls,"Dec_Name", "Name");
    local Grade = TryGetProp(cls, "Grade", "R");
    if cls == nil then
        Name = ClMsg("KupoleURItem")
        Grade = "UR"
    end
    if Grade == "UR" then
        Name = "{img cupole_grade_UR 40 24}"..Name;
    elseif Grade =="SR" then
        Name = "{img cupole_grade_SR 40 24}"..Name;
    else
        Name = "{img cupole_grade_R 40 24}"..Name;
    end
    CupoleName:SetTextByKey("Name",Name)
end

--- 선택된 큐폴의 정보를 좌측 정보 판에 세팅한다.
function SET_SELECT_CUPOLE_INFORMATION(frame, cupole_index)
    if frame == nil then
        return 0;
    end

    local NamelBG = GET_CHILD_RECURSIVELY_NAME(frame,"managerTab/manageBG/InfoBG/InfoHeadgBox/NamelBG")
    local ExplainBG = GET_CHILD_RECURSIVELY_NAME(frame,"managerTab/manageBG/InfoBG/InfoHeadgBox/ExplainBG")
    local SkillBG = GET_CHILD_RECURSIVELY_NAME(frame,"managerTab/manageBG/InfoBG/SkillSheetgBox/SkillBG")
    local PassiveBG = GET_CHILD_RECURSIVELY_NAME(frame,"managerTab/manageBG/InfoBG/SkillSheetgBox/PassiveBG")
    local RankBG = GET_CHILD_RECURSIVELY_NAME(frame,"managerTab/manageBG/InfoBG/RankBG")
    local favorites = GET_CHILD_RECURSIVELY_NAME(frame, "managerTab/manageBG/InfoBG/favorites")

    GET_CUPOLE_SORT_TYPE_FUNCTION(filter_type)

    local cupole_cls = GET_CUPOLE_BY_INDEX_IN_CLASSLIST(cupole_index);

    local IconName = TryGetProp(cupole_cls, "Icon", "None");
    local Grade = TryGetProp(cupole_cls, "Grade", "R");
    local CupoleClassName = TryGetProp(cupole_cls, "ClassName", "None");
    local CupoleDecName = TryGetProp(cupole_cls, "Dec_Name", "None");

    local state = IsFavoriteCupole(cupole_index);

    SET_CUPOLE_NAME_INFO(NamelBG, cupole_cls)
    SET_CUPOLE_BUFF_INFO(ExplainBG, cupole_cls)
    SET_CUPOLE_OWNED_EFFECT(ExplainBG, cupole_cls)
    SET_CUPOLE_ACTIVE_SKILL_INFO(SkillBG, cupole_cls);
    SET_CUPOLE_PASSIVE_SKILL_INFO(PassiveBG, cupole_cls);
    SET_CUPOLE_FRIENDLY(frame, cupole_index)
    SET_CUPOLE_FAVORITE_ICON_STATE(favorites, state);
    TOGGLE_CUPOLE_SPECIAL_ADDON(frame, cupole_index)
end

------큐폴의 이름 정보 세팅
function SET_CUPOLE_NAME_INFO(frame, cls)
    local Name = GET_CHILD(frame, "Name")

    local Cupole_Name = TryGetProp(cls, "Dec_Name", "None");
    local Grade = TryGetProp(cls, "Grade", "None");
    local RankName = string.format("cupole_grade_%s",Grade)
    if RankName == "cupole_grade_None" then
        RankName = "cupole_grade_R"
    end
    Name:SetTextByKey("rank", RankName)
    Name:SetTextByKey("value", Cupole_Name)
end

function SET_CUPOLE_STAT_AT_UI(frame, Stat, Value)
    local StatText = ClMsg(Stat)
    if utf8.len(StatText) > 25 then
        StatText = "{s12}"..StatText.."{/}";
    end
    local StatInfoStr = string.format("%s + {#ffcc33}%d{/}", StatText, Value)
    frame:SetTextByKey("value", StatInfoStr)
end

--큐폴의 효과 정보 세팅 (동행효과)
function SET_CUPOLE_BUFF_INFO(frame, cls, specifiedRank)
    if cls == nil then
        return;
    end
    local rank = nil;
    if specifiedRank then
        rank = specifiedRank;
    end
    local companyEffect = GET_CHILD(frame, "companyEffect")

    local Grade = TryGetProp(cls, "Grade", "None");

    local Stat, UpgradeValue = GET_CUPOLE_FRIENDLY_RESULT_VALUE_BY_CLS(nil, cls, rank)
    
    SET_CUPOLE_STAT_AT_UI(companyEffect, Stat, UpgradeValue)
end

--큐폴의 사용 스킬 정보 세팅
function SET_CUPOLE_ACTIVE_SKILL_INFO(frame, cls)
    local Cupole_Group_ID = TryGetProp(cls, "Group_ID", "None");
    local Cupole_Skill_List = GET_CUPOLE_SKILL_BY_GROUPID_LIST(Cupole_Group_ID)
    local Cupole_Skill_Cls = nil;
    for k,v in pairs(Cupole_Skill_List) do
        local SkillType = TryGetProp(v, "Skill_Type", "None")
        if SkillType == "Active" then
            Cupole_Skill_Cls = v;
        end
    end

    local ctrl = frame:CreateOrGetControlSet("cupole_skil","cupole_skil0", 0, -6)
    ctrl:SetGravity(ui.LEFT, ui.CENTER_VERT)
    local SkillIcon = GET_CHILD(ctrl, "SkillIcon")
    if Cupole_Skill_Cls == nil then
        SkillIcon:SetImage("");
        SkillIcon:SetEventScript(ui.MOUSEON, "None");
        SkillIcon:SetEventScriptArgNumber(ui.MOUSEON, 0);
        SkillIcon:SetEventScript(ui.MOUSEOFF, "None");
        SET_CUPOLE_SKILL_DESC(frame, nil);
        return;
    end

    local SkillClassID = TryGetProp(Cupole_Skill_Cls , "ClassID", 0);
    local SkillType = TryGetProp(Cupole_Skill_Cls , "Skill_Type", "None");
    local IconName = TryGetProp(Cupole_Skill_Cls, "Skill_Icon", "None");

    SkillIcon:SetImage(IconName);

    SkillIcon:SetEventScript(ui.MOUSEON, "ON_CUPOLE_SKILL_TOOLTIP_OPEN");
    SkillIcon:SetEventScriptArgNumber(ui.MOUSEON, SkillClassID);
    SkillIcon:SetEventScript(ui.MOUSEOFF, "ON_CUPOLE_SKILL_TOOLTIP_CLOSE");
    SET_CUPOLE_SKILL_DESC(frame, Cupole_Skill_Cls)
end

---큐폴의 패시브 스킬 정보 세팅
function SET_CUPOLE_PASSIVE_SKILL_INFO(frame, cls)
    local Cupole_Group_ID = TryGetProp(cls, "Group_ID", "None");
    local Cupole_Skill_List = GET_CUPOLE_SKILL_BY_GROUPID_LIST(Cupole_Group_ID)
    local Cupole_Skill_Cls = nil;
    for k,v in pairs(Cupole_Skill_List) do
        local SkillType = TryGetProp(v, "Skill_Type", "None")
        if SkillType == "Passive" then
            Cupole_Skill_Cls = v;
        end
    end

    local ctrl = frame:CreateOrGetControlSet("cupole_skil","cupole_skil1",0, -8)
    ctrl:SetGravity(ui.LEFT, ui.CENTER_VERT)
    local SkillIcon = GET_CHILD(ctrl, "SkillIcon")
    if Cupole_Skill_Cls == nil then
        SkillIcon:SetImage("");
        SkillIcon:SetEventScript(ui.MOUSEON, "None");
        SkillIcon:SetEventScriptArgNumber(ui.MOUSEON, 0);
        SkillIcon:SetEventScript(ui.MOUSEOFF, "None");
        SET_CUPOLE_SKILL_DESC(frame, nil);
        return;
    end
    frame:ShowWindow(1)
    
    local SkillClassID = TryGetProp(Cupole_Skill_Cls , "ClassID", 0);
    local SkillType = TryGetProp(Cupole_Skill_Cls , "Skill_Type", "None");

    local IconName = TryGetProp(Cupole_Skill_Cls, "Skill_Icon", "None");
    SkillIcon:SetImage(IconName);

    SkillIcon:SetEventScript(ui.MOUSEON, "ON_CUPOLE_SKILL_TOOLTIP_OPEN");
    SkillIcon:SetEventScriptArgNumber(ui.MOUSEON, SkillClassID);
    SkillIcon:SetEventScript(ui.MOUSEOFF, "ON_CUPOLE_SKILL_TOOLTIP_CLOSE");
    SET_CUPOLE_SKILL_DESC(frame, Cupole_Skill_Cls)
end

------보유 효과 세팅
local function GET_CUPOLE_SKILL_DISPLAY_DESC(cls)
    if cls == nil then
        return ClMsg("None");
    end

    local desc = TryGetProp(cls, "Dec_Skill", ClMsg("None"));
    desc = dic.getTranslatedStr(desc);

    local pc = GetMyPCObject();
    local groupID = TryGetProp(cls, "Group_ID", "None");
    local cupoleCls = GET_CUPOLE_CLASS_BY_GROUPID(groupID);
    if pc ~= nil and cupoleCls ~= nil then
        local ratio = GET_KUPOLE_SKILL_RATE(pc, cupoleCls, cls);
        if ratio ~= nil then
            desc = string.gsub(desc, "{Ratio}", string.format("%.f", ratio));
        end
    end
    return desc;
end

function SET_CUPOLE_SKILL_DESC(frame, cls)
    local descCtrl = GET_CHILD(frame, "Desc")
    if descCtrl == nil then
        return;
    end

    local desc = GET_CUPOLE_SKILL_DISPLAY_DESC(cls);
    descCtrl:SetTextByKey("value", desc)
    frame:SetScrollPos(0);
    frame:InvalidateScrollBar();
end

local function GET_CUPOLE_PRESET_PROP_NAME(index)
    return CUPOLE_PRESET_PROP_PREFIX..tostring(index);
end

local function NORMALIZE_CUPOLE_PRESET_VALUE(value)
    local result = {0, 0, 0};
    if value == nil or value == "None" or value == "" then
        return result, false;
    end

    local tokenList = StringSplit(tostring(value), ',');
    local registered = false;
    for i = 1, 3 do
        local classID = tonumber(tokenList[i]) or 0;
        if classID > 0 then
            result[i] = classID;
            registered = true;
        end
    end
    return result, registered;
end

local function GET_CURRENT_CUPOLE_PRESET_VALUE()
    local equipList = GET_EQUIP_CUPOLE_LIST();
    local classIDList = {0, 0, 0};
    for i = 1, 3 do
        local cupoleIndex = tonumber(equipList[i]) or -1;
        if cupoleIndex >= 0 then
            local cls = GET_CUPOLE_BY_INDEX_IN_CLASSLIST(cupoleIndex);
            classIDList[i] = TryGetProp(cls, "ClassID", 0);
        end
    end
    return string.format("%d,%d,%d", classIDList[1], classIDList[2], classIDList[3]);
end

local function GET_CUPOLE_PRESET_SLOT_TEXT(classID)
    if classID == nil or tonumber(classID) == nil or tonumber(classID) <= 0 then
        return "-";
    end

    local cls = GetClassByType("cupole_list", tonumber(classID));
    if cls == nil then
        return "?";
    end

    local iconName = TryGetProp(cls, "Icon", "None");
    if iconName == "None" then
        return "?";
    end
    return string.format("{img %s 32 32}", iconName);
end

local function GET_VALID_CUPOLE_PRESET_INDEX(index)
    index = tonumber(index);
    if index == nil or index ~= math.floor(index)
        or index < 1 or index > CUPOLE_PRESET_MAX_COUNT then
        return nil;
    end
    return index;
end

local function GET_CUPOLE_PRESET_EDIT_INDEX(frame)
    if frame == nil then
        return 0;
    end
    return tonumber(frame:GetUserIValue("CUPOLE_PRESET_EDIT_INDEX")) or 0;
end

local function GET_CUPOLE_INDEX_BY_CLASS_ID(classID)
    classID = tonumber(classID) or 0;
    if classID <= 0 then
        return -1;
    end

    local classList, classCount = GetClassList("cupole_list");
    if classList == nil then
        return -1;
    end

    for classIndex = 0, classCount - 1 do
        local cls = GetClassByIndexFromList(classList, classIndex);
        if cls ~= nil and TryGetProp(cls, "ClassID", 0) == classID then
            return classIndex;
        end
    end
    return -1;
end

local function GET_CUPOLE_PRESET_EDIT_VALUE(frame)
    local value = frame:GetUserValue("CUPOLE_PRESET_EDIT_VALUE");
    local classIDList = NORMALIZE_CUPOLE_PRESET_VALUE(value);
    return classIDList;
end

local function SET_CUPOLE_PRESET_EDIT_VALUE(frame, classIDList)
    local value = string.format("%d,%d,%d",
        tonumber(classIDList[1]) or 0,
        tonumber(classIDList[2]) or 0,
        tonumber(classIDList[3]) or 0
    );
    frame:SetUserValue("CUPOLE_PRESET_EDIT_VALUE", value);
end

local function SET_CUPOLE_PRESET_EDIT_BUTTON_STATE(frame, isEditing)
    local selectBtn = GET_CHILD_RECURSIVELY(frame, "SelectBtn");
    local disableBtn = GET_CHILD_RECURSIVELY(frame, "DisableBtn");
    local saveBtn = GET_CHILD_RECURSIVELY(frame, "PresetEditSaveBtn");
    local cancelBtn = GET_CHILD_RECURSIVELY(frame, "PresetEditCancelBtn");
    local visible = isEditing == true and 1 or 0;

    selectBtn:ShowWindow(0);
    disableBtn:ShowWindow(0);
    saveBtn:ShowWindow(visible);
    cancelBtn:ShowWindow(visible);
end

local function SET_CUPOLE_PRESET_EDIT_TITLE(frame, presetIndex)
    local slotBG = GET_CHILD_RECURSIVELY(frame, "SlotBG");
    if slotBG == nil then
        return;
    end
    local title = GET_CHILD(slotBG, "Title");
    if title == nil then
        return;
    end

    if presetIndex ~= nil and presetIndex > 0 then
        title:SetTextByKey("value", ScpArgMsg("CupolePresetEditTitle", "PRESET", presetIndex));
    else
        title:SetTextByKey("value", ClMsg("CupoleTeamFormation"));
    end
end

local function REFRESH_CUPOLE_PRESET_EDIT_SLOTS(frame)
    local slotBG = GET_CHILD_RECURSIVELY(frame, "SlotBG");
    if slotBG == nil then
        return;
    end
    local slotGroup = GET_CHILD(slotBG, "gb_slot");
    if slotGroup == nil then
        return;
    end

    local classIDList = GET_CUPOLE_PRESET_EDIT_VALUE(frame);
    local selectedSlot = tonumber(frame:GetUserIValue("CUPOLE_PRESET_EDIT_SLOT")) or 1;
    FRAME_CHILD_COLORTONE_CLEAR(slotGroup);

    for slotIndex = 1, 3 do
        local slot = GET_CHILD(slotGroup, "Main_Cupole_Slot_"..tostring(slotIndex - 1));
        if slot ~= nil then
            SET_SLOT_CUPOLE_INFO(slot, GET_CUPOLE_INDEX_BY_CLASS_ID(classIDList[slotIndex]));
            local slotButton = GET_CHILD(slot, "gb");
            if slotButton ~= nil then
                slotButton:SetEventScript(ui.LBUTTONUP, "CUPOLE_PRESET_EDIT_SLOT_SELECT");
                slotButton:SetEventScriptArgNumber(ui.LBUTTONUP, slotIndex);
                slotButton:SetEventScript(ui.RBUTTONUP, "CUPOLE_PRESET_EDIT_SLOT_CLEAR");
                slotButton:SetEventScriptArgNumber(ui.RBUTTONUP, slotIndex);
            end

            if slotIndex == selectedSlot then
                FRAME_COLOR_CHANGE(slot, "FF5CFFDF");
            end
        end
    end
end

local function END_CUPOLE_PRESET_EDIT(frame, showPresetList)
    if frame == nil then
        return;
    end

    frame:SetUserValue("CUPOLE_PRESET_EDIT_INDEX", 0);
    frame:SetUserValue("CUPOLE_PRESET_EDIT_SLOT", 0);
    frame:SetUserValue("CUPOLE_PRESET_EDIT_VALUE", "0,0,0");
    frame:SetUserValue("CUPOLE_PRESET_EDIT_PENDING", 0);

    SET_CUPOLE_SLOTS(frame);
    SET_CUPOLE_LIST(frame);
    local slotBG = GET_CHILD_RECURSIVELY(frame, "SlotBG");
    local slotGroup = nil;
    if slotBG ~= nil then
        slotGroup = GET_CHILD(slotBG, "gb_slot");
    end
    local rightSlotGroup = GET_CHILD_RECURSIVELY(frame, "slotsetBG");
    FRAME_CHILD_COLORTONE_CLEAR(slotGroup);
    FRAME_CHILD_COLORTONE_CLEAR(rightSlotGroup);
    SET_CUPOLE_PRESET_EDIT_BUTTON_STATE(frame, false);
    SET_CUPOLE_PRESET_EDIT_TITLE(frame, 0);
    CUPOLE_PRESET_REFRESH(frame);

    if showPresetList == true then
        CUPOLE_RIGHT_VIEW_CHANGE(frame, nil, "", 1);
    end
end

function CUPOLE_PRESET_EDIT_BEGIN(parent, ctrl, argStr, argNum)
    local frame = parent:GetTopParentFrame();
    local presetIndex = GET_VALID_CUPOLE_PRESET_INDEX(argNum);
    if frame == nil or presetIndex == nil then
        return;
    end

    local etc = GetMyEtcObject();
    if etc == nil then
        return;
    end

    RESET_CUPOLE_SELECT_MODE(frame);
    local propName = GET_CUPOLE_PRESET_PROP_NAME(presetIndex);
    local classIDList = NORMALIZE_CUPOLE_PRESET_VALUE(TryGetProp(etc, propName, "0,0,0"));
    frame:SetUserValue("CUPOLE_PRESET_EDIT_INDEX", presetIndex);
    frame:SetUserValue("CUPOLE_PRESET_EDIT_SLOT", 1);
    frame:SetUserValue("CUPOLE_PRESET_EDIT_PENDING", 0);
    SET_CUPOLE_PRESET_EDIT_VALUE(frame, classIDList);

    CUPOLE_RIGHT_VIEW_CHANGE(frame, nil, "", 0);
    SET_CUPOLE_PRESET_EDIT_BUTTON_STATE(frame, true);
    SET_CUPOLE_PRESET_EDIT_TITLE(frame, presetIndex);
    REFRESH_CUPOLE_PRESET_EDIT_SLOTS(frame);
    SET_CUPOLE_LIST_SET_FUNCTION(frame, "CUPOLE_PRESET_EDIT_CUPOLE_SELECT");
end

function CUPOLE_PRESET_EDIT_SLOT_SELECT(parent, ctrl, argStr, argNum)
    local frame = parent:GetTopParentFrame();
    if GET_CUPOLE_PRESET_EDIT_INDEX(frame) <= 0 then
        return;
    end

    local slotIndex = tonumber(argNum) or 0;
    if slotIndex < 1 or slotIndex > 3 then
        return;
    end

    frame:SetUserValue("CUPOLE_PRESET_EDIT_SLOT", slotIndex);
    REFRESH_CUPOLE_PRESET_EDIT_SLOTS(frame);
end

function CUPOLE_PRESET_EDIT_SLOT_CLEAR(parent, ctrl, argStr, argNum)
    local frame = parent:GetTopParentFrame();
    if GET_CUPOLE_PRESET_EDIT_INDEX(frame) <= 0 then
        return;
    end

    local slotIndex = tonumber(argNum) or 0;
    if slotIndex < 1 or slotIndex > 3 then
        return;
    end

    local classIDList = GET_CUPOLE_PRESET_EDIT_VALUE(frame);
    classIDList[slotIndex] = 0;
    frame:SetUserValue("CUPOLE_PRESET_EDIT_SLOT", slotIndex);
    SET_CUPOLE_PRESET_EDIT_VALUE(frame, classIDList);
    REFRESH_CUPOLE_PRESET_EDIT_SLOTS(frame);
end

function CUPOLE_PRESET_EDIT_CUPOLE_SELECT(parent, ctrl, argStr, argNum)
    local frame = parent:GetTopParentFrame();
    if GET_CUPOLE_PRESET_EDIT_INDEX(frame) <= 0 then
        return;
    end

    local slotIndex = tonumber(frame:GetUserIValue("CUPOLE_PRESET_EDIT_SLOT")) or 0;
    local classID = tonumber(argNum) or 0;
    if slotIndex < 1 or slotIndex > 3 or classID <= 0 then
        return;
    end

    local cls = GetClassByType("cupole_list", classID);
    local pc = GetMyPCObject();
    if pc == nil then
        return;
    end
    local account = GetMyAccountObj(pc);
    if cls == nil or account == nil then
        return;
    end

    local accountProperty = TryGetProp(cls, "AccountProperty", "None");
    if accountProperty == "None" or TryGetProp(account, accountProperty, 0) <= 0 then
        ui.SysMsg(ClMsg("CupolePresetNotOwned"));
        return;
    end

    local classIDList = GET_CUPOLE_PRESET_EDIT_VALUE(frame);
    for index = 1, 3 do
        if index ~= slotIndex and classIDList[index] == classID then
            classIDList[index] = 0;
        end
    end
    classIDList[slotIndex] = classID;
    SET_CUPOLE_PRESET_EDIT_VALUE(frame, classIDList);

    if slotIndex < 3 then
        frame:SetUserValue("CUPOLE_PRESET_EDIT_SLOT", slotIndex + 1);
    end
    REFRESH_CUPOLE_PRESET_EDIT_SLOTS(frame);
end

function CUPOLE_PRESET_EDIT_SAVE(parent, ctrl, argStr, argNum)
    local frame = parent:GetTopParentFrame();
    local presetIndex = GET_CUPOLE_PRESET_EDIT_INDEX(frame);
    if presetIndex <= 0 or frame:GetUserIValue("CUPOLE_PRESET_EDIT_PENDING") == 1 then
        return;
    end

    local classIDList = GET_CUPOLE_PRESET_EDIT_VALUE(frame);
    if classIDList[1] <= 0 then
        ui.SysMsg(ClMsg("CupolePresetNeedMain"));
        return;
    end

    frame:SetUserValue("CUPOLE_PRESET_EDIT_PENDING", 1);
    CUPOLE_PRESET_SAVE_EXEC(presetIndex, string.format("%d,%d,%d", classIDList[1], classIDList[2], classIDList[3]));
end

function CUPOLE_PRESET_EDIT_CANCEL(parent, ctrl, argStr, argNum)
    local frame = parent:GetTopParentFrame();
    END_CUPOLE_PRESET_EDIT(frame, true);
end

function CUPOLE_PRESET_SAVE(parent, ctrl, argStr, argNum)
    local presetIndex = GET_VALID_CUPOLE_PRESET_INDEX(argNum);
    if presetIndex == nil then
        return;
    end

    local classIDList = NORMALIZE_CUPOLE_PRESET_VALUE(GET_CURRENT_CUPOLE_PRESET_VALUE());
    if classIDList[1] <= 0 then
        ui.SysMsg(ClMsg("CupolePresetNeedMain"));
        return;
    end

    local etc = GetMyEtcObject();
    if etc == nil then
        return;
    end
    local propName = GET_CUPOLE_PRESET_PROP_NAME(presetIndex);
    local _, registered = NORMALIZE_CUPOLE_PRESET_VALUE(TryGetProp(etc, propName, "0,0,0"));
    if registered == true then
        ui.MsgBox(
            ScpArgMsg("CupolePresetOverwriteConfirm", "PRESET", presetIndex),
            string.format("CUPOLE_PRESET_SAVE_EXEC(%d)", presetIndex),
            "None"
        );
        return;
    end

    CUPOLE_PRESET_SAVE_EXEC(presetIndex);
end

function CUPOLE_PRESET_SAVE_EXEC(presetIndex, presetValue)
    presetIndex = GET_VALID_CUPOLE_PRESET_INDEX(presetIndex);
    if presetIndex == nil then
        return;
    end

    local txArg = tostring(presetIndex);
    if presetValue ~= nil and presetValue ~= "" then
        txArg = txArg.."/"..tostring(presetValue);
    end
    pc.ReqExecuteTx("SCR_CUPOLE_PRESET_SAVE", txArg);
end

function CUPOLE_PRESET_APPLY(parent, ctrl, argStr, argNum)
    local presetIndex = GET_VALID_CUPOLE_PRESET_INDEX(argNum);
    if presetIndex == nil then
        return;
    end

    if IS_IN_CITY() == 0 then
        ui.SysMsg(ClMsg("AllowedInTown"));
        return;
    end

    local etc = GetMyEtcObject();
    if etc == nil then
        return;
    end
    local propName = GET_CUPOLE_PRESET_PROP_NAME(presetIndex);
    local _, registered = NORMALIZE_CUPOLE_PRESET_VALUE(TryGetProp(etc, propName, "0,0,0"));
    if registered == false then
        ui.SysMsg(ClMsg("CupolePresetNotFound"));
        return;
    end

    pc.ReqExecuteTx("SCR_CUPOLE_PRESET_APPLY", tostring(presetIndex));
end

function ON_CUPOLE_PRESET_SAVED(frame, msg, argStr, argNum)
    if GET_CUPOLE_PRESET_EDIT_INDEX(frame) == (tonumber(argNum) or 0) then
        END_CUPOLE_PRESET_EDIT(frame, true);
    else
        CUPOLE_PRESET_REFRESH(frame);
    end
    ui.SysMsg(ScpArgMsg("CupolePresetSaved", "PRESET", tonumber(argNum) or 0));
end

function ON_CUPOLE_PRESET_APPLIED(frame, msg, argStr, argNum)
    local equipList = StringSplit(argStr, ";");
    local mainCupoleIndex = tonumber(equipList[1]) or -1;

    SET_CUPOLE_SLOTS(frame);
    if mainCupoleIndex >= 0 then
        SET_SELECT_CUPOLE_INFO_WITH_MODEL(frame, mainCupoleIndex);
        TOGGLE_CUPOLE_SPECIAL_ADDON(frame, mainCupoleIndex);
    end
    CUPOLE_PRESET_REFRESH(frame);
    ui.SysMsg(ScpArgMsg("CupolePresetApplied", "PRESET", tonumber(argNum) or 0));
end

function ON_CUPOLE_PRESET_FAILED(frame, msg, argStr, argNum)
    local messageKeyByReason = {
        ["INVALID_INDEX"] = "CupolePresetInvalidIndex",
        ["EMPTY_EQUIP"] = "CupolePresetNeedMain",
        ["NOT_FOUND"] = "CupolePresetNotFound",
        ["INVALID_CUPOLE"] = "CupolePresetInvalidCupole",
        ["NOT_OWNED"] = "CupolePresetNotOwned",
        ["DUPLICATE"] = "CupolePresetDuplicate",
        ["NOT_IN_CITY"] = "AllowedInTown"
    };
    frame:SetUserValue("CUPOLE_PRESET_EDIT_PENDING", 0);
    ui.SysMsg(ClMsg(messageKeyByReason[argStr] or "CupolePresetFailed"));
    CUPOLE_PRESET_REFRESH(frame);
end

function CUPOLE_PRESET_REFRESH(frame)
    if frame == nil then
        frame = ui.GetFrame("cupole_item");
    end
    if frame == nil then
        return;
    end

    local etc = GetMyEtcObject();
    if etc == nil then
        return;
    end

    local currentValue = GET_CURRENT_CUPOLE_PRESET_VALUE();
    for i = 1, CUPOLE_PRESET_MAX_COUNT do
        local row = GET_CHILD_RECURSIVELY(frame, "PresetRow"..i);
        if row ~= nil then
            local propName = GET_CUPOLE_PRESET_PROP_NAME(i);
            local presetValue = TryGetProp(etc, propName, "0,0,0");
            local classIDList, registered = NORMALIZE_CUPOLE_PRESET_VALUE(presetValue);
            local normalizedValue = string.format("%d,%d,%d", classIDList[1], classIDList[2], classIDList[3]);
            local isActive = registered == true and normalizedValue == currentValue;

            for slotIndex = 1, 3 do
                local slotText = GET_CHILD(row, "Slot"..slotIndex);
                slotText:SetTextByKey("value", GET_CUPOLE_PRESET_SLOT_TEXT(classIDList[slotIndex]));
                slotText:ShowWindow(registered == true and 1 or 0);
            end

            local emptyState = GET_CHILD(row, "EmptyState");
            local activeState = GET_CHILD(row, "ActiveState");
            local applyBtn = GET_CHILD(row, "ApplyBtn");
            local editBtn = GET_CHILD(row, "EditBtn");
            local overwriteBtn = GET_CHILD(row, "OverwriteBtn");
            local emptySaveBtn = GET_CHILD(row, "EmptySaveBtn");
            local emptySaveBtnText = GET_CHILD(row, "EmptySaveBtnText");
            local emptyCreateBtn = GET_CHILD(row, "EmptyCreateBtn");

            emptyState:ShowWindow(registered == false and 1 or 0);
            activeState:ShowWindow(isActive == true and 1 or 0);
            applyBtn:ShowWindow(registered == true and isActive == false and 1 or 0);
            editBtn:ShowWindow(registered == true and 1 or 0);
            overwriteBtn:ShowWindow(registered == true and 1 or 0);
            emptySaveBtn:ShowWindow(registered == false and 1 or 0);
            emptySaveBtnText:ShowWindow(registered == false and 1 or 0);
            emptyCreateBtn:ShowWindow(registered == false and 1 or 0);

            if isActive == true then
                row:SetSkinName("cupolegreenroundsquare");
            else
                row:SetSkinName("cupolesquare");
            end
        end
    end
end

function CUPOLE_RIGHT_VIEW_CHANGE(parent, ctrl, argStr, argNum)
    local frame = parent:GetTopParentFrame();
    local viewIndex = tonumber(argNum) or 0;
    if GET_CUPOLE_PRESET_EDIT_INDEX(frame) > 0 and viewIndex ~= 0 then
        return;
    end
    local slotsetBG = GET_CHILD_RECURSIVELY(frame, "slotsetBG");
    local presetBG = GET_CHILD_RECURSIVELY(frame, "PresetBG");
    local filtergbox = GET_CHILD_RECURSIVELY(frame, "filtergbox");
    local listTabBtn = GET_CHILD_RECURSIVELY(frame, "ListTabBtn");
    local presetTabBtn = GET_CHILD_RECURSIVELY(frame, "PresetTabBtn");
    local listTabWidth = listTabBtn:GetWidth();
    local listTabHeight = listTabBtn:GetHeight();
    local presetTabWidth = presetTabBtn:GetWidth();
    local presetTabHeight = presetTabBtn:GetHeight();

    frame:SetUserValue("CUPOLE_RIGHT_VIEW", viewIndex);
    slotsetBG:ShowWindow(viewIndex == 0 and 1 or 0);
    presetBG:ShowWindow(viewIndex == 1 and 1 or 0);
    filtergbox:ShowWindow(viewIndex == 0 and 1 or 0);

    listTabBtn:SetImage(viewIndex == 0 and "cupole_ui_view_tab_btn_clicked" or "cupole_ui_view_tab_btn");
    presetTabBtn:SetImage(viewIndex == 1 and "cupole_ui_view_tab_btn_clicked" or "cupole_ui_view_tab_btn");
    listTabBtn:Resize(listTabWidth, listTabHeight);
    presetTabBtn:Resize(presetTabWidth, presetTabHeight);

    if viewIndex == 1 then
        CUPOLE_PRESET_REFRESH(frame);
    end
end


------보유 효과 세팅
function SET_CUPOLE_OWNED_EFFECT(frame, cls, specifiedRank)
    local haveEffect = GET_CHILD(frame, "haveEffect")
    local rank = nil;
    if specifiedRank then
        rank = specifiedRank;
    end
    local Stat, Value = GET_CUPOLE_OWNED_RESULT_VALUE_BY_CLS(nil, cls, rank)
    
    if not Stat or not Value or not haveEffect then
        return;
    end
    SET_CUPOLE_STAT_AT_UI(haveEffect, Stat, Value)
end

--큐폴 친밀도 설정
function SET_CUPOLE_FRIENDLY(frame, clsid)
    local pc = GetMyPCObject();
    if pc == nil then
        return;
    end
    local acc = GetMyAccountObj(pc);
    if acc == nil then
        return;
    end
    local AccProp = GET_CUPOLE_PROP_BY_INDEX(clsid, "AccountProperty");
    local CupoleExp = TryGetProp(acc, AccProp, 0);
    SET_CUPOLE_FRIENDLY_RATE(frame, CupoleExp);
end

--친밀도 숫자 변경
function SET_CUPOLE_FRIENDLY_RATE(frame, exp)
    local Rate = GET_CHILD_RECURSIVELY_NAME(frame,"managerTab/manageBG/InfoBG/InfoHeadgBox/ExplainBG/friendly_pic/Rate")
    Rate:SetTextByKey("value", exp);
end

---큐폴 선택 버튼설정 로직
function SET_CUPOLE_SELECT_BTN(btnframe, funcscp, btnname)
    if btnframe ~= nil then
        btnframe:SetEventScript(ui.LBUTTONUP, funcscp);
        btnframe:SetTextByKey("label", ClMsg(btnname))
    end
end

function SET_CUPOLE_BTN_CITY(frame)
    local SelectBtn = GET_CHILD_RECURSIVELY(frame, "SelectBtn")
    local DisableBtn = GET_CHILD_RECURSIVELY(frame, "DisableBtn")
    
    if IS_IN_CITY() == 0 then
        SelectBtn:ShowWindow(0)
        DisableBtn:ShowWindow(0)
    end
end

---큐폴 uimodel offset 조절 함수
function SET_CUPOLE_MAINCHARACTERFRAME_BY_INDEX(index, cupole_index)
    local frame = ui.GetFrame("cupole_item")
    if frame == nil then
        return ;
    end

    local MainCharacter = GET_CHILD_RECURSIVELY_NAME(frame,"managerTab/manageBG/MainCharacter")
    if MainCharacter == nil then
        return ;
    end
    KUPOLE_UIMODEL_IN_MAINCHARACTER(cupole_index)
end

function SET_CUPOLE_GAHCAFRAME_BY_INDEX(frame, index, cupole_index)
    SET_RTT_OFFSET_IN_IMAGE(frame, index, cupole_index)
end

----특정 index의 offset 조절함수.
function SET_RTT_OFFSET_IN_IMAGE(frame, OffsetIndex, cupole_index)
    if OffsetIndex > 15 or OffsetIndex < 0 then
        print("error!!")
        return ;
    end
    local CupoleUV = string.format("cupole_%d",OffsetIndex);
    frame:SetImage(CupoleUV)
    SET_KUPOLE_RTT_IMAGE_SIZE(frame, cupole_index)
end



---- 큐폴을 선택 체크 하는 로직.
function SET_SLOT_SELECT_STATE(SlotFrame, SelectBtnFrame, SelectBtnScp, SelectTextMsg, index)
    local parent = SelectBtnFrame:GetTopParentFrame();
    FRAME_COLOR_CHANGE(SlotFrame, "FF5CFFDF");
    if index == -1 then
        CHANGE_DISABLE_BTN_SHOWSTATE(0, SlotFrame:GetName(), index);
        return;
    end
    if string.find(SlotFrame:GetName(), "cupole_slot_") ~= nil then
        CHANGE_DISABLE_BTN_SHOWSTATE(0, SlotFrame:GetName(), index);
    else
        CHANGE_DISABLE_BTN_SHOWSTATE(1, SlotFrame:GetName(), index);
    end
    
    SET_CUPOLE_SELECT_BTN(SelectBtnFrame, SelectBtnScp, SelectTextMsg);  
    SET_SELECT_CUPOLE_INFO_WITH_MODEL(parent, index);

    local upgradebtn_bg = GET_CHILD_RECURSIVELY(parent,"upgradebtn_bg")
    TOGGLE_CUPOLE_RANKUP_BTN(upgradebtn_bg);
    SET_CUPOLE_BTN_CITY(parent)
end

function SET_CUPOLE_BACKGROUND_IMAGE(frame, image)
    local parent = frame:GetTopParentFrame();
    if parent == nil then
        return;
    end
    local pic = GET_CHILD_RECURSIVELY_NAME(parent, "managerTab/pic")
    if pic == nil then
        return;
    end
    pic:SetImage(image)
end

function SET_BACKGROUND_IMAGE_BY_CUPOLE_INDEX(frame, index)
    local cls = GET_CUPOLE_BY_INDEX_IN_CLASSLIST(index)
    if cls == nil then
        return;
    end
    TOGGLE_CUPOLE_BACKGROUND_IMAGE(frame, true)

    local grade = TryGetProp(cls, "Grade", "R")
    local ImageName = "";
    if grade == "UR" then
        ImageName = "kupole_ur_goddess"
    else
        ImageName = "kupole_r_sr"
    end
    SET_CUPOLE_BACKGROUND_IMAGE(frame,ImageName)
end

function SET_BACKGROUND_IMAGE_BY_PICKUP(frame, pickup)
    local parent = frame:GetTopParentFrame();
    local managerTab = GET_CHILD_RECURSIVELY(parent, "managerTab")
    SET_CUPOLE_BACKGROUND_IMAGE(frame, "back_cacheshop")

    TOGGLE_CUPOLE_BACKGROUND_IMAGE(frame, false)
    CUPOLE_SPINE_ANIMAITON_SET(managerTab, "Cache")
end

function TOGGLE_CUPOLE_BACKGROUND_IMAGE(frame, state)
    local parent = frame:GetTopParentFrame();
    local pic = GET_CHILD_RECURSIVELY_NAME(parent, "managerTab/pic")
    local spinebg = GET_CHILD_RECURSIVELY_NAME(parent, "managerTab/spinepic")

    if state == true then
        pic:ShowWindow(1);
        spinebg:ShowWindow(0);
    else
        pic:ShowWindow(1);
        spinebg:ShowWindow(1);    
    end
end

function SET_BACKGROUND_IMAGE_BY_SELECT_TAB(frame, tab)
    if frame == nil or tab == nil then
        return;
    end
    local selc_cupole = GET_GLOBAL_SELECT_CUPOLE(frame);
    
    if tab == 0 then
        SET_BACKGROUND_IMAGE_BY_CUPOLE_INDEX(frame, selc_cupole)
    elseif tab == 1 then
        SET_BACKGROUND_IMAGE_BY_PICKUP(frame, 0);
    end
end
---get set 끝









-- 큐폴 UI의 기본적인 기능들을 구현해 놓은 것
-- 좌측 우측에서 사용하는  함수같은 경우에는 따로 루아파일을 만들어서 관리한다.
-- 여기서는 통합적인 로직 메인로직등등만을 작성해놓는다.












--------------------default function start

------큐폴 UI버튼 토글
function CUPOLE_ITEM_TOGGLE(parent, ctrl, argStr, argNum)
    local cupole_item = ui.GetFrame("cupole_item")
    cupole_item:ShowWindowToggle();
end

-----큐폴 UI등록
function CUPOLE_ITEM_ON_INIT(addon,frame)
    addon:RegisterMsg('SET_CUPOLE_EXP_UP', 'ON_SET_CUPOLE_EXP_UP');
    addon:RegisterMsg('CUPOLE_EQUIP_COMPLELTE', 'ON_SET_EQUIP_CUPOLE_OPTIONS');
    addon:RegisterMsg('CUPOLE_PRESET_SAVED', 'ON_CUPOLE_PRESET_SAVED');
    addon:RegisterMsg('CUPOLE_PRESET_APPLIED', 'ON_CUPOLE_PRESET_APPLIED');
    addon:RegisterMsg('CUPOLE_PRESET_FAILED', 'ON_CUPOLE_PRESET_FAILED');
    addon:RegisterMsg('GACHA_CUPOLE_RESULT', 'ON_GACHA_CUPOLE_RESULT');
    addon:RegisterMsg('GACHA_CUPOLE_RESULT', 'ON_GACHA_RESULT_APPLY_IN_CUPOLE_UI');
    addon:RegisterMsg('GACHA_CUPOLE_RESULT', 'ON_SET_EQUIP_CUPOLE_OPTIONS');

    addon:RegisterMsg('CUPOLE_ACTIVATE', 'PICKUP_ON_CUPOLE_ACTIVATE');
    addon:RegisterMsg('TAKE_CUPOLE_RANKUP_ITEM', 'PICKUP_ON_CUPOLE_ACTIVATE');

end

-----큐폴 UI OPEN시의 로직
function OPEN_CUPOLE_ITEM()
    local frame = ui.GetFrame("cupole_item");
    if frame == nil then
        return;
    end
    frame:SetUserValue("CUPOLE_PRESET_EDIT_INDEX", 0);
    frame:SetUserValue("CUPOLE_PRESET_EDIT_SLOT", 0);
    frame:SetUserValue("CUPOLE_PRESET_EDIT_VALUE", "0,0,0");
    frame:SetUserValue("CUPOLE_PRESET_EDIT_PENDING", 0);
    local managertab = frame:GetChild("managerTab")
    RESET_CUPOLE_SELECT_MODE(frame)
    SET_CUPOLE_PRESET_EDIT_BUTTON_STATE(frame, false);
    SET_CUPOLE_PRESET_EDIT_TITLE(frame, 0);
    
    local pc = GetMyPCObject();
    if pc == nil then
        return;
    end

    local equip_cupole_list = GET_EQUIP_CUPOLE_LIST()
    if equip_cupole_list == nil then
        return;
    end

    --큐폴 정렬
    local Cupole_Filter = ui.GetFrame("cupole_filter");
    filter_type = Cupole_Filter:GetUserValue("Filter");

    GET_CUPOLE_SORT_TYPE_FUNCTION(filter_type)

    ---현재 선택되어있는 큐폴 인덱스 가져오기
    local State, ChoosCupoleIndex, SlotIndex = GET_CHOOSE_INIT_CUPOLE(equip_cupole_list);
    frame:SetUserValue("Global_Select_Cupole",ChoosCupoleIndex);
    ---좌측 큐폴 슬롯 세팅
    SET_CUPOLE_SLOTS(frame);
    ---우측 큐폴리스트 생성
    SET_CUPOLE_LIST(frame);
    ---우측 작업 영역은 큐폴 목록을 기본으로 표시
    CUPOLE_RIGHT_VIEW_CHANGE(managertab, nil, "", 0);
    ---큐폴 정보중 GAUGE 설정
    SET_CUPOLE_FRIENDLY(frame, ChoosCupoleIndex);
    ----우상단 돈 설정
    CUPOLE_ITEM_MONEY_SET(frame)
    ---큐폴 uimodel 생성
    KUPOLE_UIMODEL_IN_MAINCHARACTER(ChoosCupoleIndex);
    SET_SELECT_CUPOLE_NAME(frame, ChoosCupoleIndex)
    TOGGLE_CUPOLE_SPECIAL_ADDON(frame, ChoosCupoleIndex)
    --이걸 해야 매 프레임마다 업데이트 하면서 uimodel을 갱신한다.
    
    frame:RunUpdateScript("UPDATE_CUPOLE")

    CUPOLE_TOP_TAB_CHANGE(managertab, nil, "", 0)
    
    local upgradebtn_bg = GET_CHILD_RECURSIVELY(frame,"upgradebtn_bg")
    SET_MOUSE_OVER_COLOR_CHNAGE_FUNC(upgradebtn_bg)
    ON_SET_EQUIP_CUPOLE_OPTIONS(frame)

    local SlotSetBg = GET_CHILD_RECURSIVELY(frame,"slotsetBG")
    SlotSetBg:SetScrollBarSkinName("verticalscrollbar3")
    --초기 선택 설정 한다.
    INIT_SELECT_CUPOLE_STATE(frame, State, ChoosCupoleIndex, SlotIndex);

    camera.SetRTTCameraDistance(200)
end

function INIT_SELECT_CUPOLE_STATE(frame, State, index, SlotIndex)
    local rightslotset = GET_CHILD_RECURSIVELY(frame, "slotsetBG")
    local SlotBG = GET_CHILD_RECURSIVELY(frame, "SlotBG")
    local gb_slot = GET_CHILD(SlotBG, "gb_slot")
    local SelectBtn = GET_CHILD_RECURSIVELY(frame,"SelectBtn");

    local SlotFrame = nil;

    local SelFunScp = ""
    local SelBtnTxt = ""
    if State == "left" then
        SelFunScp = "CUPOLE_LEFT_SLOT_EQUIP"
        SelBtnTxt = "swap"
        SlotFrame = gb_slot:GetChildByIndex(SlotIndex - 1)
    else
        SelFunScp = "CUPOLE_RIGHT_SLOT_EQUIP"
        SelBtnTxt = "equipment"
        SlotFrame = GET_CHILD_RECURSIVELY(rightslotset, "cupole_slot_1");
    end
    local Represent_cupole = GET_REPRESENT_CUPOLE_INFO()
    local clsid = TryGetProp(Represent_cupole , "ClassID", 0)
    SET_SLOT_SELECT_STATE(SlotFrame, SelectBtn, SelFunScp, SelBtnTxt, index);
    SelectBtn:ShowWindow(0)
end

---큐폴 UI닫음
function CLOSE_CUPOLE_ITEM(frame)
    frame:SetUserValue("CUPOLE_PRESET_EDIT_INDEX", 0);
    frame:SetUserValue("CUPOLE_PRESET_EDIT_SLOT", 0);
    frame:SetUserValue("CUPOLE_PRESET_EDIT_VALUE", "0,0,0");
    frame:SetUserValue("CUPOLE_PRESET_EDIT_PENDING", 0);
    CLOSE_RELEATIVE_FRAMES()
    RESET_CUPOLE_UIMODEL_FIX_DIR()
    -- local frame = ui.GetFrame("cupole_item");
    frame:StopUpdateScript('UPDATE_CUPOLE')
    frame:StopUpdateScript("CUPOLE_UIMODEL_DELAY_CREATE_IN_MAINCHARACTER")
    
    --현재 UI모델을 삭제한다.
    local selc_cupole = GET_GLOBAL_SELECT_CUPOLE(frame);
    REMOVE_ALL_CUPOLE_UIMODEL()
end

---- 큐폴 삭제
function REMOVE_ALL_CUPOLE_UIMODEL()
    local cupole_list, cnt = GetClassList("cupole_list");
    for i = 0, cnt - 1 do
        HIDE_CUPOLE_UIMODEL(i);
    end
end

---------------------default function end

---------------------msg function start

--큐폴 경험치 갱신되면 게이지 갱신해준다
function ON_SET_CUPOLE_EXP_UP(frame, msg, argStr, argNum)
    --큐폴 친밀도 게이지 설정
    local cls = GET_CUPOLE_CLASS_ACCOUNTPROP(argStr)
    local index = TryGetProp(cls, "ClassID", -1);
    local ExplainBG = GET_CHILD_RECURSIVELY(frame, "ExplainBG")
    local companyEffect = GET_CHILD_RECURSIVELY(ExplainBG, "companyEffect")
    local haveEffect = GET_CHILD_RECURSIVELY(ExplainBG, "haveEffect")

    local Grade = TryGetProp(cls, "Grdae", "R");
    local res = 0.2;
    if Grade == "UR" then
        res = 0.5;
    elseif Grade == "SR" then
        res = 0.3;
    end

    local UpgradeStat, UpgradeRes = GET_CUPOLE_FRIENDLY_RESULT_VALUE_BY_CLS(nil, cls, argNum);
    local OwnedStat, OwendRes = GET_CUPOLE_OWNED_RESULT_VALUE_BY_CLS(nil, cls, argNum);

    SET_CUPOLE_STAT_AT_UI(companyEffect, UpgradeStat, UpgradeRes)
    SET_CUPOLE_STAT_AT_UI(haveEffect, OwnedStat, OwendRes)
    SET_CUPOLE_FRIENDLY_RATE(frame, argNum);
    ON_SET_EQUIP_CUPOLE_OPTIONS(frame)
end


--큐폴 장착 시 스탯 텍스트 갱신
function ON_SET_EQUIP_CUPOLE_OPTIONS(frame, msg, argStr, argNum)
    local pc = GetMyPCObject();
    if pc == nil then
        return 0;
    end
    local acc = GetMyAccountObj(pc);
    if acc == nil then
        return 0;
    end

    local OptionListBG = GET_CHILD_RECURSIVELY(frame,"OptionListBG")
	OptionListBG:SetScrollBarSkinName("verticalscrollbar3")

    local cupole_list, cnt = GetClassList("cupole_list");
    if cupole_list == nil then
        return;
    end
    
    local y = 0;
    local offset = 30;
    local defaultoffset = {15, 30};
    local Statlist = {
    };


    for i = 0, cnt - 1 do
        local cls = GetClassByIndexFromList(cupole_list, i);
        if cls ~= nil then
            local stat, value = GET_CUPOLE_OWNED_RESULT_VALUE_BY_CLS(pc, cls)
            if value > 0 then
                if Statlist[stat] == nil then
                    Statlist[stat] = value;
                else
                    Statlist[stat] = Statlist[stat] + value;
                end
            end
        end
    end

    for k,v in spairs(Statlist, function(t,a,b) return stat_sort_value[b] > stat_sort_value[a] end) do
        local ctrl = OptionListBG:CreateOrGetControlSet("cupole_stat_slot", k, defaultoffset[1], y * offset);
        local StatBox = GET_CHILD(ctrl, "Stat")
        SET_CUPOLE_STAT_AT_UI(StatBox, k, v)
        y = y + 1;
    end
    CUPOLE_PRESET_REFRESH(frame);
end


function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end
---------------------msg function end


---------------------- btn script start


--- 강화 탭 열기
function OPEN_REINFORCE_TAB(frame, ctrl, argStr, argNum)
    ui.OpenFrame('cupole_reinforce');
    local TopParent = frame:GetTopParentFrame()
    RESET_CUPOLE_SELECT_MODE(TopParent)
end

---큐폴 선택, 가챠 탭 전환
function CUPOLE_TOP_TAB_CHANGE(parent, ctrl, argStr, argNum)
    local frame = parent:GetTopParentFrame();
    local managerTab = GET_CHILD_RECURSIVELY(frame, "managerTab");
    local curtabIndex = tonumber(argNum) or 0;
    if GET_CUPOLE_PRESET_EDIT_INDEX(frame) > 0 and curtabIndex ~= 0 then
        END_CUPOLE_PRESET_EDIT(frame, false);
    end
    local manageTabBtn = GET_CHILD(managerTab, "ManageTabBtn");
    local recruitTabBtn = GET_CHILD(managerTab, "RecruitTabBtn");
    local manageTabWidth = manageTabBtn:GetWidth();
    local manageTabHeight = manageTabBtn:GetHeight();
    local recruitTabWidth = recruitTabBtn:GetWidth();
    local recruitTabHeight = recruitTabBtn:GetHeight();

    frame:SetUserValue("CUPOLE_TOP_TAB", curtabIndex);
    manageTabBtn:SetImage(curtabIndex == 0 and "cupole_ui_top_tab_v2_clicked" or "cupole_ui_top_tab_v2");
    recruitTabBtn:SetImage(curtabIndex == 1 and "cupole_ui_top_tab_v2_clicked" or "cupole_ui_top_tab_v2");
    manageTabBtn:Resize(manageTabWidth, manageTabHeight);
    recruitTabBtn:Resize(recruitTabWidth, recruitTabHeight);
    CUPOLE_TAB_VIEW(managerTab, curtabIndex);
end

function CUPOLE_TAB_CHANGE(parent, ctrl, argStr, argNum)
    CUPOLE_TOP_TAB_CHANGE(parent, ctrl, argStr, argNum);
end

--큐폴 탭 전환 처리
function CUPOLE_TAB_VIEW(frame, curtabIndex)
    CLOSE_RELEATIVE_FRAMES()

    local parent = frame:GetTopParentFrame();
    local manageBG = frame:GetChild("manageBG")
    local gachaBG = frame:GetChild("gachaBG")
    local pickUpBG = frame:GetChild("pickUpBG")
    local pickupSelectBG = GET_CHILD_RECURSIVELY(frame, "pickupSelectBG")

    local Sel_Btn = GET_CHILD_RECURSIVELY(frame,"SelectBtn")
    local Dis_Btn = GET_CHILD_RECURSIVELY(frame,"DisableBtn")
    local filtergbox = GET_CHILD_RECURSIVELY(frame,"filtergbox")

    local equip_cupole_list = GET_EQUIP_CUPOLE_LIST()
    local State, ChoosCupoleIndex, SlotIndex = GET_CHOOSE_INIT_CUPOLE(equip_cupole_list);
    REMOVE_ALL_CUPOLE_UIMODEL();

    pickupSelectBG:SetUserValue("CURRENT_GACHA_NAME", "None");


    if curtabIndex == 0 then
        manageBG:ShowWindow(1)
        Sel_Btn:ShowWindow(1);
        Dis_Btn:ShowWindow(1);
        filtergbox:ShowWindow(1);   
        gachaBG:ShowWindow(0);
        pickUpBG:ShowWindow(0);
        parent:SetUserValue("Global_Select_Cupole", ChoosCupoleIndex);
        SET_SELECT_CUPOLE_INFORMATION(parent, ChoosCupoleIndex);
        KUPOLE_UIMODEL_IN_MAINCHARACTER(ChoosCupoleIndex)
        SET_SELECT_CUPOLE_NAME(parent, ChoosCupoleIndex)
        TOGGLE_CUPOLE_SPECIAL_ADDON(parent, ChoosCupoleIndex)
        CHECK_ILLUSTRATION_MODE(parent);
        CHNAGE_ALL_CUPOLE_UIMODEL_STATE(1)
        local rightView = parent:GetUserIValue("CUPOLE_RIGHT_VIEW");
        CUPOLE_RIGHT_VIEW_CHANGE(parent, nil, "", rightView);
    elseif curtabIndex == 1 then
        manageBG:ShowWindow(0)
        Sel_Btn:ShowWindow(0);
        Dis_Btn:ShowWindow(0);
        filtergbox:ShowWindow(0);
        gachaBG:ShowWindow(0);
        pickUpBG:ShowWindow(1);
        OPEN_CUPOLE_PICKUP_TAB();
        CHNAGE_ALL_CUPOLE_UIMODEL_STATE(0)
        SET_CUPOLE_GACHA_COLOR(frame)
    end
    ON_SET_EQUIP_CUPOLE_OPTIONS(frame)
    LBTNUP_RESET_CUPOLE_SELECT_MODE(frame);
    SET_BACKGROUND_IMAGE_BY_SELECT_TAB(frame, curtabIndex)
end

--필터 on 버튼
function CUPOLE_FILTER_BTN(parent, ctrl, argStr, argNum)
    ui.ToggleFrame("cupole_filter")
    local frame = parent:GetTopParentFrame();
    if GET_CUPOLE_PRESET_EDIT_INDEX(frame) <= 0 then
        RESET_CUPOLE_SELECT_MODE(frame)
    end
end

function CUPOLE_UIMODEL_ROTATE_BTN(parent, ctrl, argStr, argNum)
    if argNum == 0 then
        CHANGE_CUPOLE_UIMODEL_FIX_DIR(-45)
    else
        CHANGE_CUPOLE_UIMODEL_FIX_DIR(45)
    end
end
---------------------- btn script end





-----------------setter- ---------------------------

---------------------------------------------------
function UPDATE_CUPOLE(frame)
    frame:Invalidate();
    return 1;
end

function SET_KUPOLE_RTT_IMAGE_SIZE(ImageFrame, index)
    local mainFrame = ImageFrame:GetTopParentFrame();
    local SzX = mainFrame:GetUserConfig("DefaultSzX")
    local SzY = mainFrame:GetUserConfig("DefaultSzY")

    local DefRatioY = mainFrame:GetUserConfig("DefaultRatioY")
    local DefRatioX = mainFrame:GetUserConfig("DefaultRatioX")
    
    local RatioY = mainFrame:GetUserConfig("RatioY")
    local RatioX = mainFrame:GetUserConfig("RatioX")
    local numindex =  tonumber(index);

    if numindex == 33 then
        SzX = SzX * RatioX
        SzY = SzY * RatioY
    else
        SzX = SzX * DefRatioX
        SzY = SzY * DefRatioY
    end

    ImageFrame:Resize(SzX, SzY);
end

----maincharater 큐폴 설정 
function GET_CUPOLE_MAIN_PREVIEW(frame)
    frame = frame or ui.GetFrame("cupole_item")
    if frame == nil then return nil end
    local control = GET_CHILD_RECURSIVELY_NAME(frame, "managerTab/manageBG/MainCharacter")
    if control == nil then return nil end
    return tolua.cast(control, "ui::CModelPreview")
end

-- Both views use the same private actor setup; their framing stays in XML.
function SET_CUPOLE_PREVIEW_MODEL(control, index, frame, prefix)
    local cls = GET_CUPOLE_BY_INDEX_IN_CLASSLIST(index)
    if cls == nil then
        control:ClearModel()
        return
    end
    local modelClass = cls.ClassName .. "_Render"
    local monster = GetClass("Monster", modelClass)
    -- Camera values use the main RTT actor units, including RenderOffset.
    local scale = math.max(0.01, TryGetProp(monster, "Scale", 1) * TryGetProp(cls, "Scale", 1)
        * tonumber(frame:GetUserConfig(prefix .. "ACTOR_SCALE")))
    local offset = StringSplit(TryGetProp(cls, "RenderOffset", "0;0;0"), ";")
    local cameraHeight = tonumber(frame:GetUserConfig(prefix .. "HEIGHT_" .. cls.ClassName))
        or tonumber(frame:GetUserConfig(prefix .. "HEIGHT"))
    local cameraDistance = tonumber(frame:GetUserConfig(prefix .. "DISTANCE_" .. cls.ClassName))
        or tonumber(frame:GetUserConfig(prefix .. "DISTANCE"))
    local height = (cameraHeight - (tonumber(offset[2]) or 0)) / scale
    local distance = cameraDistance / scale
    if tonumber(index) == 33 then
        distance = distance / tonumber(frame:GetUserConfig("RatioY"))
    end
    SET_KUPOLE_RTT_IMAGE_SIZE(control, index)
    control:SetModel(modelClass)
    control:SetOrthographic(tonumber(frame:GetUserConfig(prefix .. "ORTHOGRAPHIC")) == 1)
    control:SetCamera(height, distance, tonumber(frame:GetUserConfig(prefix .. "LATITUDE")))
    control:SetModelScale(1)
    control:SetDirection(tonumber(frame:GetUserConfig(prefix .. "DIRECTION")))
    control:PlayAnimation("STD", true, 1)
end

function KUPOLE_UIMODEL_IN_MAINCHARACTER(index)
    local frame = ui.GetFrame("cupole_item")
    local control = GET_CUPOLE_MAIN_PREVIEW(frame)
    if control == nil then return end
    SET_CUPOLE_PREVIEW_MODEL(control, index, frame, "MAIN_PREVIEW_")
    RESET_CUPOLE_UIMODEL_FIX_DIR()
end

function KUPOLE_UIMODEL_IN_GACHA_RESULT(frame, index)
    local control = GET_CHILD_RECURSIVELY_NAME(frame, "Gacha_GroupBox/Gacha_FrontFrameBox/Character")
    if control == nil then return end
    control = tolua.cast(control, "ui::CModelPreview")
    SET_CUPOLE_PREVIEW_MODEL(control, index, frame:GetTopParentFrame(), "GACHA_PREVIEW_")
end

function GET_CUPOLE_PICKUP_PREVIEW(frame)
    frame = frame or ui.GetFrame("cupole_pickup")
    if frame == nil then return nil end
    local control = GET_CHILD_RECURSIVELY_NAME(frame, "managerTab/manageBG/MainCharacter")
    if control == nil then return nil end
    return tolua.cast(control, "ui::CModelPreview")
end

function KUPOLE_UIMODEL_IN_PICKUP(frame, index)
    frame = frame or ui.GetFrame("cupole_pickup")
    local control = GET_CUPOLE_PICKUP_PREVIEW(frame)
    if control == nil then return end
    index = tonumber(index) or GET_CURRENT_CUPOLE_SELECT_INDEX()
    if index == nil or index < 0 then
        control:ClearModel()
        return
    end
    SET_CUPOLE_PREVIEW_MODEL(control, index, frame, "PICKUP_PREVIEW_")
end


---uimodel 생성
function CREATE_CUPOLE_UIMODEL(index, isMainCharacter)
    local monName = GET_CUPOLE_NAME_BY_INDEX(index)
    local cupole_info = GET_CUPOLE_BY_INDEX_IN_CLASSLIST(index);
    if cupole_info == nil then
        return nil, nil;
    end
    if monName == "None" or monName == nil then
        return;
    end
    local Scale = TryGetProp(cupole_info, "Scale", 1)
    local FixSize = 1
    local ui_model = monName.."_Render";
    local ownerHandle = session.GetMyHandle();
    local ownerActor = world.GetActor(ownerHandle);
	local monActor_uimodel = ownerActor:GetClientMonster():GetClientMonsterByName(ui_model);
    local numindex = tonumber(index);
    local posy = 100
    if isMainCharacter == true then
        -- if numindex == 33 then
        --     FixSize = 3.5
        --     posy = 10
        -- else
            FixSize = 3
            posy = 100
        -- end
    else
        if numindex == 33 then
            posy = 10
        else
            posy = 100
        end
    end
	if monActor_uimodel == nil then
		local ownerPos = ownerActor:GetPos();
		ownerActor:GetClientMonster():ClientMonsterToPosUIModel(ui_model, "STD", ownerPos.x, ownerPos.y, ownerPos.z, 0, 0, FixSize * Scale);
		monActor_uimodel = ownerActor:GetClientMonster():GetClientMonsterByName(ui_model);
        if monActor_uimodel ~= nil then
            local monHandle = monActor_uimodel:GetHandleVal();
            FixUIModelToActor(monHandle, ownerHandle, "None", 0, posy, 0, 1, 0, -1);
            StartCupoleAnimation(monHandle, ownerHandle);
        end
	end
    if isMainCharacter == true then
        SetForceCupoleRTTOffsetIndex(ownerHandle, ui_model, 0)
    end
    SetHideUIModel(ownerHandle, ui_model, false);
    return ownerHandle, ui_model;
end


----uimodel 제거
function HIDE_CUPOLE_UIMODEL(index)
    local monName = GET_CUPOLE_NAME_BY_INDEX(index)
    if monName == "None" or monName == nil then
        return;
    end
    local ownerHandle = session.GetMyHandle();
	local ownerActor = world.GetActor(ownerHandle);
    local ui_model = monName.."_Render";
	local monActor_uimodel = ownerActor:GetClientMonster():GetClientMonsterByName(ui_model);
	if monActor_uimodel ~= nil then
        SetHideUIModel(ownerHandle, ui_model, true);
    end
end

function CHNAGE_CUPOLE_UIMODEL_STATE(index, state)
    local monName = GET_CUPOLE_NAME_BY_INDEX(index)
    if monName == "None" or monName == nil then
        return;
    end
    local ownerHandle = session.GetMyHandle();
	local ownerActor = world.GetActor(ownerHandle);
    local ui_model = monName.."_Render";
	local monActor_uimodel = ownerActor:GetClientMonster():GetClientMonsterByName(ui_model);
    local scale = 1;

    if state == 0 then
        scale = 1;
    elseif state == 1 then
        scale = 3;
    elseif state == 2 then
        scale = 2;
    end

    if monActor_uimodel ~= nil then
        monActor_uimodel:ChangeScale(scale, 0, true);
    end
end

function CHNAGE_ALL_CUPOLE_UIMODEL_STATE(State)
    local cupole_list, cnt = GetClassList("cupole_list");
    for i = 0, cnt - 1 do
        CHNAGE_CUPOLE_UIMODEL_STATE(i, State);
    end
end

function CHANGE_CUPOLE_UIMODEL_FIX_DIR(degrees)
    local frame = ui.GetFrame("cupole_item")
    local control = GET_CUPOLE_MAIN_PREVIEW(frame)
    if control == nil then return end
    local direction = (frame:GetUserIValue("MAIN_PREVIEW_DIRECTION") + degrees) % 360
    frame:SetUserValue("MAIN_PREVIEW_DIRECTION", direction)
    control:SetDirection(direction)
end

function RESET_CUPOLE_UIMODEL_FIX_DIR()
    local frame = ui.GetFrame("cupole_item")
    local control = GET_CUPOLE_MAIN_PREVIEW(frame)
    if control == nil then return end
    local direction = tonumber(frame:GetUserConfig("MAIN_PREVIEW_DIRECTION"))
    frame:SetUserValue("MAIN_PREVIEW_DIRECTION", direction)
    control:SetDirection(direction)
end

---큐폴 UI내에서 보유중인 돈 표시
function CUPOLE_ITEM_MONEY_SET(frame)
    local invenZeny = GET_CHILD_RECURSIVELY_NAME(frame,"managerTab/moneyGbox/invenZeny")
    local premiumTP = GET_CHILD_RECURSIVELY_NAME(frame,"managerTab/medalGbox_2/premiumTP")
    if invenZeny == nil or premiumTP == nil then
        return;
    end
	local accountObj = GetMyAccountObj();
    if accountObj == nil then
        return;
    end
    local silverAmountStr = GET_TOTAL_MONEY_STR();
    invenZeny:SetTextByKey("medal", GET_COMMAED_STRING(silverAmountStr));
	premiumTP:SetTextByKey("medal", tostring(accountObj.GiftMedal + accountObj.PremiumMedal + accountObj.Medal));
end

---큐폴 장착버튼 누를 시 특정 ui비활성화 
function CUPOLE_SELECT_MODE(frame, hittest, color, custom_ignore_list)
    if frame == nil then
        frame = ui.GetFrame("cupole_item");
    end
    local managerTab = GET_CHILD(frame, "managerTab")
    local manageBG = GET_CHILD(managerTab, "manageBG")
    local InfoBG = GET_CHILD(manageBG, "InfoBG")
    local slotsetBG = GET_CHILD(manageBG, "slotsetBG")

    local ignore_list = {
        "managerTab", "SlotBG", "slotsetBG", "manageBG" , "cupole_manager_top"
    }
    SELECT_FRAME_CHANGE_STATE(frame, ignore_list, hittest, color);
    SELECT_FRAME_CHANGE_STATE(managerTab, ignore_list, hittest, color);
    SELECT_FRAME_CHANGE_STATE(InfoBG, ignore_list, hittest, color);
    SELECT_FRAME_CHANGE_STATE(slotsetBG, custom_ignore_list, hittest, color);
end

----해당 UI와 하위 자식을 비활성화 처리한다.
function SELECT_FRAME_CHANGE_STATE(frame, ignore_list, HitTestEnable, ColorTone)
    local MainFrameChildCount = frame:GetChildCount()
    for i = 0 , MainFrameChildCount -1 do
        local childframe = frame:GetChildByIndex(i)
        local IsIgnoreFrame = false;
        if ignore_list ~= nil then
            for k,v in pairs(ignore_list) do
                if v == childframe:GetName() then
                    IsIgnoreFrame = true;
                end
            end
        end
        if IsIgnoreFrame == false then
            childframe:EnableHitTest(HitTestEnable);
            FRAME_COLOR_CHANGE(childframe, ColorTone);
        end
    end
end

---큐폴 선택 상태 해체
function LBTNUP_RESET_CUPOLE_SELECT_MODE(parent, ctrl, argStr, argNum)
    local frame = parent:GetTopParentFrame();
    if GET_CUPOLE_PRESET_EDIT_INDEX(frame) > 0 then
        return;
    end
    RESET_CUPOLE_SELECT_MODE(frame)
end

---큐폴 선택 상태 해체
function RESET_CUPOLE_SELECT_MODE(frame)
    local grand_parent = frame:GetTopParentFrame();
    local rightslotset = GET_CHILD_RECURSIVELY(frame, "slotsetBG")
    local SlotBG = GET_CHILD_RECURSIVELY(frame, "SlotBG")
    local gb_slot = GET_CHILD(SlotBG, "gb_slot")
    local SelectBtn = GET_CHILD_RECURSIVELY(frame,"SelectBtn");
    --색 제거
    FRAME_CHILD_COLORTONE_CLEAR(gb_slot)
    FRAME_CHILD_COLORTONE_CLEAR(rightslotset)

    --비활성화 제거
    CUPOLE_SELECT_MODE(frame, 1, "FFFFFFFF");
    CHANGE_DISABLE_BTN_SHOWSTATE(0);

    --선택 모드 종료
    gb_slot:SetUserValue("LEFT_SEL_SLOT","None");
    gb_slot:SetUserValue("RIGHT_SEL_SLOT","None");
    SET_CUPOLE_SELECT_BTN(SelectBtn,"None","equipment");
    SET_CUPOLE_BTN_CITY(grand_parent)

    RESET_LEFT_CUPOLE_SLOTSET(grand_parent);
    RESET_RIGHT_CUPOLE_SLOTSET(grand_parent);

end

----해체 버튼 상태 조절.
function CHANGE_DISABLE_BTN_SHOWSTATE(ShowState, SlotName, CupoleIndex)
    local fraem = ui.GetFrame("cupole_item")
    local DisableBtn = GET_CHILD_RECURSIVELY(fraem, "DisableBtn");
    local Numberindex = tonumber(CupoleIndex)
    DisableBtn:ShowWindow(ShowState);
    if ShowState == 1 then
        DisableBtn:SetEventScript(ui.LBUTTONUP, "SELECT_CUPOLE_UNEQUIP");
    else
        DisableBtn:SetEventScript(ui.LBUTTONUP, "None");
    end
    if SlotName ~= nil then
        DisableBtn:SetEventScriptArgString(ui.LBUTTONUP, SlotName);
    end
    if Numberindex ~= nil then
        DisableBtn:SetEventScriptArgNumber(ui.LBUTTONUP, Numberindex);
    end

end


----마우스 오버 시 애니메이션 관련 함수

function SET_MOUSE_OVER_COLOR_CHNAGE_FUNC(frame)
    local btn = GET_CHILD(frame, "btn")

    btn:SetEventScript(ui.MOUSEON, "MOUSE_OVER_COLOR_CHANGE")
    btn:SetEventScript(ui.MOUSEOFF, "MOUSE_OUT_COLOR_CHANGE")

end

function TOGGLE_CUPOLE_RANKUP_BTN(frame)
    local btn = GET_CHILD(frame, "btn")

    local index = GET_GLOBAL_SELECT_CUPOLE();
    local cls = GET_CUPOLE_CLASS_BY_INDEX(index);
    local grade = TryGetProp(cls, "Grade", "None");
    local rank = GET_CUPOLE_RANK(nil, index)
    local maxrank = shared_cupole.get_max_friendly(grade)
    if maxrank == rank or rank < 1 then
        btn:ShowWindow(0);
        frame:ShowWindow(0);
    else
        btn:ShowWindow(1);
        frame:ShowWindow(1);
    end

end

function MOUSE_OVER_COLOR_CHANGE(frame, ctrl, argStr, argNum)
    CHANGE_BTN_COLOR_WITH_FRAME(frame,"FFFFCC33")
end

function MOUSE_OUT_COLOR_CHANGE(frame, ctrl, argStr, argNum)
    CHANGE_BTN_COLOR_WITH_FRAME(frame,"FFFFFFFF")
end

function CHANGE_BTN_COLOR_WITH_FRAME(frame, color)
    FRAME_COLOR_CHANGE(frame, color)
    local btn = GET_CHILD_RECURSIVELY(frame,"btn")
    if btn ~= nil then
        FRAME_COLOR_CHANGE(btn, color)
    end
end

function FRAME_COLOR_CHANGE(frame, color)
    if frame == nil then
        return;
    end
    frame:SetColorTone(color);
end 


----마우스 오버 시 애니메이션 관련 함수

function CHECK_ILLUSTRATION_MODE(frame, ctrl, argStr, argNum)
    if frame == nil then
        return;
    end
    local TopParent = frame:GetTopParentFrame();
    if TopParent == nil then
        return;
    end
    if ctrl == nil then
        ctrl = GET_CHILD_RECURSIVELY_NAME(TopParent, "managerTab/manageBG/InfoBG/OptionBG/illustration") 
    end
    if ctrl == nil then
        return;
    end
    local manageBG = GET_CHILD_RECURSIVELY_NAME(TopParent,"managerTab/manageBG")
    local spinepic = GET_CHILD_RECURSIVELY_NAME(TopParent,"managerTab/manageBG/spinepic")
    local MainCharacter = GET_CHILD_RECURSIVELY_NAME(TopParent,"managerTab/manageBG/MainCharacter")

    local index = GET_GLOBAL_SELECT_CUPOLE();
    local cls = GET_CUPOLE_CLASS_BY_INDEX(index)
    if cls == nil then
        return;
    end
    local illustrationName = TryGetProp(cls, "ClassName", "None")
    local illustrationMode = TryGetProp(cls, "IluustrationMode", "None")
    if illustrationMode == "NO" then
        spinepic:ShowWindow(0);
        MainCharacter:ShowWindow(1);
        ctrl:ShowWindow(0);
        return;
    end
    ctrl:ShowWindow(1);
    if ctrl:IsChecked() == 1 then
        CUPOLE_SPINE_ANIMAITON_SET(manageBG, illustrationName)
        spinepic:ShowWindow(1);
        MainCharacter:ShowWindow(0);
    else
        spinepic:ShowWindow(0);
        MainCharacter:ShowWindow(1);
    end
end

function CUPOLE_SPINE_ANIMAITON_SET(frame, name)
    local spinepic = GET_CHILD(frame, "spinepic")
    local spineInfo = geSpine.GetSpineInfo(name);
    if spineInfo ~= nil then
        spinepic:SetScaleFactor(spineInfo:GetScaleFactor());
        spinepic:CreateSpineActor(spineInfo:GetRoot(), spineInfo:GetAtlas(), spineInfo:GetJson(), "", spineInfo:GetAnimation(), spineInfo:GetIsPremultiplied());
        spinepic:SetIsStopAnim(false)
    end	
end

function SET_FAVORITE_CUPOLE(parent, ctrl, argStr, argNum)
    local TopParent = parent:GetTopParentFrame();
    local cupoleindex = GET_GLOBAL_SELECT_CUPOLE();

    if CHECK_CUPOLE_WITHOUT_EQUIP(nil, cupoleindex) == false then
        return;
    end

    local isFavorite = IsFavoriteCupole(cupoleindex)
    SetFavoriteCupole(cupoleindex, not isFavorite);
    SET_CUPOLE_FAVORITE_ICON_STATE(ctrl, not isFavorite);
    SET_CUPOLE_LIST(TopParent)
end

function SET_CUPOLE_FAVORITE_ICON_STATE(frame, state)
    if state == true then
        frame:SetImage("favorite_active")
    else
        frame:SetImage("favorite_inactive")
    end
end

function TOGGLE_CUPOLE_SPECIAL_ADDON(frame, index)
    local cupole_addon = ui.GetFrame("cupole_addon")
    local cls = GET_CUPOLE_CLASS_BY_INDEX(index)
    local Special = TryGetProp(cls, "Special", "None")

    local PotionBG = GET_CHILD_RECURSIVELY(frame, "PotionBG")
    cupole_addon:ShowWindow(0);

    if Special == "None" or not Special then
        PotionBG:ShowWindow(0);
    else
        PotionBG:ShowWindow(1);
    end
end

function CLOSE_RELEATIVE_FRAMES()
    local filter = ui.CloseFrame("cupole_filter")
    local addon = ui.CloseFrame("cupole_addon")
end

function TOGGLE_POTION_AUTO_USE(parent, ctrl, argStr, argNum)
    if IS_IN_CITY() == 1 then
        return;
    end
    local player = GetMyPCObject();
    if player == nil then
        return ; 
    end
    local value = GetExProp(player, "cupole_auto_potion");
    -- SET_POTION_TOGGLE_STATE(parent, value)
    local external_addon = ui.GetFrame("cupole_external_addon")
    local cupole_item = ui.GetFrame("cupole_item")
    SET_POTION_TOGGLE_STATE(external_addon, value)
    SET_POTION_TOGGLE_STATE(cupole_item, value)

    pc.ReqExecuteTx_Item("CUPOLE_PORITON_AUTO_USE_TOGGLE", 0, 0)
end

function ON_GACHA_RESULT_APPLY_IN_CUPOLE_UI(frame, msg, argStr, argNum)
    CUPOLE_FILTER_SELECT_RESET(frame)
end

function statsortfunc(left, right)
    return stat_sort_value[left[1]] > stat_sort_value[right[1]]
end

function dumptable(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k ='"'..k..'"'
            end
            s = s  .. '['..k..']'..dumptable(v)..','
        end
        return s..'}'
    end
    return tostring(o)
end

function RBTN_CUPOLE_ITEM_EQUIP(parent, ctrl, argStr, argNum)
    RBTN_CUPOLE_EQUIP(parent, ctrl, argNum)
end

function RBTN_CUPOLE_ITEM_PROGRESS(parent, ctrl, argStr, argNum)
    SELECT_CUPOLE_UNEQUIP(parent, ctrl, argStr, argNum)
end

function SET_POTION_TOGGLE_STATE(frame, value)
    local PotionToggle = GET_CHILD_RECURSIVELY(frame, "PotionToggle")
    if value == 0 then
        PotionToggle:SetImage("potionhudon")
    else
        PotionToggle:SetImage("potionhudoff")
    end
end