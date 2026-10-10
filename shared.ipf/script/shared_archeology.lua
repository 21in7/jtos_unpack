-- shared_archeology.lua

shared_archeology = {}
local _archeology_map_list = nil
local _archeology_region_list = nil  -- { map_name : { region } }
max_archeology_storage_map_count = 3
max_archeology_storage_point = 4
max_archeology_map_count = 3
max_archeology_point = 4
local _max_archeology_try_count = 70

function shared_archeology.distance_sq_2d(x1, z1, x2, z2)
    local dx = (tonumber(x2) or 0) - (tonumber(x1) or 0)
    local dz = (tonumber(z2) or 0) - (tonumber(z1) or 0)
    return dx * dx + dz * dz
end

function shared_archeology.distance_2d(x1, z1, x2, z2)
    return math.sqrt(shared_archeology.distance_sq_2d(x1, z1, x2, z2))
end

local ARCHEOLOGY_SURVEY_DISTANCE_MESSAGES = {
    { minDistance = 5000, messageKey = "ArcheologyRelicTooFarAway" },
    { minDistance = 3000, messageKey = "ArcheologyRelicVeryFarAway" },
    { minDistance = 1500, messageKey = "ArcheologyRelicFarAway" },
    { minDistance = 800, messageKey = "ArcheologyRelicSlightlyFarAway" },
    { minDistance = 400, messageKey = "ArcheologyRelicNear" },
    { minDistance = 250, messageKey = "ArcheologyRelicVeryClose" },
    { minDistance = 0, messageKey = "ArcheologyRelicImmediate" },
}

function shared_archeology.get_survey_distance_message_key(distance)
    distance = math.max(0, tonumber(distance) or 0)
    for _, entry in ipairs(ARCHEOLOGY_SURVEY_DISTANCE_MESSAGES) do
        if distance >= entry.minDistance then
            return entry.messageKey
        end
    end
    return "ArcheologyRelicImmediate"
end

function shared_archeology.get_option_stat_rule(stat)
    return ARCHEOLOGY_RULES.get_option_rule(stat)
end

function shared_archeology.get_exhibition_effect_scale_rate(exhibitionLevel)
    return ARCHEOLOGY_RULES.get_exhibition_scale_rate(exhibitionLevel)
end

function shared_archeology.get_drop_item_reward_kind(itemClass)
    return ARCHEOLOGY_RULES.get_drop_item_reward_kind(itemClass)
end

function shared_archeology.get_drop_item_direct_gate_chance(itemClass, difficulty)
    return ARCHEOLOGY_RULES.get_direct_drop_gate_chance(itemClass, difficulty)
end

function shared_archeology.get_monster_level(policyName, monsterType, extraLevelAdd)
    return ARCHEOLOGY_RULES.get_monster_level(
        policyName, monsterType, extraLevelAdd)
end

function shared_archeology.get_adv_monster_spawn_range(monsterType)
    return ARCHEOLOGY_RULES.get_adv_monster_spawn_range(monsterType)
end

function shared_archeology.legacy_weight_bonus_to_percentage_point(rawBonus)
    return math.max(0, tonumber(rawBonus) or 0) * 0.1
end

function shared_archeology.probability_percent_to_threshold(chancePercent)
    chancePercent = math.max(0, math.min(100, tonumber(chancePercent) or 0))
    return math.floor(chancePercent * 100 + 0.0001)
end

function shared_archeology.roll_probability_percent(chancePercent)
    return IMCRandom(1, 10000) <=
        shared_archeology.probability_percent_to_threshold(chancePercent)
end

function shared_archeology.roll_probability_percent_with_value(chancePercent)
    local roll = IMCRandom(1, 10000)
    return roll <= shared_archeology.probability_percent_to_threshold(chancePercent),
        roll / 100
end

function shared_archeology.calculate_adjusted_group_probability(
        targetWeight, otherWeight, bonusPoint)
    targetWeight = math.max(0, tonumber(targetWeight) or 0)
    otherWeight = math.max(0, tonumber(otherWeight) or 0)
    if targetWeight <= 0 then
        return 0
    end

    local totalWeight = targetWeight + otherWeight
    if totalWeight <= 0 then
        return 0
    end

    return math.min(100, targetWeight * 100 / totalWeight +
        math.max(0, tonumber(bonusPoint) or 0))
end

