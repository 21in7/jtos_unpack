-- equip_cardslot_tooltip.lua --

function EQUIP_CARDSLOT_INFO_TOOLTIP_INIT(addon, frame)
end

function EQUIP_CARDSLOT_INFO_TOOLTIP_OPEN(frame, slot, argStr, groupSlotIndex)
	if slot == nil then
		return
	end
	
	local parentSlotSet = slot:GetParent()
	if parentSlotSet == nil then
		return
	end

	local slotIndex = slot:GetSlotIndex()
	if parentSlotSet:GetName() == 'ATKcard_slotset' then
		slotIndex = slotIndex + 0
	elseif parentSlotSet : GetName() == 'DEFcard_slotset' then
		slotIndex = slotIndex + 3
	elseif parentSlotSet : GetName() == 'UTILcard_slotset' then		
		slotIndex = slotIndex + 6
	elseif parentSlotSet : GetName() == 'STATcard_slotset' then
		slotIndex = slotIndex + 9
	elseif parentSlotSet : GetName() == 'LEGcard_slotset' then
		slotIndex = slotIndex + 12
	end
	frame = frame:GetTopParentFrame()
	EQUIP_CARDSLOT_TOOLTIP_BOSSCARD(slotIndex, frame:GetName());
end;

function EQUIP_CARDSLOT_INFO_TOOLTIP_CLOSE(frame, slot, argStr, argNum)		
	local tooltipFrame    = ui.GetFrame("equip_cardslot_tooltip");	
	tooltipFrame:ShowWindow(0);
end;

function EQUIP_CARDSLOT_INFO_TOOLTIP_CLOSE_TEST(frame, slot, argStr, argNum)	
	local tooltipFrame    = ui.GetFrame("monstercardslot");	
	tooltipFrame:ShowWindow(0);
end;

function set_sclae_value(value)	
	local before_min = -320
	local before_max = 1640
	local after_min = -640
	local after_max = 1540
    local before_denominator = before_max - before_min
    if before_denominator == 0 then
        before_denominator = 100000
    end
    local ratio = (value - before_min) / before_denominator
    local add_value = (after_max - after_min) * ratio
    value = after_min + add_value
    
    if value < after_min then
        value = after_min
    elseif value > after_max then
        value = after_max
	end
	
	return math.floor(value)
end

function EQUIP_CARDSLOT_TOOLTIP_BOSSCARD(slotIndex, topFrame)
	local frame = ui.GetFrame("equip_cardslot_tooltip");		
	tolua.cast(frame, "ui::CTooltipFrame");
	if frame:IsVisible() == 1 then
		return;
	end	

	local infoFrame = ui.GetFrame(topFrame);
	if infoFrame:IsVisible() == 0 then
		return
	end

	local wide_screen = false
	if ui.GetSceneWidth() / ui.GetSceneHeight() > 2 then
		wide_screen = true;
	end

	if wide_screen == false then
		if slotIndex >= 0 and slotIndex <= 2 or slotIndex >= 6 and slotIndex <= 8 then
			if infoFrame:GetX() - frame:GetWidth() < 0 then
				frame:SetOffset(infoFrame:GetX() + infoFrame:GetWidth(), frame : GetY());
			else
				frame:SetOffset(infoFrame :GetX() - frame:GetWidth() , frame:GetY());
			end
		else
			if infoFrame:GetX() + infoFrame : GetWidth() + frame : GetWidth() > ui.GetClientInitialWidth() then
				frame : SetOffset(infoFrame : GetX() - frame : GetWidth(), frame : GetY());
			else
				frame:SetOffset(infoFrame : GetX() + infoFrame : GetWidth(), frame : GetY());
			end
		end
	else
		local info_x = infoFrame:GetX()
		info_x = set_sclae_value(info_x)
	
		if slotIndex >= 0 and slotIndex <= 2 or slotIndex >= 6 and slotIndex <= 8 then	
			if info_x - frame:GetWidth() < 0 then	
				frame:SetOffset(info_x + infoFrame:GetWidth(), frame:GetY());			
			else
				frame:SetOffset(info_x - frame:GetWidth() - 200, frame:GetY());			
			end
		else
			if info_x + infoFrame:GetWidth() + frame:GetWidth() > ui.GetClientInitialWidth() then 
				frame:SetOffset(info_x - frame:GetWidth() - 200, frame:GetY());
			else
				frame:SetOffset(info_x + infoFrame:GetWidth(), frame:GetY());
			end
		end
	end
	
	local cardID, cardLv, cardExp

	if topFrame == "monstercardslot" then
		cardID, cardLv, cardExp = GETMYCARD_INFO(slotIndex);
	else
		cardID, cardLv, cardExp = _GETMYCARD_INFO(slotIndex);
	end
	local cls = GetClassByType("Item", cardID);
	if cardID == 0 then
		return;
	end

	local prop = geItemTable.GetProp(cardID);
	if prop ~= nil then
		cardLv = prop:GetLevel(cardExp);
	end

	local ypos = EQUIP_CARDSLOT_DRAW_TOOLTIP(frame, cardID, cardLv);
	ypos = EQUIP_CARDSLOT_DRAW_ADDSTAT_TOOLTIP(frame, ypos, cardID);
	if cls ~= nil and cls.ToolTipScp ~= 'LEGEND_BOSSCARD' then
		ypos = EQUIP_CARDSLOT_DRAW_EXP_TOOLTIP(frame, ypos, cardID, cardExp);
	end
	EQUIP_CARDSLOT_DRAW_CARD_SET(frame, 0, cardID); -- 세트 효과
	frame:Resize(frame:GetWidth(), ypos);
	frame:ShowWindow(1);
