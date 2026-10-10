local json = require('json')
local PATH = require('path')

MINIMAP_REGION_INFO = MINIMAP_REGION_INFO or {}

local REGION_INFO = MINIMAP_REGION_INFO

REGION_INFO.PAGE_SIZE = 4
REGION_INFO.CATEGORY_MONSTER = 'MONSTER'
REGION_INFO.CATEGORY_COLLECTION = 'COLLECTION'
REGION_INFO.CATEGORY_NPC = 'NPC'
REGION_INFO.CATEGORY_QUEST = 'QUEST'
REGION_INFO.activeCategory = REGION_INFO.activeCategory or nil
REGION_INFO.isMinimized = REGION_INFO.isMinimized == true
REGION_INFO.cache = REGION_INFO.cache or {}
REGION_INFO.cacheMapName = REGION_INFO.cacheMapName or nil
REGION_INFO.lastMapName = REGION_INFO.lastMapName or nil
REGION_INFO.lastMinimapSize = REGION_INFO.lastMinimapSize or nil
REGION_INFO.lastMapDisplayMode = REGION_INFO.lastMapDisplayMode or nil

local SETTINGS_PATH_FORMAT = '..\\release\\addon_setting\\minimap_region_info\\%s\\settings.json'
local SETTINGS_VERSION = 1
local RAIL_EXPANDED_WIDTH = 169
local RAIL_MINIMIZED_WIDTH = 34
local RAIL_CATEGORY_BUTTON_NAMES = {
	'monster_btn',
	'collection_btn',
	'npc_btn',
	'quest_btn'
}

local function MINIMAP_REGION_INFO_DEFAULT_SETTINGS()
	return {
		version = SETTINGS_VERSION,
		enabled = true
	}
end

local function MINIMAP_REGION_INFO_ENSURE_SETTINGS_DIRECTORY()
	if REGION_INFO.settingsFile == nil then
		return false
	end
	local userDirectory = PATH.dirname(REGION_INFO.settingsFile)
	local addonDirectory = PATH.dirname(userDirectory)
	if MakeDirectory(PATH.dirname(addonDirectory)) == false then
		return false
	end
	if MakeDirectory(addonDirectory) == false then
		return false
	end
	return MakeDirectory(userDirectory) ~= false
end

local function MINIMAP_REGION_INFO_SAVE_SETTINGS()
	if REGION_INFO.settingsFile == nil or REGION_INFO.settings == nil then
		return
	end
	if MINIMAP_REGION_INFO_ENSURE_SETTINGS_DIRECTORY() == false then
		return
	end
	save_json(REGION_INFO.settingsFile, REGION_INFO.settings)
end

local function MINIMAP_REGION_INFO_LOAD_SETTINGS()
	local userID = session.loginInfo.GetUserID()
	if userID == nil or userID == '' then
		userID = '0'
	end

	if REGION_INFO.settingsUserID ~= userID then
		REGION_INFO.settingsLoaded = false
		REGION_INFO.settingsUserID = userID
	end
	if REGION_INFO.settingsLoaded == true then
		return
	end

	REGION_INFO.settingsFile = string.format(SETTINGS_PATH_FORMAT, userID)
	local defaults = MINIMAP_REGION_INFO_DEFAULT_SETTINGS()
	local loaded, err = load_json(REGION_INFO.settingsFile, defaults)
	if err then
		REGION_INFO.settings = defaults
		MINIMAP_REGION_INFO_SAVE_SETTINGS()
	else
		REGION_INFO.settings = defaults
		if type(loaded) == 'table' then
			for key, value in pairs(loaded) do
				REGION_INFO.settings[key] = value
			end
		end
	end
	REGION_INFO.settings.version = SETTINGS_VERSION
	REGION_INFO.settingsLoaded = true
end

local function MINIMAP_REGION_INFO_SET_TIMER_ENABLED(frame, enabled)
	if frame == nil then
		return
	end
	local timer = GET_CHILD(frame, 'addontimer', 'ui::CAddOnTimer')
	if timer == nil then
		return
	end
	if enabled then
		timer:SetUpdateScript('MINIMAP_REGION_INFO_ON_TIMER')
		timer:Start(0.5)
	else
		timer:Stop()
	end
end

function MINIMAP_REGION_INFO_IS_ENABLED()
	MINIMAP_REGION_INFO_LOAD_SETTINGS()
	return REGION_INFO.settings ~= nil and REGION_INFO.settings.enabled ~= false
end

