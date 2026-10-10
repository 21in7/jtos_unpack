-- shared_archeology_rules.lua
-- 고고학 XML 데이터를 한 번만 순회해 도메인별 불변 룰 캐시로 제공한다.

ARCHEOLOGY_RULES = ARCHEOLOGY_RULES or {}

local rules = ARCHEOLOGY_RULES
local cache = {}
local EMPTY_LIST = {}

local function for_each_class(idspace, visitor)
    local classList, count = GetClassList(idspace)
    for index = 0, (tonumber(count) or 0) - 1 do
        local class = GetClassByIndexFromList(classList, index)
        if class ~= nil then
            visitor(class)
        end
    end
end

local function text_value(class, property, defaultValue)
    local value = TryGetProp(class, property, defaultValue)
    if value == nil or value == "" then
        return defaultValue
    end
    return value
end

local function number_value(class, property, defaultValue)
    return tonumber(TryGetProp(class, property, defaultValue)) or defaultValue
end

local function for_each_rule(idspace, handlers)
    for_each_class(idspace, function(class)
        local rowType = text_value(class, "RowType", "DEFAULT")
        local handler = handlers[rowType] or handlers.DEFAULT
        if handler ~= nil then
            handler(class)
        end
    end)
end

local function ensure_portal_rule_rows()
    if cache.portalRuleRows ~= nil then
        return cache.portalRuleRows
    end

    local rows = {}
    for_each_class("archeology_portal_difficulty", function(class)
        rows[#rows + 1] = {
            class = class,
            rowType = text_value(class, "RowType", "DEFAULT"),
        }
    end)
    cache.portalRuleRows = rows
    return rows
end

local function for_each_portal_rule(handlers)
    for _, row in ipairs(ensure_portal_rule_rows()) do
        local handler = handlers[row.rowType] or handlers.DEFAULT
        if handler ~= nil then
            handler(row.class)
        end
    end
end

