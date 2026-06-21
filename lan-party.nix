{ lib, ... }:

{
  # A runtime-selectable LAN-party profile. After rebuilding, enter it with:
  #   sudo /run/current-system/specialisation/lan/bin/switch-to-configuration switch
  # Return to the normal profile with:
  #   sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
  specialisation.lan.configuration = {
    imports = [ ./samba.nix ];

    local.vpn.enable = lib.mkForce false;

    networking.firewall.enable = lib.mkForce false;
    networking.networkmanager.settings = {
      "global-dns-domain-*" = {
        servers = "8.8.8.8,8.8.4.4,2001:4860:4860::8888,2001:4860:4860::8844";
      };
    };
  };
}
