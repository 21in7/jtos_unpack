-- archeology_orb.lua
-- 고고학 오브 재가공 UI
-- Transmute(N→M 승급) / Divine(수치 재롤) / Chaos(옵션 한 개 재설정)

local ORB_INFO = {
    Transmute = {
        item = "Arc_Orb_Transmute",
        tx     = "ARC_ORB_TRANSMUTE",
        titleMsg  = "ARC_ORB_TRANSMUTE_TITLE",
        descMsg   = "ARC_ORB_TRANSMUTE_DESC",
        targetMsg = "ARC_ORB_TRANSMUTE_TARGET",
        invalidMsg = "ARC_ORB_TRANSMUTE_INVALID",
    },
    Divine = {
        item = "Arc_Orb_Divine",
        tx     = "ARC_ORB_DIVINE",
        titleMsg  = "ARC_ORB_DIVINE_TITLE",
        descMsg   = "ARC_ORB_DIVINE_DESC",
        targetMsg = "ARC_ORB_DIVINE_TARGET",
        invalidMsg = "ARC_ORB_DIVINE_INVALID",
        reroll = {
            key = "D",
            messageKey = "ARC_ORB_DIVINE_REROLL_COUNT{CURRENT}{MAX}",
        },
    },
    Chaos = {
        item = "Arc_Orb_Chaos",
        tx     = "ARC_ORB_CHAOS",
        titleMsg  = "ARC_ORB_CHAOS_TITLE",
        descMsg   = "ARC_ORB_CHAOS_DESC",
        targetMsg = "ARC_ORB_CHAOS_TARGET",
        invalidMsg = "ARC_ORB_CHAOS_INVALID",
        reroll = {
            key = "C",
            messageKey = "ARC_ORB_CHAOS_REROLL_COUNT{CURRENT}{MAX}",
        },
    },
}

local ARC_ORB_EFFECT_KEY = "ARC_ORB_EFFECT"

local function ARC_ORB_IS_EMPTY_META(meta)
    return meta == nil or meta == "" or meta == "None"
end

local function ARC_ORB_MERGE_META(prefixMeta, suffixMeta)
    local hasPrefix = ARC_ORB_IS_EMPTY_META(prefixMeta) == false
    local hasSuffix = ARC_ORB_IS_EMPTY_META(suffixMeta) == false

    if hasPrefix == true and hasSuffix == true then
        return prefixMeta .. "," .. suffixMeta
    end
    if hasPrefix == true then
        return prefixMeta
    end
    if hasSuffix == true then
        return suffixMeta
    end
    return "None"
end

local function ARC_ORB_SET_OPTION_TEXT(frame, body_name, container_name, row_prefix, opts, empty_text)
    if frame == nil then
        return 0
    end

    local body = GET_CHILD_RECURSIVELY(frame, body_name)
    local container = GET_CHILD_RECURSIVELY(frame, container_name)
    if body == nil or container == nil then
        return 0
    end

    opts = opts or {}
    local y = 0
    for i = 1, 4 do
        local row = GET_CHILD_RECURSIVELY(frame, row_prefix .. i)
        local optionText = ''
        if opts[i] ~= nil then
            optionText = ScpArgMsg("ARCHEOLOGY_OPTION_LINE{DESC}",
                "DESC", GET_ARCHEOLOGY_STAT_DESC(opts[i].tag, opts[i].value))
        elseif i == 1 and empty_text ~= nil then
            optionText = empty_text
        end

        if row ~= nil then
            row:SetTextByKey("text", optionText)
            if optionText ~= '' then
                row:SetOffset(0, y)
                row:ShowWindow(1)
                y = y + math.max(row:GetHeight(), 24) + 6
            else
                row:ShowWindow(0)
            end
        end
    end

    container:Resize(container:GetWidth(), math.max(y, 24))
    container:ShowWindow(1)
    body:EnableScrollBar(1)
    body:SetScrollBarSkinName("verticalscrollbar3")
    body:SetScrollPos(0)
    body:UpdateData()
    body:InvalidateScrollBar()
    return #opts
end

local function ARC_ORB_IS_PENDING(frame)
    local guid = frame:GetUserValue("PENDING_GUID")
    return guid ~= "None" and guid ~= "" and guid ~= nil
end

