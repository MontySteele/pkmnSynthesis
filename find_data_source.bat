@echo off
REM find_data_source.bat - Figure out where Game.exe actually reads map data from
setlocal enabledelayedexpansion

set "PROJECT_DIR=%~dp0"
set "GAME_DIR=%PROJECT_DIR%game_data"
set "DATA_DIR=%GAME_DIR%\Data"

echo ===============================================
echo   Finding where Game.exe reads its data
echo ===============================================
echo.

echo [1] Top-level files in game_data\ (non-directories):
echo.
for %%f in ("%GAME_DIR%\*.*") do (
    for %%A in ("%%f") do echo     %%~nxA  (%%~zA bytes)
)
echo.

echo [2] Any .rgssad, .rgss, .dat, .bin, .pak, .arc files anywhere:
echo.
for /r "%GAME_DIR%" %%f in (*.rgssad *.rgss2a *.rgss3a *.rgss *.dat *.bin *.pak *.arc *.encrypted) do (
    echo     %%~f  (%%~zf bytes)
)
echo.

echo [3] Large files in game_data\ (over 1MB):
echo.
for /r "%GAME_DIR%" %%f in (*) do (
    if %%~zf GTR 1048576 (
        echo     %%~f  (%%~zf bytes)
    )
)
echo.

echo [4] Searching Scripts.rxdata for custom load_data...
echo.
ruby -r "%PROJECT_DIR%tools\rpgmaker_stubs" -e ^
"scripts = Marshal.load(File.binread(ARGV[0])); " ^
"scripts.each_with_index do |entry, i|; " ^
"  next unless entry.is_a?(Array) and entry.length >= 3; " ^
"  name = entry[1].to_s; " ^
"  begin; code = Zlib::Inflate.inflate(entry[2]); rescue; next; end; " ^
"  if code.include?('load_data') || code.include?('Map') && code.include?('rxdata'); " ^
"    puts \"  Script #{i}: #{name}\"; " ^
"    code.each_line.with_index do |line, li|; " ^
"      if line.include?('load_data') || (line.include?('Map') && line.include?('rxdata')); " ^
"        puts \"    L#{li+1}: #{line.strip[0..120]}\"; " ^
"      end; " ^
"    end; " ^
"  end; " ^
"end" "%DATA_DIR%\Scripts.rxdata" 2>&1
echo.

echo [5] Checking if there is a game data folder OUTSIDE game_data...
echo.
if exist "%APPDATA%\infinitefusion" (
    echo     [FOUND] %APPDATA%\infinitefusion
    dir /b "%APPDATA%\infinitefusion" 2>nul
)
if exist "%LOCALAPPDATA%\infinitefusion" (
    echo     [FOUND] %LOCALAPPDATA%\infinitefusion
    dir /b "%LOCALAPPDATA%\infinitefusion" 2>nul
)
if exist "%APPDATA%\Pokemon Infinite Fusion" (
    echo     [FOUND] %APPDATA%\Pokemon Infinite Fusion
)
if exist "%LOCALAPPDATA%\Pokemon Infinite Fusion" (
    echo     [FOUND] %LOCALAPPDATA%\Pokemon Infinite Fusion
)
echo.

pause
