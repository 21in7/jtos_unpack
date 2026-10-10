-- archeology_tooltip.lua

local function ARC_META_IS_EMPTY(meta)
    return meta == nil or meta == "" or meta == "None"
end

local function ARC_MERGE_META(prefixMeta, suffixMeta)
    local hasPrefix = not ARC_META_IS_EMPTY(prefixMeta)
    local hasSuffix = not ARC_META_IS_EMPTY(suffixMeta)

    if hasPrefix and hasSuffix then
        return prefixMeta .. "," .. suffixMeta
    end
    if hasPrefix then
        return prefixMeta
    end
    if hasSuffix then
        return suffixMeta
    end
    return "None"
end

local function ARC_SPLIT_NAME_TAG(baseName)
    if baseName == nil then
        return "", ""
    end

    local tag = string.match(baseName, "^(%[[^%]]+%])%s*")
    if tag == nil then
        return "", baseName
    end

    local name = string.sub(baseName, string.len(tag) + 1)
    name = string.gsub(name, "^%s+", "")
    return tag, name
end

local function ARC_PICK_AFFIX_MSG(meta, affixType)
    if ARC_META_IS_EMPTY(meta) then
        return nil
    end

    local optionInfo = GET_ARCHEOLOGY_OPTION_INFO(meta)
    local bestMsg = nil
    local bestGrade = -1

    for _, opt in ipairs(optionInfo) do
        local isMatch = opt.type == affixType
        if affixType == "Prefix" and opt.type == "Exclusive" then
            isMatch = true
        elseif affixType == "Suffix" and opt.type == "AmplifierOnly" then
            isMatch = true
        end

        if isMatch == true then
            local msg = opt.affixNameMsg
            local grade = tonumber(opt.grade) or 0
            if msg ~= nil and msg ~= "" and msg ~= "None" and grade > bestGrade then
                bestMsg = msg
                bestGrade = grade
            end
        end
    end

    if bestMsg == nil then
        return nil
    end

    local text = ClMsg(bestMsg)
    if text == nil or text == "" then
        return nil
    end
    return text
end

local function GET_ARCHEOLOGY_AFFIX_ITEM_NAME(invitem)
    local baseName = TranslateDicID(GET_FULL_NAME(invitem, true))
    local itemTag, itemName = ARC_SPLIT_NAME_TAG(baseName)
    local prefixMeta = TryGetProp(invitem, "Arc_Prefix", "None")
    local suffixMeta = TryGetProp(invitem, "Arc_Suffix", "None")
    local affixMeta = ARC_MERGE_META(prefixMeta, suffixMeta)
    local prefixName = ARC_PICK_AFFIX_MSG(affixMeta, "Prefix")
    local suffixName = ARC_PICK_AFFIX_MSG(affixMeta, "Suffix")

    local affixName = itemName
    if prefixName ~= nil and suffixName ~= nil then
        affixName = prefixName .. " " .. itemName .. " " .. suffixName
    elseif prefixName ~= nil then
        affixName = prefixName .. " " .. itemName
    elseif suffixName ~= nil then
        affixName = itemName .. " " .. suffixName
    end

    if itemTag ~= "" then
        return itemTag .. " " .. affixName
    end
    return affixName
end

local function GET_ARCHEOLOGY_EXHIBIT_BASE_CLASS(invitem)
    if invitem == nil then
        return nil
    end

    local familyName = GET_ARCHEOLOGY_RELIC_FAMILY_CLASS_NAME(TryGetProp(invitem, "ClassName", "None"))
    if familyName == "" then
        return nil
    end

    return shared_archeology.get_base_profile(familyName)
end

local function GET_ARCHEOLOGY_EXHIBITION_CLASS(invitem)
    if invitem == nil then
        return nil
    end

    local className = TryGetProp(invitem, "ClassName", "None")
    if className == nil or className == "" or className == "None" then
        return nil
    end

    return GetClass("archeology_exhibition_item", className)
end

