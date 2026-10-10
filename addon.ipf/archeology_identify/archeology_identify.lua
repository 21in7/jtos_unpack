local function ARCHEOLOGY_IDENTIFY_REFRESH_MODE_INFO(frame)
	local mode = frame:GetUserValue('MATERIAL_MODE')
	local modeText = GET_CHILD_RECURSIVELY(frame, 'modeText')
	local costText = GET_CHILD_RECURSIVELY(frame, 'costText')
	-- 구형 유물이 정리되면 구형/신규 구분이 의미 없으므로 신규 모드에서는 라벨을 숨긴다.
	if mode == 'LEGACY' then
		modeText:SetTextByKey('mode', ClMsg('ARCHEOLOGY_IDENTIFY_MODE_LABEL_LEGACY'))
		costText:SetTextByKey('cost', ClMsg('ARCHEOLOGY_IDENTIFY_COST_LEGACY'))
		modeText:ShowWindow(1)
		costText:SetMargin(0, 23, 0, 0)
	else
		modeText:SetTextByKey('mode', '')
		costText:SetTextByKey('cost', ClMsg('ARCHEOLOGY_IDENTIFY_COST_NEW'))
		modeText:ShowWindow(0)
		costText:SetMargin(0, 11, 0, 0)
	end

	costText:ShowWindow(1)
end

function ARCHEOLOGY_IDENTIFY_ON_INIT(addon, frame)
	addon:RegisterMsg('OPEN_DLG_ARCHEOLOGY_IDENTIFY', 'ON_OPEN_DLG_ARCHEOLOGY_IDENTIFY')
	addon:RegisterMsg('SUCCESS_ARCH_IDENTIFY', 'ON_SUCCESS_ARCH_IDENTIFY')
	addon:RegisterMsg('ARCHEOLOGY_IDENTIFY_FINISHED', 'ON_ARCHEOLOGY_IDENTIFY_FINISHED')
end

local function ARCHEOLOGY_IDENTIFY_OPEN_WITH_MODE(mode)
	local current = ui.GetFrame("archeology_identify")
	if current:GetUserValue("IDENTIFY_PENDING") == "YES" then return end
	local frame = ui.GetFrame('archeology_identify')
	frame:SetUserValue('MATERIAL_MODE', mode)
	ui.OpenFrame('archeology_identify')
	ARCHEOLOGY_IDENTIFY_REFRESH_MODE_INFO(frame)
end

function OPEN_ARCHEOLOGY_IDENTIFY_UI()
	-- 기존 Ancient_Fragment의 CT_ClientScp가 이 호환 진입점을 사용한다.
	ARCHEOLOGY_IDENTIFY_OPEN_WITH_MODE('LEGACY')
end

function OPEN_ARCHEOLOGY_IDENTIFY_LEGACY_UI()
	ARCHEOLOGY_IDENTIFY_OPEN_WITH_MODE('LEGACY')
end

function OPEN_ARCHEOLOGY_IDENTIFY_NEW_UI()
	ARCHEOLOGY_IDENTIFY_OPEN_WITH_MODE('NEW')
end

function ON_OPEN_DLG_ARCHEOLOGY_IDENTIFY(frame, msg, argStr, argNum)
	ARCHEOLOGY_IDENTIFY_UI_RESET()

	local invframe = ui.GetFrame('inventory')
	invframe:ShowWindow(1)

	local frame = ui.GetFrame('archeology_identify')
	frame:ShowWindow(1)

	INVENTORY_PUSH_CUSTOM_RBTNDOWN(frame, 'ARCHEOLOGY_IDENTIFY_INV_RBTN')
end

local function ARCHEOLOGY_IDENTIFY_IS_EMPTY_META(meta)
	return meta == nil or meta == '' or meta == 'None'
end

local function ARCHEOLOGY_IDENTIFY_COUNT_META(meta)
	if ARCHEOLOGY_IDENTIFY_IS_EMPTY_META(meta) == true then
		return 0
	end

	local tokens = StringSplit(meta, ',')
	local count = 0
	for _, token in ipairs(tokens) do
		if token ~= nil and token ~= '' then
			count = count + 1
		end
	end
	return count
