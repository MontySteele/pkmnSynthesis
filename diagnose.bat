@echo off
REM diagnose.bat - Check if injection is working on Windows

setlocal enabledelayedexpansion

set "PROJECT_DIR=%~dp0"
set "GAME_DIR=%PROJECT_DIR%game_data"
set "DATA_DIR=%GAME_DIR%\Data"

echo ===============================================
echo   Pokemon: Synthesis - Diagnostics
echo ===============================================
echo.

echo [1] Checking paths...
echo     Project dir: %PROJECT_DIR%
echo     Game dir:    %GAME_DIR%
echo     Data dir:    %DATA_DIR%
echo.

echo [2] Checking game data...
if exist "%DATA_DIR%" (
    echo     [OK] Data directory exists
) else (
    echo     [FAIL] Data directory NOT FOUND
    pause
    exit /b 1
)

if exist "%DATA_DIR%\Map048.rxdata" (
    echo     [OK] Map048.rxdata exists (Player's Room)
) else (
    echo     [FAIL] Map048.rxdata NOT FOUND
)

if exist "%GAME_DIR%\Game.rgssad" (
    echo     [WARN] Game.rgssad still exists! This will override loose files.
) else if exist "%GAME_DIR%\Game.rgssad.bak" (
    echo     [OK] Game.rgssad renamed to .bak
) else (
    echo     [OK] No Game.rgssad found (good)
)
echo.

echo [3] Checking Ruby...
where ruby >nul 2>&1
if errorlevel 1 (
    echo     [FAIL] Ruby not found in PATH
    pause
    exit /b 1
)
for /f "tokens=*" %%v in ('ruby --version') do echo     [OK] %%v
echo.

echo [4] Checking dialogue files...
set "JSON_COUNT=0"
for %%f in ("%PROJECT_DIR%dialogue_changes\*.json") do set /a JSON_COUNT+=1
echo     Found !JSON_COUNT! JSON files in dialogue_changes\
if !JSON_COUNT!==0 (
    echo     [FAIL] No dialogue files found!
    pause
    exit /b 1
)
echo.

echo [5] Checking rpgmaker_stubs...
if exist "%PROJECT_DIR%tools\rpgmaker_stubs.rb" (
    echo     [OK] rpgmaker_stubs.rb exists
) else (
    echo     [FAIL] rpgmaker_stubs.rb NOT FOUND - injection will fail
    pause
    exit /b 1
)
echo.

echo [6] Test injection on pallet_town.json (Map 48 = Player's Room)...
echo     Running: ruby tools\inject_dialogue.rb "%DATA_DIR%" dialogue_changes\pallet_town.json
echo.
echo --- Ruby output start ---
ruby "%PROJECT_DIR%tools\inject_dialogue.rb" "%DATA_DIR%" "%PROJECT_DIR%dialogue_changes\pallet_town.json" 2>&1
set "RUBY_EXIT=%errorlevel%"
echo --- Ruby output end ---
echo.
echo     Ruby exit code: %RUBY_EXIT%
echo.

echo [7] Verifying injection wrote to disk...
ruby -e "data = Marshal.load(File.binread(ARGV[0])); ev = data.events[2]; cmd = ev.pages[0].list[0]; puts 'Map048 Event 2, Page 0, first text: ' + cmd.parameters[0].to_s" "%DATA_DIR%\Map048.rxdata" 2>&1
echo.
echo     If the line above says "Your old game console" then injection worked.
echo     If it says something else, injection did NOT modify the file.
echo.

pause
