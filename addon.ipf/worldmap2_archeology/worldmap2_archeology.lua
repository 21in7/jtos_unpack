-- worldmap2_archeology.lua

function WORLDMAP2_ARCHEOLOGY_ON_INIT(addon, frame)
end

function OPEN_WORLDMAP2_ARCHEOLOGY(frame)
	WORLDMAP2_ARCHEOLOGY_SET_MAP(frame)
end

function WORLDMAP2_ARCHEOLOGY_SET_MAP(frame)
	local missionGb = GET_CHILD_RECURSIVELY(frame, "missions_gb")
	local aObj = GetMyAccountObj()
	local index = 0;
	missionGb:RemoveAllChild()
	local emptyText = GET_CHILD_RECURSIVELY(frame, "empty_text")
	emptyText:ShowWindow(0)
	local activeMapCount = shared_archeology.get_active_map_count(aObj)
	local tryCount = tonumber(TryGetProp(aObj, 'archeology_try_count', 0)) or 0
	local options = GET_CURRENT_APPLY_EFFECT_LIST() or {}
	local bonusCount = math.max(0, math.floor(tonumber(options.ARCHEOLOGY_SURVEY_ATTEMPT) or 0))
	local maxTryCount = shared_archeology.get_max_archeology_try_count() + bonusCount
	local isExhausted = tryCount >= maxTryCount
	for i = 1, isExhausted and 0 or activeMapCount do
		local mapName = TryGetProp(aObj, "archeology_map_"..i, "None")
		local mapCls = GetClass("Map", mapName)
		local is_complete = TryGetProp(aObj, 'archeology_map_' .. i .. '_complete', 0)
		if mapCls ~= nil and is_complete == 0 then
			local mapCtrl = missionGb:CreateOrGetControlSet("archeology_mission_map_set", "ARCHEOLOGY_MAP_"..i, 3, 80*index)
			local title = GET_CHILD(mapCtrl, "title_text")
			local trait = GET_CHILD(mapCtrl, "trait_text")
			local tokenBtn = GET_CHILD(mapCtrl, "token_btn")
			title:SetTextByKey("map_name", mapCls.Name)
			local _, traitProfile = shared_archeology.get_map_trait_profile_by_map(mapName)
			if shared_archeology.is_advanced_mission(aObj) and traitProfile ~= nil then
				local color = traitProfile.color or 'FFFFFF'
				trait:ShowWindow(1)
				trait:SetTextByKey("color", color)
				trait:SetTextByKey("trait", ClMsg(traitProfile.titleMsg))
				trait:SetTextByKey("reward", ClMsg(traitProfile.rewardMsg))
			else
				trait:ShowWindow(0)
			end

			local isTokenState = session.loginInfo.IsPremiumState(ITEM_TOKEN)
			local imageName = ""
	
			if isTokenState == true and GET_TOKEN_WARP_COOLDOWN() == 0 then
				imageName = "{img worldmap2_token_gold 38 38} "
			else
				imageName = "{img worldmap2_token_gray 38 38} "
			end
	
			tokenBtn:SetTextByKey("token_icon", imageName)
			tokenBtn:SetTextByKey("token_label", ScpArgMsg("TokenWarp"))
			tokenBtn:SetUserValue("MAP_NAME", mapName)
			index = index + 1
		end
	end
	-- No active (unfinished) mission area: show a hint instead of an empty box.
	if index == 0 then
		-- 아이리네의 탐사 의뢰는 Lv.550 이상에게만 보인다. 미만이면 요구 레벨을 알린다.
		local pc = GetMyPCObject()
		local pcLevel = pc ~= nil and (tonumber(TryGetProp(pc, 'Lv', 0)) or 0) or 0
		local emptyMsgKey = 'ARCHEOLOGY_WORLDMAP_NO_MISSION_AREA'
		if pcLevel < 550 then
			emptyMsgKey = 'ARCHEOLOGY_WORLDMAP_NO_MISSION_AREA_LOW_LEVEL'
		elseif isExhausted and activeMapCount > 0 then
			emptyMsgKey = 'ARCHEOLOGY_WORLDMAP_MISSION_EXHAUSTED'
		end
		emptyText:SetTextByKey('message', ClMsg(emptyMsgKey))
		emptyText:ShowWindow(1)
	end
end

function WORLDMAP2_ARCHEOLOGY_CLICK_TOKEN_BTN(parent, self)
    WORLDMAP2_TOKEN_WARP(self:GetUserValue("MAP_NAME"))
end
