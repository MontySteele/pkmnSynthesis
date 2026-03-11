@echo off
REM setup_windows.bat — Install Git and Ruby for Pokemon: Synthesis
REM Requires Windows 10 1709+ (winget is built into Windows 11)

setlocal

echo ===============================================
echo   Pokemon: Synthesis — Windows Setup
echo ===============================================
echo.
echo This will install Git and Ruby if they're missing.
echo You may see Windows permission prompts — click Yes.
echo.

REM ── Check for winget ──
where winget >nul 2>&1
if errorlevel 1 (
    echo [ERROR] winget is not available on this system.
    echo.
    echo Please install manually:
    echo   Git:  https://git-scm.com/download/win
    echo   Ruby: https://rubyinstaller.org/
    echo.
    echo Then run play.bat again.
    pause
    exit /b 1
)

set NEEDS_RESTART=0

REM ── Install Git if missing ──
where git >nul 2>&1
if errorlevel 1 (
    echo [INFO] Installing Git for Windows...
    winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        echo [ERROR] Git installation failed. Try installing manually:
        echo         https://git-scm.com/download/win
        pause
        exit /b 1
    )
    echo [OK] Git installed.
    set NEEDS_RESTART=1
) else (
    echo [OK] Git is already installed.
)

REM ── Install Ruby if missing ──
where ruby >nul 2>&1
if errorlevel 1 (
    echo [INFO] Installing Ruby with DevKit...
    winget install --id RubyInstallerTeam.RubyWithDevKit.3.3 -e --silent --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        echo [WARN] Ruby 3.3 failed, trying Ruby 3.2...
        winget install --id RubyInstallerTeam.RubyWithDevKit.3.2 -e --silent --accept-package-agreements --accept-source-agreements
        if errorlevel 1 (
            echo [ERROR] Ruby installation failed. Try installing manually:
            echo         https://rubyinstaller.org/
            pause
            exit /b 1
        )
    )
    echo [OK] Ruby installed.
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
    echo [OK] All dependencies already installed. You're good to go!
    exit /b 0
)
