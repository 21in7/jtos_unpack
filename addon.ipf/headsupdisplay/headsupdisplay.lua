HEADSUPDISPLAY_OPTION = HEADSUPDISPLAY_OPTION or {}

-- Margins: left, top, right, bottom. [0] = no relic, [1] = relic equipped.
-- group moves the image and count together; background/count adjust them separately.
HEADSUPDISPLAY_SOULCRYSTAL_LAYOUT = {
	Default = {
		[0] = { group = {0, 3, 16, 0}, background = {0, 0, 0, 0}, count = {-6, 0, 0, 34} },
		[1] = { group = {0, 3, 16, 0}, background = {0, 0, 0, 0}, count = {-6, 0, 0, 34} },
	},
	NormalGrade = {
		[0] = { group = {0, 3, 16, 0}, background = {0, 0, 0, 0}, count = {-6, 0, 0, 34} },
		[1] = { group = {0, 3, 16, 0}, background = {0, 0, 0, 0}, count = {-6, 0, 0, 34} },
	},
	MagicGrade = {
		[0] = { group = {0, 3, 16, 0}, background = {0, 0, 0, 0}, count = {-6, 0, 0, 34} },
		[1] = { group = {0, 3, 16, 0}, background = {0, 0, 0, 0}, count = {-6, 0, 0, 34} },
	},
	UniqueGrade = {
		[0] = { group = {0, 3, 16, 0}, background = {0, 0, 0, 0}, count = {-6, 0, 0, 34} },
		[1] = { group = {0, 3, 16, 0}, background = {0, 0, 0, 0}, count = {-6, 0, 0, 34} },
	},
	LegendGrade = {
		[0] = { group = {0, 3, 16, 0}, background = {0, 0, 0, 0}, count = {-6, 0, 0, 34} },
		[1] = { group = {0, 3, 16, 0}, background = {0, 0, 0, 0}, count = {-6, 0, 0, 34} },
	},
	GoddessGrade = {
		[0] = { group = {0, 3, 16, 0}, background = {0, 0, 0, 0}, count = {-6, 0, 0, 34} },
		[1] = { group = {0, 3, 16, 0}, background = {0, 0, 0, 0}, count = {-6, 0, 0, 34} },
	},
	Archeology = {
		[0] = { group = {-9, 4, 16, 0}, background = {-5, 0, 0, 0}, count = {-10, 0, 0, 34} },
		[1] = { group = {-9, 4, 16, 0}, background = {-4, 0, 0, 0}, count = {-10, 0, 0, 34} },
	},
	ResonanceZawra = {
		[0] = { group = {-1, 4, 16, 0}, background = {-2, 0, 0, 0}, count = {-11, 0, 0, 34} },
		[1] = { group = {-5, 3, 16, 0}, background = {-5, 0, 0, 0}, count = {-11, 0, 0, 34} },
	},
}

