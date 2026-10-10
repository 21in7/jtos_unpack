function SCR_CORAL_32_1_HIDDEN_TRAP1_PRE_DIALOG(pc, dialog, handle)
    local result1 = SCR_QUEST_CHECK(pc, 'CORAL_32_1_SQ_4')
    local result2 = SCR_QUEST_CHECK(pc, 'CORAL_32_1_SQ_5')
    if result1 == 'PROGRESS' then
        return 'YES'
    elseif result2 == 'PROGRESS' then
        return 'YES'
    end
    return 'NO'
end

function SCR_CORAL_32_1_HIDDEN_TRAP2_PRE_DIALOG(pc, dialog, handle)
    local result1 = SCR_QUEST_CHECK(pc, 'CORAL_32_1_SQ_4')
    local result2 = SCR_QUEST_CHECK(pc, 'CORAL_32_1_SQ_7')
    if result1 == 'PROGRESS' then
        return 'YES'
    elseif result2 == 'PROGRESS' then
        return 'YES'
    end
    return 'NO'
end

function SCR_CORAL_32_1_CORALPOINT1_PRE_DIALOG(pc, dialog, handle)
    local result = SCR_QUEST_CHECK(pc, 'CORAL_32_1_SQ_9')
    if result == 'PROGRESS' then
        return 'YES'
    end
    return 'NO'
end

function SCR_CORAL_32_1_CORALPOINT2_PRE_DIALOG(pc, dialog, handle)
    local result = SCR_QUEST_CHECK(pc, 'CORAL_32_1_SQ_9')
    if result == 'PROGRESS' then
        return 'YES'
    end
    return 'NO'
end

function SCR_CORAL_32_1_CORALPOINT3_PRE_DIALOG(pc, dialog, handle)
    local result = SCR_QUEST_CHECK(pc, 'CORAL_32_1_SQ_9')
    if result == 'PROGRESS' then
        return 'YES'
    end
    return 'NO'
end

function SCR_CORAL_32_1_SQ_6_NPC_PRE_DIALOG(pc, dialog, handle)
    return 'NO'
end

function SCR_NPC_COMMODORE_DIALOG(self, pc)
    local zone_name = GetZoneName(pc);
    local map_cls = GetClass("Map", zone_name);
    if map_cls ~= nil then
        local bgm_play_list = TryGetProp(map_cls, "BgmPlayList", "None");
        StopMusicQueueLocal(pc, bgm_play_list);
    end
    PlayMusicQueueLocal(pc, "master_Commodore", true)
    ShowOkDlg(pc, "MASTER_COMMODORE_NPC_basic1")
end