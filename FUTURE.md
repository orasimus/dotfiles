# Future investigations

Ideas I might come back to. Not blocking; here for context next time.

## Secrets in the flake (agenix)

Today `/etc/nm-secrets.env` (WiFi PSK) and `/etc/nordlynx/private.key` (WireGuard
key) live outside the flake. A fresh install of this host needs both files
placed by hand before `asenna` produces a working system — the flake alone
isn't enough to rebuild the machine.

`agenix` would let those secrets live in this repo, encrypted against an age
public key derived from my SSH key. At activation time agenix decrypts them
into `/run/agenix/<name>` and the existing module options
(`networking.networkmanager.ensureProfiles.environmentFiles`,
`wg-quick.privateKeyFile`) can point at those paths instead of `/etc/...`.

Why not now: the manual files work, and the recovery story (curl creds from
NordVPN, paste PSK once) is already documented inline in `configuration.nix`.
The win is reproducibility for a reinstall I haven't done.

Lighter than `sops-nix` for this scale (handful of standalone tokens, not
bundles of related secrets).

## Declarative disk layout with disko

Implemented in `disko.nix`: the host now declares its install-time disk layout
in the flake and imports `disko.nixosModules.disko`, so `fileSystems.*`,
`swapDevices`, and the LUKS initrd config come from the same source.

Partition table on `nvme0n1`:

| Partition | FS    | UUID                                  | Mount / role         |
|-----------|-------|---------------------------------------|----------------------|
| nvme0n1p1 | vfat  | generated at format time              | `/boot` (EFI system) |
| nvme0n1p2 | LUKS2 | generated at format time              | `cryptroot`          |

BTRFS subvolumes inside `/dev/mapper/cryptroot`:

| Subvolume    | Mounted at  | Role                                          |
|--------------|-------------|-----------------------------------------------|
| `@root`      | `/`         | rolled back to `@root-blank` on every boot    |
| `@root-blank` | —          | empty snapshot; source for the rollback       |
| `@nix`       | `/nix`      | Nix store (never wiped)                       |
| `@persist`   | `/persist`  | persistent system state (see `impermanence.nix`) |
| `@log`       | `/var/log`  | journal (neededForBoot)                       |

No disk swap. The rollback service in `impermanence.nix` archives old `@root`
snapshots under `/btrfs_tmp/old_roots/<timestamp>` for 30 days.

Fresh install sketch:

```
nix run github:nix-community/disko -- --mode destroy,format,mount ./disko.nix
nixos-install --flake ~/.dotfiles#markeeg
```

Before committing to the reinstall, make the disk-layout decisions that would
be painful to change later:

- ESP size: `disko.nix` currently allocates 1G for `/boot`. That is probably
  enough, especially with Lanzaboote's NixOS-oriented stub, but growing the ESP
  later is partition surgery. If in doubt, make it 2G before formatting.
- Hibernation: the current plan has zram only and no disk swap. A btrfs
  swapfile inside encrypted root can be added later, but it must be
  preallocated, NODATACOW, uncompressed, and wired with a resume offset. A
  dedicated encrypted swap partition would require deciding that now.
- LVM inside LUKS: not needed for this host because btrfs subvolumes cover the
  current use case. Adding LVM later would be a backup/restore migration, so
  only add it now if separate block volumes or partition-like resizing are a
  known requirement.
- Filesystem choice: switching away from btrfs later means reinstall/restore.
  Tweaking subvolumes, mount options, compression, scrub/balance timers, and
  snapshot policy is incremental.
- LUKS format shape: passphrases, recovery keys, TPM2 enrollment, FIDO2, and
  key rotation are incremental LUKS2 keyslot changes. Changing fundamental
  encryption parameters, detached headers, or integrity-style layouts later is
  at least a high-risk reencrypt/restore job.

Post-install hardening should not require another reinstall:

- Lanzaboote / Secure Boot: layer on after the encrypted install. The host is
  already UEFI + systemd-boot, which is the expected base.
- TPM2 unlock: enroll with `systemd-cryptenroll` after LUKS exists; PCR policy
  can be wiped and re-enrolled as the boot chain evolves.
- Signed PCR policy / measured boot: add after Lanzaboote/UKI-style boot is in
  place. Prefer policies that tolerate normal kernel/initrd updates over
  sealing only to one current PCR value.
- Secure Boot keys: firmware setup-mode work plus key enrollment/signing, not a
  disk layout concern. Keep recovery media and firmware access in mind before
  replacing OEM keys.
- Normal NixOS hardening: agenix/sops-nix, AppArmor, firewall rules, sysctls,
  audit/logging, systemd service sandboxing, user policy, fwupd, and
  impermanence path adjustments are ordinary rebuilds.

## `nh` rebuild helper

`pkgs.nh` wraps `nixos-rebuild`/`home-manager` with a build-tree view, a
generation diff, and a confirmation prompt before activation. `nh os switch
~/.dotfiles --ask` is the headline command.

Why not now: `asenna` (the `sudo nixos-rebuild switch --flake …` alias) is
fine. `nh` adds polish — diff preview, GC ergonomics — but no capability the
current setup lacks. Worth a try when I next have an hour to fiddle.
