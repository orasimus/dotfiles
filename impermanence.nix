# Impermanence: on every boot the `@root` btrfs subvolume is rolled back to
# the empty `@root_blank` snapshot, then `environment.persistence."/persist"`
# below bind-mounts the declared system paths from `/persist` back into place.
# `/nix`, `/persist`, `/var/log`, and `/boot` are independent subvolumes /
# partitions and are unaffected by the wipe.
#
# Prerequisites before the first switch + reboot under this config:
#   1) The `@root_blank` subvolume must exist:
#        sudo mount -o subvol=/ /dev/nvme0n1p2 /mnt/btrfs
#        sudo btrfs subvolume create /mnt/btrfs/@root_blank
#        sudo umount /mnt/btrfs
#      (It is intentionally empty — every reboot snapshots this over @root.)
#   2) Any files that already live on `@root` and need to survive the first
#      wipe must be relocated under `/persist/` first. In this config that
#      currently means at least:
#        /etc/nordlynx/private.key   → /persist/etc/nordlynx/private.key
#        /etc/nm-secrets.env         → /persist/etc/nm-secrets.env
#        /var/lib/{NetworkManager,bluetooth,fwupd,nixos}/ → /persist/var/lib/...
#      The bind mounts declared below pull these back into place on subsequent
#      boots, but the *first* boot under impermanence loses anything not yet
#      staged in /persist.

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
    script = ''
      mkdir -p /btrfs_tmp
      mount -o subvol=/ /dev/disk/by-uuid/630b3ded-5206-4369-a36e-50a6d462db9c /btrfs_tmp

      if [[ -e /btrfs_tmp/@root ]]; then
        mkdir -p /btrfs_tmp/old_roots
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
      for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30 2>/dev/null); do
        delete_subvolume_recursively "$i"
      done

      btrfs subvolume snapshot /btrfs_tmp/@root_blank /btrfs_tmp/@root
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

      # NordVPN WireGuard private key (referenced as a file path by
      # networking.wg-quick.interfaces.nordlynx.privateKeyFile in vpn.nix).
      "/etc/nordlynx"
    ];

    files = [
      # systemd / journald host identity. Generated fresh on first boot if
      # not present; impermanence catches and persists whatever first-boot
      # writes here.
      "/etc/machine-id"

      # WiFi PSK substitution file, referenced by
      # networking.networkmanager.ensureProfiles.environmentFiles.
      "/etc/nm-secrets.env"
    ];
  };
}
