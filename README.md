# VR-reversal

Uses mpv to display a 3D side-by-side video as a 2D video, allows you to look around and zoom within the video.

Steps:

- Download the lastest mpv https://mpv.io/
- Download the 360plugin.lua from this repo.
- Play a video using the plugin with the command: `mpv --script=360plugin.lua videoFile.mp4`


# Controls
- `y` Increase resolution
- `h` decrease resolution
- `i`,`j`,`k`,`l` look around 
- `u`,`o` roll head
- `=`,`-` zoom
- `q` quit
- MouseLook: to look around with the mouse: one click to start, move the mouse to look around and then click again to stop
- MouseScroll: Zoom in and out

The video will start at a low resolution, press `y` increase the initial quality.

# 'Head' Motion Logging
Your 'head' movements in the video will be logged to a file named `3dViewHistory.txt` this is in the format of ffmpeg commands and looks like:

```
188.792256-188.807622 [expr] v360 pitch -0.100000, [expr] v360 yaw 0.400000, [expr] v360 roll 0.000000, [expr] v360 d_fov 90.000000;
188.807622-188.824578 [expr] v360 pitch -0.300000, [expr] v360 yaw 1.000000, [expr] v360 roll 0.000000, [expr] v360 d_fov 90.000000;
...
224.595089-224.611200 [expr] v360 pitch -3.500000, [expr] v360 yaw 7.100000, [expr] v360 roll 0.000000, [expr] v360 d_fov 95.000000;
224.611200-224.627511 [expr] v360 pitch -3.200000, [expr] v360 yaw 7.100000, [expr] v360 roll 0.000000, [expr] v360 d_fov 95.000000;
```

You can you the file `3dViewHistory.txt` to render out your head motions to a 2d video with the command:
`ffmpeg -ss 188 -i videoFile.mp4 -to 224 -copyts -vf "v360=hequirect:flat:in_stereo=sbs:out_stereo=2d:id_fov=180.0:d_fov=90:yaw=0:pitch=0:roll=0:w=1920.0:h=1080.0:interp=cubic,sendcmd=filename=3dViewHistory.txt" outputVideo.mp4`

Where the values for `-ss 188` and `-to 224` should be the values from your 3dViewHistory.txt specifiyng the start and stop time in seconds of your view recording.
