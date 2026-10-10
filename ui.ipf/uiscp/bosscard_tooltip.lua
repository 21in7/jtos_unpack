-- bosscard_tooltip.lua
-- 보스카드 아이템

function ITEM_TOOLTIP_BOSSCARD(tooltipframe, invitem, strarg)
	tolua.cast(tooltipframe, "ui::CTooltipFrame");

	local mainframename = 'bosscard'

	local ypos = DRAW_BOSSCARD_COMMON_TOOLTIP(tooltipframe, invitem, mainframename); -- 보스 카드라면 공통적으로 그리는 툴팁들
	ypos = DRAW_BOSSCARD_ADDSTAT_TOOLTIP(tooltipframe, invitem, ypos, mainframename);
	ypos = DRAW_BOSSCARD_EXP_TOOLTIP(tooltipframe, invitem, ypos, mainframename); -- 경험치 바
    ypos = DRAW_BOSSCARD_TRADABILITY_TOOLTIP(tooltipframe, invitem, ypos, mainframename); -- 
	ypos = DRAW_BOSSCARD_SELL_PRICE(tooltipframe, invitem, ypos, mainframename);
end

function ITEM_TOOLTIP_LEGEND_BOSSCARD(tooltipframe, invitem, strarg)

	tolua.cast(tooltipframe, "ui::CTooltipFrame");

	local mainframename = 'bosscard'

	local ypos = DRAW_BOSSCARD_COMMON_TOOLTIP(tooltipframe, invitem, mainframename); -- 보스 카드라면 공통적으로 그리는 툴팁들
	ypos = DRAW_BOSSCARD_ADDSTAT_TOOLTIP(tooltipframe, invitem, ypos, mainframename);
        ypos = DRAW_BOSSCARD_TRADABILITY_TOOLTIP(tooltipframe, invitem, ypos, mainframename); -- 
	ypos = DRAW_BOSSCARD_SELL_PRICE(tooltipframe, invitem, ypos, mainframename);
end

function ITEM_TOOLTIP_GODDESSCARD(tooltipframe, invitem, strarg)

	tolua.cast(tooltipframe, "ui::CTooltipFrame");

	local subframename = 'goddesscard'

	local ypos = DRAW_REINFORCE_CARD_GODDESS_COMMON_TOOLTIP(tooltipframe, invitem,subframename); -- 보스 카드라면 공통적으로 그리는 툴팁들
	ypos = DRAW_BOSSCARD_ADDSTAT_TOOLTIP(tooltipframe, invitem, ypos, subframename);
	ypos = DRAW_BOSSCARD_TRADABILITY_TOOLTIP(tooltipframe, invitem, ypos, subframename); -- 
	CARD_GODDESS_TOOLTIP_X_ALIGN(tooltipframe,subframename)
end

function CARD_GODDESS_TOOLTIP_X_ALIGN(tooltipframe,subframename)
	local gBox = GET_CHILD(tooltipframe,subframename)
	local cnt = gBox:GetChildCount()
	for i = 0,cnt-1 do
		local child = gBox:GetChildByIndex(i)
		if child:GetName() ~= "boss_common_cset" then
			child:Move(30,0)
		end
	end
end

function ITEM_TOOLTIP_REINFORCE_CARD(tooltipframe, invitem, strarg)

	tolua.cast(tooltipframe, "ui::CTooltipFrame");

	local mainframename = 'bosscard'

	local ypos = DRAW_REINFORCE_CARD_COMMON_TOOLTIP(tooltipframe, invitem, mainframename); -- 강화용 카드 툴팁
	ypos = DRAW_BOSSCARD_ADDSTAT_TOOLTIP(tooltipframe, invitem, ypos, mainframename);
	ypos = DRAW_BOSSCARD_EXP_TOOLTIP(tooltipframe, invitem, ypos, mainframename); -- 경험치 바
    ypos = DRAW_BOSSCARD_TRADABILITY_TOOLTIP(tooltipframe, invitem, ypos, mainframename); -- 
	ypos = DRAW_BOSSCARD_SELL_PRICE(tooltipframe, invitem, ypos, mainframename);
