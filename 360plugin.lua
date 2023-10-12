-- If the file "../script-opts/360plugin.conf" (or name of this script) is present,
-- and enabled=yes is written to it,
-- or the command line argument "--script-opts=360plugin-enabled=yes" is passed,
-- the features of this script will be running without having to use the toggle key.
-- The following default key bindings can also be reconfigured in the same way
-- (including via CLI) without editing this script at all.
local opts = {
	["enabled"]=false,
	["toggle_vr360"]="v",
	["cycle_input"]="1",
	["cycle_output"]="2",
	["roll_left"]="u",
	["roll_right"]="o",
	["write_log"]="w",
	["pitch_up"]="i",
	["pitch_down"]="k",
	["yaw_up"]="l",
	["yaw_down"]="j",
	["easy_crop"]="c",
	["res_up"]="y",
	["res_down"]="h",
	["zoom_in"]="=",
	["zoom_out"]="-",
	["wzoom_out"]="WHEEL_DOWN",
	["wzoom_in"]="WHEEL_UP",
	["reset_view"]="0",
	["switch_stereo"]="r",
	["switch_eye"]="t",
	["switch_scaler"]="e",
	["switch_output_sbs"]="p",
	["toggle_smooth"]="g",
	["switch_bounds"]="b",
	["new_log_session"]="n",
	["grab_mouse"]="mouse_btn0",
	["mouse_pan"]="mouse_move",
	["show_help"]="?",
	["osc"]="no",
	["fullscreen"]="yes",
	["osd-font-size"]=30
}
(require 'mp.options').read_options(opts)

local saved_props = {
	["hwdec"] 			= "NIL",
	["fullscreen"] 		= "NIL",
	["osc"] 			= "NIL",
	["osd-font-size"] 	= "NIL",
	["cursor-autohide"] = "NIL"
}

local yaw   = 0.0
local last_yaw = 0.0
local init_yaw = 0.0

local pitch = 0.0
local last_pitch = 0.0
local init_pitch = 0.0

local roll  = 0.0
local last_roll  = 0.0
local init_roll = 0.0

local inputProjections = {
	"hequirect",
	"equirect",
	"fisheye",
	"pannini",
	"cylindrical",
	"sg"
}
local inputProjectionInd = 0
local inputProjection    = "hequirect"

local outputProjections = {
	"flat",
	"sg"
}

local outputProjectionInd = 0
local outputProjection    = "flat"



local idfov=180.0
local dfov=110.0
local last_dfov  = 110.0
local init_dfov = 0.0


local doit = 0.0
local res  = 1.0
local dragging = false

local smoothMouse = true

local scaling   = 'linear'

 
local in_stereo  = 'sbs'
local outputMode = '2d'
local out_stereo = '2d'
local anaglyph_filter = ""
local sarOutput = 1.0

local h_flip    = '0'
local in_flip   = ''

local interp    = 'cubic'

local startTime = nil

local filterIsOn = false

local mousePos = {}
local lasttimePos = nil
local filename = nil

local fileobjectNumber = 0
local fileobjectFilename = ''
local videofilename = ''
local file_object      = nil

local ffmpegCommandList = {}

local openNewLogFile = function()
	if lasttimePos ~= nil then
		fileobjectNumber = fileobjectNumber+1
	end
	videofilename = mp.get_property('filename')
	fileobjectFilename = string.format('%s_3dViewHistory_%s.txt',videofilename,fileobjectNumber)
	file_object = io.open(fileobjectFilename, 'w')
	lasttimePos = nil
end

local SecondsToClock = function(seconds)
	local seconds = tonumber(seconds)
	if seconds <= 0 then
		return "00:00:00";
	else
	hours = string.format("%02.f", math.floor(seconds/3600));
	mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
	secs = string.format("%02.2f", seconds - hours*3600 - mins *60);
		return hours .. ":" .. mins .. ":" .. secs
	end
end

