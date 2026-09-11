@echo off
setlocal
pushd "%~dp0functions"
node scripts\map_admin.js %*
set EXIT_CODE=%ERRORLEVEL%
popd
exit /b %EXIT_CODE%
