g_archeologyRewardVaultItems = g_archeologyRewardVaultItems or {}

local ARCHEOLOGY_REWARD_VAULT_WIDTH = 350
local ARCHEOLOGY_REWARD_VAULT_HEIGHT = 360
local ARCHEOLOGY_REWARD_VAULT_MINIMIZED_SIZE = 62
local ARCHEOLOGY_REWARD_VAULT_ROW_HEIGHT = 48
local ARCHEOLOGY_REWARD_VAULT_SOURCE_HEADER_HEIGHT = 30
local ARCHEOLOGY_REWARD_VAULT_SOURCE_INFO = {
    EXPLORATION = {
        order = 1,
        labelMsg = 'ARCHEOLOGY_VAULT_SOURCE_EXPLORATION',
        color = 'FFE082',
        tooltipMsg = 'ARCHEOLOGY_VAULT_SOURCE_EXPLORATION_DESC',
    },
    GIMMICK = {
        order = 2,
        labelMsg = 'ARCHEOLOGY_VAULT_SOURCE_GIMMICK',
        color = '8FD3FF',
        tooltipMsg = 'ARCHEOLOGY_VAULT_SOURCE_GIMMICK_DESC',
    },
    CLEAR = {
        order = 3,
        labelMsg = 'ARCHEOLOGY_VAULT_SOURCE_CLEAR',
        color = '8FFFA8',
        tooltipMsg = 'ARCHEOLOGY_VAULT_SOURCE_CLEAR_DESC',
    },
    ENTRY_REFUND = {
        order = 4,
        labelMsg = 'ARCHEOLOGY_VAULT_SOURCE_ENTRY_REFUND',
        color = 'FFC8A0',
        tooltipMsg = 'ARCHEOLOGY_VAULT_SOURCE_ENTRY_REFUND_DESC',
    },
    CONSOLATION = {
        order = 5,
        labelMsg = 'ARCHEOLOGY_VAULT_SOURCE_CONSOLATION',
        color = 'C8C8C8',
        tooltipMsg = 'ARCHEOLOGY_VAULT_SOURCE_CONSOLATION_DESC',
    },
}

function ARCHEOLOGY_REWARD_VAULT_ON_INIT(addon, frame)
    addon:RegisterMsg('GAME_START', 'ARCHEOLOGY_REWARD_VAULT_RESTORE_POSITION')
    addon:RegisterMsg('ARCHEOLOGY_REWARD_VAULT_OPEN',
        'ON_ARCHEOLOGY_REWARD_VAULT_OPEN')
    addon:RegisterMsg('ARCHEOLOGY_REWARD_VAULT_SNAPSHOT',
        'ON_ARCHEOLOGY_REWARD_VAULT_SNAPSHOT')
    addon:RegisterMsg('ARCHEOLOGY_REWARD_VAULT_SETTLING',
        'ON_ARCHEOLOGY_REWARD_VAULT_SETTLING')
    addon:RegisterMsg('ARCHEOLOGY_REWARD_VAULT_SETTLED',
        'ON_ARCHEOLOGY_REWARD_VAULT_SETTLED')
    addon:RegisterMsg('ARCHEOLOGY_REWARD_VAULT_ITEM_SETTLED',
        'ON_ARCHEOLOGY_REWARD_VAULT_ITEM_SETTLED')
    addon:RegisterMsg('ARCHEOLOGY_REWARD_VAULT_CLOSE',
        'ON_ARCHEOLOGY_REWARD_VAULT_CLOSE')

    frame:SetUserValue('VAULT_DISPLAY', 'MINIMIZED')
    frame:SetUserValue('VAULT_STATE', 'HIDDEN')
    ARCHEOLOGY_REWARD_VAULT_APPLY_DISPLAY(frame, 'MINIMIZED')
    frame:ShowWindow(0)
end

local function ARCHEOLOGY_REWARD_VAULT_SET_TEXT(ctrl, key, text, tooltip)
    if ctrl == nil then
        return
    end
    ctrl:SetTextByKey(key, text or '')
    if tooltip ~= nil then
        ctrl:SetTextTooltip(tooltip)
    end
