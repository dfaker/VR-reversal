

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
	"hequirect",
	"equirect",
	"fisheye",
	"pannini",
	"cylindrical",
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

local in_stereo = 'sbs'

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

local ffmpegComamndList = {}

local openNewLogFile = function()
	if lasttimePos ~= nil then
		fileobjectNumber = fileobjectNumber+1
	end
	videofilename = mp.get_property('filename')
	fileobjectFilename = string.format('%s_3dViewHistory_%s.txt',videofilename,fileobjectNumber)
	file_object = io.open(fileobjectFilename, 'w')
	lasttimePos=nil
end


function SecondsToClock(seconds)
  local seconds = tonumber(seconds)

  if seconds <= 0 then
    return "00:00:00";
  else
    hours = string.format("%02.f", math.floor(seconds/3600));
    mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
    secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));
    return hours..":"..mins..":"..secs
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

		if initPass or pitch ~= last_pitch then
			changedValues[#changedValues+1]= string.format(", [expr] v360 pitch %.3f",pitch)
		end 
		last_pitch=pitch

		if initPass or yaw ~= last_yaw then
			changedValues[#changedValues+1]= string.format(", [expr] v360 yaw %.3f",yaw)
		end 
		last_yaw=yaw


		if initPass or roll ~= last_roll then
			changedValues[#changedValues+1]= string.format(", [expr] v360 roll %.3f",roll)
		end 
		last_roll=roll

		if initPass or dfov ~= last_dfov then
			changedValues[#changedValues+1]= string.format(", [expr] v360 d_fov %.3f",dfov)
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

local updateFilters = function ()

	if not filterIsOn then
		mp.command_native_async({"no-osd", "vf", "add", string.format("@vrrev:%sv360=%s:%s:in_stereo=%s:out_stereo=2d:id_fov=%s:d_fov=%.3f:yaw=%.3f:pitch=%s:roll=%.3f:w=%s*192.0:h=%.3f*108.0:h_flip=%s:interp=%s",in_flip,inputProjection,outputProjection,in_stereo,idfov,dfov,yaw,pitch,roll,res,res,h_flip,scaling)}, updateComplete)
		filterIsOn=true
	else
		if not updateAwaiting then
			updateAwaiting=true
			mp.command_native_async({"no-osd", "vf", "set", string.format("@vrrev:%sv360=%s:%s:in_stereo=%s:out_stereo=2d:id_fov=%s:d_fov=%.3f:yaw=%.3f:pitch=%s:roll=%.3f:w=%s*192.0:h=%.3f*108.0:h_flip=%s:interp=%s",in_flip,inputProjection,outputProjection,in_stereo,idfov,dfov,yaw,pitch,roll,res,res,h_flip,scaling)}, updateComplete)
		end
		filterIsOn=true
	end

	writeHeadPositionChange()
end

local mouse_btn0_cb = function ()
	dragging = not dragging
	if dragging then
		mp.set_property("cursor-autohide", "always")
	else
		mp.set_property("cursor-autohide", "no")
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
			elseif yaw ~= yawpc then
				yaw   = (yawpc+(yaw*5))/6
				updateCrop=true
			end

			if pitch ~= pitchpc and math.abs(pitch-pitchpc)<0.1 then
				pitch = pitchpc
				updateCrop=true
			elseif pitch ~= pitchpc then
				pitch = (pitchpc+(pitch*5))/6
				updateCrop=true
			end
		else
			if yaw ~= yawpc then 
				yaw  = yawpc
				updateCrop=true
			end
			if pitch ~= pitchpc then 
				pitch  = pitchpc
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
	res = math.max(math.min(res,20),1)
	mp.osd_message(string.format("Out-Width: %spx",res*108.0),0.5)
	updateFilters()
end

local increment_roll = function (inc)
	roll = roll+inc
	updateFilters()
	mp.osd_message(string.format("Roll: %s°",roll),0.5)
end

local increment_pitch = function (inc)
	pitch = pitch+inc
	updateFilters()
end

local increment_yaw = function (inc)
	yaw = yaw+inc
	updateFilters()
end

local increment_zoom = function (inc)
	dfov = dfov+inc
	dfov = math.max(math.min(150,dfov),30)
	mp.osd_message(string.format("D-Fov: %s°",dfov),0.5)
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
	print(ih_flip,h_flip)
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

local showHelp  = function()
	mp.osd_message("Keyboard and Mouse Controls:\n? = show help\ny,h = adjust quality\ni,j,k,l,mouseClick = Look around\nu,i = roll head\n-,=,mouseWheel = zoom\nr = switch SetereoMode\nt = switch Eye\ne = switch Scaler\ng = toggle mouse smothing\nn = start and stop motion recording\n1,2 - cycle in and out projections",10)
end

local closeCurrentLog = function()
	commandForFinalLog=''
	if lasttimePos ~= nil  and file_object ~= nil then

		finalTimeStamp = mp.get_property("time-pos")

		file_object:write('#\n')

 		local stats = string.format( '# Duration: %s-%s (total %s) %s seconds', 
			SecondsToClock(startTime),SecondsToClock(finalTimeStamp),SecondsToClock(finalTimeStamp-startTime),finalTimeStamp-startTime )

		print('#')
		file_object:write( stats  .. '\n')
		print(stats)

		file_object:write( '# Suggested ffmpeg conversion command:\n')

		local closingCommandComment = string.format('ffmpeg -y -ss %s -i "%s" -to %s -copyts -filter_complex "%sv360=%s:%s:in_stereo=%s:out_stereo=2d:id_fov=%s:d_fov=%.3f:yaw=%.3f:pitch=%.3f:roll=%.3f:w=1920.0:h=1080.0:interp=cubic:h_flip=%s,sendcmd=filename=%s_3dViewHistory_%s.txt" -avoid_negative_ts make_zero -preset slower -crf 17 %s_2d_%03d.mp4',
			startTime,filename,finalTimeStamp,in_flip,inputProjection,outputProjection,in_stereo,idfov,init_dfov,init_yaw,init_pitch,init_roll,h_flip,videofilename,fileobjectNumber,videofilename,fileobjectNumber
		)

				
		file_object:write('# ' .. closingCommandComment .. '\n')
		file_object:write('#\n')

		print(closingCommandComment)
		print('#')

		commandForFinalLog = closingCommandComment
	end
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
		mp.osd_message(string.format("Start Motion Record %s_3dViewHistory_%s.txt",videofilename,fileobjectNumber),0.5)
	else
		mp.osd_message(string.format("Stop Motion Record %s_3dViewHistory_%s.txt",videofilename,fileobjectNumber),0.5)
		writeHeadPositionChange()
		local command = closeCurrentLog()
		if command then
			ffmpegComamndList[#ffmpegComamndList+1] = command
		end
	end
		
end

local onExit = function()
	closeCurrentLog()
	mergedCommand = ''
	for k,v in pairs(ffmpegComamndList) do
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
	else
		print('No head motions logged')
	end
end

local initFunction = function()

	mp.add_forced_key_binding("1", cycleInputProjection  )
	mp.add_forced_key_binding("2", cycleOutputProjection )

	mp.add_forced_key_binding("u", function() increment_roll(-1) end, 'repeatable')
	mp.add_forced_key_binding("o", function() increment_roll(1)  end, 'repeatable')

	mp.add_forced_key_binding("v", writeHeadPositionChange)

	mp.add_forced_key_binding("i", function() increment_pitch(1)  end, 'repeatable')
	mp.add_forced_key_binding("k", function() increment_pitch(-1) end, 'repeatable')
	mp.add_key_binding("l", function() increment_yaw(1)  end, 'repeatable')
	mp.add_key_binding("j", function() increment_yaw(-1) end, 'repeatable')
	mp.add_key_binding("c", "easy_crop", updateFilters)

	mp.add_forced_key_binding("y", function() increment_res(1)  end, 'repeatable')
	mp.add_forced_key_binding("h", function() increment_res(-1) end, 'repeatable')

	mp.add_forced_key_binding("=", function() increment_zoom(-1)  end, 'repeatable')
	mp.add_forced_key_binding("-", function() increment_zoom(1) end, 'repeatable')

	mp.add_forced_key_binding("WHEEL_DOWN", function() increment_zoom(1)  end)
	mp.add_forced_key_binding("WHEEL_UP",   function() increment_zoom(-1) end)

	mp.add_forced_key_binding("r", switchStereoMode)
	mp.add_forced_key_binding("t", switchEye)
	mp.add_forced_key_binding("e", switchScaler)
	mp.add_forced_key_binding("g", toggleSmoothMouse)
	mp.add_forced_key_binding("b", switchInputFovBounds)
	mp.add_forced_key_binding("n", startNewLogSession)

	mp.set_property("osc", "no")
	mp.set_property("fullscreen", "yes")
	mp.set_property("osd-font-size", "30")
	mp.add_forced_key_binding("mouse_btn0",mouse_btn0_cb)
	mp.add_forced_key_binding("mouse_move", mouse_pan)

	mp.add_forced_key_binding("?", showHelp)
	mp.add_forced_key_binding("/", showHelp)

	mp.register_event("shutdown", onExit)

	updateFilters()

end

mp.register_event("file-loaded", initFunction)