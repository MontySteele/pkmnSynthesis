@echo off
REM play.bat — Windows launcher for Pokemon: Synthesis
REM Prerequisites: Git for Windows, Ruby (https://rubyinstaller.org/)

setlocal enabledelayedexpansion

set "PROJECT_DIR=%~dp0"
set "GAME_DIR=%PROJECT_DIR%game_data"
set "DATA_DIR=%GAME_DIR%\Data"
set "CHANGES_DIR=%PROJECT_DIR%dialogue_changes"

echo ===============================================
echo   Pokemon: Synthesis — Windows Launcher
echo ===============================================
echo.

REM ── Check prerequisites ──
where git >nul 2>&1 || (
    echo [ERROR] Git is not installed. Download from https://git-scm.com/download/win
    pause
    exit /b 1
)

where ruby >nul 2>&1 || (
    echo [ERROR] Ruby is not installed. Download from https://rubyinstaller.org/
    echo         Choose "Ruby+Devkit" and run the default install.
    pause
    exit /b 1
)

REM ── Clone game data if needed ──
if exist "%DATA_DIR%" (
    echo [OK] Game data already present.
) else (
    echo [INFO] Cloning Pokemon Infinite Fusion game data...
    echo        This is a large download and may take a while.
    git clone --depth 1 https://github.com/infinitefusion/infinitefusion-e18 "%GAME_DIR%"
    if errorlevel 1 (
        echo [ERROR] Failed to clone game data.
        pause
        exit /b 1
    )
    echo [OK] Game data cloned.
)

REM ── Back up originals on first run ──
if not exist "%GAME_DIR%\.originals" (
    echo [INFO] Backing up original game files...
    mkdir "%GAME_DIR%\.originals"
    REM Back up all map files and trainers.dat
    for %%f in ("%DATA_DIR%\Map*.rxdata") do (
        if not exist "%GAME_DIR%\.originals\%%~nxf" copy "%%f" "%GAME_DIR%\.originals\%%~nxf" >nul
    )
    if exist "%DATA_DIR%\trainers.dat" (
        if not exist "%GAME_DIR%\.originals\trainers.dat" copy "%DATA_DIR%\trainers.dat" "%GAME_DIR%\.originals\trainers.dat" >nul
    )
    echo [OK] Originals backed up.
)

REM ── Restore originals before injection ──
echo [INFO] Restoring original files before injection...
for %%f in ("%GAME_DIR%\.originals\*.rxdata") do copy "%%f" "%DATA_DIR%\%%~nxf" >nul
if exist "%GAME_DIR%\.originals\trainers.dat" copy "%GAME_DIR%\.originals\trainers.dat" "%DATA_DIR%\trainers.dat" >nul

REM ── Add Synthesis trainer entries ──
if exist "%PROJECT_DIR%tools\add_trainer.rb" (
    echo [INFO] Adding Synthesis trainer entries...
    ruby "%PROJECT_DIR%tools\add_trainer.rb" "%GAME_DIR%"
)

REM ── Inject dialogue ──
echo [INFO] Injecting Synthesis dialogue...
for %%f in ("%CHANGES_DIR%\*.json") do (
    echo [INFO] Injecting: %%~nxf
    ruby "%PROJECT_DIR%tools\inject_dialogue.rb" "%DATA_DIR%" "%%f"
    if errorlevel 1 (
        echo [ERROR] Injection failed for %%~nxf
        pause
        exit /b 1
    )
)
echo [OK] Dialogue injection complete.

REM ── Launch ──
if exist "%GAME_DIR%\Game.exe" (
    echo.
    echo [INFO] Launching Pokemon: Synthesis...
    cd /d "%GAME_DIR%"
    start "" "Game.exe"
) else (
    echo [ERROR] Game.exe not found in %GAME_DIR%.
    pause
    exit /b 1
)