end


function DRAW_REINFORCE_CARD_COMMON_TOOLTIP(tooltipframe, invitem, mainframename)
	local gBox = GET_CHILD(tooltipframe, mainframename,'ui::CGroupBox')
	gBox:RemoveAllChild()
	
	local CSetBg = gBox : CreateControlSet('tooltip_bosscard_bg', 'boss_bg_cset', 0, 200);

	local CSet = gBox:CreateControlSet('tooltip_bosscard_common', 'boss_common_cset', 0, 50);
	tolua.cast(CSet, "ui::CControlSet");

	local GRADE_FONT_SIZE = CSet:GetUserConfig("GRADE_FONT_SIZE"); -- 등급 나타내는 별 크기
	

	-- 카드 테두리 세팅
	SET_CARD_EDGE_TOOLTIP(CSet, invitem);

	-- 아이템 이미지
	local itemPicture = GET_CHILD(CSet, "itempic");
	itemPicture:SetImage(invitem.TooltipImage);

	-- 별 그리기
	SET_GRADE_TOOLTIP(CSet, invitem, GRADE_FONT_SIZE);

	-- 아이템 이름 세팅
	local fullname = GET_FULL_NAME(invitem, true);
	local nameChild = GET_CHILD(CSet, "name");
	nameChild:SetText(fullname);

	local typeRichtext = GET_CHILD(CSet, "type_text");
	typeRichtext:SetText("");
    
	local BOTTOM_MARGIN = CSet:GetUserConfig("BOTTOM_MARGIN"); -- 맨 아랫쪽 여백
	CSet:Resize(CSet:GetWidth(),typeRichtext:GetY() + typeRichtext:GetHeight() + BOTTOM_MARGIN);
	gBox:Resize(gBox:GetWidth(),gBox:GetHeight()+CSet:GetHeight() + 50)
	return CSet:GetHeight()+50;
end

function DRAW_REINFORCE_CARD_GODDESS_COMMON_TOOLTIP(tooltipframe, invitem,subframename)
	local subframe = GET_CHILD(tooltipframe, subframename,'ui::CGroupBox')
	subframe:RemoveAllChild()
	
	local CSetBg = subframe : CreateControlSet('tooltip_bosscard_bg', 'boss_bg_cset', 11, 100);
	local CSet = subframe:CreateControlSet('tooltip_goddesscard_common', 'boss_common_cset', 0, 0);
	tolua.cast(CSet, "ui::CControlSet");
	
	--사이즈 안 줄이면 옆에 선 생김
	CSetBg:Resize(CSetBg:GetWidth()-21,CSetBg:GetHeight())
	local GRADE_FONT_SIZE = CSet:GetUserConfig("GRADE_FONT_SIZE"); -- 등급 나타내는 별 크기
	

	-- 카드 테두리 세팅
	SET_CARD_EDGE_TOOLTIP(CSet, invitem);

	-- 아이템 이미지
	local spineItemPicture = GET_CHILD(CSet, "itempic");
	SET_SPINE_TOOLTIP_IMAGE(spineItemPicture, invitem);

	-- 별 그리기
	SET_GRADE_TOOLTIP(CSet, invitem, GRADE_FONT_SIZE);

	-- 아이템 이름 세팅
	local fullname = GET_FULL_NAME(invitem, true);
	local nameChild = GET_CHILD(CSet, "name");
	nameChild:SetText(fullname);

	local typeRichtext = GET_CHILD(CSet, "type_text");
	typeRichtext:SetText("");
    
	local BOTTOM_MARGIN = CSet:GetUserConfig("BOTTOM_MARGIN"); -- 맨 아랫쪽 여백
	CSet:Resize(CSet:GetWidth(),typeRichtext:GetY() + typeRichtext:GetHeight() + BOTTOM_MARGIN);
	subframe:Resize(subframe:GetWidth(), subframe:GetHeight()+CSet:GetHeight())
	return CSet:GetHeight();
