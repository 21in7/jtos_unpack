-- hair_gacha_free_start.lua --

function HAIR_GACHA_FREE_START_ON_INIT(addon, frame)

end

function HAIR_GACHA_FREE_OPEN(frame)
	local frame = ui.GetFrame("hair_gacha_free_start")
	
	local button = GET_CHILD_RECURSIVELY(frame, "button")
	-- if button ~= nil then
	-- 	if config.GetServiceNation() ~= "KOR" and config.GetServiceNation() ~= "GLOBAL_KOR" then
	-- 		button:SetMargin(0, 0, 0, 70);
	-- 	end
	-- end
end

function HAIR_GACHA_FREE_OK_BTN()
	local darkframe = ui.GetFrame("fulldark")
	local popupframe = ui.GetFrame("hair_gacha_popup")

	if darkframe == nil or popupframe == nil then
		return
	end

	if darkframe:IsVisible() == true or popupframe:IsVisible() == true then
		ui.SysMsg(ScpArgMsg('TryLater'));
		return
	end

	local frame = ui.GetFrame("hair_gacha_free_start");
    local skip_animation = GET_CHILD_RECURSIVELY(frame, "skip_animation");
    
	local type = frame:GetUserValue("ClassName");
	local isSkipAnimation = "NO";
	if skip_animation:IsChecked() == 1 then
		isSkipAnimation = "YES";
    end

	ui.Chat(string.format("/hairgacha %s %s", type, isSkipAnimation));
	ui.CloseFrame("hair_gacha_free_start")
end

function HAIR_GACHA_FREE_OK_BTNXTEN()
	local darkframe = ui.GetFrame("fulldark")
	local popupframe = ui.GetFrame("hair_gacha_popup")

	if darkframe == nil or popupframe == nil then
		return
	end

	if darkframe:IsVisible() == true or popupframe:IsVisible() == true then
		ui.SysMsg(ScpArgMsg('TryLater'));
		return
	end

	local frame = ui.GetFrame("hair_gacha_free_start");
    local skip_animation = GET_CHILD_RECURSIVELY(frame, "skip_animation");
    
	local type = frame:GetUserValue("ClassNameXTen");
	if type == nil or type == "None" then
		return
	end
	if type == "Gacha_Memory_of_Uriel_CUBE_001_X10" then
		local item = GetClass("Item", "Gacha_Memory_of_Uriel_CUBE_001")
		if item == nil or GET_TOTAL_ITEM_CNT(item.ClassID) < 10 then
			ui.SysMsg(ScpArgMsg("NeedItemCount", "Cnt", "10"));
			return
		end
	end
	local isSkipAnimation = "NO";
	if skip_animation:IsChecked() == 1 then
		isSkipAnimation = "YES";
    end

	ui.Chat(string.format("/hairgacha %s %s", type, isSkipAnimation));
	ui.CloseFrame("hair_gacha_free_start")
end

function CLIENT_GACHA_FREE_SCP(invItem)
	if invItem.isLockState == true then
		ui.SysMsg(ScpArgMsg("MaterialItemIsLock"))
		return
	end

	local itemobj = GetIES(invItem:GetObject());
    local gachaDetail = GetClass("GachaDetail", itemobj.ClassName);
    
	if gachaDetail.PreCheckScp ~= "None" then
		local scp = _G[gachaDetail.PreCheckScp];
		if scp() == "NO" then
			return;
		end
    end

	GACHA_FREE_START(gachaDetail)
end

