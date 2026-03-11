@echo off
setlocal enabledelayedexpansion

echo ============================================
echo   Pokemon: Synthesis - Mod Uninstaller
echo ============================================
echo.

:: Try to auto-detect game location by looking for our backup folder
set "GAME_DIR="

for %%P in (
    "%USERPROFILE%\Pokemon Infinite Fusion"
    "%USERPROFILE%\Desktop\Pokemon Infinite Fusion"
    "%USERPROFILE%\Downloads\Pokemon Infinite Fusion"
    "%APPDATA%\Pokemon Infinite Fusion"
    "C:\Games\Pokemon Infinite Fusion"
    "D:\Games\Pokemon Infinite Fusion"
) do (
    if exist "%%~P\Data\.synthesis_backup" (
        set "GAME_DIR=%%~P"
        goto :found
    )
)

echo Could not auto-detect your game install.
echo Please type the full path to your Pokemon Infinite Fusion folder:
echo.
set /p "GAME_DIR=Game folder: "
set "GAME_DIR=!GAME_DIR:"=!"

:found
set "BACKUP_DIR=!GAME_DIR!\Data\.synthesis_backup"

if not exist "!BACKUP_DIR!" (
    echo.
    echo No backup found at: !BACKUP_DIR!
    echo Either the mod was never installed, or backups were deleted.
    pause
    exit /b 1
)

echo Game found at: !GAME_DIR!
echo.

:: Restore backed-up files
set COUNT=0
for %%F in ("!BACKUP_DIR!\*.rxdata") do (
    set "FILENAME=%%~nxF"
    echo   Restoring: !FILENAME!
    copy /y "%%F" "!GAME_DIR!\Data\!FILENAME!" >nul
    set /a COUNT+=1
)

:: Clean up backup directory
rmdir /s /q "!BACKUP_DIR!"

echo.
echo ============================================
echo   Done! Restored !COUNT! original file(s).
echo   Backup folder removed.
echo   Your game is back to normal.
echo ============================================
echo.
pause
