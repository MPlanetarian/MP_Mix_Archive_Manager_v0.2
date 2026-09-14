<#
.SYNOPSIS
    Traktor Pro Live Monitor & Audio Recorder - Windows 10 & 11 PowerShell Launcher
.DESCRIPTION
    Launches scripts\traktor_monitor.py directly with Python 3 on Windows.
#>
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ScriptDir
$PyScript = Join-Path $ScriptDir "scripts\traktor_monitor.py"

if (Get-Command python.exe -ErrorAction SilentlyContinue) {
    & python.exe $PyScript @args
} elseif (Get-Command py.exe -ErrorAction SilentlyContinue) {
    & py.exe -3 $PyScript @args
} else {
    $PythonCandidates = @(
        "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python310\python.exe",
        "$env:ProgramFiles\Python312\python.exe",
        "$env:ProgramFiles\Python311\python.exe",
        "C:\Python312\python.exe",
        "C:\Python311\python.exe"
    )
    $FoundPy = $null
    foreach ($P in $PythonCandidates) {
        if (Test-Path $P) {
            $FoundPy = $P
            break
        }
    }
    if ($FoundPy) {
        & $FoundPy $PyScript @args
    } else {
        Write-Host "==============================================================================" -ForegroundColor Red
        Write-Host "[ERROR] Python 3 was not found in PATH or standard installation paths!" -ForegroundColor Red
        Write-Host "Please install Python 3 from https://www.python.org/ or the Microsoft Store." -ForegroundColor Yellow
        Write-Host "==============================================================================" -ForegroundColor Red
        Read-Host "Press [Enter] to exit..."
    }
}
