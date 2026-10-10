-- shared_Fanaticus.lua
-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Fanaticus_FanaticBlaze_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 8
    return GET_PVP_TARGET_COUNT(pc, count)
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Fanaticus_Fulminatio_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 8
    return GET_PVP_TARGET_COUNT(pc, count)
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Fanaticus_BlindChase_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 5
    return GET_PVP_TARGET_COUNT(pc, count)
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Fanaticus_Compassio_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 10
    return GET_PVP_TARGET_COUNT(pc, count)
end

-- 콤파시오 디버프의 받는 피해 증가량(%). [가시관] 특성 on/off 에 따라 표시값이 바뀐다.
-- hardskill_Fanaticus.lua 의 FANATICUS_COMPASSIO_DAMAGE / FANATICUS_COMPASSIO_THORN_ADD 와 맞출 것.
-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Fanaticus_Compassio_Ratio2(skill)
    local damageRate = 20
    local thornAdd = 10

    local pc = GetSkillOwner(skill)
    if pc == nil then return damageRate end

    local abil = GetAbility(pc, "Fanaticus9")
    if abil ~= nil and TryGetProp(abil, "ActiveState", 0) == 1 then
        return damageRate + thornAdd
    end

    return damageRate
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Fanaticus_Martyrdom_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 10
    return GET_PVP_TARGET_COUNT(pc, count)
end

-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_GET_Fanaticus_DivineFanaticism_Ratio(skill)
    local pc = GetSkillOwner(skill)
    local count = 15
    return GET_PVP_TARGET_COUNT(pc, count)
end

-- 스킬별 HP 소모량 (최대 HP 대비 비율. 실제로는 현재 HP에서 차감된다).
-- 스택 1개당 1% 이므로 1%의 배수로 설정한다. 밸런스 확정 시 이 표만 수정한다.
-- 서버(FANATICUS_CRUOR_ON)와 클라이언트(SP 툴팁) 양쪽에서 참조한다.
local FANATICUS_CRUOR_HP_RATE = {
    Fanaticus_FanaticBlaze = 0.01,    -- 1스택
    Fanaticus_Fulminatio   = 0.02,    -- 2스택 ([봉헌] 활성 시에만 소모)
    Fanaticus_BlindChase   = 0.01,    -- 1스택
    Fanaticus_Compassio    = 0.02,    -- 2스택 (다른 스킬보다 많은 HP 소모)
    Fanaticus_Martyrdom    = 0.01,    -- 1스택
}

-- HP 하한선. 소모 후 현재 HP가 최대 HP의 이 비율 아래로 내려가면 HP를 소모하지 않는다.
-- 크루오르로 죽지 않게 하는 안전장치. 이때는 SP를 대신 소모하며 스택은 그대로 적립된다.
local FANATICUS_CRUOR_HP_FLOOR = 0.5

-- 해당 스킬의 HP 소모 비율
function FANATICUS_GET_CRUOR_HP_RATE(sklName)
    local rate = FANATICUS_CRUOR_HP_RATE[sklName]
    if rate == nil then return 0 end
    return rate
end

-- 지금 이 스킬이 크루오르 적립 대상인가. HP 하한선은 보지 않는다.
-- 특성 미보유 / [황홀] 중 / 소모량 0 이면 HP 소모도 스택 적립도 없다.
-- 하한선에 걸린 경우는 SP를 대신 소모할 뿐 스택은 적립되므로 여기서 걸러내지 않는다.
function FANATICUS_IS_CRUOR_SKILL(pc, sklName)
    if pc == nil then return false end
    if GetAbility(pc, "Fanaticus100") == nil then return false end
    if IsBuffApplied(pc, "Rapture_Buff") == "YES" then return false end

    if FANATICUS_GET_CRUOR_HP_RATE(sklName) <= 0 then return false end
    if TryGetProp(pc, "MHP", 0) <= 0 then return false end

    return true
end

-- 지금 이 스킬이 크루오르로 HP를 소모할 수 있는 상태인가.
-- HP 소모 여부와 SP 대체 여부를 하나의 기준으로 판정하기 위해 서버·클라이언트가 함께 참조한다.
-- 하한선에 걸리면 일부만 내고 마는 구멍이 생기므로, 전액을 낼 수 있을 때만 참이다.
-- 이때는 SP를 정상 소모하되 스택은 HP를 냈을 때와 같은 양이 적립된다 (FANATICUS_CRUOR_ON).
-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function FANATICUS_CAN_PAY_CRUOR_HP_COST(pc, sklName)
    if FANATICUS_IS_CRUOR_SKILL(pc, sklName) == false then return false end

    local rate  = FANATICUS_GET_CRUOR_HP_RATE(sklName)
    local maxHP = TryGetProp(pc, "MHP", 0)
    local curHP = TryGetProp(pc, "HP", 0)

    return (curHP - maxHP * rate) >= (maxHP * FANATICUS_CRUOR_HP_FLOOR)
end

-- HP를 소모하는 스킬은 SP를 소모하지 않는다.
-- [황홀] 중이거나 하한선에 걸려 HP를 낼 수 없으면 SP를 정상 소모한다.
-- (자원을 전혀 쓰지 않고 사용되는 것을 방지)
-- 하한선 때문에 SP로 넘어간 경우에도 크루오르 스택은 정상 적립된다.
-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_Get_SpendSP_Fanaticus(skill)
    local value = SCR_Get_SpendSP(skill)
    local pc = GetSkillOwner(skill)
    if pc == nil then return value end

    if FANATICUS_CAN_PAY_CRUOR_HP_COST(pc, TryGetProp(skill, "ClassName", "None")) == true then
        return 0
    end

    return value
end

-- 풀미나티오는 [봉헌] 특성이 켜져 있을 때만 SP를 HP로 대체한다. 비활성이면 항상 SP를 소모한다.
-- done, 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그램팀에 알려주시기 바랍니다.
function SCR_Get_SpendSP_Fanaticus_Fulminatio(skill)
    local pc = GetSkillOwner(skill)
    if pc == nil then return SCR_Get_SpendSP(skill) end

    local abil = GetAbility(pc, "Fanaticus7")
    if abil == nil or TryGetProp(abil, "ActiveState", 0) ~= 1 then
        return SCR_Get_SpendSP(skill)
    end

    return SCR_Get_SpendSP_Fanaticus(skill)
end

function SCR_FANATICUS_CHECK_USE_DIVINEFANATICISM_C(actor, skl, buffName)
    local buff = actor:GetBuff():GetBuff("Rapture_Buff")
    if buff ~= nil then
        return 1
    end
    return 0
end
