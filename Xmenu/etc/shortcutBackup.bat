@echo off
setlocal enabledelayedexpansion

REM set %rootDir% to the parent folder
if not defined rootDir (
    for %%I in ("%~dp0..") do set "rootDir=%%~fI\"
)

:: Get the directory that contains the script (no trailing slash)
set "scriptDir=%~dp0"
if "%scriptDir:~-1%"=="\" (
    set "scriptDir=%scriptDir:~0,-1%"
)

:: Get the parent directory
for %%A in ("%scriptDir%\..") do set "curDrv=%%~fA"

:: Remove trailing backslash
if "%curDrv:~-1%"=="\" set "curDrv=%curDrv:~0,-1%"

set "xamppDirCur="

REM check to see if apache is active 
call "%rootDir%etc\chkEnabled"
if /i "!Status!"=="Running" (
    REM set php version
    if defined xamppDirCur (
	set "XAMPP_PHP_DIR=%xamppDirCur%\php"
	call "%rootDir%etc\getver.bat"
    )
) else (
    powershell -ExecutionPolicy Bypass -File "%rootDir%etc\alert.ps1" -Message "Cannot locate an active web server"
    goto exit
)
call "%rootDir%etc\WordPressBackup.bat"
:EXIT
 timeout /t 15 /nobreak > NUL
endlocal
exit