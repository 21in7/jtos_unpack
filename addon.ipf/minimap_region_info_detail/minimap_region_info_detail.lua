MINIMAP_REGION_INFO_DETAIL = MINIMAP_REGION_INFO_DETAIL or {}

local DETAIL = MINIMAP_REGION_INFO_DETAIL

DETAIL.data = DETAIL.data or {}
DETAIL.category = DETAIL.category or nil
DETAIL.mapName = DETAIL.mapName or nil
DETAIL.selectedDataIndex = DETAIL.selectedDataIndex or nil
DETAIL.selectedCategory = DETAIL.selectedCategory or nil
DETAIL.markerSerial = DETAIL.markerSerial or 0

local ROW_CONTROLSET_NAME = 'minimap_region_info_detail_row'
local ROW_HEIGHT = 59
local GEN_AREA_ALPHA = 100
local GEN_MARKER_COLOR_TONE = 'CC72D66B'
local GEN_AREA_COLOR_TONE = 'FF72D66B'

local function MINIMAP_REGION_INFO_DETAIL_GET_PANEL()
	return ui.GetFrame('minimap_region_info_detail')
end

local function MINIMAP_REGION_INFO_DETAIL_GET_ROW_LIST(frame)
	if frame == nil then
		return nil
	end
	return GET_CHILD_RECURSIVELY(frame, 'row_list', 'ui::CGroupBox')
end

local function MINIMAP_REGION_INFO_DETAIL_GET_ROW(frame, rowIndex)
	local rowList = MINIMAP_REGION_INFO_DETAIL_GET_ROW_LIST(frame)
	if rowList == nil then
		return nil
	end
	return GET_CHILD(rowList, 'row' .. tostring(rowIndex), 'ui::CControlSet')
end

local function MINIMAP_REGION_INFO_DETAIL_CREATE_ROWS(frame)
	local rowList = MINIMAP_REGION_INFO_DETAIL_GET_ROW_LIST(frame)
	if rowList == nil then
		return
	end

	for rowIndex = 1, MINIMAP_REGION_INFO.PAGE_SIZE do
		local rowY = (rowIndex - 1) * ROW_HEIGHT
		local row = rowList:CreateOrGetControlSet(ROW_CONTROLSET_NAME, 'row' .. tostring(rowIndex), 0, rowY)
		row:SetOffset(0, rowY)
		row:Resize(rowList:GetWidth(), ROW_HEIGHT)
		row:SetEventScript(ui.LBUTTONUP, 'MINIMAP_REGION_INFO_DETAIL_SELECT_ROW')
		row:SetEventScriptArgNumber(ui.LBUTTONUP, rowIndex)

		local locationButton = GET_CHILD(row, 'location', 'ui::CButton')
		local monsterLocationButton = GET_CHILD(row, 'monster_location', 'ui::CButton')
		locationButton:SetEventScriptArgNumber(ui.LBUTTONUP, rowIndex)
		monsterLocationButton:SetEventScriptArgNumber(ui.LBUTTONUP, rowIndex)
	end
	rowList:Invalidate()
end

local function MINIMAP_REGION_INFO_DETAIL_SHOW_CATEGORY_HEADER(frame, category)
	local categories = {
		MONSTER = 'monster',
		COLLECTION = 'collection',
		NPC = 'npc',
		QUEST = 'quest'
	}

	for categoryName, suffix in pairs(categories) do
		local title = GET_CHILD_RECURSIVELY(frame, 'title_' .. suffix)
		local summary = GET_CHILD_RECURSIVELY(frame, 'summary_' .. suffix)
		local visible = categoryName == category and 1 or 0
		if title ~= nil then
			title:ShowWindow(visible)
		end
		if summary ~= nil then
			summary:ShowWindow(visible)
		end
	end
end

