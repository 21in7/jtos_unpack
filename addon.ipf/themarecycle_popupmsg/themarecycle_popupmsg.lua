-- hair_gacha_start.lua --

function THEMARECYCLE_POPUPMSG_ON_INIT(addon, frame)

end

function THEMARECYCLE_POPUPMSG_MAKE_ITEMLIST()
	local frame = ui.GetFrame("themarecycle_popupmsg");
	local tpitemframe = ui.GetFrame("thema_recycle");

	if frame == nil or tpitemframe == nil then
		return false;
	end

	local currencyItemName = GET_THEMA_RECYCLE_CURRENCY_ITEM_NAME(tpitemframe)
	local currencyItem = GetClass("Item", currencyItemName)
	if currencyItem == nil then
		return false;
	end

	local slotsetname = nil
		slotsetname = "rcycle_basketsellslotset"
	

	local slotset = GET_CHILD_RECURSIVELY(tpitemframe,slotsetname)
	
	local gbox = GET_CHILD_RECURSIVELY(frame,"itemlistgbox")
	if gbox == nil then
		return false;
	end
	DESTROY_CHILD_BYNAME(gbox, 'thema_eachitem_');
	local slotCount = slotset:GetSlotCount();
	local allprice = 0
	local drawcount = 0

	for i = 0, slotCount - 1 do
		local slotIcon	= slotset:GetIconByIndex(i);

		if slotIcon ~= nil then

			local slot  = slotset:GetSlotByIndex(i);

			local tpitemname = slot:GetUserValue("TPITEMNAME");
			local cnt = slot:GetUserValue("COUNT");
			local item = GetClass("Item",tpitemname)
			local tpitem = GetClass("recycle_thema",tpitemname)
			if config.GetServiceNation() == "PAPAYA" then
				tpitem = GetClass("recycle_thema",tpitemname)
			end

			if tpitem ~= nil and item ~= nil and IS_CURRENT_THEMA_RECYCLE_CLASS(tpitemframe, tpitem) == true then

				local itemcset = gbox:CreateOrGetControlSet('themashop_recycle_popup', 'thema_eachitem_'..drawcount, 0, ui.GetControlSetAttribute("themashop_recycle_popup", 'height') * drawcount);
				local slot = GET_CHILD_RECURSIVELY(itemcset,"itemicon")
				
				SET_SLOT_IMG(slot, GET_ITEM_ICON_IMAGE(item));
				
				local itemname = GET_CHILD_RECURSIVELY(itemcset,"itemname")
				local itemStaticprice_sell = GET_CHILD_RECURSIVELY(itemcset,"itemStaticprice_sell")
				local itemprice = GET_CHILD_RECURSIVELY(itemcset,"itemprice")
				

					itemname:SetTextByKey("name", item.Name)
					itemname:SetTextByKey("count", tostring(cnt))
					itemname:SetTextTooltip(itemname:GetText())
					itemStaticprice_sell:ShowWindow(1)
					itemStaticprice_sell:SetTextByKey("piece", currencyItem.Name)
					itemprice:SetTextByKey("value", tostring(tpitem.SellPrice * cnt))
					allprice = allprice + (tpitem.SellPrice * cnt)

				drawcount = drawcount + 1
			else
				return false
			end

		end
	end

	if allprice == 0 then
		return false;
	end

	local totalmedal_sell = GET_CHILD_RECURSIVELY(frame,"totalmedal_sell")
	local explain_sell = GET_CHILD_RECURSIVELY(frame,"explain_sell")
	local button_ok = GET_CHILD_RECURSIVELY(frame,"button_ok")
	local button_cancel = GET_CHILD_RECURSIVELY(frame,"button_cancel")


	totalmedal_sell:ShowWindow(1)
	totalmedal_sell:SetTextByKey("piece", currencyItem.Name)
	explain_sell:ShowWindow(1)
	explain_sell:SetTextByKey("piece", currencyItem.Name)
	button_ok:SetEventScript(ui.LBUTTONUP, 'EXEC_SELL_THEMA_RECYCLE_ITEM');
	--button_cancel:SetEventScript(ui.LBUTTONUP, 'TPSHOP_RECYCLE_ITEM_BASKET_SELL_CANCEL');
	

	local totalmedal = GET_CHILD_RECURSIVELY(frame,"totalmedal")
	totalmedal:SetTextByKey("price",allprice)

	return true
end