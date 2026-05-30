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

## `nh` rebuild helper

`pkgs.nh` wraps `nixos-rebuild`/`home-manager` with a build-tree view, a
generation diff, and a confirmation prompt before activation. `nh os switch
~/.dotfiles --ask` is the headline command.

Why not now: `asenna` (the `sudo nixos-rebuild switch --flake …` alias) is
fine. `nh` adds polish — diff preview, GC ergonomics — but no capability the
current setup lacks. Worth a try when I next have an hour to fiddle.
