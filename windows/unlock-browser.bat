@echo off
setlocal EnableDelayedExpansion
title In'Seine - unlock the browser

net session >nul 2>&1
if %errorLevel% neq 0 (
  echo.
  echo   This needs to run as Administrator.
  echo   Right-click unlock-browser.bat and choose "Run as administrator".
  echo.
  pause
  exit /b 1
)

echo.
echo   IN'SEINE - UNLOCK THE BROWSER
echo   =============================
echo.

for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\InSeine" /v Salt 2^>nul ^| findstr Salt') do set SALT=%%B
for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\InSeine" /v Hash 2^>nul ^| findstr Hash') do set WANT=%%B

if "!SALT!"=="" (
  echo   No PIN on file - removing any policy found anyway.
  goto :remove
)

set /p PIN="   Removal PIN: "
for /f "delims=" %%A in ('powershell -NoProfile -Command "$b=[Text.Encoding]::UTF8.GetBytes('!SALT!'+'!PIN!'); (($([Security.Cryptography.SHA256]::Create().ComputeHash($b)) ^| ForEach-Object { $_.ToString('x2') }) -join '')"') do set GOT=%%A

if /i not "!GOT!"=="!WANT!" (
  echo.
  echo   Wrong PIN.
  timeout /t 3 >nul
  exit /b 1
)
echo   PIN accepted.

:remove
echo.
echo   Removing policy...

reg delete "HKLM\SOFTWARE\Policies\Google\Chrome\URLBlocklist" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Google\Chrome\ExtensionSettings" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Google\Chrome" /v IncognitoModeAvailability /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Google\Chrome" /v ForceGoogleSafeSearch /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Google\Chrome" /v ForceYouTubeRestrict /f >nul 2>&1

reg delete "HKLM\SOFTWARE\Policies\Microsoft\Edge\URLBlocklist" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Edge\ExtensionSettings" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v InPrivateModeAvailability /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v ForceGoogleSafeSearch /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v ForceBingSafeSearch /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v ForceYouTubeRestrict /f >nul 2>&1

reg delete "HKLM\SOFTWARE\Policies\Mozilla\Firefox" /v DisablePrivateBrowsing /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Mozilla\Firefox" /v BlockAboutAddons /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Mozilla\Firefox" /v BlockAboutConfig /f >nul 2>&1

:: Added alongside the Firefox extension lock in lock-browser.bat. Without this
:: the lock script would set it and nothing would ever take it away.
reg delete "HKLM\SOFTWARE\Policies\Mozilla\Firefox" /v ExtensionSettings /f >nul 2>&1

reg delete "HKLM\SOFTWARE\InSeine" /f >nul 2>&1

echo.
echo   Unlocked. Close ALL browsers completely and reopen them.
echo.
pause
