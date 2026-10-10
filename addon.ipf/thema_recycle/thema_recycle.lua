----DEFAULT FUNCTION START
function THEMA_RECYCLE_ON_INIT(addon, frame)
	addon:RegisterMsg("THEMA_RECYCLE_SUCCESS", "THEMA_ALL_CLEAR");

end

function GET_THEMA_RECYCLE_CURRENCY_ITEM_NAME(frame)
	local currencyItemName = frame:GetUserValue("THEMA_RECYCLE_CURRENCY")
	if currencyItemName == nil or currencyItemName == "None" then
		currencyItemName = "Piece_Of_Memory_Snigo"
	end
	return currencyItemName
end

function GET_THEMA_RECYCLE_THEME_ITEM_NAME(frame)
	local themeItemName = frame:GetUserValue("THEMA_RECYCLE_ITEM")
	if themeItemName == nil or themeItemName == "None" then
		themeItemName = "Gacha_Memory_of_Snigo_CUBE_001"
	end
	return themeItemName
end

function GET_THEMA_RECYCLE_CLASS_CURRENCY_ITEM_NAME(recycleCls)
	local currencyItemName = TryGetProp(recycleCls, "PackageList", "None")
	if currencyItemName == "None" then
		currencyItemName = "Piece_Of_Memory_Snigo"
	end
	return currencyItemName
end

function IS_CURRENT_THEMA_RECYCLE_CLASS(frame, recycleCls)
	if frame == nil or recycleCls == nil then
		return false
	end
	return GET_THEMA_RECYCLE_CURRENCY_ITEM_NAME(frame) == GET_THEMA_RECYCLE_CLASS_CURRENCY_ITEM_NAME(recycleCls)
end

function SET_THEMA_RECYCLE_TEXT(frame)
	local currencyItem = GetClass("Item", GET_THEMA_RECYCLE_CURRENCY_ITEM_NAME(frame))
	local themeItem = GetClass("Item", GET_THEMA_RECYCLE_THEME_ITEM_NAME(frame))
	if currencyItem == nil or themeItem == nil then
		return
	end

	GET_CHILD_RECURSIVELY(frame, "leftTitle"):SetTextByKey("theme", themeItem.Name)
	GET_CHILD_RECURSIVELY(frame, "rcycle_haveStaticTPbox"):SetTextByKey("piece", currencyItem.Name)
	GET_CHILD_RECURSIVELY(frame, "rcycle_remainStaticTPbox"):SetTextByKey("piece", currencyItem.Name)
	GET_CHILD_RECURSIVELY(frame, "rcycle_basketStaticTP"):SetTextByKey("piece", currencyItem.Name)
	GET_CHILD_RECURSIVELY(frame, "rcycle_group1_text"):SetTextByKey("theme", themeItem.Name)
end

function REQ_OPEN_THEMARECYCLE(theme)
	local frame = ui.GetFrame("thema_recycle")
	if theme == "URIEL" then
		frame:SetUserValue("THEMA_RECYCLE_CURRENCY", "Piece_Of_Memory_Uriel")
		frame:SetUserValue("THEMA_RECYCLE_ITEM", "Gacha_Memory_of_Uriel_CUBE_001")
	else
		frame:SetUserValue("THEMA_RECYCLE_CURRENCY", "Piece_Of_Memory_Snigo")
		frame:SetUserValue("THEMA_RECYCLE_ITEM", "Gacha_Memory_of_Snigo_CUBE_001")
	end
	ui.OpenFrame("thema_recycle")
end

function REQ_OPEN_URIEL_THEMARECYCLE()
	REQ_OPEN_THEMARECYCLE("URIEL")
end

function OPEN_THEMA_RECYCLE()
	local frame = ui.GetFrame('thema_recycle');
	SET_THEMA_RECYCLE_TEXT(frame)
	THEMA_ALL_CLEAR(frame)
end

function CLOSE_THEMA_RECYCLE()	
	SET_TOPMOST_FRAME_SHOWFRAME(1);
	session.ui.Clear_NISMS_ItemList();
	ui.OpenAllClosedUI();

	session.ui.Clear_NISMS_CashInven_ItemList();	

	ui.CloseFrame("themarecycle_popupmsg");

end
----DEFAULT FUNCTION END

-----reset function start

