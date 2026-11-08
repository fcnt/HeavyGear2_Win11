@echo off
setlocal
set "PSModulePath=%SystemRoot%\System32\WindowsPowerShell\v1.0\Modules"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Install-Win11.ps1" -FromDisc -Interactive %*
set "HG2_INSTALL_EXIT=%ERRORLEVEL%"
pause
exit /b %HG2_INSTALL_EXIT%