function shared_archeology.apply_percent_bonus_count(baseCount, bonusPercent)
    baseCount = math.max(0, tonumber(baseCount) or 0)
    bonusPercent = math.max(0, tonumber(bonusPercent) or 0)
    local exactBonus = baseCount * bonusPercent * 0.01
    local guaranteedBonus = math.floor(exactBonus)
    local remainderPercent = (exactBonus - guaranteedBonus) * 100
    if shared_archeology.roll_probability_percent(remainderPercent) then
        guaranteedBonus = guaranteedBonus + 1
    end
    return baseCount + guaranteedBonus
end

local ARCHEOLOGY_PORTAL_REWARD_RULE = {
    CURRENT_CONTRACT_REWARD = "CURRENT_CONTRACT_REWARD",
    BASIC_AND_PERFORMANCE_REWARD = "BASIC_AND_PERFORMANCE_REWARD",
}
local function clamp_portal_percent(value)
    return math.max(0, math.min(100, tonumber(value) or 0))
end

local function apply_portal_stat_rate(basePct, rate)
    basePct = tonumber(basePct) or 0
    rate = math.max(100, tonumber(rate) or 100)
    return math.max(0, math.floor((((100 + basePct) * rate) / 100) - 100 + 0.5))
end

-- Scale the complete EASY stat (including mode/deep bonuses), so every
-- mode keeps the same difficulty ratios. Round deep bonuses before scaling
-- to retain the former HARD stats as the new EASY baseline.
function shared_archeology.scale_portal_monster_stat(profilePct, easyPct, modePct, deepRate)
    profilePct = tonumber(profilePct) or 0
    easyPct = tonumber(easyPct) or 0
    modePct = tonumber(modePct) or 0
    local baselinePct = easyPct + modePct
    if (tonumber(deepRate) or 100) > 100 then
        baselinePct = apply_portal_stat_rate(baselinePct, deepRate)
    end
    local difficultyRate = (100 + profilePct) / (100 + easyPct)
    return math.max(0, (100 + baselinePct) * difficultyRate - 100)
end

function shared_archeology.get_portal_monster_level_add(difficulty)
    local profile = ARCHEOLOGY_RULES.get_portal_difficulty(difficulty)
    return profile ~= nil and profile.monsterLevelAdd or 0
end

function shared_archeology.get_portal_difficulty_rank(difficulty)
    local portalRules = ARCHEOLOGY_RULES.get_portal_rules()
    local profile = ARCHEOLOGY_RULES.get_portal_difficulty(difficulty) or
        ARCHEOLOGY_RULES.get_portal_difficulty(portalRules.global.defaultDifficulty)
    return profile ~= nil and profile.difficultyRank or 1
end

function shared_archeology.get_shard_jackpot_multiplier()
    return ARCHEOLOGY_RULES.get_drop_policy().shardJackpotMultiplier or 1
end

function shared_archeology.get_portal_modifier_profiles()
    return ARCHEOLOGY_RULES.get_portal_modifiers()
end

function shared_archeology.normalize_portal_modifier_item(itemName)
    return ARCHEOLOGY_RULES.normalize_portal_modifier_item(itemName)
end

function shared_archeology.get_portal_reward_rules()
    return ARCHEOLOGY_PORTAL_REWARD_RULE
end

function shared_archeology.get_portal_record_reward_profiles()
    return ARCHEOLOGY_RULES.get_portal_record_rewards()
end

function shared_archeology.get_portal_record_reward_profile(itemName)
    local canonicalName = shared_archeology.normalize_portal_modifier_item(itemName)
    if canonicalName == nil then
        return nil
    end
    return ARCHEOLOGY_RULES.get_portal_record_reward(canonicalName)
end

function shared_archeology.build_portal_modifier_contract(itemNames)
    return ARCHEOLOGY_RULES.build_portal_modifier_contract(itemNames)
end

function shared_archeology.get_portal_reward_group_weights(lv, region, exhibitionLevel)
    return ARCHEOLOGY_RULES.get_reward_group_weights(lv, region, exhibitionLevel)
end

-- 보상표(archeology_reward_list) 희귀 그룹 확률. 발굴·클리어 보상 추첨과 입장 창 미리보기가
-- 같이 쓴다. 기본 비율 = max(현재 등급 비율, 이전 등급 최고 비율) 이라 제단 등급이 올라도
-- 떨어지지 않고, 등급 보너스(bonusPoint 에 포함)만큼 오른다. 희귀 풀이 없으면 0.
function shared_archeology.calculate_reward_rare_probability(lv, region, exhibitionLevel,
        rareWeight, normalWeight, bonusPoint)
    rareWeight = math.max(0, tonumber(rareWeight) or 0)
    normalWeight = math.max(0, tonumber(normalWeight) or 0)
    if rareWeight <= 0 then
        return 0
    end
    local share = rareWeight * 100 / (rareWeight + normalWeight)
    share = math.max(share,
        ARCHEOLOGY_RULES.get_reward_rare_share_floor(lv, region, exhibitionLevel))
    return math.min(100, share + math.max(0, tonumber(bonusPoint) or 0))