function HEADSUPDISPLAY_ON_INIT(addon, frame)

	addon:RegisterOpenOnlyMsg('STANCE_CHANGE', 'HEADSUPDISPLAY_ON_MSG');
	addon:RegisterOpenOnlyMsg('NAME_UPDATE', 'HEADSUPDISPLAY_ON_MSG');
	addon:RegisterOpenOnlyMsg('STAT_UPDATE', 'HEADSUPDISPLAY_ON_MSG');
	addon:RegisterOpenOnlyMsg('TAKE_DAMAGE', 'HEADSUPDISPLAY_ON_MSG');
	addon:RegisterOpenOnlyMsg('TAKE_HEAL', 'HEADSUPDISPLAY_ON_MSG');
    
    addon:RegisterOpenOnlyMsg('STA_UPDATE', 'STAMINA_UPDATE');
    addon:RegisterOpenOnlyMsg('PC_PROPERTY_UPDATE', 'STAMINA_UPDATE');
    addon:RegisterOpenOnlyMsg('CANT_RUN_STA', 'CANT_RUN_ALARM');
    addon:RegisterOpenOnlyMsg('CANT_JUMP_STA', 'CANT_JUMP_ALARM');

	addon:RegisterMsg('CAUTION_DAMAGE_INFO', 'HEADSUPDISPLAY_ON_MSG');
	addon:RegisterMsg('CAUTION_DAMAGE_INFO_RELEASE', 'HEADSUPDISPLAY_ON_MSG');

	addon:RegisterMsg('STAT_UPDATE', 'HEADSUPDISPLAY_ON_MSG');
	addon:RegisterMsg('GAME_START', 'HEADSUPDISPLAY_ON_MSG');
	addon:RegisterMsg('LEVEL_UPDATE', 'HEADSUPDISPLAY_ON_MSG');

	addon:RegisterMsg('CHANGE_COUNTRY', 'HEADSUPDISPLAY_ON_MSG');

	addon:RegisterMsg("MYPC_CHANGE_SHAPE", "HEADSUPDISPLAY_ON_MSG");
    addon:RegisterMsg('GAME_START', 'HUD_SET_SAVED_OFFSET');
    addon:RegisterMsg('CHANGE_RESOLUTION', 'HUD_SET_SAVED_OFFSET');
    addon:RegisterMsg("CAMP_UPDATE", "HEADSUPDISPLAY_SET_CAMP_BTN");
    addon:RegisterMsg("PARTY_UPDATE", "HEADSUPDISPLAY_SET_CAMP_BTN");
	addon:RegisterMsg("SHOW_SOUL_CRISTAL", "HEADSUPDISPLAY_SHOW_SOUL_CRISTAL");
	addon:RegisterMsg("UPDATE_SOUL_CRISTAL", "HEADSUPDISPLAY_UPDATE_SOUL_CRISTAL");
	addon:RegisterMsg("UPDATE_REPRESENTATION_CLASS_ICON", "UPDATE_REPRESENTATION_CLASS_ICON");
	addon:RegisterMsg("UPDATE_RELIC_EQUIP", "HEADSUPDISPLAY_UPDATE_RELIC_EQUIP");
	addon:RegisterMsg("RP_UPDATE", "HEADSUPDISPLAY_UPDATE_RP_GAUGE")
	addon:RegisterMsg("PARTY_SKIN_REQUEST", "HEADSUPDISPLAY_ON_HUD_SKIN_REQUEST");

	local leaderMark = GET_CHILD(frame, "Isleader", "ui::CPicture");
	leaderMark:SetImage('None_Mark');
	HEADSUPDISPLAY_SET_HUD_SKIN_LEADER_MARK_MARGIN(frame);
	HEADSUPDISPLAY_SET_HUD_SKIN_JOB_PIC_MARGIN(frame);
	HEADSUPDISPLAY_SET_HUD_SKIN_SOULCRYSTAL_MARGIN(frame);

	SHOW_SOULCRYSTAL_COUNT(frame, 0)
	frame:SetEventScript(ui.LBUTTONDBLCLICK, "HEADSUPDISPLAY_DBC_ON");	
	local check = GET_CHILD_RECURSIVELY(frame, 'fix_pos')
	check:ShowWindow(0)
end

function HEADSUPDISPLAY_SET_HUD_SKIN_LEADER_MARK_MARGIN(frame)
	if frame == nil then
		return;
	end

	local leaderMark = GET_CHILD(frame, "Isleader", "ui::CPicture");
	if leaderMark == nil then
		return;
	end

	local marginX = 62;
	local marginY = 30;
	local selectGradeName = hud_skin.GetSelectHudGradeName();
	if selectGradeName == "Archeology" then
		marginX = 59;
		marginY = 30;
	elseif selectGradeName == "ResonanceZawra" then
		marginX = 59;
		marginY = 30;
	end

	leaderMark:SetMargin(marginX, marginY, 0, 0);
end

function HEADSUPDISPLAY_SET_HUD_SKIN_JOB_PIC_MARGIN(frame)
	if frame == nil then
		return;
	end

	local jobPic = GET_CHILD_RECURSIVELY(frame, "jobPic");
	if jobPic == nil then
		return;
	end

	local marginX = 16;
	local marginY = 6;
	local selectGradeName = hud_skin.GetSelectHudGradeName();
	if HEADSUPDISPLAY_OPTION.relic_equip == 1 then
		if selectGradeName == "Default" then
			marginX = 17;
			marginY = 6;
		elseif selectGradeName == "Archeology" then
			marginX = 15;
			marginY = 6;
		elseif selectGradeName == "ResonanceZawra" then
			marginX = 14;
			marginY = 4;
		else
			marginX = 17;
			marginY = 6;
		end
	else
		if selectGradeName == "Default" then
			marginX = 14;
			marginY = 6;
		elseif selectGradeName == "Archeology" then
			marginX = 16;
			marginY = 6;
		elseif selectGradeName == "ResonanceZawra" then
			marginX = 16;
			marginY = 4;
		else
			marginX = 17;
			marginY = 6;
		end
	end

	jobPic:SetMargin(marginX, marginY, 0, 0);
