

local yaw   = 0.0
local last_yaw = 0.0

local pitch = 0.0
local last_pitch = 0.0

local roll  = 0.0
local last_roll  = 0.0

local dfov=110.0
local last_dfov  = 110.0

local doit = 0.0
local res  = 1.0
local dragging = false

local scaling   = 'near'

local in_stereo = 'sbs'

local h_flip    = '0'
local in_flip   = ''

local interp    = 'near'

local startTime = nil

local filterIsOn = false

local mousePos = {}
local lasttimePos = nil
local filename = nil

local fileobjectNumber = 0
local file_object      = io.open('3dViewHistory.txt', 'w')

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
		mp.error('Unable to open file for appending: ')
		return
	else
		
		if lasttimePos == nil then
			lasttimePos = mp.get_property("time-pos")
			startTime   = lasttimePos
		else
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

			local only_zoom = (pitch==0 and yaw==0 and roll == 0)

			if #changedValues > 0 and not only_zoom then
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

end


local draw_cropper = function ()

	if not filterIsOn then
		local ok, err = mp.command(string.format("async no-osd vf add @vrrev:%sv360=hequirect:flat:in_stereo=%s:out_stereo=2d:id_fov=180.0:d_fov=%.3f:yaw=%.3f:pitch=%s:roll=%.3f:w=%s*192.0:h=%.3f*108.0:h_flip=%s:interp=%s",in_flip,in_stereo,dfov,yaw,pitch,roll,res,res,h_flip,scaling))
		filterIsOn=true
	else
		local ok, err = mp.command(string.format("async no-osd vf set @vrrev:%sv360=hequirect:flat:in_stereo=%s:out_stereo=2d:id_fov=180.0:d_fov=%.3f:yaw=%.3f:pitch=%s:roll=%.3f:w=%s*192.0:h=%.3f*108.0:h_flip=%s:interp=%s",in_flip,in_stereo,dfov,yaw,pitch,roll,res,res,h_flip,scaling))
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


		if yaw ~= yawpc and math.abs(yaw-yawpc)<0.1 then
			yaw = yawpc
			updateCrop=true
		elseif yaw ~= yawpc then
			yaw   = (yawpc+yaw+yaw)/3
			updateCrop=true
		end

		if pitch ~= pitchpc and math.abs(pitch-pitchpc)<0.1 then
			pitch = pitchpc
			updateCrop=true
		elseif pitch ~= pitchpc then
			pitch = (pitchpc+pitch+pitch)/3
			updateCrop=true
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
	mp.osd_message("Keyboard and Mouse Controls:\n? = show help\ny,h = adjust quality\ni,j,k,l,mouseClick = Look around\nu,i = roll head\n-,=,mouseWheel = zoom\nr = switch SetereoMode\nt = switch Eye\ne = switch Scaler ",10)
end


local onExit = function()
	if lasttimePos ~= nil then

		file_object:write('#\n')

 		local stats = string.format( '# Duration: %s-%s (total %s) %s seconds', 
			SecondsToClock(startTime),SecondsToClock(lasttimePos),SecondsToClock(lasttimePos-startTime),lasttimePos-startTime )

		print('#')
		file_object:write( stats  .. '\n')
		print(stats)

		file_object:write( '# Suggested ffmpeg conversion command:\n')

		local closingCommandComment = string.format('# ffmpeg -y -ss %s -i "%s" -to %s -copyts -filter_complex "%sv360=hequirect:flat:in_stereo=%s:out_stereo=2d:id_fov=180.0:d_fov=110.0:yaw=0:pitch=0:roll=0:w=1920.0:h=1080.0:interp=cubic:h_flip=%s,sendcmd=filename=3dViewHistory.txt" -avoid_negative_ts make_zero -preset slower -crf 17 out.mp4',
			startTime,filename,lasttimePos,in_flip,in_stereo,h_flip
		)
		file_object:write(closingCommandComment .. '\n')
		file_object:write('#\n')

		print(closingCommandComment)
		print('#')
		file_object:close()
	end
end



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


mp.set_property("osc", "no")
mp.set_property("fullscreen", "yes")
mp.add_forced_key_binding("mouse_btn0",mouse_btn0_cb)
mp.add_forced_key_binding("mouse_move", mouse_pan)

mp.add_forced_key_binding("?", showHelp)
mp.add_forced_key_binding("/", showHelp)

mp.register_event("shutdown", onExit)

draw_cropper()