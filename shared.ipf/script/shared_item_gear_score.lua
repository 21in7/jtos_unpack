-- shared_item_gear_score.lua

local check_slot_list = nil
local enchant_option_max_value = nil

function GET_RANDOM_ICOR_PORTION(item)
    if item == nil then
        return 0
    end
    
    local max = 4    
    local cnt = 1
    local portion = 0
    for i = 1, 6 do
        if cnt > max then
            break
        end

        local name = TryGetProp(item, 'RandomOption_'..i, 'None')        
        if name ~= 'None' then			
            local value = TryGetProp(item, 'RandomOptionValue_'..i, 0)
            cnt = cnt + 1
            local use_lv = TryGetProp(item, 'UseLv', 1)

            if TryGetProp(item, 'StringArg', 'None') == 'Growth_Item_Legend' and TryGetProp(item, 'NumberArg1', 0) ~= 0 then
                local growthItem = CALC_GROWTH_ITEM_LEVEL(item);
                if growthItem ~= nil then
                    use_lv = growthItem;
                end
            end

            local _, max_value = GET_RANDOM_OPTION_VALUE_VER2(item, name)
            if max_value == nil or use_lv < 430 then                
                max_value = 2000
            end
            if max_value <= 0 then
                max_value = 2000
            end
            
            local diff = (value / max_value)
            if diff < 0 then
                diff = 0
            end
            if diff > 1 then
                diff = 1
            end
            portion = portion + diff * 100
		end
    end

    return math.floor(portion / max + 0.5) / 100
end

function GET_EARRING_GEAR_SCORE(item)
    local lv = TryGetProp(item, 'UseLv', 0)
    local score = lv
    local sum = 0
    for i = 1, item_earring_max_stats_option_count do
        local op_name = 'RandomOptionValue_' .. i
        sum = sum + TryGetProp(item, op_name, 0)
    end
    
    score = score + math.floor(sum / 20)
    score = score + (shared_item_earring.get_earring_grade(item) * 15)
    return score
end

function GET_ENCHANT_OPTION_PORTION(item)
    if item == nil then
        return 0
    end
    
    if enchant_option_max_value == nil then
        enchant_option_max_value = {}
        enchant_option_max_value['RareOption_MainWeaponDamageRate'] = 150
        enchant_option_max_value['RareOption_BossDamageRate'] = 150
        enchant_option_max_value['RareOption_PVPDamageRate'] = 150
        enchant_option_max_value['RareOption_CriticalDamage_Rate'] = 150

        enchant_option_max_value['RareOption_MagicReducedRate'] = 250
        enchant_option_max_value['RareOption_MeleeReducedRate'] = 250
        enchant_option_max_value['RareOption_PVPReducedRate'] = 250

        enchant_option_max_value['RareOption_CriticalHitRate'] = 250
        enchant_option_max_value['RareOption_CriticalDodgeRate'] = 250
        enchant_option_max_value['RareOption_HitRate'] = 250
        enchant_option_max_value['RareOption_DodgeRate'] = 250
        enchant_option_max_value['RareOption_BlockBreakRate'] = 250
        enchant_option_max_value['RareOption_BlockRate'] = 250

        enchant_option_max_value['RareOption_MSPD'] = 3
        enchant_option_max_value['RareOption_SR'] = 3
    end

    local portion = 0

    local name = TryGetProp(item, 'RandomOptionRare', 'None')    
    if name ~= 'None' then			
        local value = TryGetProp(item, 'RandomOptionRareValue', 0)
        local max_value = enchant_option_max_value[name]
        if max_value == nil then
            max_value = 250
        end
        
        local diff = (value / max_value)
        if diff < 0 then
            diff = 0
        end
        if diff > 1 then
            diff = 1
        end

        portion = diff * 100        
    end    
    
    return math.floor(portion + 0.5) / 100
end

local LEVEL_BASE_SCORE = {
    [510] = 1100,
    [540] = 1200,
}

