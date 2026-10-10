-- EquipBossCard V2 Effect/Param 데이터를 일반·여신 카드 UI가 함께 쓰는 표시 행으로 변환한다.
-- client AddOn 전용 모듈이며 server handler Lua와 VM 및 수명주기를 공유하지 않는다.
-- 세트 효과는 기존 SetItem 전용 툴팁 영역에서만 표시하므로 카드첩의 일반 옵션 행에는 합치지 않는다.

local EQUIPBOSSCARD_V2_EFFECT_INDEX = nil
local EQUIPBOSSCARD_V2_SET_EFFECT_INDEX = nil
local EQUIPBOSSCARD_V2_PARAM_INDEX = nil
local EQUIPBOSSCARD_V2_SET_INDEX = nil
local EQUIPBOSSCARD_V2_SETS_BY_CARD = nil

-- create="open" AddOn을 client 시작 시 선로드하기 위한 진입점이다.
-- 이 모듈은 UI frame이나 메시지 listener를 소유하지 않는다.
function EQUIPBOSSCARD_V2_ON_INIT(addon, frame)
end

-- 카드 부모 행이 명시적인 V2 schema인지 판정한다.
function EQUIPBOSSCARD_V2_IS_CARD(cardInfo)
	if cardInfo == nil then
		return false
	end
	return TryGetProp(cardInfo, 'EffectSchemaVersion', 1) == 2
end

