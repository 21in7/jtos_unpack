local function ARCHEOLOGY_PORTAL_TRACKER_LAYOUT_ABANDON(frame, contentHeight)
    frame:SetUserValue('TRACKER_CONTENT_HEIGHT', contentHeight)
    local button = GET_CHILD_RECURSIVELY(frame, 'abandon_button')
    if button == nil then return contentHeight end
    -- 실패 결과 뒤에도 60초 강제 퇴장을 기다리지 않고 나갈 수 있게 한다.
    -- 서버(ARCHEOLOGY_DUNGEON_PORTAL.abandon)는 클리어 보상 시작 뒤에만 포기를 막는다.
    local show = frame:GetUserValue('TRACKER_RESULT') ~= 'SUCCESS'
    button:ShowWindow(show and 1 or 0)
    button:SetMargin(240, contentHeight, 0, 0)
    -- 남은 부활 수는 포기 버튼 왼쪽 빈자리에 둔다(진행 중에만).
    local reviveText = GET_CHILD_RECURSIVELY(frame, 'revive_text')
    if reviveText ~= nil then
        local reviveMax = frame:GetUserIValue('TRACKER_REVIVE_MAX')
        local showRevive = show and reviveMax > 0 and
            frame:GetUserValue('TRACKER_RESULT') == 'None'
        if showRevive then
            local remain = math.max(0, frame:GetUserIValue('TRACKER_REVIVE_REMAIN'))
            reviveText:SetTextByKey('text', (remain <= 0 and '{#FF8A80}' or '{#CFCFCF}') ..
                ScpArgMsg('ARCHEOLOGY_TRACKER_REVIVE_REMAIN{REMAIN}{MAX}',
                    'REMAIN', remain, 'MAX', reviveMax) .. '{/}')
            reviveText:SetMargin(20, contentHeight, 0, 0)
        end
        reviveText:ShowWindow(showRevive and 1 or 0)
    end
    return contentHeight + (show and 38 or 0)
end

function ARCHEOLOGY_PORTAL_TRACKER_ON_INIT(addon, frame)
    addon:RegisterMsg('GAME_START', 'ARCHEOLOGY_PORTAL_TRACKER_RESTORE_POSITION')
    addon:RegisterMsg('ARCHEOLOGY_PORTAL_TRACKER_UPDATE', 'ON_ARCHEOLOGY_PORTAL_TRACKER_UPDATE')
    addon:RegisterMsg('ARCHEOLOGY_PORTAL_TRACKER_RESULT', 'ON_ARCHEOLOGY_PORTAL_TRACKER_RESULT')
    addon:RegisterMsg('ARCHEOLOGY_PORTAL_TRACKER_REWARD', 'ON_ARCHEOLOGY_PORTAL_TRACKER_REWARD')
    addon:RegisterMsg('ARCHEOLOGY_PORTAL_TRACKER_CLOSE', 'ON_ARCHEOLOGY_PORTAL_TRACKER_CLOSE')
    addon:RegisterMsg('ARCHEOLOGY_PORTAL_ECOLOGY_CUE', 'ON_ARCHEOLOGY_PORTAL_ECOLOGY_CUE')
    addon:RegisterMsg('ARCHEOLOGY_NEBULAS_STATE', 'ON_ARCHEOLOGY_NEBULAS_STATE')

    ARCHEOLOGY_PORTAL_TRACKER_ENSURE_DEFENSE_CONTROLS(frame)
    ARCHEOLOGY_PORTAL_TRACKER_ENSURE_NEBULAS_CONTROLS(frame)
    local _, _, ecologyGauge1, _, ecologyGauge2 =
        ARCHEOLOGY_PORTAL_TRACKER_ENSURE_ECOLOGY_CONTROLS(frame)

    local progressGauge = GET_CHILD_RECURSIVELY(frame, 'progress_gauge')
    if progressGauge ~= nil then
        tolua.cast(progressGauge, 'ui::CGauge')
        progressGauge:AddStat('%v/%m')
        progressGauge:SetStatFont(0, 'white_14_ol')
        progressGauge:SetStatAlign(0, ui.CENTER_HORZ, ui.CENTER_VERT)
    end
    local ecologyGauges = { ecologyGauge1, ecologyGauge2 }
    for gaugeIndex = 1, #ecologyGauges do
        local ecologyGauge = ecologyGauges[gaugeIndex]
        if ecologyGauge ~= nil then
            tolua.cast(ecologyGauge, 'ui::CGauge')
            ecologyGauge:AddStat('%v/%m')
            ecologyGauge:SetStatFont(0, 'white_12_ol')
            ecologyGauge:SetStatAlign(
                0, ui.CENTER_HORZ, ui.CENTER_VERT)
        end
    end

    frame:SetUserValue('TRACKER_MODE', 'None')
    frame:SetUserValue('TRACKER_RESULT', 'None')
    frame:SetUserValue('TRACKER_REWARD', 'None')
    frame:SetUserValue('TRACKER_GENERATION', 0)
    frame:ShowWindow(0)
end

local function ARCHEOLOGY_PORTAL_TRACKER_GET_MODE_INFO(mode)
    if mode == 'EXTERMINATION' then
        return ClMsg('ARCHEOLOGY_TRACKER_MODE_EXTERMINATION'),
            ClMsg('ARCHEOLOGY_TRACKER_OBJECTIVE_EXTERMINATION'), 'E7B85A'
    elseif mode == 'DEFENSE' then
        return ClMsg('ARCHEOLOGY_TRACKER_MODE_DEFENSE'),
            ClMsg('ARCHEOLOGY_TRACKER_OBJECTIVE_DEFENSE'), '67D7FF'
    elseif mode == 'REINFORCEMENT' then
        return ClMsg('ARCHEOLOGY_TRACKER_MODE_SEAL'),
            ClMsg('ARCHEOLOGY_TRACKER_OBJECTIVE_SEAL'), 'FF8A65'
    end
    return ClMsg('ARCHEOLOGY_TRACKER_MODE_DEFAULT'),
        ClMsg('ARCHEOLOGY_TRACKER_OBJECTIVE_DEFAULT'), 'FFFFFF'
end

local function ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(ctrl, text, tooltip)
    if ctrl == nil then
        return
    end
	ctrl:SetTextByKey('text', text or '')
    if tooltip ~= nil then
        ctrl:SetTextTooltip(tooltip)
    end
end