function THEMA_ALL_CLEAR(frame)
	if frame == nil then
		frame = ui.GetFrame('thema_recycle');
	end
	local slotset = GET_CHILD_RECURSIVELY(frame,"rcycle_basketsellslotset");
	THEMA_CLEAR_SLOTSET(slotset)

	SET_CHANGE_TO_MDEAL_ITEM_LIST(frame)
	UPDATE_THEMA_RECYCLE_BASKET_MONEY(frame)
end

function THEMA_CLEAR_SLOTSET(slotset)
	local slotCount = slotset:GetSlotCount();
	for i = 0, slotCount - 1 do
		local slot = slotset:GetSlotByIndex(i);
		slot:SetUserValue('TPITEMNAME', 'None');
	end
	slotset:ClearIconAll();
end


-----reset functio end

---- SETUP FUNCTION START
function SET_CHANGE_TO_MDEAL_ITEM_LIST(frame)
	if ctrl ~= nil then
	    ctrl:SetSkinName("baseyellow_btn");
	    local rcycle_group1 = GET_CHILD_RECURSIVELY(frame,"rcycle_group1");	
	    rcycle_group1:SetSkinName("base_btn");
	end
	if frame == nil then
		frame = ui.GetFrame('thema_recycle')
	end
	local rcycle_basketgbox = GET_CHILD_RECURSIVELY(frame,'rcycle_basketgbox');
	rcycle_basketgbox:SetVisible(1)

	local rcycle_basketsellslotset = GET_CHILD_RECURSIVELY(frame,"rcycle_basketsellslotset");
	rcycle_basketsellslotset:ShowWindow(1)

	local rcycle_tomedalBtn = GET_CHILD_RECURSIVELY(frame,"rcycle_tomedalBtn");
	rcycle_tomedalBtn:ShowWindow(1)

	local rcycle_mainSellText = GET_CHILD_RECURSIVELY(frame,"rcycle_mainSellText");
	rcycle_mainSellText:ShowWindow(1)

	UPDATE_THEMA_SELL_BASKET(frame)
	CREATE_THEMA_SELL_LIST(frame);	
end

function UPDATE_THEMA_SELL_BASKET(frame)
	local slotset = GET_CHILD_RECURSIVELY(frame,"rcycle_basketsellslotset");
	local slotCount = slotset:GetSlotCount();
	local allprice = 0
	for i = 0, slotCount - 1 do
		local slotIcon	= slotset:GetIconByIndex(i);

		if slotIcon ~= nil then
			local slot  = slotset:GetSlotByIndex(i);
			local classname = slot:GetUserValue("TPITEMNAME");
			local alreadyItem = GetClass("recycle_thema",classname)
			if config.GetServiceNation() == "PAPAYA" then
				alreadyItem = GetClass("recycle_thema",classname)
			end
			
			if alreadyItem ~= nil and IS_CURRENT_THEMA_RECYCLE_CLASS(frame, alreadyItem) == true then
				local cnt = slot:GetUserValue("COUNT");
				allprice = allprice + (alreadyItem.SellPrice * cnt)
			end
		end
	end

	local basketTP = GET_CHILD_RECURSIVELY(frame,"rcycle_basketTP")
	if allprice == 0 then
		basketTP:SetTextByKey("value", "0")
	else
		basketTP:SetTextByKey("value", "+"..tostring(allprice))
	end
	local accountObj = GetMyAccountObj();

	local havemedalcnt = 0
	local medal = session.GetInvItemByName(GET_THEMA_RECYCLE_CURRENCY_ITEM_NAME(frame));
	if medal ~= nil then
		havemedalcnt = medal.count
	end
	
	frame:Invalidate();
end

