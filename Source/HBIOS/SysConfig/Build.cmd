@echo off
setlocal

set TOOLS=../../Tools
set PATH=%TOOLS%\tasm32;%PATH%
set TASMTABS=%TOOLS%\tasm32

tasm -t80 -g3 -fFF sysconfig.asm sysconfig.com sysconfig.lst || exit /b

copy /Y sysconfig.com ..\..\Binary\Apps\ || exit /b