end




function DRAW_BOSSCARD_COMMON_TOOLTIP(tooltipframe, invitem, mainframename)
	local gBox = GET_CHILD(tooltipframe, mainframename,'ui::CGroupBox')
	gBox:RemoveAllChild()
	
	local CSetBg = gBox : CreateControlSet('tooltip_bosscard_bg', 'boss_bg_cset', 0, 200);
	local CSet = gBox:CreateControlSet('tooltip_bosscard_common', 'boss_common_cset', 0, 0);
	tolua.cast(CSet, "ui::CControlSet");

	local GRADE_FONT_SIZE = CSet:GetUserConfig("GRADE_FONT_SIZE"); -- 등급 나타내는 별 크기

	-- 카드 테두리 세팅
	SET_CARD_EDGE_TOOLTIP(CSet, invitem);

	-- 아이템 이미지
	local spineItemPicture = GET_CHILD(CSet, "itempic");
	SET_SPINE_TOOLTIP_IMAGE(spineItemPicture, invitem);

	-- 별 그리기
	SET_GRADE_TOOLTIP(CSet, invitem, GRADE_FONT_SIZE);

	-- 아이템 이름 세팅
	local fullname = GET_FULL_NAME(invitem, true);
	local nameChild = GET_CHILD(CSet, "name");
	nameChild:SetText(fullname);

	-- 종족 세팅
	local stringArg =''
	if invitem.NumberArg1 ~= 0 then
	    local bossCls = GetClassByType('Monster', invitem.NumberArg1);
	    stringArg = ScpArgMsg(bossCls.RaceType)
	end
	
	local typeRichtext = GET_CHILD(CSet, "type_text");
	typeRichtext:SetText(stringArg);
    
	local BOTTOM_MARGIN = CSet:GetUserConfig("BOTTOM_MARGIN"); -- 맨 아랫쪽 여백
	CSet:Resize(CSet:GetWidth(),typeRichtext:GetY() + typeRichtext:GetHeight() + BOTTOM_MARGIN);
	gBox:Resize(gBox:GetWidth(),gBox:GetHeight()+CSet:GetHeight());
	return CSet:GetHeight();
end

--포텐 및 내구도
function DRAW_BOSSCARD_EXP_TOOLTIP(tooltipframe, invitem, yPos, mainframename)

	local gBox = GET_CHILD(tooltipframe, mainframename)
	gBox:RemoveChild('tooltip_bosscard_exp');
	
	local CSet = gBox:CreateControlSet('tooltip_bosscard_exp', 'tooltip_bosscard_exp', 0, yPos);

	--경험치 게이지
	local gauge = GET_CHILD(CSet,'level_gauge','ui::CGauge')
	local lv, curExp, maxExp = GET_ITEM_LEVEL_EXP(invitem);
	if curExp > maxExp then
		curExp = maxExp;
	end
	gauge:SetPoint(curExp, maxExp);

	gBox:Resize(gBox:GetWidth(),gBox:GetHeight() + CSet:GetHeight())
	return CSet:GetHeight() + CSet:GetY();
end