local ARC_ORB_STATE_MESSAGES = {
    STATE_EMPTY = { messageKey = "ARC_ORB_STATE_EMPTY" },
    STATE_INVALID_TARGET = { messageKey = "ARC_ORB_STATE_INVALID_TARGET" },
    STATE_READY = { messageKey = "ARC_ORB_STATE_READY" },
    STATE_NO_MATERIAL = { messageKey = "ARC_ORB_STATE_NO_MATERIAL" },
    STATE_PROCESSING = { messageKey = "ARC_ORB_STATE_PROCESSING" },
    STATE_FAILED = { messageKey = "ARC_ORB_STATE_FAILED" },
    STATE_SUCCESS = { messageKey = "ARC_ORB_STATE_SUCCESS" },
    STATE_REROLL_LIMIT = { messageKey = "ARC_ORB_STATE_REROLL_LIMIT" },
}

local function ARC_ORB_SET_STATE(frame, key)
    local state = GET_CHILD_RECURSIVELY(frame, "stateText")
    local message = ARC_ORB_STATE_MESSAGES[key]
    if state and message then
        -- 빈 상태 등록 안내는 slotGuide 한 곳에만 둔다.
        state:SetTextByKey("state", key == "STATE_EMPTY" and "" or ClMsg(message.messageKey))
    end
end

local function ARC_ORB_GET_REROLL_LIMIT(key)
    if GET_ARCHEOLOGY_ORB_REROLL_LIMIT ~= nil then
        return GET_ARCHEOLOGY_ORB_REROLL_LIMIT(key)
    end
    return 5
end

local function ARC_ORB_GET_TARGET_STATUS(orb_type, target)
    local is_class_name = type(target) == "string"
    local class_name = is_class_name and target or TryGetProp(target, "ClassName", "")
    local grade_valid = false
    if orb_type == "Transmute" then
        grade_valid = class_name:find("_N$") ~= nil
    elseif orb_type == "Divine" then
        grade_valid = class_name:find("_M$") ~= nil or class_name:find("_R$") ~= nil
    elseif orb_type == "Chaos" then
        grade_valid = class_name:find("_R$") ~= nil
    end

    if grade_valid ~= true then
        return false, "INVALID_TARGET", 0, 0
    end

    local info = ORB_INFO[orb_type]
    if info == nil or info.reroll == nil or is_class_name then
        return true, "READY", 0, 0
    end

    local reroll_meta = TryGetProp(target, "Arc_RerollMeta", "None")
    local current = GET_ARCHEOLOGY_REROLL_META_VALUE ~= nil and
        GET_ARCHEOLOGY_REROLL_META_VALUE(reroll_meta, info.reroll.key) or 0
    local limit = ARC_ORB_GET_REROLL_LIMIT(info.reroll.key)
    if current >= limit then
        return false, "REROLL_LIMIT", current, limit
    end
    return true, "READY", current, limit
end

local function ARC_ORB_IS_VALID_TARGET(orb_type, target)
    local valid = ARC_ORB_GET_TARGET_STATUS(orb_type, target)
    return valid
end

local function ARC_ORB_STOP_EFFECT(frame)
    local slot = GET_CHILD_RECURSIVELY(frame, "relicSlot")
    if slot ~= nil and slot.StopUIEffect ~= nil then
        slot:StopUIEffect(ARC_ORB_EFFECT_KEY, true, 0.0)
    end
end

local function ARC_ORB_SYNC_SLOT_PLUS(frame)
    local slot = GET_CHILD_RECURSIVELY(frame, "relicSlot")
    local slot_plus = GET_CHILD_RECURSIVELY(frame, "relicSlot_plus")
    if slot_plus == nil then return end

    local has_icon = false
    if slot ~= nil and slot.GetIcon ~= nil then
        has_icon = slot:GetIcon() ~= nil
    else
        local guid = frame:GetUserValue("RELIC_GUID")
        has_icon = guid ~= nil and guid ~= "" and guid ~= "None"
    end
    slot_plus:ShowWindow(has_icon and 0 or 1)
end

local function ARC_ORB_SET_SLOT_GUIDES(frame, show)
    local visible = show == true and 1 or 0
    local slot_guide = GET_CHILD_RECURSIVELY(frame, "slotGuide")
    if slot_guide then slot_guide:ShowWindow(visible) end
    local target = GET_CHILD_RECURSIVELY(frame, "targetCondition")
    if target then target:ShowWindow(visible) end
end