end

function HEADSUPDISPLAY_SET_HUD_SKIN_SOULCRYSTAL_MARGIN(frame)
	frame = frame or ui.GetFrame("headsupdisplay");
	if frame == nil then
		return 0;
	end

	local skin = hud_skin.GetSelectHudGradeName();
	local layouts = HEADSUPDISPLAY_SOULCRYSTAL_LAYOUT[skin] or HEADSUPDISPLAY_SOULCRYSTAL_LAYOUT.Default;
	local relicItem = session.GetEquipItemBySpot(item.GetEquipSpotNum('RELIC'));
	local relicEquip = 0;
	if relicItem ~= nil and relicItem.type == 11040003 then
		relicEquip = 1;
	end
	local layout = layouts[relicEquip];
	local controls = {
		soulCrystalGbox = layout.group,
		soulCrystal_bg = layout.background,
		soulCrystalCount = layout.count,
	};
	for name, margin in pairs(controls) do
		local control = GET_CHILD_RECURSIVELY(frame, name);
		if control ~= nil then
			control:SetMargin(margin[1], margin[2], margin[3], margin[4]);
		end
	end
	return 1;
end

-- Call with true while tuning, false when finished. No XML reload is needed.
function HEADSUPDISPLAY_PREVIEW_SOULCRYSTAL_LAYOUT(enable)
	local frame = ui.GetFrame("headsupdisplay");
	if frame == nil then
		return;
	end
	frame:StopUpdateScript("HEADSUPDISPLAY_SET_HUD_SKIN_SOULCRYSTAL_MARGIN");
	HEADSUPDISPLAY_SET_HUD_SKIN_SOULCRYSTAL_MARGIN(frame);
	if enable == true then
		frame:RunUpdateScript("HEADSUPDISPLAY_SET_HUD_SKIN_SOULCRYSTAL_MARGIN", 0.1);
	end
end

function HEADSUPDISPLAY_ON_HUD_SKIN_REQUEST(frame)
	HEADSUPDISPLAY_SET_HUD_SKIN_LEADER_MARK_MARGIN(frame);
	HEADSUPDISPLAY_SET_HUD_SKIN_JOB_PIC_MARGIN(frame);
	HEADSUPDISPLAY_SET_HUD_SKIN_SOULCRYSTAL_MARGIN(frame);
end

function HEADSUPDISPLAY_VIDEO_CAMERA_OPTION(frame, msg, argStr, argNum)    
	print("HEADSUPDISPLAY_VIDEO_CAMERA_OPTION", frame, msg, argStr, argNum)
	if argStr == "hide_hud_char_name" then
		HEADSUPDISPLAY_OPTION["hide_hud_char_name"] = argNum;
		HEADSUPDISPLAY_ON_MSG(frame, 'NAME_UPDATE', '', argNum )
	end
end

function UPDATE_REPRESENTATION_CLASS_ICON(frame, msg, argStr, argNum)    
    HUD_SET_EMBLEM(frame, argNum, 1)
    session.SetUserConfig("SELECT_SKLTREE", argNum)
end

function CANT_RUN_ALARM(frame, msg, argStr, argNum)
	local gauge_name = hud.GetHeadGuageName(2)

	local staGauge = GET_CHILD_RECURSIVELY(frame, gauge_name, 'ui::CGauge')
	staGauge:SetGrayStyle(0);
	ui.AlarmMsg("NotEnoughStamina");
	imcSound.PlaySoundEvent('stamina_alarm');

end

function CANT_JUMP_ALARM(frame, msg, argStr, argNum)
	CANT_RUN_ALARM(frame, msg, argStr, argNum);
end

function MOVETOCAMP(aid)
    if IS_IN_EVENT_MAP() == true then
        ui.SysMsg(ClMsg('ImpossibleInCurrentMap'));
        return;
    end
    if session.colonywar.GetIsColonyWarMap() == true then
        ui.SysMsg(ClMsg('ImpossibleInCurrentMap'));
	    return;
	end
	if GetExProp(GetMyPCObject(), 'BOUNTYHUNT_PLAYING') == 1 then
		ui.SysMsg(ClMsg('WarpBanBountyHunt'));
		return;
	end
	session.party.RequestMoveToCamp(aid);
