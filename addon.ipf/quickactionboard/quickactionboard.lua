local PATH = require("path")
require("json")

local QAB_SETTINGS_ROOT = "..\\release\\addon_setting\\quickactionboard"

QUICKACTIONBOARD = QUICKACTIONBOARD or {}
local QAB = QUICKACTIONBOARD

QAB.SCHEMA_VERSION = 4
QAB.MAX_BOARD_COUNT = 5
QAB.MAX_TOTAL_SLOT_COUNT = 100
QAB.MIN_ROW_COL = 1
QAB.MAX_ROW_COL = 8
QAB.MIN_SCALE = 50
QAB.MAX_SCALE = 150
QAB.MIN_ALPHA = 10
QAB.MAX_ALPHA = 100
QAB.MAX_CHARACTER_BUCKET_COUNT = 64
QAB.MAX_CHARACTER_SOURCE_ENTRIES = 128
QAB.MAX_BOARD_SOURCE_ENTRIES = 32
QAB.MAX_ACTION_SOURCE_ENTRIES = 256
QAB.MAX_BOARD_NAME_BYTES = 96
QAB.MAX_IES_ID_BYTES = 128
QAB.MAX_CLASS_ID = 2147483647
QAB.MAX_SETTINGS_FILE_BYTES = 1048576
QAB.JOYSTICK_HOLD_SECONDS = 0.7
QAB.data = QAB.data or nil
QAB.loaded = QAB.loaded or false
QAB.settingsReady = QAB.settingsReady or false
QAB.frameNames = QAB.frameNames or {}
QAB.activeBoards = QAB.activeBoards or {}
QAB.paletteActions = QAB.paletteActions or {}
QAB.selectedBoardID = QAB.selectedBoardID or nil
QAB.paletteKind = QAB.paletteKind or "Pose"
QAB.paletteColumns = 7
QAB.managerTab = QAB.managerTab or "Settings"
QAB.managerAdvanced = QAB.managerAdvanced or false
QAB.managerDirty = false
QAB.pendingBoardIndex = nil
QAB.pendingAddBoard = false
QAB.dragAction = nil
QAB.dragSourceBoardID = nil
QAB.dragSourceSlotIndex = nil
QAB.dragFrameName = nil
QAB.menuBoardID = nil
QAB.joystickFocus = false
QAB.joystickBoardIndex = 1
QAB.joystickSlotIndex = 0
QAB.joystickHoldTime = 0
QAB.joystickHoldTriggered = false
QAB.joystickWaitRelease = false
QAB.joystickPrevious = QAB.joystickPrevious or {}
QAB.specialItemEffects = QAB.specialItemEffects or {}
QAB.specialEffectElapsed = QAB.specialEffectElapsed or {}

local QAB_ALLOWED_ACTION_KINDS = {
    Item = true,
    Skill = true,
    Ability = true,
    Pose = true,
    Motion = true,
    Emoticon = true,
    Warp = true
}

local function QAB_MANAGER_FRAME()
    return ui.GetFrame("quickactionboard")
end

local function QAB_CURRENT_CID()
    local mySession = session.GetMySession()
    if mySession == nil then
        return "0"
    end
    return tostring(mySession:GetCID())
end

local function QAB_DEEP_COPY(value)
    if type(value) ~= "table" then
        return value
    end

    local copied = {}
    for key, child in pairs(value) do
        copied[QAB_DEEP_COPY(key)] = QAB_DEEP_COPY(child)
    end
    return copied
end

