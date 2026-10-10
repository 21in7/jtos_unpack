function SCR_KATYN72_BOSS_PRE_DIALOG(pc, dialog)
    local result = SCR_QUEST_CHECK(pc, 'KATYN72_MQ_10')
    if result == 'PROGRESS' then
        return 'YES'
    end
    return 'NO'
end

function SCR_KATYN72_CORPSE_PRE_DIALOG(pc, dialog)
    local result = SCR_QUEST_CHECK(pc, 'KATYN72_MQ_01')
    if result == 'PROGRESS' then
        return 'YES'
    end
    return 'NO'
end
function SCR_KATYN72_RASSFLY_PRE_DIALOG(pc, dialog)
    local result = SCR_QUEST_CHECK(pc, 'KATYN72_MQ_03')
    if result == 'PROGRESS' then
        return 'YES'
    end
    return 'NO'
end

function SCR_KATYN72_GHOST_PRE_DIALOG(pc, dialog)
    return 'NO'
end

function SCR_NPC_KNELLER_DIALOG(self, pc)
    local zone_name = GetZoneName(pc);
    local map_cls = GetClass("Map", zone_name);
    if map_cls ~= nil then
        local bgm_play_list = TryGetProp(map_cls, "BgmPlayList", "None");
        StopMusicQueueLocal(pc, bgm_play_list);
    end
    PlayMusicQueueLocal(pc, "master_Kneller", true)
    ShowOkDlg(pc, "MASTER_KNELLER_NPC_basic1")
end