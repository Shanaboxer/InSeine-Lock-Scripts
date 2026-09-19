#!/usr/bin/env bash
# In'Seine — lock the browser (Linux)
#
# Uses Chrome's ExtensionSettings policy with force_installed. That does two
# things nothing else can:
#
#   1. Removes every route to removing In'Seine - greyed out on the extensions
#      page AND in the toolbar icon's right-click menu - while leaving every
#      other extension untouched and manageable.
#
#   2. Installs In'Seine automatically into EVERY user account on this
#      computer. So a child with their own standard account gets the filter
#      without you having to sign in and install it by hand.
#
# Also forces SafeSearch on, disables private browsing, and optionally filters
# YouTube - all below the extension, unchangeable from inside the browser.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo
  echo "  This needs root. Run it with:"
  echo "      sudo bash lock-browser.sh"
  echo
  exit 1
fi

CHROME_DIRS=(
  "/etc/opt/chrome/policies/managed"
  "/etc/chromium/policies/managed"
  "/etc/chromium-browser/policies/managed"
  "/etc/brave/policies/managed"
  "/etc/opt/edge/policies/managed"
  "/etc/vivaldi/policies/managed"
  "/etc/opt/vivaldi/policies/managed"
  "/etc/opera/policies/managed"
)

FIREFOX_DIRS=(
  "/etc/firefox/policies"
  "/usr/lib/firefox/distribution"
  "/usr/lib64/firefox/distribution"
  "/opt/firefox/distribution"
)

cat <<'BANNER'

  IN'SEINE - LOCK THE BROWSER
  ===========================

  ALWAYS APPLIED, to every browser found on this computer:

    * Private browsing disabled. Without this, a private window bypasses
      everything In'Seine does.
    * Google SafeSearch forced on in Chrome, Edge and other Chromium
      browsers, below the extension and unchangeable from inside it.
    * about:config blocked in Firefox.
    * A removal PIN, so none of the above can be undone without it.

  These apply to EVERY account on this computer, because browser policy is
  set system-wide.

    * In'Seine installed automatically into every account, and made
      impossible to remove or disable - and only In'Seine, your other
      extensions carry on working and stay manageable. This covers Chrome,
      Edge and the other Chromium browsers, and Firefox.

  The browser installs In'Seine FROM the store, so this needs no details
  from you: the Chrome Web Store ID and the addons.mozilla.org download
  link are both built into this script.

  IMPORTANT: this protects against a child using the computer. It does NOT
  protect against anyone with the administrator password. If your child's
  account has admin rights, give them a standard account instead - that is
  the single most effective thing you can do.

BANNER

# --- Chrome ------------------------------------------------------------------

# In'Seine's Chrome Web Store ID, assigned at publication and permanent:
#   https://chromewebstore.google.com/detail/inseine/ichaagpaahpkijknaieiiegblkjaichh
#
# Earlier versions asked for this, because the extension wasn't on the store
# yet and there was no ID to hard-code. There is one now, and asking a parent
# to copy 32 characters out of a URL was friction for nothing.
EXTID="ichaagpaahpkijknaieiiegblkjaichh"

echo "  CHROME, EDGE, BRAVE and other Chromium browsers"
echo "  -----------------------------------------------"
echo "  In'Seine will be installed automatically into every account on this"
echo "  computer, and made impossible to remove or disable there. Your other"
echo "  extensions are left alone and stay manageable as normal."
echo

# Sanity check only. force_installed tells Chrome to DOWNLOAD the extension
# from the Web Store, so it cannot work for a developer-loaded copy whatever ID
# is supplied - the ID Chrome shows for an unpacked extension is a hash of its
# folder path and changes if the folder is renamed. This guards against the ID
# above being mistyped in a future edit, not against user input.
if ! [[ "$EXTID" =~ ^[a-p]{32}$ ]]; then
  echo
  echo "  Internal error: the built-in extension ID is malformed."
  echo "  Expected 32 letters in the range a-p."
  echo
  exit 1
fi

