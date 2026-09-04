@echo off
setlocal enabledelayedexpansion

REM showLogs = false - allows script to be run as process (runHidden.ps1) and no output to terminal
REM	     = true  - - ran as normal with output to terminal
set "showLogs=true" 

REM set flag to indicate if menu should be displayed.  
REM      parameter = "" - startup normal display menu = true
REM	parameter = xmenu - executed from shortcut to this menu, display menu = true
REM	parameter = any other value - executed from shortcut and parameter is a menu choice, display menu = false
if "%~1"=="" (
    set "DisplayMenu=true"
) else (
    if /i "%~1"=="xmenu" (
	set "DisplayMenu=true"
    ) else (
	set "menuChoice=%~1"
	set "DisplayMenu=false"
    )
) 

REM set enviromental variables
:: get only the drive letter of the batch file
REM for %%A in ("%~dp0") do set "curDrv=%%~dA"

:: Get the directory that contains the script (no trailing slash)
set "scriptDir=%~dp0"
if "%scriptDir:~-1%"=="\" (
    set "scriptDir=%scriptDir:~0,-1%"
)

:: Get the parent directory
for %%A in ("%scriptDir%\..") do set "curDrv=%%~fA"
:: Remove trailing backslash
if "%curDrv:~-1%"=="\" set "curDrv=%curDrv:~0,-1%"

set "rootDir=%~dp0"
set "xamppDirCur="
set "xamppVersion="
set "sqlVersion="
set /a XamppService=0
set "message="
set "website="
REM timers
set startBrowser=15
set waitTimer=5



:Menu
REM :: if apache is running set variables indicating

for /f "tokens=1,2,3,4,* delims=|" %%A in ('
    powershell -ExecutionPolicy Bypass -File "%rootDir%\etc\chkEnabled.ps1"
') do (
    set exitCode=%%A
    set Status=%%B
    set Htdocs=%%C
    set xamppDirCur=%%D
    set xamppService=%%E
)

echo .
echo "*****************************"
echo "exitCode= !exitCode!"
echo "Status= !Status!"
echo "Htdocs= !Htdocs!"
echo "xamppDirCur= !xamppDirCur!"
echo "xamppService= !xamppService!"
echo "*****************************"

set "xamppVersion="
set "sqlVersion="

REM set php and mysql version
if defined xamppDirCur (
    REM xamppDirCur is set based upon status of Xampp control panel
    call "%rootDir%etc\getver.bat"

    set "runMeFirst=%rootDir%etc\runmefirst.bat"
    if exist "!runMeFirst!" (
	call "!runMeFirst!"
	echo "Word Press version: !wp_version!"
    )
)

REM check for messages to display 
if not "!message!"=="" (
    echo.
    echo.
    echo !message!
    set "message="
    timeout /t %waitTimer% /nobreak > NUL
)

REM if menu choice has not been determined then display
REM menu.

if /I "!DisplayMenu!"=="true" (
    REM Display GUI Main Menu Items
    set "menuChoice=0"
    echo.
    echo Make selection from the pop up menu ....
    echo.
    for /f "delims=" %%A in ('
	powershell -NoProfile -ExecutionPolicy Bypass -File "%rootDir%etc\menu.ps1"
    ') do (
	set "menuChoice=%%A"
    )
)

if "%menuChoice%"=="0" goto END
if "%menuChoice%"=="x" goto Menu
if "%MenuChoice%"=="u" goto UTILMENU

REM if display menu is true, get menu choice
REM and run menu.bat as a process.

if "!showLogs!"=="false" (
    if /I "!DisplayMenu!"=="true" (
	powershell -ExecutionPolicy Bypass -File "%rootDir%\etc\runHidden.ps1"  -MenuID %MenuChoice%
	goto MenuNext
    )
)

REM RUN AS PROCESS ..... 
REM !DisplayMenu!"=="false" runs when menu.bat called 
REM with menuid parameter ... processesthe parameters associated 
REM with ID.

:: ===== REM Get button configuration from file / Check for administered items =====
set "filePath=%rootDir%data\buttons.txt"
if exist %filePath% (
    set "columnList=label id url dir custom"
    :: ===== Main Line Loop =====
    for /f "usebackq delims=" %%L in ("!filePath!") do (
	set "line=%%L"
	call :ClearFields "!columnList!"
	call :ParseLine "!line!" "!columnList!"
	if "!id!"=="!menuChoice!" goto :runWebsite
    )
)

echo "Invalid Selection: %MenuChoice%"
pause
goto MenuNext


