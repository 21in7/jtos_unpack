-- shared_induninfo_button.lua
shared_induninfo_button = {}

shared_induninfo_button.RED_BUTTON = 1
shared_induninfo_button.BUTTON1 = 2
shared_induninfo_button.BUTTON2 = 3
shared_induninfo_button.BUTTON3 = 4

shared_induninfo_button.get_button_name = function(action_button)
    if action_button == shared_induninfo_button.RED_BUTTON then
        return "RedButton"
    end

    if action_button == shared_induninfo_button.BUTTON1 then
        return "Button1"
    end

    if action_button == shared_induninfo_button.BUTTON2 then
        return "Button2"
    end

    if action_button == shared_induninfo_button.BUTTON3 then
        return "Button3"
    end
    return "None"
end

shared_induninfo_button.get_action_name = function(button_cls, button_name)
    if button_cls == nil or button_name == nil or button_name == "None" then
        return "None"
    end
    return TryGetProp(button_cls, button_name.."Action", "None")
end

shared_induninfo_button.is_server = function()
    return IsServerSection() == 1
end

shared_induninfo_button.get_pc = function(pc)
    if shared_induninfo_button.is_server() == true then
        if pc ~= nil then
            return pc
        end
    else
        return GetMyPCObject()
    end
    return nil
end

shared_induninfo_button.send_restrict_msg = function(pc)
    if shared_induninfo_button.is_server() == true then
        SendSysMsg(pc, "ThisLocalUseNot")
    else
        ui.SysMsg(ScpArgMsg("ThisLocalUseNot"))
    end
end

shared_induninfo_button.has_block_keyword = function(keyword, block_keyword)
    if keyword == nil or block_keyword == nil or block_keyword == "None" then
        return false
    end

    local keyword_list = StringSplit(keyword, ";")
    local block_list = StringSplit(block_keyword, ";")
    for i = 1, #block_list do
        if table.find(keyword_list, block_list[i]) > 0 then
            return true
        end
    end
    return false
end

shared_induninfo_button.check_dungeon_type = function(dungeon_type, check_dungeon_type)
    if check_dungeon_type == nil or check_dungeon_type == "None" then
        return true
    end

    if dungeon_type == nil or dungeon_type == "None" then
        return false
    end

    local check_dungeon_type_list = StringSplit(check_dungeon_type, ";")
    for i = 1, #check_dungeon_type_list do
        local check_type = check_dungeon_type_list[i]
        if check_type == dungeon_type then
            return true
        end
    end
    return false
end

shared_induninfo_button.check_sub_type = function(sub_type, check_sub_type)
    if check_sub_type == nil or check_sub_type == "None" then
        return true
    end

    if sub_type == nil or sub_type == "None" then
        return false
    end

    local check_sub_type_list = StringSplit(check_sub_type, ";")
    for i = 1, #check_sub_type_list do
        local check_type = check_sub_type_list[i]
        if check_type == sub_type then
            return true
        end
    end
    return false
end

shared_induninfo_button.is_integrate_server = function()
    if shared_induninfo_button.is_server() == true then
        return IsIntegrateServer() == 1
    end
    return session.world.IsIntegrateServer() == true
end

shared_induninfo_button.get_layer = function(pc)
    if shared_induninfo_button.is_server() == true then
        return GetLayer(pc)
    end
    return world.GetLayer()
end

shared_induninfo_button.get_map_cls = function(pc)
    if shared_induninfo_button.is_server() == true then
        local zone_name = GetZoneName(pc)
        return GetClass("Map", zone_name)
    end
    return GetClass("Map", session.GetMapName())
end

shared_induninfo_button.is_raid_field = function(pc, map_cls)
    if shared_induninfo_button.is_server() == true then
        return IsRaidField(pc) == 1
    end

    local keyword = TryGetProp(map_cls, "Keyword", "None")
    return shared_induninfo_button.has_block_keyword(keyword, "IsRaidField")
end

shared_induninfo_button.is_weekly_boss_map = function(pc, map_cls)
    if shared_induninfo_button.is_server() == true then
        local result = IsWeeklyBossMap(pc)
        return result == true or result == 1
    end

    local keyword = TryGetProp(map_cls, "Keyword", "None")
    return shared_induninfo_button.has_block_keyword(keyword, "WeeklyBossMap")
end