local function ARC_ORB_SET_GRADE_BADGES(frame, obj)
    local before_badge = GET_CHILD_RECURSIVELY(frame, "beforeGradeBadge")
    local after_badge = GET_CHILD_RECURSIVELY(frame, "afterGradeBadge")
    if before_badge == nil or after_badge == nil then return end
    if obj == nil then
        before_badge:ShowWindow(0)
        after_badge:ShowWindow(0)
        return
    end

    local class_name = TryGetProp(obj, "ClassName", "")
    local before_image = class_name:find("_N$") and "archeology_ui_grade_normal" or
        (class_name:find("_M$") and "archeology_ui_grade_magic" or "archeology_ui_grade_unique")
    local after_image = before_image
    if frame:GetUserValue("ORB_TYPE") == "Transmute" then
        before_image = "archeology_ui_grade_normal"
        after_image = "archeology_ui_grade_magic"
    end
    before_badge:SetImage(before_image)
    after_badge:SetImage(after_image)
    before_badge:ShowWindow(1)
    after_badge:ShowWindow(1)
end

local function ARC_ORB_UPDATE_REROLL_DISPLAY(frame, obj)
    local gauge = GET_CHILD_RECURSIVELY(frame, "rerollGauge")
    local text = GET_CHILD_RECURSIVELY(frame, "rerollText")
    local info = ORB_INFO[frame:GetUserValue("ORB_TYPE")]
    if gauge == nil or text == nil then return end
    if obj == nil or info == nil or info.reroll == nil then
        gauge:ShowWindow(0)
        text:ShowWindow(0)
        return
    end

    local reroll_meta = TryGetProp(obj, "Arc_RerollMeta", "None")
    local current = GET_ARCHEOLOGY_REROLL_META_VALUE ~= nil and
        GET_ARCHEOLOGY_REROLL_META_VALUE(reroll_meta, info.reroll.key) or 0
    local limit = ARC_ORB_GET_REROLL_LIMIT(info.reroll.key)
    if gauge.SetPoint ~= nil then gauge:SetPoint(math.min(current, limit), limit) end
    text:SetTextByKey("text", ScpArgMsg(info.reroll.messageKey,
        "CURRENT", current, "MAX", limit))
    gauge:ShowWindow(1)
    text:ShowWindow(1)
end

local function ARC_ORB_SET_STATIC_TEXTS(frame)
    local material_help = GET_CHILD_RECURSIVELY(frame, "materialHelp")
    if material_help then material_help:SetTextByKey("help", ClMsg("ARC_ORB_MATERIAL_HELP")) end
    local slot_guide = GET_CHILD_RECURSIVELY(frame, "slotGuide")
    if slot_guide then slot_guide:SetTextByKey("guide", ClMsg("ARC_ORB_SLOT_GUIDE")) end
    local before_label = GET_CHILD_RECURSIVELY(frame, "beforeLabel")
    if before_label then before_label:SetTextByKey("label", ClMsg("ARC_ORB_BEFORE_LABEL")) end
    local after_label = GET_CHILD_RECURSIVELY(frame, "afterLabel")
    if after_label then after_label:SetTextByKey("label", ClMsg("ARC_ORB_AFTER_LABEL")) end
    local close = GET_CHILD_RECURSIVELY(frame, "close")
    if close ~= nil and close.SetTextTooltip ~= nil then
        close:SetTextTooltip(ClMsg("ARC_ORB_CLOSE_TOOLTIP"))
    end
    local slot = GET_CHILD_RECURSIVELY(frame, "relicSlot")
    if slot ~= nil and slot.SetTextTooltip ~= nil then
        slot:SetTextTooltip(ClMsg("ARC_ORB_RELIC_SLOT_TOOLTIP"))
    end
end

local function ARC_ORB_RESET_COMPARISON(frame)
    ARC_ORB_SET_OPTION_TEXT(frame, "before_body", "curOptions", "curOption",
        nil, ClMsg("ARC_ORB_EMPTY_BEFORE"))
    ARC_ORB_SET_OPTION_TEXT(frame, "after_body", "resultText", "resultOption",
        nil, ClMsg("ARC_ORB_EMPTY_AFTER"))
end

