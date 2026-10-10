function RESONANCE_POINT_ON_INIT(addon, frame)
    addon:RegisterMsg("RESONANCE_POINT_START", "ON_RESONANCE_POINT_OPEN")
    addon:RegisterMsg("RESONANCE_POINT_END", "ON_RESONANCE_POINT_CLOSE")
    addon:RegisterMsg("RESONANCE_POINT_UPDATE", "ON_RESONANCE_POINT_UPDATE")
    addon:RegisterMsg("RESONANCE_POINT_RESULT", "ON_RESONANCE_POINT_RESULT")
end

function ON_RESONANCE_POINT_OPEN(frame, msg, arg_str, arg_num)
    if frame == nil then
        return
    end

    local result_text = GET_CHILD_RECURSIVELY(frame, "reward_step")
    if result_text ~= nil then
        result_text:ShowWindow(0)
    end

    frame:ShowWindow(1)
end

function ON_RESONANCE_POINT_CLOSE(frame, msg, arg_str, arg_num)
    if frame == nil then
        return
    end
    frame:ShowWindow(0)
end

function ON_RESONANCE_POINT_UPDATE(frame, msg, arg_str, arg_num)
    if frame == nil then
        return
    end

    if frame:IsVisible() == 0 then
        frame:ShowWindow(1)
    end

    local cur_point = tonumber(arg_str) or 0
    local max_point = tonumber(arg_num) or 0
    cur_point = math.max(cur_point, 0)

    local percent = 0
    if max_point > 0 then
        cur_point = math.min(cur_point, max_point)
        percent = math.floor((cur_point / max_point) * 100)
    end
    
    local text = GET_CHILD_RECURSIVELY(frame, "text")
    if text ~= nil then
        text:SetTextByKey("text", ScpArgMsg("SancuartyResonance_PointProgress", "PERCENT", percent))
    end

    local gauge = GET_CHILD_RECURSIVELY(frame, "gauge")
    if gauge ~= nil then
        if max_point > 0 then
            gauge:SetPoint(cur_point, max_point)
        else
            gauge:SetPoint(0, 1)
        end
    end
end

function ON_RESONANCE_POINT_RESULT(frame, msg, arg_str, arg_num)
    if frame == nil then
        return
    end

    local token = StringSplit(arg_str, "/")
    local cur_point = tonumber(token[1]) or 0
    local max_point = tonumber(token[2]) or 100
    local reward_step = math.max(0, math.min(tonumber(arg_num) or 0, 3))
    frame:ShowWindow(1)

    ON_RESONANCE_POINT_UPDATE(frame, "RESONANCE_POINT_UPDATE", tostring(cur_point), max_point)

    local result_text = GET_CHILD_RECURSIVELY(frame, "reward_step")
    if result_text ~= nil then
        local reward_step_text = ScpArgMsg("SancuartyResonance_AdditionalRewardCount{COUNT}", "COUNT", reward_step)
        result_text:SetTextByKey("step", reward_step_text)
        result_text:ShowWindow(1)
    end

end
