@echo off
setlocal EnableDelayedExpansion
title In'Seine - lock the browser

net session >nul 2>&1
if %errorLevel% neq 0 (
  echo.
  echo   This needs to run as Administrator.
  echo   Right-click lock-browser.bat and choose "Run as administrator".
  echo.
  pause
  exit /b 1
)

echo.
echo   IN'SEINE - LOCK THE BROWSER
echo   ===========================
echo.
echo   This writes browser policy that:
echo.
echo     * Installs In'Seine into EVERY account on this computer
echo     * Stops In'Seine being removed - and only In'Seine. Your other
echo       extensions carry on working and stay manageable.
echo     * Forces Google SafeSearch on, browser-wide
echo     * Disables private browsing, which otherwise bypasses everything
echo     * Blocks about:config in Firefox
echo.
echo   IMPORTANT: this protects against a child using the computer. It does
echo   NOT protect against anyone with the administrator password. If your
echo   child's account has admin rights, give them a standard account -
echo   that is the single most effective thing you can do.
echo.
echo   You need In'Seine's Chrome Web Store extension ID. It's at the end of
echo   the store listing address. 32 letters, a to p.
echo.

set /p EXTID="   Extension ID: "
for /f "delims=" %%A in ('powershell -NoProfile -Command "'!EXTID!'.Trim().ToLower()"') do set EXTID=%%A

echo !EXTID!| findstr /r "^[a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p]$" >nul
if errorlevel 1 (
  echo.
  echo   That doesn't look like a Chrome extension ID.
  echo   Expected 32 letters in the range a-p, for example:
  echo       nmmhkkegccagdldgiimedpiccmgmieda
  echo.
  pause
  exit /b 1
)

echo.
set /p PIN="   Set a removal PIN (4 digits): "
echo !PIN!| findstr /r "^[0-9][0-9][0-9][0-9]$" >nul
if errorlevel 1 (
  echo   Needs to be exactly 4 digits.
  pause
  exit /b 1
)

echo.
echo   Filter YouTube? Restricted Mode also disables YouTube comments.
echo   For children this is usually worth it.
set /p YT="   Turn on YouTube filtering? (Y/n): "

echo.
set /p CONFIRM="   Continue? (y/n): "
if /i not "%CONFIRM%"=="y" (
  echo   Cancelled. Nothing was changed.
  pause
  exit /b 0
)

set CHROME=HKLM\SOFTWARE\Policies\Google\Chrome
set EDGE=HKLM\SOFTWARE\Policies\Microsoft\Edge
set FIREFOX=HKLM\SOFTWARE\Policies\Mozilla\Firefox

:: Salted hash of the removal PIN, under a key only admins can read.
for /f "delims=" %%A in ('powershell -NoProfile -Command "-join ((1..16) ^| ForEach-Object {'{0:x2}' -f (Get-Random -Max 256)})"') do set SALT=%%A
for /f "delims=" %%A in ('powershell -NoProfile -Command "$b=[Text.Encoding]::UTF8.GetBytes('!SALT!'+'!PIN!'); (([Security.Cryptography.SHA256]::Create().ComputeHash($b) ^| ForEach-Object { $_.ToString('x2') }) -join '')"') do set HASH=%%A

reg add "HKLM\SOFTWARE\InSeine" /v Salt /t REG_SZ /d "!SALT!" /f >nul
reg add "HKLM\SOFTWARE\InSeine" /v Hash /t REG_SZ /d "!HASH!" /f >nul

echo.
echo   Writing policy...

:: Lock In'Seine only, and install it into every account.
reg add "%CHROME%\ExtensionSettings\!EXTID!" /v installation_mode /t REG_SZ /d "force_installed" /f >nul
reg add "%CHROME%\ExtensionSettings\!EXTID!" /v update_url /t REG_SZ /d "https://clients2.google.com/service/update2/crx" /f >nul
reg add "%CHROME%\ExtensionSettings\!EXTID!" /v incognito_mode /t REG_SZ /d "enabled" /f >nul
reg add "%CHROME%\ExtensionSettings\!EXTID!" /v toolbar_pin /t REG_SZ /d "force_pinned" /f >nul

reg add "%EDGE%\ExtensionSettings\!EXTID!" /v installation_mode /t REG_SZ /d "force_installed" /f >nul
reg add "%EDGE%\ExtensionSettings\!EXTID!" /v update_url /t REG_SZ /d "https://clients2.google.com/service/update2/crx" /f >nul

:: Browser-level settings, below the extension
reg add "%CHROME%" /v ForceGoogleSafeSearch /t REG_DWORD /d 1 /f >nul
reg add "%CHROME%" /v IncognitoModeAvailability /t REG_DWORD /d 1 /f >nul
reg add "%EDGE%" /v ForceGoogleSafeSearch /t REG_DWORD /d 1 /f >nul
reg add "%EDGE%" /v ForceBingSafeSearch /t REG_DWORD /d 2 /f >nul
reg add "%EDGE%" /v InPrivateModeAvailability /t REG_DWORD /d 1 /f >nul

reg add "%FIREFOX%" /v DisablePrivateBrowsing /t REG_DWORD /d 1 /f >nul
reg add "%FIREFOX%" /v BlockAboutConfig /t REG_DWORD /d 1 /f >nul

if /i not "%YT%"=="n" (
  reg add "%CHROME%" /v ForceYouTubeRestrict /t REG_DWORD /d 2 /f >nul
  reg add "%EDGE%" /v ForceYouTubeRestrict /t REG_DWORD /d 2 /f >nul
  echo   YouTube filtering on - comments will be unavailable.
)

echo.
echo   Done. Close ALL browsers completely and reopen them.
echo.
echo   Check it worked:
echo     chrome://policy       the entries should be listed
echo     chrome://extensions   In'Seine's Remove should be greyed out,
echo                           other extensions unaffected
echo     Right-click the In'Seine icon - Remove should be unavailable
echo.
echo   IN EVERY OTHER ACCOUNT ON THIS COMPUTER, In'Seine installs itself the
echo   next time Chrome starts. Sign into your child's account, open Chrome,
echo   and go through In'Seine's setup there to choose their filters and PIN.
echo.
echo   To undo: run unlock-browser.bat as administrator with your PIN.
echo.
pause
