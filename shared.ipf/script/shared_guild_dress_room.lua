-- shared_guild_dress_room.lua


shared_guild_dress_room = {}

-- 길드 마일리지(10) : 길드 기여도(1) 비율
shared_guild_dress_room.get_cost = function()
    return 20
end

shared_guild_dress_room.get_item_option_list = function(item)
    local name = TryGetProp(item, 'ClassName', 'None')
    local cls = GetClass('guild_dress_room', name)
    if cls == nil then
        return nil
    end

    local result = {}
    local max_level = TryGetProp(cls, 'MaxLevel', 0)
    for i = 1, max_level do
        local prop = 'Level_' .. i
        local option_str = TryGetProp(cls, prop, 'None')        
        if option_str ~= 'None' then -- PATK_BM/158;HR_BM/402
            result[i] = option_str
        end
    end

    return result
end

shared_guild_dress_room.is_valid_item = function(item)
    local name = TryGetProp(item, 'ClassName', 'None')
    local cls = GetClass('guild_dress_room', name)
    if cls == nil then
        return false, 'None'
    end

    local ret = TryGetProp(item, 'CharacterBelonging', 0)
    local ret1 = TryGetProp(item, 'TeamBelonging', 0)
    if ret == 1 then -- 캐릭터 귀속이면 안됨.        
        return false, 'CantExecCuzCharacterBelonging'
    end

    ret = TryGetProp(item, 'LifeTime', 0)
    if ret > 0 then -- 기간제면 안됨        
        return false, 'TimelimitedItemsCannotBeUsed'
    end

    if ret1 == 1 and TryGetProp(item, 'GuildDressRoomItem', 0) == 0 then        
        return false, 'CantExecCuzTeamBelonging'
    end

    -- 팀 귀속이지만 GuildDressRoomItem == 1 이면 가능

    return true, 'None'
end

shared_guild_dress_room.get_my_contribution_point = function(pc)
    if IsServerSection() == 1 then
        local guildObj = GetGuildObj(pc)
        if guildObj == nil then
            return 0
        end
        
    	local memberObj = GetMemberObjByPC(guildObj, pc);
        if memberObj == nil then
            return 0
        end
    	local currentContribution = TryGetProp(memberObj, "Contribution", 0)
        return currentContribution
    else
        return GET_MY_CONTRIBUTION()
    end
end

shared_guild_dress_room.get_item_option_list_from_cls_and_level = function(cls, level)
    local prop = 'Level_' .. level
    local option_str = TryGetProp(cls, prop, 'None')        
    return option_str
end

shared_guild_dress_room.get_total_rental_count = function(pc, item)
    local class_name = TryGetProp(item, "ClassName", "None")
    local cls = GetClass("guild_dress_room", class_name)
    if cls == nil then
        return 0
    end

    local guild_obj = nil
    if IsServerSection() == 0 then
        guild_obj = GetMyGuildObject()
    else
        guild_obj = GetGuildObj(pc)        
    end
    
    if guild_obj == nil then
        return 0
    end

    local prop = TryGetProp(cls, "CountGuildProperty", "None")
    return TryGetProp(guild_obj, prop, 0)
end

-- 길드의 위엄 총합
shared_guild_dress_room.get_guild_dignity_total = function(pc)
    local data = {}

    local guildObj = nil

    if IsServerSection() == 0 then
        guildObj = GetMyGuildObject()
    else
        guildObj = GetGuildObj(pc)        
    end
    
    local itemlist, cnt = GetClassList("guild_dress_room")
    for i = 0, cnt -1 do
        local cls = GetClassByIndexFromList(itemlist, i)
        if cls ~= nil then
            local prop_name = TryGetProp(cls, 'GuildProperty', 'None')
            if prop_name ~= 'None' then
                local level = TryGetProp(guildObj, prop_name, 0)
                local option_str = shared_guild_dress_room.get_item_option_list_from_cls_and_level(cls, level)
                if option_str ~= 'None' then
                    local option_data = StringSplit(option_str, ";")
                    for j = 1, #option_data do
                        local single_option = StringSplit(option_data[j], "/")
                        if #single_option == 2 then
                            local option_name = single_option[1]
                            local option_value = tonumber(single_option[2])
                            if data[option_name] == nil then
                                data[option_name] = option_value
                            else
                                data[option_name] = data[option_name] + option_value
                            end
                        end
                    end
                end
            end
        end
    end
    
    local option_order = {
        "MATK_BM", "PATK_BM", "STR_BM", "INT_BM", "CON_BM",
        "DEX_BM", "MNA_BM", "CRTATK_BM", "CRTMATK_BM", 
        "DEF_BM", "MDEF_BM", "BLK_BM", "BLK_BREAK_BM", "CRTDR_BM", "CRTHR_BM",
        "HR_BM", "DR_BM", "MHP_BM", "MSP_BM"
    }

    local sorted_data = {}
    for i = 1, #option_order do
        local opt_name = option_order[i]
        if data[opt_name] ~= nil then
            table.insert(sorted_data, { opt_name, data[opt_name] })            
        end
    end

    -- sorted_data[1][1], sorted_data[1][2] ...
    return sorted_data