end

function CONTEXT_MY_INFO(frame, ctrl)
	local list = session.party.GetPartyMemberList(PARTY_NORMAL);
	local count = list:Count();

	-- 파티원이 존재 할 때
	if 0 < count then
		local context = ui.CreateContextMenu("CONTEXT_PARTY", "", 0, 0, 170, 100);
		local campCount = 0;
		for i = 0 , count - 1 do
			local partyMemberInfo = list:Element(i);
			local map = GetClassByType("Map", partyMemberInfo.campMapID);
			if  nil ~= map then
				campCount = campCount +1;
			end
		end
		if 0 < campCount then
			local str =  string.format("{@st41b}%s(%d)", ClMsg("MoveToCampChar"), campCount);
			ui.AddContextMenuItem(context, str, "None");
		end

		for i = 0 , count - 1 do
			local partyMemberInfo = list:Element(i);
			if partyMemberInfo.campMapID ~= 0 then
				local map = GetClassByType("Map", partyMemberInfo.campMapID);
				if nil ~= map then
					local obj = GetIES(partyMemberInfo:GetObject());
					str = string.format("      {@st59s}{#FFFF00}%s {#FFFFFF}%s",obj.Name, map.Name);
					ui.AddContextMenuItem(context, str, string.format("MOVETOCAMP(\"%s\")", partyMemberInfo:GetAID()));
				end
			end
		end
		ui.AddContextMenuItem(context, ScpArgMsg("WithdrawParty"), "OUT_PARTY()");	
		ui.AddContextMenuItem(context, ScpArgMsg("Cancel"), "None");
		ui.OpenContextMenu(context);
		return;
	end

	local mapID = session.loginInfo.GetSquireMapID();
	local map = GetClassByType("Map", mapID);
	if nil == map then
		return;
	end
	
	local context = ui.CreateContextMenu("CONTEXT_PARTY", "", 0, 0, 170, 100);
	local str =  string.format("{@st41b}%s(1)", ClMsg("MoveToCampChar"));
	ui.AddContextMenuItem(context, str, "None");

	local obj = GetMyPCObject();
	str = string.format("      {@st59s}{#FFFF00}%s {#FFFFFF}%s",obj.Name, map.Name);
	ui.AddContextMenuItem(context, str, string.format("MOVETOCAMP(\"%s\")", session.loginInfo.GetAID()));
	ui.AddContextMenuItem(context, ScpArgMsg("Cancel"), "None");
	ui.OpenContextMenu(context);
end