end

-- 전시 5 주화·편린(BonusWeight 행)은 메인·추가 일반 보상 풀에 넣지 않아 유물 확률을
-- 희석하지 않는다. 대신 추첨 결과가 잡화(Common)일 때 BonusWeight / (잡화 가중치 +
-- BonusWeight) 확률로 그 결과를 주화·편린으로 바꾼다. 한 번 발굴에서 받는 보상 개수는
-- 그대로이므로 보상 총량이 늘지 않는다.
function shared_archeology.get_exhibition_bonus_rewards(lv, region,
        exhibitionLevel, rareBonusRaw, extraNormalBonusRaw)
    exhibitionLevel = tonumber(exhibitionLevel) or 1
    local result = { entries = {}, totalWeight = 0, commonWeight = 0,
        replaceChance = 0, commonItems = {} }
    local rareWeight, normalWeight = 0, 0
    for _, reward in ipairs(ARCHEOLOGY_RULES.get_reward_entries(lv, region)) do
        if exhibitionLevel >= reward.minExhibitionLevel and
                exhibitionLevel <= reward.maxExhibitionLevel then
            local weight = math.max(0, tonumber(reward.weight) or 0)
            if reward.rarity ~= "Normal" and reward.rarity ~= "Common" then
                rareWeight = rareWeight + weight
            else
                normalWeight = normalWeight + weight
            end
            if reward.rarity == "Common" and weight > 0 then
                result.commonWeight = result.commonWeight + weight
                result.commonItems[reward.itemClass] = true
            end
            local bonusWeight = math.max(0, tonumber(reward.bonusWeight) or 0)
            if bonusWeight > 0 then
                result.entries[#result.entries + 1] = {
                    itemClass = reward.itemClass, weight = bonusWeight,
                    minCount = reward.minCount, maxCount = reward.maxCount,
                }
                result.totalWeight = result.totalWeight + bonusWeight
            end
        end
    end
    if result.totalWeight <= 0 or result.commonWeight <= 0 or normalWeight <= 0 then
        result.totalWeight = 0
        return result
    end
    result.replaceChance = 100 * result.totalWeight /
        (result.commonWeight + result.totalWeight)

    -- 아래는 입장 창 미리보기용 기대 확률이다(RollArcheologyReward 와 같은 그룹 확률 모델).
    local policy = ARCHEOLOGY_RULES.get_drop_policy()
    local exhibitRareRaw = math.min(policy.exhibitRareBonusCap or 0,
        math.max(0, exhibitionLevel - 1) *
        (policy.exhibitRareBonusPerLevel or 0))
    local exhibitNormalRaw = math.min(policy.exhibitNormalBonusCap or 0,
        math.floor(math.max(0, exhibitionLevel - 1) /
        math.max(1, policy.exhibitNormalBonusLevelDivisor or 1)))
    local rareChance = shared_archeology.calculate_reward_rare_probability(
        lv, region, exhibitionLevel, rareWeight, normalWeight,
        shared_archeology.legacy_weight_bonus_to_percentage_point(
            (tonumber(rareBonusRaw) or 0) + exhibitRareRaw))
    local extraNormal = math.min(100,
        shared_archeology.legacy_weight_bonus_to_percentage_point(
            (tonumber(extraNormalBonusRaw) or 0) + exhibitNormalRaw))
    local commonShare = result.commonWeight / normalWeight
    local mainCommonChance = (100 - rareChance) * commonShare
    local extraCommonChance = extraNormal * commonShare
    for _, entry in ipairs(result.entries) do
        local share = entry.weight / (result.commonWeight + result.totalWeight)
        entry.mainChance = mainCommonChance * share
        entry.extraChance = extraCommonChance * share
        entry.chance = entry.mainChance + entry.extraChance -
            entry.mainChance * entry.extraChance / 100
        result[entry.itemClass] = entry
    end
    return result
end