shared_induninfo_button.check_action_restrict = function(pc, action_cls, indun_cls)
    if action_cls == nil then
        return false
    end

    if indun_cls == nil then
        return false
    end

    pc = shared_induninfo_button.get_pc(pc)
    if pc == nil then
        return false
    end

    if TryGetProp(action_cls, "CheckIntegrateServer", "NO") == "YES" and shared_induninfo_button.is_integrate_server() == true then
        shared_induninfo_button.send_restrict_msg(pc)
        return false
    end

    if TryGetProp(action_cls, "CheckPVPField", "NO") == "YES" and IsPVPField(pc) == 1 then
        shared_induninfo_button.send_restrict_msg(pc)
        return false
    end

    if TryGetProp(action_cls, "CheckPVPServer", "NO") == "YES" and IsPVPServer(pc) == 1 then
        shared_induninfo_button.send_restrict_msg(pc)
        return false
    end

    if TryGetProp(action_cls, "CheckLayerZero", "NO") == "YES" and shared_induninfo_button.get_layer(pc) ~= 0 then
        shared_induninfo_button.send_restrict_msg(pc)
        return false
    end

    local map_cls = shared_induninfo_button.get_map_cls(pc)
    local map_type = TryGetProp(map_cls, "MapType", "None")
    local block_map_type = TryGetProp(action_cls, "BlockMapType", "None")
    if block_map_type ~= "None" and map_type == block_map_type then
        shared_induninfo_button.send_restrict_msg(pc)
        return false
    end

    local keyword = TryGetProp(map_cls, "Keyword", "None")
    if TryGetProp(action_cls, "CheckRaidField", "NO") == "YES" and shared_induninfo_button.is_raid_field(pc, map_cls) == true then
        shared_induninfo_button.send_restrict_msg(pc)
        return false
    end

    if TryGetProp(action_cls, "CheckWeeklyBossMap", "NO") == "YES" and shared_induninfo_button.is_weekly_boss_map(pc, map_cls) == true then
        shared_induninfo_button.send_restrict_msg(pc)
        return false
    end

    if shared_induninfo_button.has_block_keyword(keyword, TryGetProp(action_cls, "BlockMapKeyword", "None")) == true then
        shared_induninfo_button.send_restrict_msg(pc)
        return false
    end

    if shared_induninfo_button.check_dungeon_type(TryGetProp(indun_cls, "DungeonType", "None"), TryGetProp(action_cls, "CheckDungeonType", "None")) == false then
        shared_induninfo_button.send_restrict_msg(pc)
        return false
    end

    if shared_induninfo_button.check_sub_type(TryGetProp(indun_cls, "SubType", "None"), TryGetProp(action_cls, "CheckSubType", "None")) == false then
        shared_induninfo_button.send_restrict_msg(pc)
        return false
    end

    return true
end

shared_induninfo_button.on_click = function(frame, ctrl, arg_str, arg_num)
    if ctrl == nil then
        return
    end

    local indun_class_id = tonumber(ctrl:GetUserValue("INDUNINFO_BUTTON_INDUN_CLASSID"))
    local button_class_id = tonumber(ctrl:GetUserValue("INDUNINFO_BUTTON_CLASSID"))
    local action_button = tonumber(ctrl:GetUserValue("INDUNINFO_ACTION_BUTTON"))
    if indun_class_id == nil or button_class_id == nil or action_button == nil then
        return
    end

    local button_name = shared_induninfo_button.get_button_name(action_button)
    local button_cls = GetClassByType("IndunInfoButton", button_class_id)
    local action_name = shared_induninfo_button.get_action_name(button_cls, button_name)
    if action_name == "None" then
        return
    end

    local action_cls = GetClass("induninfo_button_action", action_name)
    if action_cls == nil then
        return
    end

    local indun_cls = GetClassByType("Indun", indun_class_id)
    if indun_cls == nil then
        return
    end

    if shared_induninfo_button.check_action_restrict(nil, action_cls, indun_cls) == false then
        return
    end

    local action_type = TryGetProp(action_cls, "ActionType", "None")
    if action_type == "ENTER" then
        if TryGetProp(action_cls, "CloseIndunInfo", "YES") == "YES" then
            ui.CloseFrame("induninfo")
        end
        ReqIndunInfoButtonAction(indun_class_id, button_class_id, action_button)
    end
end

shared_induninfo_button.get_context_server_dialog = function(indun_class_name)
    if indun_class_name == nil or indun_class_name == "" or indun_class_name == "None" then
        return nil, nil
    end

    local indun_cls = GetClass("Indun", indun_class_name)
    if indun_cls == nil then
        return nil, nil
    end

    local dungeon_type = TryGetProp(indun_cls, "DungeonType", "None")
    if dungeon_type == nil or dungeon_type == "None" then
        return nil, nil
    end

    local indun_button_cls = GetClass("IndunInfoButton", dungeon_type)
    if indun_button_cls == nil then
        return nil, nil
    end

    local indun_cls_id = TryGetProp(indun_cls, "ClassID", 0)
    local button_cls_id = TryGetProp(indun_button_cls, "ClassID", 0)
    return indun_cls_id, button_cls_id
end

function INDUNINFO_ON_BUTTON_CLICK(frame, ctrl, arg_str, arg_num)
    shared_induninfo_button.on_click(frame, ctrl, arg_str, arg_num)
end
