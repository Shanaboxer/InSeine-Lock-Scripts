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
echo     * In'Seine installed automatically into every account, and made
echo       impossible to remove - and only In'Seine, your other extensions
echo       carry on working and stay manageable. This covers Chrome, Edge
echo       and the other Chromium browsers, and Firefox.
echo.
echo   The browser installs In'Seine FROM the store, so this needs no details
echo   from you: the Chrome Web Store ID and the addons.mozilla.org download
echo   link are both built into this script.
echo.
echo   IMPORTANT: this protects against a child using the computer. It does
echo   NOT protect against anyone with the administrator password. If your
echo   child's account has admin rights, give them a standard account -
echo   that is the single most effective thing you can do.
echo.

:: In'Seine's Chrome Web Store ID, assigned at publication and permanent:
::   https://chromewebstore.google.com/detail/inseine/ichaagpaahpkijknaieiiegblkjaichh
::
:: Earlier versions asked for this, because the extension wasn't on the store
:: yet and there was no ID to hard-code. There is one now, and asking a parent
:: to copy 32 characters out of a URL was friction for nothing.
set "EXTID=ichaagpaahpkijknaieiiegblkjaichh"
set "EDGEEXTID=enamohhodopckbgmeammnebbdjgdgcmg"

:: Sanity check only: exactly 32 characters, all in a-p.
:: force_installed tells Chrome to DOWNLOAD the extension from the Web Store,
:: so it cannot work for a developer-loaded copy whatever ID is given - the ID
:: Chrome shows for an unpacked extension is a hash of its folder path and
:: changes if the folder is renamed. This guards against the ID above being
:: mistyped in a future edit, not against user input.
::
:: findstr can't handle a 32-term regex ("Search string too long"), so this
:: tests the two conditions separately instead.
echo !EXTID!| findstr /r "[^a-p]" >nul
if not errorlevel 1 goto badid
if "!EXTID:~31,1!"=="" goto badid
if not "!EXTID:~32,1!"=="" goto badid
goto idok
:badid
echo.
echo   Internal error: the built-in extension ID is malformed.
echo   Expected 32 letters in the range a-p.
echo.
pause
exit /b 1
:idok

echo.
echo   FIREFOX
echo   -------
echo   In'Seine will be installed from addons.mozilla.org and made impossible
echo   to remove there too.
echo.

:: In'Seine's add-on download URL on addons.mozilla.org. The "latest" form is
:: deliberate: it always resolves to the current version, so this lock does not
:: have to be re-run after every update. Pinning the versioned file instead
:: (in_seine-0.5.0.xpi) would freeze Firefox on that build for ever.
::
:: Note the slug is "in-seine", with the hyphen, which is what AMO assigned.
set "FFURL=https://addons.mozilla.org/firefox/downloads/latest/in-seine/latest.xpi"

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
echo   ---------------------------------------------------------------
echo   PROTECT EXTENSION FILES (recommended)
echo   ---------------------------------------------------------------
echo   A background worker running as SYSTEM will lock the actual
echo   extension folders on disk. This stops a non-admin account from
echo   renaming or deleting the extension folder in File Explorer
echo   (the common bypass that breaks the filter).
echo.
echo   The worker re-applies the lock every couple of minutes.
echo   Browser updates may occasionally need a restart of the browser
echo   for the new version to appear cleanly.
echo.
echo   Without the worker, the policy still prevents removal via the
echo   browser UI, but a child who knows how can still rename the
echo   folder on disk and disable the filter.
echo.
set /p WORKER="   Install the protection worker? (Y/n): "

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

:: The other Chromium forks. These were missing entirely, so a child who
:: installed Brave, Vivaldi or Opera on Windows got a completely unmanaged
:: browser and walked round the whole lock. Brave's own documentation gives its
:: path as Software\Policies\BraveSoftware\Brave.
::
:: Written whether or not the browser is present. A key sitting unused in the
:: registry costs nothing, and it means a browser installed AFTER the lock is
:: already covered - which is exactly when a child would install one.
set BRAVE=HKLM\SOFTWARE\Policies\BraveSoftware\Brave
set CHROMIUM=HKLM\SOFTWARE\Policies\Chromium
set VIVALDI=HKLM\SOFTWARE\Policies\Vivaldi
set OPERA=HKLM\SOFTWARE\Policies\Opera Software

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

