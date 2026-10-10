-- boss_card_upgrade.lua

-- 전역 프로퍼티
local BOSS_CARD_UPGRADE_PROPERTY = {
    -- [고정 정보]
    fixedMaterialName = "None",
    fixedMaterialGuid = "None",

    -- [가변 정보]
    targetCardClassName = "None",
    targetCardName = "None",
    targetCardLevel = 1,
    
    -- [레시피 정보]
    mainMaterialCount = 0,
    subMaterials = {},           -- 서브 재료 리스트 (이제 최대 2개)

    -- [재료 카드 정보] (변경: 2개까지 저장)
    materialCardGroup = "None",
    materialCardGuids = {"None", "None"}, -- [1], [2] 슬롯

    beforeLevel = 0,
    afterLevel = 0,
    newCardGuid = 0,
}

function BOSS_CARD_UPGRADE_ON_INIT(addon, frame)
    addon:RegisterMsg('INVENTORY_RBUTTON_CLICK', 'BOSS_CARD_UPGRADE_RBUTTON_CLICK');
end

function OPEN_BOSS_CARD_UPGRADE(invItem)
    local frame = ui.GetFrame('boss_card_upgrade');
    BOSS_CARD_UPGRADE_PROPERTY_CLEAR();
    BOSS_CARD_UPGRADE_CLEAR(frame);
    
    local obj = GetIES(invItem:GetObject());
    BOSS_CARD_UPGRADE_PROPERTY.fixedMaterialName = obj.ClassName;
    BOSS_CARD_UPGRADE_PROPERTY.fixedMaterialGuid = invItem:GetIESID();

    frame:ShowWindow(1);
    BOSS_CARD_UPGRADE_SET_FIXED_MATERIAL_UI(frame, obj, invItem);
    INVENTORY_SET_CUSTOM_RBTNDOWN("BOSS_CARD_UPGRADE_SELECT_ITEM");
end

function BOSS_CARD_UPGRADE_CLOSE()
    BOSS_CARD_UPGRADE_PROPERTY_CLEAR();
    INVENTORY_SET_CUSTOM_RBTNDOWN("None");
    ui.CloseFrame('boss_card_upgrade');
end

function BOSS_CARD_UPGRADE_PROPERTY_CLEAR()
    BOSS_CARD_UPGRADE_PROPERTY.fixedMaterialName = "None";
    BOSS_CARD_UPGRADE_PROPERTY.fixedMaterialGuid = "None";
    BOSS_CARD_UPGRADE_PROPERTY.targetCardClassName = "None";
    BOSS_CARD_UPGRADE_PROPERTY.targetCardName = "None";
    BOSS_CARD_UPGRADE_PROPERTY.mainMaterialCount = 0;
    BOSS_CARD_UPGRADE_PROPERTY.subMaterials = {};
    BOSS_CARD_UPGRADE_PROPERTY.newCardGuid = 0;
    BOSS_CARD_UPGRADE_PROPERTY.materialCardGroup ="None"
    BOSS_CARD_UPGRADE_PROPERTY.materialCardGuids = {"None", "None"} -- 초기화
end