local function GET_ARCHEOLOGY_TOOLTIP_COST_DETAIL(invitem, optionMeta)
    local exCls = GET_ARCHEOLOGY_EXHIBITION_CLASS(invitem)
    if exCls == nil then
        return 0, 0, 0, 0
    end

    local baseCost = 0
    local optionBonus = 0
    local instabilityBonus = 0
    local totalCost = 0
    local rerollMeta = TryGetProp(invitem, "Arc_RerollMeta", "None")

    if GET_ARCHEOLOGY_EXHIBITION_ITEM_COST_DETAIL ~= nil then
        baseCost, optionBonus, totalCost = GET_ARCHEOLOGY_EXHIBITION_ITEM_COST_DETAIL(exCls, optionMeta, rerollMeta)
        baseCost = tonumber(baseCost) or 0
        optionBonus = tonumber(optionBonus) or 0
        totalCost = tonumber(totalCost) or (baseCost + optionBonus)
        if GET_ARCHEOLOGY_REROLL_INSTABILITY_COST ~= nil then
            instabilityBonus = tonumber(GET_ARCHEOLOGY_REROLL_INSTABILITY_COST(rerollMeta)) or 0
            totalCost = totalCost + instabilityBonus
        end
    else
        local itemProfile = shared_archeology.get_exhibition_item_profile(exCls)
        baseCost = itemProfile and (tonumber(itemProfile.cost) or 0) or 0
        if GET_ARCHEOLOGY_META_COST_BONUS ~= nil then
            optionBonus = tonumber(GET_ARCHEOLOGY_META_COST_BONUS(optionMeta)) or 0
        end
        if GET_ARCHEOLOGY_REROLL_INSTABILITY_COST ~= nil then
            instabilityBonus = tonumber(GET_ARCHEOLOGY_REROLL_INSTABILITY_COST(rerollMeta)) or 0
        end
        totalCost = baseCost + optionBonus + instabilityBonus
    end

    return baseCost, optionBonus, instabilityBonus, totalCost
end

local function GET_ARCHEOLOGY_TOOLTIP_COST_SHORT_TEXT(invitem, optionMeta)
    local baseCost, optionBonus, instabilityBonus, totalCost = GET_ARCHEOLOGY_TOOLTIP_COST_DETAIL(invitem, optionMeta)
    baseCost = tonumber(baseCost) or 0
    optionBonus = tonumber(optionBonus) or 0
    instabilityBonus = tonumber(instabilityBonus) or 0
    totalCost = tonumber(totalCost) or (baseCost + optionBonus + instabilityBonus)

    if optionBonus > 0 and instabilityBonus > 0 then
        return ScpArgMsg("ARCHEOLOGY_TOOLTIP_COST_OPTIONS_INSTABILITY{TOTAL}{OPTION}{INSTABILITY}",
            "TOTAL", totalCost, "OPTION", optionBonus, "INSTABILITY", instabilityBonus)
    end

    if optionBonus > 0 then
        return ScpArgMsg("ARCHEOLOGY_TOOLTIP_COST_BONUS{TOTAL}{BONUS}",
            "TOTAL", totalCost, "BONUS", optionBonus)
    end

    if instabilityBonus > 0 then
        return ScpArgMsg("ARCHEOLOGY_TOOLTIP_COST_BONUS{TOTAL}{BONUS}",
            "TOTAL", totalCost, "BONUS", instabilityBonus)
    end

    return ScpArgMsg("ARCHEOLOGY_TOOLTIP_COST{TOTAL}", "TOTAL", totalCost)
end

local function GET_ARCHEOLOGY_SLOT_DISPLAY_INFO(slotType)
    local profile = shared_archeology ~= nil and
        shared_archeology.get_map_trait_profile ~= nil and
        shared_archeology.get_map_trait_profile(slotType) or nil
    if profile ~= nil then
        return ClMsg(profile.exhibitSlotNameMsg),
            tonumber(profile.exhibitSlotIndex) or 0,
            "{#" .. tostring(profile.color or "D7D0C4") .. "}"
    end

    return nil, nil, "{#d7d0c4}"
end