-- 잡화 결과를 전시 5 주화·편린으로 바꿀지 굴린다. 바꾸지 않으면 입력을 그대로 돌려준다.
function shared_archeology.replace_with_exhibition_bonus(pool, itemClass, count)
    if pool == nil or pool.totalWeight <= 0 or itemClass == nil or
            pool.commonItems[itemClass] ~= true or
            shared_archeology.roll_probability_percent(pool.replaceChance) ~= true then
        return itemClass, count
    end
    local selected = IMCRandom(1, pool.totalWeight)
    local cumulative = 0
    for _, entry in ipairs(pool.entries) do
        cumulative = cumulative + entry.weight
        if selected <= cumulative then
            return entry.itemClass, IMCRandom(entry.minCount, entry.maxCount)
        end
    end
    return itemClass, count
end

function shared_archeology.build_portal_mission_preview(diff, deepMode, mapTrait,
        exterminationMissCount)
    local portalRules = ARCHEOLOGY_RULES.get_portal_rules()
    local defaultDifficulty = portalRules.global.defaultDifficulty
    local stream = portalRules.streamProfiles[diff] or
        portalRules.streamProfiles[defaultDifficulty]
    local trait = shared_archeology.get_map_trait_profile(mapTrait) or {}
    local isDeep = deepMode == true or tonumber(deepMode) == 1
    local missCount = math.max(0, tonumber(exterminationMissCount) or 0)
    local exterminationWeight = tonumber(trait.modeExtermination) or 34
    local defenseWeight = tonumber(trait.modeDefense) or 33
    local sealWeight = math.max(0, 100 - exterminationWeight - defenseWeight)
    if missCount >= 2 then
        exterminationWeight = 100
        defenseWeight = 0
        sealWeight = 0
    end

    local exterminationReward = portalRules.missionRewards.EXTERMINATION
    local defenseReward = portalRules.missionRewards.DEFENSE
    local sealReward = portalRules.missionRewards.REINFORCEMENT
    local defenseHigherRaw = defenseReward.higherTierBonusRaw[diff] or
        defenseReward.higherTierBonusRaw[defaultDifficulty]
    if isDeep then
        defenseHigherRaw = defenseHigherRaw + defenseReward.deepHigherTierBonusRaw
    end

    return {
        exterminationWeight = exterminationWeight,
        defenseWeight = defenseWeight,
        sealWeight = sealWeight,
        exterminationPity = missCount >= 2,
        targetKills = math.max(25, (stream.targetKills or 45) +
            (isDeep and 20 or 0) + (tonumber(trait.targetKillBonus) or 0)),
        aliveCap = math.max(1, (stream.aliveCap or 16) +
            (isDeep and 4 or 0) + (tonumber(trait.aliveCapBonus) or 0)),
        exterminationPacks = math.max(2, (stream.exterminationPacks or 4) +
            (isDeep and 1 or 0) + (tonumber(trait.exterminationPackBonus) or 0)),
        defenseWaves = math.max(2, (stream.defenseWaves or 4) +
            (isDeep and 1 or 0) + (tonumber(trait.defenseWaveBonus) or 0)),
        sealChests = math.min(5, (stream.sealChests or 3) + (isDeep and 1 or 0)),
        modeCombat = portalRules.modeStatRates,
        exterminationReward = {
            coinMin = exterminationReward.coinMin,
            coinMax = exterminationReward.coinMax,
            lowShardCount = exterminationReward.lowShardCount,
            highShardChance = clamp_portal_percent(exterminationReward.highShardChance +
                (tonumber(trait.highShardDropBonus) or 0)),
            relicChance = isDeep and exterminationReward.deepRelicChance or
                exterminationReward.relicChance,
            quickCoinBonusPct = math.max(0,
                (tonumber(exterminationReward.quickCoinRate) or 100) - 100),
            quickLowShardCount = exterminationReward.quickLowShardCount,
            quickRelicBonus = exterminationReward.quickRelicBonus,
        },
        defenseReward = {
            chestRewardCount = defenseReward.chestRewardCount,
            guaranteedHighShardCount = defenseReward.guaranteedHighShardCount,
            higherTierBonusPoint = shared_archeology.legacy_weight_bonus_to_percentage_point(
                defenseHigherRaw + (tonumber(trait.rareChanceBonus) or 0)),
        },
        sealReward = {
            chestCoinMin = sealReward.chestCoinMin +
                (isDeep and sealReward.deepChestCoinAdd or 0),
            chestCoinMax = sealReward.chestCoinMax +
                (isDeep and sealReward.deepChestCoinAdd or 0),
        },
    }
end

