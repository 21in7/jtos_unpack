local json = require('json')
local PATH = require('path')

FIELDLOOT = FIELDLOOT or {}

local FL = FIELDLOOT
local SETTINGS_PATH_FORMAT = '..\\release\\addon_setting\\fieldloot\\%s\\settings.json'
local LEGACY_SETTINGS_PATH_FORMAT = '..\\release\\addon_setting\\farmtracker\\%s\\settings.json'
local SETTINGS_VERSION = 3
local RARE_GRADE = 5
local MERCENARY_BADGE_CLASS_NAME = 'misc_pvp_mine2'
local FRAME_WIDTH = 260
local FRAME_COLLAPSED_HEIGHT = 30
local FRAME_EXPANDED_HEIGHT = 202
local BODY_EXPANDED_HEIGHT = 172

local function FIELDLOOT_DEFAULT_SETTINGS()
	return {
		version = SETTINGS_VERSION,
		enabled = true,
		locked = false,
		collapsed = false,
		position = nil
	}
end

local function FIELDLOOT_NEW_SESSION()
	return {
		started = false,
		running = true,
		elapsed = 0,
		runStartedAt = nil,
		items = {},
		totalCount = 0,
		silver = 0,
		mercenaryBadge = 0,
		currentMap = nil,
		maps = {}
	}
end

local function FIELDLOOT_GET_SESSION()
	if FL.session == nil then
		FL.session = FIELDLOOT_NEW_SESSION()
	end
	FL.session.silver = tonumber(FL.session.silver) or 0
	FL.session.mercenaryBadge = tonumber(FL.session.mercenaryBadge) or 0
	return FL.session
end

local function FIELDLOOT_GET_CURRENT_MAP()
	local mapName = session.GetMapName()
	if mapName == nil or mapName == '' then
		return 'None'
	end
	return mapName
end

local function FIELDLOOT_GET_MAP_DATA(mapName)
	local trackerSession = FIELDLOOT_GET_SESSION()
	local mapData = trackerSession.maps[mapName]
	if mapData == nil then
		mapData = {
			elapsed = 0,
			runStartedAt = nil,
			totalCount = 0,
			silver = 0,
			mercenaryBadge = 0
		}
		trackerSession.maps[mapName] = mapData
	end
	mapData.silver = tonumber(mapData.silver) or 0
	mapData.mercenaryBadge = tonumber(mapData.mercenaryBadge) or 0
	return mapData
end

local function FIELDLOOT_GET_ELAPSED(now)
	local trackerSession = FIELDLOOT_GET_SESSION()
	local elapsed = trackerSession.elapsed or 0
	if trackerSession.started == true and trackerSession.running == true and trackerSession.runStartedAt ~= nil then
		elapsed = elapsed + math.max(0, now - trackerSession.runStartedAt)
	end
	return elapsed
end

local function FIELDLOOT_GET_MAP_ELAPSED(mapName, now)
	local mapData = FIELDLOOT_GET_MAP_DATA(mapName)
	local elapsed = mapData.elapsed or 0
	local trackerSession = FIELDLOOT_GET_SESSION()
	if trackerSession.started == true and trackerSession.running == true and trackerSession.currentMap == mapName and mapData.runStartedAt ~= nil then
		elapsed = elapsed + math.max(0, now - mapData.runStartedAt)
	end
	return elapsed
end

local function FIELDLOOT_SYNC_MAP(now)
	local trackerSession = FIELDLOOT_GET_SESSION()
	if trackerSession.started ~= true or trackerSession.running ~= true then
		return
	end

	local mapName = FIELDLOOT_GET_CURRENT_MAP()
	if trackerSession.currentMap == mapName then
		return
	end

	if trackerSession.currentMap ~= nil then
		local previousMap = FIELDLOOT_GET_MAP_DATA(trackerSession.currentMap)
		if previousMap.runStartedAt ~= nil then
			previousMap.elapsed = previousMap.elapsed + math.max(0, now - previousMap.runStartedAt)
			previousMap.runStartedAt = nil
		end
	end

	trackerSession.currentMap = mapName
	local currentMap = FIELDLOOT_GET_MAP_DATA(mapName)
	currentMap.runStartedAt = now
end

local function FIELDLOOT_START_SESSION(now)
	local trackerSession = FIELDLOOT_GET_SESSION()
	if trackerSession.started == true then
		return
	end

	trackerSession.started = true
	trackerSession.runStartedAt = now
	trackerSession.currentMap = FIELDLOOT_GET_CURRENT_MAP()
	local mapData = FIELDLOOT_GET_MAP_DATA(trackerSession.currentMap)
	mapData.runStartedAt = now
end

local function FIELDLOOT_FORMAT_NUMBER(value)
	value = tonumber(value) or 0
	return GET_COMMAED_STRING2(math.floor(value + 0.5))
end