function GET_ARCHEOLOGY_STAT_DESC(stat_tag, value, isLegacy)
    local info = shared_archeology ~= nil and
        shared_archeology.get_option_stat_rule ~= nil and
        shared_archeology.get_option_stat_rule(stat_tag) or nil
    if info == nil then
        return ScpArgMsg("ARCHEOLOGY_STAT_DESC_RAW{TAG}{VALUE}",
            "TAG", stat_tag, "VALUE", tostring(value))
    end

    local name = ClMsg(info.displayNameMsg)
    if name == nil or name == "" then
        name = stat_tag
    end

    local absValue = math.abs(tonumber(value) or 0)
    if info.displayValueMsg ~= nil and info.displayValueMsg ~= "None" then
        local displayScale = tonumber(info.displayScale) or 1
        local displayValueMsg = info.displayValueMsg
        if isLegacy == true then
            -- LegacyV1은 r406369에서 저장된 원래 수치를 그대로 표시한다.
            -- 신규 확률 단위용 0.1 배율과 %p 표기는 AffixV2에만 적용한다.
            if displayScale == 0.1 and
                    displayValueMsg == "ARCHEOLOGY_STAT_VALUE_PERCENT_POINT{VALUE}" then
                displayScale = 1
                displayValueMsg = "ARCHEOLOGY_STAT_VALUE_PERCENT{VALUE}"
            end
        end
        local displayValue = absValue * displayScale
        local numberText = string.format("%.2f", displayValue)
        numberText = string.gsub(numberText, "(%..-)0+$", "%1")
        numberText = string.gsub(numberText, "%.$", "")
        local formattedValue = ScpArgMsg(displayValueMsg, "VALUE", numberText)
        return ScpArgMsg(
            "ARCHEOLOGY_STAT_DESC_TYPED{COLOR}{TYPE}{NAME}{VALUE}",
            "COLOR", string.gsub(info.displayColor, "[{}#]", ""),
            "TYPE", ClMsg(info.displayTypeMsg),
            "NAME", name,
            "VALUE", formattedValue
        )
    end

    local displayFormat = info.displayFormat ~= nil and
        info.displayFormat ~= "None" and info.displayFormat or "+%s"
    local formattedValue = string.format(displayFormat, absValue)
    return string.format("%s%s: %s{/}", info.displayColor, name, formattedValue)
end

-- 2025년 고고학 유물은 당시의 간결한 툴팁 구성을 유지한다.
function ITEM_TOOLTIP_ARCHEOLOGY_LEGACY(tooltipframe, invitem, argStr, usesubframe)
    tolua.cast(tooltipframe, "ui::CTooltipFrame")

    local mainframename = "archeology"
    if usesubframe == "usesubframe" or usesubframe == "usesubframe_recipe" then
        mainframename = "archeology_sub"
    end

    local ypos = DRAW_ETC_COMMON_TOOLTIP(tooltipframe, invitem, mainframename, argStr)
    ypos = DRAW_ARCHEOLOGY_LEGACY_OPTIONS_TOOLTIP(tooltipframe, invitem, ypos, mainframename)
    ypos = DRAW_ETC_DESC_TOOLTIP(tooltipframe, invitem, ypos, mainframename)
    ypos = DRAW_ETC_RECIPE_NEEDITEM_TOOLTIP(tooltipframe, invitem, ypos, mainframename)
    ypos = DRAW_ETC_PREVIEW_TOOLTIP(tooltipframe, invitem, ypos, mainframename)
    ypos = DRAW_EQUIP_TRADABILITY(tooltipframe, invitem, ypos, mainframename)

    local isHaveLifeTime = TryGetProp(invitem, "LifeTime", 0)
    if 0 == tonumber(isHaveLifeTime) and GET_ITEM_EXPIRE_TIME(invitem) == "None" then
        ypos = DRAW_SELL_PRICE(tooltipframe, invitem, ypos, mainframename)
    else
        ypos = DRAW_REMAIN_LIFE_TIME(tooltipframe, invitem, ypos, mainframename)
    end

    local gBox = GET_CHILD(tooltipframe, mainframename, "ui::CGroupBox")
    gBox:Resize(gBox:GetWidth(), ypos)
    tooltipframe:Resize(tooltipframe:GetWidth(), ypos)
end

