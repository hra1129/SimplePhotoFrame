@echo off
setlocal

set SCRIPT_DIR=%~dp0
pushd "%SCRIPT_DIR%"

if exist work rmdir /s /q work

vlib work
if not "%ERRORLEVEL%"=="0" goto :error

vlog -sv ..\graphic_processor1.v tb.sv
if not "%ERRORLEVEL%"=="0" goto :error

vsim -c -t 1ps -voptargs=+acc tb -do "do wave.do; run -all; quit -f"
set VSIM_ERROR=%ERRORLEVEL%

if exist transcript move /Y transcript log.txt >nul

popd
endlocal & exit /b %VSIM_ERROR%

:error
echo simulation flow failed.
popd
endlocal
exit /b 1