function BOSS_CARD_UPGRADE_CLEAR(frame)
    if frame == nil then return; end

    -- 메인 카드 슬롯 초기화
    local slot_main = GET_CHILD_RECURSIVELY(frame, "material_slot_main_boss_card");
    if slot_main ~= nil then 
        slot_main:ClearIcon(); 
        slot_main:SetUserValue("GUID", "None"); 
    end

    -- 메인 재료 슬롯 초기화
    local slot_material = GET_CHILD_RECURSIVELY(frame, "material_slot_main_material");
    if slot_material ~= nil then 
        slot_material:ClearIcon(); 
        slot_material:SetText("");
    end
    
    -- [변경] 서브 재료 슬롯 초기화 (1~2)
    for i = 1, 2 do
        local subSlot = GET_CHILD_RECURSIVELY(frame, "material_slot_sub_material" .. i);
        if subSlot ~= nil then subSlot:ClearIcon(); subSlot:SetText(""); end
    end

    -- [변경] 재료 카드 슬롯 초기화 (1~2)
    for i = 1, 2 do
        local cardSlot = GET_CHILD_RECURSIVELY(frame, "material_slot_sub_card" .. i);
        if cardSlot ~= nil then
            cardSlot:ClearIcon();
            cardSlot:SetUserValue("GUID", "None");
            -- 우클릭 시 해제 스크립트 연결 (XML에 설정되어 있지 않다면 코드에서 연결)
            -- cardSlot:SetEventScript(ui.RBUTTONUP, "BOSS_CARD_UPGRADE_REMOVE_MATERIAL_CARD");
            -- cardSlot:SetEventScriptArgNumber(ui.RBUTTONUP, i);
        end
    end

    local btn = GET_CHILD_RECURSIVELY(frame, "upgrade_btn");
    if btn ~= nil then btn:SetEnable(0); end

    -- UI 숨김 처리
    local infoText = GET_CHILD_RECURSIVELY(frame, "info_text_1");
    if infoText ~= nil then infoText:ShowWindow(0) end

    local targetCardText = GET_CHILD_RECURSIVELY(frame, "text_target_boss_card_name");
    if targetCardText ~= nil then targetCardText:ShowWindow(0) end

    local resultGbox = GET_CHILD_RECURSIVELY(frame, "resultGbox")
    if resultGbox ~= nil then resultGbox:ShowWindow(0) end
    
    local resultGbox2 = GET_CHILD_RECURSIVELY(frame, "resultGbox2")
    if resultGbox2 ~= nil then resultGbox2:ShowWindow(0) end

    local upgradeBtn = GET_CHILD_RECURSIVELY(frame, 'upgrade_btn')
    if upgradeBtn ~= nil then upgradeBtn:EnableHitTest(1) end
end

function BOSS_CARD_UPGRADE_SET_FIXED_MATERIAL_UI(frame, obj, invItem)
    local slot = GET_CHILD_RECURSIVELY(frame, "material_slot_main_material");
    if slot == nil then return; end

    SET_SLOT_IMG(slot, obj.Icon);
    SET_ITEM_TOOLTIP_BY_OBJ(slot:GetIcon(), invItem);
    slot:GetIcon():SetTooltipOverlap(1);
    slot:SetText(string.format("{@st66d}{#FFFFFF}%s{/}", invItem.count));
end

--------------------------------------------------------------------------------
-- 인벤토리 선택 로직
--------------------------------------------------------------------------------
function BOSS_CARD_UPGRADE_SELECT_ITEM(obj, slot, guid)
    local inv_item = GET_ITEM_BY_GUID(guid);
    if inv_item == nil then return; end
    if inv_item.isLockState == true then
        ui.SysMsg(ClMsg("MaterialItemIsLock"));
        return;
    end

    local groupName = TryGetProp(obj, "GroupName", "None")
    local Reinforce_Type = TryGetProp(obj, "Reinforce_Type", "None");

    -- 재료 카드 선택 로직으로 분기
    if BOSS_CARD_UPGRADE_PROPERTY.targetCardClassName ~= "None" and groupName == "Card" and Reinforce_Type == "Card" then
        BOSS_CARD_UPGRADE_SELECT_MATERIAL_CARD(obj, slot, guid);
        return;
    end

    if GET_ITEM_LEVEL(obj) >= 10 then
        ui.SysMsg(ClMsg("MaxReinforceItem"));
        return;
    end

    local clickedItemClassName = obj.ClassName;
    local recipeCls = GetClass("BossCardUpgrade", clickedItemClassName);
    if recipeCls == nil then
        ui.SysMsg(ClMsg("NotBossCardUpgradeTarget"));
        return;
    end

    local fixedMatName = BOSS_CARD_UPGRADE_PROPERTY.fixedMaterialName;
    local isValid = false;

    local mainMat = TryGetProp(recipeCls, "MainMaterialItemName", "None");
    if mainMat == fixedMatName then
        isValid = true;
    else
        -- [변경] 서브 재료 루프 1~2로 축소
        for i = 1, 2 do
            local subMat = TryGetProp(recipeCls, "SubMaterialItemName"..i, "None");
            if subMat == fixedMatName then
                isValid = true;
                break;
            end
        end
    end

    if isValid == false then
        ui.SysMsg(ClMsg("MaterialNotMatchCard"));
        return;
    end

    BOSS_CARD_UPGRADE_SET_TARGET_CARD(guid, clickedItemClassName, recipeCls);