function CREATE_THEMA_SELL_LIST(frame)
	if frame == nil then
		frame = ui.GetFrame('thema_recycle')
	end
	local rcycle_mainSubGbox = GET_CHILD_RECURSIVELY(frame,"rcycle_mainSubGbox");
	DESTROY_CHILD_BYNAME(rcycle_mainSubGbox, "thema_eachitem_");

	local mainSubGbox = GET_CHILD_RECURSIVELY(frame,"rcycle_mainSubGbox");
	local invItemList = session.GetInvItemList();
	local retTable = {showitemcnt = 1};
	mainSubGbox:RemoveAllChild()
	FOR_EACH_INVENTORY(invItemList, function(invItemList, invItem, retTable, mainSubGbox)
		local itemobj = GetIES(invItem:GetObject());			
		if invItem ~= nil then
			local obj = GetClass("recycle_thema", itemobj.ClassName)
			if config.GetServiceNation() == "PAPAYA" then
				obj = GetClass("recycle_thema", itemobj.ClassName)
			end
			if obj ~= nil and IS_CURRENT_THEMA_RECYCLE_CLASS(frame, obj) == true then
				local SellPrice = TryGetProp(obj,"SellPrice", 0);
				local isValidRecycleItem = IS_VALID_RECYCLE_ITEM(itemobj);
				if SellPrice ~= 0 and isValidRecycleItem == true then
					local showitemcnt = retTable.showitemcnt;
					local x = ( (showitemcnt-1) % 3) * ui.GetControlSetAttribute("themashop_recycle", 'width')
					local y = (math.ceil( (showitemcnt / 3) ) - 1) * (ui.GetControlSetAttribute("themashop_recycle", 'height') * 1)
					local itemcset = mainSubGbox:CreateOrGetControlSet('themashop_recycle', 'thema_eachitem_'..invItem:GetIESID(), x, y);
					THEMA_RECYCLE_DRAW_ITEM_DETAIL(obj, itemobj, itemcset, "sell", invItem:GetIESID());
					retTable.showitemcnt = showitemcnt + 1
				end
			end
		end
	end, false, retTable, mainSubGbox);
end

function THEMA_RECYCLE_DRAW_ITEM_DETAIL(obj, itemobj, itemcset, type, itemguid)	
	local title = GET_CHILD_RECURSIVELY(itemcset,"title");
	local subtitle = GET_CHILD_RECURSIVELY(itemcset,"subtitle");
	local nxp = GET_CHILD_RECURSIVELY(itemcset,"nxp")
	local slot = GET_CHILD_RECURSIVELY(itemcset, "icon");
	local pre_Line = GET_CHILD_RECURSIVELY(itemcset,"noneBtnPreSlot_1");
	local pre_Box = GET_CHILD_RECURSIVELY(itemcset,"noneBtnPreSlot_2");
	local pre_Text = GET_CHILD_RECURSIVELY(itemcset,"noneBtnPreSlot_3");
	local staticSellMedalbox = GET_CHILD_RECURSIVELY(itemcset,"staticSellMedalbox");
	local remaincnt = GET_CHILD_RECURSIVELY(itemcset,"remaincnt");
	local isNew_mark = GET_CHILD_RECURSIVELY(itemcset,"isNew_mark");
	isNew_mark:SetVisible(0);
	local isHot_mark = GET_CHILD_RECURSIVELY(itemcset,"isHot_mark");
	isHot_mark:SetVisible(0);	
	local isSale_mark = GET_CHILD_RECURSIVELY(itemcset,"isSale_mark");
	isSale_mark:SetVisible(0);	
	local isSpecial_mark = GET_CHILD_RECURSIVELY(itemcset, 'isLimit_mark')
	isSpecial_mark:SetVisible(0)
	

	local itemName = itemobj.Name;
	local itemclsID = itemobj.ClassID;
	local tpitem_clsName = obj.ClassName;
	local tpitem_clsID = obj.ClassID;

	if TryGetProp(obj, 'New', 'None') == 'YES' then
		isNew_mark:SetVisible(1)
	end

	if TryGetProp(obj, 'Sale', 'None') == 'YES' then
		isSale_mark:SetVisible(1)
	end

	if TryGetProp(obj, 'Special', 'None') == 'YES' then
		isSpecial_mark:SetVisible(1)
	end

	local price = obj.SellPrice
	local frame = itemcset:GetTopParentFrame()
	local currencyItem = GetClass("Item", GET_THEMA_RECYCLE_CURRENCY_ITEM_NAME(frame))
	staticSellMedalbox:ShowWindow(1)
	if currencyItem ~= nil then
		staticSellMedalbox:SetTextByKey("piece", currencyItem.Name)
	end
	remaincnt:ShowWindow(0)
	title:SetTextByKey("value", itemName);
	pre_Line:SetVisible(0);
	pre_Box:SetVisible(0);
	pre_Text:SetVisible(0);
				
	--itemcset:SetUserValue("RCITEM_CLSID", tpitem_clsID); -- ?�거 ?�요??지  ?�인??�?
	nxp:SetTextByKey("value", price);

	subtitle:SetVisible(0);	

	SET_SLOT_IMG(slot, GET_ITEM_ICON_IMAGE(itemobj));
			
	local icon = slot:GetIcon();
	icon:SetTooltipType('wholeitem');
	icon:SetTooltipArg('recycleshop', itemclsID, itemguid);

	local desc = GET_CHILD_RECURSIVELY(itemcset,"desc")
	local tradeable = GET_CHILD_RECURSIVELY(itemcset,"tradeable")
	desc:ShowWindow(0)
	tradeable:ShowWindow(0)
	local sellBtn = GET_CHILD_RECURSIVELY(itemcset, "sellBtn");
	
	local sucValue = string.format("");	
	local isBuyPossible = 1;


	sellBtn:ShowWindow(1)
	sellBtn:SetEventScript(ui.LBUTTONUP,"THEMA_ITEM_TORECYCLE_SELL_PREPROCESSOR");
	sellBtn:SetEventScriptArgString(ui.LBUTTONUP, itemguid);
	
	if itemobj.MaxStack > 1 then
		THEMA_ITEM_RECYCLE_SELL_UPDATE_REMAINCNT(itemguid)
		remaincnt:ShowWindow(1)
	end


