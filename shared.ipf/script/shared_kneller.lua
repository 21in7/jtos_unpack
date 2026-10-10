-- shared_kneller.lua
-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_DeeperResonance_Ratio(skill)
    local value = TryGetProp(skill, "Level") * 5

    return value;
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_GraveHand_Ratio(skill)
    local value = 5
    local pc = GetSkillOwner(skill)
    if pc ~= nil then
        value = GET_PVP_TARGET_COUNT(pc, value)
    end
    
    return value;
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_MourningChime_Ratio(skill)
    local value = 5
    local pc = GetSkillOwner(skill)
    if pc ~= nil then
        value = GET_PVP_TARGET_COUNT(pc, value)
    end
    
    return value;
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_PassingBell_Ratio(skill)
    local value = 5
    local pc = GetSkillOwner(skill)
    if pc ~= nil then
        value = GET_PVP_TARGET_COUNT(pc, value)
    end
    
    return value;
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_RestingGround_Ratio(skill)
    local value = 10
    local pc = GetSkillOwner(skill)
    if pc ~= nil then
        value = GET_PVP_TARGET_COUNT(pc, value)
    end
    
    return value;
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_ResonantPulse_Ratio(skill)
    local value = 10
    local pc = GetSkillOwner(skill)
    if pc ~= nil then
        value = GET_PVP_TARGET_COUNT(pc, value)
    end
    
    return value;
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_DeathKnell_Ratio(skill)
    local value = 15
    local pc = GetSkillOwner(skill)
    if pc ~= nil then
        value = GET_PVP_TARGET_COUNT(pc, value)
    end
    
    return value;
end