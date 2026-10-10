function ARCHEOLOGY_EXHIBITION_ON_INIT(addon, frame)
    addon:RegisterMsg("ARCHEOLOGY_EXHIBITION_ADD_ITEM", "ON_ARCHEOLOGY_EXHIBITION_ADD_ITEM")
    addon:RegisterMsg("ARCHEOLOGY_EXHIBITION_DELETE_ITEM", "ON_ARCHEOLOGY_EXHIBITION_DELETE_ITEM")
    addon:RegisterMsg("ARCHEOLOGY_EXHIBITION_UPDATE_AMPLIFIER", "ON_ARCHEOLOGY_EXHIBITION_UPDATE_AMPLIFIER")
    addon:RegisterMsg("CLEAR_ALL_EXHIBTTION_SLOT", "ON_CLEAR_ALL_EXHIBTTION_SLOT")
    addon:RegisterMsg("UPDATE_EXHIBITION_RANK", "ON_UPDATE_EXHIBITION_RANK")
end

-- 기존 숫자 자리만 강조하며 라벨·게이지·게임 수치는 바꾸지 않는다.
local function ARCHEOLOGY_EXHIBITION_LEVEL_NUMBER(frame, value)
    if frame:GetUserIValue("ARC_LEVEL_HIGHLIGHT") == 1 then
        return "{#f5d76e}" .. tostring(value) .. "{/}"
    end
    return value
end

local function ARCHEOLOGY_EXHIBITION_CAN_OPEN_IN_TOWN()
    -- 마을과 개인 하우징(고고학 전시대 가구)에서 연다. 서버 전시 TX 도 같은 판정을 쓴다.
    local mapProp = session.GetCurrentMapProp()
    local mapCls = mapProp ~= nil and GetClassByType("Map", mapProp.type) or nil
    if mapCls ~= nil and IS_ARCHEOLOGY_EXHIBITION_MAP(mapCls.ClassName) == true then return true end
    ui.SysMsg(ClMsg("ARCHEOLOGY_EXHIBITION_ALLOWED_PLACE"))
    return false
end

function OPEN_ARCHEOLOGY_EXHIBITION_UI(frame)
    if ARCHEOLOGY_EXHIBITION_CAN_OPEN_IN_TOWN() ~= true then return end
    ui.OpenFrame("archeology_exhibition")
end

function ARCHEOLOGY_EXHIBITION_OPEN(frame)
    if ARCHEOLOGY_EXHIBITION_CAN_OPEN_IN_TOWN() ~= true then
        frame:SetUserValue("ARC_BLOCKED_OPEN", 1)
        ui.CloseFrame("archeology_exhibition")
        return
    end
    frame:SetUserValue("ARC_BLOCKED_OPEN", 0)
    ARCHEOLOGY_EXHIBITION_RESET_LEVEL_HIGHLIGHT(frame)
    EXHIBITION_RANKUP_CANCEL()
    CREATE_ARCHEOLOGY_EXHIBITION_LIST(frame)
    CREATE_ARCHEOLOGY_AMPLIFIER_SLOT(frame)
    UPDATE_AMPLIFIER_SLOT(frame)
    UPDATE_EXHIBITION_COST_TEXT(frame)
    UPDATE_EXHIBITION_EFFECT_TEXT(frame)
    SET_EXP_TEXT(frame)

    ui.OpenFrame("inventory")
    ARCHEOLOGY_EXHIBITION_LAYOUT_INVENTORY()
    ReserveScript("ARCHEOLOGY_EXHIBITION_LAYOUT_INVENTORY()", 0.1)
    INVENTORY_PUSH_CUSTOM_RBTNDOWN(frame, "INSERT_ARCHEOLOGY_EXHIBITION_ITEM_RBTN")
    pc.ReqExecuteTx_Item("ARC_OPEN_LOGGING", "")
end

-- 인벤토리는 기본 위치에 두고, PIP 열기가 끝나면 전시대만 그 왼쪽에 배치한다.
function ARCHEOLOGY_EXHIBITION_LAYOUT_INVENTORY()
    local frame = ui.GetFrame("archeology_exhibition")
    local inventory = ui.GetFrame("inventory")
    if frame == nil or frame:IsVisible() == 0 or inventory == nil or inventory:IsVisible() == 0 then return end
    if inventory:IsPIPMoving() == 1 then
        ReserveScript("ARCHEOLOGY_EXHIBITION_LAYOUT_INVENTORY()", 0.1)
        return
    end
    local gap = 12
    local left = math.max(0, inventory:GetX() - frame:GetWidth() - gap)
    frame:SetOffset(left,
        math.max(0, (ui.GetClientInitialHeight() - frame:GetHeight()) / 2))
end

function ARCHEOLOGY_EXHIBITION_CLOSE(frame)
    ARCHEOLOGY_EXHIBITION_RESET_LEVEL_HIGHLIGHT(frame)
    if frame:GetUserIValue("ARC_BLOCKED_OPEN") == 1 then
        frame:SetUserValue("ARC_BLOCKED_OPEN", 0)
        return
    end
    EXHIBITION_RANKUP_CANCEL()
    ui.EnableSlotMultiSelect(0)
    ui.CloseFrame("inventory")
    INVENTORY_POP_CUSTOM_RBTNDOWN(frame, "INSERT_ARCHEOLOGY_EXHIBITION_ITEM_RBTN")
end

local function REFRESH_ARCHEOLOGY_EXHIBITION_FRAME(frame)
    if frame == nil then
        return
    end

    CREATE_ARCHEOLOGY_EXHIBITION_LIST(frame)
    CREATE_ARCHEOLOGY_AMPLIFIER_SLOT(frame)
    UPDATE_AMPLIFIER_SLOT(frame)
    UPDATE_EXHIBITION_COST_TEXT(frame)
    UPDATE_EXHIBITION_EFFECT_TEXT(frame)
    SET_EXP_TEXT(frame)
end

function ARCHEOLOGY_EXHIBITION_RESERVED_REFRESH()
    local frame = ui.GetFrame("archeology_exhibition")
    if frame == nil or frame:IsVisible() == 0 then
        return
    end

    -- 랭크 알림보다 계정 EXP 갱신이 늦은 경우도 기존 예약 갱신에서 확인한다.
    ARCHEOLOGY_EXHIBITION_CHECK_LEVEL_HIGHLIGHT(frame)
    REFRESH_ARCHEOLOGY_EXHIBITION_FRAME(frame)
    frame:SetUserValue("ARC_LEVEL_HIGHLIGHT_PENDING", 0)
end

local function RESERVE_ARCHEOLOGY_EXHIBITION_REFRESH()
    ReserveScript("ARCHEOLOGY_EXHIBITION_RESERVED_REFRESH()", 0.2)
end

local function ARC_EXHIBIT_MSG(key)
    return ClMsg(key)
end

local function ARC_EXHIBIT_ARG_MSG(key, ...)
    return ScpArgMsg(key, ...)
end

local function GET_RARITY_TEXT_STYLE(rarity)
    if rarity == "Rare" then
        return ARC_EXHIBIT_ARG_MSG("ARCHEOLOGY_COLORED_TEXT{COLOR}{TEXT}",
            "COLOR", "e3c35b", "TEXT", ARC_EXHIBIT_MSG("ARC_EXHIBIT_RARITY_RARE"))
    end
    if rarity == "Magic" then
        return ARC_EXHIBIT_ARG_MSG("ARCHEOLOGY_COLORED_TEXT{COLOR}{TEXT}",
            "COLOR", "6fb8ff", "TEXT", ARC_EXHIBIT_MSG("ARC_EXHIBIT_RARITY_MAGIC"))
    end
    if rarity == "Normal" then
        return ARC_EXHIBIT_ARG_MSG("ARCHEOLOGY_COLORED_TEXT{COLOR}{TEXT}",
            "COLOR", "d7d0c4", "TEXT", ARC_EXHIBIT_MSG("ARC_EXHIBIT_RARITY_NORMAL"))
    end

    return ARC_EXHIBIT_ARG_MSG("ARCHEOLOGY_COLORED_TEXT{COLOR}{TEXT}",
        "COLOR", "d7d0c4", "TEXT", ARC_EXHIBIT_MSG("ARC_EXHIBIT_INFO_NONE"))
end

