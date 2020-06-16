
local yaw   = 0.0
local pitch = 0.0
local roll  = 0.0
local doit = 0.0
local res  = 1.0
local dragging = false
local dfov=90.0

local startTime = nil

local filterIsOn = false

local mousePos = {}
local lasttimePos = nil
local filename = nil


local file_object = io.open('3dViewHistory.txt', 'w')

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

			commandString = string.format("%.3f-%.3f [expr] v360 pitch %.3f, [expr] v360 yaw %.3f, [expr] v360 roll %.3f, [expr] v360 d_fov %.3f;",
				lasttimePos,newTimePos,pitch,yaw,roll,dfov)			

			lasttimePos = newTimePos
			file_object:write(commandString .. '\n')
		end

	end

end


local draw_cropper = function ()

	if not filterIsOn then
		local ok, err = mp.command(string.format("async no-osd vf add @vrrev:v360=hequirect:flat:in_stereo=sbs:out_stereo=2d:id_fov=180.0:d_fov=%.3f:yaw=%.3f:pitch=%s:roll=%.3f:w=%s*192.0:h=%.3f*108.0",dfov,yaw,pitch,roll,res,res))
		filterIsOn=true
	else
		local ok, err = mp.command(string.format("async no-osd vf set @vrrev:v360=hequirect:flat:in_stereo=sbs:out_stereo=2d:id_fov=180.0:d_fov=%.3f:yaw=%.3f:pitch=%s:roll=%.3f:w=%s*192.0:h=%.3f*108.0",dfov,yaw,pitch,roll,res,res))
		filterIsOn=true
	end

	ouputPos()
end

local mouse_btn0_cb = function ()
	dragging = not dragging
	mousePos.x, mousePos.y = mp.get_mouse_pos()
end

local mouse_pan = function ()
	local tempMousePos = {}
	if dragging then
		tempMousePos.x, tempMousePos.y = mp.get_mouse_pos()
		yaw   = yaw + ((tempMousePos.x-mousePos.x)/10.0)
		pitch = pitch - ((tempMousePos.y-mousePos.y)/10.0)
		mousePos = tempMousePos
		draw_cropper()
	end
end


local increment_res = function ()
	res = res+1
	mp.osd_message(string.format("Resolution: %s",res*108.0))
	draw_cropper()
end
local decrement_res = function ()
	res = res-1
	res = math.max(1,res)

	mp.osd_message(string.format("Resolution: %s",res*108.0))

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
	mp.osd_message(string.format("Fov: %s",dfov))
	draw_cropper()
end
local decrement_zoom = function ()
	dfov = dfov-1

	dfov = math.max(1,dfov)

	mp.osd_message(string.format("Fov: %s",dfov))
	draw_cropper()
end

local onExit = function()
	if lasttimePos ~= nil then
		closingCommandComment = string.format('# ffmpeg -ss %s -i "%s" -to %s -copyts -vf "v360=hequirect:flat:in_stereo=sbs:out_stereo=2d:id_fov=180.0:d_fov=90:yaw=0:pitch=0:roll=0:w=1920.0:h=1080.0:interp=cubic,sendcmd=filename=3dViewHistory.txt" -preset slow -crf 17 out.mp4',
			startTime,filename,lasttimePos
		)
		file_object:write(closingCommandComment .. '\n')
		print(closingCommandComment)
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

 

mp.set_property("osc", "no")
mp.set_property("fullscreen", "yes")
mp.add_forced_key_binding("mouse_btn0",mouse_btn0_cb)
mp.add_forced_key_binding("mouse_move", mouse_pan)

mp.register_event("shutdown", onExit)

draw_cropper()