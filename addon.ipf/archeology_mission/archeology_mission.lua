local g_archeologyMissionCandidates = {}
local g_archeologyMissionSelectedMapID = 0

local ARCHEOLOGY_MISSION_CARD_WIDTH = 198
local ARCHEOLOGY_MISSION_CARD_HEIGHT = 326
local ARCHEOLOGY_MISSION_CARD_GAP = 8
local ARCHEOLOGY_MISSION_CARD_IMAGE_WIDTH = 178
local ARCHEOLOGY_MISSION_CARD_IMAGE_HEIGHT = 104
local ARCHEOLOGY_MISSION_MINIMAP_FALLBACK_IMAGE = 're_appraisal_image2'
local ARCHEOLOGY_MISSION_MINIMAP_RETRY_INTERVAL = 0.2
local ARCHEOLOGY_MISSION_MINIMAP_RETRY_MAX = 5
local ARCHEOLOGY_MISSION_DISSOLVE_DURATION = 0.9
local ARCHEOLOGY_MISSION_DISSOLVE_STYLE = 0
local ARCHEOLOGY_MISSION_DISSOLVE_EDGE_COLOR = tonumber('FFFF7A1F', 16)
local ARCHEOLOGY_MISSION_DISSOLVE_ORIGINAL_TONE_KEY = 'ARCHEOLOGY_DISSOLVE_ORIGINAL_TONE'
local g_archeologyMissionMinimapRetryCount = 0
local g_archeologyMissionMinimapRetryScheduled = false

local function ARCHEOLOGY_MISSION_RESET_CANDIDATES()
	g_archeologyMissionCandidates = {}
	g_archeologyMissionSelectedMapID = 0
	g_archeologyMissionMinimapRetryCount = 0
	g_archeologyMissionMinimapRetryScheduled = false
end