function GACHA_FREE_START(gachaDetail)
	if gachaDetail == nil then
		return;
	end

	local cnt = gachaDetail.Count;
	if cnt ~= 1 and cnt ~= 10 and cnt ~= 11 then
		return;
	end

	local frame = ui.GetFrame("hair_gacha_free_start")
	frame:ShowWindow(0)
	frame:SetUserValue("ClassName", gachaDetail.ClassName);
	local item = GetClass("Item", gachaDetail.ClassName);
	SETUP_BUTTONS(frame, item)
	SETUP_PROBABILITY_BUTTON(frame, gachaDetail)

	--어떤 BG를 쓸 것인가
	--텍스트는 어떤걸?
	--버튼 어떤거?
	--카운트의 유무
	local hairbg = GET_CHILD_RECURSIVELY(frame,"bg_hair")
	local rboxbg = GET_CHILD_RECURSIVELY(frame,"bg_rbox")
    local hairText = GET_CHILD_RECURSIVELY(frame, 'richtext_2');
	local costumeText = GET_CHILD_RECURSIVELY(frame, 'richtext_3');
	local btn = GET_CHILD_RECURSIVELY(frame,"button")
	local skip_animation = GET_CHILD_RECURSIVELY(frame, "skip_animation");

	local isSkipAnimation = skip_animation:GetUserValue("IsSkipAnimation");
	if isSkipAnimation ~= nil and isSkipAnimation ~= "None" then
		skip_animation:SetCheck(isSkipAnimation);
	end

	btn:SetVisible(1)
	local msg_key = "GachaMsg"
	if gachaDetail.ClassName == "Gacha_Memory_of_Uriel_CUBE_001" or gachaDetail.ClassName == "Gacha_Memory_of_Uriel_CUBE_010" then
		msg_key = "GachaMemoryOpen"
	end
	local val = ScpArgMsg(msg_key, "Name", item.Name);
	btn:SetTextByKey("value", "{@st42b}"..val)
	if gachaDetail.GachaType == "hair" then
		hairbg:SetVisible(1);
		rboxbg:SetVisible(0);
		hairText:SetVisible(1);
		costumeText:SetVisible(0);
	elseif gachaDetail.GachaType == "rbox" then
		hairbg:SetVisible(0);
		rboxbg:SetVisible(1);
		hairText:SetVisible(1);
		costumeText:SetVisible(0);
	elseif gachaDetail.GachaType == "costume" then
		hairbg:SetVisible(1);
		rboxbg:SetVisible(0);
		hairText:SetVisible(0);
		costumeText:SetVisible(1);
	end

	frame:ShowWindow(1)
end

function SETUP_PROBABILITY_BUTTON(frame, gachaDetail)
	local probability_button = GET_CHILD_RECURSIVELY(frame, "openBtn2")
	if probability_button == nil then
		return
	end

	probability_button:ShowWindow(0)
	local reward_group = TryGetProp(gachaDetail, "RewardGroup", "None")
	if reward_group == "Gacha_Memory_of_Uriel_CUBE_001" then
		probability_button:ShowWindow(1)
	end
end

function SCR_GACHA_FREE_SKIP_ANIMATION(frame)
	local skip_animation = GET_CHILD_RECURSIVELY(frame, "skip_animation");
	skip_animation:SetUserValue("IsSkipAnimation", skip_animation:IsChecked());
end


function SETUP_BUTTONS(frame, item)
	local type = frame:GetUserValue("ClassName");
	local button = GET_CHILD_RECURSIVELY(frame, "button")
	local buttonxten = GET_CHILD_RECURSIVELY(frame, "buttonxten")
	--크리스마스 코스튬이면 10개버튼 활성화
	local xten_type = "None"
	if type == "GACHA_HAIRACC_ReRun_2025_001_10YEAR" then
		xten_type = "GACHA_HAIRACC_ReRun_2025_010_10YEAR"
	elseif type == "Gacha_Memory_of_Uriel_CUBE_001" and GET_TOTAL_ITEM_CNT(item.ClassID) >= 10 then
		xten_type = "Gacha_Memory_of_Uriel_CUBE_001_X10"
	end

	frame:SetUserValue("ClassNameXTen", xten_type)
	if xten_type ~= "None" then
		buttonxten:ShowWindow(1);
		local button_margin = 100
		local button_height = 45
		local buttonxten_margin = 55
		local buttonxten_height = 45
		if type == "Gacha_Memory_of_Uriel_CUBE_001" then
			button_margin = 110
			button_height = 35
			buttonxten_margin = 75
			buttonxten_height = 35
		end
		button:SetMargin(0, 0, 0, button_margin);
		button:Resize(button:GetWidth(), button_height);
		buttonxten:SetMargin(0, 0, 0, buttonxten_margin);
		buttonxten:Resize(buttonxten:GetWidth(), buttonxten_height);
		local msg_key = "GachaMsgX10"
		if type == "Gacha_Memory_of_Uriel_CUBE_001" then
			msg_key = "GachaMemoryOpenX10"
		end
		local val = ScpArgMsg(msg_key, "Name", item.Name);
		buttonxten:SetTextByKey("value", "{@st42b}"..val)
	else
		buttonxten:ShowWindow(0);
		button:SetMargin(0, 0, 0, 70);
		button:Resize(button:GetWidth(), 60);
	end

	frame:Invalidate();
	button:Invalidate();
end