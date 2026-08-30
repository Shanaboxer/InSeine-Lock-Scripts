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
echo   ALWAYS APPLIED, to every browser found on this computer, in every
echo   account, because browser policy is set machine-wide:
echo.
echo     * Private browsing disabled. Without this, a private window
echo       bypasses everything In'Seine does.
echo     * Google SafeSearch forced on in Chrome and Edge
echo     * about:config blocked in Firefox
echo     * A removal PIN, so none of it can be undone without it
echo.
echo   OPTIONALLY, if you have the store details to hand:
echo.
echo     * In'Seine installed automatically into every account, and made
echo       impossible to remove - and only In'Seine, your other extensions
echo       carry on working and stay manageable.
echo.
echo   That last one needs the extension to be published, because the browser
echo   installs it FROM the store. You'll be asked next, and you can skip
echo   either or both. Skipping loses only that item.
echo.
echo   IMPORTANT: this protects against a child using the computer. It does
echo   NOT protect against anyone with the administrator password. If your
echo   child's account has admin rights, give them a standard account -
echo   that is the single most effective thing you can do.
echo.
echo   You need In'Seine's Chrome Web Store extension ID. It's at the end of
echo   the store listing address. 32 letters, a to p.
echo.
echo   Not using Chrome, or In'Seine isn't on the store yet? Press Enter to
echo   skip. Everything else still applies - private browsing off, SafeSearch
echo   forced, Firefox extension locked - but Chrome and Edge will not
echo   auto-install In'Seine or stop it being removed.
echo.

set "EXTID="
set /p EXTID="   Extension ID (or Enter to skip): "

:: Deliberately allowed to be empty. force_installed tells Chrome to DOWNLOAD
:: the extension from the Web Store, so it cannot work for an unlisted or
:: developer-loaded copy whatever ID is given - the ID Chrome shows for an
:: unpacked extension is a hash of its folder path and changes if the folder is
:: renamed. Refusing to run just meant nobody could apply the rest.
if defined EXTID (
  for /f "delims=" %%A in ('powershell -NoProfile -Command "'!EXTID!'.Trim().ToLower()"') do set EXTID=%%A
  echo !EXTID!| findstr /r "^[a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p][a-p]$" >nul
  if errorlevel 1 (
    echo.
    echo   That doesn't look like a Chrome extension ID.
    echo   Expected 32 letters in the range a-p, for example:
    echo       nmmhkkegccagdldgiimedpiccmgmieda
    echo.
    echo   Leave it blank to skip the Chrome extension lock entirely.
    echo.
    pause
    exit /b 1
  )
) else (
  echo.
  echo   Skipped. In'Seine can still be removed in Chrome and Edge.
)

echo.
echo   FIREFOX
echo   -------
echo   To install and lock In'Seine there, paste its add-on download URL.
echo   From the addons.mozilla.org listing it looks like:
echo       https://addons.mozilla.org/firefox/downloads/latest/inseine/latest.xpi
echo.
echo   Press Enter to skip. Private browsing and about:config are still
echo   blocked; In'Seine just won't install itself or resist removal there.
echo.

set "FFURL="
set /p FFURL="   Firefox add-on URL (or Enter to skip): "

if not defined FFURL (
  echo.
  echo   Skipped. In'Seine can still be removed in Firefox.
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
if defined EXTID (
  reg add "%CHROME%\ExtensionSettings\!EXTID!" /v installation_mode /t REG_SZ /d "force_installed" /f >nul
  reg add "%CHROME%\ExtensionSettings\!EXTID!" /v update_url /t REG_SZ /d "https://clients2.google.com/service/update2/crx" /f >nul
  reg add "%CHROME%\ExtensionSettings\!EXTID!" /v incognito_mode /t REG_SZ /d "enabled" /f >nul
  reg add "%CHROME%\ExtensionSettings\!EXTID!" /v toolbar_pin /t REG_SZ /d "force_pinned" /f >nul

  reg add "%EDGE%\ExtensionSettings\!EXTID!" /v installation_mode /t REG_SZ /d "force_installed" /f >nul
  reg add "%EDGE%\ExtensionSettings\!EXTID!" /v update_url /t REG_SZ /d "https://clients2.google.com/service/update2/crx" /f >nul
)

:: Browser-level settings, below the extension
reg add "%CHROME%" /v ForceGoogleSafeSearch /t REG_DWORD /d 1 /f >nul
reg add "%CHROME%" /v IncognitoModeAvailability /t REG_DWORD /d 1 /f >nul
reg add "%EDGE%" /v ForceGoogleSafeSearch /t REG_DWORD /d 1 /f >nul
reg add "%EDGE%" /v ForceBingSafeSearch /t REG_DWORD /d 2 /f >nul
reg add "%EDGE%" /v InPrivateModeAvailability /t REG_DWORD /d 1 /f >nul

reg add "%FIREFOX%" /v DisablePrivateBrowsing /t REG_DWORD /d 1 /f >nul
reg add "%FIREFOX%" /v BlockAboutConfig /t REG_DWORD /d 1 /f >nul

:: Firefox takes ExtensionSettings as a single JSON string, not as nested keys
:: the way Chrome does.
::
:: force_installed is the only Firefox mode that prevents removal, and it needs
:: install_url because Firefox fetches the add-on itself rather than protecting
:: a copy already present. An earlier version wrote "installation_mode":
:: "locked", which is not a Firefox value at all - Firefox ignored the entry and
:: the lock this script claimed to apply had never once worked.
if defined FFURL (
  reg add "%FIREFOX%" /v ExtensionSettings /t REG_SZ /d "{\"inseine@inseine.co.uk\":{\"installation_mode\":\"force_installed\",\"install_url\":\"!FFURL!\"}}" /f >nul
)

if /i not "%YT%"=="n" (
  reg add "%CHROME%" /v ForceYouTubeRestrict /t REG_DWORD /d 2 /f >nul
  reg add "%EDGE%" /v ForceYouTubeRestrict /t REG_DWORD /d 2 /f >nul
  echo   YouTube filtering on - comments will be unavailable.
)

echo.
echo   Done. Close ALL browsers completely and reopen them.
echo.
echo   APPLIED EVERYWHERE, in every account on this computer:
echo     * Private browsing disabled
echo     * Google SafeSearch forced on in Chrome and Edge
echo     * about:config blocked in Firefox
echo.
if defined EXTID (
  echo   CHROME / EDGE: In'Seine installs itself into every account and
  echo   cannot be removed or disabled.
) else (
  echo   CHROME / EDGE: NOT installed or locked - you skipped the extension ID.
  echo   In'Seine can still be removed there.
)
echo.
if defined FFURL (
  echo   FIREFOX: In'Seine installs itself and cannot be removed.
) else (
  echo   FIREFOX: NOT installed or locked - you skipped the add-on URL.
  echo   In'Seine can still be removed there.
)
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