end

-- [변경] 재료 카드 선택 로직 (2개 슬롯 순차 채움)
function BOSS_CARD_UPGRADE_SELECT_MATERIAL_CARD(obj, slot, guid)
    if GET_ITEM_LEVEL(obj) < 10 then
        ui.SysMsg(ClMsg("NotBossCardUpgradeTarget"));
        return;
    end

    local materialCardGroup = BOSS_CARD_UPGRADE_PROPERTY.materialCardGroup;
    local cardGroupName = TryGetProp(obj, "CardGroupName", "None")

    if materialCardGroup ~= cardGroupName then
        ui.SysMsg(ClMsg("NotBossCardUpgradeTarget"));
        return;
    end

    -- 이미 등록된 카드인지 확인 (중복 등록 방지)
    if BOSS_CARD_UPGRADE_PROPERTY.materialCardGuids[1] == guid or BOSS_CARD_UPGRADE_PROPERTY.materialCardGuids[2] == guid then
        ui.SysMsg(ClMsg("AlreadRegSameCard")); 
        return;
    end

    -- 빈 슬롯 찾기
    if BOSS_CARD_UPGRADE_PROPERTY.materialCardGuids[1] == "None" then
        BOSS_CARD_UPGRADE_PROPERTY.materialCardGuids[1] = guid;
    elseif BOSS_CARD_UPGRADE_PROPERTY.materialCardGuids[2] == "None" then
        BOSS_CARD_UPGRADE_PROPERTY.materialCardGuids[2] = guid;
    else
        -- 슬롯이 꽉 찼을 경우, 1번을 교체하거나 메시지 출력 (여기서는 메시지)
        -- ui.SysMsg(ClMsg("MaterialSlotIsFull"));
        -- return;
        
        -- 혹은 밀어내기 방식: 2번에 넣고 싶으면 아래 주석 해제
        BOSS_CARD_UPGRADE_PROPERTY.materialCardGuids[1] = BOSS_CARD_UPGRADE_PROPERTY.materialCardGuids[2]
        BOSS_CARD_UPGRADE_PROPERTY.materialCardGuids[2] = guid
    end

    BOSS_CARD_UPGRADE_UPDATE()
end

function BOSS_CARD_UPGRADE_TARGET_CARD_SLOT_CLEAR(parent, slot)
    if BOSS_CARD_UPGRADE_PROPERTY.targetCardClassName == "None" then return end


    local recipeMainMat = GetClass("BossCardUpgrade", BOSS_CARD_UPGRADE_PROPERTY.targetCardClassName).MainMaterialItemName;

    local needCount = BOSS_CARD_UPGRADE_PROPERTY.mainMaterialCount;

    local invItem = session.GetInvItemByName(recipeMainMat);

    OPEN_BOSS_CARD_UPGRADE(invItem)

end


-- [추가] 타겟 카드 슬롯 우클릭 시 해제 함수
function BOSS_CARD_UPGRADE_REMOVE_TARGET_CARD(parent, slot)
    local frame = ui.GetFrame('boss_card_upgrade');
    
    -- 1. 슬롯 UI 비우기
    slot:ClearIcon();
    slot:SetUserValue("GUID", "None");

    -- 2. 프로퍼티(데이터) 초기화
    -- (고정 재료인 fixedMaterialName은 건드리지 않고, 가변 정보만 리셋합니다)
    BOSS_CARD_UPGRADE_PROPERTY.targetCardClassName = "None";
    BOSS_CARD_UPGRADE_PROPERTY.targetCardName = "None";
    BOSS_CARD_UPGRADE_PROPERTY.targetCardLevel = 1;
    
    -- 레시피 정보 초기화
    BOSS_CARD_UPGRADE_PROPERTY.mainMaterialCount = 0;
    BOSS_CARD_UPGRADE_PROPERTY.subMaterials = {};

    -- 재료 카드 정보 초기화 (대상 카드가 없으면 필요 재료 카드 조건도 사라짐)
    BOSS_CARD_UPGRADE_PROPERTY.materialCardGroup = "None";
    BOSS_CARD_UPGRADE_PROPERTY.materialCardGuids = {"None", "None"};

    -- 3. 재료 카드 슬롯 UI도 같이 비워주기
    -- (대상이 사라지면 이전에 등록한 재료 카드들도 유효하지 않을 수 있으므로 제거)
    for i = 1, 2 do
        local cardSlot = GET_CHILD_RECURSIVELY(frame, "material_slot_sub_card" .. i);
        if cardSlot ~= nil then
            cardSlot:ClearIcon();
            cardSlot:SetUserValue("GUID", "None");
        end
    end
    
    -- 4. 안내 텍스트 숨기기 등을 위해 UPDATE 호출
    BOSS_CARD_UPGRADE_UPDATE();