function DRAW_ARCHEOLOGY_LEGACY_OPTIONS_TOOLTIP(tooltipframe, invitem, ypos, mainframename)
    local prefixMeta = TryGetProp(invitem, "Arc_Prefix", "None")
    local suffixMeta = TryGetProp(invitem, "Arc_Suffix", "None")
    local optionMeta = ARC_MERGE_META(prefixMeta, suffixMeta)
    if ARC_META_IS_EMPTY(optionMeta) then
        return ypos
    end

    local optInfo = GET_ARCHEOLOGY_OPTION_INFO(optionMeta)
    if optInfo == nil or #optInfo == 0 then
        return ypos
    end

    local gBox = GET_CHILD(tooltipframe, mainframename, "ui::CGroupBox")
    local labelLine = gBox:CreateOrGetControl(
        "labelline", "archeology_legacy_option_line", 0, ypos, gBox:GetWidth() - 20, 2)
    labelLine:SetSkinName("labelline_def_2")
    labelLine:SetGravity(ui.CENTER_HORZ, ui.TOP)
    ypos = ypos + 5

    local headerSet = gBox:CreateOrGetControlSet(
        "archeology_tooltip_legacy_option_header", "archeology_legacy_option_header", 10, ypos)
    GET_CHILD_RECURSIVELY(headerSet, "title"):SetTextByKey(
        "value", ScpArgMsg("archeology_effect"))
    GET_CHILD_RECURSIVELY(headerSet, "cost"):SetTextByKey(
        "value", ScpArgMsg("archeology_cost{COST}",
            "COST", shared_archeology.get_item_cost_by_cls(invitem)))
    ypos = ypos + headerSet:GetHeight()

    for i, opt in ipairs(optInfo) do
        local optionSet = gBox:CreateOrGetControlSet(
            "archeology_tooltip_option_row", "archeology_legacy_option_text_" .. i, 10, ypos)
        GET_CHILD_RECURSIVELY(optionSet, "text"):SetTextByKey(
            "value", GET_ARCHEOLOGY_STAT_DESC(opt.tag, opt.value, true))
        ypos = ypos + optionSet:GetHeight()
    end

    return ypos + 5
end

function ITEM_TOOLTIP_ARCHEOLOGY(tooltipframe, invitem, argStr, usesubframe)
    tolua.cast(tooltipframe, "ui::CTooltipFrame")

    local mainframename = "archeology"
    if usesubframe == "usesubframe" or usesubframe == "usesubframe_recipe" then
        mainframename = "archeology_sub"
    end

    local ypos = DRAW_ARCHEOLOGY_COMMON_TOOLTIP(tooltipframe, invitem, mainframename, argStr)
    ypos = DRAW_ARCHEOLOGY_FIXED_EFFECT_TOOLTIP(tooltipframe, invitem, ypos, mainframename)
    ypos = DRAW_ARCHEOLOGY_SLOT_TYPE_TOOLTIP(tooltipframe, invitem, ypos, mainframename)
    ypos = DRAW_ARCHEOLOGY_OPTIONS_TOOLTIP(tooltipframe, invitem, ypos, mainframename)
    ypos = DRAW_ETC_DESC_TOOLTIP(tooltipframe, invitem, ypos, mainframename)
    ypos = DRAW_ETC_RECIPE_NEEDITEM_TOOLTIP(tooltipframe, invitem, ypos, mainframename)
    ypos = DRAW_ETC_PREVIEW_TOOLTIP(tooltipframe, invitem, ypos, mainframename)
    ypos = DRAW_EQUIP_TRADABILITY(tooltipframe, invitem, ypos, mainframename)

    local isHaveLifeTime = TryGetProp(invitem, "LifeTime", 0)
    if 0 == tonumber(isHaveLifeTime) and GET_ITEM_EXPIRE_TIME(invitem) == "None" then
        ypos = DRAW_SELL_PRICE(tooltipframe, invitem, ypos, mainframename)
    else
        ypos = DRAW_REMAIN_LIFE_TIME(tooltipframe, invitem, ypos, mainframename)
    end

    local gBox = GET_CHILD(tooltipframe, mainframename, "ui::CGroupBox")
    gBox:Resize(gBox:GetWidth(), ypos)
    tooltipframe:Resize(tooltipframe:GetWidth(), ypos)
end

function DRAW_ARCHEOLOGY_FIXED_EFFECT_TOOLTIP(tooltipframe, invitem, ypos, mainframename)
    if GET_ARCHEOLOGY_FIXED_RELIC_EFFECT_INFO == nil then
        return ypos
    end

    local info = GET_ARCHEOLOGY_FIXED_RELIC_EFFECT_INFO(TryGetProp(invitem, "ClassName", "None"))
    if info == nil then
        return ypos
    end

    local gBox = GET_CHILD(tooltipframe, mainframename, "ui::CGroupBox")
    local width = gBox:GetWidth() - 24
    local labelLine = gBox:CreateOrGetControl("labelline", "archeology_fixed_effect_line", 0, ypos, width, 2)
    labelLine:SetSkinName("labelline_def_2")
    labelLine:SetGravity(ui.CENTER_HORZ, ui.TOP)
    ypos = ypos + 9

    local titleSet = gBox:CreateOrGetControlSet(
        "archeology_tooltip_fixed_title", "archeology_fixed_effect_title", 12, ypos)
    local title = GET_CHILD_RECURSIVELY(titleSet, "text")
    title:SetTextByKey("color", info.color or "FFFFFF")
    title:SetTextByKey("value", ClMsg(info.titleMsg))
    ypos = ypos + titleSet:GetHeight() + 3

    local descSet = gBox:CreateOrGetControlSet(
        "archeology_tooltip_fixed_desc", "archeology_fixed_effect_desc", 12, ypos)
    local desc = GET_CHILD_RECURSIVELY(descSet, "text")
    desc:SetTextByKey("value", ClMsg(info.descMsg))
    local descHeight = math.max(descSet:GetHeight(), desc:GetHeight())
    descSet:Resize(descSet:GetWidth(), descHeight)
    ypos = ypos + descHeight + 6

    return ypos
