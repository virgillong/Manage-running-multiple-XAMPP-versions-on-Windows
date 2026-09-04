
@echo off
setlocal enabledelayedexpansion
if not defined rootDir (
    for %%I in ("%~dp0..") do set "rootDir=%%~fI\"
)

:: Set USB as source with no trailing "\"
if "%rootDir:~-1%"=="\" (
    set "usbSource=%rootDir:~0,-1%"
) else (
    set "usbSource=%rootDir%"
)

:: Prompt user to select a destination folder and if desktop shortcut
:: input.ps1 returns two lines line 1: destination and 2: checkbox 
set inputMsg=Input folder to be used for xmenu installation:
set Title=Install xmenu
REM set "showCheckbox=false"
REM set "Checkboxtxt=Add Shortcut to Desktop"
set count=0

 set "selectedPath="
:again
REM powershell -STA -nologo -noprofile -ExecutionPolicy Bypass -file "%rootDir%etc\includes\input.ps1" -inputMsg "!inputMsg!" -title "!Title!" -showCheckbox "!showCheckbox!" -Checkboxtxt "!Checkboxtxt!"
REM pause
REM goto again

for /f "delims=" %%A in (
    'powershell -STA -nologo -noprofile -ExecutionPolicy Bypass -file "%rootDir%etc\input.ps1" -inputMsg "!inputMsg!" -title "!Title!" -showCheckbox "!showCheckbox!" -Checkboxtxt "!Checkboxtxt!"'
) do (
    set /a count+=1
    if !count! equ 1 (
        set "selectedPath=%%A"
    ) else if !count! equ 2 (
        set "checkboxValue=%%A"
    ) else if !count! equ 3 (
        set "shortcutName=%%A"
    )
)
if !count! equ 0 (
    goto END
)

set destFolder=!selectedPath!

if defined destFolder (
    REM trim ending backslash if found
    if "%destFolder:~-1%"=="\" (
        set "destFolder=%destFolder:~0,-1%"
    ) 
    if not exist "!destFolder!\*" (
        echo Destination folder does not exist. Creating...
        mkdir "!destFolder!" >nul 2>&1
    )
    echo.
    echo.
    echo Copying files from "!usbSource!" to "!destFolder!"... please wait
    set "exclude1=!usbSource!\Southern Woodcraft Magento Files"
    set "exclude2=!usbSource!\SanDisk Software"
	
    REM /E: Copy all subdirectories, including empty ones.
    REM /COPY:DAT: Copy data, attributes, and timestamps.
    REM /R:2 /W:2: Retry twice with a 2-second wait on failed copies.
    REM /XD: Exclude specified directories.
    REM /XO: Exclude older files — only copy files if they’re newer than what’s in the destination.
    REM /NFL: No file list (suppresses file names in the output).
    REM /NDL: No directory list (suppresses directory names in the output).
    
    
    robocopy "!usbSource!" "!destFolder!" /E /COPY:DAT /R:2 /W:2 ^
	/XD "!exclude1!" "!exclude2!" ^
	/XO /NFL /NDL

    if %ERRORLEVEL% GEQ 8 (
        echo Failure: install encountered errors errorlevel: %ERRORLEVEL%
        set exitCode=1
        goto END
    ) 
    echo Files copied successfully.
    set exitCode=0
    set "message=SUCCESS: The files have been installed to %destFolder%"
    REM add shortcut to desktop if user requested


    if /i "!checkboxValue!" =="true" (
        call "%rootDir%etc\installShortcut.bat" "!destFolder!" "!shortcutName!"
    )

) else (
    echo User canceled or input was empty.
    set message 
    set exitCode=1
    set "message=INFO: Action canceled by user"  
    goto END
)
:END
endlocal & (
    set "message=%message%"
    set "exitCode=%exitCode%"
)
exit /b 

