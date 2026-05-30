{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/nvme0n1";
      content = {
        type = "gpt";
        partitions = {
          # Partition `label` (PARTLABEL) is intentionally left unset so disko
          # falls back to its `disk-<diskname>-<partname>` default (here:
          # `disk-main-ESP`, `disk-main-nixos`). Short labels like "nixos" are
          # commonly used by NixOS installer ISOs and other tooling, and GPT
          # does not require PARTLABELs to be unique — udev's
          # `/dev/disk/by-partlabel/<name>` is order-dependent on collision,
          # so a shared label can swing the initrd LUKS lookup at the wrong
          # device after plugging in another disk.
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              # nodev/nosuid/noexec: /boot only holds kernel + initrd, which
              # the EFI loader maps directly (not via execve), so denying all
              # three closes a privilege-escalation surface at no cost.
              mountOptions = [ "umask=0077" "nodev" "nosuid" "noexec" ];
            };
          };

          nixos = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              # 4K sector size: cryptsetup still defaults to 512B and does
              # not reliably auto-detect 4K on NVMe. Measurable throughput
              # and write-amplification win, but only applied at luksFormat
              # — cannot be changed later without a full reencrypt.
              extraFormatArgs = [ "--sector-size" "4096" ];
              settings = {
                allowDiscards = true;
                bypassWorkqueues = true;
              };
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "@root" = {
                    mountpoint = "/";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };
                  "@root-blank" = { };
                  # /nix can be nodev,nosuid because NixOS routes every
                  # setuid binary through /run/wrappers/bin (a tmpfs that
                  # honors the bit), so nothing in the store actually
                  # depends on its own setuid bit. noexec is NOT safe — Nix
                  # runs binaries directly out of the store.
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "compress=zstd" "noatime" "nodev" "nosuid" ];
                  };
                  # /persist holds the source for impermanence bind mounts,
                  # several of which surface code that needs to run: project
                  # checkouts under ~/Projects, Steam libraries under
                  # ~/.local/share/Steam, Heroic-installed games, etc. Bind
                  # mounts inherit mount flags by default, so `noexec` here
                  # would propagate and break those launches. nodev,nosuid
                  # are still safe (no device nodes, no setuid binaries
                  # legitimately live here).
                  "@persist" = {
                    mountpoint = "/persist";
                    mountOptions = [ "compress=zstd" "noatime" "nodev" "nosuid" ];
                  };
                  # /var/log is journald's spool; same reasoning as /persist.
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [ "compress=zstd" "noatime" "nodev" "nosuid" "noexec" ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  fileSystems."/persist".neededForBoot = true;
  fileSystems."/var/log".neededForBoot = true;
}