end

local function ARCHEOLOGY_IDENTIFY_MERGE_META(prefixMeta, suffixMeta)
	local hasPrefix = ARCHEOLOGY_IDENTIFY_IS_EMPTY_META(prefixMeta) == false
	local hasSuffix = ARCHEOLOGY_IDENTIFY_IS_EMPTY_META(suffixMeta) == false

	if hasPrefix == true and hasSuffix == true then
		return prefixMeta .. ',' .. suffixMeta
	end
	if hasPrefix == true then
		return prefixMeta
	end
	if hasSuffix == true then
		return suffixMeta
	end
	return 'None'
end

local function ARCHEOLOGY_IDENTIFY_SET_OPTION_TEXT(ctrl, prefixMeta, suffixMeta)
	if ctrl == nil then
		return 0
	end
	local mergedMeta = ARCHEOLOGY_IDENTIFY_MERGE_META(prefixMeta, suffixMeta)
	local results = mergedMeta ~= 'None' and
		GET_ARCHEOLOGY_OPTION_INFO(mergedMeta) or {}
	for i = 1, 4 do
		local optionText = ''
		if results ~= nil and results[i] ~= nil then
			optionText = ScpArgMsg('ARCHEOLOGY_OPTION_LINE{DESC}',
				'DESC', GET_ARCHEOLOGY_STAT_DESC(results[i].tag, results[i].value))
		end
		ctrl:SetTextByKey('option' .. i, optionText)
	end
	return results ~= nil and #results or 0
end

local function ARCHEOLOGY_IDENTIFY_IS_LEGACY_ITEM(exhibitionItem)
	if exhibitionItem == nil then
		return false
	end

	local classID = tonumber(TryGetProp(exhibitionItem, 'ClassID', 0)) or 0
	if classID <= 0 or classID >= 100 then
		return false
	end

	local optionPool = TryGetProp(exhibitionItem, 'OptionPool', '')
	local optionCount = tonumber(TryGetProp(exhibitionItem, 'OptionCount', 0)) or 0
	return optionPool ~= '' and optionPool ~= 'None' and optionCount > 0
end

-- 신규/구형 유물 모두 공용 룰 프로필에서 감정 가능한 최대 옵션 수를 읽는다.
local function ARCHEOLOGY_IDENTIFY_GET_OPTION_LIMITS(exhibitionItem)
	local profile = shared_archeology.get_exhibition_item_profile(exhibitionItem)
	if profile == nil then
		return 0, 0
	end

	return tonumber(profile.maxPrefix) or 0, tonumber(profile.maxSuffix) or 0
end

local function ARCHEOLOGY_IDENTIFY_GET_COST_TEXT(exhibitionItem)
	if ARCHEOLOGY_IDENTIFY_IS_LEGACY_ITEM(exhibitionItem) == true then
		return ClMsg('ARCHEOLOGY_IDENTIFY_COST_LEGACY')
	end
	return ClMsg('ARCHEOLOGY_IDENTIFY_COST_NEW')
end

local function ARCHEOLOGY_IDENTIFY_IS_MODE_MATCH(frame, exhibitionItem)
	local mode = frame:GetUserValue('MATERIAL_MODE')
	local isLegacy = ARCHEOLOGY_IDENTIFY_IS_LEGACY_ITEM(exhibitionItem)
	if mode == 'LEGACY' then
		return isLegacy == true
	end
	if mode == 'NEW' then
		return isLegacy == false
	end
	return true
end