end

local function ARCHEOLOGY_REWARD_VAULT_GET_STATUS_TEXT(state)
    if state == 'PREPARE' then
        return ClMsg('ARCHEOLOGY_VAULT_STATUS_PREPARE')
    elseif state == 'EXPLORING' then
        return ClMsg('ARCHEOLOGY_VAULT_STATUS_EXPLORING')
    elseif state == 'SETTLING' then
        return ClMsg('ARCHEOLOGY_VAULT_STATUS_SETTLING')
    elseif state == 'SETTLED' then
        return ClMsg('ARCHEOLOGY_VAULT_STATUS_SETTLED')
    elseif state == 'FAILED' then
        return ClMsg('ARCHEOLOGY_VAULT_STATUS_FAILED')
    end
    return ''
end

function ARCHEOLOGY_REWARD_VAULT_APPLY_DISPLAY(frame, display)
    if frame == nil then
        return
    end
    local minimized = GET_CHILD_RECURSIVELY(frame, 'minimized')
    local expanded = GET_CHILD_RECURSIVELY(frame, 'expanded')
    local isExpanded = display == 'EXPANDED'

    frame:SetUserValue('VAULT_DISPLAY', isExpanded and 'EXPANDED' or 'MINIMIZED')
    frame:Resize(isExpanded and ARCHEOLOGY_REWARD_VAULT_WIDTH or
        ARCHEOLOGY_REWARD_VAULT_MINIMIZED_SIZE,
        isExpanded and ARCHEOLOGY_REWARD_VAULT_HEIGHT or
        ARCHEOLOGY_REWARD_VAULT_MINIMIZED_SIZE)
    if minimized ~= nil then
        minimized:ShowWindow(isExpanded and 0 or 1)
    end
    if expanded ~= nil then
        expanded:ShowWindow(isExpanded and 1 or 0)
    end
end

function ARCHEOLOGY_REWARD_VAULT_TOGGLE(parent, ctrl)
    local frame = parent:GetTopParentFrame()
    if frame == nil then
        return
    end
    local state = frame:GetUserValue('VAULT_STATE')
    local display = frame:GetUserValue('VAULT_DISPLAY')
    ARCHEOLOGY_REWARD_VAULT_APPLY_DISPLAY(frame,
        display == 'EXPANDED' and 'MINIMIZED' or 'EXPANDED')
end