end


function EQUIP_CARDSLOT_DRAW_TOOLTIP(tooltipframe, cardID, cardLv)
	local gBox = GET_CHILD(tooltipframe, "bg")
	gBox:RemoveAllChild()

	local CSetBg = gBox : CreateControlSet('tooltip_bosscard_bg', 'boss_bg_inven', 0, 200);
	local CSet = gBox:CreateControlSet('tooltip_bosscard_common', 'boss_common_cset', 0, 0);
	tolua.cast(CSet, "ui::CControlSet");

	local GRADE_FONT_SIZE = CSet:GetUserConfig("GRADE_FONT_SIZE"); -- ��� ��Ÿ���� �� ũ��
	
	local cls = GetClassByType("Item", cardID);
	
	SET_CARD_EDGE_TOOLTIP(CSet, cls);

	-- ������ �̹���
	local spineItemPicture = GET_CHILD(CSet, "itempic");
	SET_SPINE_TOOLTIP_IMAGE(spineItemPicture, cls);

	-- �� �׸���	
	local gradeChild = CSet:GetChild('grade');
	if gradeChild ~= nil then
		local gradeString = GET_STAR_TXT_REDUCED(GRADE_FONT_SIZE, cls, cardLv, 0);
		gradeChild:SetText(gradeString);
	end;

	-- ������ �̸� ����
	local fullname = GET_FULL_NAME(cls, true);
	local nameChild = GET_CHILD(CSet, "name");
	nameChild:SetText(fullname);
		
	local stringArg = ' '
	if cls.NumberArg1 ~= 0 then
    	local bossCls = GetClassByType('Monster', cls.NumberArg1);
    	
    	stringArg = ScpArgMsg(bossCls.RaceType)
    end
    local typeRichtext = GET_CHILD(CSet, "type_text");
	typeRichtext:SetText(stringArg);
    
	local BOTTOM_MARGIN = CSet:GetUserConfig("BOTTOM_MARGIN"); -- �� �Ʒ��� ����
	CSet:Resize(CSet:GetWidth(), 0);
	CSet:Resize(CSet:GetWidth(),typeRichtext:GetY() + typeRichtext:GetHeight() + BOTTOM_MARGIN);
	gBox:Resize(gBox:GetWidth(), 0);
	gBox:Resize(gBox:GetWidth(),gBox:GetHeight() + CSet:GetHeight())
	return CSet:GetHeight();
end

--����ġ
function EQUIP_CARDSLOT_DRAW_EXP_TOOLTIP(tooltipframe, yPos, cardID, cardExp)
	local gBox = GET_CHILD(tooltipframe, "bg");
	gBox:RemoveChild('tooltip_bosscard_exp');
	
	local CSet = gBox:CreateControlSet('tooltip_bosscard_exp', 'tooltip_bosscard_exp', 0, yPos);
	--����ġ ������
	local gauge = GET_CHILD(CSet,'level_gauge')
	local lv, curExp, maxExp = GET_ITEM_LEVEL_EXP_BYCLASSID(cardID, cardExp);
	if curExp > maxExp then
		curExp = maxExp;
	end
	gauge:SetPoint(curExp, maxExp);
	
	gBox:Resize(gBox:GetWidth(),gBox:GetHeight() + CSet:GetHeight())
	return CSet:GetHeight() + CSet:GetY();
end

--����
function EQUIP_CARDSLOT_DRAW_ADDSTAT_TOOLTIP(tooltipframe, yPos, cardID)
	local gBox = GET_CHILD(tooltipframe, "bg");
	gBox:RemoveChild('tooltip_bosscard_desc');
	
	local CSet = gBox:CreateControlSet('tooltip_bosscard_desc', 'tooltip_bosscard_desc', 0, yPos)	
	--����
	local desc_text = GET_CHILD(CSet,'desc_text')
	local cls = GetClassByType("Item", cardID);
	if cls ~= nil then
		local tempText1 = cls.Desc;
		local tempText2 = cls.Desc_Sub;
		if tempText1 == "None" then
			tempText1 = "";
		end
		if tempText2 == "None" then
			tempText2 = "";
		end
		local textDesc = string.format("%s{nl}%s{/}", tempText1, tempText2);	

		textDesc = DRAW_COLLECTION_INFO(cls, textDesc)

		desc_text:SetTextByKey("text", textDesc);
		CSet:Resize(CSet:GetWidth(), desc_text:GetHeight() + desc_text:GetOffsetY());
	end
	
	gBox:Resize(gBox:GetWidth(),gBox:GetHeight() + CSet:GetHeight() + 10)
	return CSet:GetHeight() + CSet:GetY() + 10;
end

-- 카드 세트 효과 표시
function EQUIP_CARDSLOT_DRAW_CARD_SET(tooltipframe, ypos, cardID)
	local gBox = GET_CHILD_RECURSIVELY(tooltipframe, "card_main_addinfo");
	gBox:RemoveChild('tooltip_set');

	local itemProp = geItemTable.GetProp(cardID);
	local set = itemProp.setInfo;
	if set == nil then
		gBox:ShowWindow(0)
		return ypos;
	end
	gBox:ShowWindow(1)

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
	tooltip_CSet:Resize(tooltip_CSet:GetWidth(), set_gbox_prop:GetHeight() + set_gbox_prop:GetY() );
	gBox:Resize(gBox:GetWidth(), ypos + tooltip_CSet:GetHeight())
	return tooltip_CSet:GetHeight() + tooltip_CSet:GetY();
end

-- 카드 슬롯에 장착된 카드 개수를 확인하는 헬퍼 함수
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