function shared_archeology.build_portal_entry_preview(params)
    params = params or {}
    local portalRules = ARCHEOLOGY_RULES.get_portal_rules()
    local dropPolicy = ARCHEOLOGY_RULES.get_drop_policy()
    local relicSlot = ARCHEOLOGY_RULES.get_drop_slot("Relic")
    local defaultDifficulty = portalRules.global.defaultDifficulty
    local diff = params.difficulty or defaultDifficulty
    local exhibitionLevel = tonumber(params.exhibitionLevel) or 1
    local options = params.options or {}
    local trait = shared_archeology.get_map_trait_profile(params.mapTrait) or {}
    local modifier = shared_archeology.build_portal_modifier_contract(
        params.modifierItems or {})
    local isDeep = params.deepMode == true or tonumber(params.deepMode) == 1
    local difficultyMap = portalRules.portalProfiles[diff] or
        portalRules.portalProfiles[defaultDifficulty]
    local difficulty = difficultyMap.DEFAULT
    local easy = portalRules.portalProfiles.EASY.DEFAULT
    local deepRate = isDeep and (portalRules.deepRates[diff] or
        portalRules.deepRates[defaultDifficulty]) or {}
    local combatHp = shared_archeology.scale_portal_monster_stat(
        difficulty.hpPct, easy.hpPct, 0, deepRate.hpRate)
    local combatAtk = shared_archeology.scale_portal_monster_stat(
        difficulty.atkPct, easy.atkPct, 0, deepRate.atkRate)
    local combatDef = shared_archeology.scale_portal_monster_stat(
        difficulty.defPct, easy.defPct, 0, deepRate.defRate)

    local rareWeight, normalWeight = shared_archeology.get_portal_reward_group_weights(
        params.missionLevel, params.region, exhibitionLevel)
    local exhibitionBonuses = shared_archeology.get_exhibition_bonus_rewards(
        params.missionLevel, params.region, exhibitionLevel,
        (tonumber(options.ARCHEOLOGY_RARE_CHANCE) or 0) +
        (tonumber(trait.rareChanceBonus) or 0) +
        (tonumber(modifier.rareChanceBonus) or 0) +
        (tonumber(portalRules.clearRareBonusRaw[diff]) or 0),
        tonumber(options.ARCHEOLOGY_COIN_GAIN) or 0)
    local baseRare = shared_archeology.calculate_reward_rare_probability(
        params.missionLevel, params.region, exhibitionLevel, rareWeight, normalWeight, 0)
    local optionRarePoint = shared_archeology.legacy_weight_bonus_to_percentage_point(
        options.ARCHEOLOGY_RARE_CHANCE)
    local exhibitionRareRaw = math.min(dropPolicy.exhibitRareBonusCap or 0,
        math.max(0, exhibitionLevel - 1) *
        (dropPolicy.exhibitRareBonusPerLevel or 0))
    local exhibitionRarePoint = shared_archeology.legacy_weight_bonus_to_percentage_point(
        exhibitionRareRaw)
    local traitRarePoint = shared_archeology.legacy_weight_bonus_to_percentage_point(
        trait.rareChanceBonus)
    local modifierRarePoint = shared_archeology.legacy_weight_bonus_to_percentage_point(
        modifier.rareChanceBonus)
    local difficultyRarePoint = shared_archeology.legacy_weight_bonus_to_percentage_point(
        portalRules.clearRareBonusRaw[diff])
    local finalRare = shared_archeology.calculate_reward_rare_probability(
        params.missionLevel, params.region, exhibitionLevel, rareWeight, normalWeight,
        optionRarePoint + exhibitionRarePoint + traitRarePoint + modifierRarePoint +
            difficultyRarePoint)

    local exhibitNormalRaw = math.min(dropPolicy.exhibitNormalBonusCap or 0,
        math.floor(math.max(0, exhibitionLevel - 1) /
        math.max(1, dropPolicy.exhibitNormalBonusLevelDivisor or 1)))
    local exhibitSlotBonus = math.min(dropPolicy.exhibitSlotBonusCap or 0,
        math.floor(math.max(0, exhibitionLevel - 1) /
        math.max(1, dropPolicy.exhibitSlotBonusLevelDivisor or 1)))
    local threatGrade = params.threatGrade or portalRules.global.defaultThreatGrade
    local dropScale = (portalRules.dropScale[diff] or 1) *
        (portalRules.threatDropScale[threatGrade] or 1)
    local relicBase = ((relicSlot ~= nil and
        relicSlot.chanceByMonsterType.Normal) or 0) * dropScale
    if isDeep then
        relicBase = relicBase * portalRules.global.deepModeDropRate
    end
    local relicOptionBonus = (tonumber(options.ARCHEOLOGY_MON_DROP_RATE) or 0) +
        exhibitSlotBonus + (tonumber(options.ARCHEOLOGY_RELIC_DROP_RATE) or 0)

    return {
        combat = {
            hpPct = combatHp, atkPct = combatAtk, defPct = combatDef,
            levelAdd = difficulty.levelAdd or 0,
            modifier = modifier,
        },
        mission = shared_archeology.build_portal_mission_preview(diff, isDeep,
            params.mapTrait, params.exterminationMissCount),
        clear = {
            poolAvailable = rareWeight + normalWeight > 0,
            rareWeight = rareWeight, normalWeight = normalWeight,
            exhibitionBonuses = exhibitionBonuses,
            baseRare = baseRare,
            optionRarePoint = optionRarePoint,
            exhibitionRarePoint = exhibitionRarePoint,
            traitRarePoint = traitRarePoint,
            modifierRarePoint = modifierRarePoint,
            difficultyRarePoint = difficultyRarePoint,
            finalRare = finalRare,
            extraNormalChance = shared_archeology.legacy_weight_bonus_to_percentage_point(
                (tonumber(options.ARCHEOLOGY_COIN_GAIN) or 0) + exhibitNormalRaw),
            criticalChance = clamp_portal_percent(options.ARCHEOLOGY_CRITICAL_CHANCE),
            coinBonusPct = math.max(0,
                (tonumber(options.ARCHEOLOGY_REWARD_COIN_GAIN) or 0) +
                (tonumber(trait.coinBonusPct) or 0) + modifier.coinBonusPct),
        },
        bonus = {
            guaranteedLowShard = 1,
            guaranteedFragment = modifier.fragBonus,
            lowShardBase = 0,
            lowShardOption = tonumber(options.ARCHEOLOGY_REWARD_LOW_SHARD_DROP) or 0,
            lowShardTrait = tonumber(trait.lowShardDropBonus) or 0,
            lowShardModifier = modifier.lowShardDropBonus,
            lowShardFinal = clamp_portal_percent(
                (tonumber(options.ARCHEOLOGY_REWARD_LOW_SHARD_DROP) or 0) +
                (tonumber(trait.lowShardDropBonus) or 0) + modifier.lowShardDropBonus),
            highShardBase = 10,
            highShardOption = tonumber(options.ARCHEOLOGY_REWARD_HIGH_SHARD_DROP) or 0,
            highShardTrait = tonumber(trait.highShardDropBonus) or 0,
            highShardModifier = modifier.highShardDropBonus,
            highShardFinal = clamp_portal_percent(10 +
                (tonumber(options.ARCHEOLOGY_REWARD_HIGH_SHARD_DROP) or 0) +
                (tonumber(trait.highShardDropBonus) or 0) + modifier.highShardDropBonus),
            memoryBase = 0,
            memoryOption = tonumber(options.ARCHEOLOGY_REWARD_MEMORY_FRAGMENT_DROP) or 0,
            memoryTrait = tonumber(trait.memoryFragmentDropBonus) or 0,
            memoryModifier = modifier.memoryFragmentDropBonus,
            memoryFinal = clamp_portal_percent(
                (tonumber(options.ARCHEOLOGY_REWARD_MEMORY_FRAGMENT_DROP) or 0) +
                (tonumber(trait.memoryFragmentDropBonus) or 0) +
                modifier.memoryFragmentDropBonus),
        },
        relic = {
            baseNormal = relicBase,
            optionBonus = relicOptionBonus,
            modifierBonus = modifier.relicDropRateBonus,
            finalNormal = clamp_portal_percent(relicBase + relicOptionBonus +
                modifier.relicDropRateBonus),
        },
        boss = {
            essenceCount = 1, highShardMin = 3, highShardMax = 5,
            coinMin = 18, coinMax = 28, baseChaosChance = 2,
            exhibitionHighShardBonus = params.bossExhibitionBonusUnlocked and 2 or 0,
            extraChaosChance = clamp_portal_percent(
                options.ARCHEOLOGY_REWARD_CHAOS_ORB_DROP),
            extraBossChance = clamp_portal_percent(
                options.ARCHEOLOGY_REWARD_BOSS_EXTRA),
            extraEssenceChance = clamp_portal_percent(
                options.ARCHEOLOGY_REWARD_BOSS_ESSENCE_EXTRA),
            extraHighShardChance = clamp_portal_percent(
                options.ARCHEOLOGY_REWARD_HIGH_SHARD_DROP),
        },
    }
