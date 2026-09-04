@echo off
setlocal EnableDelayedExpansion

set "foundPort="
for /f "tokens=4,5" %%a in ('netstat -aon ^| findstr /R ":3306" ^| findstr LISTENING') do set foundPort=1
if not defined foundPort (
    REM did not find active ports that are listening... 
    set exitCode=1
)

 set "XAMPP_SQL_DIR=%xamppDirCur%\mysql\bin\mysql"
for /f "tokens=3" %%i in ('!XAMPP_SQL_DIR! --version') do set MYSQL_VERSION=%%i
echo !MYSQL_VERSION!
pause

:end
endlocal & set "xamppVersion=%xamppVersion%"
exit /b

