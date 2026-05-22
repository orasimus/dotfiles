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

## `nh` rebuild helper

`pkgs.nh` wraps `nixos-rebuild`/`home-manager` with a build-tree view, a
generation diff, and a confirmation prompt before activation. `nh os switch
~/.dotfiles --ask` is the headline command.

Why not now: `asenna` (the `sudo nixos-rebuild switch --flake …` alias) is
fine. `nh` adds polish — diff preview, GC ergonomics — but no capability the
current setup lacks. Worth a try when I next have an hour to fiddle.
