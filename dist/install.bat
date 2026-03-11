@echo off
setlocal enabledelayedexpansion

echo ============================================
echo   Pokemon: Synthesis - Mod Installer
echo ============================================
echo.

:: Check if we're being run from the dist folder
if not exist "%~dp0Data" (
    echo ERROR: Can't find the Data folder next to this script.
    echo Make sure install.bat is in the same folder as the Data\ directory.
    pause
    exit /b 1
)

:: Try to auto-detect game location
set "GAME_DIR="

:: Check common install locations
for %%P in (
    "%USERPROFILE%\Pokemon Infinite Fusion"
    "%USERPROFILE%\Desktop\Pokemon Infinite Fusion"
    "%USERPROFILE%\Downloads\Pokemon Infinite Fusion"
    "%APPDATA%\Pokemon Infinite Fusion"
    "C:\Games\Pokemon Infinite Fusion"
    "D:\Games\Pokemon Infinite Fusion"
) do (
    if exist "%%~P\Game.exe" (
        set "GAME_DIR=%%~P"
        goto :found
    )
    if exist "%%~P\Game.ini" (
        set "GAME_DIR=%%~P"
        goto :found
    )
)

:: Not found - ask the user
echo Could not auto-detect your Pokemon Infinite Fusion install.
echo.
echo Please drag your game folder onto this window and press Enter,
echo or type the full path to your Pokemon Infinite Fusion folder:
echo.
set /p "GAME_DIR=Game folder: "

:: Strip surrounding quotes if present
set "GAME_DIR=!GAME_DIR:"=!"

:found
:: Validate
if not exist "!GAME_DIR!\Data" (
    echo.
    echo ERROR: "!GAME_DIR!\Data" does not exist.
    echo Make sure you pointed to the right folder ^(the one with Game.exe^).
    pause
    exit /b 1
)

echo.
echo Game found at: !GAME_DIR!
echo.

:: Create backup directory
set "BACKUP_DIR=!GAME_DIR!\Data\.synthesis_backup"
if not exist "!BACKUP_DIR!" mkdir "!BACKUP_DIR!"

:: Install patched files
set COUNT=0
for %%F in ("%~dp0Data\*.rxdata") do (
    set "FILENAME=%%~nxF"

    :: Back up original if not already backed up
    if not exist "!BACKUP_DIR!\!FILENAME!" (
        if exist "!GAME_DIR!\Data\!FILENAME!" (
            echo   Backing up: !FILENAME!
            copy /y "!GAME_DIR!\Data\!FILENAME!" "!BACKUP_DIR!\!FILENAME!" >nul
        )
    )

    :: Copy patched file
    echo   Installing: !FILENAME!
    copy /y "%%F" "!GAME_DIR!\Data\!FILENAME!" >nul
    set /a COUNT+=1
)

echo.
echo ============================================
echo   Done! Installed !COUNT! patched file(s).
echo   Originals backed up to Data\.synthesis_backup\
echo.
echo   Launch Game.exe to play!
echo ============================================
echo.
pause