function GET_BELT_GEAR_SCORE(item)
    local lv = TryGetProp(item, 'UseLv', 0)

    local base_score = LEVEL_BASE_SCORE[lv]
    score = 700
    local has_slot_bonus = false
    if lv >= 560 then        
        local gen = (lv - 560) / 20        
        if string.find(TryGetProp(item, 'ClassName', 'None'), '_high') ~= nil then
            score = math.floor(3845 * (1.2 ^ gen) + 0.5) - 300
        else
            score = math.floor(2692 * (1.2 ^ gen) + 0.5) - 200
        end
        has_slot_bonus = true
    elseif lv == 470 then
        score = 900
    elseif lv == 480 then
        score = 900
    elseif base_score ~= nil then
        score = base_score
        has_slot_bonus = true
    end

    -- 공통 로직: 랜덤 옵션 5번 슬롯부터 체크하여 개당 100점 추가
    if has_slot_bonus then
        for i = 5, MAX_RANDOM_OPTION_COUNT do
            local name = TryGetProp(item, 'RandomOption_' .. i, 'None')
            if name ~= 'None' then
                score = score + 100
            end
        end
    end

    local high = 0
    if string.find(TryGetProp(item, 'ClassName', 'None'), '_high') ~= nil then
        high = 100
    end

    if TryGetProp(item, 'GroupName', 'None') == 'BELT' then
        local max_count = shared_item_belt.get_max_random_option_count(item)
        local sum = 0        
        
        for i = 1, max_count do
            local name = TryGetProp(item, 'RandomOption_' .. i)
            local value = TryGetProp(item, 'RandomOptionValue_' .. i)
            local _, max_value = shared_item_belt.get_option_value_range_equip(item, name)
            sum = sum + (value / max_value)        
        end

        sum = sum / max_count
        return math.floor((score * 0.9) + (score * 0.1 * sum)) + high
    elseif TryGetProp(item, 'GroupName', 'None') == 'SHOULDER' then -- SHOULDER        
        local max_count = shared_item_shoulder.get_max_random_option_count(item)
        local sum = 0
        
        for i = 1, max_count do
            local name = TryGetProp(item, 'RandomOption_' .. i)
            local value = TryGetProp(item, 'RandomOptionValue_' .. i)
            local _, max_value = shared_item_shoulder.get_option_value_range_equip(item, name)
            sum = sum + (value / max_value)
        end

        sum = sum / max_count
        return math.floor((score * 0.9) + (score * 0.1 * sum)) + high
    end

    return 0
end

