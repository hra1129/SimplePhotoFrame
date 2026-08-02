@echo off
setlocal

set SCRIPT_DIR=%~dp0
pushd "%SCRIPT_DIR%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%run.ps1" %*
set VSIM_ERROR=%ERRORLEVEL%
if not "%VSIM_ERROR%"=="0" goto :error_vsim

popd
endlocal
goto :eof

:error_vsim
echo vsim failed with errorlevel %VSIM_ERROR%.
popd
endlocal
exit /b %VSIM_ERROR%

:error
echo compile failed.
popd
endlocal
exit /b 1
