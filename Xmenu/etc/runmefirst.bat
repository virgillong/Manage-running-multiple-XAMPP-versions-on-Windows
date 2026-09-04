@echo off

REM set version information for modules used 
REM set WP version
set "wpversion="
set "file=%xamppDirCur%\htdocs\postalsupply\wp-includes\version.php"
if exist %file% (
    for /f "tokens=3 delims=' " %%a in ('findstr /i "$wp_version" %file%') do set "wp_version=%%a"
    set "wpversion=%wp_version%"
)

exit /b