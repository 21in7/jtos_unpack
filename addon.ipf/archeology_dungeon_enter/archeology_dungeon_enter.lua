-- archeology_dungeon_enter.lua
-- 고고학 탐사 포탈 진입 UI — 난이도 선택 + 가변형 입장/강화 아이템 목록
-- 서버: SendAddOnMsg(pc, "ARCHEOLOGY_DUNGEON_ENTER_OPEN",
--     "portalHandle|diff|mapTrait|region|missionLevel|exterminationMissCount")
-- 클→서: pc.ReqExecuteTx_NumArgs("SCR_ARCHEOLOGY_DUNGEON_ENTER", "handle difficultyCode entryClassId res1ClassId res2ClassId")

-- ── 유효한 진입 아이템 목록 (서버 DUNGEON_MODIFIER와 동기화 필요) ────────────
local VALID_MODIFIER_ITEMS = {
    Blessed_Dig_Lantern = true,
    Relic_Incense = true,
    Shard_Resonator = true,
    Corrupted_Relic_Shard = true,
    Ancient_Rage_Stone = true,
    Cursed_Excavation_Seal = true,
}

local VALID_BOSS_ENTRY_ITEMS = {
    Arc_Boss_Portal_Nebulas = "Open Nebulas boss seal",
}

local VALID_DEEP_ENTRY_ITEMS = {
    Weekly_Dig_Permit = "Enable deep exploration",
}

local LAST_SETTING_CONFIG_KEY = "ARCHEOLOGY_DUNGEON_ENTER_LAST_SETTING"
local PORTAL_ITEM_CONTROLSET_NAME = "archeology_portal_item_slot"
local ARCH_DENTER_CONFIRM_KEY = "ARCH_DENTER_CONFIRM"
local PORTAL_ITEM_SET_WIDTH = 142
local PORTAL_ITEM_SET_HEIGHT = 220
local PORTAL_ITEM_SET_GAP = 8
local PORTAL_ITEM_MAX_COLUMNS = 3

-- 예상 결과 카드 색상 (증가 델타 = 초록, 감소 = 주황)
local DELTA_UP_COLOR    = "{#8FCB9B}"
local DELTA_DOWN_COLOR  = "{#FFB29B}"
local COLOR_POWER       = "{#FFB29B}"
local COLOR_RARE        = "{#D9B4F0}"
local COLOR_SHARD       = "{#E8CF8B}"
local COLOR_MEMORY      = "{#D9B4F0}"
local COLOR_DIM         = "{#A89880}"
local COLOR_CONSUME     = "{#C2705C}"

-- 모듈-레벨 상태
local g_portalHandle = ""
local g_diff         = "D1"
local g_difficultyChoice = "NORMAL"
local g_deepMode = false
local g_entryClassId = 0   -- 입장 증표 슬롯 (보스 증표 / 심층 탐사 허가증 전용)
local g_slot1ClassId = 0   -- 탐험 기록 슬롯 1
local g_slot2ClassId = 0   -- 탐험 기록 슬롯 2
local g_mapTrait = "ForgottenGoddess"
local g_exhibitionLevel = 1
local g_rewardRegion = "All"
local g_missionLevel = 470
local g_exterminationMissCount = 0

-- ── 유틸리티 ──────────────────────────────────────────────────────────────────

local function GET_FRAME()
    return ui.GetFrame("archeology_dungeon_enter")
end

local function GET_DIFFICULTY_CHOICE_LABEL(choice)
    if choice == "EASY" then
        return ClMsg("ARCHEOLOGY_DUNGEON_DIFFICULTY_EASY_DESC")
    end
    if choice == "HARD" then
        return ClMsg("ARCHEOLOGY_DUNGEON_DIFFICULTY_HARD_DESC")
    end
    if choice == "VERY_HARD" then
        return ClMsg("ARCHEOLOGY_DUNGEON_DIFFICULTY_VERY_HARD_DESC")
    end
    return ClMsg("ARCHEOLOGY_DUNGEON_DIFFICULTY_NORMAL_DESC")
end

local function GET_DIFFICULTY_CHOICE_CODE(choice)
    if choice == "EASY" then
        return 1
    end
    if choice == "HARD" then
        return 3
    end
    if choice == "VERY_HARD" then
        return 4
    end
    return 2
end

local function GET_DEFAULT_DIFFICULTY_CHOICE(diff)
    if diff == "D3" then
        return "VERY_HARD"
    end
    if diff == "D2" then
        return "HARD"
    end
    return "NORMAL"
end

local function SHOW_EXHIBITION_LEVEL_LOCK(requiredLevel)
    ui.SysMsg(ScpArgMsg("ARCHEOLOGY_DUNGEON_LOCKED_LEVEL", "LEVEL", requiredLevel))
end

local function IS_RISK_DIFFICULTY_UNLOCKED()
    return g_exhibitionLevel >= GET_ARCHEOLOGY_EXHIBITION_UNLOCK_LEVEL("RISK_EXPLORATION")
end

local function GET_ITEM_CLASSNAME_BY_CLASS_ID(classId)
    classId = tonumber(classId) or 0
    if classId <= 0 then
        return ""
    end

    local cls = GetClassByType("Item", classId)
    if cls == nil then
        return ""
    end

    return TryGetProp(cls, "ClassName", "")
end

local function FORMAT_PORTAL_NUMBER(value)
    local text = string.format("%.2f", tonumber(value) or 0)
    text = string.gsub(text, "0+$", "")
    text = string.gsub(text, "%.$", "")
    return text
end

local function IS_BOSS_ENTRY_SELECTED()
    return VALID_BOSS_ENTRY_ITEMS[
        GET_ITEM_CLASSNAME_BY_CLASS_ID(g_entryClassId)] ~= nil
end

local function GET_EFFECTIVE_DIFFICULTY()
    if IS_BOSS_ENTRY_SELECTED() then
        return "BOSS_NEBULAS"
    end
    return g_difficultyChoice
end

local function REFRESH_DIFFICULTY_UI(frame)
    local isBoss = IS_BOSS_ENTRY_SELECTED()
    local riskUnlocked = IS_RISK_DIFFICULTY_UNLOCKED()
    local riskLevel = GET_ARCHEOLOGY_EXHIBITION_UNLOCK_LEVEL("RISK_EXPLORATION")
    local choices = { "EASY", "NORMAL", "HARD", "VERY_HARD" }
    local names = { "btn_diff_easy", "btn_diff_normal", "btn_diff_hard", "btn_diff_very_hard" }
    local lockNames = { nil, nil, "lock_diff_hard", "lock_diff_very_hard" }
    for index, choice in ipairs(choices) do
        local button = GET_CHILD_RECURSIVELY(frame, names[index])
        if button ~= nil then
            local unlocked = index <= 2 or riskUnlocked
            button:SetEnable(not isBoss and unlocked and 1 or 0)
            button:SetColorTone(not isBoss and g_difficultyChoice == choice and "FFFFF4B0" or "FFFFFFFF")
            -- 잠금 사유는 자물쇠 아이콘 + 툴팁 한 규칙으로 통일한다.
            button:SetTextTooltip(unlocked and "" or
                ScpArgMsg("ARCHEOLOGY_DUNGEON_LOCKED_LEVEL", "LEVEL", riskLevel))
        end
        local lockCtrl = lockNames[index] ~= nil and
            GET_CHILD_RECURSIVELY(frame, lockNames[index]) or nil
        if lockCtrl ~= nil then
            lockCtrl:ShowWindow((not riskUnlocked and not isBoss) and 1 or 0)
        end
    end

    -- 보스 증표를 넣으면 난이도 줄 전체를 고정 안내로 바꾼다.
    local diffGroup = GET_CHILD_RECURSIVELY(frame, "difficulty_group")
    if diffGroup ~= nil then
        diffGroup:ShowWindow(isBoss and 0 or 1)
    end
    local bossDiffBox = GET_CHILD_RECURSIVELY(frame, "boss_diff_box")
    if bossDiffBox ~= nil then
        bossDiffBox:ShowWindow(isBoss and 1 or 0)
    end

end

local function REFRESH_MAP_TRAIT_UI(frame)
    local ctrl = GET_CHILD_RECURSIVELY(frame, "map_trait_desc")
    if ctrl == nil then
        return
    end

    local profile = shared_archeology.get_map_trait_profile(g_mapTrait)
    if profile == nil then
        ctrl:SetTextByKey("map_trait_style", "")
        ctrl:SetTextByKey("map_trait_name", "")
        ctrl:SetTextByKey("map_trait_reward", "")
        return
    end

    local color = profile.color or "FFFFFF"
    ctrl:SetTextByKey("map_trait_style", "{#" .. color .. "}")
    ctrl:SetTextByKey("map_trait_name", ClMsg(profile.titleMsg))
    ctrl:SetTextByKey("map_trait_reward", ClMsg(profile.rewardMsg))
end

local function GET_SLOT_EMPTY_TEXT(slotKey)
    if slotKey == "entry" then
        -- 보스전과 심층 탐사는 해금 등급이 다르다. 허가증을 넣기 전에도 두 조건을 각각 보여 준다.
        local bossLevel = GET_ARCHEOLOGY_EXHIBITION_UNLOCK_LEVEL("BOSS_NEBULAS")
        local deepLevel = GET_ARCHEOLOGY_EXHIBITION_UNLOCK_LEVEL("DEEP_EXPLORATION")
        if g_exhibitionLevel < bossLevel then
            return ScpArgMsg("ARCHEOLOGY_PORTAL_ENTRY_SLOT_LOCKED{BOSS}{DEEP}",
                "BOSS", bossLevel, "DEEP", deepLevel)
        end
        if g_exhibitionLevel < deepLevel then
            return ScpArgMsg("ARCHEOLOGY_PORTAL_ENTRY_SLOT_DEEP_LOCKED{LEVEL}",
                "LEVEL", deepLevel)
        end
        return ClMsg("ARCHEOLOGY_PORTAL_ENTRY_SLOT_EMPTY")
    end
    local requiredKey = slotKey == 1 and "RECORD_SLOT_1" or "RECORD_SLOT_2"
    local requiredLevel = GET_ARCHEOLOGY_EXHIBITION_UNLOCK_LEVEL(requiredKey)
    if g_exhibitionLevel < requiredLevel then
        return ScpArgMsg("ARCHEOLOGY_PORTAL_RECORD_SLOT_LOCKED{SLOT}{LEVEL}",
            "SLOT", slotKey, "LEVEL", requiredLevel)
    end
    return ScpArgMsg("ARCHEOLOGY_PORTAL_RECORD_SLOT_EMPTY{SLOT}",
        "SLOT", slotKey)