local function ARCHEOLOGY_PORTAL_TRACKER_FORMAT_ECOLOGY_ROW(token)
    if token == nil or token == '' or token == 'None' then
        return ''
    end
    local values = StringSplit(token, '|')
    if values == nil or #values < 4 then
        return ''
    end
    if values[1] == 'LAIMA' and #values >= 11 then
        local function formatProphecy(
                key, state, value, target, chainCount, chainRemainingSec)
            value = math.max(0, tonumber(value) or 0)
            target = math.max(1, tonumber(target) or 1)
            chainCount = math.max(0, tonumber(chainCount) or 0)
            chainRemainingSec =
                math.max(0, tonumber(chainRemainingSec) or 0)
			local stateText = ClMsg(state == 'SUCCESS' and
				'ARCHEOLOGY_TRACKER_STATE_SUCCESS' or (state == 'FAILED' and
				'ARCHEOLOGY_TRACKER_STATE_FAILED' or 'ARCHEOLOGY_TRACKER_STATE_ACTIVE'))
            local shortText = nil
            local description = nil
            if key == 'SPRINT' then
				shortText = ScpArgMsg('ARCHEOLOGY_TRACKER_PROPHECY_SPRINT{VALUE}{TARGET}',
					'VALUE', value, 'TARGET', target)
				description = ScpArgMsg('ARCHEOLOGY_TRACKER_PROPHECY_SPRINT_TOOLTIP{TARGET}',
					'TARGET', target)
            elseif key == 'UNYIELDING' then
                if state == 'SUCCESS' then
					shortText = ClMsg('ARCHEOLOGY_TRACKER_PROPHECY_UNYIELDING_SUCCESS')
                elseif state == 'FAILED' then
					shortText = ClMsg('ARCHEOLOGY_TRACKER_PROPHECY_UNYIELDING_FAILED')
                else
					shortText = ClMsg('ARCHEOLOGY_TRACKER_PROPHECY_UNYIELDING_ACTIVE')
				end
				description = ClMsg('ARCHEOLOGY_PROPHECY_UNYIELDING_DESC')
            elseif key == 'CHAIN' then
                if state == 'ACTIVE' and chainCount > 0 then
					shortText = ScpArgMsg(
						'ARCHEOLOGY_TRACKER_PROPHECY_CHAIN_ACTIVE{COUNT}{TARGET}{REMAIN}',
						'COUNT', chainCount, 'TARGET', target, 'REMAIN', chainRemainingSec)
				else
					shortText = ScpArgMsg(
						'ARCHEOLOGY_TRACKER_PROPHECY_CHAIN{VALUE}{TARGET}',
						'VALUE', value, 'TARGET', target)
				end
				description = ScpArgMsg('ARCHEOLOGY_TRACKER_PROPHECY_CHAIN_TOOLTIP{TARGET}',
					'TARGET', target)
            elseif key == 'DUEL' then
				shortText = ScpArgMsg('ARCHEOLOGY_TRACKER_PROPHECY_DUEL{VALUE}{TARGET}',
					'VALUE', value, 'TARGET', target)
				description = ScpArgMsg('ARCHEOLOGY_TRACKER_PROPHECY_DUEL_TOOLTIP{TARGET}',
					'TARGET', target)
            elseif key == 'CLOSURE' then
				shortText = ScpArgMsg('ARCHEOLOGY_TRACKER_PROPHECY_CLOSURE{VALUE}{TARGET}',
					'VALUE', value, 'TARGET', target)
				description = ClMsg('ARCHEOLOGY_PROPHECY_CLOSURE_DESC')
            elseif key == 'GUARD' then
				shortText = ScpArgMsg('ARCHEOLOGY_TRACKER_PROPHECY_GUARD{VALUE}{TARGET}',
					'VALUE', value, 'TARGET', target)
				description = ScpArgMsg('ARCHEOLOGY_TRACKER_PROPHECY_GUARD_TOOLTIP{TARGET}',
					'TARGET', target)
            elseif key == 'BLOCKADE' then
				shortText = ScpArgMsg('ARCHEOLOGY_TRACKER_PROPHECY_BLOCKADE{VALUE}{TARGET}',
					'VALUE', value, 'TARGET', target)
				description = ClMsg('ARCHEOLOGY_PROPHECY_BLOCKADE_DESC')
            elseif key == 'SEAL_LINK' then
				shortText = ScpArgMsg('ARCHEOLOGY_TRACKER_PROPHECY_SEAL{VALUE}{TARGET}',
					'VALUE', value, 'TARGET', target)
				description = ScpArgMsg('ARCHEOLOGY_TRACKER_PROPHECY_SEAL_TOOLTIP{TARGET}',
					'TARGET', target)
            elseif key == 'GROWTH_LINK' then
				shortText = ScpArgMsg('ARCHEOLOGY_TRACKER_PROPHECY_GROWTH{VALUE}{TARGET}',
					'VALUE', value, 'TARGET', target)
				description = ClMsg('ARCHEOLOGY_PROPHECY_GROWTH_DESC')
            elseif key == 'RECORD_LINK' then
				shortText = ScpArgMsg('ARCHEOLOGY_TRACKER_PROPHECY_RECORD{VALUE}{TARGET}',
					'VALUE', value, 'TARGET', target)
				description = ScpArgMsg('ARCHEOLOGY_TRACKER_PROPHECY_RECORD_TOOLTIP{TARGET}',
					'TARGET', target)
            elseif key == 'RESONANCE_LINK' then
				shortText = ScpArgMsg('ARCHEOLOGY_TRACKER_PROPHECY_RESONANCE{VALUE}{TARGET}',
					'VALUE', value, 'TARGET', target)
				description = ClMsg('ARCHEOLOGY_PROPHECY_RESONANCE_DESC')
            elseif key == 'RAGE_LINK' then
				shortText = ScpArgMsg('ARCHEOLOGY_TRACKER_PROPHECY_RAGE{VALUE}{TARGET}',
					'VALUE', value, 'TARGET', target)
				description = ScpArgMsg('ARCHEOLOGY_TRACKER_PROPHECY_RAGE_TOOLTIP{TARGET}',
					'TARGET', target)
            else
				shortText = ScpArgMsg('ARCHEOLOGY_TRACKER_PROPHECY_DEFAULT{VALUE}{TARGET}',
					'VALUE', value, 'TARGET', target)
				description = ClMsg('ARCHEOLOGY_TRACKER_PROPHECY_DEFAULT_TOOLTIP')
            end
            if state == 'SUCCESS' then
                if key ~= 'UNYIELDING' then
					shortText = ScpArgMsg('ARCHEOLOGY_TRACKER_STATE_PREFIX_SUCCESS{TEXT}', 'TEXT', shortText)
                end
            elseif state == 'FAILED' then
                if key ~= 'UNYIELDING' then
					shortText = ScpArgMsg('ARCHEOLOGY_TRACKER_STATE_PREFIX_FAILED{TEXT}', 'TEXT', shortText)
                end
            end
            local color = state == 'SUCCESS' and '8FFFA8' or
                (state == 'FAILED' and 'FF8F8F' or 'CDB8FF')
			return '{#' .. color .. '}' .. shortText .. '{/}',
				ScpArgMsg('ARCHEOLOGY_TRACKER_TOOLTIP_STATE{DESC}{STATE}',
					'DESC', description, 'STATE', stateText)
        end
        local first, firstDescription = formatProphecy(
            values[2], values[3], values[4], values[5],
            values[12], values[13])
        local second, secondDescription = formatProphecy(
            values[6], values[7], values[8], values[9],
            values[12], values[13])
        return ScpArgMsg('ARCHEOLOGY_TRACKER_PROPHECY_PAIR{FIRST}{SECOND}',
                'FIRST', first, 'SECOND', second),
            ScpArgMsg('ARCHEOLOGY_TRACKER_PROPHECY_PAIR_TOOLTIP{FIRST}{SECOND}',
                'FIRST', firstDescription, 'SECOND', secondDescription)
    elseif values[1] == 'CURSE_TRIAL' then
        local progressRate = math.max(0, math.min(100, tonumber(values[2]) or 0))
        local secured = math.max(0, tonumber(values[3]) or 0)
        local total = math.max(1, tonumber(values[4]) or 1)
		return ScpArgMsg('ARCHEOLOGY_TRACKER_CURSE_TRIAL{SECURED}{TOTAL}{RATE}',
			'SECURED', secured, 'TOTAL', total, 'RATE', progressRate)
    elseif values[1] == 'RECORD' then
        local state = values[2] or 'WAITING'
        local killCount = math.max(0, tonumber(values[3]) or 0)
        local remainSec = math.max(0, tonumber(values[5]) or 0)
        local tier = math.max(1, tonumber(values[6]) or 1)
        local alive = math.max(0, tonumber(values[7]) or 0)
        local spawned = math.max(0, tonumber(values[8]) or 0)
        local bossName = values[9] or 'None'
        local relicChance = math.max(0, tonumber(values[11]) or 0)
        local tooltip = ScpArgMsg('ARC_PORTAL_TOOLTIP_RULE_RELIC_INCENSE')
        if state == 'WAITING' then
            return ClMsg('ARCHEOLOGY_TRACKER_RECORD_WAITING'), tooltip
        elseif state == 'RECORDING' then
            return ScpArgMsg(
                'ARCHEOLOGY_TRACKER_RECORD_RECORDING{KILLS}{REMAIN}{TIER}',
                'KILLS', killCount, 'REMAIN', remainSec,
                'TIER', tier), tooltip
        elseif state == 'FINALE_ARMED' then
            return ScpArgMsg(
                'ARCHEOLOGY_TRACKER_RECORD_ARMED{KILLS}{TIER}',
                'KILLS', killCount, 'TIER', tier), tooltip
        elseif state == 'REPLAYING' then
            return ScpArgMsg(
                'ARCHEOLOGY_TRACKER_RECORD_REPLAYING{BOSS}{ALIVE}{TOTAL}{RELIC}{REMAIN}',
                'BOSS', bossName, 'ALIVE', alive, 'TOTAL', spawned,
                'RELIC', relicChance, 'REMAIN', remainSec), tooltip
        elseif state == 'COMPLETE' then
            return ScpArgMsg('ARCHEOLOGY_TRACKER_RECORD_COMPLETE{TIER}',
                'TIER', tier), tooltip
        elseif state == 'FAILED' then
            return ClMsg('ARCHEOLOGY_TRACKER_RECORD_FAILED'), tooltip
        end
        return ''
    elseif values[1] == 'RESONANCE' then
        local state = values[2] or 'READY'
        local total = math.max(1, tonumber(values[3]) or 3)
        local remaining = math.max(0, tonumber(values[4]) or total)
        local broken = math.max(0, tonumber(values[5]) or 0)
        local alive = math.max(0, tonumber(values[6]) or 0)
        local defeated = math.max(0, tonumber(values[8]) or 0)
        local rewardSecured = math.max(
            0, math.min(1, tonumber(values[9]) or 0))
        if state == 'READY' then
            return ClMsg('ARCHEOLOGY_TRACKER_RESONANCE_READY')
        elseif state == 'ACTIVE' or state == 'PARTIAL' then
            return ScpArgMsg('ARCHEOLOGY_TRACKER_RESONANCE_ACTIVE{BROKEN}{TOTAL}{REMAIN}{ALIVE}',
                'BROKEN', broken, 'TOTAL', total, 'REMAIN', remaining, 'ALIVE', alive)
        elseif state == 'SHARDS_BROKEN' then
            return ScpArgMsg('ARCHEOLOGY_TRACKER_RESONANCE_SHARDS_BROKEN{ALIVE}{DEFEATED}{TOTAL}',
                'ALIVE', alive, 'DEFEATED', defeated, 'TOTAL', total)
        elseif state == 'COMPLETED' then
            return ClMsg(rewardSecured == 1 and
                'ARCHEOLOGY_TRACKER_RESONANCE_COMPLETE_REWARD' or
                'ARCHEOLOGY_TRACKER_RESONANCE_COMPLETE')
        elseif state == 'FAILED' then
            return ClMsg('ARCHEOLOGY_TRACKER_RESONANCE_FAILED')
        elseif state == 'CLEANUP' then
            return ''
        end
        return ClMsg('ARCHEOLOGY_TRACKER_RESONANCE_CHECKING')
    elseif values[1] == 'RAGE' then
        local state = values[2] or 'WAITING'
        local stack = math.max(0, tonumber(values[5]) or 0)
        local maxStack = math.max(1, tonumber(values[6]) or 15)
        local bonusDropCount = math.max(0, tonumber(values[7]) or 0)
        if state == 'CHARGING' then
            return ScpArgMsg('ARCHEOLOGY_TRACKER_RAGE_CHARGING{STACK}{MAX}',
                'STACK', stack, 'MAX', maxStack)
        elseif state == 'RELEASED' then
            return ScpArgMsg('ARCHEOLOGY_TRACKER_RAGE_RELEASED{STACK}{MAX}{BONUS}',
                'STACK', stack, 'MAX', maxStack, 'BONUS', bonusDropCount)
        elseif state == 'FAILED' then
            return ClMsg('ARCHEOLOGY_TRACKER_RAGE_FAILED')
        elseif state == 'CLEANUP' then
            return ''
        end
        return ClMsg('ARCHEOLOGY_TRACKER_RAGE_WAITING')
    elseif values[1] == 'COLONY_SUMMARY' then
        local stage = math.max(0, tonumber(values[2]) or 0)
        local total = math.max(1, tonumber(values[3]) or 4)
        local gauge = math.max(0, tonumber(values[4]) or 0)
        local maxGauge = math.max(1, tonumber(values[5]) or 32)
        return ScpArgMsg('ARCHEOLOGY_TRACKER_COLONY_SUMMARY{STAGE}{TOTAL}',
            'STAGE', stage, 'TOTAL', total)
    elseif values[1] == 'COLONY' then
        local state = values[2] or 'READY'
        local stage = math.max(0, tonumber(values[3]) or 0)
        local total = math.max(1, tonumber(values[4]) or 4)
        local gauge = math.max(0, tonumber(values[5]) or 0)
        local alive = math.max(0, tonumber(values[6]) or 0)
        local spawned = math.max(0, tonumber(values[7]) or 0)
        local maxGauge = math.max(1, tonumber(values[8]) or 32)
        local rewardTier = math.max(0, tonumber(values[9]) or 0)
        local nextThreshold = math.max(0, tonumber(values[10]) or 0)
        local waveLabel = values[11] or ClMsg('ARCHEOLOGY_TRACKER_COLONY_WAVE_DEFAULT')
        local failureReason = values[12] or 'UNKNOWN'
        if state == 'READY' then
            return ClMsg('ARCHEOLOGY_TRACKER_COLONY_READY')
        elseif state == 'GROWING' then
            if alive > 0 then
                return ScpArgMsg('ARCHEOLOGY_TRACKER_COLONY_GROWING_ALIVE{STAGE}{TOTAL}{ALIVE}',
                    'STAGE', stage, 'TOTAL', total, 'ALIVE', alive)
            end
            return ScpArgMsg('ARCHEOLOGY_TRACKER_COLONY_GROWING{STAGE}{TOTAL}',
                'STAGE', stage, 'TOTAL', total)
        elseif state == 'SATURATED' then
            if alive <= 0 and (failureReason == 'CREATE_NPC_FAILED' or
                    failureReason == 'PLAYER_CONTEXT_MISSING') then
                return ClMsg('ARCHEOLOGY_TRACKER_COLONY_RECOVERING')
            end
            return ScpArgMsg('ARCHEOLOGY_TRACKER_COLONY_SATURATED{ALIVE}', 'ALIVE', alive)
        elseif state == 'LOOT_READY' then
            return ClMsg('ARCHEOLOGY_TRACKER_COLONY_LOOT_READY')
        elseif state == 'CLAIMED' then
            return ClMsg('ARCHEOLOGY_TRACKER_COLONY_CLAIMED')
        elseif state == 'FAILED' then
            if failureReason == 'NO_VALID_POSITION' then
                return ClMsg('ARCHEOLOGY_TRACKER_COLONY_FAIL_POSITION')
            elseif failureReason == 'CREATE_NPC_FAILED' then
                return ClMsg('ARCHEOLOGY_TRACKER_COLONY_FAIL_CREATE')
            elseif failureReason == 'CORE_NOT_FOUND' then
                return ClMsg('ARCHEOLOGY_TRACKER_COLONY_FAIL_CORE')
            elseif failureReason == 'PLAYER_CONTEXT_MISSING' then
                return ClMsg('ARCHEOLOGY_TRACKER_COLONY_FAIL_PLAYER')
            end
            return ClMsg('ARCHEOLOGY_TRACKER_COLONY_FAIL_UNKNOWN')
        end
    elseif values[1] == 'OVEREXCAVATION' then
        local state = values[2]
        local activationRate = math.max(1, tonumber(values[4]) or 25)
        local rewardCount = math.max(1, tonumber(values[5]) or 4)
        local siteIndex = math.max(0, tonumber(values[6]) or 0)
        local siteTotal = math.max(1, tonumber(values[7]) or 3)
        local closed = math.max(0, tonumber(values[8]) or 0)
        local alive = math.max(0, tonumber(values[9]) or 0)
        local spawned = math.max(0, tonumber(values[10]) or 0)
        local phase = values[11] or 'WAITING'
        local missRate = math.max(activationRate + 1, tonumber(values[12]) or 75)
        local profileLabelKey = values[13]
        if profileLabelKey == nil or
                string.match(profileLabelKey, '^ARCHEOLOGY_FISSURE_[A-Z0-9_]+$') == nil then
            profileLabelKey = 'ARCHEOLOGY_TRACKER_OVEREX_PROFILE_DEFAULT'
        end
        local profileLabel = ClMsg(profileLabelKey)
        local waveIndex = math.max(0, tonumber(values[14]) or 0)
        local waveTotal = math.max(1, tonumber(values[15]) or 1)
        if state == 'WAITING' then
            return ScpArgMsg('ARCHEOLOGY_TRACKER_OVEREX_WAITING{RATE}',
                'RATE', activationRate)
        elseif state == 'PENDING' then
            return ClMsg('ARCHEOLOGY_TRACKER_OVEREX_PENDING')
        elseif state == 'AVAILABLE' then
            return ScpArgMsg('ARCHEOLOGY_TRACKER_OVEREX_AVAILABLE{RATE}',
                'RATE', missRate)
        elseif state == 'ACTIVE' then
            if phase == 'OPENING' then
                return ScpArgMsg(
                    'ARCHEOLOGY_TRACKER_OVEREX_OPENING{SITE}{TOTAL}{WAVE}{WAVETOTAL}{PROFILE}',
                    'SITE', siteIndex, 'TOTAL', siteTotal, 'WAVE', waveIndex,
                    'WAVETOTAL', waveTotal, 'PROFILE', profileLabel)
            elseif phase == 'COMBAT' then
                return ScpArgMsg(
                    'ARCHEOLOGY_TRACKER_OVEREX_COMBAT{SITE}{TOTAL}{WAVE}{WAVETOTAL}{PROFILE}{ALIVE}{SPAWNED}',
                    'SITE', siteIndex, 'TOTAL', siteTotal, 'WAVE', waveIndex,
                    'WAVETOTAL', waveTotal, 'PROFILE', profileLabel,
                    'ALIVE', alive, 'SPAWNED', spawned)
            elseif phase == 'INTERMISSION' then
                return ScpArgMsg(
                    'ARCHEOLOGY_TRACKER_OVEREX_INTERMISSION{SITE}{TOTAL}{WAVE}{WAVETOTAL}',
                    'SITE', siteIndex, 'TOTAL', siteTotal,
                    'WAVE', waveIndex, 'WAVETOTAL', waveTotal)
            elseif phase == 'SEALING' then
                return ScpArgMsg('ARCHEOLOGY_TRACKER_OVEREX_SEALING{CLOSED}{TOTAL}',
                    'CLOSED', closed, 'TOTAL', siteTotal)
            elseif phase == 'NEXT' then
                return ScpArgMsg('ARCHEOLOGY_TRACKER_OVEREX_NEXT{CLOSED}{TOTAL}',
                    'CLOSED', closed, 'TOTAL', siteTotal)
            elseif phase == 'WAITING_PROGRESS' then
                local nextRate = math.max(25,
                    math.min(75, (closed + 1) * 25))
                return ScpArgMsg(
                    'ARCHEOLOGY_TRACKER_OVEREX_WAIT_PROGRESS{CLOSED}{TOTAL}{RATE}',
                    'CLOSED', closed, 'TOTAL', siteTotal, 'RATE', nextRate)
            end
            return ScpArgMsg('ARCHEOLOGY_TRACKER_OVEREX_ACTIVE{CLOSED}{TOTAL}',
                'CLOSED', closed, 'TOTAL', siteTotal)
        elseif state == 'CLEARED' then
            return ScpArgMsg('ARCHEOLOGY_TRACKER_OVEREX_CLEARED{COUNT}',
                'COUNT', rewardCount)
        elseif state == 'MISSED' then
            return ClMsg('ARCHEOLOGY_TRACKER_OVEREX_MISSED')
        end
    end
    return ''
