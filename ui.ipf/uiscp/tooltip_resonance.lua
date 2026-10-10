-- tooltip_resonance.lua --
tooltip_resonance = {}
tooltip_resonance.class_type_msg = {
	Melee = "SKILL_CAPTION_MSG1",
    Magic = "SKILL_CAPTION_MSG2",
    Missile = "SKILL_CAPTION_MSG3",
    Responsive = "SKILL_CAPTION_MSG24"
}
tooltip_resonance.attack_type_msg = {
	Aries = "SKILL_CAPTION_MSG4",
    Slash = "SKILL_CAPTION_MSG5",
    Strike = "SKILL_CAPTION_MSG6",
    Arrow = "SKILL_CAPTION_MSG7",
    Gun = "SKILL_CAPTION_MSG8",
    Cannon = "SKILL_CAPTION_MSG9"
}
tooltip_resonance.attribute_msg = {
	Fire = "SKILL_CAPTION_MSG10",
    Ice = "SKILL_CAPTION_MSG11",
    Lightning = "SKILL_CAPTION_MSG12",
    Poison = "SKILL_CAPTION_MSG13",
    Earth = "SKILL_CAPTION_MSG14",
    Dark = "SKILL_CAPTION_MSG15",
    Holy = "SKILL_CAPTION_MSG16",
    Soul = "SKILL_CAPTION_MSG17"
}
tooltip_resonance.casting_msg = {
	cast = "SKILL_CAPTION_MSG25",
    dynamic_casting = "SKILL_CAPTION_MSG25",
    channeling = "SKILL_CAPTION_MSG26"
}
tooltip_resonance.excluded_companion_skill = {
	Templer_BattleOrders = true,
    Templer_AdvancedOrders = true,
    Templer_HorseRiding = true
}
tooltip_resonance.reinforce_emphasis_start = "{#88f030}{ol}"
tooltip_resonance.reinforce_emphasis_end = "{/}{/}"
tooltip_resonance.skill_factor_emphasis_start = "{#ffb400}{ol}"
tooltip_resonance.skill_factor_emphasis_end = "{/}{/}"
tooltip_resonance.raid_effect_emphasis_start = "{#66D9EF}{ol}"
tooltip_resonance.raid_effect_emphasis_end = "{/}{/}"
tooltip_resonance.raid_effect_changed_emphasis_start = "{#00FFFF}{ol}"
tooltip_resonance.raid_effect_changed_emphasis_end = "{/}{/}"

