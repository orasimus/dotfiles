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

## Declarative disk layout with disko (+ optional LUKS)

### Current setup (for reference)

The disk is partitioned manually and not described anywhere in the flake.
Partition table on `nvme0n1`:

| Partition | FS    | UUID                                  | Mount / role         |
|-----------|-------|---------------------------------------|----------------------|
| nvme0n1p1 | vfat  | 81DF-3BF4                             | `/boot` (EFI system) |
| nvme0n1p2 | btrfs | 630b3ded-5206-4369-a36e-50a6d462db9c  | data partition       |

BTRFS subvolumes on nvme0n1p2:

| Subvolume    | Mounted at  | Role                                          |
|--------------|-------------|-----------------------------------------------|
| `@root`      | `/`         | rolled back to `@root-blank` on every boot    |
| `@root-blank` | —          | empty snapshot; source for the rollback       |
| `@nix`       | `/nix`      | Nix store (never wiped)                       |
| `@persist`   | `/persist`  | persistent system state (see `impermanence.nix`) |
| `@log`       | `/var/log`  | journal (neededForBoot)                       |

No swap, no LUKS. The rollback service in `impermanence.nix` archives old
`@root` snapshots under `/btrfs_tmp/old_roots/<timestamp>` for 30 days.

### Why disko

Right now a fresh install requires formatting the disk by hand before
`asenna` can produce a working system — the partition/subvolume structure
isn't captured in the flake at all. `disko` (github:nix-community/disko)
would let `flake.nix` declare the exact layout above, so a reinstall becomes:

```
nix run github:nix-community/disko -- --mode disko path/to/disk.nix
nixos-install --flake ~/.dotfiles#markeeg
```

The disko module also emits `fileSystems.*` and `swapDevices` automatically,
so `hardware-configuration.nix` entries for those could be dropped.

### LUKS path

Adding full-disk encryption is a natural follow-on: wrap nvme0n1p2 in a
LUKS2 container, put the BTRFS on the opened `/dev/mapper/cryptroot`, and
have disko generate the matching `boot.initrd.luks.devices.*` stanza. With
`systemd-cryptenroll` the unlock key can be bound to a TPM2 PCR policy
(silent unlock on trusted boots) with a fallback passphrase.

The impermanence rollback service targets the device by UUID today; under
LUKS it would target the mapper device (`/dev/mapper/cryptroot`) instead —
a small script change.

Why not now: the disk isn't going anywhere and a live re-encryption would
need a full backup + reinstall. Worth doing at the next hardware refresh or
whenever a reinstall is necessary for another reason.

## `nh` rebuild helper

`pkgs.nh` wraps `nixos-rebuild`/`home-manager` with a build-tree view, a
generation diff, and a confirmation prompt before activation. `nh os switch
~/.dotfiles --ask` is the headline command.

Why not now: `asenna` (the `sudo nixos-rebuild switch --flake …` alias) is
fine. `nh` adds polish — diff preview, GC ergonomics — but no capability the
current setup lacks. Worth a try when I next have an hour to fiddle.
