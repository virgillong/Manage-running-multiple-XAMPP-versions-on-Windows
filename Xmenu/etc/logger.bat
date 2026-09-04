@echo off
setlocal enabledelayedexpansion

rem ---------------- DISPATCH ----------------
set "cmd=%~1"
shift

if /i "%cmd%"==":log_msg" goto log_msg
if /i "%cmd%"==":log_error" goto log_error
if /i "%cmd%"==":log_warn" goto log_warn
if /i "%cmd%"==":log_debug" goto log_debug

goto :eof


rem ---------------- LOG MSG ----------------
:log_msg
set "msg="
:log_msg_loop
if "%~1"=="" goto log_msg_done
set "msg=!msg! %~1"
shift
goto log_msg_loop

:log_msg_done
if %LOG_LEVEL% GEQ 2 echo !msg!
goto :eof


rem ---------------- ERROR ----------------
:log_error
set "msg="
:log_error_loop
if "%~1"=="" goto log_error_done
set "msg=!msg! %~1"
shift
goto log_error_loop

:log_error_done
if %LOG_LEVEL% GEQ 0 echo [ERROR]!msg!
goto :eof


rem ---------------- WARN ----------------
:log_warn
set "msg="
:log_warn_loop
if "%~1"=="" goto log_warn_done
set "msg=!msg! %~1"
shift
goto log_warn_loop

:log_warn_done
if %LOG_LEVEL% GEQ 1 echo [WARN]!msg!
goto :eof


rem ---------------- DEBUG ----------------
:log_debug
set "msg="
:log_debug_loop
if "%~1"=="" goto log_debug_done
set "msg=!msg! %~1"
shift
goto log_debug_loop

:log_debug_done
if %LOG_LEVEL% GEQ 3 echo [DEBUG]!msg!
goto :eof