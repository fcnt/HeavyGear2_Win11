@echo off
setlocal EnableExtensions
set "PSModulePath=%SystemRoot%\System32\WindowsPowerShell\v1.0\Modules"
set "__COMPAT_LAYER=RunAsInvoker"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Launch-Win11.ps1"
set "HG2_EXIT=%ERRORLEVEL%"
if not "%HG2_EXIT%"=="0" pause
exit /b %HG2_EXIT%