function GET_GEAR_SCORE(item, pc)
    -- [1] 예외 처리: 기어 스코어 계산 대상이 아닌 경우 0 반환
    local stringArg = TryGetProp(item, 'StringArg', 'None')
    if stringArg == 'WoodCarving' or stringArg == 'Moru_goddess' or stringArg == 'TOSHeroEquip' then
        return 0
    end

    if TryGetProp(item, 'GroupName', 'None') == 'Arcane' then
        return 0
    end

    if string.find(TryGetProp(item, 'EnableEquipMap', 'None'), 'TOSHero_Straight') then
        return 0
    end

    -- [2] 슬롯 리스트 초기화 (최초 1회)
    if check_slot_list == nil then
        check_slot_list = {
            ['RING'] = 1, ['NECK'] = 1,
            ['SHIRT'] = 1, ['GLOVES'] = 1, ['BOOTS'] = 1, ['PANTS'] = 1,
            ['RH'] = 1, ['LH'] = 1, ['LH_SUB'] = 1, ['RH_SUB'] = 1,
            ['RH LH'] = 1, ['LH RH'] = 1,
            ['SEAL'] = 1, ['ARK'] = 1, ['EARRING'] = 1, ['BELT'] = 1, ['SHOULDER'] = 1
        }
    end

    local type = TryGetProp(item, 'DefaultEqpSlot', 'None')
    if check_slot_list[type] == nil then
        return 0
    end

    -- [3] 기본 속성 가져오기
    local transcend = TryGetProp(item, 'Transcend', 0)
    local reinforce = TryGetProp(item, 'Reinforce_2', 0)
    local grade = TryGetProp(item, 'ItemGrade', 1)
    local use_lv = TryGetProp(item, 'UseLv', 1)
    local item_lv = TryGetProp(item, 'EvolvedItemLv', 0)

    -- [4] 성장형 아이템 레벨 보정
    local is_growth = false
    if stringArg == 'Growth_Item_Legend' and TryGetProp(item, 'NumberArg1', 0) ~= 0 then
        local growthItem = CALC_GROWTH_ITEM_LEVEL(item)
        if growthItem ~= nil then
            use_lv = growthItem
            is_growth = true
        end
    end

    -- [5] 여신 성장 아이템 특수 처리
    if item_goddess_growth.is_goddess_growth_item(item) == true then
        if use_lv == 1 then return reinforce * 10
        elseif use_lv == 75 then return 200 + (reinforce * 10)
        elseif use_lv == 150 then return 400 + (reinforce * 10)
        end
    end

    use_lv = math.max(use_lv, item_lv)

    -- [6] 서브 슬롯 장착 여부 확인
    local is_sub_slot = false
    local guid = GetIESID(item)
    if IsServerSection() == 1 then
        local sub_lh = GetEquipItemIgnoreDur(pc, 'LH_SUB')
        local sub_rh = GetEquipItemIgnoreDur(pc, 'RH_SUB')
        if (sub_lh and GetIESID(sub_lh) == guid) or (sub_rh and GetIESID(sub_rh) == guid) then
            is_sub_slot = true
        end
    else
        local sub_lh = session.GetEquipItemBySpot(ES_LH_SUB)
        local sub_rh = session.GetEquipItemBySpot(ES_RH_SUB)
        if (sub_lh and sub_lh:GetIESID() == guid) or (sub_rh and sub_rh:GetIESID() == guid) then
            is_sub_slot = true
        end
    end

    -- [7] 특수 장비(SEAL, RELIC, ARK, EARRING, BELT) 계산
    if type == 'SEAL' then
        local class_name = TryGetProp(item, 'ClassName', 'None')
        if class_name == 'Seal_jurate' or class_name == 'Seal_jurate_def' then return 1000 end
        if class_name == 'Seal_jurate2' or class_name == 'Seal_jurate2_def' then return 1200 end
        if class_name == 'Seal_jurate3' or class_name == 'Seal_jurate3_def' then return 1400 end
        if string.find(class_name, 'Seal_jurate4') ~= nil then return 1600 end

        reinforce = GET_CURRENT_SEAL_LEVEL(item)
        if use_lv == 380 then grade = math.min(grade, 5) end
        local ret = ((0.7 * (100 * reinforce)) + ((1100 * grade) + (1 * use_lv)) * 0.3) * 0.26
        return math.floor(ret + 0.5)

    elseif type == 'RELIC' then
        return 0
    elseif type == 'ARK' then
        local ark_lv = TryGetProp(item, 'ArkLevel', 1)
        local use_lv = 0
        if TryGetProp(item, 'StringArg2', 'None') == 'Rare_Ark' then
            ark_lv = 10 
            local item_lv = TryGetProp(item, 'UseLv', 540)
            use_lv = math.floor(270 + (item_lv - 540) * 15)
        end
        local is_quest_ark = TryGetProp(item, 'StringArg2', 'None') == 'Quest_Ark'        
        local quest_ark_penalty = is_quest_ark and 0.95 or 1.1

        local ret = 251 + (25.1 * ark_lv)
        for i = 1, 2 do
            if TryGetProp(item, 'RandomOptionValue_' .. i, 0) > 0 then
                ret = ret + 250
            end
        end
        return math.floor((ret * quest_ark_penalty) + 0.5 + use_lv)

    elseif type == 'EARRING' then
        if TryGetProp(item, 'ClassName', 'None') == 'EP13_SampleGabijaEarring' then
            return 450
        end
        return GET_EARRING_GEAR_SCORE(item)

    elseif type == 'BELT' or type == 'SHOULDER' then
        return GET_BELT_GEAR_SCORE(item)
    end

    -- [8] 일반 장비(무기, 방어구, 악세서리) 계산 로직 시작
    local icor_lv = 0
    local random_icor_lv = 0
    local gem_point = 0
    local is_accessory = (type == 'RING' or type == 'NECK')

    -- 8-1. 아이커 및 젬 계산 (악세서리 제외)
    if not is_accessory then
        -- 고정 아이커 레벨
        local name = TryGetProp(item, 'InheritanceItemName', 'None')
        if name ~= 'None' then
            local cls = GetClass('Item', name)
            icor_lv = cls and TryGetProp(cls, 'UseLv', 1) or 0
        else
            icor_lv = 0
        end

        -- 랜덤 아이커 레벨
        if IS_HAVE_RANDOM_OPTION(item) then
            local ran_name = TryGetProp(item, 'InheritanceRandomItemName', 'None')
            if ran_name ~= 'None' then -- 레겐다 계열
                local cls = GetClass('Item', ran_name)
                random_icor_lv = cls and TryGetProp(cls, 'UseLv', 1) or 0
            else -- 세비노스 계열
                random_icor_lv = use_lv
            end
        else
            random_icor_lv = 0
        end

        -- 젬 포인트 계산
        local max_socket_count = TryGetProp(item, 'MaxSocket_COUNT', 0)
        if grade >= 6 then
            max_socket_count = GET_MAX_GODDESS_NORMAL_SOCKET_COUNT(use_lv)
        end

        for start_idx = 0, max_socket_count do
            local gem_id, gem_lv = 0, 0
            if IsServerSection() == 1 then
                gem_id, gem_lv = GetItemSocketInfo(item, start_idx)
            else
                local inv_item = session.GetInvItemByGuid(GetIESID(item)) or
                                 session.GetEquipItemByGuid(GetIESID(item)) or
                                 session.otherPC.GetItemByGuid(GetIESID(item))
                if inv_item then
                    gem_id = inv_item:GetEquipGemID(start_idx)
                    gem_lv = inv_item:GetEquipGemLv(start_idx)
                end
            end

            if gem_id ~= 0 and gem_id ~= 643817 then
                local gem_cls = GetClassByType('Item', gem_id)
                if gem_cls then
                    local gem_type = TryGetProp(gem_cls, 'GroupName', 'None')
                    if gem_type == 'Gem_High_Color' then
                        gem_lv = math.ceil(gem_lv * 0.15)
                    end
                    if TryGetProp(gem_cls, 'StringArg', 'None') == 'SkillGem' then
                        gem_lv = 0
                    end
                    gem_point = gem_point + gem_lv
                end
            end
        end
    else
        -- 악세서리는 아이커 레벨 기본값
        icor_lv = use_lv
        random_icor_lv = 0
    end

    -- 8-2. 평균 레벨(AvgLv) 계산
    local avg_lv
    if is_accessory then
        avg_lv = use_lv
    else
        avg_lv = math.floor((use_lv * 0.5) + ((icor_lv + use_lv + random_icor_lv) * 0.33334 * 0.5) + 0.5)
    end

    -- 8-3. 옵션 페널티 및 세트 보정치 계산
    local random_option_portion = GET_RANDOM_ICOR_PORTION(item)
    local enchant_portion = GET_ENCHANT_OPTION_PORTION(item)

    if stringArg == 'Growth_Item_Legend' and TryGetProp(item, 'NumberArg1', 0) ~= 0 then
        random_option_portion = 1
        enchant_portion = 1
    end

    local random_option_penalty = 0.05 * (1 - random_option_portion)
    local enchant_option_penalty = 0.05 * (1 - enchant_portion)
    local set_advantage = 0.9
    local add_acc = 0

    -- 8-4. 장비 타입별 보정치 (악세서리 vs 무기/방어구)
    if is_accessory then
        local base_acc = false
        if use_lv == 1 and grade == 5 then
            use_lv = math.floor(PC_MAX_LEVEL * 0.85)
            avg_lv = use_lv -- 악세서리는 avg_lv 재조정
            base_acc = true
        end

        if not base_acc then
            if stringArg == 'Luciferi' then
                add_acc = 80
            elseif grade >= 6 and use_lv >= 570 then                
                local gen = (use_lv - 550) / 20
                local target = 4141 * (1.2 ^ gen)
                local full_base = (1090 + (use_lv - 460) * 20 + (use_lv - 540) * 10) * 0.9
                add_acc = math.floor(target - full_base + 0.5)
            elseif grade >= 6 and use_lv >= 470 then
                add_acc = 100 + math.max(0, (use_lv - 470) * 20)
                if use_lv > 490 then
                    add_acc = 100 + math.max(0, (use_lv - 470) * 18)
                end
            elseif stringArg == 'Acc_EP12' then
                add_acc = 70
            elseif grade >= 6 then
                add_acc = 100
            else
                add_acc = 30
            end
        end
        -- 악세서리는 set_option 페널티 미적용 로직은 하단에서 처리됨 (페널티가 0이 되거나 set_option 계산에 반영)
    else
        -- 무기/방어구 세트 보정
        local prefix = TryGetProp(item, 'LegendPrefix', 'None')
        if prefix ~= 'None' then
            local set_cls = GetClass('LegendSetItem', prefix)
            if set_cls then
                local group = TryGetProp(set_cls, 'LegendGroup', 'None')
                local className = TryGetProp(set_cls, 'ClassName', 'None')

                if group == 'Velcoffer' then set_advantage = 0.91
                elseif group == 'Savinose/Varna' or group == 'Varna' then set_advantage = 0.93
                elseif group == 'Disnai' then set_advantage = 1
                end

                if className == 'Set_Ezera' or className == 'Set_Karys' then
                    set_advantage = 0.9
                end
            end
        end

        if is_sub_slot == true or (use_lv >= 480 and grade >= 6) then
            set_advantage = 1
        end
        if stringArg == 'Growth_Item_Legend' and TryGetProp(item, 'NumberArg1', 0) ~= 0 then
            set_advantage = 1.1
        end
    end

    -- 8-5. 고레벨/고등급 페널티 면제 및 초월 보정
    if grade >= 6 and use_lv >= 470 then
        random_option_penalty = 0
        enchant_option_penalty = 0
        transcend = 10
    end

    local set_option = 1 - random_option_penalty - enchant_option_penalty

    -- 8-6. 최종 점수 계산 (Legend vs Goddess)
    local ret = 0
    if grade < 6 then
        ret = 0.5 * ((4 * transcend) + (3 * reinforce)) + ((30 * grade) + (1.66 * avg_lv)) * 0.5
    else
        local reinforce_ratio = 20
        local transcend_ratio = 3
        local diff = avg_lv - 460
        if use_lv >= 480 then
            diff = use_lv - 460
        end
        diff = math.max(0, diff)

        ret = (transcend * transcend_ratio) + (reinforce_ratio * reinforce) + (diff * reinforce_ratio) + 460
        if use_lv >= 560 then
            if is_accessory then
                ret = ret + (use_lv - 540) * 10
            else                
                local gen = (use_lv - 560) / 20
                local bonus = math.floor(4145 * (1.2 ^ gen) - (1090 + (use_lv - 460) * 20) + 0.5)
                ret = ret + bonus
            end
        end
        ret = ret * (math.min(1, avg_lv / use_lv))
    end

    -- 8-7. 최종 합산 및 성장 페널티
    ret = ret * set_option * set_advantage + add_acc + gem_point

    if is_growth == true then
        ret = ret * 0.9
    end

    return math.floor(ret + 0.5)