reg add "%EDGE%\ExtensionSettings\!EDGEEXTID!" /v installation_mode /t REG_SZ /d "force_installed" /f >nul
reg add "%EDGE%\ExtensionSettings\!EDGEEXTID!" /v update_url /t REG_SZ /d "https://edge.microsoft.com/extensionwebstorebase/v1/crx" /f >nul

:: Browser-level settings, below the extension
reg add "%CHROME%" /v ForceGoogleSafeSearch /t REG_DWORD /d 1 /f >nul
reg add "%CHROME%" /v IncognitoModeAvailability /t REG_DWORD /d 1 /f >nul
reg add "%EDGE%" /v ForceGoogleSafeSearch /t REG_DWORD /d 1 /f >nul
reg add "%EDGE%" /v ForceBingSafeSearch /t REG_DWORD /d 2 /f >nul
reg add "%EDGE%" /v InPrivateModeAvailability /t REG_DWORD /d 1 /f >nul

for %%B in ("%BRAVE%" "%CHROMIUM%" "%VIVALDI%" "%OPERA%") do (
  reg add "%%~B" /v ForceGoogleSafeSearch /t REG_DWORD /d 1 /f >nul
  reg add "%%~B" /v IncognitoModeAvailability /t REG_DWORD /d 1 /f >nul
  reg add "%%~B\ExtensionSettings\!EXTID!" /v installation_mode /t REG_SZ /d "force_installed" /f >nul
  reg add "%%~B\ExtensionSettings\!EXTID!" /v update_url /t REG_SZ /d "https://clients2.google.com/service/update2/crx" /f >nul
)

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
reg add "%FIREFOX%" /v ExtensionSettings /t REG_SZ /d "{\"inseine@inseine.co.uk\":{\"installation_mode\":\"force_installed\",\"install_url\":\"!FFURL!\"}}" /f >nul

if /i not "%YT%"=="n" (
  reg add "%CHROME%" /v ForceYouTubeRestrict /t REG_DWORD /d 2 /f >nul
  reg add "%EDGE%" /v ForceYouTubeRestrict /t REG_DWORD /d 2 /f >nul
  for %%B in ("%BRAVE%" "%CHROMIUM%" "%VIVALDI%" "%OPERA%") do (
    reg add "%%~B" /v ForceYouTubeRestrict /t REG_DWORD /d 2 /f >nul
  )
  echo   YouTube filtering on - comments will be unavailable.
)

