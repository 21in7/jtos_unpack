-- shared_archeology_exhibition.lua
-- 전시 레벨, 장착 코스트, 유물 옵션과 적용 효과를 서버·클라이언트에서 공통 계산한다.

function GET_ARCHEOLOGY_PROGRESS_OBJ(pc)
    if IsServerSection() == 1 then
        return GetAccountObj(pc)
    end

    return GetMyAccountObj()
end

function GET_ARCHEOLOGY_ITEM_STATE_OBJ(pc)
    if IsServerSection() == 1 then
        return GetETCObject(pc)
    end

    return GetMyEtcObject()
end

local ARCHEOLOGY_EXHIBITION_UNLOCK_LEVEL = {
    GENERAL_EXPLORATION = 1,
    RECORD_SLOT_1 = 3,
    RISK_EXPLORATION = 5,
    BOSS_NEBULAS = 5,
    RECORD_SLOT_2 = 8,
    DEEP_EXPLORATION = 11,
    NEBULAS_BONUS = 15,
}

local ARCHEOLOGY_EXHIBITION_MILESTONES = {
    { level = 1, key = "GENERAL_EXPLORATION", msg = "ARC_EXHIBIT_UNLOCK_GENERAL" },
    { level = 3, key = "RECORD_SLOT_1", msg = "ARC_EXHIBIT_UNLOCK_RECORD_1" },
    { level = 5, key = "RISK_EXPLORATION", msg = "ARC_EXHIBIT_UNLOCK_RISK" },
    { level = 8, key = "RECORD_SLOT_2", msg = "ARC_EXHIBIT_UNLOCK_RECORD_2" },
    { level = 11, key = "DEEP_EXPLORATION", msg = "ARC_EXHIBIT_UNLOCK_DEEP" },
    { level = 15, key = "NEBULAS_BONUS", msg = "ARC_EXHIBIT_UNLOCK_NEBULAS" },
}

local ARCHEOLOGY_FIXED_RELIC_EFFECT = {
    Arc_Vakarine_Moon_Shield = {
        effectKey = "MOON_GUARD",
        exprop = "ARCHEOLOGY_UNIQUE_MOON_GUARD",
        titleMsg = "ARC_UNIQUE_MOON_GUARD_TITLE",
        descMsg = "ARC_UNIQUE_MOON_GUARD_DESC",
        color = "8FD3FF",
    },
    Arc_Royal_Sword = {
        effectKey = "ROYAL_MOMENTUM",
        exprop = "ARCHEOLOGY_UNIQUE_ROYAL_SWORD",
        titleMsg = "ARC_UNIQUE_ROYAL_SWORD_TITLE",
        descMsg = "ARC_UNIQUE_ROYAL_SWORD_DESC",
        color = "FFB36B",
    },
    Arc_Alchemist_Crystal = {
        effectKey = "ALCHEMIST_REFINING",
        exprop = "ARCHEOLOGY_UNIQUE_ALCHEMIST_CRYSTAL",
        titleMsg = "ARC_UNIQUE_ALCHEMIST_TITLE",
        descMsg = "ARC_UNIQUE_ALCHEMIST_DESC",
        color = "C69CFF",
    },
}

local function GET_ARCHEOLOGY_EXHIBITION_STAT_RULE(effectName)
    if shared_archeology == nil or
            shared_archeology.get_option_stat_rule == nil then
        return nil
    end
    return shared_archeology.get_option_stat_rule(effectName)
end

function GET_ARCHEOLOGY_RELIC_FAMILY_CLASS_NAME(className)
    if className == nil or className == "" or className == "None" then
        return ""
    end

    local familyName = tostring(className)
    local suffix = string.sub(familyName, -2)
    if suffix == "_N" or suffix == "_M" or suffix == "_R" then
        familyName = string.sub(familyName, 1, string.len(familyName) - 2)
    end
    return familyName
end

-- 고정(고유) 효과는 Rare 유물에서만 발동한다.
-- 전시 아이템 ClassName 은 등급 접미사 _N/_M/_R 로 끝나는 규약이다.
function IS_ARCHEOLOGY_RARE_RELIC_CLASS_NAME(className)
    if className == nil or className == "" or className == "None" then
        return false
    end
    return string.sub(tostring(className), -2) == "_R"
