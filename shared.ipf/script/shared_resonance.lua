-- shared_resonance.lua
shared_resonance = {}
shared_resonance.SORT_NONE = 1
shared_resonance.SORT_NAME = 2
shared_resonance.SORT_LEVEL = 3
shared_resonance.SORT_RESONANCE = 4

shared_resonance.TAB_SKILL_INFO  = 0
shared_resonance.TAB_SKILL_REG  = 1

shared_resonance.get_boss_sort_name = function(value)
	local boss_info = shared_resonance.get_boss_info(value)
	if boss_info == nil then
		return ""
	end
	return tostring(boss_info.name)
end

shared_resonance.sort_list = function(ret_list, sort_type)
	if ret_list == nil then
		return
	end
	sort_type = tonumber(sort_type) or sort_type

	if sort_type == shared_resonance.SORT_LEVEL then
		table.sort(ret_list, function(a, b)
			local a_level = tonumber(TryGetProp(a, "Level", 0))
			local b_level = tonumber(TryGetProp(b, "Level", 0))
			return a_level < b_level
		end)
	elseif sort_type == shared_resonance.SORT_RESONANCE then
		local progress_map = {}
		for i = 1, #ret_list do
			local cls = ret_list[i]
			local class_id = tonumber(TryGetProp(cls, "ClassID", 0)) or 0
			local cur_point, max_point = shared_resonance.get_skill_progress(class_id)
			cur_point = tonumber(cur_point) or 0
			max_point = tonumber(max_point) or 0
			if max_point <= 0 then
				cur_point = 0
				max_point = 1
			end

			progress_map[class_id] = {
				cur_point = cur_point,
				max_point = max_point,
				name = shared_resonance.get_boss_sort_name(cls)
			}
		end

		table.sort(ret_list, function(a, b)
			local a_class_id = tonumber(TryGetProp(a, "ClassID", 0)) or 0
			local b_class_id = tonumber(TryGetProp(b, "ClassID", 0)) or 0
			local a_progress = progress_map[a_class_id]
			local b_progress = progress_map[b_class_id]
			if a_progress == nil or b_progress == nil then
				return a_class_id < b_class_id
			end

			local a_compare_value = a_progress.cur_point * b_progress.max_point
			local b_compare_value = b_progress.cur_point * a_progress.max_point
			if a_compare_value ~= b_compare_value then
				return a_compare_value > b_compare_value
			end

			if a_progress.name ~= b_progress.name then
				return a_progress.name < b_progress.name
			end

			return a_class_id < b_class_id
		end)
	elseif sort_type == shared_resonance.SORT_NAME then
		table.sort(ret_list, function(a, b)
			local a_name = shared_resonance.get_boss_sort_name(a)
			local b_name = shared_resonance.get_boss_sort_name(b)
			return a_name < b_name
		end)
	end 
end