local function ARC_ORB_CLEAR_SLOT(frame)
    if frame == nil then return end
    frame:SetUserValue("RELIC_GUID", "None")
    frame:SetUserValue("RESULT_STATE", "None")
    local slot = GET_CHILD_RECURSIVELY(frame, "relicSlot")
    if slot then slot:ClearIcon() end
    ARC_ORB_SYNC_SLOT_PLUS(frame)
    ARC_ORB_SET_SLOT_GUIDES(frame, true)
    ARC_ORB_SET_GRADE_BADGES(frame, nil)
    ARC_ORB_UPDATE_REROLL_DISPLAY(frame, nil)

    local item_name = GET_CHILD_RECURSIVELY(frame, "itemName")
    if item_name then
        item_name:SetTextByKey("name", "")
        item_name:ShowWindow(1)
    end
    ARC_ORB_RESET_COMPARISON(frame)
    ARC_ORB_SET_STATE(frame, "STATE_EMPTY")
    -- 등록이 풀리면 적용 버튼 활성 상태도 다시 계산한다(무효 유물 우클릭 경로 포함).
    ARC_ORB_UPDATE_MATERIAL(frame)
end

local function ARC_ORB_REFRESH_SELECTED_RELIC(frame)
    local guid = frame:GetUserValue("RELIC_GUID")
    local inv_item = guid ~= "None" and session.GetInvItemByGuid(guid) or nil
    if inv_item == nil then
        ARC_ORB_CLEAR_SLOT(frame)
        return nil, nil
    end

    local obj = GetIES(inv_item:GetObject())
    local slot = GET_CHILD_RECURSIVELY(frame, "relicSlot")
    if slot ~= nil and SET_SLOT_ITEM_IMAGE ~= nil then SET_SLOT_ITEM_IMAGE(slot, inv_item) end
    local item_name = GET_CHILD_RECURSIVELY(frame, "itemName")
    if item_name then item_name:SetTextByKey("name", TryGetProp(obj, "Name", "")) end
    ARC_ORB_SET_SLOT_GUIDES(frame, false)
    ARC_ORB_SET_GRADE_BADGES(frame, obj)
    ARC_ORB_UPDATE_REROLL_DISPLAY(frame, obj)
    ARC_ORB_SYNC_SLOT_PLUS(frame)
    return inv_item, obj
end


function ARC_ORB_UPDATE_MATERIAL(frame)
    local info = ORB_INFO[frame:GetUserValue("ORB_TYPE")]
    if not info then return end
    local cls = GetClass("Item", info.item)
    local count = cls and session.GetInvItemCountByType(cls.ClassID) or 0
    local name = GET_CHILD_RECURSIVELY(frame, "materialName")
    local icon = GET_CHILD_RECURSIVELY(frame, "materialIcon")
    local quantity = GET_CHILD_RECURSIVELY(frame, "materialCount")
    if name then name:SetTextByKey("name", TryGetProp(cls, "Name", "")) end
    if icon then icon:SetImage(TryGetProp(cls, "Icon", "archeology_ui_symbol_card")) end
    if quantity then
        quantity:SetTextByKey("countText", ScpArgMsg("ARC_ORB_MATERIAL_COUNT{COUNT}", "COUNT", count))
    end
    local guid = frame:GetUserValue("RELIC_GUID")
    local invItem = guid ~= "None" and session.GetInvItemByGuid(guid) or nil
    local selected = invItem ~= nil
    local obj = selected and GetIES(invItem:GetObject()) or nil
    local valid, target_reason = false, "EMPTY"
    if selected then
        valid, target_reason = ARC_ORB_GET_TARGET_STATUS(frame:GetUserValue("ORB_TYPE"), obj)
    end
    frame:SetUserValue("TARGET_REASON", target_reason)
    ARC_ORB_UPDATE_REROLL_DISPLAY(frame, obj)
    local pending = ARC_ORB_IS_PENDING(frame)
    local button = GET_CHILD_RECURSIVELY(frame, "applyBtn")
    if button then
        button:ShowWindow(1)
        button:SetEnable(not pending and valid and count > 0 and 1 or 0)
        local button_label = ClMsg("ARC_ORB_APPLY_LABEL")
        if pending then button_label = ClMsg("ARC_ORB_PROCESSING_LABEL") end
        button:SetTextByKey("label", button_label)
    end
    local close = GET_CHILD_RECURSIVELY(frame, "close")
    if close then close:SetEnable(pending and 0 or 1) end
    local result_state = frame:GetUserValue("RESULT_STATE")
    if not pending and (result_state == "STATE_SUCCESS" or result_state == "STATE_FAILED") then
        ARC_ORB_SET_STATE(frame, result_state)
    else
        ARC_ORB_SET_STATE(frame, pending and "STATE_PROCESSING" or
            (not selected and "STATE_EMPTY" or (target_reason == "REROLL_LIMIT" and "STATE_REROLL_LIMIT" or
            (not valid and "STATE_INVALID_TARGET" or
            (count < 1 and "STATE_NO_MATERIAL" or "STATE_READY")))))
    end