end

-- [추가] 재료 카드 슬롯 우클릭 시 제거 함수 (UI XML에서 호출 필요: RBtnUpScp)
function BOSS_CARD_UPGRADE_REMOVE_MATERIAL_CARD(parent, slot, argNum)
    local index = argNum -- 1 or 2
    local name = slot:GetName();
    if string.find(name, "1") then index = 1; else index = 2; end
 
    BOSS_CARD_UPGRADE_PROPERTY.materialCardGuids[index] = "None";
    slot:ClearIcon();
    slot:SetUserValue("GUID", "None");
    BOSS_CARD_UPGRADE_UPDATE();
end

function BOSS_CARD_UPGRADE_SET_TARGET_CARD(guid, className, recipeCls)
    local frame = ui.GetFrame('boss_card_upgrade');
    local slot = GET_CHILD_RECURSIVELY(frame, "material_slot_main_boss_card");
    local inv_item = GET_ITEM_BY_GUID(guid);
    local obj = GetIES(inv_item:GetObject());

    SET_SLOT_IMG(slot, obj.Icon);
    SET_ITEM_TOOLTIP_BY_OBJ(slot:GetIcon(), inv_item);
    slot:GetIcon():SetTooltipOverlap(1);
    slot:SetUserValue("GUID", guid);

    local cardLevel = GET_ITEM_LEVEL(obj);
    local mainMaterialAddCount = TryGetProp(recipeCls, "MainMaterialAddCount", 0)
    mainMaterialAddCount = tonumber(mainMaterialAddCount)
    mainMaterialAddCount = mainMaterialAddCount * (cardLevel - 1);

    BOSS_CARD_UPGRADE_PROPERTY.targetCardClassName = className;
    BOSS_CARD_UPGRADE_PROPERTY.targetCardName = obj.Name;
    BOSS_CARD_UPGRADE_PROPERTY.targetCardLevel = cardLevel
    BOSS_CARD_UPGRADE_PROPERTY.mainMaterialCount = TryGetProp(recipeCls, "MainMaterialCount", 0) + mainMaterialAddCount;

    -- [변경] 서브 재료 로드 (1~2)
    BOSS_CARD_UPGRADE_PROPERTY.subMaterials = {};
    for i = 1, 2 do
        local subName = TryGetProp(recipeCls, "SubMaterialItemName"..i, "None");
        local subCount = TryGetProp(recipeCls, "SubMaterialCount"..i, 0);
        local addCount = TryGetProp(recipeCls, "SubMaterialAddCount"..i, 0);

        subCount = tonumber(subCount)
        addCount = tonumber(addCount)
        subCount = subCount + addCount * (cardLevel - 1);

        if subName ~= "None" and subCount > 0 then
            table.insert(BOSS_CARD_UPGRADE_PROPERTY.subMaterials, {
                index = i,
                name = subName,
                count = subCount
            });
        end
    end

    -- 재료 카드 그룹 초기화
    BOSS_CARD_UPGRADE_PROPERTY.materialCardGuids = {"None", "None"} -- 대상 바뀔 때 초기화
    local materialCardGroup = TryGetProp(recipeCls, "MaterialCardGroup", "None")
    if materialCardGroup ~= "None" then
        BOSS_CARD_UPGRADE_PROPERTY.materialCardGroup = materialCardGroup;
    else
        BOSS_CARD_UPGRADE_PROPERTY.materialCardGroup = "None"
    end

    BOSS_CARD_UPGRADE_UPDATE();
