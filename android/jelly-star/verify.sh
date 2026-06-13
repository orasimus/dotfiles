#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
failures=0

command -v adb >/dev/null || {
  echo "adb is required" >&2
  exit 1
}

adb get-state >/dev/null

device="$(adb shell getprop ro.product.device | tr -d '\r')"
if [[ "$device" != "Jelly_Star" ]]; then
  echo "Unexpected device: ${device:-unknown}" >&2
  exit 1
fi

check_list() {
  local file="$1"
  local expected="$2"
  local package state

  while IFS= read -r package <&3; do
    case "$package" in
      ''|'#'*) continue ;;
    esac

    if ! adb shell pm path --user 0 "$package" </dev/null 2>/dev/null |
      grep -q '^package:'; then
      echo "WARN absent package: $package ($file)"
      continue
    fi

    state="$(adb shell cmd appops get "$package" POST_NOTIFICATION \
      </dev/null 2>/dev/null || true)"
    if ! grep -q "POST_NOTIFICATION: $expected" <<<"$state"; then
      echo "FAIL notification state for $package: expected $expected"
      failures=$((failures + 1))
    fi
  done 3< "$script_dir/$file"
}

home="$(adb shell cmd package resolve-activity --brief --user 0 \
  -a android.intent.action.MAIN -c android.intent.category.HOME |
  tr -d '\r' | tail -n 1)"
if [[ "$home" != de.mm20.launcher2.release/* ]]; then
  echo "FAIL default Home is $home"
  failures=$((failures + 1))
fi

autofill="$(adb shell settings get secure autofill_service | tr -d '\r')"
if [[ "$autofill" != \
  "com.x8bit.bitwarden/.Autofill.AutofillService" ]]; then
  echo "FAIL default autofill service is $autofill"
  failures=$((failures + 1))
fi

disabled="$(adb shell pm list packages -d --user 0)"
while IFS= read -r package <&3; do
  case "$package" in
    ''|'#'*) continue ;;
  esac

  if ! grep -qx "package:$package" <<<"$disabled"; then
    echo "FAIL package is not disabled: $package"
    failures=$((failures + 1))
  fi
done 3< "$script_dir/packages-disable.txt"

check_list packages-notifications-allow.txt allow
check_list packages-notifications-deny.txt ignore

while IFS= read -r package <&3; do
  case "$package" in
    ''|'#'*) continue ;;
  esac

  state="$(adb shell cmd appops get "$package" REQUEST_INSTALL_PACKAGES \
    </dev/null 2>/dev/null || true)"
  if ! grep -q 'REQUEST_INSTALL_PACKAGES: deny' <<<"$state"; then
    echo "FAIL APK installation is not denied for $package"
    failures=$((failures + 1))
  fi
done 3< "$script_dir/packages-deny-installs.txt"

browser="$(adb shell cmd package resolve-activity --brief --user 0 \
  -a android.intent.action.VIEW -d https://example.com 2>/dev/null || true)"
if grep -q '/' <<<"$browser"; then
  echo "FAIL a browser can handle ordinary web links: $browser"
  failures=$((failures + 1))
fi

if ((failures)); then
  echo "$failures verification failure(s)" >&2
  exit 1
fi

echo "Jelly Star configuration verified"