function HEADSUPDISPLAY_ON_MSG(frame, msg, argStr, argNum)	
	if msg == 'GAME_START' then
		local equip = 1
		local relic_item = session.GetEquipItemBySpot(item.GetEquipSpotNum('RELIC'))
		local relic_obj = GetIES(relic_item:GetObject())
		if IS_NO_EQUIPITEM(relic_obj) == 1 then
			equip = 0
		end
		HEADSUPDISPLAY_OPTION['relic_equip'] = equip

		HEADSUPDISPLAY_UPDATE_RP_VISIBLE(frame, equip)
	end

	local hp_name = hud.GetHeadGuageName(0)
	local sp_name = hud.GetHeadGuageName(1)

	local hpGauge = GET_CHILD_RECURSIVELY(frame, hp_name, 'ui::CGauge')
	local spGauge = GET_CHILD_RECURSIVELY(frame, sp_name, 'ui::CGauge')
	if msg == 'STANCE_CHANGE' or msg == 'NAME_UPDATE' or msg == 'LEVEL_UPDATE' or msg == 'GAME_START' or msg == 'CHANGE_COUNTRY' or msg == 'MYPC_CHANGE_SHAPE' then
		local levelRichText = GET_CHILD(frame, "level_text", "ui::CRichText");
		local level = GETMYPCLEVEL();
		levelRichText:SetText('{@st41}Lv. '..level);
		
		local MySession = session.GetMyHandle()
		local CharName = info.GetFamilyName(MySession);
		local nameRichText = GET_CHILD(frame, "name_text", "ui::CRichText");
		nameRichText:SetText('{@st41}'..CharName)
        		        
		nameRichText:SetEventScript(ui.LBUTTONDBLCLICK, "HEADSUPDISPLAY_DBC_ON");	
        local etc = GetMyEtcObject()
        local MyJobNum = TryGetProp(etc, 'RepresentationClassID', 'None')
        if MyJobNum == 'None' or tonumber(MyJobNum) == 0 then
            MyJobNum = info.GetJob(MySession);
        end

		local JobCtrlType = GetClassString('Job', MyJobNum, 'CtrlType');
		config.SetConfig("LastJobCtrltype", JobCtrlType);
		config.SetConfig("LastPCLevel", level);

		if msg == 'GAME_START' or msg == 'MYPC_CHANGE_SHAPE' then
			HUD_SET_EMBLEM(frame, MyJobNum, 1);
		else
			HUD_SET_EMBLEM(frame, MyJobNum);
		end
        session.SetUserConfig("SELECT_SKLTREE", MyJobNum)
 		
	end

	if msg == 'LEVEL_UPDATE' or msg == 'STAT_UPDATE' or msg == 'TAKE_DAMAGE' or msg == 'TAKE_HEAL' or msg == 'GAME_START' or msg == 'CHANGE_COUNTRY' then		
		local stat = info.GetStat(session.GetMyHandle());
		if stat ~= nil then
			local beforeVal = hpGauge:GetCurPoint();
			if beforeVal > 0 and stat.HP < beforeVal then
				UI_PLAYFORCE(hpGauge, "gauge_damage");
			end

			hpGauge:SetMaxPointWithTime(stat.HP, stat.maxHP, 0.1, 0.5);
			spGauge:SetMaxPointWithTime(stat.SP, stat.maxSP, 0.1, 0.5);

			local hpRatio = stat.HP / stat.maxHP;
			if hpRatio <= 0.3 and hpRatio > 0 then
				--hpGauge:SetBlink(0.0, 1.0, 0xffff3333); -- (duration, 주기, 색상) -- 게이지 양 끝에 점멸되는 버그 잡고 써야함.
			else
				hpGauge:ReleaseBlink();
			end

		end
		frame:Invalidate();
	end

	if msg == 'CAUTION_DAMAGE_INFO' then
		CAUTION_DAMAGE_INFO(argNum);
	elseif msg == 'CAUTION_DAMAGE_INFO_RELEASE' then
		CAUTION_DAMAGE_INFO_RELEASE();
	end
end

function HUD_SET_EMBLEM(frame, jobClassID, isChangeMainClass)
    local jobCls = GetClassByType('Job', jobClassID);
    local jobIcon = TryGetProp(jobCls, 'Icon');
    if jobIcon == nil then
        return;
    end    
	
    local mySession = session.GetMySession();
    local jobPic = GET_CHILD_RECURSIVELY(frame, 'jobPic');
	local myhpspleft = GET_CHILD_RECURSIVELY(frame, 'myhpspleft');
	jobPic:SetImage(jobIcon);	
    UPDATE_MY_JOB_TOOLTIP(jobClassID, jobPic, jobCls, isChangeMainClass);
    HEADSUPDISPLAY_SET_CAMP_BTN(frame);
	HEADSUPDISPLAY_SET_HUD_SKIN_LEADER_MARK_MARGIN(frame);
	HEADSUPDISPLAY_SET_HUD_SKIN_JOB_PIC_MARGIN(frame);
	HEADSUPDISPLAY_SET_HUD_SKIN_SOULCRYSTAL_MARGIN(frame);
end

function STAMINA_UPDATE(frame, msg, argStr, argNum)
	session.UpdateMaxStamina();

	local sta_name = hud.GetHeadGuageName(2)

	local stGauge = GET_CHILD_RECURSIVELY(frame, sta_name, 'ui::CGauge')
	stGauge:ShowWindow(1)
	
	local stat = info.GetStat(session.GetMyHandle());
	if stat ~= nil then
		stGauge:StopTimeProcess();
		local stamanaValue = stat.Stamina;

		if stamanaValue > 0 then
			stamanaValue = stamanaValue + 999;		-- ui에서 0인데 실제로는 아직 sta가 남아있어서 ui출력할때 999더해서 출력함. 1000으로하면 max보다 올라가므로 999로.
		end

		stGauge:SetPoint( math.floor(stamanaValue / 1000), stat.MaxStamina / 1000);

		local staRatio = stat.Stamina / stat.MaxStamina;
		if staRatio <= 0.3 and staRatio > 0 then
			stGauge:SetBlink(0.0, 1.0, 0xffffffff);
		else
			stGauge:ReleaseBlink();
		end
	end
