

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

local scaling   = 'near'

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
local file_object      = nil

local ffmpegComamndList = {}

local openNewLogFile = function()
	if lasttimePos ~= nil then
		fileobjectNumber = fileobjectNumber+1
	end
	file_object = io.open(string.format('3dViewHistory_%s.txt',fileobjectNumber), 'w')
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

local ouputPos = function()

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

		if pitch ~= last_pitch then
			changedValues[#changedValues+1]= string.format(", [expr] v360 pitch %.3f",pitch)
		end 
		last_pitch=pitch

		if yaw ~= last_yaw then
			changedValues[#changedValues+1]= string.format(", [expr] v360 yaw %.3f",yaw)
		end 
		last_yaw=yaw


		if roll ~= last_roll then
			changedValues[#changedValues+1]= string.format(", [expr] v360 roll %.3f",roll)
		end 
		last_roll=roll

		if dfov ~= last_dfov then
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


local draw_cropper = function ()

	if not filterIsOn then
		local ok, err = mp.command(string.format("async no-osd vf add @vrrev:%sv360=%s:%s:in_stereo=%s:out_stereo=2d:id_fov=%s:d_fov=%.3f:yaw=%.3f:pitch=%s:roll=%.3f:w=%s*192.0:h=%.3f*108.0:h_flip=%s:interp=%s",in_flip,inputProjection,outputProjection,in_stereo,idfov,dfov,yaw,pitch,roll,res,res,h_flip,scaling))
		filterIsOn=true
	else
		local ok, err = mp.command(string.format("async no-osd vf set @vrrev:%sv360=%s:%s:in_stereo=%s:out_stereo=2d:id_fov=%s:d_fov=%.3f:yaw=%.3f:pitch=%s:roll=%.3f:w=%s*192.0:h=%.3f*108.0:h_flip=%s:interp=%s",in_flip,inputProjection,outputProjection,in_stereo,idfov,dfov,yaw,pitch,roll,res,res,h_flip,scaling))
		filterIsOn=true
	end

	ouputPos()
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
			draw_cropper()
		end

	end
end


local increment_res = function ()
	res = res+1
	res = math.min(res,20)

	mp.osd_message(string.format("Out-Width: %spx",res*108.0),0.5)
	draw_cropper()
end
local decrement_res = function ()
	res = res-1
	res = math.max(1,res)
	mp.osd_message(string.format("Out-Width: %spx",res*108.0),0.5)

	draw_cropper()
end


local increment_roll = function ()
	roll = roll+1
	draw_cropper()
end
local decrement_roll = function ()
	roll = roll-1
	draw_cropper()
end

local increment_pitch = function ()
	pitch = pitch+1
	draw_cropper()
end
local decrement_pitch = function ()
	pitch = pitch-1
	draw_cropper()
end

local increment_yaw = function ()
	yaw = yaw+1
	draw_cropper()
end
local decrement_yaw = function ()
	yaw = yaw-1
	draw_cropper()
end

local increment_zoom = function ()
	dfov = dfov+1
	dfov = math.min(180,dfov)
	mp.osd_message(string.format("D-Fov: %s°",dfov),0.5)
	draw_cropper()
end
local decrement_zoom = function ()
	dfov = dfov-1

	dfov = math.max(1,dfov)

	mp.osd_message(string.format("D-Fov: %s°",dfov),0.5)
	draw_cropper()
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
	if scaling == 'near' then
		scaling = 'cubic'
	else
		scaling = 'near'
	end
	mp.osd_message("Scaling algorithm: " .. scaling,0.5)
	draw_cropper()
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
	draw_cropper()
end


local cycleInputProjection = function()
	inputProjectionInd = ((inputProjectionInd+1) % (#inputProjections +1))
	inputProjection    = inputProjections[inputProjectionInd]
	mp.osd_message(string.format("Input projection: %s ",inputProjection),0.5)
	draw_cropper()
end

local cycleOutputProjection = function()
	outputProjectionInd = ((outputProjectionInd+1) % (#outputProjections + 1))
	outputProjection    = outputProjections[outputProjectionInd]
	mp.osd_message(string.format("Output projection: %s",outputProjection),0.5)
	draw_cropper()
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
	draw_cropper()
end

local switchStereoMode = function()
	if in_stereo == 'sbs' then
		in_stereo = 'tb'

	else
		in_stereo = 'sbs'
	end
	mp.osd_message("Input format: " .. in_stereo,0.5)
	draw_cropper()
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

		local closingCommandComment = string.format('ffmpeg -y -ss %s -i "%s" -to %s -copyts -filter_complex "%sv360=%s:%s:in_stereo=%s:out_stereo=2d:id_fov=%s:d_fov=%.3f:yaw=%.3f:pitch=%.3f:roll=%.3f:w=1920.0:h=1080.0:interp=cubic:h_flip=%s,sendcmd=filename=3dViewHistory_%s.txt" -avoid_negative_ts make_zero -preset slower -crf 17 3dViewout_%03d.mp4',
			startTime,filename,finalTimeStamp,in_flip,inputProjection,outputProjection,in_stereo,idfov,init_dfov,init_yaw,init_pitch,init_roll,h_flip,fileobjectNumber,fileobjectNumber
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
		ouputPos()
		mp.osd_message(string.format("Start Motion Record 3dViewHistory_%s.txt",fileobjectNumber),0.5)
	else
		mp.osd_message(string.format("Stop Motion Record 3dViewHistory_%s.txt",fileobjectNumber),0.5)
		ouputPos()
		local command = closeCurrentLog()
		if command then
			ffmpegComamndList[#ffmpegComamndList+1] = command
		end
	end
		
end

local onExit = function()
	startNewLogSession()
	mergedCommand = ''
	for k,v in pairs(ffmpegComamndList) do
		if v ~= '' then
			mergedCommand = mergedCommand .. ' & ' .. v
		end
	end
	if mergedCommand ~= '' then
		mergedCommand = mergedCommand:sub(3)
		print(mergedCommand)
		batchfile = io.open(string.format('convert_3dViewHistory.bat',fileobjectNumber), 'w')
		batchfile:write(mergedCommand)
		file_object:close()
		print('Batch processing file created convert_3dViewHistory.bat')
	else
		print('No head motions logged')
	end
end


local initFunction = function()

	mp.add_forced_key_binding("1", cycleInputProjection  )
	mp.add_forced_key_binding("2", cycleOutputProjection )

	mp.add_forced_key_binding("u", decrement_roll, 'repeatable')
	mp.add_forced_key_binding("o", increment_roll, 'repeatable')

	mp.add_forced_key_binding("v", ouputPos)

	mp.add_forced_key_binding("i", increment_pitch, 'repeatable')
	mp.add_forced_key_binding("k", decrement_pitch, 'repeatable')
	mp.add_key_binding("l", increment_yaw, 'repeatable')
	mp.add_key_binding("j", decrement_yaw, 'repeatable')
	mp.add_key_binding("c", "easy_crop", draw_cropper)

	mp.add_forced_key_binding("y", increment_res, 'repeatable')
	mp.add_forced_key_binding("h", decrement_res, 'repeatable')

	mp.add_forced_key_binding("=", increment_zoom, 'repeatable')
	mp.add_forced_key_binding("-", decrement_zoom, 'repeatable')

	mp.add_forced_key_binding("WHEEL_DOWN", increment_zoom)
	mp.add_forced_key_binding("WHEEL_UP", decrement_zoom)

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

	draw_cropper()

end

mp.register_event("file-loaded", initFunction)