local function parse_list(rawValue)
    local values = {}
    if rawValue == nil or rawValue == "" or rawValue == "None" then
        return values
    end
    for value in string.gmatch(tostring(rawValue), "[^;]+") do
        values[#values + 1] = value
    end
    return values
end

local function parse_csv(rawValue)
    local values = {}
    if rawValue == nil or rawValue == "" or rawValue == "None" then
        return values
    end
    for value in string.gmatch(tostring(rawValue), "[^,]+") do
        values[#values + 1] = value
    end
    return values
end

local function parse_number_list(rawValue)
    local values = parse_list(rawValue)
    for index, value in ipairs(values) do
        values[index] = tonumber(value) or 0
    end
    return values
end

-- "KEY,weight;KEY,weight" 형태를 { KEY = weight } 맵으로 바꾼다.
local function parse_weight_map(rawValue)
    local weights = {}
    for _, entry in ipairs(parse_list(rawValue)) do
        local values = parse_csv(entry)
        local key = string.match(tostring(values[1] or ""), "^%s*(.-)%s*$")
        local weight = tonumber(values[2]) or 0
        if key ~= "" and weight > 0 then
            weights[key] = (weights[key] or 0) + weight
        end
    end
    return weights
end

local function localized_message(messageKey)
    if messageKey == nil or messageKey == "" or messageKey == "None" then
        return "None"
    end
    if ScpArgMsg ~= nil then
        return ScpArgMsg(messageKey)
    end
    return messageKey
end

local SURVEY_DIRECTION_MESSAGE_KEYS = {
    "ARCHEOLOGY_DIRECTION_SOUTHEAST",
    "ARCHEOLOGY_DIRECTION_SOUTH",
    "ARCHEOLOGY_DIRECTION_SOUTHWEST",
    "ARCHEOLOGY_DIRECTION_WEST",
    "ARCHEOLOGY_DIRECTION_NORTHWEST",
    "ARCHEOLOGY_DIRECTION_NORTH",
    "ARCHEOLOGY_DIRECTION_NORTHEAST",
    "ARCHEOLOGY_DIRECTION_EAST",
}

function rules.get_survey_direction_label(index)
    local messageKey = SURVEY_DIRECTION_MESSAGE_KEYS[tonumber(index)]
    return localized_message(messageKey)
end

local function ensure_options()
    if cache.options ~= nil then
        return cache.options
    end

    local result = { byStat = {}, gradeByID = {} }
    for_each_class("archeology_option_list", function(class)
        local classID = number_value(class, "ClassID", 0)
        if classID > 0 then
            result.gradeByID[classID] = number_value(class, "Grade", 0)
        end

        local stat = text_value(class, "Stat", "None")
        local minValue = number_value(class, "MinValue", 0)
        local maxValue = number_value(class, "MaxValue", 0)
        local isDecimal = minValue ~= math.floor(minValue) or maxValue ~= math.floor(maxValue)
        if stat ~= "None" and result.byStat[stat] == nil then
            result.byStat[stat] = {
                stat = stat,
                optionRole = text_value(class, "OptionRole", "General"),
                effectCategory = text_value(class, "EffectCategory", "None"),
                scalePolicy = text_value(class, "ScalePolicy", "ExhibitionLevel"),
                displayNameMsg = text_value(class, "DisplayNameMsg", "None"),
                displayValueMsg = text_value(class, "DisplayValueMsg", "None"),
                displayTypeMsg = text_value(class, "DisplayTypeMsg", "None"),
                displayFormat = text_value(class, "DisplayFormat", "None"),
                displayScale = number_value(class, "DisplayScale", 1),
                displayColor = text_value(class, "DisplayColor", "{#AAAAAA}"),
            }
        end
        -- 한 행이라도 소수 범위면 그 효과는 소수값으로 합산한다(ArcheologyRuleCache.cpp 와 같은 규칙).
        if stat ~= "None" and isDecimal == true then
            result.byStat[stat].decimalValue = true
        end
    end)
    cache.options = result
    return result
end

function rules.get_option_rule(stat)
    if stat == nil or stat == "" or stat == "None" then
        return nil
    end
    return ensure_options().byStat[stat]
end

local function ensure_exhibition()
    if cache.exhibition ~= nil then
        return cache.exhibition
    end

    local result = {
        policy = nil,
        levels = {},
        maxLevel = 1,
        tiers = {},
        rarities = {},
        bases = {},
        items = {},
    }
    local handlers = {}
    -- LEVEL 행을 레벨별 요구 경험치와 최대 코스트 프로필로 캐시한다.
    handlers.LEVEL = function(class)
        local level = tonumber(text_value(class, "ClassName", "0")) or 0
        if level <= 0 then
            return
        end

        result.levels[level] = {
            level = level,
            exp = number_value(class, "Exp", 0),
            maxCost = number_value(class, "MaxCost", 0),
            rewardItem = text_value(class, "RewardItem", "None"),
            rewardItemCount = number_value(class, "RewardItemCount", 0),
            rewardText = text_value(class, "RewardText", "None"),
            unlockAmplifierSlot =
                text_value(class, "UnlockAmplifierSlot", "NO") == "YES",
        }
        result.maxLevel = math.max(result.maxLevel, level)
    end
    -- 전시 전역 스케일 정책을 캐시한다.
    handlers.GLOBAL = function(class)
        result.policy = {
            levelScaleBaseRate = number_value(class, "LevelScaleBaseRate", 100),
            levelScalePerLevel = number_value(class, "LevelScalePerLevel", 0),
            levelScaleCap = number_value(class, "LevelScaleCap", 100),
        }
    end
    handlers.BASE_TIER = function(class)
        local tier = number_value(class, "BaseTier", 0)
        if tier > 0 then
            result.tiers[tier] = {
                baseTier = tier,
                valueRate = number_value(class, "ValueRate", 100),
                dropWeightGrade = text_value(class, "DropWeightGrade", "Common"),
                desc = text_value(class, "Desc", "None"),
            }
        end
    end
    handlers.RARITY = function(class)
        local rarity = text_value(class, "Rarity", "None")
        if rarity ~= "None" then
            result.rarities[rarity] = {
                rarity = rarity,
                optionGradeMax = number_value(class, "OptionGradeMax", 0),
                maxPrefix = number_value(class, "MaxPrefix", 0),
                maxSuffix = number_value(class, "MaxSuffix", 0),
                cost = number_value(class, "Cost", 0),
            }
        end
    end
    for_each_rule("archeology_exhibition_exp", handlers)
    result.policy = result.policy or {
        levelScaleBaseRate = 100,
        levelScalePerLevel = 0,
        levelScaleCap = 100,
    }

    for_each_class("archeology_base_list", function(class)
        local className = text_value(class, "ClassName", "None")
        local tier = number_value(class, "BaseTier", 0)
        local tierRule = result.tiers[tier]
        if className ~= "None" and tierRule ~= nil then
            local desc = text_value(class, "Desc", "None")
            if desc == "None" then
                desc = tierRule.desc
            end
            result.bases[className] = {
                className = className,
                baseTier = tier,
                valueRate = tierRule.valueRate,
                dropWeightGrade = tierRule.dropWeightGrade,
                desc = desc,
                exhibitSlotType = text_value(class, "ExhibitSlotType", "None"),
                optionPoolTheme = text_value(class, "OptionPoolTheme", "None"),
                loreTag = text_value(class, "LoreTag", "None"),
                mapStateTag = text_value(class, "MapStateTag", "None"),
                affixPrefixPool = text_value(class, "AffixPrefixPool", ""),
                affixSuffixPool = text_value(class, "AffixSuffixPool", ""),
            }
        end
    end)
    cache.exhibition = result
    return result
end

local function filter_affix_pool(pool, maxGrade)
    local filtered = {}
    maxGrade = tonumber(maxGrade) or 0
    if pool == nil or pool == "" or pool == "None" or maxGrade <= 0 then
        return ""
    end

    local gradeByID = ensure_options().gradeByID
    for _, optionID in ipairs(parse_list(pool)) do
        local grade = gradeByID[tonumber(optionID) or 0] or 0
        if grade > 0 and grade <= maxGrade then
            filtered[#filtered + 1] = optionID
        end
    end
    return table.concat(filtered, ";")
end

function rules.get_base_profile(className)
    return ensure_exhibition().bases[className]
end

function rules.get_base_tier(baseTier)
    return ensure_exhibition().tiers[tonumber(baseTier) or 0]
end

function rules.get_exhibition_rarity(rarity)
    return ensure_exhibition().rarities[rarity]
end

-- 전시 LEVEL 행만 기준으로 실제 최대 레벨을 반환한다.
function rules.get_exhibition_max_level()
    return ensure_exhibition().maxLevel
end

-- 지정한 전시 레벨의 경험치·코스트 프로필을 반환한다.
function rules.get_exhibition_level(level)
    return ensure_exhibition().levels[tonumber(level) or 0]
end

function rules.get_exhibition_scale_rate(exhibitionLevel)
    local policy = ensure_exhibition().policy
    local level = math.max(1, tonumber(exhibitionLevel) or 1)
    return math.min(policy.levelScaleCap,
        policy.levelScaleBaseRate + math.max(0, level - 1) * policy.levelScalePerLevel)
end

-- 소수값 효과(처치 시 HP 회복·크리티컬 발굴 확률 등)는 정수로 반올림하면 1 로 부풀거나
-- 0 으로 사라진다. 소수 둘째 자리까지만 반올림한다. 정수 효과는 종전대로 정수 반올림.
function rules.round_option_value(stat, value)
    local numericValue = tonumber(value) or 0
    local optionRule = rules.get_option_rule(stat)
    if optionRule ~= nil and optionRule.decimalValue == true then
        return math.floor(numericValue * 100 + 0.5) / 100
    end
    return math.floor(numericValue + 0.5)
end

-- 불씨 증폭. 작은 정수 합은 반올림으로 증폭분이 사라지므로(3 × 1.1 → 3) 양수는 최소 한 단계(1·0.01) 올린다.
-- 서버 C++ AmplifyOptionTotal(ArcheologyRuleUtil.h)과 같아야 한다.
function rules.amplify_option_value(stat, value, amplifierValue)
    local numericValue = tonumber(value) or 0
    amplifierValue = tonumber(amplifierValue) or 0
    if amplifierValue <= 0 then
        return numericValue
    end
    local amplified = rules.round_option_value(stat, (numericValue * (100 + amplifierValue)) / 100)
    if numericValue > 0 and amplified <= numericValue then
        local optionRule = rules.get_option_rule(stat)
        local step = (optionRule ~= nil and optionRule.decimalValue == true) and 0.01 or 1
        return rules.round_option_value(stat, numericValue + step)
    end
    return amplified
end

function rules.scale_exhibition_value_by_rate(stat, value, scaleRate)
    local numericValue = tonumber(value) or 0
    local optionRule = rules.get_option_rule(stat)
    scaleRate = tonumber(scaleRate) or 100
    if numericValue <= 0 or scaleRate >= 100 or
            (optionRule ~= nil and optionRule.scalePolicy == "Fixed") then
        return numericValue
    end
    if optionRule ~= nil and optionRule.decimalValue == true then
        return math.max(0.01, rules.round_option_value(stat, (numericValue * scaleRate) / 100))
    end
    return math.max(1, math.floor((numericValue * scaleRate) / 100 + 0.5))
end

function rules.get_exhibition_item(exhibitionItem)
    local class = exhibitionItem
    if type(exhibitionItem) == "string" then
        class = GetClass("archeology_exhibition_item", exhibitionItem)
    end
    if class == nil then
        return nil
    end

    local exhibition = ensure_exhibition()
    local className = text_value(class, "ClassName", "None")
    if className ~= "None" and exhibition.items[className] ~= nil then
        return exhibition.items[className]
    end

    local rarity = text_value(class, "Rarity", "None")
    local baseClass = text_value(class, "BaseClass", "None")
    local rarityRule = exhibition.rarities[rarity]
    local baseRule = exhibition.bases[baseClass]
    local legacyPool = text_value(class, "OptionPool", "")
    local legacyCount = number_value(class, "OptionCount", 0)
    local isLegacyItem = legacyPool ~= "" and legacyPool ~= "None" and legacyCount > 0
    local profile = {
        rarity = rarity,
        baseClass = baseClass,
        prefixPool = text_value(class, "PrefixPool", ""),
        suffixPool = text_value(class, "SuffixPool", ""),
        maxPrefix = number_value(class, "MaxPrefix", 0),
        maxSuffix = number_value(class, "MaxSuffix", 0),
        cost = math.max(0, number_value(class, "cost", 0)),
        legacy = isLegacyItem,
    }
    if isLegacyItem then
        -- 구형 유물은 기존 단일 OptionPool을 Prefix 슬롯 하나로 유지한다.
        profile.prefixPool = legacyPool
        profile.suffixPool = ""
        profile.maxPrefix = legacyCount
        profile.maxSuffix = 0
    elseif rarityRule ~= nil and baseRule ~= nil then
        profile.prefixPool = filter_affix_pool(
            baseRule.affixPrefixPool, rarityRule.optionGradeMax)
        profile.suffixPool = filter_affix_pool(
            baseRule.affixSuffixPool, rarityRule.optionGradeMax)
        profile.maxPrefix = rarityRule.maxPrefix
        profile.maxSuffix = rarityRule.maxSuffix
        profile.cost = rarityRule.cost
    end
    if className ~= "None" then
        exhibition.items[className] = profile
    end
    return profile
end

local function ensure_drop()
    if cache.drop ~= nil then
        return cache.drop
    end

    local result = {
        policy = {},
        items = {},
        slots = {},
        dungeonSlots = {},
    }
    local function get_item(class)
        local itemClass = text_value(class, "ItemClass", "None")
        if itemClass == "None" then
            return nil
        end
        local item = result.items[itemClass]
        if item == nil then
            item = {
                itemClass = itemClass,
                rewardKind = "STANDARD",
                directDropGateChance = {},
            }
            result.items[itemClass] = item
        end
        return item
    end
    local handlers = {}
    handlers.GLOBAL = function(class)
        result.policy = {
            exhibitRareBonusPerLevel = number_value(class, "ExhibitRareBonusPerLevel", 0),
            exhibitRareBonusCap = number_value(class, "ExhibitRareBonusCap", 0),
            exhibitNormalBonusLevelDivisor = math.max(1,
                number_value(class, "ExhibitNormalBonusLevelDivisor", 1)),
            exhibitNormalBonusCap = number_value(class, "ExhibitNormalBonusCap", 0),
            exhibitSlotBonusLevelDivisor = math.max(1,
                number_value(class, "ExhibitSlotBonusLevelDivisor", 1)),
            exhibitSlotBonusCap = number_value(class, "ExhibitSlotBonusCap", 0),
            maxSlotChance = number_value(class, "MaxSlotChance", 100),
            shardJackpotMultiplier = math.max(1,
                number_value(class, "ShardJackpotMultiplier", 1)),
        }
    end
    local function read_slot_chances(class)
        return {
            Normal = number_value(class, "NormalChance", 0),
            Elite = number_value(class, "EliteChance", 0),
            MidBoss = number_value(class, "MidBossChance", 0),
            Boss = number_value(class, "BossChance", 0),
        }
    end
    handlers.FIELD_SLOT = function(class)
        local dropSlot = text_value(class, "DropSlot", "None")
        if dropSlot ~= "None" then
            local slot = {
                dropSlot = dropSlot,
                chanceByMonsterType = read_slot_chances(class),
                monsterDropRateScale = number_value(class, "MonsterDropRateScale", 0),
                monsterDropRateCap = number_value(class, "MonsterDropRateCap", 100),
                relicDropRateScale = number_value(class, "RelicDropRateScale", 0),
                modifierDropRateScale = number_value(class, "ModifierDropRateScale", 0),
            }
            result.slots[dropSlot] = slot
        end
    end
    handlers.SLOT = handlers.FIELD_SLOT
    handlers.DUNGEON_SLOT = function(class)
        local dropSlot = text_value(class, "DropSlot", "None")
        local difficulty = text_value(class, "Difficulty", "DEFAULT")
        if dropSlot == "None" then
            return
        end

        local slot = result.dungeonSlots[dropSlot]
        if slot == nil then
            slot = { dropSlot = dropSlot, byDifficulty = {} }
            result.dungeonSlots[dropSlot] = slot
        end
        slot.byDifficulty[difficulty] = {
            dropSlot = dropSlot,
            difficulty = difficulty,
            chanceByMonsterType = read_slot_chances(class),
            afterFirstRate = number_value(class, "AfterFirstRate", 1),
        }
    end
    handlers.ITEM = function(class)
        local item = get_item(class)
        if item ~= nil then
            item.rewardKind = text_value(class, "RewardKind", "STANDARD")
        end
    end
    handlers.DIRECT_DROP_GATE = function(class)
        local item = get_item(class)
        local difficulty = text_value(class, "Difficulty", "None")
        if item ~= nil and difficulty ~= "None" then
            item.directDropGateChance[difficulty] = number_value(class, "Chance", 0)
        end
    end
    for_each_rule("archeology_drop_policy", handlers)
    cache.drop = result
    return result
end

function rules.get_drop_policy()
    return ensure_drop().policy
end

local function get_drop_item(itemClass)
    return ensure_drop().items[itemClass]
end

function rules.get_drop_item_reward_kind(itemClass)
    local item = get_drop_item(itemClass)
    return item ~= nil and item.rewardKind or "STANDARD"
end

function rules.get_direct_drop_gate_chance(itemClass, difficulty)
    local item = get_drop_item(itemClass)
    return item ~= nil and item.directDropGateChance[difficulty] or nil
end

function rules.get_drop_slot(dropSlot)
    return ensure_drop().slots[dropSlot]
end

function rules.get_dungeon_drop_slot(dropSlot, difficulty)
    local slot = ensure_drop().dungeonSlots[dropSlot]
    if slot == nil then
        return nil
    end

    local profiles = slot.byDifficulty
    local profile = profiles[difficulty]
    if profile == nil and difficulty == "EASY" then
        profile = profiles.NORMAL
    end
    return profile or profiles.DEFAULT
end

function rules.get_dungeon_drop_slots(difficulty)
    local result = {}
    for dropSlot, _ in pairs(ensure_drop().dungeonSlots) do
        local profile = rules.get_dungeon_drop_slot(dropSlot, difficulty)
        if profile ~= nil then
            result[dropSlot] = profile.chanceByMonsterType
        end
    end
    return result
end

local function ensure_rewards()
    if cache.rewards ~= nil then
        return cache.rewards
    end

    local result = {
        byLevel = {},
        itemClassesByLevel = {},
        queries = {},
        groupWeights = {},
    }
    for_each_class("archeology_reward_list", function(class)
        local itemClass = text_value(class, "ItemClass",
            text_value(class, "ClassName", "None"))
        if itemClass == "None" then
            return
        end

        local level = number_value(class, "Lv", 470)
        local entry = {
            level = level,
            region = text_value(class, "Region", "All"),
            itemClass = itemClass,
            rarity = text_value(class, "Rarity", "None"),
            weight = number_value(class, "Weight", 0),
            bonusWeight = number_value(class, "BonusWeight", 0),
            minCount = number_value(class, "MinCount", 1),
            maxCount = number_value(class, "MaxCount", 1),
            minExhibitionLevel = number_value(class, "MinExhibitLv", 1),
            maxExhibitionLevel = number_value(class, "MaxExhibitLv", 999),
        }
        result.byLevel[level] = result.byLevel[level] or {}
        result.byLevel[level][#result.byLevel[level] + 1] = entry
        result.itemClassesByLevel[level] = result.itemClassesByLevel[level] or {}
        result.itemClassesByLevel[level][#result.itemClassesByLevel[level] + 1] = itemClass
    end)
    cache.rewards = result
    return result
end

function rules.get_reward_entries(level, region)
    level = tonumber(level) or 470
    region = region or "All"
    local data = ensure_rewards()
    local queryKey = tostring(level) .. ":" .. tostring(region)
    local entries = data.queries[queryKey]
    if entries ~= nil then
        return entries
    end

    entries = {}
    for _, entry in ipairs(data.byLevel[level] or EMPTY_LIST) do
        if entry.region == "All" or entry.region == region then
            entries[#entries + 1] = entry
        end
    end
    data.queries[queryKey] = entries
    return entries
end

function rules.get_reward_item_classes(level)
    return ensure_rewards().itemClassesByLevel[tonumber(level) or 470]
end

function rules.get_reward_group_weights(level, region, exhibitionLevel)
    level = tonumber(level) or 470
    region = region or "All"
    exhibitionLevel = tonumber(exhibitionLevel) or 1
    local data = ensure_rewards()
    local queryKey = tostring(level) .. ":" .. tostring(region) .. ":" ..
        tostring(exhibitionLevel)
    local weights = data.groupWeights[queryKey]
    if weights ~= nil then
        return weights.rare, weights.normal
    end

    local rareWeight = 0
    local normalWeight = 0
    for _, entry in ipairs(rules.get_reward_entries(level, region)) do
        if exhibitionLevel >= entry.minExhibitionLevel and
                exhibitionLevel <= entry.maxExhibitionLevel and entry.weight > 0 then
            if entry.rarity ~= "Normal" and entry.rarity ~= "Common" then
                rareWeight = rareWeight + entry.weight
            else
                normalWeight = normalWeight + entry.weight
            end
        end
    end
    data.groupWeights[queryKey] = { rare = rareWeight, normal = normalWeight }
    return rareWeight, normalWeight
end

-- 제단 등급 1..exhibitionLevel 가운데 가장 높은 희귀 그룹 비율(%).
-- 보상표는 등급이 오를 때 일반·잡화 행만 더 풀리는 구간(3·6·8·9등급 등)이 있어
-- 현재 등급 비율만 쓰면 등급이 올라도 희귀 확률이 떨어진다. 희귀 확률의 기본 비율은
-- 이 값 아래로 내려가지 않게 한다(calculate_reward_rare_probability).
function rules.get_reward_rare_share_floor(level, region, exhibitionLevel)
    level = tonumber(level) or 470
    region = region or "All"
    exhibitionLevel = math.max(1, math.floor(tonumber(exhibitionLevel) or 1))
    local data = ensure_rewards()
    data.rareShareFloors = data.rareShareFloors or {}
    local queryKey = tostring(level) .. ":" .. tostring(region) .. ":" ..
        tostring(exhibitionLevel)
    local cached = data.rareShareFloors[queryKey]
    if cached ~= nil then
        return cached
    end

    local best = 0
    for lv = 1, exhibitionLevel do
        local rareWeight, normalWeight = rules.get_reward_group_weights(level, region, lv)
        if rareWeight > 0 then
            best = math.max(best, rareWeight * 100 / (rareWeight + normalWeight))
        end
    end
    data.rareShareFloors[queryKey] = best
    return best
end

local function ensure_monster_drops()
    if cache.monsterDrops ~= nil then
        return cache.monsterDrops
    end

    local result = { byMonsterType = {} }
    for_each_class("archeology_monster_drop", function(class)
        local monsterType = text_value(class, "MonsterType", "Normal")
        local dropSlot = text_value(class, "DropSlot", "Relic")
        local itemClass = text_value(class, "ItemClass", "None")
        if itemClass == "None" then
            return
        end

        local entry = {
            monsterType = monsterType,
            dropSlot = dropSlot,
            itemClass = itemClass,
            rewardKind = rules.get_drop_item_reward_kind(itemClass),
            rarity = text_value(class, "Rarity", "Normal"),
            weight = number_value(class, "Weight", 0),
            count = number_value(class, "Count", 1),
            minDifficulty = text_value(class, "MinDifficulty", "EASY"),
            maxDifficulty = text_value(class, "MaxDifficulty", "VERY_HARD"),
            nebulasBaseMaterial = text_value(class, "NebulasBaseMaterial", "NO") == "YES",
            minExhibitionLevel = number_value(class, "MinExhibitLv", 1),
            maxExhibitionLevel = number_value(class, "MaxExhibitLv", 999),
        }
        result.byMonsterType[monsterType] = result.byMonsterType[monsterType] or {}
        local slots = result.byMonsterType[monsterType]
        slots[dropSlot] = slots[dropSlot] or {}
        slots[dropSlot][#slots[dropSlot] + 1] = entry
    end)
    cache.monsterDrops = result
    return result
end

function rules.get_monster_drop_entries(monsterType, dropSlot)
    local slots = ensure_monster_drops().byMonsterType[monsterType]
    if slots == nil then
        return EMPTY_LIST
    end
    return slots[dropSlot] or EMPTY_LIST
end

local function ensure_portal_modifiers()
    if cache.portalModifiers ~= nil then
        return cache.portalModifiers
    end

    local result = {
        profiles = {}, recordRewards = {}, order = {},
        monsterPolicy = {
            global = {}, monsterTypes = {}, categories = {}, specialMods = {},
        },
    }
    local ordered = {}
    for_each_portal_rule({ PORTAL_MODIFIER_ITEM = function(class)
        local itemClass = text_value(class, "ItemClass", "None")
        if itemClass ~= "None" then
            local item = GetClass("Item", itemClass)
            local performanceMsg = text_value(class, "PerformanceMsg", "None")
            local profile = {
                item_class = itemClass,
                label = TryGetProp(item, "Name", itemClass),
                modifier_order = number_value(class, "ModifierOrder", 999),
                ecology_channel = text_value(class, "EcologyChannel", "None"),
                handler_type = text_value(class, "HandlerType", "None"),
                special_weights =
                    parse_weight_map(text_value(class, "SpecialWeights", "None")),
                boss_special_weights =
                    parse_weight_map(text_value(class, "BossSpecialWeights", "None")),
                mon_hp_pct = number_value(class, "MonHPPct", 0),
                mon_atk_pct = number_value(class, "MonATKPct", 0),
                mon_def_pct = number_value(class, "MonDEFPct", 0),
                frag_bonus = number_value(class, "FragmentBonus", 0),
                reward_relic_drop_rate = number_value(class, "RewardRelicDropRate", 0),
                reward_rare_chance = number_value(class, "RewardRareChance", 0),
                reward_rare_chance_display_scale =
                    number_value(class, "RewardRareChanceDisplayScale", 1),
                reward_low_shard_drop = number_value(class, "RewardLowShardDrop", 0),
                reward_high_shard_drop = number_value(class, "RewardHighShardDrop", 0),
                reward_memory_fragment_drop =
                    number_value(class, "RewardMemoryFragmentDrop", 0),
                reward_coin_bonus_pct = number_value(class, "RewardCoinBonusPct", 0),
                rule_msg = text_value(class, "RuleMsg", "None"),
                performance_msg = performanceMsg,
            }
            result.profiles[itemClass] = profile
            result.recordRewards[itemClass] = {
                itemClass = itemClass,
                key = text_value(class, "RecordKey", "None"),
                maxPerformanceStage = number_value(class, "MaxPerformanceStage", 0),
                performanceConditionMsg = performanceMsg,
                score = {
                    basic = number_value(class, "BasicScore", 0),
                    performance = parse_number_list(
                        text_value(class, "PerformanceScores", "None")),
                },
                rewards = { HARD = {}, VERY_HARD = {} },
                enabled = text_value(class, "RecordEnabled", "NO") == "YES",
                performanceUsesMonsterDrop =
                    text_value(class, "PerformanceUsesMonsterDrop", "NO") == "YES",
            }
            ordered[#ordered + 1] = profile
        end
    end })
    table.sort(ordered, function(left, right)
        return left.modifier_order < right.modifier_order
    end)
    for _, profile in ipairs(ordered) do
        result.order[#result.order + 1] = profile.item_class
    end

    local policyHandlers = {}
    policyHandlers.MODIFIER_GLOBAL = function(class)
        result.monsterPolicy.global = {
            packBaseChance = number_value(class, "PackBaseChance", 0),
            packRiskScoreBonus = number_value(class, "PackRiskScoreBonus", 0),
            packBossPenalty = number_value(class, "PackBossPenalty", 0),
            packMaxChance = number_value(class, "PackMaxChance", 0),
            secondBaseChance = number_value(class, "SecondBaseChance", 0),
            secondRiskScoreBonus = number_value(class, "SecondRiskScoreBonus", 0),
            secondBossPenalty = number_value(class, "SecondBossPenalty", 0),
            secondMaxChance = number_value(class, "SecondMaxChance", 0),
            secondPityCap = number_value(class, "SecondPityCap", 0),
            itemWeightMaxChanceBonus =
                number_value(class, "ItemWeightMaxChanceBonus", 0),
            itemWeightDivisor = number_value(class, "ItemWeightDivisor", 1),
            itemRiskScoreChanceBonus =
                number_value(class, "ItemRiskScoreChanceBonus", 0),
            riskCapThreshold = number_value(class, "RiskCapThreshold", 0),
            riskMonsterModifierCap =
                number_value(class, "RiskMonsterModifierCap", 0),
        }
    end
    policyHandlers.MONSTER_TYPE = function(class)
        local monType = text_value(class, "MonsterType", "None")
        if monType ~= "None" then
            result.monsterPolicy.monsterTypes[monType] = {
                specialChance = number_value(class, "SpecialChance", 0),
                maxSpecialMods = number_value(class, "MaxSpecialMods", 0),
                chanceCap = number_value(class, "ChanceCap", 0),
                noItemChanceCap = number_value(class, "NoItemChanceCap", 0),
                riskCapAllowed =
                    text_value(class, "RiskCapAllowed", "NO") == "YES",
            }
        end
    end
    policyHandlers.CATEGORY = function(class)
        local category = text_value(class, "Category", "None")
        if category ~= "None" then
            result.monsterPolicy.categories[category] =
                number_value(class, "MaxPerMonster", 1)
        end
    end
    policyHandlers.SPECIAL_MOD = function(class)
        local modName = text_value(class, "Modifier", "None")
        if modName ~= "None" then
            local allowedMonsterTypes = {}
            for _, monType in ipairs(parse_list(
                    text_value(class, "AllowedMonsterTypes", "None"))) do
                allowedMonsterTypes[monType] = true
            end
            result.monsterPolicy.specialMods[modName] = {
                baseWeight = number_value(class, "BaseWeight", 0),
                category = text_value(class, "Category", "MISC"),
                allowedMonsterTypes = allowedMonsterTypes,
                bossBaseAllowed =
                    text_value(class, "BossBaseAllowed", "NO") == "YES",
                bossItemAllowed =
                    text_value(class, "BossItemAllowed", "NO") == "YES",
            }
        end
    end
    for_each_portal_rule(policyHandlers)
    cache.portalModifiers = result
    return result
end

function rules.get_portal_modifiers()
    return ensure_portal_modifiers().profiles
end

function rules.get_monster_modifier_policy()
    return ensure_portal_modifiers().monsterPolicy
end

local function get_portal_modifier(itemClass)
    return ensure_portal_modifiers().profiles[itemClass]
end

function rules.normalize_portal_modifier_item(itemClass)
    return get_portal_modifier(itemClass) ~= nil and itemClass or nil
end

function rules.get_portal_record_rewards()
    return ensure_portal_modifiers().recordRewards
end

function rules.get_portal_record_reward(itemClass)
    return ensure_portal_modifiers().recordRewards[itemClass]
end

function rules.build_portal_modifier_contract(itemClasses)
    local result = {
        itemCount = 0,
        hpPct = 0, atkPct = 0, defPct = 0,
        fragBonus = 0, relicDropRateBonus = 0, rareChanceBonus = 0,
        lowShardDropBonus = 0, highShardDropBonus = 0,
        memoryFragmentDropBonus = 0, coinBonusPct = 0,
    }
    local seen = {}
    for _, itemClass in ipairs(itemClasses or {}) do
        local profile = get_portal_modifier(itemClass)
        if profile ~= nil and seen[itemClass] ~= true then
            seen[itemClass] = true
            result.itemCount = result.itemCount + 1
            result.hpPct = result.hpPct + profile.mon_hp_pct
            result.atkPct = result.atkPct + profile.mon_atk_pct
            result.defPct = result.defPct + profile.mon_def_pct
            result.fragBonus = result.fragBonus + profile.frag_bonus
            result.relicDropRateBonus = result.relicDropRateBonus +
                profile.reward_relic_drop_rate
            result.rareChanceBonus = result.rareChanceBonus +
                profile.reward_rare_chance
            result.lowShardDropBonus = result.lowShardDropBonus +
                profile.reward_low_shard_drop
            result.highShardDropBonus = result.highShardDropBonus +
                profile.reward_high_shard_drop
            result.memoryFragmentDropBonus = result.memoryFragmentDropBonus +
                profile.reward_memory_fragment_drop
            result.coinBonusPct = result.coinBonusPct +
                profile.reward_coin_bonus_pct
        end
    end
    result.normalHpPct = math.floor(math.floor(result.hpPct * 0.75) * 0.6)
    result.normalAtkPct = math.floor(math.floor(result.atkPct * 0.75) * 0.6)
    result.normalDefPct = math.floor(math.floor(result.defPct * 0.75) * 0.6)
    result.eliteHpPct = math.floor(result.hpPct * 0.75)
    result.eliteAtkPct = math.floor(result.atkPct * 0.75)
    result.eliteDefPct = math.floor(result.defPct * 0.75)
    return result
end

local function parse_spawn_template_entries(rawEntries)
    local entries = {}
    for _, rawEntry in ipairs(parse_list(rawEntries)) do
        local values = parse_csv(rawEntry)
        local entry = {
            role = values[1],
            min = tonumber(values[2]) or 0,
            max = tonumber(values[3]) or 0,
            modType = values[4],
        }
        local chance = tonumber(values[5])
        if chance ~= nil then
            entry.chance = chance
        end
        entries[#entries + 1] = entry
    end
    return entries
end

local function ensure_portal_rules()
    if cache.portalRules ~= nil then
        return cache.portalRules
    end

    local result = {
        byName = {}, portalProfiles = {}, deepRates = {},
        streamProfiles = {}, dropScale = {}, clearRareBonusRaw = {}, monsterLevelAdd = {}, ranks = {},
        global = {
            defaultDifficulty = "NORMAL",
            defaultThreatGrade = "DEFAULT",
            deepModeDropRate = 1,
        },
        modeStatRates = {}, missionRewards = {}, threatDropScale = {},
        packAnchorRangeBands = {}, packTemplates = {}, packSpawnPlans = {},
        packAnchorSpreadRate = {}, packEntrySpreadRate = {},
        exchangeRecipes = { ORB = {}, ITEM = {} },
        exchangeRecipeList = {},
        advMonsterSpawn = {},
        streamTemplates = {},
        hazard = { targetCast = {} },
        nebulas = { statProfiles = {} },
    }
    local rewardReaders = {
        EXTERMINATION = function(class)
            return {
                coinMin = number_value(class, "CoinMin", 0),
                coinMax = number_value(class, "CoinMax", 0),
                lowShardCount = number_value(class, "LowShardCount", 0),
                highShardChance = number_value(class, "HighShardChance", 0),
                relicChance = number_value(class, "RelicChance", 0),
                deepRelicChance = number_value(class, "DeepRelicChance", 0),
                quickCoinRate = number_value(class, "QuickCoinRate", 100),
                quickLowShardCount = number_value(class, "QuickLowShardCount", 0),
                quickRelicBonus = number_value(class, "QuickRelicBonus", 0),
            }
        end,
        DEFENSE = function(class)
            return {
                chestRewardCount = number_value(class, "ChestRewardCount", 0),
                guaranteedHighShardCount =
                    number_value(class, "GuaranteedHighShardCount", 0),
                higherTierBonusRaw = {
                    EASY = number_value(class, "EasyHigherTierBonusRaw", 0),
                    NORMAL = number_value(class, "NormalHigherTierBonusRaw", 0),
                    HARD = number_value(class, "HardHigherTierBonusRaw", 0),
                    VERY_HARD = number_value(class, "VeryHardHigherTierBonusRaw", 0),
                },
                deepHigherTierBonusRaw =
                    number_value(class, "DeepHigherTierBonusRaw", 0),
                resonanceHigherTierBonusRaw =
                    number_value(class, "ResonanceHigherTierBonusRaw", 0),
                resonanceCoinCount = number_value(class, "ResonanceCoinCount", 0),
            }
        end,
        REINFORCEMENT = function(class)
            return {
                chestCoinMin = number_value(class, "ChestCoinMin", 0),
                chestCoinMax = number_value(class, "ChestCoinMax", 0),
                deepChestCoinAdd = number_value(class, "DeepChestCoinAdd", 0),
            }
        end,
    }
    local handlers = {}
    handlers.GLOBAL = function(class)
        result.global = {
            defaultDifficulty = text_value(class, "DefaultDifficulty", "NORMAL"),
            defaultThreatGrade = text_value(class, "DefaultThreatGrade", "DEFAULT"),
            deepModeDropRate = number_value(class, "DeepModeDropRate", 1),
        }
    end
    handlers.DIFFICULTY = function(class)
        local difficulty = text_value(class, "Difficulty", "None")
        if difficulty ~= "None" then
            local profile = {
                difficulty = difficulty,
                difficultyRank = number_value(class, "DifficultyRank", 0),
                isPortalDifficulty = text_value(class, "IsPortalDifficulty", "NO") == "YES",
                label = text_value(class, "Label", difficulty),
                levelAdd = number_value(class, "LevelAdd", 0),
                monsterLevelAdd = number_value(class, "MonsterLevelAdd", 0),
                hpPct = number_value(class, "HpPct", 0),
                atkPct = number_value(class, "AtkPct", 0),
                defPct = number_value(class, "DefPct", 0),
                deepHpRate = number_value(class, "DeepHpRate", 100),
                deepAtkRate = number_value(class, "DeepAtkRate", 100),
                deepDefRate = number_value(class, "DeepDefRate", 100),
                targetKills = number_value(class, "TargetKills", 0),
                aliveCap = number_value(class, "AliveCap", 0),
                exterminationPacks = number_value(class, "ExterminationPacks", 0),
                defenseWaves = number_value(class, "DefenseWaves", 0),
                sealChests = number_value(class, "SealChests", 0),
                sealAmbientPacks = number_value(class, "SealAmbientPacks", 0),
                dropScale = number_value(class, "DropScale", 1),
                -- 클리어 메인 보상 희귀 그룹 보너스(raw, 10 = +1%p). 방어 상자 상위 등급 보너스와 같은 단위.
                clearRareBonusRaw = number_value(class, "ClearRareBonusRaw", 0),
            }
            result.byName[difficulty] = profile
            result.deepRates[difficulty] = {
                hpRate = profile.deepHpRate,
                atkRate = profile.deepAtkRate,
                defRate = profile.deepDefRate,
            }
            result.dropScale[difficulty] = profile.dropScale
            result.clearRareBonusRaw[difficulty] = profile.clearRareBonusRaw
            result.monsterLevelAdd[difficulty] = profile.monsterLevelAdd
            result.ranks[difficulty] = profile.difficultyRank
            if profile.isPortalDifficulty then
                result.portalProfiles[difficulty] = { DEFAULT = {
                    label = profile.label,
                    levelAdd = profile.levelAdd,
                    hpPct = profile.hpPct,
                    atkPct = profile.atkPct,
                    defPct = profile.defPct,
                } }
                result.streamProfiles[difficulty] = {
                    targetKills = profile.targetKills,
                    aliveCap = profile.aliveCap,
                    exterminationPacks = profile.exterminationPacks,
                    defenseWaves = profile.defenseWaves,
                    sealChests = profile.sealChests,
                    sealAmbientPacks = profile.sealAmbientPacks,
                }
            end
        end
    end
    handlers.MODE_STAT = function(class)
        local mode = text_value(class, "Mode", "None")
        if mode ~= "None" then
            result.modeStatRates[mode] = {
                hpPct = number_value(class, "HpPct", 0),
                atkPct = number_value(class, "AtkPct", 0),
                defPct = number_value(class, "DefPct", 0),
            }
        end
    end
    handlers.THREAT_SCALE = function(class)
        local threatGrade = text_value(class, "ThreatGrade", "None")
        if threatGrade ~= "None" then
            result.threatDropScale[threatGrade] =
                number_value(class, "DropScale", 1)
        end
    end
    handlers.MISSION_REWARD = function(class)
        local mode = text_value(class, "Mode", "None")
        local reader = rewardReaders[mode]
        if reader ~= nil then
            result.missionRewards[mode] = reader(class)
        end
    end
    handlers.PACK_GLOBAL = function(class)
        for _, rawBand in ipairs(parse_list(
                text_value(class, "AnchorRangeBands", "None"))) do
            local values = parse_csv(rawBand)
            result.packAnchorRangeBands[#result.packAnchorRangeBands + 1] = {
                minRange = tonumber(values[1]) or 0,
                maxRange = tonumber(values[2]) or 0,
                retry = tonumber(values[3]) or 0,
            }
        end
    end
    handlers.PACK_TEMPLATE = function(class)
        local templateKey = text_value(class, "TemplateKey", "None")
        if templateKey == "None" then
            return
        end
        local template = {
            key = templateKey,
            entries = parse_spawn_template_entries(
                text_value(class, "Entries", "None")),
        }
        result.packTemplates[templateKey] = template
    end
    handlers.PACK_PLAN = function(class)
        local planKey = text_value(class, "PlanKey", "None")
        if planKey == "None" then
            return
        end
        local plan = {
            minPacks = number_value(class, "MinPacks", 0),
            maxPacks = number_value(class, "MaxPacks", 0),
            forcedTemplates = parse_list(
                text_value(class, "ForcedTemplates", "None")),
            templates = {},
        }
        for _, rawTemplate in ipairs(parse_list(
                text_value(class, "Templates", "None"))) do
            local values = parse_csv(rawTemplate)
            plan.templates[#plan.templates + 1] = {
                key = values[1],
                weight = tonumber(values[2]) or 0,
            }
        end
        result.packSpawnPlans[planKey] = plan
        result.packAnchorSpreadRate[planKey] =
            number_value(class, "AnchorSpreadRate", 100)
        result.packEntrySpreadRate[planKey] =
            number_value(class, "EntrySpreadRate", 100)
    end
    handlers.EXCHANGE_RECIPE = function(class)
        local exchangeGroup = text_value(class, "ExchangeGroup", "None")
        local exchangeKey = text_value(class, "ExchangeKey", "None")
        local giveItem = text_value(class, "GiveItem", "None")
        local group = result.exchangeRecipes[exchangeGroup]
        if group == nil or exchangeKey == "None" or giveItem == "None" then
            return
        end

        local recipe = {
            group = exchangeGroup,
            key = exchangeKey,
            give = giveItem,
            count = number_value(class, "GiveCount", 1),
            account_property = text_value(class, "AccountProperty", "None"),
            shop_property = text_value(class, "ShopProperty", "None"),
            reset_interval = text_value(class, "ResetInterval", "None"),
            give_append_property = text_value(
                class, "GiveItemAppendProperty", "None"),
            give_append_value = number_value(
                class, "GiveItemAppendValue", 0),
            take = {},
        }
        for _, rawCost in ipairs(parse_list(
                text_value(class, "Costs", "None"))) do
            local values = parse_csv(rawCost)
            local itemClass = values[1]
            local count = tonumber(values[2]) or 0
            if itemClass ~= nil and itemClass ~= "" and count > 0 then
                recipe.take[#recipe.take + 1] = { itemClass, count }
            end
        end
        group[exchangeKey] = recipe
        result.exchangeRecipeList[#result.exchangeRecipeList + 1] = recipe
    end
    handlers.ADV_MONSTER_SPAWN = function(class)
        local monsterType = text_value(class, "MonsterType", "None")
        if monsterType == "None" then
            return
        end
        local minCount = math.max(0, number_value(class, "MinCount", 0))
        local maxCount = math.max(minCount,
            number_value(class, "MaxCount", minCount))
        result.advMonsterSpawn[monsterType] = {
            minCount = minCount,
            maxCount = maxCount,
        }
    end
    handlers.STREAM_TEMPLATE = function(class)
        local groupName = text_value(class, "TemplateGroup", "None")
        local templateKey = text_value(class, "TemplateKey", "None")
        if groupName == "None" or templateKey == "None" then
            return
        end

        local template = { key = templateKey }
        local weight = tonumber(TryGetProp(class, "Weight", nil))
        if weight ~= nil then
            template.weight = weight
        end
        local entries = parse_spawn_template_entries(
            text_value(class, "Entries", "None"))
        if #entries > 0 then
            template.entries = entries
        end
        local labelMessageKey = text_value(class, "LabelMsg", "None")
        if labelMessageKey ~= "None" then
            template.label = localized_message(labelMessageKey)
        end

        if text_value(class, "Collection", "NO") == "YES" then
            local group = result.streamTemplates[groupName]
            if group == nil then
                group = {}
                result.streamTemplates[groupName] = group
            end
            group[#group + 1] = template
        else
            result.streamTemplates[groupName] = template
        end
    end
    handlers.HAZARD_GLOBAL = function(class)
        local hazard = result.hazard
        hazard.TOXIC_FIELD_PAD = text_value(class, "ToxicFieldPad", "None")
        hazard.MOLTEN_FIELD_PAD = text_value(class, "MoltenFieldPad", "None")
        hazard.MOLTEN_EXPLOSION_PAD = text_value(class, "MoltenExplosionPad", "None")
        hazard.MOLTEN_MISSILE_EFFECT = text_value(class, "MoltenMissileEffect", "None")
        hazard.THUNDERCALL_PAD = text_value(class, "ThundercallPad", "None")
        hazard.ARCANE_BEAM_PAD = text_value(class, "ArcaneBeamPad", "None")
        hazard.ARCANE_BEAM_SKILL = text_value(class, "ArcaneBeamSkill", "None")
        hazard.THUNDERCALL_WARNING_MS = number_value(class, "ThundercallWarningMs", 0)
        hazard.THUNDERCALL_WARNING_RANGE = number_value(class, "ThundercallWarningRange", 0)
        hazard.MOLTEN_PERIODIC_TARGET_RANGE = number_value(class, "MoltenPeriodicTargetRange", 0)
        hazard.ARCANE_BEAM_LINE_MIN_RATE = number_value(class, "ArcaneBeamLineMinRate", 0)
        hazard.ARCANE_BEAM_LINE_MAX_RATE = number_value(class, "ArcaneBeamLineMaxRate", 0)
        hazard.ARCANE_BEAM_LINE_SIDE_OFFSET = number_value(class, "ArcaneBeamLineSideOffset", 0)
        hazard.MOLTEN_STRIKE_WARNING_MS = number_value(class, "MoltenStrikeWarningMs", 0)
        hazard.MOLTEN_STRIKE_WARNING_RANGE = number_value(class, "MoltenStrikeWarningRange", 0)
        hazard.MOLTEN_STRIKE_MIN_RANGE = number_value(class, "MoltenStrikeMinRange", 0)
        hazard.MOLTEN_STRIKE_MAX_RANGE = number_value(class, "MoltenStrikeMaxRange", 0)
        hazard.MOLTEN_MISSILE_SCALE = number_value(class, "MoltenMissileScale", 1)
        hazard.MOLTEN_MISSILE_GRAVITY = number_value(class, "MoltenMissileGravity", 0)
        hazard.MOLTEN_MISSILE_SPEED = number_value(class, "MoltenMissileSpeed", 1)
        hazard.MOLTEN_MISSILE_MIN_FLY_TIME = number_value(class, "MoltenMissileMinFlyTime", 0)
        hazard.MOLTEN_MISSILE_DIST_PER_SEC = number_value(class, "MoltenMissileDistPerSec", 0)
        hazard.MOLTEN_PERIODIC_INTERVAL_MIN_MS = number_value(class, "MoltenPeriodicIntervalMinMs", 0)
        hazard.MOLTEN_PERIODIC_INTERVAL_MAX_MS = number_value(class, "MoltenPeriodicIntervalMaxMs", 0)
        hazard.MOLTEN_PERIODIC_RETRY_MS = number_value(class, "MoltenPeriodicRetryMs", 0)
    end
    handlers.HAZARD_TARGET_CAST = function(class)
        local castKey = text_value(class, "CastKey", "None")
        if castKey == "None" then
            return
        end
        local targetRange = number_value(class, "TargetRange", 0)
        result.hazard.targetCast[castKey] = {
            targetRange = targetRange,
            intervalMinMs = number_value(class, "IntervalMinMs", 0),
            intervalMaxMs = number_value(class, "IntervalMaxMs", 0),
            nextTimeProp = text_value(class, "NextTimeProp", "None"),
            scriptName = text_value(class, "ScriptName", "None"),
        }
        if castKey == "THUNDER" then
            result.hazard.THUNDERCALL_MAX_RANGE = targetRange
        elseif castKey == "ARCANE" then
            result.hazard.ARCANE_BEAM_TARGET_MAX_RANGE = targetRange
        end
    end
    handlers.HAZARD_BUFF = function(class)
        result.hazard.toxicTrailDistance =
            number_value(class, "ToxicTrailDistance", 0)
        result.hazard.toxicTrailIntervalMs =
            number_value(class, "ToxicTrailIntervalMs", 0)
        result.hazard.targetCastRetryMs =
            number_value(class, "TargetCastRetryMs", 0)
    end
    handlers.NEBULAS_GLOBAL = function(class)
        result.nebulas.baseAtk = number_value(class, "BaseAtk", 0)
        result.nebulas.baseDef = number_value(class, "BaseDef", 0)
        result.nebulas.baseMhp = number_value(class, "BaseMhp", 0)
        result.nebulas.defaultProfile =
            text_value(class, "DefaultProfile", "HARD")
    end
    handlers.NEBULAS_STAT_PROFILE = function(class)
        local profileName = text_value(class, "ProfileName", "None")
        if profileName == "None" then
            return
        end
        result.nebulas.statProfiles[profileName] = {
            atkRate = number_value(class, "AtkRate", 1),
            defRate = number_value(class, "DefRate", 1),
            mhpRate = number_value(class, "MhpRate", 0),
        }
    end
    for_each_portal_rule(handlers)
    cache.portalRules = result
    return result
end

function rules.get_portal_difficulty(difficulty)
    return ensure_portal_rules().byName[difficulty]
end

function rules.get_portal_rules()
    return ensure_portal_rules()
end

function rules.get_exchange_recipe(exchangeGroup, exchangeKey)
    local group = ensure_portal_rules().exchangeRecipes[exchangeGroup]
    if group == nil then
        return nil
    end
    return group[exchangeKey]
end

-- XML 선언 순서를 유지한 교환 레시피 목록을 반환한다.
function rules.get_exchange_recipes(exchangeGroup)
    local recipes = ensure_portal_rules().exchangeRecipeList
    if exchangeGroup == nil or exchangeGroup == "" or
            exchangeGroup == "None" then
        return recipes
    end

    local filtered = {}
    for _, recipe in ipairs(recipes) do
        if recipe.group == exchangeGroup then
            filtered[#filtered + 1] = recipe
        end
    end
    return filtered
end

function rules.get_adv_monster_spawn_range(monsterType)
    local profile = ensure_portal_rules().advMonsterSpawn[monsterType]
    if profile == nil then
        return nil, nil
    end
    return profile.minCount, profile.maxCount
end

function rules.get_hazard_rules()
    return ensure_portal_rules().hazard
end

function rules.get_nebulas_rules()
    return ensure_portal_rules().nebulas
end

local function ensure_monster_levels()
    if cache.monsterLevels ~= nil then
        return cache.monsterLevels
    end

    local result = {}
    local function get_policy(class)
        local policyName = text_value(class, "Policy", "None")
        if policyName == "None" then
            return nil
        end
        local profile = result[policyName]
        if profile == nil then
            profile = { levelAddByMonsterType = {} }
            result[policyName] = profile
        end
        return profile
    end
    local handlers = {}
    handlers.MONSTER_LEVEL_POLICY = function(class)
        local profile = get_policy(class)
        if profile ~= nil then
            profile.baseLevel = number_value(class, "BaseLevel", 1)
            profile.maxLevel = number_value(class, "MaxLevel", profile.baseLevel)
        end
    end
    handlers.MONSTER_LEVEL_TYPE = function(class)
        local profile = get_policy(class)
        local monsterType = text_value(class, "MonsterType", "None")
        if profile ~= nil and monsterType ~= "None" then
            profile.levelAddByMonsterType[monsterType] =
                number_value(class, "LevelAdd", 0)
        end
    end
    for_each_portal_rule(handlers)
    cache.monsterLevels = result
    return result
end

function rules.get_monster_level(policyName, monsterType, extraLevelAdd)
    local profile = ensure_monster_levels()[policyName]
    if profile == nil or profile.baseLevel == nil or profile.maxLevel == nil then
        return nil
    end
    return math.min(profile.maxLevel, profile.baseLevel +
        (profile.levelAddByMonsterType[monsterType] or 0) +
        (tonumber(extraLevelAdd) or 0))
end

local function ensure_map_traits()
    if cache.mapTraits ~= nil then
        return cache.mapTraits
    end

    local result = {
        byType = {}, order = {}, defaultType = nil,
        rosterByTrait = {}, traitByMap = {}, maps = {}, regionsByMap = {},
    }
    local ordered = {}
    local handlers = {}
    handlers.TRAIT = function(class)
        local traitType = text_value(class, "TraitType", "None")
        if traitType ~= "None" then
            local profile = {
                traitType = traitType,
                sortOrder = number_value(class, "SortOrder", 999),
                exhibitSlotIndex = number_value(class, "ExhibitSlotIndex", 0),
                exhibitSlotNameMsg = text_value(class, "ExhibitSlotNameMsg", "None"),
                titleMsg = text_value(class, "TitleMsg", "None"),
                summaryMsg = text_value(class, "SummaryMsg", "None"),
                combatMsg = text_value(class, "CombatMsg", "None"),
                rewardMsg = text_value(class, "RewardMsg", "None"),
                color = text_value(class, "Color", "D7D0C4"),
                modeExtermination = number_value(class, "ModeExtermination", 34),
                modeDefense = number_value(class, "ModeDefense", 33),
                targetKillBonus = number_value(class, "TargetKillBonus", 0),
                exterminationPackBonus = number_value(class, "ExterminationPackBonus", 0),
                defenseWaveBonus = number_value(class, "DefenseWaveBonus", 0),
                aliveCapBonus = number_value(class, "AliveCapBonus", 0),
                riskScoreBonus = number_value(class, "RiskScoreBonus", 0),
                packChanceBonus = number_value(class, "PackChanceBonus", 0),
                fieldPackCountBonus = number_value(class, "FieldPackCountBonus", 0),
                fieldRiskScoreBonus = number_value(class, "FieldRiskScoreBonus", 0),
                fieldPackChanceBonus = number_value(class, "FieldPackChanceBonus", 0),
                templateBias = text_value(class, "TemplateBias", "None"),
                templateBiasChance = number_value(class, "TemplateBiasChance", 0),
                rareChanceBonus = number_value(class, "RareChanceBonus", 0),
                lowShardDropBonus = number_value(class, "LowShardDropBonus", 0),
                highShardDropBonus = number_value(class, "HighShardDropBonus", 0),
                memoryFragmentDropBonus = number_value(class, "MemoryFragmentDropBonus", 0),
                coinBonusPct = number_value(class, "CoinBonusPct", 0),
            }
            result.byType[traitType] = profile
            ordered[#ordered + 1] = profile
            if text_value(class, "IsDefault", "NO") == "YES" then
                result.defaultType = traitType
            end
        end
    end
    handlers.MONSTER = function(class)
        local traitType = text_value(class, "MapTrait", "None")
        local monsterClass = text_value(class, "MonsterClass", "None")
        if traitType ~= "None" and monsterClass ~= "None" then
            result.rosterByTrait[traitType] = result.rosterByTrait[traitType] or {}
            result.rosterByTrait[traitType][#result.rosterByTrait[traitType] + 1] = {
                className = monsterClass,
                grade = text_value(class, "Grade", "Normal"),
                stationary = text_value(class, "Stationary", "NO") == "YES",
                roles = parse_list(text_value(class, "Roles", "")),
            }
        end
    end
    for_each_rule("archeology_map_trait", handlers)
    table.sort(ordered, function(left, right)
        if left.sortOrder == right.sortOrder then
            return left.traitType < right.traitType
        end
        return left.sortOrder < right.sortOrder
    end)
    for _, profile in ipairs(ordered) do
        result.order[#result.order + 1] = profile.traitType
    end
    result.defaultType = result.defaultType or result.order[1]

    for_each_class("archeology_map_list", function(class)
        local mapName = text_value(class, "ClassName", "None")
        local traitType = text_value(class, "TraitType", "None")
        if mapName ~= "None" then
            result.maps[#result.maps + 1] = mapName
            result.regionsByMap[mapName] = {
                text_value(class, "Region", "All"),
            }
            if result.byType[traitType] ~= nil then
                result.traitByMap[mapName] = traitType
            end
        end
    end)
    cache.mapTraits = result
    return result
end

function rules.get_map_trait(traitType)
    return ensure_map_traits().byType[traitType]
end

function rules.get_map_trait_order()
    return ensure_map_traits().order
end

function rules.get_default_map_trait()
    return ensure_map_traits().defaultType
end

function rules.get_map_trait_by_map(mapName)
    local data = ensure_map_traits()
    local traitType = data.traitByMap[mapName] or data.defaultType
    return traitType, data.byType[traitType]
end

function rules.get_map_trait_rosters()
    return ensure_map_traits().rosterByTrait
end

function rules.get_map_list()
    return ensure_map_traits().maps
end

function rules.get_map_regions()
    return ensure_map_traits().regionsByMap
end

local function ensure_spawn_roles()
    if cache.spawnRoles ~= nil then
        return cache.spawnRoles
    end

    local result = {}
    for_each_portal_rule({ SPAWN_ROLE_RANGE = function(class)
        local role = text_value(class, "Role", "None")
        if role ~= "None" then
            result[role] = {
                baseMinRange = number_value(class, "BaseMinRange", 1),
                baseMaxRange = number_value(class, "BaseMaxRange", 1),
                compactMinAdjust = number_value(class, "CompactMinAdjust", 0),
                compactMaxAdjust = number_value(class, "CompactMaxAdjust", 0),
                compactFallbackMinRange =
                    number_value(class, "CompactFallbackMinRange", 1),
                compactFallbackMaxRange =
                    number_value(class, "CompactFallbackMaxRange", 1),
            }
        end
    end })
    cache.spawnRoles = result
    return result
end

local function get_spawn_role(role)
    local profiles = ensure_spawn_roles()
    return profiles[role] or profiles.Default
end

function rules.get_spawn_range(role, compact, requestedMin, requestedMax)
    local profile = get_spawn_role(role)
    if profile == nil then
        return nil, nil
    end
    if compact ~= true then
        return profile.baseMinRange, profile.baseMaxRange
    end
    if requestedMin ~= nil and requestedMax ~= nil then
        local minRange = math.max(1, tonumber(requestedMin) or 1)
        local maxRange = math.max(minRange, tonumber(requestedMax) or minRange)
        minRange = math.max(1, minRange + profile.compactMinAdjust)
        maxRange = math.max(minRange, maxRange + profile.compactMaxAdjust)
        return minRange, maxRange
    end
    return profile.compactFallbackMinRange, profile.compactFallbackMaxRange
end

local function ensure_ecology()
    if cache.ecology ~= nil then
        return cache.ecology
    end

    local result = {
        prophecy = { byKey = {}, commonOrder = {}, linkOrder = {}, byMode = {} },
        recordTiers = {},
        recordMaxTier = 0,
        colony = { thresholds = {}, scales = {}, profiles = {}, maxStage = 0 },
        fissure = { profiles = {}, maxSite = 0 },
        settings = {
            global = {},
            greed = {},
            fissure = {},
            colony = {},
            record = {},
            rage = {},
            prophecy = {},
        },
    }
    local commonRows = {}
    local linkRows = {}
    local function append_wave_entry(profile, class)
        if profile ~= nil then
            profile.entries[#profile.entries + 1] = {
                order = number_value(class, "EntryOrder", 0),
                count = number_value(class, "Count", 0),
                monType = text_value(class, "MonsterType", "Normal"),
                classes = parse_list(text_value(class, "MonsterClasses", "")),
            }
        end
    end
    local function read_config(class, numericProps, textProps)
        local config = {}
        for _, propName in ipairs(numericProps or {}) do
            config[propName] = number_value(class, propName, 0)
        end
        for _, propName in ipairs(textProps or {}) do
            config[propName] = text_value(class, propName, "None")
        end
        return config
    end
    local handlers = {}
    local configSpecs = {
        ECOLOGY_GLOBAL = { section = "global",
            numeric = { "ObjectLifetimeSec" },
            text = { "CoinItem", "MemoryItem" } },
        ECOLOGY_GREED = { section = "greed", numeric = {
            "ActivationRate", "MissRate", "TriggerRange", "AnchorMinRange",
            "AnchorMaxRange", "ObjectiveSeparation", "FallbackMinRange",
            "FallbackMaxRange", "SiteGraceMs", "SitePulseMs", "RewardCount" } },
        ECOLOGY_FISSURE = { section = "fissure", numeric = {
            "ChainMinRange", "ChainMaxRange", "ChainFallbackMinRange",
            "ChainFallbackMaxRange", "EffectScale", "OpenDelayMs",
            "WaveDelayMs", "VisualPulseMs", "SpawnProtectionMs",
            "MonsterLifetimeMs" } },
        ECOLOGY_COLONY = { section = "colony", numeric = {
            "CoreLifetimeSec", "DialogRange", "InteractSec",
            "SpawnProtectionMs", "MonsterLifetimeMs", "RewardCount",
            "CoreMinRange", "CoreMaxRange", "ObjectiveSeparation" } },
        ECOLOGY_RECORD = { section = "record", numeric = {
            "MaxEvents", "WindowMs", "FinaleDelayMs", "SmokeLifetimeSec",
            "SpawnProtectionMs", "MonsterLifetimeMs" } },
        ECOLOGY_RAGE = { section = "rage", numeric = {
            "MaxEvents", "MaxStacks", "BonusTargetLimit", "StructureMinRange",
            "StructureMaxRange", "StructureFallbackMinRange",
            "StructureFallbackMaxRange", "ObjectiveSeparation", "HpPerStackPct",
            "AtkPerStackPct", "DefPerStackPct", "MaterialChancePerStack",
            "RelicChancePerStack" } },
        ECOLOGY_PROPHECY = { section = "prophecy", numeric = {
            "MaxProphecies", "ChainWindowMs", "ClosureClearRate",
            "ClosureDeathGraceMs", "BlockadeRemainLimit",
            "ExterminationActiveRange", "TickDiscontinuityMs" } },
    }
    for rowType, spec in pairs(configSpecs) do
        local configSpec = spec
        handlers[rowType] = function(class)
            result.settings[configSpec.section] = read_config(
                class, configSpec.numeric, configSpec.text)
        end
    end
    handlers.PROPHECY = function(class)
        local key = text_value(class, "ProphecyKey", "None")
        if key == "None" then
            return
        end
        result.prophecy.byKey[key] = {
            labelMsg = text_value(class, "LabelMsg", "None"),
            descriptionMsg = text_value(class, "DescriptionMsg", "None"),
            group = text_value(class, "Group", "NONE"),
            target = number_value(class, "Target", 1),
        }
        local commonOrder = number_value(class, "CommonOrder", 0)
        local linkOrder = number_value(class, "LinkOrder", 0)
        if commonOrder > 0 then
            commonRows[#commonRows + 1] = { key = key, order = commonOrder }
        end
        if linkOrder > 0 then
            linkRows[#linkRows + 1] = { key = key, order = linkOrder }
        end
        local mode = text_value(class, "Mode", "None")
        if mode ~= "None" then
            result.prophecy.byMode[mode] = key
        end
    end
    handlers.RECORD_TIER = function(class)
        local tier = number_value(class, "Tier", 0)
        if tier > 0 then
            result.recordMaxTier = math.max(result.recordMaxTier, tier)
            result.recordTiers[tier] = {
                minKills = number_value(class, "MinKills", 0),
                addCount = number_value(class, "AddCount", 0),
                hpBonus = number_value(class, "HpBonus", 0),
                atkBonus = number_value(class, "AtkBonus", 0),
                materialChance = number_value(class, "MaterialChance", 0),
                relicChance = number_value(class, "RelicChance", 0),
                memoryCount = number_value(class, "MemoryCount", 0),
                coinCount = number_value(class, "CoinCount", 0),
            }
        end
    end
    handlers.COLONY_STAGE = function(class)
        local stage = number_value(class, "Stage", -1)
        if stage < 0 then
            return
        end
        result.colony.maxStage = math.max(result.colony.maxStage, stage)
        result.colony.scales[stage] = number_value(class, "Scale", 1)
        if stage > 0 then
            result.colony.thresholds[stage] = number_value(class, "KillThreshold", 0)
            result.colony.profiles[stage] = {
                label = localized_message(text_value(class, "LabelMsg", "None")),
                hpBonus = number_value(class, "HpBonus", 0),
                atkBonus = number_value(class, "AtkBonus", 0),
                entries = {},
            }
        end
    end
    handlers.COLONY_WAVE = function(class)
        append_wave_entry(result.colony.profiles[number_value(class, "Stage", 0)], class)
    end
    handlers.FISSURE_SITE = function(class)
        local siteIndex = number_value(class, "SiteIndex", 0)
        if siteIndex > 0 then
            result.fissure.maxSite = math.max(result.fissure.maxSite, siteIndex)
            result.fissure.profiles[siteIndex] = {
                key = text_value(class, "ProfileKey", "None"),
                labelMsg = text_value(class, "LabelMsg", "None"),
                label = localized_message(text_value(class, "LabelMsg", "None")),
                waveTotal = number_value(class, "WaveTotal", 1),
                hpBonus = number_value(class, "HpBonus", 0),
                atkBonus = number_value(class, "AtkBonus", 0),
                entries = {},
            }
        end
    end
    handlers.FISSURE_WAVE = function(class)
        append_wave_entry(result.fissure.profiles[
            number_value(class, "SiteIndex", 0)], class)
    end
    for_each_rule("archeology_ecology", handlers)
    local function ordered_keys(rows)
        table.sort(rows, function(left, right)
            return left.order < right.order
        end)
        local keys = {}
        for _, row in ipairs(rows) do
            keys[#keys + 1] = row.key
        end
        return keys
    end
    result.prophecy.commonOrder = ordered_keys(commonRows)
    result.prophecy.linkOrder = ordered_keys(linkRows)
    result.settings.record.MaxTier = result.recordMaxTier
    for _, profile in pairs(result.colony.profiles) do
        table.sort(profile.entries, function(left, right)
            return left.order < right.order
        end)
    end
    for _, profile in pairs(result.fissure.profiles) do
        table.sort(profile.entries, function(left, right)
            return left.order < right.order
        end)
    end
    cache.ecology = result
    return result
end

function rules.get_prophecy_rules()
    return ensure_ecology().prophecy
end

function rules.get_record_tier_rules()
    return ensure_ecology().recordTiers
end

function rules.get_colony_rules()
    return ensure_ecology().colony
end

function rules.get_fissure_rules()
    return ensure_ecology().fissure
end

function rules.get_ecology_settings()
    return ensure_ecology().settings
end