:runWebsite

if defined dir (
    REM if dir contains {DRIVE} then replace with current drive
    set "origDir=!dir!"
    set "dir=!dir:{DRIVE}=%curDrv%!"
    
    REM if !dir! was changed set flag to internal to indicate 
    REM this xampp is within XMENU file structure

    if "!origDir!" NEQ "!dir!" (
	set "xamppInstall=internal"
    ) else (
	set "xamppInstall=external"
    )
)

if defined custom (
    set "custom=!custom:{DRIVE}=%curDrv%!"
)
echo ----------------------------------------
echo Menu Item:        !label!
echo URL:              !url!
echo Xampp Directory:  !dir!
echo Run Program:	!custom!
echo ----------------------------------------

if defined custom (
    if exist "!custom!" (
	rem Get file extension
	set "ext=%%~xA"

	for %%A in ("!custom!") do set "ext=%%~xA"

	if /I "!ext!"==".bat" (
	    call "!custom!"
	) else if /I "!ext!"==".ps1" (
	    powershell -ExecutionPolicy Bypass -File "!custom!"

	) else (
	    set "message=ERROR: Unsupported file type !custom!"
	    powershell -ExecutionPolicy Bypass -File "%rootDir%etc\alert.ps1" -Message "!message!"
	    goto MenuNext
	)

    ) else (
	set "message=ERROR: !custom! does not exist .... edit menu item within <Utility Menu> and check administered path"
	powershell -ExecutionPolicy Bypass -File "%rootDir%etc\alert.ps1" -Message "!message!"
	goto MenuNext
    )
)

if defined dir (
    set "xamppDir=!dir!"

    REM "%rootDir%etc\startXampp.bat"
    REM powershell -ExecutionPolicy Bypass -File "%rootDir%\etc\runHidden.ps1"  -xamppDir !dir!
    
    powershell -ExecutionPolicy Bypass -File "%rootDir%\etc\startxampp.ps1" -xamppDir "!xamppDir!" -xamppInstall "!xamppInstall!"
    REM exitCode = 0 - Successful operation
    REM          = 1 -  Errors while trying to stop current Xampp
    REM          = 2 - at least one service did not start
    REM          = 3 - control panel did not start, no services available
    
    set "exitCode=!errorlevel!"

    if "!exitCode!"=="3" (
        set "xamppDirCur="
	set "xamppVersion="
	set "sqlVersion="
	goto MenuNext
    ) else (
	if "!exitCode!"=="2" (
	    set "message= ERROR: At least one of the services did not start"
	    powershell -ExecutionPolicy Bypass -File "%rootDir%etc\alert.ps1" -Message "!message!"
	    goto MenuNext
	) else (
	    set "xamppDirCur=!xamppDir!"
	)
    )   
) 
if defined url (
    set "webSite=!url!"
    call :STARTWS  
)

:MenuNext
REM DisplayMenu indicates ran as process .... end the session
if /I "!DisplayMenu!"=="false" (
    goto END
)
goto MENU


REM ************UTILMENU**************************
:UTILMENU
set menuChoice=0
REM !psCommand!
REM pause
REM goto UTILMENU
for /f "tokens=1,2,3,4,* delims=|" %%A in ('
    powershell -ExecutionPolicy Bypass -File "%rootDir%\etc\chkEnabled.ps1"
') do (
    set exitCode=%%A
    set Status=%%B
    set Htdocs=%%C
    set xamppDirCur=%%D
    set xamppService=%%E
)


set "xamppVersion="
set "sqlVersion="

REM set php and mysql version
if defined xamppDirCur (
    REM xamppDirCur is set based upon status of Xampp control panel
    call "%rootDir%etc\getver.bat"

    set "runMeFirst=%rootDir%etc\runmefirst.bat"
    if exist "!runMeFirst!" (
	call "!runMeFirst!"
	echo "Word Press version: !wp_version!"
    )
)


for /f "delims=" %%A in ('
    powershell -NoProfile -ExecutionPolicy Bypass -File "%rootDir%etc\util.ps1"
') do (
    set "menuChoice=%%A"
)

if "%MenuChoice%"=="0" (
    if /I "!DisplayMenu!"=="false" (
	goto end
    )
    goto MENU
)
if "%MenuChoice%"=="D" (
    set "DisplayMenu=true"
    goto MENU
)
REM read file containing menu items
set "filePath=%rootDir%data\buttons-util.txt"
if exist %filePath% (
    :: ===== Input Setup =====
    set "columnList=label id path1 url"
    :: ===== Main Line Loop =====
    for /f "usebackq delims=" %%L in ("!filePath!") do (
	set "line=%%L"
	call :ClearFields "!columnList!"
	call :ParseLine "!line!" "!columnList!"
	if "!id!"=="!menuChoice!" goto :runBatch
    )
)