end

---- SETUP FUNCTIUN END



-----------------btn function start
function THEMA_ITEM_TORECYCLE_SELL_PREPROCESSOR(parent, control, itemguid)
	
	local invItem = session.GetInvItemByGuid(itemguid);
	
	if invItem == nil then
		return;
	end

	if  invItem.isLockState == true then
        ui.SysMsg(ClMsg("MaterialItemIsLock"));
        return;
    end

	local itemobj = GetClassByType("Item", invItem.type)
	
	if itemobj == nil then
		return;
	end

	local obj = GetClass("recycle_thema", itemobj.ClassName)
	if config.GetServiceNation() == "PAPAYA" then
		obj = GetClass("recycle_thema", itemobj.ClassName)
	end
	local frame = ui.GetFrame("thema_recycle")
	if obj == nil or IS_CURRENT_THEMA_RECYCLE_CLASS(frame, obj) == false then
		return;
	end

	local addcnt = 1
	if 1 == keyboard.IsKeyPressed("LSHIFT") then
		addcnt = 10
	end
	THEMA_ITEM_TO_RECYTCLE_SELL_BASKET(itemguid, addcnt)
end

function THEMA_ITEM_TO_RECYTCLE_SELL_BASKET(itemguid, addcnt)
	local invItem = session.GetInvItemByGuid(itemguid);

	if invItem == nil then
		return;
	end

	if addcnt > invItem.count then
		addcnt = invItem.count;
	end

	local itemobj = GetClassByType("Item", invItem.type)

	if itemobj == nil then
		return;
	end

	
	local obj = GetClass("recycle_thema", itemobj.ClassName)
	if config.GetServiceNation() == "PAPAYA" then
		obj = GetClass("recycle_thema", itemobj.ClassName)
	end
	local frame = ui.GetFrame("thema_recycle")
	if obj == nil or IS_CURRENT_THEMA_RECYCLE_CLASS(frame, obj) == false then
		return;
	end

	
	local slotset = GET_CHILD_RECURSIVELY(frame,"rcycle_basketsellslotset")
	local slotCount = slotset:GetSlotCount();

	for i = 0, slotCount - 1 do
		local slotIcon	= slotset:GetIconByIndex(i);

		if slotIcon ~= nil then

			local slot  = slotset:GetSlotByIndex(i);
			local alreadyguid = slot:GetUserValue("SELLITEMGUID");

			if itemobj.MaxStack > 1 then
				if alreadyguid == itemguid then
					local nowcnt = tonumber(slot:GetUserValue("COUNT"))
					
					local invItem = session.GetInvItemByGuid(alreadyguid);
					if invItem == nil then
						return;
					end

					local remaincnt = invItem.count - nowcnt

					if remaincnt <= 0 then
						ui.MsgBox(ScpArgMsg("CanNotSellDuplicateItem"))
						return;
					end

					if addcnt > remaincnt then
						 addcnt = remaincnt;
					end

					nowcnt = nowcnt + addcnt

					slot:SetUserValue("COUNT",tostring(nowcnt));
					slot:SetText("{s20}{b}{ol}"..tostring(nowcnt), 'count', ui.RIGHT, ui.BOTTOM, -2, 1);
					THEMA_ITEM_RECYCLE_SELL_UPDATE_REMAINCNT(itemguid)
					UPDATE_THEMA_RECYCLE_BASKET_MONEY(frame, "sell");
					return;
				end
			else
				if alreadyguid == itemguid then
					ui.MsgBox(ScpArgMsg("CanNotSellDuplicateItem"))
					return;
				end
			end

			
		end
	end


	for i = 0, slotCount - 1 do
		local slotIcon	= slotset:GetIconByIndex(i);

		if slotIcon == nil then

			local slot  = slotset:GetSlotByIndex(i);
			slot:SetEventScript(ui.RBUTTONDOWN, 'THEMA_RECYCLE_BASKETSLOT_REMOVE');
			slot:SetUserValue("CLASSNAME", item.ClassName);
			slot:SetUserValue("TPITEMNAME", obj.ClassName);
			slot:SetUserValue("SELLITEMGUID", itemguid);
			slot:SetUserValue("COUNT", tostring(addcnt));
			if addcnt > 1 then
				slot:SetText("{s20}{b}{ol}"..tostring(addcnt), 'count', ui.RIGHT, ui.BOTTOM, -2, 1);
			end

			SET_SLOT_IMG(slot, GET_ITEM_ICON_IMAGE(itemobj));
			local icon = slot:GetIcon();
			icon:SetTooltipType('wholeitem');
			icon:SetTooltipArg('', itemobj.ClassID, 0);

			break;

		end
	end
	THEMA_ITEM_RECYCLE_SELL_UPDATE_REMAINCNT(itemguid)
	UPDATE_THEMA_RECYCLE_BASKET_MONEY(frame)	
	