end

local function GET_ARCHEOLOGY_PORTAL_RECORD_TOOLTIP_INFO(itemClass)
    if shared_archeology == nil or
            shared_archeology.get_portal_modifier_profiles == nil then
        return nil
    end
    local profiles = shared_archeology.get_portal_modifier_profiles()
    local profile = profiles ~= nil and profiles[itemClass] or nil
    if profile == nil then
        return nil
    end
    return {
        hp = tonumber(profile.mon_hp_pct) or 0,
        atk = tonumber(profile.mon_atk_pct) or 0,
        def = tonumber(profile.mon_def_pct) or 0,
        fragment = tonumber(profile.frag_bonus) or 0,
        rare = (tonumber(profile.reward_rare_chance) or 0) *
            (tonumber(profile.reward_rare_chance_display_scale) or 1),
        coin = tonumber(profile.reward_coin_bonus_pct) or 0,
        ruleMsg = profile.rule_msg,
        performanceMsg = profile.performance_msg,
    }
end

local function GET_ARCHEOLOGY_PORTAL_RECORD_RISK_TEXT(info)
    if info.atk > 0 and info.def > 0 then
        return ScpArgMsg(
            "ARC_PORTAL_TOOLTIP_RISK_HP_ATK_DEF{HP}{ATK}{DEF}",
            "HP", info.hp,
            "ATK", info.atk,
            "DEF", info.def
        )
    end
    if info.atk > 0 then
        return ScpArgMsg(
            "ARC_PORTAL_TOOLTIP_RISK_HP_ATK{HP}{ATK}",
            "HP", info.hp,
            "ATK", info.atk
        )
    end
    return ScpArgMsg(
        "ARC_PORTAL_TOOLTIP_RISK_HP_DEF{HP}{DEF}",
        "HP", info.hp,
        "DEF", info.def
    )
end

local function GET_ARCHEOLOGY_PORTAL_RECORD_APPLIED_RISK(info, monsterType)
    local function applied(value)
        if monsterType == "BOSS" then
            return value
        end
        local elite = math.floor(value * 0.75)
        if monsterType == "NORMAL" then
            return math.floor(elite * 0.6)
        end
        return elite
    end
    return {
        hp = applied(info.hp),
        atk = applied(info.atk),
        def = applied(info.def),
    }
end

local function GET_ARCHEOLOGY_PORTAL_RECORD_CONTRACT_TEXT(info)
    local rareText = string.format("%.2f", tonumber(info.rare) or 0)
    return ScpArgMsg(
        "ARC_PORTAL_TOOLTIP_CONTRACT{FRAGMENT}{RARE}{COIN}",
        "FRAGMENT", info.fragment,
        "RARE", rareText,
        "COIN", info.coin
    )
end