end

function GET_PLAYER_GEAR_SCORE(pc)        
    local total = 14
    local score = 0

    if IsServerSection() ~= 1 then -- client
        local equipList = session.GetEquipItemList();        
        for j = 0, equipList:Count() - 1 do
            local equipItem = equipList:GetEquipItemByIndex(j);
            if equipItem ~= nil and equipItem:GetIESID() ~= '0' then
                local invitem = GET_ITEM_BY_GUID(equipItem:GetIESID());
                local itemobj = GetIES(invitem:GetObject());                
                score = score + GET_GEAR_SCORE(itemobj, pc)

                local strarg = TryGetProp(itemobj,"StringArg")
            end            
        end        
        
        local item_sub_rh = session.GetEquipItemBySpot(item.GetEquipSpotNum('RH_SUB')) -- RH_SUB
        local item_sub_lh = session.GetEquipItemBySpot(item.GetEquipSpotNum('LH_SUB')) -- LH_SUB

        local missing_count = 0
        if item_sub_rh ~= nil and item_sub_rh:GetIESID() == '0' then
            missing_count = missing_count + 1
        end

        if item_sub_lh ~= nil and item_sub_lh:GetIESID() == '0' then
            missing_count = missing_count + 1
        end
                
        local add = 0
        if missing_count > 0 then
            local div = total - missing_count
            if div > 0 then
                add = math.floor(score / div * missing_count)                 
            end
        end
        score = score + add
        return math.floor(score + 0.5)
    else
        local equipList = GetEquipItemList(pc)        
        local before_score = 0
        for i = 1, #equipList do
            local itemobj = equipList[i]
            if itemobj ~= nil then                
                score = score + GET_GEAR_SCORE(itemobj, pc)
            end
        end

        before_score = score

        local missing_count = 0
        local item_sub_lh = GetEquipItemIgnoreDur(pc, 'LH_SUB')        
        if TryGetProp(item_sub_lh, 'ClassName', 'None') == 'NoWeapon' or TryGetProp(item_sub_lh, 'ClassName', 'None') == 'None' then
            missing_count = missing_count + 1
        end
        local item_sub_rh = GetEquipItemIgnoreDur(pc, 'RH_SUB')        
        if TryGetProp(item_sub_rh, 'ClassName', 'None') == 'NoWeapon' or TryGetProp(item_sub_rh, 'ClassName', 'None') == 'None' then
            missing_count = missing_count + 1
        end

        local add = 0
        if missing_count > 0 then
            local div = total - missing_count
            if div > 0 then
                add = math.floor(score / div * missing_count)                 
            end
        end
        score = score + add

        return math.floor(score + 0.5)
    end
