local FADEIN_TIME    = 0.6
local HOLD_TIME      = 1.1
local FADEOUT_TIME   = 0.3
local DISSOLVE_PEAK_ALPHA = 65
local BACKGROUND_DISSOLVE_STYLE = 0
local BACKGROUND_DISSOLVE_EDGE_COLOR = tonumber('FFFF7A1F', 16)
local SHOW_FRAME = false
local SLIDE_DISTANCE = 272  -- 오른쪽으로 밀릴 픽셀 (effect 파일의 1600→1872 기준)

local s_isFadingOut  = false
local s_fadeStartX   = 0
local s_fadeStartY   = 0

local function SKILL_SPINE_INTRO_SET_ALPHA(frame, alphaValue)
	GET_CHILD(frame, "background"):SetAlpha(alphaValue)
	GET_CHILD(frame, "spinepic"):SetAlpha(alphaValue)
	GET_CHILD(frame, "frame"):SetAlpha(alphaValue)
	GET_CHILD(frame, "skillName"):SetAlpha(alphaValue)
end

local function SKILL_SPINE_INTRO_SET_DISSOLVE_ALPHA(frame, alphaValue)
	GET_CHILD(frame, "dissolve"):SetAlpha(alphaValue)
end

local function SKILL_SPINE_INTRO_CLEAR_BACKGROUND_DISSOLVE(frame)
	local background = GET_CHILD(frame, "background")
	AUTO_CAST(background)
	background:ClearDissolve()
end

local function SKILL_SPINE_INTRO_SET_BACKGROUND_DISSOLVE(frame, progress)
	local background = GET_CHILD(frame, "background")
	AUTO_CAST(background)

	local edgeWidth = 0.025 + math.sin(progress * math.pi) * 0.045
	background:SetDissolveStyle(BACKGROUND_DISSOLVE_STYLE)
	background:SetDissolveEdge(edgeWidth, BACKGROUND_DISSOLVE_EDGE_COLOR)
	background:SetDissolve(progress)
end

function SKILL_SPINE_INTRO_ON_INIT(addon, frame)
end

function SKILL_SPINE_INTRO_OPEN(frame)
	s_isFadingOut = false

	frame:RunUpdateScript("SKILL_SPINE_INTRO_UPDATE", 0, 0, 0, 1)


end

function SKILL_SPINE_INTRO_CLOSE(frame)
	SKILL_SPINE_INTRO_CLEAR_BACKGROUND_DISSOLVE(frame)
end

function SKILL_SPINE_INTRO_START(spineName)
	ui.CloseFrame("skill_spine_intro")

	local frame = ui.GetFrame("skill_spine_intro")
	local showFrame = SHOW_FRAME == true and 1 or 0
	GET_CHILD(frame, "frame"):ShowWindow(showFrame)
	GET_CHILD(frame, "dissolve"):ShowWindow(showFrame)

	frame:StopUpdateScript("SKILL_SPINE_INTRO_UPDATE")
	SKILL_SPINE_INTRO_CLEAR_BACKGROUND_DISSOLVE(frame)
	SKILL_SPINE_INTRO_SET_ALPHA(frame, 0)
	SKILL_SPINE_INTRO_SET_DISSOLVE_ALPHA(frame, 0)
	SKILL_SPINE_IMAGE_SET(frame, spineName)


	ui.OpenFrame("skill_spine_intro")
end

function SKILL_SPINE_IMAGE_SET(frame, spineName)
	local spinepic = GET_CHILD(frame, "spinepic")
    local spineInfo = geSpine.GetSpineInfo(spineName);
    if spineInfo ~= nil then
        spinepic:SetScaleFactor(spineInfo:GetScaleFactor());
        spinepic:CreateSpineActor(spineInfo:GetRoot(), spineInfo:GetAtlas(), spineInfo:GetJson(), "", spineInfo:GetAnimation(), spineInfo:GetIsPremultiplied());
        spinepic:SetIsStopAnim(false)
    end	

end

function SKILL_SPINE_INTRO_UPDATE(frame, elapsedTime)
	local holdEnd   = FADEIN_TIME + HOLD_TIME
	local totalTime = holdEnd + FADEOUT_TIME

	if elapsedTime <= FADEIN_TIME then
		local rate = elapsedTime / FADEIN_TIME
		SKILL_SPINE_INTRO_SET_ALPHA(frame, math.floor(100 * rate))
		SKILL_SPINE_INTRO_SET_DISSOLVE_ALPHA(frame, 0)
	elseif elapsedTime <= holdEnd then
		SKILL_SPINE_INTRO_SET_ALPHA(frame, 100)
		SKILL_SPINE_INTRO_SET_DISSOLVE_ALPHA(frame, 0)
	elseif elapsedTime <= totalTime then

		-- fadeout 시작 첫 프레임: 현재 위치 저장
		if not s_isFadingOut then
			s_isFadingOut = true
			s_fadeStartX  = frame:GetGlobalX()
			s_fadeStartY  = frame:GetGlobalY()
		end
		-- rate: 1.0(시작) → 0.0(끝)
		local rate   = (totalTime - elapsedTime) / FADEOUT_TIME
		local slideX = s_fadeStartX + math.floor(SLIDE_DISTANCE * (1 - rate))
		local dissolveProgress = 1 - rate
		frame:SetPos(slideX, s_fadeStartY)
		SKILL_SPINE_INTRO_SET_BACKGROUND_DISSOLVE(frame, dissolveProgress)
		SKILL_SPINE_INTRO_SET_ALPHA(frame, math.floor(100 * rate))
		SKILL_SPINE_INTRO_SET_DISSOLVE_ALPHA(frame, math.floor(DISSOLVE_PEAK_ALPHA * 4 * rate * (1 - rate)))

	else
		SKILL_SPINE_INTRO_SET_ALPHA(frame, 0)
		SKILL_SPINE_INTRO_SET_DISSOLVE_ALPHA(frame, 0)
		s_isFadingOut = false
		ui.CloseFrame("skill_spine_intro")
		return 0
	end

	return 1
end
