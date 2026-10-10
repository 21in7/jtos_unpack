local QAB_COLOR_NORMAL = "FFFFFFFF"
local QAB_COLOR_UNAVAILABLE = "FF777777"
local QAB_COLOR_MISSING = "FFFF5555"

local function QAB_ACTION_SAFE_NUMBER(value, defaultValue)
    local numberValue = tonumber(value)
    if numberValue == nil then
        return defaultValue
    end
    return numberValue
end

local function QAB_ACTION_GET_LIFT_CATEGORY(info)
    if info == nil then
        return nil
    end

    local category = nil
    if info.GetCategory ~= nil then
        category = info:GetCategory()
    end
    if category == nil or category == "None" or category == "" then
        category = info.category
    end
    return category
end

local function QAB_ACTION_GET_LIFT_IESID(info)
    if info == nil or info.GetIESID == nil then
        return "0"
    end

    local iesID = info:GetIESID()
    if iesID == nil or iesID == "" or iesID == "None" then
        return "0"
    end
    return tostring(iesID)
end

local function QAB_ACTION_CLEAR_SLOT(slot)
    if slot == nil then
        return
    end

    slot:ClearIcon()
    slot:ClearText()
    slot:SetFrontImage("None")
    local gauge = slot:GetSlotGauge()
    if gauge ~= nil then
        gauge:ShowWindow(0)
        slot:InvalidateGauge()
    end
end

local function QAB_ACTION_SET_ICON_TOOLTIP(icon, tooltipType, classID, iesID)
    if icon == nil then
        return
    end

    if tooltipType ~= nil and tooltipType ~= "" then
        icon:SetTooltipType(tooltipType)
    end
    icon:SetTooltipNumArg(classID or 0)
    if iesID ~= nil and iesID ~= "0" then
        icon:SetTooltipIESID(iesID)
    end
end

local function QAB_ACTION_GET_ITEM(action)
    local classID = tonumber(action.classID) or 0
    local iesID = tostring(action.iesID or "0")
    local invItem = nil
    if iesID ~= "0" and iesID ~= "" then
        invItem = session.GetInvItemByGuid(iesID)
        if invItem ~= nil and tonumber(invItem.type) ~= classID then
            invItem = nil
        end
    end
    if invItem == nil then
        invItem = session.GetInvItemByType(classID)
    end
    return invItem
end

local function QAB_ACTION_CAN_WARP(questClass)
    if questClass == nil or SCR_QUEST_CHECK_C == nil or GET_QUEST_NPC_STATE == nil then
        return false
    end

    local pc = GetMyPCObject()
    if pc == nil then
        return false
    end

    local result = SCR_QUEST_CHECK_C(pc, questClass.ClassName)
    return GET_QUEST_NPC_STATE(questClass, result, pc) ~= nil
end

local function QAB_ACTION_HAS_EMOTICON(emoticonClass)
    if emoticonClass == nil then
        return false
    end
    if TryGetProp(emoticonClass, "CheckServer", "NO") ~= "YES" then
        return true
    end

    local owner = GetMyAccountObj()
    if TryGetProp(emoticonClass, "HaveUnit", "None") == "PC" then
        owner = GetMyEtcObject()
    end
    if owner == nil then
        return false
    end
    return QAB_ACTION_SAFE_NUMBER(TryGetProp(owner, "HaveEmoticon_" .. emoticonClass.ClassID, 0), 0) > 0
end

function QUICKACTIONBOARD_ACTION_HAS_EMOTICON(classID)
    local emoticonClass = GetClassByType("chat_emoticons", tonumber(classID) or 0)
    return QAB_ACTION_HAS_EMOTICON(emoticonClass)
end

local function QAB_ACTION_GET_EMOTICON_IMAGE(emoticonClass)
    if emoticonClass == nil then
        return "None"
    end

    local names = StringSplit(emoticonClass.ClassName, "motion_")
    if names ~= nil and #names > 1 then
        return names[2]
    end
    return names ~= nil and names[1] or emoticonClass.ClassName
end

