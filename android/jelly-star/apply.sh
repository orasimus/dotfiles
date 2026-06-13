#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

command -v adb >/dev/null || {
  echo "adb is required" >&2
  exit 1
}

adb get-state >/dev/null

device="$(adb shell getprop ro.product.device | tr -d '\r')"
if [[ "$device" != "Jelly_Star" ]]; then
  echo "Refusing to configure unexpected device: ${device:-unknown}" >&2
  exit 1
fi

package_exists() {
  adb shell pm path --user 0 "$1" </dev/null 2>/dev/null | grep -q '^package:'
}

adb shell cmd package set-home-activity --user 0 de.mm20.launcher2.release \
  </dev/null
adb shell settings put secure autofill_service \
  com.x8bit.bitwarden/.Autofill.AutofillService </dev/null
adb shell ime disable \
  com.google.android.tts/com.google.android.apps.speech.tts.googletts.settings.asr.voiceime.VoiceInputMethodService \
  </dev/null
adb shell ime enable \
  com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME \
  </dev/null
adb shell ime set \
  com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME \
  </dev/null

while IFS= read -r package <&3; do
  case "$package" in
    ''|'#'*) continue ;;
  esac

  adb shell pm disable-user --user 0 "$package" </dev/null
done 3< "$script_dir/packages-disable.txt"

while IFS= read -r package <&3; do
  case "$package" in
    ''|'#'*) continue ;;
  esac

  if ! package_exists "$package"; then
    echo "Skipping absent package in packages-deny-installs.txt: $package" >&2
    continue
  fi

  adb shell cmd appops set "$package" REQUEST_INSTALL_PACKAGES deny </dev/null
done 3< "$script_dir/packages-deny-installs.txt"

while IFS= read -r package <&3; do
  case "$package" in
    ''|'#'*) continue ;;
  esac

  if ! package_exists "$package"; then
    echo "Skipping absent package in packages-notifications-deny.txt: $package" >&2
    continue
  fi

  adb shell cmd appops set "$package" POST_NOTIFICATION ignore </dev/null
  adb shell pm revoke "$package" android.permission.POST_NOTIFICATIONS \
    </dev/null 2>/dev/null || true
done 3< "$script_dir/packages-notifications-deny.txt"

while IFS= read -r package <&3; do
  case "$package" in
    ''|'#'*) continue ;;
  esac

  if ! package_exists "$package"; then
    echo "Skipping absent package in packages-notifications-allow.txt: $package" >&2
    continue
  fi

  adb shell cmd appops set "$package" POST_NOTIFICATION allow </dev/null
  adb shell pm grant "$package" android.permission.POST_NOTIFICATIONS \
    </dev/null 2>/dev/null || true
done 3< "$script_dir/packages-notifications-allow.txt"
