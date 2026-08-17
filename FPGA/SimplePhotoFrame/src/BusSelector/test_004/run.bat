@echo off
setlocal

set SCRIPT_DIR=%~dp0
pushd "%SCRIPT_DIR%"

if exist work rmdir /s /q work

vlib work
if not "%ERRORLEVEL%"=="0" goto :error

vlog +timescale+1ns/1ps ..\test_002\MT48LC2M32B2.v
if not "%ERRORLEVEL%"=="0" goto :error

vlog ..\..\SdramController\ip_sdram_tangnano20k.v
if not "%ERRORLEVEL%"=="0" goto :error

vlog -sv ..\bus_selector.v tb.sv
if not "%ERRORLEVEL%"=="0" goto :error

vsim -c -t 1ps tb -do "run -all; quit -f"
if not "%ERRORLEVEL%"=="0" goto :error

if exist transcript move /Y transcript log.txt >nul

popd
exit /b 0

:error
popd
exit /b 1