-- Effect/Param IES를 최초 요청 시 한 번만 정규화한다.
-- 서버 cache와 동일하게 effect는 (EffectOrder, ClassID), param은 (ParamOrder, ClassID) 순서를 사용한다.
local function EQUIPBOSSCARD_V2_BUILD_CLIENT_INDEX()
	if EQUIPBOSSCARD_V2_EFFECT_INDEX ~= nil then
		return
	end

	EQUIPBOSSCARD_V2_EFFECT_INDEX = {}
	EQUIPBOSSCARD_V2_SET_EFFECT_INDEX = {}
	EQUIPBOSSCARD_V2_PARAM_INDEX = {}
	EQUIPBOSSCARD_V2_SET_INDEX = {}
	EQUIPBOSSCARD_V2_SETS_BY_CARD = {}

	local effectList, effectCount = GetClassList('EquipBossCardEffect')
	if effectList ~= nil then
		for i = 0, effectCount - 1 do
			local effect = GetClassByIndexFromList(effectList, i)
			if effect ~= nil and TryGetProp(effect, 'Enabled', 1) == 1 then
				local cardClassName = TryGetProp(effect, 'CardClassName', 'None')
				if cardClassName ~= 'None' then
					if EQUIPBOSSCARD_V2_EFFECT_INDEX[cardClassName] == nil then
						EQUIPBOSSCARD_V2_EFFECT_INDEX[cardClassName] = {}
					end
					table.insert(EQUIPBOSSCARD_V2_EFFECT_INDEX[cardClassName], effect)
				else
					local setClassName = TryGetProp(effect, 'SetClassName', 'None')
					if setClassName ~= 'None' then
						if EQUIPBOSSCARD_V2_SET_EFFECT_INDEX[setClassName] == nil then
							EQUIPBOSSCARD_V2_SET_EFFECT_INDEX[setClassName] = {}
						end
						table.insert(EQUIPBOSSCARD_V2_SET_EFFECT_INDEX[setClassName], effect)
					end
				end
			end
		end
	end

	local function sortEffects(effects)
		table.sort(effects, function(lhs, rhs)
			local lhsOrder = tonumber(TryGetProp(lhs, 'EffectOrder', 0)) or 0
			local rhsOrder = tonumber(TryGetProp(rhs, 'EffectOrder', 0)) or 0
			if lhsOrder ~= rhsOrder then
				return lhsOrder < rhsOrder
			end
			return (tonumber(TryGetProp(lhs, 'ClassID', 0)) or 0) <
				(tonumber(TryGetProp(rhs, 'ClassID', 0)) or 0)
		end)
	end
	for _, effects in pairs(EQUIPBOSSCARD_V2_EFFECT_INDEX) do
		sortEffects(effects)
	end
	for _, effects in pairs(EQUIPBOSSCARD_V2_SET_EFFECT_INDEX) do
		sortEffects(effects)
	end

	local setList, setCount = GetClassList('EquipBossCardSet')
	if setList ~= nil then
		for i = 0, setCount - 1 do
			local setInfo = GetClassByIndexFromList(setList, i)
			if setInfo ~= nil and TryGetProp(setInfo, 'Enabled', 1) == 1 then
				local setClassName = TryGetProp(setInfo, 'ClassName', 'None')
				if setClassName ~= 'None' then
					EQUIPBOSSCARD_V2_SET_INDEX[setClassName] = {
						info = setInfo,
						members = {},
					}
				end
			end
		end
	end

	local memberList, memberCount = GetClassList('EquipBossCardSetMember')
	if memberList ~= nil then
		for i = 0, memberCount - 1 do
			local member = GetClassByIndexFromList(memberList, i)
			if member ~= nil then
				local setClassName = TryGetProp(member, 'SetClassName', 'None')
				local cardClassName = TryGetProp(member, 'CardClassName', 'None')
				local setRecord = EQUIPBOSSCARD_V2_SET_INDEX[setClassName]
				if setRecord ~= nil and cardClassName ~= 'None' then
					table.insert(setRecord.members, member)
					if EQUIPBOSSCARD_V2_SETS_BY_CARD[cardClassName] == nil then
						EQUIPBOSSCARD_V2_SETS_BY_CARD[cardClassName] = {}
					end
					table.insert(EQUIPBOSSCARD_V2_SETS_BY_CARD[cardClassName], setRecord)
				end
			end
		end
	end

	for _, setRecord in pairs(EQUIPBOSSCARD_V2_SET_INDEX) do
		table.sort(setRecord.members, function(lhs, rhs)
			local lhsOrder = tonumber(TryGetProp(lhs, 'MemberOrder', 0)) or 0
			local rhsOrder = tonumber(TryGetProp(rhs, 'MemberOrder', 0)) or 0
			if lhsOrder ~= rhsOrder then
				return lhsOrder < rhsOrder
			end
			return (tonumber(TryGetProp(lhs, 'ClassID', 0)) or 0) <
				(tonumber(TryGetProp(rhs, 'ClassID', 0)) or 0)
		end)
	end
	for _, setRecords in pairs(EQUIPBOSSCARD_V2_SETS_BY_CARD) do
		table.sort(setRecords, function(lhs, rhs)
			local lhsOrder = tonumber(TryGetProp(lhs.info, 'SetOrder', 0)) or 0
			local rhsOrder = tonumber(TryGetProp(rhs.info, 'SetOrder', 0)) or 0
			if lhsOrder ~= rhsOrder then
				return lhsOrder < rhsOrder
			end
			return (tonumber(TryGetProp(lhs.info, 'ClassID', 0)) or 0) <
				(tonumber(TryGetProp(rhs.info, 'ClassID', 0)) or 0)
		end)
	end

	local paramList, paramCount = GetClassList('EquipBossCardEffectParam')
	if paramList ~= nil then
		local paramRows = {}
		for i = 0, paramCount - 1 do
			local param = GetClassByIndexFromList(paramList, i)
			if param ~= nil then
				table.insert(paramRows, param)
			end
		end
		table.sort(paramRows, function(lhs, rhs)
			local lhsOrder = tonumber(TryGetProp(lhs, 'ParamOrder', 0)) or 0
			local rhsOrder = tonumber(TryGetProp(rhs, 'ParamOrder', 0)) or 0
			if lhsOrder ~= rhsOrder then
				return lhsOrder < rhsOrder
			end
			return (tonumber(TryGetProp(lhs, 'ClassID', 0)) or 0) <
				(tonumber(TryGetProp(rhs, 'ClassID', 0)) or 0)
		end)

		for _, param in ipairs(paramRows) do
			local effectClassName = TryGetProp(param, 'EffectClassName', 'None')
			local paramKey = TryGetProp(param, 'ParamKey', 'None')
			if effectClassName ~= 'None' and paramKey ~= 'None' then
				if EQUIPBOSSCARD_V2_PARAM_INDEX[effectClassName] == nil then
					EQUIPBOSSCARD_V2_PARAM_INDEX[effectClassName] = {}
				end
				local paramType = TryGetProp(param, 'ParamType', 'String')
				local value = TryGetProp(param, 'StringValue', 'None')
				if paramType == 'Number' then
					value = tonumber(TryGetProp(param, 'NumberValue', 0)) or 0
				elseif paramType == 'Boolean' then
					value = (tonumber(TryGetProp(param, 'NumberValue', 0)) or 0) == 1
				end
				EQUIPBOSSCARD_V2_PARAM_INDEX[effectClassName][paramKey] = value
			end
		end
	end
end

-- cardClassName에 연결된 활성 effect를 서버와 같은 결정적 순서로 반환한다.
function EQUIPBOSSCARD_V2_GET_EFFECT_ROWS(cardClassName)
	EQUIPBOSSCARD_V2_BUILD_CLIENT_INDEX()
	return EQUIPBOSSCARD_V2_EFFECT_INDEX[cardClassName] or {}
end

-- Lua number의 정수 여부를 보존해 tooltip token 문자열로 바꾼다.
local function EQUIPBOSSCARD_V2_FORMAT_TOKEN_VALUE(value)
	if type(value) == 'number' and value == math.floor(value) then
		return string.format('%d', value)
	end
	return tostring(value)
