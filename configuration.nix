# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./vpn.nix
    ./desktop.nix
    ./fonts.nix
    ./firefox.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # This host is entirely flake-driven; the channel machinery (nix-channel
  # command + per-user channel symlinks under ~/.nix-defexpr) is dead weight
  # and a stale-input footgun. Disable it.
  nix.channel.enable = false;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "markeeg";
  networking.networkmanager.enable = true;
  # No cellular modems on this host — NM pulls ModemManager in by default; opt out.
  networking.modemmanager.enable = false;

  # Don't block boot on DHCP/association. wg-quick-nordlynx orders After=
  # network-online.target, but waiting for the target to actually fire costs
  # ~5s on this host. The kill switch (vpn.nix) protects against early traffic
  # leaks during the gap, so reaching graphical.target sooner is a free win.
  #
  # Failure mode to know about: on a slow link where WiFi association takes
  # longer than wg-quick's interface-setup, the VPN unit can start before the
  # interface is associated and fail. The kill switch then blocks all traffic
  # until you `systemctl restart wg-quick-nordlynx`. If this ever bites, two
  # fixes — pick one:
  #   a) Cap the original wait at 5s instead of disabling:
  #        systemd.services.NetworkManager-wait-online.serviceConfig.ExecStart =
  #          [ "" "${pkgs.networkmanager}/bin/nm-online -s -q --timeout=5" ];
  #   b) Order wg-quick after the WiFi device itself:
  #        systemd.services.wg-quick-nordlynx.after =
  #          [ "sys-subsystem-net-devices-wlp5s0.device" ];
  systemd.services.NetworkManager-wait-online.enable = false;

  # Declarative WiFi via NetworkManager keyfile profiles. The PSK is kept
  # out of the world-readable nix store: `$WIFI_HOME_PSK` is substituted
  # at activation time from /etc/nm-secrets.env (root:root 0400), which
  # must contain the single line `WIFI_HOME_PSK=<password>`.
  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ "/etc/nm-secrets.env" ];
    profiles.home = {
      connection = {
        id = "TP-Link_21EB";
        type = "wifi";
        autoconnect = true;
      };
      wifi = {
        ssid = "TP-Link_21EB";
        mode = "infrastructure";
      };
      wifi-security = {
        auth-alg = "open";
        key-mgmt = "wpa-psk";
        psk = "$WIFI_HOME_PSK";
      };
      ipv4.method = "auto";
      ipv6.method = "auto";
    };
  };

  # Set your time zone.
  time.timeZone = "Pacific/Auckland";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_NZ.UTF-8";

  # No physical printer on this host. GTK/Qt "Print → Save as PDF" uses
  # toolkit-internal file backends and does not need cupsd.
  services.printing.enable = false;

  # Firmware updates via LVFS (UEFI, SSD, dock, etc.). Run `fwupdmgr refresh`
  # then `fwupdmgr update` manually when you want to apply.
  services.fwupd.enable = true;

  # Enable sound with pipewire.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Unlocks AMD microcode updates and firmware blobs assumed by hardware-configuration.nix.
  hardware.enableRedistributableFirmware = true;

  # Bluetooth — managed from a terminal via `bluetoothctl` (no tray applet).
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Nix store maintenance: weekly GC of generations older than 14 days.
  # `auto-optimise-store` dedups during every build.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.settings.auto-optimise-store = true;


  # Wipe /tmp on boot — desktop with no encrypted swap, no reason to keep stale tmp.
  boot.tmp.cleanOnBoot = true;

  # The command-not-found DB shipped via nixpkgs is stale under flakes (built against
  # whatever nixpkgs the channel pointed at, not our pinned input). Disable to avoid
  # misleading "did you mean…" output.
  programs.command-not-found.enable = false;

  # Compressed RAM swap — low-friction memory pressure relief for a desktop.
  zramSwap.enable = true;

  # Define a user account. Don’t forget to set a password with ‘passwd’.
  users.users.otso = {
    isNormalUser = true;
    description = "otso";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
  };


  programs.steam.enable = true;

  # Disable system sleep/suspend/hibernate entirely.
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  # fish.enable at system level installs shell completions and /etc/shells entry;
  # the user program config lives in home.nix — both are needed.
  programs.fish.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Most CLI tools live under home-manager programs.* in home.nix (declarative
  # config, theming, fish integration). Only fd and jq remain system-scoped:
  # neither has a home-manager module that adds anything, and both are handy
  # to have available to root too.
  environment.systemPackages = with pkgs; [
    fd
    jq
  ];

  # Pinned to install version; independent of home.stateVersion. See
  # https://nixos.org/manual/nixos/unstable/options#opt-system.stateVersion
  system.stateVersion = "25.11";

}