--스텟
function DRAW_BOSSCARD_ADDSTAT_TOOLTIP(tooltipframe, invitem, yPos, mainframename)
	local gBox = GET_CHILD(tooltipframe, mainframename)
	gBox:RemoveChild('tooltip_bosscard_desc');
	
	local CSet = gBox:CreateControlSet('tooltip_bosscard_desc', 'tooltip_bosscard_desc', 0, yPos);

	--스텟
	local desc_text = GET_CHILD(CSet,'desc_text')
	if invitem.GroupName == "Card" then
		local tempText1 = invitem.Desc;
		local tempText2 = invitem.Desc_Sub;
		if invitem.Desc == "None" then
			tempText1 = "";
		end
		if invitem.Desc_Sub == "None" then
			tempText2 = "";
		end
		local textDesc = string.format("%s{nl}%s{/}", tempText1, tempText2)	
		textDesc = DRAW_COLLECTION_INFO(invitem, textDesc)

		desc_text:SetTextByKey("text", textDesc);
		CSet:Resize(CSet:GetWidth(), desc_text:GetHeight() + desc_text:GetOffsetY());
	else
		local textDesc = invitem.Desc
		textDesc = DRAW_COLLECTION_INFO(invitem, textDesc)
		desc_text:SetTextByKey("text", textDesc);
		CSet:Resize(CSet:GetWidth(), desc_text:GetHeight() + desc_text:GetOffsetY());
	end
	
	-- 세트 효과 표시
	DRAW_CARD_SET(tooltipframe, invitem.ClassID, 0, "card_main_addinfo") -- 세트아이템

	gBox:Resize(gBox:GetWidth(),gBox:GetHeight() + CSet:GetHeight())
	return CSet:GetHeight() + CSet:GetY();
end

function DRAW_BOSSCARD_TRADABILITY_TOOLTIP(tooltipframe, invitem, ypos, mainframename)
	local gBox = GET_CHILD(tooltipframe, mainframename,'ui::CGroupBox')
	gBox:RemoveChild('tooltip_bosscard_tradability');

	local CSet = gBox:CreateControlSet('tooltip_bosscard_tradability', 'tooltip_bosscard_tradability', 0, ypos);
	tolua.cast(CSet, "ui::CControlSet");

	local event_master_card = IS_TRADE_OPTION_EVENT_MASTER_CARD(tooltipframe);
	if event_master_card == false then
		TOGGLE_TRADE_OPTION(CSet, invitem, 'option_npc', 'option_npc_text', 'ShopTrade')
		TOGGLE_TRADE_OPTION(CSet, invitem, 'option_market', 'option_market_text', 'MarketTrade')
		TOGGLE_TRADE_OPTION(CSet, invitem, 'option_teamware', 'option_teamware_text', 'TeamTrade')
		TOGGLE_TRADE_OPTION(CSet, invitem, 'option_trade', 'option_trade_text', 'UserTrade')
	else
		TOGGLE_TRADE_OPTION_EVENT_MASTER_CARD(tooltipframe, CSet, tradeselectitem_cls);
	end

	gBox:Resize(gBox:GetWidth(),gBox:GetHeight()+CSet:GetHeight())
    return ypos + CSet:GetHeight();
end
function DRAW_BOSSCARD_SELL_PRICE(tooltipframe, invitem, yPos, mainframename)
	local itemProp = geItemTable.GetPropByName(invitem.ClassName);
	if itemProp:IsEnableShopTrade() == false then
		return yPos
	end

	local gBox = GET_CHILD(tooltipframe, mainframename, 'ui::CGroupBox')
	gBox : RemoveChild('tooltip_sellinfo_bosscard');
	
	local tooltip_sellinfo_CSet = gBox:CreateControlSet('tooltip_sellinfo_bosscard', 'tooltip_sellinfo_bosscard', 0, yPos);
	tolua.cast(tooltip_sellinfo_CSet, "ui::CControlSet");

	local sellprice_text = GET_CHILD(tooltip_sellinfo_CSet, 'sellprice', 'ui::CRichText')
	sellprice_text:SetTextByKey("silver", GET_COMMAED_STRING(geItemTable.GetSellPrice(itemProp)));

	local BOTTOM_MARGIN = tooltipframe:GetUserConfig("BOTTOM_MARGIN"); --맨 아랫쪽 여백
	tooltip_sellinfo_CSet : Resize(tooltip_sellinfo_CSet : GetWidth(), tooltip_sellinfo_CSet : GetHeight() + BOTTOM_MARGIN);

	local height = gBox:GetHeight() + tooltip_sellinfo_CSet : GetHeight();
	gBox:Resize(gBox : GetWidth(), height);
	return yPos + tooltip_sellinfo_CSet:GetHeight();