end

--------------------------------------------------------------------------------
-- UI 갱신
--------------------------------------------------------------------------------
function BOSS_CARD_UPGRADE_UPDATE()
    local frame = ui.GetFrame('boss_card_upgrade');
    if frame == nil then return; end

    if BOSS_CARD_UPGRADE_PROPERTY.targetCardClassName == "None" then return; end

    local fixedMatName = BOSS_CARD_UPGRADE_PROPERTY.fixedMaterialName;
    local isAllEnough = true;

    -- 1. 메인 재료
    local slot_material = GET_CHILD_RECURSIVELY(frame, "material_slot_main_material");
    local recipeMainMat = GetClass("BossCardUpgrade", BOSS_CARD_UPGRADE_PROPERTY.targetCardClassName).MainMaterialItemName;
    local needCount = BOSS_CARD_UPGRADE_PROPERTY.mainMaterialCount;
    local invItem = session.GetInvItemByName(recipeMainMat);
    local curCount = (invItem ~= nil) and invItem.count or 0;

    if slot_material ~= nil then
        local colorStr = (curCount < needCount) and "{#FF0000}" or "{#FFFFFF}";
        slot_material:SetText(string.format("{@st66d}%s%s/%s{/}", colorStr, curCount, needCount));
        slot_material:SetUserValue("GUID", BOSS_CARD_UPGRADE_PROPERTY.fixedMaterialGuid);
    end
    
    if curCount < needCount then isAllEnough = false; end

    -- 2. [변경] 서브 재료 (1~2)
    for i = 1, 2 do
        local subSlot = GET_CHILD_RECURSIVELY(frame, "material_slot_sub_material" .. i);
        if subSlot ~= nil then subSlot:ClearIcon(); subSlot:SetText(""); end
    end

    local subMatNamesText = "";
    for _, subData in ipairs(BOSS_CARD_UPGRADE_PROPERTY.subMaterials) do
        local subSlot = GET_CHILD_RECURSIVELY(frame, "material_slot_sub_material" .. subData.index);
        local subCls = GetClass("Item", subData.name);
        local subInv = session.GetInvItemByName(subData.name);
        local subCur = (subInv ~= nil) and subInv.count or 0;

        if subSlot ~= nil and subCls ~= nil then
            if subMatNamesText ~= "" then subMatNamesText = "{@st66d_y}"..subMatNamesText.." {nl}{@st100white_16} - {@st66d_y}"; end
            subMatNamesText = subMatNamesText .. subCls.Name.."{@st100white_16} "..subData.count..ClMsg("CountOfThings");

            SET_SLOT_IMG(subSlot, subCls.Icon);
            local colorStr = (subCur < subData.count) and "{#FF0000}" or "{#FFFFFF}";
            subSlot:SetText(string.format("{@st66d}%s%s/%s{/}", colorStr, subCur, subData.count));
            
            SET_ITEM_TOOLTIP_BY_TYPE(subSlot:GetIcon(), subCls.ClassID);
            subSlot:GetIcon():SetTooltipOverlap(1);
            if subInv ~= nil then
             subSlot:SetUserValue("GUID", subInv:GetIESID());
            end
        end

        if subCur < subData.count then isAllEnough = false; end
    end

    -- 3. [변경] 재료 카드 (2개 확인)
    local cardGroup = {    
        ATK = "CardRed",
        DEF = "CardBlue",
        UTIL = "CardPurple",
        STAT = "CardGreen",
    }

    local materialCardGroup = BOSS_CARD_UPGRADE_PROPERTY.materialCardGroup;
    local cardType = cardGroup[materialCardGroup] or "None"

    if cardType ~= "None" then
        -- 텍스트에 2장 필요하다고 명시 (기획에 따라 다를 수 있음, 여기선 2장 요구 가정)
        subMatNamesText = subMatNamesText .."{nl}-{@st66d_y}  ".."10★" ..ClMsg(cardType).."{@st100white_16} 2"..ClMsg("CountOfThings");
        
        -- 2개의 슬롯을 순회하며 갱신
        local registeredCardCount = 0
        for i = 1, 2 do
            local guid = BOSS_CARD_UPGRADE_PROPERTY.materialCardGuids[i]
            local slot = GET_CHILD_RECURSIVELY(frame, "material_slot_sub_card" .. i);
            
            if slot ~= nil then
                if guid ~= "None" then
                    local inv_item = GET_ITEM_BY_GUID(guid);
                    if inv_item ~= nil then
                        local obj = GetIES(inv_item:GetObject());
                        SET_SLOT_IMG(slot, obj.Icon);
                        SET_ITEM_TOOLTIP_BY_OBJ(slot:GetIcon(), inv_item);
                        slot:GetIcon():SetTooltipOverlap(1);
                        slot:SetUserValue("GUID", guid);
                        registeredCardCount = registeredCardCount + 1
                    else
                        slot:ClearIcon();
                        slot:SetUserValue("GUID", "None");
                    end
                else
                    slot:ClearIcon();
                    slot:SetUserValue("GUID", "None");
                end
            end
        end

        -- 카드가 2장 다 채워져야 upgrade 가능
        if registeredCardCount < 2 then
            isAllEnough = false;
        end
    end

    -- 4. 안내 텍스트
    local infoText = GET_CHILD_RECURSIVELY(frame, "info_text_1");
    if infoText ~= nil then
        infoText:SetTextByKey("give", BOSS_CARD_UPGRADE_PROPERTY.targetCardName);
        local mainMatCls = GetClass("Item", GetClass("BossCardUpgrade", BOSS_CARD_UPGRADE_PROPERTY.targetCardClassName).MainMaterialItemName);
        infoText:SetTextByKey("material", (mainMatCls and mainMatCls.Name or ""));
        infoText:SetTextByKey("needCount", tostring(BOSS_CARD_UPGRADE_PROPERTY.mainMaterialCount));
        infoText:SetTextByKey("sub", (subMatNamesText == "") and "" or subMatNamesText);
        infoText:ShowWindow(1)
    end

    local targetCardText = GET_CHILD_RECURSIVELY(frame, "text_target_boss_card_name");
    if targetCardText ~= nil then
        targetCardText:SetTextByKey("value", BOSS_CARD_UPGRADE_PROPERTY.targetCardName)
        targetCardText:ShowWindow(1)
    end
    
    local btn = GET_CHILD_RECURSIVELY(frame, "upgrade_btn");
    if btn ~= nil then
        btn:SetEnable(isAllEnough and 1 or 0);
    end