end

function ON_ARC_ORB_INVENTORY_UPDATE(frame)
    if frame:IsVisible() == 1 then ARC_ORB_UPDATE_MATERIAL(frame) end
end

function ON_ARC_ORB_FINISHED(frame, msg, guid)
    if frame:GetUserValue("PENDING_GUID") ~= guid then return end
    local succeeded = frame:GetUserValue("REQUEST_SUCCEEDED") == "YES"
    frame:SetUserValue("PENDING_GUID", "None")
    ARC_ORB_REFRESH_SELECTED_RELIC(frame)
    ARC_ORB_UPDATE_MATERIAL(frame)
    ARC_ORB_SYNC_SLOT_PLUS(frame)
    if succeeded then
        frame:SetUserValue("RESULT_STATE", "STATE_SUCCESS")
        ARC_ORB_SET_STATE(frame, "STATE_SUCCESS")
    else
        ARC_ORB_STOP_EFFECT(frame)
        if frame:GetUserValue("TARGET_REASON") ~= "REROLL_LIMIT" then
            frame:SetUserValue("RESULT_STATE", "STATE_FAILED")
            ARC_ORB_SET_STATE(frame, "STATE_FAILED")
        end
    end
end

function ARC_ORB_PENDING_TIMEOUT(requestSeq)
    local frame = ui.GetFrame('archeology_orb')
    if frame == nil or not ARC_ORB_IS_PENDING(frame) or
            frame:GetUserIValue('PENDING_SEQ') ~= requestSeq then
        return
    end
    frame:SetUserValue('PENDING_GUID', 'None')
    frame:SetUserValue('REQUEST_SUCCEEDED', 'NO')
    frame:SetUserValue('RESULT_STATE', 'None')
    local _, obj = ARC_ORB_REFRESH_SELECTED_RELIC(frame)
    if obj ~= nil then
        ARC_ORB_SET_OPTION_TEXT(frame, 'before_body', 'curOptions', 'curOption',
            GET_ARCHEOLOGY_OPTION_INFO(ARC_ORB_MERGE_META(
                TryGetProp(obj, 'Arc_Prefix', 'None'),
                TryGetProp(obj, 'Arc_Suffix', 'None'))))
        ARC_ORB_SET_OPTION_TEXT(frame, 'after_body', 'resultText',
            'resultOption', nil, ClMsg('ARC_ORB_EMPTY_AFTER'))
    end
    ARC_ORB_UPDATE_MATERIAL(frame)
    ARC_ORB_SYNC_SLOT_PLUS(frame)
    ui.SysMsg(ClMsg('ARCHEOLOGY_REQUEST_RESPONSE_TIMEOUT'))
end

function ARCHEOLOGY_ORB_ON_INIT(addon, frame)
    addon:RegisterMsg("SUCCESS_ARC_ORB", "ON_SUCCESS_ARC_ORB")
    addon:RegisterMsg("ARC_ORB_FINISHED", "ON_ARC_ORB_FINISHED")
    addon:RegisterMsg("INV_ITEM_CHANGE_COUNT", "ON_ARC_ORB_INVENTORY_UPDATE")
    addon:RegisterMsg("INV_ITEM_ADD", "ON_ARC_ORB_INVENTORY_UPDATE")
    addon:RegisterMsg("INV_ITEM_REMOVE", "ON_ARC_ORB_INVENTORY_UPDATE")
end

function ARCHEOLOGY_ORB_ON_RELOAD(frame)
    if frame == nil or frame:IsVisible() ~= 1 then return end

    local orb_type = frame:GetUserValue("ORB_TYPE")
    if ORB_INFO[orb_type] == nil then return end

    frame:SetUserValue("PENDING_GUID", "None")
    frame:SetUserValue("REQUEST_SUCCEEDED", "NO")
    ARC_ORB_STOP_EFFECT(frame)
    ARC_ORB_SET_STATIC_TEXTS(frame)
    ARC_ORB_CLEAR_SLOT(frame)
    ARC_ORB_REFRESH_UI(frame)
end

-- ── 오브 타입별 진입점 ───────────────────────────────────────────
function OPEN_ARC_ORB_UI_TRANSMUTE()
    ARC_ORB_OPEN("Transmute")
end

function OPEN_ARC_ORB_UI_DIVINE()
    ARC_ORB_OPEN("Divine")
end

function OPEN_ARC_ORB_UI_CHAOS()
    ARC_ORB_OPEN("Chaos")