end

function THEMA_ITEM_RECYCLE_SELL_UPDATE_REMAINCNT(itemguid)
	local frame = ui.GetFrame("thema_recycle")
	local slotset = GET_CHILD_RECURSIVELY(frame,"rcycle_basketsellslotset")
	local slotCount = slotset:GetSlotCount();
	local invItem = session.GetInvItemByGuid(itemguid);
	if invItem == nil then
		return
	end
	local itemobj = GetClassByType("Item",invItem.type)

	local retcount = nil

	for i = 0, slotCount - 1 do
		local slotIcon	= slotset:GetIconByIndex(i);
		if slotIcon ~= nil then

			local slot  = slotset:GetSlotByIndex(i);
			local alreadyguid = slot:GetUserValue("SELLITEMGUID");

			if itemobj.MaxStack > 1 then
				if alreadyguid == itemguid then
					local nowcnt = tonumber(slot:GetUserValue("COUNT"))
					
					retcount =  invItem.count - nowcnt;
				end

			end

			
		end
	end

	if retcount == nil then
		retcount = invItem.count
	end
	local itemcset = GET_CHILD_RECURSIVELY(frame,"thema_eachitem_"..itemguid)
	itemcset:SetTextByKey("cnt",tostring(retcount))
end

function UPDATE_THEMA_RECYCLE_BASKET_MONEY(frame) -- buy? sell?

	local slotset = nil
	slotset = GET_CHILD_RECURSIVELY(frame,"rcycle_basketsellslotset")
	
	
	
	local slotCount = slotset:GetSlotCount();

	local allprice = 0

	for i = 0, slotCount - 1 do
		local slotIcon	= slotset:GetIconByIndex(i);

		if slotIcon ~= nil then

			local slot  = slotset:GetSlotByIndex(i);
			local classname = slot:GetUserValue("TPITEMNAME");
			local alreadyItem = GetClass("recycle_thema",classname)
			if config.GetServiceNation() == "PAPAYA" then
				alreadyItem = GetClass("recycle_thema",classname)
			end
			
			if alreadyItem ~= nil and IS_CURRENT_THEMA_RECYCLE_CLASS(frame, alreadyItem) == true then
				local cnt = slot:GetUserValue("COUNT");
				allprice = allprice + (alreadyItem.SellPrice * cnt)
			end

		end
	end

	local basketTP = GET_CHILD_RECURSIVELY(frame,"rcycle_basketTP")
	if allprice == 0 then
		basketTP:SetTextByKey("value", "0")
	else
		basketTP:SetTextByKey("value", "+"..tostring(allprice))
	end

	local accountObj = GetMyAccountObj();

	local havemedalcnt = 0
	local medal = session.GetInvItemByName(GET_THEMA_RECYCLE_CURRENCY_ITEM_NAME(frame));
	if medal ~= nil then
		havemedalcnt = medal.count
	end

	local haveTP = GET_CHILD_RECURSIVELY(frame,"rcycle_haveTP")
	haveTP:SetTextByKey("value", tostring(havemedalcnt))

	local remainTP = GET_CHILD_RECURSIVELY(frame,"rcycle_remainTP")
	if allprice >= 0 then
		remainTP:SetTextByKey("value", tostring(havemedalcnt + allprice))
	end

	frame:Invalidate();