local function GET_RARITY_FROM_EXHIBITION_CLASS(exCls)
    if exCls == nil then
        return "Normal"
    end

    local rarity = TryGetProp(exCls, "Rarity", "None")
    if rarity ~= "None" and rarity ~= "" then
        return rarity
    end

    local itemName = TryGetProp(exCls, "ClassName", "")
    if string.find(itemName, "_R$") ~= nil then
        return "Rare"
    end
    if string.find(itemName, "_M$") ~= nil then
        return "Magic"
    end

    return "Normal"
end

local ARCEX_EFFECT_CATEGORY_INFO = {
    Arch = {
        messageKey = "ARC_EXHIBIT_CATEGORY_ARCH",
        sortWeight = 10,
    },
    Combat = {
        messageKey = "ARC_EXHIBIT_CATEGORY_COMBAT",
        sortWeight = 20,
    },
    Special = {
        messageKey = "ARC_EXHIBIT_CATEGORY_SPECIAL",
        sortWeight = 30,
    },
}

function GET_ARCHEOLOGY_EXHIBITION_EFFECT_CATEGORY_KEY(effectName)
    local rule = shared_archeology ~= nil and
        shared_archeology.get_option_stat_rule ~= nil and
        shared_archeology.get_option_stat_rule(effectName) or nil
    if rule == nil then
        return "Combat"
    end

    if rule.optionRole == "Exploration" then
        return "Arch"
    end
    if rule.effectCategory == "Special" then
        return "Special"
    end
    return "Combat"
end

local function GET_EFFECT_CATEGORY_INFO(effectName)
    local categoryKey = GET_ARCHEOLOGY_EXHIBITION_EFFECT_CATEGORY_KEY(effectName)
    return ARCEX_EFFECT_CATEGORY_INFO[categoryKey] or ARCEX_EFFECT_CATEGORY_INFO.Combat
end

local function GET_EFFECT_CATEGORY(effectName)
    return ARC_EXHIBIT_MSG(GET_EFFECT_CATEGORY_INFO(effectName).messageKey)
end

local function GET_EFFECT_SORT_WEIGHT(effectName)
    local weights = {
        ARCHEOLOGY_RARE_CHANCE = 10,
        ARCHEOLOGY_DETECTING = 20,
        ARCHEOLOGY_COIN_GAIN = 30,
        ARCHEOLOGY_SPECIAL_REWARD = 40,
        ARCHEOLOGY_MON_FIND = 50,
        ARCHEOLOGY_DOUBLE_DROP = 60,
        ARCHEOLOGY_MON_DROP_RATE = 70,
        ARCHEOLOGY_HP_BONUS = 100,
        ARCHEOLOGY_DEF_BONUS = 110,
        ARCHEOLOGY_MDEF_BONUS = 120,
        ARCHEOLOGY_DODGE = 130,
        ARCHEOLOGY_CRIT_RES = 140,
        ARCHEOLOGY_BLOCK_PEN = 150,
        ARCHEOLOGY_HP_ON_KILL = 160,
        ARCHEOLOGY_MOVE_SPEED = 165,
        ARCHEOLOGY_PORTAL_MOVE_SPEED = 166,
        ARCHEOLOGY_DMG_REDUCE = 210,
    }

    return weights[effectName] or 999
end

local function GET_EFFECT_DISPLAY_INFO(effectName, effectValue)
    local fullDescription = GET_ARCHEOLOGY_STAT_DESC(effectName, effectValue)
    local rule = shared_archeology ~= nil and
        shared_archeology.get_option_stat_rule ~= nil and
        shared_archeology.get_option_stat_rule(effectName) or nil
    if rule == nil then
        return fullDescription, "", "", fullDescription
    end

    local effectNameText = ClMsg(rule.displayNameMsg)
    if effectNameText == nil or effectNameText == "" then
        effectNameText = effectName
    end

    local absoluteValue = math.abs(tonumber(effectValue) or 0)
    local effectTypeText = ""
    local effectValueText = ""
    if rule.displayValueMsg ~= nil and rule.displayValueMsg ~= "None" then
        local displayValue = absoluteValue * (tonumber(rule.displayScale) or 1)
        local numberText = string.format("%.2f", displayValue)
        numberText = string.gsub(numberText, "(%..-)0+$", "%1")
        numberText = string.gsub(numberText, "%.$", "")
        -- 직접 확률/확률 증가/수량 증가 꼬리표는 쓰지 않는다. 확률은 %, 증가분은 %p 단위로 구분된다.
        effectValueText = ScpArgMsg(rule.displayValueMsg, "VALUE", numberText)
    else
        local displayFormat = rule.displayFormat ~= nil and
            rule.displayFormat ~= "None" and rule.displayFormat or "+%s"
        effectValueText = string.format(displayFormat, absoluteValue)
    end

    return effectNameText, effectTypeText, effectValueText, fullDescription
end

function ARCHEOLOGY_EXHIBITION_GET_PLAIN_ITEM_NAME(displayName)
    if displayName == nil or displayName == "None" then
        return ""
    end

    local result = tostring(displayName)
    result = string.gsub(result, "{[^}]+}", "")
    result = string.gsub(result, "%s*%[[^%]]+%]%s*", " ")
    result = string.gsub(result, "%s*%([^%)]*%)%s*$", "")
    result = string.gsub(result, "%s+", " ")
    result = string.gsub(result, "^%s+", "")
    result = string.gsub(result, "%s+$", "")
    return result
end

local function GET_SLOT_DISPLAY_NAME(itemCls)
    if itemCls == nil then
        return ""
    end

    local name = TryGetProp(itemCls, "Name", "None")
    if name ~= "None" and name ~= "" then
        return name
    end

    local ctName = TryGetProp(itemCls, "CT_Name", "None")
    if ctName ~= "None" and ctName ~= "" then
        return ctName
    end

    return TryGetProp(itemCls, "ClassName", "")
end

local ARCEX_SLOT_INFO_BY_TYPE = {
    ForgottenGoddess = {
        index = 1,
        nameKey = "ARC_EXHIBIT_SLOT_NAME_FORGOTTEN_GODDESS",
        color = "{#9fd8ff}",
        roleKey = "ARC_EXHIBIT_SLOT_ROLE_FORGOTTEN_GODDESS",
        hintKey = "ARC_EXHIBIT_SLOT_HINT_FORGOTTEN_GODDESS",
    },
    NamelessAncestor = {
        index = 2,
        nameKey = "ARC_EXHIBIT_SLOT_NAME_NAMELESS_ANCESTOR",
        color = "{#d8bd62}",
        roleKey = "ARC_EXHIBIT_SLOT_ROLE_NAMELESS_ANCESTOR",
        hintKey = "ARC_EXHIBIT_SLOT_HINT_NAMELESS_ANCESTOR",
    },
    Unreturned = {
        index = 3,
        nameKey = "ARC_EXHIBIT_SLOT_NAME_UNRETURNED",
        color = "{#ff9b57}",
        roleKey = "ARC_EXHIBIT_SLOT_ROLE_UNRETURNED",
        hintKey = "ARC_EXHIBIT_SLOT_HINT_UNRETURNED",
    },
}

local ARCEX_SLOT_TYPE_BY_INDEX = {
    [1] = "ForgottenGoddess",
    [2] = "NamelessAncestor",
    [3] = "Unreturned",
}

local function GET_ARCEX_SLOT_INFO_BY_INDEX(slotidx)
    return ARCEX_SLOT_INFO_BY_TYPE[ARCEX_SLOT_TYPE_BY_INDEX[tonumber(slotidx) or 0]]
end

local function GET_ARCEX_SLOT_INFO_BY_ITEM_CLASS(itemCls)
    if itemCls == nil then
        return nil
    end

    local familyName = GET_ARCHEOLOGY_RELIC_FAMILY_CLASS_NAME(TryGetProp(itemCls, "ClassName", "None"))
    if familyName == "" then
        return nil
    end

    local baseProfile = shared_archeology.get_base_profile(familyName)
    if baseProfile == nil then
        return nil
    end

    return ARCEX_SLOT_INFO_BY_TYPE[baseProfile.exhibitSlotType or "None"]
end

local function GET_ARCEX_SLOT_INFO_NAME(slotInfo)
    if slotInfo == nil then
        return ""
    end

    return ARC_EXHIBIT_MSG(slotInfo.nameKey or "ARC_EXHIBIT_SLOT_NAME_DEFAULT")
