-- shared_Sagitta.lua

function SCR_GET_SerratedBarb_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 5
    return GET_PVP_TARGET_COUNT(pc, count)
end

function SCR_GET_BreachingPoint_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 5
    return GET_PVP_TARGET_COUNT(pc, count)
end

function SCR_GET_CausticPoint_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 5
    return GET_PVP_TARGET_COUNT(pc, count)
end

function SCR_GET_Flechette_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 10
    return GET_PVP_TARGET_COUNT(pc, count)
end

function SCR_GET_IgnitionPierce_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 10
    return GET_PVP_TARGET_COUNT(pc, count)
end

function SCR_GET_OutbreakCap_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 15
    return GET_PVP_TARGET_COUNT(pc, count)
end

function SCR_SAGITTA_CHECK_USE_FLECHETTE_C(actor, skl)
    local buff = actor:GetBuff():GetBuff("FatalTempo_Buff")
    if buff ~= nil then
        return 1
    end

    return 0
end

function SCR_SAGITTA_CHECK_USE_OUTBREAKCAP_C(actor, skl)
    local buff = actor:GetBuff():GetBuff("DrawWeight_Max_Buff")
    if buff ~= nil then
        return 1
    end

    return 0
end

function SCR_Get_SkillFactor_BreachingPoint_Detonate(skill)
    local pc = GetSkillOwner(skill)
    local value = 0
    local bpSkill = GetSkill(pc, 'Sagitta_BreachingPoint')
    if bpSkill ~= nil then
        value = TryGetProp(bpSkill, "SkillFactor", 100)
    end

    return value
end

function SCR_Get_SkillFactor_OutbreakCap_Detonate(skill)
    local pc = GetSkillOwner(skill)
    local value = 0
    local ocSkill = GetSkill(pc, 'Sagitta_OutbreakCap')
    if ocSkill ~= nil then
        value = TryGetProp(ocSkill, "SkillFactor", 100)
    end

    return value
end