function ARCHEOLOGY_OPEN_RELIC_FROM_INVENTORY(invItem)
	if invItem == nil then return false end
	local obj = GetIES(invItem:GetObject())
	local exhibitionItem = GetClass('archeology_exhibition_item',
		TryGetProp(obj, 'ClassName', 'None'))
	if exhibitionItem == nil then return false end

	local arcPrefix = TryGetProp(obj, 'Arc_Prefix', 'None')
	local arcSuffix = TryGetProp(obj, 'Arc_Suffix', 'None')
	local isLegacy = ARCHEOLOGY_IDENTIFY_IS_LEGACY_ITEM(exhibitionItem)
	local maxPrefix, maxSuffix = ARCHEOLOGY_IDENTIFY_GET_OPTION_LIMITS(exhibitionItem)
	local prefixCount = ARCHEOLOGY_IDENTIFY_COUNT_META(arcPrefix)
	local suffixCount = ARCHEOLOGY_IDENTIFY_COUNT_META(arcSuffix)
	if isLegacy then
		prefixCount = prefixCount + suffixCount
		suffixCount = 0
	end
	local pendingStage = arcPrefix:sub(1, 7) == 'STAGE1:' or
		arcSuffix:sub(1, 7) == 'STAGE1:'
	if pendingStage or prefixCount < maxPrefix or suffixCount < maxSuffix then
		if isLegacy then
			OPEN_ARCHEOLOGY_IDENTIFY_LEGACY_UI()
		else
			OPEN_ARCHEOLOGY_IDENTIFY_NEW_UI()
		end
		local frame = ui.GetFrame('archeology_identify')
		if frame ~= nil and frame:IsVisible() == 1 then
			ARCHEOLOGY_IDENTIFY_REG_ITEM(GET_CHILD_RECURSIVELY(frame, 'slot'), invItem)
		end
	else
		OPEN_ARCHEOLOGY_EXHIBITION_UI()
	end
	return true
end

local function ARCHEOLOGY_IDENTIFY_REFRESH(frame, prefixMeta, suffixMeta)
	local maxPrefix   = tonumber(frame:GetUserValue('MAX_PREFIX')) or 0
	local maxSuffix   = tonumber(frame:GetUserValue('MAX_SUFFIX')) or 0
	local prefixCount = ARCHEOLOGY_IDENTIFY_COUNT_META(prefixMeta)
	local suffixCount = ARCHEOLOGY_IDENTIFY_COUNT_META(suffixMeta)
	if frame:GetUserValue('LEGACY_ITEM') == 'YES' then
		prefixCount = prefixCount + suffixCount
		suffixCount = 0
	end
	local remainPrefix = math.max(maxPrefix - prefixCount, 0)
	local remainSuffix = math.max(maxSuffix - suffixCount, 0)

	frame:SetUserValue('ARC_PREFIX', prefixMeta or 'None')
	frame:SetUserValue('ARC_SUFFIX', suffixMeta or 'None')

	local statusText   = GET_CHILD_RECURSIVELY(frame, 'prefixText')
	local identifyBtn  = GET_CHILD_RECURSIVELY(frame, 'prefixBtn')
	local resultText   = GET_CHILD_RECURSIVELY(frame, 'resultText')

	local remainTotal = remainPrefix + remainSuffix
	local total       = maxPrefix + maxSuffix
	local current     = prefixCount + suffixCount

	-- 상태 메시지에 진행도 포함
	if remainTotal > 0 then
		if total > 0 then
			statusText:SetTextByKey('text', ScpArgMsg(
				'ARCHEOLOGY_IDENTIFY_STATUS_PROGRESS{CURRENT}{TOTAL}',
				'CURRENT', current, 'TOTAL', total))
		else
			statusText:SetTextByKey('text', ClMsg('ARCHEOLOGY_IDENTIFY_STATUS_AVAILABLE'))
		end
	else
		statusText:SetTextByKey('text', ClMsg('ARCHEOLOGY_IDENTIFY_STATUS_COMPLETE'))
	end

	identifyBtn:ShowWindow(remainTotal > 0 and 1 or 0)

	local optionCount = ARCHEOLOGY_IDENTIFY_SET_OPTION_TEXT(resultText, prefixMeta, suffixMeta)
	if optionCount > 0 then
		resultText:ShowWindow(1)
	else
		resultText:ShowWindow(0)
	end
end

local function ARCHEOLOGY_IDENTIFY_PARSE_SUCCESS_ARG(argStr)
	if argStr == nil or argStr == '' then
		return 'None', 'None'
	end

	if string.sub(argStr, 1, 9) == 'ARCIDENT|' then
		local body = string.sub(argStr, 10)
		local parts = StringSplit(body, '|')
		return parts[1] or 'None', parts[2] or 'None'
	end

	return argStr, 'None'
end