function DRAW_ARCHEOLOGY_PORTAL_RECORD_TOOLTIP(tooltipframe, invitem, ypos, mainframename)
    local className = TryGetProp(invitem, "ClassName", "None")
    local info = GET_ARCHEOLOGY_PORTAL_RECORD_TOOLTIP_INFO(className)
    if info == nil then
        return ypos
    end

    local gBox = GET_CHILD(tooltipframe, mainframename, "ui::CGroupBox")
    local width = gBox:GetWidth() - 24
    local labelLine = gBox:CreateOrGetControl("labelline", "arc_portal_record_line", 0, ypos, width, 2)
    labelLine:SetSkinName("labelline_def_2")
    labelLine:SetGravity(ui.CENTER_HORZ, ui.TOP)
    ypos = ypos + 10

    local rows = {
        {
            labelMsg = "ARC_PORTAL_TOOLTIP_LABEL_RISK_NORMAL",
            text = GET_ARCHEOLOGY_PORTAL_RECORD_RISK_TEXT(
                GET_ARCHEOLOGY_PORTAL_RECORD_APPLIED_RISK(info, "NORMAL")),
            color = "{#D9A07F}",
        },
        {
            labelMsg = "ARC_PORTAL_TOOLTIP_LABEL_RISK_ELITE",
            text = GET_ARCHEOLOGY_PORTAL_RECORD_RISK_TEXT(
                GET_ARCHEOLOGY_PORTAL_RECORD_APPLIED_RISK(info, "ELITE")),
            color = "{#D9A07F}",
        },
        {
            labelMsg = "ARC_PORTAL_TOOLTIP_LABEL_RISK_BOSS",
            text = GET_ARCHEOLOGY_PORTAL_RECORD_RISK_TEXT(
                GET_ARCHEOLOGY_PORTAL_RECORD_APPLIED_RISK(info, "BOSS")),
            color = "{#D9A07F}",
        },
        {
            labelMsg = "ARC_PORTAL_TOOLTIP_LABEL_CONTRACT",
            text = GET_ARCHEOLOGY_PORTAL_RECORD_CONTRACT_TEXT(info),
            color = "{#9FC6A2}",
        },
        {
            labelMsg = "ARC_PORTAL_TOOLTIP_LABEL_RULE",
            text = ClMsg(info.ruleMsg),
            color = "{#A9BED0}",
        },
        {
            labelMsg = "ARC_PORTAL_TOOLTIP_LABEL_PERFORMANCE",
            text = ClMsg(info.performanceMsg),
            color = "{#9FC6A2}",
        },
        {
            labelMsg = "ARCHEOLOGY_PORTAL_ENTRY_RESTRICTION",
            text = ClMsg("ARCHEOLOGY_PORTAL_BOSS_MODIFIER_BLOCKED"),
            color = "{#D9A07F}",
        },
    }

    for i, row in ipairs(rows) do
        local rowSet = gBox:CreateOrGetControlSet(
            "archeology_tooltip_portal_row", "arc_portal_record_row_" .. i, 12, ypos)
        local control = GET_CHILD_RECURSIVELY(rowSet, "text")
        local rowColor = string.gsub(row.color, "[{}#]", "")
        control:SetTextByKey("color", rowColor)
        control:SetTextByKey("label", ClMsg(row.labelMsg))
        control:SetTextByKey("value", row.text)
        rowSet:Resize(rowSet:GetWidth(), control:GetOffsetY() + control:GetHeight())
        ypos = ypos + rowSet:GetHeight() + 5
    end

	local footerSet = gBox:CreateOrGetControlSet(
		"archeology_tooltip_footer",
		"arc_portal_record_footer",
		12,
		ypos + 1
	)
	local footerText = GET_CHILD_RECURSIVELY(footerSet, "text")
	footerText:SetTextByKey("value", ClMsg("ARC_PORTAL_TOOLTIP_CONTRACT_FOOTER"))
	footerSet:Resize(footerSet:GetWidth(), footerText:GetOffsetY() + footerText:GetHeight())

	return ypos + footerSet:GetHeight() + 6
end

function ITEM_TOOLTIP_ARCHEOLOGY_PORTAL_RECORD(tooltipframe, invitem, argStr, usesubframe)
    tolua.cast(tooltipframe, "ui::CTooltipFrame")

    local mainframename = "etc"
    if usesubframe == "usesubframe" or usesubframe == "usesubframe_recipe" then
        mainframename = "etc_sub"
    end

    local ypos = DRAW_ETC_COMMON_TOOLTIP(tooltipframe, invitem, mainframename, argStr)
    ypos = DRAW_ARCHEOLOGY_PORTAL_RECORD_TOOLTIP(tooltipframe, invitem, ypos, mainframename)
    ypos = DRAW_ETC_RECIPE_NEEDITEM_TOOLTIP(tooltipframe, invitem, ypos, mainframename)
    ypos = DRAW_ETC_PREVIEW_TOOLTIP(tooltipframe, invitem, ypos, mainframename)
    ypos = DRAW_EQUIP_TRADABILITY(tooltipframe, invitem, ypos, mainframename)

    local isHaveLifeTime = TryGetProp(invitem, "LifeTime", 0)
    if tonumber(isHaveLifeTime) == 0 and GET_ITEM_EXPIRE_TIME(invitem) == "None" then
        ypos = DRAW_SELL_PRICE(tooltipframe, invitem, ypos, mainframename)
    else
        ypos = DRAW_REMAIN_LIFE_TIME(tooltipframe, invitem, ypos, mainframename)
    end

    local gBox = GET_CHILD(tooltipframe, mainframename, "ui::CGroupBox")
    gBox:Resize(gBox:GetWidth(), ypos)
    tooltipframe:Resize(tooltipframe:GetWidth(), ypos)
