-- shared_upgrade_acc.lua

-- 방어력, 치저, 블록, 치유력, 공격력, 치발감소, 추가 대미지
function GET_EP16_NECK_02_POINT(item)
    local min, max = GET_ITEM_ATK(item)        
    local avg = (min + max) * 0.5
    
    local def = math.floor(avg * 10)
    local crtdr = math.floor(avg * 0.25) -- 치저
    local blk = math.floor(avg * 0.25)

    local heal = math.floor(avg * 0.7)
    local atk = math.floor(avg * 1.6)
    local crthr = math.floor(avg * 0.28) -- 치발감소
    local add_dmg = math.floor(avg * 0.65)
    local mspd = math.floor(avg * 0.0008)

    local name = TryGetProp(item, 'ClassName', 'None')
    if name == 'EP17_Kalentis_NECK_02' then
        atk = atk + 10000
    end

    if mspd < 1 then
        mspd = 1 
    end

    if mspd > 10 then
        mspd = 10
    end
    
    return def, crtdr, blk, heal, atk, crthr, add_dmg, mspd
end

function GET_EP16_BRC_02_POINT(item)
    local min, max = GET_ITEM_ATK(item)
    local avg = (min + max) * 0.5
    
    local def = math.floor(avg * 5)
    local crtdr = math.floor(avg * 0.125) -- 치저
    local blk = math.floor(avg * 0.125)
    
    local heal = math.floor(avg * 0.35)
    local atk = math.floor(avg * 0.8)
    local crthr = math.floor(avg * 0.14) -- 치발감소
    local add_dmg = math.floor(avg * 0.325)
    local mspd = math.floor(avg * 0.0004)
    
    local name = TryGetProp(item, 'ClassName', 'None')
    if name == 'EP17_Kalentis_BRC_02' then
        atk = atk + 5000
    end

    if mspd < 1 then
        mspd = 1 
    end

    if mspd > 5 then
        mspd = 5
    end

    return def, crtdr, blk, heal, atk, crthr, add_dmg, mspd
end

-- 550제 이후 공용(칸트리베)
function GET_EP18_NECK_02_POINT(item)
    -- 1. 입력값 확인
    local min, max = GET_ITEM_ATK(item)    
    local avg = (min + max) * 0.5

    -- 2. 성장 상수
    local GEN_GROWTH = 1.005        -- 세대당 0.5% 증가

    -- 3. 세대(Generation) 계산
    local lv = TryGetProp(item, 'UseLv', 0)
    local gen_diff = math.max(0, math.floor((lv - 550) / 20))  
        
    -- 4. avg 기반 기준 수치 계산
    local ref_def     = math.floor(avg * 10)
    local ref_crtdr   = math.floor(avg * 0.25)
    local ref_blk     = math.floor(avg * 0.25)
    local ref_heal    = math.floor(avg * 0.7)
    local ref_atk     = math.floor(avg * 1.6) + 10000
    local ref_crthr   = math.floor(avg * 0.28)
    local ref_add_dmg = math.floor(avg * 0.65)

    -- 5. 세대 성장률 적용 (전 스탯 동일 0.5%)
    local gen_mult = GEN_GROWTH ^ gen_diff

    local def     = math.floor(ref_def * gen_mult)
    local crtdr   = math.floor(ref_crtdr * gen_mult)
    local blk     = math.floor(ref_blk * gen_mult)
    local heal    = math.floor(ref_heal * gen_mult)
    local atk     = math.floor(ref_atk * gen_mult)
    local crthr   = math.floor(ref_crthr * gen_mult)
    local add_dmg = math.floor(ref_add_dmg * gen_mult)

    local mspd = 10

    return def, crtdr, blk, heal, atk, crthr, add_dmg, mspd
end
-- 550제 이후 공용(칸트리베)
function GET_EP18_BRC_02_POINT(item)
    -- 1. 입력값 확인
    local min, max = GET_ITEM_ATK(item)
    local avg = (min + max) * 0.5

    local GEN_GROWTH = 1.005        -- 세대당 0.5% 증가

    -- 3. 세대(Generation) 계산
    local lv = TryGetProp(item, 'UseLv', 0)
    local gen_diff = math.max(0, math.floor((lv - 550) / 20))

    -- 4. avg 기반 기준 수치 계산
    local ref_def     = math.floor(avg * 5)
    local ref_crtdr   = math.floor(avg * 0.125)
    local ref_blk     = math.floor(avg * 0.125)
    local ref_heal    = math.floor(avg * 0.35)
    local ref_atk     = math.floor(avg * 0.8) + 5000
    local ref_crthr   = math.floor(avg * 0.14)
    local ref_add_dmg = math.floor(avg * 0.325)

    -- 5. 세대 성장률 적용 (전 스탯 동일 0.5%)
    local gen_mult = GEN_GROWTH ^ gen_diff

    local def     = math.floor(ref_def * gen_mult)
    local crtdr   = math.floor(ref_crtdr * gen_mult)
    local blk     = math.floor(ref_blk * gen_mult)
    local heal    = math.floor(ref_heal * gen_mult)
    local atk     = math.floor(ref_atk * gen_mult)
    local crthr   = math.floor(ref_crthr * gen_mult)
    local add_dmg = math.floor(ref_add_dmg * gen_mult)

    local mspd = 5

    return def, crtdr, blk, heal, atk, crthr, add_dmg, mspd