shared_resonance.get_list = function(list, cnt, sort_type)
	if list == nil or cnt <= 0 then
		return nil
	end

	local ret_list = {}
	for i = 0, cnt - 1 do
    	local cls = GetClassByIndexFromList(list, i)
		if cls ~= nil then
			local group_id = TryGetProp(cls, "GroupID", "None")
			if group_id == "SanctuartyResonance" then
				ret_list[#ret_list + 1] = cls
			end
		end
	end

	if sort_type ~= nil and sort_type ~= shared_resonance.SORT_NONE then
		shared_resonance.sort_list(ret_list, sort_type)
	end

	return ret_list
end

shared_resonance.get_boss_info = function(value)
	if value == nil then
		return nil
	end

	local boss_info = nil
	if value == "NextBoss" then
		boss_info = {
			is_next_boss = true,
			name = "Auto_Kil",
			icon = "questionmark_L",
			attribute = "None",
			indun_name = "None"
		}
	else
		local boss_name = "None"
		local boss_list = TryGetProp(value, "BossList", "None")
		local split = StringSplit(boss_list, '/')
		if #split > 1 then
			boss_name = split[#split]
		else
			boss_name = boss_list
		end

		local boss = GetClass("Monster", boss_name)
		if boss ~= nil then
			local boss_name = TryGetProp(boss, "Name", "None")
			local boss_icon = TryGetProp(boss, "Icon", "None")
			local boss_attribute = TryGetProp(boss, "Attribute", "None")
			local indun_cls_name = TryGetProp(value, "ClassName", "None")
			boss_info = {
				is_next_boss = false,
				name = boss_name,
				icon = boss_icon,
				attribute = boss_attribute,
				indun_name = indun_cls_name
			}
		end
	end
	return boss_info
end

shared_resonance.get_skill_cls_list = function(indun_cls_name)
	local cls_list = {}
	local list, cnt = GetClassList("resonance_skill")
	for i = 0, cnt - 1 do
		local cls = GetClassByIndexFromList(list, i)
		if cls ~= nil then
			local _indun_cls_name = TryGetProp(cls, "IndunClassName", "None")
			if indun_cls_name == _indun_cls_name then
				cls_list[#cls_list + 1] = cls
			end
		end
	end
	return cls_list
end

shared_resonance.get_skill_info_list = function(indun_cls_id)
	if indun_cls_id == nil or indun_cls_id == 0 then
		return nil
	end

	local indun_cls = GetClassByType("Indun", indun_cls_id)
	if indun_cls == nil then
		return nil
	end

	local indun_cls_name = TryGetProp(indun_cls, "ClassName", "None")
	local cls_list = shared_resonance.get_skill_cls_list(indun_cls_name)
	if cls_list == nil then
		return nil
	end

	local skill_info_list = {}
	for i = 1, #cls_list do
		local cls = cls_list[i]
		if cls ~= nil then
			local class_id = TryGetProp(cls, "ClassID", 0)
			local skill_cls_name = TryGetProp(cls, "SkillClassName", "None")
			local skill_max_level = TryGetProp(cls, "MaxLevel", 0)
			local skill_reinforce_buff = TryGetProp(cls, "ReinforceBuff", "None")
			local skill_reinforce_add_value = TryGetProp(cls, "ReinforceAddValue", 0)
			local skill_icon_name = TryGetProp(cls, "SkillIconName", "None")
			local skill_video_name = TryGetProp(cls, "SkillVideoName", "None")
			local skill_video_overlay_name = TryGetProp(cls, "SkillVideoOverlayName", "None")
			local reinforce_cls_name = TryGetProp(cls, "ReinforceClassName", "None")
			local skill_info = {
				id = class_id,
				skill_name = skill_cls_name,
				max_level = skill_max_level,
				reinforce_name = reinforce_cls_name,
				reinforce_buff = skill_reinforce_buff,
				reinforce_add_value = skill_reinforce_add_value,
				icon_name = skill_icon_name,
				video_name = skill_video_name,
				video_overlay_name = skill_video_overlay_name
			}
			skill_info_list[#skill_info_list + 1] = skill_info
		end
	end
	return skill_info_list
end

shared_resonance.get_skill_progress = function(indun_cls_id)
	local skill_info_list = shared_resonance.get_skill_info_list(indun_cls_id)
	if skill_info_list == nil or #skill_info_list <= 0 then
		return 0, 0
	end

	local cur_point = 0
	local max_point = 0
	for i = 1, #skill_info_list do
		local info = skill_info_list[i]
		if info ~= nil then
			local max_level = tonumber(info.max_level) or 0
			if max_level > 0 then
				local cur_level = shared_resonance.get_skill_level(info.skill_name)
				cur_level = tonumber(cur_level) or 0
				cur_level = math.max(0, math.min(cur_level, max_level))
				cur_point = cur_point + cur_level
				max_point = max_point + max_level
			end
		end
	end
	return cur_point, max_point
end

shared_resonance.get_skill_info = function(id)
	if id == nil or id == 0 then
		return nil
	end

	local cls = GetClassByType("resonance_skill", id)
	if cls == nil then
		return nil
	end

	local class_id = TryGetProp(cls, "ClassID", 0)
	local skill_cls_name = TryGetProp(cls, "SkillClassName", "None")
	local skill_max_level = TryGetProp(cls, "MaxLevel", 0)
	local skill_reinforce_buff = TryGetProp(cls, "ReinforceBuff", "None")
	local skill_reinforce_add_value = TryGetProp(cls, "ReinforceAddValue", 0)
	local skill_icon_name = TryGetProp(cls, "SkillIconName", "None")
	local skill_video_name = TryGetProp(cls, "SkillVideoName", "None")
	local skill_video_overlay_name = TryGetProp(cls, "SkillVideoOverlayName", "None")
	local reinforce_cls_name = TryGetProp(cls, "ReinforceClassName", "None")
	local skill_info = {
		id = class_id,
		skill_name = skill_cls_name,
		max_level = skill_max_level,
		reinforce_name = reinforce_cls_name,
		reinforce_buff = skill_reinforce_buff,
		reinforce_add_value = skill_reinforce_add_value,
		icon_name = skill_icon_name,
		video_name = skill_video_name,
		video_overlay_name = skill_video_overlay_name
	}
	return skill_info
end

shared_resonance.get_skill_slot_icon = function(skill_name)
	if skill_name == nil or skill_name == "None" then
		return "None"
	end

	local cls = GetClassByStrProp("resonance_skill", "SkillClassName", skill_name)
	if cls == nil then
		return "None"
	end

	return TryGetProp(cls, "SelectIconName", "None")
end

shared_resonance.get_skill_reinforce_info = function(skill_name)
	if skill_name == nil or skill_name == "" or skill_name == "None" then
		return nil
	end

	local skill_cls = GetClassByStrProp("resonance_skill", "SkillClassName", skill_name)
	if skill_cls == nil then
		return
	end

	local cls_name = TryGetProp(skill_cls, "ReinforceClassName", "None")
	if cls_name == nil or cls_name == "" or cls_name == "None" then
		return nil
	end

	local cls = GetClass("resonance_reinforce", cls_name)
	if cls == nil then
		return
	end

	local reinforce_info = {}
	local max_level = TryGetProp(skill_cls, "MaxLevel", 0)
	for i = 0, max_level do
		local prop_name = "Reinforce_"..i
		local prop_value = TryGetProp(cls, prop_name, "None")

		local desc_prop_name = "Desc_"..i
		local desc_prop_value = TryGetProp(cls, desc_prop_name, 0)

		local cooldown_prop_name = "CoolDown_"..i
		local cooldown_prop_value = TryGetProp(cls, cooldown_prop_name, "None")
		local cooldown_value = tonumber(cooldown_prop_value)
		
		local mtrl_item_name = TryGetProp(skill_cls, "ReinforceMaterialName", "None")
		if mtrl_item_name ~= nil and mtrl_item_name ~= "" and mtrl_item_name ~= "None" then
			if prop_value ~= nil and prop_value ~= "None" and desc_prop_value ~= nil then
				local prop_list = StringSplit(prop_value, '/')
				if #prop_list >= 2 then
					local mtrl_item_count = tonumber(prop_list[1]) or 0
					local reinforce_rate = tonumber(prop_list[2]) or 0
					reinforce_info[#reinforce_info + 1] = {
						id = TryGetProp(cls, "ClassID", 0),
						item_name = mtrl_item_name,
						item_count = mtrl_item_count,
						rate = reinforce_rate,
						desc_value = desc_prop_value,
						cooldown_value = cooldown_value
					}
				end
			end
		end
	end
	return reinforce_info
end

shared_resonance.get_skill_level = function(skill_name)
	if skill_name == nil or skill_name == "None" then
		return nil, nil
	end

	if GetClass("Skill", skill_name) == nil then
		return nil, nil
	end

	local acc_obj = GetMyAccountObj()
	if acc_obj == nil then
		return nil, nil
	end

	local cls = GetClassByStrProp("resonance_skill", "SkillClassName", skill_name)
	if cls == nil then
		return nil, nil
	end

	local acc_prop_level = TryGetProp(cls, "AccPropLevel", "None")
    if acc_prop_level == "None" then
		return nil, nil
	end
	
	local max_level = TryGetProp(cls, "MaxLevel", 1)
	local acc_prop_level_list = StringSplit(acc_prop_level, '/')
    if #acc_prop_level_list > 0 then
		local prop_name = acc_prop_level_list[1]
		local cur_level = TryGetProp(acc_obj, prop_name, 0)
		local next_level = cur_level + 1
		if next_level > max_level then
			next_level = max_level
		end
		return cur_level, next_level
	end
	return nil, nil
end

shared_resonance.get_skill_register_info = function(pc)
	local acc_obj = nil
	if IsServerSection() == 0 then
		acc_obj = GetMyAccountObj()
	else
		if pc == nil then
			return nil
		end
		acc_obj = GetAccountObj(pc)
	end

	if acc_obj == nil then
		return nil
	end

	local slot_count = 0 
	local slot_cls = GetClass("SharedConst", "RESONANCE_SKILL_SLOT_CNT")
	if slot_cls ~= nil then
		slot_count = slot_cls.Value
	end

	local reg_info = {}
	local acc_prop_name = "ResonanceSkillSlot_"
	for i = 1, slot_count do
		acc_prop_name = "ResonanceSkillSlot_"..i
		local prop_value = TryGetProp(acc_obj, acc_prop_name, "None")
		local slot_info = {
			prop_name = acc_prop_name,
			reg_skill_name = "None",
			reg_skill_lv = 0
		}
		if prop_value ~= "None" then
			local prop_value_list = StringSplit(prop_value, '/')
			if #prop_value_list >= 2 then
				local skill_name = prop_value_list[1]
				local skill_lv = tonumber(prop_value_list[2])
				slot_info = {
					prop_name = acc_prop_name,
					reg_skill_name = skill_name,
					reg_skill_lv = skill_lv
				}
			end
		end
		reg_info[#reg_info + 1] = slot_info
	end
	return reg_info
end

shared_resonance.is_skill_registered = function(pc, skill_name)
	if pc == nil then
		return false
	end
	
    if skill_name == nil or skill_name == "" or skill_name == "None" then
        return false
    end

    local skill_cls = GetClassByStrProp("resonance_skill", "SkillClassName", skill_name)
    if skill_cls == nil then
        return false
    end

    local acc_obj = nil
    if IsServerSection() == 1 then
        acc_obj = GetAccountObj(pc)
    else
        acc_obj = GetMyAccountObj()
    end

    if acc_obj == nil then
        return false
    end

    -- 해금되지 않은 스킬은 슬롯 값이 남아 있어도 사용할 수 없음.
    local acc_prop_level = TryGetProp(skill_cls, "AccPropLevel", "None")
    local level_list = StringSplit(acc_prop_level, '/')
    if level_list == nil or #level_list < 1 then
        return false
    end

    local cur_level = tonumber(TryGetProp(acc_obj, level_list[1], 0)) or 0
    if cur_level <= 0 then
        return false
    end

    local register_info = shared_resonance.get_skill_register_info(pc)
    if register_info == nil then
        return false
    end

    for _, info in ipairs(register_info) do
        if info ~= nil and info.reg_skill_name == skill_name and tonumber(info.reg_skill_lv) > 0 then
            return true
        end
    end
    return false
end

shared_resonance.is_skill_slot_change_blocked_by_cooldown = function(pc)
	local reg_info = shared_resonance.get_skill_register_info(pc)
	if reg_info == nil then
		return false
	end

	for i = 1, #reg_info do
		local info = reg_info[i]
		local skill_name = info ~= nil and info.reg_skill_name or "None"
		if skill_name ~= nil and skill_name ~= "None" then
			local remain_cooldown = 0
			if IsServerSection() == 1 then
				if pc == nil then
					return false
				end
				remain_cooldown = GetSkillCoolDown(pc, skill_name)
			else
				local skill_cls = GetClass("Skill", skill_name)
				if skill_cls ~= nil then
					local skill_id = TryGetProp(skill_cls, "ClassID", 0)
					remain_cooldown = session.GetSklCoolDown(skill_id)
				end
			end

			if (tonumber(remain_cooldown) or 0) > 0 then
				return true
			end
		end
	end
	return false
end

shared_resonance.is_skill_unlock = function(skill_name)
	if skill_name == nil or skill_name == "None" then
		return 0
	end

	local cur_level = shared_resonance.get_skill_level(skill_name)
	if cur_level == nil or cur_level <= 0 then
		return 0
	end
	return 1
end

shared_resonance.get_skill_select_info = function()
	local select_info = {}
	local list, cnt = GetClassList("resonance_skill")
	if list ~= nil and cnt > 0 then
		for i = 0, cnt - 1 do
			local cls = GetClassByIndexFromList(list, i)
			if cls ~= nil then
				local skill_cls_name = TryGetProp(cls, "SkillClassName", "None")
				local skill_icon = TryGetProp(cls, "SkillIconName", "None")
				local select_icon = TryGetProp(cls, "SelectIconName", "None")
				local skill_cls = GetClass("Skill", skill_cls_name)
				if skill_cls ~= nil then
					local skill_name = TryGetProp(skill_cls, "Name", "None")
					local is_enable = shared_resonance.is_skill_unlock(skill_cls_name)
					select_info[#select_info + 1] = {
						icon = skill_icon,
						select_icon = select_icon,
						enable = is_enable,
						name = skill_name,
						cls_name = skill_cls_name
					}
				end
			end
		end
	end
	return select_info
end

shared_resonance.is_skillmgr_enable_check = function(pc)
	if IsServerSection() == 0 then
		local map_name = session.GetMapName()
		local map_cls = GetClass("Map", map_name)
		if map_cls == nil then
			return false
		end
	
		if TryGetProp(map_cls, "MapType", "None") ~= "City" then
			ui.SysMsg(ClMsg("AllowedInTown"))
			return false
		end
	else
		local map = GetMapProperty(pc)
		if map ~= nil and TryGetProp(map, "MapType", "None") ~= "City" then
			SendSysMsg(pc, "AllowedInTown")
			return false
		end
	end
	return true
end

shared_resonance.is_resonance_skill = function(skill_name)
	if skill_name ~= nil and skill_name ~= "None" then
		local cls = GetClassByStrProp("resonance_skill", "SkillClassName", skill_name)
		if cls ~= nil then
			return true
		end
	end
	return false
end

shared_resonance.is_resonance_skill_by_type = function(skill_type)
	local type = tonumber(skill_type) or 0
	if type <= 0 then
		return false
	end


	local skill_cls = GetClassByType("Skill", type)
	if skill_cls == nil then
		return false
	end

	local skill_name = TryGetProp(skill_cls, "ClassName", "None")
	return shared_resonance.is_resonance_skill(skill_name)
end

shared_resonance.get_skill_cls_icon_by_type = function(skill_type)
	local type = tonumber(skill_type) or 0
	if type <= 0 then
		return "None"
	end
	
	local skill_cls = GetClassByType("Skill", type)
	if skill_cls == nil then
		return "None"
	end

	local skill_name = TryGetProp(skill_cls, "ClassName", "None")
	if shared_resonance.is_resonance_skill(skill_name) == false then
		return "None"
	end

	local skill_icon = TryGetProp(skill_cls, "Icon", "None")
	return "icon_"..skill_icon
end

shared_resonance.get_skill_cooldown = function(skill_name)
    local cls = GetClassByStrProp("resonance_skill", "SkillClassName", skill_name)
    if cls == nil then
        return 0
    end

    local acc_prop_cooldown = TryGetProp(cls, "AccPropCoolDown", "None")
	if acc_prop_cooldown == nil or acc_prop_cooldown == "" or acc_prop_cooldown == "None" then
		return 0
	end

    local list = StringSplit(acc_prop_cooldown, "/")
	if list == nil or #list < 2 then
		return 0
	end

    local prop_name = list[1]
    local default_value = tonumber(list[2]) or 0

    local acc_obj = GetMyAccountObj()
    if acc_obj == nil then
        return default_value
    end

    local acc_cooldown = TryGetProp(acc_obj, prop_name, 0)
    if acc_cooldown ~= nil and acc_cooldown > 0 then
        return acc_cooldown
    end

    return default_value
end

shared_resonance.get_skill_unlock_route = function(skill_name)
    local cls = GetClassByStrProp("resonance_skill", "SkillClassName", skill_name)
    if cls == nil then
        return nil
    end

    local indun_cls_name = TryGetProp(cls, "IndunClassName", "None")
    local indun_cls = GetClass("Indun", indun_cls_name)
    if indun_cls == nil then
        return nil
    end

    local category = TryGetProp(indun_cls, "Category", "None")
    local difficulty = TryGetProp(indun_cls, "Difficulty", "None")
    return category, difficulty
end

shared_resonance.parse_reinforce_effect_list = function(effect_string)
    local result = {}

    if effect_string == nil or effect_string == "" or effect_string == "None" then
        return result
    end

    local effect_token_list = StringSplit(effect_string, ";")
    if effect_token_list == nil then
        return nil
    end

    for i = 1, #effect_token_list do
        local effect_token = effect_token_list[i]
        local value_list = StringSplit(effect_token, "/")
        if value_list == nil or #value_list <= 0 then
            return nil
        end

        local effect_type = value_list[1]
        if effect_type == nil or effect_type == "" or effect_type == "None" then
            return nil
        end

        local args = {}
		local raw_args = {}
        for j = 2, #value_list do
            local value = value_list[j]
			raw_args[#raw_args + 1] = value
			
            local number_value = tonumber(value)
            if number_value ~= nil then
                args[#args + 1] = number_value
            else
                args[#args + 1] = value
            end
        end
		
        result[#result + 1] = {
            effect_type = effect_type,
            args = args,
			raw_args = raw_args
        }
    end
    return result
end

shared_resonance.get_skill_reinforce_effect_list = function(skill_name, level)
    if skill_name == nil or skill_name == "" or skill_name == "None" then
        return nil
    end

    local skill_cls = GetClassByStrProp("resonance_skill", "SkillClassName", skill_name)
    if skill_cls == nil then
        return nil
    end

    local max_level = tonumber(TryGetProp(skill_cls, "MaxLevel", 0))
    level = tonumber(level) or 0
    level = math.max(0, math.min(level, max_level))

    local reinforce_cls_name = TryGetProp(skill_cls, "ReinforceClassName", "None")
    if reinforce_cls_name == nil or reinforce_cls_name == "" or reinforce_cls_name == "None" then
        return nil
    end

    local reinforce_cls = GetClass("resonance_reinforce", reinforce_cls_name)
    if reinforce_cls == nil then
        return nil
    end

    local prop_name = "RaidEffect_"..level
    local effect_string = TryGetProp(reinforce_cls, prop_name, "None")
    return shared_resonance.parse_reinforce_effect_list(effect_string)
end

shared_resonance.find_reinforce_effect = function(effect_list, effect_type)
    if effect_list == nil or effect_type == nil then
        return nil
    end

    for i = 1, #effect_list do
        local effect = effect_list[i]
        if effect ~= nil and effect.effect_type == effect_type then
            return effect
        end
    end
    return nil
end

shared_resonance.get_reinforce_effect_arg = function(effect_list, effect_type, arg_index, default_value)
    local effect = shared_resonance.find_reinforce_effect(effect_list, effect_type)
    if effect == nil or effect.args == nil then
        return default_value
    end

    local value = effect.args[arg_index]
    if value == nil then
        return default_value
    end
    return value
end

shared_resonance.get_reinforce_args = function(skill_cls)
	local ret = {}
	if skill_cls == nil then
		return ret
	end

	local args = TryGetProp(skill_cls, "ReinforceArgs", "None")
	if args == nil or args == "None" or args == "" then
		return ret
	end

	local args_list = StringSplit(args, ';')
	for _, arg in ipairs(args_list) do
		local pair = StringSplit(arg, '/')
		if #pair == 2 then
			local key = pair[1]
			local value = pair[2]
			if key ~= nil and key ~= "" and value ~= nil and value ~= "" then
				ret[#ret + 1] = { arg_name = key, arg_value = value }
			end
		end
	end
	return ret
end