function ON_SUCCESS_ARCH_IDENTIFY(frame, msg, argStr, argNum)
	local slot = GET_CHILD_RECURSIVELY(frame, 'slot')
	slot:PlayUIEffect('I_sys_item_slot', 5.3, 'Inventory_Exp_ORB', true)

	local prefixMeta, suffixMeta = ARCHEOLOGY_IDENTIFY_PARSE_SUCCESS_ARG(argStr)
	ARCHEOLOGY_IDENTIFY_REFRESH(frame, prefixMeta, suffixMeta)
end

function ARCHEOLOGY_IDENTIFY_UI_RESET()
	local frame = ui.GetFrame('archeology_identify')
	if frame:GetUserValue('IDENTIFY_PENDING') == 'YES' then return end
	frame:SetUserValue('ITEM_GUID', 'None')
	frame:SetUserValue('MAX_PREFIX', '0')
	frame:SetUserValue('MAX_SUFFIX', '0')
	frame:SetUserValue('ARC_PREFIX', 'None')
	frame:SetUserValue('ARC_SUFFIX', 'None')
	frame:SetUserValue('LEGACY_ITEM', 'NO')

	-- 빈 상태 등록 안내는 slotGuide 한 곳에만 둔다(이름 자리·결과 상태 줄은 비움).
	local itemName = GET_CHILD_RECURSIVELY(frame, 'itemName')
	itemName:SetTextByKey('name', '')
	itemName:ShowWindow(1)

	ARCHEOLOGY_IDENTIFY_REFRESH_MODE_INFO(frame)

	local slot = GET_CHILD_RECURSIVELY(frame, 'slot')
	slot:ClearIcon()
	local slotPlus = GET_CHILD_RECURSIVELY(frame, 'slot_plus')
	if slotPlus ~= nil then
		slotPlus:ShowWindow(1)
	end

	local statusText   = GET_CHILD_RECURSIVELY(frame, 'prefixText')
	statusText:SetTextByKey('text', '')

	local resultText = GET_CHILD_RECURSIVELY(frame, 'resultText')
	ARCHEOLOGY_IDENTIFY_SET_OPTION_TEXT(resultText, 'None', 'None')
	resultText:ShowWindow(0)

	local identifyBtn = GET_CHILD_RECURSIVELY(frame, 'prefixBtn')
	identifyBtn:ShowWindow(0)

	INVENTORY_PUSH_CUSTOM_RBTNDOWN(frame, 'ARCHEOLOGY_IDENTIFY_INV_RBTN')
end

function OPEN_ARCHEOLOGY_IDENTIFY(frame)
	ARCHEOLOGY_IDENTIFY_UI_RESET()
end

function CLOSE_ARCHEOLOGY_IDENTIFY(frame)
	if frame:GetUserValue("IDENTIFY_PENDING") == "YES" then frame:ShowWindow(1); return end
	ARCHEOLOGY_IDENTIFY_UI_RESET()

	local invframe = ui.GetFrame('inventory')
	INVENTORY_POP_CUSTOM_RBTNDOWN(frame, 'ARCHEOLOGY_IDENTIFY_INV_RBTN')

	invframe:ShowWindow(0)
end

function ARCHEOLOGY_IDENTIFY_ITEM_DROP(parent, ctrl)
	local frame    = parent:GetTopParentFrame()
	local liftIcon = ui.GetLiftIcon()
	local slot     = tolua.cast(ctrl, 'ui::CSlot')
	local iconInfo = liftIcon:GetInfo()
	local invItem  = GET_PC_ITEM_BY_GUID(iconInfo:GetIESID())
	if nil == invItem then return end

	ARCHEOLOGY_IDENTIFY_REG_ITEM(slot, invItem)
end

function ARCHEOLOGY_IDENTIFY_INV_RBTN(itemObj, slot)
	local icon     = slot:GetIcon()
	local iconInfo = icon:GetInfo()
	local invItem  = GET_PC_ITEM_BY_GUID(iconInfo:GetIESID())
	if not invItem then return end

	local frame      = ui.GetFrame('archeology_identify')
	local targetSlot = GET_CHILD_RECURSIVELY(frame, 'slot')
	ARCHEOLOGY_IDENTIFY_REG_ITEM(targetSlot, invItem)
