local ARCHEOLOGY_DECOMPOSE_POINT_NAME = "ARCHEOLOGY_COIN"
local ARCHEOLOGY_DECOMPOSE_COIN_TYPE = 11039559
local ARCHEOLOGY_DECOMPOSE_REWARD_CLASS_NAME = "Archeology_Dig_Coin"
local ARCHEOLOGY_DECOMPOSE_LEGACY_REWARD_CLASS_NAME = "Archeology_Relic_A_4_Lv530"
-- 한 번에 분해할 수 있는 최대 "아이템 칸" 수. 수량 합계가 아니라 칸 수다.
-- (분해 TX는 GUID 한 칸당 항목 하나를 보내므로 제한 단위도 칸이어야 한다.
--  수량 합계로 제한하면 스택형 아이템 한 칸이 한도를 전부 먹어버린다.)
local ARCHEOLOGY_DECOMPOSE_MAX_SELECT = 60
-- 선택은 화면 슬롯 대신 아이템 GUID로 보존한다. 필터로 숨겨져도 유지된다.
local ARCHEOLOGY_DECOMPOSE_SELECTION = {}
local ARCHEOLOGY_DECOMPOSE_PENDING_ITEMS = nil

function ARCHEOLOGY_DECOMPOSE_ON_INIT(addon, frame)
	addon:RegisterMsg("ITEM_POINT_EXTRACTOR_EXECUTE", "ON_ARCHEOLOGY_DECOMPOSE_EXECUTE_RESULT")
	addon:RegisterMsg("UPDATE_LOCK_STATE", "ON_ARCHEOLOGY_DECOMPOSE_EXECUTE_RESULT")
	addon:RegisterMsg("INV_ITEM_ADD", "ON_ARCHEOLOGY_DECOMPOSE_EXECUTE_RESULT")
	addon:RegisterMsg("INV_ITEM_REMOVE", "ON_ARCHEOLOGY_DECOMPOSE_EXECUTE_RESULT")
	addon:RegisterMsg("INV_ITEM_CHANGE_COUNT", "ON_ARCHEOLOGY_DECOMPOSE_EXECUTE_RESULT")
end

function REQ_ARCHEOLOGY_DECOMPOSE_OPEN()
	ui.CloseFrame("item_point_extractor")
	ui.OpenFrame("archeology_decompose")
end

function ARCHEOLOGY_DECOMPOSE_OPEN(frame)
	ui.EnableSlotMultiSelect(1)
	ARCHEOLOGY_DECOMPOSE_SELECTION = {}
	ARCHEOLOGY_DECOMPOSE_PENDING_ITEMS = nil
	ARCH_DECOMP_INIT_FILTER(frame)
	ARCH_DECOMP_UPDATE_UI(frame, true)
end

function ARCHEOLOGY_DECOMPOSE_CLOSE(frame)
	ui.EnableSlotMultiSelect(0)
	ARCHEOLOGY_DECOMPOSE_SELECTION = {}
	ARCHEOLOGY_DECOMPOSE_PENDING_ITEMS = nil
end

function ARCH_DECOMP_INIT_FILTER(frame)
	if frame:GetUserValue("FILTER_INIT") == "YES" then
		return
	end

	local junk = GET_CHILD_RECURSIVELY(frame, "check_junk", "ui::CCheckBox")
	local normal = GET_CHILD_RECURSIVELY(frame, "check_normal", "ui::CCheckBox")
	local magic = GET_CHILD_RECURSIVELY(frame, "check_magic", "ui::CCheckBox")
	local rare = GET_CHILD_RECURSIVELY(frame, "check_rare", "ui::CCheckBox")

	if junk ~= nil then junk:SetCheck(1) end
	if normal ~= nil then normal:SetCheck(1) end
	if magic ~= nil then magic:SetCheck(1) end
	-- 레어 분류(레어 등급 유물, 전시 공명석·촉매)는 기본으로 숨겨 자동 등록에서 빠지게 한다.
	-- 필터를 켜면 분해할 수 있다.
	if rare ~= nil then rare:SetCheck(0) end

	frame:SetUserValue("FILTER_INIT", "YES")
end