# --- Firefox -----------------------------------------------------------------
#
# Firefox has no equivalent of Chrome's "lock it where it already is". Its
# ExtensionSettings policy takes exactly three installation_mode values —
# allowed, blocked and force_installed — and force_installed is the only one
# that prevents removal. It also REQUIRES an install_url, because the browser
# fetches the extension itself rather than protecting a copy already present.
#
# Earlier versions of this script wrote "installation_mode": "locked". That is
# not a Firefox value at all. Firefox ignored the entry, and the Firefox
# extension lock this script claimed to apply had never once worked.

# In'Seine's add-on download URL on addons.mozilla.org. The "latest" form is
# deliberate: it always resolves to the current version, so this lock does not
# have to be re-run after every update. Pinning the versioned file instead
# (in_seine-0.5.0.xpi) would freeze Firefox on that build for ever.
#
# Note the slug is "in-seine", with the hyphen, which is what AMO assigned.
FFURL="https://addons.mozilla.org/firefox/downloads/latest/in-seine/latest.xpi"

echo
echo "  FIREFOX"
echo "  -------"
echo "  In'Seine will be installed from addons.mozilla.org and made impossible"
echo "  to remove there too."
echo

# Same reasoning as the Chrome ID above: a guard against a bad edit, not
# against user input.
if ! [[ "$FFURL" =~ ^https://[^[:space:]]+\.xpi$ ]]; then
  echo
  echo "  Internal error: the built-in add-on URL is malformed."
  echo "  It should start with https:// and end with .xpi"
  echo
  exit 1
fi

echo
read -rp "  Set a removal PIN (4 digits): " PIN
if ! [[ "$PIN" =~ ^[0-9]{4}$ ]]; then
  echo "  Needs to be exactly 4 digits."
  exit 1
fi

echo
echo "  Filter YouTube? Restricted Mode also disables YouTube comments."
echo "  For children this is usually worth it - comment sections are one of"
echo "  the things parents most want filtered."
read -rp "  Turn on YouTube filtering? (Y/n): " YT
if [[ "$YT" =~ ^[Nn]$ ]]; then
  YT_POLICY=""
  echo "  YouTube filtering off."
else
  YT_POLICY=',
  "ForceYouTubeRestrict": 2'
  echo "  YouTube filtering on - comments will be unavailable."
fi

echo
echo "  ---------------------------------------------------------------"
echo "  PROTECT EXTENSION FILES (recommended)"
echo "  ---------------------------------------------------------------"
echo "  A background worker running as root will lock the actual"
echo "  extension folders on disk. This stops a non-admin account from"
echo "  renaming or deleting the extension folder (the common bypass"
echo "  that breaks the filter)."
echo
echo "  The worker re-applies the lock every couple of minutes."
echo "  Browser updates may occasionally need a restart of the browser"
echo "  for the new version to appear cleanly."
echo
echo "  Without the worker, the policy still prevents removal via the"
echo "  browser UI, but a child who knows how can still rename the"
echo "  folder on disk and disable the filter."
echo
read -rp "  Install the protection worker? (Y/n): " WORKER
if [[ "$WORKER" =~ ^[Nn]$ ]]; then
  INSTALL_WORKER=0
  echo "  Protection worker will not be installed."
else
  INSTALL_WORKER=1
  echo "  Protection worker will be installed."
fi

echo
read -rp "  Continue? (y/n): " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "  Cancelled. Nothing was changed."; exit 0; }

# Salted hash of the removal PIN, readable only by root.
mkdir -p /etc/inseine
SALT=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
HASH=$(printf '%s' "${SALT}${PIN}" | sha256sum | cut -d' ' -f1)
printf '%s\n%s\n' "$SALT" "$HASH" > /etc/inseine/removal.pin
chmod 600 /etc/inseine/removal.pin
chown root:root /etc/inseine/removal.pin

EXT_POLICY=",
  \"ExtensionSettings\": {
    \"${EXTID}\": {
      \"installation_mode\": \"force_installed\",
      \"update_url\": \"https://clients2.google.com/service/update2/crx\",
      \"incognito_mode\": \"enabled\",
      \"toolbar_pin\": \"force_pinned\"
    }
  }"