local writeHeadPositionChange = function()
	if filename == nil then
		filename = mp.get_property("path")
	end

	if file_object == nil then
		return
	else		
		local initPass=false
		if lasttimePos == nil then
			lasttimePos = mp.get_property("time-pos")
			startTime   = lasttimePos
			initPass=true
			if lasttimePos == nil then
				return
			end
		end

		local newTimePos = mp.get_property("time-pos")

		if newTimePos == nil then
			return
		end

		local outputTs = string.format("%.3f-%.3f ",lasttimePos,newTimePos)
		local changedValues = {}
		local movementDuration = (newTimePos-lasttimePos)
		local maximumTimeoutReached = movementDuration > 5.0

		if initPass or pitch ~= last_pitch or maximumTimeoutReached then
			changedValues[#changedValues+1]= string.format(", [expr] v360 pitch 'lerp(%.3f,%.3f,(T-%.3f)/%.3f)'",last_pitch,pitch,lasttimePos,movementDuration)
		end 
		last_pitch=pitch

		if initPass or yaw ~= last_yaw or maximumTimeoutReached then
			changedValues[#changedValues+1]= string.format(", [expr] v360 yaw 'lerp(%.3f,%.3f,(T-%.3f)/%.3f)'",last_yaw,yaw,lasttimePos,movementDuration)
		end 
		last_yaw=yaw


		if initPass or roll ~= last_roll or maximumTimeoutReached then
			changedValues[#changedValues+1]= string.format(", [expr] v360 roll 'lerp(%.3f,%.3f,(T-%.3f)/%.3f)'",last_roll,roll,lasttimePos,movementDuration)
		end 
		last_roll=roll

		if initPass or dfov ~= last_dfov or maximumTimeoutReached then
			changedValues[#changedValues+1]= string.format(", [expr] v360 d_fov 'lerp(%.3f,%.3f,(T-%.3f)/%.3f)'",last_dfov,dfov,lasttimePos,movementDuration)
		end 
		last_dfov=dfov

		if initPass then
			init_pitch = pitch
			init_yaw   = yaw
			init_roll  = roll
			init_dfov  = dfov
		end

		if #changedValues > 0 then
			local commandString = ''
			for k,changedValue in pairs(changedValues) do
				commandString = commandString .. changedValue
			end

			commandString = commandString:sub(2)

			commandString = outputTs .. commandString .. ';'

			file_object:write(commandString .. '\n')	
			lasttimePos = newTimePos
		end
	end
end

local updateAwaiting = false

local updateComplete = function()
	updateAwaiting = false
end

local printRecordingStatus = function()
	lasttimePos = (mp.get_property("time-pos") or lasttimePos)
	if file_object ~= nil and lasttimePos ~= nil and startTime ~= nil then
		mp.osd_message(string.format("Recording:%s", SecondsToClock(lasttimePos - startTime)), 10)
	end
end

local updateFilters = function ()
	if not filterIsOn then
		mp.command_native_async({"no-osd", "vf", "add", string.format("@vrrev:%sv360=%s:%s:reset_rot=1:in_stereo=%s:out_stereo=%s:id_fov=%s:d_fov=%.3f:yaw=%.3f:pitch=%s:roll=%.3f:w=%s*192.0:h=%.3f*108.0:h_flip=%s:interp=%s,setsar=sar=%.3f%s",in_flip,inputProjection,outputProjection,in_stereo,out_stereo,idfov,dfov,yaw,pitch,roll,res,res,h_flip,scaling,sarOutput,anaglyph_filter)}, updateComplete)
		filterIsOn=true
	elseif not updateAwaiting then
		updateAwaiting=true
		mp.command_native_async({"no-osd", "vf", "set", string.format("@vrrev:%sv360=%s:%s:reset_rot=1:in_stereo=%s:out_stereo=%s:id_fov=%s:d_fov=%.3f:yaw=%.3f:pitch=%s:roll=%.3f:w=%s*192.0:h=%.3f*108.0:h_flip=%s:interp=%s,setsar=sar=%.3f%s",in_flip,inputProjection,outputProjection,in_stereo,out_stereo,idfov,dfov,yaw,pitch,roll,res,res,h_flip,scaling,sarOutput,anaglyph_filter)}, updateComplete)
	end
	writeHeadPositionChange()
end

local mouse_btn0_cb = function ()
	dragging = not dragging
	if dragging then
		mp.set_property("cursor-autohide", "always")
	else
		mp.set_property("cursor-autohide", saved_props["cursor-autohide"])
	end 
end

local mouse_pan = function ()
	if dragging then

		local MousePosx, MousePosy = mp.get_mouse_pos()
		local osd_w, osd_h = mp.get_property("osd-width"), mp.get_property("osd-height")


		local yawpc 	= ((MousePosx/osd_w)-0.5)*180
		local pitchpc   = -((MousePosy/osd_h)-0.5)*180

		local updateCrop = false

		if smoothMouse then
			if yaw ~= yawpc and math.abs(yaw-yawpc)<0.1 then
				yaw = yawpc
				updateCrop=true
				yaw = math.max(-180,math.min(180,yaw))
			elseif yaw ~= yawpc then
				yaw   = (yawpc+(yaw*5))/6
				yaw = math.max(-180,math.min(180,yaw))
				updateCrop=true
			end

			if pitch ~= pitchpc and math.abs(pitch-pitchpc)<0.1 then
				pitch = pitchpc
				pitch = math.max(-180,math.min(180,pitch))
				updateCrop=true
			elseif pitch ~= pitchpc then
				pitch = (pitchpc+(pitch*5))/6
				pitch = math.max(-180,math.min(180,pitch))
				updateCrop=true
			end
		else
			if yaw ~= yawpc then 
				yaw  = yawpc
				yaw = math.max(-180,math.min(180,yaw))
				updateCrop=true
			end
			if pitch ~= pitchpc then 
				pitch  = pitchpc
				pitch = math.max(-180,math.min(180,pitch))
				updateCrop=true
			end

		end

		if updateCrop then
			updateFilters()
		end

	end
end

local increment_res = function(inc)
	res = res+inc
	res = math.max(math.min(res, 20), 1)
	mp.osd_message(string.format("Out-Width: %spx", res*108.0), 0.5)
	updateFilters()
end

local increment_roll = function (inc)
	roll = roll + inc
	if roll > 180.0 then
		roll = 180.0
	elseif roll < -180.0 then
		roll = -180.0
	end
	mp.osd_message(string.format("Roll: %s°", roll), 0.5)
	updateFilters()
end

local increment_pitch = function (inc)
	pitch = pitch + inc
	if pitch > 180.0 then
		pitch = 180.0
	elseif pitch < -180.0 then
		pitch = -180.0
	end
	mp.osd_message(string.format("Pitch: %s°", pitch), 0.5)
	updateFilters()
end

local increment_yaw = function (inc)
	yaw = yaw+inc
	if yaw > 180.0 then
		yaw = 180.0
	elseif yaw < -180.0 then
		yaw = -180.0
	end
	mp.osd_message(string.format("Yaw: %s°", yaw), 0.5)
	updateFilters()
end

local increment_zoom = function (inc)
	dfov = dfov+inc
	dfov = math.max(math.min(150, dfov), 30)
	mp.osd_message(string.format("D-Fov: %s°", dfov), 0.5)
	updateFilters()
end

local reset_view = function()
	yaw = 0.0
	roll = 0.0
	pitch = 0.0
	mp.osd_message("Reset view.", 0.5)
	updateFilters()
end

local toggleSmoothMouse  = function()
	smoothMouse = not smoothMouse
	if smoothMouse then
		mp.osd_message("Mouse smothing On",0.5)
	else
		mp.osd_message("Mouse smothing Off",0.5)
	end
end

local switchoutputsbs = function()
	if outputMode == 'sbs2l:arcd' then
		out_stereo = '2d'
		outputMode = '2d'
		anaglyph_filter=""
		sarOutput = 1.0
		mp.osd_message("2d output mode")
	elseif outputMode == '2d' then
		out_stereo = 'sbs'
		outputMode = 'sbs'
		anaglyph_filter=""
		sarOutput = 1.0
		mp.osd_message("Side by side full width output mode")
	elseif outputMode == 'sbs' then
		out_stereo = 'sbs'
		outputMode = 'sbs-hw'
		anaglyph_filter=""
		sarOutput = 0.5
		mp.osd_message("side by side half width output mode")
	elseif outputMode == 'sbs-hw' then
		out_stereo = 'sbs'
		outputMode = 'sbs2l:arcg'
		anaglyph_filter=",stereo3d=sbs2l:arcg"
		sarOutput = 0.5
		mp.osd_message("Red cyan gray/monochrome anaglyph output mode")
	elseif outputMode == 'sbs2l:arcg' then
		out_stereo = 'sbs'
		outputMode = 'sbs2l:arbg'
		anaglyph_filter=",stereo3d=sbs2l:arbg"
		sarOutput = 0.5
		mp.osd_message("Red blue gray/monochrome anaglyph output mode")
	elseif outputMode == 'sbs2l:arbg' then
		out_stereo = 'sbs'
		outputMode = 'sbs2l:arcd'
		anaglyph_filter=",stereo3d=sbs2l:arcd"
		sarOutput = 0.5
		mp.osd_message("Red cyan dubois anaglyph output mode")
	end
	updateFilters()
end

local switchScaler = function()
	if scaling == 'nearest' then
		scaling = 'cubic'
	elseif scaling == 'cubic' then
		scaling = 'lagrange9'
	elseif scaling == 'lagrange9' then
		scaling = 'lanczos'
	elseif scaling == 'lanczos' then
		scaling = 'linear'
	elseif scaling == 'linear' then
		scaling = 'nearest'
	end
	mp.osd_message("Scaling algorithm: " .. scaling,5.5)
	updateFilters()
end

local switchEye = function()
	if h_flip == '0' then
		h_flip  = '1'
		in_flip = 'hflip,'
		mp.osd_message("Right eye",0.5)
	else
		h_flip  = '0'
		in_flip = ''
		mp.osd_message("Left eye",0.5)
	end
	print(in_flip,h_flip)
	updateFilters()
end


local cycleInputProjection = function()
	inputProjectionInd = ((inputProjectionInd+1) % (#inputProjections +1))
	inputProjection    = inputProjections[inputProjectionInd]
	mp.osd_message(string.format("Input projection: %s ",inputProjection),0.5)
	updateFilters()
end

local cycleOutputProjection = function()
	outputProjectionInd = ((outputProjectionInd+1) % (#outputProjections + 1))
	outputProjection    = outputProjections[outputProjectionInd]
	mp.osd_message(string.format("Output projection: %s",outputProjection),0.5)
	updateFilters()
end


local switchInputFovBounds = function()
	if idfov == 180.0 then
			idfov = 360.0
	elseif idfov == 360.0 then
		idfov = 90.0
	else
		idfov = 180.0
	end
	mp.osd_message(string.format("Input fov bounds: %s°",idfov),0.5)
	updateFilters()
end

local switchStereoMode = function()
	if in_stereo == 'sbs' then
		in_stereo = 'tb'
	else
		in_stereo = 'sbs'
	end
	mp.osd_message("Input format: " .. in_stereo,0.5)
	updateFilters()
end

local binding_by_name = function(lookup)
	for k, v in pairs(bindings) do
		if v["name"] == lookup then
			return k
		end
	end
end

local build_help_string = function()
	return table.concat({ "Default keyboard & mouse controls:\n",
	binding_by_name("show_help"), " = show help\n",
	binding_by_name("res_up"), ",", binding_by_name("res_down"), " = adjust quality\n",
	"Mouse Click = look around\n",
	binding_by_name("roll_left"), ",", binding_by_name("roll_right"), " = roll head\n",
	"Mouse Wheel = zoom\n",
	binding_by_name("switch_stereo"),	" = switch stereo Mode\n",
	binding_by_name("switch_eye"), 		" = switch eye side\n",
	binding_by_name("switch_scaler"), 	" = switch scaler\n",
	binding_by_name("switch_output_sbs"), 	" = toggle side by side output\n",
	binding_by_name("toggle_smooth"), 	" = toggle mouse smoothing\n",
	binding_by_name("new_log_session"),	" = start/stop motion recording\n",
	binding_by_name("cycle_input"), ",", binding_by_name("cycle_output"), " = cycle in and out projections\n",
	binding_by_name("reset_view"), " = center view\n"
	})
end

local help_string = nil

local showHelp = function()
	if help_string == nil then
		help_string = build_help_string()
	end
	mp.osd_message(help_string, 10)
end

local closeCurrentLog = function()
	commandForFinalLog=''
	if lasttimePos ~= nil and file_object ~= nil then

		finalTimeStamp = mp.get_property("time-pos")
		-- Can be nil while the player is shutting down and the file is already closed
		if finalTimeStamp == nil then
			finalTimeStamp = lasttimePos
		end

		file_object:write('#\n')

 		local stats = string.format('# Duration: %s-%s (total %s) %s seconds',
			SecondsToClock(startTime),
			SecondsToClock(finalTimeStamp),
			SecondsToClock(finalTimeStamp - startTime),
			finalTimeStamp - startTime
		)

		print('#')
		file_object:write(stats .. '\n')
		print(stats)

		file_object:write('# Suggested ffmpeg conversion command:\n')

		local closingCommandComment = string.format(
			'ffmpeg -y -ss %s -i "%s" -to %s -copyts -filter_complex "%sv360=%s:%s:in_stereo=%s:out_stereo=%s:reset_rot=1:id_fov=%s:d_fov=%.3f:yaw=%.3f:pitch=%.3f:roll=%.3f:w=1920.0:h=1080.0:interp=cubic:h_flip=%s,setsar=sar=%.3f,sendcmd=filename=%s_3dViewHistory_%s.txt" -avoid_negative_ts make_zero -preset slower -crf 17 "%s_2d_%03d.mp4"',
			startTime, filename, finalTimeStamp, in_flip, inputProjection, outputProjection, in_stereo, out_stereo, idfov, init_dfov, init_yaw, init_pitch, init_roll, h_flip, sarOutput, videofilename, fileobjectNumber, videofilename, fileobjectNumber
		)

				
		file_object:write('# ' .. closingCommandComment .. '\n')
		file_object:write('#\n')

		print(closingCommandComment)
		print('#')

		commandForFinalLog = closingCommandComment
	end
	lasttimePos = nil
	startTime = nil
	if file_object ~= nil then
		file_object:close()
		file_object = nil
	end
	return commandForFinalLog
end

local startNewLogSession = function()
	if file_object == nil then
		openNewLogFile()
		writeHeadPositionChange()
		mp.osd_message(string.format("Started Motion Record %s_3dViewHistory_%s.txt",videofilename,fileobjectNumber), 0.5)
	else
		mp.osd_message(string.format("Stopped Motion Record %s_3dViewHistory_%s.txt",videofilename,fileobjectNumber), 2.5)
		writeHeadPositionChange()
		local command = closeCurrentLog()
		if command then
			ffmpegCommandList[#ffmpegCommandList+1] = command
		end
	end
end

local onExit = function()
	closeCurrentLog()
	mergedCommand = ''
	for _, v in pairs(ffmpegCommandList) do
		if v ~= '' then
			mergedCommand = mergedCommand .. ' & ' .. v
		end
	end
	if mergedCommand ~= '' then
		mergedCommand = mergedCommand:sub(3)
		print(mergedCommand)
		batchfile = io.open('convert_3dViewHistory.bat', 'w')
		batchfile:write(mergedCommand)
		batchfile:close()
		print('Batch processing file created convert_3dViewHistory.bat')
	end
end

local save_props = function()
	for k, _ in pairs(saved_props) do
		local propv = (mp.get_property(k) or "NIL")
		saved_props[k] = propv

		if k == "hwdec" and propv ~= "no" then
			-- Workaround: hardware acceleration rarely works well, so we have to disable it.
			-- Error: [ffmpeg] Impossible to convert between the formats supported by 
			-- the filter 'mpv_src_default_in' and the filter 'auto_scaler_0'
			mp.osd_message("Temporarily turning off hardware decoding.", 1.5)
			mp.set_property("hwdec", "no")
		end
	end
end

local restore_props = function()
	for k, v in pairs(saved_props) do
		if v ~= "NIL" then
			if k == "hwdec" then
				-- Can also be displayed in osd console with "show-text ${hwdec-current}"
				mp.osd_message(string.format("Restoring hardware acceleration: %s", v), 1.5)
			end
			mp.set_property(k, v)
		end
	end

	for k, _ in pairs(saved_props) do
		saved_props[k] = "NIL"
	end
end

local restore_keybinds = function()
	-- There is no need to re-apply the previous key-bindings if they have been
	-- forcibly rebound by our script. They are still there after removal.
	for k,v in pairs(bindings) do
		if k == binding_by_name("toggle_vr360") then
			print("Keeping key bind to toggle vr360: " .. k)
		else
			mp.remove_key_binding(v["name"])
		end
	end
end

local recordingStatusTimer = nil

local initFunction = function()
	save_props()
	for key, pref in pairs(bindings) do
		mp.add_forced_key_binding(key, pref["name"], pref["fn"], pref["flags"])
	end

	mp.set_property("osc", opts["osc"])
	-- It seems not forcing fullscreen may cause minor issues. Use with caution.
	mp.set_property("fullscreen", opts["fullscreen"])
	mp.set_property("osd-font-size", opts["osd-font-size"])

	mp.register_event("end-file", onExit)
	mp.register_event("shutdown", onExit)

	recordingStatusTimer = mp.add_periodic_timer(0.1, printRecordingStatus)

	updateFilters()
end

local teardownFunction = function()
	if recordingStatusTimer ~= nil and recordingStatusTimer:is_enabled() then
		recordingStatusTimer:kill()
		recordingStatusTimer = nil
	end
	filterIsOn = false
	updateAwaiting = true
	mp.unregister_event(onExit)
	onExit()
	-- Remove bindings before to avoid updating the filter with mouse movements
	restore_keybinds()
	-- Remove filter before restoring hardware acceleration to avoid potential errors
	mp.command_native({"no-osd", "vf", "remove", "@vrrev"}, updateComplete)
	restore_props()
end

local toggleVR = function()
	if not opts.enabled then
		opts.enabled = true
		initFunction()
		return
	end
	teardownFunction()
	opts.enabled = false
end

bindings = {
	[opts.toggle_vr360]		=	{name="toggle_vr360",		fn=toggleVR				},
	[opts.cycle_input]		=	{name="cycle_input",		fn=cycleInputProjection },
	[opts.cycle_output]		=	{name="cycle_output",		fn=cycleOutputProjection },
	[opts.roll_left]		=	{name="roll_left",			fn=function() increment_roll(-1) end,	flags={repeatable=true}},
	[opts.roll_right]		=	{name="roll_right",			fn=function() increment_roll(1) end,	flags={repeatable=true}},
	[opts.write_log]		=	{name="write_log",			fn=writeHeadPositionChange },
	[opts.pitch_up]			=	{name="pitch_up",			fn=function() increment_pitch(1) end,	flags={repeatable=true}},
	[opts.pitch_down]		=	{name="pitch_down",			fn=function() increment_pitch(-1) end,	flags={repeatable=true}},
	[opts.yaw_up]			=	{name="yaw_up",				fn=function() increment_yaw(1) end,		flags={repeatable=true}},
	[opts.yaw_down]			=	{name="yaw_down",			fn=function() increment_yaw(-1) end,	flags={repeatable=true}},
	[opts.easy_crop]		=	{name="easy_crop",			fn=updateFilters,						flags={repeatable=true}},
	[opts.res_up]			=	{name="res_up",				fn=function() increment_res(1) end,		flags={repeatable=true}},
	[opts.res_down]			=	{name="res_down",			fn=function() increment_res(-1) end,	flags={repeatable=true}},
	[opts.zoom_in]			=	{name="zoom_in",			fn=function() increment_zoom(-1) end,	flags={repeatable=true}},
	[opts.zoom_out]			=	{name="zoom_out",			fn=function() increment_zoom(1) end,	flags={repeatable=true}},
	[opts.wzoom_out]		=	{name="wzoom_out",			fn=function() increment_zoom(1) end },
	[opts.wzoom_in] 		=	{name="wzoom_in",			fn=function() increment_zoom(-1) end },
	[opts.reset_view] 		=	{name="reset_view",			fn=reset_view 			},
	[opts.switch_stereo]	=	{name="switch_stereo",		fn=switchStereoMode		},
	[opts.switch_eye]		=	{name="switch_eye",			fn=switchEye			},
	[opts.switch_scaler]	=	{name="switch_scaler",		fn=switchScaler			},
	[opts.switch_output_sbs]=	{name="switch_output_sbs",	fn=switchoutputsbs		},	
	[opts.toggle_smooth]	=	{name="toggle_smooth",		fn=toggleSmoothMouse	},
	[opts.switch_bounds]	=	{name="switch_bounds",		fn=switchInputFovBounds	},
	[opts.new_log_session]	=	{name="new_log_session",	fn=startNewLogSession	},
	[opts.grab_mouse]		=	{name="grab_mouse",			fn=mouse_btn0_cb		},
	[opts.mouse_pan]		=	{name="mouse_pan",			fn=mouse_pan			},
	[opts.show_help]		=	{name="show_help",			fn=showHelp				}
}

local register_toggle_key = function ()
	-- mp.add_forced_key_binding("v", "toggle_vr360", toggleVR)
	for k,v in pairs(bindings) do
		if v["name"] == "toggle_vr360" then
			mp.add_forced_key_binding(k, "toggle_vr360", v["fn"])
			return
		end
	end
end

register_toggle_key()

if opts.enabled == true then
	initFunction()
end