end

--------------------------------------------------------------------------------
-- 실행
--------------------------------------------------------------------------------
function BOSS_CARD_UPGRADE_EXEC()
    local frame = ui.GetFrame('boss_card_upgrade');
    local slot_main = GET_CHILD_RECURSIVELY(frame, "material_slot_main_boss_card");
    local main_guid = slot_main:GetUserValue("GUID");

    if main_guid == "None" then return; end

    if BOSS_CARD_UPGRADE_CHECK_MATERIALS() == false then
        ui.SysMsg(ClMsg("NotEnoughMaterial"));
        return;
    end
    
    local mainItem = GET_ITEM_BY_GUID(main_guid);
    local mainObj = GetIES(mainItem:GetObject());
    ui.MsgBox(ScpArgMsg("ReallyUpgradeCard{NAME}", "NAME", mainObj.Name), "BOSS_CARD_UPGRADE_REQUEST", "None");
end

function BOSS_CARD_UPGRADE_CHECK_MATERIALS()
    -- 메인 재료
    local recipeMainMat = GetClass("BossCardUpgrade", BOSS_CARD_UPGRADE_PROPERTY.targetCardClassName).MainMaterialItemName;
    local needCount = BOSS_CARD_UPGRADE_PROPERTY.mainMaterialCount;
    local invItem = session.GetInvItemByName(recipeMainMat);
    if invItem == nil or invItem.count < needCount then return false; end

    -- 서브 재료
    for _, subData in ipairs(BOSS_CARD_UPGRADE_PROPERTY.subMaterials) do
        local subInv = session.GetInvItemByName(subData.name);
        if subInv == nil or subInv.count < subData.count then return false; end
    end
    
    -- 재료 카드 (2장 체크)
    if BOSS_CARD_UPGRADE_PROPERTY.materialCardGroup ~= "None" then
        if BOSS_CARD_UPGRADE_PROPERTY.materialCardGuids[1] == "None" or BOSS_CARD_UPGRADE_PROPERTY.materialCardGuids[2] == "None" then
            return false
        end
    end

    return true;