end

function GET_PLAYER_POPOBOOST_GEAR_SCORE(pc)        
    local total = 14
    local score = 0
    local popoboostCheckTable = { ["BELT"] = 1,["SEAL"] = 1, ["ARK"] = 1,["EARRING"] = 1,["SHOULDER"] = 1 };
    if IsServerSection() ~= 1 then -- client
        local equipList = session.GetEquipItemList();        
        for j = 0, equipList:Count() - 1     do
            local equipItem = equipList:GetEquipItemByIndex(j);
            
            if equipItem ~= nil and equipItem:GetIESID() ~= '0' then
                local invitem = GET_ITEM_BY_GUID(equipItem:GetIESID());
                local itemobj = GetIES(invitem:GetObject());     
                local popoboostProp = TryGetProp(itemobj,"popoboost", 0)
                local spotname = TryGetProp(itemobj,"DefaultEqpSlot","None")
                local PopoItemProp = GET_POPOBOOST_ITEMPROP();

                if PopoItemProp > 0 and popoboostProp == PopoItemProp then
                    score = score + GET_GEAR_SCORE(itemobj, pc)
                else
                    local check = popoboostCheckTable[spotname];
                    if check ~= nil then
                        score = score + GET_GEAR_SCORE(itemobj, pc)
                    end
                end
            end            
        end        
        
        local item_sub_rh = session.GetEquipItemBySpot(item.GetEquipSpotNum('RH_SUB')) -- RH_SUB
        local item_sub_lh = session.GetEquipItemBySpot(item.GetEquipSpotNum('LH_SUB')) -- LH_SUB

        local missing_count = 0
        if item_sub_rh ~= nil and item_sub_rh:GetIESID() == '0' then
            missing_count = missing_count + 1
        end

        if item_sub_lh ~= nil and item_sub_lh:GetIESID() == '0' then
            missing_count = missing_count + 1
        end
                
        local add = 0
        if missing_count > 0 then
            local div = total - missing_count
            if div > 0 then
                add = math.floor(score / div * missing_count)                 
            end
        end
        score = score + add
        return math.floor(score + 0.5)
    else
        local equipList = GetEquipItemList(pc)        
        local before_score = 0;
        for i = 1, #equipList do
            local itemobj = equipList[i]
            if itemobj ~= nil then
                local spotname = TryGetProp(itemobj,"DefaultEqpSlot")
                local check = popoboostCheckTable[spotname];
                local PopoItemProp = GET_POPOBOOST_ITEMPROP();
                local popoboostProp = TryGetProp(itemobj,"popoboost", 0)
                
                if PopoItemProp > 0 and popoboostProp == PopoItemProp then                
                    score = score + GET_GEAR_SCORE(itemobj, pc)
                elseif check ~= nil then
                    score = score + GET_GEAR_SCORE(itemobj, pc)
                end
            end
        end

        before_score = score

        local missing_count = 0
        local item_sub_lh = GetEquipItemIgnoreDur(pc, 'LH_SUB')        
        if TryGetProp(item_sub_lh, 'ClassName', 'None') == 'NoWeapon' or TryGetProp(item_sub_lh, 'ClassName', 'None') == 'None' then
            missing_count = missing_count + 1
        end
        local item_sub_rh = GetEquipItemIgnoreDur(pc, 'RH_SUB')        
        if TryGetProp(item_sub_rh, 'ClassName', 'None') == 'NoWeapon' or TryGetProp(item_sub_rh, 'ClassName', 'None') == 'None' then
            missing_count = missing_count + 1
        end

        local add = 0
        if missing_count > 0 then
            local div = total - missing_count
            if div > 0 then
                add = math.floor(score / div * missing_count)                 
            end
        end
        score = score + add
        return math.floor(score + 0.5)
    end