end

local function ARCHEOLOGY_PORTAL_TRACKER_GET_ECOLOGY_PROGRESS_RATE(token)
    if token == nil then
        return -1
    end
    local values = StringSplit(token, '|')
    if values == nil or #values < 2 then
        return -1
    end
    if values[1] == 'CURSE_TRIAL' then
        return math.max(0, math.min(100, tonumber(values[2]) or 0))
    elseif values[1] == 'OVEREXCAVATION' and #values >= 3 then
        return math.max(0, math.min(100, tonumber(values[3]) or 0))
    elseif values[1] == 'RECORD' and #values >= 14 then
        return math.max(0, math.min(100, tonumber(values[14]) or 0))
    elseif values[1] == 'RAGE' and #values >= 8 then
        return math.max(0, math.min(100, tonumber(values[8]) or 0))
    elseif values[1] == 'COLONY' and #values >= 13 then
        return math.max(0, math.min(100, tonumber(values[13]) or 0))
    elseif values[1] == 'RESONANCE' and #values >= 10 then
        return math.max(0, math.min(100, tonumber(values[10]) or 0))
    end
    return -1
end

-- Groupboxes built from the XML frame keep the default scrollbar, so a row
-- whose text wraps past the group height shows a scrollbar on the tracker.
-- The tracker resizes itself to fit its content, so no group ever scrolls.
function ARCHEOLOGY_PORTAL_TRACKER_DISABLE_SCROLLBAR(group)
    if group == nil then
        return
    end
    group = tolua.cast(group, 'ui::CGroupBox')
    if group ~= nil then
        group:EnableScrollBar(0)
    end
end

function ARCHEOLOGY_PORTAL_TRACKER_ENSURE_DEFENSE_CONTROLS(frame)
    if frame == nil then
        return nil, nil, nil
    end
    local defenseGroup = GET_CHILD_RECURSIVELY(frame, 'defense_group')
    local defenseText = GET_CHILD_RECURSIVELY(frame, 'defense_text')
    local defenseGauge = GET_CHILD_RECURSIVELY(frame, 'defense_gauge')
    if defenseGroup ~= nil and defenseText ~= nil and defenseGauge ~= nil then
        ARCHEOLOGY_PORTAL_TRACKER_DISABLE_SCROLLBAR(defenseGroup)
        return defenseGroup, defenseText, defenseGauge
    end

    -- A running development client may still hold an older XML frame whose
    -- defense child controls were not instantiated. Rebuild them in place so
    -- tracker updates remain safe without requiring a full client restart.
    local background = GET_CHILD_RECURSIVELY(frame, 'background')
    if background == nil then
        return nil, nil, nil
    end
    defenseGroup = background:CreateOrGetControl('groupbox', 'defense_group',
        20, 88, 330, 42)
    defenseGroup = tolua.cast(defenseGroup, 'ui::CGroupBox')
    defenseGroup:SetSkinName('None')
    defenseGroup:EnableScrollBar(0)
    defenseGroup:EnableHitTest(0)

    defenseText = defenseGroup:CreateOrGetControl('richtext', 'defense_text',
        0, 0, 330, 20)
    defenseText = tolua.cast(defenseText, 'ui::CRichText')
    defenseText:SetFontName('white_14_b_ol')
    defenseText:SetTextFixWidth(1)
    defenseText:SetTextAlign('left', 'center')
    defenseText:EnableHitTest(0)
    defenseText:SetFormat('%s')
    defenseText:AddParamInfo('text', '')

    defenseGauge = defenseGroup:CreateOrGetControl('gauge', 'defense_gauge',
        0, 23, 330, 16)
    defenseGauge = tolua.cast(defenseGauge, 'ui::CGauge')
    defenseGauge:SetSkinName('archeology_ui_gauge_small')
    defenseGauge:EnableHitTest(0)
    defenseGroup:ShowWindow(0)
    return defenseGroup, defenseText, defenseGauge
end

function ARCHEOLOGY_PORTAL_TRACKER_ENSURE_ECOLOGY_CONTROLS(frame)
    if frame == nil then
        return nil, nil, nil, nil, nil
    end
    local ecologyGroup = GET_CHILD_RECURSIVELY(frame, 'ecology_group')
    local ecologyRow1 = GET_CHILD_RECURSIVELY(frame, 'ecology_row_1')
    local ecologyGauge1 =
        GET_CHILD_RECURSIVELY(frame, 'ecology_gauge_1')
    local ecologyRow2 = GET_CHILD_RECURSIVELY(frame, 'ecology_row_2')
    local ecologyGauge2 =
        GET_CHILD_RECURSIVELY(frame, 'ecology_gauge_2')
    if ecologyGroup ~= nil and ecologyRow1 ~= nil and
            ecologyGauge1 ~= nil and ecologyRow2 ~= nil and
            ecologyGauge2 ~= nil then
        ARCHEOLOGY_PORTAL_TRACKER_DISABLE_SCROLLBAR(ecologyGroup)
        return ecologyGroup, ecologyRow1, ecologyGauge1,
            ecologyRow2, ecologyGauge2
    end

    -- A running development client may still hold the pre-ecology XML frame.
    -- Build the five controls in Lua as a safe fallback so tracker readability
    -- does not depend on a full client restart or an XML hot reload.
    local background = GET_CHILD_RECURSIVELY(frame, 'background')
    if background == nil then
        return nil, nil, nil, nil, nil
    end
    ecologyGroup = background:CreateOrGetControl('groupbox', 'ecology_group',
        20, 88, 330, 88)
    ecologyGroup = tolua.cast(ecologyGroup, 'ui::CGroupBox')
    ecologyGroup:SetSkinName('None')
    ecologyGroup:EnableScrollBar(0)
    ecologyGroup:EnableHitTest(0)

    ecologyRow1 = ecologyGroup:CreateOrGetControl('richtext', 'ecology_row_1',
        0, 0, 330, 21)
    ecologyRow1 = tolua.cast(ecologyRow1, 'ui::CRichText')
    ecologyRow1:SetFontName('white_14_b_ol')
    ecologyRow1:SetTextFixWidth(1)
    ecologyRow1:SetTextAlign('left', 'center')
    ecologyRow1:EnableHitTest(0)
    ecologyRow1:SetFormat('%s')
    ecologyRow1:AddParamInfo('ecology_text_val', '')

    ecologyGauge1 = ecologyGroup:CreateOrGetControl(
        'gauge', 'ecology_gauge_1',
        0, 23, 330, 18)
    ecologyGauge1 = tolua.cast(ecologyGauge1, 'ui::CGauge')
    ecologyGauge1:SetSkinName('archeology_ui_gauge_small')
    ecologyGauge1:EnableHitTest(0)

    ecologyRow2 = ecologyGroup:CreateOrGetControl('richtext', 'ecology_row_2',
        0, 44, 330, 21)
    ecologyRow2 = tolua.cast(ecologyRow2, 'ui::CRichText')
    ecologyRow2:SetFontName('white_14_b_ol')
    ecologyRow2:SetTextFixWidth(1)
    ecologyRow2:SetTextAlign('left', 'center')
    ecologyRow2:EnableHitTest(0)
    ecologyRow2:SetFormat('%s')
    ecologyRow2:AddParamInfo('ecology_text_val', '')

    ecologyGauge2 = ecologyGroup:CreateOrGetControl(
        'gauge', 'ecology_gauge_2',
        0, 67, 330, 18)
    ecologyGauge2 = tolua.cast(ecologyGauge2, 'ui::CGauge')
    ecologyGauge2:SetSkinName('archeology_ui_gauge_small')
    ecologyGauge2:EnableHitTest(0)

    local legacyGauge = GET_CHILD_RECURSIVELY(frame, 'ecology_gauge')
    if legacyGauge ~= nil then
        legacyGauge:ShowWindow(0)
    end
    ecologyGroup:ShowWindow(0)
    return ecologyGroup, ecologyRow1, ecologyGauge1,
        ecologyRow2, ecologyGauge2
end

