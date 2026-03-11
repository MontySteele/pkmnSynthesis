@echo off
REM smoke_test.bat - Minimal test: modify one string, launch game, verify
setlocal

set "PROJECT_DIR=%~dp0"
set "GAME_DIR=%PROJECT_DIR%game_data"
set "DATA_DIR=%GAME_DIR%\Data"
set "MAP_FILE=%DATA_DIR%\Map048.rxdata"

echo ===============================================
echo   Smoke Test - Does Game.exe read our files?
echo ===============================================
echo.

echo [1] Reading current text in Map048 Event 2 (console)...
ruby -r "%PROJECT_DIR%tools\rpgmaker_stubs" -e "map = Marshal.load(File.binread(ARGV[0])); puts '    Current: ' + map.events[2].pages[0].list[0].parameters[0].to_s" "%MAP_FILE%"
echo.

echo [2] Writing test string: SYNTHESIS SMOKE TEST
ruby -r "%PROJECT_DIR%tools\rpgmaker_stubs" -e "map = Marshal.load(File.binread(ARGV[0])); map.events[2].pages[0].list[0].parameters[0] = 'SYNTHESIS SMOKE TEST'; File.binwrite(ARGV[0], Marshal.dump(map))" "%MAP_FILE%"
echo.

echo [3] Verifying write...
ruby -r "%PROJECT_DIR%tools\rpgmaker_stubs" -e "map = Marshal.load(File.binread(ARGV[0])); puts '    After write: ' + map.events[2].pages[0].list[0].parameters[0].to_s" "%MAP_FILE%"
echo.

echo [4] Recording file size and timestamp...
for %%A in ("%MAP_FILE%") do echo     Size: %%~zA bytes, Modified: %%~tA
echo.

echo ===============================================
echo   Now launching Game.exe.
echo   Start a NEW GAME and check the game console
echo   in your room. It should say:
echo       SYNTHESIS SMOKE TEST
echo   If it says "It's a PS5" then Game.exe does
echo   NOT read from Data\Map048.rxdata.
echo.
echo   CLOSE THE GAME when done, then press a key.
echo ===============================================
pause

cd /d "%GAME_DIR%"
Game.exe
echo.

echo [5] Game closed. Checking if file was modified by the game...
for %%A in ("%MAP_FILE%") do echo     Size: %%~zA bytes, Modified: %%~tA
ruby -r "%PROJECT_DIR%tools\rpgmaker_stubs" -e "map = Marshal.load(File.binread(ARGV[0])); puts '    Text now: ' + map.events[2].pages[0].list[0].parameters[0].to_s" "%MAP_FILE%"
echo.

echo If the text reverted to vanilla, the game overwrites our files.
echo If the text is still SYNTHESIS SMOKE TEST, the game ignores Data\.
echo.
pause