function ARCHEOLOGY_REWARD_VAULT_PARSE_SNAPSHOT(argStr)
    local items = {}
    if argStr == nil or argStr == '' or argStr == 'None' then
        return items
    end

    local function normalizeSource(source)
        if ARCHEOLOGY_REWARD_VAULT_SOURCE_INFO[source] == nil then
            return 'EXPLORATION'
        end
        return source
    end

    local function appendItem(source, itemClass, itemCount)
        itemCount = math.floor(tonumber(itemCount) or 0)
        if itemClass ~= nil and itemClass ~= 'None' and itemCount > 0 then
            local itemCls = GetClass('Item', itemClass)
            local itemName = itemClass
            local itemGrade = 0
            if itemCls ~= nil then
                itemName = TryGetProp(itemCls, 'Name', itemClass)
                itemGrade = math.floor(tonumber(
                    TryGetProp(itemCls, 'ItemGrade', 0)) or 0)
            end
            items[#items + 1] = {
                source = normalizeSource(source),
                itemClass = itemClass,
                itemCount = itemCount,
                itemName = itemName,
                itemGrade = itemGrade,
                settlementState = 'PENDING',
            }
        end
    end

    local flatText = argStr
    local sourceText = nil
    local separator = string.find(argStr, '#', 1, true)
    if separator ~= nil then
        flatText = string.sub(argStr, 1, separator - 1)
        sourceText = string.sub(argStr, separator + 1)
    end

    local flatCounts = {}
    for entry in string.gmatch(flatText or '', '([^;]+)') do
        local itemClass, itemCount =
            string.match(entry, '^([^,]+),([0-9]+)$')
        itemCount = math.floor(tonumber(itemCount) or 0)
        if itemClass ~= nil and itemClass ~= 'None' and itemCount > 0 then
            flatCounts[itemClass] = (flatCounts[itemClass] or 0) + itemCount
        end
    end

    local sourceCounts = {}
    if sourceText ~= nil and sourceText ~= '' and sourceText ~= 'None' then
        for entry in string.gmatch(sourceText, '([^;]+)') do
            local source, itemClass, itemCount =
                string.match(entry, '^([^,]+),([^,]+),([0-9]+)$')
            appendItem(source, itemClass, itemCount)
            itemCount = math.floor(tonumber(itemCount) or 0)
            if itemClass ~= nil and itemClass ~= 'None' and itemCount > 0 then
                sourceCounts[itemClass] =
                    (sourceCounts[itemClass] or 0) + itemCount
            end
        end
    end

    if #items > 0 then
        local sourceMatchesFlat = true
        for itemClass, itemCount in pairs(flatCounts) do
            if sourceCounts[itemClass] ~= itemCount then
                sourceMatchesFlat = false
                break
            end
        end
        if sourceMatchesFlat == true then
            for itemClass, itemCount in pairs(sourceCounts) do
                if flatCounts[itemClass] ~= itemCount then
                    sourceMatchesFlat = false
                    break
                end
            end
        end
        if sourceMatchesFlat ~= true then
            items = {}
        end
    end

    if #items <= 0 then
        for entry in string.gmatch(flatText or '', '([^;]+)') do
            local itemClass, itemCount =
                string.match(entry, '^([^,]+),([0-9]+)$')
            appendItem('EXPLORATION', itemClass, itemCount)
        end
    end

    ARCHEOLOGY_REWARD_VAULT_SORT_ITEMS(items)
    return items
end

function ARCHEOLOGY_REWARD_VAULT_SORT_ITEMS(items)
    local stateOrder = {
        PENDING = 1,
        INVENTORY = 2,
        POSTBOX = 3,
    }
    table.sort(items, function(a, b)
        local sourceA = (ARCHEOLOGY_REWARD_VAULT_SOURCE_INFO[a.source] or
            ARCHEOLOGY_REWARD_VAULT_SOURCE_INFO.EXPLORATION).order
        local sourceB = (ARCHEOLOGY_REWARD_VAULT_SOURCE_INFO[b.source] or
            ARCHEOLOGY_REWARD_VAULT_SOURCE_INFO.EXPLORATION).order
        if sourceA ~= sourceB then
            return sourceA < sourceB
        end
        local stateA = stateOrder[a.settlementState] or 9
        local stateB = stateOrder[b.settlementState] or 9
        if stateA ~= stateB then
            return stateA < stateB
        end
        if a.itemGrade ~= b.itemGrade then
            return a.itemGrade > b.itemGrade
        end
        if a.itemName ~= b.itemName then
            return tostring(a.itemName) < tostring(b.itemName)
        end
        return a.itemClass < b.itemClass
    end)
end

function ARCHEOLOGY_REWARD_VAULT_GET_COMPLETED_BACKGROUND_ALPHA(state)
    return state == 'PENDING' and 0 or 65
end