end

function CAUTION_DAMAGE_INFO(damage)
	local frame = ui.GetFrame('charbaseinfo');
	local hp_name = 'hp'
	if HEADSUPDISPLAY_OPTION.relic_equip == 1 then
		hp_name = 'hp_relic'
	end
	local hpGauge = GET_CHILD_RECURSIVELY(frame, hp_name, 'ui::CGauge')


	hpGauge:SetCautionBlink(damage, 1.0, 0xffffffff);
end

function CAUTION_DAMAGE_INFO_RELEASE()
	local frame = ui.GetFrame('charbaseinfo');
	local hp_name = 'hp'
	if HEADSUPDISPLAY_OPTION.relic_equip == 1 then
		hp_name = 'hp_relic'
	end

	local hpGauge = GET_CHILD_RECURSIVELY(frame, hp_name, 'ui::CGauge')

	hpGauge:ReleaseCautionBlink();
end

function SET_CONFIG_HEADSUP_HUD_OFFSET(frame)
    local x = frame:GetX();
	local y = frame:GetY();
	
    local name = frame:GetName();
    local width = option.GetClientWidth();
	local height = option.GetClientHeight(); 			
	config.SetHUDConfigRatio(name, x / width, y / height);		
	config.SaveHUDConfig()
end

function GET_CONFIG_HEADSUP_HUD_OFFSET(frame, defaultX, defaultY)
    local name = frame:GetName();
    if config.IsExistHUDConfig(name) ~= 1 then
        return defaultX, defaultY;
	end
	
	local x = math.floor(config.GetHUDConfigXRatio(name) * option.GetClientWidth());
    local y = math.floor(config.GetHUDConfigYRatio(name) * option.GetClientHeight());

    return x, y;
end

function HEADSUPDISPLAY_LBTN_UP(frame, msg, argStr, argNum)
    SET_CONFIG_HEADSUP_HUD_OFFSET(frame);
end

function POST_HUD_SET_SAVED_OFFSET(frame, msg, argStr, argNum)		
	if frame == nil then
		frame = ui.GetFrame('headsupdisplay')
	end
		
	local savedX, savedY = GET_CONFIG_HEADSUP_HUD_OFFSET(frame, frame:GetOriginalX(), frame:GetOriginalY());	
	local _savedX, _savedY = GET_OFFSET_IN_SCREEN(savedX, savedY, frame:GetWidth(), frame:GetHeight());    		
    
	_savedX = math.max(_savedX, frame:GetX() / option.GetClientWidth());
	_savedY = math.max(_savedY, frame:GetY()/ option.GetClientHeight());  		
	frame:SetOffset(_savedX, _savedY);
	
	if savedX ~= _savedX or savedY ~= _savedY then
		SET_CONFIG_HEADSUP_HUD_OFFSET(frame);
	end
end

function HUD_SET_SAVED_OFFSET(frame, msg, argStr, argNum)	
	if frame == nil then
		frame = ui.GetFrame('headsupdisplay')
	end
		
	local savedX, savedY = GET_CONFIG_HEADSUP_HUD_OFFSET(frame, frame:GetOriginalX(), frame:GetOriginalY());	
	local _savedX, _savedY = GET_OFFSET_IN_SCREEN(savedX, savedY, frame:GetWidth(), frame:GetHeight());    		
	_savedX = math.max(_savedX, frame:GetX() / option.GetClientWidth());
	_savedY = math.max(_savedY, frame:GetY()/ option.GetClientHeight());  		
	frame:SetOffset(_savedX, _savedY);
	
	if savedX ~= _savedX or savedY ~= _savedY then
		SET_CONFIG_HEADSUP_HUD_OFFSET(frame);
	end
	
	ReserveScript('POST_HUD_SET_SAVED_OFFSET()', 1);
end

