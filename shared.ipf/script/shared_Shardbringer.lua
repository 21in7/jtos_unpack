-- shared_Shardbringer.lua
-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Shardbringer_CrystalSowing_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 15
    return GET_PVP_TARGET_COUNT(pc, count)
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Shardbringer_ShardGale_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 8
    return GET_PVP_TARGET_COUNT(pc, count)
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Shardbringer_CrystalZone_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 8
    return GET_PVP_TARGET_COUNT(pc, count)
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Shardbringer_ShardRicochet_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 10
    return GET_PVP_TARGET_COUNT(pc, count)
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Shardbringer_CrystalSpear_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 10
    return GET_PVP_TARGET_COUNT(pc, count)
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Shardbringer_ObsidianPulsar_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 15
    return GET_PVP_TARGET_COUNT(pc, count)
end

function SCR_SHARDBRINGER_CHECK_USE_OBSIDIANPULSAR_C(actor, skl, buffName)
    local buff = actor:GetBuff():GetBuff("CrystalLiberation_Buff")
    if buff ~= nil then
        return 1
    end
    return 0
end