function ARCHEOLOGY_PORTAL_TRACKER_ENSURE_NEBULAS_CONTROLS(frame)
    if frame == nil then
        return nil, nil, nil, nil, nil, nil, nil
    end
    local group = GET_CHILD_RECURSIVELY(frame, 'nebulas_group')
    local phaseText = GET_CHILD_RECURSIVELY(frame, 'nebulas_phase_text')
    local rageText = GET_CHILD_RECURSIVELY(frame, 'nebulas_rage_text')
    local rageGauge = GET_CHILD_RECURSIVELY(frame, 'nebulas_rage_gauge')
    local actionText = GET_CHILD_RECURSIVELY(frame, 'nebulas_action_text')
    local actionGauge = GET_CHILD_RECURSIVELY(frame, 'nebulas_action_gauge')
    local stateText = GET_CHILD_RECURSIVELY(frame, 'nebulas_state_text')
    if group ~= nil and phaseText ~= nil and rageText ~= nil and
            rageGauge ~= nil and actionText ~= nil and
            actionGauge ~= nil and stateText ~= nil then
        ARCHEOLOGY_PORTAL_TRACKER_DISABLE_SCROLLBAR(group)
        ARCHEOLOGY_PORTAL_TRACKER_DISABLE_SCROLLBAR(
            GET_CHILD_RECURSIVELY(frame, 'nebulas_state_group'))
        return group, phaseText, rageText, rageGauge,
            actionText, actionGauge, stateText
    end

    local background = GET_CHILD_RECURSIVELY(frame, 'background')
    if background == nil then
        return nil, nil, nil, nil, nil, nil, nil
    end
    group = background:CreateOrGetControl('groupbox', 'nebulas_group',
        20, 40, 330, 158)
    group = tolua.cast(group, 'ui::CGroupBox')
    group:SetSkinName('None')
    group:EnableScrollBar(0)
    group:EnableHitTest(0)

    local function ensureText(name, y, height, fontName)
        local ctrl = group:CreateOrGetControl(
            'richtext', name, 0, y, 330, height)
        ctrl = tolua.cast(ctrl, 'ui::CRichText')
        ctrl:SetFontName(fontName)
        ctrl:SetTextFixWidth(1)
        ctrl:SetTextAlign('left', 'center')
        ctrl:EnableHitTest(0)
        ctrl:SetFormat('%s')
        ctrl:AddParamInfo('text', '')
        return ctrl
    end

    phaseText = ensureText('nebulas_phase_text', 0, 22, 'white_14_b_ol')
    rageText = ensureText('nebulas_rage_text', 25, 20, 'white_13_b_ol')
    rageGauge = group:CreateOrGetControl(
        'gauge', 'nebulas_rage_gauge', 0, 47, 330, 18)
    rageGauge = tolua.cast(rageGauge, 'ui::CGauge')
    rageGauge:SetSkinName('archeology_ui_gauge_small')
    rageGauge:EnableHitTest(0)
    actionText = ensureText('nebulas_action_text', 72, 20, 'white_13_b_ol')
    actionGauge = group:CreateOrGetControl(
        'gauge', 'nebulas_action_gauge', 0, 94, 330, 18)
    actionGauge = tolua.cast(actionGauge, 'ui::CGauge')
    actionGauge:SetSkinName('archeology_ui_gauge_small')
    actionGauge:EnableHitTest(0)

    local stateGroup = group:CreateOrGetControl(
        'groupbox', 'nebulas_state_group', 0, 120, 330, 38)
    stateGroup = tolua.cast(stateGroup, 'ui::CGroupBox')
    stateGroup:SetSkinName('None')
    stateGroup:EnableScrollBar(0)
    stateGroup:EnableHitTest(0)
    stateText = stateGroup:CreateOrGetControl(
        'richtext', 'nebulas_state_text', 0, 4, 330, 30)
    stateText = tolua.cast(stateText, 'ui::CRichText')
    stateText:SetFontName('white_14_b_ol')
    stateText:SetTextFixWidth(1)
    stateText:SetTextAlign('left', 'center')
    stateText:EnableHitTest(0)
    stateText:SetFormat('%s')
    stateText:AddParamInfo('text', '')
    group:ShowWindow(0)
    return group, phaseText, rageText, rageGauge,
        actionText, actionGauge, stateText
end

local function ARCHEOLOGY_PORTAL_TRACKER_GET_ECOLOGY_GAUGE_STATE(token)
    if token == nil or token == '' or token == 'None' then
        return 0, 1, 'FFFFFFFF'
    end
    local values = StringSplit(token, '|')
    if values == nil or #values < 2 then
        return 0, 1, 'FFFFFFFF'
    end
    local tokenType = values[1]
    local gaugePoint = 0
    local gaugeMax = 100
    local gaugeColor = 'FFFFFFFF'
    if tokenType == 'LAIMA' then
        gaugeMax = 2
        gaugePoint = math.max(0, math.min(
            gaugeMax, tonumber(values[10]) or 0))
        gaugeColor = gaugePoint >= 2 and 'FF8FFFA8' or
            (gaugePoint >= 1 and 'FFFFE082' or 'FFCDB8FF')
    elseif tokenType == 'CURSE_TRIAL' then
        gaugePoint = math.max(
            0, math.min(100, tonumber(values[2]) or 0))
        gaugeColor = 'FFFFB84D'
    elseif tokenType == 'OVEREXCAVATION' then
        local state = values[2] or 'WAITING'
        local progressRate = tonumber(values[3]) or 0
        local activationRate = tonumber(values[4]) or 25
        local siteTotal = math.max(1, tonumber(values[7]) or 3)
        local closed = math.max(0, tonumber(values[8]) or 0)
        local alive = math.max(0, tonumber(values[9]) or 0)
        local spawned = math.max(0, tonumber(values[10]) or 0)
        local phase = values[11] or 'WAITING'
        local waveIndex = math.max(0, tonumber(values[14]) or 0)
        local waveTotal = math.max(1, tonumber(values[15]) or 1)
        if state == 'WAITING' then
            gaugeMax = math.max(1, activationRate)
            gaugePoint = math.max(
                0, math.min(gaugeMax, progressRate))
            gaugeColor = 'FFB8B8B8'
        elseif state == 'PENDING' or state == 'AVAILABLE' then
            gaugePoint = 100
            gaugeColor = 'FFFFE36E'
        elseif state == 'ACTIVE' then
            closed = math.max(0, math.min(siteTotal, closed))
            gaugeMax = siteTotal * 100
            gaugePoint = closed * 100
            if phase == 'COMBAT' and spawned > 0 then
                local killed = math.max(
                    0, math.min(spawned, spawned - alive))
                local completedWaves = math.max(
                    0, math.min(waveTotal, waveIndex - 1))
                gaugePoint = gaugePoint + math.floor(
                    (completedWaves + killed / spawned) *
                    100 / waveTotal)
            elseif phase == 'INTERMISSION' or phase == 'OPENING' then
                gaugePoint = gaugePoint + math.floor(
                    math.max(0, math.min(
                        waveTotal, waveIndex - 1)) *
                    100 / waveTotal)
            end
            gaugePoint = math.max(
                0, math.min(gaugeMax, gaugePoint))
            gaugeColor = 'FFFFB84D'
        elseif state == 'CLEARED' then
            gaugePoint = 100
            gaugeColor = 'FF8FFFA8'
        elseif state == 'MISSED' then
            gaugePoint = 0
            gaugeColor = 'FF8F8F8F'
        end
    elseif tokenType == 'COLONY_SUMMARY' then
        gaugePoint = math.max(0, tonumber(values[4]) or 0)
        gaugeMax = math.max(1, tonumber(values[5]) or 32)
        gaugePoint = math.min(gaugeMax, gaugePoint)
        gaugeColor = 'FFCDA7FF'
    elseif tokenType == 'COLONY' then
        local state = values[2] or 'READY'
        local stage = tonumber(values[3]) or 0
        local total = math.max(1, tonumber(values[4]) or 4)
        local gauge = tonumber(values[5]) or 0
        local maxGauge = math.max(1, tonumber(values[8]) or 32)
        stage = math.max(0, math.min(total, stage))
        gaugeMax = maxGauge
        gaugePoint = math.max(0, math.min(maxGauge, gauge))
        local stageColors = {
            [0] = 'FF8A70C7',
            [1] = 'FFA47DFF',
            [2] = 'FFC65CFF',
            [3] = 'FFFF55D7',
            [4] = 'FFFF79E1',
        }
        gaugeColor = stageColors[stage] or 'FFCDA7FF'
        if state == 'SATURATED' then
            gaugePoint = gaugeMax
            gaugeColor = 'FFFF79E1'
        elseif state == 'LOOT_READY' then
            gaugePoint = gaugeMax
            gaugeColor = 'FFFFE36E'
        elseif state == 'CLAIMED' then
            gaugePoint = gaugeMax
            gaugeColor = 'FF8FFFA8'
        elseif state == 'FAILED' then
            gaugeColor = 'FF8F8F8F'
        end
    elseif tokenType == 'RECORD' then
        local state = values[2] or 'WAITING'
        local windowSec = math.max(1, tonumber(values[4]) or 60)
        local remainSec = math.max(0, tonumber(values[5]) or windowSec)
        local alive = math.max(0, tonumber(values[7]) or 0)
        local spawned = math.max(0, tonumber(values[8]) or 0)
        gaugeMax = windowSec
        gaugePoint = math.max(0, math.min(
            gaugeMax, windowSec - remainSec))
        gaugeColor = 'FF8FD3FF'
        if state == 'FINALE_ARMED' then
            gaugePoint = gaugeMax
            gaugeColor = 'FFFFE36E'
        elseif state == 'REPLAYING' then
            gaugeMax = math.max(1, spawned)
            gaugePoint = math.max(0, math.min(
                gaugeMax, spawned - alive))
            gaugeColor = 'FFCDA7FF'
        elseif state == 'COMPLETE' then
            gaugePoint = gaugeMax
            gaugeColor = 'FF8FFFA8'
        elseif state == 'FAILED' then
            gaugePoint = 0
            gaugeMax = 1
            gaugeColor = 'FF8F8F8F'
        end
    elseif tokenType == 'RESONANCE' then
        local state = values[2] or 'READY'
        local total = math.max(1, tonumber(values[3]) or 3)
        local broken = math.max(0, tonumber(values[5]) or 0)
        local defeated = math.max(0, tonumber(values[8]) or 0)
        gaugeMax = total * 2
        gaugePoint = math.max(
            0, math.min(gaugeMax, broken + defeated))
        gaugeColor = 'FF8FD3FF'
        if state == 'PARTIAL' or state == 'SHARDS_BROKEN' then
            gaugeColor = 'FFFFE082'
        elseif state == 'COMPLETED' then
            gaugePoint = gaugeMax
            gaugeColor = 'FF8FFFA8'
        elseif state == 'FAILED' or state == 'CLEANUP' then
            gaugeColor = 'FF8F8F8F'
        end
    elseif tokenType == 'RAGE' then
        local state = values[2] or 'WAITING'
        local stack = tonumber(values[5]) or 0
        local maxStack = math.max(1, tonumber(values[6]) or 15)
        gaugeMax = maxStack
        gaugePoint = math.max(0, math.min(gaugeMax, stack))
        gaugeColor = 'FFFF6B5F'
        if state == 'FAILED' or state == 'CLEANUP' then
            gaugeColor = 'FF8F8F8F'
        end
    end
    return gaugePoint, math.max(1, gaugeMax), gaugeColor
end