function HEDADSUPDISPLAY_CAMP_BTN_CLICK(parent, ctrl)
	local list = session.party.GetPartyMemberList(PARTY_NORMAL);
	local count = list:Count();
    -- 파티원이 존재 할 때
	if 0 < count then
		local context = ui.CreateContextMenu("CONTEXT_PARTY", "", 0, 0, 170, 100);
		local campCount = 0;
		for i = 0 , count - 1 do
			local partyMemberInfo = list:Element(i);
			local map = GetClassByType("Map", partyMemberInfo.campMapID);
			if  nil ~= map then
				campCount = campCount + 1;
			end
		end

		if 0 < campCount then
			local str =  string.format("{@st41b}%s(%d)", ClMsg("MoveToCampChar"), campCount);
			ui.AddContextMenuItem(context, str, "None");
		else
			local str =  string.format("{@st41b}%s", ClMsg("MoveToCampChar"));
			ui.AddContextMenuItem(context, str, "None");
		end
		
		if session.loginInfo.GetSquireMapID() ~= nil and session.loginInfo.GetSquireMapID() ~= 0 then
			local map = GetClassByType("Map", session.loginInfo.GetSquireMapID());
			if nil ~= map then
				local obj = GetMyPCObject();
				str = string.format("      {@st59s}{#FFFF00}%s {#FFFFFF}%s",obj.Name, map.Name);
				ui.AddContextMenuItem(context, str, string.format("MOVETOCAMP(\"%s\")", session.loginInfo.GetAID()));
			end
		end
		
		for i = 0 , count - 1 do
			local partyMemberInfo = list:Element(i);
			if partyMemberInfo.campMapID ~= 0 then
				local map = GetClassByType("Map", partyMemberInfo.campMapID);
				if nil ~= map then
					local obj = GetIES(partyMemberInfo:GetObject());
					str = string.format("      {@st59s}{#FFFF00}%s {#FFFFFF}%s",obj.Name, map.Name);
					ui.AddContextMenuItem(context, str, string.format("MOVETOCAMP(\"%s\")", partyMemberInfo:GetAID()));
				end
			end
		end
		
		ui.AddContextMenuItem(context, ScpArgMsg("Cancel"), "None");
		ui.OpenContextMenu(context);
		return;
	end

	local mapID = session.loginInfo.GetSquireMapID();
	local map = GetClassByType("Map", mapID);
	if nil == map then
		return;
	end
	
	local context = ui.CreateContextMenu("CONTEXT_PARTY", "", 0, 0, 170, 100);
	local str =  string.format("{@st41b}%s(1)", ClMsg("MoveToCampChar"));
	ui.AddContextMenuItem(context, str, "None");
	local obj = GetMyPCObject();
	local actor = world.GetActorByFamilyName(tostring(obj.Name));
	if actor ~= nil then
		if actor:IsMyPC() == 1 then
			str = string.format("      {@st59s}{#FFFF00}%s {#FFFFFF}%s", obj.Name, map.Name);
		else
			str = string.format("      {@st59s}{#FFFF00}%s {#FFFFFF}%s {#FF0000}%s", obj.Name, map.Name, ClMsg("CanNotMoveCamp"));
		end
	end

	ui.AddContextMenuItem(context, str, string.format("MOVETOCAMP(\"%s\")", session.loginInfo.GetAID()));
	
	ui.AddContextMenuItem(context, ScpArgMsg("Cancel"), "None");
	ui.OpenContextMenu(context);
end

function HEADSUPDISPLAY_SET_CAMP_BTN(frame)
    local campBtn = frame:GetChild('campBtn');
    local list = session.party.GetPartyMemberList(PARTY_NORMAL);
	local count = list:Count();
    -- 파티원이 존재 할 때
	if 0 < count then
        local campCount = 0;
		for i = 0 , count - 1 do
			local partyMemberInfo = list:Element(i);
			local map = GetClassByType("Map", partyMemberInfo.campMapID);            
			if nil ~= map then
				campCount = campCount +1;
			end
		end
        if campCount > 0 then            
            campBtn:ShowWindow(1);
            return;
        end
    end
        
    local mapID = session.loginInfo.GetSquireMapID();
	local map = GetClassByType("Map", mapID);
	if nil == map then
        campBtn:ShowWindow(0);
		return;
	end
    campBtn:ShowWindow(1);
end

function HEADSUPDISPLAY_SHOW_SOUL_CRISTAL(frame, msg, argStr, argNum)
	SHOW_SOULCRYSTAL_COUNT(frame, 1, argStr)
	UPDATE_SOULCRYSTAL_COUNT(frame, 0, argNum)
end

function HEADSUPDISPLAY_UPDATE_SOUL_CRISTAL(frame, msg, argStr, argNum)
	UPDATE_SOULCRYSTAL_COUNT(frame, argNum, tonumber(argStr))
end