end

local function GET_ARCEX_SLOT_INFO_ROLE(slotInfo)
    if slotInfo == nil then
        return ""
    end

    return ARC_EXHIBIT_MSG(slotInfo.roleKey or "ARC_EXHIBIT_INFO_NONE")
end

local function GET_ARCEX_SLOT_INFO_HINT(slotInfo)
    if slotInfo == nil then
        return ""
    end

    return ARC_EXHIBIT_MSG(slotInfo.hintKey or "ARC_EXHIBIT_INFO_NONE")
end

local function BUILD_ARCEX_SLOT_INFO_TEXT(slotInfo)
    if slotInfo == nil then
        return ""
    end

    return ARC_EXHIBIT_ARG_MSG("ARCHEOLOGY_COLORED_TEXT{COLOR}{TEXT}",
        "COLOR", string.gsub(slotInfo.color, "[{}#]", ""),
        "TEXT", ARC_EXHIBIT_ARG_MSG("ARC_EXHIBIT_SLOT_DISPLAY_FMT",
            "SLOT", GET_ARCEX_SLOT_INFO_NAME(slotInfo), "INDEX", slotInfo.index))
end

local function GET_SLOT_META_TEXT(itemName, arcMeta)
    local exCls = GetClass("archeology_exhibition_item", itemName)
    if exCls == nil then
        return ARC_EXHIBIT_ARG_MSG("ARCHEOLOGY_COLORED_TEXT{COLOR}{TEXT}",
            "COLOR", "d7d0c4", "TEXT", ARC_EXHIBIT_MSG("ARC_EXHIBIT_INFO_NONE"))
    end

    local rarity = GET_RARITY_FROM_EXHIBITION_CLASS(exCls)
    local baseCost, optionBonus, totalCost = GET_ARCHEOLOGY_EXHIBITION_ITEM_COST_DETAIL(exCls, arcMeta)
    local costText = ARC_EXHIBIT_ARG_MSG("ARC_EXHIBIT_COST_FMT", "VALUE", totalCost)
    if optionBonus > 0 then
        costText = ARC_EXHIBIT_ARG_MSG("ARC_EXHIBIT_COST_WITH_BONUS_FMT", "TOTAL", totalCost, "BONUS", optionBonus)
    end
    return ARC_EXHIBIT_ARG_MSG("ARC_EXHIBIT_SLOT_META{RARITY}{COST}",
        "RARITY", GET_RARITY_TEXT_STYLE(rarity), "COST", costText)
end

local function GET_ARCEX_COST_DETAIL_TEXT(itemCls, arcMeta)
    if itemCls == nil then
        return ""
    end

    local baseCost, optionBonus, totalCost = GET_ARCHEOLOGY_EXHIBITION_ITEM_COST_DETAIL(itemCls, arcMeta)
    if optionBonus > 0 then
        return ARC_EXHIBIT_ARG_MSG("ARC_EXHIBIT_COST_DETAIL_FMT", "TOTAL", totalCost, "BASE", baseCost, "BONUS", optionBonus)
    end

    return ARC_EXHIBIT_ARG_MSG("ARC_EXHIBIT_COST_FMT", "VALUE", totalCost)
end

local function CLEAR_SLOT_TOOLTIP(slot)
    if slot == nil then
        return
    end

    slot:SetTooltipType("None")
    slot:SetTooltipArg("", 0, 0)
    slot:SetTooltipNumArg(0)

    local icon = slot:GetIcon()
    if icon == nil then
        return
    end

    icon:SetTooltipType("None")
    icon:SetTooltipArg("", 0, 0)
    icon:SetTooltipNumArg(0)
    icon:SetTooltipOverlap(0)
end

local function BUILD_ARCEX_OPTION_TOOLTIP_TEXT(itemCls, arcPrefix, extraDesc, slotIndex)
    if itemCls == nil then
        return ""
    end

    local lines = {}
    lines[#lines + 1] = ARC_EXHIBIT_ARG_MSG(
        "ARC_EXHIBIT_TOOLTIP_NAME{VALUE}", "VALUE", GET_SLOT_DISPLAY_NAME(itemCls))

    local itemName = TryGetProp(itemCls, "ClassName", "None")
    if itemName ~= "None" then
        lines[#lines + 1] = ARC_EXHIBIT_ARG_MSG(
            "ARC_EXHIBIT_TOOLTIP_META{VALUE}", "VALUE", GET_SLOT_META_TEXT(itemName, arcPrefix))
    end

    local costDetail = GET_ARCEX_COST_DETAIL_TEXT(itemCls, arcPrefix)
    if costDetail ~= "" then
        lines[#lines + 1] = ARC_EXHIBIT_ARG_MSG(
            "ARC_EXHIBIT_TOOLTIP_LINE{VALUE}", "VALUE", costDetail)
    end

    local slotInfo = GET_ARCEX_SLOT_INFO_BY_ITEM_CLASS(itemCls)
    if slotInfo ~= nil then
        lines[#lines + 1] = ARC_EXHIBIT_ARG_MSG(
            "ARC_EXHIBIT_TOOLTIP_SLOT_SECTION{TITLE}{VALUE}",
            "TITLE", ARC_EXHIBIT_MSG("ARC_EXHIBIT_TOOLTIP_SLOT_TITLE"),
            "VALUE", BUILD_ARCEX_SLOT_INFO_TEXT(slotInfo))
        lines[#lines + 1] = ARC_EXHIBIT_ARG_MSG(
            "ARC_EXHIBIT_TOOLTIP_ROLE{VALUE}", "VALUE", GET_ARCEX_SLOT_INFO_ROLE(slotInfo))
    end

    if extraDesc ~= nil and extraDesc ~= "" then
        lines[#lines + 1] = ARC_EXHIBIT_ARG_MSG(
            "ARC_EXHIBIT_TOOLTIP_LINE{VALUE}", "VALUE", extraDesc)
    end

    local optionList = GET_ARCHEOLOGY_OPTION_INFO(arcPrefix)
    if GET_ARCHEOLOGY_EXHIBITION_DISPLAY_OPTION_LIST ~= nil then
        optionList = GET_ARCHEOLOGY_EXHIBITION_DISPLAY_OPTION_LIST(arcPrefix, nil, slotIndex)
    end
    if optionList ~= nil and #optionList > 0 then
        lines[#lines + 1] = ARC_EXHIBIT_ARG_MSG(
            "ARC_EXHIBIT_TOOLTIP_EFFECT_TITLE{TITLE}",
            "TITLE", ARC_EXHIBIT_MSG("ARC_EXHIBIT_EFFECT_TITLE"))
        for _, opt in ipairs(optionList) do
            local effectDesc = GET_ARCHEOLOGY_STAT_DESC(opt.tag, opt.value)
            lines[#lines + 1] = ARC_EXHIBIT_ARG_MSG(
                "ARC_EXHIBIT_TOOLTIP_EFFECT_ROW{VALUE}", "VALUE", effectDesc)
        end
    end

    return table.concat(lines, "")
end

local function SET_TEXTHELP_TOOLTIP(ctrl, text)
    if ctrl == nil then
        return
    end

    ctrl:SetTooltipType("texthelp")
    ctrl:SetTooltipArg(text)
    ctrl:SetTooltipNumArg(0)
    -- 슬롯도 아이콘과 같이 프레임 바깥 대신 해당 컨트롤 가까이에 표시한다.
    ctrl:SetTooltipOverlap(1)
end

local function SET_ARCEX_SLOT_TOOLTIP(slot, itemCls, arcPrefix, extraDesc, slotIndex)
    if slot == nil or itemCls == nil then
        return
    end

    local tooltipText = BUILD_ARCEX_OPTION_TOOLTIP_TEXT(itemCls, arcPrefix, extraDesc, slotIndex)
    if tooltipText == nil or tooltipText == "" then
        return
    end

    SET_TEXTHELP_TOOLTIP(slot, tooltipText)

    local icon = slot:GetIcon()
    if icon == nil then
        return
    end

    SET_TEXTHELP_TOOLTIP(icon, tooltipText)
    icon:SetTooltipOverlap(1)
end

local function GET_EXP_CLASS(level)
    return GetClass("archeology_exhibition_exp", tostring(level))
end