local function FIELDLOOT_FORMAT_TIME(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local remainSeconds = seconds % 60
	return string.format('%02d:%02d:%02d', hours, minutes, remainSeconds)
end

local function FIELDLOOT_FORMAT_RECENT(lastAt, now)
	if lastAt == nil then
		return 'UNKNOWN', nil
	end

	local elapsed = math.max(0, math.floor(now - lastAt))
	if elapsed < 10 then
		return 'NOW', nil
	elseif elapsed < 60 then
		return 'SECONDS', elapsed
	elseif elapsed < 3600 then
		return 'MINUTES', math.floor(elapsed / 60)
	end
	return 'HOURS', math.floor(elapsed / 3600)
end

local function FIELDLOOT_GET_ITEM_NAME(itemCls)
	local className = TryGetProp(itemCls, 'ClassName', '')
	local name = TryGetProp(itemCls, 'Name', className)
	local translatedName = TranArgMsg(name)
	if translatedName == nil or translatedName == '' or translatedName == 'None' then
		return className
	end
	return translatedName
end

local function FIELDLOOT_GET_MAP_DISPLAY_NAME(mapName)
	if mapName == nil or mapName == '' or mapName == 'None' then
		return nil
	end

	local mapCls = GetClass('Map', mapName)
	if mapCls == nil then
		return mapName
	end

	local displayName = TryGetProp(mapCls, 'Name', mapName)
	if displayName == nil or displayName == '' or displayName == 'None' then
		return mapName
	end
	return displayName
end

local function FIELDLOOT_GET_UNIQUE_COUNT(mapName)
	local count = 0
	local trackerSession = FIELDLOOT_GET_SESSION()
	for _, itemData in pairs(trackerSession.items) do
		local itemCount = itemData.count
		if mapName ~= nil then
			itemCount = itemData.mapCounts[mapName] or 0
		end
		if itemCount > 0 then
			count = count + 1
		end
	end
	return count
end

local function FIELDLOOT_GET_SORTED_ITEMS(mapName, rareOnly, sortMode)
	local result = {}
	local trackerSession = FIELDLOOT_GET_SESSION()
	for _, itemData in pairs(trackerSession.items) do
		local itemCount = itemData.count
		local lastAt = itemData.lastAt
		if mapName ~= nil then
			itemCount = itemData.mapCounts[mapName] or 0
			lastAt = itemData.mapLastAt[mapName]
		end

		if itemCount > 0 and (rareOnly ~= true or itemData.grade >= RARE_GRADE) then
			result[#result + 1] = {
				data = itemData,
				count = itemCount,
				lastAt = lastAt
			}
		end
	end

	table.sort(result, function(a, b)
		if sortMode == 'RECENT' and a.lastAt ~= b.lastAt then
			return (a.lastAt or 0) > (b.lastAt or 0)
		elseif sortMode == 'GRADE' and a.data.grade ~= b.data.grade then
			return a.data.grade > b.data.grade
		elseif a.count ~= b.count then
			return a.count > b.count
		elseif a.lastAt ~= b.lastAt then
			return (a.lastAt or 0) > (b.lastAt or 0)
		end
		return a.data.classID < b.data.classID
	end)

	return result
end

local function FIELDLOOT_MERGE_SETTINGS(loaded)
	local settings = FIELDLOOT_DEFAULT_SETTINGS()
	if type(loaded) == 'table' then
		for key, value in pairs(loaded) do
			settings[key] = value
		end
	end
	FL.settings = settings
end

local function FIELDLOOT_MIGRATE_SETTINGS()
	if FL.settings == nil then
		FIELDLOOT_MERGE_SETTINGS(nil)
	end

	local version = tonumber(FL.settings.version) or 1
	local changed = false
	if version < 2 then
		FL.settings.locked = false
		changed = true
	end

	if FL.settings.enabled == nil then
		FL.settings.enabled = true
		changed = true
	end
	if version < SETTINGS_VERSION then
		FL.settings.version = SETTINGS_VERSION
		changed = true
	end
	return changed
end

local function FIELDLOOT_ENSURE_SETTINGS_DIRECTORY()
	if FL.settingsFile == nil then
		return false
	end
	local userDirectory = PATH.dirname(FL.settingsFile)
	local addonDirectory = PATH.dirname(userDirectory)
	if MakeDirectory(PATH.dirname(addonDirectory)) == false then
		return false
	end
	if MakeDirectory(addonDirectory) == false then
		return false
	end
	return MakeDirectory(userDirectory) ~= false
end

local function FIELDLOOT_SAVE_SETTINGS()
	if FL.settingsFile == nil or FL.settings == nil then
		return
	end
	if FIELDLOOT_ENSURE_SETTINGS_DIRECTORY() == false then
		return
	end
	save_json(FL.settingsFile, FL.settings)
end

local function FIELDLOOT_SAVE_POSITION_IF_CHANGED(frame)
	if frame == nil or FL.settings == nil or FL.settings.locked == true then
		return false
	end

	local x = frame:GetX()
	local y = frame:GetY()
	local savedPosition = FL.settings.position
	if savedPosition ~= nil and tonumber(savedPosition.x) == x and tonumber(savedPosition.y) == y then
		return false
	end

	FL.settings.position = {
		x = x,
		y = y
	}
	FIELDLOOT_SAVE_SETTINGS()
	return true
end

local function FIELDLOOT_GET_MAIN_FRAME(frame)
	local mainFrame = ui.GetFrame('fieldloot')
	if mainFrame ~= nil then
		return mainFrame
	end
	return frame
end

local function FIELDLOOT_SET_VISIBLE(control, visible)
	if control == nil then
		return
	end
	control:ShowWindow(visible == true and 1 or 0)
end

local function FIELDLOOT_APPLY_LOCK(frame)
	frame = FIELDLOOT_GET_MAIN_FRAME(frame)
	if frame == nil or FL.settings == nil then
		return
	end

	local locked = FL.settings.locked == true
	frame:EnableMove(not locked)

	local lockButton = GET_CHILD_RECURSIVELY(frame, 'lockButton')
	local unlockButton = GET_CHILD_RECURSIVELY(frame, 'unlockButton')
	FIELDLOOT_SET_VISIBLE(lockButton, not locked)
	FIELDLOOT_SET_VISIBLE(unlockButton, locked)
end

local function FIELDLOOT_APPLY_COLLAPSED(frame)
	frame = FIELDLOOT_GET_MAIN_FRAME(frame)
	if frame == nil or FL.settings == nil then
		return
	end

	local collapsed = FL.settings.collapsed == true
	local background = GET_CHILD_RECURSIVELY(frame, 'background')
	local body = GET_CHILD_RECURSIVELY(frame, 'body')
	local collapseButton = GET_CHILD_RECURSIVELY(frame, 'collapseButton')
	local expandButton = GET_CHILD_RECURSIVELY(frame, 'expandButton')

	if collapsed == true then
		frame:Resize(FRAME_WIDTH, FRAME_COLLAPSED_HEIGHT)
		if background ~= nil then
			background:Resize(FRAME_WIDTH, FRAME_COLLAPSED_HEIGHT)
		end
		if body ~= nil then
			body:ShowWindow(0)
		end
		FIELDLOOT_SET_VISIBLE(collapseButton, false)
		FIELDLOOT_SET_VISIBLE(expandButton, true)
	else
		frame:Resize(FRAME_WIDTH, FRAME_EXPANDED_HEIGHT)
		if background ~= nil then
			background:Resize(FRAME_WIDTH, FRAME_EXPANDED_HEIGHT)
		end
		if body ~= nil then
			body:Resize(FRAME_WIDTH, BODY_EXPANDED_HEIGHT)
			body:ShowWindow(1)
		end
		FIELDLOOT_SET_VISIBLE(collapseButton, true)
		FIELDLOOT_SET_VISIBLE(expandButton, false)
	end

	frame:Invalidate()
end

local function FIELDLOOT_LOAD_SETTINGS(frame)
	local userID = session.loginInfo.GetUserID()
	if userID == nil or userID == '' then
		userID = '0'
	end

	if FL.settingsUserID ~= userID then
		FL.settingsLoaded = false
		FL.settingsUserID = userID
	end

	if FL.settingsLoaded ~= true then
		FL.settingsFile = string.format(SETTINGS_PATH_FORMAT, userID)
		local defaults = FIELDLOOT_DEFAULT_SETTINGS()
		local loaded, err = load_json(FL.settingsFile, defaults)
		if err then
			local legacySettingsFile = string.format(LEGACY_SETTINGS_PATH_FORMAT, userID)
			local legacyLoaded, legacyErr = load_json(legacySettingsFile, defaults)
			if legacyErr then
				FIELDLOOT_MERGE_SETTINGS(defaults)
			else
				FIELDLOOT_MERGE_SETTINGS(legacyLoaded)
				FIELDLOOT_SAVE_SETTINGS()
			end
		else
			FIELDLOOT_MERGE_SETTINGS(loaded)
		end
		FL.settingsLoaded = true
	end

	if FIELDLOOT_MIGRATE_SETTINGS() == true then
		FIELDLOOT_SAVE_SETTINGS()
	end

	if FL.settings.position ~= nil then
		local x = tonumber(FL.settings.position.x)
		local y = tonumber(FL.settings.position.y)
		if x ~= nil and y ~= nil then
			x = math.max(0, math.min(x, ui.GetClientInitialWidth() - frame:GetWidth()))
			y = math.max(0, math.min(y, ui.GetClientInitialHeight() - frame:GetHeight()))
			frame:MoveFrame(x, y)
		end
	end

	FIELDLOOT_APPLY_LOCK(frame)
	FIELDLOOT_APPLY_COLLAPSED(frame)
end

local function FIELDLOOT_SET_TIMER_ENABLED(frame, enabled)
	local timer = GET_CHILD_RECURSIVELY(frame, 'addontimer')
	if timer == nil then
		return
	end
	tolua.cast(timer, 'ui::CAddOnTimer')
	if enabled then
		timer:SetUpdateScript('FIELDLOOT_ON_TIMER')
		timer:Start(0.1)
	else
		timer:Stop()
	end
end

local function FIELDLOOT_SUSPEND_SESSION(now)
	local trackerSession = FIELDLOOT_GET_SESSION()
	if trackerSession.started ~= true or trackerSession.running ~= true then
		return
	end

	FIELDLOOT_SYNC_MAP(now)
	if trackerSession.runStartedAt ~= nil then
		trackerSession.elapsed = trackerSession.elapsed + math.max(0, now - trackerSession.runStartedAt)
		trackerSession.runStartedAt = nil
	end
	if trackerSession.currentMap ~= nil then
		local mapData = FIELDLOOT_GET_MAP_DATA(trackerSession.currentMap)
		if mapData.runStartedAt ~= nil then
			mapData.elapsed = mapData.elapsed + math.max(0, now - mapData.runStartedAt)
			mapData.runStartedAt = nil
		end
	end
end

local function FIELDLOOT_RESUME_SESSION(now)
	local trackerSession = FIELDLOOT_GET_SESSION()
	if trackerSession.started ~= true or trackerSession.running ~= true then
		return
	end

	trackerSession.runStartedAt = now
	trackerSession.currentMap = FIELDLOOT_GET_CURRENT_MAP()
	local mapData = FIELDLOOT_GET_MAP_DATA(trackerSession.currentMap)
	mapData.runStartedAt = now
end

function FIELDLOOT_IS_ENABLED()
	local frame = ui.GetFrame('fieldloot')
	if FL.settings == nil and frame ~= nil then
		FIELDLOOT_LOAD_SETTINGS(frame)
	end
	return FL.settings ~= nil and FL.settings.enabled ~= false
end

function FIELDLOOT_SET_ENABLED(enabled)
	local frame = ui.GetFrame('fieldloot')
	if frame == nil then
		return false
	end
	if FL.settings == nil then
		FIELDLOOT_LOAD_SETTINGS(frame)
	end
	if FL.settings == nil then
		return false
	end

	local nextEnabled = enabled == true or tonumber(enabled) == 1
	if FL.settings.enabled == nextEnabled then
		return true
	end

	local now = imcTime.GetAppTime()
	if nextEnabled then
		FL.settings.enabled = true
		FIELDLOOT_SAVE_SETTINGS()
		FIELDLOOT_RESUME_SESSION(now)
		FIELDLOOT_SET_TIMER_ENABLED(frame, true)
		frame:ShowWindow(1)
		FIELDLOOT_REFRESH_COMPACT(frame)
	else
		FIELDLOOT_SUSPEND_SESSION(now)
		FIELDLOOT_SAVE_POSITION_IF_CHANGED(frame)
		FL.settings.enabled = false
		FIELDLOOT_SAVE_SETTINGS()
		FIELDLOOT_SET_TIMER_ENABLED(frame, false)
		frame:ShowWindow(0)
		ui.CloseFrame('fieldloot_detail')
	end
	return true
end

local function FIELDLOOT_UPDATE_FARMING_TIME(now)
	local trackerSession = FIELDLOOT_GET_SESSION()
	if trackerSession.running ~= true or trackerSession.started == true then
		return
	end

	local pc = GetMyPCObject()
	if pc == nil or IsBattleState == nil then
		return
	end

	local success, battleState = pcall(IsBattleState, pc)
	if success == true and tonumber(battleState) == 1 then
		FIELDLOOT_START_SESSION(now)
	end
end

function FIELDLOOT_ON_INIT(addon, frame)
	addon:RegisterMsg('ITEM_PICK', 'FIELDLOOT_ON_ITEM_PICK')
	addon:RegisterMsg('TAKE_DAMAGE', 'FIELDLOOT_ON_COMBAT_SIGNAL')
	frame = FIELDLOOT_GET_MAIN_FRAME(frame)
	if frame == nil then
		return
	end

	local mySession = session.GetMySession()
	local cid = '0'
	if mySession ~= nil then
		cid = tostring(mySession:GetCID())
	end
	if FL.characterCID ~= cid then
		FL.characterCID = cid
		FL.session = FIELDLOOT_NEW_SESSION()
	end

	FL.detailMapMode = FL.detailMapMode or 'ALL'
	FL.detailRareOnly = FL.detailRareOnly or false
	FL.detailSortMode = FL.detailSortMode or 'COUNT'

	FIELDLOOT_LOAD_SETTINGS(frame)
	frame:SetEventScript(ui.LBUTTONUP, 'FIELDLOOT_SAVE_POSITION')

	FL.nextDisplayRefreshAt = 0
	FIELDLOOT_SET_TIMER_ENABLED(frame, FL.settings.enabled ~= false)
	if FL.settings.enabled == false then
		frame:ShowWindow(0)
		ui.CloseFrame('fieldloot_detail')
		return
	end
	frame:ShowWindow(1)
	FIELDLOOT_REFRESH_COMPACT(frame)
end

function FIELDLOOT_ON_COMBAT_SIGNAL(frame, msg, argStr, argNum)
	if FIELDLOOT_IS_ENABLED() == false then
		return
	end
	local trackerSession = FIELDLOOT_GET_SESSION()
	if trackerSession.running ~= true then
		return
	end

	local now = imcTime.GetAppTime()
	FIELDLOOT_START_SESSION(now)
	FIELDLOOT_SYNC_MAP(now)
	FIELDLOOT_REFRESH_COMPACT(frame)
end

function FIELDLOOT_ON_ITEM_PICK(frame, msg, itemType, itemCount)
	if FIELDLOOT_IS_ENABLED() == false then
		return
	end
	local trackerSession = FIELDLOOT_GET_SESSION()
	if trackerSession.running ~= true then
		return
	end

	itemType = tonumber(itemType)
	itemCount = tonumber(itemCount)
	if itemType == nil or itemCount == nil or itemCount <= 0 then
		return
	end

	local itemCls = GetClassByType('Item', itemType)
	if itemCls == nil then
		return
	end

	local className = TryGetProp(itemCls, 'ClassName', 'None')
	local isSilver = className == 'Vis'
	local isMercenaryBadge = className == MERCENARY_BADGE_CLASS_NAME
	if isSilver ~= true and isMercenaryBadge ~= true and TryGetProp(itemCls, 'ItemType', 'None') == 'Unused' then
		return
	end

	local now = imcTime.GetAppTime()
	FIELDLOOT_START_SESSION(now)
	FIELDLOOT_SYNC_MAP(now)

	local mapName = FIELDLOOT_GET_CURRENT_MAP()
	local mapData = FIELDLOOT_GET_MAP_DATA(mapName)

	if isSilver == true then
		trackerSession.silver = trackerSession.silver + itemCount
		mapData.silver = mapData.silver + itemCount
	elseif isMercenaryBadge == true then
		trackerSession.mercenaryBadge = trackerSession.mercenaryBadge + itemCount
		mapData.mercenaryBadge = mapData.mercenaryBadge + itemCount
	else
		local itemData = trackerSession.items[itemType]
		if itemData == nil then
			itemData = {
				classID = itemType,
				className = className,
				name = FIELDLOOT_GET_ITEM_NAME(itemCls),
				icon = GET_ITEM_ICON_IMAGE(itemCls),
				grade = tonumber(TryGetProp(itemCls, 'ItemGrade', 0)) or 0,
				count = 0,
				lastAt = now,
				mapCounts = {},
				mapLastAt = {}
			}
			trackerSession.items[itemType] = itemData
		end

		itemData.count = itemData.count + itemCount
		itemData.lastAt = now
		itemData.mapCounts[mapName] = (itemData.mapCounts[mapName] or 0) + itemCount
		itemData.mapLastAt[mapName] = now
		trackerSession.totalCount = trackerSession.totalCount + itemCount
		mapData.totalCount = mapData.totalCount + itemCount
	end

	FIELDLOOT_REFRESH_COMPACT(frame)
	local detailFrame = ui.GetFrame('fieldloot_detail')
	if detailFrame ~= nil and detailFrame:IsVisible() == 1 then
		FIELDLOOT_REFRESH_DETAIL(detailFrame)
	end
end

function FIELDLOOT_ON_TIMER(frame, timer, argStr, argNum, passedTime)
	if FIELDLOOT_IS_ENABLED() == false then
		return 1
	end
	FIELDLOOT_SAVE_POSITION_IF_CHANGED(frame)

	local now = imcTime.GetAppTime()
	FIELDLOOT_UPDATE_FARMING_TIME(now)
	FIELDLOOT_SYNC_MAP(now)

	if now >= (FL.nextDisplayRefreshAt or 0) then
		FL.nextDisplayRefreshAt = now + 0.5
		FIELDLOOT_REFRESH_COMPACT(frame)

		local detailFrame = ui.GetFrame('fieldloot_detail')
		if detailFrame ~= nil and detailFrame:IsVisible() == 1 then
			FIELDLOOT_REFRESH_DETAIL(detailFrame)
		end
	end
end

function FIELDLOOT_SAVE_POSITION(frame)
	frame = FIELDLOOT_GET_MAIN_FRAME(frame)
	FIELDLOOT_SAVE_POSITION_IF_CHANGED(frame)
end

function FIELDLOOT_TOGGLE_LOCK(frame, ctrl)
	frame = FIELDLOOT_GET_MAIN_FRAME(frame)
	if frame == nil or FL.settings == nil then
		return
	end

	FL.settings.locked = FL.settings.locked ~= true
	FL.settings.position = {
		x = frame:GetX(),
		y = frame:GetY()
	}
	FIELDLOOT_APPLY_LOCK(frame)
	FIELDLOOT_SAVE_SETTINGS()
end

function FIELDLOOT_TOGGLE_COLLAPSE(frame, ctrl)
	frame = FIELDLOOT_GET_MAIN_FRAME(frame)
	if frame == nil or FL.settings == nil then
		return
	end

	FL.settings.collapsed = FL.settings.collapsed ~= true
	FIELDLOOT_APPLY_COLLAPSED(frame)
	FIELDLOOT_SAVE_SETTINGS()
end

function FIELDLOOT_TOGGLE_PAUSE(frame, ctrl)
	frame = FIELDLOOT_GET_MAIN_FRAME(frame)
	if frame == nil then
		return
	end

	local trackerSession = FIELDLOOT_GET_SESSION()
	local now = imcTime.GetAppTime()

	if trackerSession.running == true then
		if trackerSession.started == true then
			FIELDLOOT_SYNC_MAP(now)
			trackerSession.elapsed = trackerSession.elapsed + math.max(0, now - trackerSession.runStartedAt)
			trackerSession.runStartedAt = nil

			if trackerSession.currentMap ~= nil then
				local mapData = FIELDLOOT_GET_MAP_DATA(trackerSession.currentMap)
				if mapData.runStartedAt ~= nil then
					mapData.elapsed = mapData.elapsed + math.max(0, now - mapData.runStartedAt)
					mapData.runStartedAt = nil
				end
			end
		end
		trackerSession.running = false
	else
		trackerSession.running = true
		if trackerSession.started == true then
			trackerSession.runStartedAt = now
			trackerSession.currentMap = FIELDLOOT_GET_CURRENT_MAP()
			local mapData = FIELDLOOT_GET_MAP_DATA(trackerSession.currentMap)
			mapData.runStartedAt = now
		end
	end

	FIELDLOOT_REFRESH_COMPACT(frame)
	local detailFrame = ui.GetFrame('fieldloot_detail')
	if detailFrame ~= nil and detailFrame:IsVisible() == 1 then
		FIELDLOOT_REFRESH_DETAIL(detailFrame)
	end
end

function FIELDLOOT_REQUEST_RESET(frame, ctrl)
	local detailFrame = ui.GetFrame('fieldloot_detail')
	if detailFrame == nil then
		return
	end

	local confirmText = GET_CHILD_RECURSIVELY(detailFrame, 'resetConfirmText')
	if confirmText == nil then
		return
	end
	ui.MsgBox(confirmText:GetText(), 'FIELDLOOT_RESET()', 'None')
end

function FIELDLOOT_RESET()
	FL.session = FIELDLOOT_NEW_SESSION()

	local frame = ui.GetFrame('fieldloot')
	if frame ~= nil then
		FIELDLOOT_REFRESH_COMPACT(frame)
	end

	local detailFrame = ui.GetFrame('fieldloot_detail')
	if detailFrame ~= nil and detailFrame:IsVisible() == 1 then
		FIELDLOOT_REFRESH_DETAIL(detailFrame)
	end
end

local function FIELDLOOT_REFRESH_RECENT_SLOTS(frame)
	local recentSlotset = GET_CHILD_RECURSIVELY(frame, 'recentSlotset')
	if recentSlotset == nil then
		return false
	end
	tolua.cast(recentSlotset, 'ui::CSlotSet')

	recentSlotset:ClearIconAll()
	local recentItems = FIELDLOOT_GET_SORTED_ITEMS(nil, false, 'RECENT')
	local slotCount = recentSlotset:GetSlotCount()
	for index = 0, slotCount - 1 do
		local slot = recentSlotset:GetSlotByIndex(index)
		if slot ~= nil then
			slot:ShowWindow(1)
			local sortedItem = recentItems[index + 1]
			if sortedItem ~= nil then
				local itemData = sortedItem.data
				local itemCls = GetClassByType('Item', itemData.classID)
				if itemCls ~= nil then
					SET_SLOT_ITEM_CLS(slot, itemCls)
					local icon = slot:GetIcon()
					if icon ~= nil then
						SET_ITEM_TOOLTIP_BY_NAME(icon, itemData.className)
					end
				end
			end
		end
	end
	return true
end

function FIELDLOOT_REFRESH_COMPACT(frame)
	frame = FIELDLOOT_GET_MAIN_FRAME(frame)
	if frame == nil then
		return false
	end

	local trackerSession = FIELDLOOT_GET_SESSION()
	local now = imcTime.GetAppTime()
	local elapsed = FIELDLOOT_GET_ELAPSED(now)

	local statusWaiting = GET_CHILD_RECURSIVELY(frame, 'statusWaiting')
	local statusRunning = GET_CHILD_RECURSIVELY(frame, 'statusRunning')
	local statusPaused = GET_CHILD_RECURSIVELY(frame, 'statusPaused')
	local pauseButton = GET_CHILD_RECURSIVELY(frame, 'pauseButton')
	local resumeButton = GET_CHILD_RECURSIVELY(frame, 'resumeButton')
	local timeValue = GET_CHILD_RECURSIVELY(frame, 'timeValue')
	local itemValue = GET_CHILD_RECURSIVELY(frame, 'itemValue')
	local silverValue = GET_CHILD_RECURSIVELY(frame, 'silverValue')
	if statusWaiting == nil or statusRunning == nil or statusPaused == nil or pauseButton == nil or resumeButton == nil or timeValue == nil or itemValue == nil or silverValue == nil then
		return false
	end

	local paused = trackerSession.running ~= true
	local running = trackerSession.running == true and trackerSession.started == true
	FIELDLOOT_SET_VISIBLE(statusPaused, paused)
	FIELDLOOT_SET_VISIBLE(statusRunning, running)
	FIELDLOOT_SET_VISIBLE(statusWaiting, not paused and not running)
	FIELDLOOT_SET_VISIBLE(pauseButton, not paused)
	FIELDLOOT_SET_VISIBLE(resumeButton, paused)

	timeValue:SetTextByKey('value', FIELDLOOT_FORMAT_TIME(elapsed))
	itemValue:SetTextByKey('count', FIELDLOOT_FORMAT_NUMBER(trackerSession.totalCount))
	itemValue:SetTextByKey('types', tostring(FIELDLOOT_GET_UNIQUE_COUNT(nil)))
	silverValue:SetTextByKey('value', FIELDLOOT_FORMAT_NUMBER(trackerSession.silver))
	FIELDLOOT_REFRESH_RECENT_SLOTS(frame)
	return true
end

function FIELDLOOT_OPEN_DETAIL(frame, ctrl)
	if FIELDLOOT_IS_ENABLED() == false then
		return
	end
	ui.OpenFrame('fieldloot_detail')
	local detailFrame = ui.GetFrame('fieldloot_detail')
	if detailFrame ~= nil then
		detailFrame:ShowWindow(1)
		FIELDLOOT_REFRESH_DETAIL(detailFrame)
	end
end

function FIELDLOOT_DETAIL_OPEN(frame)
	if FIELDLOOT_IS_ENABLED() == false then
		ui.CloseFrame('fieldloot_detail')
		return
	end
	if frame == nil then
		frame = ui.GetFrame('fieldloot_detail')
	end
	FIELDLOOT_REFRESH_DETAIL(frame)
end

function FIELDLOOT_DETAIL_TOGGLE_MAP(frame, ctrl)
	if FL.detailMapMode == 'ALL' then
		FL.detailMapMode = 'CURRENT'
	else
		FL.detailMapMode = 'ALL'
	end
	FIELDLOOT_REFRESH_DETAIL(ui.GetFrame('fieldloot_detail'))
end

function FIELDLOOT_DETAIL_TOGGLE_RARE(frame, ctrl)
	FL.detailRareOnly = FL.detailRareOnly ~= true
	FIELDLOOT_REFRESH_DETAIL(ui.GetFrame('fieldloot_detail'))
end

function FIELDLOOT_DETAIL_CYCLE_SORT(frame, ctrl)
	if FL.detailSortMode == 'COUNT' then
		FL.detailSortMode = 'RECENT'
	elseif FL.detailSortMode == 'RECENT' then
		FL.detailSortMode = 'GRADE'
	else
		FL.detailSortMode = 'COUNT'
	end
	FIELDLOOT_REFRESH_DETAIL(ui.GetFrame('fieldloot_detail'))
end

function FIELDLOOT_REFRESH_DETAIL(frame)
	if frame == nil then
		return false
	end

	local trackerSession = FIELDLOOT_GET_SESSION()
	local now = imcTime.GetAppTime()
	local mapName = nil
	local currentMapMode = FL.detailMapMode == 'CURRENT'
	if currentMapMode == true then
		mapName = FIELDLOOT_GET_CURRENT_MAP()
	end

	local elapsed = FIELDLOOT_GET_ELAPSED(now)
	local totalCount = trackerSession.totalCount
	local silver = trackerSession.silver
	local mercenaryBadge = trackerSession.mercenaryBadge
	local displayMapName = nil
	if mapName ~= nil then
		local mapData = FIELDLOOT_GET_MAP_DATA(mapName)
		elapsed = FIELDLOOT_GET_MAP_ELAPSED(mapName, now)
		totalCount = mapData.totalCount
		silver = mapData.silver
		mercenaryBadge = mapData.mercenaryBadge
		displayMapName = FIELDLOOT_GET_MAP_DISPLAY_NAME(mapName)
	end

	local mapValueAll = GET_CHILD_RECURSIVELY(frame, 'mapValueAll')
	local mapValueCurrent = GET_CHILD_RECURSIVELY(frame, 'mapValueCurrent')
	local mapValueUnknown = GET_CHILD_RECURSIVELY(frame, 'mapValueUnknown')
	local timeValue = GET_CHILD_RECURSIVELY(frame, 'timeValue')
	local itemValue = GET_CHILD_RECURSIVELY(frame, 'itemValue')
	local silverValue = GET_CHILD_RECURSIVELY(frame, 'silverValue')
	local mercenaryBadgeValue = GET_CHILD_RECURSIVELY(frame, 'mercenaryBadgeValue')
	local mapAllButton = GET_CHILD_RECURSIVELY(frame, 'mapAllButton')
	local mapCurrentButton = GET_CHILD_RECURSIVELY(frame, 'mapCurrentButton')
	local rareAllButton = GET_CHILD_RECURSIVELY(frame, 'rareAllButton')
	local rareOnButton = GET_CHILD_RECURSIVELY(frame, 'rareOnButton')
	local sortCountButton = GET_CHILD_RECURSIVELY(frame, 'sortCountButton')
	local sortRecentButton = GET_CHILD_RECURSIVELY(frame, 'sortRecentButton')
	local sortGradeButton = GET_CHILD_RECURSIVELY(frame, 'sortGradeButton')
	local listBox = GET_CHILD_RECURSIVELY(frame, 'itemList')
	local emptyText = GET_CHILD_RECURSIVELY(frame, 'emptyText')
	if mapValueAll == nil or mapValueCurrent == nil or mapValueUnknown == nil or timeValue == nil or itemValue == nil or silverValue == nil or mercenaryBadgeValue == nil or mapAllButton == nil or mapCurrentButton == nil or rareAllButton == nil or rareOnButton == nil or sortCountButton == nil or sortRecentButton == nil or sortGradeButton == nil or listBox == nil or emptyText == nil then
		return false
	end

	local currentMapAvailable = currentMapMode == true and displayMapName ~= nil
	FIELDLOOT_SET_VISIBLE(mapValueAll, not currentMapMode)
	FIELDLOOT_SET_VISIBLE(mapValueCurrent, currentMapAvailable)
	FIELDLOOT_SET_VISIBLE(mapValueUnknown, currentMapMode and not currentMapAvailable)
	if currentMapAvailable == true then
		mapValueCurrent:SetTextByKey('value', displayMapName)
	end

	timeValue:SetTextByKey('value', FIELDLOOT_FORMAT_TIME(elapsed))
	itemValue:SetTextByKey('count', FIELDLOOT_FORMAT_NUMBER(totalCount))
	itemValue:SetTextByKey('types', tostring(FIELDLOOT_GET_UNIQUE_COUNT(mapName)))
	silverValue:SetTextByKey('value', FIELDLOOT_FORMAT_NUMBER(silver))
	mercenaryBadgeValue:SetTextByKey('value', FIELDLOOT_FORMAT_NUMBER(mercenaryBadge))

	FIELDLOOT_SET_VISIBLE(mapAllButton, not currentMapMode)
	FIELDLOOT_SET_VISIBLE(mapCurrentButton, currentMapMode)
	FIELDLOOT_SET_VISIBLE(rareAllButton, FL.detailRareOnly ~= true)
	FIELDLOOT_SET_VISIBLE(rareOnButton, FL.detailRareOnly == true)
	FIELDLOOT_SET_VISIBLE(sortCountButton, FL.detailSortMode == 'COUNT')
	FIELDLOOT_SET_VISIBLE(sortRecentButton, FL.detailSortMode == 'RECENT')
	FIELDLOOT_SET_VISIBLE(sortGradeButton, FL.detailSortMode == 'GRADE')

	local sortedItems = FIELDLOOT_GET_SORTED_ITEMS(mapName, FL.detailRareOnly, FL.detailSortMode)
	listBox:RemoveAllChild()
	FIELDLOOT_SET_VISIBLE(emptyText, #sortedItems == 0)

	if #sortedItems > 0 then
		for index, sortedItem in ipairs(sortedItems) do
			local itemData = sortedItem.data
			local y = (index - 1) * 44
			local row = listBox:CreateOrGetControlSet('fieldloot_item_row', 'itemRow_' .. tostring(index), 0, y)
			if row == nil then
				return false
			end
			tolua.cast(row, 'ui::CControlSet')

			local icon = GET_CHILD_RECURSIVELY(row, 'icon')
			local nameCommon = GET_CHILD_RECURSIVELY(row, 'nameCommon')
			local nameRare = GET_CHILD_RECURSIVELY(row, 'nameRare')
			local countText = GET_CHILD_RECURSIVELY(row, 'count')
			local recentUnknown = GET_CHILD_RECURSIVELY(row, 'recentUnknown')
			local recentNow = GET_CHILD_RECURSIVELY(row, 'recentNow')
			local recentSeconds = GET_CHILD_RECURSIVELY(row, 'recentSeconds')
			local recentMinutes = GET_CHILD_RECURSIVELY(row, 'recentMinutes')
			local recentHours = GET_CHILD_RECURSIVELY(row, 'recentHours')
			if icon == nil or nameCommon == nil or nameRare == nil or countText == nil or recentUnknown == nil or recentNow == nil or recentSeconds == nil or recentMinutes == nil or recentHours == nil then
				return false
			end

			icon:SetImage(itemData.icon)
			SET_ITEM_TOOLTIP_BY_NAME(icon, itemData.className)

			local rare = itemData.grade >= RARE_GRADE
			FIELDLOOT_SET_VISIBLE(nameCommon, not rare)
			FIELDLOOT_SET_VISIBLE(nameRare, rare)
			nameCommon:SetTextByKey('value', itemData.name)
			nameRare:SetTextByKey('value', itemData.name)
			nameCommon:SetTextTooltip(itemData.name)
			nameRare:SetTextTooltip(itemData.name)
			countText:SetTextByKey('value', FIELDLOOT_FORMAT_NUMBER(sortedItem.count))

			local recentMode, recentValue = FIELDLOOT_FORMAT_RECENT(sortedItem.lastAt, now)
			FIELDLOOT_SET_VISIBLE(recentUnknown, recentMode == 'UNKNOWN')
			FIELDLOOT_SET_VISIBLE(recentNow, recentMode == 'NOW')
			FIELDLOOT_SET_VISIBLE(recentSeconds, recentMode == 'SECONDS')
			FIELDLOOT_SET_VISIBLE(recentMinutes, recentMode == 'MINUTES')
			FIELDLOOT_SET_VISIBLE(recentHours, recentMode == 'HOURS')
			if recentValue ~= nil then
				if recentMode == 'SECONDS' then
					recentSeconds:SetTextByKey('value', tostring(recentValue))
				elseif recentMode == 'MINUTES' then
					recentMinutes:SetTextByKey('value', tostring(recentValue))
				elseif recentMode == 'HOURS' then
					recentHours:SetTextByKey('value', tostring(recentValue))
				end
			end
		end
	end

	listBox:InvalidateScrollBar()
	listBox:Invalidate()
	frame:Invalidate()
	return true
end
