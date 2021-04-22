@ECHO OFF
pushd %~dp0
ECHO "%~1"
IF "%~1"=="" GOTO BLANK
mpv.exe --script=360plugin.lua --script-opts=360plugin-enabled=yes "%~1"
GOTO DONE
:BLANK
mpv.exe --script=360plugin.lua --script-opts=360plugin-enabled=yes
:DONE
popd