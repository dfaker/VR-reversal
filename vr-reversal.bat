@ECHO OFF
pushd %~dp0
ECHO "%~1"
IF "%~1"=="" GOTO BLANK
mpv.exe --script=360plugin.lua "%~1"
GOTO DONE
:BLANK
mpv.exe --script=360plugin.lua
:DONE
popd