POLICY="{
  \"IncognitoModeAvailability\": 1,
  \"ForceGoogleSafeSearch\": true${YT_POLICY}${EXT_POLICY}
}"

echo
# Write to every location, whether or not the browser is installed yet.
#
# This used to write only where the parent directory already existed. Two
# problems with that. Brave's own documentation says /etc/brave "may not exist
# after installing Brave" and tells you to create it yourself — so the guard
# failed, no policy was written, and Brave silently ignored the lock entirely.
# And a child who installs a browser AFTER the lock is applied got a completely
# unmanaged one, which is the obvious way round this.
#
# Writing a small JSON file into /etc for a browser that is not installed is
# harmless, and unlock-browser.sh removes them all again.
for dir in "${CHROME_DIRS[@]}"; do
  mkdir -p "$dir"
  printf '%s\n' "$POLICY" > "$dir/inseine.json"
  chmod 644 "$dir/inseine.json"
  echo "  wrote $dir/inseine.json"
done

# The gecko ID must match browser_specific_settings.gecko.id in the Firefox
# manifest. It was "inseine@localhost" during development; naming the wrong ID
# here does not fail loudly, it just silently protects nothing.
#
# "_inseine_marker" is not a Firefox policy and is ignored by it. It is here so
# unlock-browser.sh can recognise a policies.json as ours and know it is safe to
# delete. Without a reliable marker the unlock script left the file in place and
# the lock could not be undone at all.
# force_installed is the only Firefox mode that prevents removal, and it needs
# install_url because Firefox fetches the add-on itself rather than protecting
# a copy already present.
FF_EXT=",
    \"ExtensionSettings\": {
      \"inseine@inseine.co.uk\": {
        \"installation_mode\": \"force_installed\",
        \"install_url\": \"${FFURL}\"
      }
    }"

# "_inseine_marker" is not a Firefox policy and is ignored by it. It is here so
# unlock-browser.sh can recognise a policies.json as ours and know it is safe to
# delete. Without a reliable marker the unlock script left the file in place and
# the lock could not be undone at all.
FF_POLICY="{
  \"policies\": {
    \"DisablePrivateBrowsing\": true,
    \"BlockAboutConfig\": true${FF_EXT}
  },
  \"_inseine_marker\": \"written by In'Seine lock-browser.sh - safe to remove with unlock-browser.sh\"
}"

