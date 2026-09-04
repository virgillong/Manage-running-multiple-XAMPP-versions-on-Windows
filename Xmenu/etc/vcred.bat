@echo off
setlocal enabledelayedexpansion
REM remove trailing backslash
echo %rootDir%

if "%rootDir:~-1%"=="\" (
    set "rootDir=%rootDir:~0,-1%"
)

if not defined rootDir (
    for %%I in ("%~dp0..") do set "rootDir=%%~fI\"
)

REM Call PowerShell script 
:again
powershell -ExecutionPolicy Bypass -File "%rootDir%\etc\includes\vcred.ps1" -RootDir "%rootDir%"
exit /b