local function ARCHEOLOGY_PORTAL_TRACKER_SET_ECOLOGY(
        frame, rowToken1, rowToken2, topMargin)
    local ecologyGroup, ecologyRow1, ecologyGauge1,
        ecologyRow2, ecologyGauge2 =
        ARCHEOLOGY_PORTAL_TRACKER_ENSURE_ECOLOGY_CONTROLS(frame)
    if ecologyGroup == nil then
        return false
    end
    local rowText1, rowTooltip1 =
        ARCHEOLOGY_PORTAL_TRACKER_FORMAT_ECOLOGY_ROW(rowToken1)
    local rowText2, rowTooltip2 =
        ARCHEOLOGY_PORTAL_TRACKER_FORMAT_ECOLOGY_ROW(rowToken2)
    if rowText1 == '' and rowText2 ~= '' then
        rowToken1, rowToken2 = rowToken2, rowToken1
        rowText1, rowText2 = rowText2, rowText1
        rowTooltip1, rowTooltip2 = rowTooltip2, rowTooltip1
    end
    local row1Visible = rowText1 ~= ''
    local row2Visible = rowText2 ~= ''
    local visible = row1Visible or row2Visible
    ecologyGroup:ShowWindow(visible and 1 or 0)
    if visible ~= true then
        return false, 0
    end
    ecologyGroup:SetMargin(20, topMargin, 0, 0)
    local row1IsLaima = rowToken1 ~= nil and
        string.find(rowToken1, 'LAIMA|', 1, true) == 1
    local row2IsLaima = rowToken2 ~= nil and
        string.find(rowToken2, 'LAIMA|', 1, true) == 1

    -- Fill the text first and measure what the fixed-width richtext actually
    -- needs. Long rows (record replay names a boss) wrap to a second line, and
    -- laying out against the nominal one-line height pushed the row past the
    -- group, which is what raised the scrollbar.
    local function setRowText(row, text, tooltip, isVisible, isLaima)
        local baseHeight = isLaima and 42 or 21
        if row == nil then
            return baseHeight
        end
        row:ShowWindow(isVisible and 1 or 0)
        if isVisible ~= true then
            return baseHeight
        end
        row:SetFontName(isLaima and 'white_12_ol' or 'white_14_b_ol')
        row:EnableHitTest(isLaima and 1 or 0)
        if row:GetTextByKey('ecology_text_val') ~= (text or '') then
            row:Resize(330, baseHeight)
            row:SetTextByKey('ecology_text_val', text or '')
        end
        row:SetTextTooltip(tooltip or '')
        return math.max(baseHeight, row:GetHeight())
    end

    local row1Height = setRowText(
        ecologyRow1, rowText1, rowTooltip1, row1Visible, row1IsLaima)
    local row2Height = setRowText(
        ecologyRow2, rowText2, rowTooltip2, row2Visible, row2IsLaima)
    local gauge1Top = row1Height + 2
    local row2Top = gauge1Top + 21
    local gauge2Top = row2Top + row2Height + 2
    local ecologyHeight = row2Visible and
        gauge2Top + 21 or gauge1Top + 21
    ecologyGroup:Resize(330, ecologyHeight)

    local function placeEntry(
            row, gauge, token, isVisible, rowTop, rowHeight, gaugeTop)
        if row ~= nil and isVisible then
            row:Resize(330, rowHeight)
            row:SetMargin(0, rowTop, 0, 0)
        end
        if gauge ~= nil then
            gauge:ShowWindow(isVisible and 1 or 0)
            if isVisible then
                tolua.cast(gauge, 'ui::CGauge')
                gauge:Resize(330, 18)
                gauge:SetMargin(0, gaugeTop, 0, 0)
                local point, maxPoint, color =
                    ARCHEOLOGY_PORTAL_TRACKER_GET_ECOLOGY_GAUGE_STATE(
                        token)
                gauge:SetPoint(point, maxPoint)
                gauge:SetColorTone(color)
            end
        end
    end

    placeEntry(ecologyRow1, ecologyGauge1, rowToken1,
        row1Visible, 0, row1Height, gauge1Top)
    placeEntry(ecologyRow2, ecologyGauge2, rowToken2,
        row2Visible, row2Top, row2Height, gauge2Top)
    return true, ecologyHeight
end

function ON_ARCHEOLOGY_PORTAL_ECOLOGY_CUE(frame, msg, argStr, argNum)
    local cueText = {
        SITE = ClMsg('ARCHEOLOGY_TRACKER_CUE_OVEREX_SITE'),
        ACTIVE = ClMsg('ARCHEOLOGY_TRACKER_CUE_OVEREX_ACTIVE'),
        CLEARED = ClMsg('ARCHEOLOGY_TRACKER_CUE_OVEREX_CLEARED'),
        RECORD_STARTED = ScpArgMsg('ARC_RECORD_CUE_STARTED'),
        RECORD_FINALE = ScpArgMsg('ARC_RECORD_CUE_FINALE'),
        RECORD_REPLAY = ScpArgMsg('ARC_RECORD_CUE_REPLAY'),
        RECORD_COMPLETE = ScpArgMsg('ARC_RECORD_CUE_COMPLETE'),
        COLONY_CORE = ClMsg('ARCHEOLOGY_TRACKER_CUE_COLONY_CORE'),
        COLONY_STAGE_1 = ClMsg('ARCHEOLOGY_TRACKER_CUE_COLONY_STAGE_1'),
        COLONY_STAGE_2 = ClMsg('ARCHEOLOGY_TRACKER_CUE_COLONY_STAGE_2'),
        COLONY_STAGE_3 = ClMsg('ARCHEOLOGY_TRACKER_CUE_COLONY_STAGE_3'),
        COLONY_STAGE_4 = ClMsg('ARCHEOLOGY_TRACKER_CUE_COLONY_STAGE_4'),
        COLONY_LOOT_READY = ClMsg('ARCHEOLOGY_TRACKER_CUE_COLONY_LOOT_READY'),
        COLONY_CLAIMED = ClMsg('ARCHEOLOGY_TRACKER_CUE_COLONY_CLAIMED'),
    }
    local text = cueText[tostring(argStr)]
    if text == nil then
        return
    end
    imcSound.PlaySoundEvent('sys_quest_message')
    if NOTICE_CUSTOM ~= nil then
        NOTICE_CUSTOM(text, 'NOTICE_Dm_!')
    else
        ui.SysMsg(text)
    end
end

local function ARCHEOLOGY_PORTAL_TRACKER_SET_DEFAULT_REWARD(frame, mode, discoveryEnabled)
    if frame:GetUserValue('TRACKER_REWARD') ~= 'None' then
        return
    end

    local rewardText = GET_CHILD_RECURSIVELY(frame, 'reward_text')
    if mode == 'DEFENSE' then
        ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(rewardText,
            ClMsg('ARCHEOLOGY_TRACKER_DEFAULT_REWARD_DEFENSE'), '')
    elseif mode == 'EXTERMINATION' and discoveryEnabled == 1 then
        ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(rewardText,
            ClMsg('ARCHEOLOGY_TRACKER_DEFAULT_REWARD_EXTERMINATION'), '')
    elseif mode == 'REINFORCEMENT' then
        ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(rewardText,
            ClMsg('ARCHEOLOGY_TRACKER_DEFAULT_REWARD_SEAL'), '')
    else
        ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(rewardText, '', '')
    end
end

-- 섬멸 결과 뒤 목표 줄: 클리어 때 조사하지 않은 흔적은 서버가 봉인을 풀어(4) 결과 대기 동안 남겨 둔다.
-- 회수(3)했을 때만 완료로 쓰고, 남은 흔적(1·4)은 열라고 안내한다. 흔적이 없었으면(0 등) 목표 줄을 그대로 둔다.
local function ARCHEOLOGY_PORTAL_TRACKER_SET_RESULT_DISCOVERY(frame)
    if frame:GetUserValue('TRACKER_MODE') ~= 'EXTERMINATION' or
            frame:GetUserIValue('TRACKER_DISCOVERY_ENABLED') ~= 1 then
        return
    end
    local objective = GET_CHILD_RECURSIVELY(frame, 'objective')
    if objective == nil then
        return
    end
    local discoveryState = frame:GetUserIValue('TRACKER_DISCOVERY_STATE')
    if discoveryState == 3 then
        objective:SetTextByKey('text', ClMsg('ARCHEOLOGY_TRACKER_STATUS_DISCOVERY_COMPLETE'))
    elseif discoveryState == 1 or discoveryState == 4 then
        objective:SetTextByKey('text', ClMsg('ARCHEOLOGY_TRACKER_STATUS_DISCOVERY_REWARD'))
    end
end

local function ARCHEOLOGY_PORTAL_TRACKER_SET_STATUS(frame, mode, phase, discoveryEnabled, discoveryState,
        batchIndex, discoveryRevealed, discoveryGuardianRemain, wave, waveCount)
    local statusText = GET_CHILD_RECURSIVELY(frame, 'status_text')
    if phase == 'BOSS' then
        ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(statusText,
            ClMsg('ARCHEOLOGY_TRACKER_STATUS_BOSS'))
        return
    end

    if mode == 'EXTERMINATION' then
        if discoveryState == 2 then
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(statusText,
                ScpArgMsg('ARCHEOLOGY_TRACKER_STATUS_AMBUSH{COUNT}',
                    'COUNT', math.max(0, discoveryGuardianRemain)))
        elseif discoveryState == 4 then
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(statusText,
                ClMsg('ARCHEOLOGY_TRACKER_STATUS_DISCOVERY_REWARD'))
        elseif discoveryState == 1 then
            if discoveryRevealed == 1 then
                ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(statusText,
                    ClMsg('ARCHEOLOGY_TRACKER_STATUS_DISCOVERY_REVEALED'))
            else
                ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(statusText,
                    ClMsg('ARCHEOLOGY_TRACKER_STATUS_DISCOVERY_SEARCH'))
            end
        elseif discoveryState == 3 then
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(statusText,
                ClMsg('ARCHEOLOGY_TRACKER_STATUS_DISCOVERY_COMPLETE'))
        elseif discoveryEnabled == 1 then
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(statusText,
                ClMsg('ARCHEOLOGY_TRACKER_STATUS_DISCOVERY_NEXT'))
        else
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(statusText,
                ClMsg('ARCHEOLOGY_TRACKER_STATUS_EXTERMINATION_MOVE'))
        end
    elseif mode == 'DEFENSE' then
        if phase == 'AWAKENED' then
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(statusText,
                ClMsg('ARCHEOLOGY_TRACKER_STATUS_DEFENSE_AWAKENED'))
        elseif phase == 'WAIT' then
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(statusText,
                ClMsg('ARCHEOLOGY_TRACKER_STATUS_DEFENSE_WAIT'))
        else
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(statusText,
                ClMsg('ARCHEOLOGY_TRACKER_STATUS_DEFENSE_ACTIVE'))
        end
    elseif mode == 'REINFORCEMENT' then
        if discoveryGuardianRemain > 0 then
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(statusText,
                ScpArgMsg('ARCHEOLOGY_TRACKER_STATUS_SEAL_GUARDIAN{COUNT}',
                    'COUNT', discoveryGuardianRemain))
        elseif discoveryRevealed > wave then
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(statusText,
                ClMsg('ARCHEOLOGY_TRACKER_STATUS_SEAL_REWARD'))
        elseif wave >= waveCount then
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(statusText,
                ClMsg('ARCHEOLOGY_TRACKER_STATUS_SEAL_BOSS'))
        else
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(statusText,
                ClMsg('ARCHEOLOGY_TRACKER_STATUS_SEAL_SEARCH'))
        end
    end
end

