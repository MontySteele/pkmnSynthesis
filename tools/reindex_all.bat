@echo off
REM reindex_all.bat - Fix dialogue indices against actual game data
REM Run this once after cloning game data to fix all JSON files.

setlocal enabledelayedexpansion

set "PROJECT_DIR=%~dp0.."
set "DATA_DIR=%PROJECT_DIR%\game_data\Data"
set "CHANGES_DIR=%PROJECT_DIR%\dialogue_changes"

echo ===============================================
echo   Pokemon: Synthesis - Reindex Dialogue
echo ===============================================
echo.

if not exist "%DATA_DIR%" (
    echo [ERROR] Game data not found at %DATA_DIR%
    echo         Run play.bat first to clone the game data.
    pause
    exit /b 1
)

echo [INFO] Phase 1: Preview changes (dry run)...
echo.

set "TOTAL_FILES=0"
for %%f in ("%CHANGES_DIR%\*.json") do (
    ruby "%PROJECT_DIR%\tools\reindex_dialogue.rb" "%DATA_DIR%" "%%f"
    set /a TOTAL_FILES+=1
)

echo.
echo ===============================================
echo   Previewed !TOTAL_FILES! files.
echo   Press any key to apply fixes, or Ctrl+C to cancel.
echo ===============================================
pause

echo.
echo [INFO] Phase 2: Applying fixes...
echo.

for %%f in ("%CHANGES_DIR%\*.json") do (
    echo [INFO] Reindexing: %%~nxf
    ruby "%PROJECT_DIR%\tools\reindex_dialogue.rb" "%DATA_DIR%" "%%f" --write
)

echo.
echo [OK] All dialogue files reindexed.
echo     Now run play.bat to inject and launch.
pause
