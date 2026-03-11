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
    echo     [OK] Map048.rxdata exists
) else (
    echo     [FAIL] Map048.rxdata NOT FOUND
)

if exist "%GAME_DIR%\Game.rgssad" (
    echo     [WARN] Game.rgssad still exists!
) else (
    echo     [OK] No Game.rgssad
)
echo.

echo [3] Checking Ruby...
ruby --version 2>&1
echo.

echo [4] Checking dialogue files...
set "JSON_COUNT=0"
for %%f in ("%PROJECT_DIR%dialogue_changes\*.json") do set /a JSON_COUNT+=1
echo     Found !JSON_COUNT! JSON files
echo.

echo [5] Injecting pallet_town.json...
echo.
ruby "%PROJECT_DIR%tools\inject_dialogue.rb" "%DATA_DIR%" "%PROJECT_DIR%dialogue_changes\pallet_town.json" 2>&1
echo.

echo [6] Verifying file was actually modified on disk...
echo.
ruby -r "%PROJECT_DIR%tools\rpgmaker_stubs" -e "map = Marshal.load(File.binread(ARGV[0])); puts '--- Map048 Event Dump ---'; map.events.each do |id, ev|; next unless ev; ev.pages.each_with_index do |pg, pi|; pg.list.each_with_index do |cmd, ci|; if cmd.code == 101 || cmd.code == 401 || (cmd.code == 355 and cmd.parameters[0].to_s.include?('Message')); puts \"  Event #{id} Page #{pi} Cmd[#{ci}] code=#{cmd.code}: #{cmd.parameters[0].to_s[0..80]}\"; end; end; end; end" "%DATA_DIR%\Map048.rxdata" 2>&1
echo.

echo [7] What does the ORIGINAL backup look like?
echo.
if exist "%GAME_DIR%\.originals\Map048.rxdata" (
    ruby -r "%PROJECT_DIR%tools\rpgmaker_stubs" -e "map = Marshal.load(File.binread(ARGV[0])); puts '--- ORIGINAL Map048 Event Dump ---'; map.events.each do |id, ev|; next unless ev; ev.pages.each_with_index do |pg, pi|; pg.list.each_with_index do |cmd, ci|; if cmd.code == 101 || cmd.code == 401 || (cmd.code == 355 and cmd.parameters[0].to_s.include?('Message')); puts \"  Event #{id} Page #{pi} Cmd[#{ci}] code=#{cmd.code}: #{cmd.parameters[0].to_s[0..80]}\"; end; end; end; end" "%GAME_DIR%\.originals\Map048.rxdata" 2>&1
) else (
    echo     No backup found at %GAME_DIR%\.originals\Map048.rxdata
)
echo.

echo [8] Listing all files Game.exe might read from...
echo.
echo     Game.exe location:
if exist "%GAME_DIR%\Game.exe" (echo     [OK] %GAME_DIR%\Game.exe) else (echo     [MISSING])
echo.
echo     Archive files:
if exist "%GAME_DIR%\Game.rgssad" (echo     [FOUND] Game.rgssad) else (echo     [none] Game.rgssad)
if exist "%GAME_DIR%\Game.rgssad.bak" (echo     [FOUND] Game.rgssad.bak) else (echo     [none] Game.rgssad.bak)
if exist "%GAME_DIR%\Game.rgss2a" (echo     [FOUND] Game.rgss2a) else (echo     [none] Game.rgss2a)
if exist "%GAME_DIR%\Game.rgss3a" (echo     [FOUND] Game.rgss3a) else (echo     [none] Game.rgss3a)
echo.
echo     Game.ini contents:
if exist "%GAME_DIR%\Game.ini" (
    type "%GAME_DIR%\Game.ini"
) else (
    echo     [MISSING] Game.ini
)
echo.
echo     mkxp.json:
if exist "%GAME_DIR%\mkxp.json" (echo     [FOUND]) else (echo     [none])
echo.

pause