local function ARCHEOLOGY_PORTAL_TRACKER_GET_NEBULAS_PATTERN_TEXT(patternCode)
    local messageKeys = {
        NONE = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_NONE',
        LASER = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_LASER',
        FRONT_BARRAGE = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_FRONT_BARRAGE',
        CHARGE = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_CHARGE',
        LIGHTNING = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_LIGHTNING',
        BARRAGE_360 = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_BARRAGE_360',
        BARRAGE_INNER = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_BARRAGE_INNER',
        BARRAGE_SECTOR = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_BARRAGE_SECTOR',
        BARRAGE_ROTATE = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_BARRAGE_ROTATE',
        GRAVITY_MINE = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_GRAVITY_MINE',
        BEAM_VOLLEY = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_BEAM_VOLLEY',
        RAGE_ENTER = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_RAGE_ENTER',
        PHASE_SHIFT = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_PHASE_SHIFT',
        PULSE_INNER = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_PULSE_INNER',
        PULSE_OUTER = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_PULSE_OUTER',
        SEAL_OVERLOAD = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_SEAL_OVERLOAD',
        SEAL_DIRECT = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_SEAL_DIRECT',
        RIFT_CORRIDOR = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_RIFT_CORRIDOR',
        PUNISH = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_PUNISH',
        RAGE_OPENING = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_RAGE_OPENING',
        RAGE_PUNISH = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_RAGE_PUNISH',
        EXHAUSTED = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_EXHAUSTED',
        BREAK_SUCCESS = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_BREAK_SUCCESS',
        SEAL_FAILURE = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_SEAL_FAILURE',
        PHASE_PUNISH = 'ARCHEOLOGY_NEBULAS_UI_PATTERN_PHASE_PUNISH',
    }
    return ClMsg(messageKeys[patternCode] or
        'ARCHEOLOGY_NEBULAS_UI_PATTERN_NONE')
end

local function ARCHEOLOGY_PORTAL_TRACKER_GET_NEBULAS_STATE_TEXT(stateCode)
    local messageKeys = {
        ACTIVE = 'ARCHEOLOGY_NEBULAS_UI_STATE_ACTIVE',
        CAST = 'ARCHEOLOGY_NEBULAS_UI_STATE_CAST',
        RECOVERY = 'ARCHEOLOGY_NEBULAS_UI_STATE_RECOVERY',
        GROGGY = 'ARCHEOLOGY_NEBULAS_UI_STATE_GROGGY',
        SEAL = 'ARCHEOLOGY_NEBULAS_UI_STATE_SEAL',
    }
    return ClMsg(messageKeys[stateCode] or
        'ARCHEOLOGY_NEBULAS_UI_STATE_ACTIVE')
end

-- 아래(시간 표시 구역)에서 정의한다. 네뷸라스 상태 핸들러가 먼저 쓰므로 미리 선언한다.
local ARCHEOLOGY_PORTAL_TRACKER_SET_TIME_LIMIT

local function ARCHEOLOGY_PORTAL_TRACKER_LAYOUT_NEBULAS(frame)
    local hiddenControls = {
        'nebulas_group', 'progress_text', 'progress_gauge', 'defense_group',
        'ecology_group', 'status_group', 'reward_group',
    }
    for _, name in ipairs(hiddenControls) do
        local ctrl = GET_CHILD_RECURSIVELY(frame, name)
        if ctrl ~= nil then ctrl:ShowWindow(0) end
    end

    local result = frame:GetUserValue('TRACKER_RESULT')
    local text = frame:GetUserConfig('NEBULAS_OBJECTIVE')
    if result == 'SUCCESS' then
        text = frame:GetUserConfig('NEBULAS_COMPLETE')
    elseif result ~= 'None' then
        text = ClMsg('ARCHEOLOGY_TRACKER_RESULT_FAILED')
    end
    local objective = GET_CHILD_RECURSIVELY(frame, 'objective')
    local objectiveHeight = 18
    if objective ~= nil then
        objective:ShowWindow(1)
        if objective:GetTextByKey('text') ~= text then
            objective:Resize(330, 18)
            objective:SetTextByKey('text', text)
        end
        objective:SetMargin(20, 36, 0, 0)
        objectiveHeight = math.max(18, objective:GetHeight())
    end
    frame:SetUserValue('TRACKER_OBJECTIVE_OFFSET', objectiveHeight + 4)
    frame:SetUserValue('TRACKER_ECOLOGY_HEIGHT', 0)
    local modeTitle = GET_CHILD_RECURSIVELY(frame, 'mode_title')
    if modeTitle ~= nil then
        modeTitle:SetTextByKey('color', 'CDA7FF')
        modeTitle:SetTextByKey('text', ClMsg('ARCHEOLOGY_NEBULAS_UI_TITLE'))
        modeTitle:SetTextTooltip(text)
    end
    local height = ARCHEOLOGY_PORTAL_TRACKER_LAYOUT_ABANDON(
        frame, 36 + objectiveHeight + 16)
    local background = GET_CHILD_RECURSIVELY(frame, 'background')
    if background ~= nil then background:Resize(370, height) end
    frame:Resize(370, height)
end

function ON_ARCHEOLOGY_NEBULAS_STATE(frame, msg, argStr, argNum)
    if frame == nil or argStr == nil or argStr == '' then
        return
    end
    local values = StringSplit(argStr, '#')
    if values == nil or #values < 8 then
        return
    end

    local stateCode = values[4] or 'ACTIVE'
    -- 9번째 값: 20분 제한의 남은 초(0 이하면 아직 모름 — 기존 표시 유지). 보스전에는 TRACKER_UPDATE 가 없다.
    local runRemainSec = tonumber(values[9]) or -1
    -- 처치 이후 도착하는 전투 상태가 완료 화면을 다시 열지 않도록 한다.
    if frame:GetUserValue('TRACKER_MODE') == 'BOSS_NEBULAS' and
            frame:GetUserValue('TRACKER_RESULT') ~= 'None' then
        return
    end
    if stateCode == 'HIDE' then
        return
    end

    frame:SetUserValue('TRACKER_MODE', 'BOSS_NEBULAS')
    frame:ShowWindow(1)
    if runRemainSec > 0 then
        ARCHEOLOGY_PORTAL_TRACKER_SET_TIME_LIMIT(frame, runRemainSec)
    end
    ARCHEOLOGY_PORTAL_TRACKER_LAYOUT_NEBULAS(frame)
end

local function ARCHEOLOGY_PORTAL_TRACKER_UPDATE_LAYOUT(frame, ecologyHeight)
    if frame:GetUserValue('TRACKER_MODE') == 'BOSS_NEBULAS' then
        ARCHEOLOGY_PORTAL_TRACKER_LAYOUT_NEBULAS(frame)
        return
    end
    local nebulasGroup = GET_CHILD_RECURSIVELY(frame, 'nebulas_group')
    if nebulasGroup ~= nil and nebulasGroup:IsVisible() == 1 then
        local height = ARCHEOLOGY_PORTAL_TRACKER_LAYOUT_ABANDON(
            frame, frame:GetUserIValue('TRACKER_CONTENT_HEIGHT'))
        GET_CHILD_RECURSIVELY(frame, 'background'):Resize(370, height)
        frame:Resize(370, height)
        return
    end
    if ecologyHeight ~= nil then
        frame:SetUserValue('TRACKER_ECOLOGY_HEIGHT', ecologyHeight)
    else
        ecologyHeight = frame:GetUserIValue('TRACKER_ECOLOGY_HEIGHT')
    end
    local isDefense = frame:GetUserValue('TRACKER_MODE') == 'DEFENSE'
    local statusTop = (isDefense and 134 or 88) + ecologyHeight +
        frame:GetUserIValue('TRACKER_OBJECTIVE_OFFSET')
    local showReward = frame:GetUserValue('TRACKER_REWARD') ~= 'None' or
        (isDefense and frame:GetUserValue('TRACKER_RESULT') == 'SUCCESS')
    local statusGroup = GET_CHILD_RECURSIVELY(frame, 'status_group')
    local rewardGroup = GET_CHILD_RECURSIVELY(frame, 'reward_group')
    statusGroup:SetMargin(20, statusTop, 0, 0)
    rewardGroup:SetMargin(20, statusTop + 48, 0, 0)
    rewardGroup:ShowWindow(showReward and 1 or 0)
    local height = ARCHEOLOGY_PORTAL_TRACKER_LAYOUT_ABANDON(
        frame, statusTop + 50 + (showReward and 64 or 0))
    local background = GET_CHILD_RECURSIVELY(frame, 'background')
    background:Resize(370, height)
    frame:Resize(370, height)
end

-- 모드 목표 문구를 헤더 바로 아래 한 줄(길면 두 줄)로 보인다. 그 높이만큼 진행도·방어·생태
-- 행을 아래로 내리고, 내린 양을 TRACKER_OBJECTIVE_OFFSET 에 둬 상태·보상 배치도 따라가게 한다.
local ARCHEOLOGY_PORTAL_TRACKER_OBJECTIVE_TOP = 36
local function ARCHEOLOGY_PORTAL_TRACKER_SET_OBJECTIVE(frame, text)
    local objective = GET_CHILD_RECURSIVELY(frame, 'objective')
    local offset = 0
    if objective ~= nil and text ~= nil and text ~= '' then
        objective:ShowWindow(1)
        if objective:GetTextByKey('text') ~= text then
            objective:Resize(330, 18)
            objective:SetTextByKey('text', text)
        end
        objective:SetMargin(20, ARCHEOLOGY_PORTAL_TRACKER_OBJECTIVE_TOP, 0, 0)
        offset = math.max(18, objective:GetHeight()) + 4
    elseif objective ~= nil then
        objective:ShowWindow(0)
    end
    frame:SetUserValue('TRACKER_OBJECTIVE_OFFSET', offset)

    local progressText = GET_CHILD_RECURSIVELY(frame, 'progress_text')
    local progressGauge = GET_CHILD_RECURSIVELY(frame, 'progress_gauge')
    local defenseGroup = GET_CHILD_RECURSIVELY(frame, 'defense_group')
    if progressText ~= nil then progressText:SetMargin(20, 36 + offset, 0, 0) end
    if progressGauge ~= nil then progressGauge:SetMargin(20, 61 + offset, 0, 0) end
    if defenseGroup ~= nil then defenseGroup:SetMargin(20, 88 + offset, 0, 0) end
    return offset
end

-- 탐사 제한 시간(서버 RUN_TIME_LIMIT) 카운트다운. 서버가 argNum 으로 남은 초를 보내면
-- 마감 시각을 다시 잡고, 그 사이는 클라가 스스로 센다. 0 이면 RUN 이 아니므로 숨긴다.
local ARCHEOLOGY_PORTAL_TRACKER_TIME_WARN_SEC = 300

local function ARCHEOLOGY_PORTAL_TRACKER_RENDER_TIME(frame, ctrl)
    local deadline = tonumber(frame:GetUserValue('TRACKER_RUN_DEADLINE')) or 0
    if deadline <= 0 then
        ctrl:ShowWindow(0)
        return false
    end
    local remain = math.max(0, math.floor(deadline - imcTime.GetAppTime()))
    ctrl:SetTextByKey('color', remain <= ARCHEOLOGY_PORTAL_TRACKER_TIME_WARN_SEC and 'FF6B6B' or 'FFD76A')
    ctrl:SetTextByKey('text', string.format('%02d:%02d', math.floor(remain / 60), remain % 60))
    ctrl:ShowWindow(1)
    return true
end

function ARCHEOLOGY_PORTAL_TRACKER_TIME_TICK(ctrl)
    local frame = ctrl:GetTopParentFrame()
    if frame == nil or frame:IsVisible() == 0 or
            ARCHEOLOGY_PORTAL_TRACKER_RENDER_TIME(frame, ctrl) ~= true then
        if frame ~= nil then frame:SetUserValue('TRACKER_TIME_TICKING', 0) end
        return 0
    end
    return 1
end

ARCHEOLOGY_PORTAL_TRACKER_SET_TIME_LIMIT = function(frame, remainSec)
    local timeText = GET_CHILD_RECURSIVELY(frame, 'time_text')
    if timeText == nil then
        return
    end
    remainSec = math.max(0, tonumber(remainSec) or 0)
    frame:SetUserValue('TRACKER_RUN_DEADLINE',
        remainSec > 0 and (imcTime.GetAppTime() + remainSec) or 0)
    if ARCHEOLOGY_PORTAL_TRACKER_RENDER_TIME(frame, timeText) == true and
            frame:GetUserIValue('TRACKER_TIME_TICKING') ~= 1 then
        frame:SetUserValue('TRACKER_TIME_TICKING', 1)
        timeText:RunUpdateScript('ARCHEOLOGY_PORTAL_TRACKER_TIME_TICK', 0.5)
    end
end

