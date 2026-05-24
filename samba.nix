{ config, lib, pkgs, ... }:

{
  # Samba file server. Exposes ~/Public as the `public` share, authenticated
  # as the `otso` Unix user. The Samba password is *separate* from the login
  # password — set it after the first rebuild with `sudo smbpasswd -a otso`.
  # openFirewall covers 139/445 (SMB) and 137/138 (NetBIOS name/datagram).
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "server string" = "markeeg";
        "workgroup" = "WORKGROUP";
        "security" = "user";
        "map to guest" = "never";
        # Restrict to the LAN; tighten if you know your subnet.
        "hosts allow" = "192.168. 10. 127.";
        "hosts deny" = "0.0.0.0/0";
      };
      public = {
        path = "/home/otso/Public";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "otso";
        "force user" = "otso";
        "create mask" = "0644";
        "directory mask" = "0755";
      };
    };
  };

  # WS-Discovery so Windows/macOS/Dolphin show `markeeg` in their network view.
  # Opens UDP 3702 and TCP 5357.
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  # Make sure the shared directory exists and is owned by otso.
  systemd.tmpfiles.rules = [
    "d /home/otso/Public 0755 otso users -"
  ];
}