end

function GET_ARCHEOLOGY_FIXED_RELIC_EFFECT_INFO(className)
    if IS_ARCHEOLOGY_RARE_RELIC_CLASS_NAME(className) ~= true then
        return nil
    end

    local familyName = GET_ARCHEOLOGY_RELIC_FAMILY_CLASS_NAME(className)
    return ARCHEOLOGY_FIXED_RELIC_EFFECT[familyName]
end

function GET_ARCHEOLOGY_EXHIBITION_UNLOCK_LEVEL(key)
    return ARCHEOLOGY_EXHIBITION_UNLOCK_LEVEL[key] or 1
end

function GET_ARCHEOLOGY_EXHIBITION_RECORD_SLOT_COUNT(level)
    level = tonumber(level) or 1
    if level >= GET_ARCHEOLOGY_EXHIBITION_UNLOCK_LEVEL("RECORD_SLOT_2") then
        return 2
    end
    if level >= GET_ARCHEOLOGY_EXHIBITION_UNLOCK_LEVEL("RECORD_SLOT_1") then
        return 1
    end
    return 0
end

function GET_ARCHEOLOGY_EXHIBITION_NEXT_MILESTONE(level)
    level = tonumber(level) or 1
    for _, milestone in ipairs(ARCHEOLOGY_EXHIBITION_MILESTONES) do
        if milestone.level > level then
            return milestone.level, milestone.msg, milestone.key
        end
    end
    return nil, nil, nil
end

function GET_ARCHEOLOGY_EXHIBITION_MAX_LEVEL()
    if ARCHEOLOGY_RULES == nil or
            ARCHEOLOGY_RULES.get_exhibition_max_level == nil then
        return 1
    end

    return ARCHEOLOGY_RULES.get_exhibition_max_level()
end

-- 룰 캐시에서 전시 레벨별 경험치·코스트 프로필을 가져온다.
local function GET_ARCHEOLOGY_EXHIBITION_LEVEL_PROFILE(level)
    if ARCHEOLOGY_RULES == nil or
            ARCHEOLOGY_RULES.get_exhibition_level == nil then
        return nil
    end

    return ARCHEOLOGY_RULES.get_exhibition_level(level)
end

function GET_ARCHEOLOGY_EXHIBITION_LEVEL_BY_EXP(exp)
    exp = tonumber(exp) or 0
    local max_level = GET_ARCHEOLOGY_EXHIBITION_MAX_LEVEL()
    local current_level = 1
    local current_profile = GET_ARCHEOLOGY_EXHIBITION_LEVEL_PROFILE(1)

    for i = 1, max_level do
        local profile = GET_ARCHEOLOGY_EXHIBITION_LEVEL_PROFILE(i)
        if profile ~= nil then
            local req_exp = profile.exp or 0
            if exp >= req_exp then
                current_level = i
                current_profile = profile
            else
                break
            end
        end
    end

    return current_level, current_profile
end

function GET_EXHIBITION_GOAL_EXP(pc)
    local aObj = GET_ARCHEOLOGY_PROGRESS_OBJ(pc)
    if aObj == nil then
        return 0
    end

    local total_exp = TryGetProp(aObj, "ARCHEOLOGY_EXP", 0)
    local current_level = GET_ARCHEOLOGY_EXHIBITION_LEVEL_BY_EXP(total_exp)
    local next_profile = GET_ARCHEOLOGY_EXHIBITION_LEVEL_PROFILE(current_level + 1)
    if next_profile ~= nil then
        return next_profile.exp or total_exp
    end

    local max_profile = GET_ARCHEOLOGY_EXHIBITION_LEVEL_PROFILE(
        GET_ARCHEOLOGY_EXHIBITION_MAX_LEVEL())
    if max_profile ~= nil then
        return max_profile.exp or total_exp
    end

    return total_exp
end