echo "Invalid Selection: %MenuChoice%"
pause
goto UTILMENU

:runBatch


if defined path1 (
    set "path1=!path1:{DRIVE}=%curDrv%!"
)

echo menuChoice: !menuChoice!
echo Label:      !label!
echo ID:         !id!
echo PATH1:      !path1!
echo URL:        !path2!
echo ------------------------

set "exitCode=0"

REM if defined path1 (
REM    call "!path1!"
REM )
if defined path1 (

    set "SCRIPT=!path1!"
    REM set "EXT=%~x1"

    rem Or get extension directly from path1:
    for %%F in ("!SCRIPT!") do set "EXT=%%~xF"

    if /I "!EXT!"==".bat" (
	call "!SCRIPT!
	goto CKPATH2
    )
     if /I "!EXT!"==".exe" (
	call "!SCRIPT!
	goto CKPATH2
    )

    if /I "!EXT!"==".cmd" (
	call "!SCRIPT!"
	goto CKPATH2
    )

    if /I "!EXT!"==".ps1" (
	powershell -NoProfile -ExecutionPolicy Bypass -STA -File "!SCRIPT!"
	goto CKPATH2
    )

    echo Unsupported file type: %EXT%
    goto UTILMENU

)

:CKPATH2

if "!exitCode!"=="0" (
    if defined url (
        set "website=!url!"
        echo !website! | findstr /i "^http[s]*://" >nul
        if errorlevel 1 (
            set "website=http://!website!"
        )
        start "" "!webSite!"
        set "message=!webSite! started"
    )
)

goto UTILMENU


REM **************************************
:EXIT
REM terminate xampp control process 
call "%rootDir%etc\stopXampp.bat"

REM Check to see if elastic search is active
set URL=http://localhost:9200
REM Use curl to check the status
curl -s -o NUL -w "%%{http_code}" %URL% > http_status.txt
set /p HTTP_CODE=<http_status.txt
if "%HTTP_CODE%"=="200" (
    echo.
    echo Elasticsearch is active and will not be closed automatically.
    echo You may choose to close the command window associated with elasticsearch.
    timeout /t 15 /nobreak > NUL
)
del http_status.txt

:END
endlocal
exit 


:: ************************** SUBROUTINES *************************************

:: ===== Subroutine: STARTWS =====
:: Start Website
:STARTWS
setlocal
echo.
echo Browser starting .... %webSite%
echo.

REM get site name from url
for /f "tokens=2 delims=/" %%A in ("!URL!") do set siteName=%%A
set sitePath=!Htdocs!\!siteName!
set /a count=0
set "archiveFile="
set "archiveDate="
for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%rootDir%etc\getDupArchive.ps1" -sitePath "!sitePath!"`
) do (
    set /a count+=1
    if !count! equ 1 (
	set "archiveFile=%%A"
    ) else if !count! equ 2 (
	set "archiveDate=%%A"
    )
)
echo.
if "!archiveFile!" NEQ "NOT_FOUND" (
    echo !archiveFile!
    echo !archiveDate!
)
    

:: Check if the website starts with http:// or https://
echo %website% | findstr /i "^http[s]*://" >nul
if errorlevel 1 (
    set "website=http://%website%"
)

start "" "%webSite%"
set "message=SUCCESS: The default web browser will open a new window ... %webSite%"
endlocal & (
    set "message=%message%"
)
exit /b



:: ===== Subroutine: Clear Fields =====
:ClearFields
:: Clear all fieldN variables

for /f "tokens=1 delims==" %%V in ('set field 2^>nul') do set "%%V="

goto :eof



: ===== Subroutine: Parse Line =====
:ParseLine
:: Assume delayed expansion already enabled in main script
set "line=%~1"
set "columnLine=%~2"

:: Split fields by "|"
set i=0
REM echo Parsing line: !line!
for %%A in ("!line:|=" "!") do (
    set /a i+=1
    set "field!i!=%%~A"
REM    echo field!i!=%%~A
)

REM echo -------------------------------

:: Assign fields to named variables
set i=0
for %%V in (!columnLine!) do (
    set /a i+=1
    call set "value=%%field!i!%%"
    call set "%%V=%%value%%"
REM    echo Assigning: %%V=!%%V!%
)
goto :eof



