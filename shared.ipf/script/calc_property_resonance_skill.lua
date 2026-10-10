-- calc property resonance skill
function SCR_RESONANCE_POST_HIT(self, from, skill, ret)
    if IsBuffApplied(self, "Invincible") == "YES" then 
        ret.HitType = HIT_SHIELD
    end

    if IsBuffApplied(self, "Magic_Shield") == "YES" and skill.ClassType == "Magic" then
        ret.Damage = 0
        ret.ResultType = HITRESULT_NONE
        ret.KDPower = 0
        ret.HitType = HIT_SAFETY
        SetExProp(from, "CHECK_SKL_KD_PROP", 1)
        SkillTextEffect(nil, self, from, "SHOW_GUNGHO", nil)
    end
end

function SCR_RESONANCE_POST_SKILL(self, from, skill, ret, over)
    SCR_COMMON_POST_KILL(self, from, skill, ret, over)
end

function GET_RESONANCE_SKILL_REINFORCE_LEVEL(self, skill_name, fallback_level)
    if self == nil or skill_name == nil or skill_name == "" then
        return nil, nil
    end

    local acc_obj = nil
    if IsServerSection() == 0 then
        acc_obj = GetMyAccountObj()
    else
        acc_obj = GetAccountObj(self)
    end

    local cls = GetClassByStrProp("resonance_skill", "SkillClassName", skill_name)
    if cls == nil then
        return nil, nil
    end

    local level = tonumber(fallback_level) or 0
    local acc_prop_level = TryGetProp(cls, "AccPropLevel", "None")
    if acc_prop_level ~= nil and acc_prop_level ~= "" and acc_prop_level ~= "None" then
        local prop_list = StringSplit(acc_prop_level, "/")
        if prop_list ~= nil and #prop_list >= 2 then
            local prop_name = prop_list[1]
            local default_level = tonumber(prop_list[2]) or level

            level = default_level
            if acc_obj ~= nil and prop_name ~= nil and prop_name ~= "" and prop_name ~= "None" then
                level = tonumber(TryGetProp(acc_obj, prop_name, default_level)) or default_level
            end
        end
    end

    local max_level = tonumber(TryGetProp(cls, "MaxLevel", 0)) or 0
    if max_level > 0 then
        level = math.min(level, max_level)
    end
    level = math.max(0, level)
    return level, cls
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_Get_ResonanceSkillFactor(skill)
    local owner = GetSkillOwner(skill)
    if owner == nil then
        return 0
    end

    local skill_name = TryGetProp(skill, "ClassName", "None")
    local fallback_level = TryGetProp(skill, "Level", 1)
    local reinforce_level, resonance_cls = GET_RESONANCE_SKILL_REINFORCE_LEVEL(owner, skill_name, fallback_level)
    if reinforce_level == nil or resonance_cls == nil then
        return 0
    end
    reinforce_level = math.max(1, reinforce_level)

    local skill_factor = TryGetProp(skill, "SklFactor", 0)
    local skill_factor_by_level = TryGetProp(skill, "SklFactorByLevel", 0)
    local factor = SyncFloor(skill_factor * 10) * 0.1 + SyncFloor(skill_factor_by_level * 10) * 0.1 * (reinforce_level - 1)

    local reinforce_cls_name = TryGetProp(resonance_cls, "ReinforceClassName", "None")
    if reinforce_cls_name == nil or reinforce_cls_name == "" or reinforce_cls_name == "None" then
        return math.floor(factor)
    end

    local reinforce_cls = GetClass("resonance_reinforce", reinforce_cls_name)
    if reinforce_cls == nil then
        return math.floor(factor)
    end

    local growth_rate = TryGetProp(reinforce_cls, "SkillFactorGrowthRate", 0)
    local growth_start_level = TryGetProp(reinforce_cls, "SkillFactorGrowthStartLevel", 0)
    local growth_interval = TryGetProp(reinforce_cls, "SkillFactorGrowthInterval", 0)
    if growth_rate <= 0 or growth_start_level <= 0 or growth_interval <= 0 then
        return math.floor(factor)
    end

    if reinforce_level >= growth_start_level then
        local growth_count = math.floor((reinforce_level - growth_start_level) / growth_interval) + 1
        for i = 1, growth_count do
            factor = factor * growth_rate / 10000
        end
    end

    return math.floor(factor)
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_SKL_CoolDown_Resonance(skill)
    local value = TryGetProp(skill, "BasicCoolDown", 0)
    local skill_name = TryGetProp(skill, "ClassName", "None")
    if skill_name == "None" then
        return value
    end

    local cls = GetClassByStrProp("resonance_skill", "SkillClassName", skill_name)
    if cls == nil then
        return value
    end

    local reinforce_cls_name = TryGetProp(cls, "ReinforceClassName", "None")
    if reinforce_cls_name == "None" then
        return value
    end

    local reinforce_cls = GetClass("resonance_reinforce", reinforce_cls_name)
    if reinforce_cls == nil then
        return value
    end

    return tonumber(TryGetProp(reinforce_cls, "CoolDown_0", value)) or value