local function GET_EXP_CLASS_COUNT()
    local list, cnt = GetClassList("archeology_exhibition_exp")
    if list == nil or cnt == nil or cnt < 1 then
        return 1
    end

    return cnt
end

local function GET_CURRENT_EXHIBITION_LEVEL()
    local aObj = GetMyAccountObj()
    local total_exp = TryGetProp(aObj, "ARCHEOLOGY_EXP", 0)
    local max_level = GET_EXP_CLASS_COUNT()
    local currentLevel = 1

    for i = 1, max_level do
        local cls = GET_EXP_CLASS(i)
        if cls ~= nil and total_exp >= TryGetProp(cls, "Exp", 0) then
            currentLevel = i
        else
            break
        end
    end

    return currentLevel, total_exp
end

local function GET_REWARD_TEXT(cls)
    if cls == nil then
        return ARC_EXHIBIT_MSG("ARC_EXHIBIT_MAX_RANK_REACHED_REWARD")
    end

    local rewardText = TryGetProp(cls, "RewardText", "None")
    if rewardText ~= nil and rewardText ~= "" and rewardText ~= "None" then
        return rewardText
    end

    return ARC_EXHIBIT_MSG("ARC_EXHIBIT_REWARD_INFO_NONE")
end

local function GET_REWARD_ICON_NAME(cls)
    if cls == nil then
        return "icon_item_event_archeology_coin"
    end

    local rewardItem = TryGetProp(cls, "RewardItem", "None")
    if rewardItem == "None" then
        return "icon_item_event_archeology_coin"
    end

    local itemCls = GetClass("Item", rewardItem)
    if itemCls == nil then
        return "icon_item_event_archeology_coin"
    end

    return TryGetProp(itemCls, "Icon", "icon_item_event_archeology_coin")
end

function CREATE_ARCHEOLOGY_EXHIBITION_LIST(frame)
    local archeology_slot_Gbox = GET_CHILD_RECURSIVELY(frame, "archeology_slot_Gbox")
    local max_list = tonumber(frame:GetUserConfig("MAX_SIZE"))
    local slotlist = { GET_ARCEX_SLOT_ITEMS() }

    for i = 1, max_list do
        local ctrl = archeology_slot_Gbox:GetChild("slot" .. i)
        local itemidx = slotlist[i]
        if ctrl ~= nil then
            AUTO_CAST(ctrl)
            ctrl:SetEventScript(ui.RBUTTONUP, "DELETE_ARCHEOLOGY_EXHIBITION_ITEM_RBTN")
            ctrl:SetEventScriptArgNumber(ui.RBUTTONUP, i)

            local itemSlot = GET_CHILD_RECURSIVELY(ctrl, "archeology_exhibition_slot")
            if itemSlot ~= nil then
                AUTO_CAST(itemSlot)
                itemSlot:EnableDrop(1)
                itemSlot:EnableDrag(0)
                itemSlot:EnablePop(0)
                itemSlot:SetEventScript(ui.RBUTTONUP, "DELETE_ARCHEOLOGY_EXHIBITION_ITEM_RBTN")
                itemSlot:SetEventScriptArgNumber(ui.RBUTTONUP, i)
            end

            if itemidx ~= nil and itemidx > 0 then
                local itemcls = GET_ARCEX_ITEM_BY_CLSID(itemidx)
                local itemclsname = TryGetProp(itemcls, "ClassName", "None")
                UPDATE_EXHIBITION_SLOT_ITEM(frame, i, itemclsname)
            else
                UPDATE_EXHIBITION_SLOT_ITEM(frame, i, nil)
            end
        end
    end
end

function CREATE_ARCHEOLOGY_AMPLIFIER_SLOT(frame)
    local slot = GET_CHILD_RECURSIVELY(frame, "amplifier_slot")
    if slot == nil then
        return
    end

    AUTO_CAST(slot)
    slot:EnableDrop(IS_ARCEX_AMPLIFIER_SLOT_UNLOCKED() == true and 1 or 0)
    slot:EnableDrag(0)
    slot:EnablePop(0)
    slot:SetEventScript(ui.DROP, "INSERT_ARCHEOLOGY_AMPLIFIER_ITEM_DROP")
    slot:SetEventScript(ui.RBUTTONUP, "DELETE_ARCHEOLOGY_AMPLIFIER_ITEM_RBTN")
end

local function GET_ARCHEOLOGY_EXHIBITION_DROP_ITEM_GUID()
    local liftIcon = ui.GetLiftIcon()
    if liftIcon == nil then
        return nil
    end

    local iconInfo = liftIcon:GetInfo()
    if iconInfo == nil then
        return nil
    end

    return iconInfo:GetIESID()
end

function INSERT_ARCHEOLOGY_EXHIBITION_ITEM_BY_DROP_TARGET(frame, itemGuid, targetType)
    local invItem = GET_PC_ITEM_BY_GUID(itemGuid)
    if invItem == nil then
        return false
    end

    local itemObj = GetIES(invItem:GetObject())
    local itemClassName = TryGetProp(itemObj, "ClassName", "None")
    local exhibitionCls = GetClass("archeology_exhibition_item", itemClassName)
    if exhibitionCls == nil then
        return false
    end

    local isAmplifier = GET_ARCEX_ITEM_TYPE(exhibitionCls) == "Amplifier"
    if targetType == "Amplifier" then
        if isAmplifier ~= true then
            return false
        end

        pc.ReqExecuteTx_Item("ARC_EQUIP_AMPLIFIER_ITEM", itemGuid)
        return true
    end

    if targetType ~= "Exhibition" or isAmplifier == true then
        return false
    end

    INSERT_ARCHEOLOGY_EXHIBITION_ITEM(frame, itemGuid)
    return true
end

function INSERT_ARCHEOLOGY_EXHIBITION_ITEM_DROP(parent, ctrl)
    local frame = parent:GetTopParentFrame()
    local itemGuid = GET_ARCHEOLOGY_EXHIBITION_DROP_ITEM_GUID()
    if itemGuid == nil then
        return
    end

    INSERT_ARCHEOLOGY_EXHIBITION_ITEM_BY_DROP_TARGET(frame, itemGuid, "Exhibition")
end

function INSERT_ARCHEOLOGY_AMPLIFIER_ITEM_DROP(parent, ctrl)
    local frame = parent:GetTopParentFrame()
    local itemGuid = GET_ARCHEOLOGY_EXHIBITION_DROP_ITEM_GUID()
    if itemGuid == nil then
        return
    end

    INSERT_ARCHEOLOGY_EXHIBITION_ITEM_BY_DROP_TARGET(frame, itemGuid, "Amplifier")
end

function INSERT_ARCHEOLOGY_EXHIBITION_ITEM_RBTN(itemObj, slot)
    local frame = ui.GetFrame("archeology_exhibition")
    local icon = slot:GetIcon()
    if icon == nil then
        return
    end

    local iconInfo = icon:GetInfo()
    local invItem = GET_PC_ITEM_BY_GUID(iconInfo:GetIESID())
    if invItem == nil then
        return
    end

    local fromFrame = slot:GetTopParentFrame()
    if fromFrame:GetName() == "inventory" then
        INSERT_ARCHEOLOGY_EXHIBITION_ITEM(frame, iconInfo:GetIESID())
    end
end

local function GET_ARCEX_INV_ITEM_OBJECT(itemGuid)
    local invItem = GET_PC_ITEM_BY_GUID(itemGuid)
    if invItem == nil then
        return nil
    end

    return GetIES(invItem:GetObject())
end

local function CHECK_ARCEX_TARGET_SLOT_AVAILABLE(itemGuid)
    local itemObj = GET_ARCEX_INV_ITEM_OBJECT(itemGuid)
    if itemObj == nil then
        return false
    end

    local slotInfo = GET_ARCEX_SLOT_INFO_BY_ITEM_CLASS(itemObj)
    if slotInfo == nil then
        return true
    end

    local slotlist = { GET_ARCEX_SLOT_ITEMS() }
    local equippedItemId = tonumber(slotlist[slotInfo.index]) or 0
    if equippedItemId > 0 then
        ui.SysMsg(ARC_EXHIBIT_ARG_MSG("ARC_EXHIBIT_SLOT_OCCUPIED_FMT", "SLOT", GET_ARCEX_SLOT_INFO_NAME(slotInfo)))
        return false
    end

    return true
end

