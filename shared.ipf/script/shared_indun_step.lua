-- shared_indun_step
shared_indun_step = {}
shared_indun_step.step_info = {}

shared_indun_step.MISSION_ARG_STEP = "INDUN_SELECT_STEP"
shared_indun_step.MISSION_ARG_REWARD_BONUS = "INDUN_SELECT_STEP_REWARD_BONUS"

local function to_number(value, default_value)
	local number_value = tonumber(value)
	if number_value == nil then
		return default_value
	end
	return number_value
end

local function is_yes(value)
	return value == "YES" or value == 1 or value == true
end

local function make_step_info(cls)
	if cls == nil then
		return nil
	end

	local info = {
		class_id = TryGetProp(cls, "ClassID", 0),
		class_name = TryGetProp(cls, "ClassName", "None"),
		indun_type = to_number(TryGetProp(cls, "IndunType", 0), 0),
		step = to_number(TryGetProp(cls, "Step", 0), 0),
		gear_score = to_number(TryGetProp(cls, "GearScore", 0), 0),
		ability_score = to_number(TryGetProp(cls, "AbilityScore", 0), 0),
		reward_bonus = to_number(TryGetProp(cls, "RewardBonus", 0), 0),
		boss_atk_rate = to_number(TryGetProp(cls, "BossATKRate", 0), 0),
		boss_def_rate = to_number(TryGetProp(cls, "BossDEFRate", 0), 0),
		boss_mhp_rate = to_number(TryGetProp(cls, "BossMHPRate", 0), 0),
		default_unlock = TryGetProp(cls, "DefaultUnlocked", "NO"),
		unlocked_step_prop_name = TryGetProp(cls, "UnlockedStepPropName", "None"),
	}
	info.is_default_unlocked = is_yes(info.default_unlock)
	return info
end

local function build_step_list(indun_type)
	local ret = {}
	local list, cnt = GetClassList("indun_step")
	if list == nil or cnt == nil or cnt <= 0 then
		return ret
	end

	for i = 0, cnt - 1 do
		local cls = GetClassByIndexFromList(list, i)
		local info = make_step_info(cls)
		if info ~= nil and info.indun_type == indun_type and info.step > 0 then
			ret[#ret + 1] = info
		end
	end

	table.sort(ret, function(a, b)
		return a.step < b.step
	end)

	return ret
end

function shared_indun_step.clear_cache(indun_type)
	if indun_type == nil then
		shared_indun_step.step_info = {}
		return
	end
	shared_indun_step.step_info[indun_type] = nil
end

function shared_indun_step.get_list(indun_type)
	indun_type = to_number(indun_type, 0)
	if indun_type <= 0 then
		return {}
	end

	if shared_indun_step.step_info[indun_type] == nil then
		shared_indun_step.step_info[indun_type] = build_step_list(indun_type)
	end

	return shared_indun_step.step_info[indun_type]
end

function shared_indun_step.get_info(indun_type, step)
	step = to_number(step, 0)
	if step <= 0 then
		return nil
	end

	local list = shared_indun_step.get_list(indun_type)
	for i = 1, #list do
		if list[i].step == step then
			return list[i]
		end
	end
	return nil
end

function shared_indun_step.is_valid_step(indun_type, step)
	return shared_indun_step.get_info(indun_type, step) ~= nil
end

function shared_indun_step.is_default_unlocked(indun_type, step)
	local info = shared_indun_step.get_info(indun_type, step)
	if info == nil then
		return false
	end
	return info.is_default_unlocked == true
end

function shared_indun_step.is_unlocked(pc, indun_type, step)
	if step <= 0 then
		return false
	end

	local info = shared_indun_step.get_info(indun_type, step)
	if info == nil then
		return false
	end

	local unlocked_step = shared_indun_step.get_unlocked_step(pc, indun_type)
	return step <= unlocked_step
end

function shared_indun_step.get_first_unlocked_step(pc, indun_type)
	local list = shared_indun_step.get_list(indun_type)
	local unlocked_step = shared_indun_step.get_unlocked_step(pc, indun_type)
	local first_step = 0
	for i = 1, #list do
		local info = list[i]
		if info ~= nil and info.step <= unlocked_step then
			first_step = info.step
		end
	end
	return first_step
end

function shared_indun_step.get_max_step(indun_type)
	local list = shared_indun_step.get_list(indun_type)
	local max_step = 0
	for i = 1, #list do
		if list[i].step > max_step then
			max_step = list[i].step
		end
	end
	return max_step
end

function shared_indun_step.get_default_unlocked_step(indun_type)
    local list = shared_indun_step.get_list(indun_type)
    local max_step = 0
    for i = 1, #list do
        local info = list[i]
        if info ~= nil and info.is_default_unlocked == true then
            max_step = math.max(max_step, info.step)
        end
    end
    return max_step
end

function shared_indun_step.get_step_btn_skin(is_unlocked, step, selected_step)
	if is_unlocked == false then
		return "cupole_btn2"
	elseif step == selected_step then
		return "cupole_border_btn"
	else
		return "cupole_btn"
	end
end

function shared_indun_step.get_step_btn_text(is_unlocked, step, selected_step)
	if is_unlocked == false then
		return "{@st66d}{s22}"..tostring(step).."{/}"
	elseif step == selected_step then
		return "{@st66d}{s22}"..tostring(step).."{/}"
	else
		return "{@st42b}{s22}"..tostring(step).."{/}"
	end
end

function shared_indun_step.get_unlock_target_obj(pc, indun_type)
	if pc == nil then
		return nil, "None"
	end

	local indun_cls = GetClassByType("Indun", indun_type)
	if indun_cls == nil then
		return nil, "None"
	end

	local unit_per_reset = TryGetProp(indun_cls, "UnitPerReset", "None")
	if unit_per_reset == "ACCOUNT" then
		if IsServerSection() == 1 then
			return GetAccountObj(pc), unit_per_reset
		else
			return GetMyAccountObj(), unit_per_reset
		end
	end

	if unit_per_reset == "PC" then
		if IsServerSection() == 1 then
			return GetETCObject(pc), unit_per_reset
		else
			return GetMyEtcObject(), unit_per_reset
		end
	end
	return nil, "None"
end

function shared_indun_step.get_unlocked_step_prop_name(indun_type)
    local list = shared_indun_step.get_list(indun_type)
    for i = 1, #list do
        local prop_name = list[i].unlocked_step_prop_name
        if prop_name ~= nil and prop_name ~= "None" and prop_name ~= "" then
            return prop_name
        end
    end
    return "None"
end

function shared_indun_step.get_saved_unlocked_step(pc, indun_type)
    local obj = shared_indun_step.get_unlock_target_obj(pc, indun_type)
    if obj == nil then
        return 0
    end

    local prop_name = shared_indun_step.get_unlocked_step_prop_name(indun_type)
    if prop_name == "None" then
        return 0
    end

    return TryGetProp(obj, prop_name, 0)
end

function shared_indun_step.get_unlocked_step(pc, indun_type)
    local default_step = shared_indun_step.get_default_unlocked_step(indun_type)
    local saved_step = shared_indun_step.get_saved_unlocked_step(pc, indun_type)
    return math.max(default_step, saved_step)
end