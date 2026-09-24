@echo off
rem ==============================================================================
rem MP_Mix_Manager_v0.3 - Windows 10 & 11 Native Launcher
rem Launches Mix_Archive_Manager.sh using Git Bash, MSYS2, or WSL
rem ==============================================================================
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

rem 1. Check for Git for Windows (bash.exe) in standard install directories
if exist "%ProgramFiles%\Git\bin\bash.exe" (
    "%ProgramFiles%\Git\bin\bash.exe" "%SCRIPT_DIR%Mix_Archive_Manager.sh" %*
    goto :eof
)
if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" (
    "%ProgramFiles(x86)%\Git\bin\bash.exe" "%SCRIPT_DIR%Mix_Archive_Manager.sh" %*
    goto :eof
)
if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" (
    "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" "%SCRIPT_DIR%Mix_Archive_Manager.sh" %*
    goto :eof
)

rem 2. Check for bash on system PATH (Git Bash, MSYS2, Cygwin)
where bash.exe >nul 2>nul
if %ERRORLEVEL% equ 0 (
    bash.exe "%SCRIPT_DIR%Mix_Archive_Manager.sh" %*
    goto :eof
)

rem 3. Check for MSYS2 default paths
if exist "C:\msys64\usr\bin\bash.exe" (
    "C:\msys64\usr\bin\bash.exe" -l "%SCRIPT_DIR%Mix_Archive_Manager.sh" %*
    goto :eof
)

rem 4. Check for WSL (Windows Subsystem for Linux)
where wsl.exe >nul 2>nul
if %ERRORLEVEL% equ 0 (
    for /f "delims=" %%i in ('wsl.exe wslpath "%SCRIPT_DIR%"') do set "WSL_DIR=%%i"
    wsl.exe bash -c "cd '!WSL_DIR!' && ./Mix_Archive_Manager.sh"
    goto :eof
)

echo ==============================================================================
echo [ERROR] No compatible Bash environment found!
echo.
echo Mix Archive Manager requires a Bash shell on Windows 10 or 11.
echo Please install one of the following:
echo   - Git for Windows: https://git-scm.com/download/win (Recommended)
echo   - MSYS2:           https://www.msys2.org
echo   - WSL2:            Run 'wsl --install' in PowerShell
echo ==============================================================================
pause
