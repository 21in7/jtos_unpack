-- shared_leticia_prop.lua

local blessed_goddess_cube_list = nil

----------------------------------------------------------------
-- 보상 리스트 초기화
----------------------------------------------------------------
local function make_blessed_goddess_cube_list()
	if blessed_goddess_cube_list == nil then
		blessed_goddess_cube_list = {}
	end

	local clslist, cnt = GetClassList('reward_tp')
	for i = 0, cnt - 1 do
		local rewardCls = GetClassByIndexFromList(clslist, i)
		local group = TryGetProp(rewardCls, 'Group', 'None')

		local reward = {
			Group = group,
			ItemName = TryGetProp(rewardCls, 'ItemName'),
			Count = TryGetProp(rewardCls, 'Count'),
			Ratio = TryGetProp(rewardCls, 'Ratio', 0),
			Rank = TryGetProp(rewardCls, 'Rank'),
			ClassID = TryGetProp(rewardCls, 'ClassID'),
			TeamBelonging = TryGetProp(rewardCls, 'TeamBelonging', 0),
			CharacterBelonging = TryGetProp(rewardCls, 'CharacterBelonging', 0),
			NeedProperty = TryGetProp(rewardCls, 'NeedProperty'),
			NeedPropertyValue = TryGetProp(rewardCls, 'NeedPropertyValue'),
		}

		if blessed_goddess_cube_list[group] == nil then
			blessed_goddess_cube_list[group] = {}
		end
		table.insert(blessed_goddess_cube_list[group], reward)
	end
end

----------------------------------------------------------------
-- 레티시아 확률 조회
----------------------------------------------------------------
function GET_LETICIA_PROBABILITY()
	local nation = config.GetServiceNation()
	local is_papaya = (nation == 'PAPAYA')

	local start = is_papaya and 7501 or 7001
	local group_name = is_papaya and 'Gacha_TP2_001_PAPAYA' or 'Gacha_TP2_001'

	-- 전체 확률 합계 계산
	local total = 0
	for i = start, start + 100 do
		local cls = GetClassByType('reward_tp', i)
		if TryGetProp(cls, 'Group', 'None') == group_name then
			total = total + TryGetProp(cls, 'Ratio', 0)
		end
	end

	-- 확률 데이터 생성
	local ret = {}
	for i = start, start + 100 do
		local cls = GetClassByType('reward_tp', i)
		if TryGetProp(cls, 'Group', 'None') == group_name then
			local ratio = TryGetProp(cls, 'Ratio', 0)
			table.insert(ret, {
				TryGetProp(cls, 'ItemName', 'None'),
				TryGetProp(cls, 'Count', 0),
				string.format('%.5f', ratio / total * 100),
				TryGetProp(cls, 'Rank', 'None')
			})
		end
	end

	return ret
end

function GET_REWARD_GROUP_PROBABILITY(reward_group)
	if blessed_goddess_cube_list == nil then
		make_blessed_goddess_cube_list()
	end

	local reward_list = blessed_goddess_cube_list[reward_group]
	if reward_list == nil then
		return {}
	end

	local total_ratio = 0
	for _, reward in ipairs(reward_list) do
		if reward.Group == reward_group then
			total_ratio = total_ratio + reward.Ratio
		end
	end
	if total_ratio == 0 then
		return {}
	end

	local ret = {}
	for _, reward in ipairs(reward_list) do
		if reward.Group == reward_group then
			table.insert(ret, {
				reward.ItemName,
				reward.Count,
				string.format('%.5f', reward.Ratio / total_ratio * 100),
				reward.Rank
			})
		end
	end

	return ret
end

----------------------------------------------------------------
-- 헬퍼 함수들
----------------------------------------------------------------
local function GET_GODDESS_CUBE_GROUP_TABLE(ratioGroupName)
	return GET_GODDESS_CUBE_PROBABILITY()
end

----------------------------------------------------------------
-- 축복받은 여신 큐브 공용 함수 (item_gacha.lua에서도 사용)
----------------------------------------------------------------

-- 그룹명에 접미사 추가
function BLESSED_CUBE_APPEND_SUFFIX(base_name, is_papaya, is_event)
	local result = base_name
	if is_papaya then
		result = result .. '_PAPAYA'
	end
	if is_event then
		result = result .. '_EVENT'
	end
	return result
end

-- 등급별 New/Old 풀 설정 반환
-- @return pool_prefixes, pool_ratios (C등급은 nil, nil)
function BLESSED_CUBE_GET_POOL_CONFIG(rank, is_papaya, is_event)
	-- C등급: New/Old 구분 없음
	if rank == 'C' then
		return nil, nil
	-- S등급: EVENT는 100% New, 그 외 50%/50%
	elseif rank == 'S' then
		if is_event then
			return {'Blessed_New_'}, {1.0}
		else
			return {'Blessed_New_', 'Blessed_Old_'}, {0.5, 0.5}
		end
	-- A/B등급: PAPAYA/EVENT는 100% New, 그 외 35%/65%
	else
		if is_papaya or is_event then
			return {'Blessed_New_'}, {1.0}
		else
			return {'Blessed_New_', 'Blessed_Old_'}, {0.35, 0.65}
		end
	end