# /etc/firefox/policies is the supported location and is created here if
# missing, for the same reason as above. The distribution/ directories are only
# written when Firefox is actually installed there, since creating them under
# /usr/lib for an absent browser would be litter rather than protection.
for dir in "${FIREFOX_DIRS[@]}"; do
  parent="$(dirname "$dir")"
  if [[ "$dir" == /etc/* ]] || [[ -d "$parent" ]]; then
    mkdir -p "$dir"
    if [[ -f "$dir/policies.json" ]] && ! grep -q '_inseine_marker\|inseine@' "$dir/policies.json" 2>/dev/null; then
      cp "$dir/policies.json" "$dir/policies.json.inseine-backup"
      echo "  backed up existing $dir/policies.json"
    fi
    printf '%s\n' "$FF_POLICY" > "$dir/policies.json"
    echo "  wrote $dir/policies.json"
  fi
done

# --- Optional protection worker ----------------------------------------------
if [[ $INSTALL_WORKER -eq 1 ]]; then
  echo
  echo "  Installing protection worker..."

  mkdir -p /etc/inseine
  cat > /etc/inseine/worker.sh << 'WORKER'
#!/bin/bash
# In'Seine protection worker - runs as root
# Re-applies restrictive permissions on the extension folders so a
# non-admin user cannot rename or delete them.

EXT_IDS=("ichaagpaahpkijknaieiiegblkjaichh" "enamohhodopckbgmeammnebbdjgdgcmg")
GECKO_ID="inseine@inseine.co.uk"

# Chromium-family locations under each user's home
BROWSER_SUBPATHS=(
  ".config/google-chrome"
  ".config/chromium"
  ".config/BraveSoftware/Brave-Browser"
  ".config/microsoft-edge"
  ".config/vivaldi"
  ".config/opera"
  ".var/app/com.google.Chrome/config/google-chrome"
  ".var/app/org.chromium.Chromium/config/chromium"
  ".var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser"
  ".var/app/com.microsoft.Edge/config/microsoft-edge"
)

for home in /home/*; do
  [ -d "$home" ] || continue
  user=$(basename "$home")

  for sub in "${BROWSER_SUBPATHS[@]}"; do
    base="$home/$sub"
    [ -d "$base" ] || continue
    # Each profile (Default, Profile 1, ...)
    for profile in "$base"/*/; do
      [ -d "$profile" ] || continue
      extroot="${profile}Extensions"
      [ -d "$extroot" ] || continue
      for id in "${EXT_IDS[@]}"; do
        extdir="$extroot/$id"
        if [ -d "$extdir" ]; then
          # Owner root, group the user, mode 755 (user can read+enter, not write)
          chown -R root:"$user" "$extdir" 2>/dev/null || true
          chmod -R u=rwX,g=rX,o=rX "$extdir" 2>/dev/null || true
          # Extra hardening with setfacl if available
          if command -v setfacl >/dev/null 2>&1; then
            setfacl -R -m "u:$user:r-x" "$extdir" 2>/dev/null || true
            setfacl -R -m "d:u:$user:r-x" "$extdir" 2>/dev/null || true
            setfacl -R -m "g:$user:r-x" "$extdir" 2>/dev/null || true
          fi
        fi
      done
    done
  done

  # Firefox
  ffprofiles="$home/.mozilla/firefox"
  if [ -d "$ffprofiles" ]; then
    for profile in "$ffprofiles"/*/; do
      [ -d "$profile" ] || continue
      extdir="${profile}extensions/$GECKO_ID"
      if [ -d "$extdir" ] || [ -f "$extdir" ]; then
        chown -R root:"$user" "$extdir" 2>/dev/null || true
        chmod -R u=rwX,g=rX,o=rX "$extdir" 2>/dev/null || true
        if command -v setfacl >/dev/null 2>&1; then
          setfacl -R -m "u:$user:r-x" "$extdir" 2>/dev/null || true
          setfacl -R -m "d:u:$user:r-x" "$extdir" 2>/dev/null || true
        fi
      fi
    done
  fi
done
WORKER

  chmod 700 /etc/inseine/worker.sh
  chown root:root /etc/inseine/worker.sh

  # systemd timer + service (preferred) or fall back to cron
  if command -v systemctl >/dev/null 2>&1; then
    cat > /etc/systemd/system/inseine-worker.service << 'SVC'
[Unit]
Description=In'Seine extension folder protection worker
After=network.target

[Service]
Type=oneshot
ExecStart=/etc/inseine/worker.sh
Nice=10
SVC

    cat > /etc/systemd/system/inseine-worker.timer << 'TMR'
[Unit]
Description=Run In'Seine protection worker every 3 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=3min
AccuracySec=30s
Persistent=true

[Install]
WantedBy=timers.target
TMR

    systemctl daemon-reload
    systemctl enable --now inseine-worker.timer >/dev/null 2>&1 || true
    # Run once immediately
    /etc/inseine/worker.sh || true
    echo "  Protection worker installed (systemd timer)."
  else
    # Fallback: cron
    echo "*/3 * * * * root /etc/inseine/worker.sh" > /etc/cron.d/inseine-worker
    chmod 644 /etc/cron.d/inseine-worker
    /etc/inseine/worker.sh || true
    echo "  Protection worker installed (cron)."
  fi

  echo "1" > /etc/inseine/worker.installed
  chmod 644 /etc/inseine/worker.installed
fi

# --- browsers this lock cannot reach -----------------------------------------
#
# Chromium and its forks hardcode their policy directory under /etc. A Flatpak
# or Snap browser reads the /etc INSIDE its own sandbox, not the host's, so a
# file written here is invisible to it. The Flatpak project was asked for a way
# round this in 2022 and closed the request without one.
#
# Silence would be the wrong answer. A parent who ran this script is entitled to
# know that one of their browsers is not covered, because a browser with private
# browsing still available undoes the rest of the lock.
UNREACHABLE=""

if command -v flatpak >/dev/null 2>&1; then
  while read -r app; do
    case "$app" in
      com.brave.Browser)      UNREACHABLE="$UNREACHABLE  Brave (Flatpak)\n" ;;
      com.google.Chrome)      UNREACHABLE="$UNREACHABLE  Chrome (Flatpak)\n" ;;
      org.chromium.Chromium)  UNREACHABLE="$UNREACHABLE  Chromium (Flatpak)\n" ;;
      com.microsoft.Edge)     UNREACHABLE="$UNREACHABLE  Edge (Flatpak)\n" ;;
      com.vivaldi.Vivaldi)    UNREACHABLE="$UNREACHABLE  Vivaldi (Flatpak)\n" ;;
      com.opera.Opera)        UNREACHABLE="$UNREACHABLE  Opera (Flatpak)\n" ;;
      org.mozilla.firefox)    UNREACHABLE="$UNREACHABLE  Firefox (Flatpak)\n" ;;
    esac
  done < <(flatpak list --app --columns=application 2>/dev/null)