local function MINIMAP_REGION_INFO_TRY_NUMBER(value, defaultValue)
	local numberValue = tonumber(value)
	if numberValue == nil then
		return defaultValue or 0
	end
	return numberValue
end

local function MINIMAP_REGION_INFO_LOCALIZE(key)
	if key == nil or key == '' or key == 'None' then
		return '-'
	end

	local value = ScpArgMsg(key)
	if value == nil or value == '' or value == 'None' then
		return tostring(key)
	end
	return value
end

local function MINIMAP_REGION_INFO_CURRENT_MAP_NAME()
	local mapName = session.GetMapName()
	if mapName == nil or mapName == '' then
		return 'None'
	end
	return mapName
end

local function MINIMAP_REGION_INFO_CURRENT_MAP_DISPLAY_NAME(mapName)
	local mapClass = GetClass('Map', mapName)
	if mapClass == nil then
		return mapName
	end
	return TryGetProp(mapClass, 'Name', mapName)
end

local function MINIMAP_REGION_INFO_IS_VALID_CATEGORY(category)
	return category == REGION_INFO.CATEGORY_MONSTER
		or category == REGION_INFO.CATEGORY_COLLECTION
		or category == REGION_INFO.CATEGORY_NPC
		or category == REGION_INFO.CATEGORY_QUEST
end

local function MINIMAP_REGION_INFO_MONSTER_JOURNAL_INFO(monster)
	local currentPoint = 0
	local maximumPoint = 0
	local unknown = 1
	local classID = TryGetProp(monster, 'ClassID', 0)

	if ADVENTURE_BOOK_MONSTER_CONTENT ~= nil and ADVENTURE_BOOK_MONSTER_CONTENT.EXIST_IN_HISTORY ~= nil then
		unknown = 1 - ADVENTURE_BOOK_MONSTER_CONTENT.EXIST_IN_HISTORY(classID)
	end

	if GetMonKillCount ~= nil and GET_ADVENTURE_BOOK_MONSTER_KILL_COUNT_INFO ~= nil then
		local pc = GetMyPCObject()
		local killCount = GetMonKillCount(pc, classID)
		local isBoss = TryGetProp(monster, 'MonRank', 'None') == 'Boss'
		local level, point, maximum = GET_ADVENTURE_BOOK_MONSTER_KILL_COUNT_INFO(isBoss, killCount)
		currentPoint = MINIMAP_REGION_INFO_TRY_NUMBER(point, 0)
		maximumPoint = MINIMAP_REGION_INFO_TRY_NUMBER(maximum, 0)
	end

	return currentPoint, maximumPoint, unknown
end

local function MINIMAP_REGION_INFO_IS_LISTABLE_MONSTER(monster)
	local monsterName = TryGetProp(monster, 'Name', 'UnvisibleName')
	if monsterName == 'UnvisibleName' or monsterName == '' or monsterName == 'None' then
		return false
	end

	local journal = TryGetProp(monster, 'Journal', 'None')
	if journal == nil or journal == '' or journal == 'None' then
		local monRank = TryGetProp(monster, 'MonRank', 'None')
		if monRank == 'MISC' or monRank == 'NPC' or monRank == 'Material' then
			return false
		end
	end
	return true
end

