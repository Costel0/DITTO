@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0easy_deploy.ps1" %*
exit /b %ERRORLEVEL%