function ON_ARCHEOLOGY_PORTAL_TRACKER_UPDATE(frame, msg, argStr, argNum)
    if argStr == nil or argStr == '' then
        return
    end

    local values = StringSplit(argStr, '#')
    if values == nil or #values < 10 then
        return
    end

    local mode = values[1]
    local killCount = tonumber(values[2]) or 0
    local targetKills = math.max(1, tonumber(values[3]) or 1)
    local wave = tonumber(values[4]) or 0
    local waveCount = math.max(1, tonumber(values[5]) or 1)
    local chestHpRate = tonumber(values[6]) or -1
    local phase = values[7] or 'ACTIVE'
    local discoveryEnabled = tonumber(values[8]) or 0
    local discoveryState = tonumber(values[9]) or -1
    local batchIndex = tonumber(values[10]) or 0
    local runId = values[16] or 'None'
    -- 17·18: 남은 부활 / 최대 부활(구 서버 데이터면 없음 → 표시 안 함)
    frame:SetUserValue('TRACKER_REVIVE_REMAIN', tonumber(values[17]) or 0)
    frame:SetUserValue('TRACKER_REVIVE_MAX', tonumber(values[18]) or 0)
    local discoveryRevealed = tonumber(values[11]) or 0
    local discoveryGuardianRemain = tonumber(values[12]) or 0
    local ecologyRow1 = values[13] or 'None'
    local ecologyRow2 = values[14] or 'None'
    local ecologyProgressRate = ARCHEOLOGY_PORTAL_TRACKER_GET_ECOLOGY_PROGRESS_RATE(ecologyRow1)
    -- 생태 1행에 % 가 없는 종류(라이마 등)는 서버가 함께 보낸 포탈 진행도(15번째)를 쓴다.
    -- 그래서 방어·봉인 해제도 항상 「진행도 %」 형식 하나로 보인다.
    local portalProgressRate = tonumber(values[15]) or -1
    if ecologyProgressRate < 0 then
        ecologyProgressRate = portalProgressRate
    end

    local oldMode = frame:GetUserValue('TRACKER_MODE')
    local oldRunId = frame:GetUserValue('TRACKER_RUN_ID')
    if frame:GetUserValue('TRACKER_RESULT') ~= 'None' and
            oldMode == mode and oldRunId == runId then
        -- 클리어 뒤 남겨 둔 흔적을 열거나(4→3) 봉인이 풀리면(1→4) 이 갱신으로만 알 수 있다.
        frame:SetUserValue('TRACKER_DISCOVERY_STATE', discoveryState)
        if frame:GetUserValue('TRACKER_RESULT') == 'SUCCESS' then
            ARCHEOLOGY_PORTAL_TRACKER_SET_RESULT_DISCOVERY(frame)
        end
        -- 결과 뒤에도 남는 생태 목표(거대 오염 수정 등)는 조사 결과가 이 갱신으로만 오므로
        -- 진행도·상태·시간은 결과 표시를 유지하고 생태 행만 계속 갱신한다.
        if mode ~= 'BOSS_NEBULAS' then
            local hasEcology, ecologyHeight = ARCHEOLOGY_PORTAL_TRACKER_SET_ECOLOGY(
                frame, ecologyRow1, ecologyRow2,
                (mode == 'DEFENSE' and 134 or 88) +
                    frame:GetUserIValue('TRACKER_OBJECTIVE_OFFSET'))
            ARCHEOLOGY_PORTAL_TRACKER_UPDATE_LAYOUT(frame,
                hasEcology and ecologyHeight or 0)
        end
        return
    end
    ARCHEOLOGY_PORTAL_TRACKER_SET_TIME_LIMIT(frame, argNum)
    if frame:IsVisible() == 0 or oldMode ~= mode or oldRunId ~= runId then
        frame:SetUserValue('TRACKER_RESULT', 'None')
        frame:SetUserValue('TRACKER_REWARD', 'None')
        frame:SetUserValue('TRACKER_DEFENSE_HP', -1)
    end
    frame:SetUserValue('TRACKER_RUN_ID', runId)
    frame:SetUserValue('TRACKER_MODE', mode)
    -- 결과 표시에서 공세 총수를 다시 쓰므로 보관해 둔다.
    frame:SetUserValue('TRACKER_DEFENSE_WAVE_COUNT', waveCount)
    frame:SetUserValue('TRACKER_DISCOVERY_ENABLED', discoveryEnabled)
    frame:SetUserValue('TRACKER_DISCOVERY_STATE', discoveryState)

    frame:ShowWindow(1)
    local nebulasGroup = GET_CHILD_RECURSIVELY(frame, 'nebulas_group')
    if nebulasGroup ~= nil then
        nebulasGroup:ShowWindow(0)
    end
    local regularControls = { 'progress_text', 'progress_gauge', 'status_group', 'reward_group' }
    for i = 1, #regularControls do
        local ctrl = GET_CHILD_RECURSIVELY(frame, regularControls[i])
        if ctrl ~= nil then
            ctrl:ShowWindow(1)
        end
    end

    local modeName, objectiveText, modeColor = ARCHEOLOGY_PORTAL_TRACKER_GET_MODE_INFO(mode)
    -- 발견 목표가 남았을 때만(미시작 0·탐색 1·매복 2·회수 대기 4) 회수 안내를 띄운다.
    -- 완료(3) 뒤에도 남기면 생태 목표(공진 파편 등)가 남은 이유를 가린다.
    if mode == 'EXTERMINATION' and killCount >= targetKills and discoveryEnabled == 1 and
            discoveryState >= 0 and discoveryState ~= 3 then
        objectiveText = ClMsg('ARCHEOLOGY_TRACKER_OBJECTIVE_RECOVERY')
    end
    local modeTitle = GET_CHILD_RECURSIVELY(frame, 'mode_title')
    if modeTitle ~= nil then
        modeTitle:SetTextByKey('color', modeColor)
        modeTitle:SetTextByKey('text', modeName)
        modeTitle:SetTextTooltip(objectiveText)
    end
    -- 목표 문구는 툴팁만이 아니라 본문 첫 줄에도 보인다.
    local objectiveOffset = ARCHEOLOGY_PORTAL_TRACKER_SET_OBJECTIVE(frame, objectiveText)

    local progressText = GET_CHILD_RECURSIVELY(frame, 'progress_text')
    local progressGauge = GET_CHILD_RECURSIVELY(frame, 'progress_gauge')
    tolua.cast(progressGauge, 'ui::CGauge')

    local defenseGroup, defenseText, defenseGauge =
        ARCHEOLOGY_PORTAL_TRACKER_ENSURE_DEFENSE_CONTROLS(frame)
    if mode == 'DEFENSE' then
        local hasEcology, ecologyHeight =
            ARCHEOLOGY_PORTAL_TRACKER_SET_ECOLOGY(
                frame, ecologyRow1, ecologyRow2, 134 + objectiveOffset)
        ecologyHeight = hasEcology and ecologyHeight or 0
        ARCHEOLOGY_PORTAL_TRACKER_UPDATE_LAYOUT(frame, ecologyHeight)
        if defenseGroup ~= nil then
            defenseGroup:ShowWindow(1)
        end
        local finishedWave = math.max(0, wave - 1)
        if ecologyProgressRate >= 0 then
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(progressText,
                ScpArgMsg('ARCHEOLOGY_TRACKER_PROGRESS_DEFENSE_ECOLOGY{RATE}{WAVE}{TOTAL}',
                    'RATE', ecologyProgressRate, 'WAVE', math.max(1, wave), 'TOTAL', waveCount))
            progressGauge:SetPoint(ecologyProgressRate, 100)
        else
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(progressText,
                ScpArgMsg('ARCHEOLOGY_TRACKER_PROGRESS_DEFENSE{WAVE}{TOTAL}',
                    'WAVE', math.max(1, wave), 'TOTAL', waveCount))
            progressGauge:SetPoint(finishedWave, waveCount)
        end

        -- 정산 때 상자가 정리되면 서버는 -1(없음)을 보낸다. 0%로 바꾸지 않는다.
        if chestHpRate >= 0 then
            frame:SetUserValue('TRACKER_DEFENSE_HP', math.min(100, chestHpRate))
        end
        local displayHpRate = math.max(0, frame:GetUserIValue('TRACKER_DEFENSE_HP'))
        ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(defenseText,
            ScpArgMsg('ARCHEOLOGY_TRACKER_DEFENSE_HP{RATE}', 'RATE', displayHpRate))
        if defenseGauge ~= nil then
            defenseGauge:ShowWindow(1)
            defenseGauge:SetPoint(displayHpRate, 100)
            defenseGauge:SetColorTone(displayHpRate <= 30 and 'FFFF6060' or 'FFFFFFFF')
        end
    else
        local hasEcology, ecologyHeight =
            ARCHEOLOGY_PORTAL_TRACKER_SET_ECOLOGY(
                frame, ecologyRow1, ecologyRow2, 88 + objectiveOffset)
        ecologyHeight = hasEcology and ecologyHeight or 0
        ARCHEOLOGY_PORTAL_TRACKER_UPDATE_LAYOUT(frame, ecologyHeight)
        if defenseGroup ~= nil then
            defenseGroup:ShowWindow(0)
        end
        if mode == 'REINFORCEMENT' then
            local clearedSeals = math.max(0, math.min(waveCount, wave))
            local unlockedSeals = math.max(0, math.min(waveCount, discoveryRevealed))
            if ecologyProgressRate >= 0 then
                ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(progressText,
                    ScpArgMsg('ARCHEOLOGY_TRACKER_PROGRESS_SEAL_ECOLOGY{RATE}{COUNT}{TOTAL}',
                        'RATE', ecologyProgressRate, 'COUNT', clearedSeals, 'TOTAL', waveCount))
                progressGauge:SetPoint(ecologyProgressRate, 100)
            else
                ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(progressText,
                    ScpArgMsg('ARCHEOLOGY_TRACKER_PROGRESS_SEAL{UNLOCKED}{CLEARED}{TOTAL}',
                        'UNLOCKED', unlockedSeals, 'CLEARED', clearedSeals, 'TOTAL', waveCount))
                progressGauge:SetPoint(clearedSeals, waveCount)
            end
        else
            local currentKills = math.max(0, math.min(targetKills, killCount))
            -- 생태 1행 종류와 관계없이 같은 형식(포탈 진행도 %)으로 보인다. 생태 토큰에 %가 없으면
            -- 서버 UPDATE_ARCHEOLOGY_PORTAL_ECOLOGY_PROGRESS 와 같은 식(처치 ÷ 목표)으로 계산한다.
            local progressRate = ecologyProgressRate
            if progressRate < 0 then
                progressRate = targetKills > 0 and
                    math.floor(currentKills * 100 / targetKills) or 0
            end
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(progressText,
                ScpArgMsg('ARCHEOLOGY_TRACKER_PROGRESS_KILL_ECOLOGY{RATE}{COUNT}{TOTAL}',
                    'RATE', progressRate, 'COUNT', currentKills, 'TOTAL', targetKills))
            progressGauge:SetPoint(progressRate, 100)
        end
    end

    ARCHEOLOGY_PORTAL_TRACKER_SET_STATUS(frame, mode, phase, discoveryEnabled, discoveryState,
        batchIndex, discoveryRevealed, discoveryGuardianRemain, wave, waveCount)
    ARCHEOLOGY_PORTAL_TRACKER_SET_DEFAULT_REWARD(frame, mode, discoveryEnabled)
end