end

-- New/Old 풀 선택 (확률 기반)
function BLESSED_CUBE_SELECT_POOL(rank, is_papaya, is_event)
	local pool_prefixes, pool_ratios = BLESSED_CUBE_GET_POOL_CONFIG(rank, is_papaya, is_event)
	-- 풀이 없거나 하나만 있으면 첫 번째 반환
	if pool_prefixes == nil then
		return nil
	end
	if #pool_prefixes == 1 then
		return pool_prefixes[1]
	end

	-- 확률 기반 선택 (첫 번째 풀 확률 기준)
	local rand = IMCRandom(1, 10000)
	local threshold = pool_ratios[1] * 10000

	if rand <= threshold then
		return pool_prefixes[1]
	else
		return pool_prefixes[2]
	end
end

-- C등급 그룹명 생성
function BLESSED_CUBE_GET_C_RANK_GROUP_NAME(is_papaya, is_event, reward_list)
	local base_name = is_papaya and 'Blessed_HairAcc_C_PAPAYA' or 'Blessed_HairAcc_C'

	if is_event then
		local event_name = base_name .. '_EVENT'
		-- reward_list가 제공된 경우 이벤트 그룹 존재 여부 확인
		if reward_list ~= nil then
			if reward_list[event_name] then
				return event_name
			else
				return base_name
			end
		end
		return event_name
	end

	return base_name
end

-- 보상 리스트의 전체 확률 합계 계산
local function calc_total_ratio(clslist, group_name)
	local total = 0
	if clslist then
		for _, reward in ipairs(clslist) do
			if reward.Group == group_name then
				total = total + reward.Ratio
			end
		end
	end
	return total
end

-- 풀별 확률 데이터 수집
local function collect_pool_probability(clslist, group_name, parent_ratio, pool_ratio, rank, table_list)
	local total_ratio = calc_total_ratio(clslist, group_name)
	if total_ratio == 0 then
		return
	end

	for _, reward in ipairs(clslist) do
		if reward.Group == group_name then
			local ratio = reward.Ratio / total_ratio * parent_ratio * pool_ratio
			table.insert(table_list, {
				reward.ItemName,
				reward.Count,
				string.format('%.5f', ratio * 100),
				rank
			})
		end
	end
end

----------------------------------------------------------------
-- 축복받은 여신 큐브 확률 조회 (메인 함수)
----------------------------------------------------------------
function GET_GODDESS_CUBE_PROBABILITY(reward_group)
	if blessed_goddess_cube_list == nil then
		make_blessed_goddess_cube_list()
	end

	local nation = config.GetServiceNation()
	local is_papaya = (nation == 'PAPAYA')
	local is_event = (reward_group == 'Gacha_Blessed_CUBE_001_EVENT')

	-- PAPAYA 접미사 추가
	if is_papaya then
		reward_group = reward_group .. '_PAPAYA'
	end

	local clslist = blessed_goddess_cube_list[reward_group]
	if clslist == nil then
		return {}
	end

	-- 등급별 확률 수집
	local grade_ratios = {}
	local total_ratio = 0

	for _, reward in ipairs(clslist) do
		if reward.Group == reward_group then
			local rank = reward.Rank
			if grade_ratios[rank] == nil then
				grade_ratios[rank] = 0
			end
			grade_ratios[rank] = grade_ratios[rank] + reward.Ratio
			total_ratio = total_ratio + reward.Ratio
		end
	end

	-- 확률 데이터 생성 (S, A, B, C 순서 보장)
	local table_list = {}
	local grade_order = {'S', 'A', 'B', 'C'}

	for _, rank in ipairs(grade_order) do
		local rank_ratio = grade_ratios[rank]
		if rank_ratio == nil then
			goto continue
		end

		local parent_ratio = rank_ratio / total_ratio

		if rank == 'C' then
			-- C등급: 단일 풀
			local group_name = BLESSED_CUBE_GET_C_RANK_GROUP_NAME(is_papaya, is_event)
			local pool_list = blessed_goddess_cube_list[group_name]
			if pool_list then
				collect_pool_probability(pool_list, group_name, parent_ratio, 1, rank, table_list)
			end
		else
			-- S/A/B등급: New/Old 풀
			local pool_prefixes, pool_ratios = BLESSED_CUBE_GET_POOL_CONFIG(rank, is_papaya, is_event)
			for i, prefix in ipairs(pool_prefixes) do
				local group_name = BLESSED_CUBE_APPEND_SUFFIX(prefix .. rank, is_papaya, is_event)
				local pool_list = blessed_goddess_cube_list[group_name]
				if pool_list then
					collect_pool_probability(pool_list, group_name, parent_ratio, pool_ratios[i], rank, table_list)
				end
			end
		end

		::continue::
	end

	return table_list
end