function ARCHEOLOGY_REWARD_VAULT_MARK_SETTLED(
        source, itemClass, itemCount, delivery)
    itemCount = math.max(0, math.floor(tonumber(itemCount) or 0))
    if itemCount <= 0 then return end
    local moved = 0
    local template = nil
    for index = #g_archeologyRewardVaultItems, 1, -1 do
        local reward = g_archeologyRewardVaultItems[index]
        if reward.settlementState == 'PENDING' and reward.source == source and
                reward.itemClass == itemClass and moved < itemCount then
            template = template or reward
            local count = math.min(reward.itemCount, itemCount - moved)
            reward.itemCount = reward.itemCount - count
            moved = moved + count
            if reward.itemCount <= 0 then
                table.remove(g_archeologyRewardVaultItems, index)
            end
        end
    end
    if moved <= 0 then return end
    for _, reward in ipairs(g_archeologyRewardVaultItems) do
        if reward.settlementState == delivery and reward.source == source and
                reward.itemClass == itemClass then
            reward.itemCount = reward.itemCount + moved
            ARCHEOLOGY_REWARD_VAULT_SORT_ITEMS(g_archeologyRewardVaultItems)
            return
        end
    end
    g_archeologyRewardVaultItems[#g_archeologyRewardVaultItems + 1] = {
        source = source,
        itemClass = itemClass,
        itemCount = moved,
        itemName = template.itemName,
        itemGrade = template.itemGrade,
        settlementState = delivery,
    }
    ARCHEOLOGY_REWARD_VAULT_SORT_ITEMS(g_archeologyRewardVaultItems)
end

local function ARCHEOLOGY_REWARD_VAULT_RENDER_SOURCE_HEADER(
        list, source, index, y)
    local sourceInfo = ARCHEOLOGY_REWARD_VAULT_SOURCE_INFO[source] or
        ARCHEOLOGY_REWARD_VAULT_SOURCE_INFO.EXPLORATION
    local header = list:CreateOrGetControlSet('archeology_reward_vault_source_header',
        'reward_source_' .. tostring(index),
        0, y)
    local label = GET_CHILD_RECURSIVELY(header, 'source_label')
    label:SetTextByKey('color', sourceInfo.color)
    label:SetTextByKey('label', ClMsg(sourceInfo.labelMsg))
    label:SetTextTooltip(ClMsg(sourceInfo.tooltipMsg))
end

local function ARCHEOLOGY_REWARD_VAULT_RENDER_ROW(
        list, reward, index, y)
    local row = list:CreateOrGetControlSet('archeology_reward_vault_row',
        'reward_row_' .. tostring(index), 0, y)
    local completedAlpha = ARCHEOLOGY_REWARD_VAULT_GET_COMPLETED_BACKGROUND_ALPHA(
        reward.settlementState)
    row:SetSkinName(completedAlpha > 0 and 'quest_bg_black_op_50' or 'None')
    row:SetAlpha(completedAlpha > 0 and completedAlpha or 100)

    local slot = GET_CHILD_RECURSIVELY(row, 'item_slot')

    local itemName = reward.itemName or reward.itemClass
    local itemCls = GetClass('Item', reward.itemClass)
    if itemCls ~= nil then
        SET_SLOT_IMG(slot, TryGetProp(itemCls, 'Icon', 'None'))
        local icon = slot:GetIcon()
        if icon ~= nil then
            SET_ITEM_TOOLTIP_BY_TYPE(icon, TryGetProp(itemCls, 'ClassID', 0))
        end
    end

    local nameText = GET_CHILD_RECURSIVELY(row, 'item_name')
    local stateMessage = 'ARCHEOLOGY_VAULT_ITEM_PENDING{ITEM}'
    if reward.settlementState == 'INVENTORY' then
        stateMessage = 'ARCHEOLOGY_VAULT_ITEM_ACQUIRED{ITEM}'
    elseif reward.settlementState == 'POSTBOX' then
        stateMessage = 'ARCHEOLOGY_VAULT_ITEM_POSTBOX{ITEM}'
    end
    ARCHEOLOGY_REWARD_VAULT_SET_TEXT(nameText, 'name',
        ScpArgMsg(stateMessage, 'ITEM', tostring(itemName)),
        tostring(itemName))

    local countText = GET_CHILD_RECURSIVELY(row, 'item_count')
    ARCHEOLOGY_REWARD_VAULT_SET_TEXT(countText, 'count', reward.itemCount)
end