function ON_ARCHEOLOGY_PORTAL_TRACKER_RESULT(frame, msg, argStr, argNum)
    if argStr == nil or argStr == '' then
        return
    end

    local values = StringSplit(argStr, '#')
    if values == nil or #values < 2 then
        return
    end

    local mode = values[1]
    local result = values[2]
    ARCHEOLOGY_PORTAL_TRACKER_SET_TIME_LIMIT(frame, 0)
    frame:SetUserValue('TRACKER_MODE', mode)
    frame:SetUserValue('TRACKER_RESULT', result)
    frame:ShowWindow(1)

    local statusText = GET_CHILD_RECURSIVELY(frame, 'status_text')
    local progressGauge = GET_CHILD_RECURSIVELY(frame, 'progress_gauge')
    local progressText = GET_CHILD_RECURSIVELY(frame, 'progress_text')
    if mode == 'BOSS_NEBULAS' then
        ARCHEOLOGY_PORTAL_TRACKER_UPDATE_LAYOUT(frame, 0)
        return
    end
    tolua.cast(progressGauge, 'ui::CGauge')
    if result == 'SUCCESS' then
        ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(statusText,
            ClMsg('ARCHEOLOGY_TRACKER_RESULT_SUCCESS'))
        ARCHEOLOGY_PORTAL_TRACKER_SET_RESULT_DISCOVERY(frame)
        progressGauge:SetPoint(progressGauge:GetMaxPoint(), progressGauge:GetMaxPoint())
        -- 게이지만 채우면 진행도 문구가 마지막 갱신값(예: 「75% · 4 / 4」)으로
        -- 남아 결과와 어긋난다. 방어는 공세 표기를 유지한 채 100% 로 맞춘다.
        if mode == 'DEFENSE' then
            local defenseText = GET_CHILD_RECURSIVELY(frame, 'defense_text')
            local defenseGauge = GET_CHILD_RECURSIVELY(frame, 'defense_gauge')
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(defenseText,
                ClMsg('ARCHEOLOGY_TRACKER_DEFENSE_PRESERVED'))
            if defenseGauge ~= nil then defenseGauge:ShowWindow(0) end
            local waveCount = math.max(1, tonumber(
                frame:GetUserValue('TRACKER_DEFENSE_WAVE_COUNT')) or 1)
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(progressText,
                ScpArgMsg('ARCHEOLOGY_TRACKER_PROGRESS_DEFENSE_ECOLOGY{RATE}{WAVE}{TOTAL}',
                    'RATE', 100, 'WAVE', waveCount, 'TOTAL', waveCount))
            local rewardText = GET_CHILD_RECURSIVELY(frame, 'reward_text')
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(rewardText,
                ClMsg('ARCHEOLOGY_TRACKER_RESULT_DEFENSE_REWARD'))
        end
    else
        -- FAIL_CHEST: 상자 파괴. 부활 소진 등 다른 방어 실패는 일반 실패 문구를 쓴다.
        if mode == 'DEFENSE' and result == 'FAIL_CHEST' then
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(statusText,
                ClMsg('ARCHEOLOGY_TRACKER_RESULT_DEFENSE_FAILED'))
            -- 한 번에 큰 피해로 파괴되면 마지막 갱신값(예: 3%)이 남으므로 0%로 맞춘다.
            frame:SetUserValue('TRACKER_DEFENSE_HP', 0)
            local defenseText = GET_CHILD_RECURSIVELY(frame, 'defense_text')
            local defenseGauge = GET_CHILD_RECURSIVELY(frame, 'defense_gauge')
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(defenseText,
                ScpArgMsg('ARCHEOLOGY_TRACKER_DEFENSE_HP{RATE}', 'RATE', 0))
            if defenseGauge ~= nil then
                defenseGauge = tolua.cast(defenseGauge, 'ui::CGauge')
                defenseGauge:SetPoint(0, 100)
            end
        else
            ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(statusText,
                ClMsg('ARCHEOLOGY_TRACKER_RESULT_FAILED'))
        end
    end
    ARCHEOLOGY_PORTAL_TRACKER_UPDATE_LAYOUT(frame)
end

local function ARCHEOLOGY_PORTAL_TRACKER_GET_RARITY_INFO(rarity)
    local rarityInfo = {
        Common = { ClMsg('ARCHEOLOGY_RARITY_COMMON'), 'FFFFFF' },
        Normal = { ClMsg('ARCHEOLOGY_RARITY_COMMON'), 'FFFFFF' },
        Magic = { ClMsg('ARCHEOLOGY_RARITY_MAGIC'), '8FD7FF' },
        Rare = { ClMsg('ARCHEOLOGY_RARITY_RARE'), 'FFD76A' },
        Epic = { ClMsg('ARCHEOLOGY_RARITY_EPIC'), 'C78CFF' },
        Legendary = { ClMsg('ARCHEOLOGY_RARITY_LEGENDARY'), 'FF8A65' },
        Fallback = { ClMsg('ARCHEOLOGY_RARITY_FALLBACK'), 'FFFFFF' },
        Material = { ClMsg('ARCHEOLOGY_RARITY_MATERIAL'), 'C8E6FF' },
    }
    return rarityInfo[rarity] or { tostring(rarity or ClMsg('ARCHEOLOGY_RELIC')), 'FFFFFF' }
end

function ON_ARCHEOLOGY_PORTAL_TRACKER_REWARD(frame, msg, argStr, argNum)
    if argStr == nil or argStr == '' then
        return
    end

    local values = StringSplit(argStr, '#')
    if values == nil or #values < 5 then
        return
    end

    local itemClassName = values[1]
    local itemCount = math.max(0, tonumber(values[2]) or 0)
    local rarity = shared_archeology.get_relic_display_rarity(itemClassName, values[3])
    local shardCount = math.max(0, tonumber(values[4]) or 0)
    local rewardType = values[5]
    local itemName = itemClassName
    local itemCls = GetClass('Item', itemClassName)
    if itemCls ~= nil then
        itemName = TryGetProp(itemCls, 'Name', itemClassName)
    end

    local rewardText = GET_CHILD_RECURSIVELY(frame, 'reward_text')
    local text = ''
    if rewardType == 'BROKEN' then
        text = ScpArgMsg('ARCHEOLOGY_TRACKER_REWARD_BROKEN{ITEM}{COUNT}{SHARD}',
            'ITEM', itemName, 'COUNT', itemCount, 'SHARD', shardCount)
    elseif rewardType == 'DISCOVERY' then
        local highShardCount = math.max(0, tonumber(values[6]) or 0)
        local memoryFragmentCount = math.max(0, tonumber(values[7]) or 0)
        if highShardCount > 0 and memoryFragmentCount > 0 then
            text = ScpArgMsg(
                'ARCHEOLOGY_TRACKER_REWARD_DISCOVERY_ALL{ITEM}{COUNT}{SHARD}{HIGH}{MEMORY}',
                'ITEM', itemName, 'COUNT', itemCount, 'SHARD', shardCount,
                'HIGH', highShardCount, 'MEMORY', memoryFragmentCount)
        elseif highShardCount > 0 then
            text = ScpArgMsg(
                'ARCHEOLOGY_TRACKER_REWARD_DISCOVERY_HIGH{ITEM}{COUNT}{SHARD}{HIGH}',
                'ITEM', itemName, 'COUNT', itemCount, 'SHARD', shardCount, 'HIGH', highShardCount)
        elseif memoryFragmentCount > 0 then
            text = ScpArgMsg(
                'ARCHEOLOGY_TRACKER_REWARD_DISCOVERY_MEMORY{ITEM}{COUNT}{SHARD}{MEMORY}',
                'ITEM', itemName, 'COUNT', itemCount, 'SHARD', shardCount,
                'MEMORY', memoryFragmentCount)
        else
            text = ScpArgMsg('ARCHEOLOGY_TRACKER_REWARD_DISCOVERY{ITEM}{COUNT}{SHARD}',
                'ITEM', itemName, 'COUNT', itemCount, 'SHARD', shardCount)
        end
    elseif rewardType == 'DISCOVERY_RELIC' then
        local rarityInfo = ARCHEOLOGY_PORTAL_TRACKER_GET_RARITY_INFO(rarity)
        if shardCount > 0 then
            text = ScpArgMsg(
                'ARCHEOLOGY_TRACKER_REWARD_DISCOVERY_RELIC_BONUS{COLOR}{RARITY}{ITEM}{COUNT}{SHARD}',
                'COLOR', rarityInfo[2], 'RARITY', rarityInfo[1],
                'ITEM', itemName, 'COUNT', itemCount, 'SHARD', shardCount)
        else
            text = ScpArgMsg(
                'ARCHEOLOGY_TRACKER_REWARD_DISCOVERY_RELIC{COLOR}{RARITY}{ITEM}{COUNT}',
                'COLOR', rarityInfo[2], 'RARITY', rarityInfo[1],
                'ITEM', itemName, 'COUNT', itemCount)
        end
    else
        local rarityInfo = ARCHEOLOGY_PORTAL_TRACKER_GET_RARITY_INFO(rarity)
        if shardCount > 0 then
            text = ScpArgMsg(
                'ARCHEOLOGY_TRACKER_REWARD_RELIC_SHARD{COLOR}{RARITY}{ITEM}{COUNT}{SHARD}',
                'COLOR', rarityInfo[2], 'RARITY', rarityInfo[1],
                'ITEM', itemName, 'COUNT', itemCount, 'SHARD', shardCount)
        else
            text = ScpArgMsg(
                'ARCHEOLOGY_TRACKER_REWARD_RELIC{COLOR}{RARITY}{ITEM}{COUNT}',
                'COLOR', rarityInfo[2], 'RARITY', rarityInfo[1],
                'ITEM', itemName, 'COUNT', itemCount)
        end
    end

    frame:SetUserValue('TRACKER_REWARD', text)
    ARCHEOLOGY_PORTAL_TRACKER_SET_TEXT(rewardText, text, text)
    if frame:GetUserValue('TRACKER_MODE') ~= 'BOSS_NEBULAS' or
            frame:GetUserValue('TRACKER_RESULT') ~= 'None' then
        ARCHEOLOGY_PORTAL_TRACKER_UPDATE_LAYOUT(frame)
    end
end

function ARCHEOLOGY_PORTAL_TRACKER_ABANDON()
    local frame = ui.GetFrame('archeology_portal_tracker')
    if frame == nil or frame:IsVisible() ~= 1 or
            frame:GetUserValue('TRACKER_MODE') == 'None' or
            frame:GetUserValue('TRACKER_RESULT') == 'SUCCESS' then return end
    local yesScript = string.format('ARCHEOLOGY_PORTAL_TRACKER_ABANDON_EXEC(%d)',
        frame:GetUserIValue('TRACKER_GENERATION'))
    ui.MsgBox(frame:GetUserConfig('ABANDON_CONFIRM'), yesScript, 'None')
end

function ARCHEOLOGY_PORTAL_TRACKER_ABANDON_EXEC(generation)
    local frame = ui.GetFrame('archeology_portal_tracker')
    if frame == nil or frame:IsVisible() ~= 1 or
            frame:GetUserValue('TRACKER_MODE') == 'None' or
            frame:GetUserValue('TRACKER_RESULT') == 'SUCCESS' or
            frame:GetUserIValue('TRACKER_GENERATION') ~= generation then return end
    pc.ReqExecuteTx('SCR_ARCHEOLOGY_DUNGEON_ABANDON', 'None')
end

function ON_ARCHEOLOGY_PORTAL_TRACKER_CLOSE(frame, msg, argStr, argNum)
    ARCHEOLOGY_PORTAL_TRACKER_SET_TIME_LIMIT(frame, 0)
    frame:SetUserValue('TRACKER_GENERATION', frame:GetUserIValue('TRACKER_GENERATION') + 1)
    frame:SetUserValue('TRACKER_MODE', 'None')
    frame:SetUserValue('TRACKER_RESULT', 'None')
    frame:SetUserValue('TRACKER_REWARD', 'None')
    frame:SetUserValue('TRACKER_REVIVE_MAX', 0)
    frame:ShowWindow(0)
end

function ARCHEOLOGY_PORTAL_TRACKER_RESTORE_POSITION(frame)
    if frame == nil then return end
    local pos = ui.GetCatchMovePos(frame:GetName())
    if pos.x == 0 and pos.y == 0 then return end
    frame:MoveFrame(pos.x, pos.y)
end