local function MINIMAP_REGION_INFO_DETAIL_UPDATE_SUMMARY(frame, category, data)
	if category == 'MONSTER' then
		local unknownCount = 0
		for _, item in ipairs(data) do
			unknownCount = unknownCount + (item.unknown or 0)
		end
		local summary = GET_CHILD_RECURSIVELY(frame, 'summary_monster')
		summary:SetTextByKey('total', #data)
		summary:SetTextByKey('unknown', unknownCount)
	elseif category == 'COLLECTION' then
		local summary = GET_CHILD_RECURSIVELY(frame, 'summary_collection')
		summary:SetTextByKey('total', #data)
	elseif category == 'NPC' then
		local summary = GET_CHILD_RECURSIVELY(frame, 'summary_npc')
		summary:SetTextByKey('total', #data)
	elseif category == 'QUEST' then
		local summary = GET_CHILD_RECURSIVELY(frame, 'summary_quest')
		summary:SetTextByKey('total', #data)
	end
end

local function MINIMAP_REGION_INFO_DETAIL_HIDE_ROW_CATEGORY_CONTROLS(row)
	local suffixes = {
		'level',
		'monster_race_icon',
		'monster_attribute_icon',
		'monster_armor_icon',
		'monster_attr',
		'monster_meta',
		'npc_meta',
		'quest_meta',
		'collection_meta'
	}
	for _, suffix in ipairs(suffixes) do
		local control = GET_CHILD(row, suffix)
		if control ~= nil then
			control:ShowWindow(0)
		end
	end
end

local function MINIMAP_REGION_INFO_DETAIL_SET_ROW(frame, rowIndex, dataIndex, item, category)
	local row = MINIMAP_REGION_INFO_DETAIL_GET_ROW(frame, rowIndex)
	if row == nil then
		return
	end

	if item == nil then
		row:ShowWindow(0)
		row:SetUserValue('DATA_INDEX', 0)
		return
	end

	row:ShowWindow(1)
	row:SetUserValue('DATA_INDEX', dataIndex)
	MINIMAP_REGION_INFO_DETAIL_HIDE_ROW_CATEGORY_CONTROLS(row)

	local icon = GET_CHILD(row, 'icon', 'ui::CPicture')
	local title = GET_CHILD(row, 'title', 'ui::CRichText')
	local locationButton = GET_CHILD(row, 'location', 'ui::CButton')
	local monsterLocationButton = GET_CHILD(row, 'monster_location', 'ui::CButton')
	locationButton:ShowWindow(0)
	monsterLocationButton:ShowWindow(0)
	if icon ~= nil then
		icon:SetImage(item.icon or 'question_mark')
		icon:SetEnableStretch(1)
	end
	if title ~= nil then
		title:SetTextByKey('value', item.name or '-')
	end
	
	if category == 'MONSTER' then
		local level = GET_CHILD(row, 'level', 'ui::CRichText')
		local raceIcon = GET_CHILD(row, 'monster_race_icon', 'ui::CPicture')
		local attributeIcon = GET_CHILD(row, 'monster_attribute_icon', 'ui::CPicture')
		local armorIcon = GET_CHILD(row, 'monster_armor_icon', 'ui::CPicture')
		local attribute = GET_CHILD(row, 'monster_attr', 'ui::CRichText')
		local meta = GET_CHILD(row, 'monster_meta', 'ui::CRichText')

		level:SetTextByKey('value', item.level or 0)
		level:ShowWindow(1)

		local monsterIcons = {
			{ control = raceIcon, image = item.raceImage, tooltip = item.race },
			{ control = attributeIcon, image = item.attributeImage, tooltip = item.attribute },
			{ control = armorIcon, image = item.armorImage, tooltip = item.armor }
		}
		for _, iconInfo in ipairs(monsterIcons) do
			if iconInfo.control ~= nil and iconInfo.image ~= nil then
				iconInfo.control:SetImage(iconInfo.image)
				iconInfo.control:SetEnableStretch(1)
				iconInfo.control:SetTextTooltip(iconInfo.tooltip or '')
				iconInfo.control:ShowWindow(1)
			end
		end

		attribute:SetTextByKey('race', item.race or '-')
		attribute:SetTextByKey('attribute', item.attribute or '-')
		attribute:SetTextByKey('armor', item.armor or '-')
		attribute:SetTextByKey('size', item.size or '-')
		attribute:ShowWindow(1)
		meta:SetTextByKey('maxpop', item.maxPop or 0)
		meta:SetTextByKey('respawn', item.respawnSeconds or 0)
		meta:SetTextByKey('current', item.journalCurrent or 0)
		meta:SetTextByKey('maximum', item.journalMaximum or 0)
		meta:ShowWindow(1)
		monsterLocationButton:ShowWindow(1)
	elseif category == 'NPC' then
		local meta = GET_CHILD(row, 'npc_meta', 'ui::CRichText')
		meta:SetTextByKey('count', item.locationCount or 0)
		meta:ShowWindow(1)
		locationButton:ShowWindow(1)
	elseif category == 'QUEST' then
		local meta = GET_CHILD(row, 'quest_meta', 'ui::CRichText')
		meta:SetTextByKey('state', item.stateText or '-')
		meta:SetTextByKey('level', item.level or 0)
		meta:ShowWindow(1)
		locationButton:ShowWindow(1)
	elseif category == 'COLLECTION' then
		local meta = GET_CHILD(row, 'collection_meta', 'ui::CRichText')
		meta:SetTextByKey('current', item.current or 0)
		meta:SetTextByKey('maximum', item.maximum or 0)
		meta:SetTextByKey('related', item.relatedCount or 0)
		meta:ShowWindow(1)
		locationButton:ShowWindow(0)
	end

	if DETAIL.selectedDataIndex == dataIndex and DETAIL.selectedCategory == category then
		row:SetSkinName('quest_bg_black_op_50')
	else
		row:SetSkinName('None')
	end
end

local function MINIMAP_REGION_INFO_DETAIL_UPDATE_ROW_SELECTION(frame)
	for rowIndex = 1, MINIMAP_REGION_INFO.PAGE_SIZE do
		local row = MINIMAP_REGION_INFO_DETAIL_GET_ROW(frame, rowIndex)
		if row ~= nil and row:IsVisible() == 1 then
			local dataIndex = row:GetUserIValue('DATA_INDEX')
			if DETAIL.selectedDataIndex == dataIndex and DETAIL.selectedCategory == DETAIL.category then
				row:SetSkinName('quest_bg_black_op_50')
			else
				row:SetSkinName('None')
			end
		end
	end
end

function MINIMAP_REGION_INFO_DETAIL_REFRESH(frame, category)
	frame = frame or MINIMAP_REGION_INFO_DETAIL_GET_PANEL()
	category = category or MINIMAP_REGION_INFO_GET_ACTIVE_CATEGORY()
	if frame == nil or category == nil then
		return
	end
	MINIMAP_REGION_INFO_DETAIL_CREATE_ROWS(frame)

	local data, mapName, mapDisplayName = MINIMAP_REGION_INFO_GET_CATEGORY_DATA(category, false)
	DETAIL.data = data or {}
	DETAIL.category = category
	DETAIL.mapName = mapName

	MINIMAP_REGION_INFO_DETAIL_SHOW_CATEGORY_HEADER(frame, category)
	MINIMAP_REGION_INFO_DETAIL_UPDATE_SUMMARY(frame, category, DETAIL.data)

	local mapNameControl = GET_CHILD_RECURSIVELY(frame, 'map_name', 'ui::CRichText')
	mapNameControl:SetTextByKey('value', mapDisplayName or mapName)

	local pageSize = MINIMAP_REGION_INFO.PAGE_SIZE
	local totalPages = math.max(1, math.ceil(#DETAIL.data / pageSize))
	MINIMAP_REGION_INFO.page = math.max(1, math.min(MINIMAP_REGION_INFO.page or 1, totalPages))
	local startIndex = ((MINIMAP_REGION_INFO.page - 1) * pageSize) + 1
	for rowIndex = 1, pageSize do
		local dataIndex = startIndex + rowIndex - 1
		MINIMAP_REGION_INFO_DETAIL_SET_ROW(frame, rowIndex, dataIndex, DETAIL.data[dataIndex], category)
	end

	local emptyText = GET_CHILD_RECURSIVELY(frame, 'empty_text')
	emptyText:ShowWindow(#DETAIL.data == 0 and 1 or 0)

	local pageText = GET_CHILD_RECURSIVELY(frame, 'page_text', 'ui::CRichText')
	pageText:SetTextByKey('page', MINIMAP_REGION_INFO.page)
	pageText:SetTextByKey('total', totalPages)
	local previousButton = GET_CHILD_RECURSIVELY(frame, 'prev_btn', 'ui::CButton')
	local nextButton = GET_CHILD_RECURSIVELY(frame, 'next_btn', 'ui::CButton')
	previousButton:SetEnable(MINIMAP_REGION_INFO.page > 1 and 1 or 0)
	nextButton:SetEnable(MINIMAP_REGION_INFO.page < totalPages and 1 or 0)
	frame:Invalidate()
end

function MINIMAP_REGION_INFO_DETAIL_CHANGE_PAGE(frame, ctrl, argStr, argNum)
	local delta = tonumber(argNum) or 0
	local totalPages = math.max(1, math.ceil(#DETAIL.data / MINIMAP_REGION_INFO.PAGE_SIZE))
	MINIMAP_REGION_INFO.page = math.max(1, math.min((MINIMAP_REGION_INFO.page or 1) + delta, totalPages))
	DETAIL.selectedDataIndex = nil
	DETAIL.selectedCategory = nil
	MINIMAP_REGION_INFO_DETAIL_CLEAR_MARKERS()
	MINIMAP_REGION_INFO_DETAIL_REFRESH(MINIMAP_REGION_INFO_DETAIL_GET_PANEL(), DETAIL.category)
end

local function MINIMAP_REGION_INFO_DETAIL_CREATE_MARKER(parent, x, y)
	DETAIL.markerSerial = DETAIL.markerSerial + 1
	local markerName = 'MINIMAP_REGION_INFO_MARK_' .. tostring(DETAIL.markerSerial)
	local marker = parent:CreateOrGetControl('picture', markerName, math.floor(x - 14), math.floor(y - 14), 28, 28)
	tolua.cast(marker, 'ui::CPicture')
	marker:SetImage('worldmap2_map_zonecheck')
	marker:SetEnableStretch(1)
	marker:SetColorTone(GEN_MARKER_COLOR_TONE)
	marker:EnableHitTest(0)
	marker:SetUserValue('EXTERN', 'MINIMAP_REGION_INFO')
	marker:ShowWindow(1)
end

local function MINIMAP_REGION_INFO_DETAIL_CREATE_GEN_AREA(parent, x, y, width, height)
	DETAIL.markerSerial = DETAIL.markerSerial + 1
	local markerName = 'MINIMAP_REGION_INFO_MARK_' .. tostring(DETAIL.markerSerial)
	width = math.max(math.floor(width), 28)
	height = math.max(math.floor(height), 28)
	local area = parent:CreateOrGetControl('picture', markerName, math.floor(x - width / 2), math.floor(y - height / 2), width, height)
	tolua.cast(area, 'ui::CPicture')
	area:SetImage('worldmap2_map_zonecheck')
	area:SetEnableStretch(1)
	area:SetAlpha(GEN_AREA_ALPHA)
	area:SetColorTone(GEN_AREA_COLOR_TONE)
	area:EnableHitTest(0)
	area:SetUserValue('EXTERN', 'MINIMAP_REGION_INFO')
	area:ShowWindow(1)
end

local function MINIMAP_REGION_INFO_DETAIL_GET_MARKER_CONTEXT()
	local fullMap = ui.GetFrame('map')
	if fullMap ~= nil and fullMap:IsVisible() == 1 then
		local mapPicture = GET_CHILD_RECURSIVELY(fullMap, 'map', 'ui::CPicture')
		if mapPicture ~= nil then
			return {
				parent = fullMap,
				searchRoot = fullMap,
				mapPicture = mapPicture,
				offsetX = mapPicture:GetX(),
				offsetY = mapPicture:GetY()
			}
		end
	end

	local minimap = ui.GetFrame('minimap')
	if minimap == nil then
		return nil
	end
	local mapPicture = GET_CHILD(minimap, 'map', 'ui::CPicture')
	local npcList = GET_CHILD(minimap, 'npclist', 'ui::CGroupBox')
	if mapPicture == nil or npcList == nil then
		return nil
	end
	return {
		parent = npcList,
		searchRoot = npcList,
		mapPicture = mapPicture,
		offsetX = 0,
		offsetY = 0
	}
end

function MINIMAP_REGION_INFO_DETAIL_CLEAR_MARKERS()
	local minimap = ui.GetFrame('minimap')
	if minimap ~= nil then
		local npcList = GET_CHILD(minimap, 'npclist', 'ui::CGroupBox')
		if npcList ~= nil then
			DESTROY_CHILD_BYNAME(npcList, 'MINIMAP_REGION_INFO_MARK_')
			npcList:Invalidate()
		end
	end

	local fullMap = ui.GetFrame('map')
	if fullMap ~= nil then
		DESTROY_CHILD_BYNAME(fullMap, 'MINIMAP_REGION_INFO_MARK_')
		fullMap:Invalidate()
	end
	DETAIL.markerSerial = 0
end

local function MINIMAP_REGION_INFO_DETAIL_DRAW_GEN_MARKERS(item)
	local context = MINIMAP_REGION_INFO_DETAIL_GET_MARKER_CONTEXT()
	if context == nil then
		return
	end

	local mapProp = geMapTable.GetMapProp(DETAIL.mapName)
	if mapProp == nil or mapProp.mongens == nil then
		return
	end

	local mapWidth = context.mapPicture:GetWidth()
	local mapHeight = context.mapPicture:GetHeight()
	local minimapLocationMultiplier = tonumber(MINIMAP_LOC_MULTI)
	local worldSize = tonumber(WORLD_SIZE)
	local monGens = mapProp.mongens
	for index = 0, monGens:Count() - 1 do
		local monProp = monGens:Element(index)
		local genType = tostring(monProp.GenType)
		if item.genTypes[genType] == true and monProp.GenList ~= nil then
			local genRange = item.genRanges ~= nil and tonumber(item.genRanges[genType]) or nil
			for positionIndex = 0, monProp.GenList:Count() - 1 do
				local worldPosition = monProp.GenList:Element(positionIndex)
				local mapPosition = mapProp:WorldPosToMinimapPos(worldPosition, mapWidth, mapHeight)
				local x = context.offsetX + mapPosition.x
				local y = context.offsetY + mapPosition.y
				if genRange ~= nil and genRange > 0 and minimapLocationMultiplier ~= nil and worldSize ~= nil and worldSize > 0 then
					MINIMAP_REGION_INFO_DETAIL_CREATE_GEN_AREA(
						context.parent,
						x,
						y,
						genRange * minimapLocationMultiplier * mapWidth / worldSize,
						genRange * minimapLocationMultiplier * mapHeight / worldSize
					)
				else
					MINIMAP_REGION_INFO_DETAIL_CREATE_MARKER(context.parent, x, y)
				end
			end
		end
	end
	context.parent:Invalidate()
end

local function MINIMAP_REGION_INFO_DETAIL_DRAW_QUEST_MARKERS(item)
	local context = MINIMAP_REGION_INFO_DETAIL_GET_MARKER_CONTEXT()
	if context == nil or GET_QUEST_CONTROL_NAME_LIST == nil then
		return
	end

	local controlNames = GET_QUEST_CONTROL_NAME_LIST(DETAIL.mapName, item.className)
	if controlNames == nil then
		return
	end
	for index = 1, #controlNames do
		local locationControl = GET_CHILD_RECURSIVELY(context.searchRoot, controlNames[index])
		if locationControl ~= nil then
			local x = locationControl:GetGlobalX() - context.parent:GetGlobalX() + (locationControl:GetWidth() / 2)
			local y = locationControl:GetGlobalY() - context.parent:GetGlobalY() + (locationControl:GetHeight() / 2)
			MINIMAP_REGION_INFO_DETAIL_CREATE_MARKER(context.parent, x, y)
		end
	end
	context.parent:Invalidate()
end

local function MINIMAP_REGION_INFO_DETAIL_DRAW_SELECTED_MARKERS()
	MINIMAP_REGION_INFO_DETAIL_CLEAR_MARKERS()
	if DETAIL.selectedDataIndex == nil or DETAIL.selectedCategory == nil then
		return
	end
	local item = DETAIL.data[DETAIL.selectedDataIndex]
	if item == nil then
		return
	end

	if DETAIL.selectedCategory == 'MONSTER' or DETAIL.selectedCategory == 'NPC' then
		MINIMAP_REGION_INFO_DETAIL_DRAW_GEN_MARKERS(item)
	elseif DETAIL.selectedCategory == 'QUEST' then
		MINIMAP_REGION_INFO_DETAIL_DRAW_QUEST_MARKERS(item)
	end
end

function MINIMAP_REGION_INFO_DETAIL_REFRESH_MARKERS()
	local panel = MINIMAP_REGION_INFO_DETAIL_GET_PANEL()
	if panel == nil or panel:IsVisible() == 0 then
		return
	end
	if DETAIL.mapName ~= session.GetMapName() then
		DETAIL.selectedDataIndex = nil
		DETAIL.selectedCategory = nil
		MINIMAP_REGION_INFO_DETAIL_CLEAR_MARKERS()
		return
	end
	MINIMAP_REGION_INFO_DETAIL_DRAW_SELECTED_MARKERS()
end

function MINIMAP_REGION_INFO_DETAIL_TOGGLE_MARKER(frame, ctrl, argStr, argNum)
	local rowIndex = tonumber(argNum) or 0
	local panel = MINIMAP_REGION_INFO_DETAIL_GET_PANEL()
	local row = MINIMAP_REGION_INFO_DETAIL_GET_ROW(panel, rowIndex)
	if row == nil then
		return
	end

	local dataIndex = row:GetUserIValue('DATA_INDEX')
	if dataIndex <= 0 or DETAIL.data[dataIndex] == nil then
		return
	end

	if DETAIL.selectedDataIndex == dataIndex and DETAIL.selectedCategory == DETAIL.category then
		DETAIL.selectedDataIndex = nil
		DETAIL.selectedCategory = nil
		MINIMAP_REGION_INFO_DETAIL_CLEAR_MARKERS()
	else
		DETAIL.selectedDataIndex = dataIndex
		DETAIL.selectedCategory = DETAIL.category
		MINIMAP_REGION_INFO_DETAIL_DRAW_SELECTED_MARKERS()
	end
	MINIMAP_REGION_INFO_DETAIL_UPDATE_ROW_SELECTION(panel)
end

function MINIMAP_REGION_INFO_DETAIL_SELECT_ROW(frame, ctrl, argStr, argNum)
	if DETAIL.category == 'COLLECTION' then
		ui.OpenFrame('collection')
		return
	end
	MINIMAP_REGION_INFO_DETAIL_TOGGLE_MARKER(frame, ctrl, argStr, argNum)
end

function MINIMAP_REGION_INFO_DETAIL_CLOSE(frame, ctrl, argStr, argNum)
	MINIMAP_REGION_INFO_CLOSE_PANEL()
end

function MINIMAP_REGION_INFO_DETAIL_ON_OPEN(frame)
	MINIMAP_REGION_INFO_SYNC_LAYOUT()
	MINIMAP_REGION_INFO_DETAIL_REFRESH(frame, MINIMAP_REGION_INFO_GET_ACTIVE_CATEGORY())
end

function MINIMAP_REGION_INFO_DETAIL_ON_CLOSE(frame)
	DETAIL.selectedDataIndex = nil
	DETAIL.selectedCategory = nil
	MINIMAP_REGION_INFO_DETAIL_CLEAR_MARKERS()
	MINIMAP_REGION_INFO_ON_PANEL_CLOSED()
end

function MINIMAP_REGION_INFO_DETAIL_ON_ESCAPE(frame, msg, argStr, argNum)
	local panel = MINIMAP_REGION_INFO_DETAIL_GET_PANEL()
	if panel ~= nil and panel:IsVisible() == 1 then
		MINIMAP_REGION_INFO_CLOSE_PANEL()
	end
end

function MINIMAP_REGION_INFO_DETAIL_ON_INIT(addon, frame)
	DETAIL.addon = addon
	DETAIL.frame = frame
	addon:RegisterMsg('ESCAPE_PRESSED', 'MINIMAP_REGION_INFO_DETAIL_ON_ESCAPE')
	addon:RegisterMsg('CHANGE_CLIENT_SIZE', 'MINIMAP_REGION_INFO_SYNC_LAYOUT')
end
