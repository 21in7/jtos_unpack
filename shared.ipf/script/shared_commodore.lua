-- shared_commodore.lua

function SCR_COMMODORE_CHECK_USE_SKILL_C(actor, skl, buffName)
    local buff = actor:GetBuff():GetBuff("FullSalvo_Buff")
    if buff ~= nil then
        return 1;
    end
    
    return 0;
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_Get_SkillFactor_Commodore_AntiBoarding(skill)
    local pc = GetSkillOwner(skill)
    local value = SCR_Get_SkillFactor_Reinforce_Ability(skill)
    local abil = GetAbility(pc, "Commodore6")
    if abil ~= nil and TryGetProp(abil, "ActiveState", 0) == 1 then
        value = value * 0.75
    end

    return math.floor(value)
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_TargetingSight_Ratio(skill)
    local value = 15
    local pc = GetSkillOwner(skill)
    if pc ~= nil then
        value = GET_PVP_TARGET_COUNT(pc, value)
    end
    
    return value;
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_ArtillerySupport_Ratio(skill)
    local value = 5
    local pc = GetSkillOwner(skill)
    if pc ~= nil then
        value = GET_PVP_TARGET_COUNT(pc, value)
    end
    
    return value;
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_ArmorPiercingShot_Ratio(skill)
    local value = 10
    local pc = GetSkillOwner(skill)
    if pc ~= nil then
        value = GET_PVP_TARGET_COUNT(pc, value)
    end
    
    return value;
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_DirectHit_Ratio(skill)
    local value = 30 + (skill.Level * 2)
    if value > 42 then
        value = 42
    end

    return value;
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_AntiBoarding_Ratio(skill)
    local value = 10
    local pc = GetSkillOwner(skill)
    if pc ~= nil then
        value = GET_PVP_TARGET_COUNT(pc, value)
    end
    
    return value;
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_AnchorStrike_Ratio(skill)
    local value = 10
    local pc = GetSkillOwner(skill)
    if pc ~= nil then
        value = GET_PVP_TARGET_COUNT(pc, value)
    end
    
    return value;
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_AnnihilationBombardment_Ratio(skill)
    local value = 15
    local pc = GetSkillOwner(skill)
    if pc ~= nil then
        value = GET_PVP_TARGET_COUNT(pc, value)
    end
    
    return value;
end