end

function DRAW_ARCHEOLOGY_COMMON_TOOLTIP(tooltipframe, invitem, mainframename, from)
    local gBox = GET_CHILD(tooltipframe, mainframename, "ui::CGroupBox")
    gBox:RemoveAllChild()

    gBox:SetSkinName("test_Item_tooltip_normal")

    local CSet = gBox:CreateControlSet("tooltip_etc_common", "tooltip_etc_common", 0, 0)
    tolua.cast(CSet, "ui::CControlSet")

    local gradeFontSize = CSet:GetUserConfig("GRADE_FONT_SIZE")
    local itemPicture = GET_CHILD(CSet, "itempic", "ui::CPicture")

    if invitem.TooltipImage ~= nil and invitem.TooltipImage ~= "None" then
        itemPicture:SetImage(invitem.TooltipImage)
        itemPicture:ShowWindow(1)
        SET_SLOT_STAR_TEXT(itemPicture, invitem)
    else
        itemPicture:ShowWindow(0)
    end

    local questMark = GET_CHILD(CSet, "questMark", "ui::CPicture")
    questMark:ShowWindow(0)

    SET_GRADE_TOOLTIP(CSet, invitem, gradeFontSize)

	local fullname = GET_ARCHEOLOGY_AFFIX_ITEM_NAME(invitem)
	local nameChild = GET_CHILD(CSet, "name", "ui::CRichText")
	nameChild:SetTextByKey("itemname", fullname)
    nameChild:SetTextAlign("center", "center")

    if nameChild:GetWidth() < nameChild:GetTextWidth() then
        nameChild:EnableSlideShow(1)
        nameChild:SetCompareTextWidthBySlideShow(true)
    else
        nameChild:EnableSlideShow(0)
        nameChild:SetCompareTextWidthBySlideShow(false)
    end

	local invDesc = GET_ITEM_DESC_BY_TOOLTIP_VALUE(invitem)
	local propRichtext = GET_CHILD(CSet, "prop_text", "ui::CRichText")
	propRichtext:SetTextByKey("desc", invDesc)

	-- 아이템 유저 거래 유무 다시 세팅
	local noTrade_cnt = GET_CHILD(CSet, "noTrade_cnt", "ui::CRichText");
	local noTradeCount = TryGetProp(invitem, "BelongingCount");
	if nil ~= noTradeCount and 0 > noTradeCount then
		noTradeCount = 0
	end
	noTrade_cnt:SetTextByKey('count', noTradeCount);

	local itemProp = geItemTable.GetPropByName(invitem.ClassName);
	if itemProp ~= nil then
		if itemProp:IsEnableUserTrade() ~= true then
			if nil ~= noTrade_cnt then
				noTrade_cnt:ShowWindow(0);
			end
		end
	else
		if nil ~= noTrade_cnt then
			noTrade_cnt:ShowWindow(0);
		end
	end
    
    if from ~= nil and from == 'accountwarehouse' then
        noTrade_cnt:ShowWindow(0)
    end
    
	
	-- 아이템 종류 세팅
	local type_richtext = GET_CHILD(CSet, "type_text", "ui::CRichText");
	local type_txt = invitem.GroupName
	if type_txt == 'Gem_Relic' then
		type_txt = invitem.GemType
	end
	local exhibitCls = GetClass('archeology_exhibition_item', TryGetProp(invitem, 'ClassName', 'None'))
	if TryGetProp(exhibitCls, 'ExhibitType', 'None') == 'Amplifier' then
		type_txt = ClMsg("ARCHEOLOGY_EXHIBIT_AMPLIFIER_ITEM_TYPE")
	else
		type_txt = ClMsg("ARCHEOLOGY_RELIC_ITEM_TYPE")
	end
	type_richtext:SetTextByKey('type', type_txt);
	
	--무게
	local weightRichtext = GET_CHILD(CSet, "weight_text", "ui::CRichText");
	weightRichtext:ShowWindow(0);

	gBox:Resize(gBox:GetWidth(),gBox:GetHeight()+CSet:GetHeight())

    return CSet:GetY() + CSet:GetHeight()
end