fi

if command -v snap >/dev/null 2>&1; then
  while read -r name _; do
    case "$name" in
      brave)     UNREACHABLE="$UNREACHABLE  Brave (Snap)\n" ;;
      chromium)  UNREACHABLE="$UNREACHABLE  Chromium (Snap)\n" ;;
      opera)     UNREACHABLE="$UNREACHABLE  Opera (Snap)\n" ;;
    esac
  done < <(snap list 2>/dev/null | tail -n +2)
fi

echo
echo "  Done. Now QUIT ALL BROWSERS COMPLETELY and reopen them."
echo "  Closing the window isn't enough - check with: pgrep -a chrome"
echo
echo "  APPLIED EVERYWHERE, in every account on this computer:"
echo "    * Private browsing disabled"
echo "    * Google SafeSearch forced on in Chromium browsers"
echo "    * about:config blocked in Firefox"
if [[ -n "$YT_POLICY" ]]; then
  echo "    * YouTube Restricted Mode"
fi
if [[ $INSTALL_WORKER -eq 1 ]]; then
  echo "    * Extension folders locked on disk (protection worker)"
fi
echo

echo "  CHROME: In'Seine will install itself into every account the next time"
echo "  the browser starts, and cannot be removed or disabled."
echo "  Sign into your child's account, open Chrome, and go through In'Seine's"
echo "  setup there to choose their filters and their PIN."
echo

echo "  FIREFOX: In'Seine will install itself and cannot be removed."

if [[ -n "$UNREACHABLE" ]]; then
  echo
  echo "  ---------------------------------------------------------------"
  echo "  THESE BROWSERS ARE NOT COVERED BY THE LOCK:"
  echo
  printf "%b" "$UNREACHABLE"
  echo
  echo "  They are installed as Flatpak or Snap packages, which run in a"
  echo "  sandbox with their own /etc. Browser policy written on this"
  echo "  computer cannot reach inside it. That is a limitation of those"
  echo "  packaging systems, not something this script can work around."
  echo
  echo "  In'Seine itself still filters normally in them once installed."
  echo "  What is missing is private browsing being disabled, and the"
  echo "  extension being impossible to remove."
  echo
  echo "  To bring one under the lock, remove the Flatpak or Snap version"
  echo "  and install the browser's normal .deb or .rpm instead. To take"
  echo "  the simpler route, remove the browser and use one that is"
  echo "  covered. Otherwise treat it as an open door."
  echo "  ---------------------------------------------------------------"
fi

cat <<'DONE'

  Check it worked:
    chrome://policy       the entries should be listed
    chrome://extensions   In'Seine's Remove is greyed out, and other
                          extensions are unaffected
    about:policies        the Firefox equivalent

  Private browsing should be gone from the menu in both.

  To undo all of this:
    sudo bash unlock-browser.sh
  and enter the removal PIN you just set.

  Worth doing NOW rather than when you need it: run the unlock script once,
  check it accepts your PIN, then run this one again. Finding out that the
  removal works is worth two minutes.

DONE