end

-- ClassType {Neck, Ring}
shared_upgrade_acc = {}
local material_table = nil
local value_grade_table = nil
local value_atk_table = nil

local function make_shared_upgrade_acc_table()
    if material_table ~= nil then
        return
    end

    material_table = {}
    value_grade_table = {}
    value_atk_table = {} -- 추가된 공격력 정보

    material_table[510] = {}
    material_table[510]['Neck'] = {}
    material_table[510]['Neck']['RadaCertificate'] = 7000
    material_table[510]['Neck']['misc_BlessedStone_1'] = 2
    material_table[510]['Neck']['misc_merregina_blackpearl_NoTrade'] = 20
    
    material_table[510]['Ring'] = {}
    material_table[510]['Ring']['RadaCertificate'] = 3500
    material_table[510]['Ring']['misc_BlessedStone_1'] = 1
    material_table[510]['Ring']['misc_merregina_blackpearl_NoTrade'] = 10

    material_table[530] = {}
    material_table[530]['Neck'] = {}
    material_table[530]['Neck']['JurateCertificate'] = 5000
    material_table[530]['Neck']['misc_BlessedStone_1'] = 1
    material_table[530]['Neck']['misc_ore28'] = 100
    material_table[530]['Neck']['misc_ep17_acc_NoTrade'] = 12
    
    material_table[530]['Ring'] = {}
    material_table[530]['Ring']['JurateCertificate'] = 5000
    material_table[530]['Ring']['misc_BlessedStone_1'] = 1
    material_table[530]['Ring']['misc_ore28'] = 100
    material_table[530]['Ring']['misc_ep17_acc_NoTrade'] = 12

    -- EP18
    material_table[550] = {}
    material_table[550]['Neck'] = {}
    material_table[550]['Neck']['AustejaCertificate'] = 5000
    material_table[550]['Neck']['misc_BlessedStone_2'] = 1
    material_table[550]['Neck']['misc_ore29'] = 100
    material_table[550]['Neck']['misc_ep18_acc_NoTrade'] = 12

    material_table[550]['Ring'] = {}
    material_table[550]['Ring']['AustejaCertificate'] = 5000
    material_table[550]['Ring']['misc_BlessedStone_2'] = 1 -- 최고급 축복받은 조각
    material_table[550]['Ring']['misc_ore29'] = 100        -- 엘타스 가루
    material_table[550]['Ring']['misc_ep18_acc_NoTrade'] = 12 -- 변경필요


    -- 값 세팅
    value_grade_table['EP16_NECK_01'] = {} -- 피크티스 네클리스
    value_grade_table['EP16_BRC_01'] = {} -- 피크티스 네클리스    
    value_grade_table['EP16_NECK_02'] = {} -- 칸트리베 네클리스
    value_grade_table['EP16_BRC_02'] = {} -- 칸트리베 네클리스
    value_grade_table['EP16_NECK_03'] = {} -- 주오다 네클리스
    value_grade_table['EP16_BRC_03'] = {} -- 주오다 네클리스
    value_grade_table['EP16_NECK_04'] = {} -- 트리우카스 네클리스
    value_grade_table['EP16_BRC_04'] = {} -- 트리우카스 네클리스
    
    value_grade_table['EP17_Kalentis_NECK_01'] = {} -- 피크티스 네클리스
    value_grade_table['EP17_Kalentis_BRC_01'] = {} -- 피크티스 네클리스    
    value_grade_table['EP17_Kalentis_NECK_02'] = {} -- 칸트리베 네클리스
    value_grade_table['EP17_Kalentis_BRC_02'] = {} -- 칸트리베 네클리스
    value_grade_table['EP17_Kalentis_NECK_03'] = {} -- 주오다 네클리스
    value_grade_table['EP17_Kalentis_BRC_03'] = {} -- 주오다 네클리스
    value_grade_table['EP17_Kalentis_NECK_04'] = {} -- 트리우카스 네클리스
    value_grade_table['EP17_Kalentis_BRC_04'] = {} -- 트리우카스 네클리스

    -- EP18
    value_grade_table['EP18_NECK_01'] = {} -- 피크티스 네클리스
    value_grade_table['EP18_BRC_01'] = {} -- 피크티스 네클리스
    value_grade_table['EP18_NECK_03'] = {} -- 주오다 네클리스
    value_grade_table['EP18_BRC_03'] = {} -- 주오다 네클리스
    value_grade_table['EP18_NECK_04'] = {} -- 트리우카스 네클리스
    value_grade_table['EP18_BRC_04'] = {} -- 트리우카스 네클리스



    value_grade_table['EP17_Kalentis_NECK_01'][0] = {2250, 675}
    value_grade_table['EP17_Kalentis_BRC_01'][0] = {1125, 338}
    value_grade_table['EP17_Kalentis_NECK_03'][0] = {4200, 1260}
    value_grade_table['EP17_Kalentis_BRC_03'][0] = {2100, 630}
    value_grade_table['EP17_Kalentis_NECK_04'][0] = {2626, 788}
    value_grade_table['EP17_Kalentis_BRC_04'][0] = {1313, 394}

    -- EP18
    value_grade_table['EP18_NECK_01'][0] = {2250, 675}
    value_grade_table['EP18_BRC_01'][0] = {1125, 338}
    value_grade_table['EP18_NECK_03'][0] = {4200, 1260}
    value_grade_table['EP18_BRC_03'][0] = {2100, 630}
    value_grade_table['EP18_NECK_04'][0] = {2626, 788}
    value_grade_table['EP18_BRC_04'][0] = {1313, 394}

    for i = 1, 20 do
        value_grade_table['EP16_NECK_01'][i] = {112 * i, 33 * i}
        value_grade_table['EP16_BRC_01'][i] = {56 * i, 16 * i}
        value_grade_table['EP16_NECK_02'][i] = {500 * i, 0}
        value_grade_table['EP16_BRC_02'][i] = {250 * i, 0}
        value_grade_table['EP16_NECK_03'][i] = {210 * i, 63 * i}
        value_grade_table['EP16_BRC_03'][i] = {105 * i, 31 * i}
        value_grade_table['EP16_NECK_04'][i] = {131 * i, 39 * i}
        value_grade_table['EP16_BRC_04'][i] = {65 * i, 19 * i}
        
        value_grade_table['EP17_Kalentis_NECK_01'][i] = {2250, 675}
        value_grade_table['EP17_Kalentis_BRC_01'][i] = {1125, 338}
        value_grade_table['EP17_Kalentis_NECK_03'][i] = {4200, 1260}
        value_grade_table['EP17_Kalentis_BRC_03'][i] = {2100, 630}
        value_grade_table['EP17_Kalentis_NECK_04'][i] = {2626, 788}
        value_grade_table['EP17_Kalentis_BRC_04'][i] = {1313, 394}

        -- EP18
        value_grade_table['EP18_NECK_01'][i] = {2250, 675}
        value_grade_table['EP18_BRC_01'][i] = {1125, 338}
        value_grade_table['EP18_NECK_03'][i] = {4200, 1260}
        value_grade_table['EP18_BRC_03'][i] = {2100, 630}
        value_grade_table['EP18_NECK_04'][i] = {2626, 788}
        value_grade_table['EP18_BRC_04'][i] = {1313, 394}
    end

    value_grade_table['EP16_NECK_01'][20] = {2250, 675}
    value_grade_table['EP16_BRC_01'][20] = {1125, 337}    
    value_grade_table['EP16_NECK_02'][20] = {10000, 0}
    value_grade_table['EP16_BRC_02'][20] = {5000, 0}
    value_grade_table['EP16_NECK_03'][20] = {4200, 1260}
    value_grade_table['EP16_BRC_03'][20] = {2100, 630}
    value_grade_table['EP16_NECK_04'][20] = {2626, 788}
    value_grade_table['EP16_BRC_04'][20] = {1313, 394}    
    
    value_grade_table['EP17_Kalentis_NECK_01'][20] = {2250, 675}
    value_grade_table['EP17_Kalentis_BRC_01'][20] = {1125, 338}
    value_grade_table['EP17_Kalentis_NECK_03'][20] = {4200, 1260}
    value_grade_table['EP17_Kalentis_BRC_03'][20] = {2100, 630}
    value_grade_table['EP17_Kalentis_NECK_04'][20] = {2626, 788}
    value_grade_table['EP17_Kalentis_BRC_04'][20] = {1313, 394}

    -- EP18
    value_grade_table['EP18_NECK_01'][20] = {2250, 675}
    value_grade_table['EP18_BRC_01'][20] = {1125, 338}
    value_grade_table['EP18_NECK_03'][20] = {4200, 1260}
    value_grade_table['EP18_BRC_03'][20] = {2100, 630}
    value_grade_table['EP18_NECK_04'][20] = {2626, 788}
    value_grade_table['EP18_BRC_04'][20] = {1313, 394}


    -- 추가 공격력 세팅
    -- 추가 공격력 세팅
    value_atk_table['EP16_NECK_01'] = 4000 -- 피크티스 네클리스
    value_atk_table['EP16_BRC_01'] = 2000 -- 피크티스 브레이슬릿    
    value_atk_table['EP16_NECK_02'] = 4000 -- 칸트리베 네클리스
    value_atk_table['EP16_BRC_02'] = 4000 -- 칸트리베 브레이슬릿    
    value_atk_table['EP16_NECK_04'] = 4000 -- 트리우카스 네클리스
    value_atk_table['EP16_BRC_04'] = 4000 -- 트리우카스 브레이슬릿

    value_atk_table['EP17_Kalentis_NECK_01'] = 4800 -- 피크티스 네클리스
    value_atk_table['EP17_Kalentis_BRC_01'] = 2400 -- 피크티스 브레이슬릿
    value_atk_table['EP17_Kalentis_NECK_03'] = 4800 -- 주오다 네클리스
    value_atk_table['EP17_Kalentis_BRC_03'] = 2400 -- 주오다 브레이슬릿
    value_atk_table['EP17_Kalentis_NECK_04'] = 4800 -- 트리우카스 네클리스
    value_atk_table['EP17_Kalentis_BRC_04'] = 2400 -- 트리우카스 브레이슬릿
    
    -- EP18
    value_atk_table['EP18_NECK_01'] = 7200 -- 피크티스 네클리스  x1.5
    value_atk_table['EP18_BRC_01'] = 3600 -- 피크티스 브레이슬릿  x1.5
    value_atk_table['EP18_NECK_03'] = 7200 -- 주오다 네클리스  x1.5
    value_atk_table['EP18_BRC_03'] = 3600 -- 주오다 브레이슬릿  x1.5
    value_atk_table['EP18_NECK_04'] = 7200 -- 트리우카스 네클리스  x1.5
    value_atk_table['EP18_BRC_04'] = 3600 -- 트리우카스 브레이슬릿  x1.5