end

-- 카드 세트 효과 표시 함수
function DRAW_CARD_SET(tooltipframe, classID, ypos, mainframename)

	local gBox = GET_CHILD(tooltipframe, mainframename, 'ui::CGroupBox');
	if gBox == nil then
		return
	end
	
	gBox:RemoveChild('tooltip_set');

	local itemProp = geItemTable.GetProp(classID);
	local set = itemProp.setInfo;
	if set == nil then
		return ypos;
	end

	local tooltip_CSet = gBox:CreateControlSet('tooltip_set', 'tooltip_set', 0, ypos);
	tolua.cast(tooltip_CSet, "ui::CControlSet");
	local set_gbox_type = GET_CHILD(tooltip_CSet, 'set_gbox_type', 'ui::CGroupBox')
	local set_gbox_prop = GET_CHILD(tooltip_CSet, 'set_gbox_prop', 'ui::CGroupBox')

	local inner_yPos = 0;
	local inner_xPos = 0;
	local DEFAULT_POS_Y = tooltip_CSet:GetUserConfig("DEFAULT_POS_Y")
	inner_yPos = DEFAULT_POS_Y;
	inner_xPos = 0;

	-- 세트 아이템 목록 표시
	local cnt = set:GetItemCount();
	local clsID = 0
	local HaveCount = 0;
	local EntireHaveCount = 0;

	for i = 0, cnt - 1 do
		local itemClsName = set:GetItemClassName(i)
		local itemCls = GetClass("Item", itemClsName)

		if itemCls ~= nil then
			local setItemName = set:GetItemName(i)

			local setItemTextCset = set_gbox_type:CreateControlSet('eachitem_in_setitemtooltip', 'setItemText'..i, inner_xPos, inner_yPos);
			tolua.cast(setItemTextCset, "ui::CControlSet");
			local setItemName = GET_CHILD_RECURSIVELY(setItemTextCset, "setitemtext")

			if itemCls.ClassID ~= clsID then
				HaveCount = 0
			end

			local count = GET_CARD_ITEM_CNT(itemCls.ClassID)
			count = count - HaveCount

			if count == 0 then
				setItemName:SetTextByKey("font", tooltip_CSet:GetUserConfig("NOT_HAVE_ITEM_FONT"))
				HaveCount = 0
			else
				setItemName:SetTextByKey("font", tooltip_CSet:GetUserConfig("HAVE_ITEM_FONT"))
				EntireHaveCount = EntireHaveCount + 1
				HaveCount = HaveCount + 1
				clsID = itemCls.ClassID
			end

			setItemName:SetTextByKey("itemname", itemCls.Name)
			local heightMargin = setItemTextCset:GetUserConfig("HEIGHT_MARGIN")
			inner_yPos = inner_yPos + heightMargin;
		end
	end
	set_gbox_type:Resize(set_gbox_type:GetWidth(), inner_yPos)

	local USE_SETOPTION_FONT = tooltip_CSet:GetUserConfig("USE_SETOPTION_FONT")
	local NOT_USE_SETOPTION_FONT = tooltip_CSet:GetUserConfig("NOT_USE_SETOPTION_FONT")

	inner_yPos = DEFAULT_POS_Y

	-- 세트 효과 표시
	for i = 0, cnt - 1 do
		local setEffect = set:GetSetEffect(i);
		if setEffect ~= nil then
			local color = USE_SETOPTION_FONT
			if EntireHaveCount >= i + 1 then
				color = NOT_USE_SETOPTION_FONT
			end

			local setTitle = ScpArgMsg("Auto_{s16}{Auto_1}{Auto_2}_SeTeu_HyoKwa__{nl}", "Auto_1", color, "Auto_2", i + 1);
			local setDesc = string.format("{s16}%s%s", color, setEffect:GetDesc());
			local each_text_CSet = set_gbox_prop:CreateControlSet('tooltip_set_each_prop_text', 'each_text_CSet'..i, inner_xPos, inner_yPos);
			tolua.cast(each_text_CSet, "ui::CControlSet");
			local y_margin = each_text_CSet:GetUserConfig("TEXT_Y_MARGIN")
			local set_text = GET_CHILD(each_text_CSet, 'set_prop_Text', 'ui::CRichText')
			set_text:SetTextByKey("setTitle", setTitle)

			--즈메이 카드 세트처럼 특정 조건이 있는 경우를 위해 추가적인 설명 추가
			local cls = GetClassByType("SetItem", set.classID);
			if cls ~= nil then
				local funcName = TryGetProp(cls, "ConditionalCheckScp", "None")
				if funcName ~= "None" then
					local ret = _G[funcName](set);
					local extraColor = USE_SETOPTION_FONT
					if ret == 1 then
						extraColor = NOT_USE_SETOPTION_FONT
					end

					local extraDesc = TryGetProp(cls, "ConditionalEffectDesc", "None")
					local extraDesc2 = string.format("{/}{/} {nl}{s16}%s%s", extraColor, extraDesc);
					setDesc = setDesc..extraDesc2
				end
			end

			set_text:SetTextByKey("setDesc", setDesc)
			local labelline = GET_CHILD_RECURSIVELY(each_text_CSet, 'labelline')
			local testRect = set_text:GetMargin();
			each_text_CSet:Resize(each_text_CSet:GetWidth(), set_text:GetHeight() + testRect.top);
			inner_yPos = inner_yPos + each_text_CSet:GetHeight() + y_margin;
		end
	end

	-- 맨 아랫쪽 여백
	local BOTTOM_MARGIN = tooltipframe:GetUserConfig("BOTTOM_MARGIN");
	set_gbox_prop:Resize(set_gbox_prop:GetWidth(), inner_yPos + BOTTOM_MARGIN)
	set_gbox_prop:SetOffset(set_gbox_prop:GetX(), set_gbox_type:GetY() + set_gbox_type:GetHeight())
	tooltip_CSet:Resize(tooltip_CSet:GetWidth(), set_gbox_prop:GetHeight() + set_gbox_prop:GetY());
	gBox:Resize(gBox:GetWidth(), tooltip_CSet:GetHeight())
	return tooltip_CSet:GetHeight() + tooltip_CSet:GetY();