local function QAB_CLAMP(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function QAB_TRIM(value)
    if value == nil then
        return ""
    end
    return string.match(tostring(value), "^%s*(.-)%s*$") or ""
end

local function QAB_SANITIZE_BOARD_NAME(value)
    local name = QAB_TRIM(value)
    name = string.gsub(name, "[{}]", "")
    name = string.gsub(name, "%c", "")
    return QAB_TRIM(name)
end

local function QAB_DEFAULT_DATA()
    return {
        schemaVersion = QAB.SCHEMA_VERSION,
        initialized = false,
        enabled = true,
        nextBoardID = 1,
        globalVisible = true,
        accountBoards = {},
        characterBoards = {},
        hud = {}
    }
end

local function QAB_DEFAULT_BOARD_NAME(sequence)
    local frame = QAB_MANAGER_FRAME()
    local nameFormat = frame ~= nil and frame:GetUserConfig("DEFAULT_BOARD_NAME_FORMAT") or "%d"
    return string.format(nameFormat, sequence)
end

-- Schema 3 stored the rendered default name. Schema 4+ stores only its index,
-- so this list is used solely to recognize defaults saved by older clients.
local QAB_LEGACY_DEFAULT_BOARD_NAME_FORMATS = {
    "보드 %d",
    "Board %d",
    "ボード %d",
    "Papan %d"
}

local function QAB_LEGACY_DEFAULT_BOARD_NAME_INDEX(name, sequence)
    name = tostring(name or "")
    sequence = math.floor(tonumber(sequence) or 0)
    local suffixSequence = tonumber(string.match(name, "(%d+)%s*$"))
    local candidates = {}
    if suffixSequence ~= nil then
        table.insert(candidates, suffixSequence)
    end
    table.insert(candidates, sequence)
    local checked = {}
    for _, candidate in ipairs(candidates) do
        candidate = math.floor(tonumber(candidate) or 0)
        if candidate > 0 and checked[candidate] ~= true then
            checked[candidate] = true
            if name == QAB_DEFAULT_BOARD_NAME(candidate) then
                return candidate
            end
            for _, nameFormat in ipairs(QAB_LEGACY_DEFAULT_BOARD_NAME_FORMATS) do
                if name == string.format(nameFormat, candidate) then
                    return candidate
                end
            end
        end
    end
    return nil
end

local function QAB_BOARD_DISPLAY_NAME(board)
    if board == nil then
        return ""
    end
    if board.usesDefaultName == true or QAB_TRIM(board.name) == "" then
        return QAB_DEFAULT_BOARD_NAME(board.defaultNameIndex or board.order)
    end
    return board.name
end

local function QAB_NEXT_DEFAULT_BOARD_NAME_INDEX()
    local usedNames = {}
    if QAB.data ~= nil then
        for _, board in ipairs(QAB.data.accountBoards or {}) do
            usedNames[QAB_BOARD_DISPLAY_NAME(board)] = true
        end

        local currentCID = QAB_CURRENT_CID()
        local characterBoards = QAB.data.characterBoards and QAB.data.characterBoards[currentCID] or {}
        for _, board in ipairs(characterBoards or {}) do
            usedNames[QAB_BOARD_DISPLAY_NAME(board)] = true
        end
    end

    for visibleSequence = 1, QAB.MAX_BOARD_COUNT + 1 do
        local candidate = QAB_DEFAULT_BOARD_NAME(visibleSequence)
        if usedNames[candidate] ~= true then
            return visibleSequence
        end
    end
    return QAB.MAX_BOARD_COUNT + 1
end

local function QAB_DEFAULT_HUD(board)
    local order = tonumber(board.order) or 1
    return {
        xRatio = QAB_CLAMP(0.32 + ((order - 1) % 3) * 0.04, 0, 1),
        yRatio = QAB_CLAMP(0.62 + math.floor((order - 1) / 3) * 0.05, 0, 1),
        scale = 100,
        alpha = 100,
        locked = false,
        visible = true,
        minimized = false
    }
end

local function QAB_NORMALIZE_ACTION(action)
    if type(action) ~= "table" or QAB_ALLOWED_ACTION_KINDS[action.kind] ~= true then
        return nil
    end

    local classID = tonumber(action.classID)
    if classID == nil or classID < 1 or classID > QAB.MAX_CLASS_ID then
        return nil
    end
    classID = math.floor(classID)

    local iesID = tostring(action.iesID or "0")
    if iesID == "" or #iesID > QAB.MAX_IES_ID_BYTES or string.match(iesID, "^[%w_%-]+$") == nil then
        iesID = "0"
    end

    return {
        kind = action.kind,
        classID = classID,
        iesID = iesID
    }
end

local function QAB_COLLECT_ACTION_ENTRIES(actions)
    local indexed = {}
    local sourceCount = 0
    if type(actions) == "table" then
        for key, action in pairs(actions) do
            sourceCount = sourceCount + 1
            if sourceCount > QAB.MAX_ACTION_SOURCE_ENTRIES then
                break
            end

            local index = tonumber(key)
            if index ~= nil then
                index = math.floor(index)
                if index >= 1 and index <= QAB.MAX_ROW_COL * QAB.MAX_ROW_COL and indexed[index] == nil then
                    indexed[index] = QAB_NORMALIZE_ACTION(action)
                end
            end
        end
    end

    local entries = {}
    for index, action in pairs(indexed) do
        if action ~= nil then
            table.insert(entries, { index = index, action = action })
        end
    end
    table.sort(entries, function(left, right)
        return left.index < right.index
    end)
    return entries
end

local function QAB_EXPAND_BOARD_TO_FIT(board, requiredCapacity)
    while board.rows * board.cols < requiredCapacity and board.rows < QAB.MAX_ROW_COL do
        board.rows = board.rows + 1
    end
    while board.rows * board.cols < requiredCapacity and board.cols < QAB.MAX_ROW_COL do
        board.cols = board.cols + 1
    end
end

local function QAB_NORMALIZE_BOARD_ACTIONS(board, sourceActions)
    local entries = QAB_COLLECT_ACTION_ENTRIES(sourceActions)
    local capacity = board.rows * board.cols
    local needsReflow = false
    for _, entry in ipairs(entries) do
        if entry.index > capacity then
            needsReflow = true
            break
        end
    end

    if needsReflow == true then
        QAB_EXPAND_BOARD_TO_FIT(board, #entries)
    end

    local normalized = {}
    for position, entry in ipairs(entries) do
        local targetIndex = needsReflow == true and position or entry.index
        normalized[tostring(targetIndex)] = entry.action
    end
    return normalized
end

local function QAB_NORMALIZE_BOARD(source, scope, ownerCID)
    if type(source) ~= "table" then
        return nil, 0
    end

    local id = tostring(source.id or "")
    local sequence = tonumber(string.match(id, "^qab_(%d+)$"))
    if sequence == nil or sequence < 1 or sequence > QAB.MAX_CLASS_ID then
        return nil, 0
    end
    sequence = math.floor(sequence)

    local order = tonumber(source.order) or sequence
    if order < 1 or order > QAB.MAX_CLASS_ID then
        order = sequence
    end
    order = math.floor(order)
    local name = type(source.name) == "string" and QAB_SANITIZE_BOARD_NAME(source.name) or ""
    local legacyDefaultNameIndex = nil
    local usesDefaultName = source.usesDefaultName == true
    if source.usesDefaultName == nil then
        legacyDefaultNameIndex = QAB_LEGACY_DEFAULT_BOARD_NAME_INDEX(name, order)
        usesDefaultName = legacyDefaultNameIndex ~= nil
    end
    local defaultNameIndex = math.floor(QAB_CLAMP(
        source.defaultNameIndex or legacyDefaultNameIndex or order,
        1,
        QAB.MAX_CLASS_ID
    ))
    if name == "" or #name > QAB.MAX_BOARD_NAME_BYTES then
        name = ""
        usesDefaultName = true
    elseif usesDefaultName == true then
        name = ""
    end

    local board = {
        id = id,
        order = order,
        name = name,
        usesDefaultName = usesDefaultName,
        defaultNameIndex = defaultNameIndex,
        scope = scope,
        ownerCID = scope == "Character" and tostring(ownerCID or "0") or "0",
        rows = math.floor(QAB_CLAMP(source.rows or 1, QAB.MIN_ROW_COL, QAB.MAX_ROW_COL)),
        cols = math.floor(QAB_CLAMP(source.cols or 4, QAB.MIN_ROW_COL, QAB.MAX_ROW_COL)),
        actions = {}
    }
    board.actions = QAB_NORMALIZE_BOARD_ACTIONS(board, source.actions)
    return board, sequence
end

local function QAB_NORMALIZE_HUD(source, board)
    local fallback = QAB_DEFAULT_HUD(board)
    source = type(source) == "table" and source or {}
    return {
        xRatio = QAB_CLAMP(source.xRatio or fallback.xRatio, 0, 1),
        yRatio = QAB_CLAMP(source.yRatio or fallback.yRatio, 0, 1),
        scale = math.floor(QAB_CLAMP(source.scale or fallback.scale, QAB.MIN_SCALE, QAB.MAX_SCALE)),
        alpha = math.floor(QAB_CLAMP(source.alpha or fallback.alpha, QAB.MIN_ALPHA, QAB.MAX_ALPHA)),
        locked = source.locked == true or tonumber(source.locked) == 1,
        visible = source.visible ~= false and tonumber(source.visible) ~= 0,
        minimized = source.minimized == true or tonumber(source.minimized) == 1
    }
end

local function QAB_NORMALIZE_BOARD_LIST(source, scope, ownerCID, maximumCount, slotBudget, state)
    local normalized = {}
    local usedSlots = 0
    local sourceCount = 0
    if type(source) ~= "table" then
        return normalized, usedSlots
    end

    for _, rawBoard in ipairs(source) do
        sourceCount = sourceCount + 1
        if sourceCount > QAB.MAX_BOARD_SOURCE_ENTRIES or #normalized >= maximumCount then
            break
        end

        local board, sequence = QAB_NORMALIZE_BOARD(rawBoard, scope, ownerCID)
        local boardSlots = board ~= nil and board.rows * board.cols or 0
        if board ~= nil and state.boardIDs[board.id] ~= true and usedSlots + boardSlots <= slotBudget then
            state.boardIDs[board.id] = true
            state.maxBoardSequence = math.max(state.maxBoardSequence, sequence)
            state.hud[board.id] = QAB_NORMALIZE_HUD(state.sourceHUD[board.id], board)
            table.insert(normalized, board)
            usedSlots = usedSlots + boardSlots
        end
    end
    return normalized, usedSlots
end

local function QAB_NORMALIZE_CID(value)
    local cid = tostring(value or "")
    if cid == "" or #cid > 32 or string.match(cid, "^%d+$") == nil then
        return nil
    end
    return cid
end

local function QAB_NORMALIZE_DATA(data)
    data = type(data) == "table" and data or {}
    local sourceCharacterBoards = type(data.characterBoards) == "table" and data.characterBoards or {}
    local state = {
        boardIDs = {},
        maxBoardSequence = 0,
        sourceHUD = type(data.hud) == "table" and data.hud or {},
        hud = {}
    }
    local normalized = QAB_DEFAULT_DATA()
    normalized.enabled = data.enabled ~= false
    normalized.globalVisible = data.globalVisible ~= false

    local accountSlots = 0
    normalized.accountBoards, accountSlots = QAB_NORMALIZE_BOARD_LIST(
        data.accountBoards,
        "Account",
        "0",
        QAB.MAX_BOARD_COUNT,
        QAB.MAX_TOTAL_SLOT_COUNT,
        state
    )

    local characterBoardLimit = math.max(QAB.MAX_BOARD_COUNT - #normalized.accountBoards, 0)
    local characterSlotBudget = math.max(QAB.MAX_TOTAL_SLOT_COUNT - accountSlots, 0)
    local processedCIDs = {}
    local currentCID = QAB_NORMALIZE_CID(QAB_CURRENT_CID())
    local characterBucketCount = 0

    local function normalizeCharacterBucket(rawCID, boardList)
        local cid = QAB_NORMALIZE_CID(rawCID)
        if cid == nil or processedCIDs[cid] == true or characterBucketCount >= QAB.MAX_CHARACTER_BUCKET_COUNT then
            return
        end
        processedCIDs[cid] = true

        local boards = QAB_NORMALIZE_BOARD_LIST(
            boardList,
            "Character",
            cid,
            characterBoardLimit,
            characterSlotBudget,
            state
        )
        if #boards > 0 then
            normalized.characterBoards[cid] = boards
            characterBucketCount = characterBucketCount + 1
        end
    end

    if currentCID ~= nil then
        normalizeCharacterBucket(currentCID, sourceCharacterBoards[currentCID])
    end

    local sourceBucketCount = 0
    for rawCID, boardList in pairs(sourceCharacterBoards) do
        sourceBucketCount = sourceBucketCount + 1
        if sourceBucketCount > QAB.MAX_CHARACTER_SOURCE_ENTRIES or characterBucketCount >= QAB.MAX_CHARACTER_BUCKET_COUNT then
            break
        end
        normalizeCharacterBucket(rawCID, boardList)
    end

    normalized.hud = state.hud
    local nextBoardID = tonumber(data.nextBoardID) or 1
    if nextBoardID < 1 or nextBoardID > QAB.MAX_CLASS_ID then
        nextBoardID = 1
    end
    normalized.nextBoardID = math.max(math.floor(nextBoardID), state.maxBoardSequence + 1, 1)
    normalized.initialized = data.initialized == true
        or #normalized.accountBoards > 0
        or characterBucketCount > 0
    normalized.schemaVersion = QAB.SCHEMA_VERSION
    return normalized
end

local function QAB_SAFE_PATH_COMPONENT(value)
    value = tostring(value or "")
    value = string.gsub(value, "[/\\:*?\"<>|]", "_")
    value = string.gsub(value, "%.%.", "__")
    value = string.gsub(value, "[%.%s]+$", "_")
    if value == "" or value == "." or value == ".." or #value > 96 then
        return "0"
    end
    return value
end

local function QAB_GET_SETTINGS_PATH()
    local userID = session.loginInfo.GetUserID()
    if userID == nil or userID == "" then
        userID = "0"
    end
    return string.format("%s\\%s\\settings.json", QAB_SETTINGS_ROOT, QAB_SAFE_PATH_COMPONENT(userID))
end

local function QAB_ENSURE_SETTINGS_DIRECTORY()
    if MakeDirectory(QAB_SETTINGS_ROOT) == false then
        return false
    end
    return MakeDirectory(PATH.dirname(QAB.settingsPath)) ~= false
end

local function QAB_FILE_EXISTS(path)
    local file = io.open(path, "r")
    if file == nil then
        return false
    end
    file:close()
    return true
end

local function QAB_TRY_LOAD_JSON(path)
    local file = io.open(path, "rb")
    if file == nil then
        return nil, "NOT_FOUND"
    end
    local size = file:seek("end") or 0
    file:close()
    if size > QAB.MAX_SETTINGS_FILE_BYTES then
        return nil, "FILE_TOO_LARGE"
    end

    local ok, loaded, loadError = pcall(load_json, path)
    if ok == false or loadError ~= nil or type(loaded) ~= "table" then
        return nil, loadError or loaded or "INVALID_JSON"
    end
    return loaded, nil
end

local function QAB_ATOMIC_SAVE(path, data)
    local temporaryPath = path .. ".tmp"
    local backupPath = path .. ".bak"
    local saveOK, _, saveError = pcall(save_json, temporaryPath, data)
    if saveOK == false or saveError ~= nil then
        return false, saveError
    end

    local verified = QAB_TRY_LOAD_JSON(temporaryPath)
    if verified == nil then
        os.remove(temporaryPath)
        return false, "TEMP_VERIFY_FAILED"
    end

    local hadOriginal = QAB_FILE_EXISTS(path)
    local originalIsValid = hadOriginal == true and QAB_TRY_LOAD_JSON(path) ~= nil
    local backedUpOriginal = false
    if originalIsValid == true then
        if QAB_FILE_EXISTS(backupPath) == true then
            local removed, removeError = os.remove(backupPath)
            if removed == nil then
                os.remove(temporaryPath)
                return false, removeError
            end
        end

        local backedUp, backupError = os.rename(path, backupPath)
        if backedUp == nil then
            os.remove(temporaryPath)
            return false, backupError
        end
        backedUpOriginal = true
    elseif hadOriginal == true then
        local removed, removeError = os.remove(path)
        if removed == nil then
            os.remove(temporaryPath)
            return false, removeError
        end
    end

    local promoted, promoteError = os.rename(temporaryPath, path)
    if promoted == nil then
        if backedUpOriginal == true and QAB_FILE_EXISTS(backupPath) == true then
            os.rename(backupPath, path)
        end
        os.remove(temporaryPath)
        return false, promoteError
    end
    return true, nil
end

local function QAB_NOTIFY(messageKey)
    local frame = QAB_MANAGER_FRAME()
    if frame == nil then
        return
    end

    local message = frame:GetUserConfig(messageKey)
    if message ~= nil and message ~= "None" and message ~= "" then
        ui.SysMsg(message)
    end
end

local function QAB_NOTIFY_REASON(reason)
    if reason == "UNSUPPORTED_ACTION" or reason == "INVALID_ACTION" then
        QAB_NOTIFY("MSG_UNSUPPORTED_ACTION")
    elseif reason == "UNAVAILABLE_ACTION" then
        QAB_NOTIFY("MSG_UNAVAILABLE_ACTION")
    end
end

local function QAB_SAVE()
    if QAB.data == nil or QAB.settingsPath == nil then
        QAB.settingsReady = false
        return false
    end

    if QAB_ENSURE_SETTINGS_DIRECTORY() == false then
        QAB.settingsReady = false
        QAB_NOTIFY("MSG_SAVE_FAILED")
        return false
    end

    QAB.data = QAB_NORMALIZE_DATA(QAB.data)
    local saved, saveError = QAB_ATOMIC_SAVE(QAB.settingsPath, QAB.data)
    if saved == false then
        QAB.settingsReady = false
        QAB_NOTIFY("MSG_SAVE_FAILED")
        return false
    end
    QAB.settingsReady = true
    return true
end

local function QAB_CREATE_BOARD_RECORD(scope)
    local sequence = QAB.data.nextBoardID
    QAB.data.nextBoardID = sequence + 1
    local board = {
        id = string.format("qab_%d", sequence),
        order = sequence,
        name = "",
        usesDefaultName = true,
        defaultNameIndex = QAB_NEXT_DEFAULT_BOARD_NAME_INDEX(),
        scope = scope,
        ownerCID = scope == "Character" and QAB_CURRENT_CID() or "0",
        rows = 1,
        cols = 4,
        actions = {}
    }
    QAB.data.hud[board.id] = QAB_DEFAULT_HUD(board)
    return board
end

local function QAB_ENSURE_FIRST_BOARD()
    if QAB.data.initialized == true then
        return
    end

    local cid = QAB_CURRENT_CID()
    QAB.data.characterBoards[cid] = QAB.data.characterBoards[cid] or {}
    table.insert(QAB.data.characterBoards[cid], QAB_CREATE_BOARD_RECORD("Character"))
    QAB.data.initialized = true
end

local function QAB_LOAD()
    if QAB.loaded == true then
        if QAB.data ~= nil and QAB.settingsReady == false then
            QAB.settingsPath = QAB.settingsPath or QAB_GET_SETTINGS_PATH()
            QAB_SAVE()
        end
        return true
    end

    QAB.settingsPath = QAB_GET_SETTINGS_PATH()
    local loaded = QAB_TRY_LOAD_JSON(QAB.settingsPath)
    if loaded == nil then
        loaded = QAB_TRY_LOAD_JSON(QAB.settingsPath .. ".bak")
    end
    if loaded == nil then
        loaded = QAB_TRY_LOAD_JSON(QAB.settingsPath .. ".tmp")
    end
    QAB.data = loaded or QAB_DEFAULT_DATA()

    QAB.data = QAB_NORMALIZE_DATA(QAB.data)
    QAB.loaded = true
    QAB_ENSURE_FIRST_BOARD()
    QAB_SAVE()
    return true
end

local function QAB_GET_CHARACTER_LIST(cid, create)
    local key = tostring(cid or QAB_CURRENT_CID())
    local list = QAB.data.characterBoards[key]
    if list == nil and create == true then
        list = {}
        QAB.data.characterBoards[key] = list
    end
    return list or {}
end

local function QAB_GET_ACTIVE_BOARDS()
    local boards = {}
    for _, board in ipairs(QAB.data.accountBoards) do
        table.insert(boards, board)
    end
    for _, board in ipairs(QAB_GET_CHARACTER_LIST(QAB_CURRENT_CID(), false)) do
        table.insert(boards, board)
    end
    table.sort(boards, function(left, right)
        return (tonumber(left.order) or 0) < (tonumber(right.order) or 0)
    end)
    return boards
end

local function QAB_FIND_BOARD(boardID)
    if boardID == nil or QAB.data == nil then
        return nil, nil, nil
    end

    for index, board in ipairs(QAB.data.accountBoards) do
        if board.id == boardID then
            return board, QAB.data.accountBoards, index
        end
    end
    for _, boardList in pairs(QAB.data.characterBoards) do
        for index, board in ipairs(boardList) do
            if board.id == boardID then
                return board, boardList, index
            end
        end
    end
    return nil, nil, nil
end

local function QAB_GET_HUD(board)
    local hud = QAB.data.hud[board.id]
    if type(hud) ~= "table" then
        hud = QAB_DEFAULT_HUD(board)
        QAB.data.hud[board.id] = hud
    end
    return hud
end

local function QAB_BOARD_SLOT_COUNT(board)
    return (tonumber(board.rows) or 1) * (tonumber(board.cols) or 1)
end

local function QAB_VALIDATE_CONTEXT(accountBoards, characterBoards)
    local boardCount = #accountBoards + #characterBoards
    if boardCount > QAB.MAX_BOARD_COUNT then
        return false, "MSG_MAX_BOARD"
    end

    local slotCount = 0
    for _, board in ipairs(accountBoards) do
        slotCount = slotCount + QAB_BOARD_SLOT_COUNT(board)
    end
    for _, board in ipairs(characterBoards) do
        slotCount = slotCount + QAB_BOARD_SLOT_COUNT(board)
    end
    if slotCount > QAB.MAX_TOTAL_SLOT_COUNT then
        return false, "MSG_MAX_SLOT"
    end
    return true, nil
end

local function QAB_VALIDATE_ALL_LIMITS()
    local checkedCurrent = false
    local currentCID = QAB_CURRENT_CID()
    for cid, boardList in pairs(QAB.data.characterBoards) do
        local valid, reason = QAB_VALIDATE_CONTEXT(QAB.data.accountBoards, boardList)
        if valid == false then
            return false, reason
        end
        if tostring(cid) == currentCID then
            checkedCurrent = true
        end
    end

    if checkedCurrent == false then
        return QAB_VALIDATE_CONTEXT(QAB.data.accountBoards, {})
    end
    return true, nil
end

local function QAB_ACTION_AT(board, slotIndex)
    if board == nil or type(board.actions) ~= "table" then
        return nil
    end
    return board.actions[tostring(slotIndex + 1)] or board.actions[slotIndex + 1]
end

local function QAB_SET_ACTION(board, slotIndex, action)
    board.actions = board.actions or {}
    board.actions[tostring(slotIndex + 1)] = action
    board.actions[slotIndex + 1] = nil
end

local function QAB_REFLOW_ACTIONS_FOR_CAPACITY(board, capacity)
    local entries = QAB_COLLECT_ACTION_ENTRIES(board.actions)
    if #entries > capacity then
        return false
    end

    local needsReflow = false
    for _, entry in ipairs(entries) do
        if entry.index > capacity then
            needsReflow = true
            break
        end
    end

    local actions = {}
    for position, entry in ipairs(entries) do
        local targetIndex = needsReflow == true and position or entry.index
        actions[tostring(targetIndex)] = entry.action
    end
    board.actions = actions
    return true
end

local function QAB_CLEAR_DRAG()
    QAB.dragAction = nil
    QAB.dragSourceBoardID = nil
    QAB.dragSourceSlotIndex = nil
    QAB.dragFrameName = nil
end

local function QAB_SCENE_SIZE()
    local width = math.max(tonumber(ui.GetSceneWidth()) or 1920, 1)
    local height = math.max(tonumber(ui.GetSceneHeight()) or 1080, 1)
    return width, height
end

local function QAB_FRAME_NAME(boardID)
    return "quickactionboard_board_" .. tostring(boardID)
end

local function QAB_DESTROY_REMOVED_BOARD_FRAMES(activeFrameNames)
    for _, frameName in ipairs(QAB.frameNames) do
        if activeFrameNames[frameName] ~= true and ui.GetFrame(frameName) ~= nil then
            ui.DestroyFrame(frameName)
        end
    end
    QAB.frameNames = {}
end

local function QAB_HIDE_BOARD_FRAMES()
    for _, frameName in ipairs(QAB.frameNames) do
        local frame = ui.GetFrame(frameName)
        if frame ~= nil then
            frame:ShowWindow(0)
        end
    end
end

local function QAB_CONFIGURE_BOARD_SLOT(board, hud, slot, slotIndex)
    slot:SetUserValue("QAB_BOARD_ID", board.id)
    slot:SetUserValue("QAB_SLOT_INDEX", slotIndex)
    slot:SetSkinName("quickslot")
    slot:SetEventScript(ui.RBUTTONUP, "QUICKACTIONBOARD_BOARD_RBUTTON")
    slot:SetEventScriptArgString(ui.RBUTTONUP, board.id)
    slot:SetEventScriptArgNumber(ui.RBUTTONUP, slotIndex)
    slot:EnableDrag(hud.locked and 0 or 1)
    slot:EnableDrop(hud.locked and 0 or 1)
    slot:EnablePop(hud.locked and 0 or 1)

    local action = QAB_ACTION_AT(board, slotIndex)
    if action ~= nil then
        QUICKACTIONBOARD_ACTION_RENDER(action, slot)
    else
        slot:ClearIcon()
        slot:ClearText()
    end
end

local function QAB_POSITION_BOARD_FRAME(frame, board, hud)
    local sceneWidth, sceneHeight = QAB_SCENE_SIZE()
    local x = math.floor(QAB_CLAMP(hud.xRatio, 0, 1) * sceneWidth)
    local y = math.floor(QAB_CLAMP(hud.yRatio, 0, 1) * sceneHeight)
    x = math.max(0, math.min(x, math.max(sceneWidth - frame:GetWidth(), 0)))
    y = math.max(0, math.min(y, math.max(sceneHeight - frame:GetHeight(), 0)))
    frame:SetOffset(x, y)
end

local function QAB_CREATE_BOARD_FRAME(board, previewScale, previewAlpha)
	local hud = QAB_GET_HUD(board)
	local frameName = QAB_FRAME_NAME(board.id)
    local frame = ui.GetFrame(frameName)
    if frame == nil then
        frame = ui.CreateNewFrame("quickactionboard_board", frameName)
    end
    if frame == nil then
        return
    end

	local isPreview = previewScale ~= nil or previewAlpha ~= nil
	if isPreview == false then
		table.insert(QAB.frameNames, frameName)
	end
	frame:SetUserValue("QAB_BOARD_ID", board.id)
	frame:SetEventScript(ui.LBUTTONUP, "QUICKACTIONBOARD_BOARD_END_MOVE")
	frame:EnableMove(hud.locked and 0 or 1)
	local renderScale = math.floor(QAB_CLAMP(previewScale or hud.scale, QAB.MIN_SCALE, QAB.MAX_SCALE))
	local renderAlpha = math.floor(QAB_CLAMP(previewAlpha or hud.alpha, QAB.MIN_ALPHA, QAB.MAX_ALPHA))
	frame:SetAlpha(renderAlpha)

	local slotSize = math.floor(48 * renderScale / 100)
    local slotWidth = board.cols * slotSize
    local headerWidth = slotWidth
    local frameWidth = slotWidth + 16
    local frameHeight = hud.minimized and 33 or board.rows * slotSize + 33
    local compactHeader = headerWidth < 144
    frame:Resize(frameWidth, frameHeight)
    frame:SetUserValue("QAB_COMPACT_HEADER", compactHeader and 1 or 0)

    local boardHeader = GET_CHILD_RECURSIVELY(frame, "boardHeader", "ui::CGroupBox")
    boardHeader:Resize(headerWidth, 24)
    local title = GET_CHILD_RECURSIVELY(frame, "boardTitle", "ui::CRichText")
    title:Resize(math.max(headerWidth - 80, 40), 22)
    local displayName = QAB_BOARD_DISPLAY_NAME(board)
    title:SetTextByKey("board", displayName)
    title:ShowWindow(compactHeader and 0 or 1)
    local scopeMessageKey = board.scope == "Account" and "QuickActionBoardScopeAccount" or "QuickActionBoardScopeCharacter"
    local manageButton = GET_CHILD_RECURSIVELY(frame, "manageButton", "ui::CButton")
    local minimizeButton = GET_CHILD_RECURSIVELY(frame, "minimizeButton", "ui::CButton")
    local restoreButton = GET_CHILD_RECURSIVELY(frame, "restoreButton", "ui::CButton")
    local closeButton = GET_CHILD_RECURSIVELY(frame, "closeButton", "ui::CButton")
    if compactHeader then
        manageButton:SetGravity(ui.CENTER_HORZ, ui.TOP)
        manageButton:SetMargin(0, 1, 0, 0)
        manageButton:SetTextTooltip(ScpArgMsg("QuickActionBoardCompactTooltip{BOARD}{SCOPE}", "BOARD", displayName, "SCOPE", ClMsg(scopeMessageKey)))
        minimizeButton:ShowWindow(0)
        restoreButton:ShowWindow(0)
        closeButton:ShowWindow(0)
    else
        manageButton:SetGravity(ui.RIGHT, ui.TOP)
        manageButton:SetMargin(0, 1, 52, 0)
        manageButton:SetTextTooltip(ScpArgMsg("QuickActionBoardManageTooltip{BOARD}{SCOPE}", "BOARD", displayName, "SCOPE", ClMsg(scopeMessageKey)))
        minimizeButton:ShowWindow(hud.minimized and 0 or 1)
        restoreButton:ShowWindow(hud.minimized and 1 or 0)
        closeButton:ShowWindow(1)
    end

    local slotset = GET_CHILD_RECURSIVELY(frame, "boardSlots", "ui::CSlotSet")
    slotset:RemoveAllChild()
    slotset:SetSlotSize(slotSize, slotSize)
    slotset:SetColRow(board.cols, board.rows)
    slotset:Resize(slotWidth, board.rows * slotSize)
    slotset:EnableDrag(hud.locked and 0 or 1)
    slotset:EnableDrop(hud.locked and 0 or 1)
    slotset:EnablePop(hud.locked and 0 or 1)
    slotset:ShowWindow(hud.minimized and 0 or 1)
    slotset:CreateSlots()
    for index = 0, QAB_BOARD_SLOT_COUNT(board) - 1 do
        QAB_CONFIGURE_BOARD_SLOT(board, hud, slotset:GetSlotByIndex(index), index)
    end

    local timer = GET_CHILD_RECURSIVELY(frame, "boardTimer", "ui::CAddOnTimer")
    timer:SetUpdateScript("QUICKACTIONBOARD_BOARD_UPDATE")
    timer:Start(0.3)

    QAB_POSITION_BOARD_FRAME(frame, board, hud)
    frame:ShowWindow(QAB.data.enabled and QAB.data.globalVisible and hud.visible and 1 or 0)
end

function QUICKACTIONBOARD_REBUILD_BOARDS()
    if QAB_LOAD() == false then
        return
    end

    if QAB.data.enabled == false then
        QAB_HIDE_BOARD_FRAMES()
        QUICKACTIONBOARD_SYNC_GLOBAL_BUTTON()
        return
    end

    QAB.activeBoards = QAB_GET_ACTIVE_BOARDS()
    local activeFrameNames = {}
    for _, board in ipairs(QAB.activeBoards) do
        activeFrameNames[QAB_FRAME_NAME(board.id)] = true
    end
    QAB_DESTROY_REMOVED_BOARD_FRAMES(activeFrameNames)
    for _, board in ipairs(QAB.activeBoards) do
        QAB_CREATE_BOARD_FRAME(board)
    end

    QUICKACTIONBOARD_MANAGER_REFRESH()
    QUICKACTIONBOARD_SYNC_GLOBAL_BUTTON()
end

local function QAB_SAVE_AND_REBUILD()
    QAB_SAVE()
    QUICKACTIONBOARD_REBUILD_BOARDS()
end

local QAB_SPECIAL_ITEM_EFFECT_NAMES = {
    JUNGTAN = true,
    JUNGTANDEF = true,
    DISPELDEBUFF = true
}

local function QAB_UPDATE_SPECIAL_ITEM_EFFECT_STATE(argStr, itemType)
    local effectName, state = string.match(tostring(argStr or ""), "^([%u]+)_([%u]+)$")
    if QAB_SPECIAL_ITEM_EFFECT_NAMES[effectName] ~= true then
        return
    end

    if state == "ON" and (tonumber(itemType) or 0) > 0 then
        QAB.specialItemEffects[effectName] = tonumber(itemType)
    elseif state == "OFF" then
        QAB.specialItemEffects[effectName] = nil
    end
end

local function QAB_PLAY_SPECIAL_ITEM_EFFECTS(board, slotset)
    if movie == nil or movie.PlayUIEffect == nil then
        return
    end

    local activeItemTypes = {}
    for _, itemType in pairs(QAB.specialItemEffects) do
        activeItemTypes[tonumber(itemType)] = true
    end

    for index = 0, QAB_BOARD_SLOT_COUNT(board) - 1 do
        local action = QAB_ACTION_AT(board, index)
        if action ~= nil and action.kind == "Item" and activeItemTypes[tonumber(action.classID)] == true then
            local slot = slotset:GetSlotByIndex(index)
            if slot ~= nil then
                local x, y = GET_SCREEN_XY(slot)
                movie.PlayUIEffect("I_sys_item_slot", x, y, 0.8)
            end
        end
    end
end

function QUICKACTIONBOARD_BOARD_UPDATE(frame, timer, argStr, argNum, elapsedTime)
    if frame == nil or frame:IsVisible() == 0 then
        return 1
    end

    local board = QAB_FIND_BOARD(frame:GetUserValue("QAB_BOARD_ID"))
    if board == nil then
        return 1
    end
    if QAB_GET_HUD(board).minimized == true then
        return 1
    end

    local slotset = GET_CHILD_RECURSIVELY(frame, "boardSlots", "ui::CSlotSet")
    for index = 0, QAB_BOARD_SLOT_COUNT(board) - 1 do
        local action = QAB_ACTION_AT(board, index)
        if action ~= nil then
            QUICKACTIONBOARD_ACTION_REFRESH(action, slotset:GetSlotByIndex(index), "TIMER")
        end
    end

    if next(QAB.specialItemEffects) ~= nil then
        local effectElapsed = (QAB.specialEffectElapsed[board.id] or 0) + (tonumber(elapsedTime) or 0)
        if effectElapsed >= 1 then
            effectElapsed = 0
            QAB_PLAY_SPECIAL_ITEM_EFFECTS(board, slotset)
        end
        QAB.specialEffectElapsed[board.id] = effectElapsed
    else
        QAB.specialEffectElapsed[board.id] = 0
    end
    return 1
end

function QUICKACTIONBOARD_BOARD_END_MOVE(frame)
    local board = QAB_FIND_BOARD(frame:GetUserValue("QAB_BOARD_ID"))
    if board == nil then
        return
    end

    local hud = QAB_GET_HUD(board)
    if hud.locked == true then
        return
    end

    local sceneWidth, sceneHeight = QAB_SCENE_SIZE()
    hud.xRatio = QAB_CLAMP(frame:GetX() / sceneWidth, 0, 1)
    hud.yRatio = QAB_CLAMP(frame:GetY() / sceneHeight, 0, 1)
    QAB_SAVE()
end

local function QAB_BOARD_FROM_CONTROL(frame, ctrl)
    local source = ctrl or frame
    if source == nil then
        return nil, nil
    end
    local topFrame = source:GetTopParentFrame()
    if topFrame == nil then
        return nil, nil
    end
    return QAB_FIND_BOARD(topFrame:GetUserValue("QAB_BOARD_ID")), topFrame
end

function QUICKACTIONBOARD_BOARD_TOGGLE_MINIMIZED(frame, ctrl)
    local board = QAB_BOARD_FROM_CONTROL(frame, ctrl)
    if board == nil then
        return
    end
    local hud = QAB_GET_HUD(board)
    hud.minimized = not hud.minimized
    QAB_SAVE_AND_REBUILD()
end

function QUICKACTIONBOARD_BOARD_CLOSE(frame, ctrl)
    local board = QAB_BOARD_FROM_CONTROL(frame, ctrl)
    if board == nil then
        return
    end
    local hud = QAB_GET_HUD(board)
    hud.visible = false

    local manager = QAB_MANAGER_FRAME()
    if manager ~= nil and manager:IsVisible() == 1 and QAB.selectedBoardID == board.id and QAB.managerDirty then
        local visibleCheck = GET_CHILD_RECURSIVELY(manager, "visibleCheck", "ui::CCheckBox")
        if visibleCheck ~= nil then
            visibleCheck:SetCheck(0)
        end
    end
    QAB_SAVE_AND_REBUILD()
end

function QUICKACTIONBOARD_BOARD_POP(parent, slot)
    local frame = slot:GetTopParentFrame()
    local board = QAB_FIND_BOARD(frame:GetUserValue("QAB_BOARD_ID"))
    if board == nil then
        QAB_CLEAR_DRAG()
        return
    end

    local hud = QAB_GET_HUD(board)
    local slotIndex = slot:GetSlotIndex()
    local action = QAB_ACTION_AT(board, slotIndex)
    if hud.locked == true or action == nil then
        QAB_CLEAR_DRAG()
        return
    end

    QAB.dragAction = QAB_DEEP_COPY(action)
    QAB.dragSourceBoardID = board.id
    QAB.dragSourceSlotIndex = slotIndex
    QAB.dragFrameName = frame:GetName()

    QAB_SET_ACTION(board, slotIndex, nil)
    slot:ClearIcon()
    slot:ClearText()
    if QAB_SAVE() == false then
        local currentBoard = QAB_FIND_BOARD(board.id)
        if currentBoard ~= nil then
            QAB_SET_ACTION(currentBoard, slotIndex, action)
        end
        QUICKACTIONBOARD_ACTION_RENDER(action, slot)
        QAB_CLEAR_DRAG()
    end
end

function QUICKACTIONBOARD_BOARD_DROP(parent, slot)
    local targetFrame = slot:GetTopParentFrame()
    local targetBoard = QAB_FIND_BOARD(targetFrame:GetUserValue("QAB_BOARD_ID"))
    if targetBoard == nil or QAB_GET_HUD(targetBoard).locked == true then
        QAB_CLEAR_DRAG()
        return
    end

    local liftIcon = ui.GetLiftIcon()
    local originName = nil
    if liftIcon ~= nil and liftIcon:GetTopParentFrame() ~= nil then
        originName = liftIcon:GetTopParentFrame():GetName()
    end

    local action = nil
    local reason = nil
    local useStoredDrag = QAB.dragAction ~= nil and originName == QAB.dragFrameName
    if useStoredDrag then
        action = QAB_DEEP_COPY(QAB.dragAction)
    elseif liftIcon ~= nil then
        QAB_CLEAR_DRAG()
        action, reason = QUICKACTIONBOARD_ACTION_FROM_LIFT(liftIcon, liftIcon:GetInfo())
    end

    if action == nil then
        QAB_NOTIFY_REASON(reason or "UNSUPPORTED_ACTION")
        QAB_CLEAR_DRAG()
        return
    end

    local targetIndex = slot:GetSlotIndex()
    if useStoredDrag and QAB.dragSourceBoardID ~= nil then
        local sourceBoard = QAB_FIND_BOARD(QAB.dragSourceBoardID)
        if sourceBoard ~= nil and (sourceBoard.id ~= targetBoard.id or QAB.dragSourceSlotIndex ~= targetIndex) then
            QAB_SET_ACTION(sourceBoard, QAB.dragSourceSlotIndex, nil)
        end
    end
    QAB_SET_ACTION(targetBoard, targetIndex, action)
    QAB_CLEAR_DRAG()
    QAB_SAVE_AND_REBUILD()
end

function QUICKACTIONBOARD_BOARD_RBUTTON(parent, slot, boardID, slotIndex)
    local board = QAB_FIND_BOARD(boardID)
    if board == nil then
        return
    end

    local hud = QAB_GET_HUD(board)
    local action = QAB_ACTION_AT(board, tonumber(slotIndex) or slot:GetSlotIndex())
    if action == nil then
        return
    end

    if keyboard.IsKeyPressed("LALT") == 1 and hud.locked == false then
        QAB_SET_ACTION(board, tonumber(slotIndex) or slot:GetSlotIndex(), nil)
        QAB_SAVE_AND_REBUILD()
        return
    end

    local success, reason = QUICKACTIONBOARD_ACTION_EXECUTE(action, slot, "Mouse")
    if success == false then
        QAB_NOTIFY_REASON(reason)
    end
end

local function QAB_VISIBLE_ACTIVE_BOARDS()
    local visible = {}
    if QAB.data.globalVisible == false then
        return visible
    end
    for _, board in ipairs(QAB_GET_ACTIVE_BOARDS()) do
        local hud = QAB_GET_HUD(board)
        if hud.visible == true and hud.minimized ~= true then
            table.insert(visible, board)
        end
    end
    return visible
end

local function QAB_HAS_ENABLED_BOARD(boards)
    for _, board in ipairs(boards or {}) do
        if QAB_GET_HUD(board).visible == true then
            return true
        end
    end
    return false
end

function QUICKACTIONBOARD_SYNC_GLOBAL_BUTTON()
    local quickslotFrame = ui.GetFrame("quickslotnexpbar")
    if quickslotFrame == nil then
        return
    end
    local button = GET_CHILD_RECURSIVELY(quickslotFrame, "quickactionboardToggle")
    if button == nil then
        return
    end
    local isEnabled = QAB.data ~= nil and QAB.data.enabled == true
    button:ShowWindow(isEnabled and 1 or 0)
    if isEnabled == false then
        return
    end
    local isVisible = QAB.data ~= nil
        and QAB.data.globalVisible == true
        and QAB_HAS_ENABLED_BOARD(QAB_GET_ACTIVE_BOARDS())
    button:SetImage(isVisible and "chat_fold_btn" or "chat_expand_btn")
    button:SetColorTone("FFFFFFFF")
end

function QUICKACTIONBOARD_IS_ENABLED()
    if QAB_LOAD() == false or QAB.data == nil then
        return false
    end
    return QAB.data.enabled == true
end

function QUICKACTIONBOARD_SET_ENABLED(enabled)
    if QAB_LOAD() == false or QAB.data == nil then
        return false
    end

    local nextEnabled = enabled == true or tonumber(enabled) == 1
    local previousEnabled = QAB.data.enabled
    if previousEnabled == nextEnabled then
        QUICKACTIONBOARD_SYNC_GLOBAL_BUTTON()
        return true
    end

    QAB.data.enabled = nextEnabled
    if QAB_SAVE() == false then
        QAB.data.enabled = previousEnabled
        QUICKACTIONBOARD_SYNC_GLOBAL_BUTTON()
        return false
    end

    if nextEnabled then
        QUICKACTIONBOARD_REBUILD_BOARDS()
    else
        if QAB.joystickFocus == true then
            QUICKACTIONBOARD_JOYSTICK_EXIT()
        end
        QAB_HIDE_BOARD_FRAMES()
        ui.CloseFrame("quickactionboard")
        QUICKACTIONBOARD_SYNC_GLOBAL_BUTTON()
    end
    return true
end

function QUICKACTIONBOARD_TOGGLE_GLOBAL()
    if QAB_LOAD() == false or QAB.data == nil then
        return
    end
    if QAB.data.enabled == false then
        return
    end
    local activeBoards = QAB_GET_ACTIVE_BOARDS()
    local previousVisible = QAB.data.globalVisible
    local previousBoardVisibility = {}
    local hasEnabledBoard = QAB_HAS_ENABLED_BOARD(activeBoards)
    local nextVisible = not (QAB.data.globalVisible == true and hasEnabledBoard)
    local restoredBoards = false
    for _, board in ipairs(activeBoards) do
        previousBoardVisibility[board.id] = QAB_GET_HUD(board).visible
    end

    QAB.data.globalVisible = nextVisible
    if nextVisible and hasEnabledBoard == false then
        for _, board in ipairs(activeBoards) do
            QAB_GET_HUD(board).visible = true
        end
        restoredBoards = #activeBoards > 0
    end
    if QAB_SAVE() == false then
        QAB.data.globalVisible = previousVisible
        for _, board in ipairs(activeBoards) do
            QAB_GET_HUD(board).visible = previousBoardVisibility[board.id]
        end
        QUICKACTIONBOARD_SYNC_GLOBAL_BUTTON()
        return
    end
    activeBoards = QAB_GET_ACTIVE_BOARDS()
    if QAB.data.globalVisible == false and QAB.joystickFocus == true then
        QUICKACTIONBOARD_JOYSTICK_EXIT()
    end
    local missingFrame = false
    for _, board in ipairs(activeBoards) do
        local frame = ui.GetFrame(QAB_FRAME_NAME(board.id))
        if frame ~= nil then
            frame:ShowWindow(QAB.data.globalVisible and QAB_GET_HUD(board).visible and 1 or 0)
        else
            missingFrame = true
        end
    end
    if missingFrame or restoredBoards then
        QUICKACTIONBOARD_REBUILD_BOARDS()
        return
    end
    QUICKACTIONBOARD_SYNC_GLOBAL_BUTTON()
end

local function QAB_MANAGER_ACTIVE_BOARD(index)
    QAB.activeBoards = QAB_GET_ACTIVE_BOARDS()
    return QAB.activeBoards[index]
end

local function QAB_MANAGER_SELECTED_BOARD()
    if QAB.selectedBoardID == nil then
        return nil
    end
	return QAB_FIND_BOARD(QAB.selectedBoardID)
end

local function QAB_MANAGER_RENDER_LIVE_PREVIEW(frame)
	local board = QAB_MANAGER_SELECTED_BOARD()
	if board == nil then
		return
	end
	local hud = QAB_GET_HUD(board)
	local scaleEdit = GET_CHILD_RECURSIVELY(frame, "scaleEdit", "ui::CEditControl")
	local alphaEdit = GET_CHILD_RECURSIVELY(frame, "alphaEdit", "ui::CEditControl")
	if scaleEdit == nil or alphaEdit == nil then
		return
	end
	local scale = tonumber(scaleEdit:GetText()) or hud.scale
	local alpha = tonumber(alphaEdit:GetText()) or hud.alpha
	QAB_CREATE_BOARD_FRAME(board, scale, alpha)
end

local function QAB_MANAGER_RESTORE_LIVE_PREVIEW()
	local board = QAB_MANAGER_SELECTED_BOARD()
	if board == nil then
		return
	end
	local hud = QAB_GET_HUD(board)
	QAB_CREATE_BOARD_FRAME(board, hud.scale, hud.alpha)
end

local function QAB_MANAGER_RENDER_PREVIEW(frame)
	local preview = GET_CHILD_RECURSIVELY(frame, "previewSlots", "ui::CSlotSet")
	local rowEdit = GET_CHILD_RECURSIVELY(frame, "rowEdit", "ui::CEditControl")
	local colEdit = GET_CHILD_RECURSIVELY(frame, "colEdit", "ui::CEditControl")
	local alphaEdit = GET_CHILD_RECURSIVELY(frame, "alphaEdit", "ui::CEditControl")
	if preview == nil or rowEdit == nil or colEdit == nil or alphaEdit == nil then
		return
	end

    local rows = math.floor(QAB_CLAMP(rowEdit:GetText(), QAB.MIN_ROW_COL, QAB.MAX_ROW_COL))
    local cols = math.floor(QAB_CLAMP(colEdit:GetText(), QAB.MIN_ROW_COL, QAB.MAX_ROW_COL))
    local slotSize = math.floor(math.min(24, 104 / cols, 56 / rows))
    slotSize = math.max(slotSize, 8)
    local width = cols * slotSize
    local height = rows * slotSize

    preview:RemoveAllChild()
    preview:SetSlotSize(slotSize, slotSize)
    preview:SetSpc(0, 0)
    preview:SetColRow(cols, rows)
    preview:Resize(width, height)
	preview:SetOffset(13 + math.floor((104 - width) / 2), 25 + math.floor((56 - height) / 2))
	preview:CreateSlots()
	preview:SetAlpha(math.floor(QAB_CLAMP(alphaEdit:GetText(), QAB.MIN_ALPHA, QAB.MAX_ALPHA)))
end

local function QAB_MANAGER_SET_DIRTY(frame, dirty)
    QAB.managerDirty = dirty == true
    local applyButton = GET_CHILD_RECURSIVELY(frame, "applyBoard", "ui::CButton")
    if applyButton == nil then
        return
    end
    local canApply = QAB.managerDirty and QAB_MANAGER_SELECTED_BOARD() ~= nil
    applyButton:SetEnable(canApply and 1 or 0)
    applyButton:SetSkinName(canApply and "test_pvp_btn" or "test_normal_button")
end

local function QAB_MANAGER_UPDATE_VIEW(frame)
    local settingsVisible = QAB.managerTab ~= "Actions"
    local settingBox = GET_CHILD_RECURSIVELY(frame, "settingBox", "ui::CGroupBox")
    local paletteBox = GET_CHILD_RECURSIVELY(frame, "paletteBox", "ui::CGroupBox")
    local settingsTab = GET_CHILD_RECURSIVELY(frame, "settingsTab", "ui::CButton")
    local actionsTab = GET_CHILD_RECURSIVELY(frame, "actionsTab", "ui::CButton")
    local advancedBox = GET_CHILD_RECURSIVELY(frame, "advancedBox", "ui::CGroupBox")
    local advancedToggle = GET_CHILD_RECURSIVELY(frame, "advancedToggle", "ui::CButton")

    settingBox:ShowWindow(settingsVisible and 1 or 0)
    paletteBox:ShowWindow(settingsVisible and 0 or 1)
    settingsTab:SetSkinName(settingsVisible and "test_pvp_btn" or "test_normal_button")
    actionsTab:SetSkinName(settingsVisible and "test_normal_button" or "test_pvp_btn")
    advancedBox:ShowWindow(settingsVisible and QAB.managerAdvanced and 1 or 0)
    advancedToggle:SetTextByKey("text", frame:GetUserConfig(QAB.managerAdvanced and "ADVANCED_CLOSE" or "ADVANCED_OPEN"))
end

function QUICKACTIONBOARD_MANAGER_TAB(frame, ctrl, argStr)
    QAB.managerTab = argStr == "Actions" and "Actions" or "Settings"
    QAB_MANAGER_UPDATE_VIEW(QAB_MANAGER_FRAME())
end

function QUICKACTIONBOARD_MANAGER_TOGGLE_ADVANCED()
    QAB.managerAdvanced = not QAB.managerAdvanced
    QAB_MANAGER_UPDATE_VIEW(QAB_MANAGER_FRAME())
end

function QUICKACTIONBOARD_MANAGER_FIELD_CHANGED()
    local frame = QAB_MANAGER_FRAME()
    if frame == nil then
        return
	end
	QAB_MANAGER_RENDER_PREVIEW(frame)
	QAB_MANAGER_RENDER_LIVE_PREVIEW(frame)
	QAB_MANAGER_SET_DIRTY(frame, true)
end

function QUICKACTIONBOARD_MANAGER_STEP(frame, ctrl, argStr, argNum)
    local manager = QAB_MANAGER_FRAME()
    local edit = GET_CHILD_RECURSIVELY(manager, argStr, "ui::CEditControl")
    if edit == nil then
        return
    end
	local minimum = QAB.MIN_ROW_COL
	local maximum = QAB.MAX_ROW_COL
	if argStr == "scaleEdit" then
		minimum = QAB.MIN_SCALE
		maximum = QAB.MAX_SCALE
	elseif argStr == "alphaEdit" then
		minimum = QAB.MIN_ALPHA
		maximum = QAB.MAX_ALPHA
	end
	local value = tonumber(edit:GetText()) or minimum
	value = math.floor(QAB_CLAMP(value + (tonumber(argNum) or 0), minimum, maximum))
	edit:SetTextByKey("value", tostring(value))
	QUICKACTIONBOARD_MANAGER_FIELD_CHANGED()
end

function QUICKACTIONBOARD_MANAGER_CLOSE()
    local frame = QAB_MANAGER_FRAME()
    if frame == nil then
        return
    end
    if QAB.managerDirty then
        ui.MsgBox(frame:GetUserConfig("MSG_DISCARD_CHANGES"), "QUICKACTIONBOARD_MANAGER_CLOSE_DISCARD_YES", "None")
        return
    end
    ui.CloseFrame("quickactionboard")
end

function QUICKACTIONBOARD_MANAGER_CLOSE_DISCARD_YES()
	QAB_MANAGER_RESTORE_LIVE_PREVIEW()
	QAB.managerDirty = false
	ui.CloseFrame("quickactionboard")
end

local function QAB_MANAGER_SET_FIELDS(frame, board)
    local selectedTitle = GET_CHILD_RECURSIVELY(frame, "selectedBoardTitle", "ui::CRichText")
    local nameEdit = GET_CHILD_RECURSIVELY(frame, "nameEdit", "ui::CEditControl")
    local scopeDrop = GET_CHILD_RECURSIVELY(frame, "scopeDrop", "ui::CDropList")
    local rowEdit = GET_CHILD_RECURSIVELY(frame, "rowEdit", "ui::CEditControl")
    local colEdit = GET_CHILD_RECURSIVELY(frame, "colEdit", "ui::CEditControl")
    local scaleEdit = GET_CHILD_RECURSIVELY(frame, "scaleEdit", "ui::CEditControl")
    local alphaEdit = GET_CHILD_RECURSIVELY(frame, "alphaEdit", "ui::CEditControl")
    local lockedCheck = GET_CHILD_RECURSIVELY(frame, "lockedCheck", "ui::CCheckBox")
    local visibleCheck = GET_CHILD_RECURSIVELY(frame, "visibleCheck", "ui::CCheckBox")
    local settingBox = GET_CHILD_RECURSIVELY(frame, "settingBox", "ui::CGroupBox")
    local paletteBox = GET_CHILD_RECURSIVELY(frame, "paletteBox", "ui::CGroupBox")

    if board == nil then
        selectedTitle:SetTextByKey("board", "-")
        nameEdit:SetTextByKey("value", "")
        rowEdit:SetTextByKey("value", "")
        colEdit:SetTextByKey("value", "")
        scaleEdit:SetTextByKey("value", "")
        alphaEdit:SetTextByKey("value", "")
        lockedCheck:SetCheck(0)
        visibleCheck:SetCheck(0)
        lockedCheck:SetEnable(0)
        visibleCheck:SetEnable(0)
        settingBox:SetEnable(0)
        paletteBox:SetEnable(0)
        QAB_MANAGER_RENDER_PREVIEW(frame)
        QAB_MANAGER_SET_DIRTY(frame, false)
        return
    end

    local hud = QAB_GET_HUD(board)
    local displayName = QAB_BOARD_DISPLAY_NAME(board)
    selectedTitle:SetTextByKey("board", displayName)
    nameEdit:SetTextByKey("value", displayName)
    scopeDrop:SelectItem(board.scope == "Account" and 1 or 0)
    rowEdit:SetTextByKey("value", tostring(board.rows))
    colEdit:SetTextByKey("value", tostring(board.cols))
    scaleEdit:SetTextByKey("value", tostring(hud.scale))
    alphaEdit:SetTextByKey("value", tostring(hud.alpha))
    lockedCheck:SetCheck(hud.locked and 1 or 0)
    visibleCheck:SetCheck(hud.visible and 1 or 0)
    lockedCheck:SetEnable(1)
    visibleCheck:SetEnable(1)
    settingBox:SetEnable(1)
    paletteBox:SetEnable(1)
    QAB_MANAGER_RENDER_PREVIEW(frame)
    QAB_MANAGER_SET_DIRTY(frame, false)
end

function QUICKACTIONBOARD_MANAGER_REFRESH()
    local frame = QAB_MANAGER_FRAME()
    if frame == nil or QAB.loaded == false then
        return
    end

    if GET_CHILD_RECURSIVELY(frame, "boardButton1", "ui::CButton") == nil then
        return
    end

    QAB.activeBoards = QAB_GET_ACTIVE_BOARDS()
    if QAB.selectedBoardID == nil and #QAB.activeBoards > 0 then
        QAB.selectedBoardID = QAB.activeBoards[1].id
    elseif QAB.selectedBoardID ~= nil and QAB_FIND_BOARD(QAB.selectedBoardID) == nil then
        QAB.selectedBoardID = #QAB.activeBoards > 0 and QAB.activeBoards[1].id or nil
    end

    for index = 1, QAB.MAX_BOARD_COUNT do
        local button = GET_CHILD_RECURSIVELY(frame, "boardButton" .. index, "ui::CButton")
        local board = QAB.activeBoards[index]
        if board ~= nil then
            local selected = board.id == QAB.selectedBoardID
            button:SetTextByKey("board", QAB_BOARD_DISPLAY_NAME(board))
            button:SetSkinName(selected and "test_pvp_btn" or "test_normal_button")
            button:SetColorTone(selected and "FFFFF4B0" or "FFFFFFFF")
            button:ShowWindow(1)
        else
            button:ShowWindow(0)
        end
    end

    local emptyText = GET_CHILD_RECURSIVELY(frame, "emptyBoardText", "ui::CRichText")
    emptyText:ShowWindow(#QAB.activeBoards == 0 and 1 or 0)
    local selectedBoard = QAB_MANAGER_SELECTED_BOARD()
    local deleteButton = GET_CHILD_RECURSIVELY(frame, "deleteBoard", "ui::CButton")
    deleteButton:SetEnable(selectedBoard ~= nil and 1 or 0)
    if QAB.managerDirty then
        QAB_MANAGER_SET_DIRTY(frame, true)
    else
        QAB_MANAGER_SET_FIELDS(frame, selectedBoard)
    end
    QAB_MANAGER_UPDATE_VIEW(frame)
end

local function QAB_MANAGER_SELECT_INDEX(index)
    local board = QAB_MANAGER_ACTIVE_BOARD(index)
    if board == nil then
        return
    end
    QAB.selectedBoardID = board.id
    QUICKACTIONBOARD_MANAGER_REFRESH()
end

function QUICKACTIONBOARD_MANAGER_SELECT(frame, ctrl, argStr, argNum)
    local index = tonumber(argNum) or 1
    local board = QAB_MANAGER_ACTIVE_BOARD(index)
    if board == nil or board.id == QAB.selectedBoardID then
        return
    end
    if QAB.managerDirty then
        QAB.pendingBoardIndex = index
        ui.MsgBox(QAB_MANAGER_FRAME():GetUserConfig("MSG_DISCARD_CHANGES"), "QUICKACTIONBOARD_MANAGER_SELECT_DISCARD_YES", "None")
        return
    end
    QAB_MANAGER_SELECT_INDEX(index)
end

function QUICKACTIONBOARD_MANAGER_SELECT_DISCARD_YES()
	local index = QAB.pendingBoardIndex
	QAB.pendingBoardIndex = nil
	QAB_MANAGER_RESTORE_LIVE_PREVIEW()
	QAB.managerDirty = false
    if index ~= nil then
        QAB_MANAGER_SELECT_INDEX(index)
    end
end

local function QAB_MANAGER_ADD_NOW()
    QAB_LOAD()
    local backup = QAB_DEEP_COPY(QAB.data)
    local list = QAB_GET_CHARACTER_LIST(QAB_CURRENT_CID(), true)
    local board = QAB_CREATE_BOARD_RECORD("Character")
    table.insert(list, board)
    local valid, reason = QAB_VALIDATE_ALL_LIMITS()
    if valid == false then
        QAB.data = backup
        QAB_NOTIFY(reason)
        return
    end

    QAB.selectedBoardID = board.id
    QAB_SAVE_AND_REBUILD()
end

function QUICKACTIONBOARD_MANAGER_ADD()
    if QAB.managerDirty then
        QAB.pendingAddBoard = true
        ui.MsgBox(QAB_MANAGER_FRAME():GetUserConfig("MSG_DISCARD_CHANGES"), "QUICKACTIONBOARD_MANAGER_ADD_DISCARD_YES", "None")
        return
    end
    QAB_MANAGER_ADD_NOW()
end

function QUICKACTIONBOARD_MANAGER_ADD_DISCARD_YES()
	QAB.pendingAddBoard = false
	QAB_MANAGER_RESTORE_LIVE_PREVIEW()
	QAB.managerDirty = false
    QAB_MANAGER_ADD_NOW()
end

function QUICKACTIONBOARD_MANAGER_DELETE()
    if QAB_MANAGER_SELECTED_BOARD() == nil then
        return
    end
    local frame = QAB_MANAGER_FRAME()
    ui.MsgBox(frame:GetUserConfig("MSG_DELETE_CONFIRM"), "QUICKACTIONBOARD_MANAGER_DELETE_YES", "None")
end

function QUICKACTIONBOARD_MANAGER_DELETE_YES()
    local board, list, index = QAB_FIND_BOARD(QAB.selectedBoardID)
    if board == nil then
        return
    end
    table.remove(list, index)
    QAB.data.hud[board.id] = nil
    QAB.selectedBoardID = nil
    QAB.managerDirty = false
    QAB_SAVE_AND_REBUILD()
end

local function QAB_MOVE_BOARD_SCOPE(board, targetScope)
    if board.scope == targetScope then
        return
    end

    local _, oldList, oldIndex = QAB_FIND_BOARD(board.id)
    table.remove(oldList, oldIndex)
    board.scope = targetScope
    if targetScope == "Account" then
        board.ownerCID = "0"
        table.insert(QAB.data.accountBoards, board)
    else
        board.ownerCID = QAB_CURRENT_CID()
        table.insert(QAB_GET_CHARACTER_LIST(QAB_CURRENT_CID(), true), board)
    end
end

function QUICKACTIONBOARD_MANAGER_APPLY()
    local frame = QAB_MANAGER_FRAME()
    local board = QAB_MANAGER_SELECTED_BOARD()
    if frame == nil or board == nil then
        return
    end

    local name = QAB_SANITIZE_BOARD_NAME(GET_CHILD_RECURSIVELY(frame, "nameEdit", "ui::CEditControl"):GetText())
    local rows = tonumber(GET_CHILD_RECURSIVELY(frame, "rowEdit", "ui::CEditControl"):GetText())
    local cols = tonumber(GET_CHILD_RECURSIVELY(frame, "colEdit", "ui::CEditControl"):GetText())
    local scale = tonumber(GET_CHILD_RECURSIVELY(frame, "scaleEdit", "ui::CEditControl"):GetText())
    local alpha = tonumber(GET_CHILD_RECURSIVELY(frame, "alphaEdit", "ui::CEditControl"):GetText())
    local scopeIndex = GET_CHILD_RECURSIVELY(frame, "scopeDrop", "ui::CDropList"):GetSelItemIndex()
    local locked = GET_CHILD_RECURSIVELY(frame, "lockedCheck", "ui::CCheckBox"):IsChecked() == 1
    local visible = GET_CHILD_RECURSIVELY(frame, "visibleCheck", "ui::CCheckBox"):IsChecked() == 1

    if rows == nil or cols == nil or scale == nil or alpha == nil
        or rows < QAB.MIN_ROW_COL or rows > QAB.MAX_ROW_COL
        or cols < QAB.MIN_ROW_COL or cols > QAB.MAX_ROW_COL
        or scale < QAB.MIN_SCALE or scale > QAB.MAX_SCALE
        or alpha < QAB.MIN_ALPHA or alpha > QAB.MAX_ALPHA then
        QAB_NOTIFY("MSG_INVALID_VALUE")
        return
    end

    local newRows = math.floor(rows)
    local newCols = math.floor(cols)
    local backup = QAB_DEEP_COPY(QAB.data)
    if (newRows ~= board.rows or newCols ~= board.cols)
        and QAB_REFLOW_ACTIONS_FOR_CAPACITY(board, newRows * newCols) == false then
        QAB_NOTIFY("MSG_TOO_MANY_ACTIONS")
        return
    end

    local displayedDefaultName = QAB_DEFAULT_BOARD_NAME(board.defaultNameIndex or board.order)
    board.usesDefaultName = name == "" or (board.usesDefaultName == true and name == displayedDefaultName)
    board.name = board.usesDefaultName and "" or name
    board.rows = newRows
    board.cols = newCols
    QAB_MOVE_BOARD_SCOPE(board, scopeIndex == 1 and "Account" or "Character")
    local hud = QAB_GET_HUD(board)
    hud.scale = math.floor(scale)
    hud.alpha = math.floor(alpha)
    hud.locked = locked
    hud.visible = visible

    local valid, reason = QAB_VALIDATE_ALL_LIMITS()
    if valid == false then
        QAB.data = backup
        QAB_NOTIFY(reason)
        QUICKACTIONBOARD_MANAGER_REFRESH()
        return
    end

    QAB.managerDirty = false
    QAB_SAVE_AND_REBUILD()
end

local function QAB_POSE_AVAILABLE(poseClass)
    local iconName = TryGetProp(poseClass, "Icon", "None")
    if iconName == nil or iconName == "" or iconName == "None" then
        return false
    end

    local poseType = TryGetProp(poseClass, "PoseType", "Basic")
    if poseType == "Basic" then
        return true
    elseif poseType == "Premium" then
        return session.loginInfo.IsPremiumState(ITEM_TOKEN) == true
    elseif poseType == "Reward" then
        local account = GetMyAccountObj()
        if account == nil then
            return false
        end
        local rewardName = TryGetProp(poseClass, "RewardName", "None")
        local required = tonumber(TryGetProp(poseClass, "RewardCheckCount", 1)) or 1
        return rewardName ~= "None" and (tonumber(TryGetProp(account, rewardName, 0)) or 0) >= required
    end
    return true
end

local function QAB_BUILD_POSE_PALETTE()
    local actions = {}
    local classList, count = GetClassList("Pose")
    for index = 0, count - 1 do
        local poseClass = GetClassByIndexFromList(classList, index)
        if poseClass ~= nil and QAB_POSE_AVAILABLE(poseClass) then
            table.insert(actions, { kind = "Pose", classID = poseClass.ClassID, iesID = "0" })
        end
    end
    return actions
end

local function QAB_BUILD_EMOTICON_PALETTE()
    local actions = {}
    local classList, count = GetClassList("chat_emoticons")
    for index = 0, count - 1 do
        local emoticonClass = GetClassByIndexFromList(classList, index)
        if emoticonClass ~= nil and QUICKACTIONBOARD_ACTION_HAS_EMOTICON(emoticonClass.ClassID) then
            local kind = TryGetProp(emoticonClass, "IconGroup", "Normal") == "Motion" and "Motion" or "Emoticon"
            table.insert(actions, { kind = kind, classID = emoticonClass.ClassID, iesID = "0" })
        end
    end
    return actions
end

local function QAB_BUILD_WARP_PALETTE()
    local actions = {}
    local seen = {}
    local questFrame = ui.GetFrame("questinfoset_2")
    local memberBox = questFrame ~= nil and GET_CHILD_RECURSIVELY(questFrame, "member", "ui::CGroupBox") or nil
    if memberBox == nil then
        return actions
    end

    for index = 0, memberBox:GetChildCount() - 1 do
        local child = memberBox:GetChildByIndex(index)
        local picture = child ~= nil and GET_CHILD_RECURSIVELY(child, "statepicture", "ui::CPicture") or nil
        local questName = picture ~= nil and picture:GetUserValue("RETURN_QUEST_NAME") or "None"
        if questName ~= nil and questName ~= "None" then
            local questClass = GetClass("QuestProgressCheck", questName)
            if questClass ~= nil and seen[questClass.ClassID] ~= true then
                seen[questClass.ClassID] = true
                table.insert(actions, { kind = "Warp", classID = questClass.ClassID, iesID = "0" })
            end
        end
    end
    return actions
end

local function QAB_SET_PALETTE_ACTIONS(kind)
    if kind == "Emoticon" then
        QAB.paletteActions = QAB_BUILD_EMOTICON_PALETTE()
    elseif kind == "Warp" then
        QAB.paletteActions = QAB_BUILD_WARP_PALETTE()
    else
        QAB.paletteActions = QAB_BUILD_POSE_PALETTE()
        kind = "Pose"
    end
    QAB.paletteKind = kind
end

local function QAB_RENDER_PALETTE(frame)
    local slotset = GET_CHILD_RECURSIVELY(frame, "paletteSlots", "ui::CSlotSet")
    local rowCount = math.max(math.ceil(#QAB.paletteActions / QAB.paletteColumns), 4)
    slotset:SetColRow(QAB.paletteColumns, rowCount)
    slotset:Resize(420, rowCount * 56)
    slotset:CreateSlots()

    for index = 0, slotset:GetSlotCount() - 1 do
        local slot = slotset:GetSlotByIndex(index)
        slot:ClearIcon()
        slot:ClearText()
        local action = QAB.paletteActions[index + 1]
        if action ~= nil then
            QUICKACTIONBOARD_ACTION_RENDER(action, slot)
            slot:SetUserValue("QAB_PALETTE_INDEX", index + 1)
            slot:EnableDrag(1)
            slot:EnablePop(1)
            slot:ShowWindow(1)
        else
            slot:EnableDrag(0)
            slot:EnablePop(0)
            slot:ShowWindow(0)
        end
    end

    local scroll = GET_CHILD_RECURSIVELY(frame, "paletteScroll", "ui::CGroupBox")
    scroll:InvalidateScrollBar()
    scroll:SetScrollBarOffset(0, 0)

    local poseTab = GET_CHILD_RECURSIVELY(frame, "poseTab", "ui::CButton")
    local emoticonTab = GET_CHILD_RECURSIVELY(frame, "emoticonTab", "ui::CButton")
    local warpTab = GET_CHILD_RECURSIVELY(frame, "warpTab", "ui::CButton")
    poseTab:SetSkinName(QAB.paletteKind == "Pose" and "test_pvp_btn" or "test_normal_button")
    emoticonTab:SetSkinName(QAB.paletteKind == "Emoticon" and "test_pvp_btn" or "test_normal_button")
    warpTab:SetSkinName(QAB.paletteKind == "Warp" and "test_pvp_btn" or "test_normal_button")
end

function QUICKACTIONBOARD_MANAGER_PALETTE(frame, ctrl, argStr)
    QAB_SET_PALETTE_ACTIONS(argStr)
    QAB_RENDER_PALETTE(QAB_MANAGER_FRAME())
end

function QUICKACTIONBOARD_PALETTE_POP(parent, slot)
    local actionIndex = tonumber(slot:GetUserValue("QAB_PALETTE_INDEX"))
    local action = actionIndex ~= nil and QAB.paletteActions[actionIndex] or nil
    if action == nil then
        QAB_CLEAR_DRAG()
        return
    end

    QAB.dragAction = QAB_DEEP_COPY(action)
    QAB.dragSourceBoardID = nil
    QAB.dragSourceSlotIndex = nil
    QAB.dragFrameName = slot:GetTopParentFrame():GetName()
end

function QUICKACTIONBOARD_MANAGER_OPEN(frame)
    QAB_LOAD()
    if QAB.data == nil or QAB.data.enabled == false then
        ui.CloseFrame("quickactionboard")
        return
    end
    QAB.managerTab = "Settings"
    QAB.managerAdvanced = false
    QAB.managerDirty = false
    QAB.pendingBoardIndex = nil
    QAB.pendingAddBoard = false
    local scopeDrop = GET_CHILD_RECURSIVELY(frame, "scopeDrop", "ui::CDropList")
    scopeDrop:ClearItems()
    scopeDrop:AddItem(0, frame:GetUserConfig("SCOPE_CHARACTER"))
    scopeDrop:AddItem(1, frame:GetUserConfig("SCOPE_ACCOUNT"))
    local paletteScroll = GET_CHILD_RECURSIVELY(frame, "paletteScroll", "ui::CGroupBox")
    paletteScroll:SetScrollBarOffset(0, 0)
    paletteScroll:SetScrollBarSkinName("verticalscrollbar")
    QAB_SET_PALETTE_ACTIONS(QAB.paletteKind)
    QAB_RENDER_PALETTE(frame)
    QUICKACTIONBOARD_MANAGER_REFRESH()
    QAB_MANAGER_UPDATE_VIEW(frame)
end

function QUICKACTIONBOARD_TOGGLE_MANAGER()
    QAB_LOAD()
    if QAB.data == nil or QAB.data.enabled == false then
        return
    end
    local frame = QAB_MANAGER_FRAME()
    if frame ~= nil and frame:IsVisible() == 1 then
        QUICKACTIONBOARD_MANAGER_CLOSE()
    else
        ui.OpenFrame("quickactionboard")
    end
    ui.CloseFrame("apps")
end

function QUICKACTIONBOARD_OPEN_MANAGER_FROM_BOARD(frame, ctrl)
    local source = ctrl or frame
    if source == nil then
        return
    end
    local topFrame = source:GetTopParentFrame()
    local boardID = topFrame:GetUserValue("QAB_BOARD_ID")
    if boardID ~= nil and boardID ~= "None" then
        QAB.selectedBoardID = boardID
    end
    ui.OpenFrame("quickactionboard")
end

function QUICKACTIONBOARD_BOARD_MANAGE_BUTTON(frame, ctrl)
    local source = ctrl or frame
    if source == nil then
        return
    end
    local topFrame = source:GetTopParentFrame()
    if topFrame == nil then
        return
    end
    if topFrame:GetUserIValue("QAB_COMPACT_HEADER") == 1 then
        QUICKACTIONBOARD_BOARD_OPEN_MENU(topFrame, ctrl)
        return
    end
    QUICKACTIONBOARD_OPEN_MANAGER_FROM_BOARD(topFrame, ctrl)
end

function QUICKACTIONBOARD_BOARD_OPEN_MENU(frame, ctrl)
    local board, topFrame = QAB_BOARD_FROM_CONTROL(frame, ctrl)
    if board == nil or topFrame == nil then
        return
    end

    QAB.menuBoardID = board.id
    local hud = QAB_GET_HUD(board)
    local scopeMessageKey = board.scope == "Account" and "QuickActionBoardScopeAccount" or "QuickActionBoardScopeCharacter"
    local menuTitle = ScpArgMsg("QuickActionBoardMenuTitle{BOARD}{SCOPE}", "BOARD", QAB_BOARD_DISPLAY_NAME(board), "SCOPE", ClMsg(scopeMessageKey))
    local context = ui.CreateContextMenu("QUICKACTIONBOARD_BOARD_MENU", menuTitle, 0, 0, 200, 100)
    ui.AddContextMenuItem(context, ClMsg("QuickActionBoardMenuManage"), "QUICKACTIONBOARD_BOARD_MENU_MANAGE()")
    local minimizeKey = hud.minimized and "QuickActionBoardMenuRestore" or "QuickActionBoardMenuMinimize"
    ui.AddContextMenuItem(context, ClMsg(minimizeKey), "QUICKACTIONBOARD_BOARD_MENU_TOGGLE_MINIMIZED()")
    ui.AddContextMenuItem(context, ClMsg("QuickActionBoardMenuClose"), "QUICKACTIONBOARD_BOARD_MENU_CLOSE()")
    ui.OpenContextMenu(context)
end

local function QAB_BOARD_MENU_TARGET()
    local board = QAB_FIND_BOARD(QAB.menuBoardID)
    if board == nil then
        QAB.menuBoardID = nil
        return nil, nil
    end
    return board, ui.GetFrame(QAB_FRAME_NAME(board.id))
end

function QUICKACTIONBOARD_BOARD_MENU_MANAGE()
    local board, frame = QAB_BOARD_MENU_TARGET()
    QAB.menuBoardID = nil
    if board == nil or frame == nil then
        return
    end
    QUICKACTIONBOARD_OPEN_MANAGER_FROM_BOARD(frame, nil)
end

function QUICKACTIONBOARD_BOARD_MENU_TOGGLE_MINIMIZED()
    local board, frame = QAB_BOARD_MENU_TARGET()
    QAB.menuBoardID = nil
    if board == nil or frame == nil then
        return
    end
    QUICKACTIONBOARD_BOARD_TOGGLE_MINIMIZED(frame, nil)
end

function QUICKACTIONBOARD_BOARD_MENU_CLOSE()
    local board, frame = QAB_BOARD_MENU_TARGET()
    QAB.menuBoardID = nil
    if board == nil or frame == nil then
        return
    end
    QUICKACTIONBOARD_BOARD_CLOSE(frame, nil)
end

local function QAB_REFRESH_ALL(eventName)
    if QAB.data == nil or QAB.data.enabled == false then
        return
    end
    for _, board in ipairs(QAB_GET_ACTIVE_BOARDS()) do
        local frame = ui.GetFrame(QAB_FRAME_NAME(board.id))
        local slotset = frame ~= nil and GET_CHILD_RECURSIVELY(frame, "boardSlots", "ui::CSlotSet") or nil
        if slotset ~= nil then
            for index = 0, QAB_BOARD_SLOT_COUNT(board) - 1 do
                local action = QAB_ACTION_AT(board, index)
                if action ~= nil then
                    QUICKACTIONBOARD_ACTION_REFRESH(action, slotset:GetSlotByIndex(index), eventName)
                end
            end
        end
    end
end

function QUICKACTIONBOARD_ON_MSG(frame, message, argStr, argNum)
    if message == "GAME_START" then
        QAB_LOAD()
        QUICKACTIONBOARD_REBUILD_BOARDS()
        ReserveScript("QUICKACTIONBOARD_SYNC_GLOBAL_BUTTON()", 1)
    elseif QAB.loaded == false or QAB.data == nil or QAB.data.enabled == false then
        return
    elseif message == "CHANGE_RESOLUTION" then
        QUICKACTIONBOARD_JOYSTICK_EXIT()
        QUICKACTIONBOARD_REBUILD_BOARDS()
    elseif message == "JUNGTAN_SLOT_UPDATE" then
        QAB_UPDATE_SPECIAL_ITEM_EFFECT_STATE(argStr, argNum)
    else
        QAB_REFRESH_ALL(message)
    end
end

local function QAB_JOYSTICK_KEY_DOWN(key)
    return joystick.IsKeyPressed(key) == 1
end

local function QAB_JOYSTICK_EDGE(key)
    local current = QAB_JOYSTICK_KEY_DOWN(key) and 1 or 0
    local previous = QAB.joystickPrevious[key] or 0
    QAB.joystickPrevious[key] = current
    return current == 1 and previous == 0
end

local function QAB_JOYSTICK_UPDATE_PREVIOUS()
    local keys = {
        "JOY_CROSS_UP", "JOY_CROSS_DOWN", "JOY_CROSS_LEFT", "JOY_CROSS_RIGHT",
        "JOY_BTN_2", "JOY_BTN_3", "JOY_BTN_4", "JOY_BTN_5", "JOY_BTN_6"
    }
    for _, key in ipairs(keys) do
        QAB.joystickPrevious[key] = QAB_JOYSTICK_KEY_DOWN(key) and 1 or 0
    end
end

local function QAB_JOYSTICK_HAS_ENTRY_CONFLICT()
    local keys = {
        "JOY_UP", "JOY_DOWN", "JOY_LEFT", "JOY_RIGHT",
        "JOY_CROSS_UP", "JOY_CROSS_DOWN", "JOY_CROSS_LEFT", "JOY_CROSS_RIGHT",
        "JOY_BTN_1", "JOY_BTN_2", "JOY_BTN_3", "JOY_BTN_4"
    }
    for _, key in ipairs(keys) do
        if QAB_JOYSTICK_KEY_DOWN(key) then
            return true
        end
    end
    return false
end

local function QAB_JOYSTICK_SELECTED_BOARD()
    local boards = QAB_VISIBLE_ACTIVE_BOARDS()
    if #boards == 0 then
        return nil, boards
    end
    QAB.joystickBoardIndex = QAB_CLAMP(QAB.joystickBoardIndex, 1, #boards)
    return boards[QAB.joystickBoardIndex], boards
end

local function QAB_JOYSTICK_HIGHLIGHT()
    for _, board in ipairs(QAB_GET_ACTIVE_BOARDS()) do
        local frame = ui.GetFrame(QAB_FRAME_NAME(board.id))
        if frame ~= nil then
            local slotset = GET_CHILD_RECURSIVELY(frame, "boardSlots", "ui::CSlotSet")
            for index = 0, QAB_BOARD_SLOT_COUNT(board) - 1 do
                slotset:GetSlotByIndex(index):SetColorTone("FFFFFFFF")
            end
        end
    end

    if QAB.joystickFocus == false then
        return
    end
    local board = QAB_JOYSTICK_SELECTED_BOARD()
    if board == nil then
        return
    end
    local frame = ui.GetFrame(QAB_FRAME_NAME(board.id))
    if frame == nil then
        return
    end
    local slotset = GET_CHILD_RECURSIVELY(frame, "boardSlots", "ui::CSlotSet")
    local maxIndex = math.max(QAB_BOARD_SLOT_COUNT(board) - 1, 0)
    QAB.joystickSlotIndex = QAB_CLAMP(QAB.joystickSlotIndex, 0, maxIndex)
    slotset:GetSlotByIndex(QAB.joystickSlotIndex):SetColorTone("FFFFFF66")
end

function QUICKACTIONBOARD_JOYSTICK_ENTER()
    if QAB.data.globalVisible == false then
        QUICKACTIONBOARD_TOGGLE_GLOBAL()
    end
    local boards = QAB_VISIBLE_ACTIVE_BOARDS()
    if #boards == 0 then
        return
    end
    QAB.joystickFocus = true
    QAB.joystickBoardIndex = 1
    QAB.joystickSlotIndex = 0
    QAB.joystickWaitRelease = true
    SetKeyboardSelectMode(1)
    QAB_JOYSTICK_UPDATE_PREVIOUS()
    QAB_JOYSTICK_HIGHLIGHT()
end

function QUICKACTIONBOARD_JOYSTICK_EXIT()
    if QAB.joystickFocus == false then
        return
    end
    QAB.joystickFocus = false
    QAB.joystickWaitRelease = false
    SetKeyboardSelectMode(0)
    QAB_JOYSTICK_HIGHLIGHT()
end

local function QAB_JOYSTICK_MOVE(deltaRow, deltaCol)
    local board = QAB_JOYSTICK_SELECTED_BOARD()
    if board == nil then
        return
    end

    local row = math.floor(QAB.joystickSlotIndex / board.cols)
    local col = QAB.joystickSlotIndex % board.cols
    row = (row + deltaRow) % board.rows
    col = (col + deltaCol) % board.cols
    QAB.joystickSlotIndex = row * board.cols + col
    QAB_JOYSTICK_HIGHLIGHT()
end

local function QAB_JOYSTICK_CHANGE_BOARD(delta)
    local _, boards = QAB_JOYSTICK_SELECTED_BOARD()
    if #boards == 0 then
        return
    end
    QAB.joystickBoardIndex = ((QAB.joystickBoardIndex - 1 + delta) % #boards) + 1
    local board = boards[QAB.joystickBoardIndex]
    QAB.joystickSlotIndex = math.min(QAB.joystickSlotIndex, QAB_BOARD_SLOT_COUNT(board) - 1)
    QAB_JOYSTICK_HIGHLIGHT()
end

local function QAB_JOYSTICK_EXECUTE()
    local board = QAB_JOYSTICK_SELECTED_BOARD()
    if board == nil then
        return
    end
    local action = QAB_ACTION_AT(board, QAB.joystickSlotIndex)
    local frame = ui.GetFrame(QAB_FRAME_NAME(board.id))
    local slotset = frame ~= nil and GET_CHILD_RECURSIVELY(frame, "boardSlots", "ui::CSlotSet") or nil
    if action == nil or slotset == nil then
        return
    end
    local success, reason = QUICKACTIONBOARD_ACTION_EXECUTE(action, slotset:GetSlotByIndex(QAB.joystickSlotIndex), "Joystick")
    if success == false then
        QAB_NOTIFY_REASON(reason)
    end
end

local function QAB_UPDATE_JOYSTICK(elapsedTime)
    if IsJoyStickMode() == 0 then
        QAB.joystickHoldTime = 0
        QAB.joystickHoldTriggered = false
        if QAB.joystickFocus then
            QUICKACTIONBOARD_JOYSTICK_EXIT()
        end
        return
    end

    if QAB.joystickFocus and ui.CheckHoldedUI() == true then
        QUICKACTIONBOARD_JOYSTICK_EXIT()
        return
    end

    local l1l2 = QAB_JOYSTICK_KEY_DOWN("JOY_L1L2")
    if QAB.joystickFocus == false then
        if l1l2 and QAB_JOYSTICK_HAS_ENTRY_CONFLICT() == false then
            QAB.joystickHoldTime = QAB.joystickHoldTime + elapsedTime
            if QAB.joystickHoldTime >= QAB.JOYSTICK_HOLD_SECONDS and QAB.joystickHoldTriggered == false then
                QAB.joystickHoldTriggered = true
                QUICKACTIONBOARD_JOYSTICK_ENTER()
            end
        else
            QAB.joystickHoldTime = 0
            if l1l2 == false then
                QAB.joystickHoldTriggered = false
            end
        end
        return
    end

    if QAB.joystickWaitRelease then
        QAB_JOYSTICK_UPDATE_PREVIOUS()
        if l1l2 == false then
            QAB.joystickWaitRelease = false
        end
        return
    end

    if QAB_JOYSTICK_EDGE("JOY_BTN_3") then
        QUICKACTIONBOARD_JOYSTICK_EXIT()
        return
    elseif QAB_JOYSTICK_EDGE("JOY_BTN_4") then
        QUICKACTIONBOARD_TOGGLE_GLOBAL()
        return
    elseif QAB_JOYSTICK_EDGE("JOY_BTN_2") then
        QAB_JOYSTICK_EXECUTE()
    elseif QAB_JOYSTICK_EDGE("JOY_BTN_5") then
        QAB_JOYSTICK_CHANGE_BOARD(-1)
    elseif QAB_JOYSTICK_EDGE("JOY_BTN_6") then
        QAB_JOYSTICK_CHANGE_BOARD(1)
    elseif QAB_JOYSTICK_EDGE("JOY_CROSS_UP") then
        QAB_JOYSTICK_MOVE(-1, 0)
    elseif QAB_JOYSTICK_EDGE("JOY_CROSS_DOWN") then
        QAB_JOYSTICK_MOVE(1, 0)
    elseif QAB_JOYSTICK_EDGE("JOY_CROSS_LEFT") then
        QAB_JOYSTICK_MOVE(0, -1)
    elseif QAB_JOYSTICK_EDGE("JOY_CROSS_RIGHT") then
        QAB_JOYSTICK_MOVE(0, 1)
    end
end

function QUICKACTIONBOARD_TIMER_UPDATE(frame, timer, argStr, argNum, elapsedTime)
    if QAB.loaded == false or QAB.data == nil or QAB.data.enabled == false then
        return 1
    end
    QAB_UPDATE_JOYSTICK(elapsedTime)
    return 1
end

function QUICKACTIONBOARD_ON_INIT(addon, frame)
    addon:RegisterMsg("GAME_START", "QUICKACTIONBOARD_ON_MSG")
    addon:RegisterMsg("CHANGE_RESOLUTION", "QUICKACTIONBOARD_ON_MSG")
    addon:RegisterMsg("INV_ITEM_ADD", "QUICKACTIONBOARD_ON_MSG")
    addon:RegisterMsg("INV_ITEM_ADD_FOR_QUICKSLOT", "QUICKACTIONBOARD_ON_MSG")
    addon:RegisterMsg("INV_ITEM_POST_REMOVE", "QUICKACTIONBOARD_ON_MSG")
    addon:RegisterMsg("INV_ITEM_CHANGE_COUNT", "QUICKACTIONBOARD_ON_MSG")
    addon:RegisterMsg("EQUIP_ITEM_LIST_GET", "QUICKACTIONBOARD_ON_MSG")
    addon:RegisterMsg("PC_PROPERTY_UPDATE_TO_QUICKSLOT", "QUICKACTIONBOARD_ON_MSG")
    addon:RegisterMsg("SKILL_LIST_GET", "QUICKACTIONBOARD_ON_MSG")
    addon:RegisterMsg("SPECIFIC_SKILL_GET", "QUICKACTIONBOARD_ON_MSG")
    addon:RegisterMsg("RESET_ABILITY_ACTIVE", "QUICKACTIONBOARD_ON_MSG")
    addon:RegisterMsg("JUNGTAN_SLOT_UPDATE", "QUICKACTIONBOARD_ON_MSG")

    local timer = GET_CHILD_RECURSIVELY(frame, "addontimer", "ui::CAddOnTimer")
    timer:SetUpdateScript("QUICKACTIONBOARD_TIMER_UPDATE")
    timer:Start(0.05)
end

if QAB.loaded == true and QAB.data ~= nil then
    ReserveScript("QUICKACTIONBOARD_REBUILD_BOARDS()", 0.1)
end
