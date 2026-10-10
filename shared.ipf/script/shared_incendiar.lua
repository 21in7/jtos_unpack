-- shared_incendiar.lua

function SCR_GET_Incendiar_FlareBlast_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 5
    return GET_PVP_TARGET_COUNT(pc, count)
end

function SCR_GET_Incendiar_BlazingEruption_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 8
    return GET_PVP_TARGET_COUNT(pc, count)
end

function SCR_GET_Incendiar_Gehenna_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 8
    return GET_PVP_TARGET_COUNT(pc, count)
end

function SCR_GET_Incendiar_VolcanicGeyser_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 10
    return GET_PVP_TARGET_COUNT(pc, count)
end

function SCR_GET_Incendiar_Inferno_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 10
    return GET_PVP_TARGET_COUNT(pc, count)
end

function SCR_GET_Incendiar_DiesIrae_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 15
    return GET_PVP_TARGET_COUNT(pc, count)
end

function SCR_GET_Incendiar_DiesIrae_Ratio2(skill)
    local lv = TryGetProp(skill, "Level", 1)
    local rate = lv * 2
    if rate > 12 then rate = 12 end
    return rate
end

function SCR_INCENDIAR_CHECK_USE_DIESIIRAE_C(actor, skl, buffName)
    local buff = actor:GetBuff():GetBuff("Incendiar_Ignition_Max_Buff")
    if buff ~= nil then
        return 1
    end
    return 0
end
