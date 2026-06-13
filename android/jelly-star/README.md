# Jelly Star dumb-phone configuration

This directory records the reversible ADB configuration applied to the
Unihertz Jelly Star. It does not root the phone.

## Prerequisites

- The required applications are already installed.
- Developer options and USB debugging are enabled.
- The phone has authorized the computer's ADB key.
- `adb` is available. On NixOS, run commands inside:

  ```sh
  nix shell nixpkgs#android-tools
  ```

## Apply

Connect exactly one Android device and run:

```sh
./android/jelly-star/apply.sh
./android/jelly-star/verify.sh
```

The scripts refuse to operate unless `ro.product.device` is `Jelly_Star`.

`apply.sh`:

- makes Kvaesitso the default Home application;
- makes Bitwarden the default password/autofill service;
- makes Gboard the only enabled/default input method;
- disables the packages in `packages-disable.txt`;
- revokes unnecessary APK installation access;
- applies the notification allow and deny lists.

## Manual settings

Kvaesitso keeps its hidden-app configuration in private application data, so
ADB cannot reproduce it without root. Hide these apps manually:

- Google Play Store (`com.android.vending`)
- F-Droid (`org.fdroid.fdroid`)

Keep Play Store automatic updates enabled. Store hiding is cosmetic: Settings
can still open the Play Store.

Inside **Gboard Settings > Languages**, keep only **Suomi (Suomi)** with the
**suomi** layout. Gboard stores this language selection in private app data, so
ADB cannot reproduce it. The scripts do remove the separate Google Voice
Typing input method and make Gboard the sole/default keyboard.

Application accounts, internal preferences, Kvaesitso layout, notification
channels, battery exemptions, and app installation are not managed here.

The Jelly Star runs Android 13. Bitwarden can provide password autofill, but
Android 13 cannot select a third-party system passkey provider. That requires
Android 14 or newer.

## Finalize

After `verify.sh` succeeds:

1. Open **Settings > System > Developer options**.
2. Turn off **USB debugging**.
3. Optionally select **Revoke USB debugging authorizations**.
4. Developer options themselves may remain enabled, or turn them off using
   the switch at the top of that screen.

USB debugging is intentionally not disabled by `apply.sh`: doing so would
disconnect ADB before verification and remove the immediate recovery path.

To apply, verify, or restore the configuration later, re-enable Developer
options by tapping **Settings > About phone > Build number** seven times, then
enable **USB debugging** and authorize the computer again.

## Restore

```sh
./android/jelly-star/restore.sh
```

This re-enables disabled packages, restores APK installation app-ops to their
defaults, and enables notifications for applications managed by these lists.
It cannot reconstruct notification choices that existed before this setup.

## Files

- `apps-visible.txt`: documented launcher-capable applications.
- `packages-keep.txt`: packages intentionally retained.
- `packages-disable.txt`: packages disabled for Android user 0.
- `packages-hide.txt`: manually hidden launcher entries.
- `packages-deny-installs.txt`: retained apps denied unknown-APK installation.
- `packages-notifications-allow.txt`: essential notification sources.
- `packages-notifications-deny.txt`: applications with notifications blocked.
- `baseline/`: pre-configuration device inventory with serials redacted.