end

function shared_archeology.get_base_profile(className)
    return ARCHEOLOGY_RULES.get_base_profile(className)
end

function shared_archeology.get_base_tier_profile(baseTier)
    return ARCHEOLOGY_RULES.get_base_tier(baseTier)
end

function shared_archeology.get_exhibition_rarity_profile(rarity)
    return ARCHEOLOGY_RULES.get_exhibition_rarity(rarity)
end

function shared_archeology.get_exhibition_item_profile(exCls)
    return ARCHEOLOGY_RULES.get_exhibition_item(exCls)
end

-- 보상표(archeology_reward_list.xml) Rarity 는 드롭 가중치 등급이라 _M 을 Rare, _R 을
-- Epic/Legendary 로 적는다. 화면에는 감정·전시와 같은 유물 실제 등급(Normal/Magic/Rare)을
-- 보여야 하므로, 유물이면 전시 등급을 돌려주고 아니면 받은 값을 그대로 쓴다.
local ARCHEOLOGY_RELIC_TABLE_RARITIES = {
    Common = true, Normal = true, Magic = true, Rare = true, Epic = true, Legendary = true,
}

function shared_archeology.get_relic_display_rarity(itemClassName, fallbackRarity)
    local profile = ARCHEOLOGY_RULES.get_exhibition_item(itemClassName)
    if profile ~= nil and profile.rarity ~= nil and profile.rarity ~= "None" then
        return profile.rarity
    end
    -- 상자 유물 풀에는 봉인된 기록 파편 같은 재료 행도 섞여 있다(보상표 Rarity 는 추첨 가중치
    -- 등급). 유물이 아닌 아이템은 등급 대신 「재료」로 표시한다. Fallback·Broken 같은 특수 표시는 유지.
    if ARCHEOLOGY_RELIC_TABLE_RARITIES[fallbackRarity] == true then
        return "Material"
    end
    return fallbackRarity
