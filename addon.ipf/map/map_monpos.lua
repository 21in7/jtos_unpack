

function GET_MAP_POS(frame, mapprop, x, y, width, height)
	
	if frame:GetName() == "map" then
		local MapPos = mapprop:WorldPosToMinimapPos(x, y, m_mapWidth, m_mapHeight);
		 return m_offsetX + MapPos.x, m_offsetY + MapPos.y, width, height;
	else
		
		local cursize = GET_MINIMAPSIZE();
		local pictureui  = GET_CHILD(frame:GetTopParentFrame(), "map", "ui::CPicture");	
		local minimapw = pictureui:GetImageWidth() * (100 + cursize) / 100;
		local minimaph = pictureui:GetImageHeight() * (100 + cursize) / 100;
		local dd = (100 + cursize) / 100;
		local MapPos = mapprop:WorldPosToMinimapPos(x, y, minimapw, minimaph);
		return MapPos.x, MapPos.y, width * dd, height * dd;
	end
end

function IS_ARCHEOLOGY_MON_MINIMAP_INFO(info)
	if info == nil or info.type == nil or info.type == 0 then
		return false;
	end

	local monCls = GetClassByType("Monster", info.type);
	if monCls == nil or monCls.ClassName == nil then
		return false;
	end

	return string.find(monCls.ClassName, "Archeology", 1, true) ~= nil;
end

function MAP_MON_MINIMAP(frame, msg, argStr, argNum, info)
	if ARCHEOLOGY_MON_MINIMAP_RECV_DEBUG_COUNT == nil then
		ARCHEOLOGY_MON_MINIMAP_RECV_DEBUG_COUNT = 0;
	end

	if ARCHEOLOGY_MON_MINIMAP_RECV_DEBUG_COUNT < 20 then
		print(string.format("[ARCH_DBG][MON_MINIMAP_CLIENT] recv handle=%s type=%s useIcon=%s isDot=%s x=%s z=%s", tostring(info.handle), tostring(info.type), tostring(info.useIcon), tostring(info.isDot), tostring(info.x), tostring(info.z)));
		ARCHEOLOGY_MON_MINIMAP_RECV_DEBUG_COUNT = ARCHEOLOGY_MON_MINIMAP_RECV_DEBUG_COUNT + 1;
	end

	local isMinimap = false;
	if frame:GetTopParentFrame():GetName() == "minimap" then
		frame = GET_CHILD(frame, 'npclist', 'ui::CGroupBox');
		isMinimap = true;
	end

	local ctrlName = "_MONPOS_" .. info.handle;
	local monPic = frame:GetChild(ctrlName);
	if monPic ~= nil then
		MAP_MON_MINIMAP_SETPOS(frame, info);
		return;
	end

	local SIZE = 40;
	if info.isDot == true then
		SIZE = 14;
	elseif IS_ARCHEOLOGY_MON_MINIMAP_INFO(info) == true then
		SIZE = 24;
	end

	local ctrlName = "_MONPOS_" .. info.handle;
	monPic = frame:CreateOrGetControl('picture', ctrlName, 0, 0, SIZE, SIZE);
	tolua.cast(monPic, "ui::CPicture");
	if false == monPic:HaveUpdateScript("_MONPIC_AUTOUPDATE") then
		monPic:RunUpdateScript("_MONPIC_AUTOUPDATE", 1);
	end

	monPic:SetUserValue("W", SIZE);
	monPic:SetUserValue("H", SIZE);
	monPic:SetUserValue("HANDLE", info.handle);
	monPic:SetUserValue("EXTERN", "YES");
	monPic:SetUserValue("EXTERN_PIC", "YES");

	if isMinimap == true then
		local cursize = GET_MINIMAPSIZE();
		local dd = (100 + cursize) / 100;
		dd = 1 / dd;
		dd = CLAMP(dd, 0.5, 1.5);
		monPic:SetScale(dd, dd);
	end

	local imgName = GET_MAP_MON_MINIMAP_IMAGENAME(info)
	monPic:SetImage(imgName);
	monPic:SetEnableStretch(1);
	monPic:ShowWindow(1);

	MAP_MON_MINIMAP_SETPOS(frame, info);
end

function GET_MAP_MON_MINIMAP_IMAGENAME(info)
	local isPC = info.type == 0;
	if isPC then
		return GET_JOB_ICON(info.job);
	end
	if info.useIcon == true then
		if info.isDot == true then
			return "monster_notice_dot"
		else
			if info.changeIconName ~= "None" then
				return info.changeIconName
			end
			local monCls = GetClassByType("Monster", info.type);
			if monCls == nil or monCls.MinimapIcon == nil or monCls.MinimapIcon == "" or monCls.MinimapIcon == "None" then
				return "monster_notice_dot"
			end
			return monCls.MinimapIcon
		end
	end
	
	local myTeam = GET_MY_TEAMID();
	if info.teamID == 0 then
		return "fullyellow";
	elseif info.teamID ~= myTeam then
		return "fullred";
	else
		return "fullblue";
	end
