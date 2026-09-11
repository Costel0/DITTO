@echo off
setlocal
pushd "%~dp0functions"
if /I "%~1"=="set-sector" goto MAP_EDIT
if /I "%~1"=="set-zone" goto MAP_EDIT
node scripts\map_admin.js %*
goto DONE
:MAP_EDIT
node scripts\map_edit.js %*
:DONE
set EXIT_CODE=%ERRORLEVEL%
popd
exit /b %EXIT_CODE%
