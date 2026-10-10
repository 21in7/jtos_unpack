-- shared_archeology_simple.lua
-- 고고학 옵션 메타의 직렬화, 역직렬화, 표시 정보 조회 계약을 한곳에서 관리한다.

ARCHEOLOGY_OPTION_CODEC = ARCHEOLOGY_OPTION_CODEC or {}

-- 클라이언트 UI와 서버 TX가 같은 재조율 한도를 사용한다.
ARCHEOLOGY_ORB_DIVINE_REROLL_LIMIT = 5
ARCHEOLOGY_ORB_CHAOS_REROLL_LIMIT = 5

function GET_ARCHEOLOGY_ORB_REROLL_LIMIT(key)
    if key == "D" then
        return ARCHEOLOGY_ORB_DIVINE_REROLL_LIMIT
    end
    if key == "C" then
        return ARCHEOLOGY_ORB_CHAOS_REROLL_LIMIT
    end
    return 0
end

-- 옵션 쌍 목록을 "ClassID;값,ClassID;값" 형식으로 직렬화한다.
function ARCHEOLOGY_OPTION_CODEC.serialize(options)
    if options == nil or #options <= 0 then
        return "None"
    end

    local encoded = {}
    for _, option in ipairs(options) do
        local optionClassID = tonumber(option[1])
        local value = tonumber(option[2])
        if optionClassID ~= nil and value ~= nil then
            encoded[#encoded + 1] = tostring(optionClassID) .. ";" ..
                tostring(value)
        end
    end

    if #encoded <= 0 then
        return "None"
    end
    return table.concat(encoded, ",")
end

-- 직렬화된 옵션 메타를 {ClassID, 값} 목록으로 복원한다.
function ARCHEOLOGY_OPTION_CODEC.deserialize(optionMeta)
    if optionMeta == nil or optionMeta == "" or optionMeta == "None" then
        return {}
    end

    local options = {}
    for _, encodedOption in ipairs(StringSplit(optionMeta, ",")) do
        local values = StringSplit(encodedOption, ";")
        local optionClassID = tonumber(values[1])
        local value = tonumber(values[2])
        if optionClassID ~= nil and value ~= nil then
            options[#options + 1] = { optionClassID, value }
        end
    end
    return options
end

-- 옵션 메타를 UI와 전시 효과 계산에 필요한 상세 정보 목록으로 변환한다.
function ARCHEOLOGY_OPTION_CODEC.get_option_info(optionMeta)
    local results = {}
    for _, option in ipairs(ARCHEOLOGY_OPTION_CODEC.deserialize(optionMeta)) do
        local optionClassID = option[1]
        local optionClass =
            GetClassByType("archeology_option_list", optionClassID)
        if optionClass ~= nil then
            results[#results + 1] = {
                id = optionClassID,
                tag = TryGetProp(optionClass, "Stat", "UNKNOWN"),
                type = TryGetProp(optionClass, "Type", "Prefix"),
                value = option[2],
                desc = TryGetProp(optionClass, "Desc", ""),
                grade = TryGetProp(optionClass, "Grade", 1),
                affixNameMsg = TryGetProp(optionClass, "AffixNameMsg", ""),
            }
        end
    end
    return results
end

-- 기존 단일 숫자 인자와 옵션 목록 호출을 모두 지원하는 직렬화 호환 진입점이다.
function SERIALIZE_ARCHEOLOGY_OPTION(options, value)
    if type(options) == "number" then
        return ARCHEOLOGY_OPTION_CODEC.serialize({ { options, value } })
    end
    return ARCHEOLOGY_OPTION_CODEC.serialize(options)
end

-- 기존 전역 호출자를 위한 역직렬화 호환 진입점이다.
function DESERIALIZE_ARCHEOLOGY_OPTION(optionMeta)
    return ARCHEOLOGY_OPTION_CODEC.deserialize(optionMeta)
end

-- 기존 전역 호출자를 위한 옵션 정보 조회 호환 진입점이다.
function GET_ARCHEOLOGY_OPTION_INFO(optionMeta)
    return ARCHEOLOGY_OPTION_CODEC.get_option_info(optionMeta)
end
