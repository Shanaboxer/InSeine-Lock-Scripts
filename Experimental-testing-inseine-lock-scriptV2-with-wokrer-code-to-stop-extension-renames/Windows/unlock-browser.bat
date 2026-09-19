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

:: The other Chromium forks, added alongside them in lock-browser.bat. Without
:: this the lock would set them and nothing would ever take them away.
for %%B in ("HKLM\SOFTWARE\Policies\BraveSoftware\Brave" ^
            "HKLM\SOFTWARE\Policies\Chromium" ^
            "HKLM\SOFTWARE\Policies\Vivaldi" ^
            "HKLM\SOFTWARE\Policies\Opera Software") do (
  reg delete "%%~B\ExtensionSettings" /f >nul 2>&1
  reg delete "%%~B" /v ForceGoogleSafeSearch /f >nul 2>&1
  reg delete "%%~B" /v IncognitoModeAvailability /f >nul 2>&1
  reg delete "%%~B" /v ForceYouTubeRestrict /f >nul 2>&1
)

reg delete "HKLM\SOFTWARE\Policies\Mozilla\Firefox" /v DisablePrivateBrowsing /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Mozilla\Firefox" /v BlockAboutAddons /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Mozilla\Firefox" /v BlockAboutConfig /f >nul 2>&1

:: Added alongside the Firefox extension lock in lock-browser.bat. Without this
:: the lock script would set it and nothing would ever take it away.
reg delete "HKLM\SOFTWARE\Policies\Mozilla\Firefox" /v ExtensionSettings /f >nul 2>&1

:: ---------------------------------------------------------------------------
:: Remove protection worker (if it was installed)
:: ---------------------------------------------------------------------------
echo   Removing protection worker (if present)...

schtasks /End /TN "InSeineWorker" >nul 2>&1
schtasks /Delete /TN "InSeineWorker" /F >nul 2>&1

if exist "C:\ProgramData\InSeine\Worker.ps1" (
  del /f /q "C:\ProgramData\InSeine\Worker.ps1" >nul 2>&1
)
if exist "C:\ProgramData\InSeine" (
  rmdir /s /q "C:\ProgramData\InSeine" >nul 2>&1
)

reg delete "HKLM\SOFTWARE\InSeine" /f >nul 2>&1

echo.
echo   Unlocked. Close ALL browsers completely and reopen them.
echo.
echo   The extensions page works again, and you can remove the In'Seine
echo   extension from there in the normal way.
echo.
echo   If a protection worker was installed, it has been stopped and removed.
echo.
pause