function QUICKACTIONBOARD_ACTION_FROM_LIFT(liftIcon, info)
    if liftIcon == nil then
        return nil, "INVALID_ACTION"
    end

    local specialKind = liftIcon:GetUserValue("QAB_ACTION_KIND")
    if specialKind ~= nil and specialKind ~= "None" and specialKind ~= "" then
        local specialClassID = QAB_ACTION_SAFE_NUMBER(liftIcon:GetUserValue("QAB_CLASS_ID"), 0)
        if specialClassID <= 0 then
            return nil, "INVALID_ACTION"
        end
        return {
            kind = specialKind,
            classID = specialClassID,
            iesID = "0"
        }
    end

    local poseID = QAB_ACTION_SAFE_NUMBER(liftIcon:GetUserValue("POSEID"), 0)
    if poseID > 0 then
        return {
            kind = "Pose",
            classID = poseID,
            iesID = "0"
        }
    end

    if info == nil then
        return nil, "INVALID_ACTION"
    end

    local category = QAB_ACTION_GET_LIFT_CATEGORY(info)
    local classID = QAB_ACTION_SAFE_NUMBER(info.type, 0)
    if category == "Item" and classID > 0 then
        return {
            kind = "Item",
            classID = classID,
            iesID = QAB_ACTION_GET_LIFT_IESID(info)
        }
    elseif category == "Skill" and classID > 0 then
        return {
            kind = "Skill",
            classID = classID,
            iesID = "0"
        }
    elseif category == "Ability" and classID > 0 then
        return {
            kind = "Ability",
            classID = classID,
            iesID = QAB_ACTION_GET_LIFT_IESID(info)
        }
    elseif category == "Pose" and classID > 0 then
        return {
            kind = "Pose",
            classID = classID,
            iesID = "0"
        }
    elseif category == "WarpAction" and classID > 0 then
        return {
            kind = "Warp",
            classID = classID,
            iesID = "0"
        }
    end

    return nil, "UNSUPPORTED_ACTION"
end

local function QAB_ACTION_RENDER_ITEM(action, slot)
    local itemClass = GetClassByType("Item", action.classID)
    if itemClass == nil then
        return false
    end

    local invItem = QAB_ACTION_GET_ITEM(action)
    if invItem ~= nil then
        local itemObject = GetIES(invItem:GetObject())
        local icon = CreateIcon(slot)
        icon:Set(GET_ITEM_ICON_IMAGE(itemObject or itemClass), "Item", action.classID, invItem.invIndex, invItem:GetIESID(), invItem.count)
        SET_SLOT_ITEM_TEXT(slot, invItem, itemClass)
        if icon ~= nil then
            icon:SetColorTone(QAB_COLOR_NORMAL)
            QAB_ACTION_SET_ICON_TOOLTIP(icon, "wholeitem", action.classID, invItem:GetIESID())
            if ICON_SET_ITEM_COOLDOWN_OBJ ~= nil and itemObject ~= nil then
                ICON_SET_ITEM_COOLDOWN_OBJ(icon, itemObject)
            end
        end
        return true
    end

    local icon = CreateIcon(slot)
    icon:Set(GET_ITEM_ICON_IMAGE(itemClass), "Item", action.classID, 0, tostring(action.iesID or "0"))
    icon:SetColorTone(QAB_COLOR_MISSING)
    QAB_ACTION_SET_ICON_TOOLTIP(icon, "wholeitem", action.classID, tostring(action.iesID or "0"))
    SET_SLOT_COUNT_TEXT(slot, 0)
    return false
end

local function QAB_ACTION_RENDER_SKILL(action, slot)
    local skillClass = GetClassByType("Skill", action.classID)
    if skillClass == nil then
        return false
    end

    local icon = CreateIcon(slot)
    local iconName = "icon_" .. TryGetProp(skillClass, "Icon", "None")
    icon:Set(iconName, "Skill", action.classID, 0, "0")
    icon:SetOnCoolTimeUpdateScp("ICON_UPDATE_SKILL_COOLDOWN")
    icon:SetEnableUpdateScp("ICON_UPDATE_SKILL_ENABLE")
    icon:SetColorTone(session.GetSkill(action.classID) ~= nil and QAB_COLOR_NORMAL or QAB_COLOR_UNAVAILABLE)
    QAB_ACTION_SET_ICON_TOOLTIP(icon, "skill", action.classID, "0")
    quickslot.OnSetSkillIcon(slot, action.classID)
    if QUICKSLOT_MAKE_GAUGE ~= nil then
        QUICKSLOT_MAKE_GAUGE(slot)
        local gauge = slot:GetSlotGauge()
        if gauge ~= nil then
            gauge:Resize(math.max(slot:GetWidth() - 4, 1), 10)
        end
    end
    if SET_QUICKSLOT_OVERHEAT ~= nil then
        SET_QUICKSLOT_OVERHEAT(slot)
    end
    return session.GetSkill(action.classID) ~= nil