function DRAW_ARCHEOLOGY_SLOT_TYPE_TOOLTIP(tooltipframe, invitem, ypos, mainframename)
    -- 전시 보조 장치처럼 전시 슬롯 타입이 없는 전시품도 전시 점수는 표시해야 한다.
    if GET_ARCHEOLOGY_EXHIBITION_CLASS(invitem) == nil then
        return ypos
    end

    local slotName, slotIndex, slotColor = nil, nil, nil
    local baseCls = GET_ARCHEOLOGY_EXHIBIT_BASE_CLASS(invitem)
    if baseCls ~= nil then
        local slotType = baseCls.exhibitSlotType or "None"
        slotName, slotIndex, slotColor = GET_ARCHEOLOGY_SLOT_DISPLAY_INFO(slotType)
    end

    local gBox = GET_CHILD(tooltipframe, mainframename, "ui::CGroupBox")
    local labelLine = gBox:CreateOrGetControl("labelline", "archeology_slot_line", 0, ypos, gBox:GetWidth() - 20, 2)
    labelLine:SetSkinName("labelline_def_2")
    labelLine:SetGravity(ui.CENTER_HORZ, ui.TOP)
    ypos = ypos + 8

    local prefixMeta = TryGetProp(invitem, "Arc_Prefix", "None")
    local suffixMeta = TryGetProp(invitem, "Arc_Suffix", "None")
    local optionMeta = ARC_MERGE_META(prefixMeta, suffixMeta)
    local costTextValue = GET_ARCHEOLOGY_TOOLTIP_COST_SHORT_TEXT(invitem, optionMeta)

    local slotHeader = gBox:CreateOrGetControlSet(
        "archeology_tooltip_slot_header", "archeology_slot_header", 10, ypos)
    GET_CHILD_RECURSIVELY(slotHeader, "cost"):SetTextByKey("value", costTextValue)
    ypos = ypos + slotHeader:GetHeight()

    if slotName ~= nil then
        local slotSet = gBox:CreateOrGetControlSet(
            "archeology_tooltip_slot_type", "archeology_slot_type", 10, ypos)
        local slotText = GET_CHILD_RECURSIVELY(slotSet, "text")
        local slotColorText = string.gsub(slotColor, "[{}#]", "")
        slotText:SetTextByKey("color", slotColorText)
        slotText:SetTextByKey("name", slotName)
        slotText:SetTextByKey("index", slotIndex)
        ypos = ypos + slotSet:GetHeight()
    end

    return ypos + 5
end

function DRAW_ARCHEOLOGY_OPTIONS_TOOLTIP(tooltipframe, invitem, ypos, mainframename)
    local gBox = GET_CHILD(tooltipframe, mainframename, "ui::CGroupBox")

    local prefixMeta = TryGetProp(invitem, "Arc_Prefix", "None")
    local suffixMeta = TryGetProp(invitem, "Arc_Suffix", "None")
    local optionMeta = ARC_MERGE_META(prefixMeta, suffixMeta)
    if ARC_META_IS_EMPTY(optionMeta) then
        return ypos
    end

    local optInfo = GET_ARCHEOLOGY_OPTION_INFO(optionMeta)
    if GET_ARCHEOLOGY_EXHIBITION_DISPLAY_OPTION_LIST ~= nil then
        optInfo = GET_ARCHEOLOGY_EXHIBITION_DISPLAY_OPTION_LIST(optionMeta)
    end
    if optInfo == nil or #optInfo == 0 then
        return ypos
    end

    local labelLine = gBox:CreateOrGetControl("labelline", "archeology_option_line", 0, ypos, gBox:GetWidth() - 20, 2)
    labelLine:SetSkinName("labelline_def_2")
    labelLine:SetGravity(ui.CENTER_HORZ, ui.TOP)
    ypos = ypos + 5

    local titleSet = gBox:CreateOrGetControlSet(
        "archeology_tooltip_option_title", "archeology_option_title", 10, ypos)
    ypos = ypos + titleSet:GetHeight()

    for i, opt in ipairs(optInfo) do
		local valueStr = GET_ARCHEOLOGY_STAT_DESC(opt.tag, opt.value)
        local optionSet = gBox:CreateOrGetControlSet(
            "archeology_tooltip_option_row", "archeology_option_text_" .. i, 10, ypos)
        GET_CHILD_RECURSIVELY(optionSet, "text"):SetTextByKey("value", valueStr)
        ypos = ypos + optionSet:GetHeight()
    end

    return ypos + 5
end
