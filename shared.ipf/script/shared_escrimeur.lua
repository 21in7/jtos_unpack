-- shared_escrimeur.lua

function SCR_ESCRIMEUR_CHECK_USE_SKILL_C(actor, skl, buffName)
    local buff = actor:GetBuff():GetBuff("Touche_max_Buff")
    if buff ~= nil then
        return 1;
    end
    
    return 0;
end

function SCR_GET_AdvantGarde_Ratio(skill)
    local value = 11 + skill.Level;
    
    value = value * SCR_REINFORCEABILITY_TOOLTIP(skill)
    
    return math.floor(value)
end

function SCR_Get_SkillFactor_Escrimeur_AttaqueEnchainee(skill)
    local pc = GetSkillOwner(skill)
    local value = SCR_Get_SkillFactor_Reinforce_Ability(skill)
    local abil = GetAbility(pc, "Escrimeur106")
    if abil ~= nil and TryGetProp(abil, "ActiveState", 0) == 1 then
        value = value * 0.8
    end

    return math.floor(value)
end

function SCR_GET_Invitation_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local level = TryGetProp(skill, "Level", 0)
    local value = 10 + level
    if value > 20 then
        value = 20
    end

    return value
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_AttaqueEnchainee_Ratio(skill)
    local value = 5
    local pc = GetSkillOwner(skill)
    if pc ~= nil then
        value = GET_PVP_TARGET_COUNT(pc, value)
    end
    return value
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_SeptEclairs_Ratio(skill)
    local value = 5
    local pc = GetSkillOwner(skill)
    if pc ~= nil then
        value = GET_PVP_TARGET_COUNT(pc, value)
    end
    return value
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_GrandFente_Ratio(skill)
    local value = 10
    local pc = GetSkillOwner(skill)
    if pc ~= nil then
        value = GET_PVP_TARGET_COUNT(pc, value)
    end
    return value
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Rafale_Ratio(skill)
    local value = 10
    local pc = GetSkillOwner(skill)
    if pc ~= nil then
        value = GET_PVP_TARGET_COUNT(pc, value)
    end
    return value
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_PassataSotto_Ratio(skill)
    local value = 10
    local pc = GetSkillOwner(skill)
    if pc ~= nil then
        value = GET_PVP_TARGET_COUNT(pc, value)
    end
    return value
end