end

local function QAB_ACTION_RENDER_ABILITY(action, slot)
    local abilityClass = GetClassByType("Ability", action.classID)
    if abilityClass == nil then
        return false
    end

    local abilityObject = GetAbilityIESObject(GetMyPCObject(), abilityClass.ClassName)
    local icon = CreateIcon(slot)
    icon:Set(TryGetProp(abilityClass, "Icon", "None"), "Ability", action.classID, 0, tostring(action.iesID or "0"))
    icon:SetColorTone(abilityObject ~= nil and QAB_COLOR_NORMAL or QAB_COLOR_UNAVAILABLE)
    QAB_ACTION_SET_ICON_TOOLTIP(icon, "ability", action.classID, tostring(action.iesID or "0"))
    if abilityObject ~= nil and SET_ABILITY_TOGGLE_COLOR ~= nil then
        SET_ABILITY_TOGGLE_COLOR(icon, action.classID)
    end
    return abilityObject ~= nil
end

local function QAB_ACTION_RENDER_POSE(action, slot)
    local poseClass = GetClassByType("Pose", action.classID)
    if poseClass == nil then
        return false
    end

    local iconName = TryGetProp(poseClass, "Icon", "None")
    if iconName == nil or iconName == "" or iconName == "None" then
        return false
    end

    local icon = CreateIcon(slot)
    icon:Set(iconName, "Pose", action.classID, 0, "0")
    icon:SetColorTone(QAB_COLOR_NORMAL)
    icon:SetTextTooltip(TryGetProp(poseClass, "Name", ""))
    return true
end

local function QAB_ACTION_RENDER_EMOTICON(action, slot)
    local emoticonClass = GetClassByType("chat_emoticons", action.classID)
    if emoticonClass == nil then
        return false
    end

    local icon = CreateIcon(slot)
    icon:SetImage(QAB_ACTION_GET_EMOTICON_IMAGE(emoticonClass))
    icon:SetColorTone(QAB_ACTION_HAS_EMOTICON(emoticonClass) and QAB_COLOR_NORMAL or QAB_COLOR_UNAVAILABLE)
    icon:SetTextTooltip("/" .. dictionary.ReplaceDicIDInCompStr(TryGetProp(emoticonClass, "IconTokken", "")))
    return QAB_ACTION_HAS_EMOTICON(emoticonClass)
end

local function QAB_ACTION_RENDER_WARP(action, slot)
    local questClass = GetClassByType("QuestProgressCheck", action.classID)
    if questClass == nil then
        return false
    end

    local available = QAB_ACTION_CAN_WARP(questClass)
    local icon = CreateIcon(slot)
    icon:Set("questinfo_return", "WarpAction", action.classID, 0, "0")
    icon:SetColorTone(available and QAB_COLOR_NORMAL or QAB_COLOR_UNAVAILABLE)
    icon:SetTextTooltip(TryGetProp(questClass, "Name", ""))
    return available
end

function QUICKACTIONBOARD_ACTION_RENDER(action, slot)
    QAB_ACTION_CLEAR_SLOT(slot)
    if action == nil or action.kind == nil then
        return false, "INVALID_ACTION"
    end

    local available = false
    if action.kind == "Item" then
        available = QAB_ACTION_RENDER_ITEM(action, slot)
    elseif action.kind == "Skill" then
        available = QAB_ACTION_RENDER_SKILL(action, slot)
    elseif action.kind == "Ability" then
        available = QAB_ACTION_RENDER_ABILITY(action, slot)
    elseif action.kind == "Pose" then
        available = QAB_ACTION_RENDER_POSE(action, slot)
    elseif action.kind == "Motion" or action.kind == "Emoticon" then
        available = QAB_ACTION_RENDER_EMOTICON(action, slot)
    elseif action.kind == "Warp" then
        available = QAB_ACTION_RENDER_WARP(action, slot)
    else
        return false, "UNSUPPORTED_ACTION"
    end

    return available, available and nil or "UNAVAILABLE_ACTION"
end

local function QAB_ACTION_EXECUTE_ITEM(action, slot)
    local invItem = QAB_ACTION_GET_ITEM(action)
    if invItem == nil then
        return false, "UNAVAILABLE_ACTION"
    end

    QUICKSLOTNEXPBAR_SLOT_USE(slot:GetParent(), slot, "", 0)
    return true
