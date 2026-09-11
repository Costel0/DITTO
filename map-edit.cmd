@echo off
setlocal
pushd "%~dp0functions"
node scripts\map_edit.js %*
set EXIT_CODE=%ERRORLEVEL%
popd
exit /b %EXIT_CODE%