:: ---------------------------------------------------------------------------
:: Optional protection worker
:: ---------------------------------------------------------------------------
if /i not "%WORKER%"=="n" (
  echo.
  echo   Installing protection worker...

  mkdir "C:\ProgramData\InSeine" 2>nul

  :: Write the worker PowerShell script
  (
    echo # In'Seine protection worker - runs as SYSTEM
    echo # Re-applies restrictive NTFS permissions on the extension folders
    echo # so a non-admin user cannot rename or delete them.
    echo $ErrorActionPreference = 'SilentlyContinue'
    echo $extIds = @('ichaagpaahpkijknaieiiegblkjaichh', 'enamohhodopckbgmeammnebbdjgdgcmg'^)
    echo $browserPaths = @(
    echo   'Google\Chrome\User Data',
    echo   'Microsoft\Edge\User Data',
    echo   'BraveSoftware\Brave-Browser\User Data',
    echo   'Chromium\User Data',
    echo   'Vivaldi\User Data',
    echo   'Opera Software\Opera Stable'
    echo ^)
    echo Get-ChildItem 'C:\Users' -Directory ^| ForEach-Object {
    echo   $userProfile = $_.FullName
    echo   $userName = $_.Name
    echo   if ($userName -in @('Public','Default','Default User','All Users'^)^) { return }
    echo   foreach ($bp in $browserPaths^) {
    echo     $base = Join-Path $userProfile "AppData\Local\$bp"
    echo     if (-not (Test-Path $base^)^) { continue }
    echo     Get-ChildItem $base -Directory -ErrorAction SilentlyContinue ^| ForEach-Object {
    echo       $profileDir = $_.FullName
    echo       $extRoot = Join-Path $profileDir 'Extensions'
    echo       if (-not (Test-Path $extRoot^)^) { return }
    echo       foreach ($id in $extIds^) {
    echo         $extDir = Join-Path $extRoot $id
    echo         if (Test-Path $extDir^) {
    echo           # SYSTEM + Administrators full control, user read+execute only
    echo           icacls $extDir /inheritance:d /T ^> $null 2^>^&1
    echo           icacls $extDir /grant:r "SYSTEM:(OI)(CI)F" /T ^> $null 2^>^&1
    echo           icacls $extDir /grant:r "Administrators:(OI)(CI)F" /T ^> $null 2^>^&1
    echo           icacls $extDir /grant:r "${userName}:(OI)(CI)RX" /T ^> $null 2^>^&1
    echo           icacls $extDir /deny "${userName}:(OI)(CI)(D,WDAC,WO,WD,AD,DC,DE)" /T ^> $null 2^>^&1
    echo         }
    echo       }
    echo     }
    echo   }
    echo   # Firefox profiles (approximate^)
    echo   $ffProfiles = Join-Path $userProfile 'AppData\Roaming\Mozilla\Firefox\Profiles'
    echo   if (Test-Path $ffProfiles^) {
    echo     Get-ChildItem $ffProfiles -Directory -ErrorAction SilentlyContinue ^| ForEach-Object {
    echo       $extDir = Join-Path $_.FullName 'extensions\inseine@inseine.co.uk'
    echo       if (Test-Path $extDir^) {
    echo         icacls $extDir /inheritance:d /T ^> $null 2^>^&1
    echo         icacls $extDir /grant:r "SYSTEM:(OI)(CI)F" /T ^> $null 2^>^&1
    echo         icacls $extDir /grant:r "Administrators:(OI)(CI)F" /T ^> $null 2^>^&1
    echo         icacls $extDir /grant:r "${userName}:(OI)(CI)RX" /T ^> $null 2^>^&1
    echo         icacls $extDir /deny "${userName}:(OI)(CI)(D,WDAC,WO,WD,AD,DC,DE)" /T ^> $null 2^>^&1
    echo       }
    echo     }
    echo   }
    echo }
  ) > "C:\ProgramData\InSeine\Worker.ps1"

  :: Protect the worker folder itself
  icacls "C:\ProgramData\InSeine" /inheritance:d >nul 2>&1
  icacls "C:\ProgramData\InSeine" /grant:r "SYSTEM:(OI)(CI)F" >nul 2>&1
  icacls "C:\ProgramData\InSeine" /grant:r "Administrators:(OI)(CI)F" >nul 2>&1
  icacls "C:\ProgramData\InSeine" /deny "Users:(OI)(CI)(W,D,M)" >nul 2>&1

  :: Create scheduled task that runs as SYSTEM every 3 minutes and at startup
  schtasks /Create /TN "InSeineWorker" /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"C:\ProgramData\InSeine\Worker.ps1\"" /SC MINUTE /MO 3 /RU SYSTEM /RL HIGHEST /F >nul 2>&1
  schtasks /Run /TN "InSeineWorker" >nul 2>&1

  reg add "HKLM\SOFTWARE\InSeine" /v WorkerInstalled /t REG_DWORD /d 1 /f >nul

  echo   Protection worker installed and started.
  echo   It will keep the extension folders locked against non-admin changes.
)

echo.
echo   Done. Close ALL browsers completely and reopen them.
echo.
echo   APPLIED EVERYWHERE, in every account on this computer:
echo     * Private browsing disabled
echo     * Google SafeSearch forced on in Chrome and Edge
echo     * about:config blocked in Firefox
echo.
echo   CHROME / EDGE: In'Seine installs itself into every account and
echo   cannot be removed or disabled.
echo.
echo   FIREFOX: In'Seine installs itself and cannot be removed.
echo.
if /i not "%WORKER%"=="n" (
  echo   PROTECTION WORKER: Extension folders on disk are locked so a
  echo   non-admin account cannot rename or delete them.
  echo.
)
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
