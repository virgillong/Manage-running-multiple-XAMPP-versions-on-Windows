@echo off
setlocal enabledelayedexpansion

REM set %rootDir% to the parent folder
if not defined rootDir (
    for %%I in ("%~dp0..") do set "rootDir=%%~fI\"
)

REM if "%1"=="" (
REM    echo "No ID parameter passed"
REM    goto EXIT
REM )

set "MenuID=%1"
start "" /min "%rootDir%menu.bat" %MenuID%
REM start "" "%rootDir%menu.bat" %MenuID%


:EXIT
endlocal
exit 