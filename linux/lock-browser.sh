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

  This writes browser policy that:

    * Installs In'Seine into EVERY account on this computer, automatically
    * Stops In'Seine being removed or disabled - and only In'Seine. Your
      other extensions carry on working and stay manageable.
    * Forces Google SafeSearch on, browser-wide
    * Disables private browsing, which otherwise bypasses everything
    * Blocks about:config in Firefox

  None of it can be changed from inside the browser.

  IMPORTANT: this protects against a child using the computer. It does NOT
  protect against anyone with the administrator password. If your child's
  account has admin rights, give them a standard account instead - that is
  the single most effective thing you can do.

BANNER

echo "  You need In'Seine's Chrome Web Store extension ID."
echo
echo "  It's on the store listing page, at the end of the address:"
echo "      chrome.google.com/webstore/detail/inseine/<THIS BIT>"
echo
echo "  32 letters, a to p."
echo
read -rp "  Extension ID: " EXTID

EXTID=$(echo "$EXTID" | tr -d '[:space:]' | tr 'A-Z' 'a-z')
if ! [[ "$EXTID" =~ ^[a-p]{32}$ ]]; then
  echo
  echo "  That doesn't look like a Chrome extension ID."
  echo "  Expected 32 letters in the range a-p, for example:"
  echo "      nmmhkkegccagdldgiimedpiccmgmieda"
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
read -rp "  Continue? (y/n): " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "  Cancelled. Nothing was changed."; exit 0; }

# Salted hash of the removal PIN, readable only by root.
mkdir -p /etc/inseine
SALT=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
HASH=$(printf '%s' "${SALT}${PIN}" | sha256sum | cut -d' ' -f1)
printf '%s\n%s\n' "$SALT" "$HASH" > /etc/inseine/removal.pin
chmod 600 /etc/inseine/removal.pin
chown root:root /etc/inseine/removal.pin

POLICY="{
  \"IncognitoModeAvailability\": 1,
  \"ForceGoogleSafeSearch\": true${YT_POLICY},
  \"ExtensionSettings\": {
    \"${EXTID}\": {
      \"installation_mode\": \"force_installed\",
      \"update_url\": \"https://clients2.google.com/service/update2/crx\",
      \"incognito_mode\": \"enabled\",
      \"toolbar_pin\": \"force_pinned\"
    }
  }
}"

echo
for dir in "${CHROME_DIRS[@]}"; do
  parent="$(dirname "$(dirname "$dir")")"
  if [[ -d "$parent" ]]; then
    mkdir -p "$dir"
    printf '%s\n' "$POLICY" > "$dir/inseine.json"
    chmod 644 "$dir/inseine.json"
    echo "  wrote $dir/inseine.json"
  fi
done

FF_POLICY='{
  "policies": {
    "DisablePrivateBrowsing": true,
    "BlockAboutConfig": true,
    "ExtensionSettings": {
      "inseine@localhost": { "installation_mode": "locked" }
    }
  }
}'

for dir in "${FIREFOX_DIRS[@]}"; do
  parent="$(dirname "$dir")"
  if [[ -d "$parent" ]]; then
    mkdir -p "$dir"
    if [[ -f "$dir/policies.json" ]] && ! grep -q 'DisablePrivateBrowsing' "$dir/policies.json" 2>/dev/null; then
      cp "$dir/policies.json" "$dir/policies.json.inseine-backup"
      echo "  backed up existing $dir/policies.json"
    fi
    printf '%s\n' "$FF_POLICY" > "$dir/policies.json"
    echo "  wrote $dir/policies.json"
  fi
done

cat <<'DONE'

  Done. Now QUIT ALL BROWSERS COMPLETELY and reopen them.
  Closing the window isn't enough - check with: pgrep -a chrome

  Check it worked:
    chrome://policy       the entries should be listed
    chrome://extensions   In'Seine's Remove should be greyed out,
                          other extensions unaffected
    Right-click the In'Seine icon - Remove should be unavailable

  Private browsing should be gone from the menu.

  IN EVERY OTHER ACCOUNT ON THIS COMPUTER, In'Seine will install itself
  the next time Chrome starts. Sign into your child's account, open Chrome,
  and go through In'Seine's setup there to choose their filters and PIN.

  To undo all of this:
    sudo bash unlock-browser.sh
  and enter the removal PIN you just set.

DONE