function INSERT_ARCHEOLOGY_EXHIBITION_ITEM(frame, itemGuid)
    if CHECK_ARCEX_TARGET_SLOT_AVAILABLE(itemGuid) ~= true then
        return
    end

    pc.ReqExecuteTx_Item("ARC_EQUIP_ITEM", itemGuid)
end

function DELETE_ARCHEOLOGY_EXHIBITION_ITEM_RBTN(frame, parent, argStr, argNum)
    pc.ReqExecuteTx_Item("ARC_UNEQUIP_ITEM", argNum)
end

function DELETE_ARCHEOLOGY_AMPLIFIER_ITEM_RBTN()
    pc.ReqExecuteTx_Item("ARC_UNEQUIP_AMPLIFIER_ITEM", "1")
end

function ON_ARCHEOLOGY_EXHIBITION_ADD_ITEM(frame, msg, itemName, SlotIdx)
    UPDATE_EXHIBITION_SLOT_ITEM(frame, SlotIdx, itemName)
    UPDATE_EXHIBITION_COST_TEXT(frame)
    UPDATE_EXHIBITION_EFFECT_TEXT(frame)
    RESERVE_ARCHEOLOGY_EXHIBITION_REFRESH()
end

function ON_ARCHEOLOGY_EXHIBITION_DELETE_ITEM(frame, msg, itemName, SlotIdx)
    UPDATE_EXHIBITION_SLOT_ITEM(frame, SlotIdx, itemName)
    UPDATE_EXHIBITION_COST_TEXT(frame)
    UPDATE_EXHIBITION_EFFECT_TEXT(frame)
    RESERVE_ARCHEOLOGY_EXHIBITION_REFRESH()
end

function ON_ARCHEOLOGY_EXHIBITION_UPDATE_AMPLIFIER(frame)
    UPDATE_AMPLIFIER_SLOT(frame)
    UPDATE_EXHIBITION_COST_TEXT(frame)
    UPDATE_EXHIBITION_EFFECT_TEXT(frame)
    RESERVE_ARCHEOLOGY_EXHIBITION_REFRESH()
end

function ALL_UNEQUIP_EXHIBITION_ITEM(parent, ctrl, item, slot)
    ui.MsgBox(ARC_EXHIBIT_MSG("ARC_EXHIBIT_CLEAR_ALL_CONFIRM"), "pc.ReqExecuteTx_Item('ARC_UNEQUIP_ITEM', 4)", "None")
end

function UPDATE_EXHIBITION_SLOT_ITEM(frame, slotidx, itemName)
    local archeology_slot_Gbox = GET_CHILD_RECURSIVELY(frame, "archeology_slot_Gbox")
    if archeology_slot_Gbox == nil then
        return
    end

    local child_slot = archeology_slot_Gbox:GetChild("slot" .. slotidx)
    if child_slot == nil then
        return
    end

    local target_item = GetClass("Item", itemName)
    local archeology_exhibition_slot = GET_CHILD_RECURSIVELY(child_slot, "archeology_exhibition_slot")
    local default_image = GET_CHILD_RECURSIVELY(child_slot, "default_image")
    local slot_name = GET_CHILD_RECURSIVELY(child_slot, "slot_name")
    local slot_meta = GET_CHILD_RECURSIVELY(child_slot, "slot_meta")
    local slot_hint = GET_CHILD_RECURSIVELY(child_slot, "slot_hint")
    local slot_cost_value = GET_CHILD_RECURSIVELY(child_slot, "slot_cost_value")
    local arcPrefix = GET_ARCEX_SLOT_META(nil, slotidx)
    local emptySlotInfo = GET_ARCEX_SLOT_INFO_BY_INDEX(slotidx)

    if target_item == nil then
        archeology_exhibition_slot:ClearIcon()
        CLEAR_SLOT_TOOLTIP(archeology_exhibition_slot)
        if emptySlotInfo ~= nil then
            SET_TEXTHELP_TOOLTIP(archeology_exhibition_slot, string.format("{@st42b}%s{/}{nl}{@st66d}%s{/}", BUILD_ARCEX_SLOT_INFO_TEXT(emptySlotInfo), GET_ARCEX_SLOT_INFO_HINT(emptySlotInfo)))
        end
        default_image:ShowWindow(1)
        if emptySlotInfo ~= nil then
			slot_name:SetTextByKey("name", GET_ARCEX_SLOT_INFO_NAME(emptySlotInfo))
			slot_meta:SetTextByKey("meta", ARC_EXHIBIT_ARG_MSG("ARC_EXHIBIT_SLOT_INDEX_FMT", "INDEX", emptySlotInfo.index))
			slot_hint:SetTextByKey("hint", GET_ARCEX_SLOT_INFO_HINT(emptySlotInfo))
        else
			slot_name:SetTextByKey("name", ARC_EXHIBIT_MSG("ARC_EXHIBIT_SLOT_EMPTY_NAME"))
			slot_meta:SetTextByKey("meta", ARC_EXHIBIT_MSG("ARC_EXHIBIT_SLOT_EMPTY_META"))
			slot_hint:SetTextByKey("hint", ARC_EXHIBIT_MSG("ARC_EXHIBIT_SLOT_EMPTY_HINT"))
        end
        slot_hint:ShowWindow(1)
		slot_cost_value:SetTextByKey("value", "")
		slot_cost_value:SetTextByKey("color", "d7d0c4")
        return
    end

    SET_SLOT_IMG(archeology_exhibition_slot, target_item.Icon)
    SET_ARCEX_SLOT_TOOLTIP(archeology_exhibition_slot, target_item, arcPrefix, nil, slotidx)
    default_image:ShowWindow(0)
	slot_name:SetTextByKey("name", ARCHEOLOGY_EXHIBITION_GET_PLAIN_ITEM_NAME(GET_SLOT_DISPLAY_NAME(target_item)))
	slot_meta:SetTextByKey("meta", GET_SLOT_META_TEXT(itemName, arcPrefix))
    slot_hint:ShowWindow(0)

    local exCls = GetClass("archeology_exhibition_item", itemName)
    local cost = GET_ARCHEOLOGY_EXHIBITION_ITEM_COST(exCls, arcPrefix)
    local slotInfo = GET_ARCEX_SLOT_INFO_BY_INDEX(slotidx)
    if slotInfo ~= nil then
		slot_cost_value:SetTextByKey("color", "d8bd62")
		slot_cost_value:SetTextByKey("value", GET_ARCEX_SLOT_INFO_NAME(slotInfo))
    else
		slot_cost_value:SetTextByKey("color", "d7d0c4")
		slot_cost_value:SetTextByKey("value", ARC_EXHIBIT_ARG_MSG("ARC_EXHIBIT_COST_FMT", "VALUE", cost))
    end
end

function UPDATE_AMPLIFIER_SLOT(frame)
    local slot = GET_CHILD_RECURSIVELY(frame, "amplifier_slot")
    local nameText = GET_CHILD_RECURSIVELY(frame, "amplifier_name")
    local descText = GET_CHILD_RECURSIVELY(frame, "amplifier_desc")
    local unlockText = GET_CHILD_RECURSIVELY(frame, "amplifier_unlock_text")

    if slot == nil or nameText == nil or descText == nil or unlockText == nil then
        return
    end

    if IS_ARCEX_AMPLIFIER_SLOT_UNLOCKED() ~= true then
        slot:ClearIcon()
        CLEAR_SLOT_TOOLTIP(slot)
        slot:EnableHitTest(0)
		nameText:SetTextByKey("name", ARC_EXHIBIT_MSG("ARC_EXHIBIT_AMPLIFIER_LOCKED"))
		descText:SetTextByKey("desc", ARC_EXHIBIT_MSG("ARC_EXHIBIT_AMPLIFIER_LOCKED_DESC"))
		unlockText:SetTextByKey("hint", ARC_EXHIBIT_ARG_MSG(
			"ARC_EXHIBIT_AMPLIFIER_UNLOCK_COND{VALUE}", "VALUE", 3))
        unlockText:ShowWindow(1)
        return
    end

    local amplifierCls = GET_ARCEX_AMPLIFIER_ITEM()
    if amplifierCls == nil then
        slot:ClearIcon()
        CLEAR_SLOT_TOOLTIP(slot)
        slot:EnableHitTest(1)
		nameText:SetTextByKey("name", ARC_EXHIBIT_MSG("ARC_EXHIBIT_AMPLIFIER_EMPTY"))
		descText:SetTextByKey("desc", ARC_EXHIBIT_MSG("ARC_EXHIBIT_AMPLIFIER_EMPTY_DESC"))
		unlockText:SetTextByKey("hint", ARC_EXHIBIT_MSG("ARC_EXHIBIT_AMPLIFIER_EQUIP_HINT"))
        unlockText:ShowWindow(1)
        return
    end

    local itemCls = GetClass("Item", TryGetProp(amplifierCls, "ClassName", "None"))
    if itemCls ~= nil then
        local amplifierMeta = GET_ARCEX_AMPLIFIER_META()
        SET_SLOT_IMG(slot, TryGetProp(itemCls, "Icon", "None"))
        SET_ARCEX_SLOT_TOOLTIP(slot, itemCls, amplifierMeta, TryGetProp(amplifierCls, "AmplifierText", ARC_EXHIBIT_MSG("ARC_EXHIBIT_INFO_NONE")))
    else
        slot:ClearIcon()
        CLEAR_SLOT_TOOLTIP(slot)
    end

    slot:EnableHitTest(1)
	nameText:SetTextByKey("name", GET_SLOT_DISPLAY_NAME(itemCls))
	descText:SetTextByKey("desc", TryGetProp(amplifierCls, "AmplifierText", ARC_EXHIBIT_MSG("ARC_EXHIBIT_INFO_NONE")))
	unlockText:ShowWindow(0)