function ARCH_DECOMP_GET_MATERIAL_LIST()
	local clsList, cnt = GetClassList("PointExtractItem")
	local retTable = {}
	for i = 0, cnt - 1 do
		local cls = GetClassByIndexFromList(clsList, i)
		if TryGetProp(cls, "PointName", "None") == ARCHEOLOGY_DECOMPOSE_POINT_NAME then
			retTable[cls.ItemClassName] = TryGetProp(cls, "Point", 0)
		end
	end
	return retTable
end

function ARCH_DECOMP_GET_CATEGORY(itemName, point)
	if string.find(itemName, "Arc_Junk_") == 1 or point < 5 then
		return "JUNK"
	end
	-- 전시 보조 장치(공명석·촉매)는 옵션이 붙은 1개짜리라 포인트와 관계없이 기본 보호 분류로 둔다.
	if string.find(itemName, "_R$") ~= nil or point >= 60 or
			string.find(itemName, "Arc_Exhibit_", 1, true) == 1 then
		return "RARE"
	end
	if string.find(itemName, "_M$") ~= nil or point >= 25 then
		return "MAGIC"
	end
	return "NORMAL"
end

function ARCH_DECOMP_IS_CATEGORY_VISIBLE(frame, category)
	local checkName = "check_normal"
	if category == "JUNK" then
		checkName = "check_junk"
	elseif category == "MAGIC" then
		checkName = "check_magic"
	elseif category == "RARE" then
		checkName = "check_rare"
	end

	local check = GET_CHILD_RECURSIVELY(frame, checkName, "ui::CCheckBox")
	return check ~= nil and check:IsChecked() == 1
end

function ARCH_DECOMP_IS_LOCKED_ITEM(invItem)
	if invItem == nil then
		return true
	end
	if invItem.isLockState == true or invItem.isLockState == 1 or invItem.isLockState == "YES" then
		return true
	end

	if IS_TEMP_LOCK ~= nil then
		local invFrame = ui.GetFrame("inventory")
		if invFrame ~= nil and IS_TEMP_LOCK(invFrame, invItem) == true then
			return true
		end
	end

	return false
end

function ARCH_DECOMP_IS_AUTO_EXCLUDED_ITEM(category)
	return false
end

