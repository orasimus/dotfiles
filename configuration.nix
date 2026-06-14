# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-luks.nix
    ./vpn.nix
    ./desktop.nix
    ./fonts.nix
    ./firefox.nix
    ./impermanence.nix
    ./secrets.nix
    # ./samba.nix
  ];

  # Bootloader.
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  # Wipe /tmp on boot — desktop with no encrypted swap, no reason to keep stale tmp.
  boot.tmp.cleanOnBoot = true;

  # Most CLI tools live under home-manager programs.* in home.nix (declarative
  # config, theming, fish integration). Only fd and jq remain system-scoped:
  # neither has a home-manager module that adds anything, and both are handy
  # to have available to root too.
  environment.systemPackages = with pkgs; [
    fd
    jq
    mangohud
    sbctl
  ];

  # Keep Codex's user config writable for project trust and interactive
  # settings. Claude Code still consumes the shared Home Manager MCP config.
  environment.etc."codex/config.toml".text = ''
    [mcp_servers.nixos]
    command = "${pkgs.mcp-nixos}/bin/mcp-nixos"
    enabled = true
  '';

  # Bluetooth — managed from a terminal via `bluetoothctl` (no tray applet).
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Unlocks AMD microcode updates and firmware blobs assumed by hardware-configuration.nix.
  hardware.enableRedistributableFirmware = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Select internationalisation properties.
  i18n.defaultLocale = "en_NZ.UTF-8";

  networking.hostName = "markeeg";

  # No cellular modems on this host — NM pulls ModemManager in by default; opt out.
  networking.modemmanager.enable = false;

  networking.networkmanager.enable = true;

  # Declarative WiFi via NetworkManager keyfile profiles. The PSK is kept
  # out of the world-readable nix store: `$WIFI_HOME_PSK` is substituted
  # at activation time from a sops-nix secret, which must contain the single
  # line `WIFI_HOME_PSK=<password>`.
  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ config.sops.secrets."network/nm-secrets.env".path ];
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

  # This host is entirely flake-driven; the channel machinery (nix-channel
  # command + per-user channel symlinks under ~/.nix-defexpr) is dead weight
  # and a stale-input footgun. Disable it.
  nix.channel.enable = false;

  # Nix store maintenance: weekly GC of generations older than 14 days.
  # `auto-optimise-store` dedups during every build.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.settings.auto-optimise-store = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # The command-not-found DB shipped via nixpkgs is stale under flakes (built against
  # whatever nixpkgs the channel pointed at, not our pinned input). Disable to avoid
  # misleading "did you mean…" output.
  programs.command-not-found.enable = false;

  # fish.enable at system level installs shell completions and /etc/shells entry;
  # the user program config lives in home.nix — both are needed.
  programs.fish.enable = true;

  programs.gamemode.enable = true;
  programs.gamescope.enable = true;
  programs.steam = {
    enable = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  powerManagement.cpuFreqGovernor = "performance";

  # RealtimeKit — required by services.pipewire below for audio thread realtime priority.
  security.rtkit.enable = true;

  # Monthly btrfs scrub: read every block and verify its checksum so silent
  # bit-rot surfaces in journald instead of waiting for the day we cat the
  # affected file. With no second copy on this host the scrub only detects,
  # it cannot self-heal — early notice is still worth the background read.
  services.btrfs.autoScrub.enable = true;

  # Weekly fstrim — belt-and-braces alongside the kernel's inline
  # `discard=async` (auto-enabled on btrfs since 6.2) and the LUKS
  # `allowDiscards=true` passthrough configured in disko.nix.
  services.fstrim.enable = true;

  # Firmware updates via LVFS (UEFI, SSD, dock, etc.). Run `fwupdmgr refresh`
  # then `fwupdmgr update` manually when you want to apply.
  services.fwupd.enable = true;

  # Enable sound with pipewire.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # No physical printer on this host. GTK/Qt "Print → Save as PDF" uses
  # toolkit-internal file backends and does not need cupsd.
  services.printing.enable = false;

  # Pinned to install version; independent of home.stateVersion. See
  # https://nixos.org/manual/nixos/unstable/options#opt-system.stateVersion
  system.stateVersion = "25.11";

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

  # Disable system sleep/suspend/hibernate entirely.
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  # Set your time zone.
  time.timeZone = "Pacific/Auckland";

  # Impermanence-friendly user management. `/etc/shadow` lives on the wiped
  # @root subvolume, so any imperatively-set password would vanish on the
  # next reboot. Instead, hashes are decrypted by sops-nix before users are
  # created, and activation rewrites /etc/shadow from them on every boot.
  #
  # `mutableUsers = false` enforces the declarative path — `passwd` still
  # appears to work in a running session but its changes are dropped on
  # reboot, which would be silently confusing. Better to disable it.
  users.mutableUsers = false;

  users.users.otso = {
    isNormalUser = true;
    description = "otso";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
    hashedPasswordFile = config.sops.secrets."passwords/otso".path;
  };

  users.users.root.hashedPasswordFile = config.sops.secrets."passwords/root".path;

  # Compressed RAM swap — low-friction memory pressure relief for a desktop.
  zramSwap.enable = true;
}
