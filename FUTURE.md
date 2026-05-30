# Future investigations

Ideas I might come back to. Not blocking; here for context next time.

## Measured boot / PCR policy

TPM2 unlock currently favors rebuild tolerance. A stricter policy could bind
unlock to Secure Boot state or signed PCR policy instead of accepting any boot
chain on the same TPM.

Questions to settle first:

- Which PCR set is stable enough across NixOS kernel/initrd updates?
- Whether Lanzaboote's signed generation model gives a practical signed-PCR
  workflow for this host.
- How recovery should work when firmware updates, Secure Boot dbx updates, or
  bootloader changes alter measurements.

## Additional hardening

Candidates that are still ordinary rebuilds:

- AppArmor policy.
- Firewall tightening beyond NetworkManager defaults.
- Kernel/sysctl hardening.
- Audit/logging review.
- systemd service sandboxing for long-running services.

## `nh` rebuild helper

`pkgs.nh` wraps `nixos-rebuild`/`home-manager` with a build-tree view, a
generation diff, and a confirmation prompt before activation. `nh os switch
~/.dotfiles --ask` is the headline command.

Why not now: `asenna` (the `sudo nixos-rebuild switch --flake …` alias) is
fine. `nh` adds polish — diff preview, GC ergonomics — but no capability the
current setup lacks. Worth a try when I next have an hour to fiddle.