end

local function GET_BERSERKER_ZAWRA_CHFIRE_PILLAR_COUNT(skill, skill_level)
    local skill_name = TryGetProp(skill, "ClassName", "None")
    local cls = GetClassByStrProp("resonance_skill", "SkillClassName", skill_name)
    if cls == nil then
        return 1
    end

    local add = 0
    local start_level = math.huge
    local interval = 1
    local max_count = math.huge
    local args = shared_resonance.get_reinforce_args(cls)
    for _, arg in ipairs(args) do
        if arg.arg_name == "Add" then
            add = math.max(0, tonumber(arg.arg_value) or 0)
        elseif arg.arg_name == "StartLevel" then
            start_level = tonumber(arg.arg_value) or math.huge
        elseif arg.arg_name == "Interval" then
            interval = math.max(1, tonumber(arg.arg_value) or 1)
        elseif arg.arg_name == "Max" then
            max_count = math.max(1, tonumber(arg.arg_value) or math.huge)
        end
    end

    skill_level = math.max(1, tonumber(skill_level) or 1)
    local pillar_count = 1
    if skill_level >= start_level then
        local growth_count = math.floor((skill_level - start_level) / interval) + 1
        pillar_count = pillar_count + add * growth_count
    end

    return math.min(math.max(1, pillar_count), max_count)
end

function SCR_GET_BerserkerZawra_ChFire_TotalFactor(skill)
    local value = 0
    local pc = GetSkillOwner(skill)
    if pc == nil then
        return value
    end

    local skill_name = TryGetProp(skill, "ClassName", "None")
    if skill_name == "None" then
        return value
    end

    local fallback_level = TryGetProp(skill, "Level", 1)
    local acc_level, cls = GET_RESONANCE_SKILL_REINFORCE_LEVEL(pc, skill_name, fallback_level)
    if acc_level == nil or cls == nil then
        return value
    end
    acc_level = math.max(1, acc_level)

    local skill_factor = tonumber(TryGetProp(skill, "SkillFactor", 0)) or 0
    if skill_factor <= 0 then
        skill_factor = SCR_Get_ResonanceSkillFactor(skill)
    end

    local hit_count = tonumber(TryGetProp(skill, "SklHitCount", 0)) or 0
    local pillar_count = GET_BERSERKER_ZAWRA_CHFIRE_PILLAR_COUNT(skill, acc_level)
    value = math.floor(skill_factor * hit_count * pillar_count)
    
    return value
end

function SCR_GET_BerserkerZawra_ChFire_CaptionRatio(skill)
    return SCR_GET_BerserkerZawra_ChFire_TotalFactor(skill)
end

function SCR_GET_BerserkerZawra_ChFire_CaptionRatio2(skill)
    local pc = GetSkillOwner(skill)
    if pc == nil then
        return 1
    end

    local skill_name = TryGetProp(skill, "ClassName", "None")
    local fallback_level = TryGetProp(skill, "Level", 1)
    local level = GET_RESONANCE_SKILL_REINFORCE_LEVEL(pc, skill_name, fallback_level)
    if level == nil then
        return 1
    end
    level = math.max(1, level)
    return GET_BERSERKER_ZAWRA_CHFIRE_PILLAR_COUNT(skill, level)
end

function SCR_GET_BerserkerZawra_ChFire_CaptionRatio3(skill)
    local skill_factor = tonumber(TryGetProp(skill, "SkillFactor", 0)) or 0
    if skill_factor > 0 then
        return math.floor(skill_factor)
    end

    local pillar_count = SCR_GET_BerserkerZawra_ChFire_CaptionRatio2(skill)
    local hit_count = tonumber(TryGetProp(skill, "SklHitCount", 0)) or 0
    if pillar_count <= 0 or hit_count <= 0 then
        return 0
    end

    return math.floor(SCR_GET_BerserkerZawra_ChFire_TotalFactor(skill) / (pillar_count * hit_count))
end