end

make_shared_upgrade_acc_table()

-- 무기/방어구/악세 조건 동일
shared_upgrade_acc.is_valid_item = function(item)
    -- 장신구(목걸이/팔찌) 전용 — 일반 장비는 장비 업그레이드(shared_upgrade_equip) 대상
    local class_type = TryGetProp(item, 'ClassType', 'None')
    if class_type ~= 'Neck' and class_type ~= 'Ring' then
        return false, 'NotValidItem'
    end

    if TryGetProp(item, 'EnableUpgrade', 'None') ~= 'YES' then
        return false, 'NotValidItem'
    end
    
    if TryGetProp(item, 'Reinforce_2', 0) < 25 then
        return false, 'Need25Reinforcement'
    end
    
    if TryGetProp(item, 'UpgradeRank', 0) >= 20 then
        return false, 'AlreadyMaxGrade'
    end

    return true
end

shared_upgrade_acc.get_value = function(item, rank)
    if rank == nil then
        rank = TryGetProp(item, 'UpgradeRank', 0)
    end

    local name = TryGetProp(item, 'ClassName', 'None')

    if value_grade_table[name] == nil then
        return 0, 0
    end

    if value_grade_table[name][rank] == nil then
        return 0, 0
    end

    return value_grade_table[name][rank][1], value_grade_table[name][rank][2] 
end

shared_upgrade_acc.get_add_atk_value = function(item)    
    local name = TryGetProp(item, 'ClassName', 'None')

    if value_atk_table[name] == nil then
        return 0
    end

    return value_atk_table[name]
end

shared_upgrade_acc.get_cost = function(item)
    local name = TryGetProp(item, 'ClassName', 'None')
    local lv = TryGetProp(item, 'UseLv', 0)
    local spot = TryGetProp(item, 'ClassType', 'None')

    if material_table[lv] == nil then
        return nil
    end

    if material_table[lv][name] ~= nil then
        return material_table[lv][name]
    end

    if material_table[lv][spot] == nil then
        return nil
    end

    return material_table[lv][spot]
end


function EQUIP_UPGRADE_BELT_510(pc, item)    
    local ret = shared_upgrade_equip.get_value(item)
    item.ALLSTAT = item.ALLSTAT + ret[1][2]
end

function UNEQUIP_UPGRADE_BELT_510(pc, item)    
    local ret = shared_upgrade_equip.get_value(item)
    item.ALLSTAT = item.ALLSTAT - ret[1][2]
end
