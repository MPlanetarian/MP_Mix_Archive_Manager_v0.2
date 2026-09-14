@echo off
rem ==============================================================================
rem Traktor Pro Live Monitor & Recorder - Windows 10 & 11 Direct Launcher
rem Runs scripts\traktor_monitor.py directly via Python
rem ==============================================================================
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

rem 1. Check for python.exe on PATH
where python.exe >nul 2>nul
if %ERRORLEVEL% equ 0 (
    python.exe "%SCRIPT_DIR%scripts\traktor_monitor.py" %*
    goto :eof
)

rem 2. Check for py.exe (Python Launcher for Windows)
where py.exe >nul 2>nul
if %ERRORLEVEL% equ 0 (
    py.exe -3 "%SCRIPT_DIR%scripts\traktor_monitor.py" %*
    goto :eof
)

rem 3. Check for standard LocalAppData and ProgramFiles Python locations
for %%P in (
    "%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
    "%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
    "%LOCALAPPDATA%\Programs\Python\Python310\python.exe"
    "%ProgramFiles%\Python312\python.exe"
    "%ProgramFiles%\Python311\python.exe"
    "%ProgramFiles%\Python310\python.exe"
    "C:\Python312\python.exe"
    "C:\Python311\python.exe"
    "C:\Python310\python.exe"
) do (
    if exist "%%~P" (
        "%%~P" "%SCRIPT_DIR%scripts\traktor_monitor.py" %*
        goto :eof
    )
)

echo ==============================================================================
echo [ERROR] Python 3 was not found on this Windows system!
echo.
echo Please install Python 3 from the Microsoft Store or https://www.python.org/
echo Make sure to check "Add python.exe to PATH" during setup.
echo ==============================================================================
pause