end


function GET_GEAR_SCORE_BY(type, transcend, reinforce, grade, use_lv, item_lv)
    if check_slot_list == nil then
        check_slot_list = {}
        check_slot_list['RING'] = 1
        check_slot_list['NECK'] = 1

        check_slot_list['SHIRT'] = 1
        check_slot_list['GLOVES'] = 1
        check_slot_list['BOOTS'] = 1
        check_slot_list['PANTS'] = 1
        check_slot_list['RH'] = 1
        check_slot_list['LH'] = 1
        check_slot_list['LH_SUB'] = 1
        check_slot_list['RH_SUB'] = 1
        check_slot_list['RH LH'] = 1
        check_slot_list['LH RH'] = 1        

        check_slot_list['SEAL'] = 1
        check_slot_list['ARK'] = 1        
        --check_slot_list['RELIC'] = 1        
    end
    
    use_lv = math.max(use_lv, item_lv)

    if check_slot_list[type] == nil then        
        return 0
    end

    if type == 'SEAL' then        
        local ret = ((0.7 *(100*reinforce))+((1000*grade)+(1*use_lv)) * 0.3)*0.26        
        return math.floor(ret + 0.5)
    elseif type == 'RELIC' then        
        return 0
    elseif type == 'ARK' then        
        return 0
    else -- 무기/방어구/악세서리
        local icor_lv = use_lv
        local random_icor_lv = 0
        
        local enchant_portion = 1       -- 인챈트 쥬얼 비율(max치 대비)
        local random_option_penalty = 0
        local enchant_option_penalty = 0

        if type ~= 'RING' and type ~= 'NECK' then            
                        
            -- 랜덤 아이커 레벨 체크
            if false then
                local ran_name = TryGetProp(item, 'InheritanceRandomItemName', 'None')
                if ran_name ~= 'None' then -- 레겐다 계열
                    cls = GetClass('Item', ran_name)
                    if cls ~= nil then
                        random_icor_lv = TryGetProp(cls, 'UseLv', 1)
                        
                    end
                else -- 세비노스 계열
                    if TryGetProp(item, 'StringArg', 'None') == 'Growth_Item_Legend' and TryGetProp(item, 'NumberArg1', 0) ~= 0 then
                        local growthItem = CALC_GROWTH_ITEM_LEVEL(item);
                        if growthItem ~= nil then
                            use_lv = growthItem;
                        end
                    end
                    random_icor_lv = use_lv
                end
            else
                -- 레겐다 계열
                random_icor_lv = 0
            end

            -- 랜덤 옵션 수치
            local random_option_portion = 0
            if TryGetProp(item, 'StringArg', 'None') == 'Growth_Item_Legend' and TryGetProp(item, 'NumberArg1', 0) ~= 0 then
                random_option_portion = 1
            end             
            local diff = 1 - random_option_portion
            random_option_penalty = 0.05 * diff -- 5% 비중

            -- 인챈트 수치
            local enchant_portion = 0
            if TryGetProp(item, 'StringArg', 'None') == 'Growth_Item_Legend' and TryGetProp(item, 'NumberArg1', 0) ~= 0 then
                enchant_portion = 1
            end             
            diff = 1 - enchant_portion
            enchant_option_penalty = 0.05 * diff -- 5% 비중            
        end
                
        local avg_lv = math.floor((use_lv * 0.5) + ((icor_lv + use_lv + random_icor_lv) * 0.33334 * 0.5) + 0.5)
        local set_option = 1
        local set_advantage = 0.9

        if type == 'NECK' or type == 'RING' then            
            avg_lv = use_lv
        else
            local prefix = 'None'
            if prefix ~= 'None' then                
                local set_cls = GetClass('LegendSetItem', prefix)
                if set_cls ~= nil then
                    local group = TryGetProp(set_cls, 'LegendGroup', 'None')
                    if group == 'Velcoffer' then
                        set_advantage = 0.91
                    elseif group == 'Savinose/Varna' or group == 'Varna' then
                        set_advantage = 0.93 
                    elseif group == 'Disnai' then
                        set_advantage = 1 
                    end
                end
            end
            
            if TryGetProp(item, 'StringArg', 'None') == 'Growth_Item_Legend' and TryGetProp(item, 'NumberArg1', 0) ~= 0 then
                set_advantage = 1.1
            end
        end        
        set_option = 1 - random_option_penalty - enchant_option_penalty        
        local ret = 0.5 * ( (4*transcend) + (3*reinforce)) + ( (30*grade) + (1.66*avg_lv) )*0.5
        ret = ret * set_option * set_advantage
        
        return math.floor(ret + 0.5)
    end

    return 0