end

function ARC_ORB_OPEN(orb_type)
    local current = ui.GetFrame("archeology_orb")
    if current and ARC_ORB_IS_PENDING(current) then return end
    if current then ARC_ORB_FULL_RESET(current) end
    ui.OpenFrame("archeology_orb")
    local frame = ui.GetFrame("archeology_orb")
    if not frame then return end
    frame:SetUserValue("ORB_TYPE", orb_type)
    frame:SetUserValue("RELIC_GUID", "None")
    ARC_ORB_REFRESH_UI(frame)
end

-- ── 프레임 오픈/클로즈 ────────────────────────────────────────────
function OPEN_ARCHEOLOGY_ORB(frame)
    if ARC_ORB_IS_PENDING(frame) then
        ARC_ORB_UPDATE_MATERIAL(frame)
        return
    end
    ARC_ORB_FULL_RESET(frame)
    local invframe = ui.GetFrame("inventory")
    if invframe ~= nil then
        frame:SetUserValue("INVENTORY_WAS_VISIBLE", tostring(invframe:IsVisible()))
        -- 이전 훅 저장/복원은 INVENTORY_PUSH/POP_CUSTOM_RBTNDOWN 이 처리한다.
        invframe:ShowWindow(1)
    end
    INVENTORY_PUSH_CUSTOM_RBTNDOWN(frame, "ARC_ORB_INV_RBTN")
end

function CLOSE_ARCHEOLOGY_ORB(frame)
    if ARC_ORB_IS_PENDING(frame) then frame:ShowWindow(1); return end
    local inventory_was_visible = frame:GetUserValue("INVENTORY_WAS_VISIBLE")
    local invframe = ui.GetFrame("inventory")
    INVENTORY_POP_CUSTOM_RBTNDOWN(frame, "ARC_ORB_INV_RBTN")
    ARC_ORB_FULL_RESET(frame)
    if invframe ~= nil and inventory_was_visible ~= "1" then
        invframe:ShowWindow(0)
    end
end

-- ── UI 갱신 (오브 타입 전환 시) ──────────────────────────────────
function ARC_ORB_REFRESH_UI(frame)
    local orb_type = frame:GetUserValue("ORB_TYPE")
    local info = ORB_INFO[orb_type]
    if not info then return end
    ARC_ORB_SET_STATIC_TEXTS(frame)

    local titleCtrl = GET_CHILD_RECURSIVELY(frame, "title")
    if titleCtrl then
        titleCtrl:SetTextByKey("caption", ClMsg(info.titleMsg))
    end

    local descCtrl = GET_CHILD_RECURSIVELY(frame, "orbDesc")
    if descCtrl then
        -- 구슬 창 수치는 원값이다(인벤 툴팁은 전시 효과율·증폭 반영값). 차이를 한 줄로 알린다.
        descCtrl:SetTextByKey("desc", ClMsg(info.descMsg) ..
            "{nl}{#9C978D}{s12}" .. ClMsg("ARCHEOLOGY_OPTION_RAW_VALUE_NOTE") .. "{/}{/}")
    end

    local targetCtrl = GET_CHILD_RECURSIVELY(frame, "targetCondition")
    if targetCtrl then
        targetCtrl:SetTextByKey("target", ClMsg(info.targetMsg))
        targetCtrl:ShowWindow(1)
    end
    ARC_ORB_UPDATE_MATERIAL(frame)
end

function ARC_ORB_FULL_RESET(frame)
    frame:SetUserValue("PENDING_GUID", "None")
    frame:SetUserValue("REQUEST_SUCCEEDED", "NO")
    frame:SetUserValue("TARGET_REASON", "EMPTY")
    frame:SetUserValue("ORB_TYPE", "None")
    ARC_ORB_STOP_EFFECT(frame)
    ARC_ORB_SET_STATIC_TEXTS(frame)
    ARC_ORB_CLEAR_SLOT(frame)

    local applyBtn = GET_CHILD_RECURSIVELY(frame, "applyBtn")
    if applyBtn then
        applyBtn:SetTextByKey("label", ClMsg("ARC_ORB_APPLY_LABEL"))
        applyBtn:ShowWindow(1)
    end
    local close = GET_CHILD_RECURSIVELY(frame, "close")
    if close then close:SetEnable(1) end
end