end

-- 카드 아이템 개수를 확인하는 헬퍼 함수
function GET_CARD_ITEM_CNT(classID)
	local cnt = 0;
	-- equipcard.GetCardInfo를 사용하여 모든 카드 슬롯 확인
	-- 슬롯 인덱스는 1부터 시작 (ATK: 1-6, DEF: 7-12, UTIL: 13-18, STAT: 19-24, LEG: 25-30)
	-- 총 5개 타입 * MONSTER_CARD_SLOT_COUNT_PER_TYPE(6) = 30개 슬롯
	for slotIndex = 1, 30 do
		local cardInfo = equipcard.GetCardInfo(slotIndex);
		if cardInfo ~= nil then
			local cardID = cardInfo:GetCardID();
			if cardID == classID then
				cnt = cnt + 1;
			end
		end
	end

	return cnt;
end

-- 카드 아이템 개수를 확인하는 헬퍼 함수
function GET_CARD_ITEM_STAR(classID)
	local cnt = 0;
	-- equipcard.GetCardInfo를 사용하여 모든 카드 슬롯 확인
	-- 슬롯 인덱스는 1부터 시작 (ATK: 1-6, DEF: 7-12, UTIL: 13-18, STAT: 19-24, LEG: 25-30)
	-- 총 5개 타입 * MONSTER_CARD_SLOT_COUNT_PER_TYPE(6) = 30개 슬롯
	for slotIndex = 1, 30 do
		local cardInfo = equipcard.GetCardInfo(slotIndex);
		if cardInfo ~= nil then
			local cardID = cardInfo:GetCardID();
			if cardID == classID then
				return cardInfo.cardLv;
			end
		end
	end

	return 0;
end