function SHOW_SOULCRYSTAL_COUNT(frame, isShow, limitFlag)
	local frame = ui.GetFrame('headsupdisplay');
	if frame ~= nil then
		local soulCrystalGbox = GET_CHILD_RECURSIVELY(frame, "soulCrystalGbox");
		if soulCrystalGbox ~= nil then
			soulCrystalGbox:ShowWindow(isShow);
		end
		
		if limitFlag == "limited" or limitFlag == 1 then
			frame:SetUserValue("limitFlag", 1);
		elseif limitFlag == "unlimited" or limitFlag == 0 then
			frame:SetUserValue("limitFlag", 0);
		end
	end
end

function UPDATE_SOULCRYSTAL_COUNT(frame, curCount, maxCount)
	local frame = ui.GetFrame('headsupdisplay');
	if frame ~= nil then
		local soulCrystalCount = GET_CHILD_RECURSIVELY(frame, "soulCrystalCount")
		local limitFlag = frame:GetUserIValue("limitFlag");
		if limitFlag == 1 or maxCount > 0 then
			if limitFlag ~= 1 then
				frame:SetUserValue("limitFlag", 1)
			end
			local casting_text = tolua.cast(soulCrystalCount, "ui::CRichText");
			casting_text:SetFormat(" {@st43b}{s16}{#ff2c2c}%s{@st43b}{s16}/%s");
			casting_text:UpdateFormat();

			local count = frame:GetUserIValue('MAX_COUNT');
			if count == 0 and maxCount ~= 0 then
				frame:SetUserValue('SOULCRYSTAL_MAX_COUNT', maxCount);
			else
				maxCount = frame:GetUserIValue('SOULCRYSTAL_MAX_COUNT');
			end
			curCount = maxCount - curCount;
			soulCrystalCount:SetTextByKey("curCount", curCount);
			soulCrystalCount:SetTextByKey("maxCount", maxCount);
		else
			local casting_text = tolua.cast(soulCrystalCount, "ui::CRichText");
			casting_text:SetFormat(" {@st43b}{s16}{#ff2c2c}%s{@st43b}{s16}%s");
			casting_text:UpdateFormat();

			soulCrystalCount:SetTextByKey("curCount", "");
			soulCrystalCount:SetTextByKey("maxCount", "{img infinity_text_red 20 10}");	
		end
		soulCrystalCount:Invalidate();
		SHOW_SOULCRYSTAL_COUNT(frame, 1, limitFlag);
	end
end

function HEADSUPDISPLAY_UPDATE_RP_VISIBLE(frame, type)
	HEADSUPDISPLAY_OPTION['relic_equip'] = type
	HEADSUPDISPLAY_SET_HUD_SKIN_SOULCRYSTAL_MARGIN(frame);

	local jopicon = GET_CHILD_RECURSIVELY(frame, 'jobPic');

	STAMINA_UPDATE(frame)
	HEADSUPDISPLAY_UPDATE_RP_GAUGE(frame)


end

function HEADSUPDISPLAY_UPDATE_RELIC_EQUIP(frame, msg, argStr, argNum)
	HEADSUPDISPLAY_UPDATE_RP_VISIBLE(frame, argNum)
end

function HEADSUPDISPLAY_UPDATE_RP_GAUGE(frame)
	if HEADSUPDISPLAY_OPTION.relic_equip == 0 then
		return
	end
	local rpname =  hud.GetHeadGuageName(3);
	local rpGauge = GET_CHILD_RECURSIVELY(frame, rpname, 'ui::CGauge')
	rpGauge:ShowWindow(1)
	
	rpGauge:StopTimeProcess()

	local pc = GetMyPCObject()
	local cur_rp, max_rp = shared_item_relic.get_rp(pc)

	rpGauge:SetPoint(cur_rp, max_rp)

	local rpRatio = cur_rp / max_rp
	if rpRatio <= 0.3 and rpRatio > 0 then
		rpGauge:SetBlink(0.0, 1.0, 0xffffffff)
	else
		rpGauge:ReleaseBlink()
	end
end

function HEADSUPDISPLAY_DBC_ON(frame, str, num)
	local check = GET_CHILD_RECURSIVELY(frame, 'fix_pos')
	if check ~= nil then
		local visible = check:IsVisible()
		if visible == 1 then
			check:ShowWindow(0)
		else
			check:ShowWindow(1)
		end
	end
end