-- ── 인벤토리 우클릭 핸들러 ────────────────────────────────────────
function ARC_ORB_INV_RBTN(itemObj, slot)
    if slot == nil then return end
    local icon = slot:GetIcon()
    if not icon then return end
    local iconInfo = icon:GetInfo()
    local invItem = GET_PC_ITEM_BY_GUID(iconInfo:GetIESID())
    if not invItem then return end

    local frame = ui.GetFrame("archeology_orb")
    if frame == nil or frame:IsVisible() ~= 1 or ARC_ORB_IS_PENDING(frame) then return end
    ARC_ORB_REG_RELIC(frame, invItem)
end

-- ── 드롭/제거 핸들러 ─────────────────────────────────────────────
function ARC_ORB_RELIC_DROP(parent, ctrl)
    if ARC_ORB_IS_PENDING(parent:GetTopParentFrame()) then return end
    local frame    = parent:GetTopParentFrame()
    local liftIcon = ui.GetLiftIcon()
    if not liftIcon then return end
    local iconInfo = liftIcon:GetInfo()
    local invItem  = GET_PC_ITEM_BY_GUID(iconInfo:GetIESID())
    if not invItem then return end
    ARC_ORB_REG_RELIC(frame, invItem)
end

function ARC_ORB_RELIC_REMOVE(parent, ctrl)
    if ARC_ORB_IS_PENDING(parent:GetTopParentFrame()) then return end
    local frame = parent:GetTopParentFrame()
    ARC_ORB_CLEAR_SLOT(frame)
    ARC_ORB_UPDATE_MATERIAL(frame)
    ARC_ORB_SYNC_SLOT_PLUS(frame)
end


-- ── 유물 등록 ────────────────────────────────────────────────────
function ARC_ORB_REG_RELIC(frame, invItem)
    if frame == nil or invItem == nil then return end
    if ARC_ORB_IS_PENDING(frame) then return end
    frame:SetUserValue("RESULT_STATE", "None")
    if invItem.isLockState then
        ARC_ORB_CLEAR_SLOT(frame)
        ui.SysMsg(ClMsg("MaterialItemIsLock"))
        return
    end

    local orb_type  = frame:GetUserValue("ORB_TYPE")
    local obj       = GetIES(invItem:GetObject())
    local class_name = TryGetProp(obj, "ClassName", "")

    local clslist      = GetClassList("archeology_exhibition_item")
    local exhibitionItem = GetClassByNameFromList(clslist, class_name)
    if exhibitionItem == nil then
        ARC_ORB_CLEAR_SLOT(frame)
        ui.SysMsg(ClMsg("ARC_ORB_INVALID_RELIC"))
        return
    end

    local arc_prefix = TryGetProp(obj, "Arc_Prefix", "None")
    local arc_suffix = TryGetProp(obj, "Arc_Suffix", "None")
    local arc_meta   = ARC_ORB_MERGE_META(arc_prefix, arc_suffix)
    if arc_meta == "None" or arc_prefix:sub(1, 7) == "STAGE1:" or arc_suffix:sub(1, 7) == "STAGE1:" then
        ARC_ORB_CLEAR_SLOT(frame)
        ui.SysMsg(ClMsg("ARC_ORB_UNIDENTIFIED_RELIC"))
        return
    end

    local valid, target_reason = ARC_ORB_GET_TARGET_STATUS(orb_type, obj)
    if valid ~= true then
        ARC_ORB_CLEAR_SLOT(frame)
        local info = ORB_INFO[orb_type]
        if target_reason == "REROLL_LIMIT" then
            ui.SysMsg(ClMsg("ARC_ORB_STATE_REROLL_LIMIT"))
        else
            ui.SysMsg(ClMsg(info ~= nil and info.invalidMsg or "ARC_ORB_TARGET_INVALID"))
        end
        return
    end

    local guid = invItem:GetIESID()
    frame:SetUserValue("RELIC_GUID", guid)

    ARC_ORB_REFRESH_SELECTED_RELIC(frame)

    -- 적용 전 옵션 스냅샷 표시 (오브 적용 후에도 변경되지 않아 비교 가능)
    local beforeLabel = GET_CHILD_RECURSIVELY(frame, "beforeLabel")
    if beforeLabel then beforeLabel:ShowWindow(1) end

    local opts = GET_ARCHEOLOGY_OPTION_INFO(arc_meta)
    ARC_ORB_SET_OPTION_TEXT(frame, "before_body", "curOptions", "curOption", opts)

    -- 이전 적용 결과 초기화
    local afterLabel = GET_CHILD_RECURSIVELY(frame, "afterLabel")
    if afterLabel then afterLabel:ShowWindow(1) end
    ARC_ORB_SET_OPTION_TEXT(frame, "after_body", "resultText", "resultOption",
        nil, ClMsg("ARC_ORB_EMPTY_AFTER"))

    ARC_ORB_UPDATE_MATERIAL(frame)
    ARC_ORB_SYNC_SLOT_PLUS(frame)
    imcSound.PlaySoundEvent("inven_equip")