local function ARCHEOLOGY_MISSION_PARSE_CANDIDATES(argStr)
	ARCHEOLOGY_MISSION_RESET_CANDIDATES()
	if argStr == nil or argStr == '' or argStr == 'None' then
		return
	end

	for token in string.gmatch(argStr, '([^;]+)') do
		local classID = tonumber(token) or 0
		if classID > 0 then
			g_archeologyMissionCandidates[#g_archeologyMissionCandidates + 1] = classID
		end
	end
end

local function ARCHEOLOGY_MISSION_GET_CANDIDATE_INFO(classID)
	local mapDataCls = GetClassByType('archeology_map_list', classID)
	if mapDataCls == nil then
		return nil
	end

	local mapName = TryGetProp(mapDataCls, 'ClassName', 'None')
	local mapCls = GetClass('Map', mapName)
	if mapCls == nil then
		return nil
	end

	local traitType, profile = shared_archeology.get_map_trait_profile_by_map(mapName)
	if profile == nil then
		return nil
	end

	return {
		classID = classID,
		mapName = mapName,
		displayName = mapCls.Name,
		traitType = traitType,
		traitName = ClMsg(profile.titleMsg),
		traitSummary = ClMsg(profile.summaryMsg),
		combat = ClMsg(profile.combatMsg),
		reward = ClMsg(profile.rewardMsg),
		color = profile.color or 'FFFFFF',
	}
end

local function ARCHEOLOGY_MISSION_DISABLE_HIT_TEST(ctrl)
	if ctrl ~= nil then
		ctrl:EnableHitTest(0)
	end
end

local function ARCHEOLOGY_MISSION_DRAW_CANDIDATE_CARD(candidateGbox, index, info, isSelected)
	local x = (index - 1) * (ARCHEOLOGY_MISSION_CARD_WIDTH + ARCHEOLOGY_MISSION_CARD_GAP)
	local card = candidateGbox:CreateOrGetControlSet('archeology_mission_candidate_card',
		'candidate_card_' .. index, x, 0)
	-- Keep a filled background when the selected border (transparent inside) is shown.
	local background = GET_CHILD_RECURSIVELY(card, 'candidate_background')
	background:SetColorTone(isSelected == true and 'FF806B47' or 'FF403A32')
	GET_CHILD_RECURSIVELY(card, 'candidate_selected_border'):ShowWindow(isSelected == true and 1 or 0)

	local mapPicture = GET_CHILD_RECURSIVELY(card, 'map_picture')
	mapPicture = tolua.cast(mapPicture, 'ui::CPicture')
	local imageName = info.mapName
	if ui.IsImageExist(imageName) == true then
		mapPicture:SetImage(imageName)
	else
		mapPicture:SetImage(ARCHEOLOGY_MISSION_MINIMAP_FALLBACK_IMAGE)
		world.PreloadMinimap(info.mapName, 512, false)
	end

	local nameText = GET_CHILD_RECURSIVELY(card, 'candidate_name')
	nameText:SetTextByKey('name', info.displayName)
	local traitText = GET_CHILD_RECURSIVELY(card, 'candidate_trait')
	traitText:SetTextByKey('color', info.color)
	traitText:SetTextByKey('trait', info.traitName)
	GET_CHILD_RECURSIVELY(card, 'combat_text'):SetTextByKey('text', info.combat)
	GET_CHILD_RECURSIVELY(card, 'reward_text'):SetTextByKey('text', info.reward)

	local stateText = GET_CHILD_RECURSIVELY(card, 'candidate_state')
	stateText:SetTextByKey('color', isSelected == true and 'FFE5A7' or 'D8CAB8')
	stateText:SetTextByKey('state', ClMsg(isSelected == true and
		'ARCHEOLOGY_MISSION_SELECTED' or 'ARCHEOLOGY_MISSION_CLICK_TO_SELECT'))

	local button = GET_CHILD_RECURSIVELY(card, 'candidate_button')
	button:SetEventScript(ui.LBUTTONUP, 'ARCHEOLOGY_MISSION_SELECT_CANDIDATE')
	button:SetEventScriptArgNumber(ui.LBUTTONUP, info.classID)
	button:SetTextTooltip(info.traitSummary)
end

local function ARCHEOLOGY_MISSION_REQUEST_MINIMAP_REFRESH()
	g_archeologyMissionMinimapRetryCount = 0
	if g_archeologyMissionMinimapRetryScheduled == true then
		return
	end

	g_archeologyMissionMinimapRetryScheduled = true
	ReserveScript('ARCHEOLOGY_MISSION_REFRESH_MINIMAP_IMAGES()', ARCHEOLOGY_MISSION_MINIMAP_RETRY_INTERVAL)
end

function ARCHEOLOGY_MISSION_REFRESH_MINIMAP_IMAGES()
	g_archeologyMissionMinimapRetryScheduled = false
	local frame = ui.GetFrame('archeology_mission')
	if frame == nil or frame:IsVisible() == 0 then
		return
	end

	local hasPendingImage = false
	for i = 1, 3 do
		local classID = g_archeologyMissionCandidates[i] or 0
		local info = ARCHEOLOGY_MISSION_GET_CANDIDATE_INFO(classID)
		local card = GET_CHILD_RECURSIVELY(frame, 'candidate_card_' .. i)
		local mapPicture = card ~= nil and GET_CHILD_RECURSIVELY(card, 'map_picture') or nil
		if info ~= nil and mapPicture ~= nil then
			mapPicture = tolua.cast(mapPicture, 'ui::CPicture')
			local imageName = info.mapName
			if ui.IsImageExist(imageName) == true then
				mapPicture:SetImage(imageName)
			else
				hasPendingImage = true
				world.PreloadMinimap(info.mapName, 512, false)
			end
		end
	end

	if hasPendingImage == true and g_archeologyMissionMinimapRetryCount < ARCHEOLOGY_MISSION_MINIMAP_RETRY_MAX then
		g_archeologyMissionMinimapRetryCount = g_archeologyMissionMinimapRetryCount + 1
		g_archeologyMissionMinimapRetryScheduled = true
		ReserveScript('ARCHEOLOGY_MISSION_REFRESH_MINIMAP_IMAGES()', ARCHEOLOGY_MISSION_MINIMAP_RETRY_INTERVAL)
	end
end

local function ARCHEOLOGY_MISSION_REFRESH_CANDIDATES(frame)
	local candidateGbox = GET_CHILD_RECURSIVELY(frame, 'candidate_gbox')
	if candidateGbox == nil then
		return
	end
	candidateGbox:RemoveAllChild()

	for i = 1, 3 do
		local classID = g_archeologyMissionCandidates[i] or 0
		local info = ARCHEOLOGY_MISSION_GET_CANDIDATE_INFO(classID)
		if info ~= nil then
			ARCHEOLOGY_MISSION_DRAW_CANDIDATE_CARD(candidateGbox, i, info,
				g_archeologyMissionSelectedMapID == classID)
		end
	end
end

local function ARCHEOLOGY_MISSION_APPLY_LEVEL_LAYOUT(frame, lv)
	local candidateGbox = GET_CHILD_RECURSIVELY(frame, 'candidate_gbox')
	local picture = GET_CHILD_RECURSIVELY(frame, 'pic')
	local selectionGuide = GET_CHILD_RECURSIVELY(frame, 'selection_guide')
	local selectionNote = GET_CHILD_RECURSIVELY(frame, 'selection_note')
	local sendButton = GET_CHILD_RECURSIVELY(frame, 'send_ok')
	if lv >= 530 then
		if candidateGbox ~= nil then candidateGbox:ShowWindow(1) end
		if picture ~= nil then picture:ShowWindow(0) end
		if selectionGuide ~= nil then
			selectionGuide:ShowWindow(1)
			selectionGuide:SetTextByKey('guide', ClMsg('ARCHEOLOGY_MISSION_SELECT_GUIDE'))
		end
		if selectionNote ~= nil then selectionNote:ShowWindow(1) end
		if sendButton ~= nil then sendButton:SetTextByKey('value', ClMsg('ARCHEOLOGY_MISSION_START_SELECTED')) end
	else
		if candidateGbox ~= nil then candidateGbox:ShowWindow(0) end
		if picture ~= nil then picture:ShowWindow(1) end
		if selectionGuide ~= nil then
			selectionGuide:ShowWindow(1)
			selectionGuide:SetTextByKey('guide', ClMsg('ARCHEOLOGY_MISSION_ACCEPT_GUIDE'))
		end
		if selectionNote ~= nil then selectionNote:ShowWindow(0) end
		if sendButton ~= nil then sendButton:SetTextByKey('value', ClMsg('ARCHEOLOGY_MISSION_ACCEPT')) end
	end
end

function ARCHEOLOGY_MISSION_ON_INIT(addon, frame)
	addon:RegisterMsg('ARCHEOLOGY_MISSION_OPEN', 'ON_ARCHEOLOGY_MISSION_OPEN');
	addon:RegisterMsg('ARCHEOLOGY_MISSION_CLOSE', 'ON_ARCHEOLOGY_MISSION_CLOSE');
	addon:RegisterMsg('ARCHEOLOGY_MISSION_ACCEPT_RESULT', 'ON_ARCHEOLOGY_MISSION_ACCEPT_RESULT');
end

function ON_ARCHEOLOGY_MISSION_OPEN(frame, msg, argStr, argNum)
	frame:SetUserValue('lv', argNum)	
	local bg = GET_CHILD_RECURSIVELY(frame, "bg")
	if argNum >= 530 then
		ARCHEOLOGY_MISSION_PARSE_CANDIDATES(argStr)
		if #g_archeologyMissionCandidates ~= 3 then
			ui.SysMsg(ClMsg('ARCHEOLOGY_MISSION_CANDIDATE_FAILED'))
			return
		end
	else
		ARCHEOLOGY_MISSION_RESET_CANDIDATES()
	end
	ARCHEOLOGY_MISSION_APPLY_LEVEL_LAYOUT(frame, argNum)
	ARCHEOLOGY_MISSION_REFRESH_CANDIDATES(frame)
	local cost_item, cost_count = shared_archeology.get_cost(frame:GetUserIValue('lv'))
	
	local cls = GetClass('Item', cost_item)
	local title = GET_CHILD_RECURSIVELY(frame, 'richtext_1')
	title:SetTextByKey('title', ClMsg(argNum == 530 and
		'ARCHEOLOGY_MISSION_TITLE_530' or 'ARCHEOLOGY_MISSION_TITLE_470'))

	local desc_item = GET_CHILD_RECURSIVELY(frame, 'richtext_2')
	desc_item:SetTextByKey('value1', cls.Name)
	desc_item:SetTextByKey('value2', cost_count)

	frame:ShowWindow(1)
	bg:ShowWindow(1)
	if argNum >= 530 then
		ARCHEOLOGY_MISSION_REQUEST_MINIMAP_REFRESH()
	end
	if argNum ~= nil then
		frame:SetUserValue("MSG_BOX_CHECK_FLAG", argNum);
	end

	ARCHEOLOGY_MISSION_FIND_AND_REGISTER_ITEM(frame);
end

local function ARCHEOLOGY_MISSION_CLAMP01(value)
	if value == nil or value < 0 then
		return 0
	end
	if value > 1 then
		return 1
	end
	return value
end

local function ARCHEOLOGY_MISSION_FOR_EACH_CTRL(ctrl, func)
	if ctrl == nil or func == nil then
		return
	end

	ctrl = AUTO_CAST(ctrl)
	func(ctrl)
	local childCount = ctrl:GetChildCount()
	for i = 0, childCount - 1 do
		local child = ctrl:GetChildByIndex(i)
		if child ~= nil then
			ARCHEOLOGY_MISSION_FOR_EACH_CTRL(child, func)
		end
	end
end

local function ARCHEOLOGY_MISSION_HASH_TEXT(text)
	local hash = 0
	if text == nil then
		return hash
	end

	for i = 1, string.len(text) do
		hash = (hash * 31 + string.byte(text, i)) % 9973
	end
	return hash
end

local function ARCHEOLOGY_MISSION_GET_CTRL_BURN_SEED(ctrl)
	local nameSeed = ARCHEOLOGY_MISSION_HASH_TEXT(ctrl:GetName())
	return (nameSeed + ctrl:GetX() * 3 + ctrl:GetY() * 5 + ctrl:GetWidth() * 7 + ctrl:GetHeight() * 11) % 9973
end

local function ARCHEOLOGY_MISSION_GET_CTRL_BURN_PROGRESS(ctrl, progress)
	local p = ARCHEOLOGY_MISSION_CLAMP01(progress)
	if p >= 1 then
		return 1
	end

	local seed = ARCHEOLOGY_MISSION_GET_CTRL_BURN_SEED(ctrl)
	local delay = (seed % 9) * 0.007
	local speed = 0.94 + ((math.floor(seed / 9) % 7) * 0.02)
	local ripple = math.sin(p * 9.0 + seed * 0.013) * 0.018

	if ctrl:GetClassName() == 'richtext' then
		delay = delay * 0.45
		ripple = ripple * 0.5
	end

	return ARCHEOLOGY_MISSION_CLAMP01(((p - delay + ripple) / math.max(0.82, 1 - delay)) * speed)
end

local function ARCHEOLOGY_MISSION_GET_ORGANIC_BURN_PROGRESS(progress)
	local p = ARCHEOLOGY_MISSION_CLAMP01(progress)
	local eased = p * p * (3 - 2 * p)
	local flutter = math.sin(p * 17.0) * 0.018 + math.sin(p * 31.0 + 0.7) * 0.01
	return ARCHEOLOGY_MISSION_CLAMP01(eased + flutter)
end

local function ARCHEOLOGY_MISSION_GET_DISSOLVE_EDGE_WIDTH(progress)
	local p = ARCHEOLOGY_MISSION_CLAMP01(progress)
	local edge = 0.025 + math.sin(p * math.pi) * 0.045
	if p > 0.78 then
		edge = edge + (p - 0.78) * 0.08
	end
	return edge
end

local function ARCHEOLOGY_MISSION_RESET_DISSOLVE(frame)
	if frame == nil then
		return
	end

	local parchment = GET_CHILD_RECURSIVELY(frame, 'bg')
	ARCHEOLOGY_MISSION_FOR_EACH_CTRL(parchment, function(ctrl)
		ctrl:ClearDissolve()
		ctrl:SetAlpha(100)

		local originalTone = ctrl:GetUserValue(ARCHEOLOGY_MISSION_DISSOLVE_ORIGINAL_TONE_KEY)
		if originalTone ~= nil and originalTone ~= '' and originalTone ~= 'None' then
			ctrl:SetColorTone(originalTone)
			ctrl:SetUserValue(ARCHEOLOGY_MISSION_DISSOLVE_ORIGINAL_TONE_KEY, 'None')
		end

		if ctrl:GetClassName() == 'slot' then
			local icon = ctrl:GetIcon()
			if icon ~= nil then
				icon:ClearDissolve()
				icon:SetAlpha(100)
			end
		end
	end)

	frame:SetAlpha(100)
end

local function ARCHEOLOGY_MISSION_APPLY_DISSOLVE(frame, progress)
	local parchment = GET_CHILD_RECURSIVELY(frame, 'bg')
	if parchment == nil then
		return
	end

	local dissolveProgress = math.max(progress, 0.001)
	ARCHEOLOGY_MISSION_FOR_EACH_CTRL(parchment, function(ctrl)
		local localProgress = ARCHEOLOGY_MISSION_GET_CTRL_BURN_PROGRESS(ctrl, dissolveProgress)
		local edgeSeed = ARCHEOLOGY_MISSION_GET_CTRL_BURN_SEED(ctrl)
		local edgeWidth = ARCHEOLOGY_MISSION_GET_DISSOLVE_EDGE_WIDTH(localProgress) * (0.82 + (edgeSeed % 5) * 0.07)
		local className = ctrl:GetClassName()

		if className == 'picture' then
			AUTO_CAST(ctrl)
		end
		ctrl:SetDissolveStyle(ARCHEOLOGY_MISSION_DISSOLVE_STYLE)
		ctrl:SetDissolveEdge(edgeWidth, ARCHEOLOGY_MISSION_DISSOLVE_EDGE_COLOR)
		ctrl:SetDissolve(localProgress)

		if className == 'slot' then
			local icon = ctrl:GetIcon()
			if icon ~= nil then
				icon:SetDissolveStyle(ARCHEOLOGY_MISSION_DISSOLVE_STYLE)
				icon:SetDissolveEdge(edgeWidth, ARCHEOLOGY_MISSION_DISSOLVE_EDGE_COLOR)
				icon:SetDissolve(localProgress)
			end
		end
	end)
end


function OPEN_ARCHEOLOGY_MISSION(frame)
	frame:StopUpdateScript('ARCHEOLOGY_MISSION_DISSOLVE_UPDATE')
	ARCHEOLOGY_MISSION_RESET_DISSOLVE(frame)
	frame:SetUserValue('DISSOLVE_PENDING', 0)
	frame:SetEnable(1)
	frame:EnableHittestFrame(1)
	ARCHEOLOGY_MISSION_INIT(frame)
	INVENTORY_PUSH_CUSTOM_RBTNDOWN(frame, 'ARCHEOLOGY_MISSION_INVENTORY_RBTN_CLICK')
	frame:SetUserValue('ARCHEOLOGY_MISSION_RBTN_PUSHED', 1)
end

function CLOSE_ARCHEOLOGY_MISSION(frame)
	if frame:GetUserIValue('ARCHEOLOGY_MISSION_RBTN_PUSHED') == 1 then
		INVENTORY_POP_CUSTOM_RBTNDOWN(frame, 'ARCHEOLOGY_MISSION_INVENTORY_RBTN_CLICK')
		frame:SetUserValue('ARCHEOLOGY_MISSION_RBTN_PUSHED', 0)
	end
	if frame:GetUserIValue('DISSOLVE_PENDING') == 1 then
		return
	end
	frame:ShowWindow(0)
	ARCHEOLOGY_MISSION_RESET_CANDIDATES()
end

function ARCHEOLOGY_MISSION_DISSOLVE_UPDATE(frame, elapsedTime)
	if frame:GetUserIValue('DISSOLVE_PENDING') ~= 1 then
		return 0
	end

	local rawProgress = math.min(1, elapsedTime / ARCHEOLOGY_MISSION_DISSOLVE_DURATION)
	local progress = ARCHEOLOGY_MISSION_GET_ORGANIC_BURN_PROGRESS(rawProgress)
	ARCHEOLOGY_MISSION_APPLY_DISSOLVE(frame, progress)

	if elapsedTime < ARCHEOLOGY_MISSION_DISSOLVE_DURATION then
		return 1
	end

	ARCHEOLOGY_MISSION_APPLY_DISSOLVE(frame, 1)
	frame:SetUserValue('DISSOLVE_PENDING', 0)
	CLOSE_ARCHEOLOGY_MISSION(frame)
	return 0
end

function ARCHEOLOGY_MISSION_SELECT_CANDIDATE(parent, ctrl, argStr, argNum)
	local classID = tonumber(argNum) or 0
	if classID <= 0 then
		return
	end

	local isCandidate = false
	for _, candidateID in ipairs(g_archeologyMissionCandidates) do
		if candidateID == classID then
			isCandidate = true
			break
		end
	end
	if isCandidate ~= true then
		return
	end

	g_archeologyMissionSelectedMapID = classID
	local frame = parent:GetTopParentFrame()
	ARCHEOLOGY_MISSION_REFRESH_CANDIDATES(frame)
	ARCHEOLOGY_MISSION_REQUEST_MINIMAP_REFRESH()
end

local function SET_TARGET_SLOT(frame, targetItem)
	local slot = GET_CHILD_RECURSIVELY(frame, 'slot');	
	local slot_bg_image = GET_CHILD_RECURSIVELY(frame, 'slot_bg_image');
	local text_putonitem = GET_CHILD_RECURSIVELY(frame, 'text_putonitem');
	local text_itemname = GET_CHILD_RECURSIVELY(frame, 'text_itemname');	

	if targetItem ~= nil then
		local targetItemObj = GetIES(targetItem:GetObject());
		local cost_name, cost_count = shared_archeology.get_cost(frame:GetUserIValue('lv'))
		local slot_item_name = TryGetProp(targetItemObj, "ClassName", "None")
		local now_count = session.GetInvItemCountByType(targetItemObj.ClassID)

		if cost_name == slot_item_name then
			if now_count >= cost_count then
				SET_SLOT_ITEM(slot, targetItem);
				text_itemname:SetTextByKey('name', targetItemObj.Name);
				slot_bg_image:ShowWindow(0);
				text_putonitem:ShowWindow(0);
			else
				ui.SysMsg(ClMsg('Auto_SuLyangi_BuJogHapNiDa.'))
				return
			end
		else
			ui.SysMsg(ClMsg('IMPOSSIBLE_ITEM'))
			return
		end

	else
		slot:ClearIcon();
		text_itemname:SetTextByKey('name', '');
		slot_bg_image:ShowWindow(1);
		text_putonitem:ShowWindow(1);
	end
end

local function GET_TARGET_SLOT_ITEM(frame)
	local slot = GET_CHILD_RECURSIVELY(frame, 'slot');
	local icon = slot:GetIcon();
	if icon == nil then
		return nil;
	end

	local targetItem = session.GetInvItemByGuid(icon:GetInfo():GetIESID());
	if targetItem == nil then
		return nil;
	end
	return targetItem;
end

function ARCHEOLOGY_MISSION_INIT(frame)
	if ui.CheckHoldedUI() == true then
		return;
	end
	frame = frame:GetTopParentFrame();
	SET_TARGET_SLOT(frame, nil)
end

function ARCHEOLOGY_MISSION_INVENTORY_RBTN_CLICK(itemObj, invSlot, invItemGuid)
	local frame = ui.GetFrame('archeology_mission');
	if invSlot:IsSelected() == 1 then
		ARCHEOLOGY_MISSION_INIT(frame);
	else
		ARCHEOLOGY_MISSION_REGISTER_ITEM(frame, invItemGuid);
	end
end

function ARCHEOLOGY_MISSION_DROP_ITEM(parent, slot)
	if ui.CheckHoldedUI() == true then return; end
	local liftIcon = ui.GetLiftIcon();
	local fromFrame = liftIcon:GetTopParentFrame();
	local toFrame = parent:GetTopParentFrame();
	if fromFrame:GetName() == 'inventory' then
		local iconInfo = liftIcon:GetInfo();
		ARCHEOLOGY_MISSION_REGISTER_ITEM(toFrame, iconInfo:GetIESID());
	end
end

function ARCHEOLOGY_MISSION_SLOT_LBTN_CLICK(parent, ctrl)
	local frame = parent:GetTopParentFrame();
	ARCHEOLOGY_MISSION_FIND_AND_REGISTER_ITEM(frame, true);
end

-- notifyMissing: 허가증이 없을 때 안내하는지 여부. 창을 열 때는 조용히 빈 슬롯으로 두고,
-- 슬롯을 직접 눌러 등록을 시도한 경우에만 알린다.
function ARCHEOLOGY_MISSION_FIND_AND_REGISTER_ITEM(frame, notifyMissing)
	local cost_name, cost_count = shared_archeology.get_cost(frame:GetUserIValue('lv'));
	local mat_item = session.GetInvItemByName(cost_name);
	if mat_item == nil or mat_item.count < cost_count then
		if notifyMissing == true then
			ui.SysMsg(ClMsg('Auto_SuLyangi_BuJogHapNiDa.'));
		end
		SET_TARGET_SLOT(frame, nil);
		return;
	end

	ARCHEOLOGY_MISSION_REGISTER_ITEM(frame, mat_item:GetIESID());
end

function ARCHEOLOGY_MISSION_REGISTER_ITEM(frame, invItemID)
	if ui.CheckHoldedUI() == true then return; end	
	local targetItem = session.GetInvItemByGuid(invItemID);
	SET_TARGET_SLOT(frame, targetItem);
end

function ARCHEOLOGY_MISSION_EXECUTE(parent, ctrl)
	local frame = parent:GetTopParentFrame();
	local lv = frame:GetUserIValue('lv')
	if lv >= 530 and g_archeologyMissionSelectedMapID <= 0 then
		ui.SysMsg(ClMsg('ARCHEOLOGY_MISSION_SELECT_MAP_REQUIRED'))
		return
	end
	local slot = GET_CHILD_RECURSIVELY(frame, 'slot');
	local icon = slot:GetIcon();
	if icon == nil or icon:GetInfo() == nil then
		ui.SysMsg(ClMsg('NotExistTargetItem'));
		return;
	end

	local archeologyy_item = GET_TARGET_SLOT_ITEM(frame);
	if archeologyy_item == nil then
		ui.SysMsg(ClMsg('NotExistTargetItem'));
		SET_TARGET_SLOT(frame, nil);
		return;
	end
	if archeologyy_item.isLockState == true then
		ui.SysMsg(ClMsg('MaterialItemIsLock'));
		return;
	end

	local targetItemID = icon:GetInfo():GetIESID();
	frame:SetUserValue('guid', targetItemID)

	local yesscp = string.format('_ARCHEOLOGY_MISSION_EXECUTE("%s")', targetItemID)

	local clMsg = 'ReallyUseContentsMultiple';

	local archeologyy_item_obj = GetIES(archeologyy_item:GetObject());
	local msgBox = ui.MsgBox(ScpArgMsg(clMsg, 'Name', TryGetProp(archeologyy_item_obj, 'Name', 'None')), yesscp, '');
	SET_MODAL_MSGBOX(msgBox);
end

function _ARCHEOLOGY_MISSION_EXECUTE(targetItemID, confirmedMapID)
	local frame = ui.GetFrame('archeology_mission')
	if frame:IsVisible() == 0 then
		return;
	end
	if frame:GetUserIValue('DISSOLVE_PENDING') == 1 then
		return
	end

	local targetInvItem = session.GetInvItemByGuid(targetItemID)
	if targetInvItem == nil then
		ui.SysMsg(ClMsg('NotExistTargetItem'))
		ARCHEOLOGY_MISSION_INIT(frame)
		return;
	end

	if targetInvItem.isLockState == true then
		ui.SysMsg(ClMsg('MaterialItemIsLock'))
		ARCHEOLOGY_MISSION_INIT(frame)
		return;
	end

	local argStr = frame:GetUserValue('guid');
	local lv = frame:GetUserIValue('lv')
	local txArg = tostring(lv)
	if lv >= 530 then
		local selectedMapID = g_archeologyMissionSelectedMapID
		if selectedMapID <= 0 then
			ui.SysMsg(ClMsg('ARCHEOLOGY_MISSION_SELECT_MAP_REQUIRED'))
			return
		end
		local selectedInfo = ARCHEOLOGY_MISSION_GET_CANDIDATE_INFO(selectedMapID)
		if selectedInfo == nil then
			ui.SysMsg(ClMsg('ARCHEOLOGY_MISSION_INVALID_MAP_SELECTION'))
			return
		end
		local acc = GetMyAccountObj()
		local activeMap = acc ~= nil and TryGetProp(acc, 'archeology_map_1', 'None') or 'None'
		local activeComplete = acc ~= nil and tonumber(TryGetProp(acc, 'archeology_map_1_complete', 0)) or 0
		if acc ~= nil and shared_archeology.is_advanced_mission(acc) == true and
				activeMap ~= 'None' and activeComplete ~= 1 and
				activeMap ~= selectedInfo.mapName and tonumber(confirmedMapID) ~= selectedMapID then
			local activeMapCls = GetClass('Map', activeMap)
			local activeName = activeMapCls ~= nil and activeMapCls.Name or activeMap
			local yesScript = string.format('_ARCHEOLOGY_MISSION_EXECUTE("%s", %d)',
				targetItemID, selectedMapID)
			local msgBox = ui.MsgBox(ScpArgMsg('ARCHEOLOGY_MISSION_CHANGE_CONFIRM{CURRENT}{NEXT}',
				'CURRENT', activeName, 'NEXT', selectedInfo.displayName), yesScript, '')
			SET_MODAL_MSGBOX(msgBox)
			return
		end
		txArg = txArg .. ' ' .. tostring(selectedMapID)
		if tonumber(confirmedMapID) == selectedMapID then
			txArg = txArg .. ' 1'
		end
	end

	pc.ReqExecuteTx_Item("ACCEPT_ARCHEOLOGY_MISSION", argStr, txArg)	
end

function ON_ARCHEOLOGY_MISSION_ACCEPT_RESULT(frame, msg, argStr, argNum)
	if argStr ~= 'SUCCESS' or frame:IsVisible() == 0 or
			frame:GetUserIValue('DISSOLVE_PENDING') == 1 or
			frame:GetUserIValue('lv') ~= argNum then
		return
	end
	frame:SetUserValue('DISSOLVE_PENDING', 1)
	frame:EnableHittestFrame(0)
	ARCHEOLOGY_MISSION_APPLY_DISSOLVE(frame, 0.001)
	frame:RunUpdateScript('ARCHEOLOGY_MISSION_DISSOLVE_UPDATE', 0, 0, 0, 1)
end

function ON_ARCHEOLOGY_MISSION_CLOSE(frame, msg, argStr, argNum)
	local ARCHEOLOGY_MISSION = ui.GetFrame('archeology_mission');
	if ARCHEOLOGY_MISSION:GetUserIValue('DISSOLVE_PENDING') == 1 then
		return
	end
	ARCHEOLOGY_MISSION:ShowWindow(0);
end


function OPEN_ARCHEOLOGY_SHOP(shopType)
	local frame = ui.GetFrame('earthtowershop')
	if frame:IsVisible() == 1 then
		ui.CloseFrame('earthtowershop')
	end
	
    if shopType == nil or shopType == '' then
        shopType = 'archeology_season2'
    end

    frame:SetUserValue("SHOP_TYPE", shopType);

	
    ui.OpenFrame('earthtowershop');
end