end

function BOSS_CARD_UPGRADE_REQUEST()
    local frame = ui.GetFrame('boss_card_upgrade');
    if frame == nil then return; end

    session.ResetItemList();

    -- 1. 메인 카드
    local slot_main = GET_CHILD_RECURSIVELY(frame, "material_slot_main_boss_card");
    local main_guid = slot_main:GetUserValue("GUID");
    if main_guid == nil or main_guid == "None" then return; end
    session.AddItemID(main_guid, 1);

    -- 2. 메인 재료
    local mainMatCount = BOSS_CARD_UPGRADE_PROPERTY.mainMaterialCount;
    if mainMatCount > 0 then
        local slot_material = GET_CHILD_RECURSIVELY(frame, "material_slot_main_material");
        local mat_guid = slot_material:GetUserValue("GUID");
        if mat_guid ~= nil and mat_guid ~= "None" then
            session.AddItemID(mat_guid, mainMatCount);
        end
    end

    -- 3. 서브 재료
    for _, subData in ipairs(BOSS_CARD_UPGRADE_PROPERTY.subMaterials) do
        local subSlot = GET_CHILD_RECURSIVELY(frame, "material_slot_sub_material" .. subData.index);
        local sub_guid = subSlot:GetUserValue("GUID");
        if sub_guid ~= nil and sub_guid ~= "None" then
            session.AddItemID(sub_guid, subData.count);
        end
    end

    -- 4. [변경] 재료 카드 (2장 모두 추가)
    if BOSS_CARD_UPGRADE_PROPERTY.materialCardGroup ~= "None" then
        for i = 1, 2 do
            local mat_guid = BOSS_CARD_UPGRADE_PROPERTY.materialCardGuids[i];
            if mat_guid == nil or mat_guid == "None" then
                ui.SysMsg(ClMsg("NotEnoughMaterial"));
                return;
            end
            session.AddItemID(mat_guid, 1);
        end
    end

    local result = item.DialogTransaction("BOSS_CARD_UPGRADE", session.GetItemIDList());
end

--------------------------------------------------------------------------------
-- 5. 강화 성공 및 연출 (Client Side)
--------------------------------------------------------------------------------

-- 서버에서 ExecClientScp로 호출하는 함수
-- stringScp = "BOSS_CARD_UPGRADE_SUCCESS(before, after, 'guid_string')"
function BOSS_CARD_UPGRADE_SUCCESS(beforeLv, afterLv, guid)
    local frame = ui.GetFrame("boss_card_upgrade")
    if frame == nil then return end

    -- 1. 성공 타이머 시작 (연출 타이밍 조절용)
    local timer = GET_CHILD_RECURSIVELY(frame, "timer");
    if timer ~= nil then
        timer:ShowWindow(1);
        timer:ForcePlayAnimation(); -- 타이머 스크립트(BOSS_CARD_REINFORCE_TIMER) 가동
    end

    -- 2. 결과 UI 표시를 위한 데이터 저장
    frame:SetUserValue("IsVisibleResult", 1)
    frame:SetUserValue("beforeLevel", beforeLv)
    frame:SetUserValue("afterLevel", afterLv)

    -- 3. UI 갱신 (성공한 카드로 다시 세팅)
    -- 고정 재료(fixedMaterial)를 기준으로 창을 다시 여는 것과 같은 효과
    local invItem = GET_ITEM_BY_GUID(BOSS_CARD_UPGRADE_PROPERTY.fixedMaterialGuid);
    if invItem ~= nil then
        OPEN_BOSS_CARD_UPGRADE(invItem);
        
        -- 강화된 카드를 다시 타겟으로 잡음
        local newCardItem = GET_ITEM_BY_GUID(guid);
        if newCardItem ~= nil then
            local obj = GetIES(newCardItem:GetObject());
            -- 슬롯에 다시 등록 (레시피 재계산)
            BOSS_CARD_UPGRADE_SELECT_ITEM(obj, nil, guid);
        end
    end
    
    -- 4. 이펙트 실행
    BOSS_CARD_UPGRADE_EFFECT_EXEC(frame)