local function MINIMAP_REGION_INFO_BUILD_MONSTERS(mapName)
	local byClassID = {}
	local classList, classCount = GetClassList('GenType_' .. mapName)
	if classList == nil then
		return {}
	end

	for index = 0, classCount - 1 do
		local genClass = GetClassByIndexFromList(classList, index)
		local classType = TryGetProp(genClass, 'ClassType', 'None')
		local faction = TryGetProp(genClass, 'Faction', 'None')
		local maximumPopulation = MINIMAP_REGION_INFO_TRY_NUMBER(TryGetProp(genClass, 'MaxPop', 0), 0)
		local hidden = MINIMAP_REGION_INFO_TRY_NUMBER(TryGetProp(genClass, 'Hide', 0), 0)
		local genName = TryGetProp(genClass, 'Name', 'None')
		local monster = GetClass('Monster', classType)

		if faction == 'Monster' and maximumPopulation > 0 and hidden == 0 and genName ~= 'UnvisibleName' and monster ~= nil then
			local monsterName = TryGetProp(monster, 'Name', 'UnvisibleName')
			if MINIMAP_REGION_INFO_IS_LISTABLE_MONSTER(monster) == true then
				local classID = TryGetProp(monster, 'ClassID', 0)
				local item = byClassID[classID]
				if item == nil then
					local raceType = TryGetProp(monster, 'RaceType', 'None')
					local attributeType = TryGetProp(monster, 'Attribute', 'None')
					local armorType = TryGetProp(monster, 'ArmorMaterial', 'None')
					local sizeType = TryGetProp(monster, 'Size', 'None')
					local currentPoint, maximumPoint, unknown = MINIMAP_REGION_INFO_MONSTER_JOURNAL_INFO(monster)
					item = {
						classID = classID,
						className = TryGetProp(monster, 'ClassName', classType),
						name = monsterName,
						icon = TryGetProp(monster, 'Icon', 'question_mark'),
						level = MINIMAP_REGION_INFO_TRY_NUMBER(TryGetProp(monster, 'Level', 0), 0),
						race = MINIMAP_REGION_INFO_LOCALIZE(raceType),
						attribute = attributeType ~= 'None' and MINIMAP_REGION_INFO_LOCALIZE('Attr_' .. attributeType) or '-',
						armor = MINIMAP_REGION_INFO_LOCALIZE(armorType),
						size = MINIMAP_REGION_INFO_LOCALIZE('MonInfo_Size_'..sizeType),
						raceImage = raceType ~= 'None' and 'Tribe_' .. raceType or nil,
						attributeImage = attributeType ~= 'None' and 'attri_' .. attributeType or nil,
						armorImage = armorType ~= 'None' and 'Armor_' .. armorType or nil,
						maxPop = 0,
						respawnMilliseconds = nil,
						journalCurrent = currentPoint,
						journalMaximum = maximumPoint,
						unknown = unknown,
						genTypes = {},
						genRanges = {}
					}
					byClassID[classID] = item
				end

				item.maxPop = item.maxPop + maximumPopulation
				local respawnMilliseconds = MINIMAP_REGION_INFO_TRY_NUMBER(TryGetProp(genClass, 'RespawnTime', 0), 0)
				if respawnMilliseconds > 0 and (item.respawnMilliseconds == nil or respawnMilliseconds < item.respawnMilliseconds) then
					item.respawnMilliseconds = respawnMilliseconds
				end
				local genType = tostring(TryGetProp(genClass, 'GenType', 0))
				local genRange = MINIMAP_REGION_INFO_TRY_NUMBER(TryGetProp(genClass, 'GenRange', 0), 0)
				item.genTypes[genType] = true
				item.genRanges[genType] = math.max(item.genRanges[genType] or 0, genRange)
			end
		end
	end

	local result = {}
	for _, item in pairs(byClassID) do
		item.respawnSeconds = math.floor((item.respawnMilliseconds or 0) / 1000)
		result[#result + 1] = item
	end

	table.sort(result, function(left, right)
		if left.level == right.level then
			return tostring(left.name) < tostring(right.name)
		end
		return left.level < right.level
	end)
	return result
end

local function MINIMAP_REGION_INFO_BUILD_NPCS(mapName)
	local mapProp = geMapTable.GetMapProp(mapName)
	if mapProp == nil or mapProp.mongens == nil then
		return {}
	end

	local byClassName = {}
	local monGens = mapProp.mongens
	for index = 0, monGens:Count() - 1 do
		local monProp = monGens:Element(index)
		local dialog = monProp:GetDialog()
		local genType = tostring(monProp.GenType)
		local npcState = MINIMAP_REGION_INFO_TRY_NUMBER(GetNPCState(mapProp:GetClassName(), monProp.GenType), 0)
		local hideNPCData = GetClass('HideNPC', dialog)
		local visibleByHideState = true

		if hideNPCData ~= nil then
			local etcObject = GetMyEtcObject()
			visibleByHideState = etcObject ~= nil and TryGetProp(etcObject, 'Hide_' .. hideNPCData.ClassID, 1) ~= 1
		end

		if monProp.Minimap >= 1 and npcState > 0 and visibleByHideState and monProp:GetName() ~= 'UnvisibleName' then
			local className = monProp:GetClassName()
			local item = byClassName[className]
			if item == nil then
				local icon = monProp:GetMinimapIcon()
				if icon == nil or icon == 'None' then
					icon = 'minimap_0'
				end

				item = {
					className = className,
					name = monProp:GetName(),
					icon = icon,
					locationCount = 0,
					genTypes = {}
				}
				byClassName[className] = item
			end

			item.genTypes[genType] = true
			if monProp.GenList ~= nil then
				item.locationCount = item.locationCount + monProp.GenList:Count()
			end
		end
	end

	local result = {}
	for _, item in pairs(byClassName) do
		result[#result + 1] = item
	end
	table.sort(result, function(left, right)
		return tostring(left.name) < tostring(right.name)
	end)
	return result
end

local function MINIMAP_REGION_INFO_BUILD_QUESTS(mapName)
	local result = {}
	local pc = GetMyPCObject()
	local questClassList, questClassCount = GetClassList('QuestProgressCheck')
	if questClassList == nil then
		return result
	end

	for index = 0, questClassCount - 1 do
		local questClass = GetClassByIndexFromList(questClassList, index)
		local visible = TryGetProp(questClass, 'PossibleUI_Notify', 'NO') ~= 'NO'
			and MINIMAP_REGION_INFO_TRY_NUMBER(TryGetProp(questClass, 'Level', 9999), 9999) ~= 9999
			and MINIMAP_REGION_INFO_TRY_NUMBER(TryGetProp(questClass, 'Lvup', -9999), -9999) ~= -9999
			and TryGetProp(questClass, 'QuestStartMode', 'NPCENTER_HIDE') ~= 'NPCENTER_HIDE'
			and TryGetProp(questClass, 'QuestMode', 'KEYITEM') ~= 'KEYITEM'

		if visible then
			local state = SCR_QUEST_CHECK_C(pc, questClass.ClassName)
			local belongsToMap = (state == 'POSSIBLE' and questClass.StartMap == mapName)
				or (state == 'PROGRESS' and questClass.ProgMap == mapName)
				or (state == 'SUCCESS' and questClass.EndMap == mapName)

			if belongsToMap then
				local icon = 'quest_indi_icon'
				if GET_QUESTINFOSET_ICON_BY_STATE_MODE ~= nil then
					icon = GET_QUESTINFOSET_ICON_BY_STATE_MODE(state, questClass)
				end
				result[#result + 1] = {
					classID = TryGetProp(questClass, 'ClassID', 0),
					className = TryGetProp(questClass, 'ClassName', 'None'),
					name = TryGetProp(questClass, 'Name', 'None'),
					icon = icon,
					level = MINIMAP_REGION_INFO_TRY_NUMBER(TryGetProp(questClass, 'Level', 0), 0),
					state = state,
					stateText = MINIMAP_REGION_INFO_LOCALIZE(state)
				}
			end
		end
	end

	table.sort(result, function(left, right)
		if left.level == right.level then
			return tostring(left.name) < tostring(right.name)
		end
		return left.level < right.level
	end)
	return result
end

local function MINIMAP_REGION_INFO_BUILD_REGION_DROP_ITEMS(monsters)
	local itemSet = {}
	for _, monsterInfo in ipairs(monsters) do
		local monster = GetClassByType('Monster', monsterInfo.classID)
		local dropListName = TryGetProp(monster, 'DropItemList', 'None')
		if dropListName ~= 'None' then
			local dropClassList, dropClassCount = GetClassList('MonsterDropItemList_' .. dropListName)
			if dropClassList ~= nil then
				for index = 0, dropClassCount - 1 do
					local dropClass = GetClassByIndexFromList(dropClassList, index)
					local itemClassName = TryGetProp(dropClass, 'ItemClassName', 'None')
					if itemClassName ~= 'None' and GetClass('Item', itemClassName) ~= nil then
						itemSet[itemClassName] = true
					end
				end
			end
		end
	end
	return itemSet
end

local function MINIMAP_REGION_INFO_COLLECTION_PROGRESS(collectionClass, collection)
	local requirements = {}
	local maximum = 0
	for index = 1, 9 do
		local itemClassName = TryGetProp(collectionClass, 'ItemName_' .. index, 'None')
		if itemClassName ~= 'None' then
			requirements[itemClassName] = (requirements[itemClassName] or 0) + 1
			maximum = maximum + 1
		end
	end

	local current = 0
	if collection ~= nil then
		for itemClassName, requiredCount in pairs(requirements) do
			local itemClass = GetClass('Item', itemClassName)
			if itemClass ~= nil then
				local ownedCount = MINIMAP_REGION_INFO_TRY_NUMBER(collection:GetItemCountByType(itemClass.ClassID), 0)
				current = current + math.min(requiredCount, ownedCount)
			end
		end
	end
	return current, maximum
end

local function MINIMAP_REGION_INFO_BUILD_COLLECTIONS(mapName)
	local monsters = REGION_INFO.cache[REGION_INFO.CATEGORY_MONSTER] or MINIMAP_REGION_INFO_BUILD_MONSTERS(mapName)
	local regionDropItems = MINIMAP_REGION_INFO_BUILD_REGION_DROP_ITEMS(monsters)
	local result = {}
	local collectionClassList, collectionClassCount = GetClassList('Collection')
	local mySession = session.GetMySession()
	local collectionList = mySession ~= nil and mySession:GetCollection() or nil
	if collectionClassList == nil then
		return result
	end

	for index = 0, collectionClassCount - 1 do
		local collectionClass = GetClassByIndexFromList(collectionClassList, index)
		if TryGetProp(collectionClass, 'Journal', 'FALSE') == 'TRUE' then
			local relatedCount = 0
			local firstItemIcon = 'collection_num'
			for itemIndex = 1, 9 do
				local itemClassName = TryGetProp(collectionClass, 'ItemName_' .. itemIndex, 'None')
				if itemClassName ~= 'None' then
					local itemClass = GetClass('Item', itemClassName)
					if itemIndex == 1 and itemClass ~= nil then
						firstItemIcon = TryGetProp(itemClass, 'Icon', firstItemIcon)
					end
					if regionDropItems[itemClassName] == true then
						relatedCount = relatedCount + 1
					end
				end
			end

			if relatedCount > 0 then
				local collection = nil
				if collectionList ~= nil then
					collection = collectionList:Get(collectionClass.ClassID)
				end
				local current, maximum = MINIMAP_REGION_INFO_COLLECTION_PROGRESS(collectionClass, collection)
				result[#result + 1] = {
					classID = TryGetProp(collectionClass, 'ClassID', 0),
					className = TryGetProp(collectionClass, 'ClassName', 'None'),
					name = TryGetProp(collectionClass, 'Name', 'None'),
					icon = firstItemIcon,
					current = current,
					maximum = maximum,
					relatedCount = relatedCount
				}
			end
		end
	end

	table.sort(result, function(left, right)
		if left.relatedCount == right.relatedCount then
			return tostring(left.name) < tostring(right.name)
		end
		return left.relatedCount > right.relatedCount
	end)
	return result
end

local function MINIMAP_REGION_INFO_BUILD_CATEGORY(category, mapName)
	if category == REGION_INFO.CATEGORY_MONSTER then
		return MINIMAP_REGION_INFO_BUILD_MONSTERS(mapName)
	elseif category == REGION_INFO.CATEGORY_COLLECTION then
		return MINIMAP_REGION_INFO_BUILD_COLLECTIONS(mapName)
	elseif category == REGION_INFO.CATEGORY_NPC then
		return MINIMAP_REGION_INFO_BUILD_NPCS(mapName)
	elseif category == REGION_INFO.CATEGORY_QUEST then
		return MINIMAP_REGION_INFO_BUILD_QUESTS(mapName)
	end
	return {}
end

function MINIMAP_REGION_INFO_GET_CATEGORY_DATA(category, forceRefresh)
	local mapName = MINIMAP_REGION_INFO_CURRENT_MAP_NAME()
	if REGION_INFO.cacheMapName ~= mapName then
		REGION_INFO.cache = {}
		REGION_INFO.cacheMapName = mapName
	end

	if forceRefresh == true or REGION_INFO.cache[category] == nil then
		REGION_INFO.cache[category] = MINIMAP_REGION_INFO_BUILD_CATEGORY(category, mapName)
	end
	return REGION_INFO.cache[category], mapName, MINIMAP_REGION_INFO_CURRENT_MAP_DISPLAY_NAME(mapName)
end

function MINIMAP_REGION_INFO_GET_ACTIVE_CATEGORY()
	return REGION_INFO.activeCategory
end

function MINIMAP_REGION_INFO_IS_FULL_MAP_VISIBLE()
	if REGION_INFO.lastMapDisplayMode == 'FULL_MAP' then
		return true
	elseif REGION_INFO.lastMapDisplayMode == 'MINIMAP' then
		return false
	end

	local fullMap = ui.GetFrame('map')
	return fullMap ~= nil and fullMap:IsVisible() == 1
end

local function MINIMAP_REGION_INFO_APPLY_MINIMIZED(frame)
	if frame == nil then
		frame = ui.GetFrame('minimap_region_info')
	end
	if frame == nil then
		return
	end

	local minimized = REGION_INFO.isMinimized == true
	local targetWidth = minimized and RAIL_MINIMIZED_WIDTH or RAIL_EXPANDED_WIDTH
	frame:Resize(targetWidth, frame:GetHeight())

	local railBackground = GET_CHILD(frame, 'rail_bg', 'ui::CGroupBox')
	if railBackground ~= nil then
		railBackground:Resize(targetWidth, railBackground:GetHeight())
	end

	for _, buttonName in ipairs(RAIL_CATEGORY_BUTTON_NAMES) do
		local categoryButton = GET_CHILD(frame, buttonName, 'ui::CButton')
		if categoryButton ~= nil then
			categoryButton:ShowWindow(minimized and 0 or 1)
		end
	end

	local minimizeButton = GET_CHILD(frame, 'minimize_btn', 'ui::CButton')
	local maximizeButton = GET_CHILD(frame, 'maximize_btn', 'ui::CButton')
	if minimizeButton ~= nil then
		minimizeButton:ShowWindow(minimized and 0 or 1)
	end
	if maximizeButton ~= nil then
		maximizeButton:ShowWindow(minimized and 1 or 0)
	end
end

function MINIMAP_REGION_INFO_UPDATE_BUTTONS()
	local frame = ui.GetFrame('minimap_region_info')
	if frame == nil then
		return
	end

	local buttonByCategory = {
		[REGION_INFO.CATEGORY_MONSTER] = 'monster_btn',
		[REGION_INFO.CATEGORY_COLLECTION] = 'collection_btn',
		[REGION_INFO.CATEGORY_NPC] = 'npc_btn',
		[REGION_INFO.CATEGORY_QUEST] = 'quest_btn'
	}
	for category, buttonName in pairs(buttonByCategory) do
		local button = GET_CHILD(frame, buttonName, 'ui::CButton')
		if button ~= nil then
			if category == REGION_INFO.activeCategory then
				button:SetColorTone('FFFFC75A')
			else
				button:SetColorTone('FFFFFFFF')
			end
		end
	end
end

function MINIMAP_REGION_INFO_SYNC_LAYOUT(displayMode)
	local minimap = ui.GetFrame('minimap')
	local rail = ui.GetFrame('minimap_region_info')
	local panel = ui.GetFrame('minimap_region_info_detail')
	if rail == nil then
		return
	end
	if MINIMAP_REGION_INFO_IS_ENABLED() == false then
		rail:ShowWindow(0)
		if panel ~= nil then
			panel:ShowWindow(0)
		end
		return
	end

	local minimapVisible = minimap ~= nil and minimap:IsVisible() or 0
	local fullMapVisible = MINIMAP_REGION_INFO_IS_FULL_MAP_VISIBLE() and 1 or 0
	if displayMode == 'FULL_MAP' then
		fullMapVisible = 1
	elseif displayMode == 'MINIMAP' then
		fullMapVisible = 0
	end
	local railVisible = minimapVisible == 1 or fullMapVisible == 1
	local rightMargin = fullMapVisible == 1 and 18 or 350
	local topMargin = fullMapVisible == 1 and 70 or 35
	local railLayer = fullMapVisible == 1 and 101 or 32
	local panelLayer = fullMapVisible == 1 and 102 or 26

	rail:SetMargin(0, topMargin, rightMargin, 0)
	rail:SetLayerLevel(railLayer)
	rail:ShowWindow(railVisible and 1 or 0)
	if railVisible == false then
		if panel ~= nil then
			panel:ShowWindow(0)
		end
		return
	end

	if panel ~= nil then
		panel:SetMargin(0, topMargin, rightMargin + rail:GetWidth() + 4, 0)
		panel:SetLayerLevel(panelLayer)
	end
end

function MINIMAP_REGION_INFO_SET_ENABLED(enabled)
	MINIMAP_REGION_INFO_LOAD_SETTINGS()
	if REGION_INFO.settings == nil then
		return false
	end

	local nextEnabled = enabled == true or tonumber(enabled) == 1
	if REGION_INFO.settings.enabled == nextEnabled then
		return true
	end
	REGION_INFO.settings.enabled = nextEnabled
	MINIMAP_REGION_INFO_SAVE_SETTINGS()

	local frame = ui.GetFrame('minimap_region_info')
	MINIMAP_REGION_INFO_SET_TIMER_ENABLED(frame, nextEnabled)
	if nextEnabled then
		MINIMAP_REGION_INFO_APPLY_MINIMIZED(frame)
		MINIMAP_REGION_INFO_UPDATE_BUTTONS()
		MINIMAP_REGION_INFO_SYNC_LAYOUT()
	else
		MINIMAP_REGION_INFO_CLOSE_PANEL()
		if MINIMAP_REGION_INFO_DETAIL_CLEAR_MARKERS ~= nil then
			MINIMAP_REGION_INFO_DETAIL_CLEAR_MARKERS()
		end
		if frame ~= nil then
			frame:ShowWindow(0)
		end
	end
	return true
end

function MINIMAP_REGION_INFO_ON_MAP_OPEN()
	if MINIMAP_REGION_INFO_IS_ENABLED() == false then
		return
	end
	REGION_INFO.lastMapDisplayMode = 'FULL_MAP'
	MINIMAP_REGION_INFO_SYNC_LAYOUT('FULL_MAP')
	if MINIMAP_REGION_INFO_DETAIL_REFRESH_MARKERS ~= nil then
		MINIMAP_REGION_INFO_DETAIL_REFRESH_MARKERS()
	end
end

function MINIMAP_REGION_INFO_ON_MAP_CLOSE()
	if MINIMAP_REGION_INFO_IS_ENABLED() == false then
		return
	end
	REGION_INFO.lastMapDisplayMode = 'MINIMAP'
	MINIMAP_REGION_INFO_SYNC_LAYOUT('MINIMAP')
	if MINIMAP_REGION_INFO_DETAIL_REFRESH_MARKERS ~= nil then
		MINIMAP_REGION_INFO_DETAIL_REFRESH_MARKERS()
	end
end

function MINIMAP_REGION_INFO_INVALIDATE(frame, msg, argStr, argNum)
	if MINIMAP_REGION_INFO_IS_ENABLED() == false then
		return
	end
	REGION_INFO.cache = {}
	REGION_INFO.cacheMapName = MINIMAP_REGION_INFO_CURRENT_MAP_NAME()
	local panel = ui.GetFrame('minimap_region_info_detail')
	if panel ~= nil and panel:IsVisible() == 1 and MINIMAP_REGION_INFO_DETAIL_REFRESH ~= nil then
		MINIMAP_REGION_INFO_DETAIL_REFRESH(panel, REGION_INFO.activeCategory)
	end
end

function MINIMAP_REGION_INFO_ON_PANEL_CLOSED()
	REGION_INFO.activeCategory = nil
	MINIMAP_REGION_INFO_UPDATE_BUTTONS()
	if MINIMAP_REGION_INFO_DETAIL_CLEAR_MARKERS ~= nil then
		MINIMAP_REGION_INFO_DETAIL_CLEAR_MARKERS()
	end
end

function MINIMAP_REGION_INFO_CLOSE_PANEL()
	local panel = ui.GetFrame('minimap_region_info_detail')
	if panel ~= nil and panel:IsVisible() == 1 then
		ui.CloseFrame('minimap_region_info_detail')
	else
		MINIMAP_REGION_INFO_ON_PANEL_CLOSED()
	end
end

function MINIMAP_REGION_INFO_TOGGLE_MINIMIZED(frame, ctrl, argStr, argNum)
	if MINIMAP_REGION_INFO_IS_ENABLED() == false then
		return
	end
	REGION_INFO.isMinimized = REGION_INFO.isMinimized ~= true
	if REGION_INFO.isMinimized == true then
		MINIMAP_REGION_INFO_CLOSE_PANEL()
	end
	MINIMAP_REGION_INFO_APPLY_MINIMIZED(frame)
	MINIMAP_REGION_INFO_SYNC_LAYOUT()
end

function MINIMAP_REGION_INFO_TOGGLE_CATEGORY(frame, ctrl, argStr, argNum)
	if MINIMAP_REGION_INFO_IS_ENABLED() == false then
		return
	end
	local category = string.upper(tostring(argStr or ''))
	if MINIMAP_REGION_INFO_IS_VALID_CATEGORY(category) == false then
		return
	end

	local panel = ui.GetFrame('minimap_region_info_detail')
	if panel == nil then
		return
	end
	if REGION_INFO.activeCategory == category and panel:IsVisible() == 1 then
		MINIMAP_REGION_INFO_CLOSE_PANEL()
		return
	end

	REGION_INFO.activeCategory = category
	REGION_INFO.page = 1
	MINIMAP_REGION_INFO_UPDATE_BUTTONS()
	MINIMAP_REGION_INFO_SYNC_LAYOUT()
	ui.OpenFrame('minimap_region_info_detail')
	if MINIMAP_REGION_INFO_DETAIL_REFRESH ~= nil then
		MINIMAP_REGION_INFO_DETAIL_REFRESH(panel, category)
	end
end

function MINIMAP_REGION_INFO_ON_GAME_START(frame, msg, argStr, argNum)
	if MINIMAP_REGION_INFO_IS_ENABLED() == false then
		MINIMAP_REGION_INFO_SYNC_LAYOUT()
		return
	end
	REGION_INFO.lastMapName = MINIMAP_REGION_INFO_CURRENT_MAP_NAME()
	MINIMAP_REGION_INFO_INVALIDATE(frame, msg, argStr, argNum)
	ReserveScript('MINIMAP_REGION_INFO_SYNC_LAYOUT()', 0.3)
end

function MINIMAP_REGION_INFO_ON_TIMER(frame)
	if MINIMAP_REGION_INFO_IS_ENABLED() == false then
		return 1
	end
	local currentMapName = MINIMAP_REGION_INFO_CURRENT_MAP_NAME()
	if REGION_INFO.lastMapName ~= currentMapName then
		REGION_INFO.lastMapName = currentMapName
		MINIMAP_REGION_INFO_INVALIDATE(frame)
		if MINIMAP_REGION_INFO_DETAIL_CLEAR_MARKERS ~= nil then
			MINIMAP_REGION_INFO_DETAIL_CLEAR_MARKERS()
		end
	end

	MINIMAP_REGION_INFO_SYNC_LAYOUT()
	local mapDisplayMode = MINIMAP_REGION_INFO_IS_FULL_MAP_VISIBLE() and 'FULL_MAP' or 'MINIMAP'
	if REGION_INFO.lastMapDisplayMode ~= mapDisplayMode then
		REGION_INFO.lastMapDisplayMode = mapDisplayMode
		if MINIMAP_REGION_INFO_DETAIL_REFRESH_MARKERS ~= nil then
			MINIMAP_REGION_INFO_DETAIL_REFRESH_MARKERS()
		end
	end

	local minimap = ui.GetFrame('minimap')
	if minimap ~= nil then
		local mapPicture = GET_CHILD(minimap, 'map', 'ui::CPicture')
		if mapPicture ~= nil then
			local sizeKey = tostring(mapPicture:GetWidth()) .. ':' .. tostring(mapPicture:GetHeight())
			if REGION_INFO.lastMinimapSize ~= sizeKey then
				REGION_INFO.lastMinimapSize = sizeKey
				if MINIMAP_REGION_INFO_DETAIL_REFRESH_MARKERS ~= nil then
					MINIMAP_REGION_INFO_DETAIL_REFRESH_MARKERS()
				end
			end
		end
	end
	return 1
end

function MINIMAP_REGION_INFO_ON_INIT(addon, frame)
	REGION_INFO.addon = addon
	REGION_INFO.frame = frame
	MINIMAP_REGION_INFO_LOAD_SETTINGS()
	addon:RegisterMsg('GAME_START', 'MINIMAP_REGION_INFO_ON_GAME_START')
	addon:RegisterMsg('CHANGE_CLIENT_SIZE', 'MINIMAP_REGION_INFO_SYNC_LAYOUT')
	addon:RegisterMsg('QUEST_UPDATE', 'MINIMAP_REGION_INFO_INVALIDATE')
	addon:RegisterMsg('GET_NEW_QUEST', 'MINIMAP_REGION_INFO_INVALIDATE')
	addon:RegisterMsg('QUEST_DELETED', 'MINIMAP_REGION_INFO_INVALIDATE')
	addon:RegisterMsg('NPC_STATE_UPDATE', 'MINIMAP_REGION_INFO_INVALIDATE')
	addon:RegisterMsg('ADD_COLLECTION', 'MINIMAP_REGION_INFO_INVALIDATE')
	addon:RegisterMsg('COLLECTION_ITEM_CHANGE', 'MINIMAP_REGION_INFO_INVALIDATE')
	addon:RegisterMsg('UPDATE_ADVENTURE_BOOK_CONTENTS_POINT', 'MINIMAP_REGION_INFO_INVALIDATE')

	MINIMAP_REGION_INFO_SET_TIMER_ENABLED(frame, REGION_INFO.settings.enabled ~= false)
	REGION_INFO.lastMapName = MINIMAP_REGION_INFO_CURRENT_MAP_NAME()
	MINIMAP_REGION_INFO_APPLY_MINIMIZED(frame)
	MINIMAP_REGION_INFO_UPDATE_BUTTONS()
	MINIMAP_REGION_INFO_SYNC_LAYOUT()
end