end

function GET_PLAYER_ABILITY_SCORE(pc)    
    local job_list = GetJobHistoryList(pc)
    local total_score_list = {}
    table.insert(total_score_list, 600000)
    table.insert(total_score_list, 600000)
    table.insert(total_score_list, 600000)
    table.insert(total_score_list, 600000)

    for i = 1, #job_list do
        local ability_point_score = GetClassByType('ability_point_score', job_list[i])
        if ability_point_score ~= nil then
            local require_score = TryGetProp(ability_point_score, 'RequireScore', 600000)
            total_score_list[i] = require_score
        end
    end

    local total_score = 0
    for i = 1, #total_score_list do
        total_score = total_score + total_score_list[i]
    end

    if total_score <= 0 then
        total_score = 1
    end

    local use_point = 0
    
    if IsServerSection() == 1 then
        local abilList = GetAbilityNames(pc)
        for i = 1, #abilList do
            local abil_obj = GetAbilityIESObject(pc, abilList[i]);            
            local name = TryGetProp(abil_obj, 'ClassName', 'None') -- 특성 이름
            local score = GET_MAX_REQUIRED_ABILITY_POINT(pc, name)                
            if score ~= nil then
                local now = GET_ABILITY_POINT_BY_NAME(pc, name)
                use_point = use_point + now
            end 
        end
    else
        pc = GetMyPCObject()

        local abilList = session.GetAbilityList();
        local abilListCnt = abilList:Count();
            
        for i = 0, abilListCnt - 1 do
            local abil = session.GetAbilityByIndex(i);
            if abil ~= nil then
                local abil_obj = GetIES(abil:GetObject());
                local name = TryGetProp(abil_obj, 'ClassName', 'None') -- 특성 이름
                local score = GET_MAX_REQUIRED_ABILITY_POINT(pc, name)                
                if score ~= nil then
                    local now = GET_ABILITY_POINT_BY_NAME(pc, name)
                    use_point = use_point + now
                end                
            end
        end
    end    

    local ret = use_point / total_score * 100
    if ret >= 100 then
        ret = 100
    end
    return string.format('%.2f', ret)
end

function GET_PLAYER_STATUS_BY_NAME(pc, name)    
    if name == 'ATK' then
        local sum = TryGetProp(pc, 'MINPATK', 0) + TryGetProp(pc, 'MAXPATK', 0)
        return math.floor(sum / 2)
    elseif name == 'MATK' then
        local sum = TryGetProp(pc, 'MINMATK', 0) + TryGetProp(pc, 'MAXMATK', 0)
        return math.floor(sum / 2)
    else
        return TryGetProp(pc, name, 0)
    end
end