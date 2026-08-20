@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0hard_deploy.ps1" %*
exit /b %ERRORLEVEL%
