
function VIDEO_PLAYER_ON_INIT(addon, frame)
	addon:RegisterMsg('PLAY_VIDEO', 'PLAY_VIDEO');
	addon:RegisterMsg('STOP_VIDEO', 'STOP_VIDEO');
end

function VIDEO_PLAYER_FIRST_OPEN(frame)
	VIDEO_PLAYER_RESIZE(frame);
end

function VIDEO_PLAYER_RESIZE(frame)
	DIRECTORMODE_SIZE_UPDATE(frame);
	local picture = frame:GetChild('video');
	DIRECTORMODE_SIZE_UPDATE(picture);
end

function PLAY_VIDEO(frame, arg, fileName)
	ui.OpenFrame("video_player");
	local video = GET_CHILD_RECURSIVELY(frame, 'video')
	if video ~= nil then
        video:Stop()
		video:SetVideoName(fileName)
		video:Play()
    end
end

function STOP_VIDEO(frame)
	ui.OpenFrame("video_player");
	local video = GET_CHILD_RECURSIVELY(frame, 'video')
    if video ~= nil then
        video:Stop()
    end
	ui.CloseFrame("video_player");
end