end

local function make_archeology_map_list()
    if _archeology_map_list ~= nil then
        return
    end

    _archeology_map_list = ARCHEOLOGY_RULES.get_map_list()
    _archeology_region_list = ARCHEOLOGY_RULES.get_map_regions()
end

shared_archeology.get_archeology_map_list = function()
    make_archeology_map_list()
    return _archeology_map_list
end
shared_archeology.get_archeology_region_list = function()
    make_archeology_map_list()
    return _archeology_region_list
end
shared_archeology.get_map_trait_order = function()
    return ARCHEOLOGY_RULES.get_map_trait_order()
end
shared_archeology.get_map_trait_profile = function(traitType)
    return ARCHEOLOGY_RULES.get_map_trait(traitType)
end
shared_archeology.get_default_map_trait = function()
    return ARCHEOLOGY_RULES.get_default_map_trait()
end
shared_archeology.get_map_trait_type = function(mapName)
    local traitType = ARCHEOLOGY_RULES.get_map_trait_by_map(mapName)
    return traitType
end
shared_archeology.get_map_trait_profile_by_map = function(mapName)
    return ARCHEOLOGY_RULES.get_map_trait_by_map(mapName)
end
shared_archeology.get_active_map_count_by_level = function(lv)
    if (tonumber(lv) or 0) >= 530 then
        return 1
    end
    return max_archeology_map_count
end
-- The new Lv.550 mission retains the stored Lv.530 key for existing data.
shared_archeology.is_normal_mission = function(acc)
    return tonumber(TryGetProp(acc, 'archeology_lv', 0)) == 470
end
shared_archeology.is_advanced_mission = function(acc)
    return (tonumber(TryGetProp(acc, 'archeology_lv', 0)) or 0) >= 530
end
shared_archeology.get_point_count = function(acc)
    if shared_archeology.is_normal_mission(acc) then
        return 3
    end
    return max_archeology_point
end
shared_archeology.get_active_map_count = function(acc)
    if acc == nil then
        return max_archeology_map_count
    end

    local lv = tonumber(TryGetProp(acc, "archeology_lv", 0)) or 0
    if lv < 530 then
        return max_archeology_map_count
    end

    -- 기존에 이미 발급된 Lv.530 3지역 의뢰는 완료할 수 있도록 보존한다.
    local map2 = TryGetProp(acc, "archeology_map_2", "None")
    local map3 = TryGetProp(acc, "archeology_map_3", "None")
    if map2 ~= "None" or map3 ~= "None" then
        return max_archeology_map_count
    end
    return 1