end

function ARCHEOLOGY_IDENTIFY_REG_ITEM(slot, invItem)
	if true == invItem.isLockState then
		ui.SysMsg(ClMsg('MaterialItemIsLock'))
		return
	end

	local clslist, cnt   = GetClassList('archeology_exhibition_item')
	local obj            = GetIES(invItem:GetObject())
	local exhibitionItem = GetClassByNameFromList(clslist, TryGetProp(obj, 'ClassName', 'None'))
	if exhibitionItem == nil then
		ui.SysMsg(ClMsg('ARCHEOLOGY_IDENTIFY_INVALID_RELIC'))
		return
	end

	local frame = ui.GetFrame('archeology_identify')
	if frame:GetUserValue('IDENTIFY_PENDING') == 'YES' then return end
	if ARCHEOLOGY_IDENTIFY_IS_MODE_MATCH(frame, exhibitionItem) == false then
		local mode = frame:GetUserValue('MATERIAL_MODE')
		if mode == 'LEGACY' then
			ui.SysMsg(ClMsg('ARCHEOLOGY_IDENTIFY_MODE_LEGACY_ONLY'))
		else
			ui.SysMsg(ClMsg('ARCHEOLOGY_IDENTIFY_MODE_NEW_ONLY'))
		end
		return
	end

	local arcPrefix = TryGetProp(obj, 'Arc_Prefix', 'None')
	local arcSuffix = TryGetProp(obj, 'Arc_Suffix', 'None')
	if string.sub(arcPrefix, 1, 7) == 'STAGE1:' or string.sub(arcSuffix, 1, 7) == 'STAGE1:' then
		ui.SysMsg(ClMsg('ARCHEOLOGY_IDENTIFY_STAGE1_INVALID'))
		return
	end

	local maxPrefix, maxSuffix = ARCHEOLOGY_IDENTIFY_GET_OPTION_LIMITS(exhibitionItem)
	local isLegacyItem = ARCHEOLOGY_IDENTIFY_IS_LEGACY_ITEM(exhibitionItem)
	local prefixCount = ARCHEOLOGY_IDENTIFY_COUNT_META(arcPrefix)
	local suffixCount = ARCHEOLOGY_IDENTIFY_COUNT_META(arcSuffix)
	if isLegacyItem == true then
		prefixCount = prefixCount + suffixCount
		suffixCount = 0
	end
	if prefixCount >= maxPrefix and suffixCount >= maxSuffix then
		ui.SysMsg(ClMsg('ARCHEOLOGY_IDENTIFY_ALREADY_COMPLETE'))
		return
	end

	local guid = invItem:GetIESID()
	frame:SetUserValue('ITEM_GUID', guid)
	frame:SetUserValue('MAX_PREFIX', tostring(maxPrefix))
	frame:SetUserValue('MAX_SUFFIX', tostring(maxSuffix))
	frame:SetUserValue('LEGACY_ITEM', isLegacyItem == true and 'YES' or 'NO')

	SET_SLOT_ITEM_IMAGE(slot, invItem)
	local slotPlus = GET_CHILD_RECURSIVELY(frame, 'slot_plus')
	if slotPlus ~= nil then
		slotPlus:ShowWindow(0)
	end

	local itemName = GET_CHILD_RECURSIVELY(frame, 'itemName')
	itemName:SetTextByKey('name', obj.Name)
	itemName:ShowWindow(1)

	local costText = GET_CHILD_RECURSIVELY(frame, 'costText')
	costText:SetTextByKey('cost', ARCHEOLOGY_IDENTIFY_GET_COST_TEXT(exhibitionItem))
	costText:ShowWindow(1)

	ARCHEOLOGY_IDENTIFY_REFRESH(frame, arcPrefix, arcSuffix)
	imcSound.PlaySoundEvent('inven_equip')
end

function ARCHEOLOGY_IDENTIFY_ITEM_REMOVE(parent, ctrl)
	ARCHEOLOGY_IDENTIFY_UI_RESET()
end