end

function ON_CLEAR_ALL_EXHIBTTION_SLOT(frame)
    for i = 1, 3 do
        UPDATE_EXHIBITION_SLOT_ITEM(frame, i, nil)
    end

    UPDATE_AMPLIFIER_SLOT(frame)
    UPDATE_EXHIBITION_EFFECT_TEXT(frame)
    UPDATE_EXHIBITION_COST_TEXT(frame)
    RESERVE_ARCHEOLOGY_EXHIBITION_REFRESH()
end

function UPDATE_EXHIBITION_COST_TEXT(frame)
    local archeology_cost = GET_CHILD_RECURSIVELY(frame, "archeology_cost")
    local cost_progress_gauge = GET_CHILD_RECURSIVELY(frame, "cost_progress_gauge")
    local curCost = GET_CURRENT_AREX_COST()
    local _, maxCost = GET_ARCHEOLOGY_EXHIBITION_INFO()

    local color = "d7d0c4"
    if curCost > maxCost then
        color = "ff6f61"
    elseif curCost >= maxCost - 1 then
        color = "f5d76e"
    end

	archeology_cost:SetTextByKey("current_color", color)
	archeology_cost:SetTextByKey("current", curCost)
	archeology_cost:SetTextByKey("maximum", ARCHEOLOGY_EXHIBITION_LEVEL_NUMBER(frame, maxCost))
    if cost_progress_gauge ~= nil then
        cost_progress_gauge:SetPoint(curCost, math.max(maxCost, 1))
    end
end

