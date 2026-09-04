@echo off
setlocal EnableDelayedExpansion

set "XAMPP_PHP_DIR=%xamppDirCur%\php"
REM ---- Build error message safely ----
set "msg=PHP executable not found in the specified directory: %XAMPP_PHP_DIR%"
set "msg=!msg! Try starting  a new web page from main menu, or you may try executing option"
set "msg=!msg! Check/shutdown ports needed by webserver and mysql in Utilities menu."
set "msg=!msg! This will clear all resources which may be causing the issue."

REM ---- Verify php.exe exists FIRST ----
if not exist "%XAMPP_PHP_DIR%\php.exe" (
    echo ERROR: !msg!
    goto :end
)

REM ---- Test execution ----
set PHPRC=
set PHP_INI_SCAN_DIR=
set "PATH=%XAMPP_PHP_DIR%;%SystemRoot%\system32;%SystemRoot%"

"%XAMPP_PHP_DIR%\php.exe" -n -d output_buffering=0 --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: !msg!
    goto :end
)

REM ---- Get PHP version ----
call :GetPhpVersion

REM ---- Get MYSQL version ----
call :GetSQLVersion


:end
endlocal & (
 set "xamppVersion=%xamppVersion%"
 set "sqlVersion=%sqlVersion%"
)

exit /b



:GetPhpVersion
set "xamppVersion=unavailable"

pushd "%XAMPP_PHP_DIR%"
REM Loop through each line of php.exe output
for /f "usebackq tokens=*" %%L in (`"%XAMPP_PHP_DIR%\php.exe" -v 2^>^&1`
) do (
    set "line=%%L"

    REM Remove leading spaces
    for /f "tokens=* delims= " %%S in ("!line!") do set "line=%%S"
    
    REM Check if line starts with PHP
    if /i "!line:~0,4!"=="PHP " (
	for /f "tokens=* delims=" %%A in ("!line!") do (
	    set "fullLine=%%A"

	    if "!fullLine:PHP Fatal=!" neq "!fullLine!" (
		echo !fullLine!
	    ) else if "!fullLine:PHP Warning:=!" neq "!fullLine!" (
		echo !fullLine!
	    ) else (
		for /f "tokens=2" %%V in ("!fullLine!") do (
		    set "xamppVersion=%%V"
		)
	    )
	)
    )
)
REM if XamppService = 1 Apache not started
if !XamppService! equ 1 ( 
	set sqlVersion="unavailable"
)
popd
goto :eof


:GetSQLVersion
set "sqlVersion=unavailable"
set "mysqlpath=!xamppDirCur!\mysql\bin\mysql.exe"

for /f "tokens=3" %%a in ('!mysqlpath! --version') do (
    set "sqlVersion=%%a
)
REM if XamppService = 2 MYsql not started
if !XamppService! equ 2 ( 
	set sqlVersion="unavailable"
    )

goto :eof