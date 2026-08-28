#!/usr/bin/env bash
# In'Seine — undo the browser lock (Linux)

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo
  echo "  This needs root. Run it with:"
  echo "      sudo bash unlock-browser.sh"
  echo
  exit 1
fi

echo
echo "  IN'SEINE - UNLOCK THE BROWSER"
echo "  ============================="
echo

if [[ ! -f /etc/inseine/removal.pin ]]; then
  echo "  No PIN on file - the lock doesn't appear to be installed."
  echo "  Removing any policy files found anyway."
else
  read -rsp "  Removal PIN: " PIN
  echo
  SALT=$(sed -n 1p /etc/inseine/removal.pin)
  WANT=$(sed -n 2p /etc/inseine/removal.pin)
  GOT=$(printf '%s' "${SALT}${PIN}" | sha256sum | cut -d' ' -f1)
  if [[ "$GOT" != "$WANT" ]]; then
    echo
    echo "  Wrong PIN."
    sleep 3
    exit 1
  fi
  echo "  PIN accepted."
fi

echo
REMOVED=0
for dir in \
  "/etc/opt/chrome/policies/managed" "/etc/chromium/policies/managed" \
  "/etc/chromium-browser/policies/managed" "/etc/brave/policies/managed" \
  "/etc/opt/edge/policies/managed" "/etc/opt/vivaldi/policies/managed" \
  "/etc/opera/policies/managed"
do
  if [[ -f "$dir/inseine.json" ]]; then
    rm -f "$dir/inseine.json"
    echo "  removed $dir/inseine.json"
    REMOVED=$((REMOVED+1))
  fi
done

for dir in "/etc/firefox/policies" "/usr/lib/firefox/distribution" \
           "/usr/lib64/firefox/distribution" "/opt/firefox/distribution"; do
  if [[ -f "$dir/policies.json.inseine-backup" ]]; then
    mv "$dir/policies.json.inseine-backup" "$dir/policies.json"
    echo "  restored previous $dir/policies.json"
    REMOVED=$((REMOVED+1))
  elif [[ -f "$dir/policies.json" ]] && grep -q 'BlockAboutAddons' "$dir/policies.json" 2>/dev/null; then
    rm -f "$dir/policies.json"
    echo "  removed $dir/policies.json"
    REMOVED=$((REMOVED+1))
  fi
done

rm -f /etc/inseine/removal.pin
rmdir /etc/inseine 2>/dev/null || true

[[ $REMOVED -eq 0 ]] && echo "  Nothing to remove."

cat <<'DONE'

  Unlocked. QUIT ALL BROWSERS COMPLETELY and reopen them.

  The extensions page works again, and you can remove the In'Seine
  extension from there in the normal way.

DONE