end

shared_guild_dress_room.get_guild_dignity_total_str = function(pc)
    local option_order = {
        "MATK_BM", "PATK_BM", "STR_BM", "INT_BM", "CON_BM",
        "DEX_BM", "MNA_BM", "CRTATK_BM", "CRTMATK_BM"         
    }

    local option_order2 = {
        "DEF_BM", "MDEF_BM", "BLK_BM", "BLK_BREAK_BM", "CRTDR_BM", "CRTHR_BM",
        "HR_BM", "DR_BM", "MHP_BM", "MSP_BM"
    }

    local data = shared_guild_dress_room.get_guild_dignity_total(pc)
    local result = ""

    local str = ""
    local str2 = ""

    for i = 1, #data do
        local opt_name = data[i][1]
        local opt_value = data[i][2]
        if result ~= "" then
            result = result .. ";"
        end
        result = result .. opt_name .. "/" .. opt_value
        
        if table.find(option_order, opt_name) > 0 then
            if str ~= "" then
                str = str .. ";"
            end
            str = str .. opt_name .. "/" .. opt_value
        elseif table.find(option_order2, opt_name) > 0 then
            if str2 ~= "" then
                str2 = str2 .. ";"
            end
            str2 = str2 .. opt_name .. "/" .. opt_value
        end
    end
    return result, str, str2
end

shared_guild_dress_room.get_guild_dress_room_info_list = function(pc, grade)
    local guild_obj = nil
    if IsServerSection() == 0 then
        guild_obj = GetMyGuildObject()
    else
        guild_obj = GetGuildObj(pc)
    end

    if guild_obj == nil then
        return
    end

    local is_all = false
    if grade == "All" then
        is_all = true
    end

    local info_list = {}
    local list, cnt = GetClassList("guild_dress_room")
    for i = 0, cnt - 1 do
        local cls = GetClassByIndexFromList(list, i)
        if cls ~= nil then
            local _grade = TryGetProp(cls, "Grade", "None")
            local is_enable = true
            if is_all == false then
                if grade ~= _grade then
                    is_enable = false
                end
            end

            if is_enable == true then
                local class_id = TryGetProp(cls, "ClassID", 0)
                local class_name = TryGetProp(cls, "ClassName", "None")
                local name = TryGetProp(cls, "Name", "None")
                local level, max_level, unlock_level = 0, TryGetProp(cls, "MaxLevel", 0), TryGetProp(cls, "UnlockLevel", 0)
                local prop_name = TryGetProp(cls, "GuildProperty", "None")
                if prop_name ~= "None" then
                    level = TryGetProp(guild_obj, prop_name, 0)
                end
                info_list[#info_list + 1] = { type = class_id, class_name = class_name, name = name, cur_level = level, max_level = max_level, unlock_level = unlock_level, grade = _grade }
            end
        end
    end
    return info_list
end

shared_guild_dress_room.get_guild_dress_room_complete_count = function(pc)
    local guild_obj = nil
    if IsServerSection() == 0 then
        guild_obj = GetMyGuildObject()
    else
        guild_obj = GetGuildObj(pc)
    end

    if guild_obj == nil then
        return
    end

    local complete_list = {
        S = { complete_count = 0, max_count = 0 },
        A = { complete_count = 0, max_count = 0 },
        B = { complete_count = 0, max_count = 0 },
        All = { complete_count = 0, max_count = 0 }
    }
    local list, cnt = GetClassList("guild_dress_room")
    for i = 0, cnt - 1 do
        local cls = GetClassByIndexFromList(list, i)
        if cls ~= nil then
            local grade = TryGetProp(cls, "Grade", "None")
            local level, max_level, unlock_level = 0, TryGetProp(cls, "MaxLevel", 0), TryGetProp(cls, "UnlockLevel", 0)
            local prop_name = TryGetProp(cls, "GuildProperty", "None")
            if prop_name ~= "None" then
                level = TryGetProp(guild_obj, prop_name, 0)
            end
            if level >= max_level then
                complete_list[grade].complete_count = complete_list[grade].complete_count + 1
                complete_list["All"].complete_count = complete_list["All"].complete_count + 1
            end
            complete_list[grade].max_count = complete_list[grade].max_count + 1
            complete_list["All"].max_count = complete_list["All"].max_count + 1
        end
    end
    return complete_list
end

shared_guild_dress_room.get_guild_dress_room_rental_count = function(pc, type)
    local guild_obj = nil
    if IsServerSection() == 0 then
        guild_obj = GetMyGuildObject()
    else
        guild_obj = GetGuildObj(pc)
    end

     if guild_obj == nil then
        return 0
    end

    local cls = GetClassByType("guild_dress_room", type)
    if cls == nil then
        return 0
    end

    local prop_name = TryGetProp(cls, "CountGuildProperty", "None")
    if prop_name == nil or prop_name == "None" then
        return 0
    end

    return TryGetProp(guild_obj, prop_name, 0)
end