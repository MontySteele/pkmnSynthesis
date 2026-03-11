@echo off
REM play.bat - Windows launcher for Pokemon: Synthesis
REM Automatically installs Git and Ruby if missing

setlocal enabledelayedexpansion

set "PROJECT_DIR=%~dp0"
set "GAME_DIR=%PROJECT_DIR%game_data"
set "DATA_DIR=%GAME_DIR%\Data"
set "CHANGES_DIR=%PROJECT_DIR%dialogue_changes"

echo ===============================================
echo   Pokemon: Synthesis - Windows Launcher
echo ===============================================
echo.

REM -- Check prerequisites, auto-install if missing --
set "MISSING=0"
where git >nul 2>&1 || set "MISSING=1"
where ruby >nul 2>&1 || set "MISSING=1"

if "!MISSING!"=="1" (
    echo [INFO] Missing dependencies detected. Running setup...
    echo.
    call "%PROJECT_DIR%setup_windows.bat"
    if errorlevel 1 (
        echo [ERROR] Setup failed. See messages above.
        pause
        exit /b 1
    )
    REM Re-check after setup - need a new shell for PATH changes
    where git >nul 2>&1 || (
        echo.
        echo [INFO] Please close this window and double-click play.bat again.
        echo        Git/Ruby were just installed and need a fresh terminal to work.
        pause
        exit /b 0
    )
    where ruby >nul 2>&1 || (
        echo.
        echo [INFO] Please close this window and double-click play.bat again.
        echo        Git/Ruby were just installed and need a fresh terminal to work.
        pause
        exit /b 0
    )
)

REM -- Clone game data if needed --
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

REM -- Remove encrypted archive so game reads loose files --
REM RPG Maker XP packages data into Game.rgssad. If this file exists,
REM Game.exe reads from it instead of the Data/ folder, which means
REM our injected .rxdata files get ignored. Renaming it forces the
REM game to fall back to the loose files.
if exist "%GAME_DIR%\Game.rgssad" (
    echo [INFO] Found Game.rgssad - renaming so game reads loose Data files...
    rename "%GAME_DIR%\Game.rgssad" "Game.rgssad.bak"
    echo [OK] Renamed to Game.rgssad.bak
)
if exist "%GAME_DIR%\Game.rgss2a" (
    echo [INFO] Found Game.rgss2a - renaming...
    rename "%GAME_DIR%\Game.rgss2a" "Game.rgss2a.bak"
)
if exist "%GAME_DIR%\Game.rgss3a" (
    echo [INFO] Found Game.rgss3a - renaming...
    rename "%GAME_DIR%\Game.rgss3a" "Game.rgss3a.bak"
)

REM -- Back up originals on first run --
if not exist "%GAME_DIR%\.originals" (
    echo [INFO] Backing up original game files...
    mkdir "%GAME_DIR%\.originals"
    for %%f in ("%DATA_DIR%\Map*.rxdata") do (
        if not exist "%GAME_DIR%\.originals\%%~nxf" copy "%%f" "%GAME_DIR%\.originals\%%~nxf" >nul
    )
    if exist "%DATA_DIR%\trainers.dat" (
        if not exist "%GAME_DIR%\.originals\trainers.dat" copy "%DATA_DIR%\trainers.dat" "%GAME_DIR%\.originals\trainers.dat" >nul
    )
    echo [OK] Originals backed up.
)

REM -- Restore originals before injection --
echo [INFO] Restoring original files before injection...
for %%f in ("%GAME_DIR%\.originals\*.rxdata") do copy "%%f" "%DATA_DIR%\%%~nxf" >nul
if exist "%GAME_DIR%\.originals\trainers.dat" copy "%GAME_DIR%\.originals\trainers.dat" "%DATA_DIR%\trainers.dat" >nul

REM -- Add Synthesis trainer entries --
if exist "%PROJECT_DIR%tools\add_trainer.rb" (
    echo [INFO] Adding Synthesis trainer entries...
    ruby "%PROJECT_DIR%tools\add_trainer.rb" "%GAME_DIR%"
)

REM -- Inject dialogue --
echo [INFO] Injecting Synthesis dialogue...
set "INJECT_COUNT=0"
for %%f in ("%CHANGES_DIR%\*.json") do (
    echo [INFO] Injecting: %%~nxf
    ruby "%PROJECT_DIR%tools\inject_dialogue.rb" "%DATA_DIR%" "%%f"
    if errorlevel 1 (
        echo [ERROR] Injection failed for %%~nxf
        echo.
        echo If you see Ruby errors above, try running this manually:
        echo   ruby "%PROJECT_DIR%tools\inject_dialogue.rb" "%DATA_DIR%" "%%f"
        pause
        exit /b 1
    )
    set /a INJECT_COUNT+=1
)

if !INJECT_COUNT!==0 (
    echo [WARN] No dialogue files found in %CHANGES_DIR%
    echo        Something may be wrong with your checkout.
    pause
    exit /b 1
)
echo [OK] Dialogue injection complete - processed !INJECT_COUNT! files.

REM -- Launch --
if exist "%GAME_DIR%\Game.exe" (
    echo.
    echo [INFO] Launching Pokemon: Synthesis...
    echo        If the game shows vanilla dialogue, please report it.
    echo.
    pause
    cd /d "%GAME_DIR%"
    start "" "Game.exe"
) else (
    echo [ERROR] Game.exe not found in %GAME_DIR%.
    pause
    exit /b 1
)
