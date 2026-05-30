# Updated Reinstall Instructions

  1. Boot the NixOS installer USB.
  2. Open a terminal and become root if needed:

  sudo -i

  3. Connect to the internet:

  nmcli device wifi list
  nmcli device wifi connect "TP-Link_21EB" --ask

  4. Clone the repo:

  cd /tmp
  git clone <your-repo-url> dotfiles
  cd /tmp/dotfiles

  5. Confirm the install disk:

  lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE,MOUNTPOINTS

  6. Run disko:

  nix run github:nix-community/disko -- --mode destroy,format,mount ./disko.nix

  7. Copy in the age key:

  mkdir -p /mnt/persist/var/lib/sops-nix
  install -m 0400 /path/to/key.txt /mnt/persist/var/lib/sops-nix/key.txt

  8. Install NixOS:

  nixos-install --flake /tmp/dotfiles#markeeg

  9. Reboot:

  reboot

  10. First boot checks:

  findmnt / /boot /nix /persist /var/log
  systemctl status NetworkManager
  systemctl status wg-quick-nordlynx