end
shared_archeology.get_max_archeology_try_count = function()
    return _max_archeology_try_count
end
shared_archeology.get_storage_map_count = function()
    return max_archeology_storage_map_count or max_archeology_map_count or 1
end
shared_archeology.get_storage_point_count = function()
    return max_archeology_storage_point or max_archeology_point or 4
end
-- 임무 비용
shared_archeology.get_cost = function(lv)
    if lv == 530 then
        return 'Archeology_Dig_Permit', 1
    end

    return nil
end
shared_archeology.get_reward_list = function(lv)
    return ARCHEOLOGY_RULES.get_reward_item_classes(lv)
end

shared_archeology.get_item_cost_by_cls = function(itemcls)
    local clsname = TryGetProp(itemcls, "ClassName", "None")
    local profile = ARCHEOLOGY_RULES.get_exhibition_item(clsname)
    return profile and profile.cost or 0
end

local function normalize_archeology_point_pos(x, y, z)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if x == nil or y == nil or z == nil or
            x ~= x or y ~= y or z ~= z or
            math.abs(x) == math.huge or math.abs(y) == math.huge or
            math.abs(z) == math.huge then
        return nil, nil, nil
    end
    return math.floor(x), math.floor(y), math.floor(z)
end

shared_archeology.get_point_pos_from_meta = function(pos_meta)
    if pos_meta == nil or pos_meta == "None" or pos_meta == "" then
        return nil, nil, nil
    end

    local token = StringSplit(pos_meta, ";")
    if token == nil or token[1] == nil then
        return nil, nil, nil
    end

    local pos = StringSplit(token[1], ",")
    if pos == nil or #pos < 3 then
        return nil, nil, nil
    end

    return normalize_archeology_point_pos(pos[1], pos[2], pos[3])
end

shared_archeology.get_previous_point_pos = function(acc, archeology_map_property, point_index)
    if acc == nil or point_index == nil or point_index <= 1 then
        return nil, nil, nil
    end

    for i = point_index - 1, 1, -1 do
        local prev_meta = TryGetProp(acc, archeology_map_property .. "_pos_" .. i, "None")
        local x, y, z = shared_archeology.get_point_pos_from_meta(prev_meta)
        if x ~= nil and y ~= nil and z ~= nil then
            return x, y, z
        end
    end

    return nil, nil, nil
end

shared_archeology.get_legacy_point_pos = function(pc)
    local base_x, base_y, base_z = normalize_archeology_point_pos(Get3DPos(pc))
    if base_x == nil then
        return nil, nil, nil
    end
    for i = 1, 5 do
        local x, y, z = normalize_archeology_point_pos(
            GetRandomPosInRange(pc, base_x, base_y, base_z, 1000, 10000))
        if x ~= nil and (base_x ~= x or base_y ~= y or base_z ~= z) then
            return x, y, z
        end
    end
    return nil, nil, nil
end

shared_archeology.get_clustered_point_pos = function(pc, acc, archeology_map_property, point_index)
    local base_x, base_y, base_z = shared_archeology.get_previous_point_pos(acc, archeology_map_property, point_index)
    local min_range = 450
    local max_range = 1800

    if base_x == nil or base_y == nil or base_z == nil then
        base_x, base_y, base_z = Get3DPos(pc)
        min_range = 500
        max_range = 3200
    end

    base_x, base_y, base_z = normalize_archeology_point_pos(base_x, base_y, base_z)
    if base_x == nil then
        return nil, nil, nil
    end

    for i = 1, 10 do
        local x, y, z = normalize_archeology_point_pos(
            GetRandomPosInRange(pc, base_x, base_y, base_z, min_range, max_range))
        if x ~= nil and shared_archeology.distance_sq_2d(
                base_x, base_z, x, z) >= min_range * min_range then
            return x, y, z
        end
    end

    local pc_x, pc_y, pc_z = normalize_archeology_point_pos(Get3DPos(pc))
    if pc_x == nil then
        return nil, nil, nil
    end
    for i = 1, 8 do
        local x, y, z = normalize_archeology_point_pos(
            GetRandomPosInRange(pc, pc_x, pc_y, pc_z, 500, 3200))
        if x ~= nil and shared_archeology.distance_sq_2d(
                pc_x, pc_z, x, z) >= 500 * 500 and
                shared_archeology.distance_sq_2d(
                    base_x, base_z, x, z) >= min_range * min_range then
            return x, y, z
        end
    end

    return nil, nil, nil
end
