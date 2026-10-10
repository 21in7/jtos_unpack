
function FULLBLACK_ON_INIT(addon, frame)
	addon:RegisterMsg('CHANGE_CLIENT_SIZE', 'FRAME_FULLSCREEN');
	addon:RegisterMsg('RESERVE_FULLBLACK', 'RESERVE_FULLBLACK');
end

function FULLBLACK_FIRST_OPEN(frame)
	FULLBLACK_RESIZE(frame);
end

function FULLBLACK_RESIZE(frame)
	DIRECTORMODE_SIZE_UPDATE(frame);
	local picture = frame:GetChild('screenmask');
	DIRECTORMODE_SIZE_UPDATE(picture);
end

function RESERVE_FULLBLACK(frame, argStr ,time)

	RunScript("_RESERVE_FULLBLACK", frame, time)

end

function _RESERVE_FULLBLACK(frame, time)
	ui.OpenFrame("fullblack");
	sleep(time)
	ui.CloseFrame("fullblack");
end