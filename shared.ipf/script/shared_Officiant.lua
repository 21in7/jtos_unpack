-- shared_Officiant.lua
-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Officiant_Prelude_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 15
    return GET_PVP_TARGET_COUNT(pc, count)
end

-- 프렐류드 [연무] 지속시간(초). 기본 60초, [아츠] 잠식(Officiant6) 채용 시 30초.
-- pad_skill_list.xml 의 Officiant_Haze(life 60000) / _Arts(life 30000) 와 같은 값이어야 한다.
function SCR_GET_Officiant_Prelude_Ratio2(skill)
    local pc = GetSkillOwner(skill)
    local abil = GetAbility(pc, "Officiant6")
    if abil ~= nil and TryGetProp(abil, "ActiveState", 0) == 1 then
        return 30
    end
    return 60
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Officiant_IncenseBreath_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 5
    return GET_PVP_TARGET_COUNT(pc, count)
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Officiant_EmberWave_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 5
    return GET_PVP_TARGET_COUNT(pc, count)
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Officiant_IncenseBeacon_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 10
    return GET_PVP_TARGET_COUNT(pc, count)
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Officiant_Vertigo_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 10
    return GET_PVP_TARGET_COUNT(pc, count)
end

-- 베르티고 지속시간(초) = PAD 틱 수. 기본 3틱, [아츠] 잔향(Officiant8) 채용 시 4틱.
-- pad_skill_list.xml 의 Officiant_Vertigo_Pad(life 3000) / _Arts(life 4000) 와 같은 값이어야 한다.
-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Officiant_Vertigo_Ratio2(skill)
    local pc = GetSkillOwner(skill)
    local abil = GetAbility(pc, "Officiant8")
    if abil ~= nil and TryGetProp(abil, "ActiveState", 0) == 1 then
        return 4
    end
    return 3
end

-- 베르티고 총 타수 = PAD 틱 수 x 틱당 연출 연타. 기본 9타, [아츠] 잔향 채용 시 12타.
-- Ratio2 를 그대로 곱하므로 지속시간 표기와 타수 표기가 어긋나지 않는다.
-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Officiant_Vertigo_Ratio3(skill)
    local OFFICIANT_VERTIGO_HIT_PER_TICK = 3

    return SCR_GET_Officiant_Vertigo_Ratio2(skill) * OFFICIANT_VERTIGO_HIT_PER_TICK
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Officiant_Botafumeiro_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 15
    return GET_PVP_TARGET_COUNT(pc, count)
end

function SCR_OFFICIANT_CHECK_USE_BOTAFUMEIRO_C(actor, skl, buffName)
    local buff = actor:GetBuff():GetBuff("Officiant_Offering_Max_Buff")
    if buff ~= nil then
        return 1
    end
    return 0
end