tooltip_resonance.caption_append = function(lines, msg)
	if msg ~= nil and msg ~= "" then
		lines[#lines + 1] = msg
	end
end

tooltip_resonance.get_hit_type_override_msg = function(skill_name)
	if skill_name == nil or skill_name == "" or skill_name == "None" then
		return "None"
	end

	local resonance_cls = GetClassByStrProp("resonance_skill", "SkillClassName", skill_name)
	if resonance_cls == nil then
		return "None"
	end

	return TryGetProp(resonance_cls, "TooltipHitTypeOverrideMsg", "None")
end

tooltip_resonance.caption_lines = function(lines, per_line)
	local caption_lines = {}
	for i = 1, #lines, per_line do
		local row = {}
		for j = i, math.min(i + per_line - 1, #lines) do
			row[#row + 1] = lines[j]
		end
		caption_lines[#caption_lines + 1] = table.concat(row, "  ")
	end
	return table.concat(caption_lines, "{nl}")
end

tooltip_resonance.get_skill_cls = function(skill_name)
	if skill_name == nil or skill_name == "" or skill_name == "None" then
		return nil	
	end
	return GetClass("Skill", skill_name)
end

tooltip_resonance.get_parse_level = function(skill_name)
	local cur_level, next_level = shared_resonance.get_skill_level(skill_name)
	if cur_level == nil or cur_level <= 0 then
		return 1
	end
	return cur_level
end

tooltip_resonance.format_caption_value = function(value)
	if value == nil then
		return ""
	end

	local num = tonumber(value)
	if num ~= nil then
		if num % 1 ~= 0 then
			value = string.format("%.1f", num)
		else
			value = tostring(num)
		end
		return GET_COMMAED_STRING(tonumber(value))
	end
	return tostring(value)
end

tooltip_resonance.format_raid_effect_value = function(value)
    if value == nil then
        return ""
    end

    if type(value) == "string" then
        return value
    end

    local number_value = tonumber(value)
    if number_value == nil then
        return tostring(value)
    end

    if number_value == 0 then
        return "0"
    end

    local result = string.format("%.15f", number_value)
    result = string.gsub(result, "0+$", "")
    result = string.gsub(result, "%.$", "")
    return result
end

tooltip_resonance.format_cooldown_value = function(value)
	local cooldown = tonumber(value)
	if cooldown == nil then
		return nil
	end

	if cooldown < 0 then
		cooldown = 0
	end

	local seconds = cooldown / 1000
	if seconds % 1 ~= 0 then
		return string.format("%.1f", seconds)..ScpArgMsg("UI_Sec")
	end
	return GET_COMMAED_STRING(seconds)..ScpArgMsg("UI_Sec")
end

tooltip_resonance.has_caption_prop = function(caption, prop_name)
	if caption == nil or prop_name == nil then
		return false
	end

	if string.find(caption, "#{"..prop_name.."}#", 1, true) ~= nil then
		return true
	end

	if string.find(caption, "#{1"..prop_name.."}#", 1, true) ~= nil then
		return true
	end
	return false
end

tooltip_resonance.emphasis_caption_line = function(caption, prop_name, style_start, style_end)
	if caption == nil or caption == "" or prop_name == nil or prop_name == "" then
		return caption
	end

	if style_start == nil then
		style_start = tooltip_resonance.reinforce_emphasis_start
	end

	if style_end == nil then
		style_end = tooltip_resonance.reinforce_emphasis_end
	end

	local token = "#{"..prop_name.."}#"
	local token_by_one = "#{1"..prop_name.."}#"

	local lines = StringSplit(caption, "{nl}")
	if lines == nil or #lines <= 0 then
		return caption
	end

	for i = 1, #lines do
		if string.find(lines[i], token, 1, true) ~= nil or string.find(lines[i], token_by_one, 1, true) ~= nil then
			lines[i] = style_start ..lines[i]..style_end
		end
	end
	return table.concat(lines, "{nl}")
end

tooltip_resonance.try_parse_property = function(obj, next_obj, caption, override_props)
	local tag_start = string.find(caption, "#{")
	if tag_start == nil then
		return caption, 0
	end

	local next_str = string.sub(caption, tag_start + 2, string.len(caption))
	local tag_end = string.find(next_str, "}#")
	if tag_end == nil then
		return caption, 0
	end

	local tag_text = string.sub(caption, tag_start + 2, tag_start + tag_end)
	local prop_name = tag_text
	if string.sub(tag_text, 1, 1) == "1" then
		prop_name = string.sub(tag_text, 2, string.len(tag_text))
	end

	if override_props ~= nil then
		local override_value = override_props[tag_text]
		if override_value == nil then
			override_value = override_props[prop_name]
		end

		if override_value ~= nil then
			local before_str = string.sub(caption, 1, tag_start - 1)
			local end_str = string.sub(caption, tag_start + tag_end + 3, string.len(caption))
			return before_str..tooltip_resonance.format_caption_value(override_value)..end_str, 1
		end
	end

	return TRY_PARSE_PROPERTY(obj, next_obj, caption)
end

tooltip_resonance.parse_skill_caption = function(cls, caption, level, override_props)
	if cls == nil or caption == nil or caption == "" or caption == "None" then
		return ""
	end

	caption = dictionary.ReplaceDicIDInCompStr(caption)

	if level == nil or level <= 0 then
		level = 1
	end

	local obj = CloneIES_UseCP(cls)
	if obj == nil then
		return caption
	end

	local next_obj = CloneIES_UseCP(cls)
	if next_obj == nil then
		DestroyIES(obj)
		return caption
	end

	if TryGetProp(next_obj, "LevelByDB", nil) ~= nil then
		next_obj.LevelByDB = level
	else
		next_obj.Level = level
	end

	while true do
		local parsed = 0
		caption, parsed = tooltip_resonance.try_parse_property(obj, next_obj, caption, override_props)
		if parsed == 0 then
			break
		end
	end

	DestroyIES(obj)
	DestroyIES(next_obj)
	return caption
end

tooltip_resonance.get_properties_skill_desc = function(cls)
	local add_caption = ""
	if cls ~= nil then
		local class_name = TryGetProp(cls, "ClassName", "None")
		local class_type = TryGetProp(cls, "ClassType", "None")
		local attack_type = TryGetProp(cls, "AttackType", "None")
		local attribute = TryGetProp(cls, "Attribute", "None")
		local affected_by_attack_speed_rate = TryGetProp(cls, "AffectedByAttackSpeedRate", "None")
		local casting_category = TryGetProp(cls, "CastingCategory", "None")
		local enable_companion = TryGetProp(cls, "EnableCompanion", "None")
		local hit_type = TryGetProp(cls, "HitType", "None")

		local lines = {}
		local value_type = TryGetProp(cls, "ValueType", "None")
		if value_type == "Attack" then
			local parts = {}

			local class_type_msg_key = tooltip_resonance.class_type_msg[class_type]
			if class_type_msg_key ~= nil then
				parts[#parts + 1] = ScpArgMsg(class_type_msg_key)
			end

			local attack_type_msg_key = tooltip_resonance.attack_type_msg[attack_type]
			if attack_type_msg_key ~= nil then
				parts[#parts + 1] = ScpArgMsg(attack_type_msg_key)
			end

			local attribute_msg_key = tooltip_resonance.attribute_msg[attribute]
			if attribute_msg_key ~= nil then
				parts[#parts + 1] = ScpArgMsg(attribute_msg_key)
			elseif attribute == "Melee" and class_type == "Magic" then
				parts[#parts + 1] = ScpArgMsg("SKILL_CAPTION_MSG27")
			end

			if #parts > 0 then
				tooltip_resonance.caption_append(lines, table.concat(parts, " - "))
			end

			local casting_msg_key = tooltip_resonance.casting_msg[casting_category]
			if casting_msg_key ~= nil then
				tooltip_resonance.caption_append(lines, ScpArgMsg(casting_msg_key))
			end

			if affected_by_attack_speed_rate == "YES" then
				tooltip_resonance.caption_append(lines, ScpArgMsg("SKILL_CAPTION_MSG18"))
			end
		end

		if enable_companion == "BOTH" then
			local is_excluded_skill = tooltip_resonance.excluded_companion_skill[class_name] == true
			if is_excluded_skill == false then
				tooltip_resonance.caption_append(lines, ScpArgMsg("SKILL_CAPTION_MSG19"))
			end
		elseif enable_companion == "YES" then
			tooltip_resonance.caption_append(lines, ScpArgMsg("SKILL_CAPTION_MSG20"))
		end

		local hit_type_override_msg = tooltip_resonance.get_hit_type_override_msg(class_name)
		if hit_type_override_msg ~= nil and hit_type_override_msg ~= "" and hit_type_override_msg ~= "None" then
			tooltip_resonance.caption_append(lines, ScpArgMsg(hit_type_override_msg))
		elseif hit_type == "Pad" then
			if class_type == "Magic" then
				tooltip_resonance.caption_append(lines, ScpArgMsg("SKILL_CAPTION_MSG21"))
			else
				tooltip_resonance.caption_append(lines, ScpArgMsg("SKILL_CAPTION_MSG22"))
			end
		elseif hit_type == "Installation" then
			tooltip_resonance.caption_append(lines, ScpArgMsg("SKILL_CAPTION_MSG23"))
		end

		if #lines > 0 then
			local caption_count = 3	
			add_caption = "{@st71orbd16}{s18}" .. tooltip_resonance.caption_lines(lines, caption_count) .. "{nl}{/}{/}"
		end
	end
	return add_caption
end

tooltip_resonance.get_skill_top_desc = function(skill_name)
	local cls = tooltip_resonance.get_skill_cls(skill_name)
	if cls == nil then
		return ""
	end
	return tooltip_resonance.get_properties_skill_desc(cls) --
end

tooltip_resonance.get_skill_main_desc = function(skill_name)
	local cls = tooltip_resonance.get_skill_cls(skill_name)
	if cls == nil then
		return ""
	end

	local caption = TryGetProp(cls, "Caption", "None")
	if caption == nil or caption == "" or caption == "None" then
		return ""	
	end

	local level = tooltip_resonance.get_parse_level(skill_name)
	return tooltip_resonance.parse_skill_caption(cls, caption, level)
end

tooltip_resonance.get_skill_detail_desc = function(skill_name)
	local level = tooltip_resonance.get_parse_level(skill_name)
	return tooltip_resonance.get_skill_detail_desc_by_level(skill_name, level)
end

tooltip_resonance.get_skill_detail_desc_by_level = function(skill_name, level)
    local cls = tooltip_resonance.get_skill_cls(skill_name)
	if cls == nil then
		return ""
	end

    local caption2 = TryGetProp(cls, "Caption2", "None")
	if caption2 == nil or caption2 == "" or caption2 == "None" then
		return ""
	end

    if level == nil or level <= 0 then
		level = 1
	end

	return tooltip_resonance.parse_skill_caption(cls, caption2, level)
end

tooltip_resonance.get_resonance_reinforce_tooltip_props = function(skill_name, reinforce_level)
	local skill_cls = tooltip_resonance.get_skill_cls(skill_name)
	local resonance_cls = GetClassByStrProp("resonance_skill", "SkillClassName", skill_name)
	if skill_cls == nil or resonance_cls == nil then
		return nil
	end

	reinforce_level = math.max(1, tonumber(reinforce_level) or 1)

	local reinforce_cls_name = TryGetProp(resonance_cls, "ReinforceClassName", "None")
	local reinforce_cls = GetClass("resonance_reinforce", reinforce_cls_name)
	if reinforce_cls == nil then
		return nil
	end

	local skill_factor = tonumber(TryGetProp(skill_cls, "SklFactor", 0)) or 0
	local skill_factor_by_level = tonumber(TryGetProp(skill_cls, "SklFactorByLevel", 0)) or 0
	local factor = SyncFloor(skill_factor * 10) * 0.1 + SyncFloor(skill_factor_by_level * 10) * 0.1 * (reinforce_level - 1)

	local growth_rate = tonumber(TryGetProp(reinforce_cls, "SkillFactorGrowthRate", 0)) or 0
	local growth_start_level = tonumber(TryGetProp(reinforce_cls, "SkillFactorGrowthStartLevel", 0)) or 0
	local growth_interval = tonumber(TryGetProp(reinforce_cls, "SkillFactorGrowthInterval", 0)) or 0
	if growth_rate > 0 and growth_start_level > 0 and growth_interval > 0 and reinforce_level >= growth_start_level then
		local growth_count = math.floor((reinforce_level - growth_start_level) / growth_interval) + 1
		for i = 1, growth_count do
			factor = factor * growth_rate / 10000
		end
	end
	factor = math.floor(factor)
	if factor <= 0 then
		return nil
	end

	local result = {
		CaptionRatio = factor
	}
	if skill_name ~= "Resonance_BerserkerZawra_ChFire" then
		return result
	end

	local add = 0
	local start_level = math.huge
	local interval = 1
	local max_count = math.huge
	local args = shared_resonance.get_reinforce_args(resonance_cls)
	for _, arg in ipairs(args) do
		if arg.arg_name == "Add" then
			add = math.max(0, tonumber(arg.arg_value) or 0)
		elseif arg.arg_name == "StartLevel" then
			start_level = tonumber(arg.arg_value) or math.huge
		elseif arg.arg_name == "Interval" then
			interval = math.max(1, tonumber(arg.arg_value) or 1)
		elseif arg.arg_name == "Max" then
			max_count = math.max(1, tonumber(arg.arg_value) or math.huge)
		end
	end

	local pillar_count = 1
	if reinforce_level >= start_level then
		local growth_count = math.floor((reinforce_level - start_level) / interval) + 1
		pillar_count = pillar_count + add * growth_count
	end
	pillar_count = math.min(math.max(1, pillar_count), max_count)
	local hit_count = tonumber(TryGetProp(skill_cls, "SklHitCount", 0)) or 0
	if pillar_count <= 0 or hit_count <= 0 then
		return nil
	end

	result.CaptionRatio = factor * pillar_count * hit_count
	result.CaptionRatio2 = pillar_count
	result.CaptionRatio3 = factor
	return result
end

tooltip_resonance.get_skill_reinforce_desc = function(skill_name, reinforce_level, desc_value, desc_prop_name, is_emphasis_props, cooldown_value)
	local cls = tooltip_resonance.get_skill_cls(skill_name)
	if cls == nil then
		return ""
	end

	local caption2 = TryGetProp(cls, "Caption2", "None")
	if caption2 == nil or caption2 == "" or caption2 == "None" then
		return ""
	end

	if reinforce_level == nil or reinforce_level <= 0 then
		reinforce_level = 1
	end

	if desc_prop_name == nil or desc_prop_name == "" or desc_prop_name == "None" then
		desc_prop_name = "CaptionRatio"
	end

	local override_props = {}
	override_props[desc_prop_name] = desc_value
	local resonance_props = tooltip_resonance.get_resonance_reinforce_tooltip_props(skill_name, reinforce_level)
	if resonance_props ~= nil then
		for prop_name, value in pairs(resonance_props) do
			override_props[prop_name] = value
		end
	end
	if cooldown_value ~= nil then
		override_props["CoolDown"] = tooltip_resonance.format_cooldown_value(cooldown_value)
	end

	local append_cooldown = cooldown_value ~= nil and tooltip_resonance.has_caption_prop(caption2, "CoolDown") == false
	if append_cooldown == true then
		caption2 = caption2.."{nl}"..ScpArgMsg("SancuartyResonance_SkillCooldown", "TIME", "#{CoolDown}#")
	end

	if is_emphasis_props == true then
		caption2 = tooltip_resonance.emphasis_caption_line(caption2, "SkillFactor", tooltip_resonance.skill_factor_emphasis_start, tooltip_resonance.skill_factor_emphasis_end)
		caption2 = tooltip_resonance.emphasis_caption_line(caption2, desc_prop_name, tooltip_resonance.reinforce_emphasis_start, tooltip_resonance.reinforce_emphasis_end)
		caption2 = tooltip_resonance.emphasis_caption_line(caption2, "CaptionRatio2", tooltip_resonance.reinforce_emphasis_start, tooltip_resonance.reinforce_emphasis_end)
		caption2 = tooltip_resonance.emphasis_caption_line(caption2, "CaptionRatio3", tooltip_resonance.reinforce_emphasis_start, tooltip_resonance.reinforce_emphasis_end)
		caption2 = tooltip_resonance.emphasis_caption_line(caption2, "CoolDown", tooltip_resonance.reinforce_emphasis_start, tooltip_resonance.reinforce_emphasis_end)
	end

	return tooltip_resonance.parse_skill_caption(cls, caption2, reinforce_level, override_props)
end

tooltip_resonance.get_reinforce_slot_image = function(level)
	return "resonance_skill_reinforce_slot_"..level
end

tooltip_resonance.find_caption_prop = function(line)
	if line == nil then
		return nil
	end

	local tag_start = string.find(line, "#{")
	if tag_start == nil then
		return nil
	end

	local next_str = string.sub(line, tag_start + 2, string.len(line))
	local tag_end = string.find(next_str, "}#")
	if tag_end == nil then
		return nil
	end

	local tag_text = string.sub(line, tag_start + 2, tag_start + tag_end)
	if string.sub(tag_text, 1, 1) == "1" then
		tag_text = string.sub(tag_text, 2, string.len(tag_text))
	end
	return tag_text
end

tooltip_resonance.get_skill_reinforce_desc_list = function(skill_name, reinforce_level, desc_value, desc_prop_name, is_emphasis_props, cooldown_value)
	local cls = tooltip_resonance.get_skill_cls(skill_name)
	if cls == nil then
		return {}
	end

	local caption2 = TryGetProp(cls, "Caption2", "None")
	if caption2 == nil or caption2 == "" or caption2 == "None" then
		return {}
	end

	if reinforce_level == nil or reinforce_level <= 0 then
		reinforce_level = 1
	end

	if desc_prop_name == nil or desc_prop_name == "" or desc_prop_name == "None" then
		desc_prop_name = "CaptionRatio"
	end

	local override_props = {}
	override_props[desc_prop_name] = desc_value
	local resonance_props = tooltip_resonance.get_resonance_reinforce_tooltip_props(skill_name, reinforce_level)
	if resonance_props ~= nil then
		for prop_name, value in pairs(resonance_props) do
			override_props[prop_name] = value
		end
	end
	if cooldown_value ~= nil then
		override_props["CoolDown"] = tooltip_resonance.format_cooldown_value(cooldown_value)
	end
	local append_cooldown = cooldown_value ~= nil and tooltip_resonance.has_caption_prop(caption2, "CoolDown") == false

	caption2 = dictionary.ReplaceDicIDInCompStr(caption2)

	local result = {}
	local lines = StringSplit(caption2, "{nl}")
	for i = 1, #lines do
		local raw_line = lines[i]
		local prop_name = tooltip_resonance.find_caption_prop(raw_line)
		local parsed_line = tooltip_resonance.parse_skill_caption(cls, raw_line, reinforce_level, override_props)
		if parsed_line ~= nil and parsed_line ~= "" then
			local emphasis = false
			if is_emphasis_props == true then
				if prop_name == "SkillFactor" or prop_name == desc_prop_name or prop_name == "CaptionRatio2" or prop_name == "CaptionRatio3" then
					emphasis = true
				end
			end
			result[#result + 1] = {
				prop_name = prop_name,
				text = parsed_line,
				emphasis = emphasis
			}
		end
	end

	local cooldown_text = tooltip_resonance.format_cooldown_value(cooldown_value)
	if cooldown_text ~= nil and append_cooldown == true then
		result[#result + 1] = {
			prop_name = "CoolDown",
			text = ScpArgMsg("SancuartyResonance_SkillCooldown", "TIME", cooldown_text),
			emphasis = is_emphasis_props == true
		}
	end

	local raid_effect_desc_list = tooltip_resonance.get_skill_raid_effect_desc_list(skill_name, reinforce_level, is_emphasis_props)
	for i = 1, #raid_effect_desc_list do
		result[#result + 1] = raid_effect_desc_list[i]
	end
	return result
end

tooltip_resonance.format_cooldown_time = function(cooldown_ms)
    local total_sec = math.floor((tonumber(cooldown_ms) or 0) / 1000)
	local min = math.floor(total_sec / 60)
	local sec = total_sec % 60
	if min > 0 then
		return tostring(min)..ScpArgMsg("UI_Min").." "..tostring(sec)..ScpArgMsg("UI_Sec")
	end
	return tostring(sec)..ScpArgMsg("UI_Sec")
end

tooltip_resonance.get_locked_skill_tooltip = function(category, difficulty)
	if category == nil or category == "None" then
		category = ""
	end

	if difficulty == nil or difficulty == "None" then
		difficulty = ""
	end

	local title = ScpArgMsg("SancuartyResonance_SkillLocked_Title")
	local how_to_get = ScpArgMsg("SancuartyResonance_SkillLocked_HowToGet")
	local route = ScpArgMsg("SancuartyResonance_SkillLocked_Route", "DIFFICULTY", difficulty, "CATEGORY", category)
	return "{@st66b}"..title.."{/}{nl}"..how_to_get.."{nl}"..route
end

tooltip_resonance.make_raid_effect_message_args = function(effect_info)
    local message_args = {}

    if effect_info == nil or effect_info.args == nil then
        return message_args
    end

    local function add_message_arg(key, value)
        message_args[#message_args + 1] = key
        message_args[#message_args + 1] = value
    end

    for i = 1, #effect_info.args do
        local number_value = tonumber(effect_info.args[i])
        local raw_value = effect_info.args[i]

        if effect_info.raw_args ~= nil and effect_info.raw_args[i] ~= nil then
            raw_value = effect_info.raw_args[i]
        end

        local value_key = "VALUE" .. i
        local value_text = tooltip_resonance.format_raid_effect_value(raw_value)
        local second_text = value_text
        local ratio_percent_text = value_text

        if number_value ~= nil then
            second_text = tooltip_resonance.format_raid_effect_value(number_value / 1000)
            ratio_percent_text = tooltip_resonance.format_raid_effect_value(number_value * 100)
        end

        add_message_arg(value_key, value_text)
        add_message_arg(value_key.."_MS", value_text)
        add_message_arg(value_key.."_SEC", second_text)
        add_message_arg(value_key.."_RATIO_PERCENT", ratio_percent_text)
    end
    return message_args
end

tooltip_resonance.get_raid_effect_message = function(effect_info)
    if effect_info == nil or effect_info.effect_type == nil or effect_info.effect_type == "" or effect_info.effect_type == "None" then
        return nil
    end

    local message_key = "SancuartyResonance_RaidEffect_"..effect_info.effect_type
    local message_args = tooltip_resonance.make_raid_effect_message_args(effect_info)
    if #message_args == 0 then
        return ScpArgMsg(message_key)
    end
    return ScpArgMsg(message_key, unpack(message_args))
end

tooltip_resonance.make_skill_raid_effect_desc_list = function(skill_name, reinforce_level)
    local result = {}
    local effect_list = shared_resonance.get_skill_reinforce_effect_list(skill_name, reinforce_level)
    if effect_list == nil then
        return result
    end

    local occurrence_count = {}
    for i = 1, #effect_list do
        local effect_info = effect_list[i]
        local effect_type = effect_info.effect_type
        if effect_type ~= nil and effect_type ~= "" and effect_type ~= "None" then
            occurrence_count[effect_type] = (occurrence_count[effect_type] or 0) + 1
            local effect_text = tooltip_resonance.get_raid_effect_message(effect_info)
            if effect_text ~= nil and effect_text ~= "" then
                result[#result + 1] = {
                    prop_name = string.format("RaidEffect_%s_%d", effect_type, occurrence_count[effect_type]),
                    text = effect_text,
					is_raid_effect = true
                }
            end
        end
    end
    return result
end

tooltip_resonance.get_skill_raid_effect_desc_list = function(skill_name, reinforce_level, is_emphasis_props)
    reinforce_level = tonumber(reinforce_level)
	local current_list = tooltip_resonance.make_skill_raid_effect_desc_list(skill_name, reinforce_level)
    if #current_list == 0 then
        return {}
    end

    local previous_map = {}
    if is_emphasis_props == true and reinforce_level > 0 then
        local previous_list = tooltip_resonance.make_skill_raid_effect_desc_list(skill_name, reinforce_level - 1)
        for i = 1, #previous_list do
            previous_map[previous_list[i].prop_name] = previous_list[i].text
        end
    end

    local result = {}
    for i = 1, #current_list do
        local info = current_list[i]
        local emphasis = false
        if is_emphasis_props == true then
            emphasis = previous_map[info.prop_name] ~= info.text
        end

        result[#result + 1] = {
            prop_name = info.prop_name,
            text = info.text,
            emphasis = emphasis,
			is_raid_effect = true
        }
    end
    return result
end

tooltip_resonance.get_skill_raid_effect_tooltip = function(skill_name, reinforce_level)
    local desc_list = tooltip_resonance.get_skill_raid_effect_desc_list(skill_name, reinforce_level, false)
    if desc_list == nil or #desc_list == 0 then
        return ""
    end

	local style_start = tooltip_resonance.raid_effect_emphasis_start
    local style_end = tooltip_resonance.raid_effect_emphasis_end
    local lines = {}

	local title = ScpArgMsg("SancuartyResonance_RaidEffectTitle")
    lines[#lines + 1] = style_start..title..style_end

    for i = 1, #desc_list do
        local text = desc_list[i].text
        if text ~= nil and text ~= "" then
            lines[#lines + 1] = style_start..text..style_end
        end
    end
    return table.concat(lines, "{nl}")
end

function get_raid_effect_tooltip_Resonance_BerserkerZawra_ChFire(obj)
    local skill_name = TryGetProp(obj, "ClassName", "None")
    if skill_name == "None" then
        return ""
    end

    local level = tooltip_resonance.get_parse_level(skill_name)
    return tooltip_resonance.get_skill_raid_effect_tooltip(skill_name, level)
end