local function ARCHEOLOGY_IDENTIFY_EXEC()
	local frame = ui.GetFrame('archeology_identify')
	local guid  = frame:GetUserValue('ITEM_GUID')
	if guid == 'None' or session.GetInvItemByGuid(guid) == nil then return end

	local yesscp = string.format("EXEC_ARCHEOLOGY_IDENTIFY('%s')", guid)
	local msgbox = ui.MsgBox(ScpArgMsg('archeology_identify_check'), yesscp, 'None')
	SET_MODAL_MSGBOX(msgbox)
end

function ARCHEOLOGY_IDENTIFY_RANDOM_BTN(parent, ctrl)
	ARCHEOLOGY_IDENTIFY_EXEC()
end

function ARCHEOLOGY_IDENTIFY_PREFIX_BTN(parent, ctrl)
	ARCHEOLOGY_IDENTIFY_EXEC()
end

function EXEC_ARCHEOLOGY_IDENTIFY(expectedGuid)
	local frame   = ui.GetFrame('archeology_identify')
	local guid    = frame:GetUserValue('ITEM_GUID')
	if frame:IsVisible() == 0 or frame:GetUserValue('IDENTIFY_PENDING') == 'YES' then return end
	if expectedGuid ~= nil and expectedGuid ~= guid then return end
	local invItem = session.GetInvItemByGuid(guid)
	if invItem == nil then return end

	frame:SetUserValue('IDENTIFY_PENDING', 'YES')
	frame:SetUserValue('IDENTIFY_PENDING_GUID', guid)
	local requestSeq = frame:GetUserIValue('IDENTIFY_PENDING_SEQ') + 1
	frame:SetUserValue('IDENTIFY_PENDING_SEQ', requestSeq)
	local identifyBtn = GET_CHILD_RECURSIVELY(frame, 'prefixBtn')
	identifyBtn:ShowWindow(1)
	identifyBtn:SetEnable(0)
	identifyBtn:SetTextByKey('label', frame:GetUserConfig('PROCESSING_LABEL'))

	pc.ReqExecuteTx_Item('ARCHEOLOGY_IDENTIFY', guid)
	ReserveScript(string.format('ARCHEOLOGY_IDENTIFY_PENDING_TIMEOUT(%d)', requestSeq), 12)
end

function ARCHEOLOGY_IDENTIFY_PENDING_TIMEOUT(requestSeq)
	local frame = ui.GetFrame('archeology_identify')
	if frame == nil or frame:GetUserValue('IDENTIFY_PENDING') ~= 'YES' or
			frame:GetUserIValue('IDENTIFY_PENDING_SEQ') ~= requestSeq then
		return
	end
	local guid = frame:GetUserValue('IDENTIFY_PENDING_GUID')
	frame:SetUserValue('IDENTIFY_PENDING', 'NO')
	frame:SetUserValue('IDENTIFY_PENDING_GUID', 'None')
	local invItem = session.GetInvItemByGuid(guid)
	if invItem ~= nil then
		local obj = GetIES(invItem:GetObject())
		ARCHEOLOGY_IDENTIFY_REFRESH(frame,
			TryGetProp(obj, 'Arc_Prefix', 'None'),
			TryGetProp(obj, 'Arc_Suffix', 'None'))
	else
		ARCHEOLOGY_IDENTIFY_UI_RESET()
	end
	local button = GET_CHILD_RECURSIVELY(frame, 'prefixBtn')
	button:SetEnable(1)
	button:SetTextByKey('label', frame:GetUserConfig('IDENTIFY_LABEL'))
	ui.SysMsg(ClMsg('ARCHEOLOGY_REQUEST_RESPONSE_TIMEOUT'))
end

function ON_ARCHEOLOGY_IDENTIFY_FINISHED(frame, msg, guid)
    if frame:GetUserValue('IDENTIFY_PENDING_GUID') ~= guid then return end
    frame:SetUserValue('IDENTIFY_PENDING', 'NO')
    frame:SetUserValue('IDENTIFY_PENDING_GUID', 'None')
    local button = GET_CHILD_RECURSIVELY(frame, 'prefixBtn')
    button:SetEnable(1)
    button:SetTextByKey('label', frame:GetUserConfig('IDENTIFY_LABEL'))
end
