--- skillshared.lua

function SKILL_TARGET_ITEM_Swordman_Thrust(obj)
	
		
	return 1;	
end

function GET_NINJA_SKILLS()

	local retList = {};
	retList[#retList + 1] = "Shinobi_Kunai";
	retList[#retList + 1] = "Shinobi_Mijin_no_jutsu";
	retList[#retList + 1] = "Shinobi_Katon_no_jutsu";
	retList[#retList + 1] = "Shinobi_Raiton_no_Jutsu";
	return retList;

end

function GET_HOMUNCULUS_SKILLS()

	local retList = {};
	retList[#retList + 1] = "Wizard_Sleep";
	retList[#retList + 1] = "Wizard_Lethargy";
	retList[#retList + 1] = "Wizard_MagicMissile";
	retList[#retList + 1] = "Pyromancer_FireBall";
	retList[#retList + 1] = "Pyromancer_EnchantFire";
	retList[#retList + 1] = "Pyromancer_FirePillar";
	retList[#retList + 1] = "Cryomancer_IceBolt";	
	retList[#retList + 1] = "Cryomancer_IceWall";
	retList[#retList + 1] = "Cryomancer_IciclePike";
	retList[#retList + 1] = "Cryomancer_SubzeroShield";
	retList[#retList + 1] = "Cryomancer_Gust";
	retList[#retList + 1] = "Linker_JointPenalty";
	retList[#retList + 1] = "Linker_Physicallink";
	retList[#retList + 1] = "Psychokino_Swap";
	retList[#retList + 1] = "Psychokino_Teleportation";
	retList[#retList + 1] = "Psychokino_Raise";
	retList[#retList + 1] = "Psychokino_MagneticForce";
	retList[#retList + 1] = "Elementalist_StoneCurse";
	retList[#retList + 1] = "Elementalist_Rain";
--	retList[#retList + 1] = "Chronomancer_Quicken";
	retList[#retList + 1] = "Chronomancer_Slow";
	retList[#retList + 1] = "Chronomancer_Stop";
	retList[#retList + 1] = "Thaumaturge_ShrinkBody";
	retList[#retList + 1] = "Thaumaturge_SwellBody";
	
	return retList;

end

function GET_ENCHANTARMOR_OPTION(sklLv)

	local retList = {};
	retList[#retList + 1] = "ENCHANTARMOR_SOLID";
	retList[#retList + 1] = "ENCHANTARMOR_HEALING";
	retList[#retList + 1] = "ENCHANTARMOR_PROTECTIVE";
	retList[#retList + 1] = "ENCHANTARMOR_BLESSING";
	retList[#retList + 1] = "ENCHANTARMOR_HOLY";
	retList[#retList + 1] = "ENCHANTARMOR_VOLITIVE";
	local maxCnt = math.min(sklLv+1, 6);
	local tempList = {}
	for i = 1, maxCnt do
		tempList[i] = retList[i];
	end

	return tempList;
end

function SAGE_PORTAL_SKL_PORTAL_COOLTIME(skill)
	return 1800 - (skill.Level - 1) * 60;
end

function GET_TEMPLAR_GUILD_SKIL_LIST()
	local sklList = {"Templer_BuildForge", "Templer_BuildShieldCharger"};

	return sklList;
end

function HAS_GUILDGROWTH_SKL_OBJ(guildObj, sklName, sklLv)

	local objName = 'None'
	if string.find(sklName, 'Forge') ~= nil then
		objName = 'Forge_';
	elseif string.find(sklName, 'ShieldCharger') ~= nil then
		objName = 'ShieldCharger_';
	end

	if objName == 'None' then
		return false;
	end

	local objCount = 0;
	local propName = 'BuildingLife_'..objName;
	for i = 1, 5 do
		local propValue = TryGetProp(guildObj, propName..i);
		if nil == propValue then
			return false;
		end

		if propValue ~= 'None' then
			objCount = objCount + 1;
		end
	end
	
	if sklLv < objCount then
		return false;
	end

	return true;
end

function SCR_ARRAY_SHUFFLE(arr_val)
    if arr_val ~= nil then
        if type(arr_val) == 'table' then
            local i;
            local temp_arr;
            local rnd;
            for i = 1, #arr_val do
                rnd = IMCRandom(i, #arr_val);
                if rnd ~= i then
                    temp_arr = arr_val[i];
                    arr_val[i] = arr_val[rnd];
                    arr_val[rnd] = temp_arr;
                end
            end            
        end
    end
    return arr_val;
end


function SCR_USER_SHOP_PIRCE_DEFAULT(shopClassName)
	local shopClass = GetClass("UserShopPrice", shopClassName);
	if shopClass == nil then
		return 0;
	end
	
	local price = TryGetProp(shopClass, "DefaultPrice", 0);
	
	local minPrice = TryGetProp(shopClass, "MinPrice");
	local maxPrice = TryGetProp(shopClass, "MaxPrice");
	
	price = math.min(math.max(price, minPrice), maxPrice);
	
	return math.floor(price);
end


function SCR_GET_ROASTING_PRICE(shopClassName, mapClassName, buffClassName, abilList)
	local price = SCR_USER_SHOP_PIRCE_DEFAULT(shopClassName)
	
	return math.floor(price);
end

function SCR_GET_ITEMAWAKENING_PRICE(shopClassName, mapClassName, buffClassName, abilList)
	local price = SCR_USER_SHOP_PIRCE_DEFAULT(shopClassName)
	
	return math.floor(price);
end

function SCR_GET_PORTALSHOP_PRICE(shopClassName, mapClassName, buffClassName, abilList)
	local price = SCR_USER_SHOP_PIRCE_DEFAULT(shopClassName)
	
	return math.floor(price);
end

function SCR_GET_ENCHANTARMOR_PRICE(shopClassName, mapClassName, buffClassName, abilList)
	local price = SCR_USER_SHOP_PIRCE_DEFAULT(shopClassName)
	
	return math.floor(price);
end

function SCR_GET_SPELLSHOP_PRICE(shopClassName, mapClassName, buffClassName, abilList)
--	if buffClassName == 'Priest_Aspersion' then
--		return 714;
--	end
--	
--	if buffClassName == 'Priest_Blessing' then
--		return 714;
--	end
--	
--	if buffClassName == 'Priest_Sacrament' then
--		return 700;
--	end
--	
--	if buffClassName == 'Pardoner_IncreaseMagicDEF' then
--		return 714;
--	end
--	
--	return 100;
	local price = SCR_USER_SHOP_PIRCE_DEFAULT(shopClassName)
	local mapClass = GetClass("Map", mapClassName);
	if TryGetProp(mapClass, "MapType") == "Dungeon" then
--		for i = 1, #abilList do
--			if abilList[i].ClassName == "Pardoner8" then
--				price = 1200
--				
--				break
--			end
--		end
		price = 1200
	end
	
	return math.floor(price);
end

function SCR_GET_SWITCHGENDER_PRICE(shopClassName, mapClassName, buffClassName, abilList)
	local price = SCR_USER_SHOP_PIRCE_DEFAULT(shopClassName)
	
	return math.floor(price);
end

-- deprecated: buff_seller_info.xml에 적어주세요 
-- function GET_BUFFSELLER_SPEND_ITEM_COUNT(sklClassName)
-- 	if sklClassName == "Priest_Aspersion" then
-- 		return 10;
-- 	end
	
-- 	if sklClassName == "Priest_Blessing" then
-- 		return 25;
-- 	end
	
-- 	if sklClassName == "Priest_Sacrament" then
-- 		return 14;
-- 	end
	
-- 	if sklClassName == "Pardoner_IncreaseMagicDEF" then
-- 		return 10;
-- 	end
	
-- 	return 0;
-- end

-- 부활을 시키지 않을꺼면 0을 반환
--여기를 고칠 땐 
function SCR_ENABLE_RESURRECT_BY_BACKMASKING(pc)
	-- 여기에서 부활을 해줄지 말지 판정해준다
	if IsRaidField(pc) == 1 then
        local pcAidx = tonumber(GetPcAIDStr(pc));
        local mGameValue = "resurrection_" .. pcAidx
        if GetMGameValue(pc, mGameValue) == nil or GetMGameValue(pc, mGameValue) == 0 then
            return 1;
        else
            return 0;
        end
    end

    return 1 -- 기본적으론 1을 반환하여 부활을 허용한다.
end

function SCR_GET_EQUIPMENTTOUCHUP_PRICE(shopClassName, mapClassName, buffClassName, abilList)
	local price = SCR_USER_SHOP_PIRCE_DEFAULT(shopClassName)
	local mapClass = GetClass("Map", mapClassName);
	if TryGetProp(mapClass, "MapType") == "Dungeon" then
--		for i = 1, #abilList do
--			if abilList[i].ClassName == "Squire13" then
--				price = 500
--				
--				break
--			end
--		end
		price = 500
	end
	
	return math.floor(price);
end

function SCR_GET_REPAIR_PRICE(shopClassName, mapClassName, buffClassName, abilList)
	local price = SCR_USER_SHOP_PIRCE_DEFAULT(shopClassName)
	local mapClass = GetClass("Map", mapClassName);
	if TryGetProp(mapClass, "MapType") == "Dungeon" then
--		for i = 1, #abilList do
--			if abilList[i].ClassName == "Squire12" then
--				price = 200
--				
--				break
--			end
--		end
		price = 200
	end
	
	return math.floor(price);
end

function SCR_GET_APPRISE_PRICE(shopClassName, mapClassName, buffClassName, abilList)
	local price = SCR_USER_SHOP_PIRCE_DEFAULT(shopClassName)
	
	return math.floor(price);
end

-- 해당 skill에 checkKeyword 키워드가 존재하는지 체크. 있으면 1 반환, 없으면 0 반환.
function CHECK_SKILL_KEYWORD(skill, checkKeyword)
	local skillKeyword = TryGetProp(skill, 'Keyword');
	if skillKeyword ~= nil and skillKeyword ~= 'None' then
		local skillKeywordList = SCR_STRING_CUT(skillKeyword, ';')
		local index = table.find(skillKeywordList, checkKeyword);
		if index ~= 0 then
			return 1;
		end
	end
	
	return 0;
end


-- 버프 강화 특성 증가 비율 계산-------
-- calc_property_skill.lua 의 function SCR_REINFORCEABILITY_TOOLTIP(skill) 와 내용 동일함
-- 같이 변경해야 함
-- done , 해당 함수 내용은 cpp로 이전되었습니다. 변경 사항이 있다면 반드시 프로그래팀에 알려주시기 바랍니다.
function SCR_REINFORCEABILITY_FOR_BUFFSKILL(self, skill)
	local ignore_hidden_list = {
		"Oracle_CounterSpell",
		"Dievdirbys_CarveAustrasKoks",
	}
	
    local addRate = 1;
    if self ~= nil and skill ~= nil then
        local reinforceAbilName = TryGetProp(skill, "ReinforceAbility", "None");
        if reinforceAbilName ~= "None" then
            local reinforceAbil = GetAbility(self, reinforceAbilName)
            if reinforceAbil ~= nil then
                local abilLevel = TryGetProp(reinforceAbil, "Level")
                local masterAddValue = 0
                if abilLevel == 100 then
                    masterAddValue = 0.1
                end
                
                addRate = addRate + (abilLevel * 0.005 + masterAddValue);
				
				local hidden_abil_cls = GetClass("HiddenAbility_Reinforce", skill.ClassName);
				if table.find(ignore_hidden_list, skill.ClassName) == 0 and abilLevel >= 65 and hidden_abil_cls ~= nil then
					local hidden_abil_name = TryGetProp(hidden_abil_cls, "HiddenReinforceAbil");
					local hidden_abil = GetAbility(self, hidden_abil_name);
					if hidden_abil ~= nil then
						local abil_level = TryGetProp(hidden_abil, "Level");
						local add_factor = TryGetProp(hidden_abil_cls, "FactorByLevel", 0) * 0.01;
						local add_value = 0;
						if abil_level == 10 then
							add_value = TryGetProp(hidden_abil_cls, "AddFactor", 0) * 0.01
						end
						
						addRate = addRate * (1 + (abil_level * add_factor) + add_value);
					end
				end
            end
        end
	end
	
    return addRate
end

function CHECK_SKILL_REQSTANCE(skill, checkReqStance)
	local className = TryGetProp(skill, 'ClassName', 'None')
	if IsNormalSkill(className) == 1 or IsExpertSkill(className) == 1 then
		local skillReqStance = TryGetProp(skill, 'ReqStance', 'None')
		if skillReqStance == 'None' then
			return 1
		end

		local skillReqStanceList = SCR_STRING_CUT(skillReqStance, ';')
		local index = table.find(skillReqStanceList, checkReqStance)
		if index > 0 then
			return 1
		end
	end
	
	return 0;
end

function SCR_GET_FOODTABLE_PRICE(shopClassName, mapClassName, buffClassName, abilList)
	return 0;
end

function SCR_GET_OBLATION_PRICE(shopClassName, mapClassName, buffClassName, abilList)
	return 1;
end

function igbore_skill_list_check(sklName, list)
	for i = 1, #list do
		if sklName == list[i] then
			return 0;
		end
	end
	return 1;
end

function ignore_skill_hit_check(target)
	if IsBuffApplied(target, 'InfernalShadow_Debuff') == "YES" then
		return 1;
	end

	return 0;
end
-- ============================================================================
-- 무적 연계 차단 (글로벌 쿨다운) — 서버/클라 공용 정의
--   UseGlobalCoolTime 키워드를 가진 무적 스킬끼리, 하나를 쓰면 나머지의
--   재사용 대기시간이 5초 미만일 때 5초로 조정된다.
--
--   이 시스템의 데이터(대기시간, 특성 예외)는 전부 여기에만 둔다.
--     서버 : skill_buff_pc.lua  SCR_GLOBAL_COOLDOWN / SCR_GLOBAL_ABIL_COOLDOWN
--     클라 : tooltip.lua        MAKE_GLOBAL_COOLDOWN_CAPTION
--   양쪽이 같은 함수를 쓰므로 툴팁 표기와 실제 동작이 어긋날 수 없다.
--
--   상세는 _docs/무적스킬_글로벌쿨다운.md
-- ============================================================================
GLOBAL_COOLDOWN_TIME = 5000

-- 활성이면 그 스킬의 무적이 사라져 대상에서 빠지는 특성
GLOBAL_COOLDOWN_ABIL_OFF = {
	Bulletmarker_BloodyOverdrive = 'Bulletmarker25',
	Assassin_Annihilation        = 'Assassin23',
	Arditi_Ritirarsi             = 'Arditi18',
}

-- 활성이어야 무적이 붙는 특성. 비활성이면 애초에 무적이 아니므로 대상에서 빠진다
GLOBAL_COOLDOWN_ABIL_ON = {
	Bulletmarker_BloodyOverdrive = 'Bulletmarker12',
	Fencer_EsquiveToucher        = 'Fencer23',
	Hunter_Praise                = 'Hunter26',
}

-- pc 를 넘기면 특성 상태까지 반영한다. nil 이면 키워드만 본다(스킬 자체의 성질).
function IS_GLOBAL_COOLDOWN_SKILL(pc, skill)
	if skill == nil then
		return false;
	end

	if CHECK_SKILL_KEYWORD(skill, 'UseGlobalCoolTime') ~= 1 then
		return false;
	end

	if pc == nil then
		return true;
	end

	local className = TryGetProp(skill, 'ClassName', 'None');

	local offAbil = GLOBAL_COOLDOWN_ABIL_OFF[className];
	if offAbil ~= nil then
		local abil = GetAbility(pc, offAbil);
		if abil ~= nil and TryGetProp(abil, 'ActiveState', 0) == 1 then
			return false;
		end
	end

	local onAbil = GLOBAL_COOLDOWN_ABIL_ON[className];
	if onAbil ~= nil then
		local abil = GetAbility(pc, onAbil);
		if abil == nil or TryGetProp(abil, 'ActiveState', 0) ~= 1 then
			return false;
		end
	end

	return true;
end

-- 위 두 목록에 등장하는 특성 이름 전체. 특성 토글 차단(SCR_GLOBAL_ABIL_COOLDOWN)이 쓴다.
-- pairs 순회라 순서가 보장되지 않으므로 정렬해 돌려준다.
function GET_GLOBAL_COOLDOWN_ABIL_LIST()
	local seen = {};
	local list = {};

	for _, abilName in pairs(GLOBAL_COOLDOWN_ABIL_OFF) do
		if seen[abilName] == nil then
			seen[abilName] = true;
			table.insert(list, abilName);
		end
	end

	for _, abilName in pairs(GLOBAL_COOLDOWN_ABIL_ON) do
		if seen[abilName] == nil then
			seen[abilName] = true;
			table.insert(list, abilName);
		end
	end

	table.sort(list);
	return list;
end