end

function MAP_MON_MINIMAP_SETPOS(frame, info)
	
	_MAP_MON_MINIMAP_SETPOS(frame, info.handle, info.x, info.z);

	local ctrlName = "_MONPOS_" .. info.handle;
	local monPic = frame:GetChild(ctrlName);
	monPic:SetUserValue("POS_X", info.x);
	monPic:SetUserValue("POS_Z", info.z);	
	
end

function _MAP_MON_MINIMAP_SETPOS(frame, handle, x, z)

	local ctrlName = "_MONPOS_" .. handle;
	local monPic = frame:GetChild(ctrlName);
	local mapprop = session.GetCurrentMapProp();
	local width = monPic:GetUserIValue("W");
	local height = monPic:GetUserIValue("H");
	local XC, YC, sx, sy = GET_MAP_POS(frame, mapprop, x, z, width, height);
	
	XC = XC - sx / 2;
	YC = YC - sy / 2;
	monPic:SetOffset(XC, YC);
	monPic:Resize(sx, sy);

	ctrlName = "_MONPOS_T_" .. handle;
	local textC = frame:GetChild(ctrlName);
	if textC ~= nil then
		textC:SetOffset(XC + 0, YC + 0);
		textC:Resize(sx, sy);
	end

	if frame:GetTopParentFrame():GetName() == "minimap" then
		local cursize = GET_MINIMAPSIZE();
		local dd = (100 + cursize) / 100;
		dd = 1 / dd;
		dd = CLAMP(dd, 0.5, 1.5);
		monPic:SetScale(dd, dd);
	end

end

function ON_MON_MINIMAP_END(frame, msg, argStr, handle)

	if frame:GetName() == "minimap" then
		frame = GET_CHILD(frame, 'npclist', 'ui::CGroupBox');
	end

	frame:RemoveChild(string.format("_MONPOS_%d", handle));
	frame:RemoveChild(string.format("_MONPOS_T_%d", handle));
	frame:Invalidate();

end

function ARCHEOLOGY_CLEAR_MONSTER_MINIMAP_MARKS(handleList)
	local mapFrame = ui.GetFrame("map");
	local miniFrame = ui.GetFrame("minimap");

	local function removeAll(parent)
		if parent == nil then
			return;
		end

		local removeNames = {};
		for i = 0, parent:GetChildCount() - 1 do
			local child = parent:GetChildByIndex(i);
			if child ~= nil then
				local childName = child:GetName();
				if string.find(childName, "_MONPOS_", 1, true) == 1 then
					removeNames[#removeNames + 1] = childName;
				end
			end
		end

		for i = 1, #removeNames do
			parent:RemoveChild(removeNames[i]);
		end
		parent:Invalidate();
	end

	if handleList == "ALL" then
		removeAll(mapFrame);
		if miniFrame ~= nil then
			removeAll(GET_CHILD(miniFrame, 'npclist', 'ui::CGroupBox'));
			miniFrame:Invalidate();
		end
		return;
	end

	for handleText in string.gmatch(handleList or "", "[^;]+") do
		local handle = tonumber(handleText);
		if handle ~= nil then
			if mapFrame ~= nil then
				mapFrame:RemoveChild(string.format("_MONPOS_%d", handle));
				mapFrame:RemoveChild(string.format("_MONPOS_T_%d", handle));
				mapFrame:Invalidate();
			end

			if miniFrame ~= nil then
				local npcList = GET_CHILD(miniFrame, 'npclist', 'ui::CGroupBox');
				if npcList ~= nil then
					npcList:RemoveChild(string.format("_MONPOS_%d", handle));
					npcList:RemoveChild(string.format("_MONPOS_T_%d", handle));
					npcList:Invalidate();
				end
				miniFrame:Invalidate();
			end
		end
	end
end

function _MONPIC_AUTOUPDATE(ctrl)
	local handle = ctrl:GetUserIValue("HANDLE");	
	local actor = world.GetActor(handle);
	if actor ~= nil then
		local actorPos = actor:GetPos();
		ctrl:SetUserValue("POS_X", actorPos.x);
		ctrl:SetUserValue("POS_Y", actorPos.z);
		_MAP_MON_MINIMAP_SETPOS(ctrl:GetParent(), handle, actorPos.x, actorPos.z);
		return 1;
	end

	if ctrl:GetTopParentFrame():GetName() == "minimap" then
		local lastSize = ctrl:GetUserIValue("LASTSIZE");
		local cursize = GET_MINIMAPSIZE();
		if lastSize ~= cursize then
			ctrl:SetUserValue("LASTSIZE", cursize);
			
			local x = ctrl:GetUserIValue("POS_X");
			local y = ctrl:GetUserIValue("POS_Y");
			_MAP_MON_MINIMAP_SETPOS(ctrl:GetParent(), handle, x, y);
			ctrl:GetTopParentFrame():Invalidate();
		end
	end

	return 1;
end
