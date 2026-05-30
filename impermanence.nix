# Impermanence: on every boot the `@root` btrfs subvolume is rolled back to
# the empty `@root-blank` snapshot, then `environment.persistence."/persist"`
# below bind-mounts the declared system paths from `/persist` back into place.
# `/nix`, `/persist`, `/var/log`, and `/boot` are independent subvolumes /
# partitions and are unaffected by the wipe.
#
# Prerequisites before the first switch + reboot under this config:
#   1) The `@root-blank` subvolume must exist (must match the name used in
#      the rollback script below — historically a typo here left the system
#      with no @root after the first rollback):
#        sudo mount -o subvol=/ /dev/nvme0n1p2 /mnt/btrfs
#        sudo btrfs subvolume create /mnt/btrfs/@root-blank
#        sudo umount /mnt/btrfs
#      (It is intentionally empty — every reboot snapshots this over @root.)
#   2) The sops-nix age identity must exist at
#      /persist/var/lib/sops-nix/key.txt (root-only). Password hashes, WiFi,
#      and VPN credentials are decrypted from secrets.yaml at activation time.
#      `neededForUsers = true` makes the password hashes available before
#      NixOS creates users, so losing /etc/shadow to the rollback is harmless.
#   3) Any other files that already live on `@root` and need to survive the
#      first wipe must be relocated under `/persist/` first. In this config
#      that currently means at least:
#        /var/lib/{NetworkManager,bluetooth,fwupd,nixos}/ → /persist/var/lib/...
#      The bind mounts declared below pull these back into place on subsequent
#      boots, but the *first* boot under impermanence loses anything not yet
#      staged in /persist. See `home.persistence` in home.nix for the
#      matching list of /home/otso paths that should be pre-seeded too.

{ lib, ... }:

{
  # systemd in initrd — the rollback service below is a systemd unit ordered
  # before sysroot.mount. Without this we'd be stuck with the older
  # boot.initrd.postDeviceCommands hook.
  boot.initrd.systemd.enable = true;

  # Roll @root back to an empty snapshot before stage-2 mounts it as /.
  # The previous @root is preserved under /old_roots/<timestamp> on the parent
  # subvolume for ~30 days — escape hatch if a reboot wipes something we
  # forgot to declare in /persist.
  boot.initrd.systemd.services.rollback-root = {
    description = "Roll @root btrfs subvolume back to a pristine state";
    wantedBy = [ "initrd.target" ];
    # Ordering: after the device node appears, before sysroot.mount mounts /.
    after = [ "dev-disk-by\\x2duuid-630b3ded\\x2d5206\\x2d4369\\x2da36e\\x2d50a6d462db9c.device" ];
    requires = [ "dev-disk-by\\x2duuid-630b3ded\\x2d5206\\x2d4369\\x2da36e\\x2d50a6d462db9c.device" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    # `set -euo pipefail`: a silent failure here (e.g. the snapshot source
    # name not matching the on-disk subvolume) is what made the first attempt
    # at this config unbootable — @root got moved to old_roots but never
    # recreated, and sysroot.mount had nothing to mount. Fail loudly instead.
    script = ''
      set -euo pipefail

      mkdir -p /btrfs_tmp
      mount -o subvol=/ /dev/disk/by-uuid/630b3ded-5206-4369-a36e-50a6d462db9c /btrfs_tmp
      mkdir -p /btrfs_tmp/old_roots

      if [[ -e /btrfs_tmp/@root ]]; then
        timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/@root)" "+%Y-%m-%d_%H:%M:%S")
        mv /btrfs_tmp/@root "/btrfs_tmp/old_roots/$timestamp"
      fi

      # Garbage-collect old_roots older than 30 days.
      delete_subvolume_recursively() {
        IFS=$'\n'
        for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
          delete_subvolume_recursively "/btrfs_tmp/$i"
        done
        btrfs subvolume delete "$1"
      }
      for i in $(find /btrfs_tmp/old_roots/ -mindepth 1 -maxdepth 1 -mtime +30); do
        delete_subvolume_recursively "$i"
      done

      btrfs subvolume snapshot /btrfs_tmp/@root-blank /btrfs_tmp/@root
      umount /btrfs_tmp
    '';
  };

  # System-level persistence. Everything declared here is bind-mounted from
  # /persist back into the wiped @root after stage-2 boot. User-level paths
  # (Discord, Steam, etc.) will be wired separately via home.persistence
  # under home.nix.
  environment.persistence."/persist" = {
    hideMounts = true;

    directories = [
      # NixOS itself: uid/gid map. Losing this re-rolls uids on next boot.
      "/var/lib/nixos"

      # NetworkManager: connection profiles + DHCP lease cache + secret_key
      # (used to encrypt the connection-stored secrets at rest).
      "/var/lib/NetworkManager"

      # The declarative WiFi profile from configuration.nix is rendered into
      # /etc/NetworkManager/system-connections at activation, but NM also
      # writes any non-declarative ones (e.g. one added with `nmcli` in a
      # pinch) here. Persist the directory so those don't vanish.
      "/etc/NetworkManager/system-connections"

      # Bluetooth pairings (link keys, trusted devices).
      "/var/lib/bluetooth"

      # fwupd: LVFS metadata cache + applied-update state.
      "/var/lib/fwupd"

      # systemd-coredump landing zone (mostly debugging convenience).
      "/var/lib/systemd/coredump"

    ];

    files = [
      # systemd / journald host identity. Generated fresh on first boot if
      # not present; impermanence catches and persists whatever first-boot
      # writes here.
      "/etc/machine-id"

    ];
  };
}