end

-- ── 적용 버튼 ────────────────────────────────────────────────────
function ARC_ORB_APPLY_BTN(parent, ctrl)
    local frame = parent:GetTopParentFrame()
    if ARC_ORB_IS_PENDING(frame) then return end
    local guid  = frame:GetUserValue("RELIC_GUID")
    local invItem = guid ~= "None" and session.GetInvItemByGuid(guid) or nil
    if invItem == nil then return end

    local orb_type = frame:GetUserValue("ORB_TYPE")
    local info = ORB_INFO[orb_type]
    local obj = GetIES(invItem:GetObject())
    if info == nil or ARC_ORB_IS_VALID_TARGET(orb_type, obj) ~= true then
        ARC_ORB_UPDATE_MATERIAL(frame)
        return
    end
    local orb_cls = GetClass("Item", info.item)
    local yesscp   = string.format("EXEC_ARC_ORB('%s', '%s')", guid, orb_type)
    local confirm_text = ScpArgMsg("ARC_ORB_CONFIRM{ORB}{RELIC}",
        "ORB", TryGetProp(orb_cls, "Name", ""),
        "RELIC", TryGetProp(obj, "Name", ""))
    local msgbox   = ui.MsgBox(confirm_text, yesscp, "None")
    SET_MODAL_MSGBOX(msgbox)
end

function EXEC_ARC_ORB(guid, orb_type)
    local frame = ui.GetFrame("archeology_orb")
    if frame == nil or frame:IsVisible() == 0 or ARC_ORB_IS_PENDING(frame) then return end
    if guid ~= frame:GetUserValue("RELIC_GUID") or orb_type ~= frame:GetUserValue("ORB_TYPE") then return end

    local invItem = session.GetInvItemByGuid(guid)
    if not invItem then return end

    local info = ORB_INFO[orb_type]
    if not info then return end

    local obj = GetIES(invItem:GetObject())
    if ARC_ORB_IS_VALID_TARGET(orb_type, obj) ~= true then
        ARC_ORB_UPDATE_MATERIAL(frame)
        return
    end
    ARC_ORB_SET_OPTION_TEXT(frame, "before_body", "curOptions", "curOption",
        GET_ARCHEOLOGY_OPTION_INFO(ARC_ORB_MERGE_META(
            TryGetProp(obj, "Arc_Prefix", "None"), TryGetProp(obj, "Arc_Suffix", "None"))))
    frame:SetUserValue("PENDING_GUID", guid)
    frame:SetUserValue("REQUEST_SUCCEEDED", "NO")
    frame:SetUserValue("RESULT_STATE", "None")
    local requestSeq = frame:GetUserIValue('PENDING_SEQ') + 1
    frame:SetUserValue('PENDING_SEQ', requestSeq)
    ARC_ORB_STOP_EFFECT(frame)
    ARC_ORB_UPDATE_MATERIAL(frame)

    pc.ReqExecuteTx_Item(info.tx, guid)
    ReserveScript(string.format('ARC_ORB_PENDING_TIMEOUT(%d)', requestSeq), 12)
end

-- ── 서버 응답 ────────────────────────────────────────────────────
function ON_SUCCESS_ARC_ORB(frame, msg, argStr, argNum)
    if not ARC_ORB_IS_PENDING(frame) then return end
    frame:SetUserValue("REQUEST_SUCCEEDED", "YES")
    ARC_ORB_STOP_EFFECT(frame)

    local opts = GET_ARCHEOLOGY_OPTION_INFO(argStr)

    -- curOptions는 유지(적용 전 스냅샷) — afterLabel/resultText에만 결과 반영
    local afterLabel = GET_CHILD_RECURSIVELY(frame, "afterLabel")
    if afterLabel then afterLabel:ShowWindow(1) end

    ARC_ORB_SET_OPTION_TEXT(frame, "after_body", "resultText", "resultOption", opts)

    -- 버튼 재활성화
    local applyBtn = GET_CHILD_RECURSIVELY(frame, "applyBtn")
    if applyBtn then applyBtn:ShowWindow(1) end
end