end

-- ClassID로 인벤토리에서 아이템을 검색 (첫 번째 일치 아이템 반환)
local function GetInvItemByClassId(classId)
    if classId == 0 then return nil end
    local itemList = session.GetInvItemList()
    if itemList == nil then return nil end
    local guidList = itemList:GetGuidList()
    local cnt = guidList:Count()
    for i = 0, cnt - 1 do
        local guid    = guidList:Get(i)
        local invItem = session.GetInvItemByGuid(guid)
        if invItem ~= nil then
            local cls = GetIES(invItem:GetObject())
            if cls ~= nil and tonumber(TryGetProp(cls, "ClassID", "0")) == classId then
                return invItem
            end
        end
    end
    return nil
end

-- 효과 미리보기 텍스트 갱신 (세 슬롯 모두 반영)
local function GET_SELECTED_MODIFIER_ITEMS()
    local result = {}
    local item1 = GET_ITEM_CLASSNAME_BY_CLASS_ID(g_slot1ClassId)
    local item2 = GET_ITEM_CLASSNAME_BY_CLASS_ID(g_slot2ClassId)
    if item1 ~= "" then
        result[#result + 1] = item1
    end
    if item2 ~= "" then
        result[#result + 1] = item2
    end
    return result
end

-- modifierItems/deepMode 를 넘기지 않으면 현재 선택 상태로 계산한다.
-- 델타 기준선은 modifierItems={}, deepMode=false 로 한 번 더 호출해서 얻는다.
-- (심층 허가증 기여분은 data.combat.modifier 같은 분리 필드에 없어서
--  분리 필드만으로 계산하면 델타가 0으로 나온다. 2회 호출이 유일하게 정확하다.)
local function BUILD_REWARD_PREVIEW_DATA(modifierItems, deepMode, difficultyOverride,
        exhibitionLevelOverride)
    -- 등급을 바꿔 계산하는 가이드 행은 옵션 효과도 그 등급 배율로 다시 계산한다.
    local options = GET_CURRENT_APPLY_EFFECT_LIST(nil, exhibitionLevelOverride) or {}
    local bossUnlockLevel = GET_ARCHEOLOGY_EXHIBITION_UNLOCK_LEVEL("NEBULAS_BONUS")
    local exhibitionLevel = exhibitionLevelOverride or g_exhibitionLevel
    if modifierItems == nil then
        modifierItems = GET_SELECTED_MODIFIER_ITEMS()
        deepMode = g_deepMode
    end
    return shared_archeology.build_portal_entry_preview({
        difficulty = difficultyOverride or GET_EFFECTIVE_DIFFICULTY(),
        deepMode = deepMode,
        mapTrait = g_mapTrait,
        region = g_rewardRegion,
        missionLevel = g_missionLevel,
        exhibitionLevel = exhibitionLevel,
        exterminationMissCount = g_exterminationMissCount,
        threatGrade = "DEFAULT",
        modifierItems = modifierItems,
        options = options,
        bossExhibitionBonusUnlocked = exhibitionLevel >= bossUnlockLevel,
    })
end

local function SHOW_PREVIEW_CONTROL(frame, controlName, visible)
    local ctrl = GET_CHILD_RECURSIVELY(frame, controlName)
    if ctrl ~= nil then
        ctrl:ShowWindow(visible and 1 or 0)
    end
end

local function SAVE_LAST_SETTING()
    config.SetConfig(LAST_SETTING_CONFIG_KEY,
        tostring(g_difficultyChoice) .. ";"
        .. tostring(g_entryClassId) .. ";"
        .. tostring(g_slot1ClassId) .. ";"
        .. tostring(g_slot2ClassId))
end

local function SET_SLOT_CLASS_ID(slotIndex, classId)
    classId = tonumber(classId) or 0
    if classId <= 0 then
        return true
    end

    local className = GET_ITEM_CLASSNAME_BY_CLASS_ID(classId)
    if slotIndex == "entry" then
        if VALID_BOSS_ENTRY_ITEMS[className] == nil and VALID_DEEP_ENTRY_ITEMS[className] == nil then
            return false
        end
        if VALID_BOSS_ENTRY_ITEMS[className] ~= nil and
                (g_slot1ClassId ~= 0 or g_slot2ClassId ~= 0) then
            return false
        end
        if GetInvItemByClassId(classId) == nil then
            return false
        end
        if VALID_DEEP_ENTRY_ITEMS[className] ~= nil and g_exhibitionLevel < GET_ARCHEOLOGY_EXHIBITION_UNLOCK_LEVEL("DEEP_EXPLORATION") then
            return false
        end
        if VALID_BOSS_ENTRY_ITEMS[className] ~= nil and g_exhibitionLevel < GET_ARCHEOLOGY_EXHIBITION_UNLOCK_LEVEL("BOSS_NEBULAS") then
            return false
        end
        g_entryClassId = classId
        g_deepMode = VALID_DEEP_ENTRY_ITEMS[className] ~= nil
        return true
    end

    if VALID_MODIFIER_ITEMS[className] == nil then
        return false
    end
    if IS_BOSS_ENTRY_SELECTED() then
        return false
    end
    if GetInvItemByClassId(classId) == nil then
        return false
    end

    local slotCount = GET_ARCHEOLOGY_EXHIBITION_RECORD_SLOT_COUNT(g_exhibitionLevel)
    if tonumber(slotIndex) == nil or slotIndex > slotCount then
        return false
    end

    if slotIndex == 1 then
        if g_slot2ClassId == classId then
            return false
        end
        g_slot1ClassId = classId
        return true
    end

    if g_slot1ClassId == classId then
        return false
    end
    g_slot2ClassId = classId
    return true
end

-- ── 예상 결과 카드 ───────────────────────────────────────────────────────────

local function FORMAT_CARD_VALUE(text, color)
    return (color or "{#F1E8D9}") .. "{s24}" .. tostring(text) .. "{/}"
end

local function FORMAT_ROW_VALUE(text, color)
    return (color or "{#F1E8D9}") .. "{s20}" .. tostring(text) .. "{/}"
end

-- 확정 수량 열. 값이 없으면 빈 칸으로 둔다(억지로 채우지 않는다).
local function FORMAT_GUARANTEED(count)
    count = tonumber(count) or 0
    if count <= 0 then
        return ""
    end
    return "{@st66d_y}{s15}" ..
        ScpArgMsg("ARCHEOLOGY_PORTAL_GUARANTEED{COUNT}", "COUNT", count) .. "{/}"
end

-- 델타가 0이면 빈 문자열을 돌려준다. 아이템을 안 넣었으면 델타 열이 통째로
-- 비어 보이고, 뭔가 등록했을 때만 눈에 들어온다.
-- unit: 확률 증감은 "%p"(툴팁 분해 줄과 같은 단위). 배율·수량은 값 쪽 표기로 구분되므로 생략.
local function FORMAT_DELTA(value, unit)
    value = tonumber(value) or 0
    if value > -0.005 and value < 0.005 then
        return ""
    end
    local color = value > 0 and DELTA_UP_COLOR or DELTA_DOWN_COLOR
    local arrow = value > 0 and "▲+" or "▼"
    return color .. "{s15}" .. arrow .. FORMAT_PORTAL_NUMBER(value) ..
        (unit or "") .. "{/}"
end

local function SET_CARD(frame, card, titleText, subText, valueText, deltaText)
    local titleCtrl = GET_CHILD_RECURSIVELY(frame, card .. "_title")
    if titleCtrl ~= nil then
        titleCtrl:SetTextByKey(card .. "_title_val", titleText or "")
        titleCtrl:SetTextByKey(card .. "_sub_val", subText or "")
    end
    local valueCtrl = GET_CHILD_RECURSIVELY(frame, card .. "_value")
    if valueCtrl ~= nil then
        valueCtrl:SetTextByKey(card .. "_value_val", valueText or "")
    end
    local deltaCtrl = GET_CHILD_RECURSIVELY(frame, card .. "_delta")
    if deltaCtrl ~= nil then
        deltaCtrl:SetTextByKey(card .. "_delta_val", deltaText or "")
    end
end

-- card_c 전용 3행 표. 행마다 레이블/값/델타 컨트롤을 따로 둔다.
-- 한 컨트롤에 {nl} 로 3줄을 넣으면 레이블(s12)과 값(s15)의 줄 높이가 달라
-- 행이 아래로 갈수록 어긋난다.
local function SET_CARD_ROWS(frame, card, rows)
    for index = 1, 3 do
        local row = rows[index] or {}
        local pairsToSet = {
            { "_l" .. index, row.label },
            { "_g" .. index, row.guaranteed },
            { "_v" .. index, row.value },
            { "_d" .. index, row.delta },
        }
        for _, entry in ipairs(pairsToSet) do
            local ctrl = GET_CHILD_RECURSIVELY(frame, card .. entry[1])
            if ctrl ~= nil then
                ctrl:SetTextByKey(card .. entry[1] .. "_val", entry[2] or "")
            end
        end
        -- 아이템 아이콘. 3종 파편은 이름이 서로 닮아 아이콘이 있어야 구분된다.
        local iconCtrl = GET_CHILD_RECURSIVELY(frame, card .. "_i" .. index)
        if iconCtrl ~= nil then
            local iconName = ""
            if row.itemClassName ~= nil and row.itemClassName ~= "" then
                local cls = GetClass("Item", row.itemClassName)
                if cls ~= nil then
                    iconName = TryGetProp(cls, "Icon", "")
                end
            end
            if iconName ~= "" then
                iconCtrl:SetImage(iconName)
                iconCtrl:ShowWindow(1)
            else
                iconCtrl:ShowWindow(0)
            end
        end
    end
end

-- 아이템 정식 명칭을 클래스에서 읽어 쓴다(하드코딩/현지화 누락 방지).
local function GET_ITEM_NAME(className, fallbackMsg)
    local cls = className ~= nil and GetClass("Item", className) or nil
    local name = cls ~= nil and TryGetProp(cls, "Name", "") or ""
    if name ~= "" then
        return name
    end
    return ClMsg(fallbackMsg)
end

-- 카드 groupbox 는 hittestbox="false" 라 마우스를 받지 않는다.
-- 툴팁은 반드시 안쪽 richtext 에 붙인다. (groupbox 에 붙이려고 hittestbox 를
--  켜면 아이템 슬롯 드롭 판정을 가로챈다.)
local function SET_CARD_TOOLTIP(frame, card, tooltip)
    local suffixes = { "_title", "_value",
        "_l1", "_g1", "_v1", "_l2", "_g2", "_v2", "_l3", "_g3", "_v3" }
    for _, suffix in ipairs(suffixes) do
        local ctrl = GET_CHILD_RECURSIVELY(frame, card .. suffix)
        if ctrl ~= nil then
            ctrl:SetTextTooltip(tooltip or "")
        end
    end
end

local function TIP_LINE(labelMsg, value, suffix)
    return "{#A89880}{s13}" .. ClMsg(labelMsg) .. "{/}  {#F1E8D9}{s14}" ..
        FORMAT_PORTAL_NUMBER(value) .. (suffix or "") .. "{/}"
end

local function BUILD_BREAKDOWN(titleMsg, finalValue, parts)
    local lines = {
        "{#FFF4D0}{s15}" .. ClMsg(titleMsg) .. "{/}  {#E8CF8B}{s16}" ..
            FORMAT_PORTAL_NUMBER(finalValue) .. "%{/}",
    }
    for _, part in ipairs(parts) do
        lines[#lines + 1] = TIP_LINE(part[1], part[2], part[3] or "%p")
    end
    return table.concat(lines, "{nl}")
end

local function INDEPENDENT_NOTE()
    return "{#8A7A64}{s12}" .. ClMsg("ARCHEOLOGY_PORTAL_TIP_INDEPENDENT") .. "{/}"
end

-- 서버는 난이도 보정과 강화 아이템 보정을 같은 기본 스탯에 각각 더한다
-- (archeology_dungeon_combat.lua apply_mon_stat_rate → ADD_BM).
-- 그래서 %는 축 안에서 더하고, 축끼리만 곱한다.
-- 아이템 보정은 몬스터 타입마다 달라지므로, 가장 많이 상대하는 일반 몬스터 기준.
-- 제단 등급별 희귀 보상 확률 가이드. 지금 입장 창 설정(난이도·지역·강화 아이템·옵션)을
-- 그대로 두고 제단 등급만 바꿔 같은 공식(build_portal_entry_preview)으로 계산한다.
-- 반환: 툴팁 문자열, 희귀 풀이 처음 열리는 제단 등급(없으면 nil)
local function BUILD_RARE_GUIDE_TOOLTIP()
    local maxLevel = math.max(1, tonumber(GET_ARCHEOLOGY_EXHIBITION_MAX_LEVEL()) or 1)
    local unlockLevel = nil
    -- 같은 확률이 이어지는 등급은 한 줄로 묶는다(행 수를 줄여 글자를 키울 여유를 만든다).
    local rows = {}
    for level = 1, maxLevel do
        local clear = (BUILD_REWARD_PREVIEW_DATA(nil, nil, nil, level) or {}).clear or {}
        if unlockLevel == nil and (tonumber(clear.rareWeight) or 0) > 0 then
            unlockLevel = level
        end
        local valueText = FORMAT_PORTAL_NUMBER(clear.finalRare) .. "%"
        local last = rows[#rows]
        if last ~= nil and last.valueText == valueText then
            last.to = level
        else
            rows[#rows + 1] = { from = level, to = level, valueText = valueText }
        end
    end

    local lines = {
        "{@st42b}{s16}" .. ClMsg("ARCHEOLOGY_PORTAL_RARE_GUIDE_TITLE") .. "{/}",
    }
    for _, row in ipairs(rows) do
        local label = row.from == row.to and
            ScpArgMsg("ARCHEOLOGY_PORTAL_RARE_GUIDE_LEVEL{LEVEL}", "LEVEL", row.from) or
            ScpArgMsg("ARCHEOLOGY_PORTAL_RARE_GUIDE_RANGE{FROM}{TO}",
                "FROM", row.from, "TO", row.to)
        local isCurrent = g_exhibitionLevel >= row.from and g_exhibitionLevel <= row.to
        lines[#lines + 1] = (isCurrent and "{#FFD76A}" or "{#DCD2C0}") .. "{s15}" ..
            label .. "{/}   " .. (isCurrent and "{#FFD76A}" or "{#FFFFFF}") .. "{s16}" ..
            row.valueText ..
            (isCurrent and ("  " .. ClMsg("ARCHEOLOGY_PORTAL_RARE_GUIDE_CURRENT")) or "") ..
            "{/}"
    end
    lines[#lines + 1] = "{#BFB3A0}{s14}" .. ClMsg("ARCHEOLOGY_PORTAL_RARE_GUIDE_NOTE") .. "{/}"
    return table.concat(lines, "{nl}"), unlockLevel
end

-- 가이드 버튼을 제목 글자 바로 뒤에 둔다(제목 뒤 보조 문구 길이가 바뀌므로 매번 맞춘다).
local function PLACE_RARE_GUIDE_BUTTON(frame, visible, tooltip)
    local guide = GET_CHILD_RECURSIVELY(frame, "card_b_guide")
    if guide == nil then
        return
    end
    if visible ~= true then
        guide:ShowWindow(0)
        return
    end
    local title = GET_CHILD_RECURSIVELY(frame, "card_b_title")
    local left = 100
    if title ~= nil then
        left = math.min(title:GetX() + title:GetTextWidth() + 6, 196)
    end
    guide:SetMargin(left, 0, 0, 0)
    guide:SetTextTooltip(tooltip or "")
    guide:ShowWindow(1)
end

local function GET_POWER_MULTIPLIER(combat)
    if combat == nil then
        return 1
    end
    local modifier = combat.modifier or {}
    -- 서버는 난이도·위협 배율을 먼저 적용한 스탯에 강화 아이템 %를 곱한다(복리). 표시도 같게 곱한다.
    local function compound(basePct, itemPct)
        return (1 + (tonumber(basePct) or 0) / 100) *
            (1 + (tonumber(itemPct) or 0) / 100)
    end
    local hp = compound(combat.hpPct, modifier.normalHpPct)
    local atk = compound(combat.atkPct, modifier.normalAtkPct)
    local def = compound(combat.defPct, modifier.normalDefPct)
    return hp * def * atk
end

local function BUILD_POWER_TOOLTIP(data)
    local combat = data.combat or {}
    local modifier = combat.modifier or {}
    local function statLine(labelMsg, hpPct, atkPct, defPct)
        return "{#A89880}{s11}" .. ClMsg(labelMsg) .. "{/}  {#F1E8D9}{s12}HP +" ..
            FORMAT_PORTAL_NUMBER(hpPct) .. "% / ATK +" ..
            FORMAT_PORTAL_NUMBER(atkPct) .. "% / DEF +" ..
            FORMAT_PORTAL_NUMBER(defPct) .. "%{/}"
    end
    return table.concat({
        "{#FFF4D0}{s13}" .. ClMsg("ARCHEOLOGY_PORTAL_CARD_POWER") .. "{/}",
        statLine("ARCHEOLOGY_PORTAL_TIP_DIFFICULTY",
            combat.hpPct, combat.atkPct, combat.defPct),
        statLine("ARCHEOLOGY_PORTAL_TIP_RECORD",
            modifier.normalHpPct, modifier.normalAtkPct, modifier.normalDefPct),
        "{#8A7A64}{s10}" .. ClMsg("ARCHEOLOGY_PORTAL_TIP_POWER_NOTE") .. "{/}",
    }, "{nl}")
end

local function BUILD_MISSION_TOOLTIP(data)
    local mission = data.mission or {}
    return table.concat({
        "{#FFF4D0}{s13}" .. ClMsg("ARCHEOLOGY_PORTAL_TIP_MISSION_TITLE") .. "{/}",
        TIP_LINE("ARCHEOLOGY_PORTAL_MISSION_EXTERM", mission.exterminationWeight, "%"),
        TIP_LINE("ARCHEOLOGY_PORTAL_MISSION_DEFENSE", mission.defenseWeight, "%"),
        TIP_LINE("ARCHEOLOGY_PORTAL_MISSION_SEAL", mission.sealWeight, "%"),
        " ",
        "{#FFF4D0}{s13}" .. ClMsg("ARCHEOLOGY_PORTAL_TIP_MISSION_TARGET") .. "{/}",
        -- 섬멸 목표 처치 수(공식 값). 실제 목표는 입장 후 배치된 전투원 수를 따른다.
        "{#A89880}{s13}" .. ClMsg("ARCHEOLOGY_PORTAL_MISSION_KILLS") .. "{/}  {#F1E8D9}{s14}" ..
            ScpArgMsg("ARCHEOLOGY_PORTAL_TARGET_COUNT{COUNT}", "COUNT",
                FORMAT_PORTAL_NUMBER(mission.targetKills)) .. "{/}",
        TIP_LINE("ARCHEOLOGY_PORTAL_MISSION_WAVES", mission.defenseWaves, ""),
        TIP_LINE("ARCHEOLOGY_PORTAL_MISSION_CHESTS", mission.sealChests, ""),
    }, "{nl}")
end

-- 등록한 아이템은 입장 시 소모되므로 이름을 그대로 보여준다.
local function BUILD_CONSUME_TEXT()
    local names = {}
    for _, classId in ipairs({ g_entryClassId, g_slot1ClassId, g_slot2ClassId }) do
        if classId ~= 0 then
            local cls = GetClassByType("Item", classId)
            if cls ~= nil then
                names[#names + 1] = TryGetProp(cls, "Name", "")
            end
        end
    end
    return table.concat(names, " · ")
end

local function SET_SIDE_LINE(frame, controlName, labelText, valueText)
    local ctrl = GET_CHILD_RECURSIVELY(frame, controlName)
    if ctrl == nil then
        return
    end
    local prefix = controlName == "extra_line" and "extra" or "consume"
    ctrl:SetTextByKey(prefix .. "_label_val", labelText or "")
    ctrl:SetTextByKey(prefix .. "_value_val", valueText or "")
end

local function REFRESH_EFFECT_NORMAL(frame, data, base)
    local clear = data.clear or {}
    local bonus = data.bonus or {}
    local relic = data.relic or {}
    local baseClear = base.clear or {}
    local baseBonus = base.bonus or {}
    local baseRelic = base.relic or {}
    local function diff(now, was)
        return (tonumber(now) or 0) - (tonumber(was) or 0)
    end

    -- 카드 A : 적 강도
    local power = GET_POWER_MULTIPLIER(data.combat)
    SET_CARD(frame, "card_a",
        ClMsg("ARCHEOLOGY_PORTAL_CARD_POWER"),
        GET_DIFFICULTY_CHOICE_LABEL(g_difficultyChoice),
        FORMAT_CARD_VALUE("×" .. string.format("%.1f", power), COLOR_POWER),
        FORMAT_DELTA(power - GET_POWER_MULTIPLIER(base.combat)))
    SET_CARD_TOOLTIP(frame, "card_a", BUILD_POWER_TOOLTIP(data))

    -- 카드 B : 희귀 보상
    if clear.poolAvailable == true then
        local exhibitionBonusTip = ""
        local exhibitionBonuses = clear.exhibitionBonuses or {}
        local coinBonus = exhibitionBonuses.Archeology_Dig_Coin
        local fragmentBonus = exhibitionBonuses.Ancient_Memory_Fragment
        if coinBonus ~= nil and fragmentBonus ~= nil then
            exhibitionBonusTip = ScpArgMsg(
                "ARCHEOLOGY_PORTAL_EXHIBITION_BONUS_CHANCE{COIN}{FRAGMENT}",
                "COIN", FORMAT_PORTAL_NUMBER(coinBonus.chance),
                "FRAGMENT", FORMAT_PORTAL_NUMBER(fragmentBonus.chance))
        end
        -- 희귀 풀이 아직 안 열린 제단 등급이면 확률이 0% 로 고정된다. 개방 등급을 작게 알린다.
        local rareGuideTooltip, rareUnlockLevel = BUILD_RARE_GUIDE_TOOLTIP()
        local rareSubText = ""
        if (tonumber(clear.rareWeight) or 0) <= 0 and rareUnlockLevel ~= nil and
                rareUnlockLevel > g_exhibitionLevel then
            rareSubText = "{#E8CF8B}" .. ScpArgMsg("ARCHEOLOGY_PORTAL_RARE_LOCKED{LEVEL}",
                "LEVEL", rareUnlockLevel) .. "{/}"
        end
        SET_CARD(frame, "card_b",
            ClMsg("ARCHEOLOGY_PORTAL_CARD_RARE"), rareSubText,
            FORMAT_CARD_VALUE(
                FORMAT_PORTAL_NUMBER(clear.finalRare) .. "%", COLOR_RARE),
            FORMAT_DELTA(diff(clear.finalRare, baseClear.finalRare), "%p"))
        PLACE_RARE_GUIDE_BUTTON(frame, true, rareGuideTooltip)
        SET_CARD_TOOLTIP(frame, "card_b",
            BUILD_BREAKDOWN("ARCHEOLOGY_PORTAL_CARD_RARE", clear.finalRare, {
                { "ARCHEOLOGY_PORTAL_TIP_BASE", clear.baseRare, "%" },
                { "ARCHEOLOGY_PORTAL_TIP_OPTION", clear.optionRarePoint },
                { "ARCHEOLOGY_PORTAL_TIP_EXHIBITION", clear.exhibitionRarePoint },
                { "ARCHEOLOGY_PORTAL_TIP_TRAIT", clear.traitRarePoint },
                { "ARCHEOLOGY_PORTAL_TIP_RECORD", clear.modifierRarePoint },
                { "ARCHEOLOGY_PORTAL_TIP_DIFFICULTY_RARE", clear.difficultyRarePoint },
            }) .. (exhibitionBonusTip ~= "" and
                "{nl}" .. exhibitionBonusTip or "") ..
                "{nl}" .. INDEPENDENT_NOTE())
    else
        -- 보상 풀 산정 불가는 숨기지 않고 그대로 알린다.
        SET_CARD(frame, "card_b",
            ClMsg("ARCHEOLOGY_PORTAL_CARD_RARE"), "",
            "{#FFB29B}{s16}" .. ClMsg("ARCHEOLOGY_PORTAL_NOT_APPLIED") .. "{/}", "")
        SET_CARD_TOOLTIP(frame, "card_b", "")
        PLACE_RARE_GUIDE_BUTTON(frame, false)
    end

    -- 카드 C : 기록 파편 3종
    SET_CARD(frame, "card_c", ClMsg("ARCHEOLOGY_PORTAL_CARD_SHARD"), "", "", "")
    -- 확정 수량을 같이 보여준다. 확률만 띄우면 "빛바랜은 15% 확률"로 읽히는데
    -- 실제로는 확정 1개 + 추가 확률이라 오해를 부른다.
    SET_CARD_ROWS(frame, "card_c", {
        {
            itemClassName = "Relic_Shard_Low",
            label = GET_ITEM_NAME("Relic_Shard_Low", "ARCHEOLOGY_PORTAL_SHARD_LOW"),
            guaranteed = FORMAT_GUARANTEED(bonus.guaranteedLowShard),
            value = FORMAT_ROW_VALUE(
                FORMAT_PORTAL_NUMBER(bonus.lowShardFinal) .. "%", COLOR_SHARD),
            delta = FORMAT_DELTA(diff(bonus.lowShardFinal, baseBonus.lowShardFinal), "%p"),
        },
        {
            itemClassName = "Relic_Shard_High",
            label = GET_ITEM_NAME("Relic_Shard_High", "ARCHEOLOGY_PORTAL_SHARD_HIGH"),
            guaranteed = "",
            value = FORMAT_ROW_VALUE(
                FORMAT_PORTAL_NUMBER(bonus.highShardFinal) .. "%", COLOR_SHARD),
            delta = FORMAT_DELTA(diff(bonus.highShardFinal, baseBonus.highShardFinal), "%p"),
        },
        {
            itemClassName = "Ancient_Memory_Fragment",
            label = GET_ITEM_NAME("Ancient_Memory_Fragment", "ARCHEOLOGY_PORTAL_SHARD_MEMORY"),
            guaranteed = FORMAT_GUARANTEED(bonus.guaranteedFragment),
            value = FORMAT_ROW_VALUE(
                FORMAT_PORTAL_NUMBER(bonus.memoryFinal) .. "%", COLOR_MEMORY),
            delta = FORMAT_DELTA(diff(bonus.memoryFinal, baseBonus.memoryFinal), "%p"),
        },
    })
    SET_CARD_TOOLTIP(frame, "card_c", table.concat({
        BUILD_BREAKDOWN("ARCHEOLOGY_PORTAL_SHARD_LOW", bonus.lowShardFinal, {
            { "ARCHEOLOGY_PORTAL_TIP_BASE", bonus.lowShardBase, "%" },
            { "ARCHEOLOGY_PORTAL_TIP_OPTION", bonus.lowShardOption },
            { "ARCHEOLOGY_PORTAL_TIP_TRAIT", bonus.lowShardTrait },
            { "ARCHEOLOGY_PORTAL_TIP_RECORD", bonus.lowShardModifier },
        }),
        BUILD_BREAKDOWN("ARCHEOLOGY_PORTAL_SHARD_HIGH", bonus.highShardFinal, {
            { "ARCHEOLOGY_PORTAL_TIP_BASE", bonus.highShardBase, "%" },
            { "ARCHEOLOGY_PORTAL_TIP_OPTION", bonus.highShardOption },
            { "ARCHEOLOGY_PORTAL_TIP_TRAIT", bonus.highShardTrait },
            { "ARCHEOLOGY_PORTAL_TIP_RECORD", bonus.highShardModifier },
        }),
        BUILD_BREAKDOWN("ARCHEOLOGY_PORTAL_SHARD_MEMORY", bonus.memoryFinal, {
            { "ARCHEOLOGY_PORTAL_TIP_BASE", bonus.memoryBase, "%" },
            { "ARCHEOLOGY_PORTAL_TIP_OPTION", bonus.memoryOption },
            { "ARCHEOLOGY_PORTAL_TIP_TRAIT", bonus.memoryTrait },
            { "ARCHEOLOGY_PORTAL_TIP_RECORD", bonus.memoryModifier },
        }),
        INDEPENDENT_NOTE(),
    }, "{nl} {nl}"))

    -- 카드 D : 유물 추가 획득
    SET_CARD(frame, "card_d",
        ClMsg("ARCHEOLOGY_PORTAL_CARD_RELIC"),
        ClMsg("ARCHEOLOGY_PORTAL_CARD_RELIC_SUB"),
        FORMAT_CARD_VALUE(
            FORMAT_PORTAL_NUMBER(relic.finalNormal) .. "%", COLOR_SHARD),
        FORMAT_DELTA(diff(relic.finalNormal, baseRelic.finalNormal), "%p"))
    SET_CARD_TOOLTIP(frame, "card_d",
        BUILD_BREAKDOWN("ARCHEOLOGY_PORTAL_CARD_RELIC", relic.finalNormal, {
            { "ARCHEOLOGY_PORTAL_TIP_BASE", relic.baseNormal, "%" },
            { "ARCHEOLOGY_PORTAL_TIP_OPTION", relic.optionBonus },
            { "ARCHEOLOGY_PORTAL_TIP_RECORD", relic.modifierBonus },
        }) .. "{nl}" .. INDEPENDENT_NOTE())

    -- 값이 붙었을 때만 나타나는 줄
    -- 확정 편린 수량은 기록 파편 카드로 옮겼다. 여기는 주화만.
    local coinBonus = tonumber(clear.coinBonusPct) or 0
    if coinBonus > 0 then
        SET_SIDE_LINE(frame, "extra_line",
            ClMsg("ARCHEOLOGY_PORTAL_EXTRA_LABEL"),
            DELTA_UP_COLOR .. "{s15}" .. ClMsg("ARCHEOLOGY_PORTAL_COIN") .. " +" ..
            FORMAT_PORTAL_NUMBER(coinBonus) .. "%{/}")
    else
        SET_SIDE_LINE(frame, "extra_line", "", "")
    end
end

local function REFRESH_EFFECT_BOSS(frame, data)
    local boss = data.boss or {}
    local function num(value)
        return FORMAT_PORTAL_NUMBER(value)
    end

    SET_CARD(frame, "card_a",
        ClMsg("ARCHEOLOGY_PORTAL_CARD_POWER"), "",
        "{#FFB29B}{s19}" .. ClMsg("ARCHEOLOGY_PORTAL_BOSS_NAME") .. "{/}",
        COLOR_DIM .. "{s14}" .. ClMsg("ARCHEOLOGY_PORTAL_BOSS_FIXED") .. "{/}")
    SET_CARD_TOOLTIP(frame, "card_a", "")

    local chaosTotal = (tonumber(boss.baseChaosChance) or 0) +
        (tonumber(boss.extraChaosChance) or 0)
    PLACE_RARE_GUIDE_BUTTON(frame, false)
    SET_CARD(frame, "card_b",
        ClMsg("ARCHEOLOGY_PORTAL_BOSS_CHAOS"), "",
        FORMAT_CARD_VALUE(num(chaosTotal) .. "%", COLOR_RARE),
        FORMAT_DELTA(boss.extraChaosChance, "%p"))
    SET_CARD_TOOLTIP(frame, "card_b",
        BUILD_BREAKDOWN("ARCHEOLOGY_PORTAL_BOSS_CHAOS", chaosTotal, {
            { "ARCHEOLOGY_PORTAL_TIP_BASE", boss.baseChaosChance, "%" },
            { "ARCHEOLOGY_PORTAL_TIP_EXHIBITION", boss.extraChaosChance },
        }) .. "{nl}" .. INDEPENDENT_NOTE())

    SET_CARD(frame, "card_c",
        ClMsg("ARCHEOLOGY_PORTAL_BOSS_CARD_FIXED"), "", "", "")
    SET_CARD_ROWS(frame, "card_c", {
        {
            itemClassName = "Relic_Essence",
            label = GET_ITEM_NAME("Relic_Essence", "ARCHEOLOGY_PORTAL_BOSS_ESSENCE"),
            value = FORMAT_ROW_VALUE(num(boss.essenceCount), COLOR_MEMORY),
        },
        {
            itemClassName = "Relic_Shard_High",
            label = GET_ITEM_NAME("Relic_Shard_High", "ARCHEOLOGY_PORTAL_SHARD_HIGH"),
            value = FORMAT_ROW_VALUE(
                num(boss.highShardMin) .. "~" .. num(boss.highShardMax), COLOR_SHARD),
            delta = FORMAT_DELTA(boss.exhibitionHighShardBonus),
        },
        {
            itemClassName = "Archeology_Dig_Coin",
            label = GET_ITEM_NAME("Archeology_Dig_Coin", "ARCHEOLOGY_PORTAL_COIN"),
            value = FORMAT_ROW_VALUE(
                num(boss.coinMin) .. "~" .. num(boss.coinMax), COLOR_SHARD),
        },
    })
    SET_CARD_TOOLTIP(frame, "card_c", "")

    SET_CARD(frame, "card_d",
        ClMsg("ARCHEOLOGY_PORTAL_BOSS_CARD_CHANCE"), "",
        FORMAT_CARD_VALUE(num(boss.extraEssenceChance) .. "% / " ..
            num(boss.extraHighShardChance) .. "%", COLOR_SHARD), "")
    SET_CARD_TOOLTIP(frame, "card_d", table.concat({
        "{#FFF4D0}{s13}" ..
            ClMsg("ARCHEOLOGY_PORTAL_BOSS_CARD_CHANCE") .. "{/}",
        TIP_LINE("ARCHEOLOGY_PORTAL_BOSS_ESSENCE", boss.extraEssenceChance, "%"),
        TIP_LINE("ARCHEOLOGY_PORTAL_SHARD_HIGH", boss.extraHighShardChance, "%"),
        -- 보스 보상 추가 옵션은 서버에서 정수 1개를 따로 판정해 준다(희귀 보상이 아니다).
        TIP_LINE("ARCHEOLOGY_PORTAL_BOSS_EXTRA_ESSENCE", boss.extraBossChance, "%"),
        INDEPENDENT_NOTE(),
    }, "{nl}"))

    SET_SIDE_LINE(frame, "extra_line",
        ClMsg("ARCHEOLOGY_PORTAL_NOT_APPLIED"),
        COLOR_DIM .. "{s15}" ..
        ClMsg("ARCHEOLOGY_PORTAL_NOT_APPLIED_VALUE") .. "{/}")
end

-- 하단 요약 스트립은 보이는 줄 수만큼만 키우고, 줄이 없으면 숨긴다.
-- 거기에 맞춰 버튼 행·배경·프레임 높이를 당겨 창 아래의 빈 공백을 없앤다.
local LAYOUT_BG_TOP = 30             -- bg margin top (xml)
local LAYOUT_SUMMARY_TOP = 480       -- 좌우 패널 아래(84 + 384 + 12)
local LAYOUT_SUMMARY_PADDING = 8
local LAYOUT_SUMMARY_LINE_STEP = 26  -- 줄 높이 24 + 간격
local LAYOUT_GROUP_GAP = 12
local LAYOUT_BUTTON_HEIGHT = 58
local LAYOUT_BOTTOM_PADDING = 20

local function LAYOUT_SUMMARY_AND_FRAME(frame)
    local strip = GET_CHILD_RECURSIVELY(frame, "summary_strip")
    if strip == nil then
        return
    end

    local lines = {}
    local function collect(name, visible)
        local ctrl = GET_CHILD_RECURSIVELY(frame, name)
        if ctrl == nil then
            return
        end
        ctrl:ShowWindow(visible and 1 or 0)
        if visible then
            lines[#lines + 1] = ctrl
        end
    end
    local extra = GET_CHILD_RECURSIVELY(frame, "extra_line")
    local consume = GET_CHILD_RECURSIVELY(frame, "consume_line")
    local pity = GET_CHILD_RECURSIVELY(frame, "pity_notice")
    collect("extra_line", extra ~= nil and extra:GetTextByKey("extra_label_val") ~= "")
    collect("consume_line", consume ~= nil and consume:GetTextByKey("consume_label_val") ~= "")
    collect("pity_notice", pity ~= nil and pity:IsVisible() == 1)

    local buttonTop = LAYOUT_SUMMARY_TOP
    if #lines > 0 then
        local y = LAYOUT_SUMMARY_PADDING
        for _, ctrl in ipairs(lines) do
            local margin = ctrl:GetMargin()
            ctrl:SetMargin(margin.left, y, margin.right, margin.bottom)
            y = y + LAYOUT_SUMMARY_LINE_STEP
        end
        local stripHeight = y - (LAYOUT_SUMMARY_LINE_STEP - 24) + LAYOUT_SUMMARY_PADDING
        strip:Resize(strip:GetWidth(), stripHeight)
        strip:ShowWindow(1)
        buttonTop = LAYOUT_SUMMARY_TOP + stripHeight + LAYOUT_GROUP_GAP
    else
        strip:ShowWindow(0)
    end

    for _, name in ipairs({ "btn_reset", "btn_last_setting", "btn_enter" }) do
        local button = GET_CHILD_RECURSIVELY(frame, name)
        if button ~= nil then
            local margin = button:GetMargin()
            button:SetMargin(margin.left, buttonTop, margin.right, margin.bottom)
        end
    end

    local bgHeight = buttonTop + LAYOUT_BUTTON_HEIGHT + LAYOUT_BOTTOM_PADDING - LAYOUT_BG_TOP
    local bg = GET_CHILD(frame, "bg")
    if bg ~= nil then
        bg:Resize(bg:GetWidth(), bgHeight)
    end
    frame:Resize(frame:GetWidth(), LAYOUT_BG_TOP + bgHeight + LAYOUT_BG_TOP)
end

local function REFRESH_EFFECT_DESC(frame)
    local data = BUILD_REWARD_PREVIEW_DATA()
    local isBoss = IS_BOSS_ENTRY_SELECTED()

    -- 상태 배지 : 심층 / 보스 / 없음
    local badge = ""
    if isBoss then
        badge = "{#FFB29B}{s15}" .. ClMsg("ARCHEOLOGY_PORTAL_BADGE_BOSS") .. "{/}"
    elseif g_deepMode then
        badge = "{#FF8A65}{s15}" .. ClMsg("ARCHEOLOGY_PORTAL_BADGE_DEEP") .. "{/}"
    end
    local badgeCtrl = GET_CHILD_RECURSIVELY(frame, "effect_state_badge")
    if badgeCtrl ~= nil then
        badgeCtrl:SetTextByKey("state_badge_val", badge)
    end

    if isBoss then
        REFRESH_EFFECT_BOSS(frame, data)
    else
        -- 델타 기준선 = 현재 난이도 그대로, 아이템만 없는 상태.
        REFRESH_EFFECT_NORMAL(frame, data, BUILD_REWARD_PREVIEW_DATA({}, false))
    end

    -- 델타 기준선이 '현재 난이도'라 난이도를 바꿔도 델타는 움직이지 않는다.
    -- 그 대신 난이도 설명 줄에 쉬움 대비 이득을 따로 적어 준다.
    local diffDeltaCtrl = GET_CHILD_RECURSIVELY(frame, "difficulty_delta")
    if diffDeltaCtrl ~= nil then
        local deltaText = ""
        if not isBoss and data.clear ~= nil and data.clear.poolAvailable == true then
            local easyData = BUILD_REWARD_PREVIEW_DATA({}, false, "EASY")
            local gain = (tonumber(data.clear.finalRare) or 0) -
                (tonumber(easyData.clear.finalRare) or 0)
            if gain > 0.005 then
                deltaText =
                    ScpArgMsg("ARCHEOLOGY_PORTAL_DIFF_DELTA{VALUE}",
                        "VALUE", FORMAT_PORTAL_NUMBER(gain))
            end
        end
        diffDeltaCtrl:SetTextByKey("difficulty_delta_val", deltaText)
    end

    local consumeText = BUILD_CONSUME_TEXT()
    if consumeText ~= "" then
        SET_SIDE_LINE(frame, "consume_line",
            ClMsg("ARCHEOLOGY_PORTAL_CONSUME_LABEL"),
            COLOR_CONSUME .. "{s15}" .. consumeText .. "{/}")
    else
        SET_SIDE_LINE(frame, "consume_line", "", "")
    end

    -- 탐사 유형 확률·목표는 화면에서 빼고 ⓘ 툴팁으로만 남긴다.
    local infoBtn = GET_CHILD_RECURSIVELY(frame, "btn_mission_info")
    if infoBtn ~= nil then
        infoBtn:SetTextTooltip(isBoss and "" or BUILD_MISSION_TOOLTIP(data))
        infoBtn:ShowWindow(isBoss and 0 or 1)
    end

    -- 확정 정보이고 기대값을 크게 바꾸므로 툴팁에 묻지 않는다.
    SHOW_PREVIEW_CONTROL(frame, "pity_notice",
        data.mission ~= nil and data.mission.exterminationPity == true and not isBoss)

    LAYOUT_SUMMARY_AND_FRAME(frame)
end

local function GET_PORTAL_ITEM_CONTROL_NAME(slotKey)
    if slotKey == "entry" then
        return "PORTAL_ITEM_ENTRY"
    end
    return "PORTAL_ITEM_MODIFIER_" .. tostring(slotKey)
end

local function GET_PORTAL_ITEM_SLOT_CONTROLS(frame, slotKey)
    if frame == nil then
        return nil, nil, nil, nil
    end

    local controlSet = GET_CHILD_RECURSIVELY(
        frame, GET_PORTAL_ITEM_CONTROL_NAME(slotKey))
    if controlSet == nil then
        return nil, nil, nil, nil
    end

    local slot = GET_CHILD_RECURSIVELY(controlSet, "item_slot")
    local nameCtrl = GET_CHILD_RECURSIVELY(controlSet, "item_name")
    local plusImg = GET_CHILD_RECURSIVELY(controlSet, "item_slot_plus")
    local lockImg = GET_CHILD_RECURSIVELY(controlSet, "item_slot_lock")
    return controlSet, slot, nameCtrl, plusImg, lockImg
end

-- 난이도 버튼과 같은 규칙(자물쇠 + Lv.N)으로 잠금을 표시하기 위한 판정.
local function IS_SLOT_LOCKED(slotKey)
    if slotKey == "entry" then
        local requiredKey = g_deepMode and "DEEP_EXPLORATION" or "BOSS_NEBULAS"
        return g_exhibitionLevel <
            GET_ARCHEOLOGY_EXHIBITION_UNLOCK_LEVEL(requiredKey)
    end
    return (tonumber(slotKey) or 0) >
        GET_ARCHEOLOGY_EXHIBITION_RECORD_SLOT_COUNT(g_exhibitionLevel)
end

-- 잠긴 슬롯도 자물쇠로 보여준다. 예전에는 해금된 개수만큼만 만들어서
-- 슬롯이 더 열린다는 사실 자체가 화면에 없었다.
local function BUILD_PORTAL_ITEM_SLOT_DESCRIPTORS()
    local descriptors = {
        {
            key = "entry",
            label = ClMsg("ARCHEOLOGY_PORTAL_ENTRY_SLOT_LABEL"),
            locked = IS_SLOT_LOCKED("entry"),
        },
    }
    local modifierSlotCount =
        GET_ARCHEOLOGY_EXHIBITION_RECORD_SLOT_COUNT(g_exhibitionLevel)
    for slotIndex = 1, 2 do
        descriptors[#descriptors + 1] = {
            key = slotIndex,
            label = ScpArgMsg("ARCHEOLOGY_PORTAL_RECORD_SLOT_LABEL{SLOT}",
                "SLOT", slotIndex),
            locked = slotIndex > modifierSlotCount,
        }
    end
    return descriptors
end

local function REBUILD_PORTAL_ITEM_LIST(frame)
    local portalItemList = GET_CHILD_RECURSIVELY(frame, "portal_item_list")
    if portalItemList == nil then
        return false
    end

    portalItemList:RemoveAllChild()
    local descriptors = BUILD_PORTAL_ITEM_SLOT_DESCRIPTORS()
    local itemCount = #descriptors
    local columnCount = math.max(
        1, math.min(PORTAL_ITEM_MAX_COLUMNS, itemCount))
    local rowCount = math.max(
        1, math.ceil(itemCount / PORTAL_ITEM_MAX_COLUMNS))
    local listWidth = columnCount * PORTAL_ITEM_SET_WIDTH +
        (columnCount - 1) * PORTAL_ITEM_SET_GAP
    local listHeight = rowCount * PORTAL_ITEM_SET_HEIGHT +
        (rowCount - 1) * PORTAL_ITEM_SET_GAP

    -- 위치는 XML 이 고정한다(condition_panel 기준 margin "24 132").
    -- 여기서는 크기만 맞춘다.
    portalItemList:EnableScrollBar(0)
    portalItemList:Resize(listWidth, listHeight)

    for itemIndex, descriptor in ipairs(descriptors) do
        local zeroIndex = itemIndex - 1
        local columnIndex = zeroIndex % PORTAL_ITEM_MAX_COLUMNS
        local rowIndex = math.floor(zeroIndex / PORTAL_ITEM_MAX_COLUMNS)
        local x = columnIndex *
            (PORTAL_ITEM_SET_WIDTH + PORTAL_ITEM_SET_GAP)
        local y = rowIndex *
            (PORTAL_ITEM_SET_HEIGHT + PORTAL_ITEM_SET_GAP)
        local controlSet = portalItemList:CreateOrGetControlSet(
            PORTAL_ITEM_CONTROLSET_NAME,
            GET_PORTAL_ITEM_CONTROL_NAME(descriptor.key), x, y)
        if controlSet ~= nil then
            controlSet = tolua.cast(controlSet, "ui::CControlSet")
            -- 공용 템플릿은 유지하되 이 화면에서는 더 조밀한 고고학 카드로 보인다.
            controlSet:Resize(
                PORTAL_ITEM_SET_WIDTH, PORTAL_ITEM_SET_HEIGHT)
            controlSet:SetSkinName("archeology_ui_card_panel")

            local header = GET_CHILD_RECURSIVELY(
                controlSet, "slot_header")
            local label = GET_CHILD_RECURSIVELY(
                controlSet, "slot_label")
            local slot = GET_CHILD_RECURSIVELY(
                controlSet, "item_slot")
            local nameCtrl = GET_CHILD_RECURSIVELY(
                controlSet, "item_name")
            local plusImg = GET_CHILD_RECURSIVELY(
                controlSet, "item_slot_plus")
            local lockImg = GET_CHILD_RECURSIVELY(
                controlSet, "item_slot_lock")
            if header ~= nil then
                header:Resize(132, 32)
                header:SetGravity(ui.CENTER_HORZ, ui.TOP)
                header:SetMargin(0, 6, 0, 0)
                header:SetSkinName("archeology_ui_slot")
                -- slot_header 는 groupbox(draw=false). SetDraw 는 CControlSet 전용이라 오류가 나 입장 창이 열리지 않았다.
                header:EnableDrawFrame(1)
            end
            if label ~= nil then
                label:Resize(126, 28)
                label:SetGravity(ui.CENTER_HORZ, ui.CENTER_VERT)
                label:SetMargin(0, 0, 0, 0)
                label:SetTextByKey(
                    "slot_label_val", descriptor.label)
            end
            if slot ~= nil then
                slot:Resize(104, 104)
                slot:SetGravity(ui.CENTER_HORZ, ui.TOP)
                slot:SetMargin(0, 44, 0, 0)
                slot:SetEventScript(
                    ui.DROP, "ARCH_DENTER_DROP_ITEM_SLOT")
                slot:SetEventScriptArgString(
                    ui.DROP, tostring(descriptor.key))
                slot:SetEventScript(
                    ui.LBUTTONUP, "ARCH_DENTER_CLEAR_ITEM_SLOT")
                slot:SetEventScriptArgString(
                    ui.LBUTTONUP, tostring(descriptor.key))
            end
            if nameCtrl ~= nil then
                nameCtrl:Resize(126, 54)
                nameCtrl:SetGravity(ui.CENTER_HORZ, ui.TOP)
                nameCtrl:SetMargin(0, 154, 0, 0)
            end
            if plusImg ~= nil then
                plusImg:Resize(48, 48)
            end
            if lockImg ~= nil then
                lockImg:Resize(28, 36)
            end
        end
    end

    return true
end

-- slotKey: "entry" | 1 | 2
local function REFRESH_SLOT_UI(frame, slotKey, classId)
    local _, slot, nameCtrl, plusImg, lockImg =
        GET_PORTAL_ITEM_SLOT_CONTROLS(frame, slotKey)
    if slot == nil or nameCtrl == nil then
        return
    end

    local locked = IS_SLOT_LOCKED(slotKey)
    if lockImg ~= nil then
        lockImg:ShowWindow(locked and 1 or 0)
    end

    -- 조작 안내는 화면에서 빼고 슬롯 툴팁으로 내렸다.
    local guide = ClMsg("ARCHEOLOGY_PORTAL_SLOT_GUIDE")
    if slotKey == "entry" then
        local tooltip = ClMsg("ARCHEOLOGY_PORTAL_ENTRY_TOOLTIP") .. "{nl}" .. guide
        slot:SetTextTooltip(classId == 0 and tooltip or guide)
        nameCtrl:SetTextTooltip(tooltip)
    else
        slot:SetTextTooltip(guide)
        nameCtrl:SetTextTooltip(guide)
    end

    if classId ~= 0 and not locked then
        local item = GetInvItemByClassId(classId)
        if item ~= nil then
            SET_SLOT_ITEM(slot, item)
            local cls = GetIES(item:GetObject())
            local itemNameText = string.gsub(
                TryGetProp(cls, "Name", ""), " ", "{nl}", 1)
            nameCtrl:SetTextByKey("item_name_val", itemNameText)
            if plusImg ~= nil then
                plusImg:ShowWindow(0)
            end
            return
        end
    end

    slot:ClearIcon()
    nameCtrl:SetTextByKey(
        "item_name_val", GET_SLOT_EMPTY_TEXT(slotKey))
    -- 잠긴 슬롯은 + 대신 자물쇠만 보여준다.
    if plusImg ~= nil then
        plusImg:ShowWindow(locked and 0 or 1)
    end
end

-- ── 슬롯별 아이템 등록 ────────────────────────────────────────────────────────

-- 입장 증표 슬롯: 보스 증표 / 심층 탐사 허가증 전용
local function TRY_REGISTER_ENTRY_ITEM(frame, invItemGuid)
    if ui.CheckHoldedUI() == true then return end

    local item = session.GetInvItemByGuid(invItemGuid)
    if item == nil then return end

    local cls       = GetIES(item:GetObject())
    local className = TryGetProp(cls, "ClassName", "")

    if VALID_BOSS_ENTRY_ITEMS[className] == nil and VALID_DEEP_ENTRY_ITEMS[className] == nil then
        if VALID_MODIFIER_ITEMS[className] ~= nil then
            ui.SysMsg(ClMsg("ARCHEOLOGY_PORTAL_RECORD_ITEM_USE_OWN_SLOT"))
        else
            ui.SysMsg(ClMsg("ARCHEOLOGY_PORTAL_ENTRY_SLOT_ITEM_INVALID"))
        end
        return
    end

    local newClassId = tonumber(TryGetProp(cls, "ClassID", "0")) or 0
    if VALID_BOSS_ENTRY_ITEMS[className] ~= nil and
            (g_slot1ClassId ~= 0 or g_slot2ClassId ~= 0) then
        ui.SysMsg(ClMsg("ARCHEOLOGY_PORTAL_BOSS_MODIFIER_BLOCKED"))
        return
    end
    if VALID_DEEP_ENTRY_ITEMS[className] ~= nil then
        local requiredLevel = GET_ARCHEOLOGY_EXHIBITION_UNLOCK_LEVEL("DEEP_EXPLORATION")
        if g_exhibitionLevel < requiredLevel then
            SHOW_EXHIBITION_LEVEL_LOCK(requiredLevel)
            return
        end
    end
    if VALID_BOSS_ENTRY_ITEMS[className] ~= nil then
        local requiredLevel = GET_ARCHEOLOGY_EXHIBITION_UNLOCK_LEVEL("BOSS_NEBULAS")
        if g_exhibitionLevel < requiredLevel then
            SHOW_EXHIBITION_LEVEL_LOCK(requiredLevel)
            return
        end
    end
    g_entryClassId = newClassId
    g_deepMode = VALID_DEEP_ENTRY_ITEMS[className] ~= nil
    REFRESH_SLOT_UI(frame, "entry", newClassId)
    REFRESH_DIFFICULTY_UI(frame)
    REFRESH_EFFECT_DESC(frame)
end

-- 탐험 기록 슬롯: MODIFIER 아이템 전용
local function TRY_REGISTER_RESONANCE_ITEM(frame, slotIndex, invItemGuid)
    if ui.CheckHoldedUI() == true then return end

    local slotCount = GET_ARCHEOLOGY_EXHIBITION_RECORD_SLOT_COUNT(g_exhibitionLevel)
    if slotIndex > slotCount then
        local requiredKey = slotIndex == 1 and "RECORD_SLOT_1" or "RECORD_SLOT_2"
        SHOW_EXHIBITION_LEVEL_LOCK(GET_ARCHEOLOGY_EXHIBITION_UNLOCK_LEVEL(requiredKey))
        return
    end

    local item = session.GetInvItemByGuid(invItemGuid)
    if item == nil then return end

    local cls       = GetIES(item:GetObject())
    local className = TryGetProp(cls, "ClassName", "")

    if VALID_MODIFIER_ITEMS[className] == nil then
        if VALID_BOSS_ENTRY_ITEMS[className] ~= nil or VALID_DEEP_ENTRY_ITEMS[className] ~= nil then
            ui.SysMsg(ClMsg("ARCHEOLOGY_PORTAL_ENTRY_ITEM_USE_OWN_SLOT"))
        else
            ui.SysMsg(ClMsg("ARCHEOLOGY_PORTAL_RECORD_SLOT_ITEM_INVALID"))
        end
        return
    end
    if IS_BOSS_ENTRY_SELECTED() then
        ui.SysMsg(ClMsg("ARCHEOLOGY_PORTAL_BOSS_MODIFIER_BLOCKED"))
        return
    end

    local newClassId   = tonumber(TryGetProp(cls, "ClassID", "0")) or 0
    local otherClassId = slotIndex == 1 and g_slot2ClassId or g_slot1ClassId

    if otherClassId == newClassId then
        ui.SysMsg(ClMsg("ARCHEOLOGY_PORTAL_RECORD_DUPLICATE"))
        return
    end

    if slotIndex == 1 then
        g_slot1ClassId = newClassId
    else
        g_slot2ClassId = newClassId
    end

    REFRESH_SLOT_UI(frame, slotIndex, newClassId)
    REFRESH_EFFECT_DESC(frame)
end

-- ── 메시지 핸들러 ─────────────────────────────────────────────────────────────

function ARCHEOLOGY_DUNGEON_ENTER_ON_INIT(addon, frame)
    addon:RegisterMsg("ARCHEOLOGY_DUNGEON_ENTER_OPEN", "ARCH_DENTER_ON_OPEN")
    addon:RegisterMsg("ARCHEOLOGY_DUNGEON_ENTER_CLOSE", "ARCH_DENTER_ON_PORTAL_CLOSE")
end

-- 서버에서 UI 열기 요청:
-- argStr = "portalHandle|diff|mapTrait|region|missionLevel|exterminationMissCount"
function ARCH_DENTER_ON_OPEN(frame, msg, argStr, argNum)
    -- 상태 초기화
    g_entryClassId = 0
    g_slot1ClassId = 0
    g_slot2ClassId = 0
    local exhibitionLevel = GET_ARCHEOLOGY_EXHIBITION_INFO()
    g_exhibitionLevel = tonumber(exhibitionLevel) or 1

    local parts = {}
    for value in string.gmatch(tostring(argStr or ""), "([^|]+)") do
        parts[#parts + 1] = value
    end
    g_portalHandle = parts[1] or ""
    g_diff = parts[2] or "D1"
    g_mapTrait = parts[3] or "ForgottenGoddess"
    g_rewardRegion = parts[4] or "All"
    g_missionLevel = tonumber(parts[5]) or 470
    g_exterminationMissCount = math.max(0, tonumber(parts[6]) or 0)
    g_difficultyChoice = GET_DEFAULT_DIFFICULTY_CHOICE(g_diff)
    if IS_RISK_DIFFICULTY_UNLOCKED() ~= true and (g_difficultyChoice == "HARD" or g_difficultyChoice == "VERY_HARD") then
        g_difficultyChoice = "NORMAL"
    end
    g_deepMode = false

    REFRESH_DIFFICULTY_UI(frame)
    REFRESH_MAP_TRAIT_UI(frame)

    -- 현재 해금된 슬롯 수만큼 공용 controlset을 추가하고 레이아웃을 맞춘다.
    REBUILD_PORTAL_ITEM_LIST(frame)
    REFRESH_SLOT_UI(frame, "entry", 0)
    REFRESH_SLOT_UI(frame, 1, 0)
    REFRESH_SLOT_UI(frame, 2, 0)
    REFRESH_EFFECT_DESC(frame)

    -- 인벤토리 열고 UI 표시
    if frame:IsVisible() ~= 1 then
        local inventory = ui.GetFrame("inventory")
        local inventoryWasOpen = inventory ~= nil and inventory:IsVisible() == 1
        frame:SetUserValue("ENTRY_OPENED_INVENTORY", inventoryWasOpen and "NO" or "YES")
        if inventoryWasOpen ~= true then
            ui.OpenFrame("inventory")
        end
    end
    INVENTORY_PUSH_CUSTOM_RBTNDOWN(frame, "ARCH_DENTER_INVENTORY_RBTN")
    frame:ShowWindow(1)
    -- 표시 시점에 xml 크기로 되돌아가는 경우가 있어 한 번 더 맞춘다.
    LAYOUT_SUMMARY_AND_FRAME(frame)
end

function ARCH_DENTER_APPLY_LAST(parent, ctrl)
    local frame = parent:GetTopParentFrame()
    if frame == nil then
        return
    end

    local saved = config.GetConfig(LAST_SETTING_CONFIG_KEY, "")
    if saved == nil or saved == "" or saved == "None" then
        ui.SysMsg(ClMsg("ARCHEOLOGY_PORTAL_LAST_SETTING_EMPTY"))
        return
    end

    local parts = {}
    for value in string.gmatch(saved, "([^;]+)") do
        parts[#parts + 1] = value
    end
    if #parts < 4 then
        ui.SysMsg(ClMsg("ARCHEOLOGY_PORTAL_LAST_SETTING_INVALID"))
        return
    end

    local savedDifficulty = parts[1]
    if savedDifficulty ~= "EASY" and savedDifficulty ~= "NORMAL" and savedDifficulty ~= "HARD" and savedDifficulty ~= "VERY_HARD" then
        savedDifficulty = GET_DEFAULT_DIFFICULTY_CHOICE(g_diff)
    end
    if IS_RISK_DIFFICULTY_UNLOCKED() ~= true and (savedDifficulty == "HARD" or savedDifficulty == "VERY_HARD") then
        savedDifficulty = "NORMAL"
    end

    g_entryClassId = 0
    g_slot1ClassId = 0
    g_slot2ClassId = 0
    g_deepMode = false
    g_difficultyChoice = savedDifficulty

    local entryOk = SET_SLOT_CLASS_ID("entry", tonumber(parts[2]) or 0)
    local slot1Ok = SET_SLOT_CLASS_ID(1, tonumber(parts[3]) or 0)
    local slot2Ok = SET_SLOT_CLASS_ID(2, tonumber(parts[4]) or 0)

    REFRESH_SLOT_UI(frame, "entry", g_entryClassId)
    REFRESH_SLOT_UI(frame, 1, g_slot1ClassId)
    REFRESH_SLOT_UI(frame, 2, g_slot2ClassId)
    REFRESH_DIFFICULTY_UI(frame)
    REFRESH_EFFECT_DESC(frame)

    if entryOk == false or slot1Ok == false or slot2Ok == false then
        ui.SysMsg(ClMsg("ARCHEOLOGY_PORTAL_LAST_SETTING_PARTIAL"))
    end
end

function ARCH_DENTER_SELECT_EASY(parent, ctrl)
    if IS_BOSS_ENTRY_SELECTED() then return end
    local frame = parent:GetTopParentFrame()
    g_difficultyChoice = "EASY"
    REFRESH_DIFFICULTY_UI(frame)
    REFRESH_EFFECT_DESC(frame)
end

function ARCH_DENTER_SELECT_NORMAL(parent, ctrl)
    if IS_BOSS_ENTRY_SELECTED() then return end
    local frame = parent:GetTopParentFrame()
    g_difficultyChoice = "NORMAL"
    REFRESH_DIFFICULTY_UI(frame)
    REFRESH_EFFECT_DESC(frame)
end

function ARCH_DENTER_SELECT_HARD(parent, ctrl)
    if IS_BOSS_ENTRY_SELECTED() then return end
    if IS_RISK_DIFFICULTY_UNLOCKED() ~= true then
        SHOW_EXHIBITION_LEVEL_LOCK(GET_ARCHEOLOGY_EXHIBITION_UNLOCK_LEVEL("RISK_EXPLORATION"))
        return
    end
    local frame = parent:GetTopParentFrame()
    g_difficultyChoice = "HARD"
    REFRESH_DIFFICULTY_UI(frame)
    REFRESH_EFFECT_DESC(frame)
end

function ARCH_DENTER_SELECT_VERY_HARD(parent, ctrl)
    if IS_BOSS_ENTRY_SELECTED() then return end
    if IS_RISK_DIFFICULTY_UNLOCKED() ~= true then
        SHOW_EXHIBITION_LEVEL_LOCK(GET_ARCHEOLOGY_EXHIBITION_UNLOCK_LEVEL("RISK_EXPLORATION"))
        return
    end
    local frame = parent:GetTopParentFrame()
    g_difficultyChoice = "VERY_HARD"
    REFRESH_DIFFICULTY_UI(frame)
    REFRESH_EFFECT_DESC(frame)
end

-- 인벤토리 우클릭으로 아이템 슬롯 자동 배치
-- 이 UI 가 다룰 아이템이 아니면 false 를 돌려준다. 그래야 인벤토리가 훅을 건너뛰고
-- 평소의 우클릭 사용(표식 조각 교환 등)을 그대로 태운다. 예전처럼 전부 삼키면
-- 입장 UI 를 띄워둔 동안 다른 아이템은 우클릭으로 쓸 수 없다.
function ARCH_DENTER_INVENTORY_RBTN(itemObj, invSlot, invItemGuid)
    local frame = GET_FRAME()
    if frame == nil or frame:IsVisible() == 0 then return false end

    local item = session.GetInvItemByGuid(invItemGuid)
    if item == nil then return false end
    local cls       = GetIES(item:GetObject())
    local className = TryGetProp(cls, "ClassName", "")

    if VALID_BOSS_ENTRY_ITEMS[className] ~= nil or VALID_DEEP_ENTRY_ITEMS[className] ~= nil then
        -- 입장 증표 슬롯으로 직접 배치
        TRY_REGISTER_ENTRY_ITEM(frame, invItemGuid)
        return true
    end

    if VALID_MODIFIER_ITEMS[className] == nil then
        return false
    end

    if g_slot1ClassId == 0 then
        TRY_REGISTER_RESONANCE_ITEM(frame, 1, invItemGuid)
    else
        TRY_REGISTER_RESONANCE_ITEM(frame, 2, invItemGuid)
    end
    return true
end

-- ── 공용 controlset 입력 핸들러 ──────────────────────────────────────────────

function ARCH_DENTER_DROP_ITEM_SLOT(parent, slot, argStr, argNum)
    if ui.CheckHoldedUI() == true then return end
    local liftIcon  = ui.GetLiftIcon()
    local fromFrame = liftIcon:GetTopParentFrame()
    if fromFrame:GetName() ~= "inventory" then return end
    local iconInfo = liftIcon:GetInfo()
    local frame = parent:GetTopParentFrame()
    if tostring(argStr) == "entry" then
        TRY_REGISTER_ENTRY_ITEM(frame, iconInfo:GetIESID())
        return
    end
    local slotIndex = tonumber(argStr)
    if slotIndex ~= nil then
        TRY_REGISTER_RESONANCE_ITEM(
            frame, slotIndex, iconInfo:GetIESID())
    end
end

function ARCH_DENTER_CLEAR_ITEM_SLOT(parent, ctrl, argStr, argNum)
    if ui.CheckHoldedUI() == true then return end
    local frame = parent:GetTopParentFrame()
    if tostring(argStr) == "entry" then
        g_entryClassId = 0
        g_deepMode = false
        REFRESH_SLOT_UI(frame, "entry", 0)
        REFRESH_DIFFICULTY_UI(frame)
        REFRESH_EFFECT_DESC(frame)
        return
    end

    local slotIndex = tonumber(argStr)
    if slotIndex == 1 then
        g_slot1ClassId = 0
    elseif slotIndex == 2 then
        g_slot2ClassId = 0
    else
        return
    end
    REFRESH_SLOT_UI(frame, slotIndex, 0)
    REFRESH_EFFECT_DESC(frame)
end

function ARCH_DENTER_RESET_SLOTS(parent, ctrl)
    if ui.CheckHoldedUI() == true then return end
    local frame = parent:GetTopParentFrame()
    if frame == nil then return end

    g_entryClassId = 0
    g_slot1ClassId = 0
    g_slot2ClassId = 0
    g_deepMode = false

    REFRESH_SLOT_UI(frame, "entry", 0)
    REFRESH_SLOT_UI(frame, 1, 0)
    REFRESH_SLOT_UI(frame, 2, 0)
    REFRESH_DIFFICULTY_UI(frame)
    REFRESH_EFFECT_DESC(frame)
end

-- ── 확인 / 취소 ───────────────────────────────────────────────────────────────

function ARCH_DENTER_CONFIRM(parent, ctrl)
    local frame = parent:GetTopParentFrame()
    if frame == nil then return end
    if IS_BOSS_ENTRY_SELECTED() and
            (g_slot1ClassId ~= 0 or g_slot2ClassId ~= 0) then
        ui.SysMsg(ClMsg("ARCHEOLOGY_PORTAL_BOSS_MODIFIER_BLOCKED"))
        return
    end

    -- 아이템 잠금 상태 확인
    for _, classId in ipairs({ g_entryClassId, g_slot1ClassId, g_slot2ClassId }) do
        if classId ~= 0 then
            local item = GetInvItemByClassId(classId)
            if item ~= nil and item.isLockState == true then
                ui.SysMsg(ClMsg("MaterialItemIsLock"))
                return
            end
        end
    end

    -- 아이템 소모 안내 포함 확인 메시지
    local confirmMsg
    if g_entryClassId ~= 0 or g_slot1ClassId ~= 0 or g_slot2ClassId ~= 0 then
        confirmMsg = ScpArgMsg("ARCHEOLOGY_DUNGEON_ENTER_CONFIRM_ITEM")
    else
        confirmMsg = ScpArgMsg("ARCHEOLOGY_DUNGEON_ENTER_CONFIRM")
    end

    local yesCmd = string.format("_ARCH_DENTER_DO_ENTER()")
    -- 키를 붙여 두 번 눌러도 확인창이 하나만 뜨고, 입장 창을 닫을 때 같이 닫을 수 있게 한다.
    local msgBox = ui.MsgBox_NonNested(confirmMsg, ARCH_DENTER_CONFIRM_KEY, yesCmd, "None")
    SET_MODAL_MSGBOX(msgBox)
end

-- 입장 창이 닫혔는데 확인창만 남으면 「예」가 아무 일도 하지 않는다. 창과 함께 닫는다.
local function ARCH_DENTER_CLOSE_CONFIRM()
    local msgBox = ui.GetMsgBoxByNonNestedKey(ARCH_DENTER_CONFIRM_KEY)
    if msgBox == nil then return end
    msgBox = tolua.cast(msgBox, "ui::CMessageBoxFrame")
    ui.CloseMsgBoxByIndex(msgBox:GetIndex())
end

-- MsgBox "예" 콜백
function _ARCH_DENTER_DO_ENTER()
    local frame = GET_FRAME()
    if frame == nil or frame:IsVisible() == 0 then return end

    -- NumArgs avoids the 33-byte TxArg limit of pc.ReqExecuteTx.
    -- NumArgs 는 float 라 포탈 핸들은 로그용이다. 서버는 자기 포탈 기록으로 대상을 정한다.
    local argStr = tostring(tonumber(g_portalHandle) or 0)
                .. " " .. tostring(GET_DIFFICULTY_CHOICE_CODE(g_difficultyChoice))
                .. " " .. tostring(g_entryClassId)
                .. " " .. tostring(g_slot1ClassId)
                .. " " .. tostring(g_slot2ClassId)

    SAVE_LAST_SETTING()
    -- 「예」를 누른 확인창은 스스로 닫히므로 여기서 다시 닫지 않는다.
    ARCH_DENTER_CLOSE_UI(true)
    pc.ReqExecuteTx_NumArgs("SCR_ARCHEOLOGY_DUNGEON_ENTER", argStr)
end

function ARCH_DENTER_CANCEL(parent, ctrl)
    ARCH_DENTER_CLOSE_UI()
end

function ARCH_DENTER_ON_CLOSE(frame)
    ARCH_DENTER_CLOSE_UI()
end

function ARCH_DENTER_ON_PORTAL_CLOSE(frame, msg, argStr, argNum)
    if frame ~= nil and frame:IsVisible() == 1 and
            tostring(g_portalHandle) == tostring(argStr) then
        ARCH_DENTER_CLOSE_UI()
    end
end

function ARCH_DENTER_CLOSE_UI(keepConfirm)
    local frame = GET_FRAME()
    if frame == nil then return end
    if keepConfirm ~= true then
        ARCH_DENTER_CLOSE_CONFIRM()
    end
    frame:ShowWindow(0)
    if frame:GetUserValue("ENTRY_OPENED_INVENTORY") == "YES" then
        ui.CloseFrame("inventory")
    end
    frame:SetUserValue("ENTRY_OPENED_INVENTORY", "NO")
    INVENTORY_POP_CUSTOM_RBTNDOWN(frame, "ARCH_DENTER_INVENTORY_RBTN")
    g_portalHandle = ""
    g_entryClassId = 0
    g_slot1ClassId = 0
    g_slot2ClassId = 0
    g_difficultyChoice = "NORMAL"
    g_deepMode = false
    g_mapTrait = "ForgottenGoddess"
    g_exhibitionLevel = 1
end
