@echo off
REM setup_windows.bat - Install Git and Ruby for Pokemon: Synthesis

setlocal enabledelayedexpansion

echo ===============================================
echo   Pokemon: Synthesis - Windows Setup
echo ===============================================
echo.
echo This will install Git and Ruby if they are missing.
echo You may see Windows permission prompts - click Yes.
echo.

set NEEDS_RESTART=0

REM ── Install Git if missing ──
where git >nul 2>&1
if errorlevel 1 (
    echo [INFO] Git not found. Installing...
    call :install_git
    if errorlevel 1 (
        echo [ERROR] Could not install Git automatically.
        echo         Please download and install from: https://git-scm.com/download/win
        echo         Then run play.bat again.
        pause
        exit /b 1
    )
    set NEEDS_RESTART=1
) else (
    echo [OK] Git is already installed.
)

REM ── Install Ruby if missing ──
where ruby >nul 2>&1
if errorlevel 1 (
    echo [INFO] Ruby not found. Installing...
    call :install_ruby
    if errorlevel 1 (
        echo [ERROR] Could not install Ruby automatically.
        echo         Please download and install from: https://rubyinstaller.org/
        echo         Choose "Ruby+Devkit" and use the default settings.
        echo         Then run play.bat again.
        pause
        exit /b 1
    )
    set NEEDS_RESTART=1
) else (
    echo [OK] Ruby is already installed.
)

echo.
if %NEEDS_RESTART%==1 (
    echo ===============================================
    echo   Setup complete!
    echo   IMPORTANT: Close this window and re-open
    echo   play.bat so it picks up the new programs.
    echo ===============================================
    pause
    exit /b 0
) else (
    echo [OK] All dependencies already installed.
    exit /b 0
)

REM ══════════════════════════════════════════════════════════════════════════════
REM  Installer subroutines
REM ══════════════════════════════════════════════════════════════════════════════

:install_git
REM Try winget first, then fall back to direct download
where winget >nul 2>&1
if not errorlevel 1 (
    echo [INFO] Installing Git via winget...
    winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements
    if not errorlevel 1 (
        echo [OK] Git installed via winget.
        exit /b 0
    )
    echo [WARN] winget install failed, trying direct download...
)

echo [INFO] Downloading Git installer...
set "GIT_INSTALLER=%TEMP%\git-installer.exe"
powershell -NoProfile -Command ^
    "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " ^
    "$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/git-for-windows/git/releases/latest'; " ^
    "$asset = $release.assets | Where-Object { $_.name -match 'Git-.*-64-bit\.exe$' } | Select-Object -First 1; " ^
    "if ($asset) { " ^
    "  Write-Host '[INFO] Downloading:' $asset.name; " ^
    "  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile '%GIT_INSTALLER%' -UseBasicParsing; " ^
    "  exit 0 " ^
    "} else { exit 1 }"
if errorlevel 1 (
    echo [ERROR] Failed to download Git installer.
    exit /b 1
)

echo [INFO] Running Git installer (silent)...
"%GIT_INSTALLER%" /VERYSILENT /NORESTART /NOCANCEL /SP-
if errorlevel 1 (
    echo [ERROR] Git installer returned an error.
    del /f "%GIT_INSTALLER%" 2>nul
    exit /b 1
)
del /f "%GIT_INSTALLER%" 2>nul
echo [OK] Git installed.
exit /b 0

:install_ruby
REM Try winget first, then fall back to direct download
where winget >nul 2>&1
if not errorlevel 1 (
    echo [INFO] Installing Ruby via winget...
    winget install --id RubyInstallerTeam.RubyWithDevKit.3.3 -e --silent --accept-package-agreements --accept-source-agreements
    if not errorlevel 1 (
        echo [OK] Ruby installed via winget.
        exit /b 0
    )
    echo [WARN] winget install failed, trying direct download...
)

echo [INFO] Downloading Ruby installer...
echo         (This file is ~150 MB, please be patient)
set "RUBY_INSTALLER=%TEMP%\ruby-installer.exe"
powershell -NoProfile -Command ^
    "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " ^
    "$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/oneclick/rubyinstaller2/releases/latest'; " ^
    "$asset = $release.assets | Where-Object { $_.name -match 'rubyinstaller-devkit-.*-x64\.exe$' } | Select-Object -First 1; " ^
    "if ($asset) { " ^
    "  Write-Host '[INFO] Downloading:' $asset.name; " ^
    "  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile '%RUBY_INSTALLER%' -UseBasicParsing; " ^
    "  exit 0 " ^
    "} else { exit 1 }"
if errorlevel 1 (
    echo [ERROR] Failed to download Ruby installer.
    exit /b 1
)

echo [INFO] Running Ruby installer (silent)...
"%RUBY_INSTALLER%" /VERYSILENT /NORESTART /NOCANCEL /SP- /TASKS="modpath,assocfiles"
if errorlevel 1 (
    echo [ERROR] Ruby installer returned an error.
    del /f "%RUBY_INSTALLER%" 2>nul
    exit /b 1
)
del /f "%RUBY_INSTALLER%" 2>nul
echo [OK] Ruby installed.
exit /b 0