end

-- 같은 카드들의 장착 레벨로 모든 공용 표시 집계값을 계산한다.
local function EQUIPBOSSCARD_V2_BUILD_DISPLAY_CONTEXT(cardLevels, stackPolicy)
	local context = {
		EquippedCount = #cardLevels,
		TotalStar = 0,
		MaxStar = 0,
		MinStar = 0,
	}
	for _, level in ipairs(cardLevels) do
		local numberLevel = tonumber(level) or 0
		context.TotalStar = context.TotalStar + numberLevel
		context.MaxStar = math.max(context.MaxStar, numberLevel)
		if context.MinStar == 0 or numberLevel < context.MinStar then
			context.MinStar = numberLevel
		end
	end

	if stackPolicy == 'CardCount' then
		context.Aggregate = context.EquippedCount
	elseif stackPolicy == 'MaxStar' then
		context.Aggregate = context.MaxStar
	elseif stackPolicy == 'MinStar' then
		context.Aggregate = context.MinStar
	else
		context.Aggregate = context.TotalStar
	end
	return context
end

-- 대문자로 시작하는 named token만 치환해 TOS `{s16}` 같은 markup을 보존한다.
local function EQUIPBOSSCARD_V2_REPLACE_NAMED_TOKENS(optionText, context, params)
	return string.gsub(optionText, '{([A-Z][A-Za-z0-9_]*)}', function(key)
		local value = context[key]
		if value == nil then
			value = params[key]
		end
		if value == nil then
			IMC_LOG('ERROR_EQUIP_BOSS_CARD_V2_UI', 'Unresolved tooltip token: '..tostring(key))
			return '{'..key..'}'
		end
		return EQUIPBOSSCARD_V2_FORMAT_TOKEN_VALUE(value)
	end)
end

-- 하나의 V2 카드를 임의 개수의 독립 UI 행으로 변환한다.
-- cardLevels는 동일 ClassName으로 현재 장착된 모든 카드 레벨이며 위치별 고정 인자는 만들지 않는다.
function EQUIPBOSSCARD_V2_BUILD_OPTION_ROWS(cardClassName, cardLevels)
	local optionRows = {}
	EQUIPBOSSCARD_V2_BUILD_CLIENT_INDEX()

	local function appendEffect(effect, context)
		local effectClassName = TryGetProp(effect, 'ClassName', 'None')
		local params = EQUIPBOSSCARD_V2_PARAM_INDEX[effectClassName] or {}
		-- effect별 배율이 있으면 V1 UI의 `별 합계 × OptionTextValue`와 같은 최종 표시값을 제공한다.
		local valuePerAggregate = tonumber(params.ValuePerAggregate)
		if valuePerAggregate ~= nil then
			context.CalculatedValue = context.Aggregate * valuePerAggregate
		end
		local displayPolicy = TryGetProp(effect, 'DisplayPolicy', 'Show')
		local optionText = nil

		if displayPolicy == 'Show' then
			optionText = TryGetProp(effect, 'OptionText', 'None')
			if optionText ~= 'None' then
				optionText = dictionary.ReplaceDicIDInCompStr(optionText)
				optionText = EQUIPBOSSCARD_V2_REPLACE_NAMED_TOKENS(optionText, context, params)
			else
				optionText = nil
			end
		elseif displayPolicy == 'Custom' then
			local handlerName = TryGetProp(effect, 'TooltipHandler', 'None')
			local handler = _G[handlerName]
			if type(handler) == 'function' then
				local ok, result = pcall(handler, cardClassName, cardLevels, effect, params, context)
				if ok and type(result) == 'string' then
					optionText = result
				elseif not ok then
					IMC_LOG('ERROR_EQUIP_BOSS_CARD_V2_UI',
						'Tooltip handler error: '..tostring(handlerName)..', message: '..tostring(result))
				end
			else
				IMC_LOG('ERROR_EQUIP_BOSS_CARD_V2_UI', 'Missing tooltip handler: '..tostring(handlerName))
			end
		end

		if optionText ~= nil then
			table.insert(optionRows, {
				effectClassName = effectClassName,
				effectClassID = tonumber(TryGetProp(effect, 'ClassID', 0)) or 0,
				effectOrder = tonumber(TryGetProp(effect, 'EffectOrder', 0)) or 0,
				text = optionText,
			})
		end
	end

	for _, effect in ipairs(EQUIPBOSSCARD_V2_GET_EFFECT_ROWS(cardClassName)) do
		appendEffect(
			effect,
			EQUIPBOSSCARD_V2_BUILD_DISPLAY_CONTEXT(
				cardLevels,
				TryGetProp(effect, 'StackPolicy', 'SumStar')
			)
		)
	end

	return optionRows
end