function UPDATE_EXHIBITION_EFFECT_TEXT(frame)
    local archeology_effect_Gbox = GET_CHILD_RECURSIVELY(frame, "archeology_effect_Gbox")
    local archeology_effect_text_Gbox = GET_CHILD_RECURSIVELY(frame, "archeology_effect_text_Gbox")
    local emptyText = GET_CHILD_RECURSIVELY(frame, "archeology_effect_empty_text")
    if archeology_effect_Gbox == nil or archeology_effect_text_Gbox == nil or emptyText == nil then
        return
    end

    archeology_effect_Gbox:EnableScrollBar(1)
    archeology_effect_Gbox:SetScrollBarSkinName("verticalscrollbar3")
    archeology_effect_text_Gbox:EnableScrollBar(0)

    local categoryOrder = { "Arch", "Combat", "Special" }
    local categoryControls = {}
    local categoryEntries = {
        Arch = {},
        Combat = {},
        Special = {},
    }
    for _, categoryKey in ipairs(categoryOrder) do
        local controlKey = string.lower(categoryKey)
        local categoryGroup = GET_CHILD_RECURSIVELY(
            frame, "effect_category_" .. controlKey .. "_Gbox")
        local categoryTitle = GET_CHILD_RECURSIVELY(
            frame, "effect_category_" .. controlKey .. "_title")
        local categoryList = GET_CHILD_RECURSIVELY(
            frame, "effect_category_" .. controlKey .. "_list")
        if categoryGroup == nil or categoryTitle == nil or categoryList == nil then
            return
        end

        categoryList:RemoveAllChild()
        categoryList:EnableScrollBar(0)
        categoryGroup:ShowWindow(0)
        categoryTitle:SetTextByKey(
            "value", ARC_EXHIBIT_MSG(ARCEX_EFFECT_CATEGORY_INFO[categoryKey].messageKey))
        categoryControls[categoryKey] = {
            group = categoryGroup,
            list = categoryList,
        }
    end
    emptyText:ShowWindow(0)

    local apply_effect_list = GET_CURRENT_APPLY_EFFECT_LIST()
    local effect_entries = {}
    for effect_name, effect_value in pairs(apply_effect_list) do
        local categoryInfo = GET_EFFECT_CATEGORY_INFO(effect_name)
        local categoryKey = GET_ARCHEOLOGY_EXHIBITION_EFFECT_CATEGORY_KEY(effect_name)
        effect_entries[#effect_entries + 1] = {
            name = effect_name,
            value = effect_value,
            weight = GET_EFFECT_SORT_WEIGHT(effect_name),
            categoryWeight = categoryInfo.sortWeight,
            categoryKey = categoryKey,
        }
    end

    table.sort(effect_entries, function(a, b)
        if a.categoryWeight ~= b.categoryWeight then
            return a.categoryWeight < b.categoryWeight
        end
        if a.weight == b.weight then
            return a.name < b.name
        end
        return a.weight < b.weight
    end)

    for _, info in ipairs(effect_entries) do
        categoryEntries[info.categoryKey][#categoryEntries[info.categoryKey] + 1] = info
    end

    -- 고정(고유) 효과는 스탯이 아니라 장착 유물 자체에 붙는 효과라 별도로 모은다.
    local fixedCount = 0
    if GET_ARCHEOLOGY_FIXED_RELIC_EFFECT_INFO ~= nil then
        for slotIndex = 1, 3 do
            local classID = GET_ARCEX_SLOT_ITEM_IDX(nil, slotIndex)
            local itemCls = GetClassByType("archeology_exhibition_item", tonumber(classID) or 0)
            if itemCls ~= nil then
                local fixedInfo = GET_ARCHEOLOGY_FIXED_RELIC_EFFECT_INFO(
                    TryGetProp(itemCls, "ClassName", "None"))
                if fixedInfo ~= nil then
                    fixedCount = fixedCount + 1
                    categoryEntries.Special[#categoryEntries.Special + 1] = {
                        fixed = fixedInfo,
                        name = fixedInfo.effectKey,
                    }
                end
            end
        end
    end

    if #effect_entries == 0 and fixedCount == 0 then
        emptyText:SetTextByKey("value", ARC_EXHIBIT_MSG("ARC_EXHIBIT_EMPTY_EFFECTS"))
        emptyText:ShowWindow(1)
        archeology_effect_text_Gbox:Resize(archeology_effect_text_Gbox:GetWidth(), 60)
        archeology_effect_Gbox:UpdateData()
        archeology_effect_Gbox:InvalidateScrollBar()
        return
    end

    local curY = 8
    for _, categoryKey in ipairs(categoryOrder) do
        local entries = categoryEntries[categoryKey]
        if #entries > 0 then
            local controls = categoryControls[categoryKey]
            local rowY = 0
            for _, info in ipairs(entries) do
                if info.fixed ~= nil then
                    local fixedSet = controls.list:CreateOrGetControlSet(
                        "archeology_exhibition_effect_row", "fixed_" .. info.name, 0, rowY)
                    local fixedName = GET_CHILD_RECURSIVELY(fixedSet, "effect_name")
                    local fixedValue = GET_CHILD_RECURSIVELY(fixedSet, "effect_value")
                    fixedName:SetTextByKey("name",
                        "{#" .. (info.fixed.color or "FFFFFF") .. "}" ..
                        ClMsg(info.fixed.titleMsg))
                    fixedValue:SetTextByKey("value", "")
                    SET_TEXTHELP_TOOLTIP(fixedSet, ClMsg(info.fixed.descMsg))
                    rowY = rowY + fixedSet:GetHeight() + 4
                else
                    local effectNameText, effectTypeText, effectValueText, fullDescription =
                        GET_EFFECT_DISPLAY_INFO(info.name, info.value)
                    local controlSetName = "archeology_exhibition_effect_row"
                    if effectTypeText ~= "" then
                        controlSetName = "archeology_exhibition_effect_typed_row"
                    end
                    local effectSet = controls.list:CreateOrGetControlSet(
                        controlSetName, "effect_" .. info.name, 0, rowY)
                    local effectNameControl = GET_CHILD_RECURSIVELY(effectSet, "effect_name")
                    local effectValueControl = GET_CHILD_RECURSIVELY(effectSet, "effect_value")
                    local effectTypeControl = nil
                    if effectTypeText ~= "" then
                        effectTypeControl = GET_CHILD_RECURSIVELY(effectSet, "effect_type")
                    end
                    -- 이름이 3줄 이상이면 controlset(34·58px)에 잘린다. 기본 높이로 되돌린 뒤
                    -- 글을 넣어 늘어난 이름 높이만큼 행을 키운다(재사용되는 행도 매번 다시 잰다).
                    local baseNameHeight = effectTypeControl ~= nil and 38 or 34
                    local baseRowHeight = effectTypeControl ~= nil and 58 or 34
                    effectNameControl:Resize(132, baseNameHeight)
                    effectNameControl:SetTextByKey("name", effectNameText)
                    effectValueControl:SetTextByKey("value", effectValueText)
                    if effectTypeControl ~= nil then
                        effectTypeControl:SetTextByKey("type", effectTypeText)
                    end
                    local nameHeight = math.max(baseNameHeight, effectNameControl:GetHeight())
                    local rowHeight = baseRowHeight + (nameHeight - baseNameHeight)
                    if effectTypeControl ~= nil then
                        effectTypeControl:SetMargin(0, nameHeight + 1, 0, 0)
                    end
                    effectSet:Resize(effectSet:GetWidth(), rowHeight)
                    effectValueControl:Resize(effectValueControl:GetWidth(), rowHeight)
                    local divider = GET_CHILD_RECURSIVELY(effectSet, "divider")
                    if divider ~= nil then
                        divider:SetMargin(0, rowHeight - divider:GetHeight(), 0, 0)
                        divider:SetGravity(ui.CENTER_HORZ, ui.TOP)
                    end
                    SET_TEXTHELP_TOOLTIP(effectSet, fullDescription)
                    rowY = rowY + effectSet:GetHeight() + 4
                end
            end

            controls.list:Resize(controls.list:GetWidth(), rowY)
            controls.group:Resize(controls.group:GetWidth(), rowY + 28)
            controls.group:SetOffset(4, curY)
            controls.group:ShowWindow(1)
            curY = curY + controls.group:GetHeight() + 6
        end
    end

    archeology_effect_text_Gbox:Resize(archeology_effect_text_Gbox:GetWidth(), curY + 8)
    archeology_effect_Gbox:UpdateData()
    archeology_effect_Gbox:InvalidateScrollBar()
end

function EXCUTE_EXHIBITION_RANKUP(frame, ctrl, argStr, argNum)
    frame = ui.GetFrame("archeology_exhibition")
    local dialog = GET_CHILD_RECURSIVELY(frame, "rankup_overlay")
    local itemCls = GetClassByType("Item", 11039559)
    GET_CHILD_RECURSIVELY(dialog, "rankup_item_name"):SetTextByKey("name", itemCls.Name)
    local icon = GET_CHILD_RECURSIVELY(dialog, "rankup_item_icon")
    tolua.cast(icon, "ui::CPicture"):SetImage(itemCls.Icon)
    local countControl = GET_CHILD_RECURSIVELY(dialog, "rankup_count")
    -- Direct edits do not update the format cache; reset it when reopening.
    countControl:SetTextByKey("count", "")
    countControl:SetTextByKey("count", "1")
    dialog:ShowWindow(1)
    EXHIBITION_RANKUP_UPDATE()
    dialog:RunUpdateScript("EXHIBITION_RANKUP_TICK", 0.2)
end

function EXHIBITION_RANKUP_CANCEL()
    local frame = ui.GetFrame("archeology_exhibition")
    if frame == nil then return end
    local dialog = GET_CHILD_RECURSIVELY(frame, "rankup_overlay")
    dialog:StopUpdateScript("EXHIBITION_RANKUP_TICK")
    GET_CHILD_RECURSIVELY(dialog, "rankup_count"):SetTextByKey("count", "")
    dialog:ShowWindow(0)
end

function EXHIBITION_RANKUP_TICK()
    local frame = ui.GetFrame("archeology_exhibition")
    if frame == nil or frame:IsVisible() == 0 then return 0 end
    local dialog = GET_CHILD_RECURSIVELY(frame, "rankup_overlay")
    if dialog:IsVisible() == 0 then return 0 end
    EXHIBITION_RANKUP_UPDATE()
    return 1
end

function EXHIBITION_RANKUP_UPDATE()
    local frame = ui.GetFrame("archeology_exhibition")
    local dialog = GET_CHILD_RECURSIVELY(frame, "rankup_overlay")
    if dialog:IsVisible() == 0 then return nil end
    local aObj = GetMyAccountObj()
    local curCoinCnt = session.GetInvItemCountByType(11039559)
    local maxExp = GET_EXHIBITION_GOAL_EXP()
    local curExp = TryGetProp(aObj, "ARCHEOLOGY_EXP", 0)
    local nextExp = math.max(maxExp - curExp, 0)
    local maximum = math.min(curCoinCnt, nextExp)
    local countControl = GET_CHILD_RECURSIVELY(dialog, "rankup_count")
    local count = tonumber(tolua.cast(countControl, "ui::CEditControl"):GetText())
    local valid = count ~= nil and count >= 1 and count <= maximum and count == math.floor(count)
    GET_CHILD_RECURSIVELY(dialog, "rankup_owned"):SetTextByKey("count", curCoinCnt)
    GET_CHILD_RECURSIVELY(dialog, "rankup_range"):SetTextByKey("max", maximum)
    GET_CHILD_RECURSIVELY(dialog, "rankup_range"):ShowWindow(maximum > 0 and 1 or 0)
    GET_CHILD_RECURSIVELY(dialog, "rankup_empty"):ShowWindow(curCoinCnt <= 0 and nextExp > 0 and 1 or 0)
    GET_CHILD_RECURSIVELY(dialog, "rankup_max_level"):ShowWindow(nextExp <= 0 and 1 or 0)
    GET_CHILD_RECURSIVELY(dialog, "rankup_invalid"):ShowWindow(not valid and maximum > 0 and 1 or 0)
    GET_CHILD_RECURSIVELY(dialog, "rankup_preview"):ShowWindow(valid and 1 or 0)
    GET_CHILD_RECURSIVELY(dialog, "rankup_confirm"):SetEnable(valid and 1 or 0)
    GET_CHILD_RECURSIVELY(dialog, "rankup_confirm"):SetTextByKey("count", valid and count or 0)
    if not valid then return nil end
    GET_CHILD_RECURSIVELY(dialog, "rankup_spend"):SetTextByKey("count", count)
    GET_CHILD_RECURSIVELY(dialog, "rankup_remain"):SetTextByKey("count", curCoinCnt - count)
    GET_CHILD_RECURSIVELY(dialog, "rankup_exp"):SetTextByKey("exp", count)
    GET_CHILD_RECURSIVELY(dialog, "rankup_next"):SetTextByKey("exp", nextExp - count)
    return count
end

function SEND_EXHIBITION_RANKUP()
    -- Recheck inventory and progress at confirmation; never send a stale preview amount.
    local count = EXHIBITION_RANKUP_UPDATE()
    if count == nil then return end
    EXHIBITION_RANKUP_CANCEL()
    pc.ReqExecuteTx_Item("ARC_UPGRADE", count)
end

local function STOP_ARCHEOLOGY_EXHIBITION_LEGACY_LEVEL_EFFECTS(frame)
    local progressPanel = GET_CHILD_RECURSIVELY(frame, "progress_panel")
    if progressPanel ~= nil then
        progressPanel:StopUIEffect("ARCHEOLOGY_EXHIBITION_LEVEL_PROGRESS", true, 0.0)
    end
    local costGauge = GET_CHILD_RECURSIVELY(frame, "cost_progress_gauge")
    if costGauge ~= nil then
        costGauge:StopUIEffect("ARCHEOLOGY_EXHIBITION_COST_CAP", true, 0.0)
    end
end

function ARCHEOLOGY_EXHIBITION_RESET_LEVEL_HIGHLIGHT(frame)
    if frame == nil then return end
    STOP_ARCHEOLOGY_EXHIBITION_LEGACY_LEVEL_EFFECTS(frame)
    frame:StopUpdateScript("ARCHEOLOGY_EXHIBITION_LEVEL_HIGHLIGHT_TICK")
    frame:SetUserValue("ARC_LEVEL_HIGHLIGHT", 0)
    frame:SetUserValue("ARC_LEVEL_HIGHLIGHT_UNTIL", 0)
    frame:SetUserValue("ARC_LEVEL_HIGHLIGHT_PENDING", 0)
    UPDATE_EXHIBITION_COST_TEXT(frame)
    SET_EXP_TEXT(frame)
end

function ARCHEOLOGY_EXHIBITION_CHECK_LEVEL_HIGHLIGHT(frame)
    if frame:GetUserIValue("ARC_LEVEL_HIGHLIGHT_PENDING") ~= 1 then return end
    if frame:IsVisible() == 0 then
        ARCHEOLOGY_EXHIBITION_RESET_LEVEL_HIGHLIGHT(frame)
        return
    end
    local currentLevel = GET_CURRENT_EXHIBITION_LEVEL()
    local previousLevel = frame:GetUserIValue("ARC_LAST_SHOWN_LEVEL")
    if previousLevel > 0 and currentLevel > previousLevel then
        frame:SetUserValue("ARC_LEVEL_HIGHLIGHT", 1)
        frame:SetUserValue("ARC_LEVEL_HIGHLIGHT_UNTIL", imcTime.GetAppTime() + 1.0)
        frame:SetUserValue("ARC_LEVEL_HIGHLIGHT_PENDING", 0)
        frame:StopUpdateScript("ARCHEOLOGY_EXHIBITION_LEVEL_HIGHLIGHT_TICK")
        frame:RunUpdateScript("ARCHEOLOGY_EXHIBITION_LEVEL_HIGHLIGHT_TICK", 0.05)
    end
end

function ARCHEOLOGY_EXHIBITION_LEVEL_HIGHLIGHT_TICK(frame)
    if frame == nil or frame:GetUserIValue("ARC_LEVEL_HIGHLIGHT") ~= 1 then return 0 end
    local untilTime = tonumber(frame:GetUserValue("ARC_LEVEL_HIGHLIGHT_UNTIL")) or 0
    if frame:IsVisible() == 1 and imcTime.GetAppTime() < untilTime then return 1 end
    frame:SetUserValue("ARC_LEVEL_HIGHLIGHT", 0)
    frame:SetUserValue("ARC_LEVEL_HIGHLIGHT_UNTIL", 0)
    if frame:IsVisible() == 0 then frame:SetUserValue("ARC_LEVEL_HIGHLIGHT_PENDING", 0) end
    UPDATE_EXHIBITION_COST_TEXT(frame)
    SET_EXP_TEXT(frame)
    return 0
end

function ON_UPDATE_EXHIBITION_RANK(frame)
    STOP_ARCHEOLOGY_EXHIBITION_LEGACY_LEVEL_EFFECTS(frame)
    frame:SetUserValue("ARC_LEVEL_HIGHLIGHT_PENDING", 1)
    ARCHEOLOGY_EXHIBITION_CHECK_LEVEL_HIGHLIGHT(frame)
    EXHIBITION_RANKUP_CANCEL()
    UPDATE_EXHIBITION_COST_TEXT(frame)
    UPDATE_AMPLIFIER_SLOT(frame)
    SET_EXP_TEXT(frame)
    UPDATE_EXHIBITION_EFFECT_TEXT(frame)
    RESERVE_ARCHEOLOGY_EXHIBITION_REFRESH()
end

function SET_EXP_TEXT(frame)
    local currentLevel, total_exp = GET_CURRENT_EXHIBITION_LEVEL()
    local max_level = GET_EXP_CLASS_COUNT()

    local currentCls = GET_EXP_CLASS(currentLevel)
    local nextCls = nil
    if currentLevel < max_level then
        nextCls = GET_EXP_CLASS(currentLevel + 1)
    end

    local currentReq = TryGetProp(currentCls, "Exp", 0)
    local nextReq = nextCls ~= nil and TryGetProp(nextCls, "Exp", currentReq) or currentReq
    local remain_exp = nextCls ~= nil and math.max(nextReq - total_exp, 0) or 0
    local curCostCap = TryGetProp(currentCls, "MaxCost", 0)
    local nextCostCap = nextCls ~= nil and TryGetProp(nextCls, "MaxCost", curCostCap) or curCostCap

    local rank_text = GET_CHILD_RECURSIVELY(frame, "rank_text")
    local next_reward_text = GET_CHILD_RECURSIVELY(frame, "next_reward_text")
    local exp_gauge = GET_CHILD_RECURSIVELY(frame, "exp_gauge")
    local exp_value_text = GET_CHILD_RECURSIVELY(frame, "exp_value_text")
    local levelt_text = GET_CHILD_RECURSIVELY(frame, "levelt_text")
    local reward_icon = GET_CHILD_RECURSIVELY(frame, "reward_icon")
    local reward_desc = GET_CHILD_RECURSIVELY(frame, "reward_desc")

	rank_text:SetTextByKey("level", ARCHEOLOGY_EXHIBITION_LEVEL_NUMBER(frame, currentLevel))
    frame:SetUserValue("ARC_LAST_SHOWN_LEVEL", currentLevel)

    if nextCls ~= nil then
        local nextRewardText = ARC_EXHIBIT_ARG_MSG("ARC_EXHIBIT_NEXT_REWARD_COST_FMT", "VALUE", nextCostCap - curCostCap)
        local milestoneLevel, milestoneMsg = GET_ARCHEOLOGY_EXHIBITION_NEXT_MILESTONE(currentLevel)
        if milestoneLevel ~= nil and milestoneMsg ~= nil then
            nextRewardText = ARC_EXHIBIT_ARG_MSG(
                "ARC_EXHIBIT_NEXT_REWARD_AND_UNLOCK{REWARD}{LEVEL}{UNLOCK}",
                "REWARD", nextRewardText, "LEVEL", milestoneLevel,
                "UNLOCK", ARC_EXHIBIT_MSG(milestoneMsg))
        end
		next_reward_text:SetTextByKey("text", nextRewardText)
		exp_value_text:SetTextByKey("text", ARC_EXHIBIT_ARG_MSG("ARC_EXHIBIT_EXP_FMT", "CUR", total_exp - currentReq, "MAX", nextReq - currentReq))
		levelt_text:SetTextByKey("text", ARC_EXHIBIT_ARG_MSG("ARC_EXHIBIT_NEXT_LEVEL_REMAIN_FMT", "VALUE", remain_exp))
        exp_gauge:SetPoint(total_exp - currentReq, math.max(nextReq - currentReq, 1))
        reward_icon:SetImage(GET_REWARD_ICON_NAME(nextCls))
		reward_desc:SetTextByKey("text", GET_REWARD_TEXT(nextCls))
    else
		next_reward_text:SetTextByKey("text", ARC_EXHIBIT_MSG("ARC_EXHIBIT_MAX_LEVEL_REACHED"))
		exp_value_text:SetTextByKey("text", ARC_EXHIBIT_ARG_MSG("ARC_EXHIBIT_EXP_ONLY_FMT", "CUR", total_exp))
		levelt_text:SetTextByKey("text", ARC_EXHIBIT_MSG("ARC_EXHIBIT_ALL_REWARDS_DONE"))
        exp_gauge:SetPoint(1, 1)
        reward_icon:SetImage("icon_item_event_archeology_coin")
		reward_desc:SetTextByKey("text", ARC_EXHIBIT_MSG("ARC_EXHIBIT_NO_MORE_REWARDS"))
    end
end