end

-- 성공 이펙트 (폭죽 등)
function BOSS_CARD_UPGRADE_EFFECT_EXEC(frame)
    local resulteffect_position_slot = GET_CHILD_RECURSIVELY(frame, "resulteffect_position_slot");
    if resulteffect_position_slot == nil then return end
    
    local posX, posY = GET_SCREEN_XY(resulteffect_position_slot);

    -- 연출용 이펙트 이름 (클라이언트에 존재하는 이펙트여야 함)
    local effectName = "UI_success_logo_empty"     -- 예시
    local startEffectName = "UI_card_empty"        -- 예시

    -- 화면 좌표에 이펙트 재생
    movie.PlayUIEffect(startEffectName, posX, posY, 4.2)
    movie.PlayUIEffect(effectName, posX, posY, 4)
end

-- 타이머에 의해 호출됨: 연출이 끝난 후 결과창(Gbox) 띄우기
function BOSS_CARD_REINFORCE_TIMER(ctrl, str, tick)
    local frame = ctrl:GetTopParentFrame()
    
    -- 5초 뒤 결과 UI 표시
    if tick == 5 then
        BOSS_CARD_UPGRADE_EFFECT_UI_EXEC(frame)
    
    -- 30초 뒤 결과창 닫기 (자동 정리)
    elseif tick == 30 then
        local resultGbox = GET_CHILD_RECURSIVELY(frame, "resultGbox")
        if resultGbox ~= nil then resultGbox:ShowWindow(0) end
        
        local resultGbox2 = GET_CHILD_RECURSIVELY(frame, "resultGbox2")
        if resultGbox2 ~= nil then resultGbox2:ShowWindow(0) end
    end
end

-- 결과 텍스트 및 버튼 변경
function BOSS_CARD_UPGRADE_EFFECT_UI_EXEC(frame)
    local beforeLv = frame:GetUserValue("beforeLevel")
    local afterLv = frame:GetUserValue("afterLevel")

    local beforeLvText = GET_CHILD_RECURSIVELY(frame, 'before_lv')
    local afterLvText = GET_CHILD_RECURSIVELY(frame, 'after_lv')
    
    if beforeLvText ~= nil then beforeLvText:SetTextByKey("value", "LV " .. beforeLv) end
    if afterLvText ~= nil then afterLvText:SetTextByKey("value", "LV " .. afterLv) end
        
    local resultGbox2 = GET_CHILD_RECURSIVELY(frame, 'resultGbox2')
    if resultGbox2 ~= nil then resultGbox2:ShowWindow(1) end
    
    -- 강화 버튼을 "확인" 버튼으로 잠시 변경
    local upgradeBtn = GET_CHILD_RECURSIVELY(frame, 'upgrade_btn')
    if upgradeBtn ~= nil then
        upgradeBtn:SetTextByKey("value", ClMsg("Confirm"))
        upgradeBtn:EnableHitTest(0) -- 클릭 방지 (연출 중)
    end

    BOSS_CARD_UPGRADE_DRAW_RESULT(frame)
end

function BOSS_CARD_UPGRADE_DRAW_RESULT(frame)
    ui.SetHoldUI(false);

    local resultGbox = GET_CHILD_RECURSIVELY(frame, 'resultGbox')
    local upgradeBtn = GET_CHILD_RECURSIVELY(frame, 'upgrade_btn')
    
    if resultGbox ~= nil then resultGbox:ShowWindow(1) end
    if upgradeBtn ~= nil then upgradeBtn:EnableHitTest(1) end
end