function EXHIBITION_EXP_TO_LEVEL(pc, exp)
    local total_exp = tonumber(exp) or 0
    local max_level = GET_ARCHEOLOGY_EXHIBITION_MAX_LEVEL()
    for i = 1, max_level do
        local profile = GET_ARCHEOLOGY_EXHIBITION_LEVEL_PROFILE(i)
        if profile ~= nil then
            local req_exp = profile.exp or 0
            if total_exp <= req_exp then
                return i, profile.maxCost or 0
            end
        end
    end

    local profile = GET_ARCHEOLOGY_EXHIBITION_LEVEL_PROFILE(max_level)
    return max_level, profile and profile.maxCost or 0
end

function GET_ARCHEOLOGY_EXHIBITION_INFO(pc)
    local aObj = GET_ARCHEOLOGY_PROGRESS_OBJ(pc)
    if aObj == nil then
        local profile = GET_ARCHEOLOGY_EXHIBITION_LEVEL_PROFILE(1)
        return 1, profile and profile.maxCost or 0
    end

    local total_exp = TryGetProp(aObj, "ARCHEOLOGY_EXP", 0)
    local current_level, current_profile =
        GET_ARCHEOLOGY_EXHIBITION_LEVEL_BY_EXP(total_exp)
    return current_level, current_profile and current_profile.maxCost or 0
end

function GET_CURRENT_AREX_COST(pc)
    local aObj = GET_ARCHEOLOGY_ITEM_STATE_OBJ(pc)
    if aObj == nil then
        return 0
    end

    local slot1 = TryGetProp(aObj, "ARCHEOLOGY_EQUIP_SLOT1", 0)
    local slot2 = TryGetProp(aObj, "ARCHEOLOGY_EQUIP_SLOT2", 0)
    local slot3 = TryGetProp(aObj, "ARCHEOLOGY_EQUIP_SLOT3", 0)
    local total_cost = 0
    local has_slot = false
    local slot_list = {slot1, slot2, slot3}
    for i = 1, 3 do
        local item_id = tonumber(slot_list[i]) or 0
        if item_id > 0 then
            local cls = GetClassByType("archeology_exhibition_item", item_id)
            if cls ~= nil then
                local meta = TryGetProp(aObj, "ARCHEOLOGY_EQUIP_META_" .. i, "None")
                local reroll_meta = TryGetProp(aObj, "ARCHEOLOGY_EQUIP_REROLL_META_" .. i, "None")
                total_cost = total_cost + GET_ARCHEOLOGY_EXHIBITION_ITEM_COST(cls, meta, reroll_meta)
                has_slot = true
            end
        end
    end

    -- 전시 보조 장치도 전시 점수를 소모하므로 한도 합계에 포함한다.
    local amplifier_id = tonumber(TryGetProp(aObj, "ARCHEOLOGY_AMPLIFIER_SLOT", 0)) or 0
    if amplifier_id > 0 then
        total_cost = total_cost + GET_ARCEX_AMPLIFIER_COST(pc)
        has_slot = true
    end

    if has_slot == true then
        return total_cost
    end

    return TryGetProp(aObj, "ARCHEOLOGY_COST", 0)
end

function GET_ARCHEOLOGY_OPTION_COST_BONUS(option_id)
    local opt_id = tonumber(option_id) or 0
    if opt_id <= 0 then
        return 0
    end

    local opt_cls = GetClassByType("archeology_option_list", opt_id)
    if opt_cls == nil then
        return 0
    end

    return tonumber(TryGetProp(opt_cls, "CostBonus", 0)) or 0
end

function GET_ARCHEOLOGY_META_COST_BONUS(arc_meta)
    if arc_meta == nil or arc_meta == "" or arc_meta == "None" then
        return 0
    end

    local bonus = 0
    local tokens = StringSplit(arc_meta, ",")
    for _, token in ipairs(tokens) do
        local pair = StringSplit(token, ";")
        local opt_id = tonumber(pair[1])
        if opt_id ~= nil then
            bonus = bonus + GET_ARCHEOLOGY_OPTION_COST_BONUS(opt_id)
        end
    end

    return bonus
end

function GET_ARCHEOLOGY_REROLL_META_VALUE(reroll_meta, key)
    if reroll_meta == nil or reroll_meta == "" or reroll_meta == "None" then
        return 0
    end

    local tokens = StringSplit(reroll_meta, ";")
    for _, token in ipairs(tokens) do
        local pair = StringSplit(token, "=")
        if pair[1] == key then
            return tonumber(pair[2]) or 0
        end
    end

    return 0
end

function SET_ARCHEOLOGY_REROLL_META_VALUE(reroll_meta, key, value)
    local divine_count = GET_ARCHEOLOGY_REROLL_META_VALUE(reroll_meta, "D")
    local chaos_count = GET_ARCHEOLOGY_REROLL_META_VALUE(reroll_meta, "C")

    local normalized_value = math.max(0, tonumber(value) or 0)
    if key == "D" then
        divine_count = normalized_value
    elseif key == "C" then
        chaos_count = normalized_value
    end

    if divine_count <= 0 and chaos_count <= 0 then
        return "None"
    end

    return string.format("D=%d;C=%d", divine_count, chaos_count)
end

function ADD_ARCHEOLOGY_REROLL_META_VALUE(reroll_meta, key, delta)
    local current_value = GET_ARCHEOLOGY_REROLL_META_VALUE(reroll_meta, key)
    return SET_ARCHEOLOGY_REROLL_META_VALUE(reroll_meta, key, current_value + (tonumber(delta) or 0))
end

function GET_ARCHEOLOGY_EXHIBITION_ITEM_COST(ex_cls, arc_meta, reroll_meta)
    if ex_cls == nil then
        return 0
    end

    local profile = shared_archeology.get_exhibition_item_profile(ex_cls)
    local base_cost = profile and profile.cost or 0
    return base_cost + GET_ARCHEOLOGY_META_COST_BONUS(arc_meta)
end

function GET_ARCHEOLOGY_EXHIBITION_ITEM_COST_DETAIL(ex_cls, arc_meta, reroll_meta)
    if ex_cls == nil then
        return 0, 0, 0
    end

    local profile = shared_archeology.get_exhibition_item_profile(ex_cls)
    local base_cost = profile and profile.cost or 0
    local option_bonus = GET_ARCHEOLOGY_META_COST_BONUS(arc_meta)
    return base_cost, option_bonus, base_cost + option_bonus
end

function CHECK_EXHIBITION_COST(pc, cost)
    local curCost = GET_CURRENT_AREX_COST(pc)
    local _, maxCost = GET_ARCHEOLOGY_EXHIBITION_INFO(pc)
    return maxCost >= curCost + cost
end

function GET_ARCEX_SLOT_ITEMS(pc)
    local aObj = GET_ARCHEOLOGY_ITEM_STATE_OBJ(pc)
    if aObj == nil then
        return 0, 0, 0
    end

    local slot1 = TryGetProp(aObj, "ARCHEOLOGY_EQUIP_SLOT1", 0)
    local slot2 = TryGetProp(aObj, "ARCHEOLOGY_EQUIP_SLOT2", 0)
    local slot3 = TryGetProp(aObj, "ARCHEOLOGY_EQUIP_SLOT3", 0)

    return slot1, slot2, slot3
end

function GET_ARCEX_SLOT_ITEM_IDX(pc, index)
    local slot1, slot2, slot3 = GET_ARCEX_SLOT_ITEMS(pc)
    if index == 1 then
        return slot1
    end
    if index == 2 then
        return slot2
    end
    if index == 3 then
        return slot3
    end

    return 0
end

function GET_ARCEX_AMPLIFIER_ITEM_IDX(pc)
    local aObj = GET_ARCHEOLOGY_ITEM_STATE_OBJ(pc)
    if aObj == nil then
        return 0
    end

    return TryGetProp(aObj, "ARCHEOLOGY_AMPLIFIER_SLOT", 0)
end

function GET_ARCEX_AMPLIFIER_META(pc)
    local aObj = GET_ARCHEOLOGY_ITEM_STATE_OBJ(pc)
    if aObj == nil then
        return "None"
    end

    return TryGetProp(aObj, "ARCHEOLOGY_AMPLIFIER_META", "None")
end

function GET_ARCEX_AMPLIFIER_COST(pc)
    local aObj = GET_ARCHEOLOGY_ITEM_STATE_OBJ(pc)
    if aObj == nil then
        return 0
    end

    local amplifier_id = tonumber(TryGetProp(aObj, "ARCHEOLOGY_AMPLIFIER_SLOT", 0)) or 0
    if amplifier_id <= 0 then
        return 0
    end

    local amplifier_cls = GetClassByType("archeology_exhibition_item", amplifier_id)
    if amplifier_cls == nil then
        return 0
    end

    return GET_ARCHEOLOGY_EXHIBITION_ITEM_COST(
        amplifier_cls,
        TryGetProp(aObj, "ARCHEOLOGY_AMPLIFIER_META", "None"),
        TryGetProp(aObj, "ARCHEOLOGY_AMPLIFIER_REROLL_META", "None"))
end

function GET_ARCEX_SLOT_META(pc, index)
    local aObj = GET_ARCHEOLOGY_ITEM_STATE_OBJ(pc)
    if aObj == nil then
        return "None"
    end

    return TryGetProp(aObj, "ARCHEOLOGY_EQUIP_META_" .. index, "None")
end

function GET_SLOT_EFFECT(pc, index)
    return GET_ARCEX_SLOT_META(pc, index)
end

function GET_ARCEX_ITEM_BY_CLSID(clsid)
    return GetClassByType("archeology_exhibition_item", clsid)
end

function GET_ARCEX_AMPLIFIER_ITEM(pc)
    local clsid = GET_ARCEX_AMPLIFIER_ITEM_IDX(pc)
    if clsid == nil or clsid == 0 then
        return nil
    end

    return GET_ARCEX_ITEM_BY_CLSID(clsid)
end

function GET_ARCEX_ITEM_TYPE(itemCls)
    if itemCls == nil then
        return "Normal"
    end

    return TryGetProp(itemCls, "ExhibitType", "Normal")
end

function IS_ARCEX_AMPLIFIER_SLOT_UNLOCKED(pc)
    local current_level = GET_ARCHEOLOGY_EXHIBITION_INFO(pc)
    return current_level >= 3
end

-- 전시대를 열고 전시·해제할 수 있는 맵: 3개 마을(IS_TOWN_MAP)과 개인 하우징.
-- 개인 하우징은 Housing_Place 클래스(맵 이름) Type=Personal 로 판정한다(클라·서버 공용).
function IS_ARCHEOLOGY_EXHIBITION_MAP(mapName)
    if mapName == nil or mapName == "" or mapName == "None" then
        return false
    end
    if IS_TOWN_MAP(GetClass("Map", mapName)) == true then
        return true
    end
    local housingPlace = GetClass("Housing_Place", mapName)
    return housingPlace ~= nil and TryGetProp(housingPlace, "Type", "None") == "Personal"
end

function GET_ARCHEOLOGY_EXHIBITION_EFFECT_SCALE_RATE(pc)
    local current_level = GET_ARCHEOLOGY_EXHIBITION_INFO(pc)
    return shared_archeology.get_exhibition_effect_scale_rate(current_level)
end

local function GET_ARCHEOLOGY_EXHIBITION_DISPLAY_VALUE_BY_RATE(effectName, effectValue, scale_rate)
    return ARCHEOLOGY_RULES.scale_exhibition_value_by_rate(
        effectName, effectValue, scale_rate)
end

function GET_ARCHEOLOGY_EXHIBITION_DISPLAY_VALUE(effectName, effectValue, pc)
    return GET_ARCHEOLOGY_EXHIBITION_DISPLAY_VALUE_BY_RATE(effectName, effectValue, GET_ARCHEOLOGY_EXHIBITION_EFFECT_SCALE_RATE(pc))
end

-- 전시 중인 3슬롯의 옵션 값을 실제 적용값과 같은 규칙(스탯 합계 → 증폭 반올림 → 등급 배율)으로
-- 계산한 뒤, 그 합계를 각 옵션에 최대 나머지 방식으로 나눠 준다. 옵션별로 따로 반올림하면
-- 같은 스탯 유물이 여럿일 때 툴팁 합과 적용값이 1 어긋난다.
-- 반환: result[slot][optionIndex] = 표시 값 (같은 스탯이 2개 이상인 옵션만)
local function GET_ARCHEOLOGY_EXHIBITION_DISTRIBUTED_VALUES(pc)
    local entries_by_tag = {}
    local tag_order = {}
    for slot = 1, 3 do
        local item_cls = GET_ARCEX_ITEM_BY_CLSID(GET_ARCEX_SLOT_ITEM_IDX(pc, slot))
        if item_cls ~= nil and GET_ARCEX_ITEM_TYPE(item_cls) ~= "Amplifier" then
            local option_list = GET_ARCHEOLOGY_OPTION_INFO(GET_ARCEX_SLOT_META(pc, slot)) or {}
            for index, opt in ipairs(option_list) do
                local tag = opt.tag
                local value = tonumber(opt.value)
                if tag ~= nil and tag ~= "" and tag ~= "UNKNOWN" and
                        tag ~= "ARCHEOLOGY_EXHIBIT_EFFECT_BOOST" and value ~= nil then
                    if entries_by_tag[tag] == nil then
                        entries_by_tag[tag] = {}
                        tag_order[#tag_order + 1] = tag
                    end
                    local list = entries_by_tag[tag]
                    list[#list + 1] = { slot = slot, index = index, value = value }
                end
            end
        end
    end

    local result = {}
    local scale_rate = GET_ARCHEOLOGY_EXHIBITION_EFFECT_SCALE_RATE(pc)
    for _, tag in ipairs(tag_order) do
        local list = entries_by_tag[tag]
        local raw_sum = 0
        for _, entry in ipairs(list) do
            raw_sum = raw_sum + entry.value
        end
        if #list >= 2 and raw_sum > 0 then
            local total = raw_sum
            local amplifier_value = GET_ARCHEOLOGY_EXHIBITION_AMPLIFIER_VALUE(tag, pc)
            if amplifier_value > 0 then
                total = ARCHEOLOGY_RULES.amplify_option_value(tag, total, amplifier_value)
            end
            total = GET_ARCHEOLOGY_EXHIBITION_DISPLAY_VALUE_BY_RATE(tag, total, scale_rate)

            local unit = ARCHEOLOGY_RULES.round_option_value(tag, 0.5) == 0.5 and 0.01 or 1
            local total_units = math.floor(total / unit + 0.5)
            local used_units = 0
            local shares = {}
            for i, entry in ipairs(list) do
                local exact = total_units * entry.value / raw_sum
                local base = math.floor(exact)
                shares[i] = { entry = entry, units = base, frac = exact - base }
                used_units = used_units + base
            end
            table.sort(shares, function(a, b)
                if a.frac ~= b.frac then return a.frac > b.frac end
                if a.entry.slot ~= b.entry.slot then return a.entry.slot < b.entry.slot end
                return a.entry.index < b.entry.index
            end)
            for i = 1, math.max(0, total_units - used_units) do
                local share = shares[((i - 1) % #shares) + 1]
                share.units = share.units + 1
            end
            for _, share in ipairs(shares) do
                result[share.entry.slot] = result[share.entry.slot] or {}
                result[share.entry.slot][share.entry.index] =
                    ARCHEOLOGY_RULES.round_option_value(tag, share.units * unit)
            end
        end
    end
    return result
end

-- slotIndex: 전시 슬롯 툴팁이면 그 슬롯 번호(1~3). 모르면 nil 로 넘겨 메타 일치 슬롯을 찾는다.
function GET_ARCHEOLOGY_EXHIBITION_DISPLAY_OPTION_LIST(optionMeta, pc, slotIndex)
    local option_list = GET_ARCHEOLOGY_OPTION_INFO(optionMeta)
    if option_list == nil or #option_list == 0 then
        return {}
    end

    -- 전시 중인 슬롯의 유물이면 슬롯 합계 기준으로 나눈 값을 쓴다.
    -- 메타가 같은 유물이 두 슬롯에 있으면 메타 검색은 첫 슬롯 몫만 찾으므로, 슬롯을 알면 그 슬롯 몫을 쓴다.
    local distributed = nil
    slotIndex = tonumber(slotIndex)
    if optionMeta ~= nil and optionMeta ~= "None" and optionMeta ~= "" and slotIndex ~= nil and slotIndex >= 1 and slotIndex <= 3 then
        if GET_ARCEX_SLOT_META(pc, slotIndex) == optionMeta then
            distributed = GET_ARCHEOLOGY_EXHIBITION_DISTRIBUTED_VALUES(pc)[slotIndex]
        end
    elseif optionMeta ~= nil and optionMeta ~= "None" and optionMeta ~= "" then
        for slot = 1, 3 do
            if GET_ARCEX_SLOT_META(pc, slot) == optionMeta then
                distributed = GET_ARCHEOLOGY_EXHIBITION_DISTRIBUTED_VALUES(pc)[slot]
                break
            end
        end
    end

    local display_list = {}
    local scale_rate = GET_ARCHEOLOGY_EXHIBITION_EFFECT_SCALE_RATE(pc)
    local amplifier_value_by_tag = {}
    for _, opt in ipairs(option_list) do
        local display_opt = {}
        for key, value in pairs(opt) do
            display_opt[key] = value
        end
        display_opt.rawValue = opt.value
        local display_value = opt.value
        if GET_ARCHEOLOGY_EXHIBITION_AMPLIFIER_VALUE ~= nil then
            local amplifier_value = amplifier_value_by_tag[opt.tag]
            if amplifier_value == nil then
                amplifier_value = GET_ARCHEOLOGY_EXHIBITION_AMPLIFIER_VALUE(opt.tag, pc)
                amplifier_value_by_tag[opt.tag] = amplifier_value
            end
            display_value = tonumber(opt.value) or 0
            if amplifier_value > 0 then
                display_value = ARCHEOLOGY_RULES.amplify_option_value(opt.tag, display_value, amplifier_value)
            end
        end
        display_opt.value = GET_ARCHEOLOGY_EXHIBITION_DISPLAY_VALUE_BY_RATE(opt.tag, display_value, scale_rate)
        if distributed ~= nil and distributed[#display_list + 1] ~= nil then
            display_opt.value = distributed[#display_list + 1]
        end
        display_list[#display_list + 1] = display_opt
    end

    return display_list
end

-- exhibition_level 을 주면 현재 등급 대신 그 등급의 효과 배율로 계산한다(입장 창 등급별 가이드용).
local function APPLY_ARCHEOLOGY_EXHIBITION_LEVEL_SCALE(apply_buff_list, pc, exhibition_level)
    local scale_rate = exhibition_level ~= nil and
        shared_archeology.get_exhibition_effect_scale_rate(exhibition_level) or
        GET_ARCHEOLOGY_EXHIBITION_EFFECT_SCALE_RATE(pc)
    if scale_rate >= 100 then
        return apply_buff_list
    end

    for effectName, effectValue in pairs(apply_buff_list) do
        apply_buff_list[effectName] = GET_ARCHEOLOGY_EXHIBITION_DISPLAY_VALUE_BY_RATE(effectName, effectValue, scale_rate)
    end

    return apply_buff_list
end

local function IS_ARCHEOLOGY_COMBAT_EFFECT(effectName)
    local rule = GET_ARCHEOLOGY_EXHIBITION_STAT_RULE(effectName)
    return rule ~= nil and rule.effectCategory == "Combat"
end

local function IS_ARCHEOLOGY_SPECIAL_EFFECT(effectName)
    local rule = GET_ARCHEOLOGY_EXHIBITION_STAT_RULE(effectName)
    return rule ~= nil and rule.effectCategory == "Special"
end

local function CAN_APPLY_AMPLIFIER(target, effectName)
    if effectName == "ARCHEOLOGY_EXHIBIT_EFFECT_BOOST" then
        return false
    end

    if target == "All" then
        return true
    end

    if target == "Archeology" then
        return string.find(effectName, "ARCHEOLOGY_") == 1
    end

    if target == "Combat" then
        return IS_ARCHEOLOGY_COMBAT_EFFECT(effectName) or IS_ARCHEOLOGY_SPECIAL_EFFECT(effectName)
    end

    if target == "Special" then
        return IS_ARCHEOLOGY_SPECIAL_EFFECT(effectName)
    end

    return IS_ARCHEOLOGY_COMBAT_EFFECT(effectName) == false and IS_ARCHEOLOGY_SPECIAL_EFFECT(effectName) == false
end

function GET_ARCHEOLOGY_EXHIBITION_AMPLIFIER_VALUE(effectName, pc)
    local amplifier_cls = GET_ARCEX_AMPLIFIER_ITEM(pc)
    if amplifier_cls == nil then
        return 0
    end

    local target = TryGetProp(amplifier_cls, "AmplifierTarget", "Archeology")
    if CAN_APPLY_AMPLIFIER(target, effectName) ~= true then
        return 0
    end

    local value = tonumber(TryGetProp(amplifier_cls, "AmplifierValue", 0)) or 0
    local amplifier_meta = GET_ARCEX_AMPLIFIER_META(pc)
    local option_list = GET_ARCHEOLOGY_OPTION_INFO(amplifier_meta)
    for _, opt in ipairs(option_list) do
        if opt.tag == "ARCHEOLOGY_EXHIBIT_EFFECT_BOOST" then
            value = value + (tonumber(opt.value) or 0)
        end
    end

    return math.max(0, value)
end

function GET_ARCHEOLOGY_EXHIBITION_AMPLIFIED_VALUE(effectName, effectValue, pc)
    local numeric_value = tonumber(effectValue) or 0
    local amplifier_value = GET_ARCHEOLOGY_EXHIBITION_AMPLIFIER_VALUE(effectName, pc)
    if amplifier_value <= 0 then
        return numeric_value
    end

    return ARCHEOLOGY_RULES.amplify_option_value(effectName, numeric_value, amplifier_value)
end

local function APPLY_ARCEX_AMPLIFIER(apply_buff_list, amplifier_cls, pc)
    if amplifier_cls == nil then
        return apply_buff_list
    end

    local target = TryGetProp(amplifier_cls, "AmplifierTarget", "Archeology")
    local value = tonumber(TryGetProp(amplifier_cls, "AmplifierValue", 0))
    if value == nil then
        value = 0
    end

    local amplifier_meta = GET_ARCEX_AMPLIFIER_META(pc)
    local option_list = GET_ARCHEOLOGY_OPTION_INFO(amplifier_meta)
    for _, opt in ipairs(option_list) do
        if opt.tag == "ARCHEOLOGY_EXHIBIT_EFFECT_BOOST" then
            value = value + (tonumber(opt.value) or 0)
        end
    end

    if value == nil or value <= 0 then
        return apply_buff_list
    end

    for effectName, effectValue in pairs(apply_buff_list) do
        if CAN_APPLY_AMPLIFIER(target, effectName) == true then
            apply_buff_list[effectName] = ARCHEOLOGY_RULES.amplify_option_value(effectName, effectValue, value)
        end
    end

    return apply_buff_list
end

function GET_CURRENT_APPLY_EFFECT_LIST(pc, exhibition_level)
    local apply_buff_list = {}

    for i = 1, 3 do
        local item_idx = GET_ARCEX_SLOT_ITEM_IDX(pc, i)
        local item_cls = GET_ARCEX_ITEM_BY_CLSID(item_idx)
        if item_cls ~= nil and GET_ARCEX_ITEM_TYPE(item_cls) ~= "Amplifier" then
            local arc_prefix = GET_ARCEX_SLOT_META(pc, i)
            local option_list = GET_ARCHEOLOGY_OPTION_INFO(arc_prefix)
            for _, opt in ipairs(option_list) do
                local effect_tag = opt.tag
                local effect_value = tonumber(opt.value)
                if effect_tag ~= nil and effect_tag ~= "" and effect_tag ~= "UNKNOWN" and effect_tag ~= "ARCHEOLOGY_EXHIBIT_EFFECT_BOOST" and effect_value ~= nil then
                    if apply_buff_list[effect_tag] == nil then
                        apply_buff_list[effect_tag] = effect_value
                    else
                        apply_buff_list[effect_tag] = apply_buff_list[effect_tag] + effect_value
                    end
                end
            end
        end
    end

    local amplifier_cls = GET_ARCEX_AMPLIFIER_ITEM(pc)
    apply_buff_list = APPLY_ARCEX_AMPLIFIER(apply_buff_list, amplifier_cls, pc)
    return APPLY_ARCHEOLOGY_EXHIBITION_LEVEL_SCALE(apply_buff_list, pc, exhibition_level)
end
