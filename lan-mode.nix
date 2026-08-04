{ pkgs, ... }:

let
  laneille = pkgs.writeShellApplication {
    name = "laneille";
    runtimeInputs = with pkgs; [ systemd ];
    text = ''
      echo "Entering LAN mode: stopping VPN, firewall, and kill-switch; starting file sharing."
      sudo systemctl stop nftables.service
      sudo systemctl stop wg-quick-nordlynx.service || true
      sudo systemctl start samba.target samba-wsdd.service
      sudo resolvectl flush-caches || true
    '';
  };

  kotiin = pkgs.writeShellApplication {
    name = "kotiin";
    runtimeInputs = with pkgs; [ systemd ];
    text = ''
      echo "Leaving LAN mode: stopping file sharing; restoring firewall, kill-switch, and VPN."
      sudo systemctl stop samba-smbd.service samba-nmbd.service samba.target samba-wsdd.service || true
      sudo systemctl start nftables.service
      sudo systemctl restart wg-quick-nordlynx.service
      sudo resolvectl flush-caches || true
    '';
  };
in
{
  # Runtime LAN profile: coordinate the VPN kill-switch with the SMB services
  # without building a second NixOS specialisation on every rebuild.
  environment.systemPackages = [ laneille kotiin ];
}