function ARCH_DECOMP_CAPTURE_SELECTION(frame)
	local slotSet = GET_CHILD_RECURSIVELY(frame, "slotlist", "ui::CSlotSet")
	if slotSet == nil then return end
	local visible = {}
	for i = 0, slotSet:GetSlotCount() - 1 do
		local slot = slotSet:GetSlotByIndex(i)
		local icon = slot:GetIcon()
		if icon ~= nil then
			local guid = icon:GetInfo():GetIESID()
			visible[#visible + 1] = { slot = slot, guid = guid }
			ARCHEOLOGY_DECOMPOSE_SELECTION[guid] = nil
		end
	end
	-- 필터로 가려진 선택분도 칸 수로 센다.
	local slotCount = 0
	for _ in pairs(ARCHEOLOGY_DECOMPOSE_SELECTION) do
		slotCount = slotCount + 1
	end
	for _, entry in ipairs(visible) do
		local slot = entry.slot
		if slot:IsSelected() == 1 then
			local invItem = GET_ITEM_BY_GUID(entry.guid)
			local selectedCount = 0
			if invItem ~= nil and ARCH_DECOMP_IS_LOCKED_ITEM(invItem) ~= true
					and slotCount < ARCHEOLOGY_DECOMPOSE_MAX_SELECT then
				selectedCount = math.max(0, math.min(slot:GetSelectCount(), invItem.count))
			end
			-- Select(true)는 수량 모드에서 1개를 더한다. 관측은 선택 수량을 변경하지 않는다.
			if selectedCount == 0 then slot:Select(0) end
			slot:SetSelectCount(selectedCount)
			if selectedCount > 0 then
				ARCHEOLOGY_DECOMPOSE_SELECTION[entry.guid] = selectedCount
				slotCount = slotCount + 1
			end
		end
	end
	slotSet:MakeSelectionList()
end

function ARCH_DECOMP_GET_SELECTED_ITEMS(frame)
	ARCH_DECOMP_CAPTURE_SELECTION(frame)
	local materials = ARCH_DECOMP_GET_MATERIAL_LIST()
	local items = {}
	for guid, count in pairs(ARCHEOLOGY_DECOMPOSE_SELECTION) do
		local invItem = GET_ITEM_BY_GUID(guid)
		local obj = invItem ~= nil and GetIES(invItem:GetObject()) or nil
		local point = materials[TryGetProp(obj, "ClassName", "None")]
		if invItem == nil or point == nil or ARCH_DECOMP_IS_LOCKED_ITEM(invItem) == true then
			ARCHEOLOGY_DECOMPOSE_SELECTION[guid] = nil
		else
			count = math.min(count, invItem.count)
			if count > 0 then
				ARCHEOLOGY_DECOMPOSE_SELECTION[guid] = count
				items[#items + 1] = { iesID = guid, count = count, point = point,
					name = obj.Name, className = obj.ClassName }
			else
				ARCHEOLOGY_DECOMPOSE_SELECTION[guid] = nil
			end
		end
	end
	table.sort(items, function(a, b) return a.iesID < b.iesID end)
	return items
end

function ARCH_DECOMP_CLEAR_SLOTSET(frame, slotSet)
	slotSet:ClearIconAll()
	slotSet:RemoveAllChild()
	slotSet:SetColRow(slotSet:GetCol(), tonumber(frame:GetUserConfig("DEFAULT_ROW")))
	slotSet:CreateSlots()
end

function ARCH_DECOMP_UPDATE_UI(frame, resetSelection)
	local slotSet = GET_CHILD_RECURSIVELY(frame, "slotlist", "ui::CSlotSet")
	if slotSet == nil then
		return
	end

	if resetSelection ~= true then ARCH_DECOMP_GET_SELECTED_ITEMS(frame) end
	ARCH_DECOMP_CLEAR_SLOTSET(frame, slotSet)

	local materialItemList = ARCH_DECOMP_GET_MATERIAL_LIST()
	local invItemList = session.GetInvItemList()
	local visibleCount = 0
	local autoExcludedCount = 0
	local hiddenCount = 0

	FOR_EACH_INVENTORY(invItemList, function(invItemList, invItem, frame, slotSet, materialItemList)
		local obj = GetIES(invItem:GetObject())
		local itemName = TryGetProp(obj, "ClassName", "None")
		local point = materialItemList[itemName]
		if point == nil then
			return
		end

		-- 잠금·숨김 개수는 한도(ARCHEOLOGY_DECOMPOSE_MAX_SELECT)와 같은 칸 단위로 센다.
		-- 잠금 칸은 숨김에 다시 세지 않는다.
		local isLocked = ARCH_DECOMP_IS_LOCKED_ITEM(invItem)
		if isLocked == true then
			autoExcludedCount = autoExcludedCount + 1
		end

		local category = ARCH_DECOMP_GET_CATEGORY(itemName, point)
		if ARCH_DECOMP_IS_CATEGORY_VISIBLE(frame, category) ~= true then
			if isLocked ~= true then
				hiddenCount = hiddenCount + 1
			end
			return
		end

		local slotindex = imcSlot:GetEmptySlotIndex(slotSet)
		if slotindex == 0 and imcSlot:GetFilledSlotCount(slotSet) == slotSet:GetSlotCount() then
			slotSet:ExpandRow()
			slotindex = imcSlot:GetEmptySlotIndex(slotSet)
		end

		local slot = slotSet:GetSlotByIndex(slotindex)
		slot:SetMaxSelectCount(isLocked == true and 0 or invItem.count)
		slot:SetUserValue("ITEM_POINT", point)
		slot:SetUserValue("ITEM_COUNT", invItem.count)
		slot:SetUserValue("ITEM_CATEGORY", category)

		local isAutoExcluded = isLocked == true or ARCH_DECOMP_IS_AUTO_EXCLUDED_ITEM(category)
		slot:SetUserValue("LOCKED", isLocked == true and "YES" or "NO")
		slot:SetUserValue("AUTO_EXCLUDE", isAutoExcluded == true and "YES" or "NO")
		slot:SetUserValue("PROTECT_REASON", isLocked == true and "LOCK" or "NONE")
		if isAutoExcluded == true and isLocked ~= true then
			autoExcludedCount = autoExcludedCount + 1
		end

		local icon = CreateIcon(slot)
		icon:Set(obj.Icon, "Item", invItem.type, slotindex, invItem:GetIESID(), invItem.count)
		local class = GetClassByType("Item", invItem.type)
		SET_SLOT_ITEM_TEXT_USE_INVCOUNT(slot, invItem, obj, invItem.count)
		ICON_SET_INVENTORY_TOOLTIP(icon, invItem, "poisonpot", class)
		if isLocked == true then icon:SetColorTone("FF777777") end
		local selectedCount = ARCHEOLOGY_DECOMPOSE_SELECTION[invItem:GetIESID()] or 0
		slot:Select(selectedCount > 0 and 1 or 0)
		slot:SetSelectCount(selectedCount)

		visibleCount = visibleCount + invItem.count
	end, false, frame, slotSet, materialItemList)

	frame:SetUserValue("VISIBLE_COUNT", visibleCount)
	frame:SetUserValue("AUTO_EXCLUDED_COUNT", autoExcludedCount)
	frame:SetUserValue("HIDDEN_COUNT", hiddenCount)
	ARCH_DECOMP_UPDATE_POINT(frame)
end

function ARCH_DECOMP_GET_TOTAL_ADD_POINT(frame)
	local addPoint = 0
	for _, entry in ipairs(ARCH_DECOMP_GET_SELECTED_ITEMS(frame)) do
		addPoint = addPoint + entry.point * entry.count
	end
	return addPoint
end

-- 선택한 아이템 "칸" 수. 제한 단위와 같아야 하므로 수량 합계가 아니다.
function ARCH_DECOMP_GET_SELECT_COUNT(frame)
	return #ARCH_DECOMP_GET_SELECTED_ITEMS(frame)
end

local function ARCH_DECOMP_NORMALIZE_REWARD_CLASS_NAME(rewardClassName)
    if rewardClassName == ARCHEOLOGY_DECOMPOSE_LEGACY_REWARD_CLASS_NAME then
        return ARCHEOLOGY_DECOMPOSE_REWARD_CLASS_NAME
    end
    return rewardClassName
end

function ARCH_DECOMP_GET_REWARD_COUNTS(frame)
    local rows, count = GetClassList("PointExtractItem")
    local byItem = {}
    local rewards = {[ARCHEOLOGY_DECOMPOSE_REWARD_CLASS_NAME] = 0}
    for i = 0, count - 1 do
        local row = GetClassByIndexFromList(rows, i)
        if TryGetProp(row, "PointName", "None") == ARCHEOLOGY_DECOMPOSE_POINT_NAME then
            local reward = TryGetProp(row, "RewardClassName", "None")
            if reward ~= "None" then
                byItem[row.ItemClassName] = row
            end
        end
    end
    for _, entry in ipairs(ARCH_DECOMP_GET_SELECTED_ITEMS(frame)) do
        local row = byItem[entry.className]
        if row then
            local reward = ARCH_DECOMP_NORMALIZE_REWARD_CLASS_NAME(row.RewardClassName)
            rewards[reward] = (rewards[reward] or 0) + row.Point * entry.count
        end
    end
    return rewards
end

function ARCH_DECOMP_REWARD_SUMMARY(frame, rewards, mode)
    local names, lines = {}, {}
    for name in pairs(rewards) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local cls = GetClass("Item", name)
        if cls then
            local count = rewards[name]
            if mode == "OWNED" then count = session.GetInvItemCountByType(cls.ClassID)
            elseif mode == "AFTER" then count = count + session.GetInvItemCountByType(cls.ClassID) end
            lines[#lines + 1] = string.format(frame:GetUserConfig("REWARD_LINE_FORMAT"), cls.Name, count)
        end
    end
    return table.concat(lines, frame:GetUserConfig("REWARD_LINE_SEPARATOR"))
end

function ARCH_DECOMP_UPDATE_POINT(frame)
	local rewards = ARCH_DECOMP_GET_REWARD_COUNTS(frame)

	local totalPoint = GET_CHILD_RECURSIVELY(frame, "totalPoint")
	local addPoint = GET_CHILD_RECURSIVELY(frame, "addPoint")
	local afterPoint = GET_CHILD_RECURSIVELY(frame, "afterPoint")
	local statusText = GET_CHILD_RECURSIVELY(frame, "statusText")
	local decomposecnt = GET_CHILD_RECURSIVELY(frame, "decomposecnt")

	totalPoint:SetTextByKey("value", ARCH_DECOMP_REWARD_SUMMARY(frame, rewards, "OWNED"))
	addPoint:SetTextByKey("value", ARCH_DECOMP_REWARD_SUMMARY(frame, rewards, "GAIN"))
	afterPoint:SetTextByKey("value", ARCH_DECOMP_REWARD_SUMMARY(frame, rewards, "AFTER"))
	decomposecnt:SetTextByKey("cnt", ARCH_DECOMP_GET_SELECT_COUNT(frame))
	decomposecnt:SetTextByKey("max", ARCHEOLOGY_DECOMPOSE_MAX_SELECT)

	local autoExcludedCount = tonumber(frame:GetUserValue("AUTO_EXCLUDED_COUNT")) or 0
	local hiddenCount = tonumber(frame:GetUserValue("HIDDEN_COUNT")) or 0
	statusText:SetTextByKey("protected", autoExcludedCount)
	statusText:SetTextByKey("hidden", hiddenCount)
	local hiddenSelected = 0
	for _, entry in ipairs(ARCH_DECOMP_GET_SELECTED_ITEMS(frame)) do
		if ARCH_DECOMP_IS_CATEGORY_VISIBLE(frame, ARCH_DECOMP_GET_CATEGORY(entry.className, entry.point)) ~= true then
			hiddenSelected = hiddenSelected + 1
		end
	end
	statusText:SetTextByKey("selected_hidden", hiddenSelected)

	ARCH_DECOMP_SET_MATERIAL_POINT_INFO_LIST(frame)
end

function ARCH_DECOMP_SET_MATERIAL_POINT_INFO_LIST(frame)
	local gbox = GET_CHILD_RECURSIVELY(frame, "materialInfoGbox")
	if gbox == nil then return end
	gbox:RemoveAllChild()
	local items = ARCH_DECOMP_GET_SELECTED_ITEMS(frame)
	for i, entry in ipairs(items) do
		local line = gbox:CreateOrGetControlSet("archeology_decompose_point_line", "point_line_" .. i, 12, 10 + (i - 1) * 26)
		local text = GET_CHILD_RECURSIVELY(line, "text", "ui::CRichText")
		local itemCls = GetClass("Item", entry.className)
		text:SetTextByKey("name", TryGetProp(itemCls, "Name", entry.className or ""))
		text:SetTextByKey("point", entry.point)
		text:SetTextByKey("count", entry.count)
		text:SetTextByKey("total", entry.point * entry.count)
	end
	if #items == 0 then
		gbox:CreateOrGetControlSet("archeology_decompose_empty_line", "point_line_empty", 12, 10)
	end
end

function ARCH_DECOMP_FILTER_CHANGED(parent, ctrl)
	local frame = parent:GetTopParentFrame()
	ARCH_DECOMP_UPDATE_UI(frame)
end

function ARCH_DECOMP_SLOT_CLICK(parent, ctrl)
	ui.EnableSlotMultiSelect(1)
	ARCH_DECOMP_UPDATE_POINT(parent:GetTopParentFrame())
end

function ARCH_DECOMP_DESELECT_ALL(parent, ctrl)
	ARCHEOLOGY_DECOMPOSE_SELECTION = {}
	local frame = parent:GetTopParentFrame()
	local slotSet = GET_CHILD_RECURSIVELY(frame, "slotlist", "ui::CSlotSet")
	for i = 0, slotSet:GetSlotCount() - 1 do
		local slot = slotSet:GetSlotByIndex(i)
		if slot:GetIcon() ~= nil then
			slot:Select(0)
			slot:SetSelectCount(0)
		end
	end
	slotSet:MakeSelectionList()
	ARCH_DECOMP_UPDATE_POINT(frame)
end

function ARCH_DECOMP_AUTO_REGISTER(parent, ctrl)
	ARCHEOLOGY_DECOMPOSE_SELECTION = {}
	ui.EnableSlotMultiSelect(1)

	local frame = parent:GetTopParentFrame()
	local slotSet = GET_CHILD_RECURSIVELY(frame, "slotlist", "ui::CSlotSet")
	local count = 0
	local protectedSkipped = 0

	for i = 0, slotSet:GetSlotCount() - 1 do
		local slot = slotSet:GetSlotByIndex(i)
		local icon = slot:GetIcon()
		if icon ~= nil then
			slot:Select(0)
			slot:SetSelectCount(0)

			local itemCount = tonumber(slot:GetUserValue("ITEM_COUNT")) or 0
			if slot:GetUserValue("AUTO_EXCLUDE") == "YES" then
				protectedSkipped = protectedSkipped + itemCount
			elseif count < ARCHEOLOGY_DECOMPOSE_MAX_SELECT and itemCount > 0 then
				-- 칸 단위로 채운다. 스택형 아이템은 한 칸을 통째로 선택하므로
				-- 한 종류가 한도를 전부 소진하지 않는다.
				slot:Select(1)
				slot:SetSelectCount(itemCount)
				count = count + 1
			end
		end
	end

	slotSet:MakeSelectionList()
	frame:SetUserValue("LAST_AUTO_SKIPPED", protectedSkipped)
	ARCH_DECOMP_UPDATE_POINT(frame)
end

function ARCH_DECOMP_BUILD_SELECTED_ITEM_LIST(frame)
	return ARCH_DECOMP_GET_SELECTED_ITEMS(frame)
end

function ARCH_DECOMP_EXEC(parent, ctrl)
	local frame = parent:GetTopParentFrame()
	local selectedItems = ARCH_DECOMP_BUILD_SELECTED_ITEM_LIST(frame)
	local selectedCount = 0
	local addPoint = 0
	for _, entry in ipairs(selectedItems) do
		selectedCount = selectedCount + entry.count
		addPoint = addPoint + entry.point * entry.count
	end
	if selectedCount < 1 or addPoint <= 0 then
		ui.MsgBox(ScpArgMsg("SelectSomeItemPlz"))
		return
	end
	if #selectedItems > ARCHEOLOGY_DECOMPOSE_MAX_SELECT then
		ui.MsgBox(ScpArgMsg("EXCEED_SELECT_COUNT"))
		return
	end
	ARCHEOLOGY_DECOMPOSE_PENDING_ITEMS = selectedItems
	local rewards = ARCH_DECOMP_GET_REWARD_COUNTS(frame)
	ui.MsgBox(string.format(frame:GetUserConfig("CONFIRM_REWARDS"), ARCH_DECOMP_REWARD_SUMMARY(frame, rewards, "GAIN")), "ARCH_DECOMP_EXEC_COMMIT", "None")
end

function ARCH_DECOMP_EXEC_COMMIT()
	local items = ARCHEOLOGY_DECOMPOSE_PENDING_ITEMS
	ARCHEOLOGY_DECOMPOSE_PENDING_ITEMS = nil
	if items == nil or #items == 0 then return end
	local materials = ARCH_DECOMP_GET_MATERIAL_LIST()
	session.ResetItemList()
	for _, entry in ipairs(items) do
		local invItem = GET_ITEM_BY_GUID(entry.iesID)
		if invItem == nil or invItem.count < entry.count then
			ui.SysMsg(ScpArgMsg("InvalidTarget"))
			return
		end
		if ARCH_DECOMP_IS_LOCKED_ITEM(invItem) == true then
			ui.SysMsg(ClMsg("MaterialItemIsLockEither"))
			return
		end
		local obj = GetIES(invItem:GetObject())
		if TryGetProp(obj, "ClassName", "None") ~= entry.className or materials[entry.className] ~= entry.point then
			ui.SysMsg(ScpArgMsg("InvalidTarget"))
			return
		end
	end
	for _, entry in ipairs(items) do session.AddItemID(entry.iesID, entry.count) end
	local argStrList = NewStringList()
	argStrList:Add(ARCHEOLOGY_DECOMPOSE_POINT_NAME)
	item.DialogTransaction("ITEM_POINT_EXTRACT", session.GetItemIDList(), "", argStrList)
end

function ON_ARCHEOLOGY_DECOMPOSE_EXECUTE_RESULT(frame, msg, argStr, argNum)
	if frame == nil or frame:IsVisible() == 0 then
		return
	end
	-- 분해 결과면 남은 스택을 선택된 채로 두지 않는다. 인벤 변화·잠금 변경은 선택을 유지한다.
	if msg == "ITEM_POINT_EXTRACTOR_EXECUTE" then
		ARCHEOLOGY_DECOMPOSE_SELECTION = {}
		ARCH_DECOMP_UPDATE_UI(frame, true)
		return
	end
	ARCH_DECOMP_UPDATE_UI(frame)
end