end

function THEMA_RECYCLE_BASKETSLOT_REMOVE(parent, control, strarg, classid)	

	control:ClearText();
	control:ClearIcon();

	local itemguid = control:GetUserValue("SELLITEMGUID")
	if itemguid ~= "None" then
		THEMA_ITEM_RECYCLE_SELL_UPDATE_REMAINCNT(itemguid)
	end
	control:SetUserValue("SELLITEMGUID", "None");
	control:SetUserValue("CLASSNAME", "None");
	control:SetUserValue("TPITEMNAME", "None");
	control:SetUserValue("COUNT", "None");

	UPDATE_THEMA_RECYCLE_BASKET_MONEY(parent:GetTopParentFrame())

end

---sell btn
function THEMA_RECYCLE_ITEM_BASKET_SELL(parent, control)

	local ret = THEMARECYCLE_POPUPMSG_MAKE_ITEMLIST()
	if ret == true then
		ui.OpenFrame("themarecycle_popupmsg")
	end
end


-----------------btn function end



------------------extern function start

function EXEC_SELL_THEMA_RECYCLE_ITEM()
	session.ResetItemList();
	local slotsetname = nil
	local itemListStr = ""
	slotsetname = "rcycle_basketsellslotset"

	local frame = ui.GetFrame("thema_recycle")
	local btn = GET_CHILD_RECURSIVELY(frame,"rcycle_tomedalBtn");
	local slotset = GET_CHILD_RECURSIVELY(frame,slotsetname)
	if slotset == nil then
		return;
	end
	local slotCount = slotset:GetSlotCount();

	local allprice = 0
	local isHatOption = 0

	for i = 0, slotCount - 1 do
		local slotIcon	= slotset:GetIconByIndex(i);

		if slotIcon ~= nil then
			local slot  = slotset:GetSlotByIndex(i);
			local tpitemname = slot:GetUserValue("TPITEMNAME");
			local itemguid = slot:GetUserValue("SELLITEMGUID");
			local invitem = session.GetInvItemByGuid(itemguid);
			if invitem ~= nil then 
				local itemobj = GetIES(invitem:GetObject());
				if itemobj ~= nil then
					local tt = TryGetProp(itemobj, "HatPropName_1", "None");
					if TryGetProp(itemobj, "HatPropName_1", "None") ~= "None" then
						isHatOption = 1
					end
				end
			end

			local cnt = tonumber(slot:GetUserValue("COUNT"));
			local tpitem = GetClass("recycle_thema",tpitemname)
			if config.GetServiceNation() == "PAPAYA" then
				tpitem = GetClass("recycle_thema",tpitemname)
			end
			if tpitem ~= nil and IS_CURRENT_THEMA_RECYCLE_CLASS(frame, tpitem) == true then
				allprice = allprice + (tpitem.SellPrice * cnt)

				session.AddItemID(itemguid, cnt);
			else
				return
			end
		end
	end

	if allprice == 0 then
		return
	end

	if isHatOption == 1 then
		local msg = ScpArgMsg('ConfirmExchangeHatAccHaveOption{msg}', 'msg', ClMsg('exchange_enchant_item'));
		WARNINGMSGBOX_FRAME_OPEN_EXCHANGE_RECYCLE(msg, 'CONFIRM_SELL_THEMA_RECYCLE_ITEM');
	else
		CONFIRM_SELL_THEMA_RECYCLE_ITEM()
	end
end

function CONFIRM_SELL_THEMA_RECYCLE_ITEM()
	local resultlist = session.GetItemIDList();
	item.DialogTransaction("THEMA_RECYCLE_SHOP_SELL", resultlist);
	
	local frame = ui.GetFrame("thema_recycle");
	--frame:ShowWindow(0);
	CLOSE_THEMA_RECYCLE();
end
-------------------extern functon end