end

local function QAB_ACTION_EXECUTE_ICON(slot)
    if slot:GetIcon() == nil then
        return false, "UNAVAILABLE_ACTION"
    end
    QUICKSLOTNEXPBAR_SLOT_USE(slot:GetParent(), slot, "", 0)
    return true
end

local function QAB_ACTION_EXECUTE_POSE(action)
    local poseClass = GetClassByType("Pose", action.classID)
    if poseClass == nil then
        return false, "UNAVAILABLE_ACTION"
    end
    control.Pose(poseClass.ClassName, 0, 0, 1)
    return true
end

local function QAB_ACTION_EXECUTE_EMOTICON(action)
    local emoticonClass = GetClassByType("chat_emoticons", action.classID)
    if emoticonClass == nil or QAB_ACTION_HAS_EMOTICON(emoticonClass) == false then
        return false, "UNAVAILABLE_ACTION"
    end

    local token = dictionary.ReplaceDicIDInCompStr(TryGetProp(emoticonClass, "IconTokken", ""))
    if token == nil or token == "" or token == "None" or REPLACE_EMOTICON == nil then
        return false, "UNAVAILABLE_ACTION"
    end

    local chatText = REPLACE_EMOTICON("/" .. token)
    if chatText == nil or chatText == "" or chatText == "/" .. token then
        return false, "UNAVAILABLE_ACTION"
    end
    ui.Chat(chatText)
    return true
end

local function QAB_ACTION_EXECUTE_WARP(action, slot)
    local questClass = GetClassByType("QuestProgressCheck", action.classID)
    if questClass == nil or QAB_ACTION_CAN_WARP(questClass) == false then
        return false, "UNAVAILABLE_ACTION"
    end
    QUESTION_QUEST_WARP(slot:GetParent(), slot, nil, action.classID)
    return true
end

function QUICKACTIONBOARD_ACTION_EXECUTE(action, slot, source)
    if action == nil or slot == nil then
        return false, "INVALID_ACTION"
    end

    if action.kind == "Item" then
        return QAB_ACTION_EXECUTE_ITEM(action, slot)
    elseif action.kind == "Skill" then
        if session.GetSkill(action.classID) == nil then
            return false, "UNAVAILABLE_ACTION"
        end
        return QAB_ACTION_EXECUTE_ICON(slot)
    elseif action.kind == "Ability" then
        local abilityClass = GetClassByType("Ability", action.classID)
        if abilityClass == nil or GetAbilityIESObject(GetMyPCObject(), abilityClass.ClassName) == nil then
            return false, "UNAVAILABLE_ACTION"
        end
        return QAB_ACTION_EXECUTE_ICON(slot)
    elseif action.kind == "Pose" then
        return QAB_ACTION_EXECUTE_POSE(action)
    elseif action.kind == "Motion" or action.kind == "Emoticon" then
        return QAB_ACTION_EXECUTE_EMOTICON(action)
    elseif action.kind == "Warp" then
        return QAB_ACTION_EXECUTE_WARP(action, slot)
    end

    return false, "UNSUPPORTED_ACTION"
end

function QUICKACTIONBOARD_ACTION_REFRESH(action, slot, eventName)
    if action == nil or slot == nil then
        return
    end

    if action.kind == "Item" then
        QAB_ACTION_RENDER_ITEM(action, slot)
    elseif action.kind == "Skill" then
        if eventName == "SKILL_LIST_GET" or eventName == "SPECIFIC_SKILL_GET" or eventName == "PC_PROPERTY_UPDATE_TO_QUICKSLOT" then
            QAB_ACTION_RENDER_SKILL(action, slot)
        elseif UPDATE_SLOT_OVERHEAT ~= nil then
            UPDATE_SLOT_OVERHEAT(slot)
        end
    elseif action.kind == "Ability" then
        local icon = slot:GetIcon()
        if icon ~= nil and SET_ABILITY_TOGGLE_COLOR ~= nil then
            local abilityClass = GetClassByType("Ability", action.classID)
            local abilityObject = abilityClass ~= nil and GetAbilityIESObject(GetMyPCObject(), abilityClass.ClassName) or nil
            if abilityObject ~= nil then
                SET_ABILITY_TOGGLE_COLOR(icon, action.classID)
            else
                icon:SetColorTone(QAB_COLOR_UNAVAILABLE)
            end
        end
    end
end
