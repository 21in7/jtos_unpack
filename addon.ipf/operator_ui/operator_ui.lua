-- operator_ui
function OPERATOR_UI_ON_INIT(addon, frame)
end

function ON_OPERATOR_UI_OPEN(frame)
    if frame == nil then
        frame = ui.GetFrame("operator_ui");
    end

    if frame == nil then 
        return 
    end

    if session.IsGM() == 0 then
        frame:ShowWindow(0)
        ui.CloseFrame("operator_ui")
        return
    end

    local pic = GET_CHILD_RECURSIVELY(frame, "pic")
    if pic == nil then
        return
    end

    pic:SetImage("operator_title_red")
    pic:ShowWindow(1)
end