function ARCHEOLOGY_REWARD_VAULT_RENDER(frame)
    if frame == nil then
        return
    end
    local list = GET_CHILD_RECURSIVELY(frame, 'reward_list')
    local emptyText = GET_CHILD_RECURSIVELY(frame, 'empty_text')
    local countText = GET_CHILD_RECURSIVELY(frame, 'minimized_count')
    if list == nil then
        return
    end

    list:RemoveAllChild()
    local y = 0
    local currentSource = nil
    local sourceIndex = 0
    for i = 1, #g_archeologyRewardVaultItems do
        local reward = g_archeologyRewardVaultItems[i]
        if reward.source ~= currentSource then
            currentSource = reward.source
            sourceIndex = sourceIndex + 1
            ARCHEOLOGY_REWARD_VAULT_RENDER_SOURCE_HEADER(
                list, currentSource, sourceIndex, y)
            y = y + ARCHEOLOGY_REWARD_VAULT_SOURCE_HEADER_HEIGHT
        end
        ARCHEOLOGY_REWARD_VAULT_RENDER_ROW(list,
            reward, i, y)
        y = y + ARCHEOLOGY_REWARD_VAULT_ROW_HEIGHT
    end
    list:UpdateData()
    list:InvalidateScrollBar()

    if emptyText ~= nil then
        emptyText:ShowWindow(#g_archeologyRewardVaultItems <= 0 and 1 or 0)
    end
    local uniqueClasses = {}
    local uniqueCount = 0
    for i = 1, #g_archeologyRewardVaultItems do
        local itemClass = g_archeologyRewardVaultItems[i].itemClass
        if uniqueClasses[itemClass] ~= true then
            uniqueClasses[itemClass] = true
            uniqueCount = uniqueCount + 1
        end
    end
    ARCHEOLOGY_REWARD_VAULT_SET_TEXT(countText, 'count', uniqueCount)
end

function ON_ARCHEOLOGY_REWARD_VAULT_OPEN(frame, msg, argStr, argNum)
    if frame == nil then
        return
    end
    local display = argStr == 'EXPANDED' and 'EXPANDED' or 'MINIMIZED'
    if display == 'MINIMIZED' then
        g_archeologyRewardVaultItems = {}
        frame:SetUserValue('VAULT_STATE', 'PREPARE')
    else
        frame:SetUserValue('VAULT_STATE', 'EXPLORING')
    end
    local statusText = GET_CHILD_RECURSIVELY(frame, 'status_text')
    ARCHEOLOGY_REWARD_VAULT_SET_TEXT(statusText, 'status',
        ARCHEOLOGY_REWARD_VAULT_GET_STATUS_TEXT(frame:GetUserValue('VAULT_STATE')))
    ARCHEOLOGY_REWARD_VAULT_APPLY_DISPLAY(frame, display)
    ARCHEOLOGY_REWARD_VAULT_RENDER(frame)
    frame:ShowWindow(1)
end

function ON_ARCHEOLOGY_REWARD_VAULT_SNAPSHOT(frame, msg, argStr, argNum)
    if frame == nil then
        return
    end
    local items = ARCHEOLOGY_REWARD_VAULT_PARSE_SNAPSHOT(argStr)
    for _, reward in ipairs(g_archeologyRewardVaultItems) do
        if reward.settlementState ~= 'PENDING' then
            items[#items + 1] = reward
        end
    end
    g_archeologyRewardVaultItems = items
    ARCHEOLOGY_REWARD_VAULT_SORT_ITEMS(g_archeologyRewardVaultItems)
    if frame:GetUserValue('VAULT_STATE') ~= 'SETTLING' and
            frame:GetUserValue('VAULT_STATE') ~= 'SETTLED' then
        frame:SetUserValue('VAULT_STATE',
            #g_archeologyRewardVaultItems > 0 and 'EXPLORING' or
                frame:GetUserValue('VAULT_STATE'))
    end
    local statusText = GET_CHILD_RECURSIVELY(frame, 'status_text')
    ARCHEOLOGY_REWARD_VAULT_SET_TEXT(statusText, 'status',
        ARCHEOLOGY_REWARD_VAULT_GET_STATUS_TEXT(frame:GetUserValue('VAULT_STATE')))
    ARCHEOLOGY_REWARD_VAULT_RENDER(frame)
    if tonumber(argNum) == 1 then
        imcSound.PlaySoundEvent('sys_quest_item_get')
    end
end

function ON_ARCHEOLOGY_REWARD_VAULT_ITEM_SETTLED(frame, msg, argStr, argNum)
    if frame == nil or argStr == nil then return end
    local source, itemClass, delivery =
        string.match(argStr, '^([^#]+)#([^#]+)#([^#]+)$')
    if source == nil or itemClass == nil or
            (delivery ~= 'INVENTORY' and delivery ~= 'POSTBOX') then
        return
    end
    if ARCHEOLOGY_REWARD_VAULT_SOURCE_INFO[source] == nil then
        source = 'EXPLORATION'
    end
    ARCHEOLOGY_REWARD_VAULT_MARK_SETTLED(
        source, itemClass, tonumber(argNum) or 0, delivery)
    ARCHEOLOGY_REWARD_VAULT_RENDER(frame)
end

function ON_ARCHEOLOGY_REWARD_VAULT_SETTLING(frame, msg, argStr, argNum)
    if frame == nil then
        return
    end
    if tonumber(argNum) ~= 1 then
        return
    end
    frame:SetUserValue('VAULT_STATE', 'SETTLING')
    local statusText = GET_CHILD_RECURSIVELY(frame, 'status_text')
    ARCHEOLOGY_REWARD_VAULT_SET_TEXT(statusText, 'status',
        ARCHEOLOGY_REWARD_VAULT_GET_STATUS_TEXT('SETTLING'))
    frame:ShowWindow(1)
end

function ON_ARCHEOLOGY_REWARD_VAULT_SETTLED(frame, msg, argStr, argNum)
    if frame == nil or argStr == nil then
        return
    end
    if frame:GetUserValue('VAULT_STATE') == 'HIDDEN' then
        return
    end
    local values = StringSplit(argStr, '#')
    local success = values ~= nil and values[1] == 'SUCCESS'
    local final = values ~= nil and values[3] == 'FINAL'
    if success == true and final ~= true then
        return
    end
    frame:SetUserValue('VAULT_STATE',
        success and (final and 'SETTLED' or 'EXPLORING') or 'FAILED')
    -- 실패 안내(보상은 보관 중)는 펼친 패널에만 있으므로 실패도 펼친다.
    if final or success ~= true then
        ARCHEOLOGY_REWARD_VAULT_APPLY_DISPLAY(frame, 'EXPANDED')
    end
    local statusText = GET_CHILD_RECURSIVELY(frame, 'status_text')
    ARCHEOLOGY_REWARD_VAULT_SET_TEXT(statusText, 'status',
        ARCHEOLOGY_REWARD_VAULT_GET_STATUS_TEXT(
            success and (final and 'SETTLED' or 'EXPLORING') or 'FAILED'))
    frame:ShowWindow(1)
    if success == true then
        imcSound.PlaySoundEvent('sys_quest_message')
    end
end

function ON_ARCHEOLOGY_REWARD_VAULT_CLOSE(frame, msg, argStr, argNum)
    if frame == nil then
        frame = ui.GetFrame('archeology_reward_vault')
    end
    if frame == nil then
        return
    end
    g_archeologyRewardVaultItems = {}
    frame:SetUserValue('VAULT_STATE', 'HIDDEN')
    frame:SetUserValue('VAULT_DISPLAY', 'MINIMIZED')
    ARCHEOLOGY_REWARD_VAULT_APPLY_DISPLAY(frame, 'MINIMIZED')
    ARCHEOLOGY_REWARD_VAULT_RENDER(frame)
    frame:ShowWindow(0)
end

function ARCHEOLOGY_REWARD_VAULT_RESTORE_POSITION(frame)
    if frame == nil then return end
    local pos = ui.GetCatchMovePos(frame:GetName())
    if pos.x == 0 and pos.y == 0 then return end
    frame:MoveFrame(pos.